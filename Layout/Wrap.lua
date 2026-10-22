local _, LB = ...

-- Greedy line wrapping by code points with an injected width function.
-- Lines carry offsets into the original text, so positions survive re-wrapping.
-- Pure: no WoW API.
local Wrap = {}
LB.Wrap = Wrap

local concat = table.concat

-- Returns { { text, offset, length } }: offset = code points before the line,
-- length = code points in the line. Spaces at breaks are dropped, "\n" forces a break,
-- words wider than the line are split between characters.
function Wrap.Lines(text, maxWidth, measure)
    local chars = LB.Utf8.Chars(text)
    local lines = {}
    local spaceWidth = measure(" ")

    local function emit(first, last)
        lines[#lines + 1] = {
            text = concat(chars, "", first, last),
            offset = first - 1,
            length = last - first + 1,
        }
    end

    local function wrapParagraph(first, last)
        if first > last then
            lines[#lines + 1] = { text = "", offset = first - 1, length = 0 }
            return
        end
        local lineStart, lineEnd, lineWidth

        local function startLine(wordStart, wordEnd, wordWidth)
            if wordWidth <= maxWidth then
                lineStart, lineEnd, lineWidth = wordStart, wordEnd, wordWidth
                return
            end
            local chunkStart, chunkWidth = wordStart, 0
            for k = wordStart, wordEnd do
                local charWidth = measure(chars[k])
                if chunkWidth + charWidth > maxWidth and k > chunkStart then
                    emit(chunkStart, k - 1)
                    chunkStart, chunkWidth = k, charWidth
                else
                    chunkWidth = chunkWidth + charWidth
                end
            end
            lineStart, lineEnd, lineWidth = chunkStart, wordEnd, chunkWidth
        end

        local j = first
        while j <= last do
            if chars[j] == " " then
                j = j + 1
            else
                local wordStart = j
                while j <= last and chars[j] ~= " " do
                    j = j + 1
                end
                local wordEnd = j - 1
                local wordWidth = measure(concat(chars, "", wordStart, wordEnd))
                if not lineStart then
                    startLine(wordStart, wordEnd, wordWidth)
                else
                    local gapWidth = (wordStart - lineEnd - 1) * spaceWidth
                    if lineWidth + gapWidth + wordWidth <= maxWidth then
                        lineEnd = wordEnd
                        lineWidth = lineWidth + gapWidth + wordWidth
                    else
                        emit(lineStart, lineEnd)
                        startLine(wordStart, wordEnd, wordWidth)
                    end
                end
            end
        end
        if lineStart then
            emit(lineStart, lineEnd)
        else
            lines[#lines + 1] = { text = "", offset = first - 1, length = 0 }
        end
    end

    local paragraphStart = 1
    for i = 1, #chars do
        if chars[i] == "\n" then
            wrapParagraph(paragraphStart, i - 1)
            paragraphStart = i + 1
        end
    end
    wrapParagraph(paragraphStart, #chars)
    return lines
end
