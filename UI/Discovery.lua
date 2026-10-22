local _, LB = ...

-- Discoveries in the game: targeting an NPC from the book records it (account-wide),
-- plays the quest "writing" sound and shows a toast; found NPCs get a seal next to
-- their heading in the book, with a card telling when and where they were found.
local Discovery = {}
LB.Discovery = Discovery

local L = LB.L
local Theme = LB.Theme
local Discoveries = LB.Discoveries
local Escape = LB.Text.EscapeForUI

-- Seal of a found NPC: the book's own medallion (addon.json "seal": Assets/Seal.tga
-- for large sizes, Assets/SealSmall.tga for small ones), or a client icon.
Discovery.SEAL_ICON = "Interface\\Icons\\Ability_Hunter_Pet_Boar"

function Discovery.ApplySeal(texture, large)
    if LB.BookManifest.seal then
        texture:SetTexture("Interface\\AddOns\\" .. LB.ADDON_NAME .. "\\Assets\\" .. (large and "Seal" or "SealSmall"))
        texture:SetTexCoord(0, 1, 0, 1)
    else
        texture:SetTexture(Discovery.SEAL_ICON)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end
-- SOUNDKIT names tried in order for the "writing" sound. Era 1.15.9 (/boars probe,
-- 2026-10-22): IG_QUEST_LIST_OPEN = 875; WRITE_QUEST does not exist.
Discovery.SOUNDS = { "IG_QUEST_LIST_OPEN" }
local SEAL_GAP = 6

function Discovery.Index()
    Discovery.index = Discovery.index or Discoveries.Index(LB.BookAchievements)
    return Discovery.index
end

-- Account-wide records (created on first use; never part of the book itself).
function Discovery.DB()
    local account = LB.store.account
    account.discoveries = account.discoveries or {}
    return account.discoveries
end

local function writable()
    return LB.store and not LB.store.readOnly
end

function Discovery.Title(item)
    return Discoveries.Title(item, LB.BookApp.Language(), LB.BookManifest.original)
end

-- Parchment of the current book on a small panel: the middle band of the sheet,
-- cut to the panel's proportions so the paper grain is not stretched.
function Discovery.DressPanel(frame, width, height)
    if type(frame.parchment) ~= "table" then
        frame.parchment = frame:CreateTexture(nil, "BACKGROUND")
        frame.parchment:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
        frame.parchment:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
        frame:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        local brass = Theme.colors.brass
        frame:SetBackdropBorderColor(brass[1], brass[2], brass[3], 1)
    end
    local parchment = Theme.ParchmentOf(LB.BookApp.CurrentBook())
    frame.parchment:SetTexture(parchment.texture)
    local band = math.min(0.9, 0.9 * height / width)
    frame.parchment:SetTexCoord(0.05, 0.95, 0.5 - band / 2, 0.5 + band / 2)
    frame.parchment:SetVertexColor(1, 1, 1, 1)
end

function Discovery.PlaySound()
    if type(SOUNDKIT) ~= "table" or type(PlaySound) ~= "function" then return end
    for _, name in ipairs(Discovery.SOUNDS) do
        if SOUNDKIT[name] then
            PlaySound(SOUNDKIT[name])
            return
        end
    end
end

-- Where and when the player is now.
local function placeInfo()
    local info = { at = time(), zone = GetRealZoneText and GetRealZoneText() or nil,
        subzone = GetSubZoneText and GetSubZoneText() or nil, character = UnitName("player"),
        level = UnitLevel and UnitLevel("target") or nil }
    if info.subzone == "" then info.subzone = nil end
    if type(C_Map) == "table" and C_Map.GetBestMapForUnit then
        local mapId = C_Map.GetBestMapForUnit("player")
        info.mapId = mapId
        local position = mapId and C_Map.GetPlayerMapPosition(mapId, "player")
        if position then
            local x, y = position:GetXY()
            if x and y and (x > 0 or y > 0) then
                info.x, info.y = math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
            end
        end
    end
    return info
end

