-- Speed Hub X style Rock TP / Lock v1.0
-- Safe Roblox Studio / Luau LocalScript for a private test place.
-- Purpose: scan Muscle Legends-style rocks by neededDurability, teleport to selected rock, and hold character position there.
-- No external fetch and no remote punch automation.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer

local VERSION = "Rock Lock v1.0"
local HUB_TITLE = "Speed Hub X"

local ROCKS = {
    { id = "Tiny",          req = 0,        name = "Tiny Rock",            short = "Tiny" },
    { id = "Punching",      req = 10,       name = "Punching Rock",        short = "Punch" },
    { id = "Large",         req = 100,      name = "Large Rock",           short = "Large" },
    { id = "Golden",        req = 5000,     name = "Golden Rock",          short = "Golden" },
    { id = "Frozen",        req = 150000,   name = "Frozen / Frost Rock",  short = "Frozen" },
    { id = "Mystic",        req = 400000,   name = "Mystic / Mythical",    short = "Mystic" },
    { id = "Inferno",       req = 750000,   name = "Inferno / Eternal",    short = "Inferno" },
    { id = "Legends",       req = 1000000,  name = "Legends Rock",         short = "Legends" },
    { id = "MuscleKing",    req = 5000000,  name = "Muscle King Rock",     short = "King" },
    { id = "AncientJungle", req = 10000000, name = "Ancient Jungle Rock",  short = "Jungle" },
}

local rockByReq = {}
for _, rock in ipairs(ROCKS) do
    rockByReq[rock.req] = rock
end

local gui
local mainFrame
local topBar
local miniButton
local statusLabel
local selectedLabel
local listFrame
local listLayout
local scanButton
local unlockButton
local copyButton
local refreshButton
local titleLabel
local subtitleLabel
local uiScale

local foundRocks = {}
local selectedRock = nil
local selectedRowFrame = nil
local lockConnection = nil
local lockedCFrame = nil
local oldWalkSpeed = nil
local oldAutoRotate = nil
local lastReport = ""
local dragging = false
local dragStartPosition = nil
local dragFramePosition = nil

local BASE_W = 368
local BASE_H = 520

local function setStatus(text)
    if statusLabel then
        statusLabel.Text = tostring(text or "")
    end
end

local function notify(text)
    setStatus(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = HUB_TITLE,
            Text = tostring(text or ""),
            Duration = 3,
        })
    end)
end

local function formatNumber(value)
    local n = math.floor(tonumber(value) or 0)
    local s = tostring(n)
    local result = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^%s+", "")
    return result
end

local function parseNumber(value)
    if typeof(value) == "number" then
        return value
    end

    local text = tostring(value or ""):lower():gsub("%s+", "")
    if text == "" then
        return nil
    end

    local multiplier = 1
    if text:find("k", 1, true) or text:find("к", 1, true) then
        multiplier = 1000
    elseif text:find("m", 1, true) or text:find("м", 1, true) then
        multiplier = 1000000
    elseif text:find("b", 1, true) then
        multiplier = 1000000000
    end

    local raw = text:match("[%d%.,]+")
    if not raw then
        return nil
    end

    local hasComma = raw:find(",", 1, true) ~= nil
    local hasDot = raw:find(".", 1, true) ~= nil

    if hasComma and hasDot then
        local lastComma = raw:match("^.*(),") or 0
        local lastDot = raw:match("^.*()%.") or 0
        if lastComma > lastDot then
            raw = raw:gsub("%.", ""):gsub(",", ".")
        else
            raw = raw:gsub(",", "")
        end
    elseif hasComma then
        local before, after = raw:match("^(.*),([^,]*)$")
        local digitsAfter = tostring(after or ""):gsub("%D", "")
        if multiplier == 1 and #digitsAfter == 3 and tostring(before or "") ~= "" then
            raw = raw:gsub(",", "")
        else
            raw = raw:gsub(",", ".")
        end
    elseif hasDot then
        local before, after = raw:match("^(.*)%.([^%.]*)$")
        local digitsAfter = tostring(after or ""):gsub("%D", "")
        if multiplier == 1 and #digitsAfter == 3 and tostring(before or "") ~= "" then
            raw = raw:gsub("%.", "")
        end
    end

    local number = tonumber(raw)
    if not number then
        return nil
    end

    return number * multiplier
