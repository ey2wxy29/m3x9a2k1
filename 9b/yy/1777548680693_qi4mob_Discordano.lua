-- Discord DM Chat | Firebase Realtime Database
-- Injectable LocalScript - works on most executors
-- Firebase: https://discord-roblox-40fa8-default-rtdb.firebaseio.com/

local FIREBASE_URL  = "https://discord-roblox-40fa8-default-rtdb.firebaseio.com/messages"
local POLL_INTERVAL = 1.5

-- =============================================
-- SERVICES
-- =============================================
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local USERNAME  = player.Name
local GLOBAL_OWNER = "noboestnobo"  -- only this user sees the global Roblox DM channel

-- =============================================
-- TOPBAR BUTTON
-- =============================================
local CoreGui   = game:GetService("CoreGui")
local SLOT_SIZE = 36

local buttonFrame   = nil
local TopbarButton  = nil
local guiRef        = {}

local topbarOk, topbarErr = pcall(function()
	local topBarApp     = CoreGui:WaitForChild("TopBarApp", 5)
	if not topBarApp then error("no TopBarApp") end
	topBarApp = topBarApp:WaitForChild("TopBarApp", 5)
	local sausageHolder = topBarApp
		:WaitForChild("UnibarLeftFrame", 5)
		:WaitForChild("UnibarMenu", 5)
		:WaitForChild("2", 5)

	local currentWidth = sausageHolder.Size.X.Offset
	local expandedSize = UDim2.new(0, currentWidth+SLOT_SIZE, 0, sausageHolder.Size.Y.Offset)

	buttonFrame = Instance.new("Frame")
	buttonFrame.Name              = "DiscordBloxButtonFrame"
	buttonFrame.Size              = UDim2.new(0,SLOT_SIZE,1,0)
	buttonFrame.Position          = UDim2.new(0,currentWidth,0,0)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Visible           = false
	buttonFrame.Parent            = sausageHolder

	TopbarButton = Instance.new("ImageButton")
	TopbarButton.Name              = "DiscordBloxButton"
	TopbarButton.Size              = UDim2.new(0,32,0,32)
	TopbarButton.AnchorPoint       = Vector2.new(0.5,0.5)
	TopbarButton.Position          = UDim2.new(0.5,-6,0.5,0)
	TopbarButton.BackgroundTransparency = 1
	TopbarButton.Image             = ""
	TopbarButton.ScaleType         = Enum.ScaleType.Fit
	TopbarButton.Parent            = buttonFrame

	local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TopbarButton.MouseEnter:Connect(function()
		TweenService:Create(TopbarButton,info,{Size=UDim2.new(0,36,0,36)}):Play()
	end)
	TopbarButton.MouseLeave:Connect(function()
		TweenService:Create(TopbarButton,info,{Size=UDim2.new(0,32,0,32)}):Play()
	end)

	local sizeConn
	sizeConn = sausageHolder:GetPropertyChangedSignal("Size"):Connect(function()
		if sausageHolder.Parent then
			sausageHolder.Size = expandedSize
			buttonFrame.Position = UDim2.new(0,sausageHolder.Size.X.Offset-SLOT_SIZE,0,0)
		else sizeConn:Disconnect() end
	end)
	sausageHolder.Size = expandedSize

	TopbarButton.MouseButton1Click:Connect(function()
		local g = guiRef.gui
		if g and g.Parent then g.Enabled = not g.Enabled end
	end)
end)

if not topbarOk then
	warn("[DiscordBlox] Topbar failed: " .. tostring(topbarErr))
end

-- =============================================
-- HTTP
-- =============================================
local function httpRequest(opts)
	if syn and syn.request       then return syn.request(opts)
	elseif request               then return request(opts)
	elseif http and http.request then return http.request(opts)
	elseif http_request          then return http_request(opts)
	else error("No HTTP function found") end
end

-- =============================================
-- FILE SYSTEM ALIASES
-- =============================================
local _isfolder      = isfolder      or is_folder      or function() return false end
local _makefolder    = makefolder    or make_folder    or function() end
local _isfile        = isfile        or is_file        or function() return false end
local _writefile     = writefile     or write_file     or function() end
local _readfile      = readfile      or read_file      or function() return "" end
local _getcustomasset = getcustomasset or get_custom_asset or nil

-- =============================================
-- FILE SYSTEM + ASSET DOWNLOADS
-- =============================================
local FOLDER_ROOT    = "DiscordBlox"
local FOLDER_THUMBS  = FOLDER_ROOT .. "/Thumbnails"
local FOLDER_SOUNDS  = FOLDER_ROOT .. "/Sounds"
local FOLDER_ICONS   = FOLDER_ROOT .. "/Icons"

local CUSTOM_EMOJIS = {
	extremedemon = {asset = "rbxassetid://139619709480086"},
	insane        = {asset = "rbxassetid://82592159504933"},
	harder        = {asset = "rbxassetid://129415995354865"},
	ano           = {asset = "rbxassetid://80241994833696"},
	hard          = {asset = "rbxassetid://91932716779860"},
	normal        = {asset = "rbxassetid://116101584722307"},
	aok           = {asset = "rbxassetid://127165613136301"},
	ayes          = {asset = "rbxassetid://94931283338509"},
	easy          = {asset = "rbxassetid://140636781068646"},
}

local function ensureFolder(path)
	if not _isfolder(path) then
		local ok, err = pcall(_makefolder, path)
		if not ok then warn("[DiscordBlox] Failed to create folder: " .. path .. " | " .. tostring(err)) end
	end
end

ensureFolder(FOLDER_ROOT)
ensureFolder(FOLDER_THUMBS)
ensureFolder(FOLDER_SOUNDS)
ensureFolder(FOLDER_ICONS)

