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
    if not (isfile and writefile) then return end
    if not isfile(path) then
        local ok, data = pcall(function()
            return game:HttpGet(url, true)
        end)
        if ok and data and #data > 0 then
            writefile(path, data)
        end
    end
end

--// ─────────────────────────────────────────────
--//  4. FETCH & REGISTER FEATURES
--// ─────────────────────────────────────────────

local function fetchAndRegisterAutofish()
    local ok, code = pcall(function()
        return game:HttpGet(AUTOFISH_SCRIPT_URL, true)
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

if CoreGui:FindFirstChild("AB2HubGui") then
    CoreGui:FindFirstChild("AB2HubGui"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "AB2HubGui"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = CoreGui

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
local SLOT_SIZE    = 48  -- width of each icon slot in the dropdown pill
local PILL_HEIGHT  = 44  -- height of the dropdown pill
local PILL_PADDING = 8   -- horizontal padding each side inside pill

local topBarApp     = CoreGui:WaitForChild("TopBarApp"):WaitForChild("TopBarApp")
local sausageHolder = topBarApp:WaitForChild("UnibarLeftFrame"):WaitForChild("UnibarMenu"):WaitForChild("2")

local originalWidth = sausageHolder.Size.X.Offset
local expandedSize  = UDim2.new(0, originalWidth + SLOT_SIZE, 0, sausageHolder.Size.Y.Offset)

-- Container frame inside the sausage
local buttonFrame = Instance.new("Frame")
buttonFrame.Name               = "AB2HubButtonFrame"
buttonFrame.Size               = UDim2.new(0, SLOT_SIZE, 1, 0)
buttonFrame.Position           = UDim2.new(0, originalWidth, 0, 0)
buttonFrame.BackgroundTransparency = 1
buttonFrame.Parent             = sausageHolder

-- Hub icon button inside the sausage
local TopbarButton = Instance.new("ImageButton")
TopbarButton.Name               = "AB2HubButton"
TopbarButton.Size               = UDim2.new(0, 32, 0, 32)
TopbarButton.AnchorPoint        = Vector2.new(0.5, 0.5)
TopbarButton.Position           = UDim2.new(0.5, 0, 0.5, 0)
TopbarButton.BackgroundTransparency = 1
TopbarButton.Image              = HUB_ICON_URL
TopbarButton.ScaleType          = Enum.ScaleType.Fit
TopbarButton.Parent             = buttonFrame

-- Persistence: stop Roblox shrinking the sausage back
local sizeConn
sizeConn = sausageHolder:GetPropertyChangedSignal("Size"):Connect(function()
    if sausageHolder.Parent then
        sausageHolder.Size   = expandedSize
        buttonFrame.Position = UDim2.new(0, sausageHolder.Size.X.Offset - SLOT_SIZE, 0, 0)
    else
        sizeConn:Disconnect()
    end
end)
sausageHolder.Size = expandedSize

--// ── Dropdown container (holds triangle + pill) ──
-- Anchored so it appears directly below the hub button
local DropdownContainer = Instance.new("Frame")
DropdownContainer.Name               = "AB2HubDropdown"
DropdownContainer.Size               = UDim2.new(0, SLOT_SIZE, 0, PILL_HEIGHT + 10) -- starts minimal, grows
DropdownContainer.Position           = UDim2.new(0, originalWidth, 0, sausageHolder.Size.Y.Offset + 2)
DropdownContainer.BackgroundTransparency = 1
DropdownContainer.ClipsDescendants   = false
DropdownContainer.Visible            = false
DropdownContainer.Parent             = ScreenGui

--// ── Triangle pointer (caret pointing up) ──
-- Drawn as a rotated square clipped to look like a triangle
local Triangle = Instance.new("Frame")
Triangle.Name             = "Caret"
Triangle.Size             = UDim2.new(0, 12, 0, 12)
Triangle.AnchorPoint      = Vector2.new(0.5, 0)
Triangle.Position         = UDim2.new(0.5, 0, 0, 0)
Triangle.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
Triangle.BorderSizePixel  = 0
Triangle.Rotation         = 45
Triangle.ZIndex           = 1
Triangle.Parent           = DropdownContainer

--// ── Pill (the actual dropdown) ──
local featureCount = 0  -- tracks how many icons are in the pill

local Pill = Instance.new("Frame")
Pill.Name               = "FeaturePill"
Pill.Size               = UDim2.new(0, SLOT_SIZE, 0, PILL_HEIGHT)  -- grows with features
Pill.Position           = UDim2.new(0, 0, 0, 8)   -- 8px below triangle tip
Pill.BackgroundColor3   = Color3.fromRGB(30, 30, 42)
Pill.BackgroundTransparency = 0.1
Pill.BorderSizePixel    = 0
Pill.ClipsDescendants   = true
Pill.ZIndex             = 2
Pill.Parent             = DropdownContainer

local PillCorner = Instance.new("UICorner", Pill)
PillCorner.CornerRadius = UDim.new(1, 0)  -- fully rounded = pill shape

-- Horizontal icon list inside pill
local FeatureList = Instance.new("Frame", Pill)
FeatureList.Name               = "FeatureList"
FeatureList.Size               = UDim2.new(1, 0, 1, 0)
FeatureList.BackgroundTransparency = 1
FeatureList.ZIndex             = 3

local UIList = Instance.new("UIListLayout", FeatureList)
UIList.FillDirection       = Enum.FillDirection.Horizontal
UIList.VerticalAlignment   = Enum.VerticalAlignment.Center
UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIList.Padding             = UDim.new(0, 4)
UIList.SortOrder           = Enum.SortOrder.LayoutOrder

local UIPadding = Instance.new("UIPadding", FeatureList)
UIPadding.PaddingLeft   = UDim.new(0, PILL_PADDING)
UIPadding.PaddingRight  = UDim.new(0, PILL_PADDING)

local function refreshPillWidth()
    -- Pill grows horizontally: padding*2 + (slot * count) + gaps
    local gaps = math.max(featureCount - 1, 0) * 4
    local w = (PILL_PADDING * 2) + (featureCount * 32) + gaps
    w = math.max(w, SLOT_SIZE)
    Pill.Size              = UDim2.new(0, w, 0, PILL_HEIGHT)
    DropdownContainer.Size = UDim2.new(0, w, 0, PILL_HEIGHT + 10)
    -- Re-center triangle
    Triangle.Position = UDim2.new(0, w / 2, 0, 0)
end

--// ── Open / Close animation ──
local panelOpen = false
local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function openPanel()
    panelOpen = true
    DropdownContainer.Visible = true
    refreshPillWidth()
    hubOpenSound:Play()
    Pill.BackgroundTransparency = 0.4
    TweenService:Create(Pill, tweenInfo, {BackgroundTransparency = 0.1}):Play()
    -- Slide down from unibar
    DropdownContainer.Position = UDim2.new(0, originalWidth, 0, sausageHolder.Size.Y.Offset - 4)
    TweenService:Create(DropdownContainer, tweenInfo, {
        Position = UDim2.new(0, originalWidth, 0, sausageHolder.Size.Y.Offset + 2),
    }):Play()
end

local function closePanel()
    panelOpen = false
    hubCloseSound:Play()
    local tween = TweenService:Create(DropdownContainer, tweenInfo, {
        Position = UDim2.new(0, originalWidth, 0, sausageHolder.Size.Y.Offset - 4),
    })
    TweenService:Create(Pill, tweenInfo, {BackgroundTransparency = 0.5}):Play()
    tween:Play()
    tween.Completed:Connect(function()
        if not panelOpen then
            DropdownContainer.Visible = false
        end
    end)
end

TopbarButton.Activated:Connect(function()
    if panelOpen then closePanel() else openPanel() end
end)

--// ─────────────────────────────────────────────
--//  6. FEATURE BUTTON FACTORY
--//  Each feature registers as an icon slot in
--//  the pill. Clicking toggles it on/off.
--// ─────────────────────────────────────────────

local function createFeatureButton(config)
    --[[
        config = {
            name     = "Autofish",
            iconOff  = "https://... (external URL)",
            iconOn   = "https://... (external URL)",
            soundOn  = Sound instance or nil,
            soundOff = Sound instance or nil,
            onToggle = function(enabled) ... end,
        }
    ]]

    featureCount = featureCount + 1
    local enabled = false

    -- Icon slot button inside the pill
    local Slot = Instance.new("ImageButton")
    Slot.Name               = config.name .. "Slot"
    Slot.Size               = UDim2.new(0, 32, 0, 32)
    Slot.BackgroundTransparency = 1
    Slot.Image              = config.iconOff
    Slot.ScaleType          = Enum.ScaleType.Fit
    Slot.LayoutOrder        = featureCount
    Slot.ZIndex             = 4
    Slot.Parent             = FeatureList

    -- Subtle active glow underneath icon when ON
    local Glow = Instance.new("Frame", Slot)
    Glow.Size               = UDim2.new(1, 6, 1, 6)
    Glow.Position           = UDim2.new(0, -3, 0, -3)
    Glow.BackgroundColor3   = Color3.fromRGB(80, 200, 120)
    Glow.BackgroundTransparency = 1
    Glow.BorderSizePixel    = 0
    Glow.ZIndex             = 3

    local GlowCorner = Instance.new("UICorner", Glow)
    GlowCorner.CornerRadius = UDim.new(1, 0)

    local slotTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function setVisualState(on)
        Slot.Image = on and config.iconOn or config.iconOff
        TweenService:Create(Glow, slotTween, {
            BackgroundTransparency = on and 0.55 or 1,
        }):Play()
        -- Slight scale pop when toggled on
        if on then
            TweenService:Create(Slot, TweenInfo.new(0.08), {Size = UDim2.new(0, 36, 0, 36)}):Play()
            task.delay(0.08, function()
                TweenService:Create(Slot, TweenInfo.new(0.1), {Size = UDim2.new(0, 32, 0, 32)}):Play()
            end)
        end
    end

    Slot.Activated:Connect(function()
        enabled = not enabled
        setVisualState(enabled)
        if enabled then
            if config.soundOn then config.soundOn:Play() end
        else
            if config.soundOff then config.soundOff:Play() end
        end
        if config.onToggle then config.onToggle(enabled) end
    end)

    -- Refresh pill width now that a new icon was added
    refreshPillWidth()
    return Slot
end

--// Expose globally so features can register themselves
_G.AB2Hub.createFeatureButton = createFeatureButton
_G.AB2Hub.FeatureList         = FeatureList
_G.AB2Hub.SoundHolder         = SoundHolder
_G.AB2Hub.RootFolder          = ROOT
_G.AB2Hub.AssetsIcons         = ASSETS_ICONS
_G.AB2Hub.AssetsAudios        = ASSETS_AUDIOS
_G.AB2Hub.ScriptsDir          = SCRIPTS_DIR
_G.AB2Hub.ensureFile          = ensureFile

print("[AB2 Hub] Hub initialized successfully.")
