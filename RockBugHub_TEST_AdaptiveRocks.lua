-- RockBugHub TEST T46: event-driven durability rocks + restored manual selection
local Players=game:GetService("Players")
local player=Players.LocalPlayer
if not player then return end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local q=env.RockBugRuntime
if type(q)~="table"then return end
if env.RockBugAdaptiveRocks and type(env.RockBugAdaptiveRocks.Destroy)=="function"then pcall(env.RockBugAdaptiveRocks.Destroy)end

local patch={alive=true,auto=true,lastDurability=nil,lastRock=nil,applying=false,connections={},sourceConnection=nil}
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
local function score(obj)
 if not obj or not obj:IsA("ValueBase")then return nil end
 local n=string.lower(tostring(obj.Name or""))local s=0
 if n=="durability"then s=1000 elseif n:find("durability",1,true)then s=900 elseif n=="endurance"or n:find("endurance",1,true)then s=620 elseif n:find("долговеч",1,true)or n:find("прочност",1,true)or n:find("вынослив",1,true)then s=600 else return nil end
 if n:find("mult",1,true)or n:find("boost",1,true)or n:find("gain",1,true)or n:find("percent",1,true)or n:find("required",1,true)or n:find("needed",1,true)then s-=900 end
 local ls=player:FindFirstChild("leaderstats")if ls and obj:IsDescendantOf(ls)then s+=180 end
 return s
end

local source=nil
local function findSource()
 if source and source.Parent then return source end
 local best,bestScore=nil,-math.huge
 for _,obj in ipairs(player:GetDescendants())do
  local s=score(obj)
  if s and s>bestScore then local ok,v=pcall(function()return parse(obj.Value)end);if ok and v and v>=0 then best,bestScore=obj,s end end
 end
 source=best return source
end
local function readDurability()
 local obj=findSource()
 if obj then local ok,v=pcall(function()return parse(obj.Value)end);if ok and v and v>=0 then return v,obj end end
 for _,key in ipairs({"Durability","durability"})do local ok,v=pcall(function()return parse(player:GetAttribute(key))end);if ok and v and v>=0 then return v,nil end end
 return nil,nil
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

local function paint()
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
 local holo=q.hologram
 if type(holo)=="table"and not holo.destroyed and holo.group=="farm"then
  local card=type(holo.cards)=="table"and holo.cards[1]or nil
  if card then
   if card.primary and card.primary.text then card.primary.text.Text=ru and"Автоудар"or"Auto punch"end
   if card.more and card.more.text then card.more.text.Text=(patch.auto and(ru and"Лучший: "or"Best: ")or(ru and"Вручную: "or"Manual: "))..nameOf(selected).."  →"end
   if card.hint then card.hint.Text=d and((ru and"Долговечность: "or"Durability: ")..compact(d).."  •  "..nameOf(selected))or(ru and"Долговечность не найдена"or"Durability not found")end
  end
 end
end

local function selectAuto(force)
 if not patch.alive or not patch.auto then return false end
 local d=readDurability()q.adaptiveRockDurability=d
 if d==nil then paint()return false end
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
 paint()
 return changed
end
local function setAuto(on)
 patch.auto=on==true q.autoRockSelection=false
 if patch.auto then selectAuto(true)else paint()end
end

local function unbindSource()if patch.sourceConnection then pcall(function()patch.sourceConnection:Disconnect()end)patch.sourceConnection=nil end end
local function bindSource()
 unbindSource()local obj=findSource()if not obj then return end
 patch.sourceConnection=obj:GetPropertyChangedSignal("Value"):Connect(function()
  if not patch.alive then return end
  local v=parse(obj.Value)
  if patch.auto and v~=patch.lastDurability then selectAuto(false)end
 end)
end

local bugRef=q.leverRefs and q.leverRefs.bug local originalBugSet=bugRef and bugRef.Set or nil
if bugRef and type(originalBugSet)=="function"then bugRef.Set=function(v,silent)if v and patch.auto then selectAuto(false)end return originalBugSet(v,silent)end end

local autoButton=q.layoutUI and q.layoutUI.autoRockButton
if autoButton then table.insert(patch.connections,autoButton.Activated:Connect(function()task.defer(function()if patch.alive then setAuto(true)end end)end))end
for _,key in ipairs({"Durability","durability"})do table.insert(patch.connections,player:GetAttributeChangedSignal(key):Connect(function()if patch.auto then selectAuto(false)end end))end
table.insert(patch.connections,player.DescendantAdded:Connect(function(obj)if score(obj)then source=nil bindSource()if patch.auto then selectAuto(false)end end end))
table.insert(patch.connections,player.DescendantRemoving:Connect(function(obj)if obj==source then source=nil unbindSource()end end))

-- Manual picker/slider changes selectedRock in the base UI. Detect that and stop adaptive overwrite.
task.spawn(function()
 local nextPaint=0
 while patch.alive and q.alive do
  if patch.auto and not patch.applying and q.selectedRock and patch.lastRock and q.selectedRock.id~=patch.lastRock then patch.auto=false q.autoRockSelection=false paint()end
  if not source or not source.Parent then source=nil bindSource()if patch.auto then selectAuto(false)end end
  if os.clock()>=nextPaint then nextPaint=os.clock()+0.6 paint()end
  task.wait(0.25)
 end
end)

function patch.Destroy()
 if not patch.alive then return end patch.alive=false unbindSource()
 for _,c in ipairs(patch.connections)do pcall(function()c:Disconnect()end)end
 if bugRef and originalBugSet and bugRef.Set~=originalBugSet then bugRef.Set=originalBugSet end
 if env.RockBugAdaptiveRocks==patch then env.RockBugAdaptiveRocks=nil end
end

bindSource()setAuto(true)
return patch
