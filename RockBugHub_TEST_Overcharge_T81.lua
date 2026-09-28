-- RockBugHub TEST T81: explicit support for the September 2026 Overcharge update.
-- No guessed rebirth/strength/durability numbers: live game objects stay authoritative.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
if not player then return end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local runtime=env.RockBugRuntime
if type(runtime)~="table"then return end

if env.RockBugOverchargeT81 and type(env.RockBugOverchargeT81.Destroy)=="function"then
 pcall(env.RockBugOverchargeT81.Destroy)
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
env.RockBugOverchargeT81=state
runtime.overchargeT81=state

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
 -- T81: UI/sign text is not a trustworthy spatial anchor. The game may clone
 -- destination labels all over the map, which used to drag foreign machines
 -- into Overcharge.
 return false
end

local KNOWN_GYM_POSITIONS={
 Vector3.new(-3000,35,-400),
 Vector3.new(2400,20,1050),
 Vector3.new(-7176,45,-1106),
 Vector3.new(4200,1000,-4000),
 Vector3.new(-8700,35,-5850),
 Vector3.new(-8500,35,2400),
}

local function distXZ(a,b)
 local dx,dz=a.X-b.X,a.Z-b.Z
 return math.sqrt(dx*dx+dz*dz)
end

local function farFromKnownGyms(pos)
 local best=math.huge
 for _,known in ipairs(KNOWN_GYM_POSITIONS)do
  local d=distXZ(pos,known)
  if d<best then best=d end
 end
 return best>900
end

local function collectAnchors()
 local raw={}
 local ok,all=pcall(function()return workspace:GetDescendants()end)
 if not ok or type(all)~="table"then return raw end

 for i,obj in ipairs(all)do
  local hit=contains(obj.Name)
  if not hit then
   for _,key in ipairs(metadata)do
    local good,v=pcall(function()return obj:GetAttribute(key)end)
    if good and type(v)=="string"and contains(v)then hit=true break end
   end
  end
  if hit then
   local holder=nearestWorldPart(obj)
   local pos=holder and partPosition(holder)or nil
   -- Ignore cloned portal/sign markers that sit inside an existing old gym.
   if pos and farFromKnownGyms(pos)then table.insert(raw,pos)end
  end
  if i%1800==0 then task.wait()end
 end

 -- Collapse duplicate marker copies into physical clusters.
 local clusters={}
 for _,pos in ipairs(raw)do
  local target=nil
  for _,cluster in ipairs(clusters)do
   if distXZ(pos,cluster.center)<=220 then target=cluster break end
  end
  if target then
   target.count+=1
   target.center=Vector3.new(
    (target.center.X*(target.count-1)+pos.X)/target.count,
    (target.center.Y*(target.count-1)+pos.Y)/target.count,
    (target.center.Z*(target.count-1)+pos.Z)/target.count
   )
  else
   table.insert(clusters,{center=pos,count=1})
  end
 end

 table.sort(clusters,function(a,b)return a.count>b.count end)
 local anchors={}
 if clusters[1]then
  -- One physical Overcharge area only. Never treat every duplicated label as a gym.
  anchors[1]=clusters[1].center
 end
 return anchors
end

local function nearAnchor(machine,anchors)
 local anchor=anchors and anchors[1]
 if not anchor then return false end
 local pos=partPosition(machine and(machine.seat or machine.model))
 if not pos then return false end
 -- Tight cluster: enough for one gym, not enough to swallow neighboring worlds.
 return distXZ(pos,anchor)<=420
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
  -- Some builds name only the gym root/portal, while machine models stay generic.
  -- T81 binds only the single tight physical Overcharge cluster.
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
 runtime.machineCatalogUpdateVersion="T81-Overcharge"

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
 if env.RockBugOverchargeT81==state then env.RockBugOverchargeT81=nil end
 if runtime.overchargeT81==state then runtime.overchargeT81=nil end
end

return state
