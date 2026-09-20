-- RockBugHub TEST bootstrap T73
local VERSION="T73"
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_v1_5_core.lua"
local BOSS_RUNTIME_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_RuntimeA.lua"
local ROCK_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_AdaptiveRocks.lua"
local MACHINE_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_AdaptiveMachines.lua"
local MACHINE_GUARD_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_MachineRebirthGuard.lua"
local BOSS_UI_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_BossCompact.lua"
local CARD_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_StableFarmCards.lua"
local BOSS_RARITY_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_TEST_BossRarityFilter.lua"
local ORBIT_UI_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_TEST_OrbitUI.lua"
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
env.RockBugTestVersion=VERSION

-- Boot invisibly: the pinned core builds the classic UI before TEST replaces it.
-- Disable every RockBug ScreenGui before Roblox gets a frame to render it.
local bootHeadless=env.RockBugBootstrapHeadless==true
local bootHidden={}
local bootPlayer=game:GetService("Players").LocalPlayer
local bootGui=bootPlayer and bootPlayer:FindFirstChildOfClass("PlayerGui")
local function hideBootVisual(obj)
    if obj and obj:IsA("ScreenGui") and tostring(obj.Name):find("RockBug",1,true) then
        bootHidden[obj]=true
        obj.Enabled=false
    end
end
local bootConnection=nil
if bootGui then
    for _,obj in ipairs(bootGui:GetDescendants())do hideBootVisual(obj)end
    bootConnection=bootGui.DescendantAdded:Connect(hideBootVisual)
end

local compiler=loadstring or env.loadstring
if type(compiler)~="function"then error("RockBugHub TEST "..VERSION..": executor has no loadstring",0)end
local function run(url,label)
    local stamp="?v="..VERSION.."-"..tostring(os.time()).."-"..tostring(math.random(100000,999999))
    local ok,source=pcall(function()return game:HttpGet(url..stamp,true)end)
    if not ok or type(source)~="string"then error("RockBugHub TEST "..VERSION..": failed to load "..label.." • "..tostring(source),0)end
    local chunk,problem=compiler(source)
    if type(chunk)~="function"then error("RockBugHub TEST "..VERSION..": compile "..label.." • "..tostring(problem),0)end
    return chunk()
end
local result=run(CORE_URL,"core")
if bootConnection then pcall(function()bootConnection:Disconnect()end)bootConnection=nil end
local runtime=env.RockBugRuntime or result
if type(runtime)=="table"then
    runtime.testVersion=VERSION
    -- Keep the classic core hidden permanently. TEST/consumer UI owns presentation.
    pcall(function()if runtime.uiRoot and runtime.uiRoot:IsA("ScreenGui")then runtime.uiRoot.Enabled=false end end)
end

-- T73: background autoboss must not call the core's global STOP.
-- The pinned core's bossAdapter.prepare() points at jT(), which also shuts down
-- unrelated automation. Pause only modes that physically conflict with boss combat.
pcall(function()
    if type(runtime)~="table" or type(runtime.bossAdapter)~="table" then return end
    local adapter=runtime.bossAdapter
    local oldPrepare=adapter.prepare
    if type(oldPrepare)~="function" then return end

    local function setOff(ref)
        if type(ref)=="table" and type(ref.Set)=="function" then
            pcall(ref.Set,false,false)
        end
    end

    adapter.prepare=function()
        local cycle=runtime.bossCycle
        -- Manual boss keeps the old explicit-stop behavior.
        if not (type(cycle)=="table" and cycle.internal==true) then
            return oldPrepare()
        end

        local refs=runtime.leverRefs or {}

        if runtime.bugActive then setOff(refs.bug) end

        local trainIds={}
        if type(runtime.activeTrains)=="table" then
            for id in pairs(runtime.activeTrains) do table.insert(trainIds,id) end
        end
        for _,id in ipairs(trainIds) do
            if type(refs.train)=="table" then setOff(refs.train[id]) end
        end

        if runtime.machineActive and type(runtime.stopMachineFarm)=="function" then
            pcall(runtime.stopMachineFarm,nil)
        end
        if runtime.kingLock then setOff(refs.kingLock) end
        if runtime.lockRock then setOff(refs.lockRock) end
        if runtime.lockPosition then setOff(refs.lockPosition) end

        if runtime.autoRebirth then
            runtime.rebirthToken=(runtime.rebirthToken or 0)+1
            runtime.autoRebirth=false
            runtime.nextRebirth=0
        end

        if runtime.autoQuest then
            if type(runtime.stopAutoQuest)=="function" then
                pcall(runtime.stopAutoQuest,nil)
            else
                setOff(refs.autoQuest)
            end
        end

        local killMode=runtime.killMode
        if killMode and killMode~="off" and type(refs.kill)=="table" then
            setOff(refs.kill[killMode])
        end
    end
end)
-- ORBIT_BOOT_BEGIN
local okOrbit,problemOrbit=true,nil
if not bootHeadless then
    okOrbit,problemOrbit=pcall(function()run(ORBIT_UI_URL,"orbit UI")end)
