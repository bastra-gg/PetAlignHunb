-- RockBugHub TEST bootstrap T62: decoupled reward and machine restore
local VERSION="4.31HOLO-T62"
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

-- T62 machine/boss recovery:
-- Use the core's proven detach path; never manually destroy machine/player welds.
-- Preserve auto-machine intent during internal boss stops, warm strength before boss,
-- and unblock the reward phase as soon as the independent collector finishes an attempt.
pcall(function()
    if type(runtime)~="table"then return end
    local Players=game:GetService("Players")
    local player=Players.LocalPlayer
    if not player then return end

    local oldGuard=env.RockBugMachineRebirthGuard
    if type(oldGuard)=="table"and type(oldGuard.Destroy)=="function"then pcall(oldGuard.Destroy)end

    local rawStop=runtime.stopMachineFarm
    local lever=runtime.leverRefs and runtime.leverRefs.machineFarm
    local originalAllowed=runtime.machineRebirthAllowed
    if type(rawStop)~="function"or type(originalAllowed)~="function"
        or type(lever)~="table"or type(lever.Set)~="function"then return end

    local state={
        alive=true,
        rebirthBusy=false,
        phase="idle",
        savedMachine=nil,
        resumeMachine=false,
        wrapper=nil,
        bossPreparing=false,
        bossWarmBusy=false,
        bossReadySince=nil,
        rewardAt=nil,
        rewardAttempts=0,
        rewardSuccess=0,
        rewardSawBusy=false,
        rewardSettledAt=nil,
        returningSince=nil,
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

    local function readStrength()
        -- Replicated stat first: session cache can briefly retain the pre-rebirth value.
        local leader=player:FindFirstChild("leaderstats")
        for _,container in ipairs({leader,player})do
            if container then
                for _,name in ipairs({"Strength","strength","Сила","сила"})do
                    local node=container:FindFirstChild(name)
                    if node and node:IsA("ValueBase")then
                        local n=tonumber(node.Value)
                        if n and n==n and n>=0 then return n end
                    end
                end
            end
        end
        local v=tonumber(runtime.sessionStrengthCurrent)
        if v and v==v and v>=0 then return v end
        return nil
    end

    local function machineNeed(machine)
        local n=machine and tonumber(machine.requirement)
        if not n then n=tonumber(runtime.adaptiveMachineRequirement)end
        return math.max(1,n or 1)
    end

    -- Do NOT manually destroy SeatWeld/Weld/Motor6D here.
    -- The core stop computes its own presence snapshot first and then performs its tested detach.
    -- We only suppress the old "move machine back home" branch and mark this as an internal
    -- AdaptiveMachines switch so AUTO is not interpreted as manually disabled.
    local function safeStopMachine(reason)
        local machine=runtime.selectedMachine
        local a=adaptive()
        local autoBefore=a and a.auto==true or runtime.adaptiveMachineAuto==true
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
            if autoBefore then
                a.auto=true
                runtime.adaptiveMachineAuto=true
            end
        end
        if not ok then error(err,0)end

        -- Never move until the seat has actually released the character.
        local deadline=os.clock()+0.8
        local h=human()
        while h and machine and h.SeatPart==machine.seat and os.clock()<deadline do
            task.wait(0.025)
            h=human()
        end
    end
    runtime.stopMachineFarm=safeStopMachine

    local function restartExact(machine)
        if not state.alive or not runtime.alive or not machine or not machine.seat or not machine.seat.Parent then return false end
        runtime.selectedMachine=machine
        runtime.machineZone=machine.zone
        local a=adaptive()
        local oldManual=a and a.manualArmed or false
        local autoBefore=a and a.auto==true or runtime.adaptiveMachineAuto==true
        if a then a.manualArmed=true end
        local ok=pcall(lever.Set,true,false)
        if a and a.alive~=false then
            a.manualArmed=oldManual
            if autoBefore then a.auto=true runtime.adaptiveMachineAuto=true end
        end
        if ok and runtime.machineActive and type(runtime.runMachineRecovery)=="function"then
            pcall(runtime.runMachineRecovery)
        end
        return ok and runtime.machineActive==true
    end

    local function waitCharacter(timeout)
        local deadline=os.clock()+(timeout or 2)
        while state.alive and os.clock()<deadline do
            local c,h=character(),human()
            if c and c:FindFirstChild("HumanoidRootPart")and h and h.Health>0 then return true end
            task.wait(0.04)
        end
        return false
    end

    local function waitRecovered(machine,timeout)
        local deadline=os.clock()+(timeout or 40)
        local stableSince=nil
        while state.alive and runtime.alive and os.clock()<deadline do
            local a=adaptive()
            if not a or not a.auto then return false,"auto machine off"end
            if type(runtime.runMachineRecovery)=="function"then pcall(runtime.runMachineRecovery)end
            local strength=readStrength()
            local enough=strength~=nil and strength>=machineNeed(machine)
            local seated=runtime.machineActive and machinePresent(machine)and not runtime.machineRecovering
            if enough and seated then
                stableSince=stableSince or os.clock()
                if os.clock()-stableSince>=0.65 then return true end
            else
                stableSince=nil
            end
            task.wait(0.08)
        end
        return false,"timeout"
    end

    local function beginRebirth(machine)
        if state.rebirthBusy or state.bossPreparing or not state.alive or not machine then return end
        state.rebirthBusy=true
        state.phase="detaching"
        state.savedMachine=machine
        local a=adaptive()
        state.resumeMachine=a and a.auto==true

        task.spawn(function()
            if runtime.machineActive then pcall(safeStopMachine,nil)end

            local stopDeadline=os.clock()+1.5
            while state.alive and runtime.machineActive and os.clock()<stopDeadline do task.wait(0.025)end
            if not state.alive then return end

            state.phase="waiting"
            local startDeadline=os.clock()+3
            while state.alive and runtime.autoRebirth and not runtime.rebirthInFlight and os.clock()<startDeadline do task.wait(0.01)end
            if runtime.rebirthInFlight then
                state.phase="rebirthing"
                while state.alive and runtime.rebirthInFlight do task.wait(0.01)end
            end
            if not state.alive then return end

            -- Hold every further rebirth until core recovery has:
            -- dumbbell -> enough strength -> exact saved machine -> stable seat.
            state.phase="warming"
            waitCharacter(2.5)
            task.wait(0.08)
            local machineNow=state.savedMachine
            if state.resumeMachine and adaptive()and adaptive().auto and not runtime.machineActive then
                restartExact(machineNow)
            end

            if state.resumeMachine and adaptive()and adaptive().auto then
                local recovered,problem=waitRecovered(machineNow,45)
                if not recovered and state.alive then
                    runtime.autoRebirth=false
                    local rb=runtime.leverRefs and runtime.leverRefs.autoRebirth
                    if rb and type(rb.Set)=="function"then pcall(rb.Set,false,true)end
                    runtime.machineRecoveryStatus="ТРЕНАЖЁР: восстановление не завершено • ребирты остановлены"
                    if problem=="timeout"then runtime.bossCycleStatus="Жду ручной проверки тренажёра"end
                end
            end

            state.phase="idle"
            state.rebirthBusy=false
            state.savedMachine=nil
            state.resumeMachine=false
        end)
    end

    state.wrapper=function()
        if not state.alive then return originalAllowed()end
        if state.bossPreparing then return false end

        if state.rebirthBusy then
            if state.phase=="waiting"or state.phase=="rebirthing"then return not runtime.machineActive end
            return false
        end

        local a=adaptive()
        if a and a.auto and runtime.selectedMachine then
            local strength=readStrength()
            local enough=strength~=nil and strength>=machineNeed(runtime.selectedMachine)
            if not enough or runtime.machineRecovering or not runtime.machineActive or not machinePresent(runtime.selectedMachine)then
                if type(runtime.runMachineRecovery)=="function"then pcall(runtime.runMachineRecovery)end
                return false
            end
        end

        local ok,value=pcall(originalAllowed)
        local allowed=ok and value==true
        if allowed and runtime.autoRebirth and runtime.machineActive and a and a.auto
            and not a.switching and not a.manualArmed then
            beginRebirth(runtime.selectedMachine)
            return false
        end
        return allowed
    end
    runtime.machineRebirthAllowed=state.wrapper

    function state.Destroy()
        if not state.alive then return end
        state.alive=false
        if runtime.machineRebirthAllowed==state.wrapper then runtime.machineRebirthAllowed=originalAllowed end
        if runtime.stopMachineFarm==safeStopMachine then runtime.stopMachineFarm=rawStop end
        if env.RockBugMachineRebirthGuard==state then env.RockBugMachineRebirthGuard=nil end
        if runtime.machineRebirthGuard==state then runtime.machineRebirthGuard=nil end
    end

    local function ensureBossWarm(machine)
        if state.bossWarmBusy or not machine then return end
        state.bossWarmBusy=true
        state.bossPreparing=true
        task.spawn(function()
            local a=adaptive()
            if not a or not a.auto then
                state.bossPreparing=false state.bossWarmBusy=false return
            end

            local strength=readStrength()
            local need=machineNeed(machine)

            -- Core recovery checks "already seated" before requirement, so a stale/invalid
            -- 0-strength seat must be cleanly stopped first to enter dumbbell warm-up.
            if (strength==nil or strength<need)and runtime.machineActive and machinePresent(machine)then
                pcall(safeStopMachine,nil)
            end

            if state.alive and adaptive()and adaptive().auto and not runtime.machineActive then
                restartExact(machine)
            end

            local recovered=waitRecovered(machine,45)
            if not recovered and state.alive then
                runtime.bossCycleStatus="Перед боссом: не удалось восстановить тренажёр"
            end
            state.bossPreparing=false
            state.bossWarmBusy=false
        end)
    end

    local cycle=runtime.bossCycle
    if type(cycle)=="table"and type(cycle.Tick)=="function"then
        local oldTick=cycle.Tick
        cycle.Tick=function(self,...)
            local now=os.clock()

            -- Reward collection and restore are deliberately separated.
            -- Collector may teleport/hold the chest prompt in its own task; never restore in the
            -- same tick or while that task is still busy.
            local collector=env.RockBugBossAutoCollectMenu
            if self.phase=="rewards"then
                state.returningSince=nil
                if not state.rewardAt then
                    state.rewardAt=now
                    state.rewardAttempts=collector and tonumber(collector.attempts)or 0
                    state.rewardSuccess=collector and tonumber(collector.success)or 0
                    state.rewardSawBusy=collector and collector.busy==true or false
                    state.rewardSettledAt=nil
                elseif collector then
                    if collector.busy then
                        state.rewardSawBusy=true
                        state.rewardSettledAt=nil
                    else
                        local attempted=(tonumber(collector.attempts)or 0)>state.rewardAttempts
                        local succeeded=(tonumber(collector.success)or 0)>state.rewardSuccess
                        if succeeded then
                            state.rewardSettledAt=state.rewardSettledAt or now
                        elseif attempted or state.rewardSawBusy then
                            -- Some Boss Chest prompts stay enabled even after the server grants reward.
                            -- Treat a completed attempt as done only after a quiet settling window.
                            state.rewardSettledAt=state.rewardSettledAt or now
                        end
                        if state.rewardSettledAt and now-state.rewardSettledAt>=1.0 then
                            self.phase="returning"
                            runtime.bossCycleStatus="Награда обработана • стабилизация перед возвратом"
                            state.returningSince=now
                            return
                        end
                    end
                end
            elseif self.phase=="returning"then
                -- If the old collector itself switched phase to returning on verified success,
                -- still impose the same settle barrier before touching machine/rebirth state.
                state.rewardAt=nil
                state.rewardSawBusy=false
                state.rewardSettledAt=nil
                state.returningSince=state.returningSince or now
                state.bossPreparing=true
                if collector and collector.busy then
                    runtime.bossCycleStatus="Награда: жду завершения collector"
                    return
                end
                local lastClaim=collector and tonumber(collector.lastClaimAt)or nil
                local quietFrom=math.max(state.returningSince,lastClaim or 0)
                if now-quietFrom<0.75 then
                    runtime.bossCycleStatus="Награда получена • жду физику перед восстановлением"
                    return
                end
                -- Only now may the original cycle call api.restore(snapshot,...).
                local before=self.phase
                local result=oldTick(self,...)
                if before=="returning"and self.phase~="returning"then
                    state.bossPreparing=false
                    state.returningSince=nil
                end
                return result
            else
                state.rewardAt=nil
                state.rewardSawBusy=false
                state.rewardSettledAt=nil
                state.returningSince=nil
            end

            if self.enabled and self.phase=="waiting"then
                local a=adaptive()
                local wantsMachine=(a and a.auto==true)or runtime.adaptiveMachineAuto==true
                local machine=runtime.selectedMachine

                if wantsMachine then
                    if not machine or not machine.seat or not machine.seat.Parent then
                        state.bossReadySince=nil
                        state.bossPreparing=true
                        if type(runtime.refreshMachineCatalog)=="function"and not runtime.machineScanInFlight then
                            pcall(runtime.refreshMachineCatalog,true)
                        end
                        runtime.bossCycleStatus="Перед боссом: жду выбранный тренажёр"
                        return
                    end

                    local strength=readStrength()
                    local enough=strength~=nil and strength>=machineNeed(machine)
                    local ready=enough and runtime.machineActive and not runtime.machineRecovering
                        and not state.rebirthBusy and not runtime.rebirthInFlight and machinePresent(machine)

                    if not ready then
                        state.bossReadySince=nil
                        ensureBossWarm(machine)
                        runtime.bossCycleStatus="Перед боссом: гантель → сила → тренажёр"
                        return
                    end

                    state.bossPreparing=true
                    state.bossReadySince=state.bossReadySince or now
                    if now-state.bossReadySince<0.85 then
                        runtime.bossCycleStatus="Перед боссом: проверяю посадку"
                        return
                    end
                    state.bossPreparing=false
                else
                    state.bossPreparing=false
                    state.bossReadySince=nil
                end
            else
                state.bossPreparing=false
                state.bossReadySince=nil
            end

            return oldTick(self,...)
        end
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