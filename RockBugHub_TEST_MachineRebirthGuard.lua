-- RockBugHub TEST machine rebirth guard v1
-- Prevents a seated training machine from being dragged to spawn by a rebirth/respawn.
-- Auto-rebirth is allowed only after a controlled detach; the same machine is then restored and resumed.
local Players=game:GetService("Players")
local player=Players.LocalPlayer
if not player then return end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local q=env.RockBugRuntime
if type(q)~="table"then return end

if env.RockBugMachineRebirthGuard and type(env.RockBugMachineRebirthGuard.Destroy)=="function"then
    pcall(env.RockBugMachineRebirthGuard.Destroy)
end

local lever=q.leverRefs and q.leverRefs.machineFarm
local originalAllowed=q.machineRebirthAllowed
if type(originalAllowed)~="function"or type(lever)~="table"or type(lever.Set)~="function"then return end

local state={
    alive=true,
    rebirthBusy=false,
    rebirthPhase="idle",
    recoveryBusy=false,
    savedMachine=nil,
    wrapper=nil,
    lastDriftAt=0,
    characterConn=nil,
}
env.RockBugMachineRebirthGuard=state
q.machineRebirthGuard=state

local function adaptive()
    local a=env.RockBugAdaptiveMachines
    return type(a)=="table"and a.alive~=false and a or nil
end

local function machineId(machine)
    return machine and tostring(machine.id or"")or""
end

local function rememberHome(machine)
    if not machine or not machine.seat or not machine.seat.Parent then return end
    if not machine.homeSeatCF then pcall(function()machine.homeSeatCF=machine.seat.CFrame end)end
    if not machine.homePivot and machine.model and machine.model.Parent then
        pcall(function()machine.homePivot=machine.model:GetPivot()end)
    end
end

local function drift(machine)
    if not machine then return 0 end
    local best=0
    if machine.model and machine.model.Parent and machine.homePivot then
        pcall(function()best=math.max(best,(machine.model:GetPivot().Position-machine.homePivot.Position).Magnitude)end)
    end
    if machine.seat and machine.seat.Parent and machine.homeSeatCF then
        pcall(function()best=math.max(best,(machine.seat.Position-machine.homeSeatCF.Position).Magnitude)end)
    end
    return best
end

local function restoreHome(machine)
    if not machine then return false end
    local restored=false
    if machine.model and machine.model.Parent and machine.homePivot then
        local ok=pcall(function()
            if (machine.model:GetPivot().Position-machine.homePivot.Position).Magnitude>4 then
                machine.model:PivotTo(machine.homePivot)
                restored=true
            end
        end)
        if not ok then restored=false end
    elseif machine.seat and machine.seat.Parent and machine.homeSeatCF then
        pcall(function()
            if (machine.seat.Position-machine.homeSeatCF.Position).Magnitude>4 then
                machine.seat.CFrame=machine.homeSeatCF
                restored=true
            end
        end)
    end
    return restored
end

local function waitMachineStopped(timeout)
    local untilAt=os.clock()+(timeout or 1.4)
    while state.alive and q.machineActive and os.clock()<untilAt do task.wait(0.025)end
    return not q.machineActive
end

local function stopPreserveAuto(machine)
    local a=adaptive()
    local oldSwitch=a and a.switching or false
    if a then a.switching=true end
    if q.machineActive and type(q.stopMachineFarm)=="function"then
        pcall(q.stopMachineFarm,nil)
    elseif q.machineActive then
        pcall(lever.Set,false,true)
    end
    waitMachineStopped(1.5)
    restoreHome(machine)
    if a and a.alive~=false then a.switching=oldSwitch end
end

local function refreshCatalog()
    if type(q.refreshMachineCatalog)=="function"and not q.machineScanInFlight then
        pcall(q.refreshMachineCatalog,true)
        local untilAt=os.clock()+0.45
        while state.alive and q.machineScanInFlight and os.clock()<untilAt do task.wait(0.025)end
    end
end

local function resolveMachine(saved)
    if saved and saved.seat and saved.seat.Parent then return saved end
    refreshCatalog()
    local id=machineId(saved)
    local zone=saved and tostring(saved.zone or"")or""
    local name=saved and tostring(saved.name or saved.label or"")or""
    local kind=saved and tostring(saved.kind or"")or""
    for _,machine in ipairs(q.machineCatalog or{})do
        if machine and machine.seat and machine.seat.Parent then
            if id~=""and machineId(machine)==id then return machine end
            if zone~=""and tostring(machine.zone or"")==zone then
                local sameName=name~=""and tostring(machine.name or machine.label or"")==name
                local sameKind=kind~=""and tostring(machine.kind or"")==kind
                if sameName or sameKind then return machine end
            end
        end
    end
    return nil
end

