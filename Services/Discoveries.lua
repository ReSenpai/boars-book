local _, LB = ...

-- Discoveries of a book edition: NPCs from the book that the player has targeted.
-- Definitions come from LB.BookAchievements (book/achievements.json): each one is
-- an NPC id hidden behind a chapter heading; meta achievements require several.
-- Records are account-wide: db[id] = { at, zone, subzone, mapId, x, y, level,
-- character, seen }. Pure: no WoW API.
local Discoveries = {}
LB.Discoveries = Discoveries

-- "Creature-0-<server>-<instance>-<zone>-<npcId>-<spawn>" -> npcId. Pets, players
-- and anything else are not discoveries.
function Discoveries.NpcId(guid)
    if type(guid) ~= "string" then return nil end
    local kind, npcId = string.match(guid, "^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind ~= "Creature" then return nil end
    return tonumber(npcId)
end

-- data = { discoveries = { def... }, meta = { meta... } } -> index.
function Discoveries.Index(data)
    data = data or {}
    local index = { list = data.discoveries or {}, meta = data.meta or {}, byNpc = {}, byId = {}, byBlock = {} }
    for _, def in ipairs(index.list) do
        index.byNpc[def.npcId] = def
        index.byId[def.id] = def
        index.byBlock[def.blockId] = index.byBlock[def.blockId] or {}
        table.insert(index.byBlock[def.blockId], def)
    end
    return index
end

function Discoveries.ForNpc(index, npcId)
    return npcId and index.byNpc[npcId]
end

function Discoveries.ForBlock(index, blockId)
    return index.byBlock[blockId] or {}
end

function Discoveries.Get(db, id)
    return db[id]
end

-- Title in a language, else in the original.
function Discoveries.Title(item, language, original)
    local title = item.title or {}
    return title[language] or title[original] or item.id
end

local function metaDone(db, meta)
    for _, id in ipairs(meta.requires) do
        if not db[id] then return false end
    end
    return true
end

-- Progress of a meta achievement: done, have, need.
function Discoveries.MetaProgress(db, meta)
    local have = 0
    for _, id in ipairs(meta.requires) do
        if db[id] then have = have + 1 end
    end
    return have == #meta.requires, have, #meta.requires
end

-- Records a first discovery. Returns the record and the meta achievements it
-- completed, or nil when the NPC was already found.
function Discoveries.Record(db, index, def, info)
    if db[def.id] then return nil end
    local before = {}
    for _, meta in ipairs(index.meta) do
        before[meta.id] = metaDone(db, meta)
    end
    local record = {}
    for key, value in pairs(info or {}) do record[key] = value end
    record.seen = false
    db[def.id] = record
    local completed = {}
    for _, meta in ipairs(index.meta) do
        if not before[meta.id] and metaDone(db, meta) then completed[#completed + 1] = meta end
    end
    return record, completed
end

function Discoveries.Count(db, index)
    local found = 0
    for _, def in ipairs(index.list) do
        if db[def.id] then found = found + 1 end
    end
    return found, #index.list
end

function Discoveries.Unseen(db, index)
    local count = 0
    for _, def in ipairs(index.list) do
        local record = db[def.id]
        if record and not record.seen then count = count + 1 end
    end
    return count
end

function Discoveries.MarkSeen(db, id)
    if db[id] then db[id].seen = true end
end

function Discoveries.MarkAllSeen(db)
    for _, record in pairs(db) do
        if type(record) == "table" then record.seen = true end
    end
end

-- Pages of the journal: the first one is the summary (progress, meta achievements),
-- then the list rows, perPage per page; a region header never ends a page.
function Discoveries.JournalPages(rows, perPage)
    local pages, current = { { summary = true } }, nil
    for i, row in ipairs(rows) do
        local full = current and #current.rows >= perPage
        -- A header with no room for an NPC under it starts the next page.
        local lonelyHeader = current and row.chapter and #current.rows >= perPage - 1 and rows[i + 1] ~= nil
        if not current or full or lonelyHeader then
            current = { rows = {} }
            pages[#pages + 1] = current
        end
        table.insert(current.rows, row)
    end
    return pages
end

-- Definitions grouped by chapter in book order: { { chapter, defs } }.
function Discoveries.ByChapter(index, book)
    local groups = {}
    for _, chapter in ipairs(book.chapters) do
        local defs = {}
        for _, def in ipairs(index.list) do
            if def.chapterId == chapter.id then defs[#defs + 1] = def end
        end
        if #defs > 0 then groups[#groups + 1] = { chapter = chapter, defs = defs } end
    end
    return groups
end
