local _, LB = ...

-- Design tokens (reference/design/spec/design-tokens.json) as 0..1 RGB.
local Theme = {}
LB.Theme = Theme

Theme.colors = {
    parchment = { 0.910, 0.824, 0.647 },
    ink = { 0.180, 0.129, 0.090 },
    secondary = { 0.376, 0.290, 0.196 },
    leather = { 0.235, 0.153, 0.106 },
    brass = { 0.647, 0.502, 0.259 },
    button = { 0.482, 0.125, 0.125 },
    selected = { 0.941, 0.835, 0.525 },
    warning = { 0.478, 0.239, 0.090 },
}

Theme.textColors = {
    title = Theme.colors.ink,
    heading2 = Theme.colors.ink,
    heading3 = Theme.colors.ink,
    body = Theme.colors.ink,
    caption = Theme.colors.ink,
    label = Theme.colors.secondary,
    link = Theme.colors.button,
    term = Theme.colors.ink,
}

Theme.DEFAULT_BODY_SIZE = 17

-- Verified in the Classic Era UI source (ItemTextFrame.xml, 1.15.9): the book/letter parchment.
Theme.PARCHMENT_TEXTURE = "Interface\\MailFrame\\UI-MailFrameBG"
-- The parchment occupies about 320x352 of the 512x512 file; the rest is transparent.
-- Cropped slightly inside the painted area so the window shows parchment edge to edge.
Theme.PARCHMENT_TEXCOORD = { 0.01, 0.615, 0.01, 0.68 }

-- The addon's own parchments (LoreBook/Assets/Parchments, built by tools/make_parchments.py):
-- opaque, aged edges, the whole image is used. `spread` is a two-page texture for spreads.
local OWN_PARCHMENTS = "Interface\\AddOns\\" .. LB.ADDON_NAME .. "\\Assets\\Parchments\\"
local WHOLE = { 0, 1, 0, 1 }

-- Parchments a book author can choose (book.style.parchment). `own` ones are page
-- sheets; the client ones (checked with /lb textures on Era 1.15.9) fill the window.
Theme.PARCHMENTS = {
    ivory = { texture = OWN_PARCHMENTS .. "parchment-ivory", coords = WHOLE, own = true,
        spread = OWN_PARCHMENTS .. "parchment-spread-ivory", nameKey = "PARCHMENT_IVORY" },
    quest = { texture = OWN_PARCHMENTS .. "parchment-honey", coords = WHOLE, own = true, nameKey = "PARCHMENT_QUEST" },
    sage = { texture = OWN_PARCHMENTS .. "parchment-sage", coords = WHOLE, own = true, nameKey = "PARCHMENT_SAGE" },
    classic = { texture = Theme.PARCHMENT_TEXTURE, coords = Theme.PARCHMENT_TEXCOORD, nameKey = "PARCHMENT_CLASSIC" },
    scroll = { texture = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
        coords = WHOLE, nameKey = "PARCHMENT_SCROLL" },
}
Theme.PARCHMENT_ORDER = { "ivory", "quest", "sage", "classic", "scroll" }
-- Books without style.parchment; menu windows keep the client's letter parchment.
Theme.DEFAULT_PARCHMENT = "ivory"
Theme.WINDOW_PARCHMENT = "classic"

function Theme.ParchmentId(book)
    local id = type(book) == "table" and type(book.style) == "table" and book.style.parchment
    return Theme.PARCHMENTS[id] and id or Theme.DEFAULT_PARCHMENT
end

function Theme.ParchmentOf(book)
    return Theme.PARCHMENTS[Theme.ParchmentId(book)]
end

-- How the reader covers its pages: "spread" (one two-page texture over the inset),
-- "sheets" (one page texture behind each page) or "fill" (the texture over the inset).
function Theme.ReaderBackground(parchment, mode)
    if mode == "spread" and parchment.spread then
        return { layout = "spread", texture = parchment.spread, coords = WHOLE }
    end
    if parchment.own then
        return { layout = "sheets", texture = parchment.texture, coords = parchment.coords }
    end
    return { layout = "fill", texture = parchment.texture, coords = parchment.coords }
end
