local ADDON, T = ...
local L = T.L
local DB = T.DB
local Zones = T.Zones
local Calls = T.Calls
local Bountiful = T.Bountiful

local List = {}
T.List = List

-- The window is two blocks under one title, in this order:
--
--   Bountiful   the delves the game is running bountiful right now
--   Chests      the delve you are standing in - absent when you are not
--
-- Each block is a rule, a heading, and its rows. A block with nothing to say
-- takes no height at all, so the window is only ever as tall as it has
-- something to show, and with neither to show it is a title bar.
--
-- The Delver's Call has no block of its own: Core\Calls.lua still learns the
-- quests, but the only place that shows up is the state on a bountiful row -
-- which is what answers "how many of these have I already run this week".

local WIDTH, PAD = 230, 8
local TITLE_H = 18
local ROW_H = 20          -- a chest row, which carries an icon
local TEXT_ROW_H = 16     -- a text-only row
local HEAD_H = 18         -- a block heading
local RULE_GAP = 9        -- clear space above and below a block's rule
local HEAD_GAP = 7        -- heading to the first row under it
local ZONE_H = 15         -- a zone heading inside a block
local ZONE_GAP = 9        -- above every zone after the first
local INDENT = 12         -- rows sit inside their zone heading
local COLUMN_GAP = 12     -- between a row's name and its right-hand column
local LABEL_RULE_GAP = 6  -- zone heading to the hairline beside it
local MAX_WIDTH = 340     -- names truncate rather than push the window past this

local frame, header, footer
local bountiful, chests

-- Measuring -------------------------------------------------------------------

-- The two columns are measured off the real fonts rather than assumed: the
-- widest delve name and the widest status label are what the blocks need room
-- for, and both change with the client language. Neither can change while the
-- player is logged in, so this runs once and is kept.
local measured

local function columnWidths()
    if measured then return measured.name, measured.status end

    local name = UIParent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    local status = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    name:Hide()
    status:Hide()

    local widestName, widestStatus = 0, 0
    for _, delve in ipairs(T.CallDelves) do
        name:SetText(delve.name)
        widestName = max(widestName, name:GetStringWidth())
    end
    for _, label in ipairs(Calls:Labels()) do
        status:SetText(label)
        widestStatus = max(widestStatus, status:GetStringWidth())
    end

    measured = { name = ceil(widestName), status = ceil(widestStatus) }
    return measured.name, measured.status
end

-- What the window has to be for a two-column block to hold both columns whole.
local function twoColumnWidth()
    local name, status = columnWidths()
    return PAD * 2 + INDENT + name + COLUMN_GAP + status
end

-- Dragging --------------------------------------------------------------------
-- The headings and every row are buttons covering the whole frame, so without
-- forwarding the drag there is nowhere left to grab the window by.

local function beginDrag()
    frame:StartMoving()
end

local function endDrag()
    frame:StopMovingOrSizing()
    List:SavePosition()
end

local function makeDraggable(region)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnDragStart", beginDrag)
    region:SetScript("OnDragStop", endDrag)
end

function List:SavePosition()
    if not frame then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    DB:SaveWindowPos("TOPLEFT", "BOTTOMLEFT", left, top)
end

-- Widgets ---------------------------------------------------------------------

local function addHighlight(region)
    local texture = region:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(1, 1, 1, 0.08)
    texture:Hide()
    return texture
end

-- A zone heading: the name, and a hairline running from the end of it to the
-- right edge. The line separates the groups without spending a row on doing so.
local function makeZoneLine(parent)
    local line = CreateFrame("Frame", nil, parent)
    line:SetHeight(ZONE_H)

    line.label = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line.label:SetPoint("LEFT", 0, 0)
    line.label:SetJustifyH("LEFT")

    line.rule = line:CreateTexture(nil, "ARTWORK")
    line.rule:SetHeight(1)
    line.rule:SetPoint("LEFT", line.label, "RIGHT", LABEL_RULE_GAP, 0)
    line.rule:SetPoint("RIGHT", line, "RIGHT", 0, 0)
    line.rule:SetColorTexture(1, 0.82, 0, 0.20)

    return line
end

