-- EggHub core startup contract: 1
-- Target: Steal An Egg | place 107778070777162
local VERSION = "1.0.0"
local TARGET_PLACE = 107778070777162

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")

if not game:IsLoaded() then game.Loaded:Wait() end
local LP = Players.LocalPlayer
while not LP do task.wait() LP = Players.LocalPlayer end
local PlayerGui = LP:WaitForChild("PlayerGui")

local env = _G
if type(getgenv) == "function" then
    local ok, e = pcall(getgenv)
    if ok and type(e) == "table" then env = e end
end
if env.EggHubRuntime and type(env.EggHubRuntime.Stop) == "function" then
    pcall(function() env.EggHubRuntime:Stop("reload") end)
end

local q = {
    alive = true,
    startupReady = false,
    version = VERSION,
    autoSteal = false,
    returnBase = true,
    autoHatch = false,
    autoCollect = false,
    autoTrain = false,
    autoUpgradeTreadmill = false,
    autoUpgradeBase = false,
    stealPlayerEggs = true,
    targetMode = "BEST",
    rareOnly = false,
    eggEsp = false,
    antiAfk = true,
    lowGraphics = false,
    ultraBlack = false,
    baseCFrame = nil,
    baseSource = nil,
    busy = false,
    token = 0,
    scanCache = {},
    scanAt = 0,
    recent = setmetatable({}, {__mode="k"}),
    esp = {},
    conns = {},
    uiRoot = nil,
    status = "ready",
}
env.EggHubRuntime = q

