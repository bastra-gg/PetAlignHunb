-- RockBugHub TEST T80: Overcharge Rock + dynamic update rocks
local Players=game:GetService("Players")
local player=Players.LocalPlayer
if not player then return end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local q=env.RockBugRuntime
if type(q)~="table"then return end
if env.RockBugAdaptiveRocks and type(env.RockBugAdaptiveRocks.Destroy)=="function"then pcall(env.RockBugAdaptiveRocks.Destroy)end

local patch={alive=true,auto=true,applying=false,lastDurability=nil,lastRock=nil,connections={},durabilityObject=nil,durabilityConnection=nil}
env.RockBugAdaptiveRocks=patch
q.adaptiveRocks=true
q.adaptiveRockAuto=true

local rocks={
 {id="AncientJungle",label="Древний лес",en="Ancient Jungle",req=10000000,mult=16.25},
 {id="MuscleKing",label="Король мышц",en="Muscle King",req=5000000,mult=12.5},
 {id="Legends",label="Легенды",en="Legends",req=1000000,mult=2.5},
 {id="Inferno",label="Инферно",en="Inferno",req=750000,mult=1.125},
 {id="Mystic",label="Мистический",en="Mystic",req=400000,mult=0.75},
 {id="Frozen",label="Ледяной",en="Frozen",req=150000,mult=0.375},
 {id="Golden",label="Золотой",en="Golden",req=5000,mult=0.2},
 {id="Large",label="Большой",en="Large",req=100,mult=0.075},
 {id="Punching",label="Пробивной",en="Punching",req=10,mult=0.05},
 {id="Tiny",label="Маленький",en="Tiny",req=0,mult=0.025},
}

local function compact(v)
 v=tonumber(v)if not v then return "—"end
 local a=math.abs(v)
 for _,u in ipairs({{1e15,"Q"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}})do
  if a>=u[1]then local s=("%.2f%s"):format(v/u[1],u[2]);return s:gsub("%.00([KMBTQ])$","%1"):gsub("(%.[0-9])0([KMBTQ])$","%1%2")end
 end
 return tostring(math.floor(v+0.5))
end

local function parse(v)
 if type(v)=="number"then return v end
 local s=tostring(v or""):lower():gsub("%s+","")
 local n,suf=s:match("^([%+%-]?[%d%.,]+)([kmbtq]?)$")
 if not n then return tonumber(v)end
 if n:find(",",1,true)and not n:find("%.")then
  local a,b=n:match("^(%-?%d+),(%d+)$")
  if a and b and #b<=2 then n=a.."."..b else n=n:gsub(",","")end
 else n=n:gsub(",","")end
 local x=tonumber(n)if not x then return nil end
 return x*(({k=1e3,m=1e6,b=1e9,t=1e12,q=1e15})[suf]or 1)
end

local function findDurabilityObject()
 -- Muscle Legends keeps the live stat directly at LocalPlayer.Durability.
 -- Do not choose similarly named mirrors/requirements; that was the source of the stale 600 value.
 local direct=player:FindFirstChild("Durability")
 if direct and direct:IsA("ValueBase")then return direct end
 local directLower=player:FindFirstChild("durability")
 if directLower and directLower:IsA("ValueBase")then return directLower end
 local leader=player:FindFirstChild("leaderstats")
 if leader then
  local v=leader:FindFirstChild("Durability")or leader:FindFirstChild("durability")
  if v and v:IsA("ValueBase")then return v end
 end
 return nil
end

local function readDurability()
 local obj=patch.durabilityObject
 if not obj or not obj.Parent then obj=findDurabilityObject()patch.durabilityObject=obj end
 if obj then
  local ok,v=pcall(function()return parse(obj.Value)end)
  if ok and v and v>=0 then q.adaptiveRockSource=obj:GetFullName()return v end
 end
 -- Last-resort attribute fallback only; never scan every descendant for fuzzy names.
 for _,key in ipairs({"Durability","durability"})do
  local ok,v=pcall(function()return parse(player:GetAttribute(key))end)
  if ok and v and v>=0 then q.adaptiveRockSource="attribute:"..key return v end
 end
 q.adaptiveRockSource=nil
 return nil
end

local lastRockDiscovery=0
local knownReq={}
for _,r in ipairs(rocks)do knownReq[tonumber(r.req)or-1]=r end

local function numericValue(obj)
 if not obj then return nil end
 local ok,v=pcall(function()return obj.Value end)
 if ok then return tonumber(v)end
 return nil
end

local function rockModel(valueObject)
 local p=valueObject and valueObject.Parent
 local fallback=p
 for _=1,8 do
  if not p or p==workspace then break end
  fallback=fallback or p
  if p:IsA("Model")and(p:FindFirstChild("LeftHand",true)or p:FindFirstChild("RightHand",true))then return p end
  p=p.Parent
 end
 return fallback
