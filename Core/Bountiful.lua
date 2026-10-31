local ADDON, T = ...
local L = T.L

local Bountiful = {}
T.Bountiful = Bountiful

-- Which delves are bountiful right now is the game's business, not this
-- addon's: the set turns over on the daily reset, and the game drops a delve
-- from it once you have run the thing, so there is nothing here worth shipping
-- in a data file. Blizzard puts an area POI on the map for each one:
--
--   8670  Collegiate Calamity  atlas=delves-bountiful  desc=Bountiful Delve
--   7874  The Spiral Weave     atlas=delves-regular    desc=Delve
--
-- The atlas is the test - it is the half that is never translated. The
-- description is the client's own wording for "Bountiful Delve", which is why
-- the rows and the waypoints label themselves with it rather than with a
-- translation invented here.
--
-- The POIs sit on the *continent* map as often as on the zone maps - Midnight's
-- were found on Quel'Thalas (2537) and nowhere else - so both are scanned, the
-- continent reached by walking the map tree rather than by a hardcoded id.
--
-- The POI hands over the delve's name in the client's own language and its
-- exact position, so both the rows and the waypoints need no name matching at
-- all. Matching a POI back to T.CallDelves is a bonus - it is what puts a POI
-- found on a continent map under its own zone heading, and what lets a row show
-- its Delver's Call state - and every row works without it.
--
-- /tk pois prints what the client reports, which is how the two names above
-- were established rather than guessed.

local BOUNTIFUL = "bountiful"

-- The client's own words for a bountiful delve, taken off the first POI that
-- carried them. Saves inventing a translation for a label only Blizzard names.
local label

-- The set only changes on a reset, and AREA_POIS_UPDATED clears the cache the
-- moment the game says so. This is only here to keep Refresh() - which runs on
-- a good many events - off eleven map scans in a row.
local TTL = 30

local cache, cachedAt

local function poiPosition(info)
    local position = info.position
    if not position or not position.GetXY then return nil end
    local x, y = position:GetXY()
    if not x then return nil end
    return T.ToPercent(x, y)
end

-- The atlas alone. The description says the same thing, but it is translated
-- and this word is not, so it makes a fine label and a useless test.
local function isBountiful(info)
    local atlas = info and info.atlasName
    return atlas ~= nil and strfind(strlower(atlas), BOUNTIFUL, 1, true) ~= nil
end

function Bountiful:Label()
    return label or L["Bountiful Delve"]
end

