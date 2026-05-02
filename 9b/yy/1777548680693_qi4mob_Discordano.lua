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

-- =============================================
-- TOPBAR BUTTON (hooks into Roblox CoreGui sausage bar)
-- Multiple scripts coexist: each one expands the bar by SLOT_SIZE
-- and positions its button at the new right edge.
-- =============================================
local CoreGui    = game:GetService("CoreGui")
local SLOT_SIZE  = 36
local ICON_URL   = "https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/yt/66/1777101057537_f1uc8n_5968756.png"

local topBarApp     = CoreGui:WaitForChild("TopBarApp"):WaitForChild("TopBarApp")
local sausageHolder = topBarApp:WaitForChild("UnibarLeftFrame"):WaitForChild("UnibarMenu"):WaitForChild("2")

-- Each new script expands from whatever the CURRENT width is, not original
local currentWidth  = sausageHolder.Size.X.Offset
local expandedSize  = UDim2.new(0, currentWidth + SLOT_SIZE, 0, sausageHolder.Size.Y.Offset)

-- Button container frame at the right edge
local buttonFrame = Instance.new("Frame")
buttonFrame.Name             = "DiscordBloxButtonFrame"
buttonFrame.Size             = UDim2.new(0, SLOT_SIZE, 1, 0)
buttonFrame.Position         = UDim2.new(0, currentWidth, 0, 0)
buttonFrame.BackgroundTransparency = 1
buttonFrame.Visible          = false  -- hidden until confirmed loaded
buttonFrame.Parent           = sausageHolder

-- Download topbar icon via file system (handled in async download block below)
local TOPBAR_ICON_ASSET = nil

local TopbarButton = Instance.new("ImageButton")
TopbarButton.Name              = "DiscordBloxButton"
TopbarButton.Size              = UDim2.new(0, 32, 0, 32)
TopbarButton.AnchorPoint       = Vector2.new(0.5, 0.5)
TopbarButton.Position          = UDim2.new(0.5, -6, 0.5, 0)
TopbarButton.BackgroundTransparency = 1
TopbarButton.Image             = ""  -- filled by download above
TopbarButton.ScaleType         = Enum.ScaleType.Fit
TopbarButton.Parent            = buttonFrame

-- Hover effect
local function ApplyHoverEffect(button, normalSize, hoverSize)
	local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, info, {Size = hoverSize}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, info, {Size = normalSize}):Play()
	end)
end
ApplyHoverEffect(TopbarButton, UDim2.new(0,32,0,32), UDim2.new(0,36,0,36))

-- Persist expanded size so Roblox doesn't shrink it back
local sizeConn
sizeConn = sausageHolder:GetPropertyChangedSignal("Size"):Connect(function()
	if sausageHolder.Parent then
		sausageHolder.Size = expandedSize
		buttonFrame.Position = UDim2.new(0, sausageHolder.Size.X.Offset - SLOT_SIZE, 0, 0)
	else
		sizeConn:Disconnect()
	end
end)
sausageHolder.Size = expandedSize

-- Toggle GUI on click (gui defined later, use a reference table)
local guiRef = {}
TopbarButton.MouseButton1Click:Connect(function()
	local g = guiRef.gui
	if g and g.Parent then
		g.Enabled = not g.Enabled
	end
end)

-- =============================================
-- HTTP (multi-executor) - defined first, needed by downloads
-- =============================================
local function httpRequest(opts)
	if syn and syn.request       then return syn.request(opts)
	elseif request               then return request(opts)
	elseif http and http.request then return http.request(opts)
	elseif http_request          then return http_request(opts)
	else error("No HTTP function found") end
end

-- =============================================
-- FILE SYSTEM ALIASES (normalize across executors)
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
local FOLDER_EMOJIS  = FOLDER_ROOT .. "/Emojis"

