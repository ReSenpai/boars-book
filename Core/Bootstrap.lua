local ADDON_NAME, LB = ...

-- Book edition life cycle: saved variables <Addon>DB / <Addon>CharacterDB (reading
-- place, window, settings - never the book itself), language, slash command.
local function openStorage()
    local accountName, characterName = LB.GlobalName("DB"), LB.GlobalName("CharacterDB")
    local store = LB.Storage.Open(_G[accountName], _G[characterName], { now = time })
    _G[accountName] = store.account
    _G[characterName] = store.character
    LB.store = store
    if store.status == "newer" or store.characterStatus == "newer" then
        LB.Commands.Print(LB.L("STORAGE_NEWER"))
    elseif store.status == "failed" or store.characterStatus == "failed" then
        LB.Commands.Print(LB.L("STORAGE_FAILED"))
    end
end

local function registerCommands()
    local Commands, BookApp = LB.Commands, LB.BookApp
    Commands.SetDefault(function() BookApp.ToggleReader() end)
    Commands.Register("read", function() BookApp.ToggleReader() end, "BOOK_CMD_HELP_READ")
    Commands.Register("window", function() BookApp.OpenWindow() end, "BOOK_CMD_HELP_WINDOW")
    Commands.Register("font", function(args)
        local size = tonumber(args)
        if size then
            LB.Reader.SetFontSize(size)
            LB.PageWindows.Refresh()
        end
        Commands.Print(LB.L("FONT_SET", LB.Fonts.GetBodySize()))
    end, "BOOK_CMD_HELP_FONT")
    Commands.Register("lang", function(args)
        local language = args ~= "" and LB.Translations.Parse(args) or LB.Translations.Next(BookApp.Language())
        if language then
            BookApp.SetLanguage(language)
            Commands.Print(LB.L("BOOK_LANGUAGE_SET", LB.L("LANGUAGE_" .. language)))
        else
            Commands.PrintHelp()
        end
    end, "BOOK_CMD_HELP_LANG")
    Commands.Register("minimap", function() LB.MinimapButton.Toggle() end, "BOOK_CMD_HELP_MINIMAP")
end

local function onAddonLoaded()
    local manifest = LB.BookManifest
    LB.Commands.SetOutput(function(line) print("|cffa58042" .. LB.BookApp.Title() .. "|r: " .. line) end)
    LB.Commands.SetSlash(manifest.slash, "BOOK_CMD_HEADER")
    openStorage()
    LB.BookApp.Init(LB.store, GetLocale())
    local settings = LB.store.account.settings or {}
    LB.Fonts.Init(settings.fontSize or LB.Theme.DEFAULT_BODY_SIZE)
    registerCommands()
    LB.MinimapButton.Init()
    LB.Discovery.Init()

    local key = string.upper(ADDON_NAME)
    _G["SLASH_" .. key .. "1"] = manifest.slash
    SlashCmdList[key] = function(message) LB.Commands.Dispatch(message) end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        onAddonLoaded()
    end
end)