-- Which maps to look at: every zone a delve sits in, plus the continent each of
-- those hangs off. Blizzard puts delve POIs on the continent map as readily as
-- on the zone map, and the continent's id is not worth hardcoding when the map
-- tree hands it over.
local function mapsToScan()
    local seen, out = {}, {}

    local function add(uiMapID)
        if not uiMapID or uiMapID == 0 or seen[uiMapID] then return end
        seen[uiMapID] = true
        out[#out + 1] = uiMapID
    end

    for _, uiMapID in ipairs(T.ZoneOrder) do add(uiMapID) end

    -- A second pass, so every zone map is scanned before any continent is: a
    -- delve listed on both is then attributed to its zone.
    local continent = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
    for _, uiMapID in ipairs(T.ZoneOrder) do
        local info = C_Map.GetMapInfo(uiMapID)
        for _ = 1, 4 do
            if not info or not info.parentMapID or info.parentMapID == 0 then break end
            info = C_Map.GetMapInfo(info.parentMapID)
            if not info or not info.mapType or info.mapType < continent then break end
            add(info.mapID)
        end
    end

    return out
end

-- Every POI on a map, from both sources the client offers. GetDelvesForMap is
-- the one that exists only where delves do, so it is asked first and its
-- absence is not an error.
local function poisFor(uiMapID)
    local out = {}
    if C_AreaPoiInfo.GetDelvesForMap then
        for _, poiID in ipairs(C_AreaPoiInfo.GetDelvesForMap(uiMapID) or {}) do
            out[#out + 1] = poiID
        end
    end
    for _, poiID in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(uiMapID) or {}) do
        out[#out + 1] = poiID
    end
    return out
end

local function scan()
    local byZone, order, seenName = {}, {}, {}
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then return {} end

    for _, uiMapID in ipairs(mapsToScan()) do
        for _, poiID in ipairs(poisFor(uiMapID)) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, poiID)
            local name = isBountiful(info) and (info.name or UNKNOWN) or nil

            -- The same delve turns up on its zone map and again on the
            -- continent; the first sighting wins, and the zone maps go first.
            if name and not seenName[name] then
                seenName[name] = true

                -- Resolving the name is what puts a POI found on a continent
                -- map under its own zone heading. Without it the map it was
                -- found on has to do.
                local delve = T.Calls:Resolve(name)
                local zone = (delve and delve.zone) or uiMapID
                local x, y = poiPosition(info)
                if info.description and info.description ~= "" then
                    label = info.description
                end

                if not byZone[zone] then
                    byZone[zone] = {}
                    order[#order + 1] = zone
                end
                local entries = byZone[zone]
                entries[#entries + 1] = {
                    poiID = poiID,
                    name = name,
                    delve = delve,
                    description = info.description,
                    uiMapID = uiMapID,
                    x = x,
                    y = y,
                }
            end
        end
    end

    -- T.ZoneOrder first, so the headings keep the order the rest of the addon
    -- uses; anything found somewhere unexpected trails behind rather than
    -- vanishing.
    local groups, emitted = {}, {}
    local function emit(zone)
        if emitted[zone] or not byZone[zone] then return end
        emitted[zone] = true
        local map = C_Map.GetMapInfo(zone)
        groups[#groups + 1] = {
            uiMapID = zone,
            name = (map and map.name) or T.ZoneNames[zone] or tostring(zone),
            entries = byZone[zone],
        }
    end

    for _, zone in ipairs(T.ZoneOrder) do emit(zone) end
    for _, zone in ipairs(order) do emit(zone) end

    return groups
end

function Bountiful:Groups()
    local now = GetTime()
    if cache and cachedAt and (now - cachedAt) < TTL then return cache end
    cache, cachedAt = scan(), now
    return cache
end

function Bountiful:Count()
    local n = 0
    for _, group in ipairs(self:Groups()) do
        n = n + #group.entries
    end
    return n
end

-- Whether a bountiful delve has already been run this week, which is the whole
-- reason Core\Calls.lua still learns quest ids without a list of its own.
function Bountiful:Done(entry)
    return entry.delve ~= nil and T.Calls:State(entry.delve) == T.Calls.DONE
end

-- How many are still outstanding, and how many there are. A delve whose call
-- has not been learned counts as outstanding - unknown is not the same as done,
-- and saying otherwise would quietly hide a delve still worth running.
function Bountiful:Counts()
    local left, total = 0, 0
    for _, group in ipairs(self:Groups()) do
        for _, entry in ipairs(group.entries) do
            total = total + 1
            if not self:Done(entry) then left = left + 1 end
        end
    end
    return left, total
end

function Bountiful:Invalidate()
    cache, cachedAt = nil, nil
end

-- Straight to the POI's own position, so this works for a delve the addon holds
-- no entrance coordinates for - which is every War Within one, and the three
-- Midnight entrances still unverified.
function Bountiful:Waypoint(entry)
    if not entry or not entry.x then return false end
    return T.Waypoint:SetSpot("bountiful:" .. entry.poiID, entry.uiMapID, entry.x, entry.y,
        entry.name .. " - " .. (entry.description or self:Label()))
end

-- What the client actually reports, which is the only way to settle what the
-- bountiful atlas is really called. `all` prints every POI on every map that
-- gets scanned; without it only the ones that look like a delve, which is short
-- enough to read - and to paste.
function Bountiful:Report(all)
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then
        T.Print("C_AreaPoiInfo is not available")
        return
    end

    T.Print("GetDelvesForMap: %s", tostring(C_AreaPoiInfo.GetDelvesForMap ~= nil))

    local shown, total = 0, 0
    for _, uiMapID in ipairs(mapsToScan()) do
        local pois = poisFor(uiMapID)
        local map = C_Map.GetMapInfo(uiMapID)
        local lines = {}

        for _, poiID in ipairs(pois) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, poiID)
            if info then
                total = total + 1
                local atlas = strlower(tostring(info.atlasName))
                local name = strlower(tostring(info.name))
                local interesting = strfind(atlas, "delve", 1, true)
                    or strfind(atlas, BOUNTIFUL, 1, true)
                    or strfind(name, "delve", 1, true)

                if all or interesting then
                    shown = shown + 1
                    lines[#lines + 1] = format("  %d  |cff9ecfff%s|r  atlas=%s%s%s",
                        poiID, tostring(info.name), tostring(info.atlasName),
                        info.description and ("  desc=" .. info.description) or "",
                        isBountiful(info) and "  |cff40ff40BOUNTIFUL|r" or "")
                end
            end
        end

        if #lines > 0 then
            T.Print("%s (%d): %d POIs", (map and map.name) or "?", uiMapID, #pois)
            for _, line in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(line) end
        end
    end

    T.Print("%d of %d POIs shown across %d maps. %s",
        shown, total, #mapsToScan(),
        all and "" or "Use /tk pois all for everything.")
end

T.Addon:Listen("AREA_POIS_UPDATED", function()
    Bountiful:Invalidate()
    T.Addon:Refresh()
end)
