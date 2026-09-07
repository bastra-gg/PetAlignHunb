-- BGS Legacy Hub v0.1.4 WINDOW UI
-- UI first, compact draggable window, minimize support.

local VERSION = "0.1.4-window-ui"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not game:IsLoaded() then game.Loaded:Wait() end

local LP = Players.LocalPlayer
while not LP do task.wait() LP = Players.LocalPlayer end
local PlayerGui = LP:WaitForChild("PlayerGui")

local env = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then env = value end
end

if env.BGSLegacy and type(env.BGSLegacy.Stop) == "function" then
    pcall(function() env.BGSLegacy:Stop("reload") end)
end

local S = {
    alive = true,
    startupReady = false,
    autoBubble = false,
    autoHatch = false,
    autoCollect = false,
    walkToEgg = false,
    selectedEgg = nil,
    eggs = {},
    eggIndex = 1,
    status = "UI запущен",
    conns = {},
    network = nil,
    lastBubble = 0,
    lastHatch = 0,
    lastCollect = 0,
}
env.BGSLegacy = S

-- UI FIRST -----------------------------------------------------------------

local old = PlayerGui:FindFirstChild("BGSLegacyHub")
if old then pcall(function() old:Destroy() end) end

local gui = Instance.new("ScreenGui")
gui.Name = "BGSLegacyHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.IgnoreGuiInset = false
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(360, 300)
main.Position = UDim2.new(0.5, -180, 0.5, -150)
main.BackgroundColor3 = Color3.fromRGB(15, 16, 21)
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
main.Parent = gui

local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 13)
mc.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(83, 105, 255)
stroke.Thickness = 1.3
stroke.Transparency = 0.15
stroke.Parent = main

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = Color3.fromRGB(23, 24, 31)
header.BorderSizePixel = 0
header.Active = true
header.Parent = main

local hc = Instance.new("UICorner")
hc.CornerRadius = UDim.new(0, 13)
hc.Parent = header

local headerMask = Instance.new("Frame")
headerMask.Size = UDim2.new(1, 0, 0, 14)
headerMask.Position = UDim2.new(0, 0, 1, -14)
headerMask.BackgroundColor3 = header.BackgroundColor3
headerMask.BorderSizePixel = 0
headerMask.Parent = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(13, 4)
title.Size = UDim2.new(1, -92, 0, 20)
title.Text = "BGS LEGACY HUB"
title.TextColor3 = Color3.fromRGB(246, 246, 251)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.fromOffset(13, 23)
sub.Size = UDim2.new(1, -92, 0, 14)
sub.Text = "v" .. VERSION
sub.TextColor3 = Color3.fromRGB(132, 139, 164)
sub.Font = Enum.Font.Gotham
sub.TextSize = 9
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Parent = header

local function headButton(text, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(30, 28)
    b.Position = UDim2.new(1, x, 0, 8)
    b.BackgroundColor3 = Color3.fromRGB(42, 44, 56)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(235, 237, 245)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = true
    b.Parent = header
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = b
    return b
end

local minimize = headButton("—", -72)
local close = headButton("×", -38)

local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(0, 44)
content.Size = UDim2.new(1, 0, 1, -44)
content.Parent = main

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(13, 5)
status.Size = UDim2.new(1, -26, 0, 26)
status.Text = "UI запущен"
status.TextColor3 = Color3.fromRGB(176, 181, 199)
status.Font = Enum.Font.Gotham
status.TextSize = 10
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = content

local tabs = Instance.new("Frame")
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.fromOffset(10, 35)
tabs.Size = UDim2.new(1, -20, 0, 32)
tabs.Parent = content

local pagesHolder = Instance.new("Frame")
pagesHolder.BackgroundTransparency = 1
pagesHolder.Position = UDim2.fromOffset(10, 73)
pagesHolder.Size = UDim2.new(1, -20, 1, -82)
pagesHolder.Parent = content

local pageNames = {"ФАРМ", "ЯЙЦА", "ДРУГОЕ"}
local pages = {}
local tabButtons = {}

local function addCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
end

for i, name in ipairs(pageNames) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1/3, -4, 1, 0)
    b.Position = UDim2.new((i-1)/3, (i-1)*2, 0, 0)
    b.BackgroundColor3 = Color3.fromRGB(31, 33, 42)
    b.Text = name
    b.TextColor3 = Color3.fromRGB(178, 182, 196)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Parent = tabs
    addCorner(b, 8)
    tabButtons[i] = b

    local p = Instance.new("Frame")
    p.Name = name
    p.Size = UDim2.fromScale(1, 1)
    p.BackgroundTransparency = 1
    p.Visible = i == 1
    p.Parent = pagesHolder

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 7)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = p
    pages[i] = p
end

