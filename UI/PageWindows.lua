local _, LB = ...

-- Page windows of a book edition: any number of small windows over the book, each
-- with its own page of the whole book (pages flow across chapters), to read two
-- places side by side. Only the page arrows and the close button. Closed windows
-- are kept and reused (frames are never destroyed).
local PageWindows = {}
LB.PageWindows = PageWindows

local L = LB.L
local Theme = LB.Theme
local View = LB.FieldView
local Escape = LB.Text.EscapeForUI

local INSET_X, TOP, BOTTOM = 14, 62, 42
-- Each new window is shifted so it does not hide the previous one.
local CASCADE = 28
local RESIZE_DELAY = 0.15

PageWindows.windows = {}

local function shared()
    if not PageWindows.measurer then
        PageWindows.measurer = LB.TextMeasurer.New(UIParent)
        PageWindows.cache = LB.LayoutCache.New()
    end
end

local function geometry(window)
    return { width = window:GetWidth() - 2 * INSET_X, height = window:GetHeight() - TOP - BOTTOM }
end

local function layout(window, index)
    local book, g = window.state.book, geometry(window)
    local chapter = book.chapters[index]
    local key = LB.LayoutCache.Key(book.bookId, book.revision, chapter.id .. ":window", g.width, g.height, LB.Fonts.Key())
    local result = PageWindows.cache:Get(key)
    if not result then
        result = LB.Paginator.Paginate(chapter, g, PageWindows.measurer, { omitTitle = true, figureAspect = LB.Assets.Aspect })
        PageWindows.cache:Put(key, result)
    end
    return result
end

local function flow(window)
    local counts = {}
    for index in ipairs(window.state.book.chapters) do
        counts[index] = #layout(window, index).pages
    end
    return LB.ReaderNav.Flow(counts)
end

local function render(window)
    local state = window.state
    local book = state.book
    local pages = flow(window)
    state.page = math.max(1, math.min(state.page, pages.total))
    local chapterIndex, pageIndex = LB.ReaderNav.ToLocal(pages, state.page)
    state.chapterIndex, state.pageIndex = chapterIndex, pageIndex
    local g = geometry(window)
    window.page:SetSize(g.width, g.height)
    LB.PageView.Draw(window.page, layout(window, chapterIndex).pages[pageIndex], PageWindows.measurer, { book = book })
    LB.Widgets.ApplyParchment(window.background, Theme.ParchmentOf(book))
    window.bookTitle:SetText(Escape(book.title))
    window.chapterTitle:SetText(Escape(book.chapters[chapterIndex].title))
    window.pageLabel:SetText(L("FIELD_PAGE", state.page, pages.total))
    window.prev:SetEnabled(state.page > 1)
    window.next:SetEnabled(state.page < pages.total)
    -- The passage on screen, to find again after a resize, font or language change.
    window.place = PageWindows.Anchor(window)
end

-- { chapterId, blockId, textOffset } of the window's page.
function PageWindows.Anchor(window)
    local state = window.state
    local chapter = state.book.chapters[state.chapterIndex]
    local anchor = LB.Paginator.AnchorForPage(layout(window, state.chapterIndex), state.pageIndex)
    return { chapterId = chapter.id, blockId = anchor and anchor.blockId or chapter.blocks[1].id,
        textOffset = anchor and anchor.textOffset or 0 }
end

-- Puts the window on the page of `anchor` in `book` (chapter start if the block is gone).
local function setPlace(window, book, anchor)
    window.state = { book = book, page = 1 }
    local index = 1
    for i, chapter in ipairs(book.chapters) do
        if anchor and chapter.id == anchor.chapterId then index = i end
    end
    local pageIndex = 1
    if anchor and type(anchor.blockId) == "string" then
        pageIndex = LB.Paginator.PageForAnchor(layout(window, index), anchor.blockId, anchor.textOffset or 0) or 1
    end
    window.state.page = LB.ReaderNav.ToGlobal(flow(window), index, pageIndex)
end

function PageWindows.Step(window, delta)
    local before = window.state.page
    window.state.page = window.state.page + delta
    render(window)
    if window.state.page ~= before then LB.Compat.PlayPageTurn() end
end

