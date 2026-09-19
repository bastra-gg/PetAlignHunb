local count=0
local function check(name,callback)callback();count+=1;print("PASS "..name)end
local h=HUD.mount(runtime,options)
env.RockBugRuntime=runtime
local function getgenv()return env end
local function warn(message)table.insert(errors,message)end
local function step()
 h.openedAt=os.clock()-1;h.visualElapsed=1;run:Step();assert(#errors==0,errors[1])
end
step()
-- __PINNED_PATCHES__
local nativeSpawn=task.spawn
local workers={}
task.spawn=function(callback)
 local thread=coroutine.create(callback);table.insert(workers,thread)
 local ok,err=coroutine.resume(thread);assert(ok,err)
end
task.wait=function()coroutine.yield()end
local captions=(function()
-- __STABLE_CARDS__
end)()
local boss=(function()
-- __BOSS_COMPACT__
end)()
task.spawn=nativeSpawn
local function pump()
 for _,thread in ipairs(workers)do if coroutine.status(thread)~="dead"then local ok,err=coroutine.resume(thread);assert(ok,err)end end
end
check("current T64 adaptive captions retain their single writer",function()
 runtime.adaptiveRockDurability=98765;runtime.adaptiveMachineAuto=true
 runtime.selectedMachine={label="Bench",zone="Jungle",variant="King"}
 pump();step()
 assert(h.cards[2].hint.Text:find("Jungle",1,true))
 local caption=h.cards[2].more.text.Text
 assert(caption=="Залы и тренажёры  →")
 h.nextRefresh=nil;step();assert(h.cards[2].more.text.Text==caption)
end)
check("farm caption locks do not overwrite growth or kill sections",function()
 h:SelectGroup("growth");step()
 local node=h.cards[4].more.text
 node:GetPropertyChangedSignal("Text"):Fire()
 assert(node.Text=="Все локации  →")
 h:SelectGroup("farm");pump();step()
 assert(h.cards[4].more.text.Text:find("Лут:",1,true))
end)
check("current BossCompact loot callback opens the new details popup",function()
 runtime.bossLootCount=1;runtime.bossLootItemCount=2;runtime.bossLootItems={"Aura A","Aura B"}
 pump();h.cards[4].more.node.Activated:Fire()
 assert(h.noticePanel.Visible and h.notice.Text:find("Aura A",1,true))
 h:SelectGroup("growth");step();h.cards[4].more.node.Activated:Fire()
 assert(h.modalTab=="teleport" and h.modalOpen)
 h:CloseFull(true);step()
end)
captions.Destroy();boss.Destroy()
local install
install=function()
-- __INSTALL__
end
check("HUD handoff preserves all current controls and automation functions",function()
 local tick=function()return "T64 coordinator"end
 local guard=function()return "T64 rebirth gate"end
 runtime.bossCycle={Tick=tick};runtime.machineRebirthAllowed=guard
 h:OpenFull("farm",h.cards[2]);local page=q.hologramContent.Pages.farm
 local control=page:FindFirstChild("OriginalControl")
 local previous=h
 h=install();assert(h and runtime.hologram==h and previous.destroyed)
 assert(page.Parent==h.body and not page.destroyed and control.Parent==page)
 assert(runtime.bossCycle.Tick==tick and runtime.machineRebirthAllowed==guard)
 assert(h.modalOpen and h.modalTab=="farm")
 control.Activated:Fire();assert(q.controlHits.farm==1)
 h:CloseFull(true);step();assert(h.ready and next(run.bindings)~=nil)
end)
check("failed replacement restores the previous interface and its controls",function()
 h:OpenFull("farm",h.cards[2]);local previous=h
 local instanceNew=Instance.new;local fail=true
 Instance.new=function(class)
  if class=="Beam"and fail then fail=false;error("injected construction failure")end
  return instanceNew(class)
 end
 local ok=pcall(install);Instance.new=instanceNew
 assert(not ok and runtime.hologram==previous and not previous.destroyed)
 assert(previous.modalOpen and q.hologramContent.Pages.farm.Parent==previous.body)
 previous:CloseFull(true);step();assert(previous.ready)
end)
h:Destroy()
print("T64 compatibility/install: "..count.." scenarios passed")