else
    pcall(function()
        if type(runtime)=="table"and type(runtime.hologram)=="table"and type(runtime.hologram.SetSuspended)=="function"then
            runtime.hologram:SetSuspended(true)
        end
    end)
end
if not okOrbit then warn("[RockBugHub TEST "..VERSION.."] orbit UI failed: "..tostring(problemOrbit))end
-- ORBIT_BOOT_END
local okBossRuntime,problemBossRuntime=pcall(function()run(BOSS_RUNTIME_URL,"boss reward runtime")end)
if not okBossRuntime then
    pcall(function()
        if type(runtime)=="table"then
            runtime.bossCycleError="Автосбор награды v3 не загрузился"
            runtime.bossCycleStatus="Автобосс остановлен: модуль награды не загрузился"
            local c=runtime.bossCycle
            if type(c)=="table"then
                if type(c.Cancel)=="function"then c:Cancel(false)end
                c.enabled=false
            end
        end
    end)
    warn("[RockBugHub TEST "..VERSION.."] boss reward runtime failed: "..tostring(problemBossRuntime))
end
local okRock,problemRock=pcall(function()run(ROCK_PATCH_URL,"adaptive rocks patch")end)
if not okRock then warn("[RockBugHub TEST "..VERSION.."] adaptive rocks patch failed: "..tostring(problemRock))end
local okMachine,problemMachine=pcall(function()run(MACHINE_PATCH_URL,"adaptive machines patch")end)
if not okMachine then warn("[RockBugHub TEST "..VERSION.."] adaptive machines patch failed: "..tostring(problemMachine))end

-- T73: do NOT load the old machine-rebirth guard.
-- It deliberately detached from the machine before every rebirth. The core already
-- exposes machineRebirthAllowed(), which waits for a stable confirmed seat without
-- forcing the player off first.
pcall(function()
    local stale=env.RockBugMachineRebirthGuard
    if type(stale)=="table"and type(stale.Destroy)=="function"then stale.Destroy()end
    env.RockBugMachineRebirthGuard=nil
    if type(runtime)=="table"then runtime.machineRebirthGuard=nil end
end)

