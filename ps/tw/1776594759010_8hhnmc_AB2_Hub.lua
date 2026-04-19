--[[
    AB2 Hub - Main Hub Script
    Handles: Game check, file structure, UI, asset loading, feature control
]]

--// SERVICES
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

--// CONFIG
local TARGET_PLACE_ID = 83861332438631

local HUB_ICON_URL        = "https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/v9/po/1776589182907_pfag7s_Approaching_bearable_1.png"
local HUB_OPEN_SOUND_URL  = "PLACEHOLDER_HUB_OPEN_SOUND_URL"
local HUB_CLOSE_SOUND_URL = "PLACEHOLDER_HUB_CLOSE_SOUND_URL"

local AUTOFISH_SCRIPT_URL = "https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/refs/heads/main/xp/84/1776425291737_5hcwpy_ApproachingBearable2AutoFish.lua"

--// GLOBAL HUB STATE
_G.AB2Hub = _G.AB2Hub or {}
_G.AB2Hub.Features = _G.AB2Hub.Features or {}

--// ─────────────────────────────────────────────
--//  1. GAME CHECK
--// ─────────────────────────────────────────────
if game.PlaceId ~= TARGET_PLACE_ID then
    local bindable = Instance.new("BindableFunction")
    bindable.OnInvoke = function(buttonText)
        if buttonText == "Join Game" then
            TeleportService:Teleport(TARGET_PLACE_ID, Players.LocalPlayer)
        end
    end
    StarterGui:SetCore("SendNotification", {
        Title    = "AB2 Hub — Wrong Game!",
        Text     = "This hub is for Approaching Bearable 2. Would you like to join?",
        Duration = 15,
        Callback = bindable,
        Button1  = "Join Game",
        Button2  = "Ignore",
    })
    return
end

--// ─────────────────────────────────────────────
--//  2. FILE STRUCTURE — Hub creates the skeleton
--// ─────────────────────────────────────────────
local ROOT          = "AB2 Hub"
local ASSETS_ICONS  = ROOT .. "/Assets/Icons"
local ASSETS_AUDIOS = ROOT .. "/Assets/Audios"
local SCRIPTS_DIR   = ROOT .. "/Scripts"

if makefolder then
    makefolder(ROOT)
    makefolder(ROOT .. "/Assets")
    makefolder(ASSETS_ICONS)
    makefolder(ASSETS_AUDIOS)
    makefolder(SCRIPTS_DIR)
end

--// ─────────────────────────────────────────────
--//  3. ASSET HELPERS
--// ─────────────────────────────────────────────

-- Downloads a file from a URL and saves it if not already present
local function ensureFile(path, url)
    if not (isfile and writefile and makefolder) then return end
    if not isfile(path) then
        local ok, data = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and data then
            writefile(path, data)
        end
    end
end

--// ─────────────────────────────────────────────
--//  4. FETCH & REGISTER FEATURES
--// ─────────────────────────────────────────────

local function fetchAndRegisterAutofish()
    local ok, code = pcall(function()
        return game:HttpGet(AUTOFISH_SCRIPT_URL)
    end)
    if not ok or not code then
        warn("[AB2 Hub] Failed to fetch Autofish script.")
        return
    end

    -- Execute the remotely-controlled version of Autofish.
    -- The Autofish script sets up _G.AB2Hub.Features.Autofish with its control API.
    local fn, err = loadstring(code)
    if fn then
        local success, result = pcall(fn)
        if not success then
            warn("[AB2 Hub] Autofish load error: " .. tostring(result))
        end
    else
        warn("[AB2 Hub] Autofish parse error: " .. tostring(err))
    end
end

fetchAndRegisterAutofish()

--// ─────────────────────────────────────────────
--//  5. HUB UI
--// ─────────────────────────────────────────────

