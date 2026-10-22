local _, LB = ...

-- Journal of discoveries: a view of the book window (LB.MainWindow) that is read
-- like the book. Its first page holds the progress and the meta achievements, the
-- next pages list every NPC by region; pages sit where the reader's pages are and
-- turn with the arrows or the mouse wheel (a spread, or one page in a narrow
-- window). A button over the reader's pages opens it and shows how many
-- discoveries have not been looked at yet.
local DiscoveryJournal = {}
LB.DiscoveryJournal = DiscoveryJournal

local L = LB.L
local Theme = LB.Theme
local Discoveries = LB.Discoveries
local Escape = LB.Text.EscapeForUI

local INSET_X, TOP, BOTTOM = LB.Reader.INSET_X, LB.Reader.INSET_TOP, LB.Reader.INSET_BOTTOM
local ROW_HEIGHT, META_ROW = 42, 26

DiscoveryJournal.page = 1

local function discovery() return LB.Discovery end

local function counts()
    return Discoveries.Count(discovery().DB(), discovery().Index())
end

-- Reader button ------------------------------------------------------------------

function DiscoveryJournal.UpdateButton()
    local button = LB.Reader.frame and LB.Reader.frame.discoveriesButton
    if type(button) ~= "table" then return end
    local found, total = counts()
    button:SetText(L("DISCOVERY_BUTTON", found, total))
    button.glow:SetShown(Discoveries.Unseen(discovery().DB(), discovery().Index()) > 0)
end

-- The glow breathes between faint and full, one cycle in PULSE seconds.
local PULSE = 1.6

function DiscoveryJournal.Pulse(glow, elapsed)
    glow.elapsed = (glow.elapsed + elapsed) % PULSE
    glow.texture:SetAlpha(0.3 + 0.7 * (0.5 + 0.5 * math.cos(glow.elapsed / PULSE * 2 * math.pi)))
end

local function createButton(frame)
    local button = LB.Widgets.Button(frame, "", 150, function() DiscoveryJournal.Open() end)
    button:SetPoint("RIGHT", frame.languageButton, "LEFT", -10, 0)
    -- New finds: a soft gold glow around the whole button, the client's own panel
    -- button highlight (its painted part is 80x22 of the 128x32 file) in ADD mode.
    local glow = CreateFrame("Frame", nil, button)
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 6)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -6)
    glow:SetFrameLevel(button:GetFrameLevel() + 5)
    glow.texture = glow:CreateTexture(nil, "OVERLAY")
    glow.texture:SetAllPoints(glow)
    glow.texture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    glow.texture:SetTexCoord(0, 0.625, 0, 0.6875)
    glow.texture:SetBlendMode("ADD")
    glow.elapsed = 0
    glow:SetScript("OnUpdate", function(self, elapsed) DiscoveryJournal.Pulse(self, elapsed) end)
    glow:EnableMouse(false)
    glow:Hide()
    button.glow = glow
    frame.discoveriesButton = button
    if LB.store then DiscoveryJournal.UpdateButton() end
end

-- View -----------------------------------------------------------------------------

local function sealTexture(parent, size)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetSize(size, size)
    discovery().ApplySeal(texture, false)
    return texture
end

local function setFound(texture, found)
    texture:SetDesaturated(not found)
    texture:SetAlpha(found and 1 or 0.35)
end