-- Custom emoji definitions: name -> {url, asset (nil until downloaded)}
local CUSTOM_EMOJIS = {
	ayes     = {url="https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/uh/sm/1777545766347_wb0b6z_ayes_1484424415327551629.png",    asset=nil},
	easy     = {url="https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/0i/f9/1777545769739_hblqyc_easy_1484424459032072232.png",    asset=nil},
	normal   = {url="https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/ur/ee/1777545774188_smnfkx_normal_1477582118434639995.png",  asset=nil},
	aok      = {url="https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/pm/l1/1777545777009_hndk2t_aok_1494283694834192504.png",     asset=nil},
	hard     = {url="https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/0f/qw/1777545780269_jtz6kt_hard_1484425388380651521.png",    asset=nil},
	ano      = {url="https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/q9/q7/1777545785246_dknn0f_ano_1494152321632964648.png",     asset=nil},
	harder   = {url="https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/q9/lm/1777545787497_1hju7e_harder_1488490934151806987.png",  asset=nil},
	insane   = {url="https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/hz/8q/1777545789235_tzclp9_insane_1488491290877493339.png",  asset=nil},
	extremedemon = {url="https://raw.githubusercontent.com/ey2wxy29/m3x9a2k1/main/2e/ij/1777545814486_fop085_extremedemon_1488491016976601119.png", asset=nil},
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
ensureFolder(FOLDER_EMOJIS)

local function downloadAsset(url, path, label)
	if not _getcustomasset then
		warn("[DiscordBlox] getcustomasset not supported — skipping " .. label)
		return nil
	end
	-- If already cached, just return the asset
	if _isfile(path) then
		local ok, asset = pcall(_getcustomasset, path)
		if ok and asset then
			print("[DiscordBlox] " .. label .. " already cached: " .. path)
			return asset
		end
	end
	-- Use game:HttpGetAsync for binary-safe download (correct for images/audio)
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

-- Pre-declare asset variables so UI can reference them (nil until downloaded)
local SEND_ICON_ASSET  = nil
local ICON_REPLY       = nil
local ICON_EDIT        = nil
local ICON_DELETE      = nil
local COPY_ICON        = nil
local SEND_SOUND_ASSET = nil

-- Sound instance created now, SoundId set after download
local sendSound = Instance.new("Sound")
sendSound.Volume = 0.5
sendSound.RollOffMaxDistance = 0
sendSound.Parent = game:GetService("SoundService")

-- Download all assets async so no lag spike on inject
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
			-- Apply to send button if already built
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

	-- Download custom emojis
	for name, data in pairs(CUSTOM_EMOJIS) do
		local n, d = name, data
		task.spawn(function()
			local asset = downloadAsset(d.url, FOLDER_EMOJIS .. "/" .. n .. ".png", "Emoji:" .. n)
			if asset then d.asset = asset end
		end)
	end
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

-- =============================================
-- FETCH AVATAR HEADSHOT
-- rbxthumb:// works natively in Roblox ImageLabels
-- no HTTP request needed at all
-- =============================================
local function getRbxThumb(userId)
	return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=60&h=60"
end

local MY_HEADSHOT     = getRbxThumb(player.UserId)
local ROBLOX_HEADSHOT = getRbxThumb(1)

local function waitForHeadshot(getter, timeout)
	return getter()  -- always available instantly with rbxthumb
end

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

-- Avatar: circle frame with letter fallback + image layer
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

-- Apply headshots immediately since rbxthumb is instant
local function applyAllHeadshots(img, lbl, isMe)
	applyHeadshot(img, lbl, isMe and MY_HEADSHOT or ROBLOX_HEADSHOT)
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
	Enabled = false,  -- hidden until topbar button clicked
}, playerGui)

guiRef.gui = gui

-- OUTER WRAPPER: clips to rounded shape
-- winClip handles the corner+clip, win is square inside it
local winClip = make("Frame", {
	Size             = UDim2.new(0.80, 0, 0.76, 0),
	Position         = UDim2.new(0.10, 0, 0.12, 0),
	BackgroundColor3 = C.bg_chat,
	BorderSizePixel  = 0,
	ClipsDescendants = true,
}, gui)
corner(12, winClip)

