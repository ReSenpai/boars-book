local _, LB = ...

-- UTF-8 helpers for Lua 5.1, where string functions operate on bytes.
-- Pure: no WoW API.
local Utf8 = {}
LB.Utf8 = Utf8

local byte, char, sub = string.byte, string.char, string.sub
local floor = math.floor

local BOM = "\239\187\191"

-- Length of the sequence started by lead byte b, and the allowed range of the
-- second byte (RFC 3629 table, excludes overlongs and surrogates). nil = invalid lead.
local function sequenceInfo(b)
    if b < 0x80 then return 1 end
    if b < 0xC2 then return nil end
    if b < 0xE0 then return 2, 0x80, 0xBF end
    if b == 0xE0 then return 3, 0xA0, 0xBF end
    if b == 0xED then return 3, 0x80, 0x9F end
    if b < 0xF0 then return 3, 0x80, 0xBF end
    if b == 0xF0 then return 4, 0x90, 0xBF end
    if b < 0xF4 then return 4, 0x80, 0xBF end
    if b == 0xF4 then return 4, 0x80, 0x8F end
    return nil
end

-- Returns true, or false and the byte position of the first invalid sequence.
function Utf8.Validate(s)
    local i, n = 1, #s
    while i <= n do
        local length, low, high = sequenceInfo(byte(s, i))
        if not length or i + length - 1 > n then
            return false, i
        end
        if length > 1 then
            local second = byte(s, i + 1)
            if second < low or second > high then
                return false, i
            end
            for k = i + 2, i + length - 1 do
                local b = byte(s, k)
                if b < 0x80 or b > 0xBF then
                    return false, i
                end
            end
        end
        i = i + length
    end
    return true
end

local function isLead(b)
    return b < 0x80 or b >= 0xC0
end

-- Number of code points. Assumes valid UTF-8.
function Utf8.Len(s)
    local count = 0
    for i = 1, #s do
        if isLead(byte(s, i)) then
            count = count + 1
        end
    end
    return count
end

-- Byte index where the n-th code point starts (#s + 1 when past the end).
function Utf8.ByteOffset(s, n)
    local count = 0
    for i = 1, #s do
        if isLead(byte(s, i)) then
            count = count + 1
            if count == n then
                return i
            end
        end
    end
    return #s + 1
end

-- Substring by code point indices (1-based, inclusive; j defaults to the end).
function Utf8.Sub(s, i, j)
    if j and j < i then
        return ""
    end
    local startByte = Utf8.ByteOffset(s, i)
    if not j then
        return sub(s, startByte)
    end
    local endByte = Utf8.ByteOffset(s, j + 1) - 1
    return sub(s, startByte, endByte)
end

function Utf8.Chars(s)
    local chars = {}
    local i, n = 1, #s
    while i <= n do
        local length = sequenceInfo(byte(s, i)) or 1
        table.insert(chars, sub(s, i, i + length - 1))
        i = i + length
    end
    return chars
end

-- Encodes a code point; nil for surrogates and values outside U+0000..U+10FFFF.
function Utf8.Encode(cp)
    if cp < 0 or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF) then
        return nil
    end
    if cp < 0x80 then
        return char(cp)
    end
    if cp < 0x800 then
        return char(0xC0 + floor(cp / 0x40), 0x80 + cp % 0x40)
    end
    if cp < 0x10000 then
        return char(0xE0 + floor(cp / 0x1000), 0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
    end
    return char(0xF0 + floor(cp / 0x40000), 0x80 + floor(cp / 0x1000) % 0x40,
        0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

function Utf8.StripBOM(s)
    if sub(s, 1, 3) == BOM then
        return sub(s, 4)
    end
    return s
end
