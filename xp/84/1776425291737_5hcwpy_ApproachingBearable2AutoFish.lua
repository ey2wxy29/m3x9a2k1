--[[
    AB2 Autofish — Remotely Controlled Module
    This script is fetched and loaded by AB2_Hub.lua.
    It does NOT run standalone. It registers itself into
    _G.AB2Hub.Features.Autofish and creates its own
    file/asset structure under the AB2 Hub folder.
]]

--// Guard: only run when loaded by the Hub
if not _G.AB2Hub then
    warn("[Autofish] Must be loaded through AB2 Hub.")
    return
end

--// ─────────────────────────────────────────────
--//  ASSET URLs
--// ─────────────────────────────────────────────
local ICON_OFF_URL   = "https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/fu/xf/1776589185892_kcxlbb_fish_1f41f.png"
local ICON_ON_URL    = "https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/m4/jl/1776589187448_vhqgzy_fishing-pole_1f3a3.png"
local SOUND_ON_URL   = "https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/tb/iv/1776591185504_tqc6yu_FISH_Meme_Sound_Effect_FREE_TO_USE_MP3_320K.mp3"
local SOUND_OFF_URL  = "https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/j7/j0/1776591188012_hi6s2t_Pluh_sound_effect_look_at_pinned_comment_and_description_720P_HD.mp3"

--// ─────────────────────────────────────────────
--//  1. FILE STRUCTURE — Autofish owns these
--// ─────────────────────────────────────────────
local ROOT         = _G.AB2Hub.RootFolder   -- "AB2 Hub"
local ICONS_DIR    = _G.AB2Hub.AssetsIcons  -- "AB2 Hub/Assets/Icons"
local AUDIOS_DIR   = _G.AB2Hub.AssetsAudios -- "AB2 Hub/Assets/Audios"
local SCRIPTS_DIR  = _G.AB2Hub.ScriptsDir   -- "AB2 Hub/Scripts"
-- ensureFile: downloads, saves, and returns a getcustomasset URI
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
    if getcustomasset and isfile(path) then
        return getcustomasset(path)
    end
    return url
end

local AF_ICONS_DIR   = ICONS_DIR   .. "/Autofish"
local AF_AUDIOS_DIR  = AUDIOS_DIR  .. "/Autofish"
local AF_SCRIPTS_DIR = SCRIPTS_DIR .. "/Autofish"
local LOG_FILE       = AF_SCRIPTS_DIR .. "/SoldLogs.txt"

if makefolder then
    makefolder(AF_ICONS_DIR)
    makefolder(AF_AUDIOS_DIR)
    makefolder(AF_SCRIPTS_DIR)
end

-- Download, cache, and resolve all assets
local ICON_OFF_ASSET  = ensureFile(AF_ICONS_DIR  .. "/Close.png",   ICON_OFF_URL)
local ICON_ON_ASSET   = ensureFile(AF_ICONS_DIR  .. "/Open.png",    ICON_ON_URL)
local SOUND_ON_ASSET  = ensureFile(AF_AUDIOS_DIR .. "/Enable.mp3",  SOUND_ON_URL)
local SOUND_OFF_ASSET = ensureFile(AF_AUDIOS_DIR .. "/Disable.mp3", SOUND_OFF_URL)

if writefile and isfile then
    if not isfile(LOG_FILE) then
        writefile(LOG_FILE, "Sold Items Log:\n")
    end
end

--// ─────────────────────────────────────────────
--//  2. SERVICES & STATE
--// ─────────────────────────────────────────────
local Players            = game:GetService("Players")
local StarterGui         = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")

local player = Players.LocalPlayer

local State = {
    Enabled           = false,
    SellingInProgress = false,
}

--// ─────────────────────────────────────────────
--//  3. METATABLE HOOK
--// ─────────────────────────────────────────────
local mt  = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    if (getnamecallmethod() == "FireServer") and self.Name == "EndFish" then
        args[1] = true
    end
    return old(self, unpack(args))
end)
setreadonly(mt, true)

--// ─────────────────────────────────────────────
--//  4. POSITIONS
--// ─────────────────────────────────────────────
local sellPos    = Vector3.new(226, 101, -1923)
local fishingPos = Vector3.new(-992, -84, 808)
local pickupPos  = Vector3.new(83, 1, 224)

--// ─────────────────────────────────────────────
--//  5. SELLING & LOGGING
--// ─────────────────────────────────────────────
local function logAndNotify(fishName, success)
    local msg = success and "Successfully sold!" or "Logged: (Already Sold)."
    StarterGui:SetCore("SendNotification", {
        Title    = fishName,
        Text     = msg,
        Duration = 5,
    })

    if writefile and readfile and isfile and isfile(LOG_FILE) then
        local content = readfile(LOG_FILE)
        if not string.find(content, fishName, 1, true) then
            writefile(LOG_FILE, content .. "\n" .. fishName)
        end
    end
end

