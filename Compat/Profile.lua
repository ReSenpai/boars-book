local _, LB = ...

-- APIs whose presence selects feature implementations. Order is the display order.
local FEATURE_PATHS = {
    "C_Timer.After",
    "C_Item.GetItemInfo",
    "GetItemInfo",
    "C_Spell.GetSpellInfo",
    "GetSpellInfo",
    "Settings.RegisterCanvasLayoutCategory",
    "InterfaceOptions_AddCategory",
    "UnitGUID",
}

-- Interface number ranges per branch, from verified client builds only.
local KNOWN_FLAVORS = {
    { flavor = "classic-era", min = 11500, max = 11599 },
}

local function lookup(env, path)
    local value = env
    for part in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return value
end

local function observeFlavor(interface)
    if type(interface) ~= "number" then
        return "unknown"
    end
    for _, entry in ipairs(KNOWN_FLAVORS) do
        if interface >= entry.min and interface <= entry.max then
            return entry.flavor
        end
    end
    return "unknown"
end

-- Builds a client profile from an environment table (the global table in game).
function LB.Compat.BuildProfile(env, expectedFlavor)
    local version, build, interface
    if type(env.GetBuildInfo) == "function" then
        local _
        version, build, _, interface = env.GetBuildInfo()
    end
    local locale = type(env.GetLocale) == "function" and env.GetLocale() or "?"

    local features = {}
    for _, path in ipairs(FEATURE_PATHS) do
        features[path] = type(lookup(env, path)) == "function"
    end

    local observed = observeFlavor(interface)
    local warnings = {}
    if observed ~= expectedFlavor then
        table.insert(warnings, "DEBUG_WARN_FLAVOR_MISMATCH")
    end

    return {
        version = version or "?",
        build = build or "?",
        interface = interface or "?",
        locale = locale,
        expectedFlavor = expectedFlavor,
        observedFlavor = observed,
        features = features,
        featureOrder = FEATURE_PATHS,
        warnings = warnings,
    }
end

local cachedProfile

function LB.Compat.GetClientProfile()
    if not cachedProfile then
        cachedProfile = LB.Compat.BuildProfile(_G, LB.BUILD_FLAVOR)
    end
    return cachedProfile
end