local function create()
    local window = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    window:SetSize(View.DEFAULT_WIDTH, View.DEFAULT_HEIGHT)
    -- Over the book window (HIGH); the clicked one comes to the front.
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetResizable(true)
    LB.Compat.SetResizeBounds(window, View.MIN_WIDTH, View.MIN_HEIGHT, View.MAX_WIDTH, View.MAX_HEIGHT)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    local brass = Theme.colors.brass
    window:SetBackdropBorderColor(brass[1], brass[2], brass[3], 1)

    window.background = window:CreateTexture(nil, "BACKGROUND")
    window.background:SetPoint("TOPLEFT", window, "TOPLEFT", 3, -3)
    window.background:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -3, 3)

    window.close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    window.close:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    window.close:SetScript("OnClick", function() window:Hide() end)

    window.bookTitle = window:CreateFontString(nil, "OVERLAY")
    window.bookTitle:SetFontObject(LB.Fonts.Get("caption"))
    window.bookTitle:SetPoint("TOPLEFT", window, "TOPLEFT", INSET_X, -10)
    window.bookTitle:SetPoint("RIGHT", window.close, "LEFT", -4, 0)
    window.bookTitle:SetJustifyH("LEFT")
    window.bookTitle:SetWordWrap(false)
    window.chapterTitle = window:CreateFontString(nil, "OVERLAY")
    window.chapterTitle:SetFontObject(LB.Fonts.Get("heading3"))
    window.chapterTitle:SetPoint("TOPLEFT", window, "TOPLEFT", INSET_X, -32)
    window.chapterTitle:SetPoint("RIGHT", window, "RIGHT", -INSET_X, 0)
    window.chapterTitle:SetJustifyH("LEFT")
    window.chapterTitle:SetWordWrap(false)

    window.page = LB.PageView.Create(window)
    window.page:SetPoint("TOPLEFT", window, "TOPLEFT", INSET_X, -TOP)
    window.page:EnableMouseWheel(true)
    window.page:SetScript("OnMouseWheel", function(_, delta) PageWindows.Step(window, delta > 0 and -1 or 1) end)

    window.prev = LB.Widgets.Button(window, "<", 32, function() PageWindows.Step(window, -1) end)
    window.prev:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 8, 10)
    window.next = LB.Widgets.Button(window, ">", 32, function() PageWindows.Step(window, 1) end)
    window.next:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -18, 10)
    window.pageLabel = window:CreateFontString(nil, "OVERLAY")
    window.pageLabel:SetFontObject(LB.Fonts.Get("label"))
    window.pageLabel:SetPoint("BOTTOM", window, "BOTTOM", 0, 16)

    window.grip = CreateFrame("Button", nil, window)
    window.grip:SetSize(14, 14)
    window.grip:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -2, 2)
    window.grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    window.grip:SetScript("OnMouseDown", function() window:StartSizing("BOTTOMRIGHT") end)
    window.grip:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
        PageWindows.lastWidth, PageWindows.lastHeight = window:GetWidth(), window:GetHeight()
    end)
    window.resizeDebounce = LB.Debounce.New(RESIZE_DELAY, function()
        if window:IsShown() and window.state then
            -- Keep the passage, not the page number, when the page size changes.
            setPlace(window, window.state.book, window.place)
            render(window)
        end
    end, LB.Compat.After)
    window:SetScript("OnSizeChanged", function() window.resizeDebounce:Trigger() end)
    window:Hide()
    PageWindows.windows[#PageWindows.windows + 1] = window
    return window
end

function PageWindows.Shown()
    local shown = {}
    for _, window in ipairs(PageWindows.windows) do
        if window:IsShown() then shown[#shown + 1] = window end
    end
    return shown
end

local function acquire()
    for _, window in ipairs(PageWindows.windows) do
        if not window:IsShown() then return window end
    end
    return create()
end

-- Opens one more window on the page of `anchor` (nil: the first page).
function PageWindows.Open(book, anchor)
    shared()
    local count = #PageWindows.Shown()
    local window = acquire()
    window:SetSize(PageWindows.lastWidth or View.DEFAULT_WIDTH, PageWindows.lastHeight or View.DEFAULT_HEIGHT)
    window:ClearAllPoints()
    window:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -80 - count * CASCADE, -120 - count * CASCADE)
    setPlace(window, book, anchor)
    window:Show()
    window:Raise()
    LB.Compat.PlayBookOpen()
    render(window)
    return window
end

function PageWindows.CloseAll()
    for _, window in ipairs(PageWindows.windows) do window:Hide() end
end

-- Draws every open window again on its page (marks in the book changed).
function PageWindows.Redraw()
    for _, window in ipairs(PageWindows.Shown()) do
        render(window)
    end
end

-- After a font change: every open window keeps its passage.
function PageWindows.Refresh()
    if PageWindows.measurer then
        PageWindows.measurer:Reset()
        PageWindows.cache:Clear()
    end
    for _, window in ipairs(PageWindows.Shown()) do
        setPlace(window, window.state.book, window.place)
        render(window)
    end
end

-- Another translation: each open window moves to the same chapter and block in `book`.
function PageWindows.SwitchBook(book)
    for _, window in ipairs(PageWindows.Shown()) do
        local place = window.place
        setPlace(window, book, { chapterId = place.chapterId, blockId = place.blockId, textOffset = 0 })
        render(window)
    end
end
