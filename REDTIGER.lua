--/$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
--  RedTiger - Key System (loader v1.1)
--  Un rien ne se lance que si une clé valide est fournie.
--  Les clés sont gerees depuis le bot Discord (durations 1h/1j/1semaine/etc)
--/$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

print("[RedTiger] Loader demarre - verification de la clé...")

local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local REPO_RAW  = "https://raw.githubusercontent.com/chefnon29/REDTIGER-Lua/refs/heads/main"
local KEYS_URL  = REPO_RAW .. "/keys.json"
local PANEL_URL = REPO_RAW .. "/Panel.lua"
local KEY_FILE  = "RedTiger/key.txt"

local globalWait = wait
local function _wait(seconds)
	if task ~= nil and task.wait ~= nil then return task.wait(seconds) end
	return globalWait(seconds)
end

-- ================================================================
--  HTTP (3 essais + cache-bust)
-- ================================================================
local function httpGet(url)
	local lastError = ""
	for i = 1, 3 do
		local cacheBust = "?v=" .. tostring(os.time()) .. tostring(math.random(10000, 99999))
		local ok, res = pcall(function()
			return game:HttpGet(url .. cacheBust)
		end)
		if ok and type(res) == "string" then
			return res
		end
		lastError = tostring(res or "erreur inconnue")
		_wait(0.4)
	end
	return nil, lastError
end

-- ================================================================
--  Cle : normalisation + sauvegarde local (auto-remplissage)
-- ================================================================
local function normalizeKey(input)
	local key = tostring(input or ""):upper()
	key = key:gsub("%s", "")
	return key
end

local function saveKey(key)
	pcall(function()
		if writefile then
			if isfolder ~= nil and makefolder ~= nil and not isfolder("RedTiger") then
				makefolder("RedTiger")
			end
			writefile(KEY_FILE, key)
		end
	end)
end

local function loadSavedKey()
	local key
	pcall(function()
		if readfile ~= nil and isfile ~= nil and isfile(KEY_FILE) then
			key = readfile(KEY_FILE)
		end
	end)
	if type(key) == "string" and #key > 0 then
		return normalizeKey(key)
	end
	return nil
end

-- ================================================================
--  HWID : identifiant unique du PC/execiteur
-- ================================================================
local HWID = "unknown"
do
	local id
	pcall(function()
		if type(gethwid) == "function" then id = tostring(gethwid()) end
	end)
	if not id then
		pcall(function()
			if type(IdentifyExecutor) == "function" then id = tostring(IdentifyExecutor()) end
		end)
	end
	if not id and type(getExecutorName) == "function" then
		pcall(function() id = "exec-" .. tostring(getExecutorName()) end)
	end
	if not id or #id == 0 then
		local ok, lp = pcall(function() return Players.LocalPlayer end)
		if ok and lp ~= nil then
			id = "user-" .. tostring(lp.UserId)
		else
			id = "unk-" .. tostring(math.random(100000, 999999))
		end
	end
	HWID = id
end

-- ================================================================
--  Formatage de la duree restante (pour le message de bienvenue)
-- ================================================================
local function humanRemaining(seconds)
	if seconds == math.huge then return "a vie" end
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then return "illimitee" end
	local days    = math.floor(seconds / 86400)
	local hours   = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if days > 1 then return tostring(days) .. " jours" end
	if days == 1 then return "1 jour " .. tostring(hours) .. " h" end
	if hours > 1 then return tostring(hours) .. " h " .. tostring(minutes) .. " min" end
	return tostring(minutes) .. " min"
end

-- ================================================================
--  Fenêtre de clé
-- ================================================================
local statusLabel, keyBox, verifyButton, clientIdLabel