-- A text row: a name on the left and a right-hand column, anchored to each
-- other so a name longer than the window can hold is cut off rather than run
-- into its own status.
local function makeTextRow(parent, onClick, onEnter)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(TEXT_ROW_H)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("RIGHT", 0, 0)
    row.status:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", INDENT, 0)
    row.name:SetPoint("RIGHT", row.status, "LEFT", -COLUMN_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.highlight = addHighlight(row)

    row:RegisterForClicks("LeftButtonUp")
    makeDraggable(row)
    row:SetScript("OnClick", function(self)
        if T.Addon:ShiftDown() then
            List:SetShown(false)
            return
        end
        onClick(self)
    end)
    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        onEnter(self)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)

    return row
end

-- A block: a rule, a heading carrying a name and a count, and pools for the
-- zone headings and rows underneath.
local function makeBlock(parent, onClick, onEnter)
    local block = { zoneLines = {}, rows = {} }

    block.rule = parent:CreateTexture(nil, "ARTWORK")
    block.rule:SetHeight(1)
    block.rule:SetColorTexture(1, 1, 1, 0.12)

    local head = CreateFrame("Button", nil, parent)
    head:SetHeight(HEAD_H)
    block.head = head

    head.title = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head.title:SetPoint("LEFT", 0, 0)
    head.title:SetJustifyH("LEFT")

    head.count = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    head.count:SetPoint("RIGHT", 0, 0)
    head.count:SetJustifyH("RIGHT")

    head.title:SetPoint("RIGHT", head.count, "LEFT", -COLUMN_GAP, 0)
    head.title:SetWordWrap(false)

    head.highlight = addHighlight(head)

    head:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    makeDraggable(head)
    head:SetScript("OnClick", function(self, button)
        if T.Addon:ShiftDown() then
            List:SetShown(false)
            return
        end
        onClick(self, button)
    end)
    head:SetScript("OnEnter", function(self)
        self.highlight:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        onEnter(self)
        GameTooltip:AddLine(L["Shift-Click"] .. ": " .. L["Hide the window"], 0.6, 0.8, 1)
        GameTooltip:AddLine(L["Drag"] .. ": " .. L["Move the window"], 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    head:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)

    return block
end

-- Places a block's rule and heading, and answers the offset its rows start at.
local function layoutHead(block, y, title, count, colour)
    block.rule:ClearAllPoints()
    block.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(y + RULE_GAP))
    block.rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(y + RULE_GAP))
    block.rule:Show()
    y = y + RULE_GAP + 1 + RULE_GAP

    block.head:ClearAllPoints()
    block.head:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    block.head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
    block.head.title:SetText(title)
    block.head.count:SetText(count or "")
    if colour then block.head.count:SetTextColor(colour[1], colour[2], colour[3]) end
    block.head:Show()

    return y + HEAD_H
end

local function hideBlock(block)
    block.rule:Hide()
    block.head:Hide()
    for _, line in ipairs(block.zoneLines) do line:Hide() end
    for _, row in ipairs(block.rows) do row:Hide() end
end

local function releaseFrom(block, zones, rows)
    for i = zones + 1, #block.zoneLines do block.zoneLines[i]:Hide() end
    for i = rows + 1, #block.rows do block.rows[i]:Hide() end
end

-- Bountiful block -------------------------------------------------------------

local function bountifulRow(block, index)
    local row = block.rows[index]
    if not row then
        row = makeTextRow(frame,
            -- Ctrl-click hands the quest you are tracking to this delve, which
            -- is /tk setquest without the typing, and the only reason a row ever
            -- learns to say "already run".
            function(self)
                local entry = self.entry
                if not entry then return end
                if T.Addon:ControlDown() then
                    Calls:BindTracked(entry.delve)
                else
                    Bountiful:Waypoint(entry)
                end
            end,
            function(self)
                local entry = self.entry
                if not entry then return end

                GameTooltip:AddLine(entry.name, 1, 0.82, 0)
                GameTooltip:AddLine(self.zoneName, 0.7, 0.7, 0.7)
                GameTooltip:AddLine(entry.description or Bountiful:Label(), 1, 0.5, 0.1)

                local state = entry.delve and Calls:State(entry.delve)
                if state and state ~= Calls.UNKNOWN then
                    GameTooltip:AddLine(L["Delver's Call"] .. ": " .. Calls:Label(state),
                        Calls:Colour(state))
                end
                GameTooltip:AddLine(" ")

                if entry.x then
                    GameTooltip:AddLine(L["Click"] .. ": " .. L["Set a TomTom waypoint"], 0.6, 0.8, 1)
                else
                    GameTooltip:AddLine(L["The map gives no position for this one."], 0.6, 0.8, 1)
                end
                if not (state and state ~= Calls.UNKNOWN) then
                    GameTooltip:AddLine(L["Ctrl-Click"] .. ": " .. L["Bind the quest you are tracking"], 0.6, 0.8, 1)
                end
            end)
        block.rows[index] = row
    end
    return row