local function downloadAsset(url, path, label)
	if not _getcustomasset then
		warn("[DiscordBlox] getcustomasset not supported — skipping " .. label)
		return nil
	end
	if _isfile(path) then
		local ok, asset = pcall(_getcustomasset, path)
		if ok and asset then
			print("[DiscordBlox] " .. label .. " already cached: " .. path)
			return asset
		end
	end
	local data
	local ok, err = pcall(function()
		data = game:HttpGetAsync(url)
	end)
	if not ok or not data or #data < 100 then
		warn("[DiscordBlox] " .. label .. " download failed: " .. tostring(err or "empty response"))
		return nil
	end
	local wok, werr = pcall(_writefile, path, data)
	if not wok then
		warn("[DiscordBlox] " .. label .. " writefile failed: " .. tostring(werr))
		return nil
	end
	local aok, asset = pcall(_getcustomasset, path)
	if not aok or not asset then
		warn("[DiscordBlox] " .. label .. " getcustomasset failed: " .. tostring(asset))
		return nil
	end
	print("[DiscordBlox] " .. label .. " downloaded OK (" .. #data .. " bytes) -> " .. path)
	return asset
end

local SEND_ICON_ASSET  = nil
local ICON_REPLY       = nil
local ICON_EDIT        = nil
local ICON_DELETE      = nil
local COPY_ICON        = nil
local SEND_SOUND_ASSET = nil

local sendSound = Instance.new("Sound")
sendSound.Volume = 0.5
sendSound.RollOffMaxDistance = 0
sendSound.Parent = game:GetService("SoundService")

task.spawn(function()
	local function dl(url, path, label, callback)
		task.spawn(function()
			local asset = downloadAsset(url, path, label)
			if asset and callback then callback(asset) end
		end)
	end

	dl("https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/51/ps/1777101055626_3nvu9w_send_message_icon_250990.png",
		FOLDER_ICONS .. "/icon_send.png", "Send icon", function(a)
			SEND_ICON_ASSET = a
			if sendBtn then
				local img = sendBtn:FindFirstChildWhichIsA("ImageLabel")
				if img then img.Image = a end
			end
		end)

	dl("https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/h6/ef/1777017488312_at15cd_reply-svgrepo-com.png",
		FOLDER_ICONS .. "/icon_reply.png", "Reply icon", function(a)
			ICON_REPLY = a
			if iconReply then iconReply.Image = a end
		end)

	dl("https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/9y/00/1777017490230_vguup6_edit-svgrepo-com.png",
		FOLDER_ICONS .. "/icon_edit.png", "Edit icon", function(a)
			ICON_EDIT = a
			if iconEdit then iconEdit.Image = a end
		end)

	dl("https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/mp/ao/1777017493715_aclu82_download.png",
		FOLDER_ICONS .. "/icon_delete.png", "Delete icon", function(a)
			ICON_DELETE = a
			if iconDelete then iconDelete.Image = a end
		end)

	dl("https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/i0/4o/1777131212877_nqignq_copy-link-icon.png",
		FOLDER_ICONS .. "/icon_copy.png", "Copy icon", function(a)
			COPY_ICON = a
			if iconCopy then iconCopy.Image = a end
		end)

	dl("https://www.myinstants.com/media/sounds/discord-notification.mp3",
		FOLDER_SOUNDS .. "/discord_send.mp3", "Send sound", function(a)
			SEND_SOUND_ASSET = a
			sendSound.SoundId = a
		end)

	dl("https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/yt/66/1777101057537_f1uc8n_5968756.png",
		FOLDER_ICONS .. "/icon_topbar.png", "Topbar icon", function(a)
			if TopbarButton and TopbarButton.Parent then
				TopbarButton.Image = a
			end
		end)
end)

-- =============================================
-- FETCH DISPLAY NAME
-- =============================================
local DISPLAY_NAME = USERNAME
task.spawn(function()
	local ok, res = pcall(httpRequest, {
		Url    = "https://users.roblox.com/v1/users/" .. tostring(player.UserId),
		Method = "GET",
	})
	if ok and res and res.StatusCode == 200 then
		local d = HttpService:JSONDecode(res.Body)
		if d and d.displayName then DISPLAY_NAME = d.displayName end
	end
end)

local function getRbxThumb(userId)
	return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=60&h=60"
end

local MY_HEADSHOT     = getRbxThumb(player.UserId)
local ROBLOX_HEADSHOT = getRbxThumb(1)

-- =============================================
-- COLORS
-- =============================================
local C = {
	bg_darkest  = Color3.fromRGB(17, 18, 20),
	bg_dark     = Color3.fromRGB(30, 31, 34),
	bg_chat     = Color3.fromRGB(49, 51, 56),
	bg_input    = Color3.fromRGB(56, 58, 64),
	bg_hover    = Color3.fromRGB(64, 66, 74),
	bg_profile  = Color3.fromRGB(24, 25, 28),
	accent      = Color3.fromRGB(88, 101, 242),
	accent_hov  = Color3.fromRGB(71, 82, 196),
	txt_white   = Color3.fromRGB(219, 222, 225),
	txt_muted   = Color3.fromRGB(148, 155, 164),
	txt_pending = Color3.fromRGB(85, 88, 95),
	txt_header  = Color3.fromRGB(255, 255, 255),
	icon_grey   = Color3.fromRGB(180, 183, 189),
	online      = Color3.fromRGB(35, 165, 89),
	divider     = Color3.fromRGB(59, 61, 68),
	roblox_red  = Color3.fromRGB(226, 60, 60),
	scrollbar   = Color3.fromRGB(32, 34, 37),
}

local FB = Enum.Font.GothamBold
local FM = Enum.Font.GothamMedium
local FR = Enum.Font.Gotham

-- =============================================
-- HELPERS
-- =============================================
local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	if parent then i.Parent = parent end
	return i
end

local function corner(r, p) make("UICorner", {CornerRadius = UDim.new(0, r)}, p) end
local function pad(t, b, l, r, p)
	make("UIPadding", {
		PaddingTop = UDim.new(0,t), PaddingBottom = UDim.new(0,b),
		PaddingLeft = UDim.new(0,l), PaddingRight = UDim.new(0,r),
	}, p)
end

local function makeAv(size, letter, bgColor, parent)
	local f = make("Frame", {
		Size = UDim2.new(0,size,0,size),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
	}, parent)
	corner(size, f)

	local lbl = make("TextLabel", {
		Size = UDim2.new(1,0,1,0),
		BackgroundTransparency = 1,
		Text = letter,
		Font = FB,
		TextSize = math.floor(size*0.42),
		TextColor3 = C.txt_white,
		ZIndex = f.ZIndex + 1,
	}, f)

	local img = make("ImageLabel", {
		Size = UDim2.new(1,0,1,0),
		BackgroundTransparency = 1,
		Image = "",
		ImageTransparency = 1,
		ZIndex = f.ZIndex + 2,
	}, f)
	corner(size, img)

	return f, img, lbl
end

local function applyHeadshot(img, lbl, url)
	if url and url ~= "" then
		img.Image = url
		img.ImageTransparency = 0
		lbl.Text = ""
		local bg = img.Parent
		if bg and bg:IsA("Frame") then
			bg.BackgroundTransparency = 1
		end
	end
end

-- =============================================
-- DESTROY OLD GUI
-- =============================================
local old = playerGui:FindFirstChild("DiscordDMGui")
if old then old:Destroy() end

-- =============================================
-- ROOT GUI
-- =============================================
local gui = make("ScreenGui", {
	Name = "DiscordDMGui",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	Enabled = false,
}, playerGui)

guiRef.gui = gui

local vp = workspace.CurrentCamera.ViewportSize
local isSmallScreen = vp.X < 600 or vp.Y < 500

local winW = isSmallScreen and 0.97 or 0.80
local winH = isSmallScreen and 0.88 or 0.76
local winX = (1 - winW) / 2
local winY = (1 - winH) / 2

local winClip = make("Frame", {
	Size             = UDim2.new(winW, 0, winH, 0),
	Position         = UDim2.new(winX, 0, winY, 0),
	BackgroundColor3 = C.bg_chat,
	BorderSizePixel  = 0,
	ClipsDescendants = true,
}, gui)
corner(12, winClip)

local colAWidth = isSmallScreen and 52 or 72
local colBWidth = isSmallScreen and 180 or 240
local colTotalFixed = colAWidth + colBWidth

local win = make("Frame", {
	Size             = UDim2.new(1, 0, 1, 0),
	Position         = UDim2.new(0, 0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel  = 0,
	ClipsDescendants = false,
}, winClip)

-- COL A
local colA = make("Frame", {
	Size             = UDim2.new(0, colAWidth, 1, 0),
	Position         = UDim2.new(0, 0, 0, 0),
	BackgroundColor3 = C.bg_darkest,
	BorderSizePixel  = 0,
	ZIndex           = 2,
}, win)

local homeBox = make("Frame", {
	Size = UDim2.new(0,48,0,48),
	Position = UDim2.new(0.5,-24,0,12),
	BackgroundColor3 = C.accent,
	BorderSizePixel = 0,
	ZIndex = 3,
}, colA)
corner(16, homeBox)
make("TextLabel", {
	Size = UDim2.new(1,0,1,0),
	BackgroundTransparency = 1,
	Text = "#",
	Font = FB, TextSize = 22,
	TextColor3 = C.txt_white,
	ZIndex = 4,
}, homeBox)

make("Frame", {
	Size = UDim2.new(0,32,0,1),
	Position = UDim2.new(0.5,-16,0,72),
	BackgroundColor3 = C.bg_hover,
	BorderSizePixel = 0, ZIndex = 3,
}, colA)

local friendsBox = make("TextButton", {
	Size = UDim2.new(0,48,0,48),
	Position = UDim2.new(0.5,-24,0,82),
	BackgroundColor3 = C.bg_hover,
	BorderSizePixel = 0, ZIndex = 3,
	Text = "", AutoButtonColor = false,
}, colA)
corner(16, friendsBox)

make("TextLabel", {
	Size = UDim2.new(1,0,1,0),
	BackgroundTransparency = 1,
	Text = "+",
	Font = FB, TextSize = 26,
	TextColor3 = C.txt_muted,
	ZIndex = 4,
}, friendsBox)

local friendBadge = make("Frame", {
	Size = UDim2.new(0,16,0,16),
	Position = UDim2.new(1,-4,0,-4),
	BackgroundColor3 = Color3.fromRGB(237,66,69),
	BorderSizePixel = 0, ZIndex = 5,
	Visible = false,
}, friendsBox)
corner(8, friendBadge)
local friendBadgeLabel = make("TextLabel", {
	Size = UDim2.new(1,0,1,0),
	BackgroundTransparency = 1,
	Text = "0", Font = FB, TextSize = 9,
	TextColor3 = C.txt_white, ZIndex = 6,
}, friendBadge)

make("Frame", {
	Size = UDim2.new(0,1,1,0), Position = UDim2.new(1,-1,0,0),
	BackgroundColor3 = C.divider, BorderSizePixel = 0, ZIndex = 3,
}, colA)

-- COL B
local colB = make("Frame", {
	Size = UDim2.new(0,colBWidth,1,0),
	Position = UDim2.new(0,colAWidth,0,0),
	BackgroundColor3 = C.bg_dark,
	BorderSizePixel = 0, ZIndex = 2,
}, win)

local sbHead = make("Frame", {
	Size = UDim2.new(1,0,0,48),
	BackgroundColor3 = C.bg_dark,
	BorderSizePixel = 0, ZIndex = 3,
}, colB)
make("TextLabel", {
	Size = UDim2.new(1,-16,1,0), Position = UDim2.new(0,16,0,0),
	BackgroundTransparency = 1,
	Text = "Direct Messages", Font = FB, TextSize = 12,
	TextColor3 = C.txt_muted,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, sbHead)
make("Frame", {
	Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
	BackgroundColor3 = C.divider, BorderSizePixel = 0, ZIndex = 4,
}, sbHead)

local dmArea = make("ScrollingFrame", {
	Size = UDim2.new(1,0,1,-172),
	Position = UDim2.new(0,0,0,48),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.scrollbar,
	CanvasSize = UDim2.new(0,0,0,0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ClipsDescendants = true,
	ZIndex = 3,
}, colB)
pad(4,4,8,8, dmArea)
make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0,2),
}, dmArea)

-- ROBLOX DM ENTRY (only visible to owner)
local dmEntry = make("Frame", {
	Size = UDim2.new(1,0,0,44),
	BackgroundColor3 = C.bg_hover,
	BackgroundTransparency = 1,  -- starts transparent, highlighted on select like friend entries
	BorderSizePixel = 0, ZIndex = 4,
	Visible = (USERNAME == GLOBAL_OWNER),
	LayoutOrder = 1,
}, dmArea)
corner(4, dmEntry)

local dmSelectedBar = make("Frame", {
	Name = "SelectedBar",
	Size = UDim2.new(0,3,0,24),
	Position = UDim2.new(0,-3,0.5,-12),
	BackgroundColor3 = C.txt_white,
	BorderSizePixel = 0, ZIndex = 5,
	Visible = (USERNAME == GLOBAL_OWNER),
}, dmEntry)
if USERNAME == GLOBAL_OWNER then
	dmEntry.BackgroundTransparency = 0.7
end

local dmAvHolder = make("Frame", {
	Size = UDim2.new(0,34,0,34),
	Position = UDim2.new(0,8,0.5,-17),
	BackgroundTransparency = 1, ZIndex = 5,
}, dmEntry)

local dmAvF, dmAvImg, dmAvLbl = makeAv(34,"R",C.roblox_red, dmAvHolder)
dmAvF.Size = UDim2.new(1,0,1,0)
dmAvImg.ZIndex = 6; dmAvLbl.ZIndex = 6

local onlineDot = make("Frame", {
	Size = UDim2.new(0,10,0,10),
	Position = UDim2.new(1,-8,1,-8),
	BackgroundColor3 = C.online,
	BorderSizePixel = 0, ZIndex = 8,
}, dmAvHolder)
corner(10, onlineDot)
make("UIStroke", {Color = C.bg_dark, Thickness = 2.5}, onlineDot)

make("TextLabel", {
	Size = UDim2.new(1,-52,0,16), Position = UDim2.new(0,50,0,7),
	BackgroundTransparency = 1,
	Text = "Roblox", Font = FM, TextSize = 14,
	TextColor3 = C.txt_white,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, dmEntry)

applyHeadshot(dmAvImg, dmAvLbl, ROBLOX_HEADSHOT)

-- =============================================
-- PROFILE BAR
-- =============================================
local MPS = game:GetService("MarketplaceService")
local gameName = "Roblox"
pcall(function()
	local info = MPS:GetProductInfo(game.PlaceId)
	if info and info.Name then gameName = info.Name end
end)

local safeName  = gameName:gsub("[^%w%s%-_]", ""):gsub("%s+", "_"):sub(1, 40)
local thumbFolder = FOLDER_THUMBS .. "/" .. safeName
local thumbPath   = thumbFolder .. "/" .. tostring(game.PlaceId) .. ".png"
ensureFolder(thumbFolder)

local gameThumbAsset = nil
local gameThumbRef   = {}

task.spawn(function()
	local uniOk, uniRes = pcall(httpRequest, {
		Url = "https://apis.roblox.com/universes/v1/places/" .. tostring(game.PlaceId) .. "/universe",
		Method = "GET",
	})
	local universeId
	if uniOk and uniRes and uniRes.StatusCode == 200 then
		local ok2, d = pcall(HttpService.JSONDecode, HttpService, uniRes.Body)
		if ok2 and d and d.universeId then universeId = d.universeId end
	end
	if not universeId then return end

	local imageUrl
	local ok3, res3 = pcall(httpRequest, {
		Url = "https://thumbnails.roblox.com/v1/games/icons?universeIds=" .. tostring(universeId)
			.. "&returnPolicy=PlaceHolder&size=128x128&format=Png&isCircular=false",
		Method = "GET",
	})
	if ok3 and res3 and res3.StatusCode == 200 then
		local ok4, d = pcall(HttpService.JSONDecode, HttpService, res3.Body)
		if ok4 and d and d.data and d.data[1] then
			imageUrl = d.data[1].imageUrl
		end
	end
	if not imageUrl then return end

	local asset = downloadAsset(imageUrl, thumbPath, "Game thumbnail (" .. gameName .. ")")
	if asset then
		gameThumbAsset = asset
		if gameThumbRef.img and gameThumbRef.img.Parent then
			gameThumbRef.img.Image = asset
		end
	end
end)

local SESSION_START = os.time()

local function formatPlaytime()
	local diff = os.time() - SESSION_START
	local h = math.floor(diff / 3600)
	local m = math.floor((diff % 3600) / 60)
	local s = diff % 60
	if h > 0 then return string.format("%dh %dm", h, m)
	elseif m > 0 then return string.format("%dm %ds", m, s)
	else return string.format("%ds", s) end
end

local activityBar = make("Frame", {
	Size = UDim2.new(1,0,0,62),
	Position = UDim2.new(0,0,1,-124),
	BackgroundColor3 = Color3.fromRGB(32, 33, 37),
	BorderSizePixel = 0, ZIndex = 4,
}, colB)

make("Frame", {
	Size = UDim2.new(1,0,0,1),
	BackgroundColor3 = C.divider,
	BorderSizePixel = 0, ZIndex = 5,
}, activityBar)

make("Frame", {
	Size = UDim2.new(1,-24,0,1),
	Position = UDim2.new(0,12,1,-1),
	BackgroundColor3 = C.divider,
	BorderSizePixel = 0, ZIndex = 5,
}, activityBar)

local gameThumbImg = make("ImageLabel", {
	Size = UDim2.new(0,40,0,40),
	Position = UDim2.new(0,8,0.5,-20),
	BackgroundColor3 = C.bg_hover,
	BorderSizePixel = 0,
	Image = "",
	ZIndex = 5,
}, activityBar)
corner(6, gameThumbImg)
gameThumbRef.img = gameThumbImg

if gameThumbAsset then gameThumbImg.Image = gameThumbAsset end

make("TextLabel", {
	Size = UDim2.new(1,-60,0,16),
	Position = UDim2.new(0,56,0,10),
	BackgroundTransparency = 1,
	Text = gameName,
	Font = FM, TextSize = 12,
	TextColor3 = C.txt_white,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 5,
}, activityBar)

local sessionLabel = make("TextLabel", {
	Size = UDim2.new(1,-60,0,13),
	Position = UDim2.new(0,56,0,28),
	BackgroundTransparency = 1,
	Text = "Playing for " .. formatPlaytime(),
	Font = FR, TextSize = 10,
	TextColor3 = Color3.fromRGB(35, 165, 89),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
}, activityBar)

task.spawn(function()
	while gui and gui.Parent do
		task.wait(1)
		if sessionLabel and sessionLabel.Parent then
			sessionLabel.Text = "Playing for " .. formatPlaytime()
			sessionLabel.TextColor3 = Color3.fromRGB(35, 165, 89)
		end
	end
end)

local profileBar = make("Frame", {
	Size = UDim2.new(1,0,0,62),
	Position = UDim2.new(0,0,1,-62),
	BackgroundColor3 = C.bg_profile,
	BorderSizePixel = 0, ZIndex = 4,
}, colB)

local pbAvHolder = make("Frame", {
	Size = UDim2.new(0,32,0,32),
	Position = UDim2.new(0,8,0.5,-16),
	BackgroundTransparency = 1, ZIndex = 5,
}, profileBar)

local pbAvF, pbAvImg, pbAvLbl = makeAv(32, string.upper(string.sub(USERNAME,1,1)), C.accent, pbAvHolder)
pbAvF.Size = UDim2.new(1,0,1,0)
pbAvImg.ZIndex = 6; pbAvLbl.ZIndex = 6

local pbDot = make("Frame", {
	Size = UDim2.new(0,10,0,10),
	Position = UDim2.new(1,-8,1,-8),
	BackgroundColor3 = C.online,
	BorderSizePixel = 0, ZIndex = 8,
}, pbAvHolder)
corner(10, pbDot)
make("UIStroke", {Color = C.bg_profile, Thickness = 2.5}, pbDot)

applyHeadshot(pbAvImg, pbAvLbl, MY_HEADSHOT)

local pbNameLabel = make("TextLabel", {
	Size = UDim2.new(1,-52,0,16),
	Position = UDim2.new(0,48,0,12),
	BackgroundTransparency = 1,
	Text = DISPLAY_NAME,
	Font = FM, TextSize = 13,
	TextColor3 = C.txt_white,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 5,
}, profileBar)

task.spawn(function()
	task.wait(1.5)
	pbNameLabel.Text = DISPLAY_NAME
end)

make("TextLabel", {
	Size = UDim2.new(1,-52,0,13),
	Position = UDim2.new(0,48,0,30),
	BackgroundTransparency = 1,
	Text = "@" .. USERNAME,
	Font = FR, TextSize = 11,
	TextColor3 = C.txt_muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 5,
}, profileBar)

-- COL C: Chat area
local colC = make("Frame", {
	Size = UDim2.new(1,-colTotalFixed,1,0),
	Position = UDim2.new(0,colTotalFixed,0,0),
	BackgroundColor3 = C.bg_chat,
	BorderSizePixel = 0, ZIndex = 2,
}, win)

-- =============================================
-- CHAT HEADER
-- =============================================
local header = make("Frame", {
	Name = "Header",
	Size = UDim2.new(1,0,0,48),
	BackgroundColor3 = C.bg_chat,
	BorderSizePixel = 0, ZIndex = 3,
}, colC)

make("Frame", {
	Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
	BackgroundColor3 = C.divider, BorderSizePixel = 0, ZIndex = 4,
}, header)

make("TextLabel", {
	Size = UDim2.new(0,20,0,20), Position = UDim2.new(0,16,0.5,-10),
	BackgroundTransparency = 1,
	Text = "@", Font = FB, TextSize = 20,
	TextColor3 = C.icon_grey, ZIndex = 4,
}, header)

local chatHeaderNameLabel = make("TextLabel", {
	Size = UDim2.new(0,200,0,20), Position = UDim2.new(0,38,0.5,-10),
	BackgroundTransparency = 1,
	Text = "Roblox", Font = FB, TextSize = 15,
	TextColor3 = C.txt_header,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, header)

-- =============================================
-- WELCOME BANNER
-- =============================================
local banner = make("Frame", {
	Size = UDim2.new(1,0,0,110),
	Position = UDim2.new(0,0,0,48),
	BackgroundTransparency = 1, ZIndex = 3,
}, colC)

local bnAvHolder = make("Frame", {
	Size = UDim2.new(0,64,0,64),
	Position = UDim2.new(0,16,0,20),
	BackgroundTransparency = 1, ZIndex = 4,
}, banner)
local bnAvF, bnAvImg, bnAvLbl = makeAv(64,"R",C.roblox_red,bnAvHolder)
bnAvF.Size = UDim2.new(1,0,1,0)
bnAvImg.ZIndex = 5; bnAvLbl.ZIndex = 5

applyHeadshot(bnAvImg, bnAvLbl, ROBLOX_HEADSHOT)

make("TextLabel", {
	Size = UDim2.new(1,-96,0,28), Position = UDim2.new(0,90,0,22),
	BackgroundTransparency = 1,
	Text = "Roblox", Font = FB, TextSize = 22,
	TextColor3 = C.txt_white,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, banner)
make("TextLabel", {
	Size = UDim2.new(1,-96,0,18), Position = UDim2.new(0,90,0,52),
	BackgroundTransparency = 1,
	Text = "This is the beginning of your DM with @Roblox",
	Font = FR, TextSize = 13,
	TextColor3 = C.txt_muted,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, banner)

make("Frame", {
	Size = UDim2.new(1,-32,0,1), Position = UDim2.new(0,16,1,-1),
	BackgroundColor3 = C.divider, BorderSizePixel = 0, ZIndex = 4,
}, banner)

-- =============================================
-- MESSAGE SCROLL (global channel)
-- =============================================
local msgScroll = make("ScrollingFrame", {
	Size = UDim2.new(1,0,1,-130),
	Position = UDim2.new(0,0,0,158),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.scrollbar,
	CanvasSize = UDim2.new(0,0,0,0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingEnabled = true,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 3,
	-- FIX: hide global scroll for non-owners by default
	Visible = (USERNAME == GLOBAL_OWNER),
}, colC)

local msgLayout = make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0,0),
}, msgScroll)
pad(4,4,16,16,msgScroll)

local bannerHidden = false
local function hideBanner()
	if not bannerHidden then
		bannerHidden = true
		banner.Visible = false
		msgScroll.Position = UDim2.new(0,0,0,48)
		msgScroll.Size = UDim2.new(1,0,1,-108)
	end
end

local function smartScroll()
	local distFromBottom = msgScroll.AbsoluteCanvasSize.Y
		- msgScroll.CanvasPosition.Y
		- msgScroll.AbsoluteSize.Y
	if distFromBottom < 80 then
		msgScroll.CanvasPosition = Vector2.new(0, msgScroll.AbsoluteCanvasSize.Y)
	end
end

msgLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	task.defer(smartScroll)
end)

-- =============================================
-- INPUT AREA
-- =============================================
local inputArea = make("Frame", {
	Size = UDim2.new(1,0,0,60),
	Position = UDim2.new(0,0,1,-60),
	BackgroundColor3 = C.bg_chat,
	BorderSizePixel = 0, ZIndex = 3,
}, colC)

local inputWrap = make("Frame", {
	Size = UDim2.new(1,-32,0,44),
	Position = UDim2.new(0,16,0,8),
	BackgroundColor3 = C.bg_input,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 4,
}, inputArea)
corner(8, inputWrap)

local inputBox = make("TextBox", {
	Size = UDim2.new(1,-64,0,36),
	Position = UDim2.new(0,16,0,4),
	BackgroundTransparency = 1,
	Text = "",
	PlaceholderText = "Message @Roblox",
	Font = FR, TextSize = 14,
	TextColor3 = C.txt_white,
	PlaceholderColor3 = C.txt_muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	ClearTextOnFocus = false,
	MultiLine = true,
	ZIndex = 5,
}, inputWrap)
make("UIPadding", {PaddingRight = UDim.new(0,8)}, inputBox)

local function updateInputHeight()
	local textH = inputBox.TextBounds.Y
	local newH  = math.clamp(textH + 16, 44, 120)
	inputWrap.Size     = UDim2.new(1,-32, 0, newH)
	inputBox.Size      = UDim2.new(1,-64, 0, newH - 8)
	inputArea.Size     = UDim2.new(1,0,   0, newH + 16)
	inputArea.Position = UDim2.new(0,0,   1, -(newH + 16))
	msgScroll.Size     = UDim2.new(1,0,   1, -(126 + (newH - 44)))
end

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
	task.defer(updateInputHeight)
end)

local sendBtn = make("TextButton", {
	Size = UDim2.new(0,36,0,36),
	Position = UDim2.new(1,-40,0.5,-18),
	BackgroundColor3 = C.accent,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false, ZIndex = 5,
}, inputWrap)
corner(100, sendBtn)

make("ImageLabel", {
	Size = UDim2.new(0,20,0,20),
	Position = UDim2.new(0.5,-10,0.5,-10),
	BackgroundTransparency = 1,
	Image = SEND_ICON_ASSET or "rbxassetid://6031094678",
	ImageColor3 = C.txt_white,
	ZIndex = 6,
}, sendBtn)

sendBtn.MouseEnter:Connect(function()
	if inputBox.Text ~= "" then
		TweenService:Create(sendBtn, TweenInfo.new(0.15), {BackgroundColor3 = C.accent_hov}):Play()
	end
end)
sendBtn.MouseLeave:Connect(function()
	if inputBox.Text ~= "" then
		TweenService:Create(sendBtn, TweenInfo.new(0.15), {BackgroundColor3 = C.accent}):Play()
	end
end)

local function updateSendBtn()
	local empty = inputBox.Text:match("^%s*$") ~= nil
	sendBtn.BackgroundColor3 = empty and Color3.fromRGB(64,66,74) or C.accent
	sendBtn.Active = not empty
end
updateSendBtn()
inputBox:GetPropertyChangedSignal("Text"):Connect(updateSendBtn)

-- =============================================
-- DM ENTRY PREVIEW
-- =============================================
local dmLastMsgLabel = make("TextLabel", {
	Size = UDim2.new(1,-52,0,14), Position = UDim2.new(0,50,0,24),
	BackgroundTransparency = 1,
	Text = "", Font = FR, TextSize = 11,
	TextColor3 = C.txt_muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 5,
}, dmEntry)

local dmTimestampLabel = make("TextLabel", {
	Size = UDim2.new(0,40,0,12), Position = UDim2.new(1,-48,0,8),
	BackgroundTransparency = 1,
	Text = "", Font = FR, TextSize = 10,
	TextColor3 = C.txt_muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 5,
}, dmEntry)

local function formatRelativeTime(ts)
	local diff = os.time() - ts
	if diff < 60 then return "now"
	elseif diff < 3600 then return math.floor(diff/60) .. "m"
	elseif diff < 86400 then return math.floor(diff/3600) .. "h"
	else return math.floor(diff/86400) .. "d" end
end

local lastMsgTs = 0
local function updateDMPreview(sender, text, ts)
	if ts < lastMsgTs then return end
	lastMsgTs = ts
	local prefix = sender == USERNAME and "You: " or (sender .. ": ")
	local preview = text:gsub(":([%w_]+):", function(name)
		return (":" .. name .. ":")
	end)
	dmLastMsgLabel.Text = prefix .. preview
	dmTimestampLabel.Text = formatRelativeTime(ts)
end

task.spawn(function()
	local ok, res = pcall(httpRequest, {
		Url = "https://presence.roblox.com/v1/presence/users",
		Method = "POST",
		Headers = {["Content-Type"] = "application/json"},
		Body = HttpService:JSONEncode({userIds = {1}}),
	})
	if ok and res and res.StatusCode == 200 then
		local ok2, d = pcall(HttpService.JSONDecode, HttpService, res.Body)
		if ok2 and d and d.userPresences and d.userPresences[1] then
			local p = d.userPresences[1]
			if p.presenceType == 0 then
				dmLastMsgLabel.Text = "Offline"
				onlineDot.BackgroundColor3 = Color3.fromRGB(128,132,142)
			elseif p.presenceType == 2 then
				dmLastMsgLabel.Text = "Playing " .. (p.lastLocation or "a game")
			elseif p.presenceType == 3 then
				dmLastMsgLabel.Text = "In Studio"
			else
				dmLastMsgLabel.Text = "Online"
			end
		end
	end
end)

local msgOrder    = 0
local seenKeys    = {}
local lastSender  = nil
local lastTs      = 0
local GROUP_GAP   = 300
local lastDateStr = nil
local renderedRows = {}
-- editing bar declared before clearEdit references it
local editingBar  = nil

local function renderDateSeparator(ts)
	local dateStr = os.date("%B %d, %Y", ts)
	if dateStr == lastDateStr then return end
	lastDateStr = dateStr
	lastSender = nil
	lastTs     = 0
	msgOrder += 1

	local sep = make("Frame", {
		Name = "DateSep",
		Size = UDim2.new(1,0,0,24),
		BackgroundTransparency = 1,
		LayoutOrder = msgOrder, ZIndex = 3,
	}, msgScroll)

	make("Frame", {
		Size = UDim2.new(0.5,-40,0,1),
		Position = UDim2.new(0,0,0.5,0),
		BackgroundColor3 = C.divider,
		BorderSizePixel = 0, ZIndex = 4,
	}, sep)
	make("TextLabel", {
		Size = UDim2.new(0,80,1,0),
		Position = UDim2.new(0.5,-40,0,0),
		BackgroundTransparency = 1,
		Text = dateStr,
		Font = FM, TextSize = 11,
		TextColor3 = C.txt_muted,
		ZIndex = 4,
	}, sep)
	make("Frame", {
		Size = UDim2.new(0.5,-40,0,1),
		Position = UDim2.new(0.5,40,0.5,0),
		BackgroundColor3 = C.divider,
		BorderSizePixel = 0, ZIndex = 4,
	}, sep)
end

-- =============================================
-- EMOJI PARSING
-- =============================================
local function parseEmoji(text)
	local tokens = {}
	local i = 1
	while i <= #text do
		local s, e, name = text:find(":([%w_]+):", i)
		if s then
			if s > i then
				table.insert(tokens, {type="text", value=text:sub(i, s-1)})
			end
			table.insert(tokens, {type="emoji", name=name, value=":"..name..":"})
			i = e + 1
		else
			table.insert(tokens, {type="text", value=text:sub(i)})
			break
		end
	end
	return tokens
end

local function isEmojiOnly(tokens)
	for _, t in ipairs(tokens) do
		if t.type == "text" and t.value:match("%S") then return false end
	end
	for _, t in ipairs(tokens) do
		if t.type == "emoji" then return true end
	end
	return false
end

local function tokensToRichText(tokens, jumbo)
	local emojiSize = jumbo and 48 or 22
	local parts = {}
	for _, token in ipairs(tokens) do
		if token.type == "emoji" then
			local em = CUSTOM_EMOJIS[token.name]
			if em then
				table.insert(parts, string.format(
					'<img src="%s" width="%d" height="%d" />',
					em.asset, emojiSize, emojiSize
				))
			else
				table.insert(parts, "<b>" .. token.value .. "</b>")
			end
		else
			local esc = token.value
				:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;")
			table.insert(parts, esc)
		end
	end
	return table.concat(parts)
end

local function buildEmojiContent(parent, tokens, jumbo, baseZIndex, txtColor)
	local fontSize = jumbo and 48 or 14
	local lbl = make("TextLabel", {
		Size = UDim2.new(1,0,0,0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = true,
		Text = tokensToRichText(tokens, jumbo),
		Font = FR, TextSize = fontSize,
		TextColor3 = txtColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = baseZIndex,
	}, parent)
	return lbl
end

local function refreshEmojiContent(lbl, text, isPending)
	if not lbl or not lbl.Parent then return end
	local color  = isPending and C.txt_pending or C.txt_white
	local tokens = parseEmoji(text)
	local jumbo  = isEmojiOnly(tokens)
	lbl.RichText = true
	lbl.Text      = tokensToRichText(tokens, jumbo)
	lbl.TextSize  = jumbo and 48 or 14
	lbl.TextColor3 = color
end

local function renderMessage(senderName, text, isPending, msgTs, isEdited, replyData)
	msgTs = msgTs or os.time()
	hideBanner()
	renderDateSeparator(msgTs)
	msgOrder += 1

	local isMe        = senderName == USERNAME
	local avColor     = isMe and C.accent or C.roblox_red
	local avLetter    = string.upper(string.sub(senderName, 1, 1))
	local displayName = isMe and DISPLAY_NAME or senderName
	local txtColor    = isPending and C.txt_pending or C.txt_white
	local timeStr     = os.date("%I:%M %p", msgTs)

	local isGrouped   = (senderName == lastSender) and ((msgTs - lastTs) < GROUP_GAP) and not replyData
	lastSender = senderName
	lastTs     = msgTs

	if not isPending then
		updateDMPreview(senderName, text, msgTs)
	end

	local row = make("TextButton", {
		Size = UDim2.new(1,0,0,0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = msgOrder, ZIndex = 3,
		Text = "", AutoButtonColor = false,
	}, msgScroll)

	local hbg = make("Frame", {
		Size = UDim2.new(1,20,1,0), Position = UDim2.new(0,-10,0,0),
		BackgroundTransparency = 1,
		BackgroundColor3 = C.bg_hover,
		BorderSizePixel = 0, ZIndex = 2,
	}, row)
	corner(4, hbg)
	row.MouseEnter:Connect(function()
		TweenService:Create(hbg,TweenInfo.new(0.1),{BackgroundTransparency=0.78}):Play()
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(hbg,TweenInfo.new(0.1),{BackgroundTransparency=1}):Play()
	end)

	local content
	local outerCol = make("Frame", {
		Size = UDim2.new(1,0,0,0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, ZIndex = 4,
	}, row)
	make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,0)}, outerCol)

	if replyData then
		local replyOuter = make("Frame", {
			Size = UDim2.new(1,0,0,20),
			BackgroundTransparency = 1,
			LayoutOrder = 1, ZIndex = 5,
		}, outerCol)
		local vbar = make("Frame", {
			Size = UDim2.new(0,2,1,0),
			Position = UDim2.new(0,40,0,0),
			BackgroundColor3 = C.txt_muted,
			BorderSizePixel = 0, ZIndex = 6,
		}, replyOuter)
		corner(4, vbar)
		local replyInner = make("Frame", {
			Size = UDim2.new(1,-52,1,0),
			Position = UDim2.new(0,48,0,0),
			BackgroundTransparency = 1, ZIndex = 6,
		}, replyOuter)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0,4),
		}, replyInner)
		local rAv = make("Frame", {
			Size = UDim2.new(0,14,0,14),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1, ZIndex = 7,
		}, replyInner)
		local rAvImg = make("ImageLabel", {
			Size = UDim2.new(1,0,1,0),
			BackgroundTransparency = 1,
			Image = (replyData.sender == USERNAME) and MY_HEADSHOT or ROBLOX_HEADSHOT,
			ZIndex = 8,
		}, rAv)
		corner(14, rAvImg)
		make("TextLabel", {
			Size = UDim2.new(0,0,1,0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = replyData.sender,
			Font = FM, TextSize = 12,
			TextColor3 = C.txt_white,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2, ZIndex = 7,
		}, replyInner)
		local previewText = replyData.text:gsub(":([%w_]+):", ":%1:")
		make("TextLabel", {
			Size = UDim2.new(1,0,1,0),
			BackgroundTransparency = 1,
			Text = previewText,
			Font = FR, TextSize = 12,
			TextColor3 = C.txt_muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 3, ZIndex = 7,
		}, replyInner)
	end

	local msgRow = make("Frame", {
		Size = UDim2.new(1,0,0,0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2, ZIndex = 5,
	}, outerCol)

	if isGrouped then
		pad(2,4,52,0,msgRow)
		local tokens  = parseEmoji(text)
		local jumbo   = isEmojiOnly(tokens)
		local wrapper = make("Frame", {
			Size = UDim2.new(1,0,0,0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, ZIndex = 6,
		}, msgRow)
		content = buildEmojiContent(wrapper, tokens, jumbo, 6, txtColor)
	else
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0,12),
		}, msgRow)
		pad(8,4,0,0,msgRow)

		local avHolder = make("Frame", {
			Size = UDim2.new(0,40,0,40),
			BackgroundTransparency = 1,
			LayoutOrder = 1, ZIndex = 5,
		}, msgRow)
		local avF, avImg, avLbl = makeAv(40, avLetter, avColor, avHolder)
		avF.Size = UDim2.new(1,0,1,0)
		avImg.ZIndex = 6; avLbl.ZIndex = 6
		applyHeadshot(avImg, avLbl, isMe and MY_HEADSHOT or ROBLOX_HEADSHOT)

		local tb = make("Frame", {
			Size = UDim2.new(1,-64,0,0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2, ZIndex = 5,
		}, msgRow)
		make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,2)}, tb)

		local nr = make("Frame", {
			Size = UDim2.new(1,0,0,18),
			BackgroundTransparency = 1,
			LayoutOrder = 1, ZIndex = 6,
		}, tb)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}, nr)
		make("TextLabel", {
			Size = UDim2.new(0,0,1,0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = displayName, Font = FB, TextSize = 14,
			TextColor3 = C.txt_white,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1, ZIndex = 7,
		}, nr)
		make("TextLabel", {
			Size = UDim2.new(0,0,1,0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = "  " .. timeStr,
			Font = FR, TextSize = 11,
			TextColor3 = C.txt_muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2, ZIndex = 7,
		}, nr)

		local tokens = parseEmoji(text)
		local jumbo  = isEmojiOnly(tokens)
		local wrapper = make("Frame", {
			Size = UDim2.new(1,0,0,0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2, ZIndex = 6,
		}, tb)
		content = buildEmojiContent(wrapper, tokens, jumbo, 7, txtColor)

		if isEdited then
			make("TextLabel", {
				Name = "EditedTag",
				Size = UDim2.new(1,0,0,14),
				BackgroundTransparency = 1,
				Text = "(edited)",
				Font = FR, TextSize = 10,
				TextColor3 = C.txt_muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 3, ZIndex = 7,
			}, tb)
		end
	end

	local result = {content = content, sender = senderName, row = row, isGrouped = isGrouped, rawText = text, msgTs = msgTs}
	table.insert(renderedRows, result)
	return result
end

local function confirmRender(data)
	if data and data.content then
		TweenService:Create(data.content, TweenInfo.new(0.25), {TextColor3 = C.txt_white}):Play()
		updateDMPreview(data.sender or USERNAME, data.content.Text, os.time())
	end
end

-- =============================================
-- FIREBASE
-- =============================================
local function firebaseSendGlobal(text, replyData)
	local ts  = os.time()
	local key = tostring(ts) .. "_" .. tostring(math.random(10000, 99999))
	local url = FIREBASE_URL .. "/" .. key .. ".json"
	local payload = {sender = USERNAME, text = text, ts = ts}
	if replyData then payload.replyData = replyData end
	local body = HttpService:JSONEncode(payload)
	local ok, res = pcall(httpRequest, {
		Url = url, Method = "PUT",
		Headers = {["Content-Type"] = "application/json"},
		Body = body,
	})
	local sent = ok and res and (res.StatusCode == 200 or res.StatusCode == 201 or res.StatusCode == 204)
	return sent, key
end

-- =============================================
-- CHANNEL STATE — defined before context menu and send logic
-- =============================================
local currentChannel  = (USERNAME == GLOBAL_OWNER) and "global" or "none"
local channelData     = {}
local activeDMSlots   = {}
local knownFriends    = {}
local knownPending    = {}

-- =============================================
-- FIREBASE SEND — routes based on currentChannel
-- =============================================
local function firebaseSend(text, replyData)
	-- FIX: route to correct channel based on currentChannel
	if currentChannel ~= "global" and currentChannel ~= "none" then
		local ts  = os.time()
		local key = tostring(ts).."_"..tostring(math.random(10000,99999))
		local url = "https://discord-roblox-40fa8-default-rtdb.firebaseio.com/dms/"..currentChannel.."/messages/"..key..".json"
		local payload = {sender=USERNAME, text=text, ts=ts}
		if replyData then payload.replyData = replyData end
		local ok, res = pcall(httpRequest, {
			Url=url, Method="PUT",
			Headers={["Content-Type"]="application/json"},
			Body=HttpService:JSONEncode(payload),
		})
		local sent = ok and res and (res.StatusCode==200 or res.StatusCode==201 or res.StatusCode==204)
		return sent, key
	end
	-- Only send to global if user is owner
	if currentChannel == "global" and USERNAME == GLOBAL_OWNER then
		return firebaseSendGlobal(text, replyData)
	end
	-- Non-owners on "none" channel: do nothing
	return false, nil
end

-- =============================================
-- CONTEXT MENU
-- =============================================
local contextMenu = make("Frame", {
	Size = UDim2.new(0, 160, 0, 144),
	BackgroundColor3 = Color3.fromRGB(12, 12, 14),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 200,
}, gui)
corner(8, contextMenu)
make("UIStroke", {Color = Color3.fromRGB(30,30,35), Thickness = 1}, contextMenu)

local ctxLayout = make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 0),
}, contextMenu)
pad(4, 4, 4, 4, contextMenu)

