-- RockBugHub TEST bootstrap T63: strict machine-before-rebirth boss recovery
local VERSION="4.31HOLO-T63"
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_v1_5_core.lua"
local BOSS_RUNTIME_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_RuntimeA.lua"
local ROCK_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_AdaptiveRocks.lua"
local MACHINE_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_AdaptiveMachines.lua"
local MACHINE_GUARD_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_MachineRebirthGuard.lua"
local BOSS_UI_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_BossCompact.lua"
local CARD_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/09719f8e7536f55acda625e8e18ae0ff44ce9cdb/RockBugHub_TEST_StableFarmCards.lua"
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
env.RockBugTestVersion=VERSION
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
local runtime=env.RockBugRuntime or result
if type(runtime)=="table"then runtime.testVersion=VERSION end
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

local okMachineGuard,problemMachineGuard=pcall(function()run(MACHINE_GUARD_URL,"machine rebirth guard")end)
if not okMachineGuard then warn("[RockBugHub TEST "..VERSION.."] machine rebirth guard failed: "..tostring(problemMachineGuard))end

-- T63 strict boss/machine coordinator:
-- 1) Detect boss BEFORE core starts it and pause auto-rebirth.
-- 2) Boss cannot start at 0/unknown Strength.
-- 3) If auto-machine was intended, require strength recovery + stable seat before battle.
-- 4) After reward/return, require the same stable seat BEFORE auto-rebirth is restored.
pcall(function()
    if type(runtime)~="table"then return end
    local Players=game:GetService("Players")
    local player=Players.LocalPlayer
    if not player then return end

    local oldGuard=env.RockBugMachineRebirthGuard
    if type(oldGuard)=="table"and type(oldGuard.Destroy)=="function"then pcall(oldGuard.Destroy)end

    local rawStop=runtime.stopMachineFarm
    local originalAllowed=runtime.machineRebirthAllowed
    local machineLever=runtime.leverRefs and runtime.leverRefs.machineFarm
    local rebirthLever=runtime.leverRefs and runtime.leverRefs.autoRebirth
    local cycle=runtime.bossCycle

    if type(rawStop)~="function"or type(originalAllowed)~="function"
        or type(machineLever)~="table"or type(machineLever.Set)~="function"
        or type(cycle)~="table"or type(cycle.Tick)~="function"then return end

    local state={
        alive=true,
        phase="idle",
        machine=nil,
        machineIntent=false,
        resumeAutoRebirth=false,
        preparingBoss=false,
        prepareStarted=0,
        readySince=nil,
        postBoss=false,
        postBusy=false,
        rewardAt=nil,
        rewardQuietAt=nil,
        originalTick=cycle.Tick,
        wrapper=nil,
    }
    env.RockBugMachineRebirthGuard=state
    runtime.machineRebirthGuard=state

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
        -- Force the core to refresh its own exact replicated counter first.
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

    local function strengthReady(machine)
        local strength=readStrength()
        if strength==nil or strength<=0 then return false,strength end
        local need=machineNeed(machine)
        if need and strength<need then return false,strength end
        return true,strength
    end

    local function autoMachineWanted()
        local a=adaptive()
        return (a and a.auto==true)or runtime.adaptiveMachineAuto==true
    end

    -- Keep the core's tested detach. Only suppress its legacy "move machine home" branch
    -- and tell AdaptiveMachines that this OFF is internal, not a user's manual switch.
    local function safeStopMachine(reason)
        local machine=runtime.selectedMachine
        local a=adaptive()
        local autoBefore=(a and a.auto==true)or runtime.adaptiveMachineAuto==true
        local oldSwitch=a and a.switching or false
        if a then a.switching=true end

        local homePivot,homeSeatCF
        if machine then
            homePivot=machine.homePivot
            homeSeatCF=machine.homeSeatCF
            machine.homePivot=nil
            machine.homeSeatCF=nil
        end

        local ok,err=pcall(rawStop,reason)

        if machine then
            machine.homePivot=homePivot
            machine.homeSeatCF=homeSeatCF
        end
        if a and a.alive~=false then
            a.switching=oldSwitch
            if autoBefore then a.auto=true runtime.adaptiveMachineAuto=true end
        end
        if not ok then error(err,0)end
    end
    runtime.stopMachineFarm=safeStopMachine

    local function setAutoRebirth(value)
        value=value==true
        runtime.autoRebirth=value
        if value then runtime.nextRebirth=0 end
        if rebirthLever and type(rebirthLever.Set)=="function"then
            pcall(rebirthLever.Set,value,true)
        end
    end

    local function pauseAutoRebirth()
        if runtime.autoRebirth then state.resumeAutoRebirth=true end
        setAutoRebirth(false)
    end

    local function restartExact(machine)
        if not state.alive or not runtime.alive or not machine or not machine.seat or not machine.seat.Parent then return false end
        runtime.selectedMachine=machine
        runtime.machineZone=machine.zone

        local a=adaptive()
        local autoBefore=(a and a.auto==true)or runtime.adaptiveMachineAuto==true
        local oldManual=a and a.manualArmed or false
        if a then a.manualArmed=true end
        local ok=pcall(machineLever.Set,true,false)
        if a and a.alive~=false then
            a.manualArmed=oldManual
            if autoBefore or state.machineIntent then
                a.auto=true
                runtime.adaptiveMachineAuto=true
            end
        end
        if ok and type(runtime.runMachineRecovery)=="function"then pcall(runtime.runMachineRecovery)end
        return ok
    end

    local function kickRecovery(machine)
        if not machine or not machine.seat or not machine.seat.Parent then return false end

        local ready,strength=strengthReady(machine)
        -- Core recovery checks "attached" first. At 0 strength, force a clean core detach
        -- so recovery enters dumbbell/warming instead of accepting a stale seat.
        if (strength==nil or strength<=0)and runtime.machineActive and machinePresent(machine)then
            pcall(safeStopMachine,nil)
        end

        if not runtime.machineActive then restartExact(machine)end
        if type(runtime.runMachineRecovery)=="function"then pcall(runtime.runMachineRecovery)end
        return ready
    end

    local function machineReady(machine)
        if not machine or not machine.seat or not machine.seat.Parent then return false end
        local strengthOk=strengthReady(machine)
        return strengthOk==true
            and runtime.machineActive==true
            and runtime.machineRecovering~=true
            and runtime.machineAttachInFlight~=true
            and machinePresent(machine)
    end

    local function waitMachine(machine,timeout,statusPrefix)
        local deadline=os.clock()+(timeout or 45)
        local stable=nil
        while state.alive and runtime.alive and os.clock()<deadline do
            pauseAutoRebirth()
            kickRecovery(machine)

            if machineReady(machine)then
                stable=stable or os.clock()
                if os.clock()-stable>=0.75 then return true end
            else
                stable=nil
            end

            if statusPrefix then
                local strength=readStrength()
                runtime.bossCycleStatus=statusPrefix.." • сила "..tostring(strength==nil and"?"or math.floor(strength))
            end
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
                if type(runtime.bossAdapter.targetAlive)=="function"then
                    local aliveOk,alive=pcall(runtime.bossAdapter.targetAlive,candidate.model)
                    if aliveOk and alive then return true end
                elseif type(runtime.bossAdapter.info)=="function"then
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
        state.readySince=nil
        state.machine=runtime.selectedMachine
        state.machineIntent=state.machine~=nil and (runtime.machineActive==true or autoMachineWanted())
        state.resumeAutoRebirth=runtime.autoRebirth==true
        pauseAutoRebirth()

        if state.machineIntent and state.machine then
            kickRecovery(state.machine)
        end
    end

    local function cancelBossPreparation()
        local resume=state.resumeAutoRebirth
        state.preparingBoss=false
        state.prepareStarted=0
        state.readySince=nil
        state.machine=nil
        state.machineIntent=false
        state.resumeAutoRebirth=false
        if resume then setAutoRebirth(true)end
    end

    -- Absolute rebirth gate: during boss preparation/return the seat must exist first.
    state.wrapper=function()
        if not state.alive then return originalAllowed()end

        if state.preparingBoss or state.postBoss then
            if state.machineIntent and state.machine then
                if not machineReady(state.machine)then return false end
            end
            -- During preparation auto-rebirth is intentionally paused.
            if state.preparingBoss then return false end
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

            local machine=state.machine
            local ok=true
            if state.machineIntent and machine then
                ok=waitMachine(machine,50,"После босса: сила → тренажёр → потом реб")
            end

            if ok and state.alive then
                runtime.bossCycleStatus="После босса: тренажёр подтверждён • возвращаю ребирты"
                task.wait(0.15)
                local resume=state.resumeAutoRebirth
                state.postBoss=false
                state.postBusy=false
                state.preparingBoss=false
                state.readySince=nil
                state.machine=nil
                state.machineIntent=false
                state.resumeAutoRebirth=false
                if resume then setAutoRebirth(true)end
            else
                state.postBoss=false
                state.postBusy=false
                state.preparingBoss=false
                runtime.bossCycleError="Не удалось подтвердить посадку после босса • автореб оставлен OFF"
                state.resumeAutoRebirth=false
                setAutoRebirth(false)
            end
        end)
    end

    local oldTick=cycle.Tick
    cycle.Tick=function(self,...)
        if not state.alive then return oldTick(self,...)end
        local now=os.clock()

        -- Reward collection remains independent, but never call core restore while collector
        -- is physically busy around the chest.
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
            if not state.preparingBoss then
                -- Do not pause rebirth until a real boss is present.
                if now>=(state.nextBossProbe or 0)then
                    state.nextBossProbe=now+0.55
                    if bossExists()then beginBossPreparation()end
                end
            end

            if state.preparingBoss then
                pauseAutoRebirth()

                local strength=readStrength()
                if strength==nil or strength<=0 then
                    state.readySince=nil
                    if state.machineIntent and state.machine then kickRecovery(state.machine)end
                    runtime.bossCycleStatus="БОСС ЗАБЛОКИРОВАН: сила 0 → сначала кач"
                    return
                end

                if state.machineIntent and state.machine then
                    kickRecovery(state.machine)
                    if not machineReady(state.machine)then
                        state.readySince=nil
                        runtime.bossCycleStatus="Перед боссом: сила есть → сажусь на тренажёр"
                        return
                    end
                end

                state.readySince=state.readySince or now
                if now-state.readySince<0.75 then
                    runtime.bossCycleStatus="Перед боссом: проверяю стабильную посадку"
                    return
                end

                -- Ready. Core snapshots with autoRebirth OFF, so it cannot resurrect rebirth
                -- before our post-boss machine barrier.
                local before=self.phase
                local result=oldTick(self,...)
                if before=="waiting"and self.phase=="waiting"and now-state.prepareStarted>6 then
                    -- Boss vanished between our probe and the core scan.
                    cancelBossPreparation()
                end
                return result
            end
        end

        local before=self.phase
        local result=oldTick(self,...)

        -- Core has finished its own return. Keep rebirth OFF and run one final independent
        -- seat barrier. This covers snapshots where machineActive was lost during boss prep.
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
        if runtime.machineRebirthAllowed==state.wrapper then runtime.machineRebirthAllowed=originalAllowed end
        if runtime.stopMachineFarm==safeStopMachine then runtime.stopMachineFarm=rawStop end
        if cycle.Tick~=state.originalTick then cycle.Tick=state.originalTick end
        if env.RockBugMachineRebirthGuard==state then env.RockBugMachineRebirthGuard=nil end
        if runtime.machineRebirthGuard==state then runtime.machineRebirthGuard=nil end
    end
end)
local okBossUI,problemBossUI=pcall(function()run(BOSS_UI_PATCH_URL,"boss compact UI patch")end)
if not okBossUI then warn("[RockBugHub TEST "..VERSION.."] boss UI patch failed: "..tostring(problemBossUI))end
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