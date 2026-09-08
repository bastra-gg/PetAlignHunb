-- BGS Legacy Hub v0.4.6
-- Preserves the working v0.4 UI/lists, improves island landing points,
-- and adds a non-destructive "current island only" pickup lock.

return function(S)
    if type(S) ~= "table" then return S end

    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local W = workspace
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

    local BAD = {
        "portal","spawn","fasttravel","teleport","door","gate","button",
        "unlockhitbox","hitbox","preview","showcase","display","map","gui"
    }

    local function hasBadName(obj, stopAt)
        local p = obj
        while p and p ~= stopAt and p ~= W do
            local low = tostring(p.Name or ""):lower()
            for _,word in ipairs(BAD) do
                if low:find(word,1,true) then return true end
            end
            p = p.Parent
        end
        return false
    end

    local function root()
        local c = player and player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function hum()
        local c = player and player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    local function stopMove()
        local h,r = hum(),root()
        if h and r then
            pcall(function()
                h:MoveTo(r.Position)
                h:Move(Vector3.zero,false)
            end)
        end
    end

    -- Only direct children of Worlds/<world>/Islands are considered islands.
    -- Portal/Spawn/UnlockHitbox descendants are never used as landing surfaces.
    local function geometryForIsland(node)
        if not node then return nil end
        local body = node:FindFirstChild("Island") or node
        local valid = {}
        local minX,maxX,minY,maxY,minZ,maxZ
        local best,bestScore = nil,-math.huge

        local function consider(p)
            if not p:IsA("BasePart") then return end
            if p.Transparency >= 0.98 then return end
            if hasBadName(p,body) then return end

            local area = math.max(0.01,p.Size.X*p.Size.Z)
            local flat = math.abs(p.CFrame.UpVector.Y)
            local score = area * (p.CanCollide and 2.3 or 0.45) * (flat >= 0.70 and 2.6 or 0.35)
            if p.Size.X < 4 or p.Size.Z < 4 then score = score * 0.25 end

            valid[#valid+1] = p
            local px,py,pz = p.Position.X,p.Position.Y,p.Position.Z
            local hx,hy,hz = p.Size.X/2,p.Size.Y/2,p.Size.Z/2
            minX = minX and math.min(minX,px-hx) or px-hx
            maxX = maxX and math.max(maxX,px+hx) or px+hx
            minY = minY and math.min(minY,py-hy) or py-hy
            maxY = maxY and math.max(maxY,py+hy) or py+hy
            minZ = minZ and math.min(minZ,pz-hz) or pz-hz
            maxZ = maxZ and math.max(maxZ,pz+hz) or pz+hz

            if score > bestScore then
                best,bestScore = p,score
            end
        end

        if body:IsA("BasePart") then
            consider(body)
        else
            for _,p in ipairs(body:GetDescendants()) do consider(p) end
        end

        if not best or not minX then return nil end
        if best.Size.X*best.Size.Z < 45 then return nil end

        return {
            body=body,
            landingPart=best,
            bounds={
                minX=minX,maxX=maxX,minY=minY,maxY=maxY,minZ=minZ,maxZ=maxZ,
                center=Vector3.new((minX+maxX)/2,(minY+maxY)/2,(minZ+maxZ)/2),
                size=Vector3.new(maxX-minX,maxY-minY,maxZ-minZ)
            }
        }
    end

    local islandCache = {}
    local nextIslandScan = 0

    local function scanWorldIslands()
        local worlds = W:FindFirstChild("Worlds")
        if not worlds then return {} end

        local list = {}
        for _,world in ipairs(worlds:GetChildren()) do
            local islands = world:FindFirstChild("Islands")
            if islands then
                local worldEntries = {}
                for _,node in ipairs(islands:GetChildren()) do
                    local geo = geometryForIsland(node)
                    if geo then
                        worldEntries[#worldEntries+1] = {
                            object=node,
                            part=geo.landingPart,
                            landingPart=geo.landingPart,
                            islandModel=geo.body,
                            bounds=geo.bounds,
                            name=node.Name,
                            world=world.Name:gsub("^The ",""),
                            rawWorld=world.Name,
                            canonical=true,
                            kind=(node.Name:lower():find("crystal",1,true) or world.Name:lower():find("crystal",1,true)) and "gem" or "normal",
                            y=geo.bounds.center.Y,
                        }
                    end
                end

                table.sort(worldEntries,function(a,b)
                    if math.abs(a.y-b.y) > 3 then return a.y < b.y end
                    return a.name < b.name
                end)
                for _,e in ipairs(worldEntries) do list[#list+1]=e end
            end
        end

        for i,e in ipairs(list) do e.order=i end
        return list
    end

    local function refreshIslandCache(force)
        if not force and os.clock() < nextIslandScan and #islandCache > 0 then return islandCache end
        nextIslandScan = os.clock()+15
        local scanned = scanWorldIslands()
        -- Critical: NEVER erase the working list just because the structural scan found nothing.
        if #scanned > 0 then islandCache = scanned end
        return islandCache
    end

    local function insideIsland(pos,e,pad)
        if not e or not e.bounds then return false end
        local b=e.bounds
        pad=pad or 22
        return pos.X>=b.minX-pad and pos.X<=b.maxX+pad
           and pos.Z>=b.minZ-pad and pos.Z<=b.maxZ+pad
           and pos.Y>=b.minY-40 and pos.Y<=b.maxY+110
    end

    local function flatDistance(pos,e)
        if not e or not e.bounds then return math.huge end
        local c=e.bounds.center
        local flat=(Vector2.new(pos.X,pos.Z)-Vector2.new(c.X,c.Z)).Magnitude
        local dy=math.abs(pos.Y-c.Y)
        return flat+dy*1.2
    end

    local function detectCurrentIsland()
        local r=root()
        if not r then return nil end
        local pos=r.Position
        local best,bestD=nil,math.huge

        for _,e in ipairs(islandCache) do
            if e.object and e.object.Parent and insideIsland(pos,e,30) then
                local d=flatDistance(pos,e)
                if d<bestD then best,bestD=e,d end
            end
        end
        if best then return best end

        -- Small fallback only; don't bind to some remote island across the map.
        for _,e in ipairs(islandCache) do
            if e.object and e.object.Parent then
                local d=flatDistance(pos,e)
                local span=math.max(e.bounds.size.X,e.bounds.size.Z)
                if d<bestD and d<=math.max(130,span*0.55) then best,bestD=e,d end
            end
        end
        return best
    end

    local function pickupInIsland(item,e)
        if not item or not item.part or not item.part.Parent or not e or not e.bounds then return false end
        local p=item.part.Position
        local b=e.bounds
        local span=math.max(b.size.X,b.size.Z)
        local pad=math.max(24,math.min(70,span*0.10))
        return p.X>=b.minX-pad and p.X<=b.maxX+pad
           and p.Z>=b.minZ-pad and p.Z<=b.maxZ+pad
           and p.Y>=b.minY-30 and p.Y<=b.maxY+85
    end

    S.collectCurrentIslandOnly = true
    S.collectIslandLock = nil
    S.currentIslandName = "не определён"
    S._allPickups = S._allPickups or {}

    local function applyPickupFilter()
        if not S.collectCurrentIslandOnly then
            S.pickups = S._allPickups
            S.currentIslandName = "вся карта"
            return
        end

        local island=S.collectIslandLock
        if not island or not island.object or not island.object.Parent then
            island=detectCurrentIsland()
            S.collectIslandLock=island
        end

        if not island then
            -- Don't send the player around the whole map when the island isn't known.
            S.pickups={}
            S.currentIslandName="не определён"
            if S.autoCollect then S.collectStatus="Жду · остров не определён" end
            return
        end

        local filtered={}
        for _,item in ipairs(S._allPickups or {}) do
            if pickupInIsland(item,island) then filtered[#filtered+1]=item end
        end
        S.pickups=filtered
        S.currentIslandName=island.name
        if S.autoCollect and #filtered==0 then
            S.collectStatus="Жду новые монеты · "..island.name
        end
    end

    local oldRefresh=S.Refresh
    if type(oldRefresh)=="function" then
        function S:Refresh(forceIslands)
            local selectedName=self.selectedIsland and self.selectedIsland.name
            local selectedWorld=self.selectedIsland and (self.selectedIsland.rawWorld or self.selectedIsland.world)

            -- Always let the working core refresh eggs + ALL pickups first.
            local result=oldRefresh(self,forceIslands)
            self._allPickups=self.pickups or {}

            local structural=refreshIslandCache(forceIslands==true)
            if #structural>0 then
                -- Only replace the island list when we have a real, non-empty structural result.
                self.islands=structural
                if selectedName then
                    self.selectedIsland=nil
                    for _,e in ipairs(structural) do
                        if e.name==selectedName and (not selectedWorld or e.rawWorld==selectedWorld or e.world==selectedWorld) then
                            self.selectedIsland=e
                            break
                        end
                    end
                end
            end

            applyPickupFilter()
            return result
        end
    end

    function S:SelectIsland(e)
        if not e then self.status="ТП: остров не выбран" return false end
        self.selectedIsland=e
        self.status="Выбрано: "..tostring(e.name)
        return true
    end

    function S:GoIsland(e)
        e=e or self.selectedIsland
        if not e then self.status="ТП: остров не выбран" return false end

        -- Upgrade old/core entries on demand instead of rejecting them.
        if (not e.landingPart or not e.landingPart.Parent) and e.object and e.object.Parent then
            local geo=geometryForIsland(e.object)
            if geo then
                e.landingPart=geo.landingPart
                e.part=geo.landingPart
                e.bounds=geo.bounds
                e.islandModel=geo.body
            end
        end

        local part=e.landingPart or e.part
        local r,h=root(),hum()
        if not part or not part.Parent then self.status="ТП: поверхность острова не найдена" return false end
        if hasBadName(part,e.islandModel or e.object) then self.status="ТП: плохая точка острова заблокирована" return false end
        if not r or not h or h.Health<=0 then self.status="ТП: жду персонажа" return false end

        stopMove()
        h.Sit=false
        local up=math.max(4,h.HipHeight+r.Size.Y/2+1.5)
        local p=part.CFrame:PointToWorldSpace(Vector3.new(0,part.Size.Y/2+up,0))
        r.CFrame=CFrame.new(p)*(r.CFrame-r.Position)
        r.AssemblyLinearVelocity=Vector3.zero
        r.AssemblyAngularVelocity=Vector3.zero

        self.target=nil
        self.travelUntil=os.clock()+1.1
        if self.collectCurrentIslandOnly then
            self.collectIslandLock=e
            applyPickupFilter()
        end
        self.status="ТП на остров: "..tostring(e.name)
        return true
    end

    local oldTick=S.Tick
    local nextDetect=0
    if type(oldTick)=="function" then
        function S:Tick()
            local now=os.clock()
            if self.collectCurrentIslandOnly and now>=nextDetect then
                nextDetect=now+0.8
                local current=detectCurrentIsland()
                if current and (not self.collectIslandLock or current.object~=self.collectIslandLock.object) then
                    self.collectIslandLock=current
                    self.target=nil
                    stopMove()
                    applyPickupFilter()
                elseif self.collectIslandLock and self.autoCollect and #self.pickups==0 then
                    self.collectStatus="Жду новые монеты · "..tostring(self.collectIslandLock.name)
                end
            end
            return oldTick(self)
        end
    end

    local function addToggle()
        if not playerGui then return end
        local gui=playerGui:FindFirstChild("BGSLegacyHub")
        if not gui then return end
        local page=gui:FindFirstChild("Page4",true)
        if not page or page:FindFirstChild("CurrentIslandOnly") then return end

        local row=Instance.new("TextButton")
        row.Name="CurrentIslandOnly"
        row.Size=UDim2.new(1,-6,0,51)
        row.BackgroundColor3=Color3.fromRGB(31,34,46)
        row.BorderSizePixel=0
        row.Text=""
        row.Parent=page
        local rc=Instance.new("UICorner",row) rc.CornerRadius=UDim.new(0,8)
        local rs=Instance.new("UIStroke",row) rs.Color=Color3.fromRGB(67,68,91) rs.Transparency=0.45

        local title=Instance.new("TextLabel",row)
        title.BackgroundTransparency=1
        title.Position=UDim2.fromOffset(11,6)
        title.Size=UDim2.new(1,-78,0,18)
        title.Text="Только текущий остров"
        title.Font=Enum.Font.GothamMedium
        title.TextSize=12
        title.TextColor3=Color3.fromRGB(244,244,250)
        title.TextXAlignment=Enum.TextXAlignment.Left

        local desc=Instance.new("TextLabel",row)
        desc.BackgroundTransparency=1
        desc.Position=UDim2.fromOffset(11,27)
        desc.Size=UDim2.new(1,-82,0,17)
        desc.Font=Enum.Font.Gotham
        desc.TextSize=9
        desc.TextColor3=Color3.fromRGB(157,161,183)
        desc.TextXAlignment=Enum.TextXAlignment.Left
        desc.TextTruncate=Enum.TextTruncate.AtEnd

        local pill=Instance.new("Frame",row)
        pill.Size=UDim2.fromOffset(38,21)
        pill.Position=UDim2.new(1,-49,0.5,-10)
        pill.BorderSizePixel=0
        local pc=Instance.new("UICorner",pill) pc.CornerRadius=UDim.new(1,0)

        local dot=Instance.new("Frame",pill)
        dot.Size=UDim2.fromOffset(15,15)
        dot.BorderSizePixel=0
        dot.BackgroundColor3=Color3.fromRGB(244,244,250)
        local dc=Instance.new("UICorner",dot) dc.CornerRadius=UDim.new(1,0)

        local function draw()
            local on=S.collectCurrentIslandOnly
            pill.BackgroundColor3=on and Color3.fromRGB(151,118,244) or Color3.fromRGB(67,68,91)
            dot.Position=UDim2.fromOffset(on and 20 or 3,3)
            desc.Text=on and ("Привязан: "..tostring(S.currentIslandName)) or "Собирает по всей карте"
        end

        row.Activated:Connect(function()
            S.collectCurrentIslandOnly=not S.collectCurrentIslandOnly
            S.target=nil
            stopMove()
            if S.collectCurrentIslandOnly then
                S.collectIslandLock=detectCurrentIsland()
            else
                S.collectIslandLock=nil
            end
            applyPickupFilter()
            draw()
            S.status=S.collectCurrentIslandOnly and "Сбор: только текущий остров" or "Сбор: вся карта"
        end)

        task.spawn(function()
            while row.Parent and S.alive do
                draw()
                task.wait(0.5)
            end
        end)
        draw()
    end

    -- Keep the core's initial islands if structural discovery fails.
    local initial=S.islands
    local structural=refreshIslandCache(true)
    if #structural>0 then S.islands=structural elseif initial then S.islands=initial end

    -- Capture a fresh full pickup list through the core, then filter it safely.
    pcall(function() S:Refresh(false) end)
    task.defer(addToggle)
    task.delay(0.7,addToggle)
    task.delay(2.0,addToggle)

    S.version="0.4.6-preserve-lists"
    S.status="0.4.6 · острова/фарм сохранены"
    return S
end
