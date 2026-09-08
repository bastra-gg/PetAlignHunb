-- BGS Legacy Hub v0.4.8
-- Coin farm fix: target the real touch/hitbox part (including invisible parts),
-- cross it with normal Humanoid movement, and keep collection local when current-island lock is enabled.

return function(S)
    if type(S) ~= "table" then return S end

    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

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

    local currencyNames = {
        coins="Coins",coin="Coins",gems="Gems",gem="Gems",candy="Candy",
        blocks="Blocks",shells="Shells",pearls="Pearls",stars="Stars",
        magma="Magma",crystals="Crystals",crystal="Crystals"
    }

    local function readMeta(object, keys)
        local p = object
        local depth = 0
        while p and p ~= workspace and depth < 6 do
            for _,key in ipairs(keys) do
                local ok,value = pcall(function() return p:GetAttribute(key) end)
                if ok and value ~= nil and (type(value)=="string" or type(value)=="number") then
                    return tostring(value)
                end
                local child = p:FindFirstChild(key)
                if child and child:IsA("ValueBase") then return tostring(child.Value) end
            end
            p = p.Parent
            depth += 1
        end
        return nil
    end

    local function currencyOf(object)
        local meta = readMeta(object,{"Currency","CurrencyType","PickupType","Type"})
        if meta then return meta end
        local p = object
        local depth = 0
        while p and p ~= workspace and depth < 7 do
            local low = tostring(p.Name):lower()
            for key,value in pairs(currencyNames) do
                if low:find(key,1,true) then return value end
            end
            p = p.Parent
            depth += 1
        end
        return "Другое"
    end

    local function hasTouchSignal(part)
        if not part or not part:IsA("BasePart") then return false end
        if part:FindFirstChild("TouchInterest") then return true end
        for _,child in ipairs(part:GetChildren()) do
            if child.ClassName == "TouchTransmitter" then return true end
        end
        return false
    end

    local function pickupObject(part, container)
        local p = part
        local best = part
        local depth = 0
        while p and p.Parent and p.Parent ~= container and depth < 4 do
            if p.Parent:IsA("Model") then best = p.Parent end
            p = p.Parent
            depth += 1
        end
        return best
    end

    local function scanTouchPickups()
        local container = workspace:FindFirstChild("Pickups",true)
        if not container then return {} end

        local bestByObject = {}
        for _,part in ipairs(container:GetDescendants()) do
            if part:IsA("BasePart") then
                local touch = hasTouchSignal(part)
                local low = part.Name:lower()
                local hitName = low:find("hitbox",1,true) or low:find("touch",1,true) or low:find("collect",1,true) or low:find("pickup",1,true)

                -- Invisible parts are intentionally allowed: in BGS-style pickups they are often the real touch hitbox.
                if touch or part.CanTouch or hitName then
                    local object = pickupObject(part,container)
                    local score = 0
                    if touch then score += 10000 end
                    if hitName then score += 5000 end
                    if part.CanTouch then score += 1200 end
                    if part.Transparency >= 0.98 and (touch or hitName) then score += 900 end
                    if part.Name == "Part" then score += 150 end
                    score += math.min(500,part.Size.Magnitude*5)

                    local old = bestByObject[object]
                    if not old or score > old.score then
                        bestByObject[object] = {object=object,part=part,score=score}
                    end
                end
            end
        end

        local list = {}
        for object,v in pairs(bestByObject) do
            list[#list+1] = {
                object=object,
                part=v.part,
                currency=currencyOf(object),
                touch=hasTouchSignal(v.part)
            }
        end
        return list
    end

    local function valid(item)
        if not item or not item.part or not item.part.Parent then return false end
        if not item.object or not item.object.Parent then return false end
        if not item.part:IsDescendantOf(workspace) then return false end
        if item.object:GetAttribute("Collected") == true then return false end
        return true
    end

    local function inBounds(pos,b,pad)
        if not b then return false end
        pad = pad or 40
        return pos.X >= b.minX-pad and pos.X <= b.maxX+pad
           and pos.Z >= b.minZ-pad and pos.Z <= b.maxZ+pad
           and pos.Y >= b.minY-45 and pos.Y <= b.maxY+110
    end

    local function findCurrentIsland()
        local r = root()
        if not r then return nil end
        local pos = r.Position
        local best,bestD = nil,math.huge
        for _,e in ipairs(S.islands or {}) do
            if e.bounds and e.object and e.object.Parent and inBounds(pos,e.bounds,38) then
                local c = e.bounds.center
                local d = (Vector2.new(pos.X,pos.Z)-Vector2.new(c.X,c.Z)).Magnitude + math.abs(pos.Y-c.Y)
                if d < bestD then best,bestD = e,d end
            end
        end
        return best
    end

    local coinAnchor = nil
    local coinList = {}
    local nextScan = 0
    local target = nil
    local targetStarted = 0
    local lastProgress = 0
    local lastDistance = math.huge
    local nextMove = 0
    local sweepSide = 1
    local skipped = setmetatable({},{__mode="k"})

    local function clearTarget(cooldown)
        if target and cooldown and target.object then skipped[target.object] = os.clock()+cooldown end
        target = nil
        targetStarted = 0
        lastProgress = 0
        lastDistance = math.huge
        sweepSide = 1
    end

    local function localFilter(list)
        if not S.collectCurrentIslandOnly then return list end

        local island = S.collectIslandLock
        if not island or not island.object or not island.object.Parent or not island.bounds then
            island = findCurrentIsland()
            if island then S.collectIslandLock = island end
        end

        local filtered = {}
        if island and island.bounds then
            for _,item in ipairs(list) do
                if valid(item) and inBounds(item.part.Position,island.bounds,55) then
                    filtered[#filtered+1] = item
                end
            end
            S.currentIslandName = tostring(island.name or "остров")
            return filtered
        end

        -- Fallback for surface/event areas that have no normal island model:
        -- lock to the player's local area instead of roaming across the map.
        local r = root()
        if not coinAnchor and r then coinAnchor = r.Position end
        if not coinAnchor then return filtered end
        for _,item in ipairs(list) do
            if valid(item) then
                local delta = item.part.Position-coinAnchor
                local flat = Vector2.new(delta.X,delta.Z).Magnitude
                if flat <= 300 and math.abs(delta.Y) <= 115 then filtered[#filtered+1]=item end
            end
        end
        S.currentIslandName = "текущая зона"
        return filtered
    end

    local function rescan(now)
        if now < nextScan then return end
        nextScan = now + 0.75
        local all = scanTouchPickups()
        S._allPickups = all
        coinList = localFilter(all)
        S.pickups = coinList
    end

    local function nearest(now)
        local r = root()
        if not r then return nil end
        local best,bestD = nil,math.huge
        for _,item in ipairs(coinList) do
            if valid(item) and now >= (skipped[item.object] or 0) and (S.currency=="Все" or item.currency==S.currency) then
                local d = (item.part.Position-r.Position).Magnitude
                if d < bestD then best,bestD=item,d end
            end
        end
        return best,bestD
    end

    local function directionTo(item)
        local r = root()
        if not r then return Vector3.new(1,0,0) end
        local delta = item.part.Position-r.Position
        local flat = Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude < 0.2 then
            local look = r.CFrame.LookVector
            flat = Vector3.new(look.X,0,look.Z)
        end
        if flat.Magnitude < 0.2 then flat = Vector3.new(1,0,0) end
        return flat.Unit
    end

    local function moveThrough(item,near)
        local h = hum()
        if not h or h.Health <= 0 then return end
        local dir = directionTo(item)
        local pos = item.part.Position

        if near then
            -- Alternate sides so the avatar physically crosses the touch box instead of stopping on its edge.
            local dest = pos + dir*(6*sweepSide)
            sweepSide = -sweepSide
            h:MoveTo(dest)
        else
            h:MoveTo(pos + dir*4)
        end
    end

    local function collectStep(now)
        if not S.autoCollect or S.selling or now < (S.travelUntil or 0) then return end
        local r,h = root(),hum()
        if not r or not h or h.Health <= 0 then return end

        rescan(now)

        if target and (not valid(target) or (S.currency~="Все" and target.currency~=S.currency)) then
            clearTarget()
        end

        if not target then
            local d
            target,d = nearest(now)
            if not target then
                if S.collectCurrentIslandOnly then
                    S.collectStatus = "Жду новые монеты · "..tostring(S.currentIslandName or "текущий остров")
                else
                    S.collectStatus = "Нет доступных монет"
                end
                stopMove()
                return
            end
            targetStarted = now
            lastProgress = now
            lastDistance = d or math.huge
            sweepSide = 1
        end

        local d = (target.part.Position-r.Position).Magnitude
        S.collectStatus = tostring(target.currency or "Монеты").." · "..math.floor(d).." studs"

        if d < lastDistance-0.35 then
            lastDistance = d
            lastProgress = now
        end

        -- If the target disappears after a touch, immediately acquire another pickup.
        if not valid(target) then clearTarget() return end

        if now-targetStarted > 3.6 then
            clearTarget(5)
            S.collectStatus = "Пропустил залипшую монету"
            return
        end

        if now < nextMove then return end
        nextMove = now + (d <= 10 and 0.28 or 0.18)

        if d <= 10 then
            moveThrough(target,true)
        else
            moveThrough(target,false)
            if now-lastProgress > 1.15 then
                -- One jump helps with tiny lips/edges but keeps movement local and normal.
                h.Jump = true
                moveThrough(target,false)
                lastProgress = now
            end
        end
    end

    -- Keep the original bubble/sell/hatch tick, but suppress its old coin collector.
    local previousTick = S.Tick
    if type(previousTick)=="function" then
        function S:Tick()
            local collect = self.autoCollect
            if collect then self.autoCollect = false end
            previousTick(self)
            if collect then self.autoCollect = true end
            if collect and self.alive then
                local ok,problem = pcall(collectStep,os.clock())
                if not ok then
                    self.collectStatus = "Ошибка фарма: "..tostring(problem):sub(1,90)
                    self.status = self.collectStatus
                end
            end
        end
    end

    local previousSetMode = S.SetMode
    if type(previousSetMode)=="function" then
        function S:SetMode(key,value)
            local result = previousSetMode(self,key,value)
            if key=="autoCollect" then
                clearTarget()
                local r=root()
                coinAnchor = value and r and r.Position or nil
                if value then
                    local island=findCurrentIsland()
                    if island then self.collectIslandLock=island end
                    nextScan=0
                    self.collectStatus="Ищу реальные hitbox монет"
                end
            end
            return result
        end
    end

    local previousGoIsland = S.GoIsland
    if type(previousGoIsland)=="function" then
        function S:GoIsland(entry)
            local ok = previousGoIsland(self,entry)
            if ok then
                clearTarget()
                local r=root()
                coinAnchor=r and r.Position or nil
                nextScan=0
            end
            return ok
        end
    end

    local previousHardStop = S.HardStop
    if type(previousHardStop)=="function" then
        function S:HardStop()
            clearTarget()
            coinAnchor=nil
            return previousHardStop(self)
        end
    end

    -- Version labels: this is a real functional patch, so expose it clearly.
    S.version = "0.4.8"
    local gui = playerGui and playerGui:FindFirstChild("BGSLegacyHub")
    if gui then
        for _,obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                local text=tostring(obj.Text or "")
                if text:find("0.4.7",1,true) then
                    obj.Text=text:gsub("0%.4%.7","0.4.8")
                elseif text=="v0.4 · чистая сортировка / hitbox fix" then
                    obj.Text="v0.4.8 · coin hitbox fix"
                elseif text=="BGS Legacy Hub 0.4.0" then
                    obj.Text="BGS Legacy Hub 0.4.8"
                end
            end
        end
    end

    S.status="BGS Legacy Hub v0.4.8 · coin farm fix"
    return S
end
