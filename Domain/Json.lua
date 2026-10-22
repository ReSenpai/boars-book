local _, LB = ...

-- Strict JSON for the book format. Pure: no WoW API, no code execution.
--
-- Decoding: integers only (|n| < 10^15), no duplicate keys, no trailing data,
-- depth and node limits, input must be valid UTF-8. `null` decodes to Json.NULL.
-- Encoding is canonical: object keys sorted bytewise, no whitespace, UTF-8 as is.
-- Empty tables encode as `[]` (SavedVariables cannot keep an array/object marker;
-- book objects always have required fields, so they are never empty).
local Json = {}
LB.Json = Json

local Utf8 = LB.Utf8

local byte, sub, find, format = string.byte, string.sub, string.find, string.format
local tonumber, type, pairs = tonumber, type, pairs

Json.NULL = setmetatable({}, { __tostring = function() return "Json.NULL" end })

local DEFAULT_MAX_DEPTH = 12
local DEFAULT_MAX_NODES = 100000
local MAX_INTEGER_DIGITS = 15

local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function fail(code, position)
    error({ jsonError = true, code = code, position = position }, 0)
end

function Json.Decode(s, options)
    options = options or {}
    local maxDepth = options.maxDepth or DEFAULT_MAX_DEPTH
    local maxNodes = options.maxNodes or DEFAULT_MAX_NODES

    local valid, badPosition = Utf8.Validate(s)
    if not valid then
        return nil, "JSON_UTF8", badPosition
    end

    local pos = 1
    local length = #s
    local depth = 0
    local nodes = 0
    local parseValue

    local function skipWhitespace()
        pos = find(s, "[^ \t\r\n]", pos) or length + 1
    end

    local function countNode()
        nodes = nodes + 1
        if nodes > maxNodes then
            fail("JSON_TOO_MANY_NODES", pos)
        end
    end

    local function readHex4(at)
        local hex = sub(s, at, at + 3)
        if #hex < 4 or find(hex, "[^0-9a-fA-F]") then
            fail("JSON_ESCAPE", at)
        end
        return tonumber(hex, 16)
    end

    local function parseString()
        local start = pos
        pos = pos + 1
        local parts = {}
        while true do
            local i = find(s, '["\\%z\1-\31]', pos)
            if not i then
                fail("JSON_UNEXPECTED_END", length + 1)
            end
            parts[#parts + 1] = sub(s, pos, i - 1)
            local c = sub(s, i, i)
            if c == '"' then
                pos = i + 1
                return table.concat(parts), start
            elseif c == "\\" then
                local e = sub(s, i + 1, i + 1)
                if e == "u" then
                    local cp = readHex4(i + 2)
                    local nextPos = i + 6
                    if cp >= 0xDC00 and cp <= 0xDFFF then
                        fail("JSON_SURROGATE", i)
                    elseif cp >= 0xD800 and cp <= 0xDBFF then
                        if sub(s, nextPos, nextPos + 1) ~= "\\u" then
                            fail("JSON_SURROGATE", i)
                        end
                        local low = readHex4(nextPos + 2)
                        if low < 0xDC00 or low > 0xDFFF then
                            fail("JSON_SURROGATE", i)
                        end
                        cp = 0x10000 + (cp - 0xD800) * 0x400 + (low - 0xDC00)
                        nextPos = nextPos + 6
                    end
                    if cp == 0 then
                        fail("JSON_CONTROL_CHAR", i)
                    end
                    parts[#parts + 1] = Utf8.Encode(cp)
                    pos = nextPos
                elseif ESCAPES[e] then
                    parts[#parts + 1] = ESCAPES[e]
                    pos = i + 2
                elseif e == "" then
                    fail("JSON_UNEXPECTED_END", i)
                else
                    fail("JSON_ESCAPE", i)
                end
            else
                fail("JSON_CONTROL_CHAR", i)
            end
        end
    end

    local function parseNumber()
        local start = pos
        local token = string.match(s, "^-?%d*", pos)
        local digits = string.match(token, "%d+")
        local nextChar = sub(s, pos + #token, pos + #token)
        if not digits
            or (#digits > 1 and sub(digits, 1, 1) == "0")
            or #digits > MAX_INTEGER_DIGITS
            or find(nextChar, "[%.eE]") then
            fail("JSON_NUMBER", start)
        end
        pos = pos + #token
        return tonumber(token)
    end

    local function enterContainer()
        depth = depth + 1
        if depth > maxDepth then
            fail("JSON_DEPTH", pos)
        end
    end

    local function parseArray()
        enterContainer()
        pos = pos + 1
        local result = {}
        skipWhitespace()
        if sub(s, pos, pos) == "]" then
            pos = pos + 1
            depth = depth - 1
            return result
        end
        while true do
            result[#result + 1] = parseValue()
            skipWhitespace()
            local c = sub(s, pos, pos)
            if c == "," then
                pos = pos + 1
                skipWhitespace()
                if sub(s, pos, pos) == "]" then
                    fail("JSON_SYNTAX", pos)
                end
            elseif c == "]" then
                pos = pos + 1
                depth = depth - 1
                return result
            elseif c == "" then
                fail("JSON_UNEXPECTED_END", pos)
            else
                fail("JSON_SYNTAX", pos)
            end
        end
    end

    local function parseObject()
        enterContainer()
        pos = pos + 1
        local result = {}
        skipWhitespace()
        if sub(s, pos, pos) == "}" then
            pos = pos + 1
            depth = depth - 1
            return result
        end
        while true do
            local c = sub(s, pos, pos)
            if c == "" then
                fail("JSON_UNEXPECTED_END", pos)
            elseif c ~= '"' then
                fail("JSON_SYNTAX", pos)
            end
            local key, keyStart = parseString()
            if result[key] ~= nil then
                fail("JSON_DUPLICATE_KEY", keyStart)
            end
            skipWhitespace()
            if sub(s, pos, pos) ~= ":" then
                fail(pos > length and "JSON_UNEXPECTED_END" or "JSON_SYNTAX", pos)
            end
            pos = pos + 1
            result[key] = parseValue()
            skipWhitespace()
            c = sub(s, pos, pos)
            if c == "," then
                pos = pos + 1
                skipWhitespace()
                if sub(s, pos, pos) == "}" then
                    fail("JSON_SYNTAX", pos)
                end
            elseif c == "}" then
                pos = pos + 1
                depth = depth - 1
                return result
            elseif c == "" then
                fail("JSON_UNEXPECTED_END", pos)
            else
                fail("JSON_SYNTAX", pos)
            end
        end
    end

    local LITERALS = { ["true"] = true, ["false"] = false, ["null"] = Json.NULL }

    parseValue = function()
        skipWhitespace()
        countNode()
        local c = sub(s, pos, pos)
        if c == "{" then
            return parseObject()
        elseif c == "[" then
            return parseArray()
        elseif c == '"' then
            return (parseString())
        elseif c == "-" or find(c, "^%d$") then
            return parseNumber()
        elseif c == "" then
            fail("JSON_UNEXPECTED_END", pos)
        end
        for word, value in pairs(LITERALS) do
            if sub(s, pos, pos + #word - 1) == word then
                pos = pos + #word
                return value
            end
        end
        fail("JSON_SYNTAX", pos)
    end

    local ok, result = pcall(function()
        local value = parseValue()
        skipWhitespace()
        if pos <= length then
            fail("JSON_TRAILING", pos)
        end
        return value
    end)
    if ok then
        return result
    end
    if type(result) == "table" and result.jsonError then
        return nil, result.code, result.position
    end
    error(result, 0)
end

-- Encoding -------------------------------------------------------------------

local ENCODE_ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
    ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function escapeChar(c)
    return ENCODE_ESCAPES[c] or format("\\u%04x", byte(c))
end

local function encodeString(s)
    return '"' .. string.gsub(s, '[%z\1-\31"\\]', escapeChar) .. '"'
end

-- Bytewise comparison: independent of the C locale used by `<` on strings.
local function bytewiseLess(a, b)
    local n = math.min(#a, #b)
    for i = 1, n do
        local x, y = byte(a, i), byte(b, i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

local MAX_ENCODE_DEPTH = 64

local function encodeValue(value, out, depth)
    local t = type(value)
    if value == Json.NULL then
        out[#out + 1] = "null"
    elseif t == "string" then
        out[#out + 1] = encodeString(value)
    elseif t == "boolean" then
        out[#out + 1] = value and "true" or "false"
    elseif t == "number" then
        if value ~= value or value ~= math.floor(value) or math.abs(value) >= 1e15 then
            fail("JSON_NUMBER")
        end
        out[#out + 1] = format("%d", value)
    elseif t == "table" then
        if depth > MAX_ENCODE_DEPTH then
            fail("JSON_DEPTH")
        end
        local count, stringKeys = 0, 0
        for k in pairs(value) do
            count = count + 1
            if type(k) == "string" then
                stringKeys = stringKeys + 1
            elseif type(k) ~= "number" then
                fail("JSON_KEY")
            end
        end
        if stringKeys == 0 then
            for i = 1, count do
                if value[i] == nil then
                    fail("JSON_KEY")
                end
            end
            out[#out + 1] = "["
            for i = 1, count do
                if i > 1 then out[#out + 1] = "," end
                encodeValue(value[i], out, depth + 1)
            end
            out[#out + 1] = "]"
        elseif stringKeys == count then
            local keys = {}
            for k in pairs(value) do keys[#keys + 1] = k end
            table.sort(keys, bytewiseLess)
            out[#out + 1] = "{"
            for i, k in ipairs(keys) do
                if i > 1 then out[#out + 1] = "," end
                out[#out + 1] = encodeString(k)
                out[#out + 1] = ":"
                encodeValue(value[k], out, depth + 1)
            end
            out[#out + 1] = "}"
        else
            fail("JSON_KEY")
        end
    else
        fail("JSON_TYPE")
    end
end

-- Returns the canonical JSON string, or nil and an error code.
function Json.Encode(value)
    local out = {}
    local ok, err = pcall(encodeValue, value, out, 1)
    if ok then
        return table.concat(out)
    end
    if type(err) == "table" and err.jsonError then
        return nil, err.code
    end
    error(err, 0)
end