local function makeCtxBtn(label, iconUrl, iconColor, textColor, order)
	local btn = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromRGB(30, 30, 35),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		ZIndex = 101,
	}, contextMenu)
	corner(4, btn)

	local icon = make("ImageLabel", {
		Size = UDim2.new(0, 18, 0, 18),
		Position = UDim2.new(0, 8, 0.5, -9),
		BackgroundTransparency = 1,
		Image = iconUrl or "",
		ImageColor3 = iconColor,
		ZIndex = 102,
	}, btn)

	make("TextLabel", {
		Size = UDim2.new(1, -36, 1, 0),
		Position = UDim2.new(0, 32, 0, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = FM, TextSize = 13,
		TextColor3 = textColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
	}, btn)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.7}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
	end)

	return btn, icon
end

local btnReply,  iconReply  = makeCtxBtn("Reply",  ICON_REPLY,  Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255), 1)
local btnCopy,   iconCopy   = makeCtxBtn("Copy",   COPY_ICON,   Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255), 2)
local btnEdit,   iconEdit   = makeCtxBtn("Edit",   ICON_EDIT,   Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255), 3)

make("Frame", {
	Size = UDim2.new(1,-8,0,1),
	BackgroundColor3 = Color3.fromRGB(40,40,46),
	BorderSizePixel = 0,
	LayoutOrder = 4,
	ZIndex = 101,
}, contextMenu)

