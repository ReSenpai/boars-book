local _, LB = ...

-- Validates book documents against LB.BookSchema plus semantic rules that
-- JSON Schema cannot express. Pure: no WoW API.
local Validator = {}
LB.BookValidator = Validator

local Schema = LB.BookSchema
local Utf8 = LB.Utf8

local DEFAULT_MAX_ERRORS = 50

local function copyPath(path, extra)
    local result = {}
    for i = 1, #path do result[i] = path[i] end
    if extra ~= nil then result[#result + 1] = extra end
    return result
end

local function isArray(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for k in pairs(value) do
        if type(k) ~= "number" then return false end
        count = count + 1
    end
    for i = 1, count do
        if value[i] == nil then return false end
    end
    return true
end

local function isObject(value)
    if type(value) ~= "table" or value == LB.Json.NULL then return false end
    for k in pairs(value) do
        if type(k) ~= "string" then return false end
    end
    return true
end

local function isInteger(value)
    return type(value) == "number" and value == math.floor(value) and value == value
end

local function newContext(maxErrors)
    local ctx = { errors = {}, maxErrors = maxErrors or DEFAULT_MAX_ERRORS }
    function ctx.add(code, path, params)
        if #ctx.errors < ctx.maxErrors then
            ctx.errors[#ctx.errors + 1] = { code = code, path = path, params = params or {} }
        end
    end
    return ctx
end

local validateNode

local function validateObject(schema, value, path, ctx)
    if not isObject(value) then
        ctx.add("VALIDATION_TYPE", path, { expected = "object" })
        return
    end
    local known = {}
    for _, field in ipairs(schema.fields) do
        local name, fieldSchema, required = field[1], field[2], field[3]
        known[name] = true
        if value[name] == nil then
            if required then
                ctx.add("VALIDATION_REQUIRED", copyPath(path, name))
            end
        else
            validateNode(fieldSchema, value[name], copyPath(path, name), ctx)
        end
    end
    local unknown = {}
    for name in pairs(value) do
        if not known[name] then unknown[#unknown + 1] = name end
    end
    table.sort(unknown)
    for _, name in ipairs(unknown) do
        ctx.add("VALIDATION_UNKNOWN_FIELD", copyPath(path, name))
    end
end

local function validateArray(schema, value, path, ctx)
    if not isArray(value) then
        ctx.add("VALIDATION_TYPE", path, { expected = "array" })
        return
    end
    local n = #value
    if (schema.min and n < schema.min) or (schema.max and n > schema.max) then
        ctx.add("VALIDATION_ARRAY_LENGTH", path, { min = schema.min, max = schema.max, actual = n })
    end
    for i = 1, n do
        validateNode(schema.items, value[i], copyPath(path, i), ctx)
    end
end

local function validateString(schema, value, path, ctx)
    if type(value) ~= "string" then
        ctx.add("VALIDATION_TYPE", path, { expected = "string" })
        return
    end
    if not Utf8.Validate(value) then
        ctx.add("VALIDATION_UTF8", path)
        return
    end
    local length = Utf8.Len(value)
    if (schema.min and length < schema.min) or (schema.max and length > schema.max) then
        ctx.add("VALIDATION_STRING_LENGTH", path, { min = schema.min, max = schema.max, actual = length })
    end
    if schema.pattern and not string.find(value, schema.pattern) then
        ctx.add("VALIDATION_PATTERN", path)
    end
end

local function validateUnion(schema, value, path, ctx)
    if not isObject(value) then
        ctx.add("VALIDATION_TYPE", path, { expected = "object" })
        return
    end
    local tag = value[schema.discriminator]
    if tag == nil then
        ctx.add("VALIDATION_REQUIRED", copyPath(path, schema.discriminator))
        return
    end
    local variant = type(tag) == "string" and schema.variants[tag]
    if not variant then
        ctx.add(schema.unknownCode, copyPath(path, schema.discriminator))
        return
    end
    validateObject(variant, value, path, ctx)
end

validateNode = function(schema, value, path, ctx)
    local kind = schema.kind
    if kind == "object" then
        validateObject(schema, value, path, ctx)
    elseif kind == "array" then
        validateArray(schema, value, path, ctx)
    elseif kind == "string" then
        validateString(schema, value, path, ctx)
    elseif kind == "integer" then
        if not isInteger(value) then
            ctx.add("VALIDATION_TYPE", path, { expected = "integer" })
        elseif (schema.min and value < schema.min) or (schema.max and value > schema.max) then
            ctx.add("VALIDATION_INTEGER_RANGE", path, { min = schema.min, max = schema.max })
        end
    elseif kind == "boolean" then
        if type(value) ~= "boolean" then
            ctx.add("VALIDATION_TYPE", path, { expected = "boolean" })
        end
    elseif kind == "enum" then
        for _, allowed in ipairs(schema.values) do
            if value == allowed then return end
        end
        ctx.add("VALIDATION_ENUM", path)
    elseif kind == "const" then
        if value ~= schema.value then
            if schema.newerCode and isInteger(value) and value > schema.value then
                ctx.add(schema.newerCode, path)
            elseif type(value) ~= type(schema.value) then
                ctx.add("VALIDATION_TYPE", path, { expected = type(schema.value) })
            else
                ctx.add("VALIDATION_ENUM", path)
            end
        end
    elseif kind == "union" then
        validateUnion(schema, value, path, ctx)
    else
        error("unknown schema kind: " .. tostring(kind))
    end
end

-- Semantic rules; runs only on structurally valid documents.
local function validateSemantics(book, ctx)
    local chapterIds, blockIds, itemIds = {}, {}, {}
    local totalBlocks = 0
    for c, chapter in ipairs(book.chapters) do
        if chapterIds[chapter.id] then
            ctx.add("DUPLICATE_CHAPTER_ID", { "chapters", c, "id" }, { id = chapter.id })
        end
        chapterIds[chapter.id] = true
        for b, blk in ipairs(chapter.blocks) do
            totalBlocks = totalBlocks + 1
            if blockIds[blk.id] then
                ctx.add("DUPLICATE_BLOCK_ID", { "chapters", c, "blocks", b, "id" }, { id = blk.id })
            end
            blockIds[blk.id] = true
            if blk.type == "checklist" then
                for i, item in ipairs(blk.items) do
                    if itemIds[item.id] then
                        ctx.add("DUPLICATE_ITEM_ID", { "chapters", c, "blocks", b, "items", i, "id" }, { id = item.id })
                    end
                    itemIds[item.id] = true
                end
            end
        end
    end
    for c, chapter in ipairs(book.chapters) do
        for b, blk in ipairs(chapter.blocks) do
            if blk.type == "reference" and blk.target.kind == "chapter" and not chapterIds[blk.target.id] then
                ctx.add("BROKEN_CHAPTER_REF", { "chapters", c, "blocks", b, "target", "id" }, { id = blk.target.id })
            end
        end
    end
    if totalBlocks > Schema.MAX_TOTAL_BLOCKS then
        ctx.add("TOO_MANY_BLOCKS", { "chapters" }, { max = Schema.MAX_TOTAL_BLOCKS, actual = totalBlocks })
    end
    local json = LB.Json.Encode(book)
    if json and #json > Schema.MAX_JSON_BYTES then
        ctx.add("BOOK_TOO_LARGE", {}, { max = Schema.MAX_JSON_BYTES, actual = #json })
    end
end

-- Returns ok, errors. Each error: { code, path = {segments...}, params = {...} }.
function Validator.Validate(book, options)
    options = options or {}
    local ctx = newContext(options.maxErrors)
    validateNode(Schema.BOOK, book, {}, ctx)
    if #ctx.errors == 0 then
        validateSemantics(book, ctx)
    end
    return #ctx.errors == 0, ctx.errors
end

-- Human-readable path: chapter and block IDs where available.
function Validator.DescribePath(path, book)
    local L = LB.L
    local parts = {}
    local chapter, container
    local i = 1
    while i <= #path do
        local segment, index = path[i], path[i + 1]
        if segment == "chapters" and type(index) == "number" then
            chapter = type(book) == "table" and type(book.chapters) == "table" and book.chapters[index]
            local id = type(chapter) == "table" and chapter.id
            parts[#parts + 1] = L("PATH_CHAPTER", type(id) == "string" and id or ("#" .. index))
            i = i + 2
        elseif segment == "blocks" and type(index) == "number" then
            container = type(chapter) == "table" and type(chapter.blocks) == "table" and chapter.blocks[index]
            local id = type(container) == "table" and container.id
            parts[#parts + 1] = L("PATH_BLOCK", type(id) == "string" and id or ("#" .. index))
            i = i + 2
        elseif type(index) == "number" then
            parts[#parts + 1] = L("PATH_ITEM", tostring(segment), index)
            i = i + 2
        else
            parts[#parts + 1] = tostring(segment)
            i = i + 1
        end
    end
    if #parts == 0 then
        return L("PATH_BOOK")
    end
    return table.concat(parts, " > ")
end

-- Order of params substituted into each ERR_<code> locale string.
local MESSAGE_PARAMS = {
    VALIDATION_TYPE = { "expected" },
    VALIDATION_STRING_LENGTH = { "min", "max", "actual" },
    VALIDATION_ARRAY_LENGTH = { "min", "max", "actual" },
    VALIDATION_INTEGER_RANGE = { "min", "max" },
    DUPLICATE_CHAPTER_ID = { "id" },
    DUPLICATE_BLOCK_ID = { "id" },
    DUPLICATE_ITEM_ID = { "id" },
    BROKEN_CHAPTER_REF = { "id" },
    TOO_MANY_BLOCKS = { "max", "actual" },
    BOOK_TOO_LARGE = { "max", "actual" },
}

function Validator.FormatError(err, book)
    local args = {}
    for i, name in ipairs(MESSAGE_PARAMS[err.code] or {}) do
        local value = err.params and err.params[name]
        args[i] = value == nil and "-" or tostring(value)
    end
    local message = LB.L("ERR_" .. err.code, unpack(args))
    return LB.L("ERROR_LOCATION", Validator.DescribePath(err.path, book), message)
end
