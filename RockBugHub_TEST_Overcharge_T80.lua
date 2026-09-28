-- RockBugHub TEST T80: explicit support for the September 2026 Overcharge update.
-- No guessed rebirth/strength/durability numbers: live game objects stay authoritative.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
if not player then return end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local runtime=env.RockBugRuntime
if type(runtime)~="table"then return end

if env.RockBugOverchargeT80 and type(env.RockBugOverchargeT80.Destroy)=="function"then
 pcall(env.RockBugOverchargeT80.Destroy)
end

local state={
 alive=true,
 connections={},
 originalRefresh=runtime.refreshMachineCatalog,
 scheduled=false,
 detectedMachines=0,
 detectedCrystals={},
 lastScanAt=0,
}
env.RockBugOverchargeT80=state
runtime.overchargeT80=state

local ZONE="Overcharge Gym"
local ORDER=11
local aliases={"overcharge","overcharged","overchargegym","overchargedgym"}
local metadata={"Zone","zone","Gym","gym","Location","location","Area","area","World","world","Island","island","DisplayName","displayName","Name","name"}

local function lower(v)return string.lower(tostring(v or""))end
local function contains(v)return lower(v):find("overcharg",1,true)~=nil end

local function objectMentions(obj)
 local p=obj
 for _=1,10 do
  if not p then break end
  if contains(p.Name)then return true,tostring(p.Name)end
  for _,key in ipairs(metadata)do
   local ok,v=pcall(function()return p:GetAttribute(key)end)
   if ok and type(v)=="string"and contains(v)then return true,v end
  end
  if p==workspace or p==ReplicatedStorage then break end
  p=p.Parent
 end
 return false,nil
end

local function partPosition(obj)
 if not obj then return nil end
 if obj:IsA("BasePart")then return obj.Position end
 local ok,pos=pcall(function()return obj:GetPivot().Position end)
 if ok then return pos end
 local part=obj:FindFirstChildWhichIsA("BasePart",true)
 return part and part.Position or nil
end

local function nearestWorldPart(obj)
 local p=obj
 for _=1,8 do
  if not p then break end
  if p:IsA("BasePart")then return p end
  if p:IsA("Model")then
   local pos=partPosition(p)
   if pos then return p end
  end
  if p==workspace then break end
  p=p.Parent
 end
 return nil
end

local function textMentions(obj)
 if not obj then return false end
 if obj:IsA("TextLabel")or obj:IsA("TextButton")or obj:IsA("TextBox")then
  local ok,t=pcall(function()return tostring(obj.Text or"").." "..tostring(obj.ContentText or"")end)
  return ok and contains(t)
 end
 return false
end

local function collectAnchors()
 local anchors={}
 local seen={}
 local ok,all=pcall(function()return workspace:GetDescendants()end)
 if not ok or type(all)~="table"then return anchors end
 for i,obj in ipairs(all)do
  local hit=contains(obj.Name)or textMentions(obj)
  if not hit then
   for _,key in ipairs(metadata)do
    local good,v=pcall(function()return obj:GetAttribute(key)end)
    if good and type(v)=="string"and contains(v)then hit=true break end
   end
  end
  if hit then
   local holder=nearestWorldPart(obj)
   local pos=holder and partPosition(holder)or nil
   if pos then
    local key=math.floor(pos.X/20)..":"..math.floor(pos.Z/20)
    if not seen[key]then
     seen[key]=true
     table.insert(anchors,pos)
    end
   end
  end
  if i%1800==0 then task.wait()end
 end
 return anchors
end

local function nearAnchor(machine,anchors)
 local pos=partPosition(machine and(machine.seat or machine.model))
 if not pos then return false end
 local best=math.huge
 for _,a in ipairs(anchors)do
  local dx,dz=pos.X-a.X,pos.Z-a.Z
  local d=math.sqrt(dx*dx+dz*dz)
  if d<best then best=d end
 end
 return best<=1250
end

local function addUnique(list,value)
 for _,v in ipairs(list)do if tostring(v)==value then return false end end
 table.insert(list,value)
 return true
end

local function discoverOverchargeCrystals()
 local found={}
 for _,root in ipairs({workspace,ReplicatedStorage})do
  local ok,all=pcall(function()return root:GetDescendants()end)
  if ok and type(all)=="table"then
   for i,obj in ipairs(all)do
    local name=tostring(obj.Name or"")
    local low=lower(name)
    if low:find("overcharg",1,true)and(low:find("crystal",1,true)or low:find("egg",1,true))then
     found[name]=true
    end
    if i%1800==0 then task.wait()end
   end
  end
 end
 state.detectedCrystals=found
 runtime.crystalDefaults=runtime.crystalDefaults or{}
 local changed=false
 for name in pairs(found)do if addUnique(runtime.crystalDefaults,name)then changed=true end end
 if changed then
  runtime.crystalCatalogAt=nil
  runtime.shopCatalogCache={}
 end
end

