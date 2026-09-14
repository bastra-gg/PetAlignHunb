-- RockBugHub TEST T50: robust durability-adaptive rocks + manual selection
local Players=game:GetService("Players")
local player=Players.LocalPlayer
if not player then return end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local q=env.RockBugRuntime
if type(q)~="table"then return end
if env.RockBugAdaptiveRocks and type(env.RockBugAdaptiveRocks.Destroy)=="function"then pcall(env.RockBugAdaptiveRocks.Destroy)end

local patch={alive=true,auto=true,lastDurability=nil,lastRock=nil,applying=false,connections={},sourceConnections={},sources={}}
env.RockBugAdaptiveRocks=patch
q.adaptiveRocks=true

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
 if n:find(",",1,true)and not n:find("%.")then local a,b=n:match("^(%-?%d+),(%d+)$");if a and b and #b<=2 then n=a.."."..b else n=n:gsub(",","")end else n=n:gsub(",","")end
 local x=tonumber(n)if not x then return nil end
 return x*(({k=1e3,m=1e6,b=1e9,t=1e12,q=1e15})[suf]or 1)
end
local function badName(n)
 n=string.lower(tostring(n or""))
 for _,w in ipairs({"mult","boost","gain","percent","required","needed","cost","price","bonus","rate"})do if n:find(w,1,true)then return true end end
 return false
end
local function nameScore(n)
 n=string.lower(tostring(n or""))
 if badName(n)then return nil end
 if n=="durability"then return 1200 end
 if n:find("durability",1,true)then return 950 end
 if n=="endurance"then return 700 end
 if n:find("endurance",1,true)then return 620 end
 if n:find("долговеч",1,true)or n:find("прочност",1,true)or n:find("вынослив",1,true)then return 600 end
 return nil
end

local function disconnectSources()
 for _,c in ipairs(patch.sourceConnections)do pcall(function()c:Disconnect()end)end
 patch.sourceConnections={}
end

local selectAuto
local function sourceChanged()
 if patch.alive and patch.auto and selectAuto then task.defer(function()if patch.alive and patch.auto then selectAuto(false)end end)end
end

local function addValueSource(obj)
 if not obj or not obj:IsA("ValueBase")then return end
 local s=nameScore(obj.Name)if not s then return end
 table.insert(patch.sources,{kind="value",obj=obj,score=s,name=tostring(obj.Name)})
 table.insert(patch.sourceConnections,obj:GetPropertyChangedSignal("Value"):Connect(sourceChanged))
end
local function addAttributeSources(obj)
 local ok,attrs=pcall(function()return obj:GetAttributes()end)if not ok or type(attrs)~="table"then return end
 for key in pairs(attrs)do
  local s=nameScore(key)
  if s then
   table.insert(patch.sources,{kind="attr",obj=obj,key=key,score=s+25,name=tostring(key)})
   table.insert(patch.sourceConnections,obj:GetAttributeChangedSignal(key):Connect(sourceChanged))
  end
 end
end
local function rebuildSources()
 disconnectSources()patch.sources={}
 addAttributeSources(player)
 for _,obj in ipairs(player:GetDescendants())do addValueSource(obj)addAttributeSources(obj)end
 q.adaptiveRockSourceCount=#patch.sources
end
local function sourceValue(src)
 if not src or not src.obj or not src.obj.Parent and src.obj~=player then return nil end
 local ok,v
 if src.kind=="value"then ok,v=pcall(function()return parse(src.obj.Value)end)else ok,v=pcall(function()return parse(src.obj:GetAttribute(src.key))end)end
 if ok and v and v>=0 then return v end
 return nil
