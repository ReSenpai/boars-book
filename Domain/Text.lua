local _, LB = ...

-- Text helpers for author content. Pure: no WoW API.
local Text = {}
LB.Text = Text

local Utf8 = LB.Utf8

-- Author text must never be interpreted as WoW markup (|T, |H, |c ...):
-- a doubled pipe is rendered as a literal "|".
function Text.EscapeForUI(s)
    if not s then
        return ""
    end
    return (string.gsub(s, "|", "||"))
end

-- Cyrillic capitals U+0400..U+042F (bytes D0 80..D0 AF) to lowercase.
local CYRILLIC_LOWER = {}
for cp = 0x400, 0x42F do
    CYRILLIC_LOWER[Utf8.Encode(cp)] = Utf8.Encode(cp < 0x410 and cp + 0x50 or cp + 0x20)
end

local function lowerAscii(c)
    return string.char(string.byte(c) + 32)
end

-- Locale-independent lowercase for Latin and Cyrillic; byte lengths are preserved.
function Text.Lower(s)
    s = string.gsub(s, "[A-Z]", lowerAscii)
    return (string.gsub(s, "\208[\128-\175]", CYRILLIC_LOWER))
end

-- Normalized form for search: lowercase, ё = е. Byte lengths are preserved,
-- so byte and code point positions in the key match the original text.
function Text.SearchKey(s)
    return (string.gsub(Text.Lower(s), "\209\145", "\208\181"))
end

-- Up to `count` code points before and after a position given as the number
-- of code points preceding it. Used for reading anchors (quoteBefore/After).
function Text.Excerpt(s, offset, count)
    local length = Utf8.Len(s)
    if offset < 0 then offset = 0 end
    if offset > length then offset = length end
    local before = ""
    if offset > 0 then
        local first = offset - count + 1
        if first < 1 then first = 1 end
        before = Utf8.Sub(s, first, offset)
    end
    local after = Utf8.Sub(s, offset + 1, math.min(length, offset + count))
    return before, after
end
