local _, LB = ...

-- Own font objects per text style, copied from the client's localized book fonts.
-- Global fonts are never modified.
local Fonts = {}
LB.Fonts = Fonts

local MIN_BODY, MAX_BODY = 14, 24
local MIN_CAPTION = 12
local FALLBACK_FONT = "GameFontNormal"

-- Base font candidates per style, in order of preference.
local STYLE_BASES = {
    title = { "QuestTitleFont", "ItemTextFontNormal" },
    heading2 = { "QuestTitleFont", "ItemTextFontNormal" },
    heading3 = { "QuestTitleFont", "ItemTextFontNormal" },
    body = { "ItemTextFontNormal" },
    caption = { "ItemTextFontNormal" },
    label = { "ItemTextFontNormal" },
    link = { "ItemTextFontNormal" },
    term = { "QuestTitleFont", "ItemTextFontNormal" },
}

-- Size relative to the body size.
local SIZE_OFFSETS = { title = 11, heading2 = 7, heading3 = 3, body = 0, caption = -3, label = -1, link = 0, term = 0 }

Fonts.STYLES = { "title", "heading2", "heading3", "body", "caption", "label", "link", "term" }

local fonts = {}
local bodySize = 17

local function clamp(size)
    size = math.floor(tonumber(size) or 17)
    if size < MIN_BODY then return MIN_BODY end
    if size > MAX_BODY then return MAX_BODY end
    return size
end

local function baseFont(style)
    for _, name in ipairs(STYLE_BASES[style]) do
        local font = _G[name]
        if font then return font end
    end
    return _G[FALLBACK_FONT]
end

local function styleSize(style)
    local size = bodySize + SIZE_OFFSETS[style]
    if style == "caption" and size < MIN_CAPTION then
        size = MIN_CAPTION
    end
    return size
end

local function applyStyle(style)
    local font = fonts[style]
    local base = baseFont(style)
    if base then
        font:CopyFontObject(base)
    end
    local file, _, flags = font:GetFont()
    font:SetFont(file, styleSize(style), flags)
    font:SetShadowOffset(0, 0)
    local color = LB.Theme and LB.Theme.textColors[style]
    if color then
        font:SetTextColor(color[1], color[2], color[3], 1)
    end
end

function Fonts.Init(size)
    bodySize = clamp(size)
    for _, style in ipairs(Fonts.STYLES) do
        fonts[style] = fonts[style] or CreateFont(LB.GlobalName("Font_" .. style))
        applyStyle(style)
    end
end

function Fonts.SetBodySize(size)
    bodySize = clamp(size)
    for _, style in ipairs(Fonts.STYLES) do
        applyStyle(style)
    end
end

function Fonts.GetBodySize()
    return bodySize
end

function Fonts.Get(style)
    return fonts[style] or fonts.body
end

-- Part of the layout cache key: anything that changes text metrics.
function Fonts.Key()
    return tostring(bodySize)
end
