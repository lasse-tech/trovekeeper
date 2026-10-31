local ADDON, T = ...
local L = T.L
local Zones = T.Zones

local Waypoint = {}
T.Waypoint = Waypoint

-- Waypoints this addon set, keyed by delve and chest, so clicking the same
-- chest twice replaces its waypoint instead of stacking a second one.
local mine = {}

local function key(delve, id) return delve.key .. ":" .. tostring(id) end

local function clear(k)
    local uid = mine[k]
    if not uid then return end
    mine[k] = nil
    if TomTom and TomTom.IsValidWaypoint and TomTom:IsValidWaypoint(uid) then
        TomTom:RemoveWaypoint(uid)
    end
end

function Waypoint:Available()
    return TomTom ~= nil and TomTom.AddWaypoint ~= nil
end

local function add(k, uiMapID, x, y, title, crazy)
    clear(k)
    local fx, fy = T.ToFraction(x, y)
    mine[k] = TomTom:AddWaypoint(uiMapID, fx, fy, {
        title = title,
        from = "Trovekeeper",
        persistent = false,
        minimap = true,
        world = true,
        crazy = crazy,
        silent = true,
    })
    return mine[k]
end

function Waypoint:SetChest(delve, chest)
    if not self:Available() then
        T.Print(L["TomTom is not installed - waypoint skipped."])
        return
    end

    local uiMapID = Zones:MapID(delve)
    if not uiMapID then
        T.Print(L["This delve's map is not known yet."])
        T.Print(L["Enter %s once, or use /tk setmap while inside."], delve.name)
        return
    end

    local title = delve.name .. " - " .. chest.label
    add(key(delve, chest.id), uiMapID, chest.x, chest.y, title, true)
    T.Print(L["Waypoint set: %s"], chest.label)
end

-- One waypoint per outstanding chest, with the crazy arrow pointing at the
-- first of them.
function Waypoint:SetAll(delve)
    if not self:Available() then
        T.Print(L["TomTom is not installed - waypoint skipped."])
        return
    end

    local uiMapID = Zones:MapID(delve)
    if not uiMapID then
        T.Print(L["This delve's map is not known yet."])
        T.Print(L["Enter %s once, or use /tk setmap while inside."], delve.name)
        return
    end

    local first = true
    for _, chest in ipairs(Zones:Chests(delve)) do
        if not chest.found then
            add(key(delve, chest.id), uiMapID, chest.x, chest.y,
                delve.name .. " - " .. chest.label, first)
            first = false
        end
    end
end

-- A waypoint on a plain map position, for the things that are not a chest and
-- not a shipped entrance - a bountiful delve, whose position comes off the
-- game's own area POI.
function Waypoint:SetSpot(id, uiMapID, x, y, title)
    if not self:Available() then
        T.Print(L["TomTom is not installed - waypoint skipped."])
        return false
    end
    if not uiMapID or not x or not y then return false end

    add(id, uiMapID, x, y, title, true)
    T.Print(L["Waypoint set: %s"], title)
    return true
end

function Waypoint:SetEntrance(delve)
    if not self:Available() then
        T.Print(L["TomTom is not installed - waypoint skipped."])
        return
    end
    local entrance = delve.entrance
    if not entrance then return end
    local title = delve.name .. " - " .. L["Delve entrance"]
    add(key(delve, "entrance"), entrance.uiMapID, entrance.x, entrance.y, title, true)
    T.Print(L["Waypoint set: %s"], title)
end
