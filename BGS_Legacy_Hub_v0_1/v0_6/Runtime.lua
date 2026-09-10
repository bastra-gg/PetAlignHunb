-- BGS Legacy 0.6.0: one scheduler, one movement owner, cancellable excursions.
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
    local S={alive=true,startupReady=false,version="0.6.0",errors=0,
        autoBubble=false,autoSell=false,autoCollect=false,autoHatch=false,
        autoChestRoute=false,autoShiny=false,autoPotions=false,autoMinigames=false,
        bubbleDelay=0.25,hatchDelay=1,sellCheckDelay=1,teleportHeights=5,
        collectMode="smart",currency="Все",farmWorld="Overworld",collectCurrentIslandOnly=true,
        teleportOnSelect=false,hatchAnywhere=true,hatchCount=1,shinyFilter="Все",potionRecipe=1,
        minigame="Match The Pet",eggs={},islands={},pickups={},currencies={"Все"},
        selectedEgg=nil,selectedIsland=nil,collectIslandLock=nil,anchor=nil,
        status="Готово",bubbleStatus="Выключено",sellStatus="Выключено",collectStatus="Выключено",
        hatchStatus="Выбери яйцо",chestStatus="Выключено",shinyStatus="Выключено",
        potionStatus="Выключено",minigameStatus="Выключено",travelUntil=0,selling=false,
        lastBubble=-math.huge,lastHatch=-math.huge,lastSellCheck=0,nextScan=0,worlds=L.worlds,
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
    local function worldOf(o)
        local p=o
        while p and p~=workspace do
            local w=L.world(meta(p,{"World","WorldName"})) or L.world(p.Name)
            if w then return w end
            p=p.Parent
        end
    end
    local function childWorld(container,key)
        if not container then return nil end
        for _,o in ipairs(container:GetChildren()) do if L.world(o.Name)==key then return o end end
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
        local attribute=L.world(meta(player,{"World","CurrentWorld"}))
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
            local attr=L.world(meta(player,{"World","CurrentWorld"}))
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
    local function mapEntry(node,name,world,order,def)
        local floor=surface(node)
        return {object=node,part=floor,name=name,world=world,order=order,def=def,
            y=floor and floor.Position.Y or 0,kind=(world=="Heaven" or world=="Mystic Forest") and "gem" or "normal"}
    end
    local function refreshCatalog()
        local islands,seen={},{}
        for wi,w in ipairs(L.worlds) do
            local base=worldNode(w.key)
            if base then islands[#islands+1]=mapEntry(base,"Спавн",w.key,wi*100,nil) end
            local container=islandContainer(w.key)
            if container then
                for _,node in ipairs(container:GetChildren()) do
                    local entry=mapEntry(node,node.Name,w.key,wi*100+1,{world=w.key,name=node.Name})
                    if entry.part then islands[#islands+1]=entry seen[w.key.."/"..L.norm(node.Name)]=true end
                end
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
                local ai,bi=99,99 for i,w in ipairs(L.worlds) do if a.world==w.key then ai=i end if b.world==w.key then bi=i end end
                return ai<bi
            end
            if math.abs(a.y-b.y)>1 then return a.y<b.y end
            return a.name<b.name
        end)
        for i,e in ipairs(islands) do e.order=i end
        S.islands=islands
        local eggs,byKey={},{}
        local eggData=itemModule("EggModule")
        local folders={}
        local direct=workspace:FindFirstChild("Eggs") if direct then folders[#folders+1]=direct end
        local worlds=workspace:FindFirstChild("Worlds")
        if worlds then
            for _,w in ipairs(worlds:GetChildren()) do local f=w:FindFirstChild("Eggs") if f then folders[#folders+1]=f end end
        end
        local function addEgg(o)
            local hot=o:FindFirstChild("Hotkey",true)
            if not hot and not L.norm(o.Name):find("egg",1,true) then return end
            if not o:IsA("Model") and not o:IsA("BasePart") then return end
            local p=partOf(hot) or partOf(o)
            if not p then return end
            local data=type(eggData)=="table" and eggData[o.Name] or nil
            local world=worldOf(o) or (type(data)=="table" and L.world(data.World)) or currentWorld or detectWorld()
            local key=world.."/"..o.Name
            if byKey[key] then return end
            local currency=meta(o,{"Currency","CurrencyType"})
            local price=meta(o,{"Price","Cost","EggPrice"})
            if type(data)=="table" and type(data.Cost)=="table" then
                currency=currency or data.Cost[1] price=price or tonumber(data.Cost[2])
            end
            local e={object=o,part=p,name=o.Name,world=world,y=p.Position.Y,currency=currency,price=price,kind=isGemCurrency(currency) and "gem" or "normal"}
            byKey[key]=e eggs[#eggs+1]=e
        end
        for _,folder in ipairs(folders) do
            for _,o in ipairs(folder:GetDescendants()) do
                if o.Name=="Hotkey" then
                    local owner=o.Parent
                    while owner and owner~=folder do
                        if L.norm(owner.Name):find("egg",1,true) then addEgg(owner) break end
                        owner=owner.Parent
                    end
                end
            end
            for _,o in ipairs(folder:GetChildren()) do addEgg(o) end
        end
        table.sort(eggs,function(a,b) if a.world~=b.world then return a.world<b.world end return a.name<b.name end)
        S.eggs=eggs
        if S.selectedEgg then local e=S.selectedEgg S.selectedEgg=byKey[e.world.."/"..e.name] or e end
        catalogDirty=false
    end
    function S:Refresh()
        refreshCatalog() compactPickups() self.nextScan=os.clock()+10
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
        if not L.world(key) then return false end
        self.farmWorld=L.world(key) self.collectCurrentIslandOnly=false
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
            "Pickups="..#self.pickups,"Eggs="..#self.eggs,"Islands="..#self.islands,
            "Movement="..(lease.current and lease.current.kind or "idle"),"Errors="..self.errors,
            "Hatch="..self.hatchStatus,"Shiny="..self.shinyStatus,"Potions="..self.potionStatus,"Minigame="..self.minigameStatus,"Chest="..self.chestStatus}
        local text=table.concat(reports,"\n")
        if type(setclipboard)=="function" then pcall(setclipboard,text) end
        self.status="Диагностика скопирована" print(text) return text
    end
    local function step(now)
        if not ready() then return end
        if now>=S.nextScan or catalogDirty then S:Refresh() end
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
            if o.Name=="FloatingIslands" or o.Name=="Worlds" or o.Name=="Eggs" or o.Name=="Hotkey" then catalogDirty=true end
        end)
        connect(workspace.DescendantRemoving,function(o) pickupByPart[o]=nil end)
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
        self.startupReady=true self.status="BGS Legacy 0.6.0 · готово"
    end
    local ui={Players=Players,RS=RS,Run=Run,Input=Input,player=player,playerGui=playerGui,root=root,
        connect=connect,clearTarget=clearTarget,stopMove=stopMove,isGemCurrency=isGemCurrency}
    return S,ui
end
