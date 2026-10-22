local _, LB = ...

-- The one window of the library and the reader: a game panel whose content is a
-- view (a child frame per module). Switching views keeps the window's place and
-- size; closing the window hides every view.
local MainWindow = {}
LB.MainWindow = MainWindow

local Widgets = LB.Widgets

MainWindow.DEFAULT_WIDTH, MainWindow.DEFAULT_HEIGHT = 980, 660
MainWindow.MIN_WIDTH, MainWindow.MIN_HEIGHT = 760, 420
MainWindow.MAX_WIDTH, MainWindow.MAX_HEIGHT = 1600, 1200
MainWindow.RESIZE_DELAY = 0.15

MainWindow.views = {}

local function windowProfile()
    local store = LB.store
    if not store then return nil end
    local profiles = store.account.clientProfiles
    profiles[LB.BUILD_FLAVOR] = profiles[LB.BUILD_FLAVOR] or {}
    return profiles[LB.BUILD_FLAVOR]
end

local function restoreWindow(frame)
    local profile = windowProfile()
    -- `reader` is where the reader kept its window before it was shared.
    local saved = profile and (profile.window or profile.reader)
    if type(saved) ~= "table" then return end
    if type(saved.width) == "number" and type(saved.height) == "number" then
        frame:SetSize(math.max(MainWindow.MIN_WIDTH, saved.width), math.max(MainWindow.MIN_HEIGHT, saved.height))
    end
    if type(saved.point) == "string" then
        frame:ClearAllPoints()
        frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    end
end

function MainWindow.SaveWindow()
    local frame = MainWindow.frame
    if not frame or not LB.store or LB.store.readOnly then return end
    local point, _, relativePoint, x, y = frame:GetPoint()
    windowProfile().window = {
        width = frame:GetWidth(), height = frame:GetHeight(),
        point = point, relativePoint = relativePoint, x = x, y = y,
    }
end

local function createResizeGrip(frame)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        MainWindow.SaveWindow()
    end)
    return grip
end

local function hideViews()
    for _, view in pairs(MainWindow.views) do
        view.frame:Hide()
    end
end

local function createFrame()
    local frame = Widgets.CreateWindow(LB.GlobalName("Frame"), MainWindow.DEFAULT_WIDTH, MainWindow.DEFAULT_HEIGHT, {
        onMoved = function() MainWindow.SaveWindow() end,
    })
    frame:SetResizable(true)
    LB.Compat.SetResizeBounds(frame, MainWindow.MIN_WIDTH, MainWindow.MIN_HEIGHT,
        MainWindow.MAX_WIDTH, MainWindow.MAX_HEIGHT)
    -- Page parchments of the reader: one sheet per page (see Theme.ReaderBackground).
    frame.sheets = {}
    for index = 1, 2 do
        local sheet = frame.inset:CreateTexture(nil, "BACKGROUND", nil, 3)
        sheet:Hide()
        frame.sheets[index] = sheet
    end
    frame.grip = createResizeGrip(frame)
    frame:SetScript("OnSizeChanged", function()
        if MainWindow.resizeDebounce then MainWindow.resizeDebounce:Trigger() end
    end)
    frame:SetScript("OnHide", function()
        hideViews()
        LB.Compat.PlayBookClose()
    end)
    return frame
end

function MainWindow.Frame()
    if not MainWindow.frame then
        MainWindow.frame = createFrame()
        MainWindow.resizeDebounce = LB.Debounce.New(MainWindow.RESIZE_DELAY, function()
            MainWindow.SaveWindow()
            local view = MainWindow.views[MainWindow.current]
            if view and view.frame:IsShown() and view.onResize then view.onResize() end
        end, LB.Compat.After)
        restoreWindow(MainWindow.frame)
    end
    return MainWindow.frame
end

-- A view covering the whole window; options = { onResize? }.
function MainWindow.AddView(name, options)
    local window = MainWindow.Frame()
    local view = CreateFrame("Frame", nil, window)
    view:SetAllPoints(window)
    view:Hide()
    MainWindow.views[name] = { frame = view, onResize = options and options.onResize }
    return view
end

-- Shows the window with one view; the others are hidden.
function MainWindow.ShowView(name)
    local window = MainWindow.Frame()
    local opening = not window:IsShown()
    local switching = not opening and MainWindow.current ~= name
    MainWindow.current = name
    for viewName, view in pairs(MainWindow.views) do
        view.frame:SetShown(viewName == name)
    end
    MainWindow.ResetBackground()
    window:Show()
    -- Opening sounds like a book opening; another view in the open window, like a page turning.
    if opening then
        LB.Compat.PlayBookOpen()
    elseif switching then
        LB.Compat.PlayPageTurn()
    end
end

function MainWindow.IsShowing(name)
    local view = MainWindow.views[name]
    return MainWindow.frame ~= nil and MainWindow.frame:IsShown() and view ~= nil and view.frame:IsShown()
end

function MainWindow.Hide()
    if MainWindow.frame then
        MainWindow.frame:Hide()
        hideViews()
    end
end

-- Window size; views lay out from it (a view's own size follows the window).
function MainWindow.Size()
    local frame = MainWindow.Frame()
    return frame:GetWidth(), frame:GetHeight()
end

-- The menu parchment over the whole inset, no page sheets.
function MainWindow.ResetBackground()
    local frame = MainWindow.Frame()
    Widgets.ApplyParchment(frame.parchment)
    frame.parchment:Show()
    for _, sheet in ipairs(frame.sheets) do
        sheet:Hide()
    end
end