end

local function discoverMultiplier(model)
 if not model then return nil end
 for _,key in ipairs({"petXpMultiplier","PetXpMultiplier","xpMultiplier","XPMultiplier","experienceMultiplier","rockMultiplier","RockMultiplier","Multiplier","multiplier"})do
  local node=model:FindFirstChild(key,true)
  local v=numericValue(node)
  if not v then
   local ok,a=pcall(function()return model:GetAttribute(key)end)
   if ok then v=tonumber(a)end
  end
  if v and v>0 then return v end
 end
 return nil
end

local function displayRockName(model,req)
 if not model then return "Rock "..tostring(req)end
 local p=model
 for _=1,8 do
  if not p or p==workspace then break end
  local n=tostring(p.Name or"")
  if n:lower():find("overcharg",1,true)then return "Overcharge Rock"end
  for _,key in ipairs({"Zone","zone","Gym","gym","Location","location","Area","area"})do
   local ok,v=pcall(function()return p:GetAttribute(key)end)
   if ok and type(v)=="string"and v:lower():find("overcharg",1,true)then return "Overcharge Rock"end
  end
  p=p.Parent
 end
 local name=tostring(model.Name or"")
 local lower=name:lower()
 if name~=""and lower~="rock"and lower~="model"then return name end
 p=model.Parent
 for _=1,4 do
  if not p or p==workspace then break end
  local n=tostring(p.Name or"")
  local l=n:lower()
  if n~=""and l~="workspace"and l~="rocks"and l~="rocksfolder"then return n.." Rock"end
  p=p.Parent
 end
 return "Rock "..tostring(req)
end

local function refreshDiscoveredRocks(force)
 local now=os.clock()
 if not force and now-lastRockDiscovery<2 then return end
 lastRockDiscovery=now
 local changed=false
 local ok,all=pcall(function()return workspace:GetDescendants()end)
 if not ok or type(all)~="table"then return end
 for i,obj in ipairs(all)do
  if tostring(obj.Name)=="neededDurability"then
   local req=numericValue(obj)
   if req and req>=0 and not knownReq[req]then
    local model=rockModel(obj)
    local mult=discoverMultiplier(model)
    local name=displayRockName(model,req)
    local row={id="DynamicRock_"..tostring(req),label=name,en=name,req=req,mult=mult or 0,discovered=true,multVerified=mult~=nil}
    knownReq[req]=row
    table.insert(rocks,row)
    changed=true
   end
  end
  if i%1200==0 then task.wait()end
 end
 if changed then
  table.sort(rocks,function(a,b)return(tonumber(a.req)or 0)>(tonumber(b.req)or 0)end)
  q.adaptiveRockCatalogVersion=(tonumber(q.adaptiveRockCatalogVersion)or 0)+1
 end
end

