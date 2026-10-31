local ADDON, T = ...

local DB = {}
T.DB = DB

local defaults = {
    worldPins = true,
    minimapPins = true,
    entrancePin = true,
    autoShow = true,
    hideFound = false,
    hideDoneBountiful = false,
    minimapButton = true,
    elvuiSkin = true,
    announce = true,
    pinScale = 1.0,
    opacity = 0.6,
}

function DB:Initialize()
    TrovekeeperDB = TrovekeeperDB or {}
    local db = TrovekeeperDB

    db.profile = db.profile or {}
    for k, v in pairs(defaults) do
        if db.profile[k] == nil then db.profile[k] = v end
    end

    db.window = db.window or { shown = true }
    db.minimap = db.minimap or {}
    db.delves = db.delves or {}

    db.calls = db.calls or {}
    db.calls.quests = db.calls.quests or {}
end

function DB:Profile() return TrovekeeperDB.profile end
function DB:Window() return TrovekeeperDB.window end
function DB:Minimap() return TrovekeeperDB.minimap end
function DB:Defaults() return defaults end

function DB:Set(key, value)
    TrovekeeperDB.profile[key] = value
    T.Addon:Refresh()
end

-- Per-delve state: the learned uiMapID, coordinate corrections picked up from
-- the game's vignettes, the last achievement count seen, and the found flags.
-- All of it is account-wide, because the achievement is.
function DB:Delve(key)
    local delves = TrovekeeperDB.delves
    local entry = delves[key]
    if not entry then
        entry = { chests = {}, extra = {}, found = {} }
        delves[key] = entry
    end
    entry.chests = entry.chests or {}
    entry.extra = entry.extra or {}
    entry.found = entry.found or {}
    return entry
end

-- The learned Delver's Call quest ids, keyed by delve, plus the localised
-- "Delver's Call" prefix taken off the first title that matched. Account-wide,
-- because the quest ids are the same for every character.
function DB:Calls() return TrovekeeperDB.calls end

function DB:SaveWindowPos(point, relPoint, x, y)
    local w = TrovekeeperDB.window
    w.point, w.relPoint, w.x, w.y = point, relPoint, x, y
end

function DB:ResetLearned()
    TrovekeeperDB.delves = {}
    TrovekeeperDB.calls = { quests = {} }
    T.Addon:Refresh()
end
