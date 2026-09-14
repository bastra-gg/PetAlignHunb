-- RockBugHub TEST T41: strength-adaptive machine selection
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
if not player then return end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local runtime=env.RockBugRuntime
if type(runtime)~="table"then return end

if env.RockBugAdaptiveMachines and type(env.RockBugAdaptiveMachines.Destroy)=="function"then
    pcall(env.RockBugAdaptiveMachines.Destroy)
end

local patch={alive=true,lastStrength=nil,lastMachineId=nil,switching=false}
env.RockBugAdaptiveMachines=patch
runtime.adaptiveMachine=true

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
    local mul={k=1e3,m=1e6,b=1e9,t=1e12,q=1e15}
    return num*(mul[suffix]or 1)
end

local cachedStrength=nil
local function strengthScore(object)
    if not object or not object:IsA("ValueBase")then return nil end
    local name=string.lower(tostring(object.Name or""))
    local score=0
    if name=="strength"then score=1000
    elseif name:find("strength",1,true)then score=850
    elseif name=="сила"or name:find("сил",1,true)then score=700
    else return nil end
    if name:find("gain",1,true)or name:find("mult",1,true)or name:find("boost",1,true)or name:find("percent",1,true)or name:find("required",1,true)or name:find("needed",1,true)then score=score-900 end
    local leader=player:FindFirstChild("leaderstats")
    if leader and object:IsDescendantOf(leader)then score=score+180 end
    return score
end

local function readStrength()
    local session=parseNumber(runtime.sessionStrengthCurrent)
    if session and session>=0 then return session,"runtime"end
    if cachedStrength and cachedStrength.Parent then
        local ok,v=pcall(function()return parseNumber(cachedStrength.Value)end)
        if ok and v and v>=0 then return v,cachedStrength:GetFullName()end
    end
    for _,key in ipairs({"Strength","strength"})do
        local ok,v=pcall(function()return player:GetAttribute(key)end)
        if ok then v=parseNumber(v)if v and v>=0 then return v,"attribute:"..key end end
    end
    local best,bestScore=nil,-math.huge
    local ok,list=pcall(function()return player:GetDescendants()end)
    if ok then
        for _,object in ipairs(list)do
            local score=strengthScore(object)
            if score and score>bestScore then
                local good,v=pcall(function()return parseNumber(object.Value)end)
                if good and v and v>=0 then best,bestScore=object,score end
            end
        end
    end
    cachedStrength=best
    if best then
        local good,v=pcall(function()return parseNumber(best.Value)end)
        if good and v then return v,best:GetFullName()end
    end
    return nil,nil
end

-- User priority: Deadlift first, then the lying/bench machine, then the other lifts.
-- Inside one type: the strongest accessible requirement wins; Big beats Small when requirements tie.
local function typePriority(machine)
    local text=string.lower(table.concat({tostring(machine.kind or""),tostring(machine.name or""),tostring(machine.label or"")}," "))
    if text:find("deadlift",1,true)or text:find("dead lift",1,true)then return 900 end
    if text:find("bench",1,true)or text:find("bench press",1,true)then return 800 end
    if text:find("bar lift",1,true)or text:find("barlift",1,true)or text:find("barbell",1,true)then return 700 end
    if text:find(" lift",1,true)or text:find("lifting",1,true)or text:find("weight",1,true)then return 650 end
    if text:find("squat",1,true)then return 500 end
    if text:find("pull up",1,true)or text:find("pullup",1,true)then return 400 end
    if text:find("boulder",1,true)then return 300 end
    if text:find("treadmill",1,true)or text:find("tread",1,true)then return 200 end
    return 100
end

local function sizePriority(machine)
    local v=string.lower(tostring(machine.variant or machine.explicitVariant or""))
    if v:find("big",1,true)or v:find("large",1,true)then return 30 end
    if v:find("medium",1,true)then return 20 end
    if v:find("tiny",1,true)or v:find("small",1,true)or v:find("mini",1,true)then return 10 end
    return tonumber(machine.variantOrder)or tonumber(machine.sizeScore)or 0
end

local function better(a,b)
    if not b then return true end
    local ap,bp=typePriority(a),typePriority(b)
    if ap~=bp then return ap>bp end
    local ar,br=tonumber(a.requirement)or 0,tonumber(b.requirement)or 0
    if ar~=br then return ar>br end
    local as,bs=sizePriority(a),sizePriority(b)
    if as~=bs then return as>bs end
    local az,bz=tonumber(a.zoneOrder)or 0,tonumber(b.zoneOrder)or 0
    if az~=bz then return az>bz end
    return tostring(a.id or"")<tostring(b.id or"")
end

local function bestMachineFor(strength)
    if strength==nil then return nil end
    local best=nil
    for _,machine in ipairs(runtime.machineCatalog or{})do
        local seat=machine and machine.seat
        local req=tonumber(machine and machine.requirement)or 0
        if machine and seat and seat.Parent and req<=strength and better(machine,best)then best=machine end
    end
    return best
end

