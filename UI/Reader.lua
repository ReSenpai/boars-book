local _, LB = ...

-- Reader window: two-page spread or single page. Layout, navigation, geometry and
-- positions are decided by pure modules; this file owns frames and widgets.
local Reader = {}
LB.Reader = Reader

local L = LB.L
local Theme = LB.Theme
local Escape = LB.Text.EscapeForUI

-- Pages lie inside the panel inset (Widgets.PANEL_TOP / PANEL_BOTTOM), away from
-- the aged edges of the parchment.
Reader.INSET_X, Reader.INSET_TOP, Reader.INSET_BOTTOM = 40, 84, 64
-- Page sheets reach this far past the page (single page view).
Reader.SHEET_MARGIN = 36
Reader.DEMO_BOOK_ID = "demo.pathfinder.001"
-- Icon of the button that moves the reading into the field guide window.
Reader.DETACH_ICON = "Interface\\Icons\\INV_Misc_Note_01"

local CONTENTS_ENTRY_HEIGHT = 26
local CONTENTS_HEADER_HEIGHT = 40

local setColor = LB.Widgets.SetColor

-- A book edition is read only: no bookmarks, notes, sharing or library.
local function withAnnotations()
    return not LB.IsBookEdition()
end

local function createPage(parent)
    return LB.PageView.Create(parent, { annotations = withAnnotations() })
end

local createButton = LB.Widgets.Button

local function createSearchBar(frame)
    local bar = CreateFrame("Frame", nil, frame)
    -- Replaces the pin button in the band between the title bar and the pages.
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 62, -30)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    bar:SetHeight(28)
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.label:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.returnButton = createButton(bar, L("READER_SEARCH_RETURN"), 170, function() Reader.ExitSearch() end)
    bar.returnButton:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    bar.nextButton = createButton(bar, ">", 32, function() Reader.SearchStep(1) end)
    bar.nextButton:SetPoint("RIGHT", bar.returnButton, "LEFT", -8, 0)
    bar.prevButton = createButton(bar, "<", 32, function() Reader.SearchStep(-1) end)
    bar.prevButton:SetPoint("RIGHT", bar.nextButton, "LEFT", -4, 0)
    bar:Hide()
    return bar
end

local function createContents(frame)
    local contents = CreateFrame("Frame", nil, frame)
    contents:SetAllPoints(frame.pageArea)
    contents:SetFrameLevel(frame.pageArea:GetFrameLevel() + 10)
    contents:EnableMouse(true)
    contents.background = contents:CreateTexture(nil, "BACKGROUND")
    contents.background:SetAllPoints(contents)
    LB.Widgets.ApplyParchment(contents.background)
    contents.header = contents:CreateFontString(nil, "OVERLAY")
    contents.header:SetFontObject(LB.Fonts.Get("heading2"))
    contents.header:SetPoint("TOP", contents, "TOP", 0, -4)
    contents.entryPool = LB.WidgetPool.New(function()
        local entry = CreateFrame("Button", nil, contents)
        entry:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        entry.label = entry:CreateFontString(nil, "OVERLAY")
        entry.label:SetPoint("LEFT", entry, "LEFT", 6, 0)
        entry.label:SetJustifyH("LEFT")
        entry.label:SetWordWrap(false)
        entry:SetScript("OnClick", function(self) Reader.GoToChapter(self.chapterIndex) end)
        return entry
    end, function(entry)
        entry:Hide()
        entry:ClearAllPoints()
    end)
    LB.ReaderAnnotations.SetupContents(contents)
    contents:Hide()
    return contents
end

