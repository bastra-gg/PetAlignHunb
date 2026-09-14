-- RockBugHub TEST T46: event-driven durability-adaptive rocks + manual selection
local Players=game:GetService("Players")
local player=Players.LocalPlayer
if not player then return end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local runtime=env.RockBugRuntime
if type(runtime)~="table"then return end

if env.RockBugAdaptiveRocks and type(env.RockBugAdaptiveRocks.Destroy)=="function"then
    pcall(env.RockBugAdaptiveRocks.Destroy)
end

local patch={alive=true,auto=true,lastDurability=nil,lastRock=nil,lastSource=nil,applying=false,connections={},sourceConnection=nil}
env.RockBugAdaptiveRocks=patch
runtime.adaptiveRocks=true

local rocks={
    {id="AncientJungle",label="Древний лес",en="Ancient Jungle",req=10000000,mult=16.25},
    {id="MuscleKing",label="Король мышц",en="Muscle King",req=5000000,mult=12.5},
    {id="Legends",label="Легенды",en="Legends",req=1000000,mult=2.5},
    {id="Inferno",label="Инферно",en="Inferno",req=750000,mult=1.125},
    {id="Mystic",label="Мистический",en="Mystic",req=400000,mult=0.75},
    {id="Frozen",label="Ледяной",en="Frozen",req=150000,mult=0.375},
    {id="Golden",label="Золотой",en="Golden",req=5000,mult=0.2},
    {id="Large",label="Большой",en="Large",req=100,mult=0.075},
    {id="Punching",label="Пробивной",en="Punching",req=10,mult=0.05},
    {id="Tiny",label="Маленький",en="Tiny",req=0,mult=0.025},
}

local function compact(value)
    value=tonumber(value)
    if not value then return "—" end
    local abs=math.abs(value)
    for _,unit in ipairs({{1e15,"Q"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}})do
        if abs>=unit[1]then
            local s=("%.2f%s"):format(value/unit[1],unit[2])
            return s:gsub("%.00([KMBTQ])$","%1"):gsub("(%.[0-9])0([KMBTQ])$","%1%2")
        end
    end
    return tostring(math.floor(value+0.5))
end

local function parseNumber(value)
    if type(value)=="number"then return value end
    local s=tostring(value or""):lower():gsub("%s+","")
    local n,suffix=s:match("^([%+%-]?[%d%.,]+)([kmbtq]?)$")
    if not n then return tonumber(value)end
    if n:find(",",1,true)and not n:find("%.")then
        local a,b=n:match("^(%-?%d+),(%d+)$")
        if a and b and #b<=2 then n=a.."."..b else n=n:gsub(",","")end
    else
        n=n:gsub(",","")
    end
    local num=tonumber(n)
    if not num then return nil end
    return num*(({k=1e3,m=1e6,b=1e9,t=1e12,q=1e15})[suffix]or 1)
end

local function durabilityScore(object)
    if not object or not object:IsA("ValueBase")then return nil end
    local name=string.lower(tostring(object.Name or""))
    local score=0
    if name=="durability"then score=1000
    elseif name:find("durability",1,true)then score=900
    elseif name=="endurance"or name:find("endurance",1,true)then score=620
    elseif name:find("долговеч",1,true)or name:find("прочност",1,true)or name:find("вынослив",1,true)then score=600
    else return nil end
    if name:find("mult",1,true)or name:find("boost",1,true)or name:find("gain",1,true)or name:find("percent",1,true)or name:find("required",1,true)or name:find("needed",1,true)then score-=900 end
    local leader=player:FindFirstChild("leaderstats")
    if leader and object:IsDescendantOf(leader)then score+=180 end
    return score
end

local source=nil
local function findSource()
    if source and source.Parent then return source end
    local best,bestScore=nil,-math.huge
    local ok,list=pcall(function()return player:GetDescendants()end)
    if ok then
        for _,object in ipairs(list)do
            local score=durabilityScore(object)
            if score and score>bestScore then
                local good,v=pcall(function()return parseNumber(object.Value)end)
                if good and v and v>=0 then best,bestScore=object,score end
            end
        end
    end
    source=best
    return source
end

local function readDurability()
    local object=findSource()
    if object then
        local ok,v=pcall(function()return parseNumber(object.Value)end)
        if ok and v and v>=0 then return v,object:GetFullName()end
    end
    for _,key in ipairs({"Durability","durability"})do
        local ok,v=pcall(function()return parseNumber(player:GetAttribute(key))end)
        if ok and v and v>=0 then return v,"attribute:"..key end
    end
    return nil,nil
