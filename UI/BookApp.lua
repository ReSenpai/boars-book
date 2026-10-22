local _, LB = ...

-- The book edition around the shared reader: which translation is open, the
-- language button over the pages, opening and closing the book.
local BookApp = {}
LB.BookApp = BookApp

local L = LB.L
local Translations = LB.Translations

local function manifest()
    return LB.BookManifest
end

local function books()
    return LB.Books or {}
end

function BookApp.Language()
    return BookApp.language
end

-- The book in the chosen language (the original while a translation is missing).
function BookApp.CurrentBook()
    return Translations.BookFor(books(), BookApp.language, manifest().original)
end

-- Product name for chat and help, in the chosen language.
function BookApp.Title()
    local titles = manifest().title or {}
    return titles[BookApp.language] or titles[manifest().original] or LB.ADDON_NAME
end

local function applyLanguage(language)
    BookApp.language = language
    LB.Locale.SetActive(language)
    local frame = LB.Reader.frame
    if frame and type(frame.languageButton) == "table" then
        frame.languageButton:SetText(L("LANGUAGE_" .. language))
    end
    if LB.DiscoveryJournal and LB.store then LB.DiscoveryJournal.Refresh() end
end

-- The language follows the client on every login; the language button switches it
-- for the session only.
function BookApp.Init(store, clientLocale)
    applyLanguage(Translations.Choose(clientLocale))
    BookApp.warned = false
end

local function warnIfOriginal()
    local _, fallback = BookApp.CurrentBook()
    if fallback and not BookApp.warned then
        BookApp.warned = true
        LB.Commands.Print(L("TRANSLATION_MISSING"))
    end
end

function BookApp.OpenReader()
    local book = BookApp.CurrentBook()
    warnIfOriginal()
    return LB.Reader.Open(book.bookId)
end

function BookApp.ToggleReader()
    if LB.Reader.IsShown() then
        LB.MainWindow.Hide()
    else
        BookApp.OpenReader()
    end
end

local function chapterOf(book, chapterId)
    for _, chapter in ipairs(book.chapters) do
        if chapter.id == chapterId then return chapter end
    end
    return nil
end

-- One more page window over the book: on the reader's page when the book is
-- open, otherwise on the saved reading place.
function BookApp.OpenWindow()
    warnIfOriginal()
    local book = BookApp.CurrentBook()
    local anchor
    if LB.Reader.IsShown() and LB.Reader.state then
        local state = LB.Reader.state
        anchor = LB.Reader.CurrentAnchor() or {}
        anchor.chapterId = state.book.chapters[state.chapterIndex].id
    else
        anchor = LB.ReaderState.GetPosition(LB.store, book.bookId)
    end
    return LB.PageWindows.Open(book, anchor)
end

-- Switches the interface and the book; open windows stay on the same passage
-- (translations keep the original's chapter and block ids).
function BookApp.SetLanguage(language)
    local readerShown = LB.Reader.IsShown()
    local readerChapter, readerAnchor
    if readerShown then
        local state = LB.Reader.state
        readerChapter = state.book.chapters[state.chapterIndex].id
        readerAnchor = LB.Reader.CurrentAnchor()
    end

    applyLanguage(language)
    BookApp.warned = false
    warnIfOriginal()

    local book = BookApp.CurrentBook()
    if readerShown and LB.Reader.Open(book.bookId) and readerChapter and chapterOf(book, readerChapter) then
        local blockId = readerAnchor and readerAnchor.blockId
        LB.Reader.GoToAnchor(LB.ReaderState.MakeAnchor(book, readerChapter, blockId or "", 0))
    end
    LB.PageWindows.SwitchBook(book)
end

local function createLanguageButton(frame)
    local button = LB.Widgets.Button(frame, L("LANGUAGE_" .. (BookApp.language or "enUS")), 110, function()
        BookApp.SetLanguage(Translations.Next(BookApp.language))
    end)
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -31)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L("LANGUAGE_TOOLTIP"))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.languageButton = button
end

-- Books come from this addon's translations, never from a library.
LB.Reader.FindBook = function(bookId)
    return Translations.FindBook(books(), bookId)
end

-- The icon over the pages opens another page window; the book stays open.
LB.Reader.Detach = function() BookApp.OpenWindow() end

LB.Reader.OnFrameCreated(createLanguageButton)
