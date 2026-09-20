-- RockBugHub TEST boss rarity filter T66
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")

local env=_G
if type(getgenv)=="function"then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table"then env=v end
end

local runtime=env.RockBugRuntime
if type(runtime)~="table"or runtime.alive==false then return end
if type(runtime.bossAdapter)~="table"or type(runtime.bossAdapter.scan)~="function"or type(runtime.bossAdapter.info)~="function"then return end
if not runtime.layoutUI or not runtime.layoutUI.bossPage then return end

local old=env.RockBugBossRarityFilter
if type(old)=="table"and type(old.Destroy)=="function"then pcall(old.Destroy)end

local order={"COMMON","UNCOMMON","RARE","EPIC","LEGENDARY","MYTHIC","UNIQUE"}
local labels={
    COMMON={"ОБЫЧНЫЙ","COMMON"},
    UNCOMMON={"UNCOMMON","UNCOMMON"},
    RARE={"РЕДКИЙ","RARE"},
    EPIC={"ЭПИЧЕСКИЙ","EPIC"},
    LEGENDARY={"ЛЕГЕНД.","LEGEND."},
    MYTHIC={"МИФИЧЕСКИЙ","MYTHIC"},
    UNIQUE={"УНИКАЛЬНЫЙ","UNIQUE"},
}
local colors={
    COMMON=Color3.fromRGB(122,132,145),
    UNCOMMON=Color3.fromRGB(76,178,111),
    RARE=Color3.fromRGB(64,136,225),
    EPIC=Color3.fromRGB(148,91,222),
    LEGENDARY=Color3.fromRGB(225,153,57),
    MYTHIC=Color3.fromRGB(220,73,105),
    UNIQUE=Color3.fromRGB(52,196,188),
}

local saved=env.RockBugBossRaritySettings
if type(saved)~="table"then
    saved={}
    for _,r in ipairs(order)do saved[r]=true end
    env.RockBugBossRaritySettings=saved
else
    for _,r in ipairs(order)do
        if type(saved[r])~="boolean"then saved[r]=true end
    end
end

local state={
    alive=true,
    runtime=runtime,
    settings=saved,
    connections={},
    buttons={},
    originalScan=runtime.bossAdapter.scan,
    card=nil,
}
env.RockBugBossRarityFilter=state
runtime.bossRarityFilter=state