end

local function bountifulZone(block, index)
    local line = block.zoneLines[index]
    if not line then
        line = makeZoneLine(frame)
        block.zoneLines[index] = line
    end
    return line
end

-- The delves the game is running bountiful right now, grouped by zone. Gone
-- entirely when the game reports none. The count is what is *left* rather than
-- the total, because "two still to run" is the question the block answers.
local function layoutBountiful(y)
    local left, total = Bountiful:Counts()
    if total == 0 then
        hideBlock(bountiful)
        return y
    end

    -- The game drops a delve from the set once you have run it, so `left` and
    -- `total` are usually the same number and spelling both out reads as noise.
    -- They only differ when a Delver's Call says a listed one is already done.
    local count = (left == total) and tostring(total) or format(L["%d of %d left"], left, total)
    local colour = (left == 0) and { 0.25, 1, 0.25 } or { 1, 0.5, 0.1 }
    y = layoutHead(bountiful, y, L["Bountiful Delves"], count, colour)
    y = y + HEAD_GAP

    local hideDone = DB:Profile().hideDoneBountiful
    local zones, rows = 0, 0

    for _, group in ipairs(Bountiful:Groups()) do
        -- A zone heading only earns its space when something under it is still
        -- on show.
        local visible = {}
        for _, entry in ipairs(group.entries) do
            if not (hideDone and Bountiful:Done(entry)) then
                visible[#visible + 1] = entry
            end
        end

        if #visible > 0 then
            zones = zones + 1
            if zones > 1 then y = y + ZONE_GAP end

            local line = bountifulZone(bountiful, zones)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
            line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
            line.label:SetText(group.name)
            line:Show()
            y = y + ZONE_H

            for _, entry in ipairs(visible) do
                rows = rows + 1
                local row = bountifulRow(bountiful, rows)
                row.entry, row.zoneName = entry, group.name

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
                row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)

                local done = Bountiful:Done(entry)
                row.name:SetText(entry.name)
                row.name:SetTextColor(done and 0.55 or 1, done and 0.55 or 1, done and 0.55 or 1)

                -- The Delver's Call state, but only once it is known: "Not
                -- tracked yet" on every row would be noise, not information.
                local state = entry.delve and Calls:State(entry.delve)
                if state and state ~= Calls.UNKNOWN then
                    row.status:SetText(Calls:Label(state))
                    row.status:SetTextColor(Calls:Colour(state))
                else
                    row.status:SetText("")
                end

                row:Show()
                y = y + TEXT_ROW_H
            end
        end
    end

    releaseFrom(bountiful, zones, rows)
    return y
end

-- Chest block -----------------------------------------------------------------

local function infoText(delve, chest)
    local distance = Zones:Distance(delve, chest)
    if distance then
        return format("|cff9ecfff%.0f %s|r", distance, L["yd"])
    end
    return format("|cff808080%.1f, %.1f|r", chest.x, chest.y)
end

