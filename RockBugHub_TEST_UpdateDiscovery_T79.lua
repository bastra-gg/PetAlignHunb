-- RockBugHub TEST T79: dynamic post-scan catalog repair for game updates.
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local runtime=env.RockBugRuntime
if type(runtime)~="table"then return end

if env.RockBugUpdateDiscovery and type(env.RockBugUpdateDiscovery.Destroy)=="function"then
 pcall(env.RockBugUpdateDiscovery.Destroy)
end

local state={alive=true,connections={},scheduled=false,originalRefresh=runtime.refreshMachineCatalog}
env.RockBugUpdateDiscovery=state
runtime.updateDiscovery=state

local KNOWN_ORDER={
 ["Tiny Island"]=1,["Starter Island"]=2,["Legend Beach"]=3,
 ["Frost Gym"]=4,["Mythical Gym"]=5,["Eternal Gym"]=6,["Legend Gym"]=7,
 ["Muscle King Gym"]=8,["Jungle Gym"]=9,["Industrial Gym"]=10,
}
local GENERIC={
 ["workspace"]=true,["machinesfolder"]=true,["machines"]=true,["machine"]=true,
 ["model"]=true,["folder"]=true,["interactseat"]=true,
}
local ATTRS={"Zone","zone","Gym","gym","Location","location","Area","area","World","world","Island","island"}

local function trim(s)
 return tostring(s or""):gsub("^%s+",""):gsub("%s+$","")
end

local function usefulName(name)
 name=trim(name)
 if name==""then return false end
 local low=name:lower():gsub("[%s_%-]","")
 if GENERIC[low]then return false end
 if low:find("bench",1,true)or low:find("squat",1,true)or low:find("barlift",1,true)
  or low:find("deadlift",1,true)or low:find("pullup",1,true)or low:find("treadmill",1,true)
  or low:find("boulder",1,true)then return false end
 return true
end

local function attributeZone(obj)
 local p=obj
 for _=1,7 do
  if not p or p==workspace then break end
  for _,key in ipairs(ATTRS)do
   local ok,v=pcall(function()return p:GetAttribute(key)end)
   if ok and type(v)=="string"and usefulName(v)then return trim(v)end
  end
  p=p.Parent
 end
 return nil
end

local function ancestryZone(machine)
 local fromAttr=attributeZone(machine.model or machine.identity or machine.seat)
 if fromAttr then return fromAttr end
 local p=machine.model or machine.identity or machine.seat
 local fallback=nil
 for _=1,9 do
  if not p or p==workspace then break end
  local name=trim(p.Name)
  local low=name:lower()
  if usefulName(name)then
   if low:find("gym",1,true)or low:find("island",1,true)or low:find("zone",1,true)
    or low:find("world",1,true)or low:find("area",1,true)or low:find("factory",1,true)
    or low:find("industrial",1,true)or low:find("jungle",1,true)or low:find("temple",1,true)
    or low:find("space",1,true)or low:find("cyber",1,true)or low:find("void",1,true)
    or low:find("galaxy",1,true)or low:find("cosmic",1,true)or low:find("lava",1,true)then
     return name
   end
   fallback=fallback or name
  end
  p=p.Parent
 end
 return fallback
end

local function machinePosition(machine)
 local part=machine and(machine.seat or machine.model)
 if not part then return nil end
 if part:IsA("BasePart")then return part.Position end
 local ok,p=pcall(function()
  local cf=part:GetPivot()
  return cf.Position
 end)
 return ok and p or nil
end

