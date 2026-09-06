-- RockBugHub boss reward addon v0.1
-- Generic collector for the September 2026 Boss Battles reward flow.
local Players = game:GetService("Players")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

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
    seen = setmetatable({}, {__mode = "k"}),
}
env.RockBugBossReward = state

local runtime = env.RockBugRuntime
if type(runtime) == "table" then
    runtime.bossRewardEnabled = true
    runtime.bossRewardAddon = state
end

local bossWords = {"boss", "raid", "босс"}
local rewardWords = {"reward", "claim", "collect", "chest", "prize", "take", "get", "open", "loot", "награ", "получ", "забра", "сундук", "приз"}

local function lower(v)
    return string.lower(tostring(v or ""))
end

local function hasAny(s, words)
    s = lower(s)
    for _, w in ipairs(words) do
        if s:find(w, 1, true) then return true end
    end
    return false
end

local function ownText(obj)
    local s = tostring(obj.Name or "")
    if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
        s ..= " " .. tostring(obj.Text or "")
    elseif obj:IsA("ProximityPrompt") then
        s ..= " " .. tostring(obj.ActionText or "") .. " " .. tostring(obj.ObjectText or "")
    end
    return s
end

local function chainText(obj, depth)
    local out = ""
    local p = obj
    for _ = 1, depth or 7 do
        if not p then break end
        out ..= " " .. ownText(p)
        p = p.Parent
    end
    return out
end

local function nearbyText(obj)
    local p = obj.Parent
    if not p then return "" end
    local out = ""
    local n = 0
    for _, d in ipairs(p:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            out ..= " " .. ownText(d)
            n += 1
            if n >= 24 then break end
        end
    end
    return out
end

local function bossContext(obj)
    local s = chainText(obj, 9)
    if hasAny(s, bossWords) then return true end
    s ..= " " .. nearbyText(obj)
    return hasAny(s, bossWords)
end

local function rewardContext(obj)
    local s = ownText(obj) .. " " .. chainText(obj, 5) .. " " .. nearbyText(obj)
    return hasAny(s, rewardWords)
end

local function ready(obj, cooldown)
    local now = os.clock()
    local t = state.seen[obj]
    if t and now - t < (cooldown or 1.0) then return false end
    state.seen[obj] = now
    return true
end

local function mark(kind, obj)
    state.hits += 1
    state.last = kind .. ": " .. obj:GetFullName()
end

local function clickGui(btn)
    if not state.enabled or not btn.Visible or not btn.Active then return false end
    if not bossContext(btn) or not rewardContext(btn) then return false end
    if not ready(btn, 0.75) then return false end

    local fired = false
    if type(firesignal) == "function" then
        fired = pcall(function()
            firesignal(btn.Activated)
            if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                firesignal(btn.MouseButton1Click)
            end
        end)
    end

    if not fired then
        fired = pcall(function() btn:Activate() end)
    end

    if not fired and VirtualInputManager then
        fired = pcall(function()
            local pos = btn.AbsolutePosition
            local size = btn.AbsoluteSize
            local x = pos.X + math.max(2, size.X * 0.5)
            local y = pos.Y + math.max(2, size.Y * 0.5)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
    end

    if fired then mark("gui", btn) end
    return fired
end

local function worldReward(obj)
    if not state.enabled then return false end
    if not bossContext(obj) or not rewardContext(obj) then return false end
    if not ready(obj, 0.9) then return false end

    if obj:IsA("ProximityPrompt") and obj.Enabled and type(fireproximityprompt) == "function" then
        local ok = pcall(fireproximityprompt, obj, 0)
        if ok then mark("prompt", obj) return true end
    elseif obj:IsA("ClickDetector") and type(fireclickdetector) == "function" then
        local ok = pcall(fireclickdetector, obj)
        if ok then mark("click", obj) return true end
    elseif obj:IsA("BasePart") and type(firetouchinterest) == "function" then
        local c = lp.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if root then
            local ok = pcall(function()
                firetouchinterest(root, obj, 0)
                task.wait()
                firetouchinterest(root, obj, 1)
            end)
            if ok then mark("touch", obj) return true end
        end
    end
    return false
end

local function scanGui()
    for _, obj in ipairs(pg:GetDescendants()) do
        if not state.enabled then break end
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
            pcall(clickGui, obj)
        end
    end
end

local function scanWorld()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if not state.enabled then break end
        if obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") then
            pcall(worldReward, obj)
        elseif obj:IsA("BasePart") then
            local s = chainText(obj, 5)
            if hasAny(s, bossWords) and hasAny(s, rewardWords) then
                pcall(worldReward, obj)
            end
        end
    end
end

-- Small toggle so the addon can be disabled without stopping the hub.
local old = pg:FindFirstChild("RockBugBossRewardToggle")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "RockBugBossRewardToggle"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999990
gui.Parent = pg

local btn = Instance.new("TextButton")
btn.Name = "Toggle"
btn.AnchorPoint = Vector2.new(1, 1)
btn.Position = UDim2.new(1, -12, 1, -12)
btn.Size = UDim2.fromOffset(150, 34)
btn.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
btn.BackgroundTransparency = 0.08
btn.TextColor3 = Color3.fromRGB(235, 235, 245)
btn.TextSize = 13
btn.Font = Enum.Font.GothamBold
btn.Text = "Boss reward: ON"
btn.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 9)
corner.Parent = btn

local function refresh()
    btn.Text = "Boss reward: " .. (state.enabled and "ON" or "OFF")
    if type(runtime) == "table" then runtime.bossRewardEnabled = state.enabled end
end
btn.MouseButton1Click:Connect(function()
    state.enabled = not state.enabled
    refresh()
end)

state.Stop = function()
    state.alive = false
    state.enabled = false
    if gui and gui.Parent then gui:Destroy() end
end

pg.DescendantAdded:Connect(function(obj)
    if not state.alive or not state.enabled then return end
    task.defer(function()
        task.wait(0.05)
        if obj and obj.Parent and (obj:IsA("TextButton") or obj:IsA("ImageButton")) then
            pcall(clickGui, obj)
        end
    end)
end)

workspace.DescendantAdded:Connect(function(obj)
    if not state.alive or not state.enabled then return end
    task.defer(function()
        task.wait(0.05)
        if obj and obj.Parent and (obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") or obj:IsA("BasePart")) then
            pcall(worldReward, obj)
        end
    end)
end)

task.spawn(function()
    while state.alive do
        if state.enabled then pcall(scanGui) end
        task.wait(0.35)
    end
end)

task.spawn(function()
    while state.alive do
        if state.enabled then pcall(scanWorld) end
        task.wait(1.25)
    end
end)

refresh()
print("[RockBugHub] Boss reward auto-collector loaded (ON)")
return state