local function sellFish(fish)
    State.SellingInProgress = true
    local char = player.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if not char or not hum or not root then
        State.SellingInProgress = false
        return
    end

    hum:UnequipTools()
    task.wait(2)

    root.CFrame = CFrame.new(sellPos) * CFrame.Angles(0, math.rad(90), 0)
    task.wait(1.5)

    hum:EquipTool(fish)
    task.wait(0.5)

    for i = 1, 3 do
        VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.2)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        task.wait(1.5)
    end

    task.wait(5)

    local stillHas = char:FindFirstChild(fish.Name) or player.Backpack:FindFirstChild(fish.Name)
    logAndNotify(fish.Name, not stillHas)

    hum:UnequipTools()
    task.wait(1)
    root.CFrame = CFrame.new(fishingPos)
    task.wait(2)

    State.SellingInProgress = false
end

player.Backpack.ChildAdded:Connect(function(child)
    if State.Enabled and child:IsA("Tool") and child.Name ~= "Fishing Rod" then
        if isfile and isfile(LOG_FILE) then
            local content = readfile(LOG_FILE)
            if string.find(content, child.Name, 1, true) then return end
        end
        sellFish(child)
    end
end)

--// ─────────────────────────────────────────────
--//  6. RENDER LOCK & CAMERA FIX
--// ─────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if State.Enabled and not State.SellingInProgress and root
        and (root.Position - fishingPos).Magnitude < 50 then
        workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
        workspace.CurrentCamera.CFrame     = CFrame.new(
            root.Position + Vector3.new(0, 25, 0), root.Position
        )
        char.Humanoid.WalkSpeed = 0
    else
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = 16
        end
    end
end)

--// ─────────────────────────────────────────────
--//  7. MAIN FISHING LOOP
--// ─────────────────────────────────────────────
local function getRodInHand()
    return player.Character and player.Character:FindFirstChild("Fishing Rod")
end

local function getRodAtAll()
    return player.Character and (
        player.Character:FindFirstChild("Fishing Rod") or
        player.Backpack:FindFirstChild("Fishing Rod")
    )
end

local function getAnimState()
    local animator = player.Character
        and player.Character:FindFirstChild("Humanoid")
        and player.Character.Humanoid:FindFirstChildOfClass("Animator")
    if not animator then return "NONE" end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local id = tonumber(track.Animation.AnimationId:match("%d+"))
        if id == 103273924599330 then return "THROWING" end
        if id == 113022193981637 then return "BITE"     end
    end
    return "IDLE"
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if State.Enabled and not State.SellingInProgress then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end

            local rod = getRodAtAll()
            if not rod then
                root.CFrame = CFrame.new(pickupPos)
                task.wait(1)
                VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
                task.wait(1.5)
                continue
            end

            if (root.Position - fishingPos).Magnitude > 5 then
                root.CFrame = CFrame.new(fishingPos)
                task.wait(0.5)
            end

            if not getRodInHand() then
                char.Humanoid:UnequipTools()
                task.wait(0.5)
                char.Humanoid:EquipTool(rod)
                task.wait(1)
            end

            if getRodInHand() then
                local cam = workspace.CurrentCamera
                local cx   = cam.ViewportSize.X / 2
                local cy   = cam.ViewportSize.Y / 2

                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
                task.wait(0.1)
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)

                local t1 = tick()
                repeat task.wait(0.1)
                until getAnimState() == "THROWING"
                    or (tick() - t1 > 4)
                    or not getRodInHand()
                    or not State.Enabled
                    or State.SellingInProgress

                repeat task.wait(0.1)
                until getAnimState() ~= "THROWING"
                    or not getRodInHand()
                    or not State.Enabled
                    or State.SellingInProgress

                while State.Enabled and not State.SellingInProgress
                    and getRodInHand() and getAnimState() ~= "BITE" do
                    task.wait(0.05)
                end

                if State.Enabled and not State.SellingInProgress
                    and getRodInHand() and getAnimState() == "BITE" then
                    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
                    task.wait(0.1)
                    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
                    repeat task.wait(0.1)
                    until getAnimState() ~= "BITE"
                        or not getRodInHand()
                        or State.SellingInProgress
                end
            end

            task.wait(2.5)
        end
    end
end)

--// ─────────────────────────────────────────────
--//  8. SOUNDS — use getcustomasset resolved paths
--// ─────────────────────────────────────────────
local soundHolder = _G.AB2Hub.SoundHolder

local soundOn  = Instance.new("Sound", soundHolder)
local soundOff = Instance.new("Sound", soundHolder)
soundOn.Volume  = 0.7
soundOff.Volume = 0.7
soundOn.SoundId  = SOUND_ON_ASSET
soundOff.SoundId = SOUND_OFF_ASSET

--// ─────────────────────────────────────────────
--//  9. REGISTER WITH HUB — creates the button
--// ─────────────────────────────────────────────
_G.AB2Hub.Features.Autofish = State

_G.AB2Hub.createFeatureButton({
    name     = "Autofish",
    iconOff  = ICON_OFF_ASSET,
    iconOn   = ICON_ON_ASSET,
    soundOn  = soundOn,
    soundOff = soundOff,
    onToggle = function(enabled)
        State.Enabled = enabled
    end,
})

print("[AB2 Hub] Autofish module registered successfully.")
