local _, LB = ...

-- Semantic reading positions: chapterId + blockId + textOffset (code points)
-- with short quotes around the position, so the place can be found again
-- after the author edits the text. Pure: no WoW API.
local ReaderState = {}
LB.ReaderState = ReaderState

local Utf8, Text = LB.Utf8, LB.Text

ReaderState.QUOTE_LENGTH = 24

-- The text that layout offsets refer to (see Paginator: items are joined by "\n").
function ReaderState.BlockText(block)
    local t = block.type
    if t == "paragraph" or t == "heading" then
        return block.text
    elseif t == "list" then
        return table.concat(block.items, "\n")
    elseif t == "checklist" then
        local parts = {}
        for i, item in ipairs(block.items) do parts[i] = item.text end
        return table.concat(parts, "\n")
    elseif t == "reference" then
        return block.label
    end
    return ""
end

local function findBlock(book, blockId)
    for c, chapter in ipairs(book.chapters) do
        for _, block in ipairs(chapter.blocks) do
            if block.id == blockId then
                return c, block
            end
        end
    end
    return nil
end

local function findChapter(book, chapterId)
    for c, chapter in ipairs(book.chapters) do
        if chapter.id == chapterId then return c end
    end
    return nil
end

function ReaderState.MakeAnchor(book, chapterId, blockId, textOffset)
    local anchor = {
        bookId = book.bookId,
        revisionSeen = book.revision,
        chapterId = chapterId,
        blockId = blockId,
        textOffset = 0,
        quoteBefore = "",
        quoteAfter = "",
    }
    local _, block = findBlock(book, blockId)
    if block then
        local text = ReaderState.BlockText(block)
        local offset = math.max(0, math.min(textOffset or 0, Utf8.Len(text)))
        anchor.textOffset = offset
        anchor.quoteBefore, anchor.quoteAfter = Text.Excerpt(text, offset, ReaderState.QUOTE_LENGTH)
    end
    return anchor
end

-- Code point offsets where `needle` occurs in `text`.
local function occurrences(text, needle)
    local result = {}
    if needle == "" then return result end
    local start = 1
    while true do
        local i = string.find(text, needle, start, true)
        if not i then break end
        result[#result + 1] = Utf8.Len(string.sub(text, 1, i - 1))
        start = i + 1
    end
    return result
end

local function nearest(candidates, target)
    local best
    for _, value in ipairs(candidates) do
        if not best or math.abs(value - target) < math.abs(best - target) then
            best = value
        end
    end
    return best
end

-- Finds the anchored position in an edited text: the full quote context first,
-- then the text after, then the text before. nil when nothing matches.
local function relocate(text, anchor)
    local before, after = anchor.quoteBefore or "", anchor.quoteAfter or ""
    local quoteBefore, quoteAfter = Text.Excerpt(text, anchor.textOffset, ReaderState.QUOTE_LENGTH)
    if quoteBefore == before and quoteAfter == after then
        return anchor.textOffset
    end
    local beforeLength = Utf8.Len(before)
    if before ~= "" or after ~= "" then
        local found = nearest(occurrences(text, before .. after), anchor.textOffset - beforeLength)
        if found then return found + beforeLength end
    end
    local found = nearest(occurrences(text, after), anchor.textOffset)
    if found then return found end
    found = nearest(occurrences(text, before), anchor.textOffset - beforeLength)
    if found then return found + beforeLength end
    return nil
end

-- Returns { chapterIndex, blockId?, textOffset, changed }.
-- `changed` means the edition changed and the exact place could not be kept.
function ReaderState.Resolve(book, anchor)
    if type(anchor) ~= "table" then
        return { chapterIndex = 1, textOffset = 0, changed = false }
    end
    local offset = type(anchor.textOffset) == "number" and anchor.textOffset or 0
    local chapterIndex, block = nil, nil
    if type(anchor.blockId) == "string" then
        chapterIndex, block = findBlock(book, anchor.blockId)
    end
    if not block then
        local byChapter = type(anchor.chapterId) == "string" and findChapter(book, anchor.chapterId)
        return { chapterIndex = byChapter or 1, textOffset = 0, changed = anchor.blockId ~= nil or anchor.chapterId ~= nil }
    end
    local text = ReaderState.BlockText(block)
    local length = Utf8.Len(text)
    if anchor.revisionSeen == book.revision then
        return { chapterIndex = chapterIndex, blockId = block.id, textOffset = math.min(offset, length), changed = false }
    end
    local relocated = relocate(text, { textOffset = offset, quoteBefore = anchor.quoteBefore, quoteAfter = anchor.quoteAfter })
    if relocated then
        return { chapterIndex = chapterIndex, blockId = block.id, textOffset = relocated, changed = false }
    end
    return { chapterIndex = chapterIndex, blockId = block.id, textOffset = 0, changed = true }
end

function ReaderState.SavePosition(store, anchor)
    if store.readOnly or not anchor or not anchor.bookId then
        return false
    end
    store.account.readingPositions[anchor.bookId] = anchor
    return true
end

function ReaderState.GetPosition(store, bookId)
    return store.account.readingPositions[bookId]
end
