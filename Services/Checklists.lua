local _, LB = ...

-- Manual checklist marks of the current character:
-- LoreBookCharacterDB.checklists[bookId][blockId][itemId] = true.
-- Marks are addressed by stable IDs only. Pure: no WoW API.
local Checklists = {}
LB.Checklists = Checklists

local function marksFor(store, bookId, blockId, create)
    local books = store.character.checklists
    local blocks = books[bookId]
    if not blocks then
        if not create then return nil end
        blocks = {}
        books[bookId] = blocks
    end
    local items = blocks[blockId]
    if not items and create then
        items = {}
        blocks[blockId] = items
    end
    return items
end

function Checklists.IsChecked(store, bookId, blockId, itemId)
    local items = marksFor(store, bookId, blockId, false)
    return items ~= nil and items[itemId] == true
end

-- Returns the new state (false in read-only mode).
function Checklists.Toggle(store, bookId, blockId, itemId)
    if store.readOnly then return false end
    local items = marksFor(store, bookId, blockId, true)
    items[itemId] = not items[itemId] or nil
    return items[itemId] == true
end

local function chapterChecklists(book, chapterId)
    for _, chapter in ipairs(book.chapters) do
        if chapter.id == chapterId then
            local result = {}
            for _, block in ipairs(chapter.blocks) do
                if block.type == "checklist" then result[#result + 1] = block end
            end
            return result
        end
    end
    return {}
end

-- Returns done, total for the checklist items of one chapter.
function Checklists.CountChapter(store, book, chapterId)
    local done, total = 0, 0
    for _, block in ipairs(chapterChecklists(book, chapterId)) do
        for _, item in ipairs(block.items) do
            total = total + 1
            if Checklists.IsChecked(store, book.bookId, block.id, item.id) then done = done + 1 end
        end
    end
    return done, total
end

function Checklists.ResetChapter(store, book, chapterId)
    if store.readOnly then return false end
    local blocks = store.character.checklists[book.bookId]
    if not blocks then return true end
    for _, block in ipairs(chapterChecklists(book, chapterId)) do
        blocks[block.id] = nil
    end
    return true
end
