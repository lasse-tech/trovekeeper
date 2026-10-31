local ADDON, T = ...
local L = T.L
local DB = T.DB

local Options = {}
T.Options = Options

local category, layout

-- Blizzard's SettingsListMixin lays the list out with a ScrollBox: an element's
-- height is initializer:GetExtent(), or the template's own height when that is
-- nil. We measure the text and report its exact height.
local NOTES_TEMPLATE = "TrovekeeperNotesTemplate"
local NOTES_FONT = "GameFontHighlight"
local NOTES_BOTTOM_PAD = 8

TrovekeeperNotesMixin = {}

function TrovekeeperNotesMixin:Init(initializer)
    self.Text:SetText(initializer:GetData().text)
end

local function metadata(field)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local value = get and get(ADDON, field)
    if value == "" then return nil end
    return value
end

-- Kept in the TOC rather than here, so the TOC stays the single source for
-- author and version.
local function notesText()
    local lines = {}

    local author = metadata("Author")
    if author then lines[#lines + 1] = L["Author: %s"]:format(author) end

    local website = metadata("X-Website")
    if website then lines[#lines + 1] = L["More: %s"]:format((website:gsub("^%a+://", ""))) end

    local version = metadata("Version")
    if version then lines[#lines + 1] = L["Version: %s"]:format(version) end

    return table.concat(lines, "\n")
end

local measure

local function textHeight(text)
    if not measure then
        measure = UIParent:CreateFontString(nil, "ARTWORK", NOTES_FONT)
        measure:SetJustifyH("LEFT")
        measure:Hide()
    end
    measure:SetText(text)
    return measure:GetStringHeight()
end

local function addNotes(text)
    if not Settings.CreateElementInitializer then return end
    if not text or text == "" then return end

    local initializer = Settings.CreateElementInitializer(NOTES_TEMPLATE, { text = text })
    local extent = math.ceil(textHeight(text)) + NOTES_BOTTOM_PAD
    initializer.GetExtent = function() return extent end
    layout:AddInitializer(initializer)
end

local function refresh()
    T.Addon:Refresh()
end

local function profileSetting(key, variableType, name)
    return Settings.RegisterAddOnSetting(category, ADDON .. "_" .. key, key,
        DB:Profile(), variableType, name, DB:Defaults()[key])
end

local function checkbox(key, name, tooltip)
    local setting = profileSetting(key, Settings.VarType.Boolean, name)
    setting:SetValueChangedCallback(refresh)
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function slider(key, name, minValue, maxValue, step, formatter, tooltip)
    local setting = profileSetting(key, Settings.VarType.Number, name)
    setting:SetValueChangedCallback(refresh)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
    Settings.CreateSlider(category, setting, options, tooltip)
end

function Options:Initialize()
    if category then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

    category, layout = Settings.RegisterVerticalLayoutCategory(L["Trovekeeper"])

    addNotes(notesText())

    checkbox("worldPins", L["Show world map pins"])
    checkbox("minimapPins", L["Show minimap pins"],
        L["Needs world coordinates, which not every delve map provides. /tk diag reports whether they work here."])
    checkbox("entrancePin", L["Show the delve entrance on the zone map"])
    checkbox("autoShow", L["Show the list automatically inside a delve"])
    checkbox("hideFound", L["Hide chests already found"])
    checkbox("hideDoneBountiful", L["Hide bountiful delves already run"])
    checkbox("announce", L["Announce found chests in chat"])

    slider("pinScale", L["Pin scale"], 0.5, 2.0, 0.1,
        function(value) return format("%.1fx", value) end)
    slider("opacity", L["Window opacity"], 0.0, 1.0, 0.05,
        function(value) return format("%d%%", value * 100 + 0.5) end)

    -- The minimap button belongs to LibDBIcon, which keeps its own hidden flag,
    -- so this one pushes the change instead of living in the profile alone.
    do
        local proxy = { minimapButton = DB:Profile().minimapButton }
        local setting = Settings.RegisterAddOnSetting(category, ADDON .. "_minimapButton",
            "minimapButton", proxy, Settings.VarType.Boolean, L["Show minimap button"],
            DB:Defaults().minimapButton)
        setting:SetValueChangedCallback(function(_, value)
            DB:Profile().minimapButton = value
            DB:Minimap().hide = not value
            local icon = LibStub("LibDBIcon-1.0", true)
            if not icon or not icon:IsRegistered(ADDON) then return end
            if value then icon:Show(ADDON) else icon:Hide(ADDON) end
        end)
        Settings.CreateCheckbox(category, setting)
    end

    checkbox("elvuiSkin", L["Allow ElvUI to skin this addon"],
        L["Requires a /reload to take effect."])

    Settings.RegisterAddOnCategory(category)
end

function Options:Toggle()
    if not category then self:Initialize() end
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    end
end