local function safe(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end
local function lower(v) return string.lower(tostring(v or "")) end
local function trim(v) return tostring(v or ""):gsub("^%s+",""):gsub("%s+$","") end
local function containsAny(text, words)
    text = lower(text)
    for _, w in ipairs(words) do
        if text:find(w, 1, true) then return true end
    end
    return false
end
local function root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function humanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function char() return LP.Character end
local function partOf(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Attachment") and obj.Parent and obj.Parent:IsA("BasePart") then return obj.Parent end
    return obj:FindFirstAncestorWhichIsA("BasePart")
end
local function worldPos(obj)
    local p = partOf(obj)
    return p and p.Position or nil
end
local function modelPivot(obj)
    if not obj then return nil end
    local m = obj:IsA("Model") and obj or obj:FindFirstAncestorWhichIsA("Model")
    if m then
        local ok, cf = pcall(function() return m:GetPivot() end)
        if ok then return cf end
    end
    local p = partOf(obj)
    return p and p.CFrame or nil
end
local function tp(cf)
    local r = root()
    if not r or not cf then return false end
    local ok = pcall(function()
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        r.CFrame = cf
    end)
    return ok
end

local eggWords = {"egg","яйц","steal","take","grab","pickup","pick up","snatch"}
local badEggWords = {"hatch","grow","place","deposit","store","upgrade","buy","purchase","sell","collect cash","claim cash"}
local hatchWords = {"hatch","grow","incubat","place egg","place","deposit egg"}
local collectWords = {"collect","claim","cash","money","coins","income"}
local trainWords = {"treadmill","train","speed"}
local upgradeWords = {"upgrade","level up","improve"}
local baseWords = {"base","plot","pen","home","tycoon"}
local playerBaseWords = {"plot","base","home","tycoon","pen"}

local rarityScore = {
    secret=12000, cosmic=10500, divine=9000, mythic=7600, mythical=7600,
    legendary=6200, huge=5600, giant=4700, epic=3600, rare=2500,
    uncommon=1200, limited=8000, eternal=11000,
}

local function contextText(obj, depth)
    depth = depth or 5
    local out = {}
    local cur = obj
    for _=1, depth do
        if not cur then break end
        out[#out+1] = tostring(cur.Name or "")
        if cur:IsA("ProximityPrompt") then
            out[#out+1] = tostring(cur.ActionText or "")
            out[#out+1] = tostring(cur.ObjectText or "")
        end
        cur = cur.Parent
    end
    local p = partOf(obj)
    if p then
        for _, gui in ipairs(p:GetDescendants()) do
            if gui:IsA("TextLabel") or gui:IsA("TextButton") then
                local t = trim(gui.Text)
                if t ~= "" and #t < 120 then out[#out+1] = t end
            end
        end
    end
    return table.concat(out, " | ")
end

local function promptFire(p)
    if not p or not p.Parent or not p.Enabled then return false end
    if type(fireproximityprompt) == "function" then
        local old = p.HoldDuration
        local ok = pcall(function()
            p.HoldDuration = 0
            fireproximityprompt(p)
        end)
        pcall(function() p.HoldDuration = old end)
        return ok
    end
    local ok = pcall(function()
        p:InputHoldBegin()
        task.wait(math.max(0.03, math.min(0.12, p.HoldDuration)))
        p:InputHoldEnd()
    end)
    return ok
end

local function ownerMatches(obj)
    local cur = obj
    for _=1, 7 do
        if not cur then break end
        for _, key in ipairs({"Owner","OwnerName","PlayerName","Username","UserId","OwnerUserId","PlayerUserId"}) do
            local v = safe(function() return cur:GetAttribute(key) end)
            if v ~= nil then
                if tonumber(v) == LP.UserId or lower(v) == lower(LP.Name) or lower(v) == lower(LP.DisplayName) then
                    return true
                elseif tonumber(v) or tostring(v) ~= "" then
                    return false
                end
            end
            local child = cur:FindFirstChild(key)
            if child and child:IsA("ValueBase") then
                local cv = safe(function() return child.Value end)
                if typeof(cv) == "Instance" and cv == LP then return true end
                if tonumber(cv) == LP.UserId or lower(cv) == lower(LP.Name) or lower(cv) == lower(LP.DisplayName) then return true end
            end
        end
        cur = cur.Parent
    end
    return nil
end

local function looksLikeBase(obj)
    local text = contextText(obj, 4)
    return containsAny(text, baseWords)
end

local function findOwnBase()
    local r = root()
    local best, bestScore = nil, -math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart")) and looksLikeBase(obj) then
            local own = ownerMatches(obj)
            if own == true then
                local cf = modelPivot(obj)
                if cf then
                    local score = 10000
                    if r then score = score - (cf.Position-r.Position).Magnitude*0.01 end
                    if score > bestScore then best, bestScore = {obj=obj,cf=cf}, score end
                end
            end
        end
    end
    if best then
        q.baseCFrame = best.cf + Vector3.new(0, 3, 0)
        q.baseSource = best.obj:GetFullName()
        return q.baseCFrame
    end
    return nil
end

local function isPlayerEgg(prompt)
    local cur = prompt.Parent
    for _=1, 7 do
        if not cur then break end
        if containsAny(cur.Name, playerBaseWords) then
            local own = ownerMatches(cur)
            if own == true then return false end
            if own == false then return true end
        end
        cur = cur.Parent
    end
    return false
end

local function eggCandidate(p)
    if not p:IsA("ProximityPrompt") or not p.Enabled then return false end
    local text = contextText(p, 6)
    if not containsAny(text, eggWords) then return false end
    if containsAny(text, badEggWords) and not containsAny(text, {"steal","take","grab","pickup","pick up"}) then return false end
    if not q.stealPlayerEggs and isPlayerEgg(p) then return false end
    return true
end

local function scoreEgg(p, dist)
    local text = lower(contextText(p, 6))
    local s = 0
    for word, value in pairs(rarityScore) do
        if text:find(word,1,true) then s = math.max(s,value) end
    end
    local money = text:match("([%d%.]+)%s*[kmbtq]?%s*/%s*s")
    if money then s = s + math.min(1500, tonumber(money) or 0) end
    if isPlayerEgg(p) then s = s + 150 end
    s = s - math.min(1500, dist*0.04)
    return s, text
end

local function scanEggs(force)
    local now = os.clock()
    if not force and now-q.scanAt < 0.8 then return q.scanCache end
    q.scanAt = now
    local r = root()
    local list = {}
    if not r then q.scanCache = list return list end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and eggCandidate(obj) then
            local p = partOf(obj)
            if p then
                local dist = (p.Position-r.Position).Magnitude
                if dist < 100000 then
                    local score, text = scoreEgg(obj, dist)
                    if not q.rareOnly or score >= 2400 then
                        list[#list+1] = {prompt=obj, part=p, dist=dist, score=score, text=text}
                    end
                end
            end
        end
    end
    table.sort(list, function(a,b)
        if q.targetMode == "NEAREST" then return a.dist < b.dist end
        if a.score == b.score then return a.dist < b.dist end
        return a.score > b.score
    end)
    q.scanCache = list
    return list
end

local function chooseEgg()
    local list = scanEggs(false)
    local now = os.clock()
    for _, item in ipairs(list) do
        if (q.recent[item.prompt] or 0) < now then return item end
    end
    return list[1]
end

local function findPrompt(words, nearBase, extraWords)
    local center = nearBase and q.baseCFrame and q.baseCFrame.Position or (root() and root().Position)
    local best, bestDist
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local text = contextText(obj, 5)
            if containsAny(text, words) and (not extraWords or containsAny(text, extraWords)) then
                local p = partOf(obj)
                if p then
                    local d = center and (p.Position-center).Magnitude or 0
                    if (not nearBase or not center or d < 180) and (not bestDist or d < bestDist) then
                        best, bestDist = obj, d
                    end
                end
            end
        end
    end
    return best
end

local function carryLooksLikeEgg()
    local c = char()
    if not c then return false end
    for _, obj in ipairs(c:GetChildren()) do
        if containsAny(obj.Name, {"egg"}) then return true end
        if obj:IsA("Tool") and containsAny(contextText(obj,3), eggWords) then return true end
    end
    return false
end

local function returnToBase()
    if not q.baseCFrame then findOwnBase() end
    if not q.baseCFrame then return false end
    tp(q.baseCFrame)
    task.wait(0.16)
    local deposit = findPrompt({"place egg","deposit","store egg","drop egg","deliver"}, true)
    if deposit then
        local p = partOf(deposit)
        if p then tp(p.CFrame + Vector3.new(0,2.8,0)); task.wait(0.08) end
        promptFire(deposit)
        task.wait(0.12)
        tp(q.baseCFrame)
    end
    return true
end

local function stealOnce(token)
    if q.busy or not q.autoSteal or token ~= q.token then return end
    q.busy = true
    local ok, err = pcall(function()
        local item = chooseEgg()
        if not item then q.status = "яйца не найдены" return end
        q.status = "цель: " .. tostring(item.prompt.ObjectText ~= "" and item.prompt.ObjectText or item.part.Name)
        local old = root() and root().CFrame
        tp(item.part.CFrame + Vector3.new(0,2.8,0))
        task.wait(0.10)
        if not q.autoSteal or token ~= q.token then return end
        promptFire(item.prompt)
        q.recent[item.prompt] = os.clock()+1.25
        task.wait(0.18)
        if q.returnBase then
            returnToBase()
        elseif old then
            tp(old)
        end
    end)
    if not ok then q.status = "steal error: "..tostring(err) end
    q.busy = false
end

local function autoHatchTick()
    if not q.autoHatch or q.busy then return end
    if not q.baseCFrame then findOwnBase() end
    local p = findPrompt(hatchWords, true)
    if p then
        local part = partOf(p)
        if part then
            local old = root() and root().CFrame
            tp(part.CFrame + Vector3.new(0,2.6,0)); task.wait(0.06)
            promptFire(p); task.wait(0.08)
            if q.baseCFrame then tp(q.baseCFrame) elseif old then tp(old) end
        end
    end
end

local function cashPrompt(obj)
    local text = contextText(obj,5)
    return containsAny(text, collectWords) and not containsAny(text, {"egg","upgrade","buy","purchase","index","reward index"})
end

local function autoCollectTick()
    if not q.autoCollect or q.busy then return end
    if not q.baseCFrame then findOwnBase() end
    local center = q.baseCFrame and q.baseCFrame.Position
    if not center then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled and cashPrompt(obj) then
            local p = partOf(obj)
            if p and (p.Position-center).Magnitude < 150 then promptFire(obj) end
        elseif obj:IsA("BasePart") and containsAny(contextText(obj,3), {"collect cash","collect money","cash collector"}) then
            if (obj.Position-center).Magnitude < 150 and type(firetouchinterest)=="function" then
                local r = root()
                if r then pcall(firetouchinterest,r,obj,0); pcall(firetouchinterest,r,obj,1) end
            end
        end
    end
end

local function findTreadmill()
    local center = q.baseCFrame and q.baseCFrame.Position or (root() and root().Position)
    local best, bd
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and containsAny(contextText(obj,4), {"treadmill"}) then
            local d = center and (obj.Position-center).Magnitude or 0
            if not bd or d<bd then best,bd=obj,d end
        end
    end
    if best then return best end
    local p = findPrompt(trainWords, true)
    return p and partOf(p) or nil
end

local trainPhase = false
local function autoTrainTick()
    if not q.autoTrain or q.busy then return end
    if not q.baseCFrame then findOwnBase() end
    local belt = findTreadmill()
    if not belt then q.status = "treadmill не найден" return end
    local r = root()
    local h = humanoid()
    if not r or not h then return end
    trainPhase = not trainPhase
    local offset = trainPhase and 2.2 or -2.2
    local cf = belt.CFrame * CFrame.new(offset, math.max(2.5,belt.Size.Y/2+2.2), 0)
    tp(cf)
    pcall(function() h:Move(Vector3.new(trainPhase and 1 or -1,0,0), false) end)
    local prompt = belt:FindFirstChildWhichIsA("ProximityPrompt",true)
    if prompt and containsAny(contextText(prompt,4), trainWords) then promptFire(prompt) end
end

local function upgradeTick(kind)
    if q.busy then return end
    local enabled = kind=="treadmill" and q.autoUpgradeTreadmill or q.autoUpgradeBase
    if not enabled then return end
    if not q.baseCFrame then findOwnBase() end
    local extra = kind=="treadmill" and {"treadmill","speed"} or {"base","pen","storage","capacity"}
    local p = findPrompt(upgradeWords, true, extra)
    if p then promptFire(p) end
end

local function clearEsp()
    for _, v in pairs(q.esp) do pcall(function() v:Destroy() end) end
    q.esp = {}
end
local function refreshEsp()
    if not q.eggEsp then clearEsp() return end
    local list = scanEggs(true)
    local keep = {}
    for i, item in ipairs(list) do
        if i > 60 then break end
        local p = item.part
        local gui = q.esp[p]
        if not gui or not gui.Parent then
            gui = Instance.new("BillboardGui")
            gui.Name = "EggHubESP"
            gui.AlwaysOnTop = true
            gui.Size = UDim2.fromOffset(180,42)
            gui.StudsOffset = Vector3.new(0,3.5,0)
            gui.Adornee = p
            gui.Parent = q.uiRoot
            local l = Instance.new("TextLabel")
            l.Name = "Text"
            l.Size = UDim2.fromScale(1,1)
            l.BackgroundColor3 = Color3.fromRGB(14,14,18)
            l.BackgroundTransparency = 0.25
            l.TextColor3 = Color3.fromRGB(255,225,230)
            l.TextStrokeTransparency = 0.4
            l.Font = Enum.Font.GothamBold
            l.TextSize = 12
            l.TextWrapped = true
            l.Parent = gui
            local c = Instance.new("UICorner") c.CornerRadius=UDim.new(0,7) c.Parent=l
            q.esp[p]=gui
        end
        keep[p]=true
        local l=gui:FindFirstChild("Text")
        if l then
            local name = item.prompt.ObjectText ~= "" and item.prompt.ObjectText or p.Name
            l.Text = tostring(name).."\n"..math.floor(item.dist).." studs | score "..math.floor(item.score)
        end
    end
    for p, gui in pairs(q.esp) do if not keep[p] then pcall(function() gui:Destroy() end) q.esp[p]=nil end end
end

local savedVisual = {}
local function setLowGraphics(on)
    q.lowGraphics = on
    if on then
        savedVisual.GlobalShadows = Lighting.GlobalShadows
        savedVisual.Brightness = Lighting.Brightness
        pcall(function() Lighting.GlobalShadows=false end)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                if savedVisual[obj]==nil then savedVisual[obj]=obj.Enabled end
                pcall(function() obj.Enabled=false end)
            elseif obj:IsA("BasePart") then
                if savedVisual[obj]==nil then savedVisual[obj]={obj.Material,obj.CastShadow} end
                pcall(function() obj.Material=Enum.Material.Plastic obj.CastShadow=false end)
            end
        end
        pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
    else
        for obj,v in pairs(savedVisual) do
            if typeof(obj)=="Instance" and obj.Parent then
                if type(v)=="boolean" then pcall(function() obj.Enabled=v end)
                elseif type(v)=="table" then pcall(function() obj.Material=v[1] obj.CastShadow=v[2] end) end
            end
        end
        if savedVisual.GlobalShadows~=nil then pcall(function() Lighting.GlobalShadows=savedVisual.GlobalShadows end) end
        savedVisual={}
    end
end

local function diagnosticReport()
    local lines = {}
    lines[#lines+1] = "EggHub diagnostic "..VERSION
    lines[#lines+1] = "PlaceId="..tostring(game.PlaceId).." JobId="..tostring(game.JobId)
    lines[#lines+1] = "base="..tostring(q.baseSource or "manual/none")
    local eggs=scanEggs(true)
    lines[#lines+1] = "\n[EGG PROMPTS] "..#eggs
    for i,item in ipairs(eggs) do
        if i>50 then break end
        lines[#lines+1] = string.format("%02d | %s | A=%s | O=%s | d=%d | score=%d",i,item.prompt:GetFullName(),tostring(item.prompt.ActionText),tostring(item.prompt.ObjectText),math.floor(item.dist),math.floor(item.score))
    end
    lines[#lines+1] = "\n[RELATED REMOTES]"
    local count=0
    for _,obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and containsAny(obj:GetFullName(), {"egg","steal","hatch","grow","base","plot","cash","money","speed","treadmill","upgrade","pet","pen","collect"}) then
            count=count+1
            if count<=120 then lines[#lines+1]=obj.ClassName.." | "..obj:GetFullName() end
        end
    end
    lines[#lines+1] = "remoteCount="..count
    return table.concat(lines,"\n")
end

-- UI -------------------------------------------------------------------------
local uiParent = PlayerGui
if type(gethui)=="function" then local ok,v=pcall(gethui) if ok and typeof(v)=="Instance" then uiParent=v end end
local old = uiParent:FindFirstChild("EggHub")
if old then old:Destroy() end
local gui=Instance.new("ScreenGui")
gui.Name="EggHub" gui.ResetOnSpawn=false gui.IgnoreGuiInset=false gui.DisplayOrder=999999 gui.Parent=uiParent
q.uiRoot=gui

local main=Instance.new("Frame")
main.Name="Main" main.Size=UDim2.fromOffset(430,438) main.Position=UDim2.new(0.5,-215,0.5,-219)
main.BackgroundColor3=Color3.fromRGB(15,15,19) main.BorderSizePixel=0 main.Active=true main.Parent=gui
local mc=Instance.new("UICorner") mc.CornerRadius=UDim.new(0,14) mc.Parent=main
local stroke=Instance.new("UIStroke") stroke.Color=Color3.fromRGB(190,38,58) stroke.Thickness=1.4 stroke.Transparency=.2 stroke.Parent=main

local header=Instance.new("Frame") header.Size=UDim2.new(1,0,0,50) header.BackgroundColor3=Color3.fromRGB(24,17,21) header.BorderSizePixel=0 header.Parent=main
local hc=Instance.new("UICorner") hc.CornerRadius=UDim.new(0,14) hc.Parent=header
local cover=Instance.new("Frame") cover.Size=UDim2.new(1,0,0,16) cover.Position=UDim2.new(0,0,1,-16) cover.BackgroundColor3=header.BackgroundColor3 cover.BorderSizePixel=0 cover.Parent=header
local title=Instance.new("TextLabel") title.BackgroundTransparency=1 title.Position=UDim2.fromOffset(14,6) title.Size=UDim2.new(1,-80,0,22) title.Text="EGG HUB  •  Steal An Egg" title.TextColor3=Color3.fromRGB(255,238,241) title.Font=Enum.Font.GothamBold title.TextSize=17 title.TextXAlignment=Enum.TextXAlignment.Left title.Parent=header
local sub=Instance.new("TextLabel") sub.BackgroundTransparency=1 sub.Position=UDim2.fromOffset(14,27) sub.Size=UDim2.new(1,-80,0,16) sub.Text="v"..VERSION.."  |  adaptive" sub.TextColor3=Color3.fromRGB(164,132,140) sub.Font=Enum.Font.Gotham sub.TextSize=11 sub.TextXAlignment=Enum.TextXAlignment.Left sub.Parent=header
local close=Instance.new("TextButton") close.Size=UDim2.fromOffset(34,30) close.Position=UDim2.new(1,-42,0,10) close.BackgroundColor3=Color3.fromRGB(48,26,31) close.Text="×" close.TextColor3=Color3.fromRGB(255,220,225) close.Font=Enum.Font.GothamBold close.TextSize=20 close.Parent=header
local cc=Instance.new("UICorner") cc.CornerRadius=UDim.new(0,8) cc.Parent=close

local status=Instance.new("TextLabel") status.BackgroundTransparency=1 status.Position=UDim2.fromOffset(14,55) status.Size=UDim2.new(1,-28,0,20) status.Text="готово" status.TextColor3=Color3.fromRGB(190,185,190) status.Font=Enum.Font.Gotham status.TextSize=11 status.TextXAlignment=Enum.TextXAlignment.Left status.Parent=main

local tabs=Instance.new("Frame") tabs.BackgroundTransparency=1 tabs.Position=UDim2.fromOffset(12,78) tabs.Size=UDim2.new(1,-24,0,34) tabs.Parent=main
local tabNames={"ФАРМ","ЦЕЛИ","РАЗНОЕ"}
local pages={}
local tabButtons={}
for i,name in ipairs(tabNames) do
    local b=Instance.new("TextButton") b.Size=UDim2.new(1/3,-4,1,0) b.Position=UDim2.new((i-1)/3,(i-1)*2,0,0) b.BackgroundColor3=Color3.fromRGB(30,27,31) b.Text=name b.TextColor3=Color3.fromRGB(200,190,194) b.Font=Enum.Font.GothamBold b.TextSize=12 b.Parent=tabs
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=b
    tabButtons[i]=b
    local p=Instance.new("ScrollingFrame") p.Name=name p.Position=UDim2.fromOffset(12,118) p.Size=UDim2.new(1,-24,1,-132) p.BackgroundTransparency=1 p.BorderSizePixel=0 p.ScrollBarThickness=3 p.ScrollBarImageColor3=Color3.fromRGB(120,45,58) p.CanvasSize=UDim2.fromOffset(0,0) p.AutomaticCanvasSize=Enum.AutomaticSize.Y p.Visible=i==1 p.Parent=main
    local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,7) lay.SortOrder=Enum.SortOrder.LayoutOrder lay.Parent=p
    pages[i]=p
end
local function showTab(idx)
    for i,p in ipairs(pages) do p.Visible=i==idx tabButtons[i].BackgroundColor3=i==idx and Color3.fromRGB(104,30,43) or Color3.fromRGB(30,27,31) tabButtons[i].TextColor3=i==idx and Color3.fromRGB(255,240,243) or Color3.fromRGB(200,190,194) end
end
for i,b in ipairs(tabButtons) do b.Activated:Connect(function() showTab(i) end) end
showTab(1)

local toggleButtons={}
local function makeToggle(parent,label,key,onChange)
    local b=Instance.new("TextButton") b.Size=UDim2.new(1,-4,0,36) b.BackgroundColor3=Color3.fromRGB(29,29,34) b.Text="" b.Parent=parent
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,9) c.Parent=b
    local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.Position=UDim2.fromOffset(11,0) l.Size=UDim2.new(1,-72,1,0) l.Text=label l.TextColor3=Color3.fromRGB(235,230,233) l.Font=Enum.Font.GothamMedium l.TextSize=13 l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=b
    local pill=Instance.new("Frame") pill.Size=UDim2.fromOffset(42,20) pill.Position=UDim2.new(1,-53,.5,-10) pill.BorderSizePixel=0 pill.Parent=b
    local pc=Instance.new("UICorner") pc.CornerRadius=UDim.new(1,0) pc.Parent=pill
    local dot=Instance.new("Frame") dot.Size=UDim2.fromOffset(16,16) dot.Position=UDim2.fromOffset(2,2) dot.BorderSizePixel=0 dot.Parent=pill
    local dc=Instance.new("UICorner") dc.CornerRadius=UDim.new(1,0) dc.Parent=dot
    local function redraw()
        local on=q[key]
        pill.BackgroundColor3=on and Color3.fromRGB(160,38,57) or Color3.fromRGB(64,61,66)
        dot.BackgroundColor3=on and Color3.fromRGB(255,230,234) or Color3.fromRGB(185,180,184)
        dot.Position=on and UDim2.fromOffset(24,2) or UDim2.fromOffset(2,2)
    end
    b.Activated:Connect(function() q[key]=not q[key] redraw() if onChange then onChange(q[key]) end end)
    redraw() toggleButtons[key]=redraw
    return b
end
local function makeAction(parent,label,cb)
    local b=Instance.new("TextButton") b.Size=UDim2.new(1,-4,0,36) b.BackgroundColor3=Color3.fromRGB(44,25,30) b.Text=label b.TextColor3=Color3.fromRGB(255,228,233) b.Font=Enum.Font.GothamBold b.TextSize=12 b.Parent=parent
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,9) c.Parent=b
    b.Activated:Connect(cb)
    return b
end
local function makeCycle(parent,label,get,cycle)
    local b=makeAction(parent,"")
    local function draw() b.Text=label..":  "..tostring(get()) end
    b.Activated:Connect(function() cycle() draw() end)
    draw() return b,draw
end

makeToggle(pages[1],"Авто кража яиц","autoSteal",function(on)
    q.token=q.token+1
    if on then
        if not q.baseCFrame then findOwnBase() end
        local t=q.token
        task.spawn(function()
            while q.alive and q.autoSteal and t==q.token do stealOnce(t) task.wait(0.12) end
        end)
    else q.busy=false end
end)
makeToggle(pages[1],"Возвращаться на базу","returnBase")
makeToggle(pages[1],"Авто hatch / place","autoHatch")
makeToggle(pages[1],"Авто сбор денег","autoCollect")
makeToggle(pages[1],"Авто тренировка Speed","autoTrain")
makeToggle(pages[1],"Авто апгрейд treadmill","autoUpgradeTreadmill")
makeToggle(pages[1],"Авто апгрейд pen / base","autoUpgradeBase")
makeAction(pages[1],"НАЙТИ МОЮ БАЗУ",function()
    if findOwnBase() then q.status="база найдена" else q.status="автопоиск не нашёл базу" end
end)
makeAction(pages[1],"ЗАПОМНИТЬ ТЕКУЩЕЕ МЕСТО КАК БАЗУ",function()
    local r=root() if r then q.baseCFrame=r.CFrame q.baseSource="manual" q.status="база сохранена вручную" end
end)
makeAction(pages[1],"TP НА БАЗУ",function() if not q.baseCFrame then findOwnBase() end if q.baseCFrame then tp(q.baseCFrame) end end)

makeCycle(pages[2],"Режим цели",function() return q.targetMode end,function() q.targetMode=q.targetMode=="BEST" and "NEAREST" or "BEST" q.scanAt=0 end)
makeToggle(pages[2],"Красть яйца игроков","stealPlayerEggs",function() q.scanAt=0 end)
makeToggle(pages[2],"Только Rare+","rareOnly",function() q.scanAt=0 end)
makeToggle(pages[2],"ESP яиц","eggEsp",function(on) if not on then clearEsp() else refreshEsp() end end)
makeAction(pages[2],"TP К ЛУЧШЕМУ ЯЙЦУ",function() local x=chooseEgg() if x then tp(x.part.CFrame+Vector3.new(0,2.8,0)) end end)
makeAction(pages[2],"ПЕРЕСКАНИРОВАТЬ ЯЙЦА",function() local x=scanEggs(true) q.status="найдено яиц/промптов: "..#x refreshEsp() end)

makeToggle(pages[3],"Anti AFK","antiAfk")
makeToggle(pages[3],"Low graphics","lowGraphics",setLowGraphics)
makeAction(pages[3],"ULTRA BLACK SCREEN",function() q.ultraBlack=true end)
makeAction(pages[3],"СКОПИРОВАТЬ ДИАГНОСТИКУ",function()
    local report=diagnosticReport()
    if type(setclipboard)=="function" then pcall(setclipboard,report) q.status="диагностика скопирована" else print(report) q.status="setclipboard нет — отчёт в console" end
end)
makeAction(pages[3],"HARD STOP ВСЕГО",function()
    q.autoSteal=false q.autoHatch=false q.autoCollect=false q.autoTrain=false q.autoUpgradeTreadmill=false q.autoUpgradeBase=false q.token=q.token+1 q.busy=false
    for _,k in ipairs({"autoSteal","autoHatch","autoCollect","autoTrain","autoUpgradeTreadmill","autoUpgradeBase"}) do if toggleButtons[k] then toggleButtons[k]() end end
    q.status="всё остановлено"
end)

-- proper mouse/touch drag
local dragging=false local dragStart=nil local startPos=nil
header.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true dragStart=input.Position startPos=main.Position end
end)
q.conns[#q.conns+1]=UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
q.conns[#q.conns+1]=UserInputService.InputChanged:Connect(function(input)
    if dragging and dragStart and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-dragStart main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)

local black=Instance.new("Frame") black.Name="UltraBlack" black.Size=UDim2.fromScale(1,1) black.BackgroundColor3=Color3.new(0,0,0) black.BorderSizePixel=0 black.Visible=false black.ZIndex=9999998 black.Parent=gui
local restore=Instance.new("TextButton") restore.Size=UDim2.fromOffset(150,42) restore.Position=UDim2.new(.5,-75,.5,-21) restore.BackgroundColor3=Color3.fromRGB(35,35,38) restore.Text="ВОССТАНОВИТЬ" restore.TextColor3=Color3.fromRGB(240,240,242) restore.Font=Enum.Font.GothamBold restore.TextSize=13 restore.ZIndex=9999999 restore.Parent=black
local rc=Instance.new("UICorner") rc.CornerRadius=UDim.new(0,10) rc.Parent=restore
restore.Activated:Connect(function() q.ultraBlack=false pcall(function() RunService:Set3dRenderingEnabled(true) end) end)

q.conns[#q.conns+1]=LP.Idled:Connect(function()
    if not q.antiAfk then return end
    pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.zero) end)
end)
q.conns[#q.conns+1]=LP.CharacterAdded:Connect(function()
    q.busy=false task.wait(1) if q.autoSteal and not q.baseCFrame then findOwnBase() end
end)

local lastHatch,lastCollect,lastTrain,lastUpgrade,lastEsp=0,0,0,0,0
q.conns[#q.conns+1]=RunService.Heartbeat:Connect(function()
    if not q.alive then return end
    local now=os.clock()
    status.Text=q.status.."  |  eggs "..tostring(#q.scanCache).."  |  "..q.targetMode
    if now-lastHatch>.7 then lastHatch=now autoHatchTick() end
    if now-lastCollect>.75 then lastCollect=now autoCollectTick() end
    if now-lastTrain>.16 then lastTrain=now autoTrainTick() end
    if now-lastUpgrade>1.2 then lastUpgrade=now upgradeTick("treadmill") upgradeTick("base") end
    if now-lastEsp>1.1 then lastEsp=now if q.eggEsp then refreshEsp() end end
    if black.Visible~=q.ultraBlack then
        black.Visible=q.ultraBlack
        if q.ultraBlack then pcall(function() RunService:Set3dRenderingEnabled(false) end) end
    end
end)

function q:Stop(reason)
    if not self.alive then return end
    self.alive=false self.autoSteal=false self.token=self.token+1
    clearEsp()
    if self.lowGraphics then pcall(function() setLowGraphics(false) end) end
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    for _,c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
    self.conns={}
    if self.uiRoot then pcall(function() self.uiRoot:Destroy() end) end
    self.status="stopped: "..tostring(reason or "manual")
end
close.Activated:Connect(function() q:Stop("closed") end)

task.spawn(function()
    task.wait(1)
    if game.PlaceId ~= TARGET_PLACE then q.status="ВНИМАНИЕ: другой PlaceId "..tostring(game.PlaceId) end
    if not q.baseCFrame then findOwnBase() end
    scanEggs(true)
end)

q.startupReady=true
print("EggHub "..VERSION.." loaded | Steal An Egg")
return q
