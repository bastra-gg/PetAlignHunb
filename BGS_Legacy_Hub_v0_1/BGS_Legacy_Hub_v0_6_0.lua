-- BGS Legacy Hub 0.6.1; generated with v0_6/build.py.
local logic=(function()
-- Pure decisions shared by the runtime and executable regression scenarios.
local L={}
function L.norm(value)
    return tostring(value or ""):lower():gsub("[%s%p_]", "")
end
L.worlds={
    {key="Overworld",display="Overworld · спавн",currency="Coins"},
    {key="Candy Land",display="Candy Land · мир конфет",currency="Candy"},
    {key="Toy Land",display="Toy Land · мир игрушек",currency="Blocks"},
    {key="Beach World",display="Beach World · пляж",currency="Shells"},
    {key="Atlantis",display="Atlantis · Атлантида",currency="Pearls"},
    {key="Rainbow Land",display="Rainbow Land · радужный мир",currency="Stars"},
    {key="Underworld",display="Underworld · вулканический мир",currency="Magma"},
    {key="Mystic Forest",display="Mystic Forest · мифический лес",currency="Crystals"},
    {key="Heaven",display="Heaven · райский мир",currency="Gems"},
}
function L.world(value)
    local key=L.norm(value):gsub("^the", "")
    for _,world in ipairs(L.worlds) do
        if L.norm(world.key)==key then return world.key end
    end
end
-- Each runtime owns its catalog; only replicated world names extend the defaults.
function L.newWorldCatalog()
    local worlds,byName={},{}
    local function add(name,currency)
        if type(name)~="string" or name=="" or #name>100 then return nil end
        local key=L.world(name) or name
        local normalized=L.norm(key)
        if normalized=="" then return nil end
        local entry=byName[normalized]
        if not entry then
            entry={key=key,display=key,currency=currency or "Валюта из игры"}
            byName[normalized]=entry worlds[#worlds+1]=entry
        elseif currency then entry.currency=currency end
        return entry.key
    end
    for _,world in ipairs(L.worlds) do
        add(world.key,world.currency) byName[L.norm(world.key)].display=world.display
    end
    local function resolve(value)
        local canonical=L.world(value)
        local entry=byName[L.norm(canonical or value)]
        return entry and entry.key
    end
    return worlds,resolve,add
end
function L.eggCost(data)
    if type(data)~="table" then return nil,nil end
    local cost=data.Cost
    if type(cost)~="table" then return nil,nil end
    local currency=cost.Currency or cost[1]
    local price=tonumber(cost.Amount or cost.Price or cost[2])
    if type(currency)~="string" or currency=="" then currency=nil end
    if price and (price~=price or price<0 or price==math.huge) then price=nil end
    return currency,price
end
L.chests={
    {world="Overworld",name="The Floating Island",aliases={"Floating Island"}},
    {world="Overworld",name="The Skylands",aliases={"The Skyland","Skylands"}},
    {world="Overworld",name="The Void",aliases={"Void"}},
    {world="Candy Land",name="Gumdrop Island"},
    {world="Candy Land",name="Candy Island"},
    {world="Candy Land",name="Sweet Island"},
    {world="Toy Land",name="Block Rewards",aliases={"Block Island"}},
    {world="Toy Land",name="Teddy Island"},
    {world="Toy Land",name="Treasure Isle",aliases={"Treasure Island"}},
    {world="Beach World",name="Sea Island"},
    {world="Beach World",name="Oceanic Island"},
    {world="Beach World",name="Sea Shell Island",aliases={"Sea Shell Isle","See Shell Isle"}},
    {world="Atlantis",name="Water Island"},
    {world="Atlantis",name="Sandy Island"},
    {world="Rainbow Land",name="Red Island"},
    {world="Rainbow Land",name="Blue Island"},
    {world="Rainbow Land",name="Purple Island"},
    {world="Underworld",name="Fire Island"},
    {world="Underworld",name="Inferno Island"},
    {world="Mystic Forest",name="Crystal Island"},
    {world="Heaven",name="Light Island"},
    {world="Heaven",name="Cloud Island",aliases={"Claud Island"}},
    {world="Heaven",name="Spirit Island"},
}
function L.matches(name,def)
    if L.norm(name)==L.norm(def.name) then return true end
    for _,alias in ipairs(def.aliases or {}) do
        if L.norm(name)==L.norm(alias) then return true end
    end
    return false
end
function L.hatchArgs(name,count)
    if count==3 then return table.pack("PurchaseEgg",name,"Multi") end
    return table.pack("PurchaseEgg",name)
end
function L.newLease()
    local self={generation=0,current=nil}
    function self:cancel()
        self.generation+=1
        self.current=nil
    end
    function self:begin(kind,character,saved)
        if self.current then return nil end
        self.generation+=1
        local ticket={generation=self.generation,kind=kind,character=character,saved=saved}
        self.current=ticket
        return ticket
    end
    function self:valid(ticket,character,alive)
        return alive and ticket~=nil and self.current==ticket
            and ticket.generation==self.generation and ticket.character==character
    end
    function self:finish(ticket)
        if self.current==ticket then self.current=nil end
    end
    return self
end
-- One request per group/snapshot. Never count shiny, locked, equipped or duplicate IDs.
function L.shinyGroups(pets,filter)
    local groups,seen={},{}
    for _,pet in ipairs(pets) do
        if pet.id~=nil and type(pet.name)=="string" and not seen[pet.id] then
            seen[pet.id]=true
            if pet.shiny==false and pet.locked==false and pet.equipped==false
                and (not filter or filter=="Все" or filter==pet.name) then
                local group=groups[pet.name] or {}
                groups[pet.name]=group
                group[#group+1]=pet.id
            end
        end
    end
    local out={}
    for name,ids in pairs(groups) do
        if #ids>=10 then
            table.sort(ids,function(a,b) return tostring(a)<tostring(b) end)
            local signature={}
            for _,id in ipairs(ids) do signature[#signature+1]=tostring(id) end
            out[#out+1]={name=name,id=ids[1],count=#ids,signature=table.concat(signature,"|")}
        end
    end
    table.sort(out,function(a,b) return a.name<b.name end)
    return out
end
function L.matchNext(memory,matched,first,count)
    if first then
        for i=1,count do
            if i~=first and not matched[i] and memory[first]~=nil and memory[i]==memory[first] then return i end
        end
        for i=1,count do if i~=first and not matched[i] and memory[i]==nil then return i end end
        for i=1,count do if i~=first and not matched[i] then return i end end
    else
        for i=1,count do
            if not matched[i] and memory[i]~=nil then
                for j=i+1,count do
                    if not matched[j] and memory[j]==memory[i] then return i end
                end
            end
        end
        for i=1,count do if not matched[i] and memory[i]==nil then return i end end
        for i=1,count do if not matched[i] then return i end end
    end
end
return L

end)()
local createRuntime=(function()
-- BGS Legacy 0.6.1: one scheduler, one movement owner, cancellable excursions.
return function(L)
    local Players=game:GetService("Players")
    local RS=game:GetService("ReplicatedStorage")
    local Run=game:GetService("RunService")
    local Input=game:GetService("UserInputService")
    if not game:IsLoaded() then game.Loaded:Wait() end
    local player=Players.LocalPlayer
    while not player do task.wait() player=Players.LocalPlayer end
    local playerGui=player:WaitForChild("PlayerGui",60)
    assert(playerGui,"BGS: PlayerGui недоступен")
    local env=_G
    if type(getgenv)=="function" then
        local ok,value=pcall(getgenv)
        if ok and type(value)=="table" then env=value end
    end
    local worlds,worldKey,registerWorld=L.newWorldCatalog()
    local S={alive=true,startupReady=false,version="0.6.1",errors=0,
        autoBubble=false,autoSell=false,autoCollect=false,autoHatch=false,
        autoChestRoute=false,autoShiny=false,autoPotions=false,autoMinigames=false,
        bubbleDelay=0.25,hatchDelay=1,sellCheckDelay=1,teleportHeights=5,
        collectMode="smart",currency="Все",farmWorld="Overworld",collectCurrentIslandOnly=true,
        teleportOnSelect=false,eventEggsOnly=false,hatchAnywhere=true,hatchCount=1,shinyFilter="Все",potionRecipe=1,
        minigame="Match The Pet",eggs={},islands={},pickups={},currencies={"Все"},
        selectedEgg=nil,selectedIsland=nil,collectIslandLock=nil,anchor=nil,
        status="Готово",bubbleStatus="Выключено",sellStatus="Выключено",collectStatus="Выключено",
        hatchStatus="Выбери яйцо",chestStatus="Выключено",shinyStatus="Выключено",
        potionStatus="Выключено",minigameStatus="Выключено",travelUntil=0,selling=false,
        lastBubble=-math.huge,lastHatch=-math.huge,lastSellCheck=0,nextScan=0,worlds=worlds,
        chestDefs=L.chests,chestEnabled={},chestResults={},confirmedChests=0,
    }
    for _,d in ipairs(L.chests) do S.chestEnabled[d.world.."/"..d.name]=true end
    local conns,threads={},{}
    local lease=L.newLease()
    local currentWorld=nil
    local function connect(signal,fn)
        local c=signal:Connect(fn) conns[#conns+1]=c return c
    end
    local function spawn(fn)
        local thread
        thread=coroutine.create(function()
            local ok,err=xpcall(fn,function(e) return tostring(e) end)
            threads[coroutine.running()]=nil
            if not ok and S.alive then S.errors+=1 S.status="Ошибка: "..err:sub(1,160) end
        end)
        threads[thread]=true task.spawn(thread) return thread
    end
    local function root()
        local c=player.Character return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function humanoid()
        local c=player.Character return c and c:FindFirstChildOfClass("Humanoid")
    end
    local function ready()
        local h=humanoid() return S.alive and root()~=nil and h~=nil and h.Health>0
    end
    local function stopMove()
        local r,h=root(),humanoid()
        if r and h then h:MoveTo(r.Position) h:Move(Vector3.zero,false) end
    end
    local function partOf(o)
        if not o then return nil end
        if o:IsA("BasePart") then return o end
        if o:IsA("Attachment") then return partOf(o.Parent) end
        if o:IsA("Model") and o.PrimaryPart then return o.PrimaryPart end
        return o:FindFirstChildWhichIsA("BasePart",true)
    end
    local function meta(o,names)
        if not o then return nil end
        for _,name in ipairs(names) do
            local v=o:GetAttribute(name)
            if v==nil then local child=o:FindFirstChild(name) if child and child:IsA("ValueBase") then v=child.Value end end
            if v~=nil then return v end
        end
        return nil
    end
    local modules={}
    local function path(base,names)
        for _,name in ipairs(names) do base=base and base:FindFirstChild(name) end
        return base
    end
    local function moduleAt(base,names)
        local obj=path(base,names)
        if not obj or not obj:IsA("ModuleScript") then return nil end
        if modules[obj]~=nil then return modules[obj] or nil end
        local ok,value=pcall(require,obj)
        modules[obj]=ok and value or false
        return ok and value or nil
    end
    local function itemModule(name)
        return moduleAt(RS,{"Assets","Modules","ItemDataService",name})
    end
    local function indices()
        return moduleAt(RS,{"Assets","Modules","Library","index"})
    end
    local remoteTimes={}
    local function budget()
        if not S.alive then return false end
        local now=os.clock()
        while remoteTimes[1] and now-remoteTimes[1]>=1 do table.remove(remoteTimes,1) end
        if #remoteTimes>=8 then return false end
        remoteTimes[#remoteTimes+1]=now return true
    end
    local function network(kind)
        local class=kind=="Function" and "RemoteFunction" or "RemoteEvent"
        local n=RS:FindFirstChild("NetworkRemote"..kind,true)
        if not n then n=path(RS,{"Shared","Framework","Network","Remote",kind}) end
        return n and n:IsA(class) and n or nil
    end
    local function send(action,...)
        local n=network("Event")
        if not n then return false,"NetworkRemoteEvent не найден" end
        if not budget() then return false,"Ожидание сети" end
        return pcall(n.FireServer,n,action,...)
    end
    -- At most one outstanding request. A timeout never starts more hung invocations.
    local invocation=nil
    local function invoke(action,args,valid)
        if invocation then return false,"Предыдущий ответ ещё не получен" end
        local n=network("Function")
        if not n then return false,"NetworkRemoteFunction не найден" end
        if not budget() then return false,"Ожидание сети" end
        local request={done=false}
        invocation=request
        spawn(function()
            request.result=table.pack(pcall(n.InvokeServer,n,action,table.unpack(args or {})))
            request.done=true
            if invocation==request then invocation=nil end
        end)
        local untilAt=os.clock()+5
        while not request.done and os.clock()<untilAt and S.alive and (not valid or valid()) do task.wait(0.05) end
        if not S.alive or (valid and not valid()) then return false,"Отменено" end
        if not request.done then return false,"Сервер не ответил за 5 сек" end
        return table.unpack(request.result,1,request.result.n)
    end
    local function discoverWorlds()
        for _,name in ipairs({"Worlds","FloatingIslands"}) do
            local container=workspace:FindFirstChild(name)
            if container then
                for _,node in ipairs(container:GetChildren()) do
                    if node:IsA("Model") or node:IsA("Folder") then
                        registerWorld(meta(node,{"World","WorldName"}) or node.Name,meta(node,{"Currency","CurrencyType"}))
                    end
                end
            end
        end
    end
    local function worldOf(o)
        local p=o
        while p and p~=workspace do
            local w=worldKey(meta(p,{"World","WorldName"})) or worldKey(p.Name)
            if w then return w end
            p=p.Parent
        end
    end
    local function childWorld(container,key)
        if not container then return nil end
        for _,o in ipairs(container:GetChildren()) do
            if (worldKey(meta(o,{"World","WorldName"})) or worldKey(o.Name))==key then return o end
        end
    end
    local function worldNode(key)
        return childWorld(workspace:FindFirstChild("Worlds"),key) or childWorld(workspace,key)
    end
    local function islandContainer(key)
        local floating=childWorld(workspace:FindFirstChild("FloatingIslands"),key)
        if floating then return floating end
        local w=worldNode(key)
        return w and (w:FindFirstChild("Islands") or w:FindFirstChild("FloatingIslands"))
    end
    local function islandNode(def)
        local container=islandContainer(def.world)
        if not container then return nil end
        for _,o in ipairs(container:GetChildren()) do if L.matches(o.Name,def) then return o end end
    end
    local function validObject(o) return o and o.Parent and o:IsDescendantOf(workspace) end
    local function surface(node)
        if not node then return nil end
        local collision=node:FindFirstChild("Collision")
        if collision and collision:IsA("BasePart") and collision.CanCollide then return collision end
        local best,score=nil,-1
        local candidates=node:IsA("BasePart") and {node} or node:GetDescendants()
        for _,p in ipairs(candidates) do
            if p:IsA("BasePart") and p.CanCollide and math.abs(p.CFrame.UpVector.Y)>0.7 then
                local bad=false local parent=p
                while parent and parent~=node do
                    local name=L.norm(parent.Name)
                    if name:find("portal",1,true) or name:find("chest",1,true) or name:find("tree",1,true)
                        or name:find("decor",1,true) or name:find("mountain",1,true) then bad=true break end
                    parent=parent.Parent
                end
                local area=p.Size.X*p.Size.Z
                if not bad and p.Size.X>=6 and p.Size.Z>=6 and area>score then best=p score=area end
            end
        end
        return best
    end
    local function feetHeight()
        local h,r=humanoid(),root()
        return h and r and math.max(2.5,h.HipHeight+r.Size.Y/2+0.5) or 3.5
    end
    local function landPoint(part,near)
        if not validObject(part) then return nil end
        local pos=near or part.Position
        local ray=RaycastParams.new()
        ray.FilterType=Enum.RaycastFilterType.Include ray.FilterDescendantsInstances={part}
        local hit=workspace:Raycast(Vector3.new(pos.X,part.Position.Y+part.Size.Magnitude+12,pos.Z),Vector3.new(0,-part.Size.Magnitude*2-24,0),ray)
        if hit and hit.Normal.Y>0.6 then return hit.Position+Vector3.new(0,feetHeight(),0) end
        return nil
    end
    local function standingPoint(pos,exclude)
        local ray=RaycastParams.new()
        ray.FilterType=Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances=exclude and {player.Character,exclude} or {player.Character}
        pcall(function() ray.RespectCanCollide=true end)
        local hit=workspace:Raycast(pos+Vector3.new(0,16,0),Vector3.new(0,-80,0),ray)
        if hit and hit.Normal.Y>0.6 and hit.Instance.CanCollide then return hit.Position+Vector3.new(0,feetHeight(),0) end
    end
    local function teleport(cf)
        if not ready() then return false end
        local r,h=root(),humanoid() stopMove() h.Sit=false
        r.CFrame=typeof(cf)=="CFrame" and cf or CFrame.new(cf)*(r.CFrame-r.Position)
        r.AssemblyLinearVelocity=Vector3.zero r.AssemblyAngularVelocity=Vector3.zero
        return true
    end
    local function detectWorld()
        local attribute=worldKey(meta(player,{"World","CurrentWorld"}))
        if attribute then return attribute end
        local r=root() local best,dist=nil,math.huge
        if r then
            for _,entry in ipairs(S.islands) do
                if validObject(entry.part) then local d=(r.Position-entry.part.Position).Magnitude if d<dist then best=entry.world dist=d end end
            end
        end
        return best or currentWorld or "Overworld"
    end
    local function validTicket(t) return lease:valid(t,player.Character,ready()) end
    local function waitTicket(t,seconds)
        local deadline=os.clock()+seconds
        repeat if not validTicket(t) then return false end task.wait(0.05) until os.clock()>=deadline
        return validTicket(t)
    end
    local function switchWorld(key,t)
        if not validTicket(t) then return false end
        if currentWorld==key then return true end
        local service=moduleAt(playerGui,{"ScreenGui","ClientScript","Modules","WorldService"})
        if not validTicket(t) then return false end
        if type(service)=="table" and type(service.SetWorld)=="function" then
            local ok,answer=pcall(service.SetWorld,service,key)
            if not validTicket(t) then return false end
            if not ok or answer==false then S.status="Мир недоступен: "..key return false end
            if not waitTicket(t,0.7) then return false end
            local attr=worldKey(meta(player,{"World","CurrentWorld"}))
            if attr and attr~=key then S.status="Переход в мир отклонён: "..key return false end
            if not worldNode(key) and not islandContainer(key) then S.status="Мир ещё не загрузился: "..key return false end
            currentWorld=key
            return true
        end
        -- A local move is only possible for geometry actually replicated to this client.
        local node=worldNode(key)
        local floor=surface(node)
        local pos=floor and landPoint(floor)
        if not pos then S.status="Не найден переход в "..key return false end
        if not validTicket(t) then return false end
        teleport(pos) currentWorld=key
        return waitTicket(t,0.5)
    end
    local target=nil
    local function clearTarget() target=nil S.target=nil stopMove() end
    local activeJob=nil
    local function cancelMovement()
        lease:cancel()
        if activeJob and coroutine.status(activeJob)~="dead" and activeJob~=coroutine.running() then pcall(task.cancel,activeJob) threads[activeJob]=nil end
        activeJob=nil S.selling=false clearTarget()
    end
    local function excursion(kind,restore,fn,manual)
        if not ready() then S.status="Жду персонажа" return false end
        if manual then cancelMovement() end
        if lease.current then return false end
        currentWorld=currentWorld or detectWorld()
        local saved={cf=root().CFrame,world=currentWorld,anchor=S.anchor,lock=S.collectIslandLock}
        local t=lease:begin(kind,player.Character,saved)
        if not t then return false end
        clearTarget()
        activeJob=spawn(function()
            local ok,err=pcall(fn,t)
            if restore and validTicket(t) then
                local returned=switchWorld(saved.world,t)
                if returned and validTicket(t) then
                    teleport(saved.cf)
                    S.anchor=saved.anchor S.collectIslandLock=saved.lock
                    S.travelUntil=os.clock()+0.6
                elseif validTicket(t) then S.status="Не удалось вернуться в "..saved.world end
            end
            if validTicket(t) then
                lease:finish(t) S.selling=false
                if not ok then S.errors+=1 S.status="Ошибка "..kind..": "..tostring(err):sub(1,100) end
            end
        end)
        return true
    end
    local function goIsland(entry,t)
        if not entry or not switchWorld(entry.world,t) then return false end
        local node=entry.def and islandNode(entry.def) or entry.object
        if not validObject(node) then S.status="Остров ещё не загружен: "..entry.name return false end
        local floor=surface(node)
        if not floor then S.status="Поверхность острова не найдена: "..entry.name return false end
        -- Native checkpoint request, then one verified local landing if needed; no delayed callback.
        if entry.def and send("TeleportToCheckpoint",node.Name) then if not waitTicket(t,0.6) then return false end end
        if not validTicket(t) then return false end
        local pos=landPoint(floor)
        if not pos then S.status="Нет безопасной поверхности: "..entry.name return false end
        if not teleport(pos) or not waitTicket(t,0.4) then return false end
        if (root().Position-pos).Magnitude>20 then S.status="Игра вернула персонажа с острова: "..entry.name return false end
        entry.object=node entry.part=floor entry.y=floor.Position.Y
        return true
    end
    local currencyMap={coin="Coins",coins="Coins",gem="Gems",gems="Gems",candy="Candy",block="Blocks",blocks="Blocks",shell="Shells",shells="Shells",pearl="Pearls",pearls="Pearls",star="Stars",stars="Stars",magma="Magma",crystal="Crystals",crystals="Crystals"}
    local function rememberCurrency(value)
        if type(value)=="string" and value~="" then currencyMap[L.norm(value)]=value end
    end
    local function currencyOf(o)
        local p=o
        while p and p~=workspace do
            local value=meta(p,{"Currency","CurrencyType","PickupType"})
            if value then return currencyMap[L.norm(value)] or tostring(value) end
            local name=L.norm(p.Name):gsub("%d+$","")
            if currencyMap[name] then return currencyMap[name] end
            p=p.Parent
        end
        return "Другое"
    end
    local function isGemCurrency(v) return v=="Gems" or v=="Crystals" end
    local pickupByPart={}
    local function pickupContainer(p)
        local n=p.Parent
        while n and n~=workspace do if L.norm(n.Name)=="pickups" then return n end n=n.Parent end
    end
    local function pickupOwner(p,container)
        local n=p.Parent
        while n and n~=container do
            if n:IsA("Model") then return n end
            n=n.Parent
        end
        return p
    end
    local function addPart(p)
        if not p:IsA("BasePart") or pickupByPart[p] then return end
        local container=pickupContainer(p)
        if not container then return end
        pickupByPart[p]={object=pickupOwner(p,container),part=p,currency=currencyOf(p),world=worldOf(p)}
    end
    local skipped=setmetatable({},{__mode="k"})
    local nextCompact=0
    local function compactPickups()
        local byOwner={} local currencies={['Все']=true}
        for p,item in pairs(pickupByPart) do
            if not validObject(p) or not pickupContainer(p) then pickupByPart[p]=nil
            else
                item.object=pickupOwner(p,pickupContainer(p))
                item.currency=currencyOf(p) item.world=worldOf(p)
                local score=(p:FindFirstChild("TouchInterest") and 1000 or 0)+(p.CanTouch and 100 or 0)
                if L.norm(p.Name)=="hitbox" then score+=500 end
                local old=byOwner[item.object]
                if not old or score>old.score then item.score=score byOwner[item.object]=item end
            end
        end
        S.pickups={} S.currencies={}
        for _,item in pairs(byOwner) do S.pickups[#S.pickups+1]=item currencies[item.currency]=true end
        for name in pairs(currencies) do S.currencies[#S.currencies+1]=name end
        table.sort(S.currencies,function(a,b) if a==b then return false elseif a=="Все" then return true elseif b=="Все" then return false end return a<b end)
    end
    local catalogDirty=true
    local areaByNode=setmetatable({},{__mode="k"})
    local function eventArea(node)
        if not node or not node.Parent or not (node:IsA("Model") or node:IsA("Folder")) then return false end
        local name,parent=L.norm(node.Name),L.norm(node.Parent.Name)
        return node:GetAttribute("IsEvent")==true or node:GetAttribute("AreaType")=="Event"
            or parent=="events" or parent=="eventareas"
            or name=="autumn" or name=="autumnarea" or name=="autumnevent"
            or name=="fall" or name=="fallarea" or name=="fallevent"
    end
    local function areaOf(node)
        while node and node~=workspace do
            if areaByNode[node] then return areaByNode[node] end
            node=node.Parent
        end
    end
    local function mapEntry(node,name,world,order,def)
        local floor=surface(node)
        return {object=node,part=floor,name=name,world=world,order=order,def=def,
            y=floor and floor.Position.Y or 0,kind=(world=="Heaven" or world=="Mystic Forest") and "gem" or "normal"}
    end
    local function refreshCatalog()
        discoverWorlds()
        local nodes=workspace:GetDescendants()
        local islands,seen,seenObjects={},{},{}
        areaByNode=setmetatable({},{__mode="k"})
        for wi,w in ipairs(S.worlds) do
            local base=worldNode(w.key)
            if base then islands[#islands+1]=mapEntry(base,"Спавн",w.key,wi*100,nil) seenObjects[base]=true end
            local container=islandContainer(w.key)
            if container then
                for _,node in ipairs(container:GetChildren()) do
                    local entry=mapEntry(node,node.Name,w.key,wi*100+1,{world=w.key,name=node.Name})
                    if entry.part then islands[#islands+1]=entry seen[w.key.."/"..L.norm(node.Name)]=true seenObjects[node]=true end
                end
            end
        end
        -- An event area inside Overworld is a local destination, not a guessed SetWorld argument.
        for _,node in ipairs(nodes) do
            if eventArea(node) and not seenObjects[node] then
                local world=worldOf(node) or "Overworld"
                local entry=mapEntry(node,node.Name,world,900,nil)
                if entry.part then
                    entry.event=true islands[#islands+1]=entry seenObjects[node]=true areaByNode[node]=entry
                end
            elseif eventArea(node) then
                areaByNode[node]={name=node.Name,world=worldOf(node) or "Overworld",event=true}
            end
        end
        -- Show all requested destinations even if the corresponding world is unloaded.
        for i,def in ipairs(L.chests) do
            local node=islandNode(def)
            local key=def.world.."/"..L.norm(node and node.Name or def.name)
            if not seen[key] then islands[#islands+1]=mapEntry(node,def.name,def.world,1000+i,def) end
        end
        table.sort(islands,function(a,b)
            if a.world~=b.world then
                local ai,bi=99,99 for i,w in ipairs(S.worlds) do if a.world==w.key then ai=i end if b.world==w.key then bi=i end end
                return ai<bi
            end
            if math.abs(a.y-b.y)>1 then return a.y<b.y end
            return a.name<b.name
        end)
        for i,e in ipairs(islands) do e.order=i end
        S.islands=islands
        local eggs,byKey={},{}
        local eggData=itemModule("EggModule")
        if type(eggData)=="table" then
            for _,data in pairs(eggData) do local currency=L.eggCost(data) rememberCurrency(currency) end
        end
        local function eggFolder(node)
            while node and node~=workspace do
                if L.norm(node.Name)=="eggs" then return node end
                node=node.Parent
            end
        end
        local function eggIdentity(node)
            local explicit=meta(node,{"EggName"})
            if type(explicit)=="string" and explicit~="" then return explicit end
            if type(eggData)=="table" and type(eggData[node.Name])=="table" then return node.Name end
            if L.norm(node.Name):match("egg$") then return node.Name end
        end
        local function addEgg(node,hotkey)
            if not node:IsA("Model") and not node:IsA("BasePart") then return end
            local name=eggIdentity(node)
            if not name then return end
            local hot=hotkey or node:FindFirstChild("Hotkey",true)
            local folder=eggFolder(node.Parent)
            -- A decorative model named Egg outside an egg folder is not a hatch target.
            if not hot and not folder then return end
            local part=partOf(hot) or partOf(node)
            if not part then return end
            local data=type(eggData)=="table" and eggData[name] or nil
            local area=areaOf(node)
            -- Use the physical world or replicated egg metadata, never the player's current world.
            local world=worldOf(node) or (type(data)=="table" and worldKey(data.World))
                or (area and area.world) or "Overworld"
            local key=world.."/"..name
            if byKey[key] then return end
            local currency=meta(node,{"Currency","CurrencyType"})
            local price=tonumber(meta(node,{"Price","Cost","EggPrice"}))
            local dataCurrency,dataPrice=L.eggCost(data)
            currency=currency or dataCurrency price=price or dataPrice
            rememberCurrency(currency)
            local event=area~=nil or node:GetAttribute("IsEvent")==true
                or (type(data)=="table" and (data.Limited==true or data.Event~=nil and data.Event~=false))
            local entry={object=node,part=part,name=name,world=world,y=part.Position.Y,currency=currency,price=price,
                event=event,area=area and area.name,available=true,kind=isGemCurrency(currency) and "gem" or "normal"}
            byKey[key]=entry eggs[#eggs+1]=entry
        end
        -- One workspace snapshot, including nested event folders and relocated Hotkeys.
        -- Only metadata / the existing EggModule supplies protocol names and prices.
        for _,node in ipairs(nodes) do
            if node.Name=="Hotkey" then
                local owner=node.Parent
                while owner and owner~=workspace do
                    if (owner:IsA("Model") or owner:IsA("BasePart")) and eggIdentity(owner) then addEgg(owner,node) break end
                    owner=owner.Parent
                end
            elseif (node:IsA("Model") or node:IsA("BasePart")) and eggFolder(node.Parent) then
                addEgg(node)
            end
        end
        table.sort(eggs,function(a,b)
            if a.world~=b.world then return a.world<b.world end
            if math.abs(a.y-b.y)>1 then return a.y<b.y end
            return a.name<b.name
        end)
        S.eggs=eggs
        if S.selectedEgg then
            local old=S.selectedEgg
            local replacement=byKey[old.world.."/"..old.name]
            if replacement then S.selectedEgg=replacement
            else old.available=false old.object=nil old.part=nil S.hatchStatus="Выбранное яйцо больше не загружено" end
        end
        if S.selectedIsland then
            local old=S.selectedIsland
            for _,entry in ipairs(islands) do
                if entry.world==old.world and entry.name==old.name then S.selectedIsland=entry break end
            end
        end
        catalogDirty=false
    end
    function S:Refresh()
        refreshCatalog() compactPickups() self.nextScan=os.clock()+10
        if not lease.current and ready() then currentWorld=detectWorld() end
    end
    local function nearestIsland(pos)
        local best,dist=nil,math.huge
        for _,e in ipairs(S.islands) do
            if validObject(e.part) then
                local offset=e.part.CFrame:PointToObjectSpace(pos)
                local dx=math.max(0,math.abs(offset.X)-e.part.Size.X/2)
                local dz=math.max(0,math.abs(offset.Z)-e.part.Size.Z/2)
                local dy=math.abs(offset.Y-e.part.Size.Y/2)
                local distance=math.sqrt(dx*dx+dz*dz)+dy*2
                if distance<dist then best=e dist=distance end
            end
        end
        return dist<500 and best or nil
    end
    local function inFarm(item)
        local part=item.part
        local touchHitbox=part:FindFirstChild("TouchInterest")~=nil or L.norm(part.Name)=="hitbox"
        if not validObject(part) or not validObject(item.object) or (part.Transparency>=1 and not touchHitbox)
            or item.object:GetAttribute("Collected")==true or not part.CanTouch then return false end
        if S.currency~="Все" and item.currency~=S.currency then return false end
        if os.clock()<(skipped[item.object] or 0) then return false end
        if S.collectCurrentIslandOnly then
            local island=S.collectIslandLock
            if island and validObject(island.part) then
                local p=island.part local offset=p.CFrame:PointToObjectSpace(part.Position)
                return math.abs(offset.X)<=p.Size.X/2+65 and math.abs(offset.Z)<=p.Size.Z/2+65
                    and math.abs(offset.Y-p.Size.Y/2)<=70
            end
            local anchor=S.anchor
            if not anchor then return false end
            local delta=part.Position-anchor
            return Vector2.new(delta.X,delta.Z).Magnitude<=250 and math.abs(delta.Y)<=70
        end
        if item.world then return item.world==S.farmWorld end
        local island=nearestIsland(part.Position)
        if island then return island.world==S.farmWorld end
        -- Unlabelled streamed drops belong to the active world only within a local radius.
        return currentWorld==S.farmWorld and root()~=nil and (root().Position-part.Position).Magnitude<500
    end
    local function collectStep(now)
        if lease.current or now<S.travelUntil then return end
        if not S.collectCurrentIslandOnly and currentWorld~=S.farmWorld then
            S.collectStatus="Нажми «В мир фарма», чтобы перейти" return
        end
        if target and not inFarm(target.item) then clearTarget() end
        if not target then
            local nearest,dist=nil,math.huge
            for _,item in ipairs(S.pickups) do
                if inFarm(item) then local d=(item.part.Position-root().Position).Magnitude if d<dist then nearest=item dist=d end end
            end
            if not nearest then S.collectStatus="Жду монеты · "..(S.collectCurrentIslandOnly and "текущий остров" or S.farmWorld) stopMove() return end
            local delta=nearest.part.Position-root().Position
            local dir=Vector3.new(delta.X,0,delta.Z)
            if dir.Magnitude<0.1 then dir=Vector3.new(1,0,0) end
            target={item=nearest,started=now,progress=now,best=dist,dir=dir.Unit,nextMove=0,teleported=false}
            S.target=nearest
        end
        local item=target.item local r,h=root(),humanoid()
        local d=(item.part.Position-r.Position).Magnitude
        if d<target.best-0.4 then target.best=d target.progress=now end
        if now-target.started>5 then skipped[item.object]=now+12 clearTarget() S.collectStatus="Пропускаю неподбираемую цель" return end
        if now<target.nextMove then return end
        target.nextMove=now+0.25
        local height=math.max(5,r.Size.Y+2*h.HipHeight)
        local stalled=now-target.progress>1.2
        local far=d>S.teleportHeights*height
        local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances={player.Character,item.object}
        pcall(function() ray.RespectCanCollide=true end)
        local obstacle=d>10 and workspace:Raycast(r.Position,item.part.Position-r.Position,ray)
        local useTP=S.collectMode=="teleport" or far or stalled or obstacle~=nil
        if useTP and d>9 and not target.teleported then
            local pos=standingPoint(item.part.Position-target.dir*5,item.object)
            if pos then teleport(pos) target.teleported=true target.progress=now end
        end
        -- Fixed crossing direction: never flip to the near side as distance decreases.
        h:MoveTo(item.part.Position+target.dir*6)
        if d<=9 and type(firetouchinterest)=="function" then
            pcall(firetouchinterest,r,item.part,0) pcall(firetouchinterest,r,item.part,1)
        end
        if stalled then h.Jump=true end
        S.collectStatus=item.currency.." · "..math.floor(d).." studs"
    end
    function S:SetFarmWorld(key)
        if not worldKey(key) then return false end
        self.farmWorld=worldKey(key) self.collectCurrentIslandOnly=false
        return self:GoFarmWorld()
    end
    function S:GoFarmWorld()
        local key=self.farmWorld
        return excursion("world",false,function(t)
            if switchWorld(key,t) and validTicket(t) then
                self:Refresh() self.anchor=root().Position self.collectIslandLock=nil
                self.travelUntil=os.clock()+0.7 self.status="Мир фарма: "..key
            end
        end,true)
    end
    function S:SelectIsland(entry) self.selectedIsland=entry end
    function S:GoIsland(entry)
        entry=entry or self.selectedIsland
        if not entry then self.status="Выбери остров" return false end
        return excursion("island",false,function(t)
            if goIsland(entry,t) and validTicket(t) then
                self.selectedIsland=entry self.collectIslandLock=entry self.anchor=root().Position
                self.farmWorld=entry.world self.travelUntil=os.clock()+0.7 self.status="ТП: "..entry.name
            end
        end,true)
    end
    function S:SelectEgg(entry)
        if not entry then return false end
        self.selectedEgg=entry self.lastHatch=-math.huge self.hatchStatus="Выбрано: "..entry.name
        if self.teleportOnSelect then return self:GoToEgg() end
        return true
    end
    function S:GoToEgg()
        local e=self.selectedEgg if not e then self.status="Выбери яйцо" return false end
        return excursion("egg",false,function(t)
            if not switchWorld(e.world,t) then return end
            self:Refresh() e=self.selectedEgg
            if not e or not validObject(e.part) or not validTicket(t) then self.status="Яйцо не загружено" return end
            local pos=standingPoint(e.part.Position+Vector3.new(5,0,0),e.object)
            if pos then teleport(pos) self.travelUntil=os.clock()+1 self.status="У яйца: "..e.name end
        end,true)
    end
    local hatchPending=nil
    local inventory=nil local inventoryAt=0
    local function dataField(data,key)
        if type(data)~="table" then return nil end
        if data[key]~=nil then return data[key] end
        local index=indices()
        return type(index)=="table" and index[key] and data[index[key]] or nil
    end
    function S:HatchOnce(automatic)
        local now=os.clock() local e=self.selectedEgg
        if not ready() or lease.current or now<self.travelUntil or hatchPending then return false end
        if not e then self.hatchStatus="Выбери яйцо" return false end
        if e.available==false or not validObject(e.object) then
            local known=itemModule("EggModule")
            if not self.hatchAnywhere or type(known)~="table" or type(known[e.name])~="table" then
                self.hatchStatus="Яйцо недоступно · жду появления на карте" return false
            end
        end
        if network("Function") and (not inventory or now-inventoryAt>8) then
            if not automatic then self.manualHatchRequested=true end
            self.hatchStatus="Жду данные инвентаря перед открытием" return false
        end
        if not self.hatchAnywhere and (not validObject(e.part) or (root().Position-e.part.Position).Magnitude>16) then
            self.hatchStatus="Подойди к яйцу или включи открытие из любого места" return false
        end
        if L.norm(e.currency):find("robux",1,true) then self.hatchStatus="Robux-яйцо открывай вручную" return false end
        if now-self.lastHatch<math.max(0.65,self.hatchDelay) then return false end
        local args=L.hatchArgs(e.name,self.hatchCount)
        local ok,err=send(table.unpack(args,1,args.n))
        if ok then
            self.manualHatchRequested=false
            self.lastHatch=now
            hatchPending={at=now,before=tonumber(dataField(inventory,"EGGS_OPENED")),count=self.hatchCount}
            self.hatchStatus="Запрос ×"..self.hatchCount.." · "..e.name
        else self.hatchStatus=tostring(err) end
        return ok
    end
    local function chestTarget(def)
        local node=islandNode(def) if not node then return nil end
        local chest=node:FindFirstChild("Chest") or node:FindFirstChild("Chest",true)
        if not chest then return nil end
        local regen=chest:FindFirstChild("Regen",true)
        local prompt=chest:FindFirstChildWhichIsA("ProximityPrompt",true)
        local fast=chest:FindFirstChild("FastSpawn")
        local p=fast and partOf(fast:FindFirstChild("Ignore"))
        p=p or partOf(prompt) or partOf(chest:FindFirstChild("Hitbox",true)) or partOf(chest)
        if not p then return nil end
        return {node=node,chest=chest,part=p,prompt=prompt,regen=regen,def=def}
    end
    local function regenerating(targetChest)
        if not targetChest or not validObject(targetChest.chest) then return nil end
        local regen=targetChest.regen
        if regen and regen.Parent then
            local ok,value=pcall(function() return regen.Enabled end)
            if ok and type(value)=="boolean" then return value end
        end
        local available=meta(targetChest.chest,{"Ready","Available","CanClaim"})
        if type(available)=="boolean" then return not available end
        local remaining=tonumber(meta(targetChest.chest,{"CooldownRemaining"}))
        if remaining then return remaining>0 end
        return nil
    end
    local chestDue={} local chestCursor=0 local nextChest=0
    local function collectChest(def,t)
        if not switchWorld(def.world,t) then return end
        S:Refresh()
        local targetChest=chestTarget(def)
        if not targetChest then S.chestStatus="Сундук не загружен: "..def.name return end
        local key=def.world.."/"..def.name
        if regenerating(targetChest)==true then S.chestResults[key]="Перезарядка" return end
        local entry=mapEntry(targetChest.node,def.name,def.world,1,def)
        if not S.autoChestRoute then return end
        if not goIsland(entry,t) then S.chestStatus="Не удалось попасть на "..def.name return end
        if not validTicket(t) then return end
        local p=targetChest.part
        local point=standingPoint(p.Position+Vector3.new(3,0,0),targetChest.chest)
        if not point then point=landPoint(entry.part,p.Position) end
        if not point or (point-p.Position).Magnitude>30 then S.chestStatus="Нет подхода к сундуку: "..def.name return end
        teleport(point)
        local before=regenerating(targetChest)
        local prompt=targetChest.prompt
        local promptWasEnabled=prompt and prompt.Enabled
        for attempt=1,3 do
            if not validTicket(t) or not S.autoChestRoute then return end
            if not validObject(p) then break end
            S.chestStatus="Забираю: "..def.name.." · "..attempt.."/3"
            if (root().Position-p.Position).Magnitude<=30 then
                send("CollectChestReward",targetChest.node.Name)
                if prompt and prompt.Parent and prompt.Enabled
                    and (root().Position-p.Position).Magnitude<=prompt.MaxActivationDistance then
                    if type(fireproximityprompt)=="function" then pcall(fireproximityprompt,prompt) end
                    local held=pcall(function() prompt:InputHoldBegin() end)
                    if held then
                        local hold=math.clamp(tonumber(prompt.HoldDuration) or 0,0,10)
                        local valid=waitTicket(t,hold+0.1)
                        pcall(function() prompt:InputHoldEnd() end)
                        if not valid then return end
                    end
                elseif p.CanTouch then
                    humanoid():MoveTo(p.Position)
                    if type(firetouchinterest)=="function" then pcall(firetouchinterest,root(),p,0) pcall(firetouchinterest,root(),p,1) end
                end
            end
            if not waitTicket(t,1) then return end
            local after=regenerating(targetChest)
            local confirmed=(before==false and after==true)
                or (promptWasEnabled and prompt and prompt.Parent and not prompt.Enabled)
            if confirmed then
                S.confirmedChests+=1 S.chestStatus="Награда получена: "..def.name
                S.chestResults[key]="Получено" chestDue[key]=os.clock()+60
                return
            end
        end
        S.chestResults[key]="Нет подтверждения" S.chestStatus="Сервер не подтвердил: "..def.name
        chestDue[key]=os.clock()+120
    end
    local function chestStep(now)
        if not S.autoChestRoute or lease.current or now<nextChest or now<S.travelUntil then return end
        nextChest=now+3
        for _=1,#L.chests do
            chestCursor=chestCursor%#L.chests+1
            local def=L.chests[chestCursor] local key=def.world.."/"..def.name
            if S.chestEnabled[key] and now>=(chestDue[key] or 0) then
                local chest=chestTarget(def)
                if chest and regenerating(chest)==true then
                    chestDue[key]=now+30 S.chestResults[key]="Перезарядка"
                else
                    chestDue[key]=now+180
                    excursion("chest",true,function(t)
                        local ok,err=pcall(collectChest,def,t)
                        nextChest=os.clock()+12
                        if not ok then error(err,0) end
                    end,false)
                    return
                end
            end
        end
        S.chestStatus="Жду готовые сундуки · получено "..S.confirmedChests
    end
    local function parseCompact(text)
        local str=tostring(text):lower():gsub(",",""):gsub("%s","")
        local value,suffix=str:match("([%d%.]+)(%a*)")
        local n=tonumber(value) if not n then return nil end
        local factors={k=1e3,m=1e6,b=1e9,t=1e12,qa=1e15,qi=1e18,sx=1e21,sp=1e24,oc=1e27,no=1e30}
        return n*(factors[suffix] or 1)
    end
    local function bubbleRatio()
        local label=path(playerGui,{"ScreenGui","StatsFrame","Bubble","Amount"})
        if not label or not label:IsA("TextLabel") then return nil end
        local a,b=label.Text:match("([^/]+)/([^/]+)")
        local value,limit=parseCompact(a),parseCompact(b)
        if value and limit and limit>0 then return value/limit,value end
    end
    local nextSell=0
    function S:SellNow()
        if lease.current then return false end
        return excursion("sell",true,function(t)
            self.selling=true
            local _,before=bubbleRatio()
            send("Teleport","Sell")
            if not waitTicket(t,0.5) then return end
            send("SellBubble","Sell")
            if not waitTicket(t,0.6) then return end
            local _,after=bubbleRatio()
            self.sellStatus=before and after and after<before and "Продажа подтверждена" or "Продажа: нет подтверждения"
            nextSell=os.clock()+5
        end,false)
    end
    local dataBusy=false local nextData=0 local dataGeneration=0
    local shinyPending={} local nextShiny=0
    local function petList()
        local raw=dataField(inventory,"PETS")
        if type(raw)~="table" then return nil end
        local out={}
        for _,p in pairs(raw) do
            if type(p)=="table" then
                if p.id~=nil or p.Id~=nil then
                    local function boolean(a,b) if type(a)=="boolean" then return a end if type(b)=="boolean" then return b end return nil end
                    out[#out+1]={id=p.id or p.Id,name=p.name or p.Name,
                        shiny=boolean(p.shiny,p.Shiny),locked=boolean(p.locked,p.Locked),equipped=boolean(p.equipped,p.Equipped)}
                elseif type(p[2])=="string" and (p[6]==nil or type(p[6])=="boolean")
                    and (p[7]==nil or type(p[7])=="boolean") and type(p[8])=="boolean" then
                    out[#out+1]={id=p[1],name=p[2],equipped=p[6]==true,locked=p[7]==true,shiny=p[8]}
                end
            end
        end
        return out
    end
    local function shinyStep(now)
        if not S.autoShiny or now<nextShiny or not inventory or now-inventoryAt>8 then return end
        nextShiny=now+2
        local pets=petList()
        if not pets then S.shinyStatus="Данные инвентаря не найдены" return end
        local groups=L.shinyGroups(pets,S.shinyFilter)
        S.shinyStatus=#groups>0 and "Есть группы по 10" or "Жду 10 одинаковых обычных петов"
        for _,group in ipairs(groups) do
            if shinyPending[group.name]~=group.signature then
                local ok,err=send("MakePetShiny",group.id)
                if ok then
                    shinyPending[group.name]=group.signature S.shinyStatus="Скрещивание: "..group.name.." · жду обновления"
                    nextData=0
                else S.shinyStatus=tostring(err) end
                return
            end
        end
    end
    S.potionNames={"+1 Level","+1 Enchant","Shadow Potion","Max Level","Max Enchant","Max Shadow","Potion of Money","Potion of Worlds","Potion of Bubbles"}
    local potionPending={} local nextPotion=0
    local function potionStep(now)
        if not S.autoPotions or now<nextPotion then return end
        nextPotion=now+2
        local brewing=path(playerGui,{"ScreenGui","BrewingFrame","Brewing"})
        if not brewing then S.potionStatus="Открой лабораторию один раз для загрузки слотов" return end
        for i=1,3 do
            local slot=brewing:FindFirstChild("Brew"..i)
            if slot then
                local empty=slot:FindFirstChild("Empty")
                local active=slot:FindFirstChild("Brewing")
                local skip=active and active:FindFirstChild("Skip")
                local item=active and active:FindFirstChild("ItemName")
                local state=empty and empty.Visible and "empty" or (active and active.Visible and skip and not skip.Visible and "ready" or "brewing")
                local pending=potionPending[i]
                if pending and (pending.state~=state or (item and pending.name~=item.Text)) then potionPending[i]=nil pending=nil end
                if not pending or now-pending.at>=30 then
                    if state=="empty" then
                        local ok=send("BrewPotion",S.potionRecipe)
                        if ok then potionPending[i]={state=state,name=item and item.Text,at=now} S.potionStatus="Заказ: "..S.potionNames[S.potionRecipe] end
                        return
                    elseif state=="ready" then
                        local ok=send("ClaimPotion",i)
                        if ok then potionPending[i]={state=state,name=item and item.Text,at=now} S.potionStatus="Забираю зелье · слот "..i end
                        return
                    end
                end
            end
        end
        S.potionStatus="Жду приготовления / свободный слот"
    end
    local miniGeneration=0 local miniBusy=false local nextMini=0
    local memory,matched,first={},{},nil
    local miniTurns=0 local doggyStage=1
    local function minigameStep(now)
        if not S.autoMinigames or miniBusy or lease.current or now<nextMini then return end
        nextMini=now+1.5
        local mode=S.minigame local generation=miniGeneration
        if mode=="Spin To Win" then
            local data=itemModule("SpinToWinModule")
            local used=dataField(inventory,"SPIN_TO_WIN")
            if type(data)~="table" or type(data.GetHalfDay)~="function" or type(used)~="number" then S.minigameStatus="Данные Spin To Win не загружены" return end
            local ok,period=pcall(data.GetHalfDay,data)
            if ok and type(period)=="number" and used<period then
                local sent=send("SpinToWin") S.minigameStatus=sent and "Запрос бесплатного вращения" or "Ожидание сети"
                nextMini=now+20
            else S.minigameStatus="Вращение на перезарядке" nextMini=now+20 end
        elseif mode=="Doggy Jump" then
            -- Observed BGS command; each stage is tried once per cycle, never reported as a win without game feedback.
            if not workspace:FindFirstChild("DoggyJump",true) and not playerGui:FindFirstChild("DoggyJumpFrame",true) then
                S.minigameStatus="Doggy Jump не найден в текущем мире" nextMini=now+15 return
            end
            local sent=send("DoggyJumpWin",doggyStage)
            if sent then S.minigameStatus="Doggy Jump · запрос этапа "..doggyStage doggyStage=doggyStage%4+1 end
            nextMini=now+(doggyStage==1 and 60 or 3)
        else
            if not workspace:FindFirstChild("MatchThePet",true) and not playerGui:FindFirstChild("MatchThePetFrame",true) then
                S.minigameStatus="Match The Pet не найден · открой мини-игру" nextMini=now+15 return
            end
            local index=L.matchNext(memory,matched,first,18)
            if not index or miniTurns>90 then
                memory={} matched={} first=nil miniTurns=0 nextMini=now+60 S.minigameStatus="Жду следующий раунд" return
            end
            miniBusy=true
            spawn(function()
                local function valid() return S.alive and S.autoMinigames and miniGeneration==generation end
                local ok,pet,status=invoke("MatchThePet",{index},valid)
                if valid() then
                    if ok and type(status)=="string" then
                        miniTurns+=1
                        if pet~=nil and (type(pet)=="number" or type(pet)=="string") then memory[index]=pet end
                        if status=="first" then first=index
                        elseif status=="match" then
                            if first then matched[first]=true end matched[index]=true first=nil
                        elseif status=="complete" then
                            S.minigameStatus="Match The Pet: раунд завершён"
                            memory={} matched={} first=nil miniTurns=0 nextMini=os.clock()+60
                        else first=nil nextMini=os.clock()+2.5 end
                        if status~="complete" then S.minigameStatus="Match The Pet · карточка "..index.." · "..status end
                    else
                        S.minigameStatus=ok and "Мини-игра не приняла ход" or tostring(pet)
                        nextMini=os.clock()+15
                    end
                    miniBusy=false
                end
            end)
        end
    end
    local function updateData(now)
        local needed=S.autoShiny or S.autoHatch or S.autoMinigames or hatchPending or S.manualHatchRequested
        if not needed or dataBusy or now<nextData then return end
        nextData=now+2 dataBusy=true
        local gen=dataGeneration
        spawn(function()
            local function valid() return S.alive and dataGeneration==gen end
            local ok,data=invoke("GetPlayerData",{},valid)
            if valid() then
                if ok and type(data)=="table" then inventory=data inventoryAt=os.clock()
                else nextData=os.clock()+8 if S.autoShiny then S.shinyStatus="Инвентарь: "..tostring(data) end end
                dataBusy=false
            end
        end)
    end
    local function hatchFeedback(now)
        if not hatchPending then return end
        local opened=tonumber(dataField(inventory,"EGGS_OPENED"))
        if opened and hatchPending.before and opened>hatchPending.before then
            S.hatchStatus="Открыто: "..(opened-hatchPending.before) hatchPending=nil
        elseif now-hatchPending.at>=4 then
            S.hatchStatus="Нет подтверждения открытия"..(S.hatchCount==3 and " ×3: проверь доступ к тройному открытию" or ": проверь монеты и инвентарь")
            S.lastHatch=now+2 hatchPending=nil
        end
    end
    local modes={autoBubble="bubbleStatus",autoSell="sellStatus",autoCollect="collectStatus",autoHatch="hatchStatus",autoChestRoute="chestStatus",autoShiny="shinyStatus",autoPotions="potionStatus",autoMinigames="minigameStatus"}
    function S:SetMode(key,value)
        if not modes[key] then return false end
        value=value==true
        if key=="autoHatch" and value and not self.selectedEgg then self.hatchStatus="Выбери яйцо" return false end
        self[key]=value self[modes[key]]=value and "Включено" or "Выключено"
        if key=="autoCollect" then
            clearTarget()
            if value and lease.current and lease.current.saved then
                self.anchor=lease.current.saved.anchor or lease.current.saved.cf.Position
                self.collectIslandLock=lease.current.saved.lock
            elseif value and root() then self.anchor=root().Position self.collectIslandLock=nearestIsland(root().Position) end
            if value and not self.collectCurrentIslandOnly and currentWorld~=self.farmWorld then self:GoFarmWorld() end
        elseif key=="autoHatch" then hatchPending=nil self.lastHatch=-math.huge nextData=0
        elseif key=="autoShiny" and value then shinyPending={} nextData=0 nextShiny=0
        elseif key=="autoMinigames" then
            miniGeneration+=1 miniBusy=false nextMini=0 memory={} matched={} first=nil miniTurns=0
        elseif key=="autoChestRoute" then
            if value then chestDue={} nextChest=0
            elseif lease.current and lease.current.kind=="chest" then
                -- Cooperatively stop claiming; the active excursion still returns to its saved place.
                self.chestStatus="Возвращаюсь после сундука"
            end
        end
        return true
    end
    function S:HardStop()
        for key,status in pairs(modes) do self[key]=false self[status]="Выключено" end
        cancelMovement() miniGeneration+=1 dataGeneration+=1
        for thread in pairs(threads) do if thread~=coroutine.running() and coroutine.status(thread)~="dead" then pcall(task.cancel,thread) end end
        threads={} invocation=nil dataBusy=false miniBusy=false hatchPending=nil self.manualHatchRequested=false
        self.travelUntil=0 self.status="Все действия остановлены"
    end
    function S:Stop(reason)
        if not self.alive then return end
        self:HardStop() self.alive=false
        for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns={}
        if self.gui then self.gui:Destroy() end
        self.status="Остановлен: "..tostring(reason or "manual")
    end
    function S:Diagnostic()
        local reports={"BGS Legacy "..self.version,"PlaceId="..game.PlaceId,"World="..tostring(currentWorld),
            "Worlds="..#self.worlds,"Pickups="..#self.pickups,"Eggs="..#self.eggs,"Islands="..#self.islands,
            "Movement="..(lease.current and lease.current.kind or "idle"),"Errors="..self.errors,
            "Hatch="..self.hatchStatus,"Shiny="..self.shinyStatus,"Potions="..self.potionStatus,"Minigame="..self.minigameStatus,"Chest="..self.chestStatus}
        for _,egg in ipairs(self.eggs) do
            reports[#reports+1]="Egg="..egg.name.." | "..egg.world.." | "..tostring(egg.area or "")
                .." | "..tostring(egg.currency or "?").." | "..tostring(egg.price or "?")
        end
        local text=table.concat(reports,"\n")
        if type(setclipboard)=="function" then pcall(setclipboard,text) end
        self.status="Диагностика скопирована" print(text) return text
    end
    local nextCatalogRefresh=0
    local function step(now)
        if not ready() then return end
        if now>=S.nextScan or (catalogDirty and now>=nextCatalogRefresh) then
            nextCatalogRefresh=now+1 S:Refresh()
        end
        if now>=nextCompact then compactPickups() nextCompact=now+1 end
        updateData(now) hatchFeedback(now)
        if S.autoBubble and now-S.lastBubble>=S.bubbleDelay then
            S.lastBubble=now local ok,err=send("BlowBubble") S.bubbleStatus=ok and "Надуваю" or tostring(err)
        end
        if not lease.current and S.autoSell and now>=nextSell and now-S.lastSellCheck>=S.sellCheckDelay then
            S.lastSellCheck=now local ratio=bubbleRatio()
            if ratio and ratio>=0.995 then S:SellNow() else S.sellStatus=ratio and string.format("Заполнено %.0f%%",ratio*100) or "Счётчик пузырей не найден" end
        end
        chestStep(now)
        if not lease.current then
            if S.autoHatch or S.manualHatchRequested then S:HatchOnce(true) end
            if S.autoCollect then collectStep(now) end
            shinyStep(now) potionStep(now) minigameStep(now)
        end
    end
    function S:Tick()
        if self.busy or not self.alive then return end
        self.busy=true local ok,err=pcall(step,os.clock()) self.busy=false
        if not ok then self.errors+=1 self.status="Ошибка: "..tostring(err):sub(1,150) end
    end
    function S:Start()
        -- Only retire the previous runtime once the new UI has been constructed successfully.
        if env.BGSLegacy and env.BGSLegacy~=self and type(env.BGSLegacy.Stop)=="function" then pcall(function() env.BGSLegacy:Stop("reload") end) end
        env.BGSLegacy=self
        for _,o in ipairs(workspace:GetDescendants()) do addPart(o) end
        self:Refresh() currentWorld=detectWorld() self.farmWorld=currentWorld
        connect(workspace.DescendantAdded,function(o)
            if o:IsA("BasePart") then addPart(o) end
            if not pickupContainer(o) and (o:IsA("Model") or o:IsA("Folder") or o.Name=="Hotkey"
                or o.Name=="Collision" or o.Name=="Ground" or o.Name=="EggName") then catalogDirty=true end
        end)
        connect(workspace.DescendantRemoving,function(o)
            pickupByPart[o]=nil
            if not pickupContainer(o) and (o:IsA("Model") or o:IsA("Folder") or o.Name=="Hotkey"
                or o.Name=="Collision" or o.Name=="Ground") then catalogDirty=true end
        end)
        connect(player.CharacterAdded,function()
            cancelMovement() miniGeneration+=1 dataGeneration+=1
            for thread in pairs(threads) do
                if thread~=coroutine.running() and coroutine.status(thread)~="dead" then pcall(task.cancel,thread) end
            end
            threads={} invocation=nil dataBusy=false miniBusy=false hatchPending=nil
            currentWorld=nil self.collectIslandLock=nil self.anchor=nil self.travelUntil=os.clock()+2
            spawn(function()
                local character=player.Character
                local r=character:WaitForChild("HumanoidRootPart",10)
                if self.alive and character==player.Character and r then
                    self:Refresh() currentWorld=detectWorld() self.anchor=r.Position self.collectIslandLock=nearestIsland(r.Position)
                end
            end)
        end)
        connect(player.Idled,function()
            if not self.alive then return end
            pcall(function()
                local user=game:GetService("VirtualUser")
                user:CaptureController()
                user:Button2Down(Vector2.new(0,0),workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
                user:Button2Up(Vector2.new(0,0),workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
            end)
        end)
        self.startupReady=true self.status="BGS Legacy 0.6.1 · готово"
    end
    local ui={Players=Players,RS=RS,Run=Run,Input=Input,player=player,playerGui=playerGui,root=root,
        connect=connect,clearTarget=clearTarget,stopMove=stopMove,isGemCurrency=isGemCurrency}
    return S,ui
end

end)()
local createUI=(function()
return function(S,api)
local Players,RS,Run,Input=api.Players,api.RS,api.Run,api.Input
local player,playerGui,root=api.player,api.playerGui,api.root
local connect,clearTarget,stopMove=api.connect,api.clearTarget,api.stopMove
local isGemCurrency=api.isGemCurrency
local gui
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
gui=make("ScreenGui",playerGui,{Name="BGSLegacyHubNext",ResetOnSpawn=false,DisplayOrder=999999,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local main=make("Frame",gui,{Name="Main",Size=UDim2.fromOffset(470,390),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true,Active=true})
S.gui=gui
corner(main,14) stroke(main,C.accent,0.12,1.2)
local header=make("Frame",main,{Size=UDim2.new(1,0,0,50),BackgroundColor3=C.panel,BorderSizePixel=0,Active=true})
local accentLine=make("Frame",header,{Size=UDim2.new(0,4,0,26),Position=UDim2.fromOffset(10,12),BackgroundColor3=C.accent,BorderSizePixel=0}) corner(accentLine,5)
local title=label(header,"BGS LEGACY",16) title.Font=Enum.Font.GothamBold title.Position=UDim2.fromOffset(22,7) title.Size=UDim2.new(1,-190,0,20)
local subtitle=label(header,"v0.6 · миры / сундуки / питомцы",9,C.muted) subtitle.Position=UDim2.fromOffset(22,27) subtitle.Size=UDim2.new(1,-190,0,15)
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
local pageNames={"Фарм","Яйца","Острова","Монеты","Авто"}
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
    return (e.area or e.world).." · "..price..(e.event and " · событие" or "")..(e.available==false and " · ожидаю загрузку" or "")
end
local function islandDetail(i)
    return i.world..(i.event and " · событие" or "").." · "..(i.part and "на карте" or "загрузится при переходе")
end

-- ФАРМ
toggle(pages[1],"Авто надувание","Параллельно остальным функциям",function() return S.autoBubble end,function(v) S:SetMode("autoBubble",v) end)
toggle(pages[1],"Авто продажа","Только при заполненной сумке",function() return S.autoSell end,function(v) S:SetMode("autoSell",v) end)
local sellNow=button(pages[1],"ПРОДАТЬ СЕЙЧАС",function() S:SellNow() end,36) stroke(sellNow,C.accent2,0.25)
slider(pages[1],"Интервал надувания","bubbleDelay",0.2,2,0.05,"сек")
local farmInfo=textRow(pages[1],"",32,C.accent)
local sellInfo=textRow(pages[1],"",32,C.good)

-- ЯЙЦА
toggle(pages[2],"Только яйца события","Показывать яйца загруженного события",function() return S.eventEggsOnly end,function(v) S.eventEggsOnly=v end)
textRow(pages[2],"Сортировка внутри мира: снизу → вверх.",26,C.muted)
textRow(pages[2],"Фиолетовая рамка = Gems · зелёная = обычная валюта.",26,C.muted)
local eggButton=button(pages[2],"ВЫБРАТЬ ЯЙЦО  ›",function()
    S:Refresh()
    local items={}
    for idx,e in ipairs(S.eggs) do
        if not S.eventEggsOnly or e.event then items[#items+1]={title=string.format("%02d. %s",idx,e.name),detail=eggDetail(e),value=e,selected=S.selectedEgg and S.selectedEgg.object==e.object,borderColor=borderForKind(e.kind,e.currency)} end
    end
    picker("Яйца · снизу → вверх · "..#items,items,function(e) S:SelectEgg(e) end)
end,46) stroke(eggButton,C.accent,0.25)
local eggInfo=textRow(pages[2],"Выбери яйцо.",30)
local eggActions=make("Frame",pages[2],{Size=UDim2.new(1,-6,0,35),BackgroundTransparency=1})
local goEgg=button(eggActions,"К яйцу",function() S:GoToEgg() end,35) goEgg.Size=UDim2.new(0.5,-4,1,0)
local once=button(eggActions,"Открыть ×1",function() S:HatchOnce() end,35) once.Size=UDim2.new(0.5,-4,1,0) once.Position=UDim2.new(0.5,4,0,0)
toggle(pages[2],"Автооткрытие","Открывает именно выбранное имя яйца",function() return S.autoHatch end,function(v) S:SetMode("autoHatch",v) end)
toggle(pages[2],"ТП при выборе","Переносит к выбранному яйцу",function() return S.teleportOnSelect end,function(v) S.teleportOnSelect=v end)
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
textRow(pages[5],"BGS Legacy Hub 0.6.1",24,C.accent)

-- 0.6 controls share the same picker and redraw loop as the existing UI.
local function addPickerButton(page,title,items,choose)
    return button(page,title,function() picker(title,items(),choose) end,40)
end
addPickerButton(pages[2],"Количество яиц: 1 / 3",function()
    return {{title="Открывать 1 яйцо",detail="Один запрос открытия",value=1,selected=S.hatchCount==1},
        {title="Открывать 3 яйца",detail="Игровой режим Multi · нужен доступ к ×3",value=3,selected=S.hatchCount==3}}
end,function(v) S.hatchCount=v end)
toggle(pages[2],"Яйца из любого места","Фарм монет продолжает работать; доступ проверяет игра",function() return S.hatchAnywhere end,function(v) S.hatchAnywhere=v end)
local worldButton=addPickerButton(pages[4],"Выбрать мир фарма",function()
    S:Refresh()
    local items={}
    for _,w in ipairs(S.worlds) do items[#items+1]={title=w.display,detail=w.currency,value=w.key,selected=S.farmWorld==w.key} end
    return items
end,function(v) S:SetFarmWorld(v) end)
worldButton.LayoutOrder=-3
local goWorld=button(pages[4],"В МИР ФАРМА",function() S:GoFarmWorld() end,36) goWorld.LayoutOrder=-2
toggle(pages[4],"Только текущий остров","Выключи для сбора по выбранному миру",function() return S.collectCurrentIslandOnly end,function(v)
    S.collectCurrentIslandOnly=v clearTarget()
    if root() then S.anchor=root().Position end
    if not v then S:GoFarmWorld() end
end)
draws[#draws+1]=function() worldButton.Text="Мир фарма: "..S.farmWorld.."  ›" end
toggle(pages[3],"AFK сбор сундуков","Забрать → вернуться → продолжить прежние функции",function() return S.autoChestRoute end,function(v) S:SetMode("autoChestRoute",v) end)
addPickerButton(pages[3],"Сундуки · выбор 23 островов",function()
    local items={}
    for _,d in ipairs(S.chestDefs) do
        local key=d.world.."/"..d.name
        items[#items+1]={title=(S.chestEnabled[key] and "✓ " or "○ ")..d.name,detail=d.world.." · "..(S.chestResults[key] or "Ещё не проверен"),value=key,selected=S.chestEnabled[key]}
    end
    return items
end,function(key) S.chestEnabled[key]=not S.chestEnabled[key] end)
local chestInfo=textRow(pages[3],"",44,C.good)
toggle(pages[5],"Авто золотые / Shiny","10 одинаковых обычных · без экипнутых и закрытых",function() return S.autoShiny end,function(v) S:SetMode("autoShiny",v) end)
local shinyInfo=textRow(pages[5],"",38,C.good)
addPickerButton(pages[5],"Выбор зелья",function()
    local items={}
    for i,name in ipairs(S.potionNames) do items[#items+1]={title=name,detail="Рецепт лаборатории №"..i,value=i,selected=S.potionRecipe==i} end
    return items
end,function(v) S.potionRecipe=v end)
toggle(pages[5],"Авто крафт и сбор зелий","Выбранный рецепт · свободные слоты лаборатории",function() return S.autoPotions end,function(v) S:SetMode("autoPotions",v) end)
local potionInfo=textRow(pages[5],"",44,C.accent2)
addPickerButton(pages[5],"Выбор мини-игры",function()
    local items={}
    for _,name in ipairs({"Match The Pet","Spin To Win","Doggy Jump"}) do
        items[#items+1]={title=name,detail=name=="Match The Pet" and "Запоминает карточки и собирает пары" or "Доступ и награды проверяет игра",value=name,selected=S.minigame==name}
    end
    return items
end,function(v) S:SetMode("autoMinigames",false) S.minigame=v end)
toggle(pages[5],"Авто мини-игра","Запусти выбранную мини-игру в её мире",function() return S.autoMinigames end,function(v) S:SetMode("autoMinigames",v) end)
local miniInfo=textRow(pages[5],"",44,C.accent)
button(pages[5],"Скопировать диагностику",function() S:Diagnostic() end,36)
draws[#draws+1]=function()
    chestInfo.Text=S.chestStatus shinyInfo.Text=S.shinyStatus
    potionInfo.Text=S.potionNames[S.potionRecipe].." · "..S.potionStatus
    miniInfo.Text=S.minigame.." · "..S.minigameStatus
end

-- Window movement/minimize/resize ------------------------------------------
local minimized=false
local savedSize,savedPosition=nil,nil
local drag,resize=nil,nil
local function viewport() return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600) end
local function fit()
    if minimized then return end
    local view=viewport()
    local minW=math.min(360,math.max(240,view.X-12))
    local w=math.clamp(main.Size.X.Offset,minW,math.max(minW,view.X-12))
    local minH=math.min(300,math.max(220,view.Y-58))
    local h=math.clamp(main.Size.Y.Offset,minH,math.max(minH,view.Y-58))
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
    once.Text="Открыть ×"..S.hatchCount
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

S:Start()
gui.Name="BGSLegacyHub"
main.AnchorPoint=Vector2.new(0.5,0.5)
task.defer(fit)
local nextTick,nextPaint=0,0
connect(Run.Heartbeat,function()
    if not S.alive then return end
    local now=os.clock()
    if now>=nextTick then nextTick=now+0.10 S:Tick() end
    if now>=nextPaint then nextPaint=now+0.20 refreshUI() end
end)
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit) end

S.startupReady=true
return S

end

end)()
local S,api=createRuntime(logic)
local ok,result=xpcall(function() return createUI(S,api) end,function(err) return tostring(err) end)
if not ok then
    pcall(function() S:Stop("startup failure") end)
    error("BGS UI: "..result,0)
end
return result