local function createView()
    local view = LB.MainWindow.AddView("discoveries", { onResize = function() DiscoveryJournal.Render() end })
    view.pageArea = CreateFrame("Frame", nil, view)
    view.pageArea:SetPoint("TOPLEFT", view, "TOPLEFT", INSET_X, -TOP)
    view.pageArea:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -INSET_X, BOTTOM)
    view.pageArea:EnableMouseWheel(true)
    view.pageArea:SetScript("OnMouseWheel", function(_, delta) DiscoveryJournal.Step(delta > 0 and -1 or 1) end)

    view.progress = view.pageArea:CreateFontString(nil, "OVERLAY")
    view.progress:SetFontObject(LB.Fonts.Get("heading2"))
    view.metaHeader = view.pageArea:CreateFontString(nil, "OVERLAY")
    view.metaHeader:SetFontObject(LB.Fonts.Get("heading3"))
    view.metaHeader:SetPoint("TOPLEFT", view.progress, "BOTTOMLEFT", 0, -18)
    view.metaRows = {}

    view.rowPool = LB.WidgetPool.New(function()
        local row = CreateFrame("Button", nil, view.pageArea)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.seal = sealTexture(row, 26)
        row.seal:SetPoint("LEFT", row, "LEFT", 2, 0)
        -- Two lines: the name, and under it where and when (or "not found yet").
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -3)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.detail = row:CreateFontString(nil, "OVERLAY")
        row.detail:SetFontObject(LB.Fonts.Get("caption"))
        row.detail:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -23)
        row.detail:SetJustifyH("LEFT")
        row.detail:SetWordWrap(false)
        row:SetScript("OnClick", function(self) if self.def then discovery().OpenPage(self.def) end end)
        row:SetScript("OnEnter", function(self)
            if self.def and discovery().DB()[self.def.id] then discovery().ShowCard(self.seal, { self.def }) end
        end)
        row:SetScript("OnLeave", function() discovery().HideCard() end)
        return row
    end, function(row)
        row:Hide()
        row:ClearAllPoints()
        row.def = nil
    end)

    -- The reader's bottom bar: arrows at the edges, the page in the middle.
    view.prev = LB.Widgets.Button(view, "<", 40, function() DiscoveryJournal.Step(-1) end)
    view.prev:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", 16, 12)
    view.next = LB.Widgets.Button(view, ">", 40, function() DiscoveryJournal.Step(1) end)
    view.next:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -24, 12)
    view.backButton = LB.Widgets.Button(view, L("DISCOVERY_BACK"), 140, function() LB.BookApp.OpenReader() end)
    view.backButton:SetPoint("BOTTOMLEFT", view.prev, "BOTTOMRIGHT", 8, 0)
    view.pageLabel = view:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    view.pageLabel:SetPoint("BOTTOM", view, "BOTTOM", 0, 18)
    return view
end