local function bestRock(v)
 if v==nil then return nil end
 refreshDiscoveredRocks(false)
 for _,r in ipairs(rocks)do if v>=r.req then return r end end
 return rocks[#rocks]
end

local function nameOf(r)
 if not r then return "—"end
 if q.layoutUI and type(q.layoutUI.rockName)=="function"then
  local ok,n=pcall(q.layoutUI.rockName,r)
  if ok and type(n)=="string"and n~=""then return n end
 end
 return q.language=="en"and r.en or r.label
end

local function paintDetails()
 local ru=q.language~="en" local selected=q.selectedRock local d=q.adaptiveRockDurability
 local layout=q.layoutUI local ui=q.ui
 if type(layout)=="table"then
  if layout.autoRockButton and layout.autoRockButton.Parent then layout.autoRockButton.Visible=true end
  if layout.chooseRockButton and layout.chooseRockButton.Parent then layout.chooseRockButton.Visible=true;layout.chooseRockButton.Parent.Visible=true end
 end
 if type(ui)=="table"then
  if ui.autoRockTitle and ui.autoRockTitle.Parent then ui.autoRockTitle.Text=patch.auto and(ru and"АВТОПОДБОР ПО ДОЛГОВЕЧНОСТИ"or"AUTO ROCK BY DURABILITY")or(ru and"РУЧНАЯ НАСТРОЙКА"or"MANUAL SELECTION")end
  if ui.autoRockName and ui.autoRockName.Parent and selected then ui.autoRockName.Text=nameOf(selected)..(patch.auto and""or(ru and"  •  вручную"or"  •  manual"))end
  if ui.autoRockStats and ui.autoRockStats.Parent then
   if patch.auto then ui.autoRockStats.Text=d and((ru and"Долговечность: "or"Durability: ")..compact(d).."  •  "..nameOf(selected))or(ru and"Долговечность не найдена"or"Durability not found")
   elseif selected then ui.autoRockStats.Text=(ru and"Выбран вручную: "or"Manual: ")..nameOf(selected)..(d and("  •  "..compact(d))or"")end
  end
 end
 if type(q.refreshRockList)=="function"then pcall(q.refreshRockList)end
end

local selectAuto
selectAuto=function(force)
 if not patch.alive or not patch.auto then return false end
 local d=readDurability()
 q.adaptiveRockDurability=d
 if d==nil then paintDetails()return false end
 local rock=bestRock(d)if not rock then return false end
 local changed=force or not q.selectedRock or q.selectedRock.id~=rock.id
 patch.applying=true
 q.autoRockSelection=false
 q.selectedRock=rock
 q.adaptiveRockRequirement=rock.req
 q.adaptiveRockName=nameOf(rock)
 q.autoRockReason=(q.language=="en"and"Durability "or"Долговечность ")..compact(d).." • "..nameOf(rock)
 q.autoRockCalc={durability=d,requirement=rock.req,adaptive=true}
 patch.lastDurability=d
 patch.lastRock=rock.id
 patch.applying=false
 paintDetails()
 return changed
end

local function setAuto(on)
 patch.auto=on==true
 q.adaptiveRockAuto=patch.auto
 q.autoRockSelection=false
 if patch.auto then selectAuto(true)else paintDetails()end
end

local function bindDurability()
 local obj=findDurabilityObject()
 if obj==patch.durabilityObject and patch.durabilityConnection then return end
 if patch.durabilityConnection then pcall(function()patch.durabilityConnection:Disconnect()end)patch.durabilityConnection=nil end
 patch.durabilityObject=obj
 if obj then
  patch.durabilityConnection=obj:GetPropertyChangedSignal("Value"):Connect(function()
   if not patch.alive or not patch.auto then return end
   local v=parse(obj.Value)
   if v~=patch.lastDurability then selectAuto(false)end
  end)
 end
end

local bugRef=q.leverRefs and q.leverRefs.bug
local originalBugSet=bugRef and bugRef.Set or nil
if bugRef and type(originalBugSet)=="function"then
 bugRef.Set=function(v,silent)
  if v and patch.auto then bindDurability()selectAuto(false)end
  return originalBugSet(v,silent)
 end
end

local autoButton=q.layoutUI and q.layoutUI.autoRockButton
if autoButton then table.insert(patch.connections,autoButton.Activated:Connect(function()task.defer(function()if patch.alive then bindDurability()setAuto(true)end end)end))end

table.insert(patch.connections,player.ChildAdded:Connect(function(obj)
 if (obj.Name=="Durability"or obj.Name=="durability")and obj:IsA("ValueBase")then bindDurability()if patch.auto then selectAuto(false)end end
end))
table.insert(patch.connections,player.ChildRemoved:Connect(function(obj)
 if obj==patch.durabilityObject then bindDurability()if patch.auto then selectAuto(false)end end
end))
for _,key in ipairs({"Durability","durability"})do
 table.insert(patch.connections,player:GetAttributeChangedSignal(key):Connect(function()if patch.auto and not patch.durabilityObject then selectAuto(false)end end))
end

-- Manual picker/slider changes selectedRock in the base UI. Detect that and stop adaptive overwrite.
task.spawn(function()
 while patch.alive and q.alive do
  bindDurability()
  if patch.auto and not patch.applying and q.selectedRock and patch.lastRock and q.selectedRock.id~=patch.lastRock then
   patch.auto=false q.adaptiveRockAuto=false q.autoRockSelection=false paintDetails()
  end
  task.wait(0.25)
 end
end)

function patch.Destroy()
 if not patch.alive then return end
 patch.alive=false
 if patch.durabilityConnection then pcall(function()patch.durabilityConnection:Disconnect()end)patch.durabilityConnection=nil end
 for _,c in ipairs(patch.connections)do pcall(function()c:Disconnect()end)end
 if bugRef and originalBugSet and bugRef.Set~=originalBugSet then bugRef.Set=originalBugSet end
 if env.RockBugAdaptiveRocks==patch then env.RockBugAdaptiveRocks=nil end
end

table.insert(patch.connections,workspace.DescendantAdded:Connect(function(obj)
 if tostring(obj.Name)=="neededDurability"then
  task.defer(function()
   if patch.alive then
    refreshDiscoveredRocks(true)
    if patch.auto then selectAuto(true)end
   end
  end)
 end
end))
refreshDiscoveredRocks(true)
bindDurability()
setAuto(true)
return patch
