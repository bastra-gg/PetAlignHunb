-- BGS Legacy Hub v0.4.5
-- Dynamic real-island teleport + optional collection lock to the current island.
-- No Portal/Spawn/FastTravel landing points are used.

return function(S)
    if type(S) ~= "table" then return S end

    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local W = workspace
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

    local function norm(v)
        return tostring(v or ""):lower():gsub("[%s%p_]", "")
    end

    local WORLD_ORDER = {
        ["the overworld"] = 1,
        ["overworld"] = 1,
        ["candy land"] = 2,
        ["toy land"] = 3,
        ["beach world"] = 4,
        ["atlantis"] = 5,
        ["rainbow land"] = 6,
        ["underworld"] = 7,
        ["mystic forest"] = 8,
    }

    local BAD_NAMES = {
        "portal","spawn","fasttravel","teleport","door","gate","button",
        "unlockhitbox","hitbox","preview","showcase","display","map","gui"
    }

    local function containsBadName(obj, stopAt)
        local p = obj
        while p and p ~= stopAt and p ~= W do
            local low = tostring(p.Name or ""):lower()
            for _,word in ipairs(BAD_NAMES) do
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

    local function realIslandGeometry(islandNode)
        local islandModel = islandNode:FindFirstChild("Island") or islandNode
        local valid = {}
        local minX,maxX,minY,maxY,minZ,maxZ
        local best,bestScore = nil,-math.huge

        local function consider(p)
            if not p:IsA("BasePart") then return end
            if p.Transparency >= 0.98 then return end
            if containsBadName(p,islandModel) then return end

            local area = math.max(0.01,p.Size.X * p.Size.Z)
            local flat = math.abs(p.CFrame.UpVector.Y)
            local score = area * (p.CanCollide and 2.2 or 0.45) * (flat > 0.72 and 2.2 or 0.55)

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

        if islandModel:IsA("BasePart") then
            consider(islandModel)
        else
            for _,p in ipairs(islandModel:GetDescendants()) do consider(p) end
        end

        if not best or not minX then return nil end
        if best.Size.X * best.Size.Z < 55 then return nil end

        return {
            model = islandModel,
            landingPart = best,
            bounds = {
                minX=minX,maxX=maxX,minY=minY,maxY=maxY,minZ=minZ,maxZ=maxZ,
                center=Vector3.new((minX+maxX)/2,(minY+maxY)/2,(minZ+maxZ)/2),
                size=Vector3.new(maxX-minX,maxY-minY,maxZ-minZ)
            }
        }
    end

    local islandCache = {}
    local nextIslandScan = 0

    local function scanRealIslands()
        local worlds = W:FindFirstChild("Worlds")
        local list = {}
        if not worlds then return list end

        for _,world in ipairs(worlds:GetChildren()) do
            local islands = world:FindFirstChild("Islands")
            if islands then
                for _,node in ipairs(islands:GetChildren()) do
                    local geo = realIslandGeometry(node)
                    if geo then
                        local worldName = world.Name
                        local entry = {
                            object=node,
                            part=geo.landingPart,
                            landingPart=geo.landingPart,
                            islandModel=geo.model,
                            bounds=geo.bounds,
                            name=node.Name,
                            world=worldName:gsub("^The ",""),
                            rawWorld=worldName,
                            canonical=true,
                            kind=(worldName:lower():find("crystal",1,true) or node.Name:lower():find("crystal",1,true)) and "gem" or "normal",
                            y=geo.bounds.center.Y,
                        }
                        list[#list+1] = entry
                    end
                end
            end
        end

        table.sort(list,function(a,b)
            local wa = WORLD_ORDER[a.rawWorld:lower()] or 50
            local wb = WORLD_ORDER[b.rawWorld:lower()] or 50
            if wa ~= wb then return wa < wb end
            if a.rawWorld ~= b.rawWorld then return a.rawWorld < b.rawWorld end
            if math.abs(a.y-b.y) > 3 then return a.y < b.y end
            return a.name < b.name
        end)

        for i,e in ipairs(list) do e.order=i end
        islandCache = list
        nextIslandScan = os.clock() + 15
        return list
    end

    local function pointInsideIsland(pos,e,pad)
        if not e or not e.bounds then return false end
        pad = pad or 22
        local b = e.bounds
        return pos.X >= b.minX-pad and pos.X <= b.maxX+pad
           and pos.Z >= b.minZ-pad and pos.Z <= b.maxZ+pad
           and pos.Y >= b.minY-45 and pos.Y <= b.maxY+115
    end

    local function islandDistance(pos,e)
        local c = e.bounds.center
        local flat = (Vector2.new(pos.X,pos.Z)-Vector2.new(c.X,c.Z)).Magnitude
        local dy = math.abs(pos.Y-c.Y)
        return flat + dy*1.35
    end

    local function detectCurrentIsland()
        local r = root()
        if not r then return nil end
        local pos = r.Position
        local inside = {}
        for _,e in ipairs(islandCache) do
            if e.object and e.object.Parent and pointInsideIsland(pos,e,28) then
                inside[#inside+1] = e
            end
        end
        if #inside > 0 then
            table.sort(inside,function(a,b) return islandDistance(pos,a) < islandDistance(pos,b) end)
            return inside[1]
        end

        local best,bestD = nil,math.huge
        for _,e in ipairs(islandCache) do
            local d = islandDistance(pos,e)
            local maxSpan = math.max(e.bounds.size.X,e.bounds.size.Z)
            if d < bestD and d <= math.max(180,maxSpan*0.8) then
                best,bestD = e,d
            end
        end
        return best
    end

    local function pickupInIsland(item,e)
        if not item or not item.part or not item.part.Parent or not e or not e.bounds then return false end
        local p = item.part.Position
        local b = e.bounds
        local pad = math.max(28,math.min(85,math.max(b.size.X,b.size.Z)*0.12))
        return p.X >= b.minX-pad and p.X <= b.maxX+pad
           and p.Z >= b.minZ-pad and p.Z <= b.maxZ+pad
           and p.Y >= b.minY-35 and p.Y <= b.maxY+90
    end

    S.collectCurrentIslandOnly = true
    S.collectIslandLock = nil
    S._allPickups = S._allPickups or {}
    S.currentIslandName = "не определён"

    local function applyPickupFilter()
        if not S.collectCurrentIslandOnly then
            S.pickups = S._allPickups
            S.currentIslandName = "вся карта"
            return
        end

        local island = S.collectIslandLock
        if not island or not island.object or not island.object.Parent then
            island = detectCurrentIsland()
            S.collectIslandLock = island
        end

        if not island then
            S.pickups = {}
            S.currentIslandName = "не определён"
            if S.autoCollect then S.collectStatus = "Жду: текущий остров не определён" end
            return
        end

        local filtered = {}
        for _,item in ipairs(S._allPickups or {}) do
            if pickupInIsland(item,island) then filtered[#filtered+1] = item end
        end
        S.pickups = filtered
        S.currentIslandName = island.name
        if S.autoCollect and #filtered == 0 then
            S.collectStatus = "Жду монеты · "..island.name
        end
    end

    local oldRefresh = S.Refresh
    if type(oldRefresh) == "function" then
        function S:Refresh(forceIslands)
            local selectedName = self.selectedIsland and self.selectedIsland.name
            local selectedWorld = self.selectedIsland and self.selectedIsland.rawWorld
            local result = oldRefresh(self,false)

            self._allPickups = self.pickups or {}

            if forceIslands or os.clock() >= nextIslandScan or #islandCache == 0 then
                scanRealIslands()
            end
            self.islands = islandCache

            self.selectedIsland = nil
            if selectedName then
                for _,e in ipairs(islandCache) do
                    if e.name == selectedName and (not selectedWorld or e.rawWorld == selectedWorld) then
                        self.selectedIsland = e
                        break
                    end
                end
            end

            applyPickupFilter()
            return result
        end
    end

    function S:SelectIsland(e)
        if not e or not e.canonical or not e.landingPart or not e.landingPart.Parent then
            self.status = "ТП: остров недоступен"
            return false
        end
        self.selectedIsland = e
        self.status = "Выбрано: "..e.name
        return true
    end

    function S:GoIsland(e)
        e = e or self.selectedIsland
        if not e or not e.canonical or not e.landingPart or not e.landingPart.Parent then
            self.status = "ТП: остров не загружен"
            return false
        end

        local r,h = root(),hum()
        if not r or not h or h.Health <= 0 then
            self.status = "ТП: жду персонажа"
            return false
        end

        stopMove()
        h.Sit = false
        local part = e.landingPart
        local up = math.max(4,h.HipHeight+r.Size.Y/2+1.5)
        local localPoint = Vector3.new(0,part.Size.Y/2+up,0)
        local p = part.CFrame:PointToWorldSpace(localPoint)

        r.CFrame = CFrame.new(p) * (r.CFrame-r.Position)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero

        self.target = nil
        self.travelUntil = os.clock()+1.1
        if self.collectCurrentIslandOnly then
            self.collectIslandLock = e
            applyPickupFilter()
        end
        self.status = "ТП на остров: "..e.name
        return true
    end

    local oldTick = S.Tick
    local nextIslandDetect = 0
    if type(oldTick) == "function" then
        function S:Tick()
            local now = os.clock()
            if self.collectCurrentIslandOnly and now >= nextIslandDetect then
                nextIslandDetect = now + 0.8
                local current = detectCurrentIsland()
                if current and (not self.collectIslandLock or current.object ~= self.collectIslandLock.object) then
                    self.collectIslandLock = current
                    self.target = nil
                    stopMove()
                    applyPickupFilter()
                end
            end
            return oldTick(self)
        end
    end

    -- Inject one compact switch into the existing Collection page.
    local function addCollectionToggle()
        if not playerGui then return end
        local gui = playerGui:FindFirstChild("BGSLegacyHub")
        if not gui then return end
        local page = gui:FindFirstChild("Page4",true)
        if not page or page:FindFirstChild("CurrentIslandOnly") then return end

        local row = Instance.new("TextButton")
        row.Name = "CurrentIslandOnly"
        row.Size = UDim2.new(1,-6,0,51)
        row.BackgroundColor3 = Color3.fromRGB(31,34,46)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.Parent = page
        Instance.new("UICorner",row).CornerRadius = UDim.new(0,8)
        local rs = Instance.new("UIStroke",row)
        rs.Color = Color3.fromRGB(67,68,91)
        rs.Transparency = 0.45

        local title = Instance.new("TextLabel",row)
        title.BackgroundTransparency = 1
        title.Position = UDim2.fromOffset(11,6)
        title.Size = UDim2.new(1,-78,0,18)
        title.Text = "Только текущий остров"
        title.Font = Enum.Font.GothamMedium
        title.TextSize = 12
        title.TextColor3 = Color3.fromRGB(244,244,250)
        title.TextXAlignment = Enum.TextXAlignment.Left

        local desc = Instance.new("TextLabel",row)
        desc.BackgroundTransparency = 1
        desc.Position = UDim2.fromOffset(11,27)
        desc.Size = UDim2.new(1,-82,0,17)
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 9
        desc.TextColor3 = Color3.fromRGB(157,161,183)
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextTruncate = Enum.TextTruncate.AtEnd

        local pill = Instance.new("Frame",row)
        pill.Size = UDim2.fromOffset(38,21)
        pill.Position = UDim2.new(1,-49,0.5,-10)
        pill.BorderSizePixel = 0
        Instance.new("UICorner",pill).CornerRadius = UDim.new(1,0)

        local dot = Instance.new("Frame",pill)
        dot.Size = UDim2.fromOffset(15,15)
        dot.BorderSizePixel = 0
        dot.BackgroundColor3 = Color3.fromRGB(244,244,250)
        Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)

        local function draw()
            local on = S.collectCurrentIslandOnly
            pill.BackgroundColor3 = on and Color3.fromRGB(151,118,244) or Color3.fromRGB(67,68,91)
            dot.Position = UDim2.fromOffset(on and 20 or 3,3)
            desc.Text = on and ("Привязан: "..tostring(S.currentIslandName)) or "Собирает по всей карте"
        end

        row.Activated:Connect(function()
            S.collectCurrentIslandOnly = not S.collectCurrentIslandOnly
            S.target = nil
            stopMove()
            if S.collectCurrentIslandOnly then
                S.collectIslandLock = detectCurrentIsland()
            else
                S.collectIslandLock = nil
            end
            applyPickupFilter()
            S.status = S.collectCurrentIslandOnly and ("Сбор привязан: "..tostring(S.currentIslandName)) or "Сбор: вся карта"
            draw()
        end)

        task.spawn(function()
            while row.Parent and S.alive do
                draw()
                task.wait(0.5)
            end
        end)
        draw()
    end

    scanRealIslands()
    S.islands = islandCache
    S.collectIslandLock = detectCurrentIsland()
    S._allPickups = S.pickups or {}
    applyPickupFilter()
    task.defer(addCollectionToggle)

    S.version = "0.4.5-current-island"
    S.status = "ТП: реальные острова · Сбор: текущий остров"
    return S
end
