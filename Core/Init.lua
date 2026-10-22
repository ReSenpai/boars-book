local ADDON_NAME, LB = ...

LB.ADDON_NAME = ADDON_NAME
LB.version = "0.0.1"

-- Client branch this package is built for. Set explicitly per package, never guessed.
LB.BUILD_FLAVOR = "classic-era"

-- What this package is: the whole library ("library") or one book that can only be
-- read ("book", built by tools/make_book_addon.py; its Core/Edition.lua replaces this).
LB.Edition = { kind = "library" }

function LB.IsBookEdition()
    return LB.Edition.kind == "book"
end

-- Global names (frames, fonts, saved variables) start with the addon's folder name,
-- so a book addon never collides with Lore Book itself.
function LB.GlobalName(suffix)
    return ADDON_NAME .. suffix
end

LB.Compat = LB.Compat or {}
