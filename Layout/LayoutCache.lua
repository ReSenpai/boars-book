local _, LB = ...

-- Session-only cache of chapter layouts. Never persisted: SavedVariables keep
-- semantic positions, not geometry.
local LayoutCache = {}
LayoutCache.__index = LayoutCache
LB.LayoutCache = LayoutCache

function LayoutCache.New()
    return setmetatable({ entries = {} }, LayoutCache)
end

function LayoutCache.Key(bookId, revision, chapterId, width, height, fontKey)
    return table.concat({ bookId, tostring(revision), chapterId, tostring(width), tostring(height),
        tostring(fontKey) }, "|")
end

function LayoutCache:Get(key)
    return self.entries[key]
end

function LayoutCache:Put(key, layout)
    self.entries[key] = layout
end

function LayoutCache:Clear()
    self.entries = {}
end
