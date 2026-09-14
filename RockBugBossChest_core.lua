-- RockBugBossChest core contract: 1
local a=game:GetService("Players")
if not game:IsLoaded()then game.Loaded:Wait()end
local b=a.LocalPlayer
while not b do task.wait()b=a.LocalPlayer end
local c=b.Character or b.CharacterAdded:Wait()
local d=c:WaitForChild("HumanoidRootPart",15)
if not d then error("RockBugBossChest: HumanoidRootPart not found",0)end
local e=_G
if type(getgenv)=="function"then local f,g=pcall(getgenv)if f and type(g)=="table"then e=g end end
if e.RockBugBossChestBusy then return{startupReady=true,busy=true}end
e.RockBugBossChestBusy=true
local function h(v)return string.lower(tostring(v or""))end
local function i(v)
 local s=h(v)
 return (s:find("boss chest",1,true)~=nil)
  or (s:find("сундук",1,true)~=nil and s:find("босс",1,true)~=nil)
end
local function j(v)
 local s=h(v)
 return s:find("claim reward",1,true)~=nil
  or s:find("claim",1,true)~=nil
  or s:find("получить награду",1,true)~=nil
  or s:find("награду",1,true)~=nil
end
local function k(v)
 local s=h(v)
 if s:find("mythic",1,true)or s:find("мифик",1,true)then return 600 end
 if s:find("legendary",1,true)or s:find("легендар",1,true)then return 500 end
 if s:find("rainbow",1,true)or s:find("радуж",1,true)then return 450 end
 if s:find("epic",1,true)or s:find("эпич",1,true)then return 400 end
 if s:find("rare",1,true)or s:find("редк",1,true)then return 300 end
 if s:find("common",1,true)or s:find("общ",1,true)or s:find("обыч",1,true)then return 200 end
 return 100
end
local function l(x)
 local t={}
 local function q(v)if v and tostring(v)~=""then t[#t+1]=tostring(v)end end
 q(x.Name)
 if x:IsA("ProximityPrompt")then pcall(function()q(x.ActionText)q(x.ObjectText)end)end
 local p=x.Parent
 for _=1,6 do if not p or p==workspace then break end;q(p.Name)p=p.Parent end
 return table.concat(t," ")
end
local function m(x)
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
local function n()
 local ok,all=pcall(function()return workspace:GetDescendants()end)
 if not ok then return nil end
 local best,score=nil,-math.huge
 for idx,x in ipairs(all)do
  if idx>22000 then break end
  if x:IsA("ProximityPrompt")then
   local text=l(x)
   local object="";local action=""
   pcall(function()object=tostring(x.ObjectText or"")action=tostring(x.ActionText or"")end)
   if i(object)or i(text)then
    local s=k(object.." "..text)
    if j(action)or j(text)then s=s+250 end
    if x.Enabled then s=s+100 else s=s-1000 end
    local cf=m(x)
    if cf then
     local dist=(d.Position-cf.Position).Magnitude
     s=s-math.min(dist,500)*0.01
    end
    if s>score then best,score=x,s end
   end
  end
 end
 return best
end
local function o(x)
 local cf=m(x)if not cf then return false end
 d.Anchored=false
 d.CFrame=cf*CFrame.new(0,2.8,-3.2)
 d.AssemblyLinearVelocity=Vector3.new(0,0,0)
 d.AssemblyAngularVelocity=Vector3.new(0,0,0)
 return true
end
local function p(x)
 if not x or not x.Parent or not x.Enabled then return false end
 local ok=false
 if type(fireproximityprompt)=="function"then ok=pcall(function()fireproximityprompt(x,0)end)end
 if not ok then ok=pcall(function()x:InputHoldBegin()task.wait(math.max(0.05,tonumber(x.HoldDuration)or 0)+0.05)x:InputHoldEnd()end)end
 return ok
end
local success,result=xpcall(function()
 local prompt=nil
 for _=1,20 do prompt=n()if prompt then break end;task.wait(0.25)end
 if not prompt then error("RockBugBossChest: boss reward chest not found",0)end
 if not o(prompt)then error("RockBugBossChest: chest position not found",0)end
 task.wait(0.35)
 local fired=false
 for _=1,3 do
  if prompt and prompt.Parent and prompt.Enabled then fired=p(prompt)or fired end
  if fired then break end
  task.wait(0.18)
 end
 if not fired then error("RockBugBossChest: reward prompt press failed",0)end
 local object="";pcall(function()object=tostring(prompt.ObjectText or prompt.Name)end)
 return object
end,function(x)return tostring(x)end)
e.RockBugBossChestBusy=nil
if not success then warn("[RockBugBossChest] "..tostring(result))return{startupReady=true,success=false,error=tostring(result)}end
return{startupReady=true,success=true,chest=result}