local function rebuildZones()
 local catalog=runtime.machineCatalog or{}
 if #catalog==0 then return end

 local maxOrder=10
 for _,m in ipairs(catalog)do
  local o=tonumber(m.zoneOrder)
  if o and o<900 and o>maxOrder then maxOrder=o end
 end

 local dynamicOrder={}
 for _,m in ipairs(catalog)do
  local zone=tostring(m.zone or"")
  if zone==""or zone=="Other"then
   local inferred=ancestryZone(m)
   if not inferred or inferred=="Other"then inferred="New Gym"end
   m.zone=inferred
   if not dynamicOrder[inferred]then
    maxOrder=maxOrder+1
    dynamicOrder[inferred]=maxOrder
   end
   m.zoneOrder=dynamicOrder[inferred]
  elseif not tonumber(m.zoneOrder)then
   m.zoneOrder=KNOWN_ORDER[zone]or 100
  end
 end

 local zones,byName={},{}
 for _,m in ipairs(catalog)do
  local zone=tostring(m.zone or"Other")
  local row=byName[zone]
  if not row then
   row={id=zone,label=zone,order=tonumber(m.zoneOrder)or 100,count=0}
   byName[zone]=row
   table.insert(zones,row)
  end
  row.count=row.count+1
  row.order=math.min(row.order,tonumber(m.zoneOrder)or row.order)
 end
 table.sort(zones,function(a,b)
  if a.order~=b.order then return a.order<b.order end
  return a.id<b.id
 end)
 runtime.machineZones=zones

 local destinations=runtime.teleportDestinations or{}
 runtime.teleportDestinations=destinations
 local have={}
 for _,d in ipairs(destinations)do have[tostring(d.id or"")]=true end
 for _,z in ipairs(zones)do
  if not have[z.id]then
   local pos=nil
   for _,m in ipairs(catalog)do
    if m.zone==z.id then pos=machinePosition(m)if pos then break end end
   end
   if pos then
    table.insert(destinations,{id=z.id,position={pos.X,pos.Y+3,pos.Z},dynamic=true})
    have[z.id]=true
   end
  end
 end

 local adaptive=env.RockBugAdaptiveMachines
 if type(adaptive)=="table"then adaptive.catalogCount=-1 end
 runtime.machineCatalogUpdateVersion="T79"
 if type(runtime.refreshMachineUI)=="function"then pcall(runtime.refreshMachineUI)end
 if type(runtime.refreshTeleportUI)=="function"then pcall(runtime.refreshTeleportUI)end
end

local function normalizeAfterScan()
 if state.scheduled or not state.alive then return end
 state.scheduled=true
 task.spawn(function()
  local deadline=os.clock()+12
  while state.alive and runtime.alive and runtime.machineScanInFlight and os.clock()<deadline do task.wait(0.08)end
  if state.alive and runtime.alive then pcall(rebuildZones)end
  state.scheduled=false
 end)
end

if type(state.originalRefresh)=="function"then
 runtime.refreshMachineCatalog=function(force)
  local result=state.originalRefresh(force)
  normalizeAfterScan()
  return result
 end
end

local rescanToken=0
local function requestRescan()
 rescanToken=rescanToken+1
 local token=rescanToken
 task.delay(0.35,function()
  if token~=rescanToken or not state.alive or not runtime.alive then return end
  if type(runtime.refreshMachineCatalog)=="function"then pcall(runtime.refreshMachineCatalog,true)end
 end)
end

table.insert(state.connections,workspace.DescendantAdded:Connect(function(obj)
 local n=tostring(obj.Name or""):lower()
 if n=="interactseat"or n=="neededstrength"or n=="requiredstrength"or n=="strengthrequired"or n=="strengthrequirement"then
  requestRescan()
 end
end))

pcall(rebuildZones)
if type(runtime.refreshMachineCatalog)=="function"then pcall(runtime.refreshMachineCatalog,true)end
normalizeAfterScan()

function state.Destroy()
 if not state.alive then return end
 state.alive=false
 rescanToken=rescanToken+1
 for _,c in ipairs(state.connections)do pcall(function()c:Disconnect()end)end
 state.connections={}
 if type(state.originalRefresh)=="function"then runtime.refreshMachineCatalog=state.originalRefresh end
 if env.RockBugUpdateDiscovery==state then env.RockBugUpdateDiscovery=nil end
 if runtime.updateDiscovery==state then runtime.updateDiscovery=nil end
end

return state
