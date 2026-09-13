local count=0
local function check(name,fn) fn() count+=1 print("PASS "..name) end
local function node(class,parent)
    local obj={ClassName=class,Parent=parent,Name=class,children={}}
    if parent and parent.children then table.insert(parent.children,obj) end
    function obj:IsA(kind)return self.ClassName==kind end
    function obj:IsDescendantOf(target)
        local p=self.Parent
        while p do if p==target then return true end p=p.Parent end
        return false
    end
    function obj:GetDescendants()
        local result={}
        local function walk(p)for _,child in ipairs(p.children)do table.insert(result,child)walk(child)end end
        walk(self)return result
    end
    return obj
end
local chest=node("Model",workspace) chest.Name="Rare Boss Chest"
local prompt=node("ProximityPrompt",chest)
prompt.Enabled=true prompt.ActionText="Claim Reward" prompt.ObjectText="Rare Boss Chest"
check("English boss chest",function()assert(matches(prompt))end)
check("Russian prompt from recording",function()
    chest.Name="Редкий сундук боссов" prompt.ActionText="Получить награду" prompt.ObjectText=chest.Name
    assert(matches(prompt))
end)
check("Ordinary reward and machine prompts excluded",function()
    prompt.ObjectText="Daily Chest" chest.Name="Daily Chest" prompt.ActionText="Claim Reward"
    assert(not matches(prompt))
    chest.Name="Rare Boss Chest" prompt.ActionText="Use Machine" assert(not matches(prompt))
    prompt.ActionText="Claim Reward" prompt.Enabled=false assert(not matches(prompt)) prompt.Enabled=true
end)
check("Only reward acknowledgements, no Claim button text",function()
    assert(rewardText("Награды сундуков")) assert(rewardText("You already claimed your reward!"))
    assert(rewardText("<b>Chest Rewards</b>")) assert(not rewardText("Получить награду"))
end)
check("SeatPart or a weld to the selected machine required",function()
    local character=node("Model",workspace)
    local machine=node("Model",workspace) local seat=node("Part",machine)
    local body=node("Part",character) local human={Health=100}
    local descriptor={seat=seat,model=machine}
    assert(not machinePresence(descriptor,character,human))
    human.Sit=true assert(not machinePresence(descriptor,character,human))
    human.SeatPart=seat assert(machinePresence(descriptor,character,human)) human.SeatPart=nil
    local joint=node("Weld",character) joint.Part0=body joint.Part1=node("Part",workspace)
    assert(not machinePresence(descriptor,character,human))
    joint.Part1=seat assert(machinePresence(descriptor,character,human))
    human.Health=0 assert(not machinePresence(descriptor,character,human))
end)
local function seatCase(attached,ready,current,flight)
    local time,retries=0,0
    local api={now=function()return time end,wait=function(dt)time+=dt end,owned=function()return true end,
        attached=function()return attached(time)end,ready=function()return not ready or ready(time)end,
        inFlight=function()return flight and flight(time)end,retry=function()retries+=1 end}
    local ok,problem=waitForSeat(api,function()return not current or current(time)end)
    return ok,problem,time,retries
end
check("Delayed seat must stay attached for 0.4 seconds",function()
    local ok,_,time=seatCase(function(t)return t>=2 end)
    assert(ok and time>=2.4 and time<2.7)
end)
check("A transient weld does not release rebirths",function()
    local ok,_,time=seatCase(function(t)return t>=1 and t<1.2 or t>=3 end)
    assert(ok and time>=3.4)
end)
check("Wait for attachment request to finish",function()
    local ok,_,time=seatCase(function()return true end,nil,nil,function(t)return t<2 end)
    assert(ok and time>=2.4)
end)
check("False send acknowledgement times out without resuming",function()
    local ok,problem,time=seatCase(function()return false end)
    assert(not ok and problem~="cancelled" and time>=20)
end)
check("Network pause is excluded from seating timeout",function()
    local ok,_,time=seatCase(function(t)return t>23 end,function(t)return t<1 or t>=6 end)
    assert(ok and time>=23.4)
end)
check("Stop cancels seating before next retry",function()
    local ok,problem,time=seatCase(function()return false end,nil,function(t)return t<0.5 end)
    assert(not ok and problem=="cancelled" and time<0.7)
end)
local function chestCase()
    local s={time=0,ack=false,character={},moves=0,interactions=0,ends=0,range=true,ready=true}
    local p={Enabled=true,HoldDuration=0.4}
    function p:InputHoldBegin()s.begins=(s.begins or 0)+1 end
    function p:InputHoldEnd()s.ends+=1 end
    local api={now=function()return s.time end,wait=function(dt)s.time+=dt if s.onwait then s.onwait()end end,
        character=function()return s.character end,ready=function()return s.ready end,
        acknowledged=function()return s.ack end,closed=function()return not p.Enabled end,
        matches=function()return p.Enabled end,find=function()return p end,
        move=function()s.moves+=1 return s.range end,inRange=function()return s.range end,
        interact=function()s.interactions+=1 if s.oninteract then s.oninteract()end end,
        endHold=function()p:InputHoldEnd()end,report=function()end}
    return s,p,api,createChestCollector(api)
