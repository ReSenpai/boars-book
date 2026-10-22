local _, LB = ...

-- Shared window and control builders for Lore Book frames.
local Widgets = {}
LB.Widgets = Widgets

local Theme = LB.Theme

function Widgets.SetColor(texture, color, alpha)
    texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
end

-- A parchment (Theme.PARCHMENTS entry; the menu window parchment by default).
function Widgets.ApplyParchment(texture, parchment)
    parchment = parchment or Theme.PARCHMENTS[Theme.WINDOW_PARCHMENT]
    texture:SetTexture(parchment.texture)
    texture:SetTexCoord(unpack(parchment.coords))
    texture:SetVertexColor(1, 1, 1, 1)
end

function Widgets.SetTextColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3], 1)
end

local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"

-- A template part if the client has it (real frames return nil for missing keys).
local function part(object, key)
    local value = object and object[key]
    if type(value) == "table" then return value end
end

local function makeMovable(frame, options)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if options.onMoved then options.onMoved() end
    end)
end

-- Menu window in the game's own style (ButtonFrameTemplate: portrait, title bar,
-- dark inset), with parchment inside the inset. Content starts below
-- Widgets.PANEL_TOP; buttons go below Widgets.PANEL_BOTTOM.
Widgets.PANEL_TOP, Widgets.PANEL_BOTTOM = 60, 44

local function createPanelWindow(name, width, height, options)
    local frame = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
    frame:SetSize(width, height)
    makeMovable(frame, options)

    local title = part(frame, "TitleText") or part(part(frame, "TitleContainer"), "TitleText")
    if not title then
        title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", frame, "TOP", 0, -5)
    end
    frame.title = title
    local close = part(frame, "CloseButton")
    if not close then
        close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4)
    end
    frame.close = close
    local portrait = part(frame, "portrait") or part(part(frame, "PortraitContainer"), "portrait")
    if portrait then
        if SetPortraitToTexture then
            SetPortraitToTexture(portrait, options.icon or BOOK_ICON)
        else
            portrait:SetTexture(options.icon or BOOK_ICON)
        end
    end

    local inset = part(frame, "Inset") or CreateFrame("Frame", nil, frame)
    frame.inset = inset
    frame.inset:ClearAllPoints()
    frame.inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -Widgets.PANEL_TOP)
    frame.inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, Widgets.PANEL_BOTTOM)
    frame.parchment = frame.inset:CreateTexture(nil, "BACKGROUND", nil, 2)
    frame.parchment:SetPoint("TOPLEFT", frame.inset, "TOPLEFT", 3, -3)
    frame.parchment:SetPoint("BOTTOMRIGHT", frame.inset, "BOTTOMRIGHT", -3, 3)
    Widgets.ApplyParchment(frame.parchment)

    tinsert(UISpecialFrames, name)
    frame:Hide()
    return frame
end

-- Movable, Escape-closable window in the game's panel style (see above).
function Widgets.CreateWindow(name, width, height, options)
    return createPanelWindow(name, width, height, options or {})
end

function Widgets.Button(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 26)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

-- Square icon button with a tooltip; `tooltip` is a function so the text follows the locale.
function Widgets.IconButton(parent, icon, size, tooltip, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button:SetNormalTexture(icon)
    button:SetPushedTexture(icon)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button.icon = icon
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(tooltip())
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

-- Plain clickable text row with highlight and a left-aligned label.
function Widgets.TextRow(parent, fontObject, onClick)
    local row = CreateFrame("Button", nil, parent)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints(row)
    Widgets.SetColor(row.selected, Theme.colors.selected, 0.6)
    row.selected:Hide()
    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetFontObject(fontObject)
    row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row:SetScript("OnClick", onClick)
    return row
end

-- Single-line text input with an optional placeholder, shown while the box is
-- empty and unfocused. Consumers extend OnTextChanged with HookScript.
function Widgets.EditBox(parent, width, placeholder)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 22)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box.placeholder = box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    box.placeholder:SetPoint("LEFT", box, "LEFT", 2, 0)
    box.placeholder:SetText(placeholder or "")
    function box.UpdatePlaceholder()
        box.placeholder:SetShown(placeholder ~= nil and (box:GetText() or "") == "" and not box:HasFocus())
    end
    box:SetScript("OnTextChanged", box.UpdatePlaceholder)
    box:SetScript("OnEditFocusGained", box.UpdatePlaceholder)
    box:SetScript("OnEditFocusLost", box.UpdatePlaceholder)
    box.UpdatePlaceholder()
    return box
end