-- Redraws everything that shows discoveries.
function Discovery.Refresh()
    if LB.Reader.IsShown() and LB.Reader.state then LB.Reader.Render() end
    LB.PageWindows.Redraw()
    if LB.DiscoveryJournal then LB.DiscoveryJournal.Refresh() end
end

-- A targeted unit: records a new discovery. Returns the definition when it was new.
function Discovery.OnTarget(guid)
    local def = Discoveries.ForNpc(Discovery.Index(), Discoveries.NpcId(guid))
    if not def or not writable() then return nil end
    local record, completed = Discoveries.Record(Discovery.DB(), Discovery.Index(), def, placeInfo())
    if not record then return nil end
    Discovery.PlaySound()
    LB.DiscoveryToast.Show({ def = def })
    for _, meta in ipairs(completed) do
        LB.DiscoveryToast.Show({ meta = meta })
    end
    local found, total = Discoveries.Count(Discovery.DB(), Discovery.Index())
    LB.Commands.Print(L("DISCOVERY_CHAT", Discovery.Title(def), found, total))
    Discovery.Refresh()
    return def
end

-- Forgets every discovery (testing; /boars found reset).
function Discovery.Reset()
    if not writable() then return end
    LB.store.account.discoveries = {}
    LB.DiscoveryToast.Clear()
    Discovery.HideCard()
    Discovery.Refresh()
    LB.Commands.Print(L("DISCOVERY_RESET"))
end

-- Opens a page window on the discovery's heading; the toast and the journal use it.
function Discovery.OpenPage(def)
    Discoveries.MarkSeen(Discovery.DB(), def.id)
    LB.PageWindows.Open(LB.BookApp.CurrentBook(), { chapterId = def.chapterId, blockId = def.blockId, textOffset = 0 })
    Discovery.Refresh()
end

-- "22.10.2026 14:05", "Elwynn Forest, Brackwell Pumpkin Patch (42.1, 65.3)".
function Discovery.FormatWhen(record)
    return date("%d.%m.%Y %H:%M", record.at)
end

function Discovery.FormatWhere(record)
    local where = record.zone or "?"
    if record.subzone and record.subzone ~= record.zone then where = where .. ", " .. record.subzone end
    if record.x and record.y then where = string.format("%s (%.1f, %.1f)", where, record.x, record.y) end
    return where
end

-- Card --------------------------------------------------------------------------

local CARD_WIDTH = 300

local function card()
    if Discovery.card then return Discovery.card end
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetClampedToScreen(true)
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetFontObject(LB.Fonts.Get("caption"))
    frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
    frame.text:SetWidth(CARD_WIDTH - 28)
    frame.text:SetJustifyH("LEFT")
    frame.text:SetWordWrap(true)
    frame:Hide()
    Discovery.card = frame
    return frame
end

