local ADDON, T = ...
local L = T.L
local DB = T.DB
local Zones = T.Zones

local Calls = {}
T.Calls = Calls

-- Every delve hands out one repeatable quest, "Delver's Call: <delve>". Its
-- quest ids are not shipped, for the same reason the interior map ids are not:
-- nothing publishes them, and a wrong id would report the wrong delve as done.
-- So they are learned, in three widening steps.
--
--   1. By title. A "<prefix>: <delve>" quest whose part after the colon matches
--      a delve's pattern is that delve's call. The prefix is remembered the
--      first time this fires, which is what makes step 2 possible.
--   2. By place. Once the prefix is known, any quest carrying it that is
--      accepted or handed in while the player stands inside a known delve
--      belongs to that delve - no name matching involved, so it holds up in
--      every client language.
--   3. By hand. /tk setquest binds the tracked quest to the delve the list is
--      showing, and teaches the prefix outright. One use is enough to unlock
--      step 2 on a client whose language step 1 cannot read.
--
-- Step 1 alone covers an English client. It also covers the proper nouns -
-- Gnarldor, Atal'Aman, Kriegval, Tak-Rethan - which survive translation.

-- What a delve's call is doing right now. Ordered from "nothing known" to
-- "finished", which is also the order the list colours them in.
Calls.UNKNOWN = "unknown"   -- no quest id learned for this delve yet
Calls.OPEN    = "open"      -- known, not picked up, not completed
Calls.ACTIVE  = "active"    -- in the quest log, objectives outstanding
Calls.TURNIN  = "turnin"    -- in the quest log, ready to hand in
Calls.DONE    = "done"      -- completed

-- Learned state ---------------------------------------------------------------

function Calls:QuestID(delve)
    return DB:Calls().quests[delve.key]
end

function Calls:Prefix()
    return DB:Calls().prefix
end

function Calls:Bind(delve, questID, prefix)
    if not delve or not questID or questID == 0 then return false end

    local calls = DB:Calls()
    if prefix and prefix ~= "" then calls.prefix = prefix end
    if calls.quests[delve.key] == questID then return false end

    calls.quests[delve.key] = questID
    T.Print(L["Learned the Delver's Call for %s (quest %d)."], delve.name, questID)
    T.Addon:Refresh()
    return true
end

-- Learning --------------------------------------------------------------------

-- "Delver's Call: Kriegval's Rest" splits on its first colon. Delve names carry
-- none, so the first colon is always the right one, in every language that
-- keeps the pattern at all.
local function split(title)
    if not title or title == "" then return nil end
    local prefix, name = strmatch(title, "^(.-)%s*:%s*(.+)$")
    if not prefix or prefix == "" or not name or name == "" then return nil end
    return prefix, name
end

local function carriesPrefix(prefix)
    local known = Calls:Prefix()
    return known ~= nil and strlower(prefix) == strlower(known)
end

local function delveForName(name)
    name = strlower(name)
    for _, delve in ipairs(T.CallDelves) do
        local pattern = delve.questPattern or delve.mapNamePattern
        if pattern and strfind(name, pattern, 1, true) then return delve end
    end
    return nil
end

-- One quest, offered to all three steps in turn. Silent about anything that is
-- not shaped like a call - the quest log is full of other things.
function Calls:Learn(questID, title)
    if not questID or questID == 0 then return false end
    if self:BoundTo(questID) then return false end

    title = title or C_QuestLog.GetTitleForQuestID(questID)
    local prefix, name = split(title)
    if not prefix then return false end

    -- Once the prefix is known it is required, so a "Chapter One: The Sinkhole"
    -- cannot be taken for a call. Until then the name match stands on its own.
    if self:Prefix() and not carriesPrefix(prefix) then return false end

    local delve = delveForName(name)
    if delve then return self:Bind(delve, questID, prefix) end

    -- Only with the prefix confirmed, or every quest picked up inside a delve
    -- would be taken for its call. And only for a delve that has none yet: a
    -- quest board offering somebody else's call would otherwise overwrite the
    -- one this delve is actually known by.
    if not carriesPrefix(prefix) then return false end
    local here = Zones:Current()
    if not here or self:QuestID(here) then return false end
    return self:Bind(here, questID)
end

-- A quest id already spoken for. Rebinding it to a second delve would silently
-- mark the first one done for the rest of the session.
function Calls:BoundTo(questID)
    for key, id in pairs(DB:Calls().quests) do
        if id == questID then return T.CallDelveByKey[key] end
    end
    return nil
end

function Calls:Scan()
    if not C_QuestLog.GetNumQuestLogEntries then return end

    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            self:Learn(info.questID, info.title)
        end
    end
end

-- The delve a typed fragment means: "earthcrawl", "Kriegval's Rest", the key
-- itself. Same matcher the titles go through, so whatever works there works
-- here.
function Calls:Resolve(fragment)
    if not fragment or fragment == "" then return nil end
    return T.CallDelveByKey[fragment] or delveForName(fragment)