end

local function bestRockFor(durability)
    if durability==nil then return nil end
    for _,rock in ipairs(rocks)do if durability>=rock.req then return rock end end
    return rocks[#rocks]
end

local function rockName(rock)
    if not rock then return "—" end
    if runtime.layoutUI and type(runtime.layoutUI.rockName)=="function"then
        local ok,name=pcall(runtime.layoutUI.rockName,rock)
        if ok and type(name)=="string"and name~=""then return name end
    end
    return runtime.language=="en"and rock.en or rock.label
end

local function findRefreshButton()
    local root=runtime.uiRoot
    if not root then return nil end
    for _,obj in ipairs(root:GetDescendants())do
        if obj:IsA("TextButton")then
            local t=tostring(obj.Text or""):upper()
            if t:find("↻",1,true)and(t:find("КАМНИ",1,true)or t:find("ROCKS",1,true))then return obj end
        end
    end
    return nil
end

local refreshBusy=false
local function refreshPhysicalRocks()
    if refreshBusy then return end
    local button=findRefreshButton()
    if not button then return end
    refreshBusy=true
    task.spawn(function()
        local fired=false
        if type(firesignal)=="function"then fired=pcall(function()firesignal(button.Activated)end)end
        if not fired then pcall(function()button:Activate()end)end
        task.wait(0.15)
        -- The base refresh temporarily re-enables its rebirth selector; adaptive mode owns it here.
        runtime.autoRockSelection=false
        refreshBusy=false
    end)
end

local function applyClassicUI()
    local ui=runtime.ui
    local layout=runtime.layoutUI
    if type(ui)~="table"or type(layout)~="table"then return end
    local ru=runtime.language~="en"
    if layout.autoRockButton and layout.autoRockButton.Parent then layout.autoRockButton.Visible=true end
    if layout.chooseRockButton and layout.chooseRockButton.Parent then
        layout.chooseRockButton.Visible=true
        layout.chooseRockButton.Parent.Visible=true
    end
    if ui.autoRockTitle and ui.autoRockTitle.Parent then
        ui.autoRockTitle.Text=patch.auto and(ru and"АВТОПОБОР ПО ДОЛГОВЕЧНОСТИ"or"AUTO ROCK BY DURABILITY")or(ru and"РУЧНАЯ НАСТРОЙКА"or"MANUAL SELECTION")
    end
    local selected=runtime.selectedRock
    if ui.autoRockName and ui.autoRockName.Parent and selected then
        ui.autoRockName.Text=rockName(selected)..(patch.auto and""or(ru and"  •  вручную"or"  •  manual"))
    end
    if ui.autoRockStats and ui.autoRockStats.Parent then
        local d=runtime.adaptiveRockDurability
        if patch.auto then
            ui.autoRockStats.Text=d and((ru and"Долговечность: "or"Durability: ")..compact(d).."  •  "..rockName(selected))or(ru and"Долговечность не найдена"or"Durability not found")
        elseif selected then
            ui.autoRockStats.Text=(ru and"Выбран вручную: "or"Manual: ")..rockName(selected)..(d and("  •  "..(ru and"долговечность "or"durability ")..compact(d))or"")
        end
    end
    if type(runtime.refreshRockList)=="function"then pcall(runtime.refreshRockList)end
end

local function applyHologramUI()
    local holo=runtime.hologram
    if type(holo)~="table"or holo.destroyed or holo.group~="farm"then return end
    local card=type(holo.cards)=="table"and holo.cards[1]or nil
    if not card then return end
    local ru=runtime.language~="en"
    local selected=runtime.selectedRock
    local d=runtime.adaptiveRockDurability
    if card.primary and card.primary.text then card.primary.text.Text=ru and"Автоудар"or"Auto punch"end
    if card.more and card.more.text then
        card.more.text.Text=(patch.auto and(ru and"Лучший: "or"Best: ")or(ru and"Вручную: "or"Manual: "))..rockName(selected).."  →"
    end
    if card.hint then
        card.hint.Text=d and((ru and"Долговечность: "or"Durability: ")..compact(d).."  •  "..rockName(selected))or(ru and"Долговечность не найдена"or"Durability not found")
    end
end

local function applySelection(force)
    if not patch.alive or not patch.auto then return false end
    local durability,sourceName=readDurability()
    runtime.adaptiveRockDurability=durability
    patch.lastSource=sourceName
    if durability==nil then
        runtime.adaptiveRockStatus=runtime.language=="en"and"Durability not found"or"Долговечность не найдена"
        applyClassicUI()applyHologramUI()
        return false
    end
    local rock=bestRockFor(durability)
    if not rock then return false end
    local changed=force or not runtime.selectedRock or runtime.selectedRock.id~=rock.id
    patch.applying=true
    runtime.autoRockSelection=false
    runtime.selectedRock=rock
    runtime.adaptiveRockRequirement=rock.req
    runtime.adaptiveRockName=rockName(rock)
    runtime.adaptiveRockStatus=(runtime.language=="en"and"Durability "or"Долговечность ")..compact(durability).." • "..rockName(rock)
    runtime.autoRockReason=runtime.adaptiveRockStatus
    runtime.autoRockCalc={durability=durability,requirement=rock.req,adaptive=true}
    patch.lastDurability=durability
    patch.lastRock=rock.id
    patch.applying=false
    if changed then refreshPhysicalRocks()end
    applyClassicUI()applyHologramUI()
    return changed
end

local function setAuto(value)
    patch.auto=value==true
    runtime.autoRockSelection=false
    if patch.auto then applySelection(true)else applyClassicUI()applyHologramUI()end
end

local function disconnectSource()
    if patch.sourceConnection then pcall(function()patch.sourceConnection:Disconnect()end)patch.sourceConnection=nil end
end
local function bindSource()
    disconnectSource()
    local object=findSource()
    if not object then return end
    patch.sourceConnection=object:GetPropertyChangedSignal("Value"):Connect(function()
        if not patch.alive then return end
        local value=parseNumber(object.Value)
        if patch.auto and value~=patch.lastDurability then applySelection(false)end
    end)
end

local bugRef=runtime.leverRefs and runtime.leverRefs.bug
local originalBugSet=bugRef and bugRef.Set or nil
if bugRef and type(originalBugSet)=="function"then
    bugRef.Set=function(nextValue,silent)
        if nextValue and patch.auto then applySelection(false)end
        return originalBugSet(nextValue,silent)
    end
end

local autoButton=runtime.layoutUI and runtime.layoutUI.autoRockButton
if autoButton then
    table.insert(patch.connections,autoButton.Activated:Connect(function()
        task.defer(function()if patch.alive then setAuto(true)end end)
    end))
end

local chooseButton=runtime.layoutUI and runtime.layoutUI.chooseRockButton
if chooseButton then
    table.insert(patch.connections,chooseButton.Activated:Connect(function()
        -- Do not disable immediately; the picker may be cancelled. A selectedRock change below switches to manual.
    end))
end

for _,key in ipairs({"Durability","durability"})do
    table.insert(patch.connections,player:GetAttributeChangedSignal(key):Connect(function()
        if patch.auto then applySelection(false)end
    end))
end

table.insert(patch.connections,player.DescendantAdded:Connect(function(obj)
    if durabilityScore(obj)then
        source=nil
        bindSource()
        if patch.auto then applySelection(false)end
    end
end))
table.insert(patch.connections,player.DescendantRemoving:Connect(function(obj)
    if obj==source then source=nil disconnectSource()end
end))

-- Lightweight watchdog: detects manual slider/picker changes and recovers if the stat object respawns.
task.spawn(function()
    local nextUI=0
    while patch.alive and runtime.alive do
        if patch.auto and not patch.applying and runtime.selectedRock and patch.lastRock and runtime.selectedRock.id~=patch.lastRock then
            patch.auto=false
            runtime.autoRockSelection=false
            applyClassicUI()applyHologramUI()
        end
        if not source or not source.Parent then source=nil bindSource()if patch.auto then applySelection(false)end end
        if os.clock()>=nextUI then nextUI=os.clock()+0.6 applyHologramUI()end
        task.wait(0.25)
    end
end)

function patch.Destroy()
    if not patch.alive then return end
    patch.alive=false
    disconnectSource()
    for _,connection in ipairs(patch.connections)do pcall(function()connection:Disconnect()end)end
    if bugRef and originalBugSet and bugRef.Set~=originalBugSet then bugRef.Set=originalBugSet end
    if env.RockBugAdaptiveRocks==patch then env.RockBugAdaptiveRocks=nil end
end

bindSource()
setAuto(true)
return patch
