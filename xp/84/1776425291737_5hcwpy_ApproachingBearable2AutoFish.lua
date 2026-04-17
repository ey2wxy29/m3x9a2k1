--// 1. GAME CHECK
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local TARGET_ID = 83861332438631 

if game.PlaceId ~= TARGET_ID then
    StarterGui:SetCore("SendNotification", {
        Title = "Wrong Game!",
        Text = "You should be in AB2 for this script to work.",
        Duration = 10
    })
    return 
end

--// 2. THE WIN-SPOOF HOOK
local mt = getrawmetatable(game)
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

--// 3. SERVICES & CONFIG
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local fishingPos = Vector3.new(-992, -84, 808)
local pickupPos = Vector3.new(83, 1, 224)
local ID_THROW = 103273924599330 
local ID_BITE  = 113022193981637 

_G.AutofishEnabled = false

--// 4. UNIBAR BUTTON (Centering Fix Applied)
local function SetupUnibarButton()
    local topBarApp = CoreGui:WaitForChild("TopBarApp"):WaitForChild("TopBarApp")
    local sausageHolder = topBarApp:WaitForChild("UnibarLeftFrame"):WaitForChild("UnibarMenu"):WaitForChild("2")
    
    local originalSize = sausageHolder.Size.X.Offset
    local sSize = UDim2.new(0, originalSize + 48, 0, sausageHolder.Size.Y.Offset)

    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "FishButtonFrame"
    buttonFrame.Parent = sausageHolder
    buttonFrame.Size = UDim2.new(0, 44, 1, 0) -- Match height of bar
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Position = UDim2.new(0, sausageHolder.Size.X.Offset - 48, 0, 0)

    local imageButton = Instance.new("ImageButton")
    imageButton.Parent = buttonFrame
    imageButton.BackgroundTransparency = 1
    imageButton.Size = UDim2.new(0, 32, 0, 32)
    imageButton.AnchorPoint = Vector2.new(0.5, 0.5)
    imageButton.Position = UDim2.new(0.5, 0, 0.5, 0) -- Perfectly centered in frame
    imageButton.Image = ""

    local emojiLabel = Instance.new("TextLabel")
    emojiLabel.Parent = imageButton
    emojiLabel.BackgroundTransparency = 1
    emojiLabel.Size = UDim2.new(1, 0, 1, 0)
    emojiLabel.Text = "🐟"
    emojiLabel.TextSize = 22
    emojiLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    -- Centering Logic:
    emojiLabel.TextXAlignment = Enum.TextXAlignment.Center
    emojiLabel.TextYAlignment = Enum.TextYAlignment.Center

    local connection
    connection = sausageHolder:GetPropertyChangedSignal("Size"):Connect(function()
        if sausageHolder.Parent then
            sausageHolder.Size = sSize
            buttonFrame.Position = UDim2.new(0, sausageHolder.Size.X.Offset - 48, 0, 0)
        else
            connection:Disconnect()
        end
    end)
    sausageHolder.Size = sSize

    sausageHolder.AncestryChanged:Connect(function(_, parent)
        if not parent then task.wait(1) SetupUnibarButton() end
    end)

    imageButton.Activated:Connect(function()
        _G.AutofishEnabled = not _G.AutofishEnabled
        emojiLabel.Text = _G.AutofishEnabled and "🎣" or "🐟"
    end)
end

SetupUnibarButton()

--// 5. UTILITIES
local function getRodInHand()
    local char = player.Character
    return char and char:FindFirstChild("Fishing Rod")
end

local function getFishingRodAtAll()
    local char = player.Character
    return char and (char:FindFirstChild("Fishing Rod") or player.Backpack:FindFirstChild("Fishing Rod"))
end

local function getAnimState()
    local char = player.Character
    local animator = char and char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChildOfClass("Animator")
    if not animator then return "NONE" end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local id = tonumber(track.Animation.AnimationId:match("%d+"))
        if id == ID_THROW then return "THROWING" end
        if id == ID_BITE then return "BITE" end
    end
    return "IDLE"
end

local function click()
    local cam = Workspace.CurrentCamera
    local x, y = cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

--// 6. RENDER LOCK
RunService.RenderStepped:Connect(function()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if _G.AutofishEnabled and root and (root.Position - fishingPos).Magnitude < 50 then
        local cam = Workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = CFrame.new(root.Position + Vector3.new(0, 25, 0), root.Position)
        char.Humanoid.WalkSpeed = 0
    elseif char and not _G.AutofishEnabled then
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        char.Humanoid.WalkSpeed = 16
    end
end)

--// 7. MAIN LOOP
task.spawn(function()
    while true do
        task.wait(0.5)
        if _G.AutofishEnabled then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end

            local rod = getFishingRodAtAll()
            if not rod then
                root.CFrame = CFrame.new(pickupPos)
                task.wait(1)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(1.5)
                continue
            end

            if (root.Position - fishingPos).Magnitude > 5 then
                root.CFrame = CFrame.new(fishingPos)
                task.wait(0.5)
            end

            if char and char:FindFirstChild("Humanoid") then
                if not getRodInHand() then
                    char.Humanoid:EquipTool(rod)
                    task.wait(0.5)
                end
                
                click()
                
                local t1 = tick()
                repeat task.wait(0.1) until getAnimState() == "THROWING" or (tick() - t1 > 4) or not getRodInHand() or not _G.AutofishEnabled
                repeat task.wait(0.1) until getAnimState() ~= "THROWING" or not getRodInHand() or not _G.AutofishEnabled
                
                while _G.AutofishEnabled and getRodInHand() and getAnimState() ~= "BITE" do 
                    task.wait(0.05) 
                end

                if _G.AutofishEnabled and getRodInHand() and getAnimState() == "BITE" then
                    click()
                    repeat task.wait(0.1) until getAnimState() ~= "BITE" or not getRodInHand()
                end
                
                task.wait(2.5)
            end
        end
    end
end)
