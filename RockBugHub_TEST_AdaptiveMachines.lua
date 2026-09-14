-- RockBugHub TEST T42: low-overhead strength-adaptive machine selection
local Players=game:GetService("Players")
local player=Players.LocalPlayer
if not player then return end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local runtime=env.RockBugRuntime
if type(runtime)~="table"then return end

if env.RockBugAdaptiveMachines and type(env.RockBugAdaptiveMachines.Destroy)=="function"then
    pcall(env.RockBugAdaptiveMachines.Destroy)
end

local patch={alive=true,lastStrength=nil,lastMachineId=nil,switching=false,connections={},candidates={},nextThreshold=nil,catalogCount=-1}
env.RockBugAdaptiveMachines=patch
runtime.adaptiveMachine=true

local function disconnectAll()
    for _,c in ipairs(patch.connections)do pcall(function()c:Disconnect()end)end
    patch.connections={}
end
local function connect(signal,fn)
    local c=signal:Connect(fn)
    table.insert(patch.connections,c)
    return c
end
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
    else n=n:gsub(",","")end
    local num=tonumber(n)
    if not num then return nil end
    local mul={k=1e3,m=1e6,b=1e9,t=1e12,q=1e15}
    return num*(mul[suffix]or 1)
end

-- Use the counter the base script already found. No repeated GetDescendants scans.
local strengthCounter=nil
local strengthConnection=nil
local function findStrengthCounter()
    local c=runtime.sessionStrengthCounter
    if c and c.Parent and c:IsA("ValueBase")then return c end
    local leader=player:FindFirstChild("leaderstats")
    for _,container in ipairs({leader,player})do
        if container then
            for _,name in ipairs({"Strength","strength","Сила","сила"})do
                local v=container:FindFirstChild(name)
                if v and v:IsA("ValueBase")then return v end
            end
        end
    end
    return nil
end
local function readStrength()
    local c=strengthCounter
    if c and c.Parent then
        local ok,v=pcall(function()return parseNumber(c.Value)end)
        if ok and v and v>=0 then return v end
    end
    local v=parseNumber(runtime.sessionStrengthCurrent)
    return v and math.max(0,v)or nil
end

-- Priority requested by the user. Requirement only decides whether the machine is accessible.
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
local function machineName(machine)
    if not machine then return "—" end
    local base=tostring(machine.label or machine.name or machine.kind or"Тренажёр")
    local variant=tostring(machine.variant or"")
    if variant~=""and not string.lower(base):find(string.lower(variant),1,true)then base=base.." • "..variant end
    return base
end

-- Cache the already-scanned machine catalog. This never walks workspace itself.
local function rebuildCandidates()
    local list={}
    for _,machine in ipairs(runtime.machineCatalog or{})do
        if machine and machine.seat and machine.seat.Parent then list[#list+1]=machine end
    end
    patch.candidates=list
    patch.catalogCount=#(runtime.machineCatalog or{})
end
local function requestCatalogOnce(force)
    if type(runtime.refreshMachineCatalog)=="function"and not runtime.machineScanInFlight then
        pcall(runtime.refreshMachineCatalog,force==true)
    end
end
local function ensureCatalog()
    local count=#(runtime.machineCatalog or{})
    if count==0 then requestCatalogOnce(false)return false end
    if count~=patch.catalogCount then rebuildCandidates()end
    return #patch.candidates>0
end
local function bestMachineFor(strength)
    local best=nil
    for _,machine in ipairs(patch.candidates)do
        if machine.seat and machine.seat.Parent then
            local req=tonumber(machine.requirement)or 0
            if req<=strength and better(machine,best)then best=machine end
        end
    end
    return best
end
local function computeNextThreshold(strength)
    local threshold=nil
    for _,machine in ipairs(patch.candidates)do
        local req=tonumber(machine.requirement)or 0
        if req>strength and (not threshold or req<threshold)then threshold=req end
    end
    patch.nextThreshold=threshold
end

local machineRef=runtime.leverRefs and runtime.leverRefs.machineFarm
local originalSet=machineRef and machineRef.Set or nil
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
        if patch.alive and runtime.alive and originalSet and wanted.seat and wanted.seat.Parent then pcall(originalSet,true,false)end
        patch.switching=false
    end)