local win = make("Frame", {
	Size             = UDim2.new(1, 0, 1, 0),
	Position         = UDim2.new(0, 0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel  = 0,
	ClipsDescendants = false,
}, winClip)

-- =============================================
-- LAYOUT: three vertical columns inside win
-- Col A: server icons  72px
-- Col B: sidebar      240px
-- Col C: chat area    rest
-- All columns are 100% height, no corner radius needed individually
-- =============================================

-- COL A: Server icons
local colA = make("Frame", {
	Size             = UDim2.new(0, 72, 1, 0),
	Position         = UDim2.new(0, 0, 0, 0),
	BackgroundColor3 = C.bg_darkest,
	BorderSizePixel  = 0,
	ZIndex           = 2,
}, win)

-- Home button
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

-- Thin divider line
make("Frame", {
	Size = UDim2.new(0,32,0,1),
	Position = UDim2.new(0.5,-16,0,72),
	BackgroundColor3 = C.bg_hover,
	BorderSizePixel = 0, ZIndex = 3,
}, colA)

-- Right border of colA
make("Frame", {
	Size = UDim2.new(0,1,1,0), Position = UDim2.new(1,-1,0,0),
	BackgroundColor3 = C.divider, BorderSizePixel = 0, ZIndex = 3,
}, colA)

-- COL B: Sidebar
local colB = make("Frame", {
	Size = UDim2.new(0,240,1,0),
	Position = UDim2.new(0,72,0,0),
	BackgroundColor3 = C.bg_dark,
	BorderSizePixel = 0, ZIndex = 2,
}, win)

-- Sidebar header
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

-- DM list area (leave 52px at bottom for profile bar)
local dmArea = make("Frame", {
	Size = UDim2.new(1,0,1,-172),
	Position = UDim2.new(0,0,0,48),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 3,
}, colB)
pad(4,4,8,8, dmArea)

-- ROBLOX DM ENTRY
local dmEntry = make("Frame", {
	Size = UDim2.new(1,0,0,44),
	BackgroundColor3 = C.bg_hover,
	BorderSizePixel = 0, ZIndex = 4,
}, dmArea)
corner(4, dmEntry)

-- Selected bar
make("Frame", {
	Size = UDim2.new(0,3,0,24),
	Position = UDim2.new(0,-3,0.5,-12),
	BackgroundColor3 = C.txt_white,
	BorderSizePixel = 0, ZIndex = 5,
}, dmEntry)

-- Avatar holder (34px) inside dmEntry
local dmAvHolder = make("Frame", {
	Size = UDim2.new(0,34,0,34),
	Position = UDim2.new(0,8,0.5,-17),
	BackgroundTransparency = 1, ZIndex = 5,
}, dmEntry)

local dmAvF, dmAvImg, dmAvLbl = makeAv(34,"R",C.roblox_red, dmAvHolder)
dmAvF.Size = UDim2.new(1,0,1,0)
dmAvImg.ZIndex = 6; dmAvLbl.ZIndex = 6

-- Online dot: parented to dmAvHolder, sticks to bottom-right of avatar
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
-- PROFILE BAR (bottom of sidebar, like Discord)
-- =============================================
-- Get game info
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

-- Download game thumbnail async - result stored for when gameThumbImg exists
local gameThumbAsset = nil
local gameThumbRef   = {}  -- table reference so closure always sees the current ImageLabel

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

	if not universeId then
		warn("[DiscordBlox] Could not get universe ID for place " .. tostring(game.PlaceId))
		return
	end

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

	if not imageUrl then
		warn("[DiscordBlox] Could not get thumbnail CDN URL")
		return
	end

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
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	else
		return string.format("%ds", s)
	end
end

-- ACTIVITY BAR (above profile bar)
local activityBar = make("Frame", {
	Size = UDim2.new(1,0,0,62),
	Position = UDim2.new(0,0,1,-124),
	BackgroundColor3 = Color3.fromRGB(32, 33, 37),
	BorderSizePixel = 0, ZIndex = 4,
}, colB)

-- Top divider (full width)
make("Frame", {
	Size = UDim2.new(1,0,0,1),
	BackgroundColor3 = C.divider,
	BorderSizePixel = 0, ZIndex = 5,
}, activityBar)

-- Divider between activity bar and profile bar (padded, doesn't touch edges)
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

-- Apply if already downloaded
if gameThumbAsset then gameThumbImg.Image = gameThumbAsset end

-- Game title
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

-- Session timer label
local sessionLabel = make("TextLabel", {
	Size = UDim2.new(1,-60,0,13),
	Position = UDim2.new(0,56,0,28),
	BackgroundTransparency = 1,
	Text = "Playing for " .. formatPlaytime(),
	Font = FR, TextSize = 10,
	TextColor3 = Color3.fromRGB(35, 165, 89),  -- Discord green
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
}, activityBar)

-- Update timer every second
task.spawn(function()
	while gui and gui.Parent do
		task.wait(1)
		if sessionLabel and sessionLabel.Parent then
			sessionLabel.Text = "Playing for " .. formatPlaytime()
			sessionLabel.TextColor3 = Color3.fromRGB(35, 165, 89)
		end
	end
end)

-- PROFILE BAR
local profileBar = make("Frame", {
	Size = UDim2.new(1,0,0,62),
	Position = UDim2.new(0,0,1,-62),
	BackgroundColor3 = C.bg_profile,
	BorderSizePixel = 0, ZIndex = 4,
}, colB)

-- Avatar in profile bar
local pbAvHolder = make("Frame", {
	Size = UDim2.new(0,32,0,32),
	Position = UDim2.new(0,8,0.5,-16),
	BackgroundTransparency = 1, ZIndex = 5,
}, profileBar)

local pbAvF, pbAvImg, pbAvLbl = makeAv(32, string.upper(string.sub(USERNAME,1,1)), C.accent, pbAvHolder)
pbAvF.Size = UDim2.new(1,0,1,0)
pbAvImg.ZIndex = 6; pbAvLbl.ZIndex = 6

-- Online dot
local pbDot = make("Frame", {
	Size = UDim2.new(0,10,0,10),
	Position = UDim2.new(1,-8,1,-8),
	BackgroundColor3 = C.online,
	BorderSizePixel = 0, ZIndex = 8,
}, pbAvHolder)
corner(10, pbDot)
make("UIStroke", {Color = C.bg_profile, Thickness = 2.5}, pbDot)

applyHeadshot(pbAvImg, pbAvLbl, MY_HEADSHOT)

-- Display name
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

-- Username tag
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
	Size = UDim2.new(1,-312,1,0),
	Position = UDim2.new(0,312,0,0),
	BackgroundColor3 = C.bg_chat,
	BorderSizePixel = 0, ZIndex = 2,
}, win)

