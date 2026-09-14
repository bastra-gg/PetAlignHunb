-- RockBugHub TEST direct Boss Chest patch v1
-- Experimental: while the built-in boss cycle is in rewards phase, use the same
-- simple physical ProximityPrompt approach as the standalone chest tester.
local Players=game:GetService("Players")
local lp=Players.LocalPlayer
while not lp do task.wait()lp=Players.LocalPlayer end
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local q=env.RockBugRuntime
if type(q)~="table"then error("RockBugHub TEST chest patch: runtime not found",0)end
if env.RockBugDirectChestAddon and type(env.RockBugDirectChestAddon.Stop)=="function"then pcall(env.RockBugDirectChestAddon.Stop)end
local state={alive=true,nextAt=0,attempts=0,lastPrompt=nil,lastChest=nil}
env.RockBugDirectChestAddon=state
q.directBossChestAddon=state

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
 root.Anchored=false
 hum.Sit=false
 root.CFrame=cf*CFrame.new(0,3,-4)
 root.AssemblyLinearVelocity=Vector3.zero
 root.AssemblyAngularVelocity=Vector3.zero
 return true
end
local function press(prompt)
 if not prompt or not prompt.Parent or not prompt.Enabled then return false end
 local ok=false
 if type(fireproximityprompt)=="function"then ok=pcall(function()fireproximityprompt(prompt,0)end)end
 if not ok then
  ok=pcall(function()
   prompt:InputHoldBegin()
   task.wait(math.max(0.05,tonumber(prompt.HoldDuration)or 0)+0.03)
   prompt:InputHoldEnd()
  end)
 end
 return ok
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
 local fired=press(prompt)
 state.attempts+=1
 if fired then
  q.bossCycleStatus="Сундук: direct ProximityPrompt • "..tostring(name or"Boss Chest")
  return true,name
 end
 return false,"prompt press failed"
end
function state.Stop()
 state.alive=false
 if env.RockBugDirectChestAddon==state then env.RockBugDirectChestAddon=nil end
 if q.directBossChestAddon==state then q.directBossChestAddon=nil end
end
task.spawn(function()
 while state.alive and q.alive do
  local cycle=q.bossCycle
  if cycle and cycle.phase=="rewards"and os.clock()>=(state.nextAt or 0)then
   state.nextAt=os.clock()+1.25
   pcall(state.TryOnce)
  else
   state.nextAt=0
  end
  task.wait(0.12)
 end
 state.Stop()
end)
return state
