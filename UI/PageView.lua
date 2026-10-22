local _, LB = ...

-- One rendered page: pooled widgets drawn from RenderOps. Shared by the folio
-- reader and the field guide. Checkboxes are interactive and stored per character.
local PageView = {}
LB.PageView = PageView

local Theme = LB.Theme
local setColor = LB.Widgets.SetColor

local CHECKBOX_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Up"
local CHECK_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Check"

local listeners = {}
local decorators = {}

-- Views that show checklist marks register a refresh function here.
function PageView.OnChecklistChanged(fn)
    listeners[#listeners + 1] = fn
end

-- fn(page, ops, measurer, context) runs after every page is drawn (ops = the page's
-- drawing operations, empty for a blank page); a book edition marks headings with it.
function PageView.AddDecorator(fn)
    decorators[#decorators + 1] = fn
end

local function notifyChecklistChanged()
    for _, fn in ipairs(listeners) do fn() end
end

local function pool(create)
    return LB.WidgetPool.New(create, function(widget)
        widget:Hide()
        widget:ClearAllPoints()
    end)
end

-- options.annotations: draw bookmark ribbons and note markers.
function PageView.Create(parent, options)
    options = options or {}
    local page = CreateFrame("Frame", nil, parent)
    page.textPool = pool(function()
        local fs = page:CreateFontString(nil, "OVERLAY")
        fs:SetWordWrap(false)
        fs:SetJustifyH("LEFT")
        return fs
    end)
    page.checkboxPool = pool(function()
        local box = CreateFrame("Button", nil, page)
        box:SetNormalTexture(CHECKBOX_TEXTURE)
        box.check = box:CreateTexture(nil, "OVERLAY")
        box.check:SetTexture(CHECK_TEXTURE)
        box.check:SetAllPoints(box)
        box:SetScript("OnClick", function(self)
            local checked = LB.Checklists.Toggle(LB.store, self.bookId, self.blockId, self.itemId)
            self.check:SetShown(checked)
            notifyChecklistChanged()
        end)
        return box
    end)
    page.highlightPool = pool(function()
        local texture = page:CreateTexture(nil, "ARTWORK")
        setColor(texture, Theme.colors.selected, 0.8)
        return texture
    end)
    page.imagePool = pool(function()
        local holder = CreateFrame("Frame", nil, page)
        holder.background = holder:CreateTexture(nil, "BACKGROUND")
        holder.background:SetAllPoints(holder)
        setColor(holder.background, Theme.colors.secondary, 0.15)
        holder.picture = holder:CreateTexture(nil, "ARTWORK")
        holder.picture:SetBlendMode("BLEND") -- transparent sketches lie directly on the parchment
        holder.picture:SetAllPoints(holder)
        holder.alt = holder:CreateFontString(nil, "OVERLAY")
        holder.alt:SetFontObject(LB.Fonts.Get("caption"))
        holder.alt:SetPoint("CENTER", holder, "CENTER", 0, 0)
        return holder
    end)
    if options.annotations then
        LB.ReaderAnnotations.SetupPage(page)
    end
    return page
end

-- Installed illustration, or the placeholder with its description when missing.
-- holder = { background, picture, alt }.
function PageView.ShowIllustration(holder, assetId, alt)
    local asset = LB.Assets.Resolve(assetId)
    if asset then
        holder.picture:SetTexture(asset.path)
        holder.picture:SetTexCoord(unpack(asset.coords))
        holder.picture:Show()
        holder.background:Hide()
        holder.alt:Hide()
    else
        holder.picture:Hide()
        holder.background:Show()
        holder.alt:SetText(alt)
        holder.alt:Show()
    end
end

local function applyOp(page, op, context)
    if op.op == "text" then
        local fs = page.textPool:Acquire()
        fs:SetFontObject(LB.Fonts.Get(op.style))
        fs:SetText(op.text)
        fs:SetPoint("TOPLEFT", page, "TOPLEFT", op.x, -op.y)
        fs:Show()
    elseif op.op == "checkbox" then
        local box = page.checkboxPool:Acquire()
        box.bookId, box.blockId, box.itemId = context.book.bookId, op.blockId, op.itemId
        box:SetSize(op.size, op.size)
        box:SetPoint("TOPLEFT", page, "TOPLEFT", op.x, -op.y + 2)
        box.check:SetShown(LB.Checklists.IsChecked(LB.store, box.bookId, box.blockId, box.itemId))
        box:Show()
    elseif op.op == "highlight" then
        local texture = page.highlightPool:Acquire()
        texture:SetSize(op.width, op.height)
        texture:SetPoint("TOPLEFT", page, "TOPLEFT", op.x, -op.y)
        texture:Show()
    elseif op.op == "image" then
        local holder = page.imagePool:Acquire()
        holder:SetSize(op.width, op.height)
        holder:SetPoint("TOPLEFT", page, "TOPLEFT", op.x, -op.y)
        PageView.ShowIllustration(holder, op.assetId, op.alt)
        holder:Show()
    end
end

-- context = { book, highlight?, annotations? }
function PageView.Draw(page, layoutPage, measurer, context)
    page.textPool:ReleaseAll()
    page.checkboxPool:ReleaseAll()
    page.highlightPool:ReleaseAll()
    page.imagePool:ReleaseAll()
    local ops = layoutPage and LB.RenderOps.Build(layoutPage, measurer, context.highlight) or {}
    for _, op in ipairs(ops) do
        applyOp(page, op, context)
    end
    for _, decorate in ipairs(decorators) do
        decorate(page, ops, measurer, context)
    end
    if context.annotations then
        LB.ReaderAnnotations.DrawPage(page, layoutPage)
    end
end
