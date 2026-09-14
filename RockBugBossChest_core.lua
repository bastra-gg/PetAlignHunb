-- RockBugBossChest core contract: 1
local Players=game:GetService("Players")
if not game:IsLoaded()then game.Loaded:Wait()end
local lp=Players.LocalPlayer
while not lp do task.wait()lp=Players.LocalPlayer end
local char=lp.Character or lp.CharacterAdded:Wait()
local root=char:WaitForChild("HumanoidRootPart",15)
if not root then error("RockBugBossChest: HumanoidRootPart not found",0)end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
if env.RockBugBossChestBusy then return{startupReady=true,busy=true}end
env.RockBugBossChestBusy=true

local function low(v)return string.lower(tostring(v or""))end
local tiers={
 ["common boss chest"]=100,
 ["rare boss chest"]=200,
 ["epic boss chest"]=300,
 ["legendary boss chest"]=400,
 ["mythic boss chest"]=500,
}
local function chestTier(text)
 local s=low(text)
 for name,score in pairs(tiers)do if s:find(name,1,true)then return score,name end end
 -- Roblox-localized Russian text seen in-game.
 if s:find("сундук",1,true)and s:find("босс",1,true)then
  if s:find("мифик",1,true)or s:find("мифич",1,true)then return 500,"mythic" end
  if s:find("легендар",1,true)then return 400,"legendary" end
  if s:find("эпич",1,true)then return 300,"epic" end
  if s:find("редк",1,true)then return 200,"rare" end
  if s:find("общ",1,true)or s:find("обыч",1,true)then return 100,"common" end
  return 50,"boss chest"
 end
 return nil,nil
end
local function isClaim(text)
 local s=low(text)
 return s:find("claim reward",1,true)~=nil or s:find("claim",1,true)~=nil or s:find("получить награду",1,true)~=nil or s:find("награду",1,true)~=nil
end
local function context(x)
 local t={}
 local function add(v)if v and tostring(v)~=""then t[#t+1]=tostring(v)end end
 add(x.Name)
 if x:IsA("ProximityPrompt")then pcall(function()add(x.ActionText)add(x.ObjectText)end)end
 local p=x.Parent
 for _=1,6 do if not p or p==workspace then break end;add(p.Name)p=p.Parent end
 return table.concat(t," ")
end
local function worldCF(x)
 local y=x
 for _=1,8 do
  if not y or y==workspace then break end
  if y:IsA("Attachment")then local ok,v=pcall(function()return y.WorldCFrame end)if ok then return v end end
  if y:IsA("BasePart")then return y.CFrame end
  if y:IsA("Model")then local ok,v=pcall(function()return y:GetPivot()end)if ok then return v end end
  y=y.Parent
 end
 return nil
end
local function findChest()
 local ok,all=pcall(function()return workspace:GetDescendants()end)
 if not ok then return nil end
 local best,bestScore=nil,-math.huge
 for idx,x in ipairs(all)do
  if idx>24000 then break end
  if x:IsA("ProximityPrompt")then
   local object,action="",""
   pcall(function()object=tostring(x.ObjectText or"")action=tostring(x.ActionText or"")end)
   local full=context(x)
   local tier=chestTier(object.." "..full)
   if tier then
    local score=tier
    if isClaim(action)or isClaim(full)then score=score+300 end
    if x.Enabled then score=score+100 else score=score-1000 end
    local cf=worldCF(x)
    if cf then score=score-math.min((root.Position-cf.Position).Magnitude,1000)*0.005 end
    if score>bestScore then best,bestScore=x,score end
   end
  end
 end
 return best
end
local function teleportTo(x)
 local cf=worldCF(x)if not cf then return false end
 root.Anchored=false
 root.CFrame=cf*CFrame.new(0,2.8,-3.2)
 root.AssemblyLinearVelocity=Vector3.new(0,0,0)
 root.AssemblyAngularVelocity=Vector3.new(0,0,0)
 return true
end
local function press(x)
 if not x or not x.Parent or not x.Enabled then return false end
 local ok=false
 if type(fireproximityprompt)=="function"then ok=pcall(function()fireproximityprompt(x,0)end)end
 if not ok then ok=pcall(function()x:InputHoldBegin()task.wait(math.max(0.05,tonumber(x.HoldDuration)or 0)+0.05)x:InputHoldEnd()end)end
 return ok
end

local success,result=xpcall(function()
 local prompt=nil
 for _=1,24 do prompt=findChest()if prompt then break end;task.wait(0.25)end
 if not prompt then error("RockBugBossChest: boss chest not found",0)end
 if not teleportTo(prompt)then error("RockBugBossChest: chest position not found",0)end
 task.wait(0.35)
 local fired=false
 for _=1,3 do if prompt and prompt.Parent and prompt.Enabled then fired=press(prompt)or fired end;if fired then break end;task.wait(0.18)end
 if not fired then error("RockBugBossChest: reward prompt press failed",0)end
 local object="";pcall(function()object=tostring(prompt.ObjectText or prompt.Name)end)
 return object
end,function(x)return tostring(x)end)
env.RockBugBossChestBusy=nil
if not success then warn("[RockBugBossChest] "..tostring(result))return{startupReady=true,success=false,error=tostring(result)}end
return{startupReady=true,success=true,chest=result}
