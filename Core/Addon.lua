local ADDON, T = ...
local L = T.L

T.ADDON = ADDON
T.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "0"

local Addon = CreateFrame("Frame")
T.Addon = Addon

Addon.handlers = {}
Addon.refreshers = {}

-- Modules register interest per event; the frame only listens to what somebody
-- actually asked for.
function Addon:Listen(event, fn)
    local list = self.handlers[event]
    if not list then
        list = {}
        self.handlers[event] = list
        self:RegisterEvent(event)
    end
    list[#list + 1] = fn
end

-- Anything that draws chests registers here, so a single Refresh() call keeps
-- the list, the map pins and the minimap pins in step.
function Addon:OnRefresh(fn)
    self.refreshers[#self.refreshers + 1] = fn
end

function Addon:Refresh()
    if not self.loaded then return end
    for _, fn in ipairs(self.refreshers) do
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
end

Addon:SetScript("OnEvent", function(self, event, ...)
    local list = self.handlers[event]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then geterrorhandler()(err) end
    end
end)

-- The client does not hand the keyboard state to a freshly loaded UI, so right
-- after /reload IsShiftKeyDown() answers "not held" while the key is down: the
-- first Shift- or Ctrl-click falls through every branch and looks dead, the
-- second works because the key has been pressed again by then.
-- MODIFIER_STATE_CHANGED does arrive, so the keys are tracked here too.
local held = {}

Addon:Listen("MODIFIER_STATE_CHANGED", function(key, down)
    if type(key) ~= "string" then return end
    held[key] = down == 1
end)

-- The API answers first: when it says the key is down, it is. Only its "no" is
-- worth doubting, and then the tracked state fills in, so a release the client
-- swallowed cannot leave a key stuck as pressed.
local function anyHeld(left, right, api)
    if api and api() then return true end
    return held[left] == true or held[right] == true
end

function Addon:ShiftDown()
    return anyHeld("LSHIFT", "RSHIFT", IsShiftKeyDown)
end

function Addon:ControlDown()
    return anyHeld("LCTRL", "RCTRL", IsControlKeyDown)
end

function T.Print(msg, ...)
    if select("#", ...) > 0 then msg = format(msg, ...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. L["Trovekeeper"] .. "|r: " .. tostring(msg))
end

-- Coordinates travel as percentages in the data tables and as 0-1 fractions in
-- every API call; these two are the only place that conversion happens.
function T.ToFraction(x, y) return x / 100, y / 100 end
function T.ToPercent(x, y) return x * 100, y * 100 end
