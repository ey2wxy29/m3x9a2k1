--// 1. GAME CHECK & AUTO-TELEPORT
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local TARGET_ID = 83861332438631 

if game.PlaceId ~= TARGET_ID then
    local bindable = Instance.new("BindableFunction")
    bindable.OnInvoke = function(buttonText)
        if buttonText == "Join Game" then TeleportService:Teleport(TARGET_ID, Players.LocalPlayer) end
    end
    StarterGui:SetCore("SendNotification", {
        Title = "Wrong Game!",
        Text = "This script is for AB2. Would you like to join?",
        Duration = 15,
        Callback = bindable,
        Button1 = "Join Game",
        Button2 = "Ignore"
    })
    return 
end

--// 2. CONFIG & FILE SYSTEM
local sellPos = Vector3.new(226, 101, -1923) -- Updated coordinates
local fishingPos = Vector3.new(-992, -84, 808)
local pickupPos = Vector3.new(83, 1, 224)

local folderName = "Ab2 Autofish"
local fileName = folderName .. "/SoldLogs.txt"

if makefolder and writefile and isfile then
    makefolder(folderName)
    if not isfile(fileName) then writefile(fileName, "Sold Items Log:\n") end
end

--// 3. METATABLE HOOK
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

--// 4. SERVICES
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
_G.AutofishEnabled = false
local SellingInProgress = false 

--// 5. SELLING & LOGGING
local function logAndNotify(fishName, success)
    local msg = success and "Successfully sold!" or "Logged: (Already Sold)."
    StarterGui:SetCore("SendNotification", {Title = fishName, Text = msg, Duration = 5})
    
    if writefile and readfile then
        local content = readfile(fileName)
        if not string.find(content, fishName) then
            writefile(fileName, content .. "\n" .. fishName)
        end
    end
end

local function sellFish(fish)
    SellingInProgress = true 
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if not char or not hum or not root then SellingInProgress = false return end

    -- 1. Pause Autofarm & Unequip Rod
    hum:UnequipTools()
    task.wait(2) 
    
    -- 2. Equip Fish & Teleport
    hum:EquipTool(fish)
    task.wait(0.5)
    root.CFrame = CFrame.new(sellPos)
    task.wait(1.5) 
    
    -- 3. The 3 Clicks (1.5s interval)
    for i = 1, 3 do
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.2)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        task.wait(1.5) 
    end
    
    -- 4. Server Patience Window
    task.wait(5)
    
    -- 5. Status Check
    local stillHas = char:FindFirstChild(fish.Name) or player.Backpack:FindFirstChild(fish.Name)
    logAndNotify(fish.Name, not stillHas)
    
    -- 6. Cleanup Fish & Return
    hum:UnequipTools()
    task.wait(1)
    root.CFrame = CFrame.new(fishingPos)
    task.wait(2) 
    
    SellingInProgress = false 
end

player.Backpack.ChildAdded:Connect(function(child)
    if _G.AutofishEnabled and child:IsA("Tool") and child.Name ~= "Fishing Rod" then
        if isfile and isfile(fileName) then
            if string.find(readfile(fileName), child.Name) then return end
        end
        sellFish(child)
    end
end)

