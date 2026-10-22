local _, LB = ...

-- Table helpers. Pure: no WoW API.
local Tables = {}
LB.Tables = Tables

-- Deep copy of plain data. Tables with a metatable (sentinels such as Json.NULL)
-- are shared, not copied.
function Tables.DeepCopy(value)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[Tables.DeepCopy(k)] = Tables.DeepCopy(v)
    end
    return copy
end

-- Bytewise string order, independent of the C locale used by `<`.
function Tables.BytewiseLess(a, b)
    local n = math.min(#a, #b)
    for i = 1, n do
        local x, y = string.byte(a, i), string.byte(b, i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end