local function machineName(machine)
    if not machine then return "—" end
    local base=tostring(machine.label or machine.name or machine.kind or"Тренажёр")
    local variant=tostring(machine.variant or"")
    if variant~=""and not string.lower(base):find(string.lower(variant),1,true)then base=base.." • "..variant end
    return base
end

local function ensureCatalog()
    if #(runtime.machineCatalog or{})>0 then return true end
    if type(runtime.refreshMachineCatalog)=="function"and not runtime.machineScanInFlight then
        pcall(runtime.refreshMachineCatalog,false)
    end
    return false
end

local function chooseBest(force)
    if not patch.alive then return nil end
    if not ensureCatalog()then
        runtime.adaptiveMachineStatus=runtime.language=="en"and"Searching for machines..."or"Ищу тренажёры..."
        return nil
    end
    local strength=readStrength()
    runtime.adaptiveMachineStrength=strength
    if strength==nil then
        runtime.adaptiveMachineStatus=runtime.language=="en"and"Strength not found"or"Сила не найдена"
        return nil
    end
    local best=bestMachineFor(strength)
    if not best then
        runtime.adaptiveMachineStatus=(runtime.language=="en"and"Strength "or"Сила ")..compact(strength)..(runtime.language=="en"and" • no accessible machine"or" • доступный тренажёр не найден")
        return nil
    end
    local changed=force or not runtime.selectedMachine or runtime.selectedMachine.id~=best.id
    runtime.selectedMachine=best
    runtime.machineZone=best.zone
    runtime.adaptiveMachineName=machineName(best)
    runtime.adaptiveMachineRequirement=tonumber(best.requirement)or 0
    runtime.adaptiveMachineStatus=(runtime.language=="en"and"Strength "or"Сила ")..compact(strength).." • "..machineName(best)
    patch.lastStrength=strength
    patch.lastMachineId=best.id
    if type(runtime.refreshMachineUI)=="function"then pcall(runtime.refreshMachineUI)end
    return best,changed
end

local machineRef=runtime.leverRefs and runtime.leverRefs.machineFarm
local originalSet=nil
if machineRef and type(machineRef.Set)=="function"then
    originalSet=machineRef.Set
    machineRef.Set=function(nextValue,silent)
        if nextValue then chooseBest(true)end
        return originalSet(nextValue,silent)
    end
end

local function applyHologramUI()
    local holo=runtime.hologram
    if type(holo)~="table"or holo.destroyed or holo.group~="farm"then return end
    local cards=holo.cards
    local card=type(cards)=="table"and cards[2]or nil
    if not card then return end
    local ru=runtime.language~="en"
    local best=runtime.selectedMachine
    local strength=runtime.adaptiveMachineStrength
    if card.primary and card.primary.text then card.primary.text.Text=ru and"Автотренажёр"or"Auto machine"end
    if card.more and card.more.text then card.more.text.Text=(ru and"Лучший: "or"Best: ")..machineName(best).."  →"end
    if card.hint then
        card.hint.Text=strength and((ru and"Сила: "or"Strength: ")..compact(strength).."  •  "..machineName(best))or(ru and"Сила не найдена"or"Strength not found")
    end
end

local function switchIfNeeded(best,changed)
    if not changed or not best or not runtime.machineActive or patch.switching then return end
    if runtime.machineAttachInFlight or runtime.networkPaused or runtime.fuseSession or runtime.bossRestorePending then return end
    patch.switching=true
    task.spawn(function()
        local wanted=best
        if type(runtime.stopMachineFarm)=="function"then pcall(runtime.stopMachineFarm,nil)
        elseif originalSet then pcall(originalSet,false,false)end
        runtime.selectedMachine=wanted
        runtime.machineZone=wanted.zone
        task.wait(0.18)
        if patch.alive and runtime.alive and originalSet and wanted.seat and wanted.seat.Parent then
            pcall(originalSet,true,false)
        end
        patch.switching=false
    end)
end

local binding="RockBugAdaptiveMachinesT41_"..tostring(player.UserId)
local nextRead=0
local nextCatalogRefresh=0
pcall(function()RunService:UnbindFromRenderStep(binding)end)
RunService:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value+3,function()
    if not patch.alive or not runtime.alive then return end
    local now=os.clock()
    if now>=nextCatalogRefresh then
        nextCatalogRefresh=now+12
        if type(runtime.refreshMachineCatalog)=="function"and not runtime.machineScanInFlight then pcall(runtime.refreshMachineCatalog,true)end
    end
    if now>=nextRead then
        nextRead=now+0.5
        local best,changed=chooseBest(false)
        switchIfNeeded(best,changed)
    end
    applyHologramUI()
end)

function patch.Destroy()
    if not patch.alive then return end
    patch.alive=false
    pcall(function()RunService:UnbindFromRenderStep(binding)end)
    if machineRef and originalSet and machineRef.Set~=originalSet then machineRef.Set=originalSet end
    if env.RockBugAdaptiveMachines==patch then env.RockBugAdaptiveMachines=nil end
end

chooseBest(true)
applyHologramUI()
return patch