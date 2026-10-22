local _, LB = ...

-- Runs a function once, `delay` seconds after the last Trigger().
-- `after(delay, fn)` is the scheduler (C_Timer.After in game). Pure.
local Debounce = {}
Debounce.__index = Debounce
LB.Debounce = Debounce

function Debounce.New(delay, fn, after)
    return setmetatable({ delay = delay, fn = fn, after = after, generation = 0 }, Debounce)
end

function Debounce:Trigger()
    self.generation = self.generation + 1
    local generation = self.generation
    self.after(self.delay, function()
        if generation == self.generation then
            self.fn()
        end
    end)
end

function Debounce:Cancel()
    self.generation = self.generation + 1
end