-- T73 boss/machine coordinator:
-- BEFORE BOSS: pause rebirth, gain enough strength with Weight, then fight immediately.
-- NO machine seat is required before boss.
-- AFTER BOSS: restore exact machine, confirm stable seat, only then resume auto-rebirth.
pcall(function()
    if type(runtime)~="table"then return end
    local Players=game:GetService("Players")
    local player=Players.LocalPlayer
    if not player then return end

    -- Core machineRebirthAllowed() is the only rebirth gate now:
    -- stable seat first, then rebirth. No deliberate pre-rebirth dismount.
    local baseGuard=nil
    local oldCoordinator=env.RockBugBossMachineCoordinator
    if type(oldCoordinator)=="table"and type(oldCoordinator.Destroy)=="function"then pcall(oldCoordinator.Destroy)end

    local rawStop=runtime.stopMachineFarm
    local originalAllowed=runtime.machineRebirthAllowed
    local machineLever=runtime.leverRefs and runtime.leverRefs.machineFarm
    local rebirthLever=runtime.leverRefs and runtime.leverRefs.autoRebirth
    local weightLever=runtime.leverRefs and runtime.leverRefs.train and runtime.leverRefs.train.Weight
    local cycle=runtime.bossCycle

    if type(rawStop)~="function"or type(originalAllowed)~="function"
        or type(machineLever)~="table"or type(machineLever.Set)~="function"
        or type(cycle)~="table"or type(cycle.Tick)~="function"then return end

    local state={
        alive=true,
        machine=nil,
        machineIntent=false,
        resumeAutoRebirth=false,
        preparingBoss=false,
        prepareStarted=0,
        postBoss=false,
        postBusy=false,
        rewardQuietAt=nil,
        tempWeight=false,
        weightWasActive=false,
        nextWeightTry=0,
        originalTick=cycle.Tick,
        wrapper=nil,
    }
    state.baseGuard=baseGuard
    env.RockBugBossMachineCoordinator=state
    runtime.bossMachineCoordinator=state

    local function adaptive()
        local a=env.RockBugAdaptiveMachines
        return type(a)=="table"and a.alive~=false and a or nil
    end

    local function character()
        return player.Character
    end

    local function human()
        local c=character()
        return c and c:FindFirstChildOfClass("Humanoid")or nil
    end

    local function readValue(node)
        if not node or not node.Parent or not node:IsA("ValueBase")then return nil end
        local ok,v=pcall(function()return node.Value end)
        if not ok then return nil end
        local n=tonumber(v)
        if n and n==n and n>=0 and n<math.huge then return n end
        return nil
    end

    local function strengthKey(name)
        local k=string.lower(tostring(name or"")):gsub("[%s_%-]","")
        if k=="strength"or k=="сила"then return 4 end
        if k=="muscles"or k=="musclepower"then return 2 end
        return 0
    end

    local function readStrength()
        if type(runtime.updateSessionStats)=="function"then
            pcall(runtime.updateSessionStats,os.clock())
        end

        local direct=readValue(runtime.sessionStrengthCounter)
        if direct~=nil then return direct end

        local best,bestScore=nil,0
        for _,container in ipairs({player:FindFirstChild("leaderstats"),player})do
            if container then
                for _,node in ipairs(container:GetChildren())do
                    local score=node:IsA("ValueBase")and strengthKey(node.Name)or 0
                    if score>bestScore then
                        local value=readValue(node)
                        if value~=nil then best,bestScore=value,score end
                    end
                end
            end
        end
        return best
    end

    local function machinePresent(machine)
        if not machine or not machine.seat or not machine.seat.Parent then return false end
        local c,h=character(),human()
        if not c or not h or h.Health<=0 then return false end
        if type(runtime.machinePresence)=="function"then
            local ok,v=pcall(runtime.machinePresence,machine,c,h)
            if ok then return v==true end
        end
        return h.SeatPart==machine.seat
    end

    local function machineNeed(machine)
        local n=machine and tonumber(machine.requirement)or nil
        if not n then n=tonumber(runtime.adaptiveMachineRequirement)end
        return n and math.max(1,n)or nil
    end

    local function autoMachineWanted()
        local a=adaptive()
        return (a and a.auto==true)or runtime.adaptiveMachineAuto==true
    end

    local function belongsToMachine(part,machine)
        if not part or not machine then return false end
        if part==machine.seat then return true end
        for _,root in ipairs({machine.model,machine.identity,machine.seat})do
            if root and root.Parent then
                local ok,inside=pcall(function()return part==root or part:IsDescendantOf(root)end)
                if ok and inside then return true end
            end
        end
        return false
    end

    local function belongsToCharacter(part,char)
        if not part or not char then return false end
        local ok,inside=pcall(function()return part:IsDescendantOf(char)end)
        return ok and inside==true
    end

    local function softPauseMachine(reason)
        local machine=runtime.selectedMachine
        local char=character()
        local h=human()

        if type(runtime.cancelMachineAttach)=="function"then pcall(runtime.cancelMachineAttach)end
        if runtime.machineRecovery and type(runtime.machineRecovery.Reset)=="function"then
            pcall(function()runtime.machineRecovery:Reset()end)
        end

        -- Invalidate every old attach job, but DO NOT run the core hard-stop cleanup.
        -- That cleanup deletes game-created machine pieces and can make the interaction
        -- buttons disappear until the machine is rebuilt by the game.
        runtime.machineToken=(runtime.machineToken or 0)+1
        runtime.machineActive=false
        runtime.machineAttached=false
        runtime.machineAttachInFlight=false
        runtime.machineRecovering=false
        runtime.machineNextAttach=0
        runtime.machineNextRep=0

        -- Break only welds that physically connect this character to this machine.
        -- Do not delete tools, buttons, cloned machine parts or game UI.
        if char and machine then
            local seen={}
            local roots={char,machine.model,machine.identity,machine.seat}
            for _,root in ipairs(roots)do
                if root and root.Parent then
                    local ok,nodes=pcall(function()return root:GetDescendants()end)
                    if ok and type(nodes)=="table"then
                        for _,node in ipairs(nodes)do
                            if not seen[node] and (node:IsA("Weld")or node:IsA("WeldConstraint")or node:IsA("Motor6D"))then
                                seen[node]=true
                                local p0,p1=nil,nil
                                pcall(function()p0=node.Part0 p1=node.Part1 end)
                                local c0=belongsToCharacter(p0,char)
                                local c1=belongsToCharacter(p1,char)
                                local m0=belongsToMachine(p0,machine)
                                local m1=belongsToMachine(p1,machine)
                                if (c0 and m1)or(c1 and m0) then pcall(function()node:Destroy()end)end
                            end
                        end
                    end
                end
            end
        end

        if h then
            pcall(function()h.Sit=false end)
            pcall(function()h.Jump=true end)
            pcall(function()h:ChangeState(Enum.HumanoidStateType.GettingUp)end)
        end
        if reason then runtime.machineRecoveryStatus=tostring(reason)end
        return true
    end

    local function safeStopMachine(reason)
        local a=adaptive()
        local automatic=(a and a.switching==true)
            or state.machineIntent
            or (cycle and cycle.internal==true)

        -- Automatic boss/rebirth transitions use a soft detach. Manual user STOP
        -- still uses the core hard stop exactly as before.
        if not automatic then return rawStop(reason)end

        local autoBefore=(a and a.auto==true)or runtime.adaptiveMachineAuto==true
        local ok,err=pcall(softPauseMachine,reason)
        if a and a.alive~=false then
            if autoBefore or state.machineIntent then
                a.auto=true
                runtime.adaptiveMachineAuto=true
            end
        end
        if not ok then error(err,0)end
        return true
    end
    runtime.stopMachineFarm=safeStopMachine

    local function setAutoRebirth(value,paintUI)
        value=value==true
        runtime.autoRebirth=value
        if value then runtime.nextRebirth=0 end
        if paintUI~=false and rebirthLever and type(rebirthLever.Set)=="function"then
            pcall(rebirthLever.Set,value,true)
        end
    end

    local function pauseAutoRebirth()
        if runtime.autoRebirth then state.resumeAutoRebirth=true end
        -- Pause the worker without visually disarming the user's switch.
        setAutoRebirth(false,false)
    end

    local function weightActive()
        return type(runtime.activeTrains)=="table"and runtime.activeTrains.Weight~=nil
    end

    local function startWeight()
        if weightActive()then return true end
        if not weightLever or type(weightLever.Set)~="function"then return false end
        if os.clock()<state.nextWeightTry then return false end
        state.nextWeightTry=os.clock()+0.6
        local a=adaptive()
        local autoBefore=(a and a.auto==true)or runtime.adaptiveMachineAuto==true
        local ok=pcall(weightLever.Set,true,false)
        if ok then state.tempWeight=true end
        if a and a.alive~=false and (autoBefore or state.machineIntent)then
            a.auto=true
            runtime.adaptiveMachineAuto=true
        end
        return ok
    end

    local function stopTempWeight()
        if not state.tempWeight then return end
        state.tempWeight=false
        if weightLever and type(weightLever.Set)=="function"then
            pcall(weightLever.Set,false,false)
        end
        local a=adaptive()
        if a and a.alive~=false and state.machineIntent then
            a.auto=true
            runtime.adaptiveMachineAuto=true
        end
    end

    local function requiredBeforeBoss()
        if state.machineIntent and state.machine then
            return machineNeed(state.machine)or 1
        end
        return 1
    end

    local function bossStrengthReady()
        local strength=readStrength()
        if strength==nil then return false,nil,requiredBeforeBoss()end
        local need=requiredBeforeBoss()
        return strength>=need,strength,need
    end

    local function restartExact(machine)
        if not state.alive or not runtime.alive or not machine or not machine.seat or not machine.seat.Parent then return false end
        runtime.selectedMachine=machine
        runtime.machineZone=machine.zone
        local a=adaptive()
        local oldManual=a and a.manualArmed or false
        if a then a.manualArmed=true end
        local ok=pcall(machineLever.Set,true,false)
        if a and a.alive~=false then
            a.manualArmed=oldManual
            if state.machineIntent then
                a.auto=true
                runtime.adaptiveMachineAuto=true
            end
        end
        if ok and type(runtime.runMachineRecovery)=="function"then pcall(runtime.runMachineRecovery)end
        return ok
    end

    local function machineReady(machine)
        if not machine or not machine.seat or not machine.seat.Parent then return false end
        return runtime.machineActive==true
            and runtime.machineRecovering~=true
            and runtime.machineAttachInFlight~=true
            and machinePresent(machine)
    end

    local function waitMachine(machine,timeout)
        local deadline=os.clock()+(timeout or 50)
        local stable=nil
        while state.alive and runtime.alive and os.clock()<deadline do
            pauseAutoRebirth()

            if not runtime.machineActive then restartExact(machine)end
            if type(runtime.runMachineRecovery)=="function"then pcall(runtime.runMachineRecovery)end

            if machineReady(machine)then
                stable=stable or os.clock()
                if os.clock()-stable>=0.75 then return true end
            else
                stable=nil
            end

            local strength=readStrength()
            runtime.bossCycleStatus="После босса: сажусь на тренажёр • сила "..tostring(strength==nil and"?"or math.floor(strength))
            task.wait(0.08)
        end
        return false
    end

    local function bossExists()
        if type(runtime.bossAdapter)~="table"or type(runtime.bossAdapter.scan)~="function"then return false end
        local ok,list=pcall(runtime.bossAdapter.scan)
        if not ok or type(list)~="table"then return false end
        for _,candidate in ipairs(list)do
            if candidate and candidate.model then
                if type(runtime.bossAdapter.info)=="function"then
                    local infoOk,info=pcall(runtime.bossAdapter.info,candidate.model)
                    if infoOk and info and info.alive then return true end
                else
                    return true
                end
            end
        end
        return false
    end

    local function beginBossPreparation()
        if state.preparingBoss or state.postBoss then return end
        state.preparingBoss=true
        state.prepareStarted=os.clock()
        state.machine=runtime.selectedMachine
        state.machineIntent=state.machine~=nil and (runtime.machineActive==true or autoMachineWanted())
        state.resumeAutoRebirth=runtime.autoRebirth==true
        state.weightWasActive=weightActive()
        state.tempWeight=false
        pauseAutoRebirth()
    end

    local function cancelBossPreparation()
        stopTempWeight()
        local resume=state.resumeAutoRebirth
        state.preparingBoss=false
        state.prepareStarted=0
        state.machine=nil
        state.machineIntent=false
        state.resumeAutoRebirth=false
        state.weightWasActive=false
        if resume then setAutoRebirth(true)end
    end

    -- During boss prep/post-boss restore rebirth is absolutely blocked.
    -- Outside the boss flow, AUTO MACHINE + AUTO REBIRTH means:
    -- 1) sit on the selected machine, 2) confirm a stable seat, 3) only then rebirth.
    state.wrapper=function()
        if not state.alive then return originalAllowed()end
        if state.preparingBoss or state.postBoss then return false end

        if autoMachineWanted()then
            local machine=runtime.selectedMachine
            if not machine or not machine.seat or not machine.seat.Parent then
                runtime.machineRecoveryStatus="АВТОРЕБИРТ: жду доступный тренажёр"
                return false
            end

            if not machineReady(machine)then
                runtime.machineRecoveryStatus="АВТОРЕБИРТ: жду посадку на тренажёр"
                if not runtime.machineActive then
                    restartExact(machine)
                elseif type(runtime.runMachineRecovery)=="function"then
                    pcall(runtime.runMachineRecovery)
                end
                return false
            end
        end

        local ok,value=pcall(originalAllowed)
        return ok and value==true
    end
    runtime.machineRebirthAllowed=state.wrapper

    local function finishPostBoss()
        if state.postBusy then return end
        state.postBusy=true
        task.spawn(function()
            pauseAutoRebirth()
            stopTempWeight()

            local ok=true
            if state.machineIntent and state.machine then
                ok=waitMachine(state.machine,50)
            end

            if ok and state.alive then
                runtime.bossCycleStatus=state.machineIntent
                    and"После босса: сел на тренажёр • теперь возвращаю реб"
                    or"После босса: возвращаю реб"
                task.wait(0.15)
                local resume=state.resumeAutoRebirth
                state.postBoss=false
                state.postBusy=false
                state.preparingBoss=false
                state.machine=nil
                state.machineIntent=false
                state.resumeAutoRebirth=false
                state.weightWasActive=false
                if resume then setAutoRebirth(true)end
            else
                state.postBoss=false
                state.postBusy=false
                state.preparingBoss=false
                state.resumeAutoRebirth=false
                runtime.bossCycleError="Не сел на тренажёр после босса • автореб оставлен OFF"
                setAutoRebirth(false)
            end
        end)
    end

    local oldTick=cycle.Tick
    cycle.Tick=function(self,...)
        if not state.alive then return oldTick(self,...)end
        local now=os.clock()

        -- Don't let core return while reward collector is still moving/pressing the chest.
        local collector=env.RockBugBossAutoCollectMenu
        if self.phase=="rewards"then
            if collector and collector.busy then
                state.rewardQuietAt=nil
                runtime.bossCycleStatus="Награда: collector ещё работает"
                return
            end
            state.rewardQuietAt=state.rewardQuietAt or now
            if now-state.rewardQuietAt<0.75 then
                runtime.bossCycleStatus="Награда: жду физику перед возвратом"
                return
            end
        else
            state.rewardQuietAt=nil
        end

        if self.enabled and self.phase=="waiting"and not state.postBoss then
            if not state.preparingBoss and now>=(state.nextBossProbe or 0)then
                state.nextBossProbe=now+0.55
                if bossExists()then beginBossPreparation()end
            end

            if state.preparingBoss then
                pauseAutoRebirth()

                local ready,strength,need=bossStrengthReady()
                if not ready then
                    startWeight()
                    runtime.bossCycleStatus="Перед боссом: качаю силу "..tostring(strength==nil and"?"or math.floor(strength))
                        .." / "..tostring(math.floor(need or 1))
                    return
                end

                -- Strength is ready. Stop only our temporary Weight and go directly to boss.
                -- No machine seating here.
                if state.tempWeight then
                    stopTempWeight()
                    runtime.bossCycleStatus="Перед боссом: сила готова • иду к боссу"
                    return
                end

                local before=self.phase
                local result=oldTick(self,...)
                if before=="waiting"and self.phase=="waiting"and now-state.prepareStarted>6 then
                    cancelBossPreparation()
                end
                return result
            end
        end

        local before=self.phase
        local result=oldTick(self,...)

        -- Core return finished. Now enforce: machine seat FIRST, rebirth SECOND.
        if before=="returning"and self.phase~="returning"and state.preparingBoss then
            state.preparingBoss=false
            state.postBoss=true
            pauseAutoRebirth()
            finishPostBoss()
        end

        return result
    end

    function state.Destroy()
        if not state.alive then return end
        state.alive=false
        stopTempWeight()
        if runtime.machineRebirthAllowed==state.wrapper then runtime.machineRebirthAllowed=originalAllowed end
        if runtime.stopMachineFarm==safeStopMachine then runtime.stopMachineFarm=rawStop end
        if cycle.Tick~=state.originalTick then cycle.Tick=state.originalTick end
        if env.RockBugBossMachineCoordinator==state then env.RockBugBossMachineCoordinator=nil end
        if runtime.bossMachineCoordinator==state then runtime.bossMachineCoordinator=nil end
    end
