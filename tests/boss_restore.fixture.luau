local time=0
local os={clock=function()return time end}
local root={Parent={},CFrame={},Position={}}
local character={}
local humanoid={Health=100}
local seat={Parent={}}
local model={}
function model:GetDescendants()return {}end
function character:GetDescendants()return {}end
function seat:GetDescendants()return {}end
function seat:IsDescendantOf(other)return other==model end
local machine={seat=seat,model=model}
local q
local running
local events
local seatAt
local mutation
local Vector3={zero={}}
local function aO()return root end
local function aM()return character end
local function aN()return humanoid end
local function copy(items)local result={}for k,v in pairs(items)do result[k]=v end return result end
local function paint()end
local function aP(text)table.insert(events,text)end
local function jX()q.machineActive=false q.machineToken+=1 end
local function jZ(which)
    assert(which==machine)
    q.selectedMachine=which q.machineActive=true q.machineToken+=1 q.machineNextAttach=100
    table.insert(events,"start machine")
    return true
end
local function ep()end
local function jK()end
local function iq()if q.rebirthGoalCompleted then q.autoRebirth=false end end
local function ji()q.kingLock=true end
local function jm()end
local function hY()end
local function i5()end
local function gz()end
local task={wait=function(dt)
    assert(not q.autoRebirth or mutation,"rebirth resumed before seating")
    time+=dt
    if seatAt and time>=seatAt then humanoid.SeatPart=seat end
    if mutation then mutation()end
end}
local function reset(savedRebirth)
    time=0 running=true events={} seatAt=2 mutation=nil humanoid.Health=100 humanoid.SeatPart=nil
    q={alive=true,autoRebirth=false,machineActive=false,machineToken=1,rebirthToken=1,modeToken=1,
        activeTrains={},trainOrder={},leverRefs={},killMode="off",networkPaused=false}
    q.startProteinEggAutomation=function()end q.startAutoEquipBestPets=function()end q.startAutoWheel=function()end q.startAutoQuest=function()end
    return {origin={},fields={machineActive=true,selectedMachine=machine,autoRebirth=savedRebirth},trains={},order={}}
end
