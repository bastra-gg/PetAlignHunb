-- RockBugHub TEST direct Boss Chest patch v6
-- Exclusive reward claimer: early TP + short fall guard + fireproximityprompt/InputHold + real claim verification.
local Players=game:GetService("Players")
local lp=Players.LocalPlayer
while not lp do task.wait()lp=Players.LocalPlayer end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local q=env.RockBugRuntime
if type(q)~="table"then error("RockBugHub TEST chest patch: runtime not found",0)end
if env.RockBugDirectChestAddon and type(env.RockBugDirectChestAddon.Stop)=="function"then pcall(env.RockBugDirectChestAddon.Stop)end

local cycle=q.bossCycle
if type(cycle)~="table"or type(cycle.Tick)~="function"then error("RockBugHub TEST chest patch: boss cycle not found",0)end
local originalTick=cycle.Tick

local state={
 alive=true,nextAt=0,nextScanAt=0,attempts=0,lastPrompt=nil,lastChest=nil,
 claimCount=tonumber(q.bossLootCount)or 0,lastClaimAt=nil,lastClaimChest=nil,lastLootText=nil,lastLootAt=nil,
 awaitingClaim=false,pendingChest=nil,pendingAt=nil,rewardsSince=nil,pressAt=nil,pressMethod=nil,pressBusy=false,
 verifiedAt=nil,verifyReason=nil,publishStarted=false,claimNode=nil,
 captureToken=0,candidates={},captureDone=true,uiEvidence=false,originalTick=originalTick,
 prePrompt=nil,preName=nil,preMoved=false,descendantConn=nil,enabledConn=nil,
 guardRoot=nil,guardWasAnchored=nil,guardUntil=0,
}
env.RockBugDirectChestAddon=state
q.directBossChestAddon=state
q.bossLootReport=q.bossLootReport or nil
q.bossLootCount=q.bossLootCount or 0
q.bossLootItems=q.bossLootItems or{}
q.bossLootItemCount=q.bossLootItemCount or 0

local function low(v)return string.lower(tostring(v or""))end
local tiers={
 ["common boss chest"]={100,"Common Boss Chest"},
 ["rare boss chest"]={200,"Rare Boss Chest"},
 ["epic boss chest"]={300,"Epic Boss Chest"},
 ["legendary boss chest"]={400,"Legendary Boss Chest"},
 ["mythic boss chest"]={500,"Mythic Boss Chest"},
}
local function tierOf(text)
 local s=low(text)
 for name,data in pairs(tiers)do if s:find(name,1,true)then return data[1],data[2]end end
 if s:find("сундук",1,true)and s:find("босс",1,true)then
  if s:find("мифик",1,true)or s:find("мифич",1,true)then return 500,"Mythic Boss Chest"end
  if s:find("легендар",1,true)then return 400,"Legendary Boss Chest"end
  if s:find("эпич",1,true)then return 300,"Epic Boss Chest"end
  if s:find("редк",1,true)then return 200,"Rare Boss Chest"end
  if s:find("общ",1,true)or s:find("обыч",1,true)then return 100,"Common Boss Chest"end
  return 50,"Boss Chest"
 end
 if s:find("boss chest",1,true)then return 50,"Boss Chest"end
 return nil,nil
end
local function claimText(text)
 local s=low(text)
 return s:find("claim reward",1,true)or s:find("claim",1,true)or s:find("collect",1,true)or s:find("reward",1,true)
  or s:find("получить награду",1,true)or s:find("собрать награду",1,true)or s:find("забрать награду",1,true)
