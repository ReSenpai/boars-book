local _, LB = ...

-- Bookmarks and notes inside the reader: ribbon on bookmarked pages, note markers
-- in the margin (they never change pagination) and lists in the contents panel.
local ReaderAnnotations = {}
LB.ReaderAnnotations = ReaderAnnotations

local L = LB.L
local Theme = LB.Theme
local Annotations = LB.Annotations
local Escape = LB.Text.EscapeForUI

local NOTE_ICON = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"
local ENTRY_HEIGHT = 22
local HEADER_HEIGHT = 26
local LABEL_LENGTH = 48

local function shorten(text)
    if LB.Utf8.Len(text) <= LABEL_LENGTH then return text end
    return LB.Utf8.Sub(text, 1, LABEL_LENGTH) .. "..."
end

local function openNote(note)
    LB.NotePopup.Open({ book = LB.Reader.state.book, note = note, onChange = LB.Reader.Render })
end

function ReaderAnnotations.SetupPage(page)
    page.ribbon = page:CreateTexture(nil, "OVERLAY")
    page.ribbon:SetSize(14, 44)
    page.ribbon:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 8)
    LB.Widgets.SetColor(page.ribbon, Theme.colors.button)
    page.ribbon:Hide()
    page.markerPool = LB.WidgetPool.New(function()
        local marker = CreateFrame("Button", nil, page)
        marker:SetSize(16, 16)
        marker:SetNormalTexture(NOTE_ICON)
        marker:SetScript("OnClick", function(self) openNote(self.note) end)
        marker:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(Escape(self.note.text), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        marker:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return marker
    end, function(marker)
        marker:Hide()
        marker:ClearAllPoints()
    end)
end

function ReaderAnnotations.DrawPage(page, layoutPage)
    page.markerPool:ReleaseAll()
    page.ribbon:Hide()
    if not layoutPage then return end
    local store, book = LB.store, LB.Reader.state.book
    if #Annotations.OnPage(layoutPage, Annotations.ListBookmarks(store, book)) > 0 then
        page.ribbon:Show()
    end
    for _, placed in ipairs(Annotations.OnPage(layoutPage, Annotations.ListNotes(store, book))) do
        local marker = page.markerPool:Acquire()
        marker.note = placed.item
        marker:SetPoint("TOPLEFT", page, "TOPLEFT", -20, -placed.y)
        marker:Show()
    end
end

-- Adds a bookmark at the current view, or removes the bookmarks shown in it.
function ReaderAnnotations.ToggleBookmark()
    local Reader = LB.Reader
    local state = Reader.state
    if not state then return end
    local store, book = LB.store, state.book
    local bookmarks = Annotations.ListBookmarks(store, book)
    local removed = false
    for _, shown in ipairs(Reader.VisiblePages()) do
        for _, placed in ipairs(Annotations.OnPage(shown.layout.pages[shown.pageIndex], bookmarks)) do
            Annotations.RemoveBookmark(store, book.bookId, placed.item.id)
            removed = true
        end
    end
    if not removed then
        local chapter = book.chapters[state.chapterIndex]
        local anchor = Reader.CurrentAnchor()
        Annotations.AddBookmark(store, book, chapter.id, anchor and anchor.blockId or chapter.blocks[1].id,
            anchor and anchor.textOffset or 0, chapter.title)
    end
    Reader.Render()
end

function ReaderAnnotations.NoteForCurrentPage()
    local Reader = LB.Reader
    local state = Reader.state
    if not state then return end
    local chapter = state.book.chapters[state.chapterIndex]
    local anchor = Reader.CurrentAnchor()
    LB.NotePopup.Open({
        book = state.book,
        anchor = {
            chapterId = chapter.id,
            blockId = anchor and anchor.blockId or chapter.blocks[1].id,
            textOffset = anchor and anchor.textOffset or 0,
        },
        onChange = Reader.Render,
    })
end

function ReaderAnnotations.SetupContents(contents)
    contents.headerPool = LB.WidgetPool.New(function()
        local fs = contents:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(LB.Fonts.Get("heading3"))
        fs:SetJustifyH("LEFT")
        return fs
    end, function(fs)
        fs:Hide()
        fs:ClearAllPoints()
    end)
    contents.annotationPool = LB.WidgetPool.New(function()
        local entry = LB.Widgets.TextRow(contents, LB.Fonts.Get("body"), function(self)
            if self.kind == "orphan" then
                openNote(self.item)
            elseif self.item then
                LB.Reader.GoToAnchor(self.item)
            end
        end)
        return entry
    end, function(entry)
        entry:Hide()
        entry:ClearAllPoints()
        entry.item, entry.kind = nil, nil
    end)
end

-- Fills the right column of the contents panel starting at (x, top).
function ReaderAnnotations.FillContents(contents, x, top, width, height)
    local store, book = LB.store, LB.Reader.state.book
    contents.headerPool:ReleaseAll()
    contents.annotationPool:ReleaseAll()
    local y = top

    local function header(text)
        if y + HEADER_HEIGHT > height then return false end
        local fs = contents.headerPool:Acquire()
        fs:SetText(text)
        fs:SetPoint("TOPLEFT", contents, "TOPLEFT", x + 6, -y)
        fs:Show()
        y = y + HEADER_HEIGHT
        return true
    end

    local function entry(kind, item, text)
        if y + ENTRY_HEIGHT > height then return end
        local row = contents.annotationPool:Acquire()
        row.kind, row.item = kind, item
        row:SetSize(width - 8, ENTRY_HEIGHT)
        row.label:SetWidth(width - 20)
        row.label:SetText(text)
        row:SetPoint("TOPLEFT", contents, "TOPLEFT", x, -y)
        row:Show()
        y = y + ENTRY_HEIGHT
    end

    local function section(title, kind, items, label)
        if not header(title) then return end
        if #items == 0 then
            entry("empty", nil, L("READER_NONE"))
        end
        for _, item in ipairs(items) do
            entry(kind, item, Escape(shorten(label(item))))
        end
        y = y + 8
    end

    section(L("READER_BOOKMARKS"), "bookmark", Annotations.ListBookmarks(store, book),
        function(item) return item.label or "" end)
    section(L("READER_NOTES"), "note", Annotations.ListNotes(store, book),
        function(item) return item.text end)
    local orphans = Annotations.ListOrphanedNotes(store, book.bookId)
    if #orphans > 0 then
        section(L("READER_ORPHANED_NOTES"), "orphan", orphans, function(item) return item.text end)
    end
end
