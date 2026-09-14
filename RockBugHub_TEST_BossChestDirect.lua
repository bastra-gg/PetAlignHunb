-- RockBugHub TEST direct Boss Chest patch v2
-- Physical ProximityPrompt claiming + lightweight confirmed-loot report.
local Players=game:GetService("Players")
local lp=Players.LocalPlayer
while not lp do task.wait()lp=Players.LocalPlayer end
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local q=env.RockBugRuntime
if type(q)~="table"then error("RockBugHub TEST chest patch: runtime not found",0)end
if env.RockBugDirectChestAddon and type(env.RockBugDirectChestAddon.Stop)=="function"then pcall(env.RockBugDirectChestAddon.Stop)end

local state={alive=true,nextAt=0,attempts=0,lastPrompt=nil,lastChest=nil,claimCount=0,lastClaimAt=nil,lastClaimChest=nil,lastLootText=nil,lastLootAt=nil,awaitingClaim=false,pendingChest=nil,pendingAt=nil,captureToken=0,candidates={}}
env.RockBugDirectChestAddon=state
q.directBossChestAddon=state
q.bossLootReport=q.bossLootReport or nil
q.bossLootCount=q.bossLootCount or 0

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
local function findPrompt()
 local _,root=characterParts()if not root then return nil,nil end
 local ok,nodes=pcall(function()return workspace:GetDescendants()end)if not ok then return nil,nil end
 local best,bestName,bestScore=nil,nil,-math.huge
 for index,obj in ipairs(nodes)do
  if index>28000 then break end
  if obj:IsA("ProximityPrompt")and obj.Enabled then
   local objectText,actionText="",""
   pcall(function()objectText=tostring(obj.ObjectText or"")actionText=tostring(obj.ActionText or"")end)
   local full=context(obj)
   local tier,name=tierOf(objectText.." "..full)
   if tier then
    local score=tier+(claimText(actionText)and 500 or claimText(full)and 250 or 0)
    local cf=worldCF(obj)
    if cf then score=score-math.min((root.Position-cf.Position).Magnitude,1500)*0.01 else score=score-10000 end
    if score>bestScore then best,bestName,bestScore=obj,name,score end
   end
  end
 end
 return best,bestName
end
local function moveTo(prompt)
 local _,root,hum=characterParts()
 if not root or not hum or hum.Health<=0 then return false end
 local cf=worldCF(prompt)if not cf then return false end
 root.Anchored=false hum.Sit=false
 root.CFrame=cf*CFrame.new(0,3,-4)
 root.AssemblyLinearVelocity=Vector3.zero root.AssemblyAngularVelocity=Vector3.zero
 return true
end
local function press(prompt)
 if not prompt or not prompt.Parent or not prompt.Enabled then return false end
 local ok=false
 if type(fireproximityprompt)=="function"then ok=pcall(function()fireproximityprompt(prompt,0)end)end
 if not ok then ok=pcall(function()prompt:InputHoldBegin()task.wait(math.max(0.05,tonumber(prompt.HoldDuration)or 0)+0.03)prompt:InputHoldEnd()end)end
 return ok
end

-- Only runs around a chest press, never continuously.
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
  if (obj:IsA("TextLabel")or obj:IsA("TextButton"))and visible(obj)then
   local t=clean(obj.Text)if t then map[obj]=t end
  end
 end
 return map
end
local function startCapture()
 state.captureToken+=1
 local token=state.captureToken
 local before=snapshot()
 state.candidates={}
 task.spawn(function()
  local seen={} local best={}
  for _=1,8 do
   task.wait(0.22)
   if not state.alive or token~=state.captureToken then return end
   local after=snapshot()
   for obj,text in pairs(after)do
    if before[obj]~=text and not seen[text]then
     local score=rewardScore(obj,text)
     if score>=5 then seen[text]=true table.insert(best,{score=score,text=text})end
    end
   end
  end
  table.sort(best,function(a,b)if a.score~=b.score then return a.score>b.score end return #a.text<#b.text end)
  local out={}
  for i=1,math.min(3,#best)do out[#out+1]=best[i].text end
  if token==state.captureToken then state.candidates=out end
 end)
end
local function confirmClaim()
 state.claimCount+=1
 state.lastClaimAt=os.clock()
 state.lastClaimChest=state.pendingChest or state.lastChest or"Boss Chest"
 local text=#(state.candidates or{})>0 and table.concat(state.candidates," • ")or state.lastClaimChest
 state.lastLootText=text state.lastLootAt=state.lastClaimAt
 q.bossLootReport=text q.bossLootChest=state.lastClaimChest q.bossLootCount=state.claimCount q.bossLootAt=state.lastClaimAt
 state.awaitingClaim=false state.pendingChest=nil state.pendingAt=nil state.candidates={}
end

function state.TryOnce()
 if not state.alive or not q.alive then return false,"stopped"end
 local cycle=q.bossCycle
 if not cycle or cycle.phase~="rewards"then return false,"not rewards phase"end
 local prompt,name=findPrompt()
 if not prompt then return false,"boss chest prompt not found"end
 state.lastPrompt=prompt state.lastChest=name
 if not moveTo(prompt)then return false,"move failed"end
 task.wait(0.30)
 if not state.alive or not q.alive or not q.bossCycle or q.bossCycle.phase~="rewards"then return false,"phase changed"end
 if not state.awaitingClaim then state.awaitingClaim=true state.pendingChest=name state.pendingAt=os.clock()startCapture()end
 local fired=press(prompt)
 state.attempts+=1
 if fired then q.bossCycleStatus="Сундук: direct ProximityPrompt • "..tostring(name or"Boss Chest")return true,name end
 return false,"prompt press failed"
end
function state.Stop()
 state.alive=false state.captureToken+=1
 if env.RockBugDirectChestAddon==state then env.RockBugDirectChestAddon=nil end
 if q.directBossChestAddon==state then q.directBossChestAddon=nil end
end

task.spawn(function()
 local lastPhase=nil
 while state.alive and q.alive do
  local cycle=q.bossCycle local phase=cycle and cycle.phase or nil
  if state.awaitingClaim and lastPhase=="rewards"and phase and phase~="rewards"then
   if phase=="returning"or phase=="waiting"or phase=="arena"then confirmClaim()else state.awaitingClaim=false end
  end
  if cycle and phase=="rewards"and os.clock()>=(state.nextAt or 0)then
   state.nextAt=os.clock()+1.25 pcall(state.TryOnce)
  elseif phase~="rewards"then state.nextAt=0 end
  lastPhase=phase
  task.wait(0.12)
 end
 state.Stop()
end)
return state