-- The reader is a view of the shared library/reader window (LB.MainWindow).
local function createFrame()
    local frame = LB.MainWindow.AddView("reader", { onResize = function() Reader.Relayout() end })
    frame:EnableKeyboard(false)

    frame.pageArea = CreateFrame("Frame", nil, frame)
    frame.pageArea:SetPoint("TOPLEFT", frame, "TOPLEFT", Reader.INSET_X, -Reader.INSET_TOP)
    frame.pageArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Reader.INSET_X, Reader.INSET_BOTTOM)
    frame.pageArea:EnableMouse(true)
    frame.pageArea:EnableMouseWheel(true)
    frame.pageArea:SetScript("OnMouseWheel", function(_, delta) Reader.Step(delta > 0 and -1 or 1) end)
    frame.pageArea:SetScript("OnMouseDown", function() Reader.Focus() end)

    frame.pages = { createPage(frame.pageArea), createPage(frame.pageArea) }
    frame.spine = frame.pageArea:CreateTexture(nil, "ARTWORK")
    frame.spine:SetWidth(1)
    setColor(frame.spine, Theme.colors.brass, 0.5)

    frame.prev = createButton(frame, "<", 40, function() Reader.Step(-1) end)
    frame.prev:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 12)
    frame.next = createButton(frame, ">", 40, function() Reader.Step(1) end)
    frame.next:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 12)
    if withAnnotations() then
        Reader.CreateToolbar(frame)
    end

    frame.pageLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.pageLabel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 18)

    frame.detachButton = LB.Widgets.IconButton(frame, Reader.DETACH_ICON, 26, function()
        return L(LB.IsBookEdition() and "READER_DETACH_BOOK" or "READER_DETACH")
    end, function() Reader.Detach() end)
    frame.detachButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 64, -31)

    frame.contents = createContents(frame)
    frame.searchBar = createSearchBar(frame)

    frame:SetScript("OnKeyDown", function(self, key)
        local action = LB.ReaderView.KeyAction(key, Reader.focused)
        if LB.Compat.InCombat() then return end
        if action then
            self:SetPropagateKeyboardInput(false)
            Reader.Step(action)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    frame:SetScript("OnHide", function() Reader.ClearFocus() end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function() Reader.ClearFocus() end)
    return frame
end

-- Library edition buttons between the page arrows: contents, library, sharing, notes.
function Reader.CreateToolbar(frame)
    frame.contentsButton = createButton(frame, L("READER_CONTENTS"), 120, function() Reader.ToggleContents() end)
    frame.contentsButton:SetPoint("BOTTOMLEFT", frame.prev, "BOTTOMRIGHT", 8, 0)
    frame.libraryButton = createButton(frame, L("LIBRARY"), 110, function() LB.LibraryWindow.Open() end)
    frame.libraryButton:SetPoint("BOTTOMLEFT", frame.contentsButton, "BOTTOMRIGHT", 8, 0)
    frame.shareButton = createButton(frame, L("LIBRARY_SHARE"), 110, function()
        if Reader.state then LB.ShareDialog.Open(Reader.state.bookId) end
    end)
    frame.shareButton:SetPoint("BOTTOMRIGHT", frame.next, "BOTTOMLEFT", -8, 0)
    frame.noteButton = createButton(frame, L("READER_NOTE"), 100, function()
        LB.ReaderAnnotations.NoteForCurrentPage()
    end)
    frame.noteButton:SetPoint("BOTTOMRIGHT", frame.shareButton, "BOTTOMLEFT", -8, 0)
    frame.bookmarkButton = createButton(frame, L("READER_BOOKMARK"), 100, function()
        LB.ReaderAnnotations.ToggleBookmark()
    end)
    frame.bookmarkButton:SetPoint("BOTTOMRIGHT", frame.noteButton, "BOTTOMLEFT", -8, 0)
end

local frameHooks = {}

-- fn(frame) runs once the reader frame exists (a book edition adds its controls).
function Reader.OnFrameCreated(fn)
    frameHooks[#frameHooks + 1] = fn
    if Reader.frame then fn(Reader.frame) end
end

local function ensureFrame()
    if not Reader.frame then
        Reader.frame = createFrame()
        Reader.measurer = LB.TextMeasurer.New(Reader.frame)
        Reader.cache = LB.LayoutCache.New()
        LB.PageView.OnChecklistChanged(function()
            if Reader.IsShown() and Reader.state then Reader.Render() end
        end)
        for _, fn in ipairs(frameHooks) do fn(Reader.frame) end
    end
    return Reader.frame
end

-- Where books come from: the library by default; a book edition replaces it.
function Reader.FindBook(bookId)
    return LB.Storage.GetBook(LB.store, bookId)
end

-- The detach button pins the current chapter next to the game world; a book
-- edition replaces this with its own page windows (editions/book/UI/PageWindows.lua).
function Reader.Detach()
    local state = Reader.state
    if not state then return end
    LB.FieldGuide.Open(state.bookId, state.book.chapters[state.chapterIndex].id)
end

function Reader.IsShown()
    return LB.MainWindow.IsShowing("reader")
end

local function computeGeometry()
    local windowWidth, windowHeight = LB.MainWindow.Size()
    local width = windowWidth - 2 * Reader.INSET_X
    local height = windowHeight - Reader.INSET_TOP - Reader.INSET_BOTTOM
    Reader.geometry = LB.ReaderView.Geometry(width, height, LB.Fonts.GetBodySize())
    return Reader.geometry
end

function Reader.Layout(chapterIndex)
    local book, g = Reader.state.book, Reader.geometry
    local chapter = book.chapters[chapterIndex]
    local key = LB.LayoutCache.Key(book.bookId, book.revision, chapter.id, g.pageWidth, g.pageHeight, LB.Fonts.Key())
    local layout = Reader.cache:Get(key)
    if not layout then
        layout = LB.Paginator.Paginate(chapter, { width = g.pageWidth, height = g.pageHeight }, Reader.measurer,
            { figureAspect = LB.Assets.Aspect })
        Reader.cache:Put(key, layout)
    end
    return layout
end

-- One page sequence for the whole book (every chapter laid out, cached per chapter).
function Reader.Flow()
    local counts = {}
    for index in ipairs(Reader.state.book.chapters) do
        counts[index] = #Reader.Layout(index).pages
    end
    return LB.ReaderNav.Flow(counts)
end

-- Moves the view to the one containing page `pageIndex` of a chapter; that
-- chapter stays the current one even when it starts on the right page.
local function setPosition(chapterIndex, pageIndex)
    Reader.state.focusChapter = chapterIndex
    local flow = Reader.Flow()
    pageIndex = math.max(1, math.min(pageIndex or 1, flow.counts[chapterIndex]))
    Reader.state.page = LB.ReaderView.ViewStart(LB.ReaderNav.ToGlobal(flow, chapterIndex, pageIndex),
        Reader.geometry.pagesPerView)
end

-- Pages in view, left to right: { { chapterIndex, pageIndex, layout } }.
function Reader.VisiblePages()
    local flow, visible = Reader.Flow(), {}
    for page = Reader.state.page, Reader.state.page + Reader.geometry.pagesPerView - 1 do
        local chapterIndex, pageIndex = LB.ReaderNav.ToLocal(flow, page)
        if chapterIndex then
            visible[#visible + 1] = { chapterIndex = chapterIndex, pageIndex = pageIndex, layout = Reader.Layout(chapterIndex) }
        end
    end
    return visible
end

local function currentHighlight()
    local match = Reader.search and Reader.search:Current()
    if not match then return nil end
    return { blockId = match.blockId, from = match.textOffset, to = match.textOffset + match.length }
end

local function drawPage(page, layoutPage)
    LB.PageView.Draw(page, layoutPage, Reader.measurer, {
        book = Reader.state.book, highlight = currentHighlight(), annotations = withAnnotations(),
    })
end

local function positionPages(frame, g)
    local left, right = frame.pages[1], frame.pages[2]
    for _, page in ipairs(frame.pages) do
        page:ClearAllPoints()
        page:SetSize(g.pageWidth, g.pageHeight)
    end
    frame.spine:ClearAllPoints()
    if g.mode == "spread" then
        left:SetPoint("TOPLEFT", frame.pageArea, "TOPLEFT", 0, 0)
        right:SetPoint("TOPLEFT", frame.pageArea, "TOPLEFT", g.pageWidth + LB.ReaderView.GUTTER, 0)
        right:Show()
        frame.spine:SetPoint("TOP", frame.pageArea, "TOPLEFT", g.pageWidth + LB.ReaderView.GUTTER / 2, 0)
        frame.spine:SetHeight(g.pageHeight)
        frame.spine:Show()
    else
        left:SetPoint("TOP", frame.pageArea, "TOP", 0, 0)
        right:Hide()
        frame.spine:Hide()
    end
    left:Show()
end

-- The book's parchment behind the pages (Theme.ReaderBackground): the two-page
-- texture over the whole inset, a sheet per page, or a client texture over the inset.
local function applyBackground(g, parchment)
    local window = LB.MainWindow.frame
    local background = Theme.ReaderBackground(parchment, g.mode)
    local inset, sheets = window.inset, window.sheets
    for _, sheet in ipairs(sheets) do
        sheet:ClearAllPoints()
        sheet:Hide()
    end
    if background.layout == "sheets" then
        window.parchment:Hide()
        for _, sheet in ipairs(sheets) do
            sheet:SetTexture(background.texture)
            sheet:SetTexCoord(unpack(background.coords))
            sheet:SetVertexColor(1, 1, 1, 1)
        end
        if g.mode == "spread" then
            sheets[1]:SetPoint("TOPLEFT", inset, "TOPLEFT", 3, -3)
            sheets[1]:SetPoint("BOTTOMRIGHT", inset, "BOTTOM", 0, 3)
            sheets[2]:SetPoint("TOPLEFT", inset, "TOP", 0, -3)
            sheets[2]:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -3, 3)
            sheets[2]:Show()
        else
            -- The single page is centred in the window, like the inset.
            sheets[1]:SetPoint("TOP", inset, "TOP", 0, -3)
            sheets[1]:SetPoint("BOTTOM", inset, "BOTTOM", 0, 3)
            sheets[1]:SetWidth(g.pageWidth + 2 * Reader.SHEET_MARGIN)
        end
        sheets[1]:Show()
    else
        LB.Widgets.ApplyParchment(window.parchment, background)
        window.parchment:Show()
    end
    -- Own parchments draw their own fold; the brass line is for client textures.
    Reader.frame.spine:SetShown(g.mode == "spread" and background.layout == "fill")
end

local function saveCurrentPosition(layout)
    local state = Reader.state
    local chapter = state.book.chapters[state.chapterIndex]
    local anchor = LB.Paginator.AnchorForPage(layout, state.pageIndex)
    local blockId = anchor and anchor.blockId or chapter.blocks[1].id
    local offset = anchor and anchor.textOffset or 0
    LB.ReaderState.SavePosition(LB.store, LB.ReaderState.MakeAnchor(state.book, chapter.id, blockId, offset))
end

function Reader.Render()
    local frame, state, g = Reader.frame, Reader.state, Reader.geometry
    local book = state.book
    local flow = Reader.Flow()
    state.page = LB.ReaderView.ViewStart(math.max(1, math.min(state.page, flow.total)), g.pagesPerView)
    local visible = Reader.VisiblePages()
    -- The current chapter (saved position, pinning, contents) is the one jumped to,
    -- otherwise the chapter of the left page.
    local current = visible[1]
    for _, shown in ipairs(visible) do
        if shown.chapterIndex == state.focusChapter then
            current = shown
            break
        end
    end
    state.chapterIndex, state.pageIndex = current.chapterIndex, current.pageIndex
    local layout = current.layout

    positionPages(frame, g)
    for index, page in ipairs(frame.pages) do
        local shown = index <= g.pagesPerView and visible[index]
        drawPage(page, shown and shown.layout.pages[shown.pageIndex] or nil)
    end

    local lastShown = state.page + #visible - 1
    local pagesText = lastShown > state.page and (state.page .. "-" .. lastShown) or tostring(state.page)
    LB.MainWindow.frame.title:SetText(Escape(book.title))
    local parchment = Theme.ParchmentOf(book)
    applyBackground(g, parchment)
    LB.Widgets.ApplyParchment(frame.contents.background, parchment)
    frame.pageLabel:SetText(L("READER_PAGE", pagesText, flow.total))
    frame.prev:SetEnabled(LB.ReaderNav.CanStep(state.page, -1, flow.total, g.pagesPerView))
    frame.next:SetEnabled(LB.ReaderNav.CanStep(state.page, 1, flow.total, g.pagesPerView))

    local search = Reader.search
    if search then
        frame.searchBar.label:SetText(L("READER_SEARCH_MATCH", search.index, search:Count(), Escape(search.query)))
        frame.searchBar:Show()
        frame.detachButton:Hide()
    else
        frame.searchBar:Hide()
        frame.detachButton:Show()
        -- A search match is a temporary position: it never replaces the saved one.
        saveCurrentPosition(layout)
    end
end

local function showPosition(chapterIndex, blockId, textOffset)
    local page = 1
    if blockId then
        page = LB.Paginator.PageForAnchor(Reader.Layout(chapterIndex), blockId, textOffset) or 1
    end
    setPosition(chapterIndex, page)
    Reader.Render()
end

-- Opens a book on the first match of `query`; the saved position stays untouched.
function Reader.OpenSearch(bookId, query)
    if not Reader.Open(bookId) then return false end
    local book = Reader.state.book
    local matches = LB.Library.SearchInBook(book, query)
    if #matches == 0 then return true end
    local back = LB.Tables.DeepCopy(LB.ReaderState.GetPosition(LB.store, book.bookId))
    Reader.search = LB.SearchSession.New(matches, back)
    Reader.search.query = query
    Reader.SearchStep(1)
    return true
end

-- Opens the place of a saved anchor (bookmark, note); a changed edition falls back gracefully.
function Reader.GoToAnchor(anchor)
    Reader.frame.contents:Hide()
    local position = LB.ReaderState.Resolve(Reader.state.book, anchor)
    showPosition(position.chapterIndex, position.blockId, position.textOffset)
end

function Reader.SearchStep(delta)
    local search = Reader.search
    if not search then return end
    local match = delta < 0 and search:Prev() or search:Next()
    showPosition(match.chapterIndex, match.blockId, match.textOffset)
end

function Reader.ExitSearch()
    local search = Reader.search
    if not search then return end
    Reader.search = nil
    local position = LB.ReaderState.Resolve(Reader.state.book, search:ReturnAnchor())
    showPosition(position.chapterIndex, position.blockId, position.textOffset)
end

function Reader.CurrentAnchor()
    local state = Reader.state
    if not state or not Reader.geometry then return nil end
    return LB.Paginator.AnchorForPage(Reader.Layout(state.chapterIndex), state.pageIndex)
end

-- Recomputes geometry (size, font, mode) and reopens the page with the same fragment.
function Reader.Relayout()
    if not Reader.state or not Reader.IsShown() then
        return
    end
    local anchor = Reader.CurrentAnchor()
    computeGeometry()
    local page = 1
    if anchor then
        page = LB.Paginator.PageForAnchor(Reader.Layout(Reader.state.chapterIndex), anchor.blockId, anchor.textOffset) or 1
    end
    setPosition(Reader.state.chapterIndex, page)
    Reader.Render()
end

function Reader.Open(bookId)
    bookId = bookId or Reader.DEMO_BOOK_ID
    local book = Reader.FindBook(bookId)
    if not book and bookId == Reader.DEMO_BOOK_ID and not LB.IsBookEdition() then
        local first = LB.Storage.ListBooks(LB.store)[1]
        book = first and LB.Storage.GetBook(LB.store, first.bookId)
    end
    if not book then
        LB.Commands.Print(L("READER_UNKNOWN_BOOK", Escape(bookId)))
        return false
    end
    local frame = ensureFrame()
    frame.contents:Hide()
    Reader.search = nil
    Reader.state = { bookId = book.bookId, book = book, chapterIndex = 1, pageIndex = 1, page = 1 }
    computeGeometry()

    local position = LB.ReaderState.Resolve(book, LB.ReaderState.GetPosition(LB.store, book.bookId))
    local pageIndex = 1
    if position.blockId then
        pageIndex = LB.Paginator.PageForAnchor(Reader.Layout(position.chapterIndex),
            position.blockId, position.textOffset) or 1
    end
    setPosition(position.chapterIndex, pageIndex)
    if position.changed then
        LB.Commands.Print(L("READER_EDITION_CHANGED"))
    end
    LB.Library.MarkRecent(LB.store, book.bookId)
    -- Notes of this character may predate an update made on another character.
    LB.Annotations.Reconcile(LB.store, book)
    LB.MainWindow.ShowView("reader")
    Reader.Render()
    return true
end

function Reader.Step(delta)
    local state = Reader.state
    if not state or not Reader.IsShown() then return end
    local before = state.page
    state.page = LB.ReaderNav.Step(state.page, delta, Reader.Flow().total, Reader.geometry.pagesPerView)
    state.focusChapter = nil
    Reader.Render()
    if state.page ~= before then LB.Compat.PlayPageTurn() end
end

function Reader.GoToChapter(chapterIndex)
    Reader.frame.contents:Hide()
    setPosition(chapterIndex, 1)
    Reader.Render()
end

function Reader.ToggleContents()
    local contents = Reader.frame.contents
    if contents:IsShown() then
        contents:Hide()
        return
    end
    local book, g = Reader.state.book, Reader.geometry
    local areaWidth = LB.MainWindow.Size() - 2 * Reader.INSET_X
    -- Left half: chapters (in sub-columns when long); right half: bookmarks and notes.
    local chaptersWidth = areaWidth / 2
    local perColumn = math.max(1, math.floor((g.pageHeight - CONTENTS_HEADER_HEIGHT) / CONTENTS_ENTRY_HEIGHT))
    local columns = math.ceil(#book.chapters / perColumn)
    local columnWidth = chaptersWidth / columns
    LB.ReaderAnnotations.FillContents(contents, chaptersWidth + 16, CONTENTS_HEADER_HEIGHT,
        areaWidth - chaptersWidth - 16, g.pageHeight)
    contents.header:SetText(L("READER_CONTENTS"))
    contents.entryPool:ReleaseAll()
    for index, chapter in ipairs(book.chapters) do
        local entry = contents.entryPool:Acquire()
        local column = math.floor((index - 1) / perColumn)
        local row = (index - 1) % perColumn
        entry.chapterIndex = index
        entry:SetSize(columnWidth - 8, CONTENTS_ENTRY_HEIGHT)
        entry:SetPoint("TOPLEFT", contents, "TOPLEFT", column * columnWidth,
            -CONTENTS_HEADER_HEIGHT - row * CONTENTS_ENTRY_HEIGHT)
        entry.label:SetFontObject(LB.Fonts.Get(index == Reader.state.chapterIndex and "link" or "body"))
        entry.label:SetWidth(columnWidth - 20)
        entry.label:SetText(Escape(chapter.title))
        entry:Show()
    end
    contents:Show()
end

function Reader.Focus()
    if LB.Compat.InCombat() then return end
    Reader.focused = true
    Reader.frame:EnableKeyboard(true)
    Reader.frame:SetPropagateKeyboardInput(true)
end

function Reader.ClearFocus()
    Reader.focused = false
    if Reader.frame then
        Reader.frame:EnableKeyboard(false)
    end
end

-- Changes the body text size; the reader keeps showing the same fragment.
function Reader.SetFontSize(size)
    LB.Fonts.SetBodySize(size)
    if LB.store and not LB.store.readOnly then
        LB.store.account.settings.fontSize = LB.Fonts.GetBodySize()
    end
    if Reader.measurer then
        local anchor = Reader.IsShown() and Reader.CurrentAnchor()
        Reader.measurer:Reset()
        Reader.cache:Clear()
        if anchor then
            computeGeometry()
            local page = LB.Paginator.PageForAnchor(Reader.Layout(Reader.state.chapterIndex),
                anchor.blockId, anchor.textOffset) or 1
            setPosition(Reader.state.chapterIndex, page)
            Reader.Render()
        end
    end
end

LB.Commands.Register("read", function(args)
    Reader.Open(args ~= "" and args or nil)
end, "CMD_HELP_READ")

LB.Commands.Register("font", function(args)
    local size = tonumber(args)
    if not size then
        LB.Commands.Print(L("CMD_FONT_USAGE", LB.Fonts.GetBodySize()))
        return
    end
    Reader.SetFontSize(size)
    LB.Commands.Print(L("FONT_SET", LB.Fonts.GetBodySize()))
end, "CMD_HELP_FONT")