end

local function getRootPart()
    local character = localPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local character = localPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChildWhichIsA("Humanoid")
end

local function readValueObjectNumber(object)
    if not object then
        return nil
    end

    if object:IsA("NumberValue") or object:IsA("IntValue") then
        return tonumber(object.Value)
    end

    if object:IsA("StringValue") then
        return parseNumber(object.Value)
    end

    local ok, value = pcall(function()
        return object.Value
    end)
    if ok then
        return parseNumber(value)
    end

    return nil
end

local function biggestPart(object)
    if not object then
        return nil
    end

    if object:IsA("BasePart") then
        return object
    end

    local best = nil
    local bestVolume = -1

    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local size = descendant.Size
            local volume = size.X * size.Y * size.Z
            if volume > bestVolume then
                bestVolume = volume
                best = descendant
            end
        end
    end

    return best
end

local function getPath(object)
    if not object then
        return "nil"
    end

    local parts = {}
    local current = object
    local count = 0

    while current and current ~= game and count < 24 do
        table.insert(parts, 1, current.Name)
        current = current.Parent
        count = count + 1
    end

    return table.concat(parts, "/")
end

local function rockModelFromNeededDurability(valueObject)
    local parent = valueObject and valueObject.Parent

    for _ = 1, 7 do
        if not parent or parent == workspace then
            break
        end

        local leftHand = parent:FindFirstChild("LeftHand", true)
        local rightHand = parent:FindFirstChild("RightHand", true)

        if leftHand and rightHand then
            return parent, leftHand, rightHand
        end

        parent = parent.Parent
    end

    return valueObject and valueObject.Parent or nil, nil, nil
end

local function sameReq(a, b)
    a = tonumber(a)
    b = tonumber(b)
    if not a or not b then
        return false
    end
    return math.abs(a - b) <= 0.001
end

local function getRockDefinitionByReq(req)
    for _, rock in ipairs(ROCKS) do
        if sameReq(rock.req, req) then
            return rock
        end
    end
    return nil
end

local function scanRocks()
    local rows = {}
    local seen = {}
    local root = getRootPart()
    local scanned = 0

    for _, object in ipairs(workspace:GetDescendants()) do
        scanned = scanned + 1
        if scanned % 500 == 0 then
            task.wait()
        end

        if tostring(object.Name):lower() == "neededdurability" then
            local req = readValueObjectNumber(object)
            local definition = getRockDefinitionByReq(req)

            if definition then
                local model, leftHand, rightHand = rockModelFromNeededDurability(object)
                local key = model or object.Parent

                if key and not seen[key] then
                    seen[key] = true

                    local body = biggestPart(key)
                    local hitPart = nil

                    if leftHand and leftHand:IsA("BasePart") then
                        hitPart = leftHand
                    elseif rightHand and rightHand:IsA("BasePart") then
                        hitPart = rightHand
                    elseif body then
                        hitPart = body
                    end

                    if body and hitPart then
                        local distance = 0
                        if root then
                            distance = (body.Position - root.Position).Magnitude
                        end

                        table.insert(rows, {
                            id = definition.id,
                            req = definition.req,
                            name = definition.name,
                            short = definition.short,
                            model = key,
                            body = body,
                            hit = hitPart,
                            left = leftHand,
                            right = rightHand,
                            distance = distance,
                        })
                    end
                end
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.req ~= b.req then
            return a.req < b.req
        end
        return a.distance < b.distance
    end)

    foundRocks = rows
    return rows
end