end
local function context(prompt)
 local out={}
 local function add(v)if v and tostring(v)~=""then out[#out+1]=tostring(v)end end
 add(prompt.Name)
 pcall(function()add(prompt.ActionText)add(prompt.ObjectText)end)
 local node=prompt.Parent
 for _=1,7 do if not node or node==workspace then break end;add(node.Name)node=node.Parent end
 return table.concat(out," ")
end
local function bossPromptInfo(prompt)
 if not prompt or not prompt:IsA("ProximityPrompt")then return nil,nil end
 local objectText,actionText="",""
 pcall(function()objectText=tostring(prompt.ObjectText or"")actionText=tostring(prompt.ActionText or"")end)
 local full=context(prompt)
 local tier,name=tierOf(objectText.." "..full)
 if not tier then return nil,nil end
 local score=tier+(claimText(actionText)and 500 or claimText(full)and 250 or 0)
 return name,score
end
local function worldCF(obj)
 local node=obj
 for _=1,8 do
  if not node or node==workspace then break end
  if node:IsA("Attachment")then local ok,v=pcall(function()return node.WorldCFrame end)if ok then return v end end
  if node:IsA("BasePart")then return node.CFrame end
  if node:IsA("Model")then local ok,v=pcall(function()return node:GetPivot()end)if ok then return v end end
  node=node.Parent
 end
 return nil
end
local function characterParts()
 local ch=lp.Character
 return ch,ch and ch:FindFirstChild("HumanoidRootPart"),ch and ch:FindFirstChildWhichIsA("Humanoid")
end
local function chestNode(prompt)
 local node=prompt and prompt.Parent
 local fallback=node
 for _=1,7 do
  if not node or node==workspace then break end
  local tier=tierOf(node.Name)
  if tier then return node end
  if node:IsA("Model")then fallback=node end
  node=node.Parent
 end
 return fallback
end
local function findPrompt(allowDisabled)
 local _,root=characterParts()if not root then return nil,nil end
 local ok,nodes=pcall(function()return workspace:GetDescendants()end)if not ok then return nil,nil end
 local best,bestName,bestScore=nil,nil,-math.huge
 for index,obj in ipairs(nodes)do
  if index>28000 then break end
  if obj:IsA("ProximityPrompt")and(allowDisabled or obj.Enabled)then
   local name,score=bossPromptInfo(obj)
   if score then
    local cf=worldCF(obj)
    if cf then score=score-math.min((root.Position-cf.Position).Magnitude,1500)*0.01 else score-=10000 end
    if score>bestScore then best,bestName,bestScore=obj,name,score end
   end
  end
 end
 return best,bestName
end

local function stopGuard()
 local root=state.guardRoot
 if root and root.Parent then
  local restore=state.guardWasAnchored
  pcall(function()root.Anchored=restore==true end)
 end
 state.guardRoot=nil state.guardWasAnchored=nil state.guardUntil=0
end
local function startGuard()
 stopGuard()
 local _,root,hum=characterParts()
 if not root or not hum or hum.Health<=0 then return false end
 state.guardRoot=root state.guardWasAnchored=root.Anchored state.guardUntil=os.clock()+1.6
 pcall(function()
  root.AssemblyLinearVelocity=Vector3.zero
  root.AssemblyAngularVelocity=Vector3.zero
  root.Anchored=true
 end)
 return true
end
local function moveTo(prompt)
 local _,root,hum=characterParts()
 if not root or not hum or hum.Health<=0 then return false end
 local cf=worldCF(prompt)if not cf then return false end
 stopGuard()
 root.Anchored=false hum.Sit=false
 root.CFrame=cf*CFrame.new(0,2.6,-3.1)
 root.AssemblyLinearVelocity=Vector3.zero root.AssemblyAngularVelocity=Vector3.zero
 return true
end
local function inRange(prompt)
 local _,root,hum=characterParts()if not root or not hum or hum.Health<=0 then return false end
 local cf=worldCF(prompt)if not cf then return false end
 local max=10
 pcall(function()max=math.max(5,math.min(12,tonumber(prompt.MaxActivationDistance)or 10)-0.5)end)
 return (root.Position-cf.Position).Magnitude<=max
end
local function cachePrompt(prompt,name)
 if not prompt or not prompt.Parent then return false end
 state.prePrompt=prompt state.preName=name or state.preName state.claimNode=chestNode(prompt)
 if state.enabledConn then pcall(function()state.enabledConn:Disconnect()end)state.enabledConn=nil end
 state.enabledConn=prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
  if not state.alive or not prompt.Parent then return end
  local c=q.bossCycle local phase=c and c.phase
  if prompt.Enabled and(phase=="arena"or phase=="rewards")then
   if not inRange(prompt)then state.preMoved=moveTo(prompt)else state.preMoved=true end
   if phase=="rewards"and not state.verifiedAt then task.defer(function()if state.alive then pcall(state.TryOnce)end end)end
  end
 end)
 return true