end
check("No-op mobile helper still attempts native hold",function()
    local s,p,api=chestCase() api.fire=function()s.fire=true end
    interactChest(api,p,function()return true end)
    assert(s.fire and s.begins==1 and s.ends==1 and s.time>=0.85)
end)
check("Cancelled helper never starts a native hold",function()
    local s,p,api=chestCase() local current=true api.fire=function()current=false end
    interactChest(api,p,function()return current end) assert(not s.begins)
end)
check("Delayed reward banner closes a still enabled prompt",function()
    local s,p,_,collector=chestCase()
    assert(collector:Step(function()return true end,{})=="pending")
    s.ack=true
    assert(collector:Step(function()return true end,{})=="closed")
    assert(p.Enabled and s.interactions==1)
end)
check("Manual collection before script interaction is respected",function()
    local s,_,_,collector=chestCase() s.ack=true
    assert(collector:Step(function()return true end,{})=="closed" and s.interactions==0)
end)
check("Prompt expiration is not reported as reward credit",function()
    local s,p,_,collector=chestCase()collector:Step(function()return true end,{}) p.Enabled=false
    assert(collector:Step(function()return true end,{})=="missing")
end)
check("Retries remain beside chest and are paced",function()
    local s,_,_,collector=chestCase()collector:Step(function()return true end,{})
    collector:Step(function()return true end,{}) assert(s.interactions==1)
    s.time+=3 collector:Step(function()return true end,{}) assert(s.interactions==2)
end)
check("Cancel invalidates a delayed in-flight chest interaction",function()
    local s,_,_,collector=chestCase()
    s.oninteract=function()collector:Cancel()s.ack=true end
    assert(collector:Step(function()return true end,{})=="pending") assert(not collector.closed)
end)
check("Respawn invalidates old chest state",function()
    local s,_,_,collector=chestCase()collector:Step(function()return true end,{})
    s.character={}collector:Step(function()return true end,{})assert(s.interactions==2)
end)
check("Out of range does not interact",function()
    local s,_,_,collector=chestCase()s.range=false
    collector:Step(function()return true end,{})assert(s.interactions==0)
end)
check("Rendered chest button is pressed before proximity helpers",function()
    local s,p,api=chestCase()
    api.click=function(target,current)assert(target==p and current())s.click=true s.ack=true end
    api.fire=function()error("must not send after reward")end
    interactChest(api,p,function()return true end)
    assert(s.click and not s.begins)
end)
local function buttonCase()
    local s={time=0,ack=false,valid=true,visible=true,down=0,up=0}
    local button={}
    local api={find=function()return button end,visible=function()return s.visible end,
        center=function()return 417,382 end,acknowledged=function()return s.ack end,
        matches=function()return true end,inRange=function()return true end,
        now=function()return s.time end,wait=function(dt)s.time+=dt if s.onwait then s.onwait()end end,
        down=function(x,y)assert(x==417 and y==382)s.down+=1 if s.throw then error("input blocked")end end,
        up=function(x,y)assert(x==417 and y==382)s.up+=1 end,
        setRelease=function(fn)s.release=fn end,clearRelease=function(fn)if s.release==fn then s.release=nil end end}
    return s,api,{HoldDuration=0.6},function()return s.valid end