local function rebuildMachineZones()
 local catalog=runtime.machineCatalog or{}
 local detected=0
 local anchor=nil
 local anchors=collectAnchors()
 state.anchorCount=#anchors
 for _,machine in ipairs(catalog)do
  local hit,label=objectMentions(machine.model or machine.identity or machine.seat)
  -- Some builds name only the gym sign/portal, while machine models keep generic
  -- names. In that case spatially bind nearby machines to the Overcharge marker.
  if not hit and #anchors>0 and nearAnchor(machine,anchors)then
   hit=true
   label="near Overcharge marker"
  end
  if hit then
   machine.zone=ZONE
   machine.zoneOrder=ORDER
   machine.updateDetectedLabel=label
   detected+=1
   anchor=anchor or partPosition(machine.seat or machine.model)
  end
 end
 if not anchor and anchors[1]then anchor=anchors[1]end
 state.detectedMachines=detected
 runtime.overchargeGymDetected=detected>0
 runtime.overchargeMachineCount=detected

 if detected<1 then return end

 local zones={}
 local by={}
 for _,machine in ipairs(catalog)do
  local id=tostring(machine.zone or"Other")
  local z=by[id]
  if not z then
   z={id=id,label=id,order=tonumber(machine.zoneOrder)or 99,count=0}
   by[id]=z
   table.insert(zones,z)
  end
  z.count+=1
  local mo=tonumber(machine.zoneOrder)
  if mo and mo<z.order then z.order=mo end
 end
 table.sort(zones,function(a,b)
  if a.order~=b.order then return a.order<b.order end
  return a.id<b.id
 end)
 runtime.machineZones=zones
 runtime.machineCatalogUpdateVersion="T80-Overcharge"

 local destinations=runtime.teleportDestinations or{}
 runtime.teleportDestinations=destinations
 local dest=nil
 for _,d in ipairs(destinations)do
  if contains(d.id)then dest=d break end
 end
 if not dest then
  dest={id=ZONE,aliases=aliases,dynamic=true}
  table.insert(destinations,dest)
 end
 dest.id=ZONE
 dest.aliases=aliases
 dest.dynamic=true
 if anchor then dest.position={anchor.X,anchor.Y+3,anchor.Z}end

 -- Force adaptive module to rebuild its candidate list after zone correction.
 local adaptive=env.RockBugAdaptiveMachines
 if type(adaptive)=="table"then adaptive.catalogCount=-1 end

 if runtime.machineZone and contains(runtime.machineZone)then runtime.machineZone=ZONE end
 if runtime.selectedTeleport and contains(runtime.selectedTeleport)then runtime.selectedTeleport=ZONE end
 if type(runtime.refreshMachineUI)=="function"then pcall(runtime.refreshMachineUI)end
 if type(runtime.refreshTeleportUI)=="function"then pcall(runtime.refreshTeleportUI)end
end

local function normalize()
 if not state.alive then return end
 state.lastScanAt=os.clock()
 pcall(rebuildMachineZones)
 pcall(discoverOverchargeCrystals)
end

local function afterCatalog()
 if state.scheduled or not state.alive then return end
 state.scheduled=true
 task.spawn(function()
  local deadline=os.clock()+15
  while state.alive and runtime.alive and runtime.machineScanInFlight and os.clock()<deadline do task.wait(0.08)end
  if state.alive and runtime.alive then normalize()end
  state.scheduled=false
 end)
end

if type(state.originalRefresh)=="function"then
 runtime.refreshMachineCatalog=function(force)
  local result=state.originalRefresh(force)
  afterCatalog()
  return result
 end
end

local debounce=0
local function scheduleRescan()
 debounce+=1
 local token=debounce
 task.delay(0.6,function()
  if token~=debounce or not state.alive or not runtime.alive then return end
  if type(runtime.refreshMachineCatalog)=="function"then pcall(runtime.refreshMachineCatalog,true)end
  afterCatalog()
 end)
end

table.insert(state.connections,workspace.DescendantAdded:Connect(function(obj)
 if contains(obj.Name)or lower(obj.Name)=="interactseat"or lower(obj.Name)=="neededdurability"then
  scheduleRescan()
 end
end))
table.insert(state.connections,ReplicatedStorage.DescendantAdded:Connect(function(obj)
 if contains(obj.Name)then scheduleRescan()end
end))

-- The first scan runs after the pinned core has created its normal catalog.
task.spawn(function()
 task.wait(0.15)
 if not state.alive or not runtime.alive then return end
 if type(runtime.refreshMachineCatalog)=="function"then pcall(runtime.refreshMachineCatalog,true)end
 afterCatalog()
end)

function state.Destroy()
 if not state.alive then return end
 state.alive=false
 debounce+=1
 for _,c in ipairs(state.connections)do pcall(function()c:Disconnect()end)end
 state.connections={}
 if type(state.originalRefresh)=="function"and runtime.refreshMachineCatalog~=state.originalRefresh then
  runtime.refreshMachineCatalog=state.originalRefresh
 end
 if env.RockBugOverchargeT80==state then env.RockBugOverchargeT80=nil end
 if runtime.overchargeT80==state then runtime.overchargeT80=nil end
end

return state