local function findRowById(id)
    for _, row in ipairs(foundRocks) do
        if row.id == id and row.body and row.body.Parent then
            return row
        end
    end
    return nil
end

local function makeRockCFrame(row)
    local root = getRootPart()
    if not root or not row or not row.body then
        return nil
    end

    local body = row.body
    local hitPart = row.hit
    local direction = root.Position - body.Position
    direction = Vector3.new(direction.X, 0, direction.Z)

    if direction.Magnitude < 0.1 then
        direction = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z)
    end

    if direction.Magnitude < 0.1 then
        direction = Vector3.new(0, 0, -1)
    else
        direction = direction.Unit
    end

    local radius = math.max(body.Size.X, body.Size.Z) / 2
    local insideDistance = math.max(radius * 0.32, 0.35)
    local y = body.Position.Y + math.clamp(body.Size.Y * 0.16, 0.45, 2.25)
    local position = Vector3.new(body.Position.X, y, body.Position.Z) + direction * insideDistance

    if hitPart and hitPart.Parent then
        local hitPosition = hitPart.Position
        position = position:Lerp(Vector3.new(hitPosition.X, y, hitPosition.Z), 0.2)
    end

    return CFrame.lookAt(position, Vector3.new(body.Position.X, y, body.Position.Z))
end

local function stopLock()
    if lockConnection then
        lockConnection:Disconnect()
        lockConnection = nil
    end

    local humanoid = getHumanoid()
    if humanoid then
        if oldWalkSpeed ~= nil then
            humanoid.WalkSpeed = oldWalkSpeed
        end
        if oldAutoRotate ~= nil then
            humanoid.AutoRotate = oldAutoRotate
        end
        pcall(function()
            humanoid:Move(Vector3.zero, false)
        end)
    end

    local root = getRootPart()
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    lockedCFrame = nil
    oldWalkSpeed = nil
    oldAutoRotate = nil
    setStatus("Lock stopped. Управление возвращено.")
end

local function startLock(cframe)
    stopLock()

    local root = getRootPart()
    local humanoid = getHumanoid()

    if not root or not cframe then
        setStatus("Lock error: нет персонажа/root.")
        return false
    end

    lockedCFrame = cframe

    if humanoid then
        oldWalkSpeed = humanoid.WalkSpeed
        oldAutoRotate = humanoid.AutoRotate
        humanoid.WalkSpeed = 0
        humanoid.AutoRotate = false
        pcall(function()
            humanoid:Move(Vector3.zero, false)
        end)
    end

    lockConnection = RunService.Heartbeat:Connect(function()
        local currentRoot = getRootPart()
        local currentHumanoid = getHumanoid()
        if not currentRoot or not lockedCFrame then
            return
        end

        currentRoot.CFrame = lockedCFrame
        currentRoot.AssemblyLinearVelocity = Vector3.zero
        currentRoot.AssemblyAngularVelocity = Vector3.zero

        if currentHumanoid then
            pcall(function()
                currentHumanoid:Move(Vector3.zero, false)
            end)
        end
    end)

    return true
end

local function teleportToRock(row, lockAfter)
    if not row or not row.body or not row.body.Parent then
        setStatus("Rock not found. Нажми RESCAN.")
        return false
    end

    local root = getRootPart()
    if not root then
        setStatus("Character root not found.")
        return false
    end

    local cframe = makeRockCFrame(row)
    if not cframe then
        setStatus("Cannot build rock CFrame.")
        return false
    end

    root.CFrame = cframe
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    if lockAfter then
        if startLock(cframe) then
            setStatus("LOCK: " .. row.name .. " | req " .. formatNumber(row.req))
            return true
        end
        return false
    end

    setStatus("TP: " .. row.name .. " | req " .. formatNumber(row.req))
    return true
end

