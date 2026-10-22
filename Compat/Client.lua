local _, LB = ...

-- Small client API differences and helpers behind one interface.
local Compat = LB.Compat

function Compat.After(delay, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, fn)
    else
        fn()
    end
end

function Compat.PlayerName()
    local name = UnitName and UnitName("player")
    return name or "?"
end

-- The first SOUNDKIT sound the client has; silent when it has none of them.
local function playFirst(...)
    if type(SOUNDKIT) ~= "table" or not PlaySound then return end
    for i = 1, select("#", ...) do
        local id = SOUNDKIT[select(i, ...)]
        if id then
            PlaySound(id)
            return
        end
    end
end

-- The spellbook's sounds: a page turn, the book opening and closing.
function Compat.PlayPageTurn()
    playFirst("IG_ABILITY_PAGE_TURN")
end

function Compat.PlayBookOpen()
    playFirst("IG_SPELLBOOK_OPEN", "IG_ABILITY_PAGE_TURN")
end

function Compat.PlayBookClose()
    playFirst("IG_SPELLBOOK_CLOSE", "IG_ABILITY_PAGE_TURN")
end

function Compat.InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local pendingTasks = {}
local safeFrame

local function runPending(frame)
    frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local tasks = pendingTasks
    pendingTasks = {}
    for _, task in ipairs(tasks) do
        local ok, err = pcall(task)
        if not ok and geterrorhandler then
            geterrorhandler()(err)
        end
    end
end

-- Runs heavy or state-changing addon work now, or after combat ends.
-- Returns true when the task ran immediately.
function Compat.RunWhenSafe(task)
    if not Compat.InCombat() then
        task()
        return true
    end
    pendingTasks[#pendingTasks + 1] = task
    if not safeFrame then
        safeFrame = CreateFrame("Frame")
        safeFrame:SetScript("OnEvent", runPending)
    end
    safeFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    return false
end

-- SetResizeBounds is newer; older clients use SetMinResize/SetMaxResize.
function Compat.SetResizeBounds(frame, minWidth, minHeight, maxWidth, maxHeight)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    else
        if frame.SetMinResize then frame:SetMinResize(minWidth, minHeight) end
        if frame.SetMaxResize then frame:SetMaxResize(maxWidth, maxHeight) end
    end
end
