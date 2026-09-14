-- RockBugHub TEST T48: gym-only auto machines + real manual takeover
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

local patch={
    alive=true,
    auto=false,
    applying=false,
    switching=false,
    manualArmed=false,
    manualWasActive=false,
    manualOldId=nil,
    manualArmedAt=0,
    lastStrength=nil,
    lastAutoMachineId=nil,
    nextThreshold=nil,
    catalogCount=-1,
    candidates={},
    connections={},
    strengthConnection=nil,
    primaryButton=nil,
    originalPrimary=nil,
}
env.RockBugAdaptiveMachines=patch
runtime.adaptiveMachine=true
runtime.adaptiveMachineAuto=false

local GYMS={
    ["Frost Gym"]=4,
    ["Mythical Gym"]=5,
    ["Eternal Gym"]=6,
    ["Legend Gym"]=7,
    ["Muscle King Gym"]=8,
    ["Jungle Gym"]=9,
    ["Industrial Gym"]=10,
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

local function machineId(machine)
    return machine and tostring(machine.id or"")or nil
end

local function machineName(machine)
    if not machine then return "—" end
    local base=tostring(machine.label or machine.name or machine.kind or"Тренажёр")
    local variant=tostring(machine.variant or machine.explicitVariant or"")
    if variant~=""and not string.lower(base):find(string.lower(variant),1,true)then
        base=base.." • "..variant
    end
    return base
end

local strengthCounter=nil
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
    if strengthCounter and strengthCounter.Parent then
        local ok,v=pcall(function()return parseNumber(strengthCounter.Value)end)
        if ok and v and v>=0 then return v end
    end
    local v=parseNumber(runtime.sessionStrengthCurrent)
    return v and math.max(0,v)or nil
end

local function typePriority(machine)
    local text=string.lower(table.concat({tostring(machine.kind or""),tostring(machine.name or""),tostring(machine.label or"")}," "))
    if text:find("deadlift",1,true)or text:find("dead lift",1,true)then return 900 end
    if text:find("bench",1,true)or text:find("bench press",1,true)then return 800 end
    if text:find("bar lift",1,true)or text:find("barlift",1,true)or text:find("barbell",1,true)then return 700 end
    if text:find(" lift",1,true)or text:find("lifting",1,true)or text:find("weight",1,true)then return 650 end
    if text:find("squat",1,true)then return 500 end
    if text:find("pull up",1,true)or text:find("pullup",1,true)or text:find("pull-up",1,true)then return 400 end
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

local function rebuildCandidates()
    local list={}
    for _,machine in ipairs(runtime.machineCatalog or{})do
        if machine and machine.seat and machine.seat.Parent and GYMS[tostring(machine.zone or"")]then
            list[#list+1]=machine
        end
    end
    patch.candidates=list
    patch.catalogCount=#(runtime.machineCatalog or{})
end

local function requestCatalog(force)
    if type(runtime.refreshMachineCatalog)=="function"and not runtime.machineScanInFlight then
        pcall(runtime.refreshMachineCatalog,force==true)
    end
end

local function ensureCatalog()
    local count=#(runtime.machineCatalog or{})
    if count==0 then requestCatalog(false)return false end
    if count~=patch.catalogCount then rebuildCandidates()end
    return #patch.candidates>0
end

-- Auto mode is strictly gym based. Starter/Tiny/Beach can never be selected here.
local function bestMachineFor(strength)
    local bestZone,bestZoneOrder=nil,-math.huge
    for _,machine in ipairs(patch.candidates)do
        local req=tonumber(machine.requirement)or 0
        local zo=GYMS[tostring(machine.zone or"")]
        if zo and req<=strength and zo>bestZoneOrder then
            bestZone,bestZoneOrder=machine.zone,zo
        end
    end
    if not bestZone then return nil end

    local best=nil
    for _,machine in ipairs(patch.candidates)do
        if machine.zone==bestZone and (tonumber(machine.requirement)or 0)<=strength then
            if not best then
                best=machine
            else
                local ap,bp=typePriority(machine),typePriority(best)
                local ar,br=tonumber(machine.requirement)or 0,tonumber(best.requirement)or 0
                local as,bs=sizePriority(machine),sizePriority(best)
                if ap>bp or (ap==bp and (ar>br or (ar==br and as>bs)))then best=machine end
            end
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

local function recommendation()
    if not ensureCatalog()then return nil,nil end
    local strength=readStrength()
    if strength==nil then return nil,nil end
    return bestMachineFor(strength),strength
end

local function refreshUI()
    if type(runtime.refreshMachineUI)=="function"then pcall(runtime.refreshMachineUI)end
    local holo=runtime.hologram
    if type(holo)~="table"or holo.destroyed or holo.group~="farm"then return end
    local card=type(holo.cards)=="table"and holo.cards[2]or nil
    if not card then return end
    local ru=runtime.language~="en"
    local selected=runtime.selectedMachine
    local best,strength=recommendation()
    if card.primary and card.primary.text then card.primary.text.Text=ru and"Автотренажёр"or"Auto machine"end
    if card.more and card.more.text then card.more.text.Text=ru and"Залы и тренажёры  →"or"Gyms & machines  →"end
    if card.hint then
        if patch.auto then
            local current=selected or best
            card.hint.Text=strength and((ru and"АВТО • Сила "or"AUTO • Strength ")..compact(strength).." • "..tostring(current and current.zone or"—").." • "..machineName(current))or(ru and"Сила не найдена"or"Strength not found")
        elseif selected then
            card.hint.Text=(ru and"Вручную • "or"Manual • ")..tostring(selected.zone or"—").." • "..machineName(selected)
        elseif best then
            card.hint.Text=(ru and"Лучший доступный • "or"Best available • ")..tostring(best.zone or"—").." • "..machineName(best)
        else
            card.hint.Text=ru and"В залах тренажёр не найден"or"No gym machine found"
        end
    end
end

local function selectBest(force)
    if not patch.alive or not patch.auto then return nil,false end
    if not ensureCatalog()then return nil,false end
    local strength=readStrength()
    runtime.adaptiveMachineStrength=strength
    if strength==nil then return nil,false end
    local best=bestMachineFor(strength)
    computeNextThreshold(strength)
    patch.lastStrength=strength
    if not best then return nil,false end
    local changed=force or machineId(runtime.selectedMachine)~=machineId(best)
    patch.applying=true
    runtime.selectedMachine=best
    runtime.machineZone=best.zone
    patch.lastAutoMachineId=machineId(best)
    runtime.adaptiveMachineName=machineName(best)
    runtime.adaptiveMachineRequirement=tonumber(best.requirement)or 0
    runtime.adaptiveMachineStatus=(runtime.language=="en"and"Strength "or"Сила ")..compact(strength).." • "..tostring(best.zone).." • "..machineName(best)
    patch.applying=false
    refreshUI()
    return best,changed
end

local machineRef=runtime.leverRefs and runtime.leverRefs.machineFarm
local originalSet=machineRef and machineRef.Set or nil
local originalGet=machineRef and machineRef.Get or nil

local function setAuto(value)
    patch.auto=value==true
    runtime.adaptiveMachineAuto=patch.auto
    if not patch.auto then patch.lastAutoMachineId=nil end
    refreshUI()
end

local function restartOn(machine)
    if not machine or patch.switching or not originalSet then return end
    patch.switching=true
    task.spawn(function()
        local wanted=machine
        -- Let the core finish its own stop/detach before starting the new seat.
        local untilAt=os.clock()+1.2
        while patch.alive and runtime.machineActive and os.clock()<untilAt do task.wait(0.04)end
        if not patch.alive or not runtime.alive or not wanted.seat or not wanted.seat.Parent then patch.switching=false return end
        patch.applying=true
        runtime.selectedMachine=wanted
        runtime.machineZone=wanted.zone
        patch.applying=false
        pcall(originalSet,true,false)
        patch.switching=false
        refreshUI()
    end)
end

local function switchAutoMachine(best,changed)
    if not patch.auto or not changed or not best or not runtime.machineActive or patch.switching or not originalSet then return end
    patch.switching=true
    task.spawn(function()
        local wanted=best
        pcall(originalSet,false,true)
        local untilAt=os.clock()+1.2
        while patch.alive and runtime.machineActive and os.clock()<untilAt do task.wait(0.04)end
        if patch.alive and runtime.alive and patch.auto and wanted.seat and wanted.seat.Parent then
            patch.applying=true runtime.selectedMachine=wanted runtime.machineZone=wanted.zone patch.applying=false
            pcall(originalSet,true,false)
        end
        patch.switching=false
        refreshUI()
    end)
end

local function armManual()
    if not patch.alive then return end
    patch.manualArmed=true
    patch.manualWasActive=runtime.machineActive==true or (originalGet and originalGet()==true) or false
    patch.manualOldId=machineId(runtime.selectedMachine)
    patch.manualArmedAt=os.clock()
end

local function finishManual(machine)
    if not patch.manualArmed then return end
    local old=patch.manualOldId
    local new=machineId(machine)
    if not new or new==old then return end
    local resume=patch.manualWasActive
    patch.manualArmed=false
    patch.manualWasActive=false
    patch.manualOldId=nil
    setAuto(false)
    -- Core's picker stops the current machine before assigning the new one.
    -- If training was running, immediately continue on the newly selected machine.
    if resume then restartOn(machine)end
end

-- Arm manual takeover from the actual detailed location/machine rows, not by guessing
-- from a delayed selectedMachine poll.
local layout=runtime.layoutUI
for _,control in ipairs({layout and layout.machineZoneSelection,layout and layout.machineSelection})do
    local row=control and control.Row
    if row and row:IsA("GuiButton")then
        table.insert(patch.connections,row.Activated:Connect(armManual))
    end
end

-- The detailed toggle uses the currently selected machine. It does NOT force auto mode.
if machineRef and type(originalSet)=="function"then
    machineRef.Set=function(nextValue,silent)
        if nextValue and patch.auto and not patch.manualArmed then
            local best=selectBest(false)
            if not best then requestCatalog(true)task.wait(0.12)selectBest(false)end
        elseif not nextValue and not patch.switching and not patch.manualArmed then
            setAuto(false)
        end
        return originalSet(nextValue,silent)
    end
end

-- Main card is the only control that explicitly means AUTO: choose best gym + machine.
local function bindMainCard()
    local holo=runtime.hologram
    local card=type(holo)=="table"and type(holo.cards)=="table"and holo.cards[2]or nil
    local primary=card and card.primary or nil
    if not primary or patch.primaryButton==primary then return end
    patch.primaryButton=primary
    patch.originalPrimary=primary.callback
    primary.callback=function()
        if not originalSet or not originalGet then return end
        local on=originalGet()==true
        if on then
            setAuto(false)
            originalSet(false,false)
        else
            setAuto(true)
            local best=selectBest(true)
            if not best then
                requestCatalog(true)
                task.wait(0.18)
                best=selectBest(true)
            end
            if best then originalSet(true,false)end
        end
        refreshUI()
    end
end

local function onStrengthChanged()
    if not patch.alive or not patch.auto then return end
    local strength=readStrength()
    if strength==nil then return end
    runtime.adaptiveMachineStrength=strength
    if patch.lastStrength==nil or strength<patch.lastStrength or (patch.nextThreshold and strength>=patch.nextThreshold)then
        local best,changed=selectBest(false)
        switchAutoMachine(best,changed)
    else
        patch.lastStrength=strength
    end
end

local function bindStrengthCounter()
    local current=findStrengthCounter()
    if current==strengthCounter then return end
    if patch.strengthConnection then pcall(function()patch.strengthConnection:Disconnect()end)patch.strengthConnection=nil end
    strengthCounter=current
    if current then patch.strengthConnection=current:GetPropertyChangedSignal("Value"):Connect(onStrengthChanged)end
end

bindStrengthCounter()
requestCatalog(false)

task.spawn(function()
    local lastSelected=machineId(runtime.selectedMachine)
    while patch.alive and runtime.alive do
        bindStrengthCounter()
        bindMainCard()

        local count=#(runtime.machineCatalog or{})
        if count>0 and count~=patch.catalogCount then
            rebuildCandidates()
            if patch.auto then
                local best,changed=selectBest(false)
                switchAutoMachine(best,changed)
            end
        end

        local current=runtime.selectedMachine
        local currentId=machineId(current)
        if patch.manualArmed then
            if currentId and currentId~=patch.manualOldId then
                finishManual(current)
            elseif os.clock()-patch.manualArmedAt>20 then
                patch.manualArmed=false patch.manualWasActive=false patch.manualOldId=nil
            end
        elseif not patch.applying and not patch.switching and patch.auto and lastSelected and currentId and currentId~=lastSelected and currentId~=patch.lastAutoMachineId then
            -- Fallback for any picker path that did not pass through the known rows.
            setAuto(false)
        end
        lastSelected=currentId

        if patch.auto and not strengthCounter then onStrengthChanged()end
        if runtime.selectedMachine and (not runtime.selectedMachine.seat or not runtime.selectedMachine.seat.Parent)then requestCatalog(true)end
        refreshUI()
        task.wait(0.10)
    end
end)

function patch.Destroy()
    if not patch.alive then return end
    patch.alive=false
    if patch.strengthConnection then pcall(function()patch.strengthConnection:Disconnect()end)patch.strengthConnection=nil end
    for _,c in ipairs(patch.connections)do pcall(function()c:Disconnect()end)end
    if machineRef and originalSet and machineRef.Set~=originalSet then machineRef.Set=originalSet end
    if patch.primaryButton and patch.originalPrimary and patch.primaryButton.callback~=patch.originalPrimary then patch.primaryButton.callback=patch.originalPrimary end
    if env.RockBugAdaptiveMachines==patch then env.RockBugAdaptiveMachines=nil end
end

refreshUI()
return patch