local function showTab(index)
    for i, p in ipairs(pages) do
        p.Visible = i == index
        tabButtons[i].BackgroundColor3 = i == index and Color3.fromRGB(69, 82, 166) or Color3.fromRGB(31, 33, 42)
        tabButtons[i].TextColor3 = i == index and Color3.fromRGB(248, 248, 252) or Color3.fromRGB(178, 182, 196)
    end
end
for i, b in ipairs(tabButtons) do b.Activated:Connect(function() showTab(i) end) end
showTab(1)

local redraw = {}

local function toggle(parent, label, key)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = Color3.fromRGB(29, 31, 39)
    b.Text = ""
    b.Parent = parent
    addCorner(b, 9)

    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Position = UDim2.fromOffset(11, 0)
    l.Size = UDim2.new(1, -72, 1, 0)
    l.Text = label
    l.TextColor3 = Color3.fromRGB(235, 236, 243)
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = b

    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromOffset(42, 20)
    pill.Position = UDim2.new(1, -53, 0.5, -10)
    pill.BorderSizePixel = 0
    pill.Parent = b
    addCorner(pill, 20)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(16, 16)
    dot.BorderSizePixel = 0
    dot.Parent = pill
    addCorner(dot, 20)

    local function draw()
        local on = S[key]
        pill.BackgroundColor3 = on and Color3.fromRGB(78, 98, 219) or Color3.fromRGB(63, 65, 76)
        dot.BackgroundColor3 = on and Color3.fromRGB(244, 246, 255) or Color3.fromRGB(185, 187, 196)
        dot.Position = on and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2)
    end

    b.Activated:Connect(function()
        S[key] = not S[key]
        draw()
    end)
    redraw[key] = draw
    draw()
end

local function action(parent, label, callback, accent)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = accent and Color3.fromRGB(67, 35, 44) or Color3.fromRGB(36, 38, 49)
    b.Text = label
    b.TextColor3 = accent and Color3.fromRGB(255, 226, 231) or Color3.fromRGB(239, 240, 247)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Parent = parent
    addCorner(b, 9)
    b.Activated:Connect(callback)
    return b
end

toggle(pages[1], "Авто надувание", "autoBubble")
toggle(pages[1], "Авто открытие яйца", "autoHatch")
toggle(pages[1], "Авто сбор монет", "autoCollect")

toggle(pages[2], "Идти к выбранному яйцу", "walkToEgg")

