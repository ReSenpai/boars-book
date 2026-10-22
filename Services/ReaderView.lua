local _, LB = ...

-- Reader view decisions: spread or single page, page geometry, key handling. Pure.
local ReaderView = {}
LB.ReaderView = ReaderView

ReaderView.SPREAD_MIN_CONTENT_WIDTH = 720
ReaderView.SPREAD_MAX_BODY_SIZE = 20
ReaderView.MAX_SINGLE_WIDTH = 560
ReaderView.GUTTER = 40

-- contentWidth/contentHeight: the area available for pages inside the window.
function ReaderView.Geometry(contentWidth, contentHeight, bodySize)
    if contentWidth >= ReaderView.SPREAD_MIN_CONTENT_WIDTH and bodySize <= ReaderView.SPREAD_MAX_BODY_SIZE then
        return {
            mode = "spread",
            pagesPerView = 2,
            pageWidth = (contentWidth - ReaderView.GUTTER) / 2,
            pageHeight = contentHeight,
        }
    end
    return {
        mode = "single",
        pagesPerView = 1,
        pageWidth = math.min(contentWidth, ReaderView.MAX_SINGLE_WIDTH),
        pageHeight = contentHeight,
    }
end

-- First page of the view containing `page`.
function ReaderView.ViewStart(page, pagesPerView)
    return page - (page - 1) % pagesPerView
end

local KEY_ACTIONS = { PAGEDOWN = 1, PAGEUP = -1 }

-- Page step for a key, only when the book has explicit focus; nil = let it through.
function ReaderView.KeyAction(key, focused)
    if not focused then return nil end
    return KEY_ACTIONS[key]
end