local function metaRow(view, index)
    local row = view.metaRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, view.pageArea)
    row:SetHeight(META_ROW)
    row:SetPoint("TOPLEFT", view.metaHeader, "BOTTOMLEFT", 0, -8 - (index - 1) * META_ROW)
    row.seal = sealTexture(row, 20)
    row.seal:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.title = row:CreateFontString(nil, "OVERLAY")
    row.title:SetFontObject(LB.Fonts.Get("caption"))
    row.title:SetPoint("LEFT", row, "LEFT", 28, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.count = row:CreateFontString(nil, "OVERLAY")
    row.count:SetFontObject(LB.Fonts.Get("label"))
    row.count:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    view.metaRows[index] = row
    return row
end

-- "Дун Морог. Родня по упрямству" / "Dun Morogh: Kin in Stubbornness" -> the region.
function DiscoveryJournal.Region(title)
    return string.match(title, "^(.-)[%.:]%s") or title
end

-- Rows of the list: region headers and NPCs, in book order.
function DiscoveryJournal.Rows()
    local rows = {}
    for _, group in ipairs(Discoveries.ByChapter(discovery().Index(), LB.BookApp.CurrentBook())) do
        rows[#rows + 1] = { chapter = group.chapter }
        for _, def in ipairs(group.defs) do rows[#rows + 1] = { def = def } end
    end
    return rows
end

local function background()
    local window = LB.MainWindow.frame
    local parchment = Theme.ParchmentOf(LB.BookApp.CurrentBook())
    window.parchment:SetTexture(parchment.spread or parchment.texture)
    window.parchment:SetTexCoord(0, 1, 0, 1)
    window.parchment:Show()
end

local function drawSummary(view, x, g, db, index)
    local found, total = Discoveries.Count(db, index)
    view.progress:ClearAllPoints()
    view.progress:SetPoint("TOPLEFT", view.pageArea, "TOPLEFT", x, 0)
    view.progress:SetText(L("DISCOVERY_PROGRESS", found, total))
    view.metaHeader:SetText(L("DISCOVERY_ACHIEVEMENTS"))
    local fitting = math.floor((g.pageHeight - 80) / META_ROW)
    for i, meta in ipairs(index.meta) do
        if i > fitting then break end
        local row = metaRow(view, i)
        row:SetWidth(g.pageWidth)
        row.title:SetWidth(g.pageWidth - 80)
        local done, have, need = Discoveries.MetaProgress(db, meta)
        row.title:SetText(Escape(discovery().Title(meta)))
        row.count:SetText(have .. "/" .. need)
        setFound(row.seal, done)
        row:Show()
    end
end

local function drawRow(view, item, x, y, width, db)
    local row = view.rowPool:Acquire()
    row:SetSize(width, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", view.pageArea, "TOPLEFT", x, -y)
    if item.chapter then
        row.seal:Hide()
        row.name:SetFontObject(LB.Fonts.Get("heading3"))
        row.name:SetText(Escape(DiscoveryJournal.Region(item.chapter.title)))
        row.detail:SetText("")
        row:EnableMouse(false)
    else
        local record = db[item.def.id]
        row.def = item.def
        row.seal:Show()
        setFound(row.seal, record ~= nil)
        row.name:SetFontObject(LB.Fonts.Get(record and "body" or "label"))
        local name = Escape(discovery().Title(item.def))
        if record and DiscoveryJournal.fresh[item.def.id] then
            name = name .. "  |cff7b2020" .. L("DISCOVERY_FRESH") .. "|r"
        end
        row.name:SetText(name)
        row.detail:SetText(record and Escape(discovery().FormatWhere(record) .. " · "
            .. discovery().FormatWhen(record)) or L("DISCOVERY_NOT_FOUND"))
        row:EnableMouse(true)
    end
    row.name:SetWidth(width - 40)
    row.detail:SetWidth(width - 40)
    row:Show()
end

function DiscoveryJournal.Render()
    local view = DiscoveryJournal.view
    if not view or not LB.MainWindow.IsShowing("discoveries") then return end
    local db, index = discovery().DB(), discovery().Index()
    LB.MainWindow.frame.title:SetText(L("DISCOVERY_JOURNAL"))
    background()

    -- The same pages as the reader: page size, gutter, spread or single page.
    local windowWidth, windowHeight = LB.MainWindow.Size()
    local g = LB.ReaderView.Geometry(windowWidth - 2 * INSET_X, windowHeight - TOP - BOTTOM, LB.Fonts.GetBodySize())
    local perPage = math.max(2, math.floor(g.pageHeight / ROW_HEIGHT))
    local pages = Discoveries.JournalPages(DiscoveryJournal.Rows(), perPage)
    local perView = g.pagesPerView
    DiscoveryJournal.total, DiscoveryJournal.perView = #pages, perView
    DiscoveryJournal.page = LB.ReaderView.ViewStart(math.max(1, math.min(DiscoveryJournal.page, #pages)), perView)

    view.rowPool:ReleaseAll()
    for _, row in ipairs(view.metaRows) do row:Hide() end
    view.progress:Hide()
    view.metaHeader:Hide()
    local shown = 0
    for slot = 1, perView do
        local page = pages[DiscoveryJournal.page + slot - 1]
        if page then
            shown = slot
            local x = (slot - 1) * (g.pageWidth + LB.ReaderView.GUTTER)
            if page.summary then
                view.progress:Show()
                view.metaHeader:Show()
                drawSummary(view, x, g, db, index)
            else
                for i, item in ipairs(page.rows) do
                    drawRow(view, item, x, (i - 1) * ROW_HEIGHT, g.pageWidth, db)
                end
            end
        end
    end

    local first, last = DiscoveryJournal.page, DiscoveryJournal.page + shown - 1
    view.pageLabel:SetText(L("READER_PAGE", last > first and (first .. "-" .. last) or tostring(first), #pages))
    view.prev:SetEnabled(LB.ReaderNav.CanStep(first, -1, #pages, perView))
    view.next:SetEnabled(LB.ReaderNav.CanStep(first, 1, #pages, perView))
end

function DiscoveryJournal.Step(delta)
    if not DiscoveryJournal.IsShown() then return end
    local before = DiscoveryJournal.page
    DiscoveryJournal.page = LB.ReaderNav.Step(DiscoveryJournal.page, delta, DiscoveryJournal.total or 1,
        DiscoveryJournal.perView or 1)
    DiscoveryJournal.Render()
    if DiscoveryJournal.page ~= before then LB.Compat.PlayPageTurn() end
end

function DiscoveryJournal.IsShown()
    return LB.MainWindow.IsShowing("discoveries")
end

-- Opens the journal on its first page; what was new is marked "new" this time and
-- counts as seen.
function DiscoveryJournal.Open()
    DiscoveryJournal.view = DiscoveryJournal.view or createView()
    local db, fresh = discovery().DB(), {}
    for id, record in pairs(db) do
        if type(record) == "table" and not record.seen then fresh[id] = true end
    end
    DiscoveryJournal.fresh = fresh
    DiscoveryJournal.page = 1
    Discoveries.MarkAllSeen(db)
    LB.MainWindow.ShowView("discoveries")
    DiscoveryJournal.Render()
    DiscoveryJournal.UpdateButton()
end

function DiscoveryJournal.Refresh()
    if DiscoveryJournal.IsShown() then
        -- Found while the journal is open: new, and seen right away.
        for id, record in pairs(discovery().DB()) do
            if type(record) == "table" and not record.seen then DiscoveryJournal.fresh[id] = true end
        end
        Discoveries.MarkAllSeen(discovery().DB())
        DiscoveryJournal.Render()
    end
    DiscoveryJournal.UpdateButton()
end

LB.Reader.OnFrameCreated(createButton)