local eggButton
eggButton = action(pages[2], "ЯЙЦО: скан...", function()
    if #S.eggs > 0 then
        S.eggIndex = (S.eggIndex % #S.eggs) + 1
        S.selectedEgg = S.eggs[S.eggIndex]
        eggButton.Text = "ЯЙЦО: " .. tostring(S.selectedEgg)
        S.status = "выбрано: " .. tostring(S.selectedEgg)
    else
        S.status = "яйца ещё не найдены"
    end
end)

action(pages[2], "ПЕРЕСКАНИРОВАТЬ ЯЙЦА", function()
    S.status = "скан..."
    task.spawn(function()
        local ok, err = pcall(function()
            local folder = workspace:FindFirstChild("Eggs")
            local list = {}
            if folder then
                for _, egg in ipairs(folder:GetChildren()) do list[#list + 1] = egg.Name end
            end
            table.sort(list)
            S.eggs = list
            if #list > 0 then
                S.eggIndex = 1
                S.selectedEgg = list[1]
                eggButton.Text = "ЯЙЦО: " .. tostring(S.selectedEgg)
                S.status = "найдено яиц: " .. tostring(#list)
            else
                S.selectedEgg = nil
                eggButton.Text = "ЯЙЦО: не найдено"
                S.status = "workspace.Eggs пуст / нет"
            end
        end)
        if not ok then S.status = "scan error: " .. tostring(err) end
    end)
end)

action(pages[3], "HARD STOP ВСЕГО", function()
    S.autoBubble = false
    S.autoHatch = false
    S.autoCollect = false
    S.walkToEgg = false
    for _, key in ipairs({"autoBubble", "autoHatch", "autoCollect", "walkToEgg"}) do
        if redraw[key] then redraw[key]() end
    end
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then pcall(function() h:Move(Vector3.zero, false) end) end
    S.status = "всё остановлено"
end, true)

-- DRAG + MINIMIZE -----------------------------------------------------------

local dragging = false
local dragStart = nil
local startPos = nil

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

S.conns[#S.conns + 1] = UserInputService.InputChanged:Connect(function(input)
    if dragging and dragStart and startPos then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end
end)

S.conns[#S.conns + 1] = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local minimized = false
minimize.Activated:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    main.Size = minimized and UDim2.fromOffset(360, 44) or UDim2.fromOffset(360, 300)
    minimize.Text = minimized and "+" or "—"
end)

-- GAME LOGIC ---------------------------------------------------------------

local function rootPart()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function findNetwork()
    local direct = ReplicatedStorage:FindFirstChild("NetworkRemoteEvent")
    if direct and direct:IsA("RemoteEvent") then return direct end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = string.lower(obj.Name)
            if n == "networkremoteevent" or n:find("network", 1, true) then return obj end
        end
    end
end

local function scanEggs()
    local folder = workspace:FindFirstChild("Eggs")
    local list = {}
    if folder then
        for _, egg in ipairs(folder:GetChildren()) do list[#list + 1] = egg.Name end
    end
    table.sort(list)
    S.eggs = list
    if #list > 0 then
        if not S.selectedEgg or not folder:FindFirstChild(S.selectedEgg) then
            S.eggIndex = 1
            S.selectedEgg = list[1]
        end
        eggButton.Text = "ЯЙЦО: " .. tostring(S.selectedEgg)
    end
end

local function eggPart(name)
    local folder = workspace:FindFirstChild("Eggs")
    local egg = folder and name and folder:FindFirstChild(name)
    if not egg then return nil end
    local hotkey = egg:FindFirstChild("Hotkey", true)
    if hotkey and hotkey:IsA("BasePart") then return hotkey end
    if hotkey and hotkey:IsA("Attachment") and hotkey.Parent and hotkey.Parent:IsA("BasePart") then return hotkey.Parent end
    if egg:IsA("BasePart") then return egg end
    return egg:FindFirstChildWhichIsA("BasePart", true)
end

local function nearestPickup()
    local folder = workspace:FindFirstChild("Pickups")
    local r = rootPart()
    if not folder or not r then return nil end
    local best, bestDist = nil, 140
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("BasePart") and obj.Transparency < 1 then
            local d = (obj.Position - r.Position).Magnitude
            if d < bestDist then best, bestDist = obj, d end
        end
    end
    return best
end

task.spawn(function()
    local ok, err = pcall(function()
        S.network = findNetwork()
        scanEggs()
        S.status = "готово | remote " .. (S.network and "OK" or "нет") .. " | eggs " .. tostring(#S.eggs)
    end)
    if not ok then S.status = "init error: " .. tostring(err) end
end)

S.conns[#S.conns + 1] = RunService.Heartbeat:Connect(function()
    if not S.alive then return end
    status.Text = S.status
    local now = os.clock()

    if S.autoBubble and now - S.lastBubble >= 0.20 then
        S.lastBubble = now
        local ok, err = pcall(function()
            if not S.network or not S.network.Parent then S.network = findNetwork() end
            if S.network then
                S.network:FireServer("BlowBubble")
                S.status = "надуваю"
            else
                S.status = "remote не найден"
            end
        end)
        if not ok then S.status = "bubble error: " .. tostring(err) end
    end

    if S.autoHatch and now - S.lastHatch >= 0.65 then
        S.lastHatch = now
        local ok, err = pcall(function()
            local p = eggPart(S.selectedEgg)
            local r = rootPart()
            local h = humanoid()
            if not p or not r then scanEggs() return end
            local d = (p.Position - r.Position).Magnitude
            if d <= 14.5 then
                if not S.network or not S.network.Parent then S.network = findNetwork() end
                if S.network then
                    S.network:FireServer("PurchaseEgg", S.selectedEgg)
                    S.status = "открываю " .. tostring(S.selectedEgg)
                else
                    S.status = "remote не найден"
                end
            elseif S.walkToEgg and h then
                h:MoveTo(p.Position)
                S.status = "иду к яйцу | " .. tostring(math.floor(d)) .. " studs"
            else
                S.status = "подойди к яйцу | " .. tostring(math.floor(d)) .. " studs"
            end
        end)
        if not ok then S.status = "hatch error: " .. tostring(err) end
    end

    if S.autoCollect and now - S.lastCollect >= 0.30 then
        S.lastCollect = now
        local ok, err = pcall(function()
            local p = nearestPickup()
            local h = humanoid()
            if p and h then
                h:MoveTo(p.Position)
                S.status = "собираю монеты"
            else
                S.status = "монеты рядом не найдены"
            end
        end)
        if not ok then S.status = "collect error: " .. tostring(err) end
    end
end)

function S:Stop(reason)
    if not self.alive then return end
    self.alive = false
    self.autoBubble = false
    self.autoHatch = false
    self.autoCollect = false
    self.walkToEgg = false
    for _, connection in ipairs(self.conns) do pcall(function() connection:Disconnect() end) end
    self.conns = {}
    pcall(function() gui:Destroy() end)
    self.status = "stopped: " .. tostring(reason or "manual")
end

close.Activated:Connect(function() S:Stop("closed") end)

S.startupReady = true
print("BGS Legacy Hub " .. VERSION .. " loaded")
return S