-- =============================================
-- CHAT HEADER (drag handle)
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

make("TextLabel", {
	Size = UDim2.new(0,200,0,20), Position = UDim2.new(0,38,0.5,-10),
	BackgroundTransparency = 1,
	Text = "Roblox", Font = FB, TextSize = 15,
	TextColor3 = C.txt_header,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, header)

-- (close button removed — topbar button toggles visibility)

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
-- MESSAGE SCROLL
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

-- Only auto-scroll when user is near the bottom
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

-- Input box: expands vertically up to 120px then scrolls
-- MultiLine=true, TextWrapped=true — no overlay trick (causes Android double-type)
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

-- Grow inputWrap height with content, cap at 120px
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
	Position = UDim2.new(0.5,-10,0.5,-10),  -- perfectly centered
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

-- Grey out send button when input is empty
local function updateSendBtn()
	local empty = inputBox.Text:match("^%s*$") ~= nil
	sendBtn.BackgroundColor3 = empty and Color3.fromRGB(64,66,74) or C.accent
	sendBtn.Active = not empty
end
updateSendBtn()
inputBox:GetPropertyChangedSignal("Text"):Connect(updateSendBtn)

-- =============================================
-- DM ENTRY LAST MESSAGE PREVIEW (references updated by firebasePoll)
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
	else return math.floor(diff/86400) .. "d"
	end
end

local lastMsgTs = 0
local function updateDMPreview(sender, text, ts)
	if ts < lastMsgTs then return end
	lastMsgTs = ts
	local prefix = sender == USERNAME and "You: " or (sender .. ": ")
	-- Strip emoji syntax to plain names for preview
	local preview = text:gsub(":([%w_]+):", function(name)
		return CUSTOM_EMOJIS[name] and (":" .. name .. ":") or (":" .. name .. ":")
	end)
	dmLastMsgLabel.Text = prefix .. preview
	dmTimestampLabel.Text = formatRelativeTime(ts)
end

-- Fetch Roblox presence and show as initial status in DM entry
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

-- Declare shared message state before renderDateSeparator uses msgOrder
local msgOrder    = 0
local seenKeys    = {}
local lastSender  = nil
local lastTs      = 0
local GROUP_GAP   = 300
local lastDateStr = nil
local renderedRows = {}  -- {row, sender, isGrouped, ts, key}

local function renderDateSeparator(ts)
	local dateStr = os.date("%B %d, %Y", ts)
	if dateStr == lastDateStr then return end
	lastDateStr = dateStr
	-- Reset grouping state so first message after separator is never grouped
	lastSender = nil
	lastTs     = 0
	msgOrder += 1

	local sep = make("Frame", {
		Name = "DateSep",
		Size = UDim2.new(1,0,0,24),
		BackgroundTransparency = 1,
		LayoutOrder = msgOrder, ZIndex = 3,
	}, msgScroll)

	-- Left line
	make("Frame", {
		Size = UDim2.new(0.5,-40,0,1),
		Position = UDim2.new(0,0,0.5,0),
		BackgroundColor3 = C.divider,
		BorderSizePixel = 0, ZIndex = 4,
	}, sep)

	-- Date label
	make("TextLabel", {
		Size = UDim2.new(0,80,1,0),
		Position = UDim2.new(0.5,-40,0,0),
		BackgroundTransparency = 1,
		Text = dateStr,
		Font = FM, TextSize = 11,
		TextColor3 = C.txt_muted,
		ZIndex = 4,
	}, sep)

	-- Right line
	make("Frame", {
		Size = UDim2.new(0.5,-40,0,1),
		Position = UDim2.new(0.5,40,0.5,0),
		BackgroundColor3 = C.divider,
		BorderSizePixel = 0, ZIndex = 4,
	}, sep)
end

-- =============================================
-- EMOJI PARSING
-- :name: syntax replaced with ImageLabel in message
-- If message is ONLY emoji tokens -> jumbo (48px), else inline (22px)
-- =============================================

-- Returns list of tokens: {type="text"|"emoji", value=string, name=string}
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

-- Check if ALL non-whitespace content is emoji tokens
local function isEmojiOnly(tokens)
	for _, t in ipairs(tokens) do
		if t.type == "text" and t.value:match("%S") then
			return false
		end
	end
	-- Also ensure at least one emoji exists
	for _, t in ipairs(tokens) do
		if t.type == "emoji" then return true end
	end
	return false
end

-- Build rich content: returns a Frame containing text + inline emoji ImageLabels
-- Uses a single TextLabel per text segment and ImageLabels for emoji
-- All wrapped in a horizontal flow using a Frame with UIListLayout
local function buildEmojiContent(parent, tokens, jumbo, baseZIndex, txtColor)
	local emojiSize = jumbo and 48 or 22
	local fontSize  = jumbo and 36 or 14

	-- Check if it's pure text (no emoji tokens at all) — use single label for perf
	local hasEmoji = false
	for _, t in ipairs(tokens) do
		if t.type == "emoji" then hasEmoji = true; break end
	end

	if not hasEmoji then
		-- Pure text: single wrapping TextLabel
		local lbl = make("TextLabel", {
			Size = UDim2.new(1,0,0,0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = tokens[1] and tokens[1].value or "",
			Font = FR, TextSize = fontSize,
			TextColor3 = txtColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			ZIndex = baseZIndex,
		}, parent)
		return lbl
	end

	-- Mixed/emoji: horizontal flow frame
	local flow = make("Frame", {
		Size = UDim2.new(1,0,0,0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0,2),
		Wraps = true,
	}, flow)

	local firstLbl = nil
	for _, token in ipairs(tokens) do
		if token.type == "emoji" and CUSTOM_EMOJIS[token.name] then
			local em = CUSTOM_EMOJIS[token.name]
			local imgF = make("Frame", {
				Size = UDim2.new(0,emojiSize,0,emojiSize),
				BackgroundTransparency = 1,
				ZIndex = baseZIndex+1,
			}, flow)
			local img = make("ImageLabel", {
				Size = UDim2.new(1,0,1,0),
				BackgroundTransparency = 1,
				Image = em.asset or "",
				ZIndex = baseZIndex+2,
			}, imgF)
			if not em.asset then
				task.spawn(function()
					local w = 0
					while not em.asset and w < 10 do task.wait(0.3); w+=0.3 end
					if em.asset and img.Parent then img.Image = em.asset end
				end)
			end
		else
			local lbl = make("TextLabel", {
				Size = UDim2.new(0,0,0,fontSize+4),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = token.value,
				Font = FR, TextSize = fontSize,
				TextColor3 = txtColor,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = false,
				ZIndex = baseZIndex+1,
			}, flow)
			if not firstLbl then firstLbl = lbl end
		end
	end

	return firstLbl or flow
end

-- Refresh content label text (edit case — for pure text only)
local function refreshEmojiContent(lbl, text, isPending)
	if not lbl or not lbl.Parent then return end
	local color = isPending and C.txt_pending or C.txt_white
	local tokens = parseEmoji(text)
	local hasEmoji = false
	for _, t in ipairs(tokens) do if t.type == "emoji" then hasEmoji = true; break end end
	if not hasEmoji and lbl:IsA("TextLabel") then
		lbl.Text = text
		lbl.TextColor3 = color
	else
		-- Can't easily refresh mixed flow — just update text color
		lbl.TextColor3 = color
	end
end

local function renderMessage(senderName, text, isPending, msgTs, isEdited, replyData)
	msgTs = msgTs or os.time()
	hideBanner()

	-- Date separator
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

	-- Inline reply quote (shown above message content)
	if replyData then
		local replyOuter = make("Frame", {
			Size = UDim2.new(1,0,0,20),
			BackgroundTransparency = 1,
			LayoutOrder = 1, ZIndex = 5,
		}, outerCol)

		-- Curved vertical bar (rounded frame)
		local vbar = make("Frame", {
			Size = UDim2.new(0,2,1,0),
			Position = UDim2.new(0,40,0,0),
			BackgroundColor3 = C.txt_muted,
			BorderSizePixel = 0, ZIndex = 6,
		}, replyOuter)
		corner(4, vbar)

		-- Inner row to the right of the bar
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

		-- Small avatar — transparent background, just the headshot
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

		-- Sender name
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

		-- Quoted text — strip emoji to plain :name: for the compact preview
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

	-- Main message row (avatar + text or grouped indent)
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

		-- Name + time
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

		-- Content with emoji support
		local tokens = parseEmoji(text)
		local jumbo  = isEmojiOnly(tokens)
		local wrapper = make("Frame", {
			Size = UDim2.new(1,0,0,0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2, ZIndex = 6,
		}, tb)
		content = buildEmojiContent(wrapper, tokens, jumbo, 7, txtColor)

		-- (edited) tag below content
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
		-- Update DM preview now that message is confirmed
		updateDMPreview(data.sender or USERNAME, data.content.Text, os.time())
	end
end

-- =============================================
-- FIREBASE
-- Uses simple .json GET with no orderBy
-- so it works without a Firebase index rule.
-- We sort client-side by ts instead.
-- =============================================
local function firebaseSend(text, replyData)
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
-- CONTEXT MENU (long press on own messages)
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

-- Divider sits between Edit and Delete
make("Frame", {
	Size = UDim2.new(1,-8,0,1),
	BackgroundColor3 = Color3.fromRGB(40,40,46),
	BorderSizePixel = 0,
	LayoutOrder = 4,
	ZIndex = 101,
}, contextMenu)

local btnDelete, iconDelete = makeCtxBtn("Delete", ICON_DELETE, Color3.fromRGB(237,66,69), Color3.fromRGB(237,66,69), 5)

local ctxTargetData = nil  -- holds {key, contentLabel, rowFrame, text}

local function showContextMenu(x, y, data)
	ctxTargetData = data
	local isOwn = data.sender == USERNAME

	-- Show/hide buttons based on ownership
	btnEdit.Visible   = isOwn
	btnDelete.Visible = isOwn
	-- Divider between edit and delete only shown for own messages
	for _, c in ipairs(contextMenu:GetChildren()) do
		if c:IsA("Frame") and c.LayoutOrder == 4 then
			c.Visible = isOwn
		end
	end

	-- Resize menu: own = 4 buttons + divider = 144px, others = 2 buttons = 76px
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

-- Attach 1-second hold detection to a row (mouse + touch)
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

	-- Mouse
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

	-- Touch
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
			-- Cancel if finger moves too far (scroll intent)
			local dx = math.abs(input.Position.X - holdPos.X)
			local dy = math.abs(input.Position.Y - holdPos.Y)
			if dx > 10 or dy > 10 then cancelHold() end
		end
	end)
end


local function firebasePoll()
	-- Simple GET of all messages, no orderBy needed
	local ok, res = pcall(httpRequest, {
		Url = FIREBASE_URL .. ".json",
		Method = "GET",
		Headers = {["Content-Type"] = "application/json"},
	})

	if not ok or not res or res.StatusCode ~= 200 then return end
	if res.Body == "null" or res.Body == nil then return end

	local ok2, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
	if not ok2 or type(data) ~= "table" then return end

	-- Collect and sort by ts client-side
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

-- Close menu when clicking OR touching anywhere else (but not inside the menu itself)
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
			if not inside then
				hideContextMenu()
			end
		end
	end
end)

-- REPLY
local replyingTo = nil  -- {sender, text}
local replyBar   = nil  -- the reply preview frame above input

local function clearReply()
	replyingTo = nil
	if replyBar and replyBar.Parent then
		replyBar:Destroy()
		replyBar = nil
	end
	-- Restore inputWrap position
	inputBox.PlaceholderText = "Message @Roblox"
end

btnReply.MouseButton1Click:Connect(function()
	if not ctxTargetData then return end
	replyingTo = {sender = ctxTargetData.sender, text = ctxTargetData.text}

	-- Show reply preview bar above input
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

-- COPY
btnCopy.MouseButton1Click:Connect(function()
	if not ctxTargetData then return end
	local text = ctxTargetData.text
	hideContextMenu()
	-- Use setclipboard if available, otherwise print
	if setclipboard then
		pcall(setclipboard, text)
		print("[DiscordBlox] Copied: " .. text)
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

	-- Clear any existing edit/reply bar
	clearEdit()
	clearReply()

	-- Show edit bar above input
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

	local function submitEdit()
		local newText = inputBox.Text
		if newText:match("^%s*$") then clearEdit(); return end
		clearEdit()

		local url  = FIREBASE_URL .. "/" .. editKey .. ".json"
		local body = HttpService:JSONEncode({
			sender = USERNAME, text = newText, ts = data.ts, edited = true
		})
		local ok, res = pcall(httpRequest, {
			Url = url, Method = "PUT",
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
			print("[DiscordBlox] Message edited")
		else
			warn("[DiscordBlox] Edit failed: " .. tostring(res and res.StatusCode))
		end
	end

	-- Submit via Enter key
	editingConn = inputBox.FocusLost:Connect(function(enter)
		if enter then submitEdit() end
	end)

	-- Submit via send button
	local editSendConn
	editSendConn = sendBtn.MouseButton1Click:Connect(function()
		editSendConn:Disconnect()
		submitEdit()
	end)
end)

-- DELETE
btnDelete.MouseButton1Click:Connect(function()
	if not ctxTargetData then return end
	local data = ctxTargetData
	hideContextMenu()

	local url = FIREBASE_URL .. "/" .. data.key .. ".json"
	local ok, res = pcall(httpRequest, {Url = url, Method = "DELETE"})
	if not (ok and res and (res.StatusCode == 200 or res.StatusCode == 204)) then
		warn("[DiscordBlox] Delete failed: " .. tostring(res and res.StatusCode))
		return
	end

	seenKeys[data.key] = true

	-- Find deleted row in renderedRows
	local rowIdx = nil
	for i, r in ipairs(renderedRows) do
		if r.row == data.rowFrame then rowIdx = i; break end
	end

	-- If the next message is grouped and this was its group leader, promote it
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

					-- Rebuild content from rawText instead of moving the old label
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
					nextEntry.content = newContent

					-- Destroy old grouped content if still exists
					if nextEntry.content and nextEntry.content.Parent
						and nextEntry.content.Parent ~= tb then
						nextEntry.content.Parent:Destroy()
					end

					nextEntry.isGrouped = false
				end
			end
		end
		table.remove(renderedRows, rowIdx)
	end

	-- Destroy the row
	if data.rowFrame and data.rowFrame.Parent then
		data.rowFrame:Destroy()
	end

	-- Clean up orphaned date separators after a short delay
	task.delay(0.1, function()
		local children = msgScroll:GetChildren()
		-- Filter to only layout-ordered items (exclude UIListLayout, UIPadding)
		local ordered = {}
		for _, c in ipairs(children) do
			if c:IsA("Frame") or c:IsA("TextButton") then
				table.insert(ordered, c)
			end
		end
		table.sort(ordered, function(a,b) return a.LayoutOrder < b.LayoutOrder end)

		for i, child in ipairs(ordered) do
			if child.Name == "DateSep" and child.Parent then
				-- Check if any non-separator follows before next separator or end
				local hasMsg = false
				for j = i+1, #ordered do
					if ordered[j].Name == "DateSep" then break end
					if ordered[j].Name ~= "DateSep" then hasMsg = true; break end
				end
				if not hasMsg then child:Destroy() end
			end
		end
	end)

	print("[DiscordBlox] Message deleted")
end)

-- =============================================
-- SEND
-- =============================================
local function sendMessage()
	local rawText = inputBox.Text
	if not rawText or rawText:match("^%s*$") then return end

	-- Don't send if we're in edit mode
	if editingBar and editingBar.Parent then return end

	inputBox.Text = ""

	local text      = rawText
	local curReply  = replyingTo
	if curReply then clearReply() end

	local replyPayload = curReply and {sender = curReply.sender, text = curReply.text:sub(1,80)} or nil
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
end

sendBtn.MouseButton1Click:Connect(sendMessage)
inputBox.FocusLost:Connect(function(enter) if enter then sendMessage() end end)

-- =============================================
-- DRAG (free, no clamping)
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

-- POLL LOOP
-- =============================================
local loadSuccess = true  -- will be set false if any critical error occurred

task.spawn(function()
	task.wait(0.3)
	local ok, err = pcall(firebasePoll)
	if not ok then
		warn("[DiscordBlox] Initial poll failed: " .. tostring(err))
		loadSuccess = false
	end
	-- Force scroll to bottom after history loads
	task.defer(function()
		msgScroll.CanvasPosition = Vector2.new(0, msgScroll.AbsoluteCanvasSize.Y)
	end)

	-- Only show topbar button if everything loaded successfully
	if loadSuccess then
		buttonFrame.Visible = true
		print("[DiscordBlox] Loaded successfully, topbar button visible")
	else
		buttonFrame.Visible = false
		warn("[DiscordBlox] Load failed, topbar button hidden")
	end

	while gui and gui.Parent do
		task.wait(POLL_INTERVAL)
		if gui and gui.Parent then
			pcall(firebasePoll)
		end
	end
end)

print("[DiscordDM] Loaded | Username:", USERNAME)
