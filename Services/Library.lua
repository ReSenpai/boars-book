local _, LB = ...

-- Library views (all, favorites, recent, collections) and search. Pure: works on
-- the store passed in. Search ignores case and treats ё as е.
local Library = {}
LB.Library = Library

local Text, Utf8 = LB.Text, LB.Utf8
local BytewiseLess = LB.Tables.BytewiseLess

Library.MAX_RECENT = 20

-- Session cache of search keys per book edition.
local indexCache = setmetatable({}, { __mode = "k" })

local function metaKey(book)
    return Text.SearchKey(table.concat({ book.title, book.authorName, table.concat(book.tags, "\n") }, "\n"))
end

local function contentKey(book)
    local parts = {}
    for _, chapter in ipairs(book.chapters) do
        parts[#parts + 1] = chapter.title
        for _, block in ipairs(chapter.blocks) do
            parts[#parts + 1] = LB.ReaderState.BlockText(block)
            if block.type == "facts" then
                for _, row in ipairs(block.rows) do
                    parts[#parts + 1] = row.label .. " " .. row.value
                end
            elseif block.type == "figure" then
                parts[#parts + 1] = block.alt .. " " .. block.caption
            end
        end
    end
    return Text.SearchKey(table.concat(parts, "\n"))
end

local function bookIndex(book)
    local index = indexCache[book]
    if not index then
        index = { meta = metaKey(book) }
        indexCache[book] = index
    end
    return index
end

local function queryWords(text)
    local words = {}
    for word in string.gmatch(Text.SearchKey(text or ""), "%S+") do
        words[#words + 1] = word
    end
    return words
end

local function containsAll(haystack, words)
    for _, word in ipairs(words) do
        if not string.find(haystack, word, 1, true) then
            return false
        end
    end
    return true
end

-- Returns true (meta match), true + "content", or false.
local function matches(book, words, searchContent)
    if #words == 0 then return true, false end
    local index = bookIndex(book)
    if containsAll(index.meta, words) then return true, false end
    if searchContent then
        index.content = index.content or contentKey(book)
        if containsAll(index.content, words) then return true, true end
    end
    return false, false
end

local function candidateIds(store, options)
    local db = store.account
    local filter = options.filter or "all"
    local result = {}
    if filter == "favorites" then
        for bookId in pairs(db.favorites) do result[#result + 1] = bookId end
    elseif filter == "recent" then
        for _, bookId in ipairs(db.recent) do result[#result + 1] = bookId end
    elseif filter == "collection" then
        local collection = db.collections[options.collectionId]
        for _, bookId in ipairs(collection and collection.bookIds or {}) do result[#result + 1] = bookId end
    else
        for bookId in pairs(db.books) do result[#result + 1] = bookId end
    end
    return result, filter == "recent"
end

-- options: filter = all | favorites | recent | collection, collectionId, text, searchContent.
-- Returns book summaries; recent keeps recency order, others are sorted by title.
function Library.Query(store, options)
    options = options or {}
    local words = queryWords(options.text)
    local ids, keepOrder = candidateIds(store, options)
    local result = {}
    for _, bookId in ipairs(ids) do
        local entry = store.account.books[bookId]
        if entry then
            local book = entry.current
            local ok, inContent = matches(book, words, options.searchContent)
            if ok then
                result[#result + 1] = {
                    bookId = bookId, title = book.title, authorName = book.authorName,
                    revision = book.revision, tags = book.tags, source = entry.source,
                    favorite = store.account.favorites[bookId] == true,
                    contentMatch = inContent, sortKey = Text.SearchKey(book.title),
                }
            end
        end
    end
    if not keepOrder then
        table.sort(result, function(a, b)
            if a.sortKey ~= b.sortKey then return BytewiseLess(a.sortKey, b.sortKey) end
            return BytewiseLess(a.bookId, b.bookId)
        end)
    end
    return result
end

function Library.IsFavorite(store, bookId)
    return store.account.favorites[bookId] == true
end

-- Returns the new favorite state, or nil in read-only mode.
function Library.ToggleFavorite(store, bookId)
    if store.readOnly then return nil end
    local favorites = store.account.favorites
    favorites[bookId] = not favorites[bookId] or nil
    return favorites[bookId] == true
end

function Library.MarkRecent(store, bookId)
    if store.readOnly then return end
    local recent = { bookId }
    for _, id in ipairs(store.account.recent) do
        if id ~= bookId and #recent < Library.MAX_RECENT then
            recent[#recent + 1] = id
        end
    end
    store.account.recent = recent
end

-- Collections -----------------------------------------------------------------

function Library.CreateCollection(store, name)
    if store.readOnly then return nil end
    local collections = store.account.collections
    local n = 1
    while collections["col" .. n] do n = n + 1 end
    local id = "col" .. n
    collections[id] = { name = name, bookIds = {} }
    return id
end

function Library.RenameCollection(store, id, name)
    local collection = store.account.collections[id]
    if store.readOnly or not collection then return false end
    collection.name = name
    return true
end

function Library.DeleteCollection(store, id)
    if store.readOnly then return false end
    store.account.collections[id] = nil
    return true
end

function Library.AddToCollection(store, id, bookId)
    local collection = store.account.collections[id]
    if store.readOnly or not collection then return false end
    for _, existing in ipairs(collection.bookIds) do
        if existing == bookId then return true end
    end
    collection.bookIds[#collection.bookIds + 1] = bookId
    return true
end

function Library.RemoveFromCollection(store, id, bookId)
    local collection = store.account.collections[id]
    if store.readOnly or not collection then return false end
    for i = #collection.bookIds, 1, -1 do
        if collection.bookIds[i] == bookId then table.remove(collection.bookIds, i) end
    end
    return true
end

function Library.ListCollections(store)
    local list = {}
    for id, collection in pairs(store.account.collections) do
        list[#list + 1] = { id = id, name = collection.name, count = #collection.bookIds,
            sortKey = Text.SearchKey(collection.name) }
    end
    table.sort(list, function(a, b)
        if a.sortKey ~= b.sortKey then return BytewiseLess(a.sortKey, b.sortKey) end
        return BytewiseLess(a.id, b.id)
    end)
    return list
end

-- In-book search --------------------------------------------------------------

-- All occurrences of the phrase in block texts, in reading order:
-- { chapterIndex, chapterId, blockId, textOffset, length } with code point offsets.
function Library.SearchInBook(book, query)
    local needle = Text.SearchKey((string.gsub(query or "", "^%s+", ""):gsub("%s+$", "")))
    local result = {}
    if needle == "" then return result end
    local length = Utf8.Len(needle)
    for c, chapter in ipairs(book.chapters) do
        for _, block in ipairs(chapter.blocks) do
            local haystack = Text.SearchKey(LB.ReaderState.BlockText(block))
            local start = 1
            while true do
                local i = string.find(haystack, needle, start, true)
                if not i then break end
                result[#result + 1] = {
                    chapterIndex = c, chapterId = chapter.id, blockId = block.id,
                    textOffset = Utf8.Len(string.sub(haystack, 1, i - 1)), length = length,
                }
                start = i + #needle
            end
        end
    end
    return result
end