local function chestRow(block, index)
    local row = block.rows[index]
    if row then return row end

    row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_H)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_H - 6, ROW_H - 6)
    row.icon:SetPoint("LEFT", 0, 0)

    row.info = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.info:SetPoint("RIGHT", 0, 0)
    row.info:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT", row.info, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")

    row.highlight = addHighlight(row)

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    makeDraggable(row)

    row:SetScript("OnClick", function(self, button)
        local delve, chest = self.delve, self.chest
        if not delve or not chest then return end
        if T.Addon:ShiftDown() then
            List:SetShown(false)
        elseif button == "RightButton" then
            Zones:SetFound(delve, chest.id, not chest.found)
        else
            T.Waypoint:SetChest(delve, chest)
        end
    end)

    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
        if not self.chest then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.chest.label, 1, 0.82, 0)
        GameTooltip:AddLine(self.delve.name, 0.7, 0.7, 0.7)
        GameTooltip:AddLine(format("%.1f, %.1f", self.chest.x, self.chest.y), 0.6, 0.8, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Click"] .. ": " .. L["Set a TomTom waypoint"], 0.6, 0.8, 1)
        GameTooltip:AddLine(L["Right-Click"] .. ": " .. L["Toggle found"], 0.6, 0.8, 1)
        GameTooltip:AddLine(L["Shift-Click"] .. ": " .. L["Hide the window"], 0.6, 0.8, 1)
        GameTooltip:AddLine(L["Drag"] .. ": " .. L["Move the window"], 0.6, 0.8, 1)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)

    block.rows[index] = row
    return row
end

-- The delve you are standing in, and nothing else. Outside one there is no
-- current delve to track, so the whole block goes.
local function layoutChests(y, delve)
    if not delve then
        hideBlock(chests)
        return y, nil
    end

    local done, total = T.Progress:Counts(delve)
    local colour = (total > 0 and done >= total) and { 0.25, 1, 0.25 } or { 1, 0.82, 0 }
    y = layoutHead(chests, y, delve.name, format(L["%d of %d found"], done, total), colour)
    y = y + HEAD_GAP

    local hideFound = DB:Profile().hideFound
    local rows = 0

    for _, chest in ipairs(Zones:Chests(delve)) do
        if not (hideFound and chest.found) then
            rows = rows + 1
            local row = chestRow(chests, rows)
            row.delve, row.chest = delve, chest

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
            row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)

            if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("VignetteLoot") then
                row.icon:SetAtlas("VignetteLoot", false)
                row.icon:SetTexCoord(0, 1, 0, 1)
            else
                row.icon:SetTexture("Interface\\AddOns\\Trovekeeper\\Media\\Icon.png")
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            row.icon:SetDesaturated(chest.found)

            if chest.found then
                row.name:SetText("|cff707070" .. chest.label .. "|r")
                row:SetAlpha(0.6)
            else
                row.name:SetText(chest.label)
                row:SetAlpha(1)
            end

            row.info:SetText(infoText(delve, chest))
            row:Show()
            y = y + ROW_H
        end
    end

    releaseFrom(chests, 0, rows)

    -- The note only earns its space while the map is still unknown, which is
    -- also the only time the pins have nowhere to go.
    local note
    if not Zones:MapID(delve) then
        note = L["This delve's map is not known yet."] .. " "
            .. format(L["Enter %s once, or use /tk setmap while inside."], delve.name)
    end
    return y, note
end

-- Assembly --------------------------------------------------------------------