local success, gui = pcall(function()
	local screenGui        = Instance.new("ScreenGui")
	screenGui.Name         = "RedTigerKeySystem"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		if type(syn) == "table" and type(syn.protect_gui) == "function" then
			syn.protect_gui(screenGui)
		end
	end)
	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame            = Instance.new("Frame")
	frame.Name             = "KeyFrame"
	frame.Size             = UDim2.new(0, 420, 0, 300)
	frame.Position         = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint      = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3  = Color3.fromRGB(18, 18, 22)
	frame.BorderSizePixel  = 0
	frame.Parent           = screenGui
	pcall(function()
		local UICorner = Instance.new("UICorner")
		UICorner.CornerRadius = UDim.new(0, 10)
		UICorner.Parent = frame
	end)

	local stroke     = Instance.new("UIStroke")
	stroke.Color     = Color3.fromRGB(214, 37, 44)
	stroke.Thickness = 2
	stroke.Parent    = frame

	local title       = Instance.new("TextLabel")
	title.Size        = UDim2.new(1, 0, 0, 40)
	title.Position    = UDim2.new(0, 0, 0, 2)
	title.BackgroundTransparency = 1
	title.Text        = "RedTiger - Key System"
	title.TextColor3  = Color3.fromRGB(240, 60, 70)
	title.Font        = Enum.Font.GothamBold
	title.TextSize    = 20
	title.Parent      = frame

	local hint        = Instance.new("TextLabel")
	hint.Size         = UDim2.new(1, -20, 0, 18)
	hint.Position     = UDim2.new(0, 10, 0, 42)
	hint.BackgroundTransparency = 1
	hint.Text         = "Entre ta clé pour acceder au panel"
	hint.TextColor3   = Color3.fromRGB(190, 190, 200)
	hint.Font         = Enum.Font.Gotham
	hint.TextSize     = 13
	hint.Parent       = frame

	clientIdLabel     = Instance.new("TextLabel")
	clientIdLabel.Size = UDim2.new(1, -20, 0, 16)
	clientIdLabel.Position = UDim2.new(0, 10, 0, 60)
	clientIdLabel.BackgroundTransparency = 1
	clientIdLabel.Text = "Ton ID unique : " .. HWID
	clientIdLabel.TextColor3 = Color3.fromRGB(130, 130, 140)
	clientIdLabel.Font = Enum.Font.Gotham
	clientIdLabel.TextSize = 11
	clientIdLabel.TextTruncate = Enum.TextTruncate.AtEnd
	clientIdLabel.Parent = frame

	keyBox            = Instance.new("TextBox")
	keyBox.Size       = UDim2.new(1, -40, 0, 36)
	keyBox.Position   = UDim2.new(0, 20, 0, 90)
	keyBox.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	keyBox.TextColor3 = Color3.fromRGB(240, 240, 245)
	keyBox.PlaceholderText  = "XXXX-XXXX-XXXX-XXXX"
	keyBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 110)
	keyBox.Text       = loadSavedKey() or ""
	keyBox.Font       = Enum.Font.Gotham
	keyBox.TextSize   = 14
	keyBox.ClearTextOnFocus = false
	keyBox.Parent     = frame
	pcall(function()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = keyBox
	end)

	verifyButton        = Instance.new("TextButton")
	verifyButton.Size   = UDim2.new(1, -40, 0, 34)
	verifyButton.Position = UDim2.new(0, 20, 0, 134)
	verifyButton.BackgroundColor3 = Color3.fromRGB(214, 37, 44)
	verifyButton.Text   = "Valider"
	verifyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	verifyButton.Font   = Enum.Font.GothamBold
	verifyButton.TextSize = 15
	verifyButton.Parent = frame
	pcall(function()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = verifyButton
	end)

	statusLabel        = Instance.new("TextLabel")
	statusLabel.Size   = UDim2.new(1, -40, 0, 60)
	statusLabel.Position = UDim2.new(0, 20, 0, 178)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text   = ""
	statusLabel.TextColor3 = Color3.fromRGB(240, 200, 200)
	statusLabel.Font   = Enum.Font.Gotham
	statusLabel.TextSize = 13
	statusLabel.TextWrapped = true
	statusLabel.Parent = frame

	return screenGui
end)

if not success or gui == nil then
	warn("[RedTiger] Impossible d'afficher la fenetre de clé : " .. tostring(gui))
	return
end

local function setStatus(text)
	pcall(function() statusLabel.Text = tostring(text) end)
end

local function destroyGui()
	pcall(function()
		if gui ~= nil and gui.Parent ~= nil then gui:Destroy() end
	end)
end

-- ================================================================
--  Chargement du panel (SEULEMENT si clé valide)
-- ================================================================
local function launchPanel()
	local code, err = httpGet(PANEL_URL)
	if code == nil then
		warn("[RedTiger] Erreur de telechargement du panel : " .. tostring(err))
		return
	end
	local fn, compileErr = loadstring(code)
	if fn == nil then
		warn("[RedTiger] Erreur de compilation du panel : " .. tostring(compileErr))
		return
	end
	local ok, runErr = pcall(fn)
	if not ok then
		warn("[RedTiger] Erreur d'execution du panel : " .. tostring(runErr))
	end
end

-- ================================================================
--  Verification de la clé (base sur GitHub)
-- ================================================================
local function checkKey(key)
	local res, resError = httpGet(KEYS_URL)
	if res == nil then
		return false, "Serveur injoignable, retente dans quelques secondes. (" .. resError .. ")"
	end

	local ok, data = pcall(function() return HttpService:JSONDecode(res) end)
	if not ok or type(data) ~= "table" then
		return false, "Base de clés indisponible. Retente plus tard."
	end

	local entry = data[key]
	if type(entry) ~= "table" then
		return false, "Cle invalide. Demande une clé a ton admin Discord."
	end

	local expires = tonumber(entry.expires) or 0
	if expires > 0 then
		local now = os.time()
		if now >= expires then
			return false, "clé expiree. Demande-en une nouvelle a ton admin."
		end
		return true, expires - now
	end
	return true, math.huge
end

-- ================================================================
--  Action de validation
-- ================================================================
local function validate()
	local key = normalizeKey(keyBox.Text)
	if #key == 0 then
		setStatus("âš  Entre ta clé avant de valider.")
		return
	end

	setStatus("Verification de la clé...")
	verifyButton.Text = "Verification..."

	local ok, result = checkKey(key)
	if not ok then
		setStatus("âŒ " .. tostring(result))
		verifyButton.Text = "Valider"
		return
	end

	saveKey(key)
	local remainingText = humanRemaining(result)
	setStatus("âœ… clé valide ! Bienvenue sur RedTiger. (" .. remainingText .. ")")
	verifyButton.Text = "Connecte"
	_wait(0.8)
	destroyGui()
	launchPanel()
end

verifyButton.MouseButton1Click:Connect(validate)
keyBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then validate() end
end)

setStatus("Pret. Entre ta clé puis clique Valider (ou appuie sur Entree).")
