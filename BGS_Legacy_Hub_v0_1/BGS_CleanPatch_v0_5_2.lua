-- BGS Legacy Hub v0.5.2 CLEAN
-- Single stability patch for the v0.4 core.
-- No old feature/island/coin wrappers are required.

return function(S)
    if type(S) ~= "table" then return S end

    local VERSION = "0.5.2"
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if not player or not playerGui then return S end

    local function root()
        local c=player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function hum()
        local c=player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end
    local function ready()
        local r,h=root(),hum()
        return r~=nil and h~=nil and h.Health>0
    end
    local function stopMove()
        local r,h=root(),hum()
        if r and h then pcall(function() h:MoveTo(r.Position) h:Move(Vector3.zero,false) end) end
    end
    local function norm(v)
        return tostring(v or ""):lower():gsub("[%s%p_]","")
    end
    local function exact(v,list)
        local n=norm(v)
        for _,x in ipairs(list or {}) do if n==norm(x) then return true end end
        return false
    end

    ------------------------------------------------------------------------
    -- Canonical worlds/islands. Names only: no fuzzy "island/isle" scan.
    ------------------------------------------------------------------------
    local WORLDS={
        {key="Overworld",display="Overworld (спавн)",aliases={"The Overworld","Overworld"}},
        {key="Candy Land",display="Candy Land (мир конфет)",aliases={"Candy Land","CandyLand"}},
        {key="Toy Land",display="Toy Land (мир игрушек)",aliases={"Toy Land","ToyLand"}},
        {key="Beach World",display="Beach World (пляжный мир)",aliases={"Beach World","BeachWorld"}},
        {key="Atlantis",display="Atlantis (Атлантида)",aliases={"Atlantis"}},
        {key="Rainbow Land",display="Rainbow Land (радужный мир)",aliases={"Rainbow Land","RainbowLand"}},
        {key="Underworld",display="Underworld (вулканический мир)",aliases={"Underworld","The Underworld"}},
        {key="Mystic Forest",display="Mystic Forest (мифическое дерево)",aliases={"Mystic Forest","MysticForest"}},
        {key="Heaven",display="Heaven (райский мир)",aliases={"Heaven","Heaven World","HeavenWorld"}},
    }
    local WORLD_BY={}
    for _,w in ipairs(WORLDS) do WORLD_BY[w.key]=w end

    local ISLANDS={
        {"Overworld","Starter Area",{"Starter Area","Main Island"},"normal"},
        {"Overworld","The Floating Island",{"The Floating Island","Floating Island"},"normal"},
        {"Overworld","Space",{"Space","Outer Space"},"gem"},
        {"Overworld","The Twilight",{"The Twilight","Twilight"},"gem"},
        {"Overworld","The Skylands",{"The Skylands","The Skyland","Skylands"},"gem"},
        {"Overworld","The Void",{"The Void","Void"},"gem"},
        {"Overworld","Zen",{"Zen"},"gem"},
        {"Overworld","XP Island",{"XP Island","XP"},"gem"},
        {"Candy Land","Gumdrop Island",{"Gumdrop Island"},"normal"},
        {"Candy Land","Rewards Island",{"Rewards Island","Candy Rewards"},"normal"},
        {"Candy Land","Sugar Island",{"Sugar Island"},"normal"},
        {"Candy Land","Candy Island",{"Candy Island"},"normal"},
        {"Candy Land","Sweet Island",{"Sweet Island"},"normal"},
        {"Toy Land","Block Island",{"Block Island"},"normal"},
        {"Toy Land","Block Rewards",{"Block Rewards"},"normal"},
        {"Toy Land","Toy Isle",{"Toy Isle"},"normal"},
        {"Toy Land","Teddy Island",{"Teddy Island"},"normal"},
        {"Toy Land","Treasure Isle",{"Treasure Isle","Treasure Island"},"normal"},
        {"Beach World","Sea Island",{"Sea Island"},"normal"},
        {"Beach World","Sea Rewards",{"Sea Rewards"},"normal"},
        {"Beach World","Shell Isle",{"Shell Isle"},"normal"},
        {"Beach World","Oceanic Island",{"Oceanic Island"},"normal"},
        {"Beach World","Sea Shell Island",{"Sea Shell Island","Sea Shell Isle","See Shell Isle"},"normal"},
        {"Atlantis","Water Island",{"Water Island"},"normal"},
        {"Atlantis","Atlantis Rewards",{"Atlantis Rewards"},"normal"},
        {"Atlantis","Atlantis Isle",{"Atlantis Isle"},"normal"},
        {"Atlantis","Treasure Island",{"Treasure Island"},"normal"},
        {"Atlantis","Sandy Island",{"Sandy Island"},"normal"},
        {"Rainbow Land","Red Island",{"Red Island"},"normal"},
        {"Rainbow Land","Rainbow Rewards",{"Rainbow Rewards"},"normal"},
        {"Rainbow Land","Green Island",{"Green Island"},"normal"},
        {"Rainbow Land","Blue Island",{"Blue Island"},"normal"},
        {"Rainbow Land","Purple Island",{"Purple Island"},"normal"},
        {"Underworld","Fire Island",{"Fire Island"},"normal"},
        {"Underworld","Magma Rewards",{"Magma Rewards"},"normal"},
        {"Underworld","Magma Island",{"Magma Island"},"normal"},
        {"Underworld","Inferno Island",{"Inferno Island"},"normal"},
        {"Underworld","Molten Island",{"Molten Island"},"normal"},
        {"Mystic Forest","Crystal Island",{"Crystal Island"},"gem"},
        {"Mystic Forest","Crystal Rewards",{"Crystal Rewards"},"gem"},
        {"Mystic Forest","Mythic Island",{"Mythic Island"},"gem"},
        {"Mystic Forest","Spirit Island",{"Spirit Island"},"gem"},
        {"Mystic Forest","Magic Island",{"Magic Island"},"gem"},
        {"Heaven","Light Island",{"Light Island"},"gem"},
        {"Heaven","Cloud Island",{"Cloud Island","Claud Island"},"gem"},
        {"Heaven","Spirit Island",{"Spirit Island"},"gem"},
    }

    local BAD_WORDS={"portal","spawn","fasttravel","teleport","door","gate","button","unlockhitbox","preview","showcase","display","map","gui"}
    local function badPath(obj,stop)
        local p=obj
        while p and p~=stop and p~=workspace do
            local low=norm(p.Name)
            for _,word in ipairs(BAD_WORDS) do if low:find(word,1,true) then return true end end
            p=p.Parent
        end
        return false
    end

    local function findWorld(worldKey)
        local def=WORLD_BY[worldKey]
        if not def then return nil end
        local worlds=workspace:FindFirstChild("Worlds")
        local base=worlds or workspace
        for _,obj in ipairs(base:GetChildren()) do
            if exact(obj.Name,def.aliases) then return obj end
        end
        -- limited second level only, not workspace:GetDescendants()
        for _,parent in ipairs(base:GetChildren()) do
            for _,obj in ipairs(parent:GetChildren()) do
                if exact(obj.Name,def.aliases) and (obj:FindFirstChild("Islands") or obj:FindFirstChild("Eggs")) then return obj end
            end
        end
        return nil
    end

    local function findIslandNode(worldKey,aliases)
        local world=findWorld(worldKey)
        if not world then return nil end
        local islands=world:FindFirstChild("Islands")
        if not islands then
            for _,obj in ipairs(world:GetChildren()) do
                if obj.Name=="Islands" then islands=obj break end
            end
        end
        if not islands then return nil end
        for _,obj in ipairs(islands:GetChildren()) do
            if exact(obj.Name,aliases) then return obj end
        end
        return nil
    end

    local function surfacePart(node)
        if not node then return nil end
        local body=node:FindFirstChild("Island") or node
        local best,bestScore=nil,-math.huge
        local function consider(p)
            if not p:IsA("BasePart") or p.Transparency>=0.98 or badPath(p,body) then return end
            local area=p.Size.X*p.Size.Z
            local flat=math.abs(p.CFrame.UpVector.Y)
            local score=area*(p.CanCollide and 3 or 0.25)*(flat>=0.70 and 3 or 0.25)
            if p.Size.X<5 or p.Size.Z<5 then score=score*0.08 end
            if score>bestScore then best,bestScore=p,score end
        end
        if body:IsA("BasePart") then
            consider(body)
        else
            for _,p in ipairs(body:GetDescendants()) do consider(p) end
        end
        return best
    end

    local function remoteEvent()
        local n=RS:FindFirstChild("NetworkRemoteEvent")
        if n and n:IsA("RemoteEvent") then return n end
        local shared=RS:FindFirstChild("Shared")
        local framework=shared and shared:FindFirstChild("Framework")
        local network=framework and framework:FindFirstChild("Network")
        local remote=network and network:FindFirstChild("Remote")
        local event=remote and remote:FindFirstChild("Event")
        if event and event:IsA("RemoteEvent") then return event end
        n=RS:FindFirstChild("NetworkRemoteEvent",true)
        return n and n:IsA("RemoteEvent") and n or nil
    end

    local canonicalEntries={}
    local function rebuildIslands()
        local oldName=S.selectedIsland and S.selectedIsland.name
        local oldWorld=S.selectedIsland and S.selectedIsland.world
        local list={}
        for i,d in ipairs(ISLANDS) do
            local node=findIslandNode(d[1],d[3])
            if node then
                local p=surfacePart(node)
                if p then
                    list[#list+1]={object=node,part=p,landingPart=p,name=d[2],world=d[1],rawWorld=d[1],kind=d[4],order=i,canonicalDef=d,y=p.Position.Y}
                end
            end
        end
        canonicalEntries=list
        if #list>0 then
            S.islands=list
            S.selectedIsland=nil
            if oldName then
                for _,e in ipairs(list) do if e.name==oldName and (not oldWorld or e.world==oldWorld) then S.selectedIsland=e break end end
            end
        end
        return list
    end

    local function defFromEntry(entry)
        if not entry then return nil end
        if entry.canonicalDef then return entry.canonicalDef end
        for _,d in ipairs(ISLANDS) do
            if exact(entry.name,d[3]) and (not entry.world or norm(entry.world)==norm(d[1]) or exact(entry.world,WORLD_BY[d[1]].aliases)) then return d end
        end
        return nil
    end

    function S:SelectIsland(entry)
        local d=defFromEntry(entry)
        if not d then self.status="ТП: неизвестный остров" return false end
        self.selectedIsland=entry
        self.status="Выбрано: "..d[2]
        return true
    end

    function S:GoIsland(entry)
        entry=entry or self.selectedIsland
        local d=defFromEntry(entry)
        if not d then self.status="ТП: выбери остров" return false end
        local node=findIslandNode(d[1],d[3])
        if not node then self.status="ТП: остров не найден · "..d[2] return false end
        local land=surfacePart(node)
        if not land then self.status="ТП: поверхность не найдена · "..d[2] return false end
        local r,h=root(),hum()
        if not r or not h or h.Health<=0 then self.status="ТП: жду персонажа" return false end

        stopMove()
        h.Sit=false
        local before=r.Position
        local nativeSent=false
        local portal=node:FindFirstChild("Portal",true)
        local spawn=portal and portal:FindFirstChild("Spawn",true)
        local ev=remoteEvent()
        if ev and spawn then
            local path=spawn:GetFullName()
            if not path:find("^Workspace%.") then path="Workspace."..path:gsub("^workspace%.","") end
            nativeSent=pcall(function() ev:FireServer("Teleport",path) end)
        end

        local function localLanding()
            local rr,hh=root(),hum()
            if not rr or not hh or hh.Health<=0 or not land.Parent then return end
            local up=math.max(4,hh.HipHeight+rr.Size.Y/2+1.8)
            local pos=land.CFrame:PointToWorldSpace(Vector3.new(0,land.Size.Y/2+up,0))
            rr.CFrame=CFrame.new(pos)*(rr.CFrame-rr.Position)
            rr.AssemblyLinearVelocity=Vector3.zero
            rr.AssemblyAngularVelocity=Vector3.zero
        end

        if nativeSent then
            task.delay(0.45,function()
                local rr=root()
                if not rr or not land.Parent then return end
                local distanceToLand=(rr.Position-land.Position).Magnitude
                local moved=(rr.Position-before).Magnitude
                -- If native TP did nothing OR placed us at a portal/door area, land on the real island surface.
                if moved<12 or distanceToLand>math.max(180,math.max(land.Size.X,land.Size.Z)*2.5) then localLanding() end
            end)
        else
            localLanding()
        end

        self.selectedIsland=entry
        self.collectIslandLock=entry
        self.currentIslandName=d[2]
        self.travelUntil=os.clock()+0.75
        self.status="ТП: "..d[2]..(nativeSent and " · native" or " · local")
        return true
    end

    ------------------------------------------------------------------------
    -- LIGHT PICKUP CACHE: direct children + ChildAdded, no repeated map scan.
    ------------------------------------------------------------------------
    local pickupFolder=workspace:FindFirstChild("Pickups",true)
    local pickups={}
    local pickupIndex=setmetatable({},{__mode="k"})
    local farmConns={}
    local target=nil
    local targetAt=0
    local targetBest=math.huge
    local progressAt=0
    local nextMove=0
    local anchor=nil
    local skipped=setmetatable({},{__mode="k"})

    local function currencyOf(obj)
        local p=obj
        local depth=0
        local map={coin="Coins",gem="Gems",candy="Candy",block="Blocks",shell="Shells",pearl="Pearls",star="Stars",magma="Magma",crystal="Crystals"}
        while p and p~=workspace and depth<6 do
            local a=p:GetAttribute("Currency") or p:GetAttribute("CurrencyType") or p:GetAttribute("PickupType")
            if a~=nil then return tostring(a) end
            local low=tostring(p.Name):lower()
            for k,v in pairs(map) do if low:find(k,1,true) then return v end end
            p=p.Parent depth+=1
        end
        return "Другое"
    end

    local function bestPickupPart(obj)
        if obj:IsA("BasePart") then return obj end
        local named=obj:FindFirstChild("Hitbox",true) or obj:FindFirstChild("Touch",true) or obj:FindFirstChild("Pickup",true)
        if named and named:IsA("BasePart") then return named end
        local first=nil
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") then
                if p:FindFirstChild("TouchInterest") or p.CanTouch then return p end
                first=first or p
            end
        end
        return first
    end

    local function nearestIslandWorld(pos)
        local bestWorld=nil
        local bestD=math.huge
        for _,e in ipairs(canonicalEntries) do
            if e.part and e.part.Parent then
                local d=(e.part.Position-pos).Magnitude
                if d<bestD then bestD=d bestWorld=e.world end
            end
        end
        if bestD<=900 then return bestWorld end
        return nil
    end

    local function classifyWorld(obj,part)
        local p=obj
        local depth=0
        while p and p~=workspace and depth<8 do
            for _,w in ipairs(WORLDS) do if exact(p.Name,w.aliases) then return w.key end end
            p=p.Parent depth+=1
        end
        return part and nearestIslandWorld(part.Position) or nil
    end

    local function addPickup(obj)
        if not pickupFolder or not obj or not obj.Parent or pickupIndex[obj] then return end
        local part=bestPickupPart(obj)
        if not part or not part.Parent then return end
        local item={object=obj,part=part,currency=currencyOf(obj),world=classifyWorld(obj,part)}
        pickupIndex[obj]=item
        pickups[#pickups+1]=item
    end

    local function compactPickups()
        local fresh={}
        for _,item in ipairs(pickups) do
            if item.object and item.object.Parent and item.part and item.part.Parent and item.part:IsDescendantOf(workspace) and item.object:GetAttribute("Collected")~=true then fresh[#fresh+1]=item end
        end
        pickups=fresh
    end

    local function buildPickupCache()
        pickupFolder=workspace:FindFirstChild("Pickups",true)
        pickups={}
        pickupIndex=setmetatable({},{__mode="k"})
        if not pickupFolder then return end
        local children=pickupFolder:GetChildren()
        task.spawn(function()
            for i,obj in ipairs(children) do
                addPickup(obj)
                if i%20==0 then task.wait() end
            end
        end)
    end

    local function disconnectFarmConns()
        for _,c in ipairs(farmConns) do pcall(function() c:Disconnect() end) end
        farmConns={}
    end

    local function hookPickups()
        disconnectFarmConns()
        if not pickupFolder then return end
        farmConns[#farmConns+1]=pickupFolder.ChildAdded:Connect(function(obj) task.defer(addPickup,obj) end)
        farmConns[#farmConns+1]=pickupFolder.ChildRemoved:Connect(function(obj)
            local item=pickupIndex[obj]
            if item and target==item then target=nil end
            pickupIndex[obj]=nil
        end)
    end

    local function currentIsland()
        local r=root()
        if not r then return nil end
        local best,bestD=nil,math.huge
        for _,e in ipairs(canonicalEntries) do
            if e.part and e.part.Parent then
                local d=(e.part.Position-r.Position).Magnitude
                if d<bestD then best,bestD=e,d end
            end
        end
        if bestD<=350 then return best end
        return nil
    end

    S.farmWorld=S.farmWorld or "Overworld"
    S.collectCurrentIslandOnly=(S.collectCurrentIslandOnly~=false)

    local function eligible(item)
        if not item or not item.object or not item.object.Parent or not item.part or not item.part.Parent then return false end
        if S.currency~="Все" and item.currency~=S.currency then return false end
        if os.clock()<(skipped[item.object] or 0) then return false end
        if S.collectCurrentIslandOnly then
            local island=S.collectIslandLock
            if not island or not island.part or not island.part.Parent then island=currentIsland() S.collectIslandLock=island end
            if island and island.part and island.part.Parent then
                local dy=math.abs(item.part.Position.Y-island.part.Position.Y)
                local flat=(Vector2.new(item.part.Position.X,item.part.Position.Z)-Vector2.new(island.part.Position.X,island.part.Position.Z)).Magnitude
                local radius=math.max(150,math.max(island.part.Size.X,island.part.Size.Z)*1.8)
                return flat<=radius and dy<=120
            end
            local r=root()
            if not anchor and r then anchor=r.Position end
            if not anchor then return false end
            local delta=item.part.Position-anchor
            return Vector2.new(delta.X,delta.Z).Magnitude<=280 and math.abs(delta.Y)<=120
        end
        return item.world==S.farmWorld
    end

    local function nearestPickup()
        local r=root()
        if not r then return nil,nil end
        local best,bestD=nil,math.huge
        for _,item in ipairs(pickups) do
            if eligible(item) then
                local d=(item.part.Position-r.Position).Magnitude
                if d<bestD then best,bestD=item,d end
            end
        end
        return best,bestD
    end

    local function clearTarget(cooldown)
        if target and cooldown and target.object then skipped[target.object]=os.clock()+cooldown end
        target=nil targetAt=0 targetBest=math.huge progressAt=0
    end

    local function collectTick(now)
        if not S.autoCollect or not ready() or S.selling or now<(S.travelUntil or 0) then return end
        local r,h=root(),hum()
        if target and not eligible(target) then clearTarget() end
        if not target then
            local d
            target,d=nearestPickup()
            if not target then
                stopMove()
                S.collectStatus=S.collectCurrentIslandOnly and "Жду монеты · текущий остров" or ("Жду монеты · "..tostring(S.farmWorld))
                return
            end
            targetAt=now targetBest=d or math.huge progressAt=now
        end
        if not target.part or not target.part.Parent then clearTarget() return end
        local d=(target.part.Position-r.Position).Magnitude
        if d<targetBest-0.35 then targetBest=d progressAt=now end
        if now-targetAt>4.5 then clearTarget(5) S.collectStatus="Пропустил залипшую монету" return end
        if now<nextMove then return end
        nextMove=now+0.24
        local delta=target.part.Position-r.Position
        local flat=Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude<0.2 then flat=Vector3.new(1,0,0) end
        local dir=flat.Unit
        local dest=target.part.Position+dir*(d<=9 and -5 or 3)
        h:MoveTo(dest)
        if d<=7 and type(firetouchinterest)=="function" then
            pcall(firetouchinterest,r,target.part,0)
            pcall(firetouchinterest,r,target.part,1)
        end
        if now-progressAt>1.2 then h.Jump=true progressAt=now end
        S.collectStatus=tostring(target.currency).." · "..math.floor(d).." studs"
    end

    ------------------------------------------------------------------------
    -- Light egg refresh + concurrent x1/x3 hatch.
    ------------------------------------------------------------------------
    local function lightEggs()
        local folder=workspace:FindFirstChild("Eggs",true)
        if not folder then return S.eggs or {} end
        local oldName=S.selectedEgg and S.selectedEgg.name
        local list={}
        for _,obj in ipairs(folder:GetChildren()) do
            local hot=obj:FindFirstChild("Hotkey",true)
            local part=nil
            if hot then part=hot:IsA("BasePart") and hot or hot:FindFirstChildWhichIsA("BasePart",true) end
            part=part or (obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart",true))
            if part and (obj.Name:lower():find("egg",1,true) or hot) then
                list[#list+1]={object=obj,part=part,name=obj.Name,world="Текущий мир",currency=obj:GetAttribute("Currency"),y=part.Position.Y,kind="normal"}
            end
        end
        table.sort(list,function(a,b) return a.name<b.name end)
        S.eggs=list
        S.selectedEgg=nil
        if oldName then for _,e in ipairs(list) do if e.name==oldName then S.selectedEgg=e break end end end
        return list
    end

    S.hatchCount=(S.hatchCount==3) and 3 or 1
    S.hatchAnywhere=(S.hatchAnywhere~=false)
    S.teleportOnSelect=false
    local lastHatch=-math.huge
    local remoteTimes={}
    local function fire(action,...)
        local ev=remoteEvent()
        if not ev then return false end
        local now=os.clock()
        local fresh={}
        for _,t in ipairs(remoteTimes) do if now-t<1 then fresh[#fresh+1]=t end end
        remoteTimes=fresh
        if #remoteTimes>=8 then return false end
        remoteTimes[#remoteTimes+1]=now
        local args={...}
        return pcall(function() ev:FireServer(action,table.unpack(args)) end)
    end
    local function hatchTick(now)
        if not S.autoHatch then return end
        local e=S.selectedEgg
        if not e or not e.object or not e.object.Parent then S.hatchStatus="Выбери яйцо" return end
        if now-lastHatch<math.max(0.55,tonumber(S.hatchDelay) or 0.8) then return end
        if not S.hatchAnywhere then
            local r=root()
            if not r or (e.part.Position-r.Position).Magnitude>16 then S.hatchStatus="Слишком далеко от яйца" return end
        end
        lastHatch=now
        local count=S.hatchCount==3 and 3 or 1
        local sent=0
        for _=1,count do if fire("PurchaseEgg",e.name) then sent+=1 end end
        S.hatchStatus="Открываю x"..count.." · "..e.name
        S.status=S.hatchStatus.." · "..sent
    end

    ------------------------------------------------------------------------
    -- Replace expensive core Refresh and run core without its collector/hatcher.
    ------------------------------------------------------------------------
    function S:Refresh()
        rebuildIslands()
        lightEggs()
        compactPickups()
        self.pickups=pickups
        self.nextScan=os.clock()+12
    end

    local coreTick=S.Tick
    if type(coreTick)=="function" then
        function S:Tick()
            local collect=self.autoCollect
            local hatch=self.autoHatch
            if collect then self.autoCollect=false end
            if hatch then self.autoHatch=false end
            coreTick(self)
            self.autoCollect=collect
            self.autoHatch=hatch
            if not self.alive then return end
            local now=os.clock()
            if collect then collectTick(now) end
            if hatch then hatchTick(now) end
        end
    end

    local coreSetMode=S.SetMode
    if type(coreSetMode)=="function" then
        function S:SetMode(key,value)
            local result=coreSetMode(self,key,value)
            if key=="autoCollect" then
                clearTarget()
                anchor=value and root() and root().Position or nil
                if value then self.collectIslandLock=currentIsland() self.collectStatus="Ищу монеты" end
            elseif key=="autoHatch" and value then
                lastHatch=-math.huge
            end
            return result
        end
    end

    local coreStop=S.Stop
    if type(coreStop)=="function" then
        function S:Stop(reason)
            disconnectFarmConns()
            return coreStop(self,reason)
        end
    end

    ------------------------------------------------------------------------
    -- Small UI additions. No modal/animation loops.
    ------------------------------------------------------------------------
    local gui=playerGui:FindFirstChild("BGSLegacyHub")
    local function corner(o,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 8) c.Parent=o end
    local function makeRow(parent,name,title,desc,callback)
        if not parent or parent:FindFirstChild(name) then return parent and parent:FindFirstChild(name) end
        local b=Instance.new("TextButton")
        b.Name=name b.Size=UDim2.new(1,-6,0,48) b.BackgroundColor3=Color3.fromRGB(31,34,46) b.BorderSizePixel=0 b.Text="" b.Parent=parent corner(b,8)
        local t=Instance.new("TextLabel")
        t.Name="Title" t.BackgroundTransparency=1 t.Position=UDim2.fromOffset(10,5) t.Size=UDim2.new(1,-20,0,18) t.Text=title t.TextColor3=Color3.fromRGB(244,244,250) t.Font=Enum.Font.GothamMedium t.TextSize=11 t.TextXAlignment=Enum.TextXAlignment.Left t.Parent=b
        local d=Instance.new("TextLabel")
        d.Name="Desc" d.BackgroundTransparency=1 d.Position=UDim2.fromOffset(10,26) d.Size=UDim2.new(1,-20,0,15) d.Text=desc or "" d.TextColor3=Color3.fromRGB(158,162,184) d.Font=Enum.Font.Gotham d.TextSize=9 d.TextXAlignment=Enum.TextXAlignment.Left d.Parent=b
        if callback then b.Activated:Connect(callback) end
        return b
    end

    if gui then
        local page2=gui:FindFirstChild("Page2",true)
        local page4=gui:FindFirstChild("Page4",true)
        if page2 then
            makeRow(page2,"HatchCount52","Открывать: x"..S.hatchCount,"Нажми: x1 ↔ x3",function()
                S.hatchCount=S.hatchCount==1 and 3 or 1
                local b=page2:FindFirstChild("HatchCount52") if b and b:FindFirstChild("Title") then b.Title.Text="Открывать: x"..S.hatchCount end
            end)
            makeRow(page2,"HatchAnywhere52",S.hatchAnywhere and "Яйца из любого места: ВКЛ" or "Яйца из любого места: ВЫКЛ","Нажми для переключения",function()
                S.hatchAnywhere=not S.hatchAnywhere
                local b=page2:FindFirstChild("HatchAnywhere52") if b and b:FindFirstChild("Title") then b.Title.Text=S.hatchAnywhere and "Яйца из любого места: ВКЛ" or "Яйца из любого места: ВЫКЛ" end
            end)
        end
        if page4 then
            makeRow(page4,"FarmScope52",S.collectCurrentIslandOnly and "Фарм: текущий остров" or "Фарм: выбранный мир","Нажми: остров ↔ мир",function()
                S.collectCurrentIslandOnly=not S.collectCurrentIslandOnly
                S.collectIslandLock=nil clearTarget() anchor=root() and root().Position or nil
                local b=page4:FindFirstChild("FarmScope52") if b and b:FindFirstChild("Title") then b.Title.Text=S.collectCurrentIslandOnly and "Фарм: текущий остров" or "Фарм: выбранный мир" end
            end)
            makeRow(page4,"FarmWorld52","Мир фарма: "..S.farmWorld,"Нажми для следующего из 9 миров",function()
                local idx=1
                for i,w in ipairs(WORLDS) do if w.key==S.farmWorld then idx=i break end end
                idx=idx%#WORLDS+1
                S.farmWorld=WORLDS[idx].key clearTarget()
                local b=page4:FindFirstChild("FarmWorld52") if b and b:FindFirstChild("Title") then b.Title.Text="Мир фарма: "..S.farmWorld end
            end)
        end
        for _,obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                local text=tostring(obj.Text or "")
                if text=="v0.4 · чистая сортировка / hitbox fix" or text:find("v0.5.",1,true) then
                    if obj.Name~="Title" then obj.Text="v"..VERSION.." · CLEAN" end
                elseif text=="BGS Legacy Hub 0.4.0" then obj.Text="BGS Legacy Hub "..VERSION end
            end
        end
    end

    rebuildIslands()
    lightEggs()
    buildPickupCache()
    hookPickups()
    S.pickups=pickups
    S.version=VERSION
    S.nextScan=os.clock()+12
    S.status="BGS Legacy Hub v"..VERSION.." CLEAN"
    return S
end
