local ADDON, T = ...
local L = T.L
local DB = T.DB
local Zones = T.Zones

-- Everything is wired up here, after every module has been loaded.

local function bootstrap()
    DB:Initialize()

    T.Addon.loaded = true

    T.Options:Initialize()
    T.Broker:Initialize()
    T.List:Initialize()
    T.Pins:Initialize()
    T.SkinElvUI()

    Zones:RememberPosition()
    Zones:Detect()
    T.Progress:Sync(false)
    T.Discovery:Scan()
    T.Calls:Scan()
    T.Addon:Refresh()
end

T.Addon:Listen("PLAYER_LOGIN", bootstrap)

local function onZoneChanged()
    if not T.Addon.loaded then return end

    Zones:RememberPosition()

    local before = Zones:Current()
    Zones:Detect()
    local delve = Zones:Current()

    if delve and not before and DB:Profile().autoShow and not T.List:IsShown() then
        T.List:SetShown(true)
    end

    T.Progress:Sync(false)
    T.Discovery:Scan()
    T.Addon:Refresh()
end

T.Addon:Listen("PLAYER_ENTERING_WORLD", onZoneChanged)
T.Addon:Listen("ZONE_CHANGED_NEW_AREA", onZoneChanged)
T.Addon:Listen("ZONE_CHANGED", onZoneChanged)

-- The player stands still to click a delve entrance, so this catches the spot
-- they zoned in from without polling on a timer.
T.Addon:Listen("PLAYER_STOPPED_MOVING", function()
    if T.Addon.loaded then Zones:RememberPosition() end
end)

-- Slash commands --------------------------------------------------------------

local function currentOrOnlyDelve()
    return (Zones:Current()) or T.Delves[1]
end

local function help()
    T.Print(L["Commands:"])
    for _, line in ipairs({
        "/tk - toggle the chest list",
        "/tk map - set every chest of this delve as waypoints",
        "/tk setmap - bind the current map to this delve",
        "/tk pois - print the map POIs the bountiful scan sees",
        "/tk setquest - bind the quest you are tracking to this delve",
        "/tk reset - forget learned positions and progress",
        "/tk options - open the options, credits and version",
    }) do
        DEFAULT_CHAT_FRAME:AddMessage("  |cff9ecfff" .. L[line] .. "|r")
    end
end

local function diagnostics()
    T.Bountiful:Invalidate()
    T.Print("bountiful delves found: %d", T.Bountiful:Count())

    local delve, uiMapID = Zones:Current()
    if not delve then
        local mapID = C_Map.GetBestMapForUnit("player")
        local info = mapID and C_Map.GetMapInfo(mapID)
        T.Print("map %s (%s), instance: %s",
            tostring(mapID), info and info.name or "?", tostring(IsInInstance()))
        T.Print(L["You are not on a map Trovekeeper knows a delve for."])
        return
    end

    T.Print("%s: uiMapID %d", delve.name, uiMapID)
    local possible = T.Pins:MinimapPossible()
    T.Print("minimap pins possible: %s", tostring(possible))
    T.Discovery:Export()
end

SLASH_TROVEKEEPER1 = "/trovekeeper"
SLASH_TROVEKEEPER2 = "/tk"
SlashCmdList["TROVEKEEPER"] = function(input)
    local command = strlower(strtrim(input or ""))

    if command == "" then
        T.List:Toggle()
    elseif command == "map" or command == "all" then
        T.Waypoint:SetAll(currentOrOnlyDelve())
    elseif command == "entrance" then
        T.Waypoint:SetEntrance(currentOrOnlyDelve())
    elseif command == "setmap" then
        local delve = Zones:Detect(true) or T.Delves[1]
        Zones:BindCurrentMap(delve)
    elseif strsub(command, 1, 4) == "pois" then
        T.Bountiful:Invalidate()
        T.Bountiful:Report(strfind(command, "all", 1, true) ~= nil)
    elseif strsub(command, 1, 8) == "setquest" then
        -- "/tk setquest [<delve>] [<quest id>]". A trailing number is the id;
        -- whatever is left names the delve, and with nothing left it is the one
        -- you are standing in.
        local rest = strtrim(strsub(command, 9))
        local questID = tonumber(strmatch(rest, "(%d+)$"))
        if questID then rest = strtrim((gsub(rest, "%d+$", ""))) end
        T.Calls:BindTracked(T.Calls:Resolve(rest) or Zones:Current(), questID)
    elseif command == "reset" then
        DB:ResetLearned()
        T.Print(L["/tk reset - forget learned positions and progress"])
    elseif command == "options" or command == "config"
        or command == "about" or command == "credits" then
        T.Options:Toggle()
    elseif command == "export" then
        T.Discovery:Export()
    elseif command == "diag" or command == "debug" then
        diagnostics()
    else
        help()
    end
end