local function bindPress(button, callback)
    local busy = false
    local function run()
        if busy then
            return
        end
        busy = true
        task.defer(function()
            local ok, err = pcall(callback)
            if not ok then
                setStatus("Button error: " .. tostring(err):sub(1, 90))
            end
            task.wait(0.06)
            busy = false
        end)
    end

    button.Activated:Connect(run)
    button.MouseButton1Click:Connect(run)
end

local function makeCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

local function makeStroke(instance, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.Parent = instance
    return stroke
end

local function makeGradient(instance, colorA, colorB)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colorA),
        ColorSequenceKeypoint.new(1, colorB),
    })
    gradient.Rotation = 35
    gradient.Parent = instance
    return gradient
end

local function makeLabel(parent, text, x, y, w, h, size, color, bold)
    local label = Instance.new("TextLabel")
    label.Parent = parent
    label.Size = UDim2.new(0, w, 0, h)
    label.Position = UDim2.new(0, x, 0, y)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold
    label.TextSize = size or 12
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.ZIndex = 5
    return label
end

local function makeButton(parent, text, x, y, w, h, colorA, colorB)
    local button = Instance.new("TextButton")
    button.Parent = parent
    button.Size = UDim2.new(0, w, 0, h)
    button.Position = UDim2.new(0, x, 0, y)
    button.BackgroundColor3 = colorA
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBlack
    button.TextSize = 12
    button.TextWrapped = true
    button.AutoButtonColor = true
    button.Active = true
    button.ZIndex = 8
    makeCorner(button, 10)
    makeStroke(button, Color3.fromRGB(170, 120, 255), 1, 0.42)
    makeGradient(button, colorA, colorB or colorA)
    return button
end

local function clearList()
    if not listFrame then
        return
    end

    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    selectedRowFrame = nil
end

local function selectRow(row, rowFrame)
    selectedRock = row

    if selectedRowFrame and selectedRowFrame.Parent then
        selectedRowFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 38)
    end

    selectedRowFrame = rowFrame
    if selectedRowFrame then
        selectedRowFrame.BackgroundColor3 = Color3.fromRGB(35, 30, 72)
    end

    if selectedLabel then
        selectedLabel.Text = "Selected: " .. row.name .. "\nreq " .. formatNumber(row.req) .. " | dist " .. math.floor(row.distance) .. " studs"
    end
end

local function updateCanvas()
    task.defer(function()
        if listFrame and listLayout then
            local height = listLayout.AbsoluteContentSize.Y + 14
            listFrame.CanvasSize = UDim2.new(0, 0, 0, height)
        end
    end)
end

local function makeRockRow(row, index)
    local holder = Instance.new("Frame")
    holder.Parent = listFrame
    holder.Name = "RockRow_" .. tostring(row.id)
    holder.Size = UDim2.new(1, -8, 0, 74)
    holder.BackgroundColor3 = Color3.fromRGB(18, 18, 38)
    holder.BorderSizePixel = 0
    holder.LayoutOrder = index
    holder.Active = true
    holder.ZIndex = 6
    makeCorner(holder, 12)
    makeStroke(holder, Color3.fromRGB(92, 75, 170), 1, 0.48)

    local title = makeLabel(holder, row.name, 10, 6, 184, 22, 12, Color3.fromRGB(255, 255, 255), true)
    title.ZIndex = 7

    local meta = makeLabel(holder, "req " .. formatNumber(row.req) .. "  •  " .. math.floor(row.distance) .. " studs", 10, 29, 184, 18, 10, Color3.fromRGB(180, 170, 225), false)
    meta.ZIndex = 7

    local path = makeLabel(holder, tostring(row.model and row.model.Name or row.id), 10, 49, 184, 18, 9, Color3.fromRGB(126, 122, 162), false)
    path.ZIndex = 7

    local tpButton = makeButton(holder, "TP", 207, 12, 48, 46, Color3.fromRGB(52, 82, 185), Color3.fromRGB(95, 56, 225))
    local lockButton = makeButton(holder, "LOCK", 261, 12, 58, 46, Color3.fromRGB(45, 145, 84), Color3.fromRGB(36, 110, 175))

    bindPress(tpButton, function()
        selectRow(row, holder)
        teleportToRock(row, false)
    end)

    bindPress(lockButton, function()
        selectRow(row, holder)
        teleportToRock(row, true)
    end)

    holder.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            selectRow(row, holder)
        end
    end)

    return holder