local function keep(c)
    state.connections[#state.connections+1]=c
    return c
end

local function norm(v)
    return tostring(v or""):upper():gsub("[^A-Z]","")
end

local exact={
    COMMONBOSS="COMMON",
    UNCOMMONBOSS="UNCOMMON",
    RAREBOSS="RARE",
    EPICBOSS="EPIC",
    LEGENDARYBOSS="LEGENDARY",
    MYTHICBOSS="MYTHIC",
    MYTHICALBOSS="MYTHIC",
    UNIQUEBOSS="UNIQUE",
}

local function rarityOf(info)
    if type(info)~="table"then return nil end
    for _,value in ipairs({
        info.name,
        info.modelName,
        info.model and info.model.Name,
    })do
        local r=exact[norm(value)]
        if r then return r end
    end
    return nil
end

local function selectedCount()
    local n=0
    for _,r in ipairs(order)do if saved[r]==true then n=n+1 end end
    return n
end

local function rootPart()
    local p=Players.LocalPlayer
    local c=p and p.Character
    return c and (c:FindFirstChild("HumanoidRootPart")or c:FindFirstChild("Torso"))or nil
end

local function filteredScan()
    if not state.alive then return {} end

    -- Let the original TEST scanner seed its internal boss/link caches first.
    local ok,seed=pcall(state.originalScan)
    if not ok then return {} end
    if selectedCount()==0 then return {} end

    local out={}
    local seen=setmetatable({},{__mode="k"})
    local me=rootPart()

    local function push(info)
        if type(info)~="table"or not info.model or seen[info.model]then return end
        seen[info.model]=true
        local r=rarityOf(info)
        if not r or saved[r]~=true or info.alive~=true then return end
        info.rarity=r
        if me and info.root and info.root.Parent then
            info.filterDistance=(me.Position-info.root.Position).Magnitude
        else
            info.filterDistance=math.huge
        end
        out[#out+1]=info
    end

    for _,info in ipairs(type(seed)=="table"and seed or{})do push(info)end

    -- Core TEST returns only its single best boss. Walk cached models too so a
    -- disabled COMMON boss cannot hide an allowed MYTHIC/UNIQUE boss nearby.
    for _,node in ipairs(workspace:GetDescendants())do
        if node:IsA("Model")and not seen[node]then
            local good,info=pcall(runtime.bossAdapter.info,node)
            if good and info then push(info)end
        end
    end

    table.sort(out,function(a,b)
        local ac=tonumber(a.confidence)or 0
        local bc=tonumber(b.confidence)or 0
        if ac~=bc then return ac>bc end
        return(tonumber(a.filterDistance)or math.huge)<(tonumber(b.filterDistance)or math.huge)
    end)
    return out
end

runtime.bossAdapter.scan=filteredScan

local page=runtime.layoutUI.bossPage
local previous=page:FindFirstChild("BossRarityFilterCard")
if previous then previous:Destroy()end

local card=Instance.new("Frame")
card.Name="BossRarityFilterCard"
card.Size=UDim2.new(1,-4,0,184)
card.BackgroundColor3=Color3.fromRGB(28,61,79)
card.BackgroundTransparency=0.08
card.BorderSizePixel=0
card.LayoutOrder=2
card.Parent=page
state.card=card
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,14)
corner.Parent=card
local stroke=Instance.new("UIStroke")
stroke.Color=Color3.fromRGB(65,224,255)
stroke.Transparency=0.48
stroke.Thickness=1
stroke.Parent=card

local title=Instance.new("TextLabel")
title.BackgroundTransparency=1
title.Position=UDim2.fromOffset(10,7)
title.Size=UDim2.new(1,-112,0,22)
title.Font=Enum.Font.GothamBold
title.TextSize=10
title.TextXAlignment=Enum.TextXAlignment.Left
title.TextColor3=Color3.fromRGB(193,236,247)
title.Parent=card

local allBtn=Instance.new("TextButton")
allBtn.Size=UDim2.fromOffset(42,22)
allBtn.Position=UDim2.new(1,-96,0,7)
allBtn.BackgroundColor3=Color3.fromRGB(43,82,100)
allBtn.BorderSizePixel=0
allBtn.Font=Enum.Font.GothamBold
allBtn.TextSize=8
allBtn.TextColor3=Color3.fromRGB(225,245,250)
allBtn.Parent=card
local ac=Instance.new("UICorner")ac.CornerRadius=UDim.new(1,0)ac.Parent=allBtn

local noneBtn=Instance.new("TextButton")
noneBtn.Size=UDim2.fromOffset(42,22)
noneBtn.Position=UDim2.new(1,-49,0,7)
noneBtn.BackgroundColor3=Color3.fromRGB(43,82,100)
noneBtn.BorderSizePixel=0
noneBtn.Font=Enum.Font.GothamBold
noneBtn.TextSize=8
noneBtn.TextColor3=Color3.fromRGB(225,245,250)
noneBtn.Parent=card
local nc=Instance.new("UICorner")nc.CornerRadius=UDim.new(1,0)nc.Parent=noneBtn

local grid=Instance.new("Frame")
grid.BackgroundTransparency=1
grid.Position=UDim2.fromOffset(9,38)
grid.Size=UDim2.new(1,-18,0,132)
grid.Parent=card
local layout=Instance.new("UIGridLayout")
layout.CellSize=UDim2.new(1/3,-5,0,38)
layout.CellPadding=UDim2.fromOffset(7,7)
layout.FillDirectionMaxCells=3
layout.SortOrder=Enum.SortOrder.LayoutOrder
layout.Parent=grid

local function tr(pair)
    return runtime.language=="en"and pair[2]or pair[1]
end

local function paint(r)
    local b=state.buttons[r]
    if not b then return end
    local on=saved[r]==true
    local col=colors[r]
    b.Text=tr(labels[r])
    b.BackgroundColor3=on and col:Lerp(Color3.new(0,0,0),0.48)or Color3.fromRGB(39,67,80)
    b.TextColor3=on and Color3.fromRGB(248,250,252)or Color3.fromRGB(151,183,194)
    local s=b:FindFirstChildOfClass("UIStroke")
    if s then s.Color=col s.Transparency=on and 0.16 or 0.72 end
end

local function refreshText()
    title.Text=runtime.language=="en"and"BOSS RARITY FILTER"or"ФИЛЬТР РЕДКОСТИ БОССА"
    allBtn.Text=runtime.language=="en"and"ALL"or"ВСЕ"
    noneBtn.Text=runtime.language=="en"and"NONE"or"НЕТ"
    for _,r in ipairs(order)do paint(r)end
end

local function changed()
    if runtime.bossCycle then runtime.bossCycle.nextScan=0 end
    if type(runtime.refreshBossUI)=="function"then pcall(runtime.refreshBossUI)end
end

for i,r in ipairs(order)do
    local b=Instance.new("TextButton")
    b.Name="BossRarity_"..r
    b.LayoutOrder=i
    b.BackgroundColor3=Color3.fromRGB(39,67,80)
    b.BorderSizePixel=0
    b.Font=Enum.Font.GothamBold
    b.TextSize=8
    b.AutoButtonColor=false
    b.Parent=grid
    local c=Instance.new("UICorner")c.CornerRadius=UDim.new(0,9)c.Parent=b
    local s=Instance.new("UIStroke")s.Thickness=1 s.Parent=b
    state.buttons[r]=b
    keep(b.Activated:Connect(function()
        saved[r]=not(saved[r]==true)
        paint(r)
        changed()
    end))
end

keep(allBtn.Activated:Connect(function()
    for _,r in ipairs(order)do saved[r]=true paint(r)end
    changed()
end))
keep(noneBtn.Activated:Connect(function()
    for _,r in ipairs(order)do saved[r]=false paint(r)end
    changed()
end))

-- Keep labels in sync if TEST language changes.
local lastLanguage=runtime.language
keep(RunService.Heartbeat:Connect(function()
    if not state.alive then return end
    if runtime.language~=lastLanguage then
        lastLanguage=runtime.language
        refreshText()
    end
end))

-- Put the old live-boss card after the new filter card.
for _,obj in ipairs(page:GetChildren())do
    if obj:IsA("Frame")and obj~=card then
        local found=false
        for _,d in ipairs(obj:GetDescendants())do
            if d:IsA("TextLabel")then
                local t=tostring(d.Text or""):upper()
                if t:find("ТЕКУЩИЙ БОСС",1,true)or t:find("CURRENT BOSS",1,true)then
                    found=true break
                end
            end
        end
        if found then obj.LayoutOrder=3 break end
    end
end

refreshText()

function state.Destroy()
    if not state.alive then return end
    state.alive=false
    if runtime.bossAdapter and runtime.bossAdapter.scan==filteredScan then
        runtime.bossAdapter.scan=state.originalScan
    end
    for _,c in ipairs(state.connections)do pcall(function()c:Disconnect()end)end
    state.connections={}
    if state.card and state.card.Parent then state.card:Destroy()end
    if env.RockBugBossRarityFilter==state then env.RockBugBossRarityFilter=nil end
    if runtime.bossRarityFilter==state then runtime.bossRarityFilter=nil end
end

return state
