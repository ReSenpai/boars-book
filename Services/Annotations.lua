local _, LB = ...

-- Personal annotations, kept apart from the public edition:
--   bookmarks: account-wide, LoreBookDB.bookmarks[bookId] = { bookmark... }
--   notes: per character, LoreBookCharacterDB.notes[bookId] = { note... }
-- Both use semantic anchors (chapterId, blockId, textOffset, quotes). Notes whose
-- block disappears become "orphaned" and are kept. Pure: no WoW API.
local Annotations = {}
LB.Annotations = Annotations

local Utf8 = LB.Utf8

Annotations.MAX_NOTE_LENGTH = 500

local function trim(s)
    return (string.gsub(string.gsub(s or "", "^%s+", ""), "%s+$", ""))
end

local function blockPosition(book, blockId)
    for c, chapter in ipairs(book.chapters) do
        for b, block in ipairs(chapter.blocks) do
            if block.id == blockId then
                return c, b, chapter.id
            end
        end
    end
    return nil
end

local function nextId(list, prefix)
    local max = 0
    for _, item in ipairs(list) do
        local n = tonumber(string.match(item.id or "", "^" .. prefix .. "(%d+)$"))
        if n and n > max then max = n end
    end
    return prefix .. (max + 1)
end

local function anchored(book, chapterId, blockId, textOffset)
    return LB.ReaderState.MakeAnchor(book, chapterId, blockId, textOffset)
end

-- Sorts annotations by position in the book; ones whose block is missing go last.
local function sortByReadingOrder(book, list)
    local keyed = {}
    for i, item in ipairs(list) do
        local c, b = blockPosition(book, item.blockId)
        keyed[i] = { item = item, c = c or math.huge, b = b or math.huge, o = item.textOffset or 0, i = i }
    end
    table.sort(keyed, function(x, y)
        if x.c ~= y.c then return x.c < y.c end
        if x.b ~= y.b then return x.b < y.b end
        if x.o ~= y.o then return x.o < y.o end
        return x.i < y.i
    end)
    local result = {}
    for i, entry in ipairs(keyed) do result[i] = entry.item end
    return result
end

local function listFor(db, bookId)
    db[bookId] = db[bookId] or {}
    return db[bookId]
end

local function findIndex(list, id)
    for i, item in ipairs(list or {}) do
        if item.id == id then return i end
    end
    return nil
end

-- Bookmarks -------------------------------------------------------------------

function Annotations.AddBookmark(store, book, chapterId, blockId, textOffset, label)
    if store.readOnly then return nil end
    local list = listFor(store.account.bookmarks, book.bookId)
    local bookmark = anchored(book, chapterId, blockId, textOffset)
    bookmark.id = nextId(list, "bm")
    bookmark.label = label
    bookmark.createdAt = store.now()
    list[#list + 1] = bookmark
    return bookmark
end

function Annotations.RemoveBookmark(store, bookId, id)
    local list = store.account.bookmarks[bookId]
    local index = findIndex(list, id)
    if store.readOnly or not index then return false end
    table.remove(list, index)
    return true
end

function Annotations.ListBookmarks(store, book)
    return sortByReadingOrder(book, store.account.bookmarks[book.bookId] or {})
end

-- Notes -----------------------------------------------------------------------

local function validateText(text)
    text = trim(text)
    if text == "" then return nil, "NOTE_EMPTY" end
    if Utf8.Len(text) > Annotations.MAX_NOTE_LENGTH then return nil, "NOTE_TOO_LONG" end
    return text
end

-- Returns the note, or nil and an error code (NOTE_EMPTY, NOTE_TOO_LONG, STORAGE_READ_ONLY).
function Annotations.AddNote(store, book, chapterId, blockId, textOffset, text)
    if store.readOnly then return nil, "STORAGE_READ_ONLY" end
    local clean, err = validateText(text)
    if not clean then return nil, err end
    local list = listFor(store.character.notes, book.bookId)
    local note = anchored(book, chapterId, blockId, textOffset)
    note.id = nextId(list, "n")
    note.text = clean
    note.createdAt = store.now()
    note.status = "attached"
    list[#list + 1] = note
    return note
end

function Annotations.GetNote(store, bookId, id)
    local list = store.character.notes[bookId]
    local index = findIndex(list, id)
    return index and list[index] or nil
end

function Annotations.EditNote(store, bookId, id, text)
    local note = Annotations.GetNote(store, bookId, id)
    local clean = validateText(text)
    if store.readOnly or not note or not clean then return false end
    note.text = clean
    return true
end

function Annotations.RemoveNote(store, bookId, id)
    local list = store.character.notes[bookId]
    local index = findIndex(list, id)
    if store.readOnly or not index then return false end
    table.remove(list, index)
    return true
end

-- Attached notes of the current edition, in reading order.
function Annotations.ListNotes(store, book)
    local attached = {}
    for _, note in ipairs(store.character.notes[book.bookId] or {}) do
        if note.status ~= "orphaned" and blockPosition(book, note.blockId) then
            attached[#attached + 1] = note
        end
    end
    return sortByReadingOrder(book, attached)
end

-- "Notes to a previous edition": notes whose block no longer exists.
function Annotations.ListOrphanedNotes(store, bookId)
    local orphaned = {}
    for _, note in ipairs(store.character.notes[bookId] or {}) do
        if note.status == "orphaned" then orphaned[#orphaned + 1] = note end
    end
    return orphaned
end

-- Matches notes to an edition by stable block IDs. Never deletes a note and never
-- moves it to another block by position.
function Annotations.Reconcile(store, book)
    local result = { attached = 0, orphaned = 0 }
    if store.readOnly then return result end
    for _, note in ipairs(store.character.notes[book.bookId] or {}) do
        local c, _, chapterId = blockPosition(book, note.blockId)
        if c then
            note.status = "attached"
            note.chapterId = chapterId
            result.attached = result.attached + 1
        else
            note.status = "orphaned"
            result.orphaned = result.orphaned + 1
        end
    end
    return result
end

-- Page placement ----------------------------------------------------------------

-- Anchored items visible on a laid-out page: { { item, y } } in input order.
-- An item belongs to the line whose block offset is the last one at or before it.
function Annotations.OnPage(page, items)
    local placed = {}
    for _, item in ipairs(items) do
        local best
        for _, unit in ipairs(page.units) do
            if unit.blockId == item.blockId and unit.offset <= (item.textOffset or 0) then
                best = unit
            end
        end
        if best then
            placed[#placed + 1] = { item = item, y = best.y }
        end
    end
    return placed
end
