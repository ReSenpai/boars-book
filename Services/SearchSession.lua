local _, LB = ...

-- Walks through search matches without touching the saved reading position.
-- The position to return to is kept separately. Pure.
local SearchSession = {}
SearchSession.__index = SearchSession
LB.SearchSession = SearchSession

function SearchSession.New(matches, returnAnchor)
    return setmetatable({ matches = matches, index = 0, returnAnchor = returnAnchor }, SearchSession)
end

function SearchSession:Count()
    return #self.matches
end

function SearchSession:Current()
    return self.matches[self.index]
end

function SearchSession:Next()
    local n = #self.matches
    if n == 0 then return nil end
    self.index = self.index % n + 1
    return self.matches[self.index]
end

function SearchSession:Prev()
    local n = #self.matches
    if n == 0 then return nil end
    self.index = self.index <= 1 and n or self.index - 1
    return self.matches[self.index]
end

function SearchSession:ReturnAnchor()
    return self.returnAnchor
end