end
local function readDurability()
 if #patch.sources==0 then rebuildSources()end
 local topScore=-math.huge
 for _,src in ipairs(patch.sources)do local v=sourceValue(src)if v~=nil and src.score>topScore then topScore=src.score end end
 if topScore==-math.huge then return nil,nil end
 -- Several copies of Durability can exist. The old patch preferred one stale copy
 -- (the one that sat at 600). Among equally trustworthy sources use the largest
 -- replicated value, which tracks the real player stat instead of the stale mirror.
 local bestValue,bestSource=nil,nil
 for _,src in ipairs(patch.sources)do
  if src.score>=topScore-50 then
   local v=sourceValue(src)
   if v~=nil and (bestValue==nil or v>bestValue)then bestValue,bestSource=v,src end
  end
 end
 if bestValue==nil then
  for _,src in ipairs(patch.sources)do local v=sourceValue(src)if v~=nil and (bestValue==nil or src.score>(bestSource and bestSource.score or -math.huge))then bestValue,bestSource=v,src end end
 end
 if bestSource then q.adaptiveRockSource=(bestSource.kind=="attr"and("attr:"..bestSource.name)or bestSource.obj:GetFullName())end
 return bestValue,bestSource
end
local function bestRock(v)
 if v==nil then return nil end
 for _,r in ipairs(rocks)do if v>=r.req then return r end end
 return rocks[#rocks]
end
local function nameOf(r)
 if not r then return "—"end
 if q.layoutUI and type(q.layoutUI.rockName)=="function"then local ok,n=pcall(q.layoutUI.rockName,r);if ok and type(n)=="string"and n~=""then return n end end
 return q.language=="en"and r.en or r.label
end

-- Detailed rock page only. Farm card text is owned by the stable-card patch so
-- T38's 0.5s HUD refresh cannot fight this patch and flash different captions.
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

selectAuto=function(force)
 if not patch.alive or not patch.auto then return false end
 local d=readDurability()q.adaptiveRockDurability=d
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
 patch.lastDurability=d patch.lastRock=rock.id
 patch.applying=false
 paintDetails()
 return changed
end
local function setAuto(on)
 patch.auto=on==true q.autoRockSelection=false q.adaptiveRockAuto=patch.auto
 if patch.auto then selectAuto(true)else paintDetails()end
end

local bugRef=q.leverRefs and q.leverRefs.bug local originalBugSet=bugRef and bugRef.Set or nil
if bugRef and type(originalBugSet)=="function"then bugRef.Set=function(v,silent)if v and patch.auto then selectAuto(false)end return originalBugSet(v,silent)end end
local autoButton=q.layoutUI and q.layoutUI.autoRockButton
if autoButton then table.insert(patch.connections,autoButton.Activated:Connect(function()task.defer(function()if patch.alive then setAuto(true)end end)end))end

table.insert(patch.connections,player.DescendantAdded:Connect(function(obj)
 if nameScore(obj.Name)or next(obj:GetAttributes())~=nil then rebuildSources()if patch.auto then selectAuto(false)end end
end))
table.insert(patch.connections,player.DescendantRemoving:Connect(function(obj)
 for _,src in ipairs(patch.sources)do if src.obj==obj then rebuildSources()if patch.auto then selectAuto(false)end break end end
end))

-- Manual picker/slider changes selectedRock in the base UI. Detect that and stop adaptive overwrite.
task.spawn(function()
 local nextVerify=0
 while patch.alive and q.alive do
  if patch.auto and not patch.applying and q.selectedRock and patch.lastRock and q.selectedRock.id~=patch.lastRock then patch.auto=false q.adaptiveRockAuto=false q.autoRockSelection=false paintDetails()end
  if os.clock()>=nextVerify then
   nextVerify=os.clock()+0.5
   if patch.auto then
    local d=readDurability()
    if d~=patch.lastDurability then selectAuto(false)end
   end
  end
  task.wait(0.20)
 end
end)

function patch.Destroy()
 if not patch.alive then return end patch.alive=false disconnectSources()
 for _,c in ipairs(patch.connections)do pcall(function()c:Disconnect()end)end
 if bugRef and originalBugSet and bugRef.Set~=originalBugSet then bugRef.Set=originalBugSet end
 if env.RockBugAdaptiveRocks==patch then env.RockBugAdaptiveRocks=nil end
end

rebuildSources()setAuto(true)
return patch
