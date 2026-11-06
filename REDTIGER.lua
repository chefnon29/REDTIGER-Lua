--/$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
--  RedTiger - Key System (loader v1.3)
--  - Fenêtre de clé : rien ne se lance sans clé valide
--  - Session surveillée : clé expirée/supprimée = panel fermé,
--    fichiers supprimés, joueur éjecté, logs postés
--  - _G.RedTigerKey / _G.RedTigerSessionValid consommés par Panel.lua
--/$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

print("[RedTiger] Version loader : v1.3");
print("[RedTiger] Loader demarre - verification de la clé...")
print("[RedTiger] Executor : " .. (function()
	local ok, name = pcall(function() return getExecutorName and getExecutorName() or "inconnu" end)
	return ok and tostring(name) or "inconnu"
end)())

local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local REPO_RAW  = "https://raw.githubusercontent.com/chefnon29/REDTIGER-Lua/refs/heads/main"
local KEYS_API  = "https://api.github.com/repos/chefnon29/REDTIGER-Lua/contents/keys.json"
local KEYS_RAW  = REPO_RAW .. "/keys.json"
local PANEL_ENC_URL = REPO_RAW .. "/Panel.enc.lua"
local KEY_FILE  = "RedTiger/key.txt"
local LOGS_FILE = "RedTiger/logs.txt"

-- ================================================================
--  Aides diverses
-- ================================================================
local globalWait = wait
local function _wait(seconds)
	if task ~= nil and task.wait ~= nil then return task.wait(seconds) end
	return globalWait(seconds)
end

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

local function deleteSavedKey()
	pcall(function()
		if delfile ~= nil and isfile ~= nil and isfile(KEY_FILE) then
			delfile(KEY_FILE)
		end
	end)
end

local function appendLog(line)
	pcall(function()
		if appendfile then
			if isfolder ~= nil and makefolder ~= nil and not isfolder("RedTiger") then
				makefolder("RedTiger")
			end
			appendfile(LOGS_FILE, line .. "\n")
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

local function dateFr(timestamp)
	local ok, result = pcall(function()
		return os.date("%d/%m/%Y a %H:%M", timestamp)
	end)
	if ok and result ~= nil then return tostring(result) end
	return "date inconnue"
end

-- ================================================================
--  HWID
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
		if LocalPlayer ~= nil then
			id = "user-" .. tostring(LocalPlayer.UserId)
		else
			id = "unk-" .. tostring(math.random(100000, 999999))
		end
	end
	HWID = id
end

-- ================================================================
--  Temps restant
-- ================================================================
local function humanExpires(expiresNow)
	expiresNow = tonumber(expiresNow) or 0
	if expiresNow <= 0 then return "a vie" end
	local restant = expiresNow - os.time()
	if restant <= 0 then return "expirée" end
	local days    = math.floor(restant / 86400)
	local hours   = math.floor((restant % 86400) / 3600)
	local minutes = math.floor((restant % 3600) / 60)
	if days > 1 then return tostring(days) .. " jours" end
	if days == 1 then return "1 jour " .. tostring(hours) .. " h" end
	if hours > 1 then return tostring(hours) .. " h " .. tostring(minutes) .. " min" end
	return tostring(minutes) .. " min"
end

-- ================================================================
--  base64
-- ================================================================
local B64CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function b64decode(data)
	data = data:gsub("[^" .. B64CHARS .. "=]", "")
	data = (data:gsub(".", function(x)
		if x == "=" then return "" end
		local r, f = "", (B64CHARS:find(x) - 1)
		for i = 6, 1, -1 do
			r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
		end
		return r
	end))
	return (data:gsub("%d%d?%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then return "" end
		local c = 0
		for i = 1, 8 do
			c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
		end
		return string.char(c)
	end))
end

-- ================================================================
--  RT-CRYPTO v1 (identique a crypto.js du bot : hash haché irreverssible
--  des cles + chiffrement de flot du panel ; teste croise Lua/JS)
-- ================================================================
local RT_KEY_SALT = "65DF14AEB7D7660D078D639EAF40E144"

local function rtImul32(a, b)
	local al = a % 65536
	local ah = (a - al) / 65536
	local bl = b % 65536
	local bh = (b - bl) / 65536
	local lo = al * bl
	local mid = (al * bh + ah * bl) % 65536
	return (lo + mid * 65536) % 4294967296
end

local function rtBytes(s)
	local t = {}
	for i = 1, #s do t[i] = string.byte(s, i) end
	return t
end

local function rtHash32(msg, saltStr)
	local h = 0x811C9DC5
	local function mix(b)
		h = bit32.bxor(h, b)
		h = rtImul32(h, 0x01000193)
		h = bit32.bxor(h, bit32.lrotate(h, 7))
	end
	for _, b in ipairs(rtBytes(saltStr)) do mix(b) end
	for _, b in ipairs(rtBytes(msg)) do mix(b) end
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = rtImul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = rtImul32(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end

local function rtHex8(h)
	return string.upper(string.format("%08x", h))
end

local function rtHash64(msg, salt)
	return rtHex8(rtHash32(msg, salt)) .. rtHex8(rtHash32(msg, salt .. "#2"))
end

local function rtKeyHash(key)
	return rtHash64(key, RT_KEY_SALT .. "/key/")
end

local function rtMakeCipher(secret)
	local x = rtHash32(secret, "rt/cipher/1")
	local y = rtHash32(secret, "rt/cipher/2")
	local z = rtHash32(secret, "rt/cipher/3")
	local d = rtHash32(secret, "rt/cipher/4")
	return function()
		local t = bit32.bxor(x, bit32.lshift(x, 11))
		x = y
		y = z
		z = d
		d = bit32.bxor(bit32.bxor(d, bit32.rshift(d, 19)), bit32.bxor(t, bit32.rshift(t, 8)))
		return bit32.band(d, 255)
	end
end

-- decode un base64 REVEnvoyable en table d'octets (rapide, panel complet)
local B64VAL_RT = {}
do
	for i = 1, #B64CHARS do
		B64VAL_RT[string.byte(B64CHARS, i)] = i - 1
	end
end

local function b64ToBytes(b64)
	local out = {}
	local n = 0
	local buf = 0
	local bits = 0
	for i = 1, #b64 do
		local v = B64VAL_RT[string.byte(b64, i)]
		if v then
			buf = buf * 64 + v
			bits = bits + 6
			if bits >= 8 then
				local shift = bits - 8
				n = n + 1
				out[n] = math.floor(buf / 2 ^ shift) % 256
				bits = shift
				buf = buf % 2 ^ bits
			end
		end
	end
	return out
end

-- ================================================================
--  Dechiffrement du panel stocke chiffre sur GitHub :
--  1) entry.pkey = cle du panel chiffree AVEC la cle de l'utilisateur
--  2) Panel.enc.lua chiffre AVEC cette cle du panel
--  Pas de clé valide -> impossible de rien reconstruire.
-- ================================================================
local function rtDecryptPKey(pkeyB64, userKey)
	local raw = b64decode(tostring(pkeyB64 or ""))
	if type(raw) ~= "string" or #raw == 0 then return nil end
	local nextByte = rtMakeCipher(userKey)
	local out = {}
	for i = 1, #raw do
		out[i] = string.char(bit32.band(bit32.bxor(string.byte(raw, i), nextByte()), 255))
	end
	local k = table.concat(out)
	if #k == 16 then return k end
	return nil