end
local function preTeleport()
 if not state.alive then return false end
 local c=q.bossCycle local phase=c and c.phase
 if phase~="arena"and phase~="rewards"then return false end
 local prompt,name=state.prePrompt,state.preName
 if not prompt or not prompt.Parent then
  local now=os.clock()
  if now<state.nextScanAt then return false end
  state.nextScanAt=now+0.35
  prompt,name=findPrompt(true)
  if prompt then cachePrompt(prompt,name)end
 end
 if not prompt then return false end
 if not inRange(prompt)then state.preMoved=moveTo(prompt)else state.preMoved=true;stopGuard()end
 if state.preMoved then q.bossCycleStatus="Сундук: быстрый ТП • "..tostring(name or"Boss Chest")end
 return state.preMoved
end

-- Same interaction family used by the readable public scripts we checked:
-- executor fireproximityprompt first, then a real InputHold fallback if the prompt is still active.
local function press(prompt)
 if not prompt or not prompt.Parent or not prompt.Enabled then return false,"inactive"end
 local sent=false local used={}
 if type(fireproximityprompt)=="function"then
  local ok=pcall(function()fireproximityprompt(prompt,0)end)
  if ok then sent=true;used[#used+1]="fire"end
  task.wait(0.04)
 end
 if prompt and prompt.Parent and prompt.Enabled then
  local hold=math.max(0.05,tonumber(prompt.HoldDuration)or 0)
  local ok=pcall(function()
   prompt:InputHoldBegin()
   task.wait(hold+0.05)
   prompt:InputHoldEnd()
  end)
  if ok then sent=true;used[#used+1]="hold"end
 end
 return sent,#used>0 and table.concat(used,"+")or"none"
end

local function visible(obj)
 if not obj:IsA("TextLabel")and not obj:IsA("TextButton")then return false end
 if not obj.Visible or obj.TextTransparency>=1 then return false end
 local node=obj.Parent
 while node and node~=lp.PlayerGui do
  if node:IsA("GuiObject")and not node.Visible then return false end
  if node:IsA("LayerCollector")and not node.Enabled then return false end
  node=node.Parent
 end
 return node~=nil
end
local function clean(text)
 local s=tostring(text or""):gsub("<[^>]+>",""):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
 if #s<2 or #s>90 then return nil end
 return s
end
local function rewardScore(obj,text)
 local s=low(text)
 if claimText(s)then return -100 end
 if s=="стоп"or s=="stop"or s=="настройки"or s=="settings"then return -100 end
 local ctx="" local node=obj
 for _=1,6 do if not node or node==lp.PlayerGui then break end;ctx=ctx.." "..low(node.Name)node=node.Parent end
 local score=0
 for _,w in ipairs({"reward","chest","loot","prize","result","drop","item","pet","aura","награ","сундук","лут","предмет","питом","аура"})do
  if ctx:find(w,1,true)then score+=5 end
  if s:find(w,1,true)then score+=3 end
 end
 if s:find("%+")or s:find("x%d")or s:find("×%d")then score+=1 end
 return score
end
local function snapshot()
 local map={}
 local pg=lp:FindFirstChildOfClass("PlayerGui")if not pg then return map end
 local ok,nodes=pcall(function()return pg:GetDescendants()end)if not ok then return map end
 for _,obj in ipairs(nodes)do
  if (obj:IsA("TextLabel")or obj:IsA("TextButton"))and visible(obj)then local t=clean(obj.Text)if t then map[obj]=t end end
 end
 return map
end
local function startCapture()
 state.captureToken+=1
 local token=state.captureToken
 local before=snapshot()
 state.candidates={} state.captureDone=false state.uiEvidence=false
 task.spawn(function()
  local seen,best={},{}
  for _=1,9 do
   task.wait(0.20)
   if not state.alive or token~=state.captureToken then return end
   local after=snapshot()
   for obj,text in pairs(after)do
    if before[obj]~=text and not seen[text]then
     local score=rewardScore(obj,text)
     if score>=5 then
      seen[text]=true best[#best+1]={score=score,text=text}
      if token==state.captureToken then state.uiEvidence=true end
     end
    end
   end
  end
  table.sort(best,function(a,b)if a.score~=b.score then return a.score>b.score end return #a.text<#b.text end)
  local out={}
  for i=1,math.min(20,#best)do out[#out+1]=best[i].text end
  if token==state.captureToken then state.candidates=out state.captureDone=true end
 end)
end
local function publishClaim()
 if state.publishStarted or not state.awaitingClaim then return end
 state.publishStarted=true
 local deadline=os.clock()+1.95
 while state.alive and not state.captureDone and os.clock()<deadline do task.wait(0.05)end
 state.claimCount+=1
 state.lastClaimAt=os.clock()
 state.lastClaimChest=state.pendingChest or state.lastChest or"Boss Chest"
 local items={}
 for i,v in ipairs(state.candidates or{})do items[i]=v end
 local text=#items>0 and table.concat(items," • ")or state.lastClaimChest
 state.lastLootText=text state.lastLootAt=state.lastClaimAt
 q.bossLootReport=text q.bossLootChest=state.lastClaimChest q.bossLootCount=state.claimCount q.bossLootAt=state.lastClaimAt
 q.bossLootItems=items q.bossLootItemCount=#items
 state.awaitingClaim=false state.pendingChest=nil state.pendingAt=nil state.candidates={} state.captureDone=true
end
local function claimEvidence()
 if not state.pressAt then return false,nil end
 local prompt=state.lastPrompt or state.prePrompt
 if not prompt or not prompt.Parent then return true,"prompt removed"end
 local okEnabled,enabled=pcall(function()return prompt.Enabled end)
 if okEnabled and not enabled then return true,"prompt disabled"end
 local node=state.claimNode
 if node then
  local okInside,inside=pcall(function()return node:IsDescendantOf(workspace)end)
  if okInside and not inside then return true,"chest removed"end
 end
 if state.uiEvidence then return true,"reward ui"end
 return false,nil
end

function state.TryOnce()
 if not state.alive or not q.alive then return false,"stopped"end
 if state.pressBusy then return false,"busy"end
 local c=q.bossCycle
 if not c or c.phase~="rewards"then return false,"not rewards phase"end
 if state.verifiedAt then return true,state.lastChest end
 local prompt,name=state.prePrompt,state.preName
 if not prompt or not prompt.Parent or not prompt.Enabled then
  local now=os.clock()
  if now>=state.nextScanAt then
   state.nextScanAt=now+0.35
   prompt,name=findPrompt(false)
   if prompt then cachePrompt(prompt,name)end
  else
   prompt=nil
  end
 end
 if not prompt then return false,"boss chest prompt not found"end
 state.lastPrompt=prompt state.lastChest=name or state.preName state.claimNode=state.claimNode or chestNode(prompt)
 if not inRange(prompt)then state.preMoved=moveTo(prompt)else state.preMoved=true;stopGuard()end
 if not state.preMoved then return false,"move failed"end
 task.wait(0.02)
 if not state.alive or not q.alive or not q.bossCycle or q.bossCycle.phase~="rewards"then return false,"phase changed"end
 if not state.awaitingClaim then
  state.awaitingClaim=true state.pendingChest=state.lastChest state.pendingAt=os.clock() state.publishStarted=false
  startCapture()
 end
 state.pressBusy=true
 local fired,method=press(prompt)
 state.pressBusy=false
 state.attempts+=1
 if fired then
  state.pressAt=os.clock() state.pressMethod=method
  q.bossCycleStatus="Сундук: нажал ("..tostring(method)..") • жду подтверждение"
  return true,state.lastChest
 end
 return false,"prompt press failed"
end

local function resetAttempt()
 stopGuard()
 if state.enabledConn then pcall(function()state.enabledConn:Disconnect()end)state.enabledConn=nil end
 state.prePrompt=nil state.preName=nil state.preMoved=false state.nextAt=0 state.nextScanAt=0
 state.rewardsSince=nil state.pressAt=nil state.pressMethod=nil state.pressBusy=false
 state.verifiedAt=nil state.verifyReason=nil state.claimNode=nil state.uiEvidence=false state.publishStarted=false
 state.awaitingClaim=false state.pendingChest=nil state.pendingAt=nil
end

-- Old T38 reward collector NEVER runs while phase == rewards.
cycle.Tick=function(self)
 if not state.alive then return originalTick(self)end
 if self.phase~="rewards"then
  local before=self.phase
  local result=originalTick(self)
  local after=self.phase
  if after=="arena"then
   if before~="arena"then
    resetAttempt()
    task.defer(preTeleport)
   end
  elseif after=="rewards"then
   if not state.rewardsSince then state.rewardsSince=os.clock()end
   startGuard()
   task.defer(function()if state.alive then preTeleport()pcall(state.TryOnce)end end)
  elseif before=="rewards"and after~="rewards"then
   stopGuard()
  end
  return result
 end
 local now=os.clock()
 if not state.rewardsSince then state.rewardsSince=now;startGuard()end
 local verified,reason=claimEvidence()
 if verified and not state.verifiedAt then
  state.verifiedAt=now state.verifyReason=reason stopGuard()
  q.bossCycleStatus="Награда подтверждена • "..tostring(reason)
  task.spawn(publishClaim)
 end
 if state.verifiedAt and now-state.verifiedAt>=0.18 then
  self.phase="returning"
  q.bossCycleStatus="Награда забрана • возвращаюсь"
  return
 end
 if not state.verifiedAt and not state.pressBusy and now>=(state.nextAt or 0)then
  state.nextAt=now+0.32
  preTeleport()
  task.defer(function()if state.alive then pcall(state.TryOnce)end end)
 end
 if now-state.rewardsSince>=8 then
  stopGuard()
  state.awaitingClaim=false
  self.phase="returning"
  q.bossCycleError="Сундук: нажатие не подтвердилось за 8 сек"
  q.bossCycleStatus="Сундук не подтверждён • возвращаюсь"
  return
 end
end

-- Catch the reward prompt at spawn time. Full workspace fallback scan is throttled to 0.35 s.
state.descendantConn=workspace.DescendantAdded:Connect(function(obj)
 if not state.alive or not obj:IsA("ProximityPrompt")then return end
 local c=q.bossCycle local phase=c and c.phase
 if phase~="arena"and phase~="rewards"then return end
 task.defer(function()
  if not state.alive or not obj.Parent then return end
  local name,score=bossPromptInfo(obj)
  if not score then return end
  cachePrompt(obj,name)
  preTeleport()
  if q.bossCycle and q.bossCycle.phase=="rewards"and obj.Enabled then pcall(state.TryOnce)end
 end)
end)

function state.Stop()
 if not state.alive then return end
 state.alive=false state.captureToken+=1 stopGuard()
 if state.descendantConn then pcall(function()state.descendantConn:Disconnect()end)state.descendantConn=nil end
 if state.enabledConn then pcall(function()state.enabledConn:Disconnect()end)state.enabledConn=nil end
 if q.bossCycle==cycle and cycle.Tick~=originalTick then cycle.Tick=originalTick end
 if env.RockBugDirectChestAddon==state then env.RockBugDirectChestAddon=nil end
 if q.directBossChestAddon==state then q.directBossChestAddon=nil end
end

task.spawn(function()
 while state.alive and q.alive do
  local c=q.bossCycle local phase=c and c.phase or nil
  if state.guardRoot and (phase~="rewards"or os.clock()>=state.guardUntil)then stopGuard()end
  if phase=="arena"and not state.preMoved then
   preTeleport()
  elseif phase=="rewards"and not state.verifiedAt and not state.pressBusy and os.clock()>=(state.nextAt or 0)then
   state.nextAt=os.clock()+0.32
   preTeleport()
   task.defer(function()if state.alive then pcall(state.TryOnce)end end)
  elseif phase~="arena"and phase~="rewards"then
   state.nextAt=0
  end
  task.wait(0.08)
 end
 state.Stop()
end)
return state