end
check("Screen press holds for prompt duration and releases once",function()
    local s,api,p,valid=buttonCase()
    assert(pressChestButton(api,p,valid))
    assert(s.down==1 and s.up==1 and s.time>=1.05 and not s.release and not s.ack)
end)
check("Stop immediately releases an in-flight screen press",function()
    local s,api,p,valid=buttonCase()
    s.onwait=function()s.valid=false s.release()end
    pressChestButton(api,p,valid)
    assert(s.down==1 and s.up==1 and s.time<0.1 and not s.release)
end)
check("Reward acknowledgement ends screen hold without double release",function()
    local s,api,p,valid=buttonCase()
    s.onwait=function()s.ack=true end
    pressChestButton(api,p,valid)
    assert(s.down==1 and s.up==1 and s.time<0.6)
end)
check("Input failure still sends mouse-up and clears cancellation hook",function()
    local s,api,p,valid=buttonCase()s.throw=true
    assert(not pcall(pressChestButton,api,p,valid))
    assert(s.down==1 and s.up==1 and not s.release)
end)
check("Hidden or missing reward button is never clicked",function()
    local s,api,p,valid=buttonCase()s.visible=false
    assert(not pressChestButton(api,p,valid) and s.down==0)
    s.visible=true api.find=function()return nil end
    assert(not pressChestButton(api,p,valid) and s.down==0)
end)
check("Find mobile button by chest adornee, excluding other chests and own UI",function()
    local function gui(class,parent)
        local obj=node(class,parent)
        obj.Visible=true obj.Enabled=true obj.Active=true obj.AbsoluteSize={X=150,Y=60}
        function obj:IsA(kind)
            return self.ClassName==kind or kind=="GuiButton" and (class=="TextButton" or class=="ImageButton")
                or kind=="GuiObject" and (class=="TextButton" or class=="ImageButton" or class=="TextLabel" or class=="Frame")
                or kind=="LayerCollector" and (class=="BillboardGui" or class=="ScreenGui")
        end
        return obj
    end
    local root=node("CoreGui",nil)
    local owner=node("Part",workspace)
    local p={Parent=owner,ActionText="Claim Reward"}
    local wrong=gui("BillboardGui",root)wrong.Adornee=node("Part",workspace)
    local other=gui("TextButton",wrong)other.Text="Claim Reward"
    local card=gui("BillboardGui",root)card.Adornee=owner
    local frame=gui("Frame",card)
    local label=gui("TextLabel",frame)label.Text="Получить награду"
    local button=gui("TextButton",frame)button.Text=""
    assert(findChestButton({root},p,nil)==button)
    frame.Visible=false assert(not findChestButton({root},p,nil))frame.Visible=true
    assert(not findChestButton({root},p,card))
    card.Enabled=false assert(not findChestButton({root},p,nil))card.Enabled=true
    button.Parent=nil assert(not findChestButton({root},p,nil))
end)
local function rewardGui(class,parent)
 local obj=node(class,parent)
 obj.Visible=true;obj.Enabled=true;obj.Active=true;obj.AbsoluteSize={X=150,Y=60}
 function obj:IsA(kind)
  return class==kind or kind=="GuiButton"and(class=="TextButton"or class=="ImageButton")
   or kind=="GuiObject"and(class=="TextButton"or class=="ImageButton"or class=="TextLabel"or class=="Frame")
   or kind=="LayerCollector"and(class=="BillboardGui"or class=="ScreenGui"or class=="SurfaceGui")
 end
 return obj