-- Clean up any existing hub UI
if CoreGui:FindFirstChild("AB2HubGui") then
    CoreGui:FindFirstChild("AB2HubGui"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "AB2HubGui"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent          = CoreGui

--// Hub sounds holder
local SoundHolder = Instance.new("Folder")
SoundHolder.Name   = "AB2HubSounds"
SoundHolder.Parent = ScreenGui

local hubOpenSound  = Instance.new("Sound", SoundHolder)
local hubCloseSound = Instance.new("Sound", SoundHolder)
hubOpenSound.Volume  = 0.5
hubCloseSound.Volume = 0.5
hubOpenSound.SoundId  = HUB_OPEN_SOUND_URL
hubCloseSound.SoundId = HUB_CLOSE_SOUND_URL

--// ── Unibar Button Injection ──
local BUTTON_WIDTH = 48

local topBarApp     = CoreGui:WaitForChild("TopBarApp"):WaitForChild("TopBarApp")
local sausageHolder = topBarApp:WaitForChild("UnibarLeftFrame"):WaitForChild("UnibarMenu"):WaitForChild("2")

local originalWidth  = sausageHolder.Size.X.Offset
local expandedSize   = UDim2.new(0, originalWidth + BUTTON_WIDTH, 0, sausageHolder.Size.Y.Offset)

local buttonFrame = Instance.new("Frame")
buttonFrame.Name                 = "AB2HubButtonFrame"
buttonFrame.Size                 = UDim2.new(0, BUTTON_WIDTH, 1, 0)
buttonFrame.Position             = UDim2.new(0, originalWidth, 0, 0)
buttonFrame.BackgroundTransparency = 1
buttonFrame.Parent               = sausageHolder

local TopbarButton = Instance.new("ImageButton")
TopbarButton.Name                 = "AB2HubButton"
TopbarButton.Size                 = UDim2.new(0, 32, 0, 32)
TopbarButton.AnchorPoint          = Vector2.new(0.5, 0.5)
TopbarButton.Position             = UDim2.new(0.5, 0, 0.5, 0)
TopbarButton.BackgroundTransparency = 1
TopbarButton.Image                = HUB_ICON_URL
TopbarButton.ScaleType            = Enum.ScaleType.Fit
TopbarButton.Parent               = buttonFrame

-- Keep the sausage expanded even if Roblox tries to resize it
local sizeConn
sizeConn = sausageHolder:GetPropertyChangedSignal("Size"):Connect(function()
    if sausageHolder.Parent then
        sausageHolder.Size    = expandedSize
        buttonFrame.Position  = UDim2.new(0, sausageHolder.Size.X.Offset - BUTTON_WIDTH, 0, 0)
    else
        sizeConn:Disconnect()
    end
end)
sausageHolder.Size = expandedSize

--// ── Submenu Panel ──
-- Positioned below the unibar (top-left, just under the topbar)
local Panel = Instance.new("Frame")
Panel.Name                  = "AB2HubPanel"
Panel.Size                  = UDim2.new(0, 220, 0, 0)
Panel.Position              = UDim2.new(0, 4, 0, 56)   -- sits just below the unibar
Panel.BackgroundColor3      = Color3.fromRGB(12, 12, 18)
Panel.BackgroundTransparency = 0.15
Panel.BorderSizePixel       = 0
Panel.ClipsDescendants      = true
Panel.Visible               = false
Panel.Parent                = ScreenGui

local PanelCorner = Instance.new("UICorner", Panel)
PanelCorner.CornerRadius = UDim.new(0, 10)

local PanelStroke = Instance.new("UIStroke", Panel)
PanelStroke.Color        = Color3.fromRGB(60, 90, 200)
PanelStroke.Thickness    = 1.2
PanelStroke.Transparency = 0.4

-- Panel title bar
local TitleBar = Instance.new("Frame", Panel)
TitleBar.Size             = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
TitleBar.BackgroundTransparency = 0.1
TitleBar.BorderSizePixel  = 0

local TitleCorner = Instance.new("UICorner", TitleBar)
TitleCorner.CornerRadius = UDim.new(0, 10)

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size             = UDim2.new(1, -10, 1, 0)
TitleLabel.Position         = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text             = "AB2 Hub"
TitleLabel.TextColor3       = Color3.fromRGB(200, 210, 255)
TitleLabel.TextSize         = 13
TitleLabel.Font             = Enum.Font.GothamBold
TitleLabel.TextXAlignment   = Enum.TextXAlignment.Left

-- Features list layout
local FeatureList = Instance.new("Frame", Panel)
FeatureList.Name             = "FeatureList"
FeatureList.Size             = UDim2.new(1, 0, 1, -38)
FeatureList.Position         = UDim2.new(0, 0, 0, 36)
FeatureList.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", FeatureList)
UIList.Padding          = UDim.new(0, 4)
UIList.FillDirection    = Enum.FillDirection.Vertical
UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIList.SortOrder        = Enum.SortOrder.LayoutOrder

local UIPadding = Instance.new("UIPadding", FeatureList)
UIPadding.PaddingLeft   = UDim.new(0, 8)
UIPadding.PaddingRight  = UDim.new(0, 8)
UIPadding.PaddingTop    = UDim.new(0, 4)
UIPadding.PaddingBottom = UDim.new(0, 6)

--// ── Panel open/close animation ──
local PANEL_OPEN_HEIGHT = 80
local panelOpen = false
local tweenInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function updatePanelHeight()
    -- Recalculate based on number of feature buttons
    local count = #FeatureList:GetChildren() - 2 -- subtract UIListLayout & UIPadding
    count = math.max(count, 0)
    PANEL_OPEN_HEIGHT = 38 + (count * 44) + 10
end

local function openPanel()
    panelOpen = true
    Panel.Visible = true
    updatePanelHeight()
    hubOpenSound:Play()
    TweenService:Create(Panel, tweenInfo, {
        Size = UDim2.new(0, 220, 0, PANEL_OPEN_HEIGHT),
        BackgroundTransparency = 0.15,
    }):Play()
end

local function closePanel()
    panelOpen = false
    hubCloseSound:Play()
    local tween = TweenService:Create(Panel, tweenInfo, {
        Size = UDim2.new(0, 220, 0, 0),
        BackgroundTransparency = 0.4,
    })
    tween:Play()
    tween.Completed:Connect(function()
        if not panelOpen then
            Panel.Visible = false
        end
    end)
end

TopbarButton.Activated:Connect(function()
    if panelOpen then
        closePanel()
    else
        openPanel()
    end
end)

--// ─────────────────────────────────────────────
--//  6. FEATURE BUTTON FACTORY
--//  Each feature registers itself and gets a
--//  toggle button created in the panel.
--// ─────────────────────────────────────────────

local function createFeatureButton(config)
    --[[
        config = {
            name       = "Autofish",
            iconOff    = "URL or rbxassetid",
            iconOn     = "URL or rbxassetid",
            soundOn    = Sound instance or nil,
            soundOff   = Sound instance or nil,
            onToggle   = function(enabled) ... end,
        }
    ]]

    local enabled = false

    local Button = Instance.new("TextButton")
    Button.Name                 = config.name .. "Button"
    Button.Size                 = UDim2.new(1, 0, 0, 36)
    Button.BackgroundColor3     = Color3.fromRGB(22, 22, 34)
    Button.BackgroundTransparency = 0.2
    Button.BorderSizePixel      = 0
    Button.Text                 = ""
    Button.LayoutOrder           = #FeatureList:GetChildren()
    Button.Parent               = FeatureList

    local BtnCorner = Instance.new("UICorner", Button)
    BtnCorner.CornerRadius = UDim.new(0, 7)

    local BtnStroke = Instance.new("UIStroke", Button)
    BtnStroke.Color        = Color3.fromRGB(50, 70, 160)
    BtnStroke.Thickness    = 1
    BtnStroke.Transparency = 0.6

    -- Icon
    local Icon = Instance.new("ImageLabel", Button)
    Icon.Size                   = UDim2.new(0, 22, 0, 22)
    Icon.Position               = UDim2.new(0, 8, 0.5, -11)
    Icon.BackgroundTransparency = 1
    Icon.Image                  = config.iconOff
    Icon.ScaleType              = Enum.ScaleType.Fit

    -- Label
    local Label = Instance.new("TextLabel", Button)
    Label.Size                  = UDim2.new(1, -70, 1, 0)
    Label.Position              = UDim2.new(0, 38, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text                  = config.name
    Label.TextColor3            = Color3.fromRGB(180, 190, 230)
    Label.TextSize              = 12
    Label.Font                  = Enum.Font.GothamSemibold
    Label.TextXAlignment        = Enum.TextXAlignment.Left

    -- Status pill
    local Pill = Instance.new("Frame", Button)
    Pill.Size               = UDim2.new(0, 32, 0, 16)
    Pill.Position           = UDim2.new(1, -40, 0.5, -8)
    Pill.BackgroundColor3   = Color3.fromRGB(60, 60, 80)
    Pill.BorderSizePixel    = 0

    local PillCorner = Instance.new("UICorner", Pill)
    PillCorner.CornerRadius = UDim.new(1, 0)

    local PillDot = Instance.new("Frame", Pill)
    PillDot.Size             = UDim2.new(0, 10, 0, 10)
    PillDot.Position         = UDim2.new(0, 3, 0.5, -5)
    PillDot.BackgroundColor3 = Color3.fromRGB(120, 120, 150)
    PillDot.BorderSizePixel  = 0

    local DotCorner = Instance.new("UICorner", PillDot)
    DotCorner.CornerRadius = UDim.new(1, 0)

    local dotTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function setVisualState(on)
        if on then
            Icon.Image         = config.iconOn
            Pill.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
            TweenService:Create(PillDot, dotTweenInfo, {
                Position         = UDim2.new(0, 19, 0.5, -5),
                BackgroundColor3 = Color3.fromRGB(220, 255, 230),
            }):Play()
            BtnStroke.Color    = Color3.fromRGB(40, 180, 90)
            BtnStroke.Transparency = 0.2
        else
            Icon.Image         = config.iconOff
            Pill.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            TweenService:Create(PillDot, dotTweenInfo, {
                Position         = UDim2.new(0, 3, 0.5, -5),
                BackgroundColor3 = Color3.fromRGB(120, 120, 150),
            }):Play()
            BtnStroke.Color    = Color3.fromRGB(50, 70, 160)
            BtnStroke.Transparency = 0.6
        end
    end

    Button.Activated:Connect(function()
        enabled = not enabled
        setVisualState(enabled)

        if enabled then
            if config.soundOn then config.soundOn:Play() end
        else
            if config.soundOff then config.soundOff:Play() end
        end

        if config.onToggle then
            config.onToggle(enabled)
        end
    end)

    -- Hover effect
    Button.MouseEnter:Connect(function()
        TweenService:Create(Button, dotTweenInfo, {BackgroundTransparency = 0}):Play()
    end)
    Button.MouseLeave:Connect(function()
        TweenService:Create(Button, dotTweenInfo, {BackgroundTransparency = 0.2}):Play()
    end)

    updatePanelHeight()
    return Button
end

--// Expose factory globally so features can register themselves
_G.AB2Hub.createFeatureButton = createFeatureButton
_G.AB2Hub.FeatureList         = FeatureList
_G.AB2Hub.SoundHolder         = SoundHolder
_G.AB2Hub.RootFolder          = ROOT
_G.AB2Hub.AssetsIcons         = ASSETS_ICONS
_G.AB2Hub.AssetsAudios        = ASSETS_AUDIOS
_G.AB2Hub.ScriptsDir          = SCRIPTS_DIR
_G.AB2Hub.ensureFile          = ensureFile

print("[AB2 Hub] Hub initialized successfully.")