end

-- Binds whatever the player is tracking to a delve, and takes the localised
-- prefix off its title while it is at it. That prefix is the whole point: one
-- use teaches every other call on a client whose language the shipped names
-- cannot match.
function Calls:BindTracked(delve, questID)
    if not delve then
        T.Print(L["Name the delve: /tk setquest <delve> [<quest id>]."])
        return false
    end

    questID = questID or (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID())
    if not questID or questID == 0 then
        T.Print(L["Track a Delver's Call quest first, or pass its id: /tk setquest <delve> <id>."])
        return false
    end

    local title = C_QuestLog.GetTitleForQuestID(questID)
    if not title or title == "" then
        T.Print(L["Quest %d is not in your log."], questID)
        return false
    end

    local prefix = split(title)
    if not prefix then
        T.Print(L["%s does not look like a Delver's Call."], title)
        return false
    end

    return self:Bind(delve, questID, prefix)
end

-- Status ----------------------------------------------------------------------

function Calls:State(delve)
    local questID = self:QuestID(delve)
    if not questID then return self.UNKNOWN end

    if C_QuestLog.IsQuestFlaggedCompleted(questID) then return self.DONE end
    if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) then
        if C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID) then return self.TURNIN end
        return self.ACTIVE
    end
    return self.OPEN
end

local LABELS = {
    unknown = "Not tracked yet",
    open    = "Not completed",
    active  = "In progress",
    turnin  = "Ready to hand in",
    done    = "Completed",
}

-- Grey, red, blue, gold, green. The blue and the gold are the ones the chest
-- rows already use for distances and for progress.
local COLOURS = {
    unknown = { 0.50, 0.50, 0.50 },
    open    = { 1.00, 0.25, 0.25 },
    active  = { 0.62, 0.81, 1.00 },
    turnin  = { 1.00, 0.82, 0.00 },
    done    = { 0.25, 1.00, 0.25 },
}

function Calls:Label(state)
    return L[LABELS[state] or LABELS.unknown]
end

function Calls:Colour(state)
    local colour = COLOURS[state] or COLOURS.unknown
    return colour[1], colour[2], colour[3]
end

-- Every label, so the list can measure the widest one and size its status
-- column to it instead of guessing at a width that a translation then breaks.
function Calls:Labels()
    local out = {}
    for _, key in ipairs({ "unknown", "open", "active", "turnin", "done" }) do
        out[#out + 1] = L[LABELS[key]]
    end
    return out
end

function Calls:Counts()
    local done = 0
    for _, delve in ipairs(T.CallDelves) do
        if self:State(delve) == self.DONE then done = done + 1 end
    end
    return done, #T.CallDelves
end

-- Grouping --------------------------------------------------------------------

local groups

-- Zone names come from the game so they translate; T.ZoneNames is the fallback
-- for a map id the client does not know. Built once - neither the grouping nor
-- the names change while the player is logged in.
function Calls:Groups()
    if groups then return groups end

    local byZone = {}
    for _, delve in ipairs(T.CallDelves) do
        local zone = delve.zone
        if zone then
            byZone[zone] = byZone[zone] or {}
            local list = byZone[zone]
            list[#list + 1] = delve
        end
    end

    groups = {}
    for _, zone in ipairs(T.ZoneOrder) do
        local delves = byZone[zone]
        if delves then
            local info = C_Map.GetMapInfo(zone)
            groups[#groups + 1] = {
                uiMapID = zone,
                name = (info and info.name) or T.ZoneNames[zone] or tostring(zone),
                delves = delves,
            }
        end
    end
    return groups
end

-- Events ----------------------------------------------------------------------

-- QUEST_LOG_UPDATE fires in bursts, several times per accepted quest and again
-- on every objective step. One scan a second after the burst starts is plenty.
local pending

local function scanSoon()
    if pending or not T.Addon.loaded then return end
    pending = true
    C_Timer.After(1, function()
        pending = false
        Calls:Scan()
        T.Addon:Refresh()
    end)
end

T.Addon:Listen("QUEST_LOG_UPDATE", scanSoon)
T.Addon:Listen("QUEST_REMOVED", scanSoon)

T.Addon:Listen("QUEST_ACCEPTED", function(questID)
    Calls:Learn(questID)
    T.Addon:Refresh()
end)

T.Addon:Listen("QUEST_TURNED_IN", function(questID)
    Calls:Learn(questID)
    T.Addon:Refresh()
end)

-- The quest giver's window names the quest before it is in the log at all,
-- which is the earliest a call can possibly be learned.
T.Addon:Listen("QUEST_DETAIL", function()
    if not GetQuestID then return end
    Calls:Learn(GetQuestID(), GetTitleText and GetTitleText() or nil)
    T.Addon:Refresh()
end)
