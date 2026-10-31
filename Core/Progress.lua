local ADDON, T = ...
local L = T.L
local DB = T.DB
local Zones = T.Zones

local Progress = {}
T.Progress = Progress

-- How close the player must be to a chest for a step in the counter to be
-- attributed to it. Looting happens at melee range; 40 yards is generous
-- without reaching the next chest, which are hundreds of yards apart.
local ATTRIBUTION_RANGE = 40

-- The same question in map percentage points, for delve maps that expose no
-- world coordinates and therefore no yard distance at all. The chests are at
-- least 25 points apart, so 10 cannot pick the wrong one.
local ATTRIBUTION_RANGE_ON_MAP = 10

-- "Find and open all Sturdy Chests" is a progress-bar achievement: one single
-- counting criterion that the achievement UI draws as a bar, whose `completed`
-- only turns true at the very end. Reading the criterion count as a chest count
-- would say "1", and reading `completed` as progress would say "0" until the
-- last chest. The count lives in quantity/reqQuantity instead.
--
-- Delves with one criterion per chest are handled too, by counting the
-- completed ones, so a future delve of either shape works.
local function readProgress(delve)
    local id = delve.achievementID
    if not id then return nil end

    local count = GetAchievementNumCriteria(id)
    if not count or count == 0 then return nil end

    if count == 1 then
        local _, _, completed, quantity, reqQuantity = GetAchievementCriteriaInfo(id, 1)
        if reqQuantity and reqQuantity > 1 then
            return quantity or 0, reqQuantity
        end
        return completed and 1 or 0, 1
    end

    local done = 0
    for i = 1, count do
        local _, _, completed = GetAchievementCriteriaInfo(id, i)
        if completed then done = done + 1 end
    end
    return done, count
end

-- Progress straight from the achievement, which is the number the achievement
-- UI shows. Falls back to the addon's own found flags when it cannot be read.
function Progress:Counts(delve)
    local done, total = readProgress(delve)
    if done then return done, total end

    local chests, found = Zones:Chests(delve), 0
    for _, chest in ipairs(chests) do
        if chest.found then found = found + 1 end
    end
    return found, #chests
end

-- Yards where the map provides them, map coordinates otherwise. Without the
-- fallback a delve map with no world rectangle can never attribute a step, and
-- no chest is ever marked found.
local function nearestChest(delve)
    local best, bestDistance
    for _, chest in ipairs(Zones:Chests(delve)) do
        if not chest.extra then
            local distance, limit = Zones:Distance(delve, chest), ATTRIBUTION_RANGE
            if not distance then
                distance, limit = Zones:MapDistance(delve, chest), ATTRIBUTION_RANGE_ON_MAP
            end
            if distance and distance <= limit and (not bestDistance or distance < bestDistance) then
                best, bestDistance = chest, distance
            end
        end
    end
    return best
end

local function markAll(delve, state)
    local changed = false
    for _, chest in ipairs(Zones:Chests(delve)) do
        if not chest.extra and not state.found[chest.id] then
            state.found[chest.id] = true
            changed = true
        end
    end
    return changed
end

-- The counter is the only thing the achievement tells us; which chest it was is
-- ours to work out. A step that happens while the player stands next to a chest
-- belongs to that chest.
function Progress:Sync(announce)
    if not T.Addon.loaded then return false end

    local changed = false

    for _, delve in ipairs(T.Delves) do
        local done, total = readProgress(delve)
        if done then
            local state = DB:Delve(delve.key)
            local previous = state.quantity
            state.quantity = done

            if total > 0 and done >= total then
                -- All of them, wherever the player happens to be standing.
                changed = markAll(delve, state) or changed
            elseif previous ~= nil and done > previous then
                local chest = nearestChest(delve)
                if chest and not state.found[chest.id] then
                    state.found[chest.id] = true
                    changed = true
                    if announce and DB:Profile().announce then
                        T.Print(L["Chest found: %s"], chest.label)
                    end
                end
            end
            -- previous == nil is the first look at this delve: adopt the count
            -- without attributing anything, because there is no way to know
            -- where those chests were opened.
        end
    end

    if changed then T.Addon:Refresh() end
    return changed
end

T.Addon:Listen("CRITERIA_UPDATE", function() Progress:Sync(true) end)
T.Addon:Listen("ACHIEVEMENT_EARNED", function() Progress:Sync(true) end)
