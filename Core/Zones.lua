local ADDON, T = ...
local L = T.L
local DB = T.DB

local Zones = {}
T.Zones = Zones

local function matches(delve, name)
    if not name or not delve.mapNamePattern then return false end
    return strfind(strlower(name), delve.mapNamePattern, 1, true) ~= nil
end

-- How close to a listed entrance the player must have been standing for the
-- instance they just walked into to be that delve. Two entrances in the same
-- zone are more than 20 points apart, so 5 cannot pick the wrong one.
local ENTRANCE_RANGE = 5

-- Name matching only works while the client is English: proper nouns like
-- Gnarldor and Atal'Aman survive translation, but "Twilight Crypts" and "The
-- Darkway" do not. So the delve is also identified by which entrance the player
-- walked into, which is language-independent. The position is saved, so it
-- survives the reload that a zone-in sometimes brings.
local function delveByEntrance()
    local from = TrovekeeperDB and TrovekeeperDB.lastOutdoor
    if not from then return nil end

    local best, bestDistance
    for _, delve in ipairs(T.Delves) do
        local entrance = delve.entrance
        if entrance and entrance.uiMapID == from.uiMapID then
            local dx, dy = from.x - entrance.x, from.y - entrance.y
            local distance = sqrt(dx * dx + dy * dy)
            if distance <= ENTRANCE_RANGE and (not bestDistance or distance < bestDistance) then
                best, bestDistance = delve, distance
            end
        end
    end
    return best
end

-- Called while the player is outside, so the entrance they use is known once
-- they are inside and the outdoor map is gone.
function Zones:RememberPosition()
    if IsInInstance() then return end
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then return end
    local position = C_Map.GetPlayerMapPosition(uiMapID, "player")
    if not position then return end

    local x, y = T.ToPercent(position.x, position.y)
    TrovekeeperDB.lastOutdoor = { uiMapID = uiMapID, x = x, y = y }
end

-- The delve's uiMapID is learned, never hardcoded. Requiring IsInInstance() is
-- what keeps the outdoor island - which carries the same proper noun in its
-- name - from being mistaken for the delve map itself.
function Zones:Detect(force)
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then return nil end

    local inInstance = IsInInstance()
    if not (inInstance or force) then return nil end

    local info = C_Map.GetMapInfo(uiMapID)
    local mapName = info and info.name
    local instanceName = GetInstanceInfo()

    local found
    for _, delve in ipairs(T.Delves) do
        if matches(delve, mapName) or matches(delve, instanceName) then
            found = delve
            break
        end
    end

    -- Falls back to the entrance the player came through, which works in every
    -- locale.
    found = found or delveByEntrance()
    if not found then return nil end

    -- Learned once and then left alone. A delve with more than one floor would
    -- otherwise rebind on every floor change and drag the chests onto whichever
    -- map the player last stood on. /tk setmap corrects a wrong binding.
    local state = DB:Delve(found.key)
    if state.uiMapID == nil then
        state.uiMapID = uiMapID
        T.Print(L["Learned the map for %s (uiMapID %d)."], found.name, uiMapID)
        T.Addon:Refresh()
    end
    return found, uiMapID
end

-- Force the current map onto a delve. Used by /tk setmap when the automatic
-- match cannot fire, e.g. because a future delve map is named differently.
function Zones:BindCurrentMap(delve)
    local uiMapID = C_Map.GetBestMapForUnit("player") or (WorldMapFrame and WorldMapFrame:GetMapID())
    if not uiMapID then return false end
    DB:Delve(delve.key).uiMapID = uiMapID
    T.Print(L["Learned the map for %s (uiMapID %d)."], delve.name, uiMapID)
    T.Addon:Refresh()
    return true
end

function Zones:MapID(delve)
    return DB:Delve(delve.key).uiMapID
end

-- The delve the player is standing in right now, or nil.
function Zones:Current()
    if not IsInInstance() then return nil end
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then return nil end
    for _, delve in ipairs(T.Delves) do
        if DB:Delve(delve.key).uiMapID == uiMapID then return delve, uiMapID end
    end
    return nil
end

-- The delve whose chests belong on a given map, so the pin providers can ask
-- "is this the map I should draw on?" for both the delve and its entrance.
function Zones:DelveForMap(uiMapID)
    for _, delve in ipairs(T.Delves) do
        if DB:Delve(delve.key).uiMapID == uiMapID then return delve end
    end
    return nil
end

function Zones:DelveWithEntranceOn(uiMapID)
    for _, delve in ipairs(T.Delves) do
        if delve.entrance and delve.entrance.uiMapID == uiMapID then return delve end
    end
    return nil
end

-- The single source of truth for "which chests exist and where". Static guide
-- data, corrections learned from the game's own markers, and any extra chest
-- the guides missed, merged into one list.
function Zones:Chests(delve)
    local state = DB:Delve(delve.key)
    local out = {}

    for i, chest in ipairs(delve.chests) do
        local learned = state.chests[i]
        out[#out + 1] = {
            id = i,
            number = i,
            x = learned and learned.x or chest.x,
            y = learned and learned.y or chest.y,
            verified = learned ~= nil,
            found = state.found[i] and true or false,
            label = L["Sturdy Chest"] .. " " .. i,
        }
    end

    for n, extra in ipairs(state.extra) do
        local id = "x" .. n
        local number = #delve.chests + n
        out[#out + 1] = {
            id = id,
            number = number,
            x = extra.x,
            y = extra.y,
            verified = true,
            extra = true,
            found = state.found[id] and true or false,
            label = L["Sturdy Chest"] .. " " .. number,
        }
    end

    return out
end

function Zones:SetFound(delve, id, found)
    DB:Delve(delve.key).found[id] = found or nil
    T.Addon:Refresh()
end

local HBD = LibStub("HereBeDragons-2.0")

-- Distance in yards from the player to a chest, or nil when the player is not
-- on the delve's map. HBD resolves the map to world coordinates, which works
-- inside instances too.
function Zones:Distance(delve, chest)
    local uiMapID = self:MapID(delve)
    if not uiMapID then return nil end

    -- The third return is HBD's own idea of the player's map, which is the one
    -- its coordinates are expressed in.
    local px, py, playerMap = HBD:GetPlayerZonePosition()
    if not px or playerMap ~= uiMapID then return nil end

    -- Returns nil when the map exposes no world rectangle, which some instance
    -- maps do not. Callers fall back to showing plain coordinates.
    local cx, cy = T.ToFraction(chest.x, chest.y)
    return HBD:GetZoneDistance(uiMapID, px, py, uiMapID, cx, cy)
end

-- Straight-line distance in map percentage points. Unlike Distance() this needs
-- no world rectangle, so it still answers on instance maps where HereBeDragons
-- cannot. Used to attribute a looted chest, where "which of these three" is the
-- only question that matters.
function Zones:MapDistance(delve, chest)
    local uiMapID = self:MapID(delve)
    if not uiMapID then return nil end
    if C_Map.GetBestMapForUnit("player") ~= uiMapID then return nil end

    local position = C_Map.GetPlayerMapPosition(uiMapID, "player")
    if not position then return nil end

    local px, py = T.ToPercent(position.x, position.y)
    local dx, dy = px - chest.x, py - chest.y
    return sqrt(dx * dx + dy * dy)
end
