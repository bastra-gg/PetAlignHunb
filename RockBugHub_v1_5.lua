-- RockBugHub TEST bootstrap T58: integrated boss rewards + machine rebirth guard
local VERSION="4.31HOLO-T58"
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

-- T58 machine/boss hotfix:
-- 1) never move the machine model/seat itself;
-- 2) detach before rebirth/boss movement so the seat weld cannot drag the machine;
-- 3) autoboss waits until the auto-machine has finished its post-rebirth strength warm-up.
pcall(function()
    if type(runtime)~="table"then return end
    local Players=game:GetService("Players")
    local player=Players.LocalPlayer
    if not player then return end

    -- Remove the old guard because it intentionally PivotTo/CFrame-restored displaced machines.
    local oldGuard=env.RockBugMachineRebirthGuard
    if type(oldGuard)=="table"and type(oldGuard.Destroy)=="function"then
        pcall(oldGuard.Destroy)
    end

    local rawStop=runtime.stopMachineFarm
    local function stopWithoutMovingMachine(reason)
        if type(rawStop)~="function"then return end
        local machine=runtime.selectedMachine
        local homePivot,homeSeatCF
        if machine then
            homePivot=machine.homePivot
            homeSeatCF=machine.homeSeatCF
            -- Core stop only moves the machine when these restore targets exist.
            machine.homePivot=nil
            machine.homeSeatCF=nil
        end
        local ok,err=pcall(rawStop,reason)
        if machine then
            machine.homePivot=homePivot
            machine.homeSeatCF=homeSeatCF
        end
        if not ok then error(err,0)end
    end
    runtime.stopMachineFarm=stopWithoutMovingMachine

    local lever=runtime.leverRefs and runtime.leverRefs.machineFarm
    local originalAllowed=runtime.machineRebirthAllowed
    local state={
        alive=true,
        rebirthBusy=false,
        phase="idle",
        savedMachine=nil,
        wrapper=nil,
    }
    env.RockBugMachineRebirthGuard=state
    runtime.machineRebirthGuard=state

    local function adaptive()
        local a=env.RockBugAdaptiveMachines
        return type(a)=="table"and a.alive~=false and a or nil
    end

    local function machinePresent(machine)
        if not machine or not machine.seat or not machine.seat.Parent then return false end
        local c=player.Character
        local h=c and c:FindFirstChildOfClass("Humanoid")
        if not c or not h or h.Health<=0 then return false end
        if type(runtime.machinePresence)=="function"then
            local ok,v=pcall(runtime.machinePresence,machine,c,h)
            if ok then return v==true end
        end
        return h.SeatPart==machine.seat
    end

    local function restartExact(machine)
        if not state.alive or not runtime.alive or not machine or not machine.seat or not machine.seat.Parent then return false end
        runtime.selectedMachine=machine
        runtime.machineZone=machine.zone
        local a=adaptive()
        local oldManual=a and a.manualArmed or false
        if a then a.manualArmed=true end
        local ok=false
        if type(lever)=="table"and type(lever.Set)=="function"then
            ok=pcall(lever.Set,true,false)
        end
        if a and a.alive~=false then a.manualArmed=oldManual end
        return ok and runtime.machineActive==true
    end

    local function beginDetach(machine)
        if state.rebirthBusy or not state.alive or not machine then return end
        state.rebirthBusy=true
        state.phase="detaching"
        state.savedMachine=machine
        task.spawn(function()
            -- Important: only detach the PLAYER. Do not restore/reposition the machine.
            local a=adaptive()
            local oldSwitch=a and a.switching or false
            if a then a.switching=true end
            if runtime.machineActive then pcall(stopWithoutMovingMachine,nil)end
            if a and a.alive~=false then a.switching=oldSwitch end

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

            state.phase="restart"
            local charDeadline=os.clock()+2
            while state.alive and os.clock()<charDeadline do
                local c=player.Character
                local h=c and c:FindFirstChildOfClass("Humanoid")
                if c and c:FindFirstChild("HumanoidRootPart")and h and h.Health>0 then break end
                task.wait(0.04)
            end
            task.wait(0.08)

            local saved=state.savedMachine
            local aa=adaptive()
            if state.alive and runtime.alive and runtime.autoRebirth and aa and aa.auto and not runtime.machineActive then
                restartExact(saved)
            end
            state.phase="idle"
            state.rebirthBusy=false
            state.savedMachine=nil
        end)
    end

    if type(originalAllowed)=="function"then
        state.wrapper=function()
            if not state.alive then return originalAllowed()end
            if state.rebirthBusy then
                if state.phase=="waiting"or state.phase=="rebirthing"then return not runtime.machineActive end
                return false
            end
            local ok,value=pcall(originalAllowed)
            local allowed=ok and value==true
            local a=adaptive()
            if allowed and runtime.autoRebirth and runtime.machineActive and a and a.auto and not a.switching and not a.manualArmed then
                beginDetach(runtime.selectedMachine)
                return false
            end
            return allowed
        end
        runtime.machineRebirthAllowed=state.wrapper
    end

    function state.Destroy()
        if not state.alive then return end
        state.alive=false
        if runtime.machineRebirthAllowed==state.wrapper then runtime.machineRebirthAllowed=originalAllowed end
        if runtime.stopMachineFarm==stopWithoutMovingMachine then runtime.stopMachineFarm=rawStop end
        if env.RockBugMachineRebirthGuard==state then env.RockBugMachineRebirthGuard=nil end
        if runtime.machineRebirthGuard==state then runtime.machineRebirthGuard=nil end
    end

    -- Boss must not interrupt post-rebirth warm-up. Wait until the same machine is
    -- actually ready/seated; then the ordinary T58 boss cycle can snapshot and detach.
    local cycle=runtime.bossCycle
    if type(cycle)=="table"and type(cycle.Tick)=="function"then
        local oldTick=cycle.Tick
        cycle.Tick=function(self,...)
            if self.enabled and self.phase=="waiting"then
                local a=adaptive()
                local machine=runtime.selectedMachine
                local autoMachine=a and a.auto and machine and machine.seat and machine.seat.Parent
                if autoMachine then
                    local waitingForMachine=state.rebirthBusy or runtime.rebirthInFlight
                        or runtime.machineRecovering or not runtime.machineActive or not machinePresent(machine)
                    if waitingForMachine then
                        runtime.bossCycleStatus="Перед боссом: добираю силу и сажусь на тренажёр"
                        return
                    end
                end
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