-- Text of the card for the discoveries behind one heading (found ones only).
function Discovery.CardText(defs)
    local db, parts = Discovery.DB(), {}
    for _, def in ipairs(defs) do
        local record = db[def.id]
        if record then
            local lines = { Escape(Discovery.Title(def)),
                L("DISCOVERY_FOUND_AT", Discovery.FormatWhen(record)),
                L("DISCOVERY_WHERE", Escape(Discovery.FormatWhere(record))) }
            if record.level then lines[#lines + 1] = L("DISCOVERY_LEVEL", record.level) end
            if record.character then lines[#lines + 1] = L("DISCOVERY_CHARACTER", Escape(record.character)) end
            parts[#parts + 1] = table.concat(lines, "\n")
        end
    end
    return table.concat(parts, "\n\n")
end

function Discovery.ShowCard(owner, defs)
    local frame = card()
    frame.text:SetText(Discovery.CardText(defs))
    local height = (frame.text:GetStringHeight() or 60) + 24
    frame:SetSize(CARD_WIDTH, height)
    Discovery.DressPanel(frame, CARD_WIDTH, height)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 4, 4)
    frame:Show()
end

function Discovery.HideCard()
    if Discovery.card then Discovery.card:Hide() end
end

-- Seals -------------------------------------------------------------------------

local function sealPool(page)
    if type(page.sealPool) ~= "table" then
        page.sealPool = LB.WidgetPool.New(function()
            local seal = CreateFrame("Button", nil, page)
            seal.icon = seal:CreateTexture(nil, "ARTWORK")
            seal.icon:SetAllPoints(seal)
            Discovery.ApplySeal(seal.icon, false)
            seal:SetScript("OnEnter", function(self) Discovery.ShowCard(self, self.defs) end)
            seal:SetScript("OnLeave", Discovery.HideCard)
            seal:SetScript("OnClick", function(self) Discovery.ShowCard(self, self.defs) end)
            return seal
        end, function(seal)
            seal:Hide()
            seal:ClearAllPoints()
        end)
    end
    return page.sealPool
end

-- PageView decorator: a seal after the last line of every heading with a found NPC.
function Discovery.Decorate(page, ops, measurer)
    local pool = sealPool(page)
    pool:ReleaseAll()
    if not LB.store then return end
    local db, index = Discovery.DB(), Discovery.Index()
    local last = {}
    for _, op in ipairs(ops) do
        if op.op == "text" and op.blockId and index.byBlock[op.blockId] then last[op.blockId] = op end
    end
    for blockId, op in pairs(last) do
        local found = {}
        for _, def in ipairs(Discoveries.ForBlock(index, blockId)) do
            if db[def.id] then found[#found + 1] = def end
        end
        if #found > 0 then
            local seal = pool:Acquire()
            local size = measurer:LineHeight(op.style)
            seal.defs = found
            seal:SetSize(size, size)
            seal:SetPoint("TOPLEFT", page, "TOPLEFT", op.x + measurer:Width(op.text, op.style) + SEAL_GAP, -op.y)
            seal:Show()
        end
    end
end

-- Probe (development): what the client tells about the target, the map and sounds.
local function probe(args)
    local print = LB.Commands.Print
    local name = string.match(args or "", "^sound%s+(%S+)$")
    if name then
        local id = tonumber(name) or (type(SOUNDKIT) == "table" and SOUNDKIT[name])
        print("sound " .. name .. " = " .. tostring(id))
        if id then PlaySound(id) end
        return
    end
    if args == "toast" then
        LB.DiscoveryToast.Show({ def = Discovery.Index().list[1] })
        return
    end
    local guid = UnitGUID("target")
    print("target guid: " .. tostring(guid) .. ", npcId: " .. tostring(Discoveries.NpcId(guid)))
    local info = placeInfo()
    print(string.format("map %s, x %s, y %s, zone %s, subzone %s", tostring(info.mapId), tostring(info.x),
        tostring(info.y), tostring(info.zone), tostring(info.subzone)))
    for _, sound in ipairs({ "IG_ABILITY_PAGE_TURN", "IG_SPELLBOOK_OPEN", "IG_SPELLBOOK_CLOSE" }) do
        print("SOUNDKIT." .. sound .. " = " .. tostring(type(SOUNDKIT) == "table" and SOUNDKIT[sound]))
    end
    for _, sound in ipairs(Discovery.SOUNDS) do
        print("SOUNDKIT." .. sound .. " = " .. tostring(type(SOUNDKIT) == "table" and SOUNDKIT[sound]))
    end
end

function Discovery.Init()
    LB.PageView.AddDecorator(Discovery.Decorate)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:SetScript("OnEvent", function() Discovery.OnTarget(UnitGUID("target")) end)
    Discovery.events = events
    LB.Commands.Register("found", function(args)
        if args == "reset" then
            Discovery.Reset()
            return
        end
        local found, total = Discoveries.Count(Discovery.DB(), Discovery.Index())
        LB.Commands.Print(L("DISCOVERY_PROGRESS", found, total))
    end, "BOOK_CMD_HELP_FOUND")
    LB.Commands.Register("probe", probe, "BOOK_CMD_HELP_PROBE")
end
