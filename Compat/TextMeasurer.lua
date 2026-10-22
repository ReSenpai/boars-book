local _, LB = ...

-- Layout measurer backed by client font strings: :Width(text, style), :LineHeight(style).
-- Widths are cached per style; call Reset() after any font change.
local TextMeasurer = {}
TextMeasurer.__index = TextMeasurer
LB.TextMeasurer = TextMeasurer

TextMeasurer.LINE_GAP = 3
local LINE_SAMPLE = "ЁЙAjy"

function TextMeasurer.New(parent)
    local self = setmetatable({}, TextMeasurer)
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetSize(1, 1)
    self.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    self.frame:SetAlpha(0)
    self.strings = {}
    self:Reset()
    return self
end

function TextMeasurer:Reset()
    self.widths = {}
    self.lineHeights = {}
end

function TextMeasurer:FontString(style)
    local fs = self.strings[style]
    if not fs then
        fs = self.frame:CreateFontString(nil, "ARTWORK")
        fs:SetWordWrap(false)
        fs:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        self.strings[style] = fs
    end
    fs:SetFontObject(LB.Fonts.Get(style))
    return fs
end

function TextMeasurer:Width(text, style)
    local cache = self.widths[style]
    if not cache then
        cache = {}
        self.widths[style] = cache
    end
    local escaped = LB.Text.EscapeForUI(text)
    local width = cache[escaped]
    if not width then
        local fs = self:FontString(style)
        fs:SetText(escaped)
        width = fs:GetStringWidth()
        cache[escaped] = width
    end
    return width
end

function TextMeasurer:LineHeight(style)
    local height = self.lineHeights[style]
    if not height then
        local fs = self:FontString(style)
        fs:SetText(LINE_SAMPLE)
        height = math.ceil(fs:GetStringHeight()) + TextMeasurer.LINE_GAP
        self.lineHeights[style] = height
    end
    return height
end
