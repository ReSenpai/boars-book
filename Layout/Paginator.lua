local _, LB = ...

-- Lays out one chapter into pages. Pure: text metrics come from an injected
-- measurer with :Width(text, style) and :LineHeight(style).
--
-- A page is { units = { unit... } }. Unit kinds:
--   line   { style, text, x, offset, length, marker?, checkItemId?, itemIndex?, reference? }
--   figure { assetId, alt, imageWidth, imageHeight, captionLines, captionGap, x? (when shrunk) }
--   row    { labelLines, valueLines, valueX, labelStyle, valueStyle }
-- Every unit has blockId (nil for the chapter title), blockType, offset, y, height.
-- `offset` is a code point position inside the block, monotonic within a block,
-- and is what reading anchors refer to. Page numbers are never content IDs.
local Paginator = {}
LB.Paginator = Paginator

Paginator.DEFAULT_FIGURE_ASPECT = 0.6
Paginator.KEEP_LINES_AFTER_HEADING = 2

Paginator.DEFAULT_SPACING = {
    block = 10,
    captionGap = 4,
    listIndent = 18,
    checkboxIndent = 22,
    factsGap = 8,
    factsLabelShare = 0.38,
}

local function wrap(ctx, text, width, style)
    return LB.Wrap.Lines(text, width, function(s) return ctx.measurer:Width(s, style) end)
end

local function lineUnits(ctx, block, text, style, x, baseOffset)
    local units = {}
    local height = ctx.measurer:LineHeight(style)
    for _, line in ipairs(wrap(ctx, text, ctx.width - x, style)) do
        units[#units + 1] = {
            kind = "line", style = style, text = line.text, x = x,
            offset = baseOffset + line.offset, length = line.length, height = height,
        }
    end
    return units
end

