-- BGS Legacy Hub v0.5.0
-- Major patch:
--  * canonical name-based island TP (no fuzzy island discovery)
--  * farm-world selector for 9 worlds
--  * current-island OR selected-world coin farming
--  * AFK chest route with exact island whitelist + return to saved position
--  * auto hatch can run together with coin farm, 1x / 3x mode, optional hatch-anywhere
--  * version labels fixed to v0.5.0
--
-- Shiny/minigame/potion automation is intentionally not guessed here: the original game
-- routes many actions through one NetworkRemoteEvent string contract. v0.5.0 exposes
-- diagnostics for those action names instead of blindly firing destructive guesses.

return function(S)
    if type(S) ~= "table" then return S end

    local VERSION = "0.5.0"
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if not player or not playerGui then return S end

    local function root()
        local c = player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function hum()
        local c = player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    local function ready()
        local r,h = root(),hum()
        return r ~= nil and h ~= nil and h.Health > 0
    end

    local function stopMove()
        local r,h = root(),hum()
        if r and h then
            pcall(function()
                h:MoveTo(r.Position)
                h:Move(Vector3.zero,false)
            end)
        end
    end

    local function norm(v)
        return tostring(v or ""):lower():gsub("[%s%p_]","")
    end

    local BAD_PART_WORDS = {
        "portal","spawn","fasttravel","teleport","door","gate","button",
        "unlockhitbox","preview","showcase","display","map","gui"
    }

    local function badPart(part, stopAt)
        local p = part
        while p and p ~= stopAt and p ~= workspace do
            local low = tostring(p.Name):lower()
            for _,word in ipairs(BAD_PART_WORDS) do
                if low:find(word,1,true) then return true end
            end
            p = p.Parent
        end
        return false
    end

    local WORLD_DEFS = {
        {key="Overworld", display="Overworld (спавн)", aliases={"The Overworld","Overworld"}},
        {key="Candy Land", display="Candy Land (мир конфет)", aliases={"Candy Land","CandyLand"}},
        {key="Toy Land", display="Toy Land (мир игрушек)", aliases={"Toy Land","ToyLand"}},
        {key="Beach World", display="Beach World (пляжный мир)", aliases={"Beach World","BeachWorld"}},
        {key="Atlantis", display="Atlantis (Атлантида)", aliases={"Atlantis"}},
        {key="Rainbow Land", display="Rainbow Land (радужный мир)", aliases={"Rainbow Land","RainbowLand"}},
        {key="Underworld", display="Underworld (вулканический мир)", aliases={"Underworld","The Underworld"}},
        {key="Mystic Forest", display="Mystic Forest (мифическое дерево)", aliases={"Mystic Forest","MysticForest"}},
        {key="Heaven", display="Heaven (райский мир)", aliases={"Heaven","Heaven World","HeavenWorld"}},
    }

    local WORLD_BY_KEY = {}
    for _,w in ipairs(WORLD_DEFS) do WORLD_BY_KEY[w.key] = w end

    local ISLAND_DEFS = {}
    local function addIsland(world, name, aliases, kind)
        local d = {world=world,name=name,aliases=aliases or {name},kind=kind or "normal",order=#ISLAND_DEFS+1}
        ISLAND_DEFS[#ISLAND_DEFS+1] = d
        return d
    end

    addIsland("Overworld","Starter Area",{"Starter Area","Main Island"},"normal")
    addIsland("Overworld","The Floating Island",{"The Floating Island"},"normal")
    addIsland("Overworld","Space",{"Space"},"gem")
    addIsland("Overworld","The Twilight",{"The Twilight"},"gem")
    addIsland("Overworld","The Skylands",{"The Skylands","The Skyland","Skylands"},"gem")
    addIsland("Overworld","The Void",{"The Void"},"gem")
    addIsland("Overworld","Zen",{"Zen"},"gem")
    addIsland("Overworld","XP Island",{"XP Island"},"gem")

    addIsland("Candy Land","Gumdrop Island",{"Gumdrop Island"})
    addIsland("Candy Land","Rewards Island",{"Rewards Island","Candy Rewards"})
    addIsland("Candy Land","Sugar Island",{"Sugar Island"})
    addIsland("Candy Land","Candy Island",{"Candy Island"})
    addIsland("Candy Land","Sweet Island",{"Sweet Island"})

    addIsland("Toy Land","Block Island",{"Block Island"})
    addIsland("Toy Land","Block Rewards",{"Block Rewards"})
    addIsland("Toy Land","Toy Isle",{"Toy Isle"})
    addIsland("Toy Land","Teddy Island",{"Teddy Island"})
    addIsland("Toy Land","Treasure Isle",{"Treasure Isle","Treasure Island"})

    addIsland("Beach World","Sea Island",{"Sea Island"})
    addIsland("Beach World","Sea Rewards",{"Sea Rewards"})
    addIsland("Beach World","Shell Isle",{"Shell Isle"})
    addIsland("Beach World","Oceanic Island",{"Oceanic Island"})
    addIsland("Beach World","Sea Shell Island",{"Sea Shell Island","Sea Shell Isle","See Shell Isle"})

    addIsland("Atlantis","Water Island",{"Water Island"})
    addIsland("Atlantis","Atlantis Rewards",{"Atlantis Rewards"})
    addIsland("Atlantis","Atlantis Isle",{"Atlantis Isle"})
    addIsland("Atlantis","Treasure Island",{"Treasure Island"})
    addIsland("Atlantis","Sandy Island",{"Sandy Island"})

    addIsland("Rainbow Land","Red Island",{"Red Island"})
    addIsland("Rainbow Land","Rainbow Rewards",{"Rainbow Rewards"})
    addIsland("Rainbow Land","Green Island",{"Green Island"})
    addIsland("Rainbow Land","Blue Island",{"Blue Island"})
    addIsland("Rainbow Land","Purple Island",{"Purple Island"})

    addIsland("Underworld","Fire Island",{"Fire Island"})
    addIsland("Underworld","Magma Rewards",{"Magma Rewards"})
    addIsland("Underworld","Magma Island",{"Magma Island"})
    addIsland("Underworld","Inferno Island",{"Inferno Island"})
    addIsland("Underworld","Molten Island",{"Molten Island"})

    addIsland("Mystic Forest","Crystal Island",{"Crystal Island"},"gem")
    addIsland("Mystic Forest","Crystal Rewards",{"Crystal Rewards"},"gem")
    addIsland("Mystic Forest","Mythic Island",{"Mythic Island"},"gem")
    addIsland("Mystic Forest","Spirit Island",{"Spirit Island"},"gem")
    addIsland("Mystic Forest","Magic Island",{"Magic Island"},"gem")

    addIsland("Heaven","Light Island",{"Light Island"},"gem")
    addIsland("Heaven","Cloud Island",{"Cloud Island","Claud Island"},"gem")
    addIsland("Heaven","Spirit Island",{"Spirit Island"},"gem")

    local CHEST_DEFS = {
        {world="Overworld",name="The Floating Island",aliases={"The Floating Island"}},
        {world="Overworld",name="The Skylands",aliases={"The Skylands","The Skyland","Skylands"}},
        {world="Overworld",name="The Void",aliases={"The Void"}},
        {world="Candy Land",name="Gumdrop Island",aliases={"Gumdrop Island"}},
        {world="Candy Land",name="Candy Island",aliases={"Candy Island"}},
        {world="Candy Land",name="Sweet Island",aliases={"Sweet Island"}},
        {world="Toy Land",name="Block Rewards",aliases={"Block Rewards"}},
        {world="Toy Land",name="Teddy Island",aliases={"Teddy Island"}},
        {world="Toy Land",name="Treasure Isle",aliases={"Treasure Isle","Treasure Island"}},
        {world="Beach World",name="Sea Island",aliases={"Sea Island"}},
        {world="Beach World",name="Oceanic Island",aliases={"Oceanic Island"}},
        {world="Beach World",name="Sea Shell Island",aliases={"Sea Shell Island","Sea Shell Isle","See Shell Isle"}},
        {world="Atlantis",name="Water Island",aliases={"Water Island"}},
        {world="Atlantis",name="Sandy Island",aliases={"Sandy Island"}},
        {world="Rainbow Land",name="Red Island",aliases={"Red Island"}},
        {world="Rainbow Land",name="Blue Island",aliases={"Blue Island"}},
        {world="Rainbow Land",name="Purple Island",aliases={"Purple Island"}},
        {world="Underworld",name="Fire Island",aliases={"Fire Island"}},
        {world="Underworld",name="Inferno Island",aliases={"Inferno Island"}},
        {world="Mystic Forest",name="Crystal Island",aliases={"Crystal Island"}},
        {world="Heaven",name="Light Island",aliases={"Light Island"}},
        {world="Heaven",name="Cloud Island",aliases={"Cloud Island","Claud Island"}},
        {world="Heaven",name="Spirit Island",aliases={"Spirit Island"}},
    }

    local function exactName(name, aliases)
        local n = norm(name)
        for _,a in ipairs(aliases or {}) do
            if n == norm(a) then return true end
        end
        return false
    end

    local function worldsFolder()
        return workspace:FindFirstChild("Worlds")
    end

    local function findWorldNode(worldKey)
        local def = WORLD_BY_KEY[worldKey]
        local folder = worldsFolder()
        if not def or not folder then return nil end
        for _,child in ipairs(folder:GetChildren()) do
            if exactName(child.Name,def.aliases) then return child end
        end
        return nil
    end

    local function findIslandNode(def)
        if not def then return nil end
        local world = findWorldNode(def.world)
        if not world then return nil end
        local islands = world:FindFirstChild("Islands")
        if not islands then return nil end
        for _,node in ipairs(islands:GetChildren()) do
            if exactName(node.Name,def.aliases) then return node end
        end
        return nil
    end

    local function surfaceOfIsland(node)
        if not node then return nil,nil end
        local body = node:FindFirstChild("Island") or node
        local best,bestScore = nil,-math.huge
        local minX,maxX,minY,maxY,minZ,maxZ

        local function consider(p)
            if not p:IsA("BasePart") then return end
            if p.Transparency >= 0.98 then return end
            if badPart(p,body) then return end
            local area = math.max(0.01,p.Size.X*p.Size.Z)
            local flat = math.abs(p.CFrame.UpVector.Y)
            local score = area * (p.CanCollide and 2.4 or 0.35) * (flat >= 0.72 and 2.7 or 0.25)
            if p.Size.X < 5 or p.Size.Z < 5 then score *= 0.18 end
            if score > bestScore then best,bestScore = p,score end

            local px,py,pz = p.Position.X,p.Position.Y,p.Position.Z
            local hx,hy,hz = p.Size.X/2,p.Size.Y/2,p.Size.Z/2
            minX = minX and math.min(minX,px-hx) or px-hx
            maxX = maxX and math.max(maxX,px+hx) or px+hx
            minY = minY and math.min(minY,py-hy) or py-hy
            maxY = maxY and math.max(maxY,py+hy) or py+hy
            minZ = minZ and math.min(minZ,pz-hz) or pz-hz
            maxZ = maxZ and math.max(maxZ,pz+hz) or pz+hz
        end

        if body:IsA("BasePart") then
            consider(body)
        else
            for _,p in ipairs(body:GetDescendants()) do consider(p) end
        end

        if not best or not minX or best.Size.X*best.Size.Z < 40 then return nil,nil end
        local bounds = {
            minX=minX,maxX=maxX,minY=minY,maxY=maxY,minZ=minZ,maxZ=maxZ,
            center=Vector3.new((minX+maxX)/2,(minY+maxY)/2,(minZ+maxZ)/2),
            size=Vector3.new(maxX-minX,maxY-minY,maxZ-minZ),
        }
        return best,bounds
    end

    local function canonicalIslands()
        local list = {}
        for _,def in ipairs(ISLAND_DEFS) do
            local node = findIslandNode(def)
            if node then
                local part,bounds = surfaceOfIsland(node)
                if part and bounds then
                    list[#list+1] = {
                        object=node,part=part,landingPart=part,bounds=bounds,
                        name=def.name,world=def.world,rawWorld=def.world,
                        canonical=true,canonicalDef=def,kind=def.kind,order=def.order,y=bounds.center.Y,
                    }
                end
            end
        end
        return list
    end

    local function islandDefForEntry(entry)
        if not entry then return nil end
        if entry.canonicalDef then return entry.canonicalDef end
        for _,def in ipairs(ISLAND_DEFS) do
            if def.world == tostring(entry.world or entry.rawWorld or "") and exactName(entry.name,def.aliases) then return def end
        end
        for _,def in ipairs(ISLAND_DEFS) do
            if exactName(entry.name,def.aliases) then return def end
        end
        return nil
    end

    local function teleportToIsland(entry)
        local def = islandDefForEntry(entry)
        if not def then return false,"ТП: острова нет в каноническом списке" end
        local node = findIslandNode(def)
        if not node then return false,"ТП: "..def.name.." сейчас не загружен" end
        local part,bounds = surfaceOfIsland(node)
        if not part then return false,"ТП: площадка острова не найдена" end
        local r,h = root(),hum()
        if not r or not h or h.Health <= 0 then return false,"ТП: жду персонажа" end

        stopMove()
        h.Sit = false
        local up = math.max(4,h.HipHeight+r.Size.Y/2+1.4)
        local p = part.CFrame:PointToWorldSpace(Vector3.new(0,part.Size.Y/2+up,0))
        r.CFrame = CFrame.new(p)*(r.CFrame-r.Position)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero

        entry.object=node
        entry.part=part
        entry.landingPart=part
        entry.bounds=bounds
        S.collectIslandLock=entry
        S.currentIslandName=def.name
        S.travelUntil=os.clock()+0.8
        S.status="ТП: "..def.name
        return true
    end

    local previousRefresh = S.Refresh
    if type(previousRefresh)=="function" then
        function S:Refresh(...)
            local selectedName = self.selectedIsland and self.selectedIsland.name
            local selectedWorld = self.selectedIsland and self.selectedIsland.world
            local result = previousRefresh(self,...)
            local list = canonicalIslands()
            if #list > 0 then
                self.islands = list
                self.selectedIsland=nil
                if selectedName then
                    for _,entry in ipairs(list) do
                        if entry.name==selectedName and (not selectedWorld or entry.world==selectedWorld) then
                            self.selectedIsland=entry
                            break
                        end
                    end
                end
            end
            return result
        end
    end

    function S:SelectIsland(entry)
        local def=islandDefForEntry(entry)
        if not def then self.status="ТП: неизвестный остров заблокирован" return false end
        self.selectedIsland=entry
        self.status="Выбрано: "..def.name
        return true
    end

    function S:GoIsland(entry)
        entry=entry or self.selectedIsland
        local ok,problem=teleportToIsland(entry)
        if not ok then self.status=tostring(problem) end
        return ok
    end

    local networkCache=nil
    local function network()
        if networkCache and networkCache.Parent then return networkCache end
        local n=RS:FindFirstChild("NetworkRemoteEvent",true)
        networkCache=n and n:IsA("RemoteEvent") and n or nil
        return networkCache
    end

    local remoteTimes={}
    local function safeFire(action,...)
        local n=network()
        if not n then return false,"NetworkRemoteEvent не найден" end
        local now=os.clock()
        local fresh={}
        for _,t in ipairs(remoteTimes) do if now-t<1 then fresh[#fresh+1]=t end end
        remoteTimes=fresh
        if #remoteTimes>=8 then return false,"лимит запросов" end
        remoteTimes[#remoteTimes+1]=now
        local args={...}
        local ok,problem=pcall(function() n:FireServer(action,table.unpack(args)) end)
        return ok,problem
    end

    S.hatchCount = 1
    S.hatchAnywhere = true
    S.teleportOnSelect = false
    local lastHatch50=-math.huge

    local function validEgg(e)
        return e and e.object and e.object.Parent and e.part and e.part.Parent and e.object:IsDescendantOf(workspace)
    end

    local function hatchBurst(now)
        if not S.autoHatch then return end
        local e=S.selectedEgg
        if not validEgg(e) then S.hatchStatus="Выбери яйцо" return end
        if tostring(e.currency or ""):lower():find("robux",1,true) then S.hatchStatus="Robux-яйцо вручную" return end
        if now-lastHatch50 < math.max(0.45,tonumber(S.hatchDelay) or 0.8) then return end

        if not S.hatchAnywhere then
            local r=root()
            if not r then return end
            local d=(e.part.Position-r.Position).Magnitude
            if d>15.5 then
                S.hatchStatus="Слишком далеко: "..math.floor(d).." studs"
                return
            end
        end

        lastHatch50=now
        local count=(S.hatchCount==3) and 3 or 1
        local sent=0
        for _=1,count do
            local ok=safeFire("PurchaseEgg",e.name)
            if ok then sent+=1 end
        end
        S.hatchStatus="Открываю x"..tostring(count)..": "..tostring(e.name)
        S.status=S.hatchStatus.." · запросов "..sent
    end

    function S:HatchOnce()
        local old=self.autoHatch
        self.autoHatch=true
        lastHatch50=-math.huge
        hatchBurst(os.clock())
        self.autoHatch=old
        return true
    end

    local function readMeta(object,keys)
        local p=object
        local depth=0
        while p and p~=workspace and depth<7 do
            for _,key in ipairs(keys) do
                local ok,value=pcall(function() return p:GetAttribute(key) end)
                if ok and value~=nil then return tostring(value) end
                local child=p:FindFirstChild(key)
                if child and child:IsA("ValueBase") then return tostring(child.Value) end
            end
            p=p.Parent
            depth+=1
        end
        return nil
    end

    local currencyWords={coins="Coins",coin="Coins",gems="Gems",gem="Gems",candy="Candy",blocks="Blocks",shells="Shells",pearls="Pearls",stars="Stars",magma="Magma",crystals="Crystals",crystal="Crystals"}
    local function currencyOf(object)
        local meta=readMeta(object,{"Currency","CurrencyType","PickupType","Type"})
        if meta then return meta end
        local p=object
        local depth=0
        while p and p~=workspace and depth<7 do
            local low=tostring(p.Name):lower()
            for key,value in pairs(currencyWords) do if low:find(key,1,true) then return value end end
            p=p.Parent depth+=1
        end
        return "Другое"
    end

    local function hasTouch(part)
        if not part or not part:IsA("BasePart") then return false end
        if part:FindFirstChild("TouchInterest") then return true end
        for _,c in ipairs(part:GetChildren()) do if c.ClassName=="TouchTransmitter" then return true end end
        return false
    end

    local function pickupOwner(part,container)
        local p=part
        local best=part
        local depth=0
        while p and p.Parent and p.Parent~=container and depth<4 do
            if p.Parent:IsA("Model") then best=p.Parent end
            p=p.Parent depth+=1
        end
        return best
    end

    local function scanPickups50()
        local container=workspace:FindFirstChild("Pickups",true)
        if not container then return {} end
        local bestBy={}
        for _,part in ipairs(container:GetDescendants()) do
            if part:IsA("BasePart") then
                local low=part.Name:lower()
                local touch=hasTouch(part)
                local hit=low:find("hitbox",1,true) or low:find("touch",1,true) or low:find("collect",1,true) or low:find("pickup",1,true)
                if touch or part.CanTouch or hit then
                    local object=pickupOwner(part,container)
                    local score=(touch and 10000 or 0)+(hit and 5000 or 0)+(part.CanTouch and 1200 or 0)+math.min(500,part.Size.Magnitude*5)
                    if part.Transparency>=0.98 and (touch or hit) then score+=900 end
                    local old=bestBy[object]
                    if not old or score>old.score then bestBy[object]={object=object,part=part,score=score} end
                end
            end
        end
        local result={}
        for object,v in pairs(bestBy) do result[#result+1]={object=object,part=v.part,currency=currencyOf(object)} end
        return result
    end

    local function validPickup(item)
        return item and item.object and item.object.Parent and item.part and item.part.Parent and item.part:IsDescendantOf(workspace) and item.object:GetAttribute("Collected")~=true
    end

    local worldBoundsCache={}
    local worldBoundsAt=0
    local function worldBounds(worldKey)
        local now=os.clock()
        if now-worldBoundsAt>8 then worldBoundsCache={} worldBoundsAt=now end
        if worldBoundsCache[worldKey] then return worldBoundsCache[worldKey] end
        local node=findWorldNode(worldKey)
        if not node then return nil end
        local minX,maxX,minY,maxY,minZ,maxZ
        for _,p in ipairs(node:GetDescendants()) do
            if p:IsA("BasePart") and not badPart(p,node) then
                local px,py,pz=p.Position.X,p.Position.Y,p.Position.Z
                local hx,hy,hz=p.Size.X/2,p.Size.Y/2,p.Size.Z/2
                minX=minX and math.min(minX,px-hx) or px-hx
                maxX=maxX and math.max(maxX,px+hx) or px+hx
                minY=minY and math.min(minY,py-hy) or py-hy
                maxY=maxY and math.max(maxY,py+hy) or py+hy
                minZ=minZ and math.min(minZ,pz-hz) or pz-hz
                maxZ=maxZ and math.max(maxZ,pz+hz) or pz+hz
            end
        end
        if not minX then return nil end
        local b={minX=minX,maxX=maxX,minY=minY,maxY=maxY,minZ=minZ,maxZ=maxZ,center=Vector3.new((minX+maxX)/2,(minY+maxY)/2,(minZ+maxZ)/2)}
        worldBoundsCache[worldKey]=b
        return b
    end

    local function insideBounds(pos,b,padY,padXZ)
        if not b then return false end
        padY=padY or 45 padXZ=padXZ or 40
        return pos.X>=b.minX-padXZ and pos.X<=b.maxX+padXZ
           and pos.Z>=b.minZ-padXZ and pos.Z<=b.maxZ+padXZ
           and pos.Y>=b.minY-padY and pos.Y<=b.maxY+padY
    end

    local function belongsToWorld(item,worldKey)
        local def=WORLD_BY_KEY[worldKey]
        if not def or not validPickup(item) then return false end

        local meta=readMeta(item.object,{"World","WorldName","Location","Area"})
        if meta and exactName(meta,def.aliases) then return true end

        local p=item.object
        local depth=0
        while p and p~=workspace and depth<9 do
            if exactName(p.Name,def.aliases) then return true end
            p=p.Parent depth+=1
        end

        local b=worldBounds(worldKey)
        return b and insideBounds(item.part.Position,b,120,80) or false
    end

    local function detectCurrentIsland50()
        local r=root()
        if not r then return nil end
        local best,bestD=nil,math.huge
        for _,entry in ipairs(S.islands or {}) do
            if entry.bounds and entry.object and entry.object.Parent and insideBounds(r.Position,entry.bounds,60,35) then
                local c=entry.bounds.center
                local d=(Vector2.new(r.Position.X,r.Position.Z)-Vector2.new(c.X,c.Z)).Magnitude+math.abs(r.Position.Y-c.Y)
                if d<bestD then best,bestD=entry,d end
            end
        end
        return best
    end

    local function detectCurrentWorld50()
        local r=root()
        if not r then return nil end
        for _,w in ipairs(WORLD_DEFS) do
            local b=worldBounds(w.key)
            if b and insideBounds(r.Position,b,130,90) then return w.key end
        end
        return nil
    end

    S.farmWorld = S.farmWorld or detectCurrentWorld50() or "Overworld"
    S.collectCurrentIslandOnly = S.collectCurrentIslandOnly ~= false

    local coinList={}
    local nextCoinScan=0
    local coinTarget=nil
    local coinTargetStarted=0
    local coinLastProgress=0
    local coinLastDistance=math.huge
    local coinNextMove=0
    local coinSweep=1
    local coinSkipped=setmetatable({},{__mode="k"})
    local localAnchor=nil

    local function clearCoinTarget(cooldown)
        if coinTarget and cooldown and coinTarget.object then coinSkipped[coinTarget.object]=os.clock()+cooldown end
        coinTarget=nil coinTargetStarted=0 coinLastProgress=0 coinLastDistance=math.huge coinSweep=1
    end

    local function eligiblePickups(all)
        local filtered={}
        if S.collectCurrentIslandOnly then
            local island=S.collectIslandLock
            if not island or not island.bounds or not island.object or not island.object.Parent then island=detectCurrentIsland50() S.collectIslandLock=island end
            if island and island.bounds then
                for _,item in ipairs(all) do if validPickup(item) and insideBounds(item.part.Position,island.bounds,70,55) then filtered[#filtered+1]=item end end
                S.currentIslandName=tostring(island.name or "остров")
                return filtered
            end

            local r=root()
            if not localAnchor and r then localAnchor=r.Position end
            if localAnchor then
                for _,item in ipairs(all) do
                    if validPickup(item) then
                        local delta=item.part.Position-localAnchor
                        if Vector2.new(delta.X,delta.Z).Magnitude<=280 and math.abs(delta.Y)<=120 then filtered[#filtered+1]=item end
                    end
                end
            end
            S.currentIslandName="текущая зона"
            return filtered
        end

        for _,item in ipairs(all) do if belongsToWorld(item,S.farmWorld) then filtered[#filtered+1]=item end end
        return filtered
    end

    local function rescanCoins(now)
        if now<nextCoinScan then return end
        nextCoinScan=now+0.7
        local all=scanPickups50()
        S._allPickups=all
        coinList=eligiblePickups(all)
        S.pickups=coinList
    end

    local function nearestCoin(now)
        local r=root()
        if not r then return nil,nil end
        local best,bestD=nil,math.huge
        for _,item in ipairs(coinList) do
            if validPickup(item) and now>=(coinSkipped[item.object] or 0) and (S.currency=="Все" or item.currency==S.currency) then
                local d=(item.part.Position-r.Position).Magnitude
                if d<bestD then best,bestD=item,d end
            end
        end
        return best,bestD
    end

    local function moveThroughCoin(item,near)
        local r,h=root(),hum()
        if not r or not h or h.Health<=0 then return end
        local delta=item.part.Position-r.Position
        local flat=Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude<0.2 then
            local look=r.CFrame.LookVector
            flat=Vector3.new(look.X,0,look.Z)
        end
        if flat.Magnitude<0.2 then flat=Vector3.new(1,0,0) end
        local dir=flat.Unit
        if near then
            h:MoveTo(item.part.Position+dir*(6*coinSweep))
            coinSweep=-coinSweep
        else
            h:MoveTo(item.part.Position+dir*4)
        end
    end

    local function coinStep(now)
        if not S.autoCollect or S.selling or now<(S.travelUntil or 0) then return end
        local r,h=root(),hum()
        if not r or not h or h.Health<=0 then return end
        rescanCoins(now)

        if coinTarget and (not validPickup(coinTarget) or (S.currency~="Все" and coinTarget.currency~=S.currency)) then clearCoinTarget() end
        if not coinTarget then
            local d
            coinTarget,d=nearestCoin(now)
            if not coinTarget then
                stopMove()
                if S.collectCurrentIslandOnly then
                    S.collectStatus="Жду новые монеты · "..tostring(S.currentIslandName or "остров")
                else
                    S.collectStatus="Жду монеты · "..tostring(S.farmWorld)
                end
                return
            end
            coinTargetStarted=now coinLastProgress=now coinLastDistance=d or math.huge coinSweep=1
        end

        local d=(coinTarget.part.Position-r.Position).Magnitude
        S.collectStatus=tostring(S.farmWorld).." · "..tostring(coinTarget.currency or "Монеты").." · "..math.floor(d).." studs"
        if d<coinLastDistance-0.35 then coinLastDistance=d coinLastProgress=now end

        if now-coinTargetStarted>4.0 then clearCoinTarget(6) S.collectStatus="Монета пропущена · застряла" return end
        if now<coinNextMove then return end
        coinNextMove=now+(d<=10 and 0.28 or 0.18)

        if d<=10 then
            moveThroughCoin(coinTarget,true)
        else
            moveThroughCoin(coinTarget,false)
            if now-coinLastProgress>1.2 then h.Jump=true coinLastProgress=now end
        end
    end

    S.autoChestRoute=false
    S.chestStatus="Выключено"
    local chestBusy=false
    local chestIndex=0
    local chestLastTry={}
    local nextChestCheck=0

    local function chestObjectOnIsland(def)
        local node=findIslandNode(def)
        if not node then return nil end

        local bestPrompt=nil
        local bestPart=nil
        local bestScore=-math.huge

        for _,obj in ipairs(node:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local p=obj.Parent
                local low=""
                local a=p
                local depth=0
                while a and a~=node and depth<4 do low=low.." "..a.Name:lower() a=a.Parent depth+=1 end
                if low:find("chest",1,true) or low:find("reward",1,true) then
                    if obj.Enabled then return {node=node,prompt=obj,part=p and p:IsA("BasePart") and p or p and p:FindFirstChildWhichIsA("BasePart",true)} end
                    bestPrompt=bestPrompt or obj
                end
            elseif obj:IsA("BasePart") then
                local low=obj.Name:lower()
                local parentLow=obj.Parent and obj.Parent.Name:lower() or ""
                if low:find("chest",1,true) or parentLow:find("chest",1,true) or low:find("reward",1,true) or parentLow:find("reward",1,true) then
                    local score=(obj.CanTouch and 1000 or 0)+(hasTouch(obj) and 5000 or 0)+obj.Size.Magnitude
                    if score>bestScore then bestPart,bestScore=obj,score end
                end
            end
        end

        if bestPrompt then
            local p=bestPrompt.Parent
            return {node=node,prompt=bestPrompt,part=p and p:IsA("BasePart") and p or p and p:FindFirstChildWhichIsA("BasePart",true)}
        end
        if bestPart then return {node=node,part=bestPart} end
        return nil
    end

    local function triggerChest(target)
        if not target or not target.part or not target.part.Parent then return false end
        local r,h=root(),hum()
        if not r or not h then return false end

        local p=target.part
        local up=math.max(3,h.HipHeight+r.Size.Y/2+0.8)
        r.CFrame=CFrame.new(p.Position+Vector3.new(0,p.Size.Y/2+up,0))*(r.CFrame-r.Position)
        r.AssemblyLinearVelocity=Vector3.zero r.AssemblyAngularVelocity=Vector3.zero
        task.wait(0.12)

        if target.prompt and target.prompt.Parent and target.prompt.Enabled then
            local ok=false
            if type(fireproximityprompt)=="function" then ok=pcall(fireproximityprompt,target.prompt) end
            if not ok then
                pcall(function()
                    target.prompt:InputHoldBegin()
                    task.wait(math.min(0.7,target.prompt.HoldDuration+0.05))
                    target.prompt:InputHoldEnd()
                end)
            end
        else
            h:MoveTo(p.Position)
            if type(firetouchinterest)=="function" then
                pcall(firetouchinterest,r,p,0)
                pcall(firetouchinterest,r,p,1)
            end
        end
        return true
    end

    local function chestStep(now)
        if not S.autoChestRoute or chestBusy or now<nextChestCheck or not ready() then return end
        nextChestCheck=now+2.0

        for _=1,#CHEST_DEFS do
            chestIndex=(chestIndex%#CHEST_DEFS)+1
            local def=CHEST_DEFS[chestIndex]
            local key=def.world.."/"..def.name
            if now-(chestLastTry[key] or -math.huge)>=60 then
                local target=chestObjectOnIsland(def)
                if target and target.part then
                    chestLastTry[key]=now
                    chestBusy=true
                    local r=root()
                    local saved=r and r.CFrame
                    clearCoinTarget()
                    stopMove()
                    S.chestStatus="Сундук: "..def.name
                    S.status="AFK сундук → "..def.name

                    task.spawn(function()
                        local ok=triggerChest(target)
                        task.wait(0.65)
                        local rr=root()
                        if rr and saved then
                            rr.CFrame=saved
                            rr.AssemblyLinearVelocity=Vector3.zero
                            rr.AssemblyAngularVelocity=Vector3.zero
                        end
                        S.travelUntil=os.clock()+0.45
                        chestBusy=false
                        clearCoinTarget()
                        nextCoinScan=0
                        S.chestStatus=ok and ("Проверен: "..def.name) or ("Не удалось: "..def.name)
                        S.status="Вернулся после сундука · продолжаю"
                    end)
                    return
                end
            end
        end
        S.chestStatus="Жду доступные сундуки"
    end

    S.autoShiny=false
    S.autoMinigames=false
    S.autoPotions=false
    S.experimentalStatus="Не включено"

    local function petGrid()
        local screen=playerGui:FindFirstChild("ScreenGui")
        local pets=screen and screen:FindFirstChild("PetsFrame")
        local main=pets and pets:FindFirstChild("Main")
        local pages=main and main:FindFirstChild("Pages")
        local petsPage=pages and pages:FindFirstChild("Pets")
        local list=petsPage and petsPage:FindFirstChild("List")
        return list and list:FindFirstChild("Grid")
    end

    local function countPetGroups()
        local grid=petGrid()
        if not grid then return {},"PetsFrame/Grid не найден" end
        local groups={}
        for _,cell in ipairs(grid:GetChildren()) do
            if cell:IsA("ImageButton") then
                local petName=nil
                local isShiny=false
                local frame=cell:FindFirstChild("Frame")
                local inner=frame and frame:FindFirstChild("Inner")
                local nameLabel=inner and inner:FindFirstChild("PetName")
                if nameLabel and nameLabel:IsA("TextLabel") then petName=nameLabel.Text end
                local shinyMark=cell:FindFirstChild("Shiny",true)
                if shinyMark then
                    if shinyMark:IsA("GuiObject") then isShiny=shinyMark.Visible else isShiny=true end
                end
                if petName and petName~="" and not isShiny then
                    groups[petName]=(groups[petName] or 0)+1
                end
            end
        end
        return groups,nil
    end

    function S:Diagnostic50()
        local groups,problem=countPetGroups()
        local ten={}
        for name,count in pairs(groups) do if count>=10 then ten[#ten+1]=name.." x"..count end end
        table.sort(ten)
        local remotes={}
        for _,obj in ipairs(RS:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local low=obj.Name:lower()
                if low:find("shiny",1,true) or low:find("potion",1,true) or low:find("brew",1,true) or low:find("craft",1,true) or low:find("mini",1,true) or low:find("doggy",1,true) then
                    remotes[#remotes+1]=obj:GetFullName()
                end
            end
        end
        local text="v"..VERSION.." | pets10="..(#ten>0 and table.concat(ten,", ") or "нет/не прочитаны").." | specialRemotes="..(#remotes>0 and table.concat(remotes,", ") or "нет отдельных")
        if problem then text=text.." | "..problem end
        S.experimentalStatus=text
        S.status=text:sub(1,180)
        pcall(function() setclipboard(text) end)
        return text
    end

    local previousTick=S.Tick
    if type(previousTick)=="function" then
        function S:Tick()
            local collect=self.autoCollect
            local hatch=self.autoHatch
            if collect then self.autoCollect=false end
            if hatch then self.autoHatch=false end
            local ok,problem=pcall(previousTick,self)
            self.autoCollect=collect
            self.autoHatch=hatch
            if not ok then self.status="Старый цикл: "..tostring(problem):sub(1,100) end

            if not self.alive then return end
            local now=os.clock()
            chestStep(now)
            if chestBusy then return end
            if hatch then hatchBurst(now) end
            if collect then coinStep(now) end
        end
    end

    local previousSetMode=S.SetMode
    if type(previousSetMode)=="function" then
        function S:SetMode(key,value)
            local result=previousSetMode(self,key,value)
            if key=="autoCollect" then
                clearCoinTarget()
                localAnchor=value and root() and root().Position or nil
                nextCoinScan=0
                self.collectStatus=value and "Ищу монеты" or "Выключено"
            elseif key=="autoHatch" and value then
                lastHatch50=-math.huge
            end
            return result
        end
    end

    local previousHardStop=S.HardStop
    if type(previousHardStop)=="function" then
        function S:HardStop()
            self.autoChestRoute=false
            self.autoShiny=false
            self.autoMinigames=false
            self.autoPotions=false
            chestBusy=false
            clearCoinTarget()
            localAnchor=nil
            self.chestStatus="Выключено"
            return previousHardStop(self)
        end
    end

    local gui=playerGui:FindFirstChild("BGSLegacyHub")
    local function corner(o,r)
        local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 8) c.Parent=o
    end
    local function stroke(o,color)
        local s=Instance.new("UIStroke") s.Color=color or Color3.fromRGB(70,72,94) s.Transparency=0.35 s.Parent=o
    end
    local function rowButton(parent,name,text,sub,callback,color)
        if not parent or parent:FindFirstChild(name) then return parent and parent:FindFirstChild(name) end
        local b=Instance.new("TextButton")
        b.Name=name b.Size=UDim2.new(1,-6,0,50) b.BackgroundColor3=Color3.fromRGB(31,34,46) b.BorderSizePixel=0 b.Text="" b.Parent=parent
        corner(b,8) stroke(b,color)
        local t=Instance.new("TextLabel")
        t.Name="Title" t.BackgroundTransparency=1 t.Position=UDim2.fromOffset(11,5) t.Size=UDim2.new(1,-22,0,19) t.Text=text t.TextColor3=Color3.fromRGB(244,244,250) t.Font=Enum.Font.GothamMedium t.TextSize=12 t.TextXAlignment=Enum.TextXAlignment.Left t.Parent=b
        local d=Instance.new("TextLabel")
        d.Name="Desc" d.BackgroundTransparency=1 d.Position=UDim2.fromOffset(11,27) d.Size=UDim2.new(1,-22,0,16) d.Text=sub or "" d.TextColor3=Color3.fromRGB(158,162,184) d.Font=Enum.Font.Gotham d.TextSize=9 d.TextXAlignment=Enum.TextXAlignment.Left d.TextTruncate=Enum.TextTruncate.AtEnd d.Parent=b
        if callback then b.Activated:Connect(callback) end
        return b
    end

    local function toggleRow(parent,name,title,desc,read,write)
        local b=rowButton(parent,name,title,desc,nil)
        if not b then return end
        local dot=Instance.new("Frame") dot.Name="ToggleDot" dot.Size=UDim2.fromOffset(15,15) dot.BorderSizePixel=0 dot.BackgroundColor3=Color3.fromRGB(244,244,250) dot.Parent=b corner(dot,15)
        local pill=Instance.new("Frame") pill.Name="TogglePill" pill.Size=UDim2.fromOffset(38,21) pill.Position=UDim2.new(1,-49,0.5,-10) pill.BorderSizePixel=0 pill.Parent=b corner(pill,20)
        dot.Parent=pill
        local function draw()
            local on=read()
            pill.BackgroundColor3=on and Color3.fromRGB(151,118,244) or Color3.fromRGB(67,68,91)
            dot.Position=UDim2.fromOffset(on and 20 or 3,3)
        end
        b.Activated:Connect(function() write(not read()) draw() end)
        draw()
        return draw
    end

    local modal=nil
    local function closeModal()
        if modal then modal:Destroy() modal=nil end
    end

    local function openWorldPicker(onPick)
        closeModal()
        if not gui then return end
        local main=gui:FindFirstChild("Main",true)
        if not main then return end
        modal=Instance.new("Frame") modal.Name="WorldPicker50" modal.Size=UDim2.fromScale(1,1) modal.BackgroundColor3=Color3.fromRGB(14,15,22) modal.BorderSizePixel=0 modal.ZIndex=100 modal.Parent=main
        local title=Instance.new("TextLabel") title.BackgroundTransparency=1 title.Position=UDim2.fromOffset(14,10) title.Size=UDim2.new(1,-58,0,25) title.Text="Локация фарма" title.TextColor3=Color3.fromRGB(245,245,250) title.Font=Enum.Font.GothamBold title.TextSize=14 title.TextXAlignment=Enum.TextXAlignment.Left title.ZIndex=101 title.Parent=modal
        local close=Instance.new("TextButton") close.Size=UDim2.fromOffset(30,28) close.Position=UDim2.new(1,-40,0,9) close.Text="×" close.TextSize=18 close.TextColor3=Color3.new(1,1,1) close.BackgroundColor3=Color3.fromRGB(38,40,52) close.ZIndex=101 close.Parent=modal corner(close,8) close.Activated:Connect(closeModal)
        local list=Instance.new("ScrollingFrame") list.Position=UDim2.fromOffset(12,44) list.Size=UDim2.new(1,-24,1,-56) list.BackgroundTransparency=1 list.BorderSizePixel=0 list.ScrollBarThickness=3 list.AutomaticCanvasSize=Enum.AutomaticSize.Y list.CanvasSize=UDim2.new() list.ZIndex=101 list.Parent=modal
        local layout=Instance.new("UIListLayout") layout.Padding=UDim.new(0,6) layout.Parent=list
        for i,w in ipairs(WORLD_DEFS) do
            local b=Instance.new("TextButton") b.Size=UDim2.new(1,-4,0,39) b.BackgroundColor3=Color3.fromRGB(31,34,46) b.Text=tostring(i)..". "..w.display b.TextColor3=Color3.fromRGB(240,241,248) b.TextSize=11 b.Font=Enum.Font.GothamMedium b.TextXAlignment=Enum.TextXAlignment.Left b.ZIndex=102 b.Parent=list corner(b,8)
            local pad=Instance.new("UIPadding") pad.PaddingLeft=UDim.new(0,10) pad.Parent=b
            if S.farmWorld==w.key then stroke(b,Color3.fromRGB(151,118,244)) else stroke(b,Color3.fromRGB(70,72,94)) end
            b.Activated:Connect(function() S.farmWorld=w.key clearCoinTarget() nextCoinScan=0 localAnchor=root() and root().Position or nil if onPick then onPick(w) end closeModal() end)
        end
    end

    if gui then
        local page2=gui:FindFirstChild("Page2",true)
        local page4=gui:FindFirstChild("Page4",true)
        local page5=gui:FindFirstChild("Page5",true)

        if page2 then
            rowButton(page2,"HatchCount50","Открывать: x1","Нажми для переключения 1 ↔ 3",function()
                S.hatchCount=(S.hatchCount==1) and 3 or 1
                local b=page2:FindFirstChild("HatchCount50")
                if b and b:FindFirstChild("Title") then b.Title.Text="Открывать: x"..S.hatchCount end
            end,Color3.fromRGB(151,118,244))
            toggleRow(page2,"HatchAnywhere50","Открывать из любого места","Можно одновременно бегать за монетами",function() return S.hatchAnywhere end,function(v) S.hatchAnywhere=v end)
        end

        if page4 then
            local worldBtn=rowButton(page4,"FarmWorld50","Локация фарма: "..S.farmWorld,"9 миров · точный выбор по названию",function()
                openWorldPicker(function(w)
                    local b=page4:FindFirstChild("FarmWorld50")
                    if b and b:FindFirstChild("Title") then b.Title.Text="Локация фарма: "..w.key end
                    S.collectStatus="Выбран мир: "..w.key
                end)
            end,Color3.fromRGB(105,220,151))
            if worldBtn then worldBtn.LayoutOrder=-20 end

            local scope=rowButton(page4,"FarmScope50",S.collectCurrentIslandOnly and "Фарм: текущий остров" or "Фарм: выбранный мир","Нажми: остров ↔ весь выбранный мир",function()
                S.collectCurrentIslandOnly=not S.collectCurrentIslandOnly
                S.collectIslandLock=nil clearCoinTarget() nextCoinScan=0 localAnchor=root() and root().Position or nil
                local b=page4:FindFirstChild("FarmScope50")
                if b and b:FindFirstChild("Title") then b.Title.Text=S.collectCurrentIslandOnly and "Фарм: текущий остров" or "Фарм: выбранный мир" end
            end,Color3.fromRGB(105,220,151))
            if scope then scope.LayoutOrder=-19 end
        end

        if page5 then
            toggleRow(page5,"AutoChest50","AFK сундуки · 23 острова","ТП → забрать → вернуться точно назад",function() return S.autoChestRoute end,function(v) S.autoChestRoute=v S.chestStatus=v and "Ищу доступный сундук" or "Выключено" end)
            rowButton(page5,"Diag50","Диагностика Shiny / мини-игр / зелий","Скопирует найденные группы x10 и специальные remotes",function() S:Diagnostic50() end,Color3.fromRGB(103,177,255))
        end

        for _,obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                local text=tostring(obj.Text or "")
                if text:find("0.4.8",1,true) then obj.Text=text:gsub("0%.4%.8",VERSION)
                elseif text:find("0.4.7",1,true) then obj.Text=text:gsub("0%.4%.7",VERSION)
                elseif text=="v0.4 · чистая сортировка / hitbox fix" then obj.Text="v"..VERSION.." · worlds / chests / concurrent hatch"
                elseif text=="BGS Legacy Hub 0.4.0" then obj.Text="BGS Legacy Hub "..VERSION end
            end
        end
    end

    S.version=VERSION
    S:Refresh(true)
    S.status="BGS Legacy Hub v"..VERSION
    return S
end
