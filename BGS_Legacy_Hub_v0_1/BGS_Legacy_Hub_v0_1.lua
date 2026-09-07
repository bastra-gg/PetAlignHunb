-- BGS Legacy Hub v0.1.2 SAFE
-- Startup-fixed build for the user's own Bubble Gum Simulator-style game/server.
-- No teleports, no anti-cheat bypass. Includes light rate limits and hard stop.

local VERSION = "0.1.2-safe"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

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
    safeMode = true,
    autoBubble = false,
    autoHatch = false,
    walkToEgg = false,
    autoCollect = false,

    selectedEgg = nil,
    eggs = {},
    eggIndex = 1,

    collectRadius = 140,
    status = "SAFE готово",
    conns = {},

    failures = 0,
    maxFailures = 5,
    pausedUntil = 0,
    respawnGraceUntil = 0,

    remoteTimes = {},
    maxRemotePerSecond = 7,
    lastFire = {},
    lastMove = 0,
    moveDelay = 0.28,
}

env.BGSLegacy = S

local function rootPart()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function characterReady()
    local h = humanoid()
    local r = rootPart()
    return h ~= nil and r ~= nil and h.Health > 0
end

local redraw = {}

local function redrawAutomation()
    for _, key in ipairs({"autoBubble", "autoHatch", "walkToEgg", "autoCollect"}) do
        if redraw[key] then
            redraw[key]()
        end
    end
end

local function stopAutomation(reason)
    S.autoBubble = false
    S.autoHatch = false
    S.walkToEgg = false
    S.autoCollect = false
    S.status = "SAFE STOP: " .. tostring(reason or "manual")
    redrawAutomation()
end

local function fail(reason)
    S.failures = S.failures + 1
    S.status = "ошибка " .. tostring(S.failures) .. "/" .. tostring(S.maxFailures) .. ": " .. tostring(reason)
    S.pausedUntil = os.clock() + math.min(4, 0.8 * S.failures)

    if S.failures >= S.maxFailures then
        stopAutomation("слишком много ошибок")
    end
end

local function success()
    if S.failures > 0 then
        S.failures = math.max(0, S.failures - 1)
    end
end

local function findNetwork()
    local direct = ReplicatedStorage:FindFirstChild("NetworkRemoteEvent")
    if direct and direct:IsA("RemoteEvent") then
        return direct
    end

    for _, object in ipairs(ReplicatedStorage:GetDescendants()) do
        if object:IsA("RemoteEvent") then
            local name = string.lower(object.Name)
            if name == "networkremoteevent" or name:find("network", 1, true) then
                return object
            end
        end
    end

    return nil
end

local Network = findNetwork()

