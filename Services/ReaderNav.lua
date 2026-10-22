local _, LB = ...

-- Page navigation. Pure.
-- The pages of all chapters form one sequence for the whole book: a chapter
-- that ends on a left page is followed by the next chapter on the right page,
-- and the reader shows one book-wide page count.
-- pagesPerView = 2 for spreads: a view always starts on an odd (left) page.
local ReaderNav = {}
LB.ReaderNav = ReaderNav

local function viewStart(page, perView)
    return page - (page - 1) % perView
end

-- counts[chapterIndex] = number of pages -> { starts = { first book page per chapter }, total }.
function ReaderNav.Flow(counts)
    local starts, total = {}, 0
    for index, count in ipairs(counts) do
        starts[index] = total + 1
        total = total + count
    end
    return { starts = starts, counts = counts, total = total }
end

function ReaderNav.ToGlobal(flow, chapterIndex, pageIndex)
    return flow.starts[chapterIndex] + pageIndex - 1
end

-- Book page -> chapterIndex, pageIndex (nil outside the book).
function ReaderNav.ToLocal(flow, page)
    if page < 1 or page > flow.total then return nil end
    for index = #flow.starts, 1, -1 do
        if flow.starts[index] <= page then
            return index, page - flow.starts[index] + 1
        end
    end
end

function ReaderNav.Step(page, delta, total, pagesPerView)
    local perView = pagesPerView or 1
    local last = viewStart(math.max(total, 1), perView)
    local moved = viewStart(page, perView)
    if delta > 0 then
        moved = moved + perView
    elseif delta < 0 then
        moved = moved - perView
    end
    return math.max(1, math.min(moved, last))
end

function ReaderNav.CanStep(page, delta, total, pagesPerView)
    return ReaderNav.Step(page, delta, total, pagesPerView) ~= viewStart(page, pagesPerView or 1)
end
