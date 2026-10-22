local _, LB = ...

-- Achievement toast on the book's parchment: slides in at the top of the screen,
-- stays a few seconds (longer while the mouse is over it) and fades out. Several
-- discoveries in a row queue up. Click: a found NPC opens its page, a meta
-- achievement opens the journal.
local DiscoveryToast = {}
LB.DiscoveryToast = DiscoveryToast

local L = LB.L
local Escape = LB.Text.EscapeForUI

DiscoveryToast.WIDTH, DiscoveryToast.HEIGHT = 340, 82
DiscoveryToast.FADE_IN, DiscoveryToast.HOLD, DiscoveryToast.FADE_OUT = 0.3, 6, 0.8

local queue = {}

local function create()
    local frame = CreateFrame("Button", LB.GlobalName("DiscoveryToast"), UIParent, "BackdropTemplate")
    frame:SetSize(DiscoveryToast.WIDTH, DiscoveryToast.HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- The medallion has its own drawn ring: no frame around it.
    frame.seal = frame:CreateTexture(nil, "ARTWORK")
    frame.seal:SetSize(62, 62)
    frame.seal:SetPoint("LEFT", frame, "LEFT", 10, 0)
    LB.Discovery.ApplySeal(frame.seal, true)

    frame.header = frame:CreateFontString(nil, "OVERLAY")
    frame.header:SetFontObject(LB.Fonts.Get("label"))
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 82, -14)
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject(LB.Fonts.Get("heading3"))
    frame.title:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -4)
    frame.title:SetWidth(DiscoveryToast.WIDTH - 92)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWordWrap(false)
    frame.detail = frame:CreateFontString(nil, "OVERLAY")
    frame.detail:SetFontObject(LB.Fonts.Get("caption"))
    frame.detail:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    frame.detail:SetWidth(DiscoveryToast.WIDTH - 92)
    frame.detail:SetJustifyH("LEFT")
    frame.detail:SetWordWrap(false)

    frame:SetScript("OnClick", function(_, button)
        local item = DiscoveryToast.current
        DiscoveryToast.Dismiss()
        if button ~= "LeftButton" or not item then return end
        if item.def then
            LB.Discovery.OpenPage(item.def)
        else
            LB.DiscoveryJournal.Open()
        end
    end)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L(DiscoveryToast.current and DiscoveryToast.current.def and "DISCOVERY_CLICK"
            or "DISCOVERY_CLICK_JOURNAL"))
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnUpdate", function(_, elapsed) DiscoveryToast.Advance(elapsed) end)
    frame:Hide()
    return frame
end

local function display(item)
    local frame = DiscoveryToast.frame
    DiscoveryToast.current, DiscoveryToast.elapsed = item, 0
    local Discovery = LB.Discovery
    if item.def then
        local record = Discovery.DB()[item.def.id]
        frame.header:SetText(L("DISCOVERY_NEW"))
        frame.title:SetText(Escape(Discovery.Title(item.def)))
        frame.detail:SetText(record and Escape(Discovery.FormatWhere(record)) or "")
    else
        frame.header:SetText(L("DISCOVERY_META"))
        frame.title:SetText(Escape(Discovery.Title(item.meta)))
        frame.detail:SetText(L("DISCOVERY_CLICK_JOURNAL"))
    end
    Discovery.DressPanel(frame, DiscoveryToast.WIDTH, DiscoveryToast.HEIGHT)
    frame:SetAlpha(0)
    frame:Show()
end

local function nextItem()
    DiscoveryToast.current = nil
    local item = table.remove(queue, 1)
    if item then
        display(item)
    else
        DiscoveryToast.frame:Hide()
    end
end

-- item = { def } (a found NPC) or { meta } (a completed meta achievement).
function DiscoveryToast.Show(item)
    DiscoveryToast.frame = DiscoveryToast.frame or create()
    if DiscoveryToast.current then
        queue[#queue + 1] = item
    else
        display(item)
    end
end

-- Time step of the fade in / hold / fade out cycle (OnUpdate; tests call it directly).
function DiscoveryToast.Advance(elapsed)
    local frame = DiscoveryToast.frame
    if not DiscoveryToast.current or not frame then return end
    if frame:IsMouseOver() then
        frame:SetAlpha(1)
        return
    end
    local t = DiscoveryToast.elapsed + elapsed
    DiscoveryToast.elapsed = t
    local fadeIn, hold, fadeOut = DiscoveryToast.FADE_IN, DiscoveryToast.HOLD, DiscoveryToast.FADE_OUT
    if t < fadeIn then
        frame:SetAlpha(t / fadeIn)
    elseif t < fadeIn + hold then
        frame:SetAlpha(1)
    elseif t < fadeIn + hold + fadeOut then
        frame:SetAlpha(1 - (t - fadeIn - hold) / fadeOut)
    else
        nextItem()
    end
end

function DiscoveryToast.Dismiss()
    if DiscoveryToast.frame then nextItem() end
end

-- Drops the queue and hides the toast.
function DiscoveryToast.Clear()
    queue = {}
    DiscoveryToast.current = nil
    if DiscoveryToast.frame then DiscoveryToast.frame:Hide() end
end

function DiscoveryToast.Pending()
    return #queue
end
