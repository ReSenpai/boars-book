local _, LB = ...

local FALLBACK = "enUS"
local SUPPORTED = { enUS = true, ruRU = true }

local tables = {}
local active = FALLBACK

local Locale = {}
LB.Locale = Locale

-- Merges strings into the given locale table.
function Locale.Register(locale, strings)
    tables[locale] = tables[locale] or {}
    for key, value in pairs(strings) do
        tables[locale][key] = value
    end
end

function Locale.SetActive(locale)
    active = SUPPORTED[locale] and locale or FALLBACK
end

function Locale.GetActive()
    return active
end

function Locale.GetTable(locale)
    return tables[locale] or {}
end

function Locale.Get(key, ...)
    local text = (tables[active] and tables[active][key])
        or (tables[FALLBACK] and tables[FALLBACK][key])
        or key
    if select("#", ...) > 0 then
        return string.format(text, ...)
    end
    return text
end

LB.L = Locale.Get
