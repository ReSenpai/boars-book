local _, LB = ...

-- Converts a laid-out page into flat drawing operations for the UI. Pure.
-- Coordinates are relative to the page's top-left corner, y grows downward.
-- All author text is escaped here, right before it reaches the client.
--   { op = "text", style, text, x, y, blockId, reference? }
--   { op = "checkbox", itemId, blockId, x, y, size }
--   { op = "image", assetId, alt, x, y, width, height, blockId }
--   { op = "highlight", x, y, width, height, blockId }  (drawn under the matched text)
local RenderOps = {}
LB.RenderOps = RenderOps

local Escape = LB.Text.EscapeForUI
local Utf8 = LB.Utf8

-- highlight = { blockId, from, to }: code point range inside the block text.
local function highlightOp(ops, unit, highlight, measurer)
    if not highlight or unit.blockId ~= highlight.blockId then return end
    local first = math.max(highlight.from, unit.offset)
    local last = math.min(highlight.to, unit.offset + unit.length)
    if last <= first then return end
    local prefix = Utf8.Sub(unit.text, 1, first - unit.offset)
    local matched = Utf8.Sub(unit.text, first - unit.offset + 1, last - unit.offset)
    ops[#ops + 1] = { op = "highlight", x = unit.x + measurer:Width(prefix, unit.style), y = unit.y,
        width = measurer:Width(matched, unit.style), height = unit.height, blockId = unit.blockId }
end

local function text(ops, style, value, x, y, blockId, reference)
    ops[#ops + 1] = { op = "text", style = style, text = Escape(value), x = x, y = y, blockId = blockId,
        reference = reference }
end

function RenderOps.Build(page, measurer, highlight)
    local ops = {}
    for _, unit in ipairs(page.units) do
        if unit.kind == "line" then
            highlightOp(ops, unit, highlight, measurer)
            if unit.marker then
                text(ops, unit.style, unit.marker, 0, unit.y, unit.blockId)
            end
            if unit.checkItemId then
                ops[#ops + 1] = { op = "checkbox", itemId = unit.checkItemId, blockId = unit.blockId,
                    x = 0, y = unit.y, size = measurer:LineHeight(unit.style) }
            end
            text(ops, unit.style, unit.text, unit.x, unit.y, unit.blockId, unit.reference)
        elseif unit.kind == "figure" then
            ops[#ops + 1] = { op = "image", assetId = unit.assetId, alt = Escape(unit.alt), x = unit.x or 0, y = unit.y,
                width = unit.imageWidth, height = unit.imageHeight, blockId = unit.blockId }
            local lineHeight = measurer:LineHeight("caption")
            local top = unit.y + unit.imageHeight + unit.captionGap
            for i, line in ipairs(unit.captionLines) do
                text(ops, "caption", line, 0, top + (i - 1) * lineHeight, unit.blockId)
            end
        elseif unit.kind == "row" then
            local labelHeight = measurer:LineHeight(unit.labelStyle)
            for i, line in ipairs(unit.labelLines) do
                text(ops, unit.labelStyle, line, 0, unit.y + (i - 1) * labelHeight, unit.blockId)
            end
            local valueHeight = measurer:LineHeight(unit.valueStyle)
            for i, line in ipairs(unit.valueLines) do
                text(ops, unit.valueStyle, line, unit.valueX, unit.y + (i - 1) * valueHeight, unit.blockId)
            end
        end
    end
    return ops
end