local btnDelete, iconDelete = makeCtxBtn("Delete", ICON_DELETE, Color3.fromRGB(237,66,69), Color3.fromRGB(237,66,69), 5)

local ctxTargetData = nil

local function showContextMenu(x, y, data)
	ctxTargetData = data
	local isOwn = data.sender == USERNAME

	btnEdit.Visible   = isOwn
	btnDelete.Visible = isOwn
	for _, c in ipairs(contextMenu:GetChildren()) do
		if c:IsA("Frame") and c.LayoutOrder == 4 then
			c.Visible = isOwn
		end
	end

	contextMenu.Size = UDim2.new(0, 160, 0, isOwn and 144 or 76)

	local sw = workspace.CurrentCamera.ViewportSize.X
	local sh = workspace.CurrentCamera.ViewportSize.Y
	local menuH = isOwn and 144 or 76
	local mx = math.min(x, sw - 168)
	local my = math.min(y, sh - menuH - 8)
	contextMenu.Position = UDim2.new(0, mx, 0, my)
	contextMenu.Visible = true
end

local function hideContextMenu()
	contextMenu.Visible = false
	ctxTargetData = nil
end

local function attachHoldDetection(row, getData)
	local holdTimer = nil
	local holdPos   = Vector2.new(0, 0)

	local function startHold(x, y)
		holdPos = Vector2.new(x, y)
		holdTimer = task.delay(1, function()
			showContextMenu(holdPos.X, holdPos.Y, getData())
		end)
	end

	local function cancelHold()
		if holdTimer then
			task.cancel(holdTimer)
			holdTimer = nil
		end
	end

	row.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			startHold(input.Position.X, input.Position.Y)
		end
	end)
	row.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			cancelHold()
		end
	end)
	row.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			startHold(input.Position.X, input.Position.Y)
		end
	end)
	row.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			cancelHold()
		end
	end)
	row.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			local dx = math.abs(input.Position.X - holdPos.X)
			local dy = math.abs(input.Position.Y - holdPos.Y)
			if dx > 10 or dy > 10 then cancelHold() end
		end
	end)
end

local function firebasePoll()
	if USERNAME ~= GLOBAL_OWNER then return end
	local ok, res = pcall(httpRequest, {
		Url = FIREBASE_URL .. ".json",
		Method = "GET",
		Headers = {["Content-Type"] = "application/json"},
	})

	if not ok or not res or res.StatusCode ~= 200 then return end
	if res.Body == "null" or res.Body == nil then return end

	local ok2, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
	if not ok2 or type(data) ~= "table" then return end

	local msgs = {}
	for key, val in pairs(data) do
		if type(val) == "table" and val.sender and val.text and val.ts then
			table.insert(msgs, {key=key, sender=val.sender, text=val.text, ts=val.ts})
		end
	end
	table.sort(msgs, function(a,b) return a.ts < b.ts end)

	for _, msg in ipairs(msgs) do
		if not seenKeys[msg.key] then
			seenKeys[msg.key] = true
			local rendered = renderMessage(msg.sender, msg.text, false, msg.ts, msg.edited == true, msg.replyData)

			if rendered and rendered.row then
				local msgKey    = msg.key
				local msgText   = msg.text
				local msgTs     = msg.ts
				local msgSender = msg.sender
				attachHoldDetection(rendered.row, function()
					return {
						key          = msgKey,
						text         = msgText,
						sender       = msgSender,
						contentLabel = rendered.content,
						rowFrame     = rendered.row,
						ts           = msgTs,
					}
				end)
			end
		end
	end
end

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		if contextMenu.Visible then
			local pos = contextMenu.AbsolutePosition
			local sz  = contextMenu.AbsoluteSize
			local ix  = input.Position.X
			local iy  = input.Position.Y
			local inside = ix >= pos.X and ix <= pos.X + sz.X
				and iy >= pos.Y and iy <= pos.Y + sz.Y
			if not inside then hideContextMenu() end
		end
	end
end)

-- REPLY
local replyingTo = nil
local replyBar   = nil

local function clearReply()
	replyingTo = nil
	if replyBar and replyBar.Parent then
		replyBar:Destroy()
		replyBar = nil
	end
	inputBox.PlaceholderText = "Message @Roblox"
end