end

local function rtDecryptBlob(b64, secret)
	local bytes = b64ToBytes(tostring(b64 or ""))
	local nextByte = rtMakeCipher(secret)
	local chunks = {}
	local n = #bytes
	local start = 1
	while start <= n do
		local limit = math.min(start + 4000, n)
		local chunk = {}
		local ci = 0
		for i = start, limit do
			ci = ci + 1
			chunk[ci] = string.char(bit32.band(bit32.bxor(bytes[i], nextByte()), 255))
		end
		chunks[#chunks + 1] = table.concat(chunk)
		start = limit + 1
	end
	return table.concat(chunks)
end

-- ================================================================
--  Base de clés : API GitHub (fraiche) puis raw (fallback)
-- ================================================================
local function fetchKeysTable()
	local ok, envelope = pcall(function()
		local raw = httpGet(KEYS_API)
		return HttpService:JSONDecode(raw)
	end)
	if ok and type(envelope) == "table" and type(envelope.content) == "string" then
		local decoded = b64decode(envelope.content)
		if decoded and #decoded > 0 then
			local jsonOk, data = pcall(function() return HttpService:JSONDecode(decoded) end)
			if jsonOk and type(data) == "table" then
				return data
			end
		end
	end
	local res, resError = httpGet(KEYS_RAW)
	if res == nil then
		return false, resError
	end
	local jsonOk, data = pcall(function() return HttpService:JSONDecode(res) end)
	if jsonOk and type(data) == "table" then
		return data
	end
	return false, "JSON invalide"
end

-- ================================================================
--  (Webhook Discord de logs : cote panel chiffre seulement — le loader
--  public ne connait NI le webhook, NI les clés, NI le code du panel)
-- ================================================================

-- ================================================================
--  Fenêtre de clé
-- ================================================================
local statusLabel, keyBox, verifyButton

local function guiStatus(text)
	pcall(function()
		if statusLabel ~= nil then statusLabel.Text = tostring(text) end
	end)
end

local success, gui = pcall(function()
	local screenGui        = Instance.new("ScreenGui")
	screenGui.Name         = "RedTigerKeySystem"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Parent le plus robuste possible : gethui / CoreGui / PlayerGui
	local parented = false
	pcall(function()
		if type(gethui) == "function" and gethui() ~= nil then
			screenGui.Parent = gethui()
			parented = true
		end
	end)
	if not parented then
		pcall(function()
			screenGui.Parent = game:GetService("CoreGui")
			parented = true
		end)
	end
	if not parented then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	screenGui.DisplayOrder = 2147483

	-- protection syn (avant parenting)
	pcall(function()
		if type(syn) == "table" and type(syn.protect_gui) == "function" then
			syn.protect_gui(screenGui)
		end
	end)

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

	local clientIdLabel = Instance.new("TextLabel")
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

print("[RedTiger] Etape 2 : fenetre de clé creee")

if not success or gui == nil then
	print("[RedTiger] ERREUR popup normale : " .. tostring(gui) .. " -> popup de secours")
	-- popup de secours ultra-simple (toujours jouable)
	pcall(function()
		local sg = Instance.new("ScreenGui")
		sg.Name = "RedTigerKeySystem"
		sg.ResetOnSpawn = false
		sg.Parent = (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")) or game:GetService("CoreGui")
		local fr = Instance.new("Frame")
		fr.Size = UDim2.new(0, 380, 0, 200)
		fr.Position = UDim2.new(0.5, 0, 0.5, 0)
		fr.AnchorPoint = Vector2.new(0.5, 0.5)
		fr.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		fr.Parent = sg
		local lb = Instance.new("TextLabel")
		lb.Size = UDim2.new(1, -20, 1, -20)
		lb.Position = UDim2.new(0, 10, 0, 10)
		lb.BackgroundTransparency = 1
		lb.TextColor3 = Color3.new(1, 1, 1)
		lb.TextScaled = true
		lb.TextWrapped = true
		lb.Text = "RedTiger\n\nLa fenetre de clé n'arrive pas a s'afficher.\nErreur : " .. tostring(gui)
		lb.Parent = fr
	end)
	return
end

-- ================================================================
--  Fermeture TOTALE (clé expirée / supprimée / tamponné)
--  Rien ne peut la contourner : panel détruit + fichiers
--  supprimés + Kick hard du joueur + log webhook
-- ================================================================
_G.RedTigerSessionValid = false

local function displayGui()
	pcall(function()
		if gui ~= nil and gui.Parent ~= nil then
			gui:Destroy()
		end
	end)
	pcall(function()
		local core = game:GetService("CoreGui")
		for _, child in ipairs(core:GetChildren()) do
			if child.Name == "RedTigerKeySystem" or child.Name == "Xinve" then
				child:Destroy()
			end
		end
	end)
	pcall(function()
		if LocalPlayer ~= nil then
			for _, child in ipairs(LocalPlayer:GetChildren()) do
				if child:IsA("ScreenGui") and (child.Name == "RedTigerKeySystem" or child.Name == "Xinve") then
					child:Destroy()
				end
			end
		end
	end)
end

local function killSession(reason)
	_G.RedTigerSessionValid = false
	deleteSavedKey()
	-- les fichiers locaux
	pcall(function()
		if isfile ~= nil and delfile ~= nil and isfile(LOGS_FILE) then
			delfile(LOGS_FILE)
		end
	end)
	displayGui()
	pcall(function()
		LocalPlayer:Kick("RedTiger | " .. reason .. "\nLe panel a été fermé et supprimé. Demande a ton admin si besoin.")
	end)
	-- garde la coroutine bloquee (peu utile apres kick, mais par securite)
	while true do
		_wait(1)
	end
end

-- ================================================================
--  Verification : retourne ok, expiresUnix, tag
--  tag = "invalide" | "expire" | "serveur" | nil
-- ================================================================
local function checkKey(key)
	local data, dataErr = fetchKeysTable()
	if type(data) ~= "table" then
		return false, 0, "serveur", "Serveur injoignable, retente dans quelques secondes. (" .. tostring(dataErr) .. ")"
	end

	local entry = data[rtKeyHash(key)]
	if type(entry) ~= "table" then
		return false, 0, "invalide", "Clé invalide. Demande une clé a ton admin Discord."
	end

	local expires = tonumber(entry.expires) or 0
	if expires > 0 and os.time() >= expires then
		return false, expires, "expire", "Clé expiree. Demande-en une nouvelle ou un extension a ton admin."
	end

	return true, expires, nil, entry
end

-- ================================================================
--  Chargement du panel chiffré (SEULEMENT si clé valide)
-- ================================================================
local function loadPanelCode(userKey, entry)
	local pkeyB64 = tostring(type(entry) == "table" and entry.pkey or "")
	if #pkeyB64 == 0 then
		return nil, "Cette cle n'a pas d'acces au panel. Demande une nouvelle cle a ton admin."
	end
	local secret = rtDecryptPKey(pkeyB64, userKey)
	if secret == nil then
		return nil, "Acces au panel incorrect pour cette cle."
	end
	local blob, blobErr = httpGet(PANEL_ENC_URL)
	if blob == nil then
		return nil, "Telechargement du panel impossible (" .. tostring(blobErr) .. ")"
	end
	local code = rtDecryptBlob(blob, secret)
	if type(code) ~= "string" or #code < 64 then
		return nil, "Panel verrouille pour cette cle."
	end
	return code
end

local function launchPanel(userKey, entry)
	print("[RedTiger] Etape 3 : dechiffrement + chargement du panel...")
	local code, err = loadPanelCode(userKey, entry)
	if code == nil then
		guiStatus("❌ " .. tostring(err))
		print("[RedTiger] Chargement du panel impossible : " .. tostring(err))
		return
	end
	local fn, compileErr = loadstring(code)
	if fn == nil then
		warn("[RedTiger] Erreur de compilation du panel : " .. tostring(compileErr))
		guiStatus("❌ Erreur interne du panel.")
		return
	end
	local ok, runErr = pcall(fn)
	if not ok then
		warn("[RedTiger] Erreur d'execution du panel : " .. tostring(runErr))
	end
end

-- ================================================================
--  Validation (bouton / entree)
-- ================================================================
local function validate()
	local key = normalizeKey(keyBox.Text)
	if #key == 0 then
		guiStatus("⚠ Entre ta clé avant de valider.")
		return
	end

	guiStatus("Verification de la clé...")
	verifyButton.Text = "Verification..."

	local ok, expiresUnix, tag, message, entry = checkKey(key)
	if not ok then
		guiStatus("❌ " .. tostring(message))
		verifyButton.Text = "Valider"
		return
	end

	-- état global consommé par Panel.lua (garde + affichage temps restant)
	_G.RedTigerKey = {
		key = key,
		expiresUnix = tonumber(expiresUnix) or 0,
		hwid = HWID,
		user = tostring(LocalPlayer and LocalPlayer.UserId or "?"),
		game = tostring(game.Name or "?") .. "(" .. tostring(game.GameId or "?") .. ")",
	}
	_G.RedTigerSessionValid = true
	saveKey(key)

	local restantText = humanExpires(expiresUnix)
	guiStatus("✅ Clé valide ! Bienvenue sur RedTiger. (" .. restantText .. ")")
	verifyButton.Text = "Connecte"

	local playerName = tostring(LocalPlayer ~= nil and LocalPlayer.Name or "?")
	local gameName   = tostring(game.Name or "?") .. " (" .. tostring(game.GameId or "?") .. ")"
	appendLog("[" .. dateFr(os.time()) .. "] Connexion | clé=" .. key .. " | " .. playerName .. " | " .. gameName .. " | reste " .. restantText)
	-- le log Discord (webhook) est poste par le panel chiffre, pas ici

	_wait(0.8)
	displayGui()

	-- boucle locale : kill a la seconde pres quand l'horloge passe
	task.spawn(function()
		while true do
			_wait(10)
			if type(_G.RedTigerSessionValid) ~= "boolean" or not _G.RedTigerSessionValid then
				break -- deja tuée (par le panel par exemple)
			end
			local exp = tonumber(_G.RedTigerKey ~= nil and _G.RedTigerKey.expiresUnix or 0) or 0
			if exp > 0 and os.time() >= exp then
				killSession("Clé expirée (temps restant : 0).")
				break
			end
		end
	end)

	-- boucle distante : re-verification toutes les 2-3 min (detecte
	-- /delkey du bot, expirations l'echelle de temps, revocation)
	task.spawn(function()
		while true do
			_wait(180)
			if type(_G.RedTigerSessionValid) ~= "boolean" or not _G.RedTigerSessionValid then
				break
			end
			local currentKey = normalizeKey((_G.RedTigerKey or {}).key)
			local okr, expiresNow, tagR, messageR = checkKey(currentKey)
			if not okr then
				if tagR == "invalide" or tagR == "expire" then
					killSession("Clé " .. (tagR == "invalide" and "supprimée" or "expirée") .. " (recheck serveur)")
					break
				end
				-- tag "serveur" : réseau en panne -> on reaffiche rien, on retente plus tard
			else
				-- met à jour l'expiration si le bot a fait /extend
				_G.RedTigerKey.expiresUnix = expiresNow or 0
			end
		end
	end)

	launchPanel(key, entry)
end

verifyButton.MouseButton1Click:Connect(validate)
keyBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then validate() end
end)

guiStatus("Pret. Entre ta clé puis clique Valider (ou appuie sur Entree).")
