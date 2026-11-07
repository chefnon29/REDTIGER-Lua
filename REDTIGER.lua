local RT_DEBUG = false
local function rtLog(...)
if RT_DEBUG then print(...) end
end
rtLog("[RedTiger] Version loader : v1.5");
rtLog("[RedTiger] Loader demarre - verification de la clé...")
rtLog("[RedTiger] Executor : " .. (function()
local ok, name = pcall(function() return getExecutorName and getExecutorName() or "inconnu" end)
return ok and tostring(name) or "inconnu"
end)())
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local _w1  = "https://raw.githubuser" .. "content.com/chefnon" .. "29/REDTIGER-Lua" .. "/refs/heads/main"
local _w2  = "https://api.github.co" .. "m/repos/chefnon29/R" .. "EDTIGER-Lua/con" .. "tents/keys.json"
local KEYS_RAW  = _w1 .. "/keys.json"
local _w3 = _w1 .. "/Panel.enc.lua"
local KEY_FILE  = "RedTiger/key.txt"
local _w4 = "RedTi" .. "ger/" .. "logs" .. ".txt"
local _w6 = wait
local function _x1(seconds)
if task ~= nil and task.wait ~= nil then return task.wait(seconds) end
return _w6(seconds)
end
local function _x2(url)
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
_x1(0.4)
end
return nil, lastError
end
local function _x5(input)
local key = tostring(input or ""):upper()
key = key:gsub("%s", "")
return key
end
local function _x9(key)
pcall(function()
if writefile then
if isfolder ~= nil and makefolder ~= nil and not isfolder("RedTiger") then
makefolder("RedTiger")
end
writefile(KEY_FILE, key)
end
end)
end
local function _x7()
pcall(function()
if delfile ~= nil and isfile ~= nil and isfile(KEY_FILE) then
delfile(KEY_FILE)
end
end)
end
local function _x6(line)
pcall(function()
if appendfile then
if isfolder ~= nil and makefolder ~= nil and not isfolder("RedTiger") then
makefolder("RedTiger")
end
appendfile(_w4, line .. "\n")
end
end)
end
local function _z5()
local key
pcall(function()
if readfile ~= nil and isfile ~= nil and isfile(KEY_FILE) then
key = readfile(KEY_FILE)
end
end)
if type(key) == "string" and #key > 0 then
return _x5(key)
end
return nil
end
local function _x3(timestamp)
local ok, result = pcall(function()
return os.date("%d/%m/%Y a %H:%M", timestamp)
end)
if ok and result ~= nil then return tostring(result) end
return "date inconnue"
end
local _w5 = "unknown"
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
_w5 = id
end
local function _x4(expiresNow)
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
local B64CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function _y9(data)
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
local _w0 = "65DF14AEB" .. "7D7660D07" .. "8D639EA" .. "F40E144"
local function _z1(a, b)
local al = a % 65536
local ah = (a - al) / 65536
local bl = b % 65536
local bh = (b - bl) / 65536
local lo = al * bl
local mid = (al * bh + ah * bl) % 65536
return (lo + mid * 65536) % 4294967296
end
local function _z0(s)
local t = {}
for i = 1, #s do t[i] = string.byte(s, i) end
return t
end
local function _z3(msg, saltStr)
local h = 0x811C9DC5
local function mix(b)
h = bit32.bxor(h, b)
h = _z1(h, 0x01000193)
h = bit32.bxor(h, bit32.lrotate(h, 7))
end
for _, b in ipairs(_z0(saltStr)) do mix(b) end
for _, b in ipairs(_z0(msg)) do mix(b) end
h = bit32.bxor(h, bit32.rshift(h, 16))
h = _z1(h, 0x85EBCA6B)
h = bit32.bxor(h, bit32.rshift(h, 13))
h = _z1(h, 0xC2B2AE35)
h = bit32.bxor(h, bit32.rshift(h, 16))
return h
end
local function _z2(h)
return string.upper(string.format("%08x", h))
end
local function _z4(msg, salt)
return _z2(_z3(msg, salt)) .. _z2(_z3(msg, salt .. "#2"))
end
local function _z6(key)
return _z4(key, _w0 .. "/key/")
end
local function _z7(secret)
local x = _z3(secret, "rt/cipher/1")
local y = _z3(secret, "rt/cipher/2")
local z = _z3(secret, "rt/cipher/3")
local d = _z3(secret, "rt/cipher/4")
return function()
local t = bit32.bxor(x, bit32.lshift(x, 11))
x = y
y = z
z = d
d = bit32.bxor(bit32.bxor(d, bit32.rshift(d, 19)), bit32.bxor(t, bit32.rshift(t, 8)))
return bit32.band(d, 255)
end
end
local B64VAL_RT = {}
do
for i = 1, #B64CHARS do
B64VAL_RT[string.byte(B64CHARS, i)] = i - 1
end
end
local function _y8(b64)
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
local function _z8(pkeyB64, userKey)
local raw = _y9(tostring(pkeyB64 or ""))
if type(raw) ~= "string" or #raw == 0 then return nil end
local nextByte = _z7(userKey)
local out = {}
for i = 1, #raw do
out[i] = string.char(bit32.band(bit32.bxor(string.byte(raw, i), nextByte()), 255))
end
local k = table.concat(out)
if #k == 16 then return k end
return nil
end
local function _z9(b64, secret)
local bytes = _y8(tostring(b64 or ""))
local nextByte = _z7(secret)
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
local function _y7()
local ok, envelope = pcall(function()
local raw = _x2(_w2)
return HttpService:JSONDecode(raw)
end)
if ok and type(envelope) == "table" and type(envelope.content) == "string" then
local decoded = _y9(envelope.content)
if decoded and #decoded > 0 then
local jsonOk, data = pcall(function() return HttpService:JSONDecode(decoded) end)
if jsonOk and type(data) == "table" then
return data
end
end
end
local res, resError = _x2(KEYS_RAW)
if res == nil then
return false, resError
end
local jsonOk, data = pcall(function() return HttpService:JSONDecode(res) end)
if jsonOk and type(data) == "table" then
return data
end
return false, "JSON invalide"
end
local statusLabel, keyBox, verifyButton
local function _y1(text)
pcall(function()
if statusLabel ~= nil then statusLabel.Text = tostring(text) end
end)
end
local success, gui = pcall(function()
local screenGui        = Instance.new("ScreenGui")
screenGui.Name         = "RedTigerKeySystem"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
clientIdLabel.Text = "Ton ID unique : " .. _w5
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
keyBox.Text       = _z5() or ""
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
rtLog("[RedTiger] Etape 2 : fenetre de clé creee")
if not success or gui == nil then
rtLog("[RedTiger] ERREUR popup normale : " .. tostring(gui) .. " -> popup de secours")
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
_G.RedTigerSessionValid = false
local function _y2()
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
local function _y3(reason)
_G.RedTigerSessionValid = false
_x7()
pcall(function()
if isfile ~= nil and delfile ~= nil and isfile(_w4) then
delfile(_w4)
end
end)
_y2()
pcall(function()
LocalPlayer:Kick("RedTiger | " .. reason .. "\nLe panel a été fermé et supprimé. Demande a ton admin si besoin.")
end)
while true do
_x1(1)
end
end
local function _y6(key)
local data, dataErr = _y7()
if type(data) ~= "table" then
return false, 0, "serveur", "Serveur injoignable, retente dans quelques secondes. (" .. tostring(dataErr) .. ")"
end
local entry = data[_z6(key)]
if type(entry) ~= "table" then
return false, 0, "invalide", "Clé invalide. Demande une clé a ton admin Discord."
end
local expires = tonumber(entry.expires) or 0
if expires > 0 and os.time() >= expires then
return false, expires, "expire", "Clé expiree. Demande-en une nouvelle ou un extension a ton admin."
end
local lhwid = tostring(type(entry) == "table" and entry.hwid or "")
if #lhwid > 0 and lhwid ~= _z4(_w5, _w0 .. "/hwid/") then
return false, expires, "pris", "Cle deja utilisee sur un autre PC. Une seule personne par cle : demande une nouvelle cle a ton admin."
end
return true, expires, "ok", "", entry
end
local function _y5(userKey, entry)
local pkeyB64 = tostring(type(entry) == "table" and entry.pkey or "")
if #pkeyB64 == 0 then
return nil, "Cette cle n'a pas d'acces au panel. Demande une nouvelle cle a ton admin."
end
local secret = _z8(pkeyB64, userKey)
if secret == nil then
return nil, "Acces au panel incorrect pour cette cle."
end
local blob, blobErr = _x2(_w3)
if blob == nil then
return nil, "Telechargement du panel impossible (" .. tostring(blobErr) .. ")"
end
local code = _z9(blob, secret)
if type(code) ~= "string" or #code < 64 then
return nil, "Panel verrouille pour cette cle."
end
return code
end
local function _y4(userKey, entry)
rtLog("[RedTiger] Etape 3 : dechiffrement + chargement du panel...")
local code, err = _y5(userKey, entry)
if code == nil then
_y1("❌ " .. tostring(err))
rtLog("[RedTiger] Chargement du panel impossible : " .. tostring(err))
return
end
local fn, compileErr = loadstring(code)
if fn == nil then
rtLog("[RedTiger] Erreur de compilation du panel : " .. tostring(compileErr))
_y1("❌ Erreur interne du panel.")
return
end
local ok, runErr = pcall(fn)
if not ok then
rtLog("[RedTiger] Erreur d'execution du panel : " .. tostring(runErr))
end
end
local function _x0()
local key = _x5(keyBox.Text)
if #key == 0 then
_y1("⚠ Entre ta clé avant de valider.")
return
end
_y1("Verification de la clé...")
verifyButton.Text = "Verification..."
local ok, expiresUnix, tag, message, entry = _y6(key)
if not ok then
_y1("❌ " .. tostring(message))
verifyButton.Text = "Valider"
if tag == "invalide" or tag == "expire" or tag == "pris" then
_x7()
end
return
end
_G.RedTigerKey = {
key = key,
expiresUnix = tonumber(expiresUnix) or 0,
hwid = _w5,
user = tostring(LocalPlayer and LocalPlayer.UserId or "?"),
game = tostring(game.Name or "?") .. "(" .. tostring(game.GameId or "?") .. ")",
}
_G.RedTigerSessionValid = true
_x9(key)
local restantText = _x4(expiresUnix)
_y1("✅ Clé valide ! Bienvenue sur RedTiger. (" .. restantText .. ")")
verifyButton.Text = "Connecte"
local playerName = tostring(LocalPlayer ~= nil and LocalPlayer.Name or "?")
local gameName   = tostring(game.Name or "?") .. " (" .. tostring(game.GameId or "?") .. ")"
_x6("[" .. _x3(os.time()) .. "] Connexion | clé=" .. key .. " | " .. playerName .. " | " .. gameName .. " | reste " .. restantText)
_x1(0.8)
_y2()
task.spawn(function()
while true do
_x1(10)
if type(_G.RedTigerSessionValid) ~= "boolean" or not _G.RedTigerSessionValid then
break -- deja tuée (par le panel par exemple)
end
local exp = tonumber(_G.RedTigerKey ~= nil and _G.RedTigerKey.expiresUnix or 0) or 0
if exp > 0 and os.time() >= exp then
_y3("Clé expirée (temps restant : 0).")
break
end
end
end)
task.spawn(function()
while true do
_x1(180)
if type(_G.RedTigerSessionValid) ~= "boolean" or not _G.RedTigerSessionValid then
break
end
local currentKey = _x5((_G.RedTigerKey or {}).key)
local okr, expiresNow, tagR, messageR = _y6(currentKey)
if not okr then
if tagR == "invalide" or tagR == "expire" then
_y3("Clé " .. (tagR == "invalide" and "supprimée" or "expirée") .. " (recheck serveur)")
break
end
else
_G.RedTigerKey.expiresUnix = expiresNow or 0
end
end
end)
_y4(key, entry)
return true
end
verifyButton.MouseButton1Click:Connect(_x0)
keyBox.FocusLost:Connect(function(enterPressed)
if enterPressed then _x0() end
end)
_y1("Pret. Entre ta clé puis clique Valider (ou appuie sur Entree).")
do
local saved = _z5()
if type(saved) == "string" and #saved > 0 then
rtLog("[RedTiger] Cle sauvegardee trouvee : autologin...")
keyBox.Text = saved
pcall(function()
gui.Enabled = false
end)
local okAuto = _x0()
if okAuto ~= true then
pcall(function()
_y1("Entre ta nouvelle clé.")
end)
pcall(function()
keyBox.Text = ""
end)
pcall(function()
gui.Enabled = true
end)
end
end
end
