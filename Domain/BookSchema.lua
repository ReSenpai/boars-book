local _, LB = ...

-- Book document v1 as a Lua description mirroring reference/design/spec/book.schema.json.
-- Node kinds: object, array, string, integer, boolean, enum, const, union.
-- Object fields are ordered lists { name, schema, required } for deterministic errors.
local S = {}

local ID_PATTERN = "^[A-Za-z0-9][A-Za-z0-9%._:%-]*$"
local TIMESTAMP_PATTERN = "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"
local MAX_INT32 = 2147483647

local function str(min, max, pattern)
    return { kind = "string", min = min, max = max, pattern = pattern }
end

local function int(min, max)
    return { kind = "integer", min = min, max = max }
end

local function enum(...)
    return { kind = "enum", values = { ... } }
end

local function array(items, min, max)
    return { kind = "array", items = items, min = min, max = max }
end

local function object(fields)
    return { kind = "object", fields = fields }
end

local ID = str(1, 80, ID_PATTERN)
local TIMESTAMP = str(nil, nil, TIMESTAMP_PATTERN)

local function block(fields)
    local all = { { "id", ID, true }, { "type", { kind = "string" }, true } }
    for _, field in ipairs(fields) do
        all[#all + 1] = field
    end
    return object(all)
end

local BLOCKS = {
    heading = block({ { "text", str(1, 160), true }, { "level", enum(2, 3), true } }),
    paragraph = block({ { "text", str(1, 4000), true } }),
    list = block({
        { "ordered", { kind = "boolean" }, true },
        { "items", array(str(1, 500), 1, 20), true },
    }),
    checklist = block({
        { "items", array(object({ { "id", ID, true }, { "text", str(1, 500), true } }), 1, 20), true },
    }),
    figure = block({
        { "assetId", ID, true },
        { "alt", str(1, 300), true },
        { "caption", str(0, 300), true },
    }),
    facts = block({
        { "rows", array(object({ { "label", str(1, 80), true }, { "value", str(1, 500), true } }), 1, 20), true },
    }),
    reference = block({
        { "label", str(1, 160), true },
        { "target", {
            kind = "union",
            discriminator = "kind",
            unknownCode = "VALIDATION_ENUM",
            variants = {
                item = object({ { "kind", { kind = "string" }, true }, { "id", int(1, MAX_INT32), true } }),
                spell = object({ { "kind", { kind = "string" }, true }, { "id", int(1, MAX_INT32), true } }),
                chapter = object({ { "kind", { kind = "string" }, true }, { "id", ID, true } }),
            },
        }, true },
    }),
}

local TARGET = object({
    { "flavor", enum("classic-era", "forever"), true },
    { "ruleset", enum("standard", "hardcore", "seasonal", "unspecified"), true },
    { "status", enum("demo", "unverified", "author-verified"), true },
    { "verifiedBuild", str(1, 40), false },
})

local CHAPTER = object({
    { "id", ID, true },
    { "title", str(1, 160), true },
    { "blocks", array({
        kind = "union",
        discriminator = "type",
        unknownCode = "VALIDATION_UNKNOWN_BLOCK_TYPE",
        variants = BLOCKS,
    }, 1, 64), true },
})

S.BOOK = object({
    { "schemaVersion", { kind = "const", value = 1, newerCode = "SCHEMA_TOO_NEW" }, true },
    { "bookId", ID, true },
    { "authorId", ID, true },
    { "revision", int(1, MAX_INT32), true },
    { "title", str(1, 120), true },
    { "authorName", str(1, 80), true },
    { "locale", enum("ruRU", "enUS"), true },
    { "summary", str(1, 600), true },
    { "tags", array(str(1, 40), 0, 12), true },
    { "targets", array(TARGET, 1, 4), true },
    { "assetPackVersion", str(1, 40), true },
    { "coverAssetId", ID, true },
    { "createdAt", TIMESTAMP, true },
    { "updatedAt", TIMESTAMP, true },
    { "changelog", str(0, 1000), true },
    { "contentNotice", str(0, 1000), true },
    { "chapters", array(CHAPTER, 1, 32), true },
    { "derivedFrom", object({ { "bookId", ID, true }, { "revision", int(1, MAX_INT32), true } }), false },
    -- Lore Book extension before the v1 freeze (see docs/schema-changes.md).
    { "style", object({ { "parchment", enum("ivory", "quest", "sage", "classic", "scroll"), false } }), false },
})

S.SCHEMA_VERSION = 1
S.MAX_TOTAL_BLOCKS = 512
S.MAX_JSON_BYTES = 65536
S.BLOCK_TYPES = { "heading", "paragraph", "list", "checklist", "figure", "facts", "reference" }

LB.BookSchema = S
