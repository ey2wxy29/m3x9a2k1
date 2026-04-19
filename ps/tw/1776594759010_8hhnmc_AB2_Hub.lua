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

-- Downloads a file from a URL if not already cached, returns getcustomasset URI
local function ensureFile(path, url)
    if not (isfile and writefile) then return url end
    if not isfile(path) then
        local ok, data = pcall(function()
            return game:HttpGet(url, true)
        end)
        if ok and data and #data > 0 then
            writefile(path, data)
        end
    end
    -- Return a usable rbxasset URI via getcustomasset if available
    if getcustomasset and isfile(path) then
        return getcustomasset(path)
    end
    return url
end

--// ─────────────────────────────────────────────
--//  4. FETCH & REGISTER FEATURES
--// ─────────────────────────────────────────────

local function fetchAndRegisterAutofish()
    local ok, code = pcall(function()
        return game:HttpGet(AUTOFISH_SCRIPT_URL)
    end)
    if not ok or not code or code == "" then
        warn("[AB2 Hub] Failed to fetch Autofish script.")
        StarterGui:SetCore("SendNotification", {
            Title = "AB2 Hub", Text = "Failed to fetch Autofish script.", Duration = 6
        })
        return
    end

    local fn, err = loadstring(code)
    if fn then
        local success, result = pcall(fn)
        if not success then
            warn("[AB2 Hub] Autofish load error: " .. tostring(result))
            StarterGui:SetCore("SendNotification", {
                Title = "AB2 Hub", Text = "Autofish error: " .. tostring(result), Duration = 8
            })
        end
    else
        warn("[AB2 Hub] Autofish parse error: " .. tostring(err))
        StarterGui:SetCore("SendNotification", {
            Title = "AB2 Hub", Text = "Autofish parse error: " .. tostring(err), Duration = 8
        })
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
hubOpenSound.SoundId  = HUB_OPEN_SOUND_URL   -- placeholder, swap when you have a link
hubCloseSound.SoundId = HUB_CLOSE_SOUND_URL  -- placeholder

--// Download & cache hub icon, resolve via getcustomasset
local HUB_ICON_PATH = ROOT .. "/Assets/Icons/Hub.png"
local hubIconResolved = ensureFile(HUB_ICON_PATH, HUB_ICON_URL)

--// ── Unibar Button Injection ──
local SLOT_SIZE    = 36  -- closer to native Roblox icon spacing
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
TopbarButton.Position           = UDim2.new(0.5, -6, 0.5, 0)  -- slight left nudge to center visually
TopbarButton.BackgroundTransparency = 1
TopbarButton.Image              = hubIconResolved
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
-- Position is calculated dynamically from the button's AbsolutePosition
local DropdownContainer = Instance.new("Frame")
DropdownContainer.Name               = "AB2HubDropdown"
DropdownContainer.Size               = UDim2.new(0, SLOT_SIZE, 0, PILL_HEIGHT + 10)
DropdownContainer.BackgroundTransparency = 1
DropdownContainer.ClipsDescendants   = false
DropdownContainer.Visible            = false
DropdownContainer.Parent             = ScreenGui

local PILL_COLOR = Color3.fromRGB(0, 0, 0)  -- pure black to match CoreGui

--// ── Triangle pointer (caret pointing up) ──
local Triangle = Instance.new("Frame")
Triangle.Name             = "Caret"
Triangle.Size             = UDim2.new(0, 14, 0, 14)
Triangle.AnchorPoint      = Vector2.new(0.5, 0)
Triangle.Position         = UDim2.new(0.5, 0, 0, 2)
Triangle.BackgroundColor3 = PILL_COLOR
Triangle.BackgroundTransparency = 0.4
Triangle.BorderSizePixel  = 0
Triangle.Rotation         = 45
Triangle.ZIndex           = 2
Triangle.Parent           = DropdownContainer

--// ── Pill (the actual dropdown) ──
local featureCount = 0

local Pill = Instance.new("Frame")
Pill.Name               = "FeaturePill"
Pill.Size               = UDim2.new(0, SLOT_SIZE, 0, PILL_HEIGHT)
Pill.Position           = UDim2.new(0, 0, 0, 9)
Pill.BackgroundColor3   = PILL_COLOR
Pill.BackgroundTransparency = 0.4
Pill.BorderSizePixel    = 0
Pill.ClipsDescendants   = true
Pill.ZIndex             = 2
Pill.Parent             = DropdownContainer

local PillCorner = Instance.new("UICorner", Pill)
PillCorner.CornerRadius = UDim.new(1, 0)

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

-- Dynamically calculates where the dropdown should sit based on
-- the button's real screen position — works on any screen size
local function getDropdownPosition(offset)
    local abs = TopbarButton.AbsolutePosition
    local sz  = TopbarButton.AbsoluteSize
    local x   = abs.X + sz.X / 2  -- center of hub button horizontally
    local y   = abs.Y + sz.Y + (offset or 0)
    local w   = DropdownContainer.Size.X.Offset
    -- Shift left so pill is centered under the button
    x = x - w / 2
    return UDim2.fromOffset(x, y)
end

local function refreshPillWidth()
    local gaps = math.max(featureCount - 1, 0) * 4
    local w = (PILL_PADDING * 2) + (featureCount * 32) + gaps
    w = math.max(w, SLOT_SIZE)
    Pill.Size              = UDim2.new(0, w, 0, PILL_HEIGHT)
    DropdownContainer.Size = UDim2.new(0, w, 0, PILL_HEIGHT + 10)
    Triangle.Position      = UDim2.new(0, w / 2, 0, 0)
    -- Re-center dropdown under button whenever width changes
    DropdownContainer.Position = getDropdownPosition(2)
end

--// ── Open / Close animation ──
local panelOpen = false
local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function openPanel()
    panelOpen = true
    refreshPillWidth()
    DropdownContainer.Position = getDropdownPosition(-4)
    DropdownContainer.Visible  = true
    hubOpenSound:Play()
    Pill.BackgroundTransparency     = 0.8
    Triangle.BackgroundTransparency = 0.8
    TweenService:Create(Pill,     tweenInfo, {BackgroundTransparency = 0.4}):Play()
    TweenService:Create(Triangle, tweenInfo, {BackgroundTransparency = 0.4}):Play()
    TweenService:Create(DropdownContainer, tweenInfo, {
        Position = getDropdownPosition(2),
    }):Play()
end

local function closePanel()
    panelOpen = false
    hubCloseSound:Play()
    TweenService:Create(Pill,     tweenInfo, {BackgroundTransparency = 0.8}):Play()
    TweenService:Create(Triangle, tweenInfo, {BackgroundTransparency = 0.8}):Play()
    local tween = TweenService:Create(DropdownContainer, tweenInfo, {
        Position = getDropdownPosition(-4),
    })
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
