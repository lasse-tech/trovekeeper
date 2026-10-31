local ADDON, T = ...
local L = T.L
local DB = T.DB
local Zones = T.Zones

local Discovery = {}
T.Discovery = Discovery

-- Map-coordinate distance, in percentage points, that still counts as "the same
-- chest". The three Gnarldor Isle chests sit at least 25 points apart, so 10 is
-- far too small to confuse two of them and far larger than the error in any
-- published coordinate.
local SAME_CHEST = 10
local SAME_EXTRA = 5

local function isTreasureVignette(info)
    local atlas = info and info.atlasName
    if not atlas then return false end
    atlas = strlower(atlas)
    return strfind(atlas, "loot", 1, true) ~= nil
        or strfind(atlas, "chest", 1, true) ~= nil
        or strfind(atlas, "treasure", 1, true) ~= nil
end

local function distanceOnMap(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return sqrt(dx * dx + dy * dy)
end

-- The game marks chests that come into range with a vignette, and a vignette
-- carries the exact position. Every sighting sharpens the guide coordinates the
-- addon shipped with, and a chest no guide listed gets recorded outright.
local function record(delve, x, y)
    local state = DB:Delve(delve.key)

    local bestIndex, bestDistance
    for i, chest in ipairs(delve.chests) do
        local known = state.chests[i] or chest
        local distance = distanceOnMap(x, y, known.x, known.y)
        if distance <= SAME_CHEST and (not bestDistance or distance < bestDistance) then
            bestIndex, bestDistance = i, distance
        end
    end

    if bestIndex then
        local first = state.chests[bestIndex] == nil
        state.chests[bestIndex] = { x = x, y = y }
        if first then
            T.Print(L["Corrected a chest position from the game's own marker."])
        end
        return true
    end

    for _, extra in ipairs(state.extra) do
        if distanceOnMap(x, y, extra.x, extra.y) <= SAME_EXTRA then
            extra.x, extra.y = x, y
            return false
        end
    end

    state.extra[#state.extra + 1] = { x = x, y = y }
    T.Print(L["Recorded an extra chest at %.1f, %.1f."], x, y)
    return true
end

function Discovery:Scan()
    if not T.Addon.loaded then return end

    local delve, uiMapID = Zones:Current()
    if not delve then return end

    local guids = C_VignetteInfo and C_VignetteInfo.GetVignettes and C_VignetteInfo.GetVignettes()
    if not guids then return end

    local changed = false
    for _, guid in ipairs(guids) do
        local info = C_VignetteInfo.GetVignetteInfo(guid)
        if isTreasureVignette(info) then
            local position = C_VignetteInfo.GetVignettePosition(guid, uiMapID)
            if position then
                local x, y = T.ToPercent(position.x, position.y)
                if record(delve, x, y) then changed = true end
            end
        end
    end

    if changed then T.Addon:Refresh() end
end

T.Addon:Listen("VIGNETTE_MINIMAP_UPDATED", function() Discovery:Scan() end)
T.Addon:Listen("VIGNETTES_UPDATED", function() Discovery:Scan() end)

-- Dump what the addon has learned, so verified coordinates can go back into
-- Core\Data.lua for everyone.
function Discovery:Export()
    for _, delve in ipairs(T.Delves) do
        local state = DB:Delve(delve.key)
        T.Print("%s (uiMapID %s)", delve.name, tostring(state.uiMapID))
        for _, chest in ipairs(Zones:Chests(delve)) do
            DEFAULT_CHAT_FRAME:AddMessage(format("    { x = %.2f, y = %.2f },%s",
                chest.x, chest.y,
                chest.verified and "  -- verified in-game" or "  -- from guide data"))
        end
    end
end