end)
local okBossUI,problemBossUI=pcall(function()run(BOSS_UI_PATCH_URL,"boss compact UI patch")end)
if not okBossUI then warn("[RockBugHub TEST "..VERSION.."] boss UI patch failed: "..tostring(problemBossUI))end
local okBossRarity,problemBossRarity=pcall(function()run(BOSS_RARITY_PATCH_URL,"boss rarity filter")end)
if not okBossRarity then warn("[RockBugHub TEST "..VERSION.."] boss rarity filter failed: "..tostring(problemBossRarity))end

-- T73 profile persistence extension. The pinned core profile writer predates
-- autoboss rarity filters and several newer TEST toggles.
pcall(function()
    if type(runtime)~="table"or type(runtime.layoutUI)~="table"
        or type(runtime.layoutUI.captureLastSession)~="function"
        or type(runtime.layoutUI.resumeLastSession)~="function"then return end
    if runtime.layoutUI.testPersistenceVersion=="T73"then return end

    local originalCapture=runtime.layoutUI.captureLastSession
    local originalResume=runtime.layoutUI.resumeLastSession

    local function copySet(src)
        local out={}
        if type(src)=="table"then
            for k,v in pairs(src)do if v then out[tostring(k)]=true end end
        end
        return out
    end
    local function restorePlayerSet(src)
        local out={}
        if type(src)=="table"then
            for k,v in pairs(src)do
                if v then out[tonumber(k)or k]=true end
            end
        end
        return out
    end

    runtime.layoutUI.captureLastSession=function()
        local cfg=originalCapture()
        if type(cfg)~="table"then cfg={}end

        cfg.bossCycleEnabled=type(runtime.bossCycle)=="table"and runtime.bossCycle.enabled==true
        local rarity=runtime.bossRarityFilter
        if type(rarity)=="table"and type(rarity.GetSettings)=="function"then
            local ok,value=pcall(rarity.GetSettings)
            if ok and type(value)=="table"then cfg.bossRarities=value end
        elseif type(env.RockBugBossRaritySettings)=="table"then
            cfg.bossRarities={}
            for k,v in pairs(env.RockBugBossRaritySettings)do
                if type(v)=="boolean"then cfg.bossRarities[k]=v end
            end
        end

        cfg.killMode=tostring(runtime.killMode or"off")
        cfg.killWhitelist=copySet(runtime.killWhitelist)
        cfg.killBlacklist=copySet(runtime.killBlacklist)
        cfg.lockPosition=runtime.lockPosition==true
        cfg.adaptiveMachineAuto=runtime.adaptiveMachineAuto==true
            or(type(env.RockBugAdaptiveMachines)=="table"and env.RockBugAdaptiveMachines.auto==true)
        return cfg
    end

    runtime.layoutUI.resumeLastSession=function(...)
        local cfg=runtime.layoutUI.lastSavedSession
        local ext=type(cfg)=="table"and{
            bossCycleEnabled=cfg.bossCycleEnabled==true,
            bossCycleKnown=cfg.bossCycleEnabled~=nil,
            bossRarities=cfg.bossRarities,
            killMode=cfg.killMode,
            killWhitelist=cfg.killWhitelist,
            killBlacklist=cfg.killBlacklist,
            lockPosition=cfg.lockPosition==true,
            adaptiveMachineAuto=cfg.adaptiveMachineAuto==true,
            adaptiveKnown=cfg.adaptiveMachineAuto~=nil,
        }or nil

        local result=originalResume(...)
        if result==false or not ext then return result end

        task.spawn(function()
            local deadline=os.clock()+20
            while runtime.alive and runtime.sessionResumeInFlight and os.clock()<deadline do task.wait(0.05)end
            if not runtime.alive then return end

            if type(ext.killWhitelist)=="table"then runtime.killWhitelist=restorePlayerSet(ext.killWhitelist)end
            if type(ext.killBlacklist)=="table"then runtime.killBlacklist=restorePlayerSet(ext.killBlacklist)end
            if type(runtime.refreshExtraUI)=="function"then pcall(runtime.refreshExtraUI)end

            if type(ext.killMode)=="string"and ext.killMode~=""and ext.killMode~="off"
                and type(runtime.leverRefs)=="table"and type(runtime.leverRefs.kill)=="table"then
                local ref=runtime.leverRefs.kill[ext.killMode]
                if type(ref)=="table"and type(ref.Set)=="function"then pcall(ref.Set,true,false)end
            end

            if ext.lockPosition and not runtime.machineActive and not runtime.kingLock and not runtime.lockRock then
                local ref=runtime.leverRefs and runtime.leverRefs.lockPosition
                if type(ref)=="table"and type(ref.Set)=="function"then pcall(ref.Set,true,false)end
            end

            if ext.adaptiveKnown then
                local adaptive=env.RockBugAdaptiveMachines
                if type(adaptive)=="table"and adaptive.alive~=false then adaptive.auto=ext.adaptiveMachineAuto end
                runtime.adaptiveMachineAuto=ext.adaptiveMachineAuto
            end

            local rarity=runtime.bossRarityFilter
            if type(ext.bossRarities)=="table"and type(rarity)=="table"
                and type(rarity.ApplySettings)=="function"then
                pcall(rarity.ApplySettings,ext.bossRarities)
            end

            -- Restore autoboss last, after every other mode has finished restoring.
            if ext.bossCycleKnown then
                local ref=runtime.leverRefs and runtime.leverRefs.bossCycle
                if type(ref)=="table"and type(ref.Set)=="function"then
                    pcall(ref.Set,ext.bossCycleEnabled,false)
                elseif type(runtime.bossCycle)=="table"and type(runtime.bossCycle.SetEnabled)=="function"then
                    pcall(runtime.bossCycle.SetEnabled,runtime.bossCycle,ext.bossCycleEnabled)
                end
            end
        end)
        return result
    end

    runtime.layoutUI.testPersistenceVersion="T73"
end)

