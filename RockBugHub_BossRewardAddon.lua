-- RockBugHub boss reward addon v0.3
-- Exact collector for the Boss Battles arena chest shown in-game:
-- ObjectText = "Epic Boss Chest" (or another Boss Chest tier)
-- ActionText = "Claim Reward"
-- No GUI scanning: only the physical ProximityPrompt on the boss chest.

local Players = game:GetService("Players")
local lp = Players.LocalPlayer
while not lp do task.wait() lp = Players.LocalPlayer end
local pg = lp:WaitForChild("PlayerGui", 60)
if not pg then return end

local env = _G
if type(getgenv) == "function" then
    local ok, t = pcall(getgenv)
    if ok and type(t) == "table" then env = t end
end

if env.RockBugBossReward and type(env.RockBugBossReward.Stop) == "function" then
    pcall(env.RockBugBossReward.Stop)
end

local state = {
    enabled = true,
    alive = true,
    hits = 0,
    last = nil,
    lastFireAt = 0,
}
env.RockBugBossReward = state

local runtime = env.RockBugRuntime
if type(runtime) == "table" then
    runtime.bossRewardEnabled = true
    runtime.bossRewardAddon = state
end

local function low(v)
    return string.lower(tostring(v or ""))
end

local function isBossChestPrompt(obj)
    if not obj or not obj:IsA("ProximityPrompt") or not obj.Enabled then return false end
    local action = low(obj.ActionText)
    local object = low(obj.ObjectText)

    -- Seen on the user's Boss Battles chest:
    -- "Epic Boss Chest" / "Claim Reward".
    local exactAction = action:find("claim reward", 1, true) ~= nil
    local bossChest = object:find("boss chest", 1, true) ~= nil
    return exactAction and bossChest
end

local function claim(prompt)
    if not state.alive or not state.enabled or not isBossChestPrompt(prompt) then return false end

    local now = os.clock()
    if now - state.lastFireAt < 0.8 then return false end
    state.lastFireAt = now

    local ok = false
    if type(fireproximityprompt) == "function" then
        ok = pcall(function()
            fireproximityprompt(prompt, 0)
        end)
    end

    -- Fallback for executors where fireproximityprompt is absent but the
    -- prompt's hold API is exposed.
    if not ok then
        ok = pcall(function()
            prompt:InputHoldBegin()
            task.wait(math.max(0.05, tonumber(prompt.HoldDuration) or 0))
            prompt:InputHoldEnd()
        end)
    end

    if ok then
        state.hits += 1
        state.last = prompt:GetFullName()
    end
    return ok
end

local function scan()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if not state.alive or not state.enabled then break end
        if isBossChestPrompt(obj) then
            claim(obj)
            break
        end
    end
end

-- Keep the small switch, but the collector itself never clicks any UI.
local old = pg:FindFirstChild("RockBugBossRewardToggle")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "RockBugBossRewardToggle"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999990
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

local btn = Instance.new("TextButton")
btn.Name = "Toggle"
btn.AnchorPoint = Vector2.new(1, 0)
btn.Position = UDim2.new(1, -12, 0, 86)
btn.Size = UDim2.fromOffset(150, 34)
btn.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
btn.BackgroundTransparency = 0.08
btn.TextColor3 = Color3.fromRGB(235, 235, 245)
btn.TextSize = 13
btn.Font = Enum.Font.GothamBold
btn.ZIndex = 1000
btn.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 9)
corner.Parent = btn

local function refresh()
    btn.Text = "Boss chest: " .. (state.enabled and "ON" or "OFF")
    if type(runtime) == "table" then runtime.bossRewardEnabled = state.enabled end
end

btn.MouseButton1Click:Connect(function()
    state.enabled = not state.enabled
    refresh()
    if state.enabled then task.defer(scan) end
end)

state.Stop = function()
    state.alive = false
    state.enabled = false
    if gui and gui.Parent then gui:Destroy() end
end

workspace.DescendantAdded:Connect(function(obj)
    if not state.alive or not state.enabled then return end
    if obj:IsA("ProximityPrompt") then
        task.defer(function()
            task.wait(0.05)
            claim(obj)
        end)
    end
end)

task.spawn(function()
    while state.alive do
        if state.enabled then pcall(scan) end
        task.wait(0.5)
    end
end)

refresh()
print("[RockBugHub] Exact Boss Chest auto-collector v0.3 loaded (ON)")
return state
