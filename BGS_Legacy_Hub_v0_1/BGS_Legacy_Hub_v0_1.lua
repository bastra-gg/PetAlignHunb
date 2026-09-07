-- BGS Legacy Hub v0.1.3 STARTUP-FIRST
-- UI is created first. Game-specific logic starts only after the window exists.

local VERSION = "0.1.3-startup-first"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LP = Players.LocalPlayer
while not LP do
    task.wait()
    LP = Players.LocalPlayer
end

local PlayerGui = LP:WaitForChild("PlayerGui")

local env = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then
        env = value
    end
end

if env.BGSLegacy and type(env.BGSLegacy.Stop) == "function" then
    pcall(function()
        env.BGSLegacy:Stop("reload")
    end)
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
if old then
    pcall(function() old:Destroy() end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "BGSLegacyHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(380, 350)
main.Position = UDim2.new(0.5, -190, 0.5, -175)
main.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
main.BorderSizePixel = 0
main.Parent = gui

local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 14)
mc.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(83, 105, 255)
stroke.Thickness = 1.4
stroke.Parent = main

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 8)
title.Size = UDim2.new(1, -55, 0, 24)
title.Text = "BGS LEGACY HUB  " .. VERSION
title.TextColor3 = Color3.fromRGB(245, 246, 252)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30, 28)
close.Position = UDim2.new(1, -40, 0, 8)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 13
close.TextColor3 = Color3.fromRGB(240, 240, 245)
close.BackgroundColor3 = Color3.fromRGB(43, 45, 57)
close.Parent = main
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 8)
cc.Parent = close

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(14, 38)
status.Size = UDim2.new(1, -28, 0, 34)
status.Text = "UI запущен"
status.TextColor3 = Color3.fromRGB(178, 183, 200)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = main

local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(12, 78)
body.Size = UDim2.new(1, -24, 1, -90)
body.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 7)
layout.Parent = body

local redraw = {}

local function addCorner(obj)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 9)
    c.Parent = obj
end

local function toggle(label, key)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 36)
    b.BackgroundColor3 = Color3.fromRGB(31, 33, 42)
    b.Text = ""
    b.Parent = body
    addCorner(b)

    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Position = UDim2.fromOffset(10, 0)
    l.Size = UDim2.new(1, -70, 1, 0)
    l.Text = label
    l.TextColor3 = Color3.fromRGB(236, 237, 244)
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = b

    local r = Instance.new("TextLabel")
    r.BackgroundTransparency = 1
    r.Position = UDim2.new(1, -55, 0, 0)
    r.Size = UDim2.fromOffset(45, 36)
    r.Font = Enum.Font.GothamBold
    r.TextSize = 12
    r.Parent = b

    local function draw()
        r.Text = S[key] and "ON" or "OFF"
        r.TextColor3 = S[key] and Color3.fromRGB(108, 132, 255) or Color3.fromRGB(145, 145, 155)
    end

    b.Activated:Connect(function()
        S[key] = not S[key]
        draw()
    end)

    redraw[key] = draw
    draw()
end

local function action(label, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 36)
    b.BackgroundColor3 = Color3.fromRGB(38, 40, 52)
    b.Text = label
    b.TextColor3 = Color3.fromRGB(239, 240, 248)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = body
    addCorner(b)
    b.Activated:Connect(callback)
    return b
end

toggle("Авто надувание", "autoBubble")
toggle("Авто открытие яйца", "autoHatch")
toggle("Идти к выбранному яйцу", "walkToEgg")
toggle("Авто сбор монет", "autoCollect")

local eggButton

eggButton = action("ЯЙЦО: скан...", function()
    if #S.eggs > 0 then
        S.eggIndex = (S.eggIndex % #S.eggs) + 1
        S.selectedEgg = S.eggs[S.eggIndex]
        eggButton.Text = "ЯЙЦО: " .. tostring(S.selectedEgg)
        S.status = "выбрано: " .. tostring(S.selectedEgg)
    else
        S.status = "яйца ещё не найдены"
    end
end)

action("ПЕРЕСКАНИРОВАТЬ ЯЙЦА", function()
    S.status = "скан..."
    task.spawn(function()
        local ok, err = pcall(function()
            local folder = workspace:FindFirstChild("Eggs")
            local list = {}
            if folder then
                for _, egg in ipairs(folder:GetChildren()) do
                    list[#list + 1] = egg.Name
                end
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
        if not ok then
            S.status = "scan error: " .. tostring(err)
        end
    end)
end)

action("HARD STOP", function()
    S.autoBubble = false
    S.autoHatch = false
    S.autoCollect = false
    S.walkToEgg = false
    for _, key in ipairs({"autoBubble", "autoHatch", "autoCollect", "walkToEgg"}) do
        if redraw[key] then redraw[key]() end
    end
    S.status = "всё остановлено"
end)

-- GAME LOGIC AFTER UI -------------------------------------------------------

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
    if direct and direct:IsA("RemoteEvent") then
        return direct
    end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = string.lower(obj.Name)
            if n == "networkremoteevent" or n:find("network", 1, true) then
                return obj
            end
        end
    end
end

local function scanEggs()
    local folder = workspace:FindFirstChild("Eggs")
    local list = {}
    if folder then
        for _, egg in ipairs(folder:GetChildren()) do
            list[#list + 1] = egg.Name
        end
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
    local best = nil
    local bestDist = 140
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("BasePart") and obj.Transparency < 1 then
            local d = (obj.Position - r.Position).Magnitude
            if d < bestDist then
                best = obj
                bestDist = d
            end
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
    if not ok then
        S.status = "init error: " .. tostring(err)
    end
end)

S.conns[#S.conns + 1] = RunService.Heartbeat:Connect(function()
    if not S.alive then return end

    status.Text = S.status

    local now = os.clock()

    if S.autoBubble and now - S.lastBubble >= 0.20 then
        S.lastBubble = now
        local ok, err = pcall(function()
            if not S.network or not S.network.Parent then
                S.network = findNetwork()
            end
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

            if not p or not r then
                scanEggs()
                return
            end

            local d = (p.Position - r.Position).Magnitude
            if d <= 14.5 then
                if not S.network or not S.network.Parent then
                    S.network = findNetwork()
                end
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

    for _, connection in ipairs(self.conns) do
        pcall(function() connection:Disconnect() end)
    end
    self.conns = {}

    pcall(function() gui:Destroy() end)
    self.status = "stopped: " .. tostring(reason or "manual")
end

close.Activated:Connect(function()
    S:Stop("closed")
end)

S.startupReady = true
print("BGS Legacy Hub " .. VERSION .. " loaded")
return S