local function restartExact(saved)
    if not state.alive or not q.alive then return false end
    local machine=resolveMachine(saved)
    if not machine then return false end
    rememberHome(machine)
    restoreHome(machine)
    q.selectedMachine=machine
    q.machineZone=machine.zone

    -- Bypass AdaptiveMachines' strength re-selection for this one resume only.
    -- After a rebirth strength can be 0; we must resume the SAME gym machine and let
    -- the core warm-up/recovery logic regain the requirement instead of selecting nothing.
    local a=adaptive()
    local oldManual=a and a.manualArmed or false
    if a then a.manualArmed=true end
    local ok=pcall(lever.Set,true,false)
    if a and a.alive~=false then a.manualArmed=oldManual end
    return ok and q.machineActive==true
end

local function beginRebirthDetach(machine)
    if state.rebirthBusy or state.recoveryBusy or not state.alive then return end
    state.rebirthBusy=true
    state.rebirthPhase="detaching"
    state.savedMachine=machine
    task.spawn(function()
        rememberHome(machine)
        stopPreserveAuto(machine)
        if not state.alive then return end

        -- Detached machine means the server can rebirth without a seat weld dragging
        -- the machine/model to the player's spawn point.
        state.rebirthPhase="waiting"
        local startDeadline=os.clock()+3.0
        while state.alive and q.autoRebirth and not q.rebirthInFlight and os.clock()<startDeadline do task.wait(0.01)end
        if q.rebirthInFlight then
            state.rebirthPhase="rebirthing"
            while state.alive and q.rebirthInFlight do task.wait(0.01)end
        end
        state.rebirthPhase="restart"
        if not state.alive then return end

        local charDeadline=os.clock()+2.0
        while state.alive and (not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChildWhichIsA("Humanoid") or player.Character:FindFirstChildWhichIsA("Humanoid").Health<=0) and os.clock()<charDeadline do
            task.wait(0.04)
        end
        task.wait(0.08)
        local machineNow=resolveMachine(state.savedMachine)
        if machineNow then restoreHome(machineNow)end
        if state.alive and q.alive and q.autoRebirth and adaptive() and adaptive().auto and not q.machineActive then
            restartExact(machineNow or state.savedMachine)
        end
        state.rebirthPhase="idle"
        state.rebirthBusy=false
        state.savedMachine=nil
    end)
end

state.wrapper=function()
    if not state.alive then return originalAllowed()end

    -- During our controlled gap, allow the core rebirth worker to proceed only while
    -- the machine is actually detached. Once the rebirth finished we block until resume.
    if state.rebirthBusy then
        if state.rebirthPhase=="waiting"or state.rebirthPhase=="rebirthing"then
            return not q.machineActive
        end
        return false
    end

    local ok=false
    local success,value=pcall(originalAllowed)
    if success then ok=value==true end
    local a=adaptive()
    if ok and q.autoRebirth and q.machineActive and a and a.auto and not a.switching and not a.manualArmed then
        beginRebirthDetach(q.selectedMachine)
        return false
    end
    return ok
end
q.machineRebirthAllowed=state.wrapper

local function recoverDrift(machine,reason)
    if state.recoveryBusy or state.rebirthBusy or not state.alive then return end
    local a=adaptive()
    if not a or not a.auto or a.switching or a.manualArmed or not q.machineActive then return end
    state.recoveryBusy=true
    state.lastDriftAt=os.clock()
    task.spawn(function()
        rememberHome(machine)
        stopPreserveAuto(machine)
        restoreHome(machine)
        task.wait(0.06)
        if state.alive and q.alive and a.alive~=false and a.auto and not q.machineActive then
            restartExact(machine)
        end
        q.machineRecoveryStatus="ТРЕНАЖЁР: восстановлен после смещения"..(reason and(" • "..reason)or"")
        state.recoveryBusy=false
    end)
end

state.characterConn=player.CharacterAdded:Connect(function()
    -- Unexpected respawn while a machine is active: do not immediately touch anything;
    -- the drift watchdog below repairs only if the machine really moved from its home.
    state.lastDriftAt=0
end)

task.spawn(function()
    while state.alive and q.alive do
        local machine=q.selectedMachine
        if machine then
            rememberHome(machine)
            if q.machineActive and not state.rebirthBusy and not state.recoveryBusy then
                local d=drift(machine)
                if d>30 and os.clock()-state.lastDriftAt>0.8 then
                    recoverDrift(machine,"смещение "..tostring(math.floor(d+0.5)))
                end
            elseif not q.machineActive then
                -- If a previous failure already left the model at spawn, put it back even
                -- before the user/auto mode tries to sit again.
                if drift(machine)>30 then restoreHome(machine)end
            end
        end
        task.wait(0.12)
    end
end)

function state.Destroy()
    if not state.alive then return end
    state.alive=false
    if state.characterConn then pcall(function()state.characterConn:Disconnect()end)state.characterConn=nil end
    if q.machineRebirthAllowed==state.wrapper then q.machineRebirthAllowed=originalAllowed end
    if env.RockBugMachineRebirthGuard==state then env.RockBugMachineRebirthGuard=nil end
    if q.machineRebirthGuard==state then q.machineRebirthGuard=nil end
end

return state