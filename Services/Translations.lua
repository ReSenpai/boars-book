local _, LB = ...

-- Translations of the one book of a book edition: books[language] = book, where
-- language is a client locale (ruRU, enUS). The interface follows the chosen
-- language; a missing translation shows the original. Pure.
local Translations = {}
LB.Translations = Translations

-- Languages offered to the reader (the interface has strings for each).
Translations.LANGUAGES = { "ruRU", "enUS" }

local SHORT = { ru = "ruRU", en = "enUS" }

local function offered(language)
    for _, value in ipairs(Translations.LANGUAGES) do
        if value == language then return true end
    end
    return false
end

-- Languages for clients without one of their own.
Translations.FALLBACK = "enUS"

-- The client's language when the addon offers it, otherwise English.
function Translations.Choose(clientLocale)
    if offered(clientLocale) then return clientLocale end
    return Translations.FALLBACK
end

-- book, isOriginalFallback
function Translations.BookFor(books, language, original)
    if books[language] then return books[language], false end
    return books[original], language ~= original
end

function Translations.Next(language)
    local list = Translations.LANGUAGES
    for index, value in ipairs(list) do
        if value == language then return list[index % #list + 1] end
    end
    return list[1]
end

-- "ru", "en", "ruRU", "enUS" (any case) -> language or nil.
function Translations.Parse(text)
    text = string.lower(text or "")
    for _, value in ipairs(Translations.LANGUAGES) do
        if string.lower(value) == text then return value end
    end
    return SHORT[text]
end

function Translations.FindBook(books, bookId)
    for _, book in pairs(books) do
        if book.bookId == bookId then return book end
    end
    return nil
end

-- Problems of a translation set: the original is missing, a language is not
-- offered, or two translations share a bookId (they keep separate reading places).
function Translations.Check(books, original)
    local problems, seen = {}, {}
    if not books[original] then
        problems[#problems + 1] = "original " .. tostring(original) .. " is missing"
    end
    local languages = {}
    for language in pairs(books) do languages[#languages + 1] = language end
    table.sort(languages)
    for _, language in ipairs(languages) do
        local book = books[language]
        if not offered(language) then
            problems[#problems + 1] = "language " .. language .. " is not offered"
        end
        if seen[book.bookId] then
            problems[#problems + 1] = "bookId " .. book.bookId .. " is used by " .. seen[book.bookId] .. " and " .. language
        end
        seen[book.bookId] = language
    end
    return problems
end