btnReply.MouseButton1Click:Connect(function()
	if not ctxTargetData then return end
	replyingTo = {sender = ctxTargetData.sender, text = ctxTargetData.text}

	if replyBar and replyBar.Parent then replyBar:Destroy() end
	replyBar = make("Frame", {
		Size = UDim2.new(1,0,0,28),
		Position = UDim2.new(0,0,1,-92),
		BackgroundColor3 = Color3.fromRGB(40,42,48),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, colC)

	make("TextLabel", {
		Size = UDim2.new(1,-40,1,0),
		Position = UDim2.new(0,12,0,0),
		BackgroundTransparency = 1,
		Text = "Replying to " .. replyingTo.sender .. ": " .. replyingTo.text:sub(1,40),
		Font = FR, TextSize = 11,
		TextColor3 = C.txt_muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
	}, replyBar)

	local cancelReply = make("TextButton", {
		Size = UDim2.new(0,24,0,24),
		Position = UDim2.new(1,-28,0.5,-12),
		BackgroundTransparency = 1,
		Text = "x", Font = FM, TextSize = 13,
		TextColor3 = C.txt_muted,
		AutoButtonColor = false, ZIndex = 5,
	}, replyBar)
	cancelReply.MouseButton1Click:Connect(clearReply)

	hideContextMenu()
end)

btnCopy.MouseButton1Click:Connect(function()
	if not ctxTargetData then return end
	local text = ctxTargetData.text
	hideContextMenu()
	if setclipboard then
		pcall(setclipboard, text)
	elseif toclipboard then
		pcall(toclipboard, text)
	else
		warn("[DiscordBlox] setclipboard not supported on this executor")
	end
end)

local editingConn = nil

local function clearEdit()
	if editingBar and editingBar.Parent then editingBar:Destroy() end
	editingBar = nil
	if editingConn then editingConn:Disconnect(); editingConn = nil end
	inputBox.Text = ""
	inputBox.PlaceholderText = "Message @Roblox"
end

btnEdit.MouseButton1Click:Connect(function()
	if not ctxTargetData then return end
	local data = ctxTargetData
	hideContextMenu()

	clearEdit()
	clearReply()

	editingBar = make("Frame", {
		Size = UDim2.new(1,0,0,28),
		Position = UDim2.new(0,0,1,-92),
		BackgroundColor3 = Color3.fromRGB(40,42,48),
		BorderSizePixel = 0, ZIndex = 4,
	}, colC)

	make("TextLabel", {
		Size = UDim2.new(1,-40,1,0),
		Position = UDim2.new(0,12,0,0),
		BackgroundTransparency = 1,
		Text = "Editing message: " .. data.text:sub(1,40),
		Font = FM, TextSize = 11,
		TextColor3 = C.txt_muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
	}, editingBar)

	local cancelEdit = make("TextButton", {
		Size = UDim2.new(0,24,0,24),
		Position = UDim2.new(1,-28,0.5,-12),
		BackgroundTransparency = 1,
		Text = "x", Font = FM, TextSize = 13,
		TextColor3 = C.txt_muted,
		AutoButtonColor = false, ZIndex = 5,
	}, editingBar)
	cancelEdit.MouseButton1Click:Connect(clearEdit)

	inputBox.Text = data.text
	inputBox:CaptureFocus()

	local editKey          = data.key
	local editContentLabel = data.contentLabel

	-- Determine the Firebase URL for edit based on which channel the message is in
	local editUrl
	if currentChannel == "global" then
		editUrl = FIREBASE_URL .. "/" .. editKey .. ".json"
	else
		editUrl = "https://discord-roblox-40fa8-default-rtdb.firebaseio.com/dms/"..currentChannel.."/messages/"..editKey..".json"
	end

	local function submitEdit()
		local newText = inputBox.Text
		if newText:match("^%s*$") then clearEdit(); return end
		clearEdit()

		local body = HttpService:JSONEncode({
			sender = USERNAME, text = newText, ts = data.ts, edited = true
		})
		local ok, res = pcall(httpRequest, {
			Url = editUrl, Method = "PUT",
			Headers = {["Content-Type"] = "application/json"},
			Body = body,
		})
		if ok and res and res.StatusCode == 200 then
			if editContentLabel and editContentLabel.Parent then
				refreshEmojiContent(editContentLabel, newText, false)
				local tb = editContentLabel.Parent
				if tb and not tb:FindFirstChild("EditedTag") then
					make("TextLabel", {
						Name = "EditedTag",
						Size = UDim2.new(1,0,0,14),
						BackgroundTransparency = 1,
						Text = "(edited)",
						Font = FR, TextSize = 10,
						TextColor3 = C.txt_muted,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 3, ZIndex = 7,
					}, tb)
				end
			end
		end
	end

	editingConn = inputBox.FocusLost:Connect(function(enter)
		if enter then submitEdit() end
	end)

	local editSendConn
	editSendConn = sendBtn.MouseButton1Click:Connect(function()
		editSendConn:Disconnect()
		submitEdit()
	end)
end)

btnDelete.MouseButton1Click:Connect(function()
	if not ctxTargetData then return end
	local data = ctxTargetData
	hideContextMenu()

	-- Determine correct delete URL
	local delUrl
	if currentChannel == "global" then
		delUrl = FIREBASE_URL .. "/" .. data.key .. ".json"
	else
		delUrl = "https://discord-roblox-40fa8-default-rtdb.firebaseio.com/dms/"..currentChannel.."/messages/"..data.key..".json"
	end

	local ok, res = pcall(httpRequest, {Url = delUrl, Method = "DELETE"})
	if not (ok and res and (res.StatusCode == 200 or res.StatusCode == 204)) then
		warn("[DiscordBlox] Delete failed: " .. tostring(res and res.StatusCode))
		return
	end

	seenKeys[data.key] = true

	local rowIdx = nil
	for i, r in ipairs(renderedRows) do
		if r.row == data.rowFrame then rowIdx = i; break end
	end

	if rowIdx then
		local nextEntry = renderedRows[rowIdx + 1]
		if nextEntry and nextEntry.isGrouped and nextEntry.row and nextEntry.row.Parent then
			local outerCol
			for _, c in ipairs(nextEntry.row:GetChildren()) do
				if c:IsA("Frame") and c:FindFirstChildWhichIsA("UIListLayout") then
					outerCol = c; break
				end
			end
			if outerCol then
				local msgRow
				for _, c in ipairs(outerCol:GetChildren()) do
					if c:IsA("Frame") and c.LayoutOrder == 2 then msgRow = c; break end
				end
				if msgRow then
					for _, c in ipairs(msgRow:GetChildren()) do c:Destroy() end

					local isMe = nextEntry.sender == USERNAME
					local avColor = isMe and C.accent or C.roblox_red
					local avLetter = string.upper(string.sub(nextEntry.sender,1,1))

					make("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Top,
						Padding = UDim.new(0,12),
					}, msgRow)
					pad(8,4,0,0,msgRow)

					local avHolder = make("Frame", {
						Size = UDim2.new(0,40,0,40), BackgroundTransparency = 1,
						LayoutOrder = 1, ZIndex = 5,
					}, msgRow)
					local avF, avImg, avLbl = makeAv(40, avLetter, avColor, avHolder)
					avF.Size = UDim2.new(1,0,1,0)
					applyHeadshot(avImg, avLbl, isMe and MY_HEADSHOT or ROBLOX_HEADSHOT)

					local tb = make("Frame", {
						Size = UDim2.new(1,-64,0,0), AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 5,
					}, msgRow)
					make("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,2)}, tb)

					local nr = make("Frame", {
						Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1,
						LayoutOrder = 1, ZIndex = 6,
					}, tb)
					make("UIListLayout", {
						FillDirection=Enum.FillDirection.Horizontal,
						VerticalAlignment=Enum.VerticalAlignment.Center,
					}, nr)
					make("TextLabel", {
						Size = UDim2.new(0,0,1,0), AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = isMe and DISPLAY_NAME or nextEntry.sender,
						Font = FB, TextSize = 14, TextColor3 = C.txt_white,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1, ZIndex = 7,
					}, nr)

					local rawText = nextEntry.rawText or ""
					local tokens  = parseEmoji(rawText)
					local jumbo   = isEmojiOnly(tokens)
					local wrapper = make("Frame", {
						Size = UDim2.new(1,0,0,0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = 2, ZIndex = 6,
					}, tb)
					local newContent = buildEmojiContent(wrapper, tokens, jumbo, 7, C.txt_white)
					nextEntry.content  = newContent
					nextEntry.isGrouped = false
				end
			end
		end
		table.remove(renderedRows, rowIdx)
	end

	if data.rowFrame and data.rowFrame.Parent then
		data.rowFrame:Destroy()
	end

	task.delay(0.1, function()
		local children = msgScroll:GetChildren()
		local ordered = {}
		for _, c in ipairs(children) do
			if c:IsA("Frame") or c:IsA("TextButton") then
				table.insert(ordered, c)
			end
		end
		table.sort(ordered, function(a,b) return a.LayoutOrder < b.LayoutOrder end)
		for i, child in ipairs(ordered) do
			if child.Name == "DateSep" and child.Parent then
				local hasMsg = false
				for j = i+1, #ordered do
					if ordered[j].Name == "DateSep" then break end
					if ordered[j].Name ~= "DateSep" then hasMsg = true; break end
				end
				if not hasMsg then child:Destroy() end
			end
		end
	end)
end)

-- =============================================
-- SEND
-- =============================================
local function sendMessage()
	local rawText = inputBox.Text
	if not rawText or rawText:match("^%s*$") then return end
	if editingBar and editingBar.Parent then return end
	-- FIX: block send if non-owner on global (no channel)
	if currentChannel == "none" then return end

	inputBox.Text = ""

	local text      = rawText
	local curReply  = replyingTo
	if curReply then clearReply() end

	local replyPayload = curReply and {sender = curReply.sender, text = curReply.text:sub(1,80)} or nil

	-- FIX: only render in global scroll if on global channel; private renders in its own scroll
	if currentChannel == "global" then
		local msgData = renderMessage(USERNAME, text, true, os.time(), false, replyPayload)

		if msgData and msgData.row then
			local pendingKey = nil
			attachHoldDetection(msgData.row, function()
				return {
					key          = pendingKey,
					text         = text,
					sender       = USERNAME,
					contentLabel = msgData.content,
					rowFrame     = msgData.row,
					ts           = os.time(),
				}
			end)

			task.spawn(function()
				local success, key = firebaseSend(text, replyPayload)
				if success then
					pendingKey = key
					seenKeys[key] = true
					confirmRender(msgData)
					if sendSound and SEND_SOUND_ASSET then sendSound:Play() end
				else
					if msgData and msgData.content then
						msgData.content.TextColor3 = Color3.fromRGB(200,60,60)
						msgData.content.Text = text .. "  [failed]"
					end
					lastSender = nil
					lastTs = 0
				end
			end)
		end
	else
		-- Private DM: render gray immediately, confirm white on success
		local cd = channelData[currentChannel]
		if not cd then return end
		-- Render optimistically in pending (gray) state
		local pendingKey = nil
		cd.currentMsgKey = "pending"
		local msgData = renderPrivateMsg(cd, USERNAME, text, os.time(), false, replyPayload, true)
		task.spawn(function()
			local success, key = firebaseSend(text, replyPayload)
			if success then
				pendingKey = key
				cd.seenKeys[key] = true
				-- Confirm: tween content to white
				if msgData and msgData.content then
					TweenService:Create(msgData.content, TweenInfo.new(0.25), {TextColor3 = C.txt_white}):Play()
				end
				if sendSound and SEND_SOUND_ASSET then sendSound:Play() end
			else
				-- Mark as failed
				if msgData and msgData.content then
					msgData.content.TextColor3 = Color3.fromRGB(200,60,60)
					msgData.content.Text = text .. "  [failed]"
				end
			end
		end)
	end
end

sendBtn.MouseButton1Click:Connect(sendMessage)

inputBox.FocusLost:Connect(function(enter)
	if enter and not (editingBar and editingBar.Parent) then
		sendMessage()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Return
		and not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		and not UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		if not (editingBar and editingBar.Parent) then
			sendMessage()
		end
	end
end)

-- =============================================
-- DRAG
-- =============================================
local dragging, dragStart, wsX, wsY = false, nil, 0, 0

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging  = true
		dragStart = input.Position
		wsX = winClip.AbsolutePosition.X
		wsY = winClip.AbsolutePosition.Y
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local d = input.Position - dragStart
		winClip.Position = UDim2.new(0, wsX+d.X, 0, wsY+d.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- =============================================
-- FIREBASE PATHS FOR FRIENDS SYSTEM
-- =============================================
local FB_USERS    = "https://discord-roblox-40fa8-default-rtdb.firebaseio.com/users"
local FB_REQUESTS = "https://discord-roblox-40fa8-default-rtdb.firebaseio.com/friend_requests"
local FB_FRIENDS  = "https://discord-roblox-40fa8-default-rtdb.firebaseio.com/friends"
local FB_DMS      = "https://discord-roblox-40fa8-default-rtdb.firebaseio.com/dms"
local FB_LASTSEEN = "https://discord-roblox-40fa8-default-rtdb.firebaseio.com/lastseen"

-- Cache of friend info fetched from Firebase: username -> {headshot, displayName, lastOnline}
local friendInfoCache = {}

local function fetchFriendInfo(friendName, callback)
	if friendInfoCache[friendName] then
		if callback then callback(friendInfoCache[friendName]) end
		return
	end
	task.spawn(function()
		local ok, res = pcall(httpRequest, {Url=FB_USERS.."/"..friendName..".json", Method="GET"})
		if ok and res and res.StatusCode==200 and res.Body~="null" then
			local ok2, d = pcall(HttpService.JSONDecode, HttpService, res.Body)
			if ok2 and d then
				friendInfoCache[friendName] = {
					headshot    = d.headshot or getRbxThumb(1),
					displayName = d.displayName or friendName,
					lastOnline  = d.lastOnline or 0,
				}
				if callback then callback(friendInfoCache[friendName]) end
				return
			end
		end
		-- Fallback
		friendInfoCache[friendName] = {
			headshot    = getRbxThumb(1),
			displayName = friendName,
			lastOnline  = 0,
		}
		if callback then callback(friendInfoCache[friendName]) end
	end)
end

local function formatOnlineStatus(lastOnline)
	if lastOnline == 0 then return "Unknown", C.txt_muted end
	local diff = os.time() - lastOnline
	if diff < 120 then
		return "Online", C.online
	elseif diff < 3600 then
		return "Last seen " .. math.floor(diff/60) .. "m ago", C.txt_muted
	elseif diff < 86400 then
		return "Last seen " .. math.floor(diff/3600) .. "h ago", C.txt_muted
	else
		return "Last seen " .. math.floor(diff/86400) .. "d ago", C.txt_muted
	end
end

local function getDMKey(a, b)
	if a < b then return a.."_"..b else return b.."_"..a end
end

task.spawn(function()
	pcall(httpRequest, {
		Url = FB_USERS.."/"..USERNAME..".json", Method = "PUT",
		Headers = {["Content-Type"]="application/json"},
		Body = HttpService:JSONEncode({
			username    = USERNAME,
			displayName = DISPLAY_NAME,
			lastOnline  = os.time(),
			headshot    = "rbxthumb://type=AvatarHeadShot&id="..tostring(player.UserId).."&w=60&h=60",
		}),
	})
end)

task.spawn(function()
	while gui and gui.Parent do
		task.wait(30)
		pcall(httpRequest, {
			Url = FB_USERS.."/"..USERNAME.."/lastOnline.json", Method = "PUT",
			Headers = {["Content-Type"]="application/json"},
			Body = tostring(os.time()),
		})
	end
end)

-- =============================================
-- FRIENDS SCREEN UI
-- =============================================
local friendsScreen = make("Frame", {
	Size = UDim2.new(1,-colTotalFixed,1,0),
	Position = UDim2.new(0,colTotalFixed,0,0),
	BackgroundColor3 = C.bg_chat,
	BorderSizePixel = 0, ZIndex = 2,
	Visible = false,
}, win)

local fsHead = make("Frame", {
	Size = UDim2.new(1,0,0,48),
	BackgroundColor3 = C.bg_chat,
	BorderSizePixel = 0, ZIndex = 3,
}, friendsScreen)
make("Frame", {
	Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1),
	BackgroundColor3=C.divider, BorderSizePixel=0, ZIndex=4,
}, fsHead)
make("TextLabel", {
	Size=UDim2.new(0,80,1,0), Position=UDim2.new(0,16,0,0),
	BackgroundTransparency=1, Text="Friends",
	Font=FB, TextSize=16, TextColor3=C.txt_white,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4,
}, fsHead)

local tabNames  = {"All","Pending","Add Friend"}
local tabBtns   = {}
local tabLines  = {}
local tabFrames = {}
local activeTab = "All"

local tabRow = make("Frame", {
	Size=UDim2.new(1,-96,1,0), Position=UDim2.new(0,96,0,0),
	BackgroundTransparency=1, ZIndex=4,
}, fsHead)
make("UIListLayout", {
	FillDirection=Enum.FillDirection.Horizontal,
	VerticalAlignment=Enum.VerticalAlignment.Center,
	Padding=UDim.new(0,2),
}, tabRow)

local fsBody = make("Frame", {
	Size=UDim2.new(1,0,1,-48), Position=UDim2.new(0,0,0,48),
	BackgroundTransparency=1, ZIndex=3,
}, friendsScreen)

local function switchTab(name)
	activeTab = name
	for _, n in ipairs(tabNames) do
		if tabBtns[n]  then tabBtns[n].TextColor3  = (n==name) and C.txt_white or C.txt_muted end
		if tabLines[n] then tabLines[n].Visible     = (n==name) end
		if tabFrames[n]then tabFrames[n].Visible    = (n==name) end
	end
end

for _, name in ipairs(tabNames) do
	local tabW = isSmallScreen and 70 or 88
	local btn = make("TextButton", {
		Size=UDim2.new(0,tabW,1,0),
		BackgroundTransparency=1,
		Text=name, Font=FM, TextSize=isSmallScreen and 11 or 13,
		TextColor3=C.txt_muted,
		AutoButtonColor=false, ZIndex=5,
	}, tabRow)
	local ul = make("Frame", {
		Size=UDim2.new(1,0,0,2), Position=UDim2.new(0,0,1,-2),
		BackgroundColor3=C.accent, BorderSizePixel=0, ZIndex=6,
		Visible=false,
	}, btn)
	tabBtns[name]  = btn
	tabLines[name] = ul
	btn.MouseButton1Click:Connect(function() switchTab(name) end)
end

local allScroll = make("ScrollingFrame", {
	Size=UDim2.new(1,0,1,0),
	BackgroundTransparency=1, BorderSizePixel=0,
	ScrollBarThickness=4, ScrollBarImageColor3=C.scrollbar,
	CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
	Visible=true, ZIndex=4,
}, fsBody)
tabFrames["All"] = allScroll
make("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,2)}, allScroll)
pad(8,8,16,16, allScroll)

local pendScroll = make("ScrollingFrame", {
	Size=UDim2.new(1,0,1,0),
	BackgroundTransparency=1, BorderSizePixel=0,
	ScrollBarThickness=4, ScrollBarImageColor3=C.scrollbar,
	CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
	Visible=false, ZIndex=4,
}, fsBody)
tabFrames["Pending"] = pendScroll
make("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,2)}, pendScroll)
pad(8,8,16,16, pendScroll)

local addFrame = make("Frame", {
	Size=UDim2.new(1,0,1,0),
	BackgroundTransparency=1, Visible=false, ZIndex=4,
}, fsBody)
tabFrames["Add Friend"] = addFrame

make("TextLabel", {
	Size=UDim2.new(1,-32,0,24), Position=UDim2.new(0,16,0,24),
	BackgroundTransparency=1, Text="ADD FRIEND",
	Font=FB, TextSize=13, TextColor3=C.txt_white,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
}, addFrame)
make("TextLabel", {
	Size=UDim2.new(1,-32,0,16), Position=UDim2.new(0,16,0,50),
	BackgroundTransparency=1,
	Text="You can add friends with their Roblox username.",
	Font=FR, TextSize=12, TextColor3=C.txt_muted,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
}, addFrame)

local addWrap = make("Frame", {
	Size=UDim2.new(1,-32,0,44), Position=UDim2.new(0,16,0,76),
	BackgroundColor3=C.bg_input, BorderSizePixel=0, ZIndex=5,
}, addFrame)
corner(8, addWrap)

local addInput = make("TextBox", {
	Size=UDim2.new(1,-96,1,0), Position=UDim2.new(0,12,0,0),
	BackgroundTransparency=1, Text="",
	PlaceholderText="Enter a username",
	Font=FR, TextSize=14, TextColor3=C.txt_white,
	PlaceholderColor3=C.txt_muted, ClearTextOnFocus=false, ZIndex=6,
}, addWrap)

local addBtn2 = make("TextButton", {
	Size=UDim2.new(0,72,0,32), Position=UDim2.new(1,-76,0.5,-16),
	BackgroundColor3=C.accent, BorderSizePixel=0,
	Text="Send", Font=FM, TextSize=13,
	TextColor3=C.txt_white, AutoButtonColor=false, ZIndex=6,
}, addWrap)
corner(6, addBtn2)

local addStatus = make("TextLabel", {
	Size=UDim2.new(1,-32,0,20), Position=UDim2.new(0,16,0,128),
	BackgroundTransparency=1, Text="",
	Font=FR, TextSize=12, TextColor3=C.txt_muted,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
}, addFrame)

switchTab("All")

-- =============================================
-- CHANNEL SWITCHING — FIX: proper hide/show logic
-- =============================================
local function getChannelData(dmKey)
	if not channelData[dmKey] then
		local sc = make("ScrollingFrame", {
			Size=UDim2.new(1,0,1,-108), Position=UDim2.new(0,0,0,48),
			BackgroundTransparency=1, BorderSizePixel=0,
			ScrollBarThickness=4, ScrollBarImageColor3=C.scrollbar,
			CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
			Visible=false, ZIndex=3,
		}, colC)
		local lay = make("UIListLayout", {
			SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,0),
		}, sc)
		pad(4,4,16,16, sc)
		lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			task.defer(function()
				sc.CanvasPosition = Vector2.new(0, sc.AbsoluteCanvasSize.Y)
			end)
		end)
		channelData[dmKey] = {
			scroll      = sc,
			seenKeys    = {},
			msgOrder    = 0,
			lastSender  = nil,
			lastTs      = 0,
			lastDateStr = nil,
			dmKey       = dmKey,
		}
	end
	return channelData[dmKey]
end

-- FIX: hide ALL scrolls (global + all private), then show only the target
local function hideAllChannelScrolls()
	msgScroll.Visible = false
	for _, cd in pairs(channelData) do
		cd.scroll.Visible = false
	end
end

local function showFriendsScreen()
	colC.Visible = false
	friendsScreen.Visible = true
	friendsBox.BackgroundColor3 = C.accent
end

local function showChatScreen()
	friendsScreen.Visible = false
	colC.Visible = true
	friendsBox.BackgroundColor3 = C.bg_hover
end

friendsBox.MouseButton1Click:Connect(function()
	if friendsScreen.Visible then showChatScreen() else showFriendsScreen() end
end)

local function switchToChannel(dmKey, friendName)
	currentChannel = dmKey
	hideAllChannelScrolls()
	local cd = getChannelData(dmKey)
	cd.scroll.Visible = true
	banner.Visible = false
	header.Visible = true
	inputArea.Visible = true
	local hint = colC:FindFirstChild("NoChannelHint")
	if hint then hint:Destroy() end
	if chatHeaderNameLabel then chatHeaderNameLabel.Text = friendName end
	inputBox.PlaceholderText = "Message @"..friendName
	-- Unhighlight Roblox entry
	dmEntry.BackgroundTransparency = 1
	dmSelectedBar.Visible = false
	-- Highlight only the active friend entry, hide bar on all others
	for _, slot in pairs(activeDMSlots) do
		local isActive = slot.friendName == friendName
		slot.entry.BackgroundTransparency = isActive and 0.7 or 1
		if slot.selectedBar then slot.selectedBar.Visible = isActive end
	end
	showChatScreen()
end

local function switchToGlobal()
	currentChannel = (USERNAME == GLOBAL_OWNER) and "global" or "none"
	hideAllChannelScrolls()
	-- Unhighlight all friend entries
	for _, slot in pairs(activeDMSlots) do
		slot.entry.BackgroundTransparency = 1
		if slot.selectedBar then slot.selectedBar.Visible = false end
	end
	if USERNAME == GLOBAL_OWNER then
		msgScroll.Visible = true
		banner.Visible = not bannerHidden
		header.Visible = true
		inputArea.Visible = true
		dmEntry.BackgroundTransparency = 0.7
		dmSelectedBar.Visible = true
		if chatHeaderNameLabel then chatHeaderNameLabel.Text = "Roblox" end
		inputBox.PlaceholderText = "Message @Roblox"
	else
		header.Visible = false
		inputArea.Visible = false
		dmEntry.BackgroundTransparency = 1
		dmSelectedBar.Visible = false
	end
	showChatScreen()
end

local homeClickBtn = make("TextButton", {
	Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
	Text="", AutoButtonColor=false, ZIndex=5,
}, homeBox)
homeClickBtn.MouseButton1Click:Connect(switchToGlobal)

-- Click on Roblox DM entry also switches to global
local dmEntryBtn = make("TextButton", {
	Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
	Text="", AutoButtonColor=false, ZIndex=6,
}, dmEntry)
dmEntryBtn.MouseButton1Click:Connect(switchToGlobal)

-- =============================================
-- RENDER PRIVATE DM MESSAGE
-- Full-featured: grouping, date separators, hover, hold menu, emoji
-- =============================================
function renderPrivateMsg(cd, senderName, text, msgTs, isEdited, replyData, isPending)
	msgTs = msgTs or os.time()

	-- Per-channel date separator
	local dateStr = os.date("%B %d, %Y", msgTs)
	if dateStr ~= cd.lastDateStr then
		cd.lastDateStr = dateStr
		cd.lastSender  = nil
		cd.lastTs      = 0
		cd.msgOrder   += 1
		local sep = make("Frame", {
			Name = "DateSep",
			Size = UDim2.new(1,0,0,24),
			BackgroundTransparency = 1,
			LayoutOrder = cd.msgOrder, ZIndex = 3,
		}, cd.scroll)
		make("Frame", {
			Size=UDim2.new(0.5,-40,0,1), Position=UDim2.new(0,0,0.5,0),
			BackgroundColor3=C.divider, BorderSizePixel=0, ZIndex=4,
		}, sep)
		make("TextLabel", {
			Size=UDim2.new(0,80,1,0), Position=UDim2.new(0.5,-40,0,0),
			BackgroundTransparency=1, Text=dateStr,
			Font=FM, TextSize=11, TextColor3=C.txt_muted, ZIndex=4,
		}, sep)
		make("Frame", {
			Size=UDim2.new(0.5,-40,0,1), Position=UDim2.new(0.5,40,0.5,0),
			BackgroundColor3=C.divider, BorderSizePixel=0, ZIndex=4,
		}, sep)
	end

	cd.msgOrder += 1

	local isMe        = senderName == USERNAME
	local avColor     = isMe and C.accent or Color3.fromRGB(100,100,220)
	local avLetter    = string.upper(string.sub(senderName, 1, 1))
	-- FIX: use cached display name instead of raw username
	local cachedInfo  = friendInfoCache[senderName]
	local displayName = isMe and DISPLAY_NAME or (cachedInfo and cachedInfo.displayName or senderName)
	local friendShot  = isMe and MY_HEADSHOT or (cachedInfo and cachedInfo.headshot or getRbxThumb(1))
	local timeStr     = os.date("%I:%M %p", msgTs)

	-- Per-channel grouping state
	cd.lastSender = cd.lastSender or nil
	cd.lastTs     = cd.lastTs     or 0
	local isGrouped = (senderName == cd.lastSender)
		and ((msgTs - cd.lastTs) < GROUP_GAP)
		and not replyData
	cd.lastSender = senderName
	cd.lastTs     = msgTs

	-- Update sidebar preview
	if activeDMSlots[cd.dmKey] then
		local pre = (senderName==USERNAME and "You: " or senderName..": ")..text:sub(1,30)
		activeDMSlots[cd.dmKey].lastMsgLabel.Text = pre
	end

	local row = make("TextButton", {
		Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundTransparency=1,
		LayoutOrder=cd.msgOrder, Text="", AutoButtonColor=false, ZIndex=3,
	}, cd.scroll)

	local hbg = make("Frame", {
		Size=UDim2.new(1,20,1,0), Position=UDim2.new(0,-10,0,0),
		BackgroundTransparency=1, BackgroundColor3=C.bg_hover,
		BorderSizePixel=0, ZIndex=2,
	}, row)
	corner(4, hbg)
	row.MouseEnter:Connect(function()
		TweenService:Create(hbg,TweenInfo.new(0.1),{BackgroundTransparency=0.78}):Play()
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(hbg,TweenInfo.new(0.1),{BackgroundTransparency=1}):Play()
	end)

	local content
	local outerCol = make("Frame", {
		Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundTransparency=1, ZIndex=4,
	}, row)
	make("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,0)}, outerCol)

	-- Reply quote
	if replyData then
		local replyOuter = make("Frame", {
			Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
			LayoutOrder=1, ZIndex=5,
		}, outerCol)
		local vbar = make("Frame", {
			Size=UDim2.new(0,2,1,0), Position=UDim2.new(0,40,0,0),
			BackgroundColor3=C.txt_muted, BorderSizePixel=0, ZIndex=6,
		}, replyOuter)
		corner(4, vbar)
		local replyInner = make("Frame", {
			Size=UDim2.new(1,-52,1,0), Position=UDim2.new(0,48,0,0),
			BackgroundTransparency=1, ZIndex=6,
		}, replyOuter)
		make("UIListLayout", {
			FillDirection=Enum.FillDirection.Horizontal,
			VerticalAlignment=Enum.VerticalAlignment.Center,
			Padding=UDim.new(0,4),
		}, replyInner)
		local rAv = make("Frame", {
			Size=UDim2.new(0,14,0,14), BackgroundTransparency=1,
			BorderSizePixel=0, LayoutOrder=1, ZIndex=7,
		}, replyInner)
		local rAvImg = make("ImageLabel", {
			Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
			Image = (replyData.sender == USERNAME) and MY_HEADSHOT
				or (friendInfoCache[replyData.sender] and friendInfoCache[replyData.sender].headshot or getRbxThumb(1)),
			ZIndex=8,
		}, rAv)
		corner(14, rAvImg)
		make("TextLabel", {
			Size=UDim2.new(0,0,1,0), AutomaticSize=Enum.AutomaticSize.X,
			BackgroundTransparency=1, Text=replyData.sender,
			Font=FM, TextSize=12, TextColor3=C.txt_white,
			TextXAlignment=Enum.TextXAlignment.Left,
			LayoutOrder=2, ZIndex=7,
		}, replyInner)
		make("TextLabel", {
			Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
			Text=replyData.text:gsub(":([%w_]+):",":%1:"),
			Font=FR, TextSize=12, TextColor3=C.txt_muted,
			TextXAlignment=Enum.TextXAlignment.Left,
			TextTruncate=Enum.TextTruncate.AtEnd,
			LayoutOrder=3, ZIndex=7,
		}, replyInner)
	end

	local msgRow = make("Frame", {
		Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundTransparency=1, LayoutOrder=2, ZIndex=5,
	}, outerCol)

	local txtColor = isPending and C.txt_pending or C.txt_white

	if isGrouped then
		pad(2,4,52,0,msgRow)
		local tokens = parseEmoji(text)
		local jumbo  = isEmojiOnly(tokens)
		local wrapper = make("Frame", {
			Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
			BackgroundTransparency=1, ZIndex=6,
		}, msgRow)
		content = buildEmojiContent(wrapper, tokens, jumbo, 6, txtColor)
	else
		make("UIListLayout", {
			FillDirection=Enum.FillDirection.Horizontal,
			VerticalAlignment=Enum.VerticalAlignment.Top,
			Padding=UDim.new(0,12),
		}, msgRow)
		pad(8,4,0,0,msgRow)

		local avHolder = make("Frame", {
			Size=UDim2.new(0,40,0,40), BackgroundTransparency=1,
			LayoutOrder=1, ZIndex=5,
		}, msgRow)
		local avF, avImg, avLbl = makeAv(40, avLetter, avColor, avHolder)
		avF.Size = UDim2.new(1,0,1,0)
		avImg.ZIndex=6; avLbl.ZIndex=6
		applyHeadshot(avImg, avLbl, friendShot)

		local tb = make("Frame", {
			Size=UDim2.new(1,-64,0,0), AutomaticSize=Enum.AutomaticSize.Y,
			BackgroundTransparency=1, LayoutOrder=2, ZIndex=5,
		}, msgRow)
		make("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,2)}, tb)

		local nr = make("Frame", {
			Size=UDim2.new(1,0,0,18), BackgroundTransparency=1,
			LayoutOrder=1, ZIndex=6,
		}, tb)
		make("UIListLayout", {
			FillDirection=Enum.FillDirection.Horizontal,
			VerticalAlignment=Enum.VerticalAlignment.Center,
		}, nr)
		make("TextLabel", {
			Size=UDim2.new(0,0,1,0), AutomaticSize=Enum.AutomaticSize.X,
			BackgroundTransparency=1,
			Text=displayName, Font=FB, TextSize=14, TextColor3=C.txt_white,
			TextXAlignment=Enum.TextXAlignment.Left,
			LayoutOrder=1, ZIndex=7,
		}, nr)
		make("TextLabel", {
			Size=UDim2.new(0,0,1,0), AutomaticSize=Enum.AutomaticSize.X,
			BackgroundTransparency=1,
			Text="  "..timeStr, Font=FR, TextSize=11, TextColor3=C.txt_muted,
			TextXAlignment=Enum.TextXAlignment.Left,
			LayoutOrder=2, ZIndex=7,
		}, nr)

		local tokens = parseEmoji(text)
		local jumbo  = isEmojiOnly(tokens)
		local wrapper = make("Frame", {
			Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
			BackgroundTransparency=1, LayoutOrder=2, ZIndex=6,
		}, tb)
		content = buildEmojiContent(wrapper, tokens, jumbo, 7, txtColor)

		if isEdited then
			make("TextLabel", {
				Name="EditedTag",
				Size=UDim2.new(1,0,0,14), BackgroundTransparency=1,
				Text="(edited)", Font=FR, TextSize=10,
				TextColor3=C.txt_muted,
				TextXAlignment=Enum.TextXAlignment.Left,
				LayoutOrder=3, ZIndex=7,
			}, tb)
		end
	end

	-- Hold menu (same as global channel)
	local msgKey    = cd.currentMsgKey  -- set by pollPrivateDM before calling
	local msgSender = senderName
	local msgText   = text
	local msgTsSnap = msgTs
	attachHoldDetection(row, function()
		return {
			key          = msgKey,
			text         = msgText,
			sender       = msgSender,
			contentLabel = content,
			rowFrame     = row,
			ts           = msgTsSnap,
		}
	end)

	return {content=content, sender=senderName, row=row, isGrouped=isGrouped, rawText=text, msgTs=msgTs}
end

-- =============================================
-- POLL PRIVATE DM
-- =============================================
local function pollPrivateDM(dmKey, friendName)
	local cd = getChannelData(dmKey)
	local ok, res = pcall(httpRequest, {
		Url = FB_DMS.."/"..dmKey.."/messages.json", Method="GET",
	})
	if not ok or not res or res.StatusCode ~= 200 or res.Body == "null" then return end
	local ok2, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
	if not ok2 or type(data) ~= "table" then return end

	local msgs = {}
	for key, val in pairs(data) do
		if type(val)=="table" and val.sender and val.text and val.ts then
			table.insert(msgs, {key=key, sender=val.sender, text=val.text, ts=val.ts})
		end
	end
	table.sort(msgs, function(a,b) return a.ts < b.ts end)

	for _, msg in ipairs(msgs) do
		if not cd.seenKeys[msg.key] then
			cd.seenKeys[msg.key] = true
			cd.currentMsgKey = msg.key
			renderPrivateMsg(cd, msg.sender, msg.text, msg.ts, msg.edited == true, msg.replyData)

			-- FIX: only notify for messages that arrived AFTER the script loaded,
			-- not for historical messages being loaded on first poll
			if msg.sender ~= USERNAME and not gui.Enabled and msg.ts > SESSION_START then
				pcall(function()
					local uid = Players:GetUserIdFromNameAsync(msg.sender)
					game:GetService("StarterGui"):SetCore("SendNotification", {
						Title    = msg.sender,
						Text     = msg.text:sub(1,50),
						Icon     = "rbxthumb://type=AvatarHeadShot&id="..tostring(uid).."&w=60&h=60",
						Duration = 5,
					})
				end)
				if sendSound and SEND_SOUND_ASSET then sendSound:Play() end
			end
		end
	end
end

-- =============================================
-- FRIEND REQUEST FUNCTIONS
-- =============================================
local function sendFriendRequest(toUser)
	local ok, res = pcall(httpRequest, {
		Url=FB_USERS.."/"..toUser..".json", Method="GET",
	})
	if not ok or not res or res.StatusCode~=200 or res.Body=="null" then
		return false, "User hasn't used DiscordBlox"
	end
	local dmKey = getDMKey(USERNAME, toUser)
	local ok2, res2 = pcall(httpRequest, {Url=FB_FRIENDS.."/"..dmKey..".json", Method="GET"})
	if ok2 and res2 and res2.Body~="null" then return false, "Already friends" end

	local ok3, res3 = pcall(httpRequest, {
		Url=FB_REQUESTS.."/"..toUser.."/"..USERNAME..".json", Method="PUT",
		Headers={["Content-Type"]="application/json"},
		Body=HttpService:JSONEncode({from=USERNAME, ts=os.time()}),
	})
	return (ok3 and res3 and (res3.StatusCode==200 or res3.StatusCode==201)), "Friend request sent!"
end

local function acceptFriendRequest(fromUser)
	local dmKey = getDMKey(USERNAME, fromUser)
	-- FIX: store both full usernames explicitly so we never have to parse the key
	pcall(httpRequest, {
		Url=FB_FRIENDS.."/"..dmKey..".json", Method="PUT",
		Headers={["Content-Type"]="application/json"},
		Body=HttpService:JSONEncode({user1=USERNAME, user2=fromUser, since=os.time()}),
	})
	pcall(httpRequest, {Url=FB_REQUESTS.."/"..USERNAME.."/"..fromUser..".json", Method="DELETE"})
end

local function declineFriendRequest(fromUser)
	pcall(httpRequest, {Url=FB_REQUESTS.."/"..USERNAME.."/"..fromUser..".json", Method="DELETE"})
end

-- =============================================
-- ADD FRIEND ENTRY TO SIDEBAR + ALL TAB
-- =============================================
local function addFriendEntry(friendName)
	local dmKey = getDMKey(USERNAME, friendName)
	if activeDMSlots[dmKey] then return end

	local sEntry = make("TextButton", {
		Size=UDim2.new(1,0,0,44),
		BackgroundTransparency=1, BackgroundColor3=C.bg_hover,
		BorderSizePixel=0, ZIndex=4,
		Text="", AutoButtonColor=false,
		LayoutOrder = 100 + #activeDMSlots,
	}, dmArea)
	corner(4, sEntry)

	-- Selected bar (same as Roblox dmEntry bar), hidden until this DM is active
	local sSelectedBar = make("Frame", {
		Name = "SelectedBar",
		Size = UDim2.new(0,3,0,24),
		Position = UDim2.new(0,-3,0.5,-12),
		BackgroundColor3 = C.txt_white,
		BorderSizePixel = 0, ZIndex = 5,
		Visible = false,
	}, sEntry)

	local sAvH = make("Frame", {
		Size=UDim2.new(0,34,0,34), Position=UDim2.new(0,8,0.5,-17),
		BackgroundTransparency=1, ZIndex=5,
	}, sEntry)
	local sAvF, sAvImg, sAvLbl = makeAv(34, string.upper(string.sub(friendName,1,1)), C.accent, sAvH)
	sAvF.Size = UDim2.new(1,0,1,0); sAvImg.ZIndex=6; sAvLbl.ZIndex=6

	local sDot = make("Frame", {
		Size=UDim2.new(0,10,0,10), Position=UDim2.new(1,-8,1,-8),
		BackgroundColor3=C.txt_muted, BorderSizePixel=0, ZIndex=7,
	}, sAvH)
	corner(10,sDot); make("UIStroke",{Color=C.bg_dark,Thickness=2.5},sDot)

	local sNameLabel = make("TextLabel", {
		Size=UDim2.new(1,-52,0,16), Position=UDim2.new(0,50,0,7),
		BackgroundTransparency=1, Text=friendName,
		Font=FM, TextSize=14, TextColor3=C.txt_white,
		TextXAlignment=Enum.TextXAlignment.Left,
		TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=5,
	}, sEntry)

	local sLast = make("TextLabel", {
		Size=UDim2.new(1,-52,0,12), Position=UDim2.new(0,50,0,24),
		BackgroundTransparency=1, Text="...",
		Font=FR, TextSize=10, TextColor3=C.txt_muted,
		TextXAlignment=Enum.TextXAlignment.Left,
		TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=5,
	}, sEntry)

	-- FIX: fetch real headshot, display name, and actual online status
	fetchFriendInfo(friendName, function(info)
		applyHeadshot(sAvImg, sAvLbl, info.headshot)
		sNameLabel.Text = info.displayName
		local statusText, statusColor = formatOnlineStatus(info.lastOnline)
		sDot.BackgroundColor3 = (info.lastOnline > 0 and (os.time() - info.lastOnline < 120)) and C.online or C.txt_muted
		if sLast.Text == "..." then
			sLast.Text = statusText
			sLast.TextColor3 = statusColor
		end
	end)

	sEntry.MouseButton1Click:Connect(function()
		for _, slot in pairs(activeDMSlots) do
			slot.entry.BackgroundTransparency = 1
		end
		sEntry.BackgroundTransparency = 0.7
		switchToChannel(dmKey, friendName)
	end)
	sEntry.MouseEnter:Connect(function()
		if currentChannel ~= dmKey then
			TweenService:Create(sEntry,TweenInfo.new(0.1),{BackgroundTransparency=0.5}):Play()
		end
	end)
	sEntry.MouseLeave:Connect(function()
		if currentChannel ~= dmKey then
			TweenService:Create(sEntry,TweenInfo.new(0.1),{BackgroundTransparency=1}):Play()
		end
	end)

	activeDMSlots[dmKey] = {entry=sEntry, selectedBar=sSelectedBar, lastMsgLabel=sLast, friendName=friendName}

	-- ALL tab entry
	local allEntry = make("Frame", {
		Size=UDim2.new(1,0,0,52),
		BackgroundColor3=C.bg_hover, BackgroundTransparency=0.8,
		BorderSizePixel=0, ZIndex=5,
	}, allScroll)
	corner(4,allEntry)

	local allNameLabel = make("TextLabel", {
		Size=UDim2.new(1,-88,0,20), Position=UDim2.new(0,16,0,10),
		BackgroundTransparency=1, Text=friendName,
		Font=FM, TextSize=14, TextColor3=C.txt_white,
		TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
	}, allEntry)
	local allStatusLabel = make("TextLabel", {
		Size=UDim2.new(1,-88,0,14), Position=UDim2.new(0,16,0,30),
		BackgroundTransparency=1, Text="...",
		Font=FR, TextSize=11, TextColor3=C.txt_muted,
		TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
	}, allEntry)

	-- FIX: real display name + status in All tab
	fetchFriendInfo(friendName, function(info)
		allNameLabel.Text = info.displayName
		local statusText, statusColor = formatOnlineStatus(info.lastOnline)
		allStatusLabel.Text = statusText
		allStatusLabel.TextColor3 = statusColor
	end)

	local msgBtn = make("TextButton", {
		Size=UDim2.new(0,72,0,28), Position=UDim2.new(1,-80,0.5,-14),
		BackgroundColor3=C.accent, BorderSizePixel=0,
		Text="Message", Font=FM, TextSize=11,
		TextColor3=C.txt_white, AutoButtonColor=false, ZIndex=6,
	}, allEntry)
	corner(6,msgBtn)
	msgBtn.MouseButton1Click:Connect(function() switchToChannel(dmKey, friendName) end)
end

-- =============================================
-- PENDING REQUEST ENTRY
-- =============================================
local pendingBadgeCount = 0

local function addPendingEntry(fromUser)
	if knownPending[fromUser] then return end
	knownPending[fromUser] = true
	pendingBadgeCount += 1
	friendBadge.Visible = true
	friendBadgeLabel.Text = tostring(pendingBadgeCount)

	local pEntry = make("Frame", {
		Size=UDim2.new(1,0,0,52),
		BackgroundColor3=C.bg_hover, BackgroundTransparency=0.8,
		BorderSizePixel=0, ZIndex=5,
	}, pendScroll)
	corner(4,pEntry)
	make("TextLabel", {
		Size=UDim2.new(1,-148,0,18), Position=UDim2.new(0,16,0,8),
		BackgroundTransparency=1, Text=fromUser,
		Font=FM, TextSize=14, TextColor3=C.txt_white,
		TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
	}, pEntry)
	make("TextLabel", {
		Size=UDim2.new(1,-148,0,14), Position=UDim2.new(0,16,0,28),
		BackgroundTransparency=1, Text="Incoming friend request",
		Font=FR, TextSize=11, TextColor3=C.txt_muted,
		TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
	}, pEntry)

	local accBtn = make("TextButton", {
		Size=UDim2.new(0,60,0,28), Position=UDim2.new(1,-136,0.5,-14),
		BackgroundColor3=Color3.fromRGB(35,165,89), BorderSizePixel=0,
		Text="Accept", Font=FM, TextSize=11,
		TextColor3=C.txt_white, AutoButtonColor=false, ZIndex=6,
	}, pEntry)
	corner(6,accBtn)
	local decBtn = make("TextButton", {
		Size=UDim2.new(0,60,0,28), Position=UDim2.new(1,-68,0.5,-14),
		BackgroundColor3=Color3.fromRGB(237,66,69), BorderSizePixel=0,
		Text="Decline", Font=FM, TextSize=11,
		TextColor3=C.txt_white, AutoButtonColor=false, ZIndex=6,
	}, pEntry)
	corner(6,decBtn)

	accBtn.MouseButton1Click:Connect(function()
		task.spawn(function()
			acceptFriendRequest(fromUser)
			pEntry:Destroy()
			knownPending[fromUser] = nil
			pendingBadgeCount = math.max(0, pendingBadgeCount-1)
			friendBadge.Visible = pendingBadgeCount > 0
			friendBadgeLabel.Text = tostring(pendingBadgeCount)
			addFriendEntry(fromUser)
		end)
	end)
	decBtn.MouseButton1Click:Connect(function()
		task.spawn(function()
			declineFriendRequest(fromUser)
			pEntry:Destroy()
			knownPending[fromUser] = nil
			pendingBadgeCount = math.max(0, pendingBadgeCount-1)
			friendBadge.Visible = pendingBadgeCount > 0
			friendBadgeLabel.Text = tostring(pendingBadgeCount)
		end)
	end)
end

addBtn2.MouseButton1Click:Connect(function()
	local target = addInput.Text:match("^%s*(.-)%s*$")
	if target=="" or target==USERNAME then
		addStatus.Text = target=="" and "Enter a username." or "You can't add yourself."
		addStatus.TextColor3 = Color3.fromRGB(237,66,69); return
	end
	addStatus.Text="Sending..."; addStatus.TextColor3=C.txt_muted
	task.spawn(function()
		local ok, msg = sendFriendRequest(target)
		addStatus.Text = msg
		addStatus.TextColor3 = ok and Color3.fromRGB(35,165,89) or Color3.fromRGB(237,66,69)
		if ok then addInput.Text="" end
	end)
end)

-- =============================================
-- POLL FRIENDS + REQUESTS
-- =============================================
-- isInitialLoad: true on first call — fetches one DM at a time with yields to avoid lag spike
local initialLoadDone = false

local function pollFriendsSystem(isInitialLoad)
	-- Pending friend requests (always fast, just UI entries)
	local ok, res = pcall(httpRequest, {Url=FB_REQUESTS.."/"..USERNAME..".json", Method="GET"})
	if ok and res and res.StatusCode==200 and res.Body~="null" then
		local ok2, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
		if ok2 and type(data)=="table" then
			for fromUser, _ in pairs(data) do addPendingEntry(fromUser) end
		end
	end

	local ok2, res2 = pcall(httpRequest, {Url=FB_FRIENDS..".json", Method="GET"})
	if not (ok2 and res2 and res2.StatusCode==200 and res2.Body~="null") then return end
	local ok3, data = pcall(HttpService.JSONDecode, HttpService, res2.Body)
	if not (ok3 and type(data)=="table") then return end

	-- Collect all friend channels this user is part of
	local myChannels = {}
	for dmKey, val in pairs(data) do
		local friendName = nil
		if type(val) == "table" then
			if val.user1 == USERNAME then friendName = val.user2
			elseif val.user2 == USERNAME then friendName = val.user1 end
		end
		-- Fallback for old records
		if not friendName and dmKey:find(USERNAME, 1, true) then
			local withoutMe = dmKey:gsub(USERNAME, ""):gsub("^_", ""):gsub("_$", "")
			if withoutMe ~= "" then friendName = withoutMe end
		end
		if friendName then
			table.insert(myChannels, {dmKey=dmKey, friendName=friendName})
		end
	end

	if isInitialLoad then
		-- STAGGERED: add sidebar entries first so UI appears quickly, then
		-- load each DM's message history one at a time with a yield between them
		for _, ch in ipairs(myChannels) do
			if not knownFriends[ch.dmKey] then
				knownFriends[ch.dmKey] = true
				addFriendEntry(ch.friendName)
			end
		end
		-- Now load message history one channel at a time
		for i, ch in ipairs(myChannels) do
			pollPrivateDM(ch.dmKey, ch.friendName)
			-- Yield after each channel so Roblox can render before the next batch
			task.wait(0.05)
		end
		initialLoadDone = true
	else
		-- REGULAR POLL: fast, all channels, only new messages matter
		for _, ch in ipairs(myChannels) do
			if not knownFriends[ch.dmKey] then
				knownFriends[ch.dmKey] = true
				addFriendEntry(ch.friendName)
			end
			pollPrivateDM(ch.dmKey, ch.friendName)
		end
	end
end

-- =============================================
-- LAUNCH UNREAD NOTIFICATIONS
-- =============================================
task.spawn(function()
	local lastSeenTs = 0
	local confirmedFirstRun = false  -- true only if Firebase explicitly returned null (key never written)

	local ok, res = pcall(httpRequest, {Url=FB_LASTSEEN.."/"..USERNAME..".json", Method="GET"})
	if ok and res and res.StatusCode==200 then
		if res.Body == "null" then
			-- Key genuinely doesn't exist — this is a first run
			confirmedFirstRun = true
		else
			local ok2, v = pcall(HttpService.JSONDecode, HttpService, res.Body)
			if ok2 then
				if type(v)=="number" then
					lastSeenTs = v
				elseif type(v)=="string" then
					lastSeenTs = tonumber(v) or 0
				end
			end
		end
	end
	-- If request failed entirely, lastSeenTs stays 0 but confirmedFirstRun stays false
	-- so we still attempt the scan (worst case we show 0 notifications if ts comparison fails)

	-- Only skip on a confirmed first run to avoid spamming all history
	if confirmedFirstRun then
		pcall(httpRequest, {
			Url=FB_LASTSEEN.."/"..USERNAME..".json", Method="PUT",
			Headers={["Content-Type"]="application/json"},
			Body=tostring(os.time()),
		})
		return
	end

	-- If lastSeenTs is still 0 here (bad read/parse), use a large window so we don't
	-- flood the user — only show messages from the last 24 hours as "unread"
	local effectiveTs = lastSeenTs > 0 and lastSeenTs or (os.time() - 86400)

	local unread = {}  -- sender -> count, across global + all private DMs

	-- Global channel (owner only)
	if USERNAME == GLOBAL_OWNER then
		local ok2, res2 = pcall(httpRequest, {Url=FIREBASE_URL..".json", Method="GET"})
		if ok2 and res2 and res2.StatusCode==200 and res2.Body~="null" then
			local ok3, data = pcall(HttpService.JSONDecode, HttpService, res2.Body)
			if ok3 and type(data)=="table" then
				for _, val in pairs(data) do
					if type(val)=="table" and val.ts and val.ts > effectiveTs and val.sender ~= USERNAME then
						unread[val.sender] = (unread[val.sender] or 0) + 1
					end
				end
			end
		end
	end

	-- Private DMs: scan all friend channels this user is part of
	local ok4, res4 = pcall(httpRequest, {Url=FB_FRIENDS..".json", Method="GET"})
	if ok4 and res4 and res4.StatusCode==200 and res4.Body~="null" then
		local ok5, friends = pcall(HttpService.JSONDecode, HttpService, res4.Body)
		if ok5 and type(friends)=="table" then
			for dmKey, val in pairs(friends) do
				if type(val)=="table" and (val.user1==USERNAME or val.user2==USERNAME) then
					local ok6, res6 = pcall(httpRequest, {
						Url=FB_DMS.."/"..dmKey.."/messages.json", Method="GET",
					})
					if ok6 and res6 and res6.StatusCode==200 and res6.Body~="null" then
						local ok7, msgs = pcall(HttpService.JSONDecode, HttpService, res6.Body)
						if ok7 and type(msgs)=="table" then
							for _, msg in pairs(msgs) do
								if type(msg)=="table" and msg.ts and msg.ts > effectiveTs and msg.sender ~= USERNAME then
									unread[msg.sender] = (unread[msg.sender] or 0) + 1
								end
							end
						end
					end
				end
			end
		end
	end

	-- One smooth notification per sender, staggered 1.5s apart
	for sender, count in pairs(unread) do
		local uid = 1
		pcall(function() uid = Players:GetUserIdFromNameAsync(sender) end)
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title    = sender,
				Text     = tostring(count) .. " new message" .. (count > 1 and "s" or ""),
				Icon     = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(uid) .. "&w=60&h=60",
				Duration = 5,
			})
		end)
		if sendSound and SEND_SOUND_ASSET then sendSound:Play() end
		task.wait(1.5)
	end

	pcall(httpRequest, {
		Url=FB_LASTSEEN.."/"..USERNAME..".json", Method="PUT",
		Headers={["Content-Type"]="application/json"},
		Body=tostring(os.time()),
	})
end)

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then
		pcall(httpRequest, {
			Url=FB_LASTSEEN.."/"..USERNAME..".json", Method="PUT",
			Headers={["Content-Type"]="application/json"},
			Body=tostring(os.time()),
		})
	end
end)