end
local function chooseBest(force,strength)
    if not patch.alive or not ensureCatalog()then
        runtime.adaptiveMachineStatus=runtime.language=="en"and"Searching for machines..."or"Ищу тренажёры..."
        return nil,false
    end
    strength=strength or readStrength()
    runtime.adaptiveMachineStrength=strength
    if strength==nil then
        runtime.adaptiveMachineStatus=runtime.language=="en"and"Strength not found"or"Сила не найдена"
        return nil,false
    end
    local best=bestMachineFor(strength)
    if not best then
        runtime.adaptiveMachineStatus=(runtime.language=="en"and"Strength "or"Сила ")..compact(strength)..(runtime.language=="en"and" • no accessible machine"or" • доступный тренажёр не найден")
        computeNextThreshold(strength)
        return nil,false
    end
    local changed=force or not runtime.selectedMachine or runtime.selectedMachine.id~=best.id
    runtime.selectedMachine=best
    runtime.machineZone=best.zone
    runtime.adaptiveMachineName=machineName(best)
    runtime.adaptiveMachineRequirement=tonumber(best.requirement)or 0
    runtime.adaptiveMachineStatus=(runtime.language=="en"and"Strength "or"Сила ")..compact(strength).." • "..machineName(best)
    patch.lastStrength=strength
    patch.lastMachineId=best.id
    computeNextThreshold(strength)
    if changed and type(runtime.refreshMachineUI)=="function"then pcall(runtime.refreshMachineUI)end
    return best,changed
end

local function onStrengthChanged()
    if not patch.alive then return end
    local strength=readStrength()
    if strength==nil then return end
    runtime.adaptiveMachineStrength=strength
    -- Most strength gains do nothing: only recalculate when a machine threshold is crossed.
    if patch.lastStrength==nil or strength<patch.lastStrength or (patch.nextThreshold and strength>=patch.nextThreshold)then
        local best,changed=chooseBest(false,strength)
        switchIfNeeded(best,changed)
    else
        patch.lastStrength=strength
    end
end
local function bindStrengthCounter()
    local current=findStrengthCounter()
    if current==strengthCounter then return end
    if strengthConnection then pcall(function()strengthConnection:Disconnect()end)strengthConnection=nil end
    strengthCounter=current
    if current then
        strengthConnection=current:GetPropertyChangedSignal("Value"):Connect(onStrengthChanged)
        table.insert(patch.connections,strengthConnection)
    end
end

if machineRef and type(originalSet)=="function"then
    machineRef.Set=function(nextValue,silent)
        if nextValue then
            bindStrengthCounter()
            local best=chooseBest(true)
            if not best then requestCatalogOnce(true)task.wait(0.15)chooseBest(true)end
        end
        return originalSet(nextValue,silent)
    end
end

local function applyHologramUI()
    local holo=runtime.hologram
    if type(holo)~="table"or holo.destroyed or holo.group~="farm"then return end
    local card=type(holo.cards)=="table"and holo.cards[2]or nil
    if not card then return end
    local ru=runtime.language~="en"
    local best=runtime.selectedMachine
    local strength=runtime.adaptiveMachineStrength or readStrength()
    if card.primary and card.primary.text then card.primary.text.Text=ru and"Автотренажёр"or"Auto machine"end
    if card.more and card.more.text then card.more.text.Text=(ru and"Лучший: "or"Best: ")..machineName(best).."  →"end
    if card.hint then card.hint.Text=strength and((ru and"Сила: "or"Strength: ")..compact(strength).."  •  "..machineName(best))or(ru and"Сила не найдена"or"Strength not found")end
end

-- Slow housekeeping only. No RenderStepped/Heartbeat loop and no periodic workspace scan.
task.spawn(function()
    requestCatalogOnce(false)
    while patch.alive and runtime.alive do
        bindStrengthCounter()
        local count=#(runtime.machineCatalog or{})
        if count>0 and count~=patch.catalogCount then
            rebuildCandidates()
            local best,changed=chooseBest(false)
            switchIfNeeded(best,changed)
        elseif runtime.selectedMachine and (not runtime.selectedMachine.seat or not runtime.selectedMachine.seat.Parent)then
            requestCatalogOnce(true)
        end
        if not strengthCounter then onStrengthChanged()end -- fallback only when no ValueBase is available
        applyHologramUI()
        task.wait(0.75)
    end
end)

function patch.Destroy()
    if not patch.alive then return end
    patch.alive=false
    if strengthConnection then pcall(function()strengthConnection:Disconnect()end)strengthConnection=nil end
    disconnectAll()
    if machineRef and originalSet and machineRef.Set~=originalSet then machineRef.Set=originalSet end
    if env.RockBugAdaptiveMachines==patch then env.RockBugAdaptiveMachines=nil end
end

bindStrengthCounter()
if #(runtime.machineCatalog or{})>0 then rebuildCandidates()end
chooseBest(true)
applyHologramUI()
return patch