local function keepTogether(units, extra)
    for i, unit in ipairs(units) do
        unit.keepWithNext = (#units - i) + extra
    end
end

local builders = {}

function builders.heading(ctx, block)
    local units = lineUnits(ctx, block, block.text, block.level == 3 and "heading3" or "heading2", 0, 0)
    keepTogether(units, Paginator.KEEP_LINES_AFTER_HEADING)
    return units
end

function builders.paragraph(ctx, block)
    return lineUnits(ctx, block, block.text, "body", 0, 0)
end

local function itemUnits(ctx, block, items, indent, decorate)
    local units, base = {}, 0
    for index, item in ipairs(items) do
        local text = type(item) == "table" and item.text or item
        local lines = lineUnits(ctx, block, text, "body", indent, base)
        for i, unit in ipairs(lines) do
            unit.itemIndex = index
            if i == 1 then decorate(unit, index, item) end
            units[#units + 1] = unit
        end
        base = base + LB.Utf8.Len(text) + 1
    end
    return units
end

function builders.list(ctx, block)
    return itemUnits(ctx, block, block.items, ctx.spacing.listIndent, function(unit, index)
        unit.marker = block.ordered and (index .. ".") or "•"
    end)
end

function builders.checklist(ctx, block)
    return itemUnits(ctx, block, block.items, ctx.spacing.checkboxIndent, function(unit, _, item)
        unit.checkItemId = item.id
    end)
end

function builders.figure(ctx, block)
    local captionLines, captionHeight = {}, 0
    if block.caption ~= "" then
        for _, line in ipairs(wrap(ctx, block.caption, ctx.width, "caption")) do
            captionLines[#captionLines + 1] = line.text
        end
        captionHeight = #captionLines * ctx.measurer:LineHeight("caption") + ctx.spacing.captionGap
    end
    local aspect = ctx.figureAspect(block.assetId) or Paginator.DEFAULT_FIGURE_ASPECT
    local imageWidth = math.floor(ctx.width * ctx.figureScale)
    local imageHeight = imageWidth * aspect
    if imageHeight + captionHeight > ctx.height then
        imageHeight = math.max(ctx.measurer:LineHeight("body"), ctx.height - captionHeight)
    end
    return { {
        kind = "figure", assetId = block.assetId, alt = block.alt,
        x = imageWidth < ctx.width and math.floor((ctx.width - imageWidth) / 2) or nil,
        imageWidth = imageWidth, imageHeight = imageHeight,
        captionLines = captionLines, captionGap = ctx.spacing.captionGap,
        offset = 0, length = 0, height = imageHeight + captionHeight,
    } }
end

function builders.facts(ctx, block)
    local labelWidth = math.floor(ctx.width * ctx.spacing.factsLabelShare)
    local valueX = labelWidth + ctx.spacing.factsGap
    local units = {}
    for index, row in ipairs(block.rows) do
        local labelLines, valueLines = {}, {}
        for _, line in ipairs(wrap(ctx, row.label, labelWidth, "term")) do
            labelLines[#labelLines + 1] = line.text
        end
        for _, line in ipairs(wrap(ctx, row.value, ctx.width - valueX, "body")) do
            valueLines[#valueLines + 1] = line.text
        end
        units[#units + 1] = {
            kind = "row", labelLines = labelLines, valueLines = valueLines,
            labelStyle = "term", valueStyle = "body", valueX = valueX,
            offset = index - 1, length = 0,
            height = math.max(#labelLines * ctx.measurer:LineHeight("term"),
                #valueLines * ctx.measurer:LineHeight("body")),
        }
    end
    return units
end

function builders.reference(ctx, block)
    local units = lineUnits(ctx, block, block.label, "link", 0, 0)
    for _, unit in ipairs(units) do
        unit.reference = block.target
    end
    return units
end

Paginator.MIN_FIGURE_SCALE = 0.6

-- Scales a figure unit down (centered) so it takes at most `space` in height.
-- Returns false when that would make it smaller than MIN_FIGURE_SCALE.
function Paginator.ShrinkFigure(unit, space, pageWidth)
    local captionHeight = unit.height - unit.imageHeight
    local imageHeight = math.floor(space - captionHeight)
    if imageHeight < unit.imageHeight * Paginator.MIN_FIGURE_SCALE then
        return false
    end
    unit.imageWidth = math.floor(unit.imageWidth * imageHeight / unit.imageHeight)
    unit.imageHeight = imageHeight
    unit.height = imageHeight + captionHeight
    unit.x = math.floor((pageWidth - unit.imageWidth) / 2)
    return true
end

local function buildUnits(ctx, chapter)
    local all = {}
    if not ctx.omitTitle then
        local titleUnits = lineUnits(ctx, nil, chapter.title, "title", 0, 0)
        keepTogether(titleUnits, Paginator.KEEP_LINES_AFTER_HEADING)
        for _, unit in ipairs(titleUnits) do
            unit.blockType = "title"
            all[#all + 1] = unit
        end
    end
    for _, block in ipairs(chapter.blocks) do
        local builder = builders[block.type]
        if builder then
            local units = builder(ctx, block)
            for i, unit in ipairs(units) do
                unit.blockId = block.id
                unit.blockType = block.type
                unit.spaceBefore = i == 1 and ctx.spacing.block or 0
                all[#all + 1] = unit
            end
        end
    end
    return all
end

local function paginateOnce(chapter, geometry, measurer, options, figureScale)
    local ctx = {
        measurer = measurer,
        width = geometry.width,
        height = geometry.height,
        spacing = options.spacing or Paginator.DEFAULT_SPACING,
        figureAspect = options.figureAspect or function() return nil end,
        omitTitle = options.omitTitle,
        figureScale = figureScale,
    }
    local units = buildUnits(ctx, chapter)

    -- A figure that does not fit the rest of a page is first shrunk (not below
    -- MIN_FIGURE_SCALE); otherwise it floats: the following text fills the page
    -- and the figure opens the next one. This avoids half-empty pages.
    local pages = { { units = {} } }
    local cursor = 0
    local pending

    local function put(unit, gap)
        local page = pages[#pages]
        unit.y = cursor + gap
        unit.page = #pages
        unit.keepWithNext, unit.spaceBefore = nil, nil
        cursor = unit.y + unit.height
        page.units[#page.units + 1] = unit
    end

    local function startPage()
        pages[#pages + 1] = { units = {} }
        cursor = 0
        if pending then
            local figure = pending
            pending = nil
            put(figure, 0)
        end
    end

    local function needed(i)
        local unit, total = units[i], units[i].height
        for j = 1, unit.keepWithNext or 0 do
            local nextUnit = units[i + j]
            if not nextUnit then break end
            total = total + (nextUnit.spaceBefore or 0) + nextUnit.height
        end
        return total
    end

    for i, unit in ipairs(units) do
        if unit.kind == "figure" and pending then
            startPage()
        end
        local placed = false
        while not placed do
            local page = pages[#pages]
            local gap = #page.units > 0 and (unit.spaceBefore or 0) or 0
            local free = ctx.height - cursor - gap
            if #page.units == 0 or needed(i) <= free then
                put(unit, gap)
                placed = true
            elseif unit.kind == "figure" and Paginator.ShrinkFigure(unit, free, ctx.width) then
                put(unit, gap)
                placed = true
            elseif unit.kind == "figure" and not pending and i < #units then
                pending = unit
                placed = true
            else
                startPage()
            end
        end
    end
    if pending then
        startPage()
    end

    return { chapterId = chapter.id, pages = pages, width = geometry.width, height = geometry.height }
end

-- A last page holding only a few lines looks like a mistake: when the chapter
-- has figures, they are made a little smaller until the tail fits.
Paginator.SHORT_TAIL = 0.25
Paginator.TIGHTER_FIGURE_SCALES = { 0.85, 0.7 }

local function hasFigure(chapter)
    for _, block in ipairs(chapter.blocks) do
        if block.type == "figure" then return true end
    end
    return false
end

local function shortTail(layout)
    local last, bottom = layout.pages[#layout.pages], 0
    for _, unit in ipairs(last.units) do
        bottom = math.max(bottom, unit.y + unit.height)
    end
    return #layout.pages > 1 and bottom < layout.height * Paginator.SHORT_TAIL
end

-- geometry = { width, height }; options = { spacing?, figureAspect?(assetId) -> h/w,
-- omitTitle? (when the chapter title is shown outside the page, e.g. field guide) }.
function Paginator.Paginate(chapter, geometry, measurer, options)
    options = options or {}
    local layout = paginateOnce(chapter, geometry, measurer, options, 1)
    if shortTail(layout) and hasFigure(chapter) then
        for _, scale in ipairs(Paginator.TIGHTER_FIGURE_SCALES) do
            local tighter = paginateOnce(chapter, geometry, measurer, options, scale)
            if #tighter.pages < #layout.pages then
                return tighter
            end
        end
    end
    return layout
end

-- First content position on a page: { chapterId, blockId, textOffset } or nil.
function Paginator.AnchorForPage(layout, pageIndex)
    local page = layout.pages[pageIndex]
    if not page then return nil end
    for _, unit in ipairs(page.units) do
        if unit.blockId then
            return { chapterId = layout.chapterId, blockId = unit.blockId, textOffset = unit.offset }
        end
    end
    return nil
end

-- Where each page after the first begins: { { page, blockId, textOffset } }.
-- Used by the workshop to draw page boundaries inside the edited text.
function Paginator.BreakPoints(layout)
    local breaks = {}
    for p = 2, #layout.pages do
        for _, unit in ipairs(layout.pages[p].units) do
            if unit.blockId then
                breaks[#breaks + 1] = { page = p, blockId = unit.blockId, textOffset = unit.offset }
                break
            end
        end
    end
    return breaks
end

-- Page containing a position: the page of the last unit of the block that starts
-- at or before textOffset (or the block's first unit). nil if the block is absent.
function Paginator.PageForAnchor(layout, blockId, textOffset)
    local firstPage, bestPage
    for p, page in ipairs(layout.pages) do
        for _, unit in ipairs(page.units) do
            if unit.blockId == blockId then
                firstPage = firstPage or p
                if unit.offset <= textOffset then
                    bestPage = p
                end
            end
        end
    end
    return bestPage or firstPage
end
