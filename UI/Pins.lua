local ADDON, T = ...
local L = T.L
local DB = T.DB
local Zones = T.Zones

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local Pins = {}
T.Pins = Pins

local CHEST_ATLAS = "VignetteLoot"
local CHEST_ICON = "Interface\\AddOns\\Trovekeeper\\Media\\Icon.png"
local ENTRANCE_ATLAS = "Delves-Regular"
local ENTRANCE_ICON = "Interface\\Icons\\INV_Misc_Cave_01"

local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function applyIcon(texture, atlas, fallback)
    if hasAtlas(atlas) then
        texture:SetAtlas(atlas, false)
    else
        texture:SetTexture(fallback)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local function tooltipFor(owner, delve, chest, entrance)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if entrance then
        GameTooltip:AddLine(delve.name, 1, 0.82, 0)
        GameTooltip:AddLine(L["Delve entrance"], 1, 1, 1)
    else
        GameTooltip:AddLine(chest.label, 1, 0.82, 0)
        GameTooltip:AddLine(delve.name, 0.7, 0.7, 0.7)
        if chest.found then
            GameTooltip:AddLine(L["Found"], 0.4, 1, 0.4)
        else
            GameTooltip:AddLine(L["Not found yet"], 1, 0.6, 0.2)
        end
        local distance = Zones:Distance(delve, chest)
        if distance then
            GameTooltip:AddLine(format("%.0f %s", distance, L["yd"]), 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:AddLine(format("%.1f, %.1f", chest and chest.x or delve.entrance.x,
        chest and chest.y or delve.entrance.y), 0.6, 0.8, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Click"] .. ": " .. L["Set a TomTom waypoint"], 0.6, 0.8, 1)
    if not entrance then
        GameTooltip:AddLine(L["Right-Click"] .. ": " .. L["Toggle found"], 0.6, 0.8, 1)
    end
    GameTooltip:Show()
end

-- Mixin used by the XML pin template. It has to be global for the template to
-- find it.
TrovekeeperMapPinMixin = {}

-- The canvas asserts on a pin whose frame level type it does not know, so the
-- pin has to claim a registered one before it is ever placed. Called by
-- AcquirePin the first time each pin is created.
function TrovekeeperMapPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    -- Equal start and end scale keeps the pin the same size at every zoom
    -- level instead of growing with the canvas.
    self:SetScalingLimits(1, 1.0, 1.0)
end

function TrovekeeperMapPinMixin:OnAcquired(delve, chest, entrance)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self.delve, self.chest, self.entrance = delve, chest, entrance

    local scale = DB:Profile().pinScale or 1
    self:SetSize(18 * scale, 18 * scale)

    if entrance then
        applyIcon(self.icon, ENTRANCE_ATLAS, ENTRANCE_ICON)
        self.icon:SetDesaturated(false)
        self:SetAlpha(1)
        self.number:SetText("")
        self:SetPosition(delve.entrance.x / 100, delve.entrance.y / 100)
    else
        applyIcon(self.icon, CHEST_ATLAS, CHEST_ICON)
        self.icon:SetDesaturated(chest.found)
        self:SetAlpha(chest.found and 0.45 or 1)
        self.number:SetText(chest.number)
        self:SetPosition(chest.x / 100, chest.y / 100)
    end

    self:Show()
end

function TrovekeeperMapPinMixin:OnReleased()
    self.delve, self.chest, self.entrance = nil, nil, nil
end

-- The canvas installs its own OnEnter/OnLeave and dispatches to these.
function TrovekeeperMapPinMixin:OnMouseEnter()
    tooltipFor(self, self.delve, self.chest, self.entrance)
end

function TrovekeeperMapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

-- Pins hand right clicks to the map by default, so it can zoom out. We want the
-- right click ourselves, for the found toggle.
function TrovekeeperMapPinMixin:ShouldMouseButtonBePassthrough(button)
    return false
end

-- The hook MapCanvasPinMixin:OnClick calls, rather than OnClick itself, so the
-- canvas keeps its own global click handling.
function TrovekeeperMapPinMixin:OnMouseClickAction(button)
    if self.entrance then
        T.Waypoint:SetEntrance(self.delve)
    elseif button == "RightButton" then
        Zones:SetFound(self.delve, self.chest.id, not self.chest.found)
    else
        T.Waypoint:SetChest(self.delve, self.chest)
    end
end

-- World map -----------------------------------------------------------------

local Provider = CreateFromMixins(MapCanvasDataProviderMixin)

function Provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate("TrovekeeperMapPinTemplate")
end

function Provider:RefreshAllData()
    self:RemoveAllData()

    local map = self:GetMap()
    local uiMapID = map:GetMapID()
    if not uiMapID then return end

    local profile = DB:Profile()

    if profile.worldPins then
        local delve = Zones:DelveForMap(uiMapID)
        if delve then
            for _, chest in ipairs(Zones:Chests(delve)) do
                if not (profile.hideFound and chest.found) then
                    map:AcquirePin("TrovekeeperMapPinTemplate", delve, chest, false)
                end
            end
        end
    end

    if profile.entrancePin then
        local delve = Zones:DelveWithEntranceOn(uiMapID)
        if delve then
            local done, total = T.Progress:Counts(delve)
            if not (profile.hideFound and total > 0 and done >= total) then
                map:AcquirePin("TrovekeeperMapPinTemplate", delve, nil, true)
            end
        end
    end
end

-- Minimap -------------------------------------------------------------------
-- HereBeDragons routes minimap pins through world coordinates. Instance maps do
-- not always expose those, in which case AddMinimapIconMap simply drops the
-- pin; the world map pins and the TomTom waypoints are unaffected.

local minimapPins = {}
local minimapPool

local function releaseMinimapPins()
    HBDPins:RemoveAllMinimapIcons(Pins)
    for _, pin in ipairs(minimapPins) do
        pin:Hide()
        pin.delve, pin.chest = nil, nil
    end
    wipe(minimapPins)
end

local function acquireMinimapPin(index)
    if not minimapPool then minimapPool = {} end
    local pin = minimapPool[index]
    if not pin then
        pin = CreateFrame("Button", nil, Minimap)
        pin:SetSize(14, 14)
        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetAllPoints()
        pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        pin:SetScript("OnEnter", function(self) tooltipFor(self, self.delve, self.chest, false) end)
        pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pin:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                Zones:SetFound(self.delve, self.chest.id, not self.chest.found)
            else
                T.Waypoint:SetChest(self.delve, self.chest)
            end
        end)
        minimapPool[index] = pin
    end
    return pin
end

function Pins:RefreshMinimap()
    releaseMinimapPins()

    local profile = DB:Profile()
    if not profile.minimapPins then return end

    local delve, uiMapID = Zones:Current()
    if not delve then return end

    local scale = profile.pinScale or 1
    for _, chest in ipairs(Zones:Chests(delve)) do
        if not (profile.hideFound and chest.found) then
            local index = #minimapPins + 1
            local pin = acquireMinimapPin(index)
            pin.delve, pin.chest = delve, chest
            pin:SetSize(14 * scale, 14 * scale)
            applyIcon(pin.icon, CHEST_ATLAS, CHEST_ICON)
            pin.icon:SetDesaturated(chest.found)
            pin:SetAlpha(chest.found and 0.45 or 1)
            pin:Show()
            minimapPins[index] = pin

            local x, y = T.ToFraction(chest.x, chest.y)
            HBDPins:AddMinimapIconMap(Pins, pin, uiMapID, x, y, true, true)
        end
    end
end

-- Reports whether the current delve map exposes the world coordinates that
-- minimap pins need. Used by /tk diag, so a missing pin has an answer instead
-- of a guess.
function Pins:MinimapPossible()
    local delve, uiMapID = Zones:Current()
    if not delve then return nil end
    local x, y = HBD:GetWorldCoordinatesFromZone(0.5, 0.5, uiMapID)
    return x ~= nil, uiMapID
end

function Pins:Initialize()
    WorldMapFrame:AddDataProvider(Provider)
    self:RefreshMinimap()
end

T.Addon:OnRefresh(function()
    -- Only our own provider runs, rather than every provider on the canvas.
    if Provider.GetMap and Provider:GetMap() then
        Provider:RefreshAllData()
    end
    Pins:RefreshMinimap()
end)