function List:Initialize()
    if frame then return end

    frame = CreateFrame("Frame", "TrovekeeperListFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, PAD * 2 + TITLE_H + ROW_H * 3)

    local pos = DB:Window()
    frame:SetPoint(pos.point or "TOPLEFT", UIParent, pos.relPoint or "TOPLEFT",
        pos.x or 24, pos.y or -260)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    makeDraggable(frame)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, DB:Profile().opacity)
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    -- The window's own title. The delve name and its progress sit on the chest
    -- block's heading instead, beside the chests they describe.
    header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", PAD, -PAD)
    header:SetPoint("TOPRIGHT", -PAD, -PAD)
    header:SetHeight(TITLE_H)

    header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.title:SetPoint("LEFT", 0, 0)
    header.title:SetJustifyH("LEFT")
    header.title:SetText(L["Trovekeeper"])

    header.highlight = addHighlight(header)

    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    makeDraggable(header)

    header:SetScript("OnClick", function(_, button)
        if T.Addon:ShiftDown() then
            List:SetShown(false)
        elseif button == "RightButton" then
            T.Options:Toggle()
        else
            local delve = Zones:Current()
            if delve then
                T.Waypoint:SetAll(delve)
            else
                T.Print(L["You are not in a delve."])
            end
        end
    end)
    header:SetScript("OnEnter", function(self)
        self.highlight:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Trovekeeper"], 1, 0.82, 0)
        GameTooltip:AddLine(L["Click"] .. ": " .. L["Waypoint every chest you still need"], 0.6, 0.8, 1)
        GameTooltip:AddLine(L["Right-Click"] .. ": " .. L["Open options"], 0.6, 0.8, 1)
        GameTooltip:AddLine(L["Shift-Click"] .. ": " .. L["Hide the window"], 0.6, 0.8, 1)
        GameTooltip:AddLine(L["Drag"] .. ": " .. L["Move the window"], 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)

    bountiful = makeBlock(frame,
        function()
            Bountiful:Invalidate()
            List:Refresh()
        end,
        function()
            GameTooltip:AddLine(L["Bountiful Delves"], 1, 0.82, 0)
            GameTooltip:AddLine(L["The delves running bountiful right now."], 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Click"] .. ": " .. L["Check again"], 0.6, 0.8, 1)
        end)

    chests = makeBlock(frame,
        function()
            local delve = Zones:Current()
            if delve then T.Waypoint:SetAll(delve) end
        end,
        function()
            local delve = Zones:Current()
            GameTooltip:AddLine(delve and delve.name or L["Trovekeeper"], 1, 0.82, 0)
            GameTooltip:AddLine(L["Sturdy Chest"], 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Click"] .. ": " .. L["Waypoint every chest you still need"], 0.6, 0.8, 1)
        end)

    footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", PAD, PAD)
    footer:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    footer:SetJustifyH("LEFT")
    footer:SetWordWrap(true)

    -- Distances only change while the player moves, so a half-second refresh is
    -- plenty and keeps this off the per-frame path.
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        self.elapsed = self.elapsed + delta
        if self.elapsed < 0.5 then return end
        self.elapsed = 0
        if Zones:Current() then List:UpdateDistances() end
    end)

    self:Refresh()
    self:SetShown(DB:Window().shown)
end

function List:UpdateDistances()
    if not frame or not frame:IsShown() then return end
    for _, row in ipairs(chests.rows) do
        if row:IsShown() and row.delve and row.chest then
            row.info:SetText(infoText(row.delve, row.chest))
        end
    end
end

function List:Refresh()
    if not frame then return end

    -- Once ElvUI has templated the frame, the backdrop is its business.
    if not frame.__elvuiSkinned then
        frame:SetBackdropColor(0, 0, 0, DB:Profile().opacity)
    end

    -- The window stays narrow until the bountiful block is on show; the chest
    -- rows on their own never needed the room.
    local width = WIDTH
    if Bountiful:Count() > 0 then
        width = min(max(WIDTH, twoColumnWidth()), MAX_WIDTH)
    end
    frame:SetWidth(width)

    local y = PAD + TITLE_H
    y = layoutBountiful(y)

    local note
    y, note = layoutChests(y, Zones:Current())

    -- With neither block on show the window would be a bare title bar, which
    -- reads as broken rather than as empty. This says which of the two it is.
    if y == PAD + TITLE_H then
        note = L["No bountiful delves reported. /tk pois shows what the maps hold."]
    end

    local below = 0
    if note then
        footer:SetText("|cffff8040" .. note .. "|r")
        footer:SetWidth(width - PAD * 2)
        footer:Show()
        below = footer:GetStringHeight() + PAD
    else
        footer:SetText("")
        footer:Hide()
    end

    frame:SetHeight(y + PAD + below)
end

function List:SetShown(shown)
    if not frame then return end
    DB:Window().shown = shown and true or false
    frame:SetShown(shown)
    if shown then self:Refresh() end
end

function List:Toggle()
    if not frame then return end
    self:SetShown(not frame:IsShown())
end

function List:IsShown()
    return frame and frame:IsShown()
end

-- Position and visibility are written on every change already; doing it again
-- on logout also captures a window moved by something other than a drag.
T.Addon:Listen("PLAYER_LOGOUT", function()
    if not frame then return end
    List:SavePosition()
    DB:Window().shown = frame:IsShown() and true or false
end)

T.Addon:OnRefresh(function() List:Refresh() end)