end
check("sibling attachment on the same chest and nested mobile action labels are found",function()
 local root=node("PlayerGui",nil);local model=node("Model",workspace);model.Name="Rare Boss Chest"
 local owner=node("Part",model);local other=node("Part",model)
 local p={Parent=owner,ActionText="Claim Reward",ObjectText="Rare Boss Chest"}
 local card=rewardGui("BillboardGui",root);card.Adornee=other
 local close=rewardGui("TextButton",card);close.Text="×"
 local button=rewardGui("ImageButton",card);local title=rewardGui("TextLabel",button);title.Text="Собрать награду"
 assert(findChestButton({root},p,nil)==button)
 title.Visible=false;assert(not findChestButton({root},p,nil))
end)
check("surface claim UI and Russian uppercase labels are supported",function()
 local root=node("PlayerGui",nil);local owner=node("Part",workspace)
 local p={Parent=owner,ActionText="Claim Reward"}
 local card=rewardGui("SurfaceGui",root);card.Adornee=owner
 local button=rewardGui("TextButton",card);button.Text="ЗАБРАТЬ НАГРАДУ"
 assert(findChestButton({root},p,nil)==button)
end)
check("screen-space claim dialog identifies the boss chest in its own card",function()
 local root=node("PlayerGui",nil);local screen=rewardGui("ScreenGui",root)
 local p={Parent=node("Part",workspace),ActionText="Claim Reward",ObjectText="Rare Boss Chest"}
 local card=rewardGui("Frame",screen);local label=rewardGui("TextLabel",card);label.Text="Rare Boss Chest"
 local button=rewardGui("TextButton",card);button.Text="Claim"
 assert(findChestButton({root},p,nil)==button)
 card.Visible=false;assert(not findChestButton({root},p,nil));card.Visible=true
 label.Text="Daily Chest";assert(not findChestButton({root},p,nil))
end)
check("another chest or sibling daily reward is never used as the boss action",function()
 local root=node("PlayerGui",nil);local screen=rewardGui("ScreenGui",root);local shared=rewardGui("Frame",screen)
 local p={Parent=node("Part",workspace),ActionText="Claim Reward",ObjectText="Rare Boss Chest"}
 local daily=rewardGui("Frame",shared);local dl=rewardGui("TextLabel",daily);dl.Text="Daily Chest"
 local wrong=rewardGui("TextButton",daily);wrong.Text="Claim"
 local boss=rewardGui("Frame",shared);local title=rewardGui("TextLabel",boss);title.Text="Rare Boss Chest"
 local correct=rewardGui("TextButton",boss);correct.Text="Claim"
 assert(findChestButton({root},p,nil)==correct)
end)
check("direct Activated confirmation prevents a second handler and physical input",function()
 local s,api,p,valid=buttonCase();local events={}
 api.activate=function(_,event)table.insert(events,event);s.ack=true;return true end
 assert(activateChestButton(api,p,valid)and #events==1 and events[1]=="Activated" and s.down==0)
end)
check("no-op Activated falls back to the game's click handler",function()
 local s,api,p,valid=buttonCase();local events={}
 api.activate=function(_,event)table.insert(events,event);if event=="MouseButton1Click"then s.ack=true end;return true end
 assert(activateChestButton(api,p,valid)and #events==2 and s.ack)
end)
check("unavailable direct helpers leave physical clicking available",function()
 local s,api,p,valid=buttonCase();api.activate=function()error("not supported")end
 assert(not activateChestButton(api,p,valid));assert(pressChestButton(api,p,valid)and s.down==1 and s.up==1)
end)
check("cancellation between direct events never invokes a late callback",function()
 local s,api,p,valid=buttonCase();local calls=0
 api.activate=function()calls+=1;return true end;s.onwait=function()s.valid=false end
 activateChestButton(api,p,valid);assert(calls==1)
end)
local function cycleCase()
    local state={time=0,restores=0,reports=0}
    local api={now=function()return state.time end,alive=function()return true end,ready=function()return true end,
        conflict=function()return false end,observeReward=function()end,show=function()end,cancelClaim=function()end,
        cancelRestore=function()end,stop=function()end,claim=function()return "pending" end,
        restore=function(snapshot,current)state.restores+=1 if state.onrestore then state.onrestore(snapshot,current)end return current()end,
        report=function()state.reports+=1 end}
    return state,api,createCycle(api)
end
check("Reward timeout reports failure before returning",function()
    local state,_,cycle=cycleCase()cycle.enabled=true cycle.phase="rewards"cycle.claimDeadline=30
    state.time=12 cycle:Tick()assert(cycle.phase=="rewards")
    state.time=30 cycle:Tick()assert(cycle.phase=="returning" and state.reports==1)
end)
check("Snapshot remains available throughout seat restoration",function()
    local state,_,cycle=cycleCase()cycle.enabled=true cycle.phase="returning"cycle.snapshot={}
    state.onrestore=function(snapshot)assert(cycle.snapshot==snapshot)end
    cycle:Tick()assert(cycle.snapshot==nil and cycle.phase=="waiting" and state.restores==1)
end)
check("Cancellation during restore cannot resurrect saved automation",function()
    local state,_,cycle=cycleCase()cycle.enabled=true cycle.phase="returning"cycle.snapshot={}
    state.onrestore=function()cycle:Cancel(false)end
    cycle:Tick()assert(cycle.phase=="off" and not cycle.enabled and not cycle.snapshot)
end)
check("Restore error is reported once without an endless restore loop",function()
    local state,_,cycle=cycleCase()cycle.enabled=true cycle.phase="returning"cycle.snapshot={}
    state.onrestore=function()error("simulated missing machine")end
    cycle:Tick()cycle:Tick()
    assert(cycle.phase=="off" and state.restores==1 and state.reports==1)
end)
print(tostring(count).." boss cycle scenarios passed")
