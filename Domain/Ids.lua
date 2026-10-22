local _, LB = ...

-- Opaque local IDs: "<prefix>.<time base36>.<counter>". Matching key only,
-- never a proof of identity. Pure.
local Ids = {}
LB.Ids = Ids

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

function Ids.Base36(n)
    n = math.floor(n)
    if n <= 0 then return "0" end
    local out = {}
    while n > 0 do
        local d = n % 36
        table.insert(out, 1, string.sub(DIGITS, d + 1, d + 1))
        n = math.floor(n / 36)
    end
    return table.concat(out)
end

function Ids.Generate(prefix, now, counter)
    return prefix .. "." .. Ids.Base36(now) .. "." .. Ids.Base36(counter)
end