local okCards,problemCards=pcall(function()run(CARD_PATCH_URL,"stable farm cards patch")end)
if not okCards then warn("[RockBugHub TEST "..VERSION.."] stable cards patch failed: "..tostring(problemCards))end

-- Dedicated full-close control next to the TEST HUD hide/show handle.
pcall(function()
    if type(runtime)~="table"or type(runtime.Stop)~="function"then return end
    local pg=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local handle=nil
    for _=1,40 do
        for _,obj in ipairs(pg:GetDescendants())do
            if obj:IsA("TextButton")then
                local t=tostring(obj.Text or""):upper():gsub("%s+"," ")
                if t=="СКРЫТЬ · RB"or t=="ПОКАЗАТЬ"or t=="HIDE · RB"or t=="SHOW · RB"then
                    handle=obj break
                end
            end
        end
        if handle then break end
        task.wait(0.1)
    end
    if not handle or not handle.Parent then return end
    local gui=handle:FindFirstAncestorOfClass("ScreenGui")
    if not gui then return end
    local old=gui:FindFirstChild("RockBugFullClose")
    if old then old:Destroy()end
    local close=Instance.new("TextButton")
    close.Name="RockBugFullClose"
    close.Text="×"
    close.Size=UDim2.fromOffset(32,32)
    close.BackgroundColor3=Color3.fromRGB(54,24,34)
    close.BackgroundTransparency=0.08
    close.BorderSizePixel=0
    close.Font=Enum.Font.GothamBold
    close.TextColor3=Color3.fromRGB(255,220,228)
    close.TextSize=20
    close.AutoButtonColor=true
    close.ZIndex=math.max(10,handle.ZIndex+2)
    close.Parent=gui
    local corner=Instance.new("UICorner")corner.CornerRadius=UDim.new(0,10)corner.Parent=close
    local stroke=Instance.new("UIStroke")stroke.Color=Color3.fromRGB(220,92,118)stroke.Transparency=0.38 stroke.Thickness=1 stroke.Parent=close
    local function place()
        if not close.Parent or not handle.Parent then return end
        local camera=workspace.CurrentCamera
        local vp=camera and camera.ViewportSize or Vector2.new(800,600)
        local hp=handle.AbsolutePosition
        local hs=handle.AbsoluteSize
        local x=hp.X+hs.X+7
        if x+32>vp.X-4 then x=hp.X-39 end
        close.Position=UDim2.fromOffset(math.max(4,math.floor(x)),math.max(4,math.floor(hp.Y+(hs.Y-32)/2)))
        close.Visible=handle.Visible
    end
    local function keep(conn)
        if type(runtime.connections)=="table"then table.insert(runtime.connections,conn)end
    end
    keep(close.Activated:Connect(function()
        if runtime.alive then runtime:Stop("manual close")end
    end))
    keep(handle:GetPropertyChangedSignal("AbsolutePosition"):Connect(place))
    keep(handle:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
    keep(handle:GetPropertyChangedSignal("Visible"):Connect(place))
    local camera=workspace.CurrentCamera
    if camera then keep(camera:GetPropertyChangedSignal("ViewportSize"):Connect(place))end
    task.defer(place)
end)

pcall(function()
    local pg=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local stop=nil
    for _=1,30 do
        for _,obj in ipairs(pg:GetDescendants())do
            if obj:IsA("TextButton")then
                local t=tostring(obj.Text or""):gsub("%s+",""):upper()
                if t=="СТОП"or t=="STOP"then stop=obj break end
            end
        end
        if stop then break end
        task.wait(0.1)
    end
    if not stop or not stop.Parent then return end
    local parent=stop.Parent
    if parent:FindFirstChild("OrbitContext")then return end -- Version is already in the console header.
    local old=parent:FindFirstChild("TestBuildBadge")
    if old then old:Destroy()end
    local badge=Instance.new("TextLabel")
    badge.Name="TestBuildBadge"
    badge.BackgroundColor3=Color3.fromRGB(31,35,46)
    badge.BackgroundTransparency=0.12
    badge.BorderSizePixel=0
    badge.Font=Enum.Font.GothamBold
    badge.Text="TEST • "..(VERSION:match("T%d+$")or VERSION)
    badge.TextColor3=Color3.fromRGB(194,184,255)
    badge.TextSize=8
    badge.ZIndex=math.max(1,stop.ZIndex)
    badge.Parent=parent
    local corner=Instance.new("UICorner")corner.CornerRadius=UDim.new(0,8)corner.Parent=badge
    local stroke=Instance.new("UIStroke")stroke.Color=Color3.fromRGB(142,118,255)stroke.Transparency=0.62 stroke.Thickness=1 stroke.Parent=badge
    local function place()
        if not badge.Parent or not stop.Parent then return end
        local p=parent.AbsolutePosition local s=stop.AbsolutePosition
        local h=math.max(22,math.min(28,stop.AbsoluteSize.Y-2)) local w=60
        badge.Size=UDim2.fromOffset(w,h)
        badge.Position=UDim2.fromOffset(math.floor(s.X-p.X-w-7),math.floor(s.Y-p.Y+(stop.AbsoluteSize.Y-h)/2))
    end
    place()
    stop:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
    stop:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
    parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
end)
return runtime