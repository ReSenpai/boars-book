local _, LB = ...

-- Reusable widget pool: widgets are created on demand and recycled, so the
-- number of UI objects is bounded by the busiest visible page.
local WidgetPool = {}
WidgetPool.__index = WidgetPool
LB.WidgetPool = WidgetPool

function WidgetPool.New(create, reset)
    return setmetatable({ create = create, reset = reset, free = {}, active = {} }, WidgetPool)
end

function WidgetPool:Acquire()
    local widget = table.remove(self.free)
    if not widget then
        widget = self.create()
    end
    self.active[#self.active + 1] = widget
    return widget
end

function WidgetPool:ReleaseAll()
    for i = #self.active, 1, -1 do
        local widget = self.active[i]
        if self.reset then self.reset(widget) end
        self.free[#self.free + 1] = widget
        self.active[i] = nil
    end
end

function WidgetPool:ActiveCount()
    return #self.active
end