local function pruneBudget(now)
    local fresh = {}
    for _, stamp in ipairs(S.remoteTimes) do
        if now - stamp < 1 then
            fresh[#fresh + 1] = stamp
        end
    end
    S.remoteTimes = fresh
end

local function budgetOK(now)
    pruneBudget(now)
    return #S.remoteTimes < S.maxRemotePerSecond
end

local function fire(action, delaySeconds, ...)
    local args = {...}
    local now = os.clock()

    if now < S.pausedUntil or now < S.respawnGraceUntil then
        return false
    end

    if not characterReady() then
        return false
    end

    if not Network or not Network.Parent then
        Network = findNetwork()
    end

    if not Network then
        fail("NetworkRemoteEvent не найден")
        return false
    end

    if now - (S.lastFire[action] or 0) < delaySeconds then
        return false
    end

    if S.safeMode and not budgetOK(now) then
        S.status = "SAFE: лимит remote/sec"
        return false
    end

    S.lastFire[action] = now
    if S.safeMode then
        S.remoteTimes[#S.remoteTimes + 1] = now
    end

    local ok, err = pcall(function()
        Network:FireServer(action, table.unpack(args))
    end)

    if not ok then
        fail(err)
        return false
    end

    success()
    return true
end

local function eggHotkey(egg)
    if not egg then
        return nil
    end

    local hotkey = egg:FindFirstChild("Hotkey", true)
    if hotkey then
        if hotkey:IsA("BasePart") then
            return hotkey
        end
        if hotkey:IsA("Attachment") and hotkey.Parent and hotkey.Parent:IsA("BasePart") then
            return hotkey.Parent
        end
    end

    if egg:IsA("BasePart") then
        return egg
    end

    return egg:FindFirstChildWhichIsA("BasePart", true)
end

local function scanEggs()
    local folder = workspace:FindFirstChild("Eggs")
    local names = {}

    if folder then
        for _, egg in ipairs(folder:GetChildren()) do
            if eggHotkey(egg) then
                names[#names + 1] = egg.Name
            end
        end
    end

    table.sort(names)
    S.eggs = names

    if #names == 0 then
        S.selectedEgg = nil
        S.eggIndex = 1
        S.status = "workspace.Eggs не найден/пуст"
        return
    end

    local found = false
    if S.selectedEgg then
        for index, name in ipairs(names) do
            if name == S.selectedEgg then
                S.eggIndex = index
                found = true
                break
            end
        end
    end

    if not found then
        S.eggIndex = 1
        S.selectedEgg = names[1]
    end

    S.status = "SAFE | яиц найдено: " .. tostring(#names)
end

local function selectedEggInstance()
    local folder = workspace:FindFirstChild("Eggs")
    if not folder or not S.selectedEgg then
        return nil
    end
    return folder:FindFirstChild(S.selectedEgg)
end

local function distanceTo(part)
    local r = rootPart()
    if not r or not part then
        return math.huge
    end
    return (r.Position - part.Position).Magnitude
end

local function moveTo(position, maxDistance)
    local now = os.clock()

    if now < S.pausedUntil or now < S.respawnGraceUntil then
        return false
    end

    if now - S.lastMove < S.moveDelay then
        return false
    end

    local h = humanoid()
    local r = rootPart()
    if not h or not r or h.Health <= 0 then
        return false
    end

    local distance = (position - r.Position).Magnitude
    if S.safeMode and distance > (maxDistance or S.collectRadius) then
        S.status = "SAFE: цель слишком далеко"
        return false
    end

    S.lastMove = now

    local ok, err = pcall(function()
        h:MoveTo(position)
    end)

    if not ok then
        fail(err)
        return false
    end

    return true
end

local function nearestPickup()
    local folder = workspace:FindFirstChild("Pickups")
    local r = rootPart()

    if not folder or not r then
        return nil, nil
    end

    local best = nil
    local bestDistance = S.collectRadius

    for _, object in ipairs(folder:GetChildren()) do
        if object:IsA("BasePart") and object.Transparency < 1 then
            local distance = (r.Position - object.Position).Magnitude
            local name = string.lower(object.Name)
            local looksLikePickup = object:FindFirstChild("TouchInterest") ~= nil
                or object.Name == "Part"
                or name:find("coin", 1, true) ~= nil
                or name:find("gem", 1, true) ~= nil
                or name:find("pickup", 1, true) ~= nil
                or name:find("currency", 1, true) ~= nil

            if looksLikePickup and distance < bestDistance then
                best = object
                bestDistance = distance
            end
        end
    end

    return best, bestDistance
end

-- UI ----------------------------------------------------------------------

local oldGui = PlayerGui:FindFirstChild("BGSLegacyHub")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "BGSLegacyHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(390, 392)
main.Position = UDim2.new(0.5, -195, 0.5, -196)
main.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(84, 105, 255)
mainStroke.Thickness = 1.3
mainStroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = Color3.fromRGB(24, 25, 33)
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 14)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(13, 0)
title.Size = UDim2.new(1, -60, 1, 0)
title.Text = "BGS LEGACY HUB  " .. VERSION
title.TextColor3 = Color3.fromRGB(245, 245, 250)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(32, 30)
close.Position = UDim2.new(1, -40, 0, 9)
close.BackgroundColor3 = Color3.fromRGB(45, 47, 60)
close.Text = "×"
close.TextSize = 19
close.TextColor3 = Color3.new(1, 1, 1)
close.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = close

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(13, 52)
statusLabel.Size = UDim2.new(1, -26, 0, 34)
statusLabel.TextColor3 = Color3.fromRGB(180, 184, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.Parent = main

local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(12, 91)
body.Size = UDim2.new(1, -24, 1, -103)
body.Parent = main

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 7)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = body

local function round(object)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = object
end

local function makeToggle(label, key)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 36)
    button.BackgroundColor3 = Color3.fromRGB(31, 33, 42)
    button.Text = ""
    button.Parent = body
    round(button)

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Position = UDim2.fromOffset(10, 0)
    text.Size = UDim2.new(1, -70, 1, 0)
    text.Text = label
    text.TextColor3 = Color3.fromRGB(235, 236, 244)
    text.Font = Enum.Font.GothamMedium
    text.TextSize = 13
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = button

    local state = Instance.new("TextLabel")
    state.BackgroundTransparency = 1
    state.Position = UDim2.new(1, -55, 0, 0)
    state.Size = UDim2.fromOffset(45, 36)
    state.Font = Enum.Font.GothamBold
    state.TextSize = 12
    state.Parent = button

    local function draw()
        state.Text = S[key] and "ON" or "OFF"
        state.TextColor3 = S[key] and Color3.fromRGB(108, 132, 255) or Color3.fromRGB(145, 145, 155)
    end

    button.Activated:Connect(function()
        S[key] = not S[key]
        draw()
    end)

    redraw[key] = draw
    draw()
end

local function makeAction(label, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 36)
    button.BackgroundColor3 = Color3.fromRGB(38, 40, 52)
    button.Text = label
    button.TextColor3 = Color3.fromRGB(239, 240, 248)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.Parent = body
    round(button)
    button.Activated:Connect(callback)
    return button
end

makeToggle("SAFE MODE", "safeMode")
makeToggle("Авто надувание", "autoBubble")
makeToggle("Авто открытие яйца", "autoHatch")
makeToggle("Самому идти к яйцу", "walkToEgg")
makeToggle("Авто сбор монет / валюты", "autoCollect")

local eggButton
eggButton = makeAction("ЯЙЦО: скан...", function()
    if #S.eggs == 0 then
        scanEggs()
    end

    if #S.eggs > 0 then
        S.eggIndex = (S.eggIndex % #S.eggs) + 1
        S.selectedEgg = S.eggs[S.eggIndex]
        eggButton.Text = "ЯЙЦО: " .. S.selectedEgg
        S.status = "выбрано: " .. S.selectedEgg
    end
end)

makeAction("ПЕРЕСКАНИРОВАТЬ ЯЙЦА", function()
    scanEggs()
    eggButton.Text = S.selectedEgg and ("ЯЙЦО: " .. S.selectedEgg) or "ЯЙЦО: не найдено"
end)

makeAction("HARD STOP", function()
    stopAutomation("manual")
end)

-- Drag --------------------------------------------------------------------

local dragging = false
local dragStart = nil
local startPosition = nil

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

S.conns[#S.conns + 1] = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

S.conns[#S.conns + 1] = UserInputService.InputChanged:Connect(function(input)
    if dragging and dragStart and startPosition then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end
end)

-- Scheduler ---------------------------------------------------------------

local lastBubble = 0
local lastHatch = 0
local lastCollect = 0

S.conns[#S.conns + 1] = RunService.Heartbeat:Connect(function()
    if not S.alive then
        return
    end

    local now = os.clock()

    statusLabel.Text = S.status
        .. " | remote " .. (Network and "OK" or "нет")
        .. " | eggs " .. tostring(#S.eggs)
        .. " | failures " .. tostring(S.failures)

    if now < S.pausedUntil or now < S.respawnGraceUntil then
        return
    end

    if S.autoBubble and now - lastBubble >= 0.20 then
        lastBubble = now
        if fire("BlowBubble", 0.20) then
            S.status = "SAFE | надуваю"
        end
    end

    if S.autoHatch and now - lastHatch >= 0.65 then
        lastHatch = now

        if not S.selectedEgg then
            scanEggs()
        end

        local egg = selectedEggInstance()
        local hotkey = eggHotkey(egg)

        if hotkey then
            local d = distanceTo(hotkey)

            if d <= 14.5 then
                if fire("PurchaseEgg", 0.65, S.selectedEgg) then
                    S.status = "SAFE | открываю " .. tostring(S.selectedEgg)
                end
            elseif S.walkToEgg then
                moveTo(hotkey.Position, math.min(300, d + 5))
                S.status = "иду к " .. tostring(S.selectedEgg) .. " | " .. tostring(math.floor(d)) .. " studs"
            else
                S.status = "подойди к " .. tostring(S.selectedEgg) .. " (" .. tostring(math.floor(d)) .. " studs)"
            end
        end
    end

    if S.autoCollect and now - lastCollect >= 0.30 then
        lastCollect = now
        local pickup, pickupDistance = nearestPickup()

        if pickup then
            moveTo(pickup.Position, S.collectRadius)
            S.status = "SAFE | собираю валюту (" .. tostring(math.floor(pickupDistance or 0)) .. " studs)"
        else
            S.status = "валюта рядом не найдена"
        end
    end
end)

S.conns[#S.conns + 1] = LocalPlayer.CharacterAdded:Connect(function()
    S.respawnGraceUntil = os.clock() + 2.5
    S.pausedUntil = S.respawnGraceUntil
    S.status = "SAFE: пауза после респавна"
end)

function S:Stop(reason)
    if not self.alive then
        return
    end

    stopAutomation(reason or "closed")
    self.alive = false

    for _, connection in ipairs(self.conns) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    self.conns = {}

    pcall(function()
        gui:Destroy()
    end)
end

close.Activated:Connect(function()
    S:Stop("closed")
end)

task.delay(0.7, function()
    Network = findNetwork()
    scanEggs()
    eggButton.Text = S.selectedEgg and ("ЯЙЦО: " .. S.selectedEgg) or "ЯЙЦО: не найдено"

    if not Network then
        S.status = "NetworkRemoteEvent не найден — нужна диагностика копии"
    end
end)

S.startupReady = true
print("BGS Legacy Hub " .. VERSION .. " loaded")
return S
