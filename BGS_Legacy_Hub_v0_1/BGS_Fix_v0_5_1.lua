-- BGS Legacy Hub v0.5.1
-- Fixes:
--  * disables the heavy v0.5 coin loop and replaces it with cached/event-driven pickup farming
--  * exact-name canonical TP, but robust to different Worlds/Islands nesting
--  * no fuzzy Island/Isle discovery
--  * no Portal/Spawn landing points

return function(S)
    if type(S) ~= "table" then return S end

    local VERSION="0.5.1"
    local Players=game:GetService("Players")
    local player=Players.LocalPlayer
    local playerGui=player and player:FindFirstChildOfClass("PlayerGui")
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
    -- CANONICAL TELEPORT
    ------------------------------------------------------------------------

    local WORLD_ALIASES={
        ["Overworld"]={"The Overworld","Overworld"},
        ["Candy Land"]={"Candy Land","CandyLand"},
        ["Toy Land"]={"Toy Land","ToyLand"},
        ["Beach World"]={"Beach World","BeachWorld"},
        ["Atlantis"]={"Atlantis"},
        ["Rainbow Land"]={"Rainbow Land","RainbowLand"},
        ["Underworld"]={"Underworld","The Underworld"},
        ["Mystic Forest"]={"Mystic Forest","MysticForest"},
        ["Heaven"]={"Heaven","Heaven World","HeavenWorld"},
    }

    local ISLANDS={
        {"Overworld","Starter Area",{"Starter Area","Main Island"},"normal"},
        {"Overworld","The Floating Island",{"The Floating Island"},"normal"},
        {"Overworld","Space",{"Space","Outer Space"},"gem"},
        {"Overworld","The Twilight",{"The Twilight"},"gem"},
        {"Overworld","The Skylands",{"The Skylands","The Skyland","Skylands"},"gem"},
        {"Overworld","The Void",{"The Void"},"gem"},
        {"Overworld","Zen",{"Zen"},"gem"},
        {"Overworld","XP Island",{"XP Island"},"gem"},

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

    local BAD={portal=true,spawn=true,fasttravel=true,teleport=true,door=true,gate=true,button=true,unlockhitbox=true,preview=true,showcase=true,display=true,map=true,gui=true}
    local function badPath(obj,stop)
        local p=obj
        while p and p~=stop and p~=workspace do
            local low=tostring(p.Name):lower():gsub("[%s%p_]","")
            for word in pairs(BAD) do if low:find(word,1,true) then return true end end
            p=p.Parent
        end
        return false
    end

    local function worldsRoot()
        return workspace:FindFirstChild("Worlds") or workspace
    end

    local function findWorld(worldKey)
        local aliases=WORLD_ALIASES[worldKey] or {worldKey}
        local wr=worldsRoot()
        for _,obj in ipairs(wr:GetChildren()) do
            if exact(obj.Name,aliases) then return obj end
        end
        -- Robust nesting, still exact-name only.
        for _,obj in ipairs(wr:GetDescendants()) do
            if (obj:IsA("Folder") or obj:IsA("Model")) and exact(obj.Name,aliases) and obj:FindFirstChild("Islands") then return obj end
        end
        return nil
    end

    local function findIsland(worldKey,aliases)
        local world=findWorld(worldKey)
        if not world then return nil end
        local islands=world:FindFirstChild("Islands")
        if not islands then
            for _,obj in ipairs(world:GetDescendants()) do
                if obj.Name=="Islands" and (obj:IsA("Folder") or obj:IsA("Model")) then islands=obj break end
            end
        end
        if not islands then return nil end
        for _,obj in ipairs(islands:GetChildren()) do if exact(obj.Name,aliases) then return obj end end
        for _,obj in ipairs(islands:GetDescendants()) do
            if (obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart")) and exact(obj.Name,aliases) then return obj end
        end
        return nil
    end

    local function landingPart(node)
        if not node then return nil end
        local body=node:FindFirstChild("Island") or node
        local best,bestScore=nil,-math.huge
        local function consider(p)
            if not p:IsA("BasePart") or p.Transparency>=0.98 or badPath(p,body) then return end
            local flat=math.abs(p.CFrame.UpVector.Y)
            local area=p.Size.X*p.Size.Z
            local score=area*(p.CanCollide and 3 or 0.2)*(flat>0.70 and 3 or 0.2)
            if p.Size.X<5 or p.Size.Z<5 then score*=0.08 end
            if score>bestScore then best,bestScore=p,score end
        end
        if body:IsA("BasePart") then consider(body) else for _,p in ipairs(body:GetDescendants()) do consider(p) end end
        return best
    end

    local function defFromEntry(entry)
        if not entry then return nil end
        local ew=tostring(entry.world or entry.rawWorld or "")
        for _,d in ipairs(ISLANDS) do
            if (ew=="" or norm(ew)==norm(d[1]) or exact(ew,WORLD_ALIASES[d[1]])) and exact(entry.name,d[3]) then return d end
        end
        for _,d in ipairs(ISLANDS) do if exact(entry.name,d[3]) then return d end end
        return nil
    end

    local function rebuildCanonicalList()
        local oldName=S.selectedIsland and S.selectedIsland.name
        local oldWorld=S.selectedIsland and (S.selectedIsland.world or S.selectedIsland.rawWorld)
        local list={}
        for i,d in ipairs(ISLANDS) do
            local node=findIsland(d[1],d[3])
            if node then
                local part=landingPart(node)
                if part then
                    list[#list+1]={object=node,part=part,landingPart=part,name=d[2],world=d[1],rawWorld=d[1],kind=d[4],order=i,canonical=true}
                end
            end
        end
        if #list>0 then
            S.islands=list
            S.selectedIsland=nil
            if oldName then
                for _,e in ipairs(list) do
                    if e.name==oldName and (not oldWorld or norm(e.world)==norm(oldWorld)) then S.selectedIsland=e break end
                end
            end
        end
        return list
    end

    function S:SelectIsland(entry)
        local d=defFromEntry(entry)
        if not d then self.status="ТП: остров не из списка" return false end
        self.selectedIsland=entry
        self.status="Выбрано: "..d[2]
        return true
    end

    function S:GoIsland(entry)
        entry=entry or self.selectedIsland
        local d=defFromEntry(entry)
        if not d then self.status="ТП: выбери остров" return false end
        local node=findIsland(d[1],d[3])
        if not node then self.status="ТП: "..d[2].." не найден в "..d[1] return false end
        local p=landingPart(node)
        local r,h=root(),hum()
        if not p then self.status="ТП: поверхность "..d[2].." не найдена" return false end
        if not r or not h or h.Health<=0 then self.status="ТП: жду персонажа" return false end
        stopMove()
        h.Sit=false
        local up=math.max(4,h.HipHeight+r.Size.Y/2+1.7)
        local pos=p.CFrame:PointToWorldSpace(Vector3.new(0,p.Size.Y/2+up,0))
        r.CFrame=CFrame.new(pos)*(r.CFrame-r.Position)
        r.AssemblyLinearVelocity=Vector3.zero
        r.AssemblyAngularVelocity=Vector3.zero
        self.selectedIsland=entry
        self.collectIslandLock=entry
        self.currentIslandName=d[2]
        self.travelUntil=os.clock()+0.7
        self.status="ТП: "..d[2]
        return true
    end

    ------------------------------------------------------------------------
    -- LIGHT COIN FARM
    ------------------------------------------------------------------------

    local pickupFolder=workspace:FindFirstChild("Pickups",true)
    local cache={}
    local objectByInstance=setmetatable({},{__mode="k"})
    local farmConns={}
    local target=nil
    local targetStart=0
    local targetBest=math.huge
    local targetProgress=0
    local nextMove=0
    local anchor=nil
    local skipped=setmetatable({},{__mode="k"})

    local function currencyOf(obj)
        local p=obj
        local depth=0
        local map={coin="Coins",gem="Gems",candy="Candy",block="Blocks",shell="Shells",pearl="Pearls",star="Stars",magma="Magma",crystal="Crystals"}
        while p and p~=workspace and depth<6 do
            local attr=p:GetAttribute("Currency") or p:GetAttribute("CurrencyType") or p:GetAttribute("PickupType")
            if attr~=nil then return tostring(attr) end
            local low=tostring(p.Name):lower()
            for k,v in pairs(map) do if low:find(k,1,true) then return v end end
            p=p.Parent depth+=1
        end
        return "Другое"
    end

    local function ownerOf(part)
        if not pickupFolder then return part end
        local p=part
        local best=part
        local depth=0
        while p and p.Parent and p.Parent~=pickupFolder and depth<4 do
            if p.Parent:IsA("Model") then best=p.Parent end
            p=p.Parent depth+=1
        end
        return best
    end

    local function touchScore(p)
        if not p:IsA("BasePart") then return -1 end
        local low=p.Name:lower()
        local touch=p:FindFirstChild("TouchInterest")~=nil
        local hit=low:find("hitbox",1,true) or low:find("touch",1,true) or low:find("collect",1,true) or low:find("pickup",1,true)
        if not touch and not p.CanTouch and not hit then return -1 end
        return (touch and 10000 or 0)+(hit and 5000 or 0)+(p.CanTouch and 1000 or 0)+(p.Transparency>=0.98 and (touch or hit) and 800 or 0)+math.min(400,p.Size.Magnitude*4)
    end

    local function addPickupPart(part)
        if not pickupFolder or not part:IsDescendantOf(pickupFolder) or not part:IsA("BasePart") then return end
        local score=touchScore(part)
        if score<0 then return end
        local owner=ownerOf(part)
        local old=cache[owner]
        if not old or score>old.score or not old.part.Parent then
            cache[owner]={object=owner,part=part,score=score,currency=currencyOf(owner)}
        end
        objectByInstance[part]=owner
    end

    local function fullPickupScan()
        cache={}
        objectByInstance=setmetatable({},{__mode="k"})
        pickupFolder=workspace:FindFirstChild("Pickups",true)
        if not pickupFolder then return end
        for _,p in ipairs(pickupFolder:GetDescendants()) do addPickupPart(p) end
    end

    local function valid(item)
        return item and item.object and item.object.Parent and item.part and item.part.Parent and item.part:IsDescendantOf(workspace) and item.object:GetAttribute("Collected")~=true
    end

    local function clearTarget(cooldown)
        if target and cooldown and target.object then skipped[target.object]=os.clock()+cooldown end
        target=nil targetStart=0 targetBest=math.huge targetProgress=0
    end

    local function worldForPosition(pos)
        local wr=worldsRoot()
        local best=nil
        local bestD=math.huge
        for key in pairs(WORLD_ALIASES) do
            local w=findWorld(key)
            if w then
                local ok,cf,size=pcall(function() return w:GetBoundingBox() end)
                if ok and cf and size then
                    local localPos=cf:PointToObjectSpace(pos)
                    local inside=math.abs(localPos.X)<=size.X/2+80 and math.abs(localPos.Y)<=size.Y/2+150 and math.abs(localPos.Z)<=size.Z/2+80
                    if inside then
                        local d=(pos-cf.Position).Magnitude
                        if d<bestD then best,bestD=key,d end
                    end
                end
            end
        end
        return best
    end

    local function allowed(item)
        if not valid(item) then return false end
        if S.currency~="Все" and item.currency~=S.currency then return false end
        local pos=item.part.Position
        if S.collectCurrentIslandOnly then
            if not anchor then local r=root() anchor=r and r.Position or nil end
            if not anchor then return false end
            local d=pos-anchor
            return Vector2.new(d.X,d.Z).Magnitude<=285 and math.abs(d.Y)<=120
        end
        local wanted=S.farmWorld or "Overworld"
        return worldForPosition(pos)==wanted
    end

    local function nearest(now)
        local r=root()
        if not r then return nil,nil end
        local best,bestD=nil,math.huge
        for owner,item in pairs(cache) do
            if not owner.Parent then cache[owner]=nil
            elseif allowed(item) and now>=(skipped[owner] or 0) then
                local d=(item.part.Position-r.Position).Magnitude
                if d<bestD then best,bestD=item,d end
            end
        end
        return best,bestD
    end

    local sweep=1
    local function moveThrough(item,d)
        local r,h=root(),hum()
        if not r or not h then return end
        local delta=item.part.Position-r.Position
        local dir=Vector3.new(delta.X,0,delta.Z)
        if dir.Magnitude<0.2 then
            local look=r.CFrame.LookVector
            dir=Vector3.new(look.X,0,look.Z)
        end
        if dir.Magnitude<0.2 then dir=Vector3.new(1,0,0) end
        dir=dir.Unit
        if d<=9 then
            h:MoveTo(item.part.Position+dir*(6*sweep))
            sweep=-sweep
        else
            h:MoveTo(item.part.Position+dir*3.5)
        end
    end

    local function farmStep(now)
        if not S.autoCollect or S.selling or now<(S.travelUntil or 0) or not ready() then return end
        if not pickupFolder or not pickupFolder.Parent then fullPickupScan() end
        if target and not allowed(target) then clearTarget() end
        if not target then
            local d
            target,d=nearest(now)
            if not target then
                stopMove()
                S.collectStatus=S.collectCurrentIslandOnly and "Жду монеты · текущая зона" or ("Жду монеты · "..tostring(S.farmWorld))
                return
            end
            targetStart=now targetBest=d or math.huge targetProgress=now sweep=1
        end
        local r=root()
        if not r or not valid(target) then clearTarget() return end
        local d=(target.part.Position-r.Position).Magnitude
        S.collectStatus=tostring(target.currency).." · "..math.floor(d).." studs"
        if d<targetBest-0.35 then targetBest=d targetProgress=now end
        if now-targetStart>3.8 then clearTarget(5) S.collectStatus="Пропустил залипшую монету" return end
        if now<nextMove then return end
        nextMove=now+(d<=9 and 0.28 or 0.18)
        moveThrough(target,d)
        if d>12 and now-targetProgress>1.25 then
            local h=hum() if h then h.Jump=true end
            targetProgress=now
        end
    end

    fullPickupScan()
    if pickupFolder then
        farmConns[#farmConns+1]=pickupFolder.DescendantAdded:Connect(function(obj)
            if obj:IsA("BasePart") then task.defer(addPickupPart,obj) end
        end)
        farmConns[#farmConns+1]=pickupFolder.DescendantRemoving:Connect(function(obj)
            local owner=objectByInstance[obj]
            if owner and cache[owner] and cache[owner].part==obj then cache[owner]=nil end
            if target and (target.part==obj or target.object==obj) then clearTarget() end
        end)
    end

    ------------------------------------------------------------------------
    -- WRAP OLD TICK: bypass v0.5 heavy coin loop, throttle legacy work.
    ------------------------------------------------------------------------

    local oldTick=S.Tick
    local lastLegacy=0
    function S:Tick()
        if not self.alive then return end
        local now=os.clock()
        local collect=self.autoCollect

        -- v0.5.0 coinStep is the source of repeated full scans. Keep it disabled.
        self.autoCollect=false
        if now-lastLegacy>=0.10 then
            lastLegacy=now
            local ok,problem=pcall(oldTick,self)
            if not ok then self.status="Цикл: "..tostring(problem):sub(1,100) end
        end
        self.autoCollect=collect

        if collect then
            local ok,problem=pcall(farmStep,now)
            if not ok then self.collectStatus="Фарм: "..tostring(problem):sub(1,90) self.status=self.collectStatus end
        end
    end

    local oldSetMode=S.SetMode
    if type(oldSetMode)=="function" then
        function S:SetMode(key,value)
            local result=oldSetMode(self,key,value)
            if key=="autoCollect" then
                clearTarget()
                local r=root()
                anchor=value and r and r.Position or nil
                if value then
                    if not pickupFolder or not pickupFolder.Parent or next(cache)==nil then fullPickupScan() end
                    self.collectStatus="Ищу монеты · light farm"
                else
                    stopMove()
                    self.collectStatus="Выключено"
                end
            end
            return result
        end
    end

    local oldHardStop=S.HardStop
    if type(oldHardStop)=="function" then
        function S:HardStop()
            clearTarget()
            anchor=nil
            stopMove()
            return oldHardStop(self)
        end
    end

    local oldStop=S.Stop
    if type(oldStop)=="function" then
        function S:Stop(reason)
            for _,c in ipairs(farmConns) do pcall(function() c:Disconnect() end) end
            farmConns={}
            return oldStop(self,reason)
        end
    end

    -- Re-anchor when user changes farm scope/world in the v0.5 UI.
    task.spawn(function()
        local lastScope=S.collectCurrentIslandOnly
        local lastWorld=S.farmWorld
        while S.alive do
            task.wait(0.5)
            if S.collectCurrentIslandOnly~=lastScope or S.farmWorld~=lastWorld then
                lastScope=S.collectCurrentIslandOnly
                lastWorld=S.farmWorld
                clearTarget()
                local r=root()
                anchor=S.collectCurrentIslandOnly and r and r.Position or nil
            end
        end
    end)

    rebuildCanonicalList()
    S.version=VERSION

    local gui=playerGui:FindFirstChild("BGSLegacyHub")
    if gui then
        for _,obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                local text=tostring(obj.Text or "")
                if text:find("0.5.0",1,true) then obj.Text=text:gsub("0%.5%.0",VERSION)
                elseif text:find("0.4.8",1,true) then obj.Text=text:gsub("0%.4%.8",VERSION) end
            end
        end
    end
    S.status="BGS Legacy Hub v"..VERSION.." · farm/TP fix"
    return S
end