-- =============================================
-- POLL LOOP
-- =============================================
local function fullPoll(isInitialLoad)
	firebasePoll()
	pollFriendsSystem(isInitialLoad)
end

task.spawn(function()
	task.wait(0.3)

	-- FIX: non-owners start on "none" — hide header and input bar, show hint
	if USERNAME ~= GLOBAL_OWNER then
		msgScroll.Visible = false
		banner.Visible = false
		header.Visible = false
		inputArea.Visible = false
		make("TextLabel", {
			Name = "NoChannelHint",
			Size = UDim2.new(1,0,0,40),
			Position = UDim2.new(0,0,0.5,-20),
			BackgroundTransparency = 1,
			Text = "Select a friend to start chatting",
			Font = FM, TextSize = 14,
			TextColor3 = C.txt_muted,
			ZIndex = 3,
		}, colC)
	end

	local ok, err = pcall(fullPoll, true)  -- initial load: staggered per-channel
	if not ok then
		warn("[DiscordBlox] Initial poll failed: " .. tostring(err))
	end

	task.defer(function()
		if USERNAME == GLOBAL_OWNER then
			msgScroll.CanvasPosition = Vector2.new(0, msgScroll.AbsoluteCanvasSize.Y)
		end
	end)

	buttonFrame.Visible = true
	print("[DiscordBlox] Loaded successfully")

	-- Refresh friend online status every 60s so dots stay accurate
	task.spawn(function()
		while gui and gui.Parent do
			task.wait(60)
			for friendName, _ in pairs(friendInfoCache) do
				task.spawn(function()
					local ok, res = pcall(httpRequest, {Url=FB_USERS.."/"..friendName..".json", Method="GET"})
					if ok and res and res.StatusCode==200 and res.Body~="null" then
						local ok2, d = pcall(HttpService.JSONDecode, HttpService, res.Body)
						if ok2 and d then
							friendInfoCache[friendName].lastOnline  = d.lastOnline  or friendInfoCache[friendName].lastOnline
							friendInfoCache[friendName].displayName = d.displayName or friendInfoCache[friendName].displayName
							-- Update sidebar dot and status text
							for dmKey, slot in pairs(activeDMSlots) do
								if slot.friendName == friendName then
									local statusText, statusColor = formatOnlineStatus(friendInfoCache[friendName].lastOnline)
									local isOnline = friendInfoCache[friendName].lastOnline > 0
										and (os.time() - friendInfoCache[friendName].lastOnline < 120)
									-- Find the online dot inside the entry
									local avH = slot.entry:FindFirstChildWhichIsA("Frame")
									if avH then
										local dot = avH:FindFirstChild("Frame") -- the sDot
										-- Walk children to find the dot (UIStroke child = dot)
										for _, c in ipairs(avH:GetChildren()) do
											if c:IsA("Frame") and c:FindFirstChildWhichIsA("UIStroke") then
												c.BackgroundColor3 = isOnline and C.online or C.txt_muted
											end
										end
									end
									-- Only update last msg label if it still shows a status string (no messages yet)
									if slot.lastMsgLabel.Text == statusText or
										slot.lastMsgLabel.Text == "..." or
										slot.lastMsgLabel.Text:find("Last seen") or
										slot.lastMsgLabel.Text == "Online" or
										slot.lastMsgLabel.Text == "Unknown" then
										slot.lastMsgLabel.Text = statusText
										slot.lastMsgLabel.TextColor3 = statusColor
									end
								end
							end
						end
					end
				end)
			end
		end
	end)

	while gui and gui.Parent do
		task.wait(POLL_INTERVAL)
		if gui and gui.Parent then
			pcall(fullPoll, false)  -- regular poll: fast, no stagger
		end
	end
end)

print("[DiscordDM] Loaded | Username:", USERNAME)