end

local function rebuildList()
    clearList()

    if #foundRocks == 0 then
        local empty = Instance.new("TextLabel")
        empty.Parent = listFrame
        empty.Size = UDim2.new(1, -8, 0, 82)
        empty.BackgroundColor3 = Color3.fromRGB(18, 18, 38)
        empty.BorderSizePixel = 0
        empty.Text = "Камни не найдены. Нажми RESCAN.\nИщу Value с именем neededDurability."
        empty.TextColor3 = Color3.fromRGB(210, 202, 238)
        empty.Font = Enum.Font.GothamBold
        empty.TextSize = 12
        empty.TextWrapped = true
        empty.ZIndex = 6
        makeCorner(empty, 12)
        makeStroke(empty, Color3.fromRGB(92, 75, 170), 1, 0.48)
        updateCanvas()
        return
    end

    for index, row in ipairs(foundRocks) do
        local rowFrame = makeRockRow(row, index)
        if index == 1 then
            selectRow(row, rowFrame)
        end
    end

    updateCanvas()
end

local function buildReport()
    local lines = {}
    table.insert(lines, "Speed Hub X style Rock Lock")
    table.insert(lines, "Version: " .. VERSION)
    table.insert(lines, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(lines, "GameId: " .. tostring(game.GameId))
    table.insert(lines, "Found rocks: " .. tostring(#foundRocks))
    table.insert(lines, "")

    for index, row in ipairs(foundRocks) do
        table.insert(lines, ("#%02d %s | req=%s | dist=%s"):format(index, row.name, tostring(row.req), tostring(math.floor(row.distance))))
        table.insert(lines, "model=" .. getPath(row.model))
        table.insert(lines, "body=" .. getPath(row.body))
        table.insert(lines, "hit=" .. getPath(row.hit))
        table.insert(lines, "")
    end

    if selectedRock then
        table.insert(lines, "Selected: " .. selectedRock.name .. " | req=" .. tostring(selectedRock.req))
    else
        table.insert(lines, "Selected: none")
    end

    table.insert(lines, "Lock active: " .. tostring(lockConnection ~= nil))

    lastReport = table.concat(lines, "\n")
    return lastReport
end

local function copyReport()
    local report = buildReport()
    local copied = false

    pcall(function()
        if setclipboard then
            setclipboard(report)
            copied = true
        end
    end)

    if copied then
        setStatus("Report copied.")
    else
        print(report)
        setStatus("Clipboard недоступен. Отчёт выведен в Output/console.")
    end
end

local function doScan()
    setStatus("Scanning neededDurability...")
    scanRocks()
    rebuildList()
    buildReport()
    setStatus("Scan complete: " .. tostring(#foundRocks) .. " rock(s).")
end

local function clampFramePosition(position)
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(900, 600)
    local scale = uiScale and uiScale.Scale or 1
    local width = BASE_W * scale
    local height = BASE_H * scale

    local minX = 4
    local minY = 36
    local maxX = math.max(minX, viewport.X - width - 4)
    local maxY = math.max(minY, viewport.Y - height - 4)
    local x = math.clamp(position.X.Offset, minX, maxX)
    local y = math.clamp(position.Y.Offset, minY, maxY)

    return UDim2.new(0, math.floor(x), 0, math.floor(y))
end

local function setMainPosition(position)
    if mainFrame then
        mainFrame.Position = clampFramePosition(position)
    end
end

local function fitToScreen()
    if not mainFrame or not uiScale then
        return
    end

    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(900, 600)
    local scale = math.min(1, (viewport.X - 12) / BASE_W, (viewport.Y - 54) / BASE_H)
    if scale < 0.68 then
        scale = 0.68
    end

    uiScale.Scale = scale
    setMainPosition(UDim2.new(0, 8, 0, math.max(44, math.floor(viewport.Y * 0.1))))
end

local function createGui()
    pcall(function()
        localPlayer.PlayerGui:FindFirstChild("SpeedHubX_RockLock"):Destroy()
    end)

    gui = Instance.new("ScreenGui")
    gui.Name = "SpeedHubX_RockLock"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "Main"
    mainFrame.Parent = gui
    mainFrame.Size = UDim2.new(0, BASE_W, 0, BASE_H)
    mainFrame.Position = UDim2.new(0, 8, 0, 70)
    mainFrame.BackgroundColor3 = Color3.fromRGB(9, 9, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.ZIndex = 2
    makeCorner(mainFrame, 16)
    makeStroke(mainFrame, Color3.fromRGB(120, 75, 255), 1, 0.08)

    uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = mainFrame

    local backgroundGradient = Instance.new("UIGradient")
    backgroundGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 12, 44)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(9, 9, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 17, 30)),
    })
    backgroundGradient.Rotation = 25
    backgroundGradient.Parent = mainFrame

    topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Parent = mainFrame
    topBar.Size = UDim2.new(1, -16, 0, 46)
    topBar.Position = UDim2.new(0, 8, 0, 8)
    topBar.BackgroundColor3 = Color3.fromRGB(17, 16, 38)
    topBar.BorderSizePixel = 0
    topBar.Active = true
    topBar.ZIndex = 4
    makeCorner(topBar, 13)
    makeStroke(topBar, Color3.fromRGB(140, 95, 255), 1, 0.38)

    titleLabel = makeLabel(topBar, HUB_TITLE, 12, 3, 170, 24, 17, Color3.fromRGB(255, 255, 255), true)
    subtitleLabel = makeLabel(topBar, VERSION, 12, 25, 170, 16, 10, Color3.fromRGB(164, 146, 230), false)

    local minimizeButton = makeButton(topBar, "−", 292, 9, 28, 28, Color3.fromRGB(50, 42, 90), Color3.fromRGB(70, 58, 130))
    local closeButton = makeButton(topBar, "×", 324, 9, 28, 28, Color3.fromRGB(96, 30, 48), Color3.fromRGB(128, 40, 62))

    selectedLabel = makeLabel(mainFrame, "Selected: none", 14, 63, 338, 42, 12, Color3.fromRGB(231, 225, 255), true)
    selectedLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 38)
    selectedLabel.BackgroundTransparency = 0
    selectedLabel.BorderSizePixel = 0
    selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedLabel.TextYAlignment = Enum.TextYAlignment.Center
    selectedLabel.ZIndex = 4
    makeCorner(selectedLabel, 12)
    makeStroke(selectedLabel, Color3.fromRGB(92, 75, 170), 1, 0.5)

    scanButton = makeButton(mainFrame, "RESCAN", 14, 114, 80, 34, Color3.fromRGB(70, 50, 170), Color3.fromRGB(130, 70, 230))
    refreshButton = makeButton(mainFrame, "TP SELECT", 102, 114, 92, 34, Color3.fromRGB(50, 90, 185), Color3.fromRGB(70, 62, 225))
    unlockButton = makeButton(mainFrame, "UNLOCK", 202, 114, 76, 34, Color3.fromRGB(40, 145, 86), Color3.fromRGB(33, 112, 145))
    copyButton = makeButton(mainFrame, "COPY", 286, 114, 66, 34, Color3.fromRGB(145, 90, 35), Color3.fromRGB(170, 70, 45))

    makeLabel(mainFrame, "Rocks by neededDurability", 15, 158, 190, 18, 12, Color3.fromRGB(225, 220, 255), true)
    local helperLabel = makeLabel(mainFrame, "TP = teleport | LOCK = hold position", 162, 158, 190, 18, 10, Color3.fromRGB(147, 138, 190), false)
    helperLabel.TextXAlignment = Enum.TextXAlignment.Right

    listFrame = Instance.new("ScrollingFrame")
    listFrame.Name = "RockList"
    listFrame.Parent = mainFrame
    listFrame.Size = UDim2.new(0, 338, 0, 282)
    listFrame.Position = UDim2.new(0, 14, 0, 181)
    listFrame.BackgroundColor3 = Color3.fromRGB(12, 13, 29)
    listFrame.BorderSizePixel = 0
    listFrame.ScrollBarThickness = 5
    listFrame.ScrollingEnabled = true
    listFrame.Active = true
    listFrame.ZIndex = 5
    listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    makeCorner(listFrame, 13)
    makeStroke(listFrame, Color3.fromRGB(85, 68, 155), 1, 0.34)

    local padding = Instance.new("UIPadding")
    padding.Parent = listFrame
    padding.PaddingTop = UDim.new(0, 7)
    padding.PaddingLeft = UDim.new(0, 7)
    padding.PaddingRight = UDim.new(0, 7)
    padding.PaddingBottom = UDim.new(0, 7)

    listLayout = Instance.new("UIListLayout")
    listLayout.Parent = listFrame
    listLayout.Padding = UDim.new(0, 7)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    statusLabel = makeLabel(mainFrame, "Ready. Нажми RESCAN.", 15, 472, 337, 36, 11, Color3.fromRGB(190, 181, 230), false)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextYAlignment = Enum.TextYAlignment.Top

    miniButton = Instance.new("TextButton")
    miniButton.Parent = gui
    miniButton.Name = "OpenMini"
    miniButton.Size = UDim2.new(0, 92, 0, 34)
    miniButton.Position = UDim2.new(0, 10, 0, 84)
    miniButton.BackgroundColor3 = Color3.fromRGB(65, 42, 150)
    miniButton.Text = "ROCK TP"
    miniButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    miniButton.Font = Enum.Font.GothamBlack
    miniButton.TextSize = 12
    miniButton.Visible = false
    miniButton.ZIndex = 30
    makeCorner(miniButton, 12)
    makeStroke(miniButton, Color3.fromRGB(155, 105, 255), 1, 0.18)
    makeGradient(miniButton, Color3.fromRGB(65, 42, 150), Color3.fromRGB(32, 100, 170))

    bindPress(scanButton, doScan)

    bindPress(refreshButton, function()
        if not selectedRock then
            setStatus("Select rock first.")
            return
        end

        local row = findRowById(selectedRock.id) or selectedRock
        teleportToRock(row, false)
    end)

    bindPress(unlockButton, stopLock)
    bindPress(copyButton, copyReport)

    bindPress(minimizeButton, function()
        mainFrame.Visible = false
        miniButton.Visible = true
    end)

    bindPress(miniButton, function()
        mainFrame.Visible = true
        miniButton.Visible = false
    end)

    bindPress(closeButton, function()
        stopLock()
        gui:Destroy()
    end)

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local localX = input.Position.X - topBar.AbsolutePosition.X
            if localX > topBar.AbsoluteSize.X - 80 then
                return
            end

            dragging = true
            dragStartPosition = input.Position
            dragFramePosition = mainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartPosition
            setMainPosition(UDim2.new(0, dragFramePosition.X.Offset + delta.X, 0, dragFramePosition.Y.Offset + delta.Y))
        end
    end)

    pcall(function()
        if workspace.CurrentCamera then
            workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)
        end
    end)

    fitToScreen()
    task.defer(doScan)
end

local function characterResetHook()
    localPlayer.CharacterAdded:Connect(function()
        task.wait(0.6)
        if lockedCFrame then
            startLock(lockedCFrame)
        end
    end)
end

createGui()
characterResetHook()