--// 6. UNIBAR BUTTON
local function SetupUnibarButton()
    local topBarApp = CoreGui:WaitForChild("TopBarApp"):WaitForChild("TopBarApp")
    local sausageHolder = topBarApp:WaitForChild("UnibarLeftFrame"):WaitForChild("UnibarMenu"):WaitForChild("2")
    local originalSize = sausageHolder.Size.X.Offset
    local sSize = UDim2.new(0, originalSize + 48, 0, sausageHolder.Size.Y.Offset)

    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "FishButtonFrame"
    buttonFrame.Parent = sausageHolder
    buttonFrame.Size = UDim2.new(0, 44, 1, 0)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Position = UDim2.new(0, sausageHolder.Size.X.Offset - 48, 0, 0)

    local imageButton = Instance.new("ImageButton")
    imageButton.Parent = buttonFrame
    imageButton.BackgroundTransparency = 1
    imageButton.Size = UDim2.new(0, 32, 0, 32)
    imageButton.AnchorPoint = Vector2.new(0.5, 0.5)
    imageButton.Position = UDim2.new(0.5, 0, 0.5, 0)
    imageButton.Image = ""

    local emojiLabel = Instance.new("TextLabel")
    emojiLabel.Parent = imageButton
    emojiLabel.BackgroundTransparency = 1
    emojiLabel.Size = UDim2.new(1, 0, 1, 0)
    emojiLabel.Text = "🐟"
    emojiLabel.TextSize = 22
    emojiLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    emojiLabel.TextXAlignment = Enum.TextXAlignment.Center
    emojiLabel.TextYAlignment = Enum.TextYAlignment.Center

    sausageHolder:GetPropertyChangedSignal("Size"):Connect(function()
        if sausageHolder.Parent then
            sausageHolder.Size = sSize
            buttonFrame.Position = UDim2.new(0, sausageHolder.Size.X.Offset - 48, 0, 0)
        end
    end)
    sausageHolder.Size = sSize

    imageButton.Activated:Connect(function()
        _G.AutofishEnabled = not _G.AutofishEnabled
        emojiLabel.Text = _G.AutofishEnabled and "🎣" or "🐟"
    end)
end

SetupUnibarButton()

--// 7. RENDER LOCK & UTILS
local function getRodInHand() return player.Character and player.Character:FindFirstChild("Fishing Rod") end
local function getRodAtAll() return player.Character and (player.Character:FindFirstChild("Fishing Rod") or player.Backpack:FindFirstChild("Fishing Rod")) end

local function getAnimState()
    local animator = player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid:FindFirstChildOfClass("Animator")
    if not animator then return "NONE" end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local id = tonumber(track.Animation.AnimationId:match("%d+"))
        if id == 103273924599330 then return "THROWING" end
        if id == 113022193981637 then return "BITE" end
    end
    return "IDLE"
end

RunService.RenderStepped:Connect(function()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if _G.AutofishEnabled and not SellingInProgress and root and (root.Position - fishingPos).Magnitude < 50 then
        workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
        workspace.CurrentCamera.CFrame = CFrame.new(root.Position + Vector3.new(0, 25, 0), root.Position)
        char.Humanoid.WalkSpeed = 0
    elseif char and (not _G.AutofishEnabled or SellingInProgress) then
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        char.Humanoid.WalkSpeed = 16
    end
end)

--// 8. MAIN CYCLE
task.spawn(function()
    while true do
        task.wait(0.5)
        if _G.AutofishEnabled and not SellingInProgress then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end

            local rod = getRodAtAll()
            if not rod then
                root.CFrame = CFrame.new(pickupPos)
                task.wait(1); VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(1.5)
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
                VirtualInputManager:SendMouseButtonEvent(cam.ViewportSize.X/2, cam.ViewportSize.Y/2, 0, true, game, 0)
                task.wait(0.1); VirtualInputManager:SendMouseButtonEvent(cam.ViewportSize.X/2, cam.ViewportSize.Y/2, 0, false, game, 0)
                
                local t1 = tick()
                repeat task.wait(0.1) until getAnimState() == "THROWING" or (tick()-t1 > 4) or not getRodInHand() or not _G.AutofishEnabled or SellingInProgress
                repeat task.wait(0.1) until getAnimState() ~= "THROWING" or not getRodInHand() or not _G.AutofishEnabled or SellingInProgress
                
                while _G.AutofishEnabled and not SellingInProgress and getRodInHand() and getAnimState() ~= "BITE" do 
                    task.wait(0.05) 
                end

                if _G.AutofishEnabled and not SellingInProgress and getRodInHand() and getAnimState() == "BITE" then
                    VirtualInputManager:SendMouseButtonEvent(cam.ViewportSize.X/2, cam.ViewportSize.Y/2, 0, true, game, 0)
                    task.wait(0.1); VirtualInputManager:SendMouseButtonEvent(cam.ViewportSize.X/2, cam.ViewportSize.Y/2, 0, false, game, 0)
                    repeat task.wait(0.1) until getAnimState() ~= "BITE" or not getRodInHand() or SellingInProgress
                end
            end
            task.wait(2.5)
        end
    end
end)
