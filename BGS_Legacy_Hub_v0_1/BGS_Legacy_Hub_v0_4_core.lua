-- BGS Legacy Hub 0.4.0
-- Sorted bottom->top islands/eggs, color-coded picker borders, corrected egg discovery,
-- and pickup traversal that walks THROUGH hitboxes instead of stopping beside them.

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")

if not game:IsLoaded() then game.Loaded:Wait() end
local player=Players.LocalPlayer
while not player do task.wait() player=Players.LocalPlayer end
local playerGui=player:WaitForChild("PlayerGui",60)
if not playerGui then warn("BGS: PlayerGui недоступен") return end

local env=_G
if type(getgenv)=="function" then
    local ok,value=pcall(getgenv)
    if ok and type(value)=="table" then env=value end
end
if env.BGSLegacy and type(env.BGSLegacy.Stop)=="function" then
    pcall(function() env.BGSLegacy:Stop("reload") end)
end

local conns,gui={},nil
local function connect(signal,fn)
    local c=signal:Connect(fn)
    conns[#conns+1]=c
    return c
end
local function root()
    local c=player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function humanoid()
    local c=player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function ready()
    local h=humanoid()
    return root()~=nil and h~=nil and h.Health>0
end
local function stopMove()
    local h,r=humanoid(),root()
    if h and r then pcall(function() h:MoveTo(r.Position) h:Move(Vector3.zero,false) end) end
end

-- Light request budget. This is only a stability guard.
local network,nextNetwork=nil,0
local remoteTimes={}
local MAX_REMOTE_PER_SEC=8
local function budgetOK(now)
    local fresh={}
    for _,t in ipairs(remoteTimes) do if now-t<1 then fresh[#fresh+1]=t end end
    remoteTimes=fresh
    return #remoteTimes<MAX_REMOTE_PER_SEC
end
local function send(action,...)
    local now=os.clock()
    if not budgetOK(now) then return false,"SAFE: лимит запросов" end
    if not network or not network.Parent then
        if now<nextNetwork then return false,"NetworkRemoteEvent не найден" end
        nextNetwork=now+2
        local candidate=RS:FindFirstChild("NetworkRemoteEvent",true)
        network=candidate and candidate:IsA("RemoteEvent") and candidate or nil
    end
    if not network then return false,"NetworkRemoteEvent не найден" end
    local args={...}
    remoteTimes[#remoteTimes+1]=now
    local ok,problem=pcall(function() network:FireServer(action,table.unpack(args)) end)
    return ok,problem
end

local function partOf(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Attachment") then return object.Parent and object.Parent:IsA("BasePart") and object.Parent or nil end
    if object:IsA("Model") and object.PrimaryPart then return object.PrimaryPart end
    return object:FindFirstChildWhichIsA("BasePart",true)
end
local function meta(object,keys)
    if not object then return nil end
    for _,key in ipairs(keys) do
        local value=object:GetAttribute(key)
        if value==nil then
            local node=object:FindFirstChild(key)
            if node and node:IsA("ValueBase") then value=node.Value end
        end
        if type(value)=="string" or type(value)=="number" then return value end
    end
end
local function normalize(s)
    return tostring(s or ""):lower():gsub("[%s%p_]","")
end

local currencyNames={coins="Coins",coin="Coins",gems="Gems",gem="Gems",candy="Candy",blocks="Blocks",shells="Shells",pearls="Pearls",stars="Stars",magma="Magma",crystals="Crystals"}
local function currencyOf(object,container)
    local current=object
    while current and current~=container do
        local value=meta(current,{"Currency","CurrencyType","PickupType"})
        if value then return tostring(value) end
        local low=current.Name:lower()
        for key,currency in pairs(currencyNames) do if low:find(key,1,true) then return currency end end
        current=current.Parent
    end
    return "Другое"
end
local function isGemCurrency(value)
    local s=tostring(value or ""):lower()
    return s:find("gem",1,true)~=nil or s:find("crystal",1,true)~=nil
end

-- Worlds stay grouped; inside each world everything is sorted by actual vertical position.
local WORLD_ORDER={
    ["Overworld"]=1,["Candy Land"]=2,["Toy Land"]=3,["Beach World"]=4,
    ["Atlantis"]=5,["Rainbow Land"]=6,["Underworld"]=7,["Mystic Forest"]=8,["Карта"]=99,["Текущий мир"]=99
}
local function worldRank(world) return WORLD_ORDER[tostring(world)] or 50 end

-- Canonical OG island order / classification. Actual Y is still used whenever available.
local knownIslands={
    {"Starter Area","Overworld",0,"normal"},{"The Floating Island","Overworld",85,"normal"},
    {"Space","Overworld",518,"gem"},{"The Twilight","Overworld",1134,"gem"},
    {"The Skylands","Overworld",2105,"gem"},{"The Void","Overworld",3208,"gem"},
    {"Zen","Overworld",4065,"gem"},{"XP Island","Overworld",999999,"gem"},
    {"Gumdrop Island","Candy Land",1,"normal"},{"Rewards Island","Candy Land",2,"normal"},{"Sugar Island","Candy Land",3,"normal"},{"Candy Island","Candy Land",4,"normal"},{"Sweet Island","Candy Land",5,"normal"},
    {"Block Island","Toy Land",1,"normal"},{"Block Rewards","Toy Land",2,"normal"},{"Toy Isle","Toy Land",3,"normal"},{"Teddy Island","Toy Land",4,"normal"},{"Treasure Isle","Toy Land",5,"normal"},
    {"Sea Island","Beach World",1,"normal"},{"Sea Rewards","Beach World",2,"normal"},{"Shell Isle","Beach World",3,"normal"},{"Oceanic Island","Beach World",4,"normal"},{"Sea Shell Island","Beach World",5,"normal"},
    {"Water Island","Atlantis",1,"normal"},{"Atlantis Rewards","Atlantis",2,"normal"},{"Atlantis Isle","Atlantis",3,"normal"},{"Treasure Island","Atlantis",4,"normal"},{"Sandy Island","Atlantis",5,"normal"},
    {"Red Island","Rainbow Land",1,"normal"},{"Rainbow Rewards","Rainbow Land",2,"normal"},{"Green Island","Rainbow Land",3,"normal"},{"Blue Island","Rainbow Land",4,"normal"},{"Purple Island","Rainbow Land",5,"normal"},
    {"Fire Island","Underworld",1,"normal"},{"Magma Rewards","Underworld",2,"normal"},{"Magma Island","Underworld",3,"normal"},{"Inferno Island","Underworld",4,"normal"},{"Molten Island","Underworld",5,"normal"},
    {"Crystal Island","Mystic Forest",1,"gem"},{"Crystal Rewards","Mystic Forest",2,"gem"},{"Mythic Island","Mystic Forest",3,"gem"},{"Spirit Island","Mystic Forest",4,"gem"},{"Magic Island","Mystic Forest",5,"gem"}
}
local knownNorm={}
for _,d in ipairs(knownIslands) do knownNorm[normalize(d[1])]={name=d[1],world=d[2],order=d[3],kind=d[4]} end

local function islandPart(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end
    local best,bestScore=nil,-1
    for _,p in ipairs(object:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency<1 then
            local score=p.Size.X*p.Size.Z*(p.CanCollide and 2 or 1)
            if score>bestScore then best,bestScore=p,score end
        end
    end
    return best or partOf(object)
end

-- Find the REAL egg model by walking upward from a Hotkey.
local function eggContainerFromHotkey(hotkey,folder)
    local current=hotkey and hotkey.Parent
    while current and current~=folder and current:IsDescendantOf(folder) do
        if current.Name:lower():find("egg",1,true) then return current end
        current=current.Parent
    end
    return nil
end
local function eggPart(object)
    if not object then return nil end
    local hotkey=object:FindFirstChild("Hotkey",true)
    return partOf(hotkey) or partOf(object)
end

local function scanEggs()
    local folder=workspace:FindFirstChild("Eggs",true)
    local eggs,seen={},{}
    if not folder then return eggs end

    local function add(object,hotkey)
        if not object or seen[object] or not object.Parent then return end
        local p=partOf(hotkey) or eggPart(object)
        if not p then return end
        seen[object]=true
        local world=meta(object,{"World","WorldName","Island","Area"})
        if not world then
            local parent=object.Parent
            if parent and parent~=folder and not parent.Name:lower():find("egg",1,true) then world=parent.Name end
        end
        local currency=meta(object,{"Currency","CurrencyType"})
        eggs[#eggs+1]={
            object=object,part=p,name=object.Name,world=tostring(world or "Текущий мир"),
            price=meta(object,{"Price","Cost","EggPrice"}),currency=currency,y=p.Position.Y,
            kind=isGemCurrency(currency) and "gem" or "normal"
        }
    end

    for _,node in ipairs(folder:GetDescendants()) do
        if node.Name=="Hotkey" and (node:IsA("BasePart") or node:IsA("Attachment") or node:IsA("Model")) then
            local container=eggContainerFromHotkey(node,folder)
            if container then add(container,node) end
        end
    end
    -- Fallback for copies where Hotkey is nested oddly but the top object is still an egg.
    for _,object in ipairs(folder:GetChildren()) do
        if (object:IsA("Model") or object:IsA("BasePart")) and object.Name:lower():find("egg",1,true) then add(object,object:FindFirstChild("Hotkey",true)) end
    end

    table.sort(eggs,function(a,b)
        local wa,wb=worldRank(a.world),worldRank(b.world)
        if wa~=wb then return wa<wb end
        if math.abs(a.y-b.y)>2 then return a.y<b.y end
        return a.name<b.name
    end)
    for i,e in ipairs(eggs) do e.order=i end
    return eggs
end

local function scanIslands(eggs)
    local result,seenName={},{}
    local function add(object,name,world,order,kind)
        local p=islandPart(object)
        if not p then return end
        local key=normalize(name or object.Name)
        if seenName[key] then return end
        seenName[key]=true
        local entry={object=object,part=p,name=name or object.Name,world=world or "Карта",knownOrder=order,kind=kind,y=p.Position.Y}
        result[#result+1]=entry
    end
    for _,object in ipairs(workspace:GetDescendants()) do
        if object:IsA("Model") or object:IsA("Folder") or object:IsA("BasePart") then
            local key=normalize(object.Name)
            local def=knownNorm[key]
            if def then
                add(object,def.name,def.world,def.order,def.kind)
            else
                local low=object.Name:lower()
                local candidate=low:find("island",1,true) or low:find("isle",1,true) or low=="space" or low=="zen" or low=="the void" or low=="the twilight" or low=="the skylands"
                if candidate and object.Parent~=player.Character then add(object,object.Name,"Карта",nil,nil) end
            end
        end
    end

    -- Dynamic color classification: a nearby Gems/Crystals egg makes the island purple.
    for _,island in ipairs(result) do
        if not island.kind then
            local best,bestDist=nil,math.huge
            for _,egg in ipairs(eggs or {}) do
                local dy=math.abs(egg.part.Position.Y-island.part.Position.Y)
                if dy<80 then
                    local flatA=Vector2.new(egg.part.Position.X,egg.part.Position.Z)
                    local flatB=Vector2.new(island.part.Position.X,island.part.Position.Z)
                    local d=(flatA-flatB).Magnitude
                    if d<bestDist then best,bestDist=egg,d end
                end
            end
            island.kind=(best and bestDist<260 and best.kind=="gem") and "gem" or "normal"
        end
    end

    table.sort(result,function(a,b)
        local wa,wb=worldRank(a.world),worldRank(b.world)
        if wa~=wb then return wa<wb end
        if a.knownOrder and b.knownOrder and a.knownOrder~=b.knownOrder then return a.knownOrder<b.knownOrder end
        if math.abs(a.y-b.y)>2 then return a.y<b.y end
        return a.name<b.name
    end)
    for i,island in ipairs(result) do island.order=i end
    return result
end

local function scanPickups()
    local pickups,currencies={}, {"Все"}
    local container=workspace:FindFirstChild("Pickups",true)
    if not container then return pickups,currencies end
    local bestByObject={}
    local currencySet={}
    for _,p in ipairs(container:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency<1 then
            local object=(p.Parent and p.Parent:IsA("Model")) and p.Parent or p
            local score=0
            if p:FindFirstChild("TouchInterest") then score=score+1000 end
            if p.CanTouch then score=score+100 end
            if p.Name=="Part" then score=score+25 end
            score=score+p.Size.Magnitude
            local old=bestByObject[object]
            if not old or score>old.score then bestByObject[object]={object=object,part=p,score=score} end
        end
    end
    for object,v in pairs(bestByObject) do
        local currency=currencyOf(object,container)
        pickups[#pickups+1]={object=object,part=v.part,currency=currency}
        if not currencySet[currency] then currencySet[currency]=true currencies[#currencies+1]=currency end
    end
    table.sort(currencies,function(a,b)
        if a==b then return false end
        if a=="Все" then return true end
        if b=="Все" then return false end
        return a<b
    end)
    return pickups,currencies
end

local function validEgg(e)
    return e and e.object and e.object.Parent and e.part and e.part.Parent and e.object:IsDescendantOf(workspace)
end
local function validPickup(e)
    return e and e.object and e.object.Parent and e.part and e.part.Parent and e.part.Transparency<1 and e.object:IsDescendantOf(workspace) and e.object:GetAttribute("Collected")~=true
end
local function bodyHeight()
    local r,h=root(),humanoid()
    if not r or not h then return 5 end
    return math.max(5,r.Size.Y+2*h.HipHeight)
end
local function standingPoint(position,object)
    local r,h=root(),humanoid()
    if not r or not h then return position+Vector3.new(0,3,0) end
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={player.Character,object}
    pcall(function() ray.RespectCanCollide=true end)
    local hit=workspace:Raycast(position+Vector3.new(0,18,0),Vector3.new(0,-100,0),ray)
    local height=h.HipHeight+r.Size.Y/2+0.35
    if hit and hit.Normal.Y>0.55 then return Vector3.new(position.X,hit.Position.Y+height,position.Z) end
    return position+Vector3.new(0,3,0)
end
local function teleport(point)
    if not ready() then return false,"Жду персонажа" end
    local r,h=root(),humanoid()
    stopMove() h.Sit=false
    r.CFrame=CFrame.new(point)*(r.CFrame-r.Position)
    r.AssemblyLinearVelocity=Vector3.zero
    r.AssemblyAngularVelocity=Vector3.zero
    return true
end
local function blockedTo(part)
    local r=root()
    if not r or not part then return false end
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={player.Character,part.Parent}
    pcall(function() ray.RespectCanCollide=true end)
    return workspace:Raycast(r.Position,part.Position-r.Position,ray)~=nil
end

-- Bubble amount parser for Auto Sell.
local cachedBubbleLabel=nil
local nextBubbleLabelSearch=0
local function parseCompact(text)
    if type(text)~="string" then return nil end
    local s=text:lower():gsub(",",""):gsub("%s+","")
    local n,suffix=s:match("([%d%.]+)([%a]*)")
    n=tonumber(n)
    if not n then return nil end
    local mult={k=1e3,m=1e6,b=1e9,t=1e12,qa=1e15,qi=1e18,sx=1e21,sp=1e24,oc=1e27,no=1e30,de=1e33}
    return n*(mult[suffix] or 1)
end
local function findBubbleLabel()
    if cachedBubbleLabel and cachedBubbleLabel.Parent then return cachedBubbleLabel end
    local now=os.clock()
    if now<nextBubbleLabelSearch then return nil end
    nextBubbleLabelSearch=now+4
    local screen=playerGui:FindFirstChild("ScreenGui")
    local direct=screen and screen:FindFirstChild("StatsFrame")
    direct=direct and direct:FindFirstChild("Bubble")
    direct=direct and direct:FindFirstChild("Amount")
    if direct and (direct:IsA("TextLabel") or direct:IsA("TextButton")) then cachedBubbleLabel=direct return direct end
    for _,obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text:find("/",1,true) then
            local n=(obj.Name.." "..(obj.Parent and obj.Parent.Name or "")):lower()
            if n:find("bubble",1,true) or n:find("gum",1,true) then cachedBubbleLabel=obj return obj end
        end
    end
end
local function bubbleRatio()
    local label=findBubbleLabel()
    if not label then return nil,nil,nil end
    local left,right=label.Text:match("([^/]+)/([^/]+)")
    local current,max=parseCompact(left),parseCompact(right)
    if not current or not max or max<=0 then return nil,nil,label.Text end
    return current/max,current,max
end

local S={
    alive=true,version="0.4.0",autoBubble=false,autoHatch=false,autoCollect=false,autoSell=false,
    teleportOnSelect=true,bubbleDelay=0.20,hatchDelay=0.80,sellCheckDelay=0.75,teleportHeights=5,
    collectMode="smart",currency="Все",eggs={},pickups={},currencies={"Все"},islands={},selectedEgg=nil,selectedIsland=nil,
    status="Готово",bubbleStatus="Выключено",hatchStatus="Выбери яйцо",collectStatus="Выключено",sellStatus="Выключено",
    lastBubble=-math.huge,lastHatch=-math.huge,lastSellCheck=-math.huge,nextScan=0,nextMove=0,travelUntil=0,
    skipped=setmetatable({},{__mode="k"}),target=nil,busy=false,selling=false,errors=0,
    targetStarted=0,lastProgressAt=0,lastDistance=math.huge,passAt=0,collectAttempts=setmetatable({},{__mode="k"})
}
env.BGSLegacy=S

local function clearTarget(cooldown)
    if S.target and cooldown then S.skipped[S.target.object]=os.clock()+cooldown end
    S.target=nil
    S.targetStarted=0
    S.lastProgressAt=0
    S.lastDistance=math.huge
    S.passAt=0
end

function S:Refresh()
    local oldEgg=self.selectedEgg and self.selectedEgg.object
    local oldIsland=self.selectedIsland and self.selectedIsland.object
    self.eggs=scanEggs()
    self.pickups,self.currencies=scanPickups()
    self.islands=scanIslands(self.eggs)
    self.selectedEgg=nil
    for _,e in ipairs(self.eggs) do if e.object==oldEgg then self.selectedEgg=e break end end
    self.selectedIsland=nil
    for _,i in ipairs(self.islands) do if i.object==oldIsland then self.selectedIsland=i break end end
    self.nextScan=os.clock()+4
end
function S:SelectEgg(entry)
    if not validEgg(entry) then self.status="Яйцо исчезло — обнови список" return false end
    self.selectedEgg=entry self.lastHatch=os.clock()
    self.hatchStatus="Выбрано: "..entry.name self.status=self.hatchStatus
    if self.teleportOnSelect then return self:GoToEgg() end
    return true
end
function S:GoToEgg()
    local e=self.selectedEgg
    if not validEgg(e) then self.status="Сначала выбери яйцо" return false end
    local horizontal=e.part.CFrame.LookVector
    horizontal=Vector3.new(horizontal.X,0,horizontal.Z)
    if horizontal.Magnitude<0.1 then horizontal=Vector3.new(0,0,1) else horizontal=horizontal.Unit end
    local point=standingPoint(e.part.Position-horizontal*7,e.object)
    local ok,problem=teleport(point)
    if ok then self.travelUntil=os.clock()+0.8 self.status="У яйца: "..e.name else self.status=tostring(problem) end
    return ok
end
function S:HatchOnce()
    local e=self.selectedEgg
    if not validEgg(e) or not ready() then self.status="Выбери доступное яйцо" return false end
    local d=(e.part.Position-root().Position).Magnitude
    if d>15.5 then self.status="Сначала нажми «К яйцу» · "..math.floor(d).." studs" return false end
    if tostring(e.currency or ""):lower():find("robux",1,true) then self.status="Robux-яйцо открывай вручную" return false end
    local ok,problem=send("PurchaseEgg",e.name)
    self.hatchStatus=ok and ("Открываю: "..e.name) or tostring(problem or "Открытие недоступно")
    self.status=self.hatchStatus
    return ok
end
function S:SelectIsland(entry)
    self.selectedIsland=entry self.status="Выбрано: "..entry.name
end
function S:GoIsland(entry)
    entry=entry or self.selectedIsland
    if not entry or not entry.part or not entry.part.Parent then self.status="Остров недоступен" return false end
    clearTarget() stopMove()
    local p=entry.part
    local point=standingPoint(p.Position,entry.object)
    -- For giant platform parts use the top face directly.
    if p.Size.Y>6 then point=Vector3.new(p.Position.X,p.Position.Y+p.Size.Y/2+bodyHeight()/2+0.8,p.Position.Z) end
    local ok,problem=teleport(point)
    if ok then self.travelUntil=os.clock()+0.8 self.status="ТП: "..entry.name else self.status=tostring(problem) end
    return ok
end
function S:SellNow()
    if self.selling or not ready() then return false end
    self.selling=true clearTarget() stopMove()
    local before=root().CFrame
    task.spawn(function()
        local ok1,p1=send("Teleport","Sell")
        task.wait(0.18)
        local ok2,p2=send("SellBubble","Sell")
        task.wait(0.18)
        local r=root()
        if r and r.Parent then r.CFrame=before r.AssemblyLinearVelocity=Vector3.zero r.AssemblyAngularVelocity=Vector3.zero end
        self.travelUntil=os.clock()+0.5 self.selling=false
        if ok1 and ok2 then self.sellStatus="Продано" self.status="Пузыри проданы" else self.sellStatus="Ошибка продажи" self.status=tostring(p2 or p1 or "Sell недоступен") end
    end)
    return true
end
function S:SetMode(key,value)
    value=value==true
    if key=="autoHatch" and value and not validEgg(self.selectedEgg) then self.status="Выбери яйцо" return end
    if key~="autoBubble" and key~="autoHatch" and key~="autoCollect" and key~="autoSell" then return end
    self[key]=value
    if key=="autoBubble" then self.bubbleStatus=value and "Включено" or "Выключено" end
    if key=="autoHatch" then self.hatchStatus=value and "Автооткрытие включено" or "Выключено" end
    if key=="autoCollect" then clearTarget() self.collectStatus=value and "Ищу добычу" or "Выключено" end
    if key=="autoSell" then self.sellStatus=value and "Жду заполнения" or "Выключено" end
end
function S:HardStop()
    self.autoBubble=false self.autoHatch=false self.autoCollect=false self.autoSell=false
    clearTarget() self.travelUntil=0 stopMove()
    self.bubbleStatus="Выключено" self.hatchStatus="Выключено" self.collectStatus="Выключено" self.sellStatus="Выключено"
    self.status="Все действия остановлены"
end
function S:Stop(reason)
    if not self.alive then return end
    self:HardStop() self.alive=false
    for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns={}
    if gui then pcall(function() gui:Destroy() end) end
    self.status="stopped: "..tostring(reason or "manual")
end

local function nearestPickup(now)
    local best,dist=nil,math.huge
    local r=root()
    if not r then return nil,nil end
    for _,item in ipairs(S.pickups) do
        if validPickup(item) and (S.currency=="Все" or item.currency==S.currency) and now>=(S.skipped[item.object] or 0) then
            local d=(item.part.Position-r.Position).Magnitude
            if d<dist then best,dist=item,d end
        end
    end
    return best,dist
end
local function passDirection(target)
    local r=root()
    local delta=target.part.Position-r.Position
    local flat=Vector3.new(delta.X,0,delta.Z)
    if flat.Magnitude<0.25 then
        local look=r.CFrame.LookVector
        flat=Vector3.new(look.X,0,look.Z)
    end
    if flat.Magnitude<0.25 then flat=Vector3.new(1,0,0) end
    return flat.Unit
end
local function touchAssist(target)
    if type(firetouchinterest)=="function" then
        local r=root()
        if r then pcall(firetouchinterest,r,target.part,0) pcall(firetouchinterest,r,target.part,1) end
    end
end
local function crossPickup(target,useTeleport)
    local r,h=root(),humanoid()
    if not r or not h then return false end
    local dir=passDirection(target)
    if useTeleport then
        local before=standingPoint(target.part.Position-dir*5,target.object)
        teleport(before)
    end
    -- IMPORTANT: destination is PAST the pickup, forcing the avatar through its hitbox.
    local past=target.part.Position+dir*6
    h:MoveTo(past)
    touchAssist(target)
    return true
end
local function collectStep(now)
    if now<S.travelUntil or S.selling then return end
    local target=S.target
    if target and (not validPickup(target) or (S.currency~="Все" and target.currency~=S.currency)) then clearTarget() target=nil end
    if not target then
        target=nearestPickup(now)
        if not target then S.collectStatus="Нет доступной добычи" return end
        S.target=target S.targetStarted=now S.lastProgressAt=now S.lastDistance=math.huge S.passAt=0
    end

    local r=root()
    if not r then return end
    local d=(target.part.Position-r.Position).Magnitude
    S.collectStatus=target.currency.." · "..math.floor(d).." studs"

    if d<S.lastDistance-0.45 then S.lastDistance=d S.lastProgressAt=now end

    -- Hard timeout: never get stuck forever on one bad pickup / fountain / wall.
    if now-S.targetStarted>4.2 then
        S.collectAttempts[target.object]=(S.collectAttempts[target.object] or 0)+1
        clearTarget(12)
        S.collectStatus="Цель пропущена · застряла"
        return
    end

    if d<=10 then
        if now-S.passAt>=0.45 then
            S.passAt=now
            crossPickup(target,false)
        end
        -- If it survived a couple of passes, force one short cross-teleport then keep moving.
        if now-S.targetStarted>2.0 and (S.collectAttempts[target.object] or 0)<1 then
            S.collectAttempts[target.object]=1
            crossPickup(target,true)
        end
        return
    end

    if now<S.nextMove then return end
    S.nextMove=now+0.22
    local stalled=now-S.lastProgressAt>1.1
    local far=d>S.teleportHeights*bodyHeight()
    local useTP=S.collectMode=="teleport" or far or stalled or blockedTo(target.part)
    if useTP then
        crossPickup(target,true)
        S.lastProgressAt=now
    else
        -- Walk TO/Past the actual pickup, not a safe standing point beside it.
        local dir=passDirection(target)
        humanoid():MoveTo(target.part.Position+dir*4)
    end
end

local function step(now)
    if not S.alive or not ready() then return end
    if now>=S.nextScan then S:Refresh() end

    if S.autoBubble and now-S.lastBubble>=S.bubbleDelay then
        S.lastBubble=now
        local ok,problem=send("BlowBubble")
        S.bubbleStatus=ok and "Надуваю" or tostring(problem or "Ожидание")
    end
    if S.autoSell and now-S.lastSellCheck>=S.sellCheckDelay and not S.selling then
        S.lastSellCheck=now
        local ratio,current,max=bubbleRatio()
        if ratio then
            S.sellStatus=string.format("%.0f%% · %s/%s",math.min(999,ratio*100),tostring(math.floor(current)),tostring(math.floor(max)))
            if ratio>=0.995 then S:SellNow() return end
        else S.sellStatus="Лимит пузырей не найден" end
    end
    if S.selling then return end

    if S.autoHatch then
        local e=S.selectedEgg
        if not validEgg(e) then S.hatchStatus="Выбранное яйцо недоступно" return end
        local d=(e.part.Position-root().Position).Magnitude
        if d>15.5 then
            if now>=S.nextMove then S.nextMove=now+0.8 S:GoToEgg() S.lastHatch=now end
        elseif now-S.lastHatch>=S.hatchDelay then S.lastHatch=now S:HatchOnce() end
    elseif S.autoCollect then collectStep(now) end
end
function S:Tick()
    if S.busy or not S.alive then return end
    S.busy=true
    local ok,problem=pcall(step,os.clock())
    S.busy=false
    if not ok then S.errors=S.errors+1 S.status="Ошибка: "..tostring(problem):sub(1,130) end
end

-- UI -----------------------------------------------------------------------
local C={
    bg=Color3.fromRGB(14,15,22),panel=Color3.fromRGB(22,24,34),surface=Color3.fromRGB(30,33,45),border=Color3.fromRGB(68,70,92),
    accent=Color3.fromRGB(154,120,244),accent2=Color3.fromRGB(103,177,255),text=Color3.fromRGB(244,245,250),muted=Color3.fromRGB(158,162,184),
    danger=Color3.fromRGB(232,93,121),good=Color3.fromRGB(105,220,151),gem=Color3.fromRGB(181,112,255),normal=Color3.fromRGB(111,222,142),coin=Color3.fromRGB(236,201,91)
}
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local function corner(o,r) make("UICorner",o,{CornerRadius=UDim.new(0,r or 9)}) end
local function stroke(o,color,trans,thickness)
    return make("UIStroke",o,{Color=color or C.border,Thickness=thickness or 1,Transparency=trans==nil and 0.25 or trans})
end
local function label(parent,text,size,color)
    return make("TextLabel",parent,{Text=text,TextSize=size or 13,Font=Enum.Font.Gotham,TextColor3=color or C.text,BackgroundTransparency=1,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
end
local old=playerGui:FindFirstChild("BGSLegacyHub")
if old then old:Destroy() end
gui=make("ScreenGui",playerGui,{Name="BGSLegacyHub",ResetOnSpawn=false,DisplayOrder=999999,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local main=make("Frame",gui,{Name="Main",Size=UDim2.fromOffset(470,390),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true,Active=true})
corner(main,14) stroke(main,C.accent,0.12,1.2)
local header=make("Frame",main,{Size=UDim2.new(1,0,0,50),BackgroundColor3=C.panel,BorderSizePixel=0,Active=true})
local accentLine=make("Frame",header,{Size=UDim2.new(0,4,0,26),Position=UDim2.fromOffset(10,12),BackgroundColor3=C.accent,BorderSizePixel=0}) corner(accentLine,5)
local title=label(header,"BGS LEGACY",16) title.Font=Enum.Font.GothamBold title.Position=UDim2.fromOffset(22,7) title.Size=UDim2.new(1,-190,0,20)
local subtitle=label(header,"v0.4 · чистая сортировка / hitbox fix",9,C.muted) subtitle.Position=UDim2.fromOffset(22,27) subtitle.Size=UDim2.new(1,-190,0,15)
local function button(parent,text,callback,height)
    local b=make("TextButton",parent,{Size=UDim2.new(1,-6,0,height or 38),Text=text,TextSize=12,TextColor3=C.text,Font=Enum.Font.GothamMedium,TextWrapped=true,BackgroundColor3=C.surface,BorderSizePixel=0,AutoButtonColor=true})
    corner(b,8) connect(b.Activated,callback) return b
end
local stopBtn=button(header,"СТОП",function() S:HardStop() end,28) stopBtn.Size=UDim2.fromOffset(58,28) stopBtn.Position=UDim2.new(1,-132,0,11) stopBtn.TextColor3=C.danger
local mini=button(header,"—",function() end,28) mini.Size=UDim2.fromOffset(28,28) mini.Position=UDim2.new(1,-68,0,11)
local close=button(header,"×",function() S:Stop("closed") end,28) close.Size=UDim2.fromOffset(28,28) close.Position=UDim2.new(1,-36,0,11)

local tabs=make("Frame",main,{Position=UDim2.fromOffset(9,58),Size=UDim2.new(1,-18,0,31),BackgroundTransparency=1})
local holder=make("Frame",main,{Position=UDim2.fromOffset(11,97),Size=UDim2.new(1,-22,1,-130),BackgroundTransparency=1})
local footer=label(main,"Готово",10,C.muted) footer.Position=UDim2.new(0,13,1,-28) footer.Size=UDim2.new(1,-42,0,22) footer.TextWrapped=false footer.TextTruncate=Enum.TextTruncate.AtEnd
local grip=make("TextButton",main,{Text="◢",TextSize=15,TextColor3=C.accent,Size=UDim2.fromOffset(24,24),Position=UDim2.new(1,-25,1,-25),BackgroundTransparency=1})
local pageNames={"Фарм","Яйца","Острова","Монеты","Ещё"}
local pages,tabButtons={},{}
local function setTab(index)
    for i,p in ipairs(pages) do
        p.Visible=i==index
        tabButtons[i].BackgroundColor3=i==index and C.accent or C.panel
        tabButtons[i].TextColor3=i==index and C.bg or C.muted
    end
end
for i,name in ipairs(pageNames) do
    local b=button(tabs,name,function() setTab(i) end,31)
    b.Size=UDim2.new(0.2,-4,1,0) b.Position=UDim2.new((i-1)*0.2,2,0,0) tabButtons[i]=b
    local page=make("ScrollingFrame",holder,{Name="Page"..i,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=C.accent,ScrollingDirection=Enum.ScrollingDirection.Y})
    make("UIListLayout",page,{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
    make("UIPadding",page,{PaddingBottom=UDim.new(0,7),PaddingLeft=UDim.new(0,1),PaddingTop=UDim.new(0,2)})
    pages[i]=page
end
setTab(1)
local function textRow(parent,text,height,color)
    local l=label(parent,text,11,color or C.muted) l.Size=UDim2.new(1,-9,0,height or 34) return l
end
local draws={}
local function toggle(parent,titleText,description,read,write)
    local b=button(parent,"",function() write(not read()) end,51) stroke(b,C.border,0.48)
    local t=label(b,titleText,12) t.Font=Enum.Font.GothamMedium t.Position=UDim2.fromOffset(11,7) t.Size=UDim2.new(1,-76,0,17)
    local d=label(b,description,9,C.muted) d.Position=UDim2.fromOffset(11,27) d.Size=UDim2.new(1,-78,0,17) d.TextWrapped=false d.TextTruncate=Enum.TextTruncate.AtEnd
    local pill=make("Frame",b,{Size=UDim2.fromOffset(38,21),Position=UDim2.new(1,-49,0.5,-10),BorderSizePixel=0}) corner(pill,20)
    local dot=make("Frame",pill,{Size=UDim2.fromOffset(15,15),BackgroundColor3=C.text,BorderSizePixel=0}) corner(dot,20)
    draws[#draws+1]=function()
        local on=read() pill.BackgroundColor3=on and C.accent or C.border dot.Position=UDim2.fromOffset(on and 20 or 3,3)
    end
end
local activeSlider=nil
local function slider(parent,titleText,key,min,max,stepv,unit)
    local box=make("Frame",parent,{Size=UDim2.new(1,-6,0,58),BackgroundColor3=C.panel,BorderSizePixel=0}) corner(box,8)
    local n=label(box,titleText,11) n.Position=UDim2.fromOffset(11,6) n.Size=UDim2.new(1,-112,0,18)
    local value=label(box,"",11,C.accent) value.Position=UDim2.new(1,-102,0,6) value.Size=UDim2.fromOffset(90,18) value.TextXAlignment=Enum.TextXAlignment.Right
    local track=make("TextButton",box,{Text="",Size=UDim2.new(1,-26,0,23),Position=UDim2.fromOffset(13,29),BackgroundTransparency=1,AutoButtonColor=false})
    local rail=make("Frame",track,{Size=UDim2.new(1,0,0,4),Position=UDim2.new(0,0,0.5,-2),BackgroundColor3=C.border,BorderSizePixel=0}) corner(rail,4)
    local fill=make("Frame",rail,{BackgroundColor3=C.accent,BorderSizePixel=0}) corner(fill,4)
    local knob=make("Frame",rail,{Size=UDim2.fromOffset(11,11),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=C.text,BorderSizePixel=0}) corner(knob,11)
    local function update(x)
        local a=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
        S[key]=math.clamp(math.floor((min+a*(max-min))/stepv+0.5)*stepv,min,max)
    end
    connect(track.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then activeSlider={input=input,update=update} update(input.Position.X) end
    end)
    draws[#draws+1]=function()
        local a=(S[key]-min)/(max-min) fill.Size=UDim2.fromScale(a,1) knob.Position=UDim2.fromScale(a,0.5)
        value.Text=(stepv>=1 and string.format("%.0f",S[key]) or string.format("%.2f",S[key])).." "..unit
    end
end

-- Searchable picker. Items may provide borderColor.
local overlay=make("Frame",main,{Name="Picker",Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BackgroundTransparency=0.01,BorderSizePixel=0,Visible=false,ZIndex=20,Active=true})
local pickerTitle=label(overlay,"Выбор",14) pickerTitle.Font=Enum.Font.GothamBold pickerTitle.Position=UDim2.fromOffset(15,11) pickerTitle.Size=UDim2.new(1,-65,0,26)
local pickerClose=button(overlay,"×",function() overlay.Visible=false end,28) pickerClose.Size=UDim2.fromOffset(28,28) pickerClose.Position=UDim2.new(1,-40,0,10)
local search=make("TextBox",overlay,{PlaceholderText="Поиск…",Text="",ClearTextOnFocus=false,Size=UDim2.new(1,-30,0,34),Position=UDim2.fromOffset(15,46),TextSize=12,TextColor3=C.text,PlaceholderColor3=C.muted,Font=Enum.Font.Gotham,BackgroundColor3=C.surface,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left}) corner(search,8)
make("UIPadding",search,{PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9)})
local choices=make("ScrollingFrame",overlay,{Size=UDim2.new(1,-30,1,-94),Position=UDim2.fromOffset(15,88),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=4,ScrollBarImageColor3=C.accent,ScrollingDirection=Enum.ScrollingDirection.Y})
make("UIListLayout",choices,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local pickerItems,pickerChoose={},nil
local choiceConns={}
local function renderChoices()
    for _,c in ipairs(choiceConns) do pcall(function() c:Disconnect() end) end choiceConns={}
    for _,child in ipairs(choices:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    local filter=search.Text:lower() local found=0
    for _,item in ipairs(pickerItems) do
        local hay=(item.title.." "..(item.detail or "")):lower()
        if filter=="" or hay:find(filter,1,true) then
            found=found+1
            local b=make("TextButton",choices,{Text="",Size=UDim2.new(1,-5,0,50),BackgroundColor3=item.selected and C.panel or C.surface,BorderSizePixel=0,LayoutOrder=found}) corner(b,8)
            stroke(b,item.borderColor or C.border,item.borderColor and 0.10 or 0.48,item.borderColor and 1.4 or 1)
            local t=label(b,item.title,12) t.Font=Enum.Font.GothamMedium t.Position=UDim2.fromOffset(11,5) t.Size=UDim2.new(1,-22,0,18)
            local d=label(b,item.detail or "",9,C.muted) d.Position=UDim2.fromOffset(11,26) d.Size=UDim2.new(1,-22,0,17) d.TextWrapped=false d.TextTruncate=Enum.TextTruncate.AtEnd
            choiceConns[#choiceConns+1]=b.Activated:Connect(function() overlay.Visible=false if pickerChoose then pickerChoose(item.value) end end)
        end
    end
    if found==0 then textRow(choices,"Ничего не найдено",42) end
end
connect(search:GetPropertyChangedSignal("Text"),renderChoices)
local function picker(titleText,items,choose)
    pickerItems=items pickerChoose=choose pickerTitle.Text=titleText search.Text="" choices.CanvasPosition=Vector2.zero renderChoices() overlay.Visible=true
end
local function borderForKind(kind,currency)
    if kind=="gem" or isGemCurrency(currency) then return C.gem end
    return C.normal
end
local function eggDetail(e)
    local price=e.price and (tostring(e.price).." "..tostring(e.currency or "")) or "цена из игры"
    return e.world.." · Y="..math.floor(e.y).." · "..price
end
local function islandDetail(i)
    local tag=i.kind=="gem" and "GEMS" or "обычный"
    return i.world.." · снизу #"..tostring(i.order).." · "..tag
end

-- ФАРМ
toggle(pages[1],"Авто надувание","Параллельно остальным функциям",function() return S.autoBubble end,function(v) S:SetMode("autoBubble",v) end)
toggle(pages[1],"Авто продажа","Только при заполненной сумке",function() return S.autoSell end,function(v) S:SetMode("autoSell",v) end)
local sellNow=button(pages[1],"ПРОДАТЬ СЕЙЧАС",function() S:SellNow() end,36) stroke(sellNow,C.accent2,0.25)
slider(pages[1],"Интервал надувания","bubbleDelay",0.2,2,0.05,"сек")
local farmInfo=textRow(pages[1],"",32,C.accent)
local sellInfo=textRow(pages[1],"",32,C.good)

-- ЯЙЦА
textRow(pages[2],"Список: от самого низкого яйца к самому высокому.",26,C.muted)
textRow(pages[2],"Фиолетовая рамка = Gems · зелёная = обычная валюта.",26,C.muted)
local eggButton=button(pages[2],"ВЫБРАТЬ ЯЙЦО  ›",function()
    S:Refresh()
    local items={}
    for idx,e in ipairs(S.eggs) do
        items[#items+1]={title=string.format("%02d. %s",idx,e.name),detail=eggDetail(e),value=e,selected=S.selectedEgg and S.selectedEgg.object==e.object,borderColor=borderForKind(e.kind,e.currency)}
    end
    picker("Яйца · снизу → вверх · "..#items,items,function(e) S:SelectEgg(e) end)
end,46) stroke(eggButton,C.accent,0.25)
local eggInfo=textRow(pages[2],"Выбери яйцо.",30)
local eggActions=make("Frame",pages[2],{Size=UDim2.new(1,-6,0,35),BackgroundTransparency=1})
local goEgg=button(eggActions,"К яйцу",function() S:GoToEgg() end,35) goEgg.Size=UDim2.new(0.5,-4,1,0)
local once=button(eggActions,"Открыть 1",function() S:HatchOnce() end,35) once.Size=UDim2.new(0.5,-4,1,0) once.Position=UDim2.new(0.5,4,0,0)
toggle(pages[2],"Автооткрытие","Открывает именно выбранное имя яйца",function() return S.autoHatch end,function(v) S:SetMode("autoHatch",v) end)
toggle(pages[2],"ТП при выборе","Сразу переносит к Hotkey яйца",function() return S.teleportOnSelect end,function(v) S.teleportOnSelect=v end)
slider(pages[2],"Интервал открытий","hatchDelay",0.65,3,0.05,"сек")
local hatchInfo=textRow(pages[2],"",30,C.accent)

-- ОСТРОВА
textRow(pages[3],"Сортировка внутри мира: снизу → вверх.",25,C.muted)
textRow(pages[3],"Фиолетовая рамка = gem-остров · зелёная = обычный.",25,C.muted)
local islandButton=button(pages[3],"ВЫБРАТЬ ОСТРОВ  ›",function()
    S:Refresh()
    local items={}
    for idx,i in ipairs(S.islands) do
        items[#items+1]={title=string.format("%02d. %s",idx,i.name),detail=islandDetail(i),value=i,selected=S.selectedIsland and S.selectedIsland.object==i.object,borderColor=borderForKind(i.kind)}
    end
    picker("Острова · снизу → вверх · "..#items,items,function(i) S:SelectIsland(i) S:GoIsland(i) end)
end,46) stroke(islandButton,C.accent2,0.2)
local islandInfo=textRow(pages[3],"",30)
button(pages[3],"ТП К ВЫБРАННОМУ",function() S:GoIsland() end,36)
button(pages[3],"ОБНОВИТЬ СПИСОК",function() S:Refresh() S.status="Списки обновлены" end,36)

-- МОНЕТЫ
toggle(pages[4],"Авто сбор","Проходит СКВОЗЬ hitbox монеты",function() return S.autoCollect end,function(v) S:SetMode("autoCollect",v) end)
local currencyButton=button(pages[4],"Валюта: Все  ›",function()
    S:Refresh() local items={}
    for _,c in ipairs(S.currencies) do items[#items+1]={title=c,detail=c=="Все" and "Любая валюта" or "Только эта валюта",value=c,selected=S.currency==c,borderColor=isGemCurrency(c) and C.gem or C.normal} end
    picker("Валюта",items,function(c) S.currency=c clearTarget() stopMove() end)
end)
local moveButton=button(pages[4],"Перемещение: умное  ›",function()
    picker("Сбор · перемещение",{{title="Умное",detail="Идёт; если застрял — короткий ТП и проходит сквозь hitbox",value="smart",selected=S.collectMode=="smart"},{title="Всегда ТП",detail="ТП перед монетой → движение через неё",value="teleport",selected=S.collectMode=="teleport"}},function(v) S.collectMode=v clearTarget() end)
end)
slider(pages[4],"ТП дальше чем","teleportHeights",1,15,1,"ростов")
local collectInfo=textRow(pages[4],"",34,C.accent)
local mapInfo=textRow(pages[4],"",30)
textRow(pages[4],"Если одна точка не берётся 4 сек — она пропускается на 12 сек, поэтому фарм больше не должен висеть на ней бесконечно.",50,C.muted)

-- ЕЩЁ
button(pages[5],"Обновить всё",function() S:Refresh() S.status="Списки обновлены" end,36)
local hard2=button(pages[5],"Остановить всё",function() S:HardStop() end,36) hard2.TextColor3=C.danger
textRow(pages[5],"Окно таскается за верх, меняет размер за угол и сворачивается кнопкой «—».",44)
textRow(pages[5],"BGS Legacy Hub 0.4.0",24,C.accent)

-- Window movement/minimize/resize ------------------------------------------
local minimized=false
local savedSize,savedPosition=nil,nil
local drag,resize=nil,nil
local function viewport() return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600) end
local function fit()
    if minimized then return end
    local view=viewport()
    local w=math.clamp(main.Size.X.Offset,360,math.max(360,view.X-20))
    local h=math.clamp(main.Size.Y.Offset,300,math.max(300,view.Y-58))
    main.Size=UDim2.fromOffset(w,h)
    local pos=main.AbsolutePosition
    local x=math.clamp(pos.X,0,math.max(0,view.X-w))
    local y=math.clamp(pos.Y,0,math.max(0,view.Y-h-30))
    main.AnchorPoint=Vector2.new(0,0)
    main.Position=UDim2.fromOffset(x,y)
end
local reopen=make("TextButton",gui,{Name="Mini",Text="BGS",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.text,BackgroundColor3=C.panel,Size=UDim2.fromOffset(48,42),Position=UDim2.fromOffset(20,110),Visible=false,BorderSizePixel=0,Active=true}) corner(reopen,11) stroke(reopen,C.accent,0.15)
local function toggleWindow()
    minimized=not minimized
    if minimized then savedSize=main.Size savedPosition=main.Position reopen.Position=UDim2.fromOffset(main.AbsolutePosition.X,main.AbsolutePosition.Y) overlay.Visible=false end
    main.Visible=not minimized reopen.Visible=minimized
    if not minimized then main.Size=savedSize or main.Size main.Position=savedPosition or main.Position fit() end
end
connect(mini.Activated,toggleWindow)
local miniMoved=false
local function beginDrag(surface,target,isMini)
    connect(surface.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            drag={input=input,start=input.Position,position=target.AbsolutePosition,target=target,isMini=isMini}
            if isMini then miniMoved=false end
        end
    end)
end
beginDrag(header,main,false) beginDrag(reopen,reopen,true)
connect(reopen.Activated,function() if not miniMoved then toggleWindow() end end)
connect(grip.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then resize={input=input,start=input.Position,size=main.AbsoluteSize} end
end)
connect(Input.InputChanged,function(input)
    local mouse=input.UserInputType==Enum.UserInputType.MouseMovement
    if activeSlider and (mouse or input==activeSlider.input) then activeSlider.update(input.Position.X) end
    if drag and (mouse or input==drag.input) then
        local delta=input.Position-drag.start local view=viewport() local target=drag.target
        if drag.isMini and delta.Magnitude>6 then miniMoved=true end
        local x=math.clamp(drag.position.X+delta.X,0,math.max(0,view.X-target.AbsoluteSize.X))
        local y=math.clamp(drag.position.Y+delta.Y,0,math.max(0,view.Y-target.AbsoluteSize.Y-30))
        target.AnchorPoint=Vector2.new(0,0) target.Position=UDim2.fromOffset(x,y)
    end
    if resize and (mouse or input==resize.input) then
        local delta=input.Position-resize.start local view=viewport()
        main.Size=UDim2.fromOffset(math.clamp(resize.size.X+delta.X,360,math.max(360,view.X-20)),math.clamp(resize.size.Y+delta.Y,300,math.max(300,view.Y-58)))
    end
end)
connect(Input.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then drag=nil resize=nil activeSlider=nil end
end)

local function refreshUI()
    for _,draw in ipairs(draws) do draw() end
    footer.Text=S.status
    farmInfo.Text="Пузыри: "..S.bubbleStatus
    sellInfo.Text="Продажа: "..S.sellStatus
    hatchInfo.Text=S.hatchStatus
    collectInfo.Text=S.collectStatus
    local e=S.selectedEgg
    eggButton.Text=e and (e.name.."  ›") or ("ВЫБРАТЬ ЯЙЦО · "..#S.eggs.."  ›")
    eggInfo.Text=e and eggDetail(e) or ("Найдено яиц: "..#S.eggs)
    local i=S.selectedIsland
    islandButton.Text=i and (i.name.."  ›") or ("ВЫБРАТЬ ОСТРОВ · "..#S.islands.."  ›")
    islandInfo.Text=i and islandDetail(i) or ("Найдено островов: "..#S.islands)
    currencyButton.Text="Валюта: "..S.currency.."  ›"
    moveButton.Text="Перемещение: "..(S.collectMode=="smart" and "умное" or "всегда ТП").."  ›"
    mapInfo.Text="Pickups на карте: "..#S.pickups
end

S:Refresh()
main.AnchorPoint=Vector2.new(0.5,0.5)
task.defer(fit)
local nextTick,nextPaint=0,0
connect(Run.Heartbeat,function()
    if not S.alive then return end
    local now=os.clock()
    if now>=nextTick then nextTick=now+0.10 S:Tick() end
    if now>=nextPaint then nextPaint=now+0.20 refreshUI() end
end)
connect(player.CharacterAdded,function() clearTarget() S.travelUntil=os.clock()+2 cachedBubbleLabel=nil end)
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit) end

S.startupReady=true
print("BGS Legacy Hub "..S.version.." loaded")
return S
