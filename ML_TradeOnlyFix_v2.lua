local VERSION = "4.19"
local CORE_URL = "https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/ML_TradeOnlyFix_v2_core.lua?v=" .. VERSION .. "&cb=" .. tostring(os.time())

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local statusGui
local statusLabel

local function showStatus(message, isError)
    warn("[RockBugHub Loader] " .. tostring(message))

    if not statusGui then
        pcall(function()
            local player = Players.LocalPlayer
            local parent = player and player:FindFirstChildOfClass("PlayerGui")
            if not parent and player then
                parent = player:WaitForChild("PlayerGui", 10)
            end
            if not parent then
                return
            end

            statusGui = Instance.new("ScreenGui")
            statusGui.Name = "RBHLaunchStatus"
            statusGui.ResetOnSpawn = false
            statusGui.DisplayOrder = 1000000
            statusGui.IgnoreGuiInset = true
            statusGui.Parent = parent

            statusLabel = Instance.new("TextLabel")
            statusLabel.Name = "Status"
            statusLabel.AnchorPoint = Vector2.new(0.5, 0)
            statusLabel.Position = UDim2.new(0.5, 0, 0, 18)
            statusLabel.Size = UDim2.new(0, 360, 0, 48)
            statusLabel.BackgroundColor3 = Color3.fromRGB(16, 19, 25)
            statusLabel.BackgroundTransparency = 0.08
            statusLabel.BorderSizePixel = 0
            statusLabel.Font = Enum.Font.GothamBold
            statusLabel.TextColor3 = Color3.fromRGB(235, 240, 245)
            statusLabel.TextSize = 14
            statusLabel.TextWrapped = true
            statusLabel.ZIndex = 1000000
            statusLabel.Parent = statusGui

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 10)
            corner.Parent = statusLabel
        end)
    end

    if statusLabel then
        statusLabel.Text = "RockBugHub " .. VERSION .. "\n" .. tostring(message)
        statusLabel.TextColor3 = isError and Color3.fromRGB(255, 120, 130) or Color3.fromRGB(105, 255, 180)
    end

    task.spawn(function()
        for _ = 1, 4 do
            local ok = pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "RockBugHub " .. VERSION,
                    Text = tostring(message),
                    Duration = isError and 12 or 4,
                })
            end)
            if ok then
                return
            end
            task.wait(0.5)
        end
    end)
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

showStatus("1/3: загрузка ядра...", false)

if type(loadstring) ~= "function" then
    showStatus("Ошибка: исполнитель не поддерживает loadstring", true)
    return
end

local downloaded, source = pcall(function()
    return game:HttpGet(CORE_URL, true)
end)

if not downloaded or type(source) ~= "string" or #source < 100000 then
    showStatus("Ошибка загрузки: " .. tostring(source):sub(1, 120), true)
    return
end

showStatus("2/3: компиляция ядра...", false)
local chunk, compileError = loadstring(source)
if type(chunk) ~= "function" then
    showStatus("Ошибка компиляции: " .. tostring(compileError):sub(1, 140), true)
    return
end

showStatus("3/3: создание интерфейса...", false)
local ran, runtimeError = xpcall(chunk, function(err)
    local trace = ""
    if debug and type(debug.traceback) == "function" then
        trace = "\n" .. tostring(debug.traceback())
    end
    return tostring(err) .. trace
end)

if not ran then
    showStatus("Ошибка запуска: " .. tostring(runtimeError):sub(1, 160), true)
    return
end

if statusGui then
    statusGui:Destroy()
end
