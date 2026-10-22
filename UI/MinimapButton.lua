local _, LB = ...

-- Round button on the minimap edge: left click opens the book, right click one
-- more page window; drag moves it around the minimap. Place and visibility live in
-- settings.minimap = { angle, hidden }.
local MinimapButton = {}
LB.MinimapButton = MinimapButton

local L = LB.L

MinimapButton.ICON = "Interface\\Icons\\Ability_Hunter_Pet_Boar"
MinimapButton.DEFAULT_ANGLE = 200
-- Distance from the minimap centre beyond its radius.
local EDGE = 10

-- Offset from the minimap centre for an angle in degrees. Pure.
function MinimapButton.Offset(angle, radius)
    local radians = math.rad(angle)
    return math.cos(radians) * radius, math.sin(radians) * radius
end

-- Angle in degrees (0-360) of a point relative to the minimap centre. Pure.
function MinimapButton.Angle(dx, dy)
    return math.deg(math.atan2(dy, dx)) % 360
end

local function settings()
    local account = LB.store.account
    account.settings.minimap = account.settings.minimap or {}
    return account.settings.minimap
end

local function writable()
    return LB.store and not LB.store.readOnly
end

local function parent()
    return Minimap or UIParent
end

local function place(button)
    local angle = settings().angle or MinimapButton.DEFAULT_ANGLE
    local x, y = MinimapButton.Offset(angle, parent():GetWidth() / 2 + EDGE)
    button:ClearAllPoints()
    button:SetPoint("CENTER", parent(), "CENTER", x, y)
end

local function followCursor(button)
    local map = parent()
    local scale = map:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local centerX, centerY = map:GetCenter()
    local angle = MinimapButton.Angle(cursorX / scale - centerX, cursorY / scale - centerY)
    if writable() then settings().angle = angle end
    place(button)
end

local function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(LB.BookApp.Title())
    GameTooltip:AddLine(L("MINIMAP_LEFT_CLICK"), 1, 1, 1)
    GameTooltip:AddLine(L("MINIMAP_RIGHT_CLICK"), 1, 1, 1)
    GameTooltip:AddLine(L("MINIMAP_DRAG"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function create()
    local button = CreateFrame("Button", LB.GlobalName("MinimapButton"), parent())
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetSize(20, 20)
    button.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(18, 18)
    button.icon:SetTexture(MinimapButton.ICON)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetSize(53, 53)
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            LB.BookApp.OpenWindow()
        else
            LB.BookApp.ToggleReader()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", followCursor)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function MinimapButton.Init()
    MinimapButton.button = MinimapButton.button or create()
    place(MinimapButton.button)
    MinimapButton.button:SetShown(not settings().hidden)
end

-- /<slash> minimap: hides or shows the button.
function MinimapButton.Toggle()
    local hidden = not settings().hidden
    if writable() then settings().hidden = hidden end
    MinimapButton.button:SetShown(not hidden)
    LB.Commands.Print(L(hidden and "MINIMAP_HIDDEN" or "MINIMAP_SHOWN"))
end
