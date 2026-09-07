-- BGS Legacy Hub v0.4.3 canonical native teleport patch
-- Replaces direct CFrame island teleport with the original BGS Teleport remote.

return function(S)
    if type(S) ~= "table" then return S end

    local RS = game:GetService("ReplicatedStorage")
    local function norm(v)
        return tostring(v or ""):lower():gsub("[%s%p_]","")
    end

    local canonical = {
        {name="Starter Area", world="The Overworld", aliases={"Starter Area","Main Island","Spawn"}, order=0},
        {name="The Floating Island", world="The Overworld", aliases={"Floating Island","The Floating Island"}, order=1},
        {name="Space", world="The Overworld", aliases={"Outer Space","Space"}, order=2},
        {name="The Twilight", world="The Overworld", aliases={"Twilight","The Twilight"}, order=3},
        {name="The Skylands", world="The Overworld", aliases={"Skylands","The Skylands"}, order=4},
        {name="The Void", world="The Overworld", aliases={"Void","The Void"}, order=5},
        {name="Zen", world="The Overworld", aliases={"Zen"}, order=6},
        {name="XP Island", world="The Overworld", aliases={"XP Island","XP"}, order=7},
    }

    local function findRemote()
        local direct = RS:FindFirstChild("NetworkRemoteEvent", true)
        if direct and direct:IsA("RemoteEvent") then return direct end
        local shared = RS:FindFirstChild("Shared")
        local framework = shared and shared:FindFirstChild("Framework")
        local network = framework and framework:FindFirstChild("Network")
        local remote = network and network:FindFirstChild("Remote")
        local event = remote and remote:FindFirstChild("Event")
        if event and event:IsA("RemoteEvent") then return event end
        return nil
    end

    local function worldFolder(name)
        local worlds = workspace:FindFirstChild("Worlds")
        if not worlds then return nil end
        local exact = worlds:FindFirstChild(name)
        if exact then return exact end
        for _,child in ipairs(worlds:GetChildren()) do
            if norm(child.Name) == norm(name) then return child end
        end
    end

    local function directIslandEntry(def)
        local world = worldFolder(def.world)
        if not world then return nil end
        local islands = world:FindFirstChild("Islands")
        if not islands then return nil end

        local islandObj = nil
        for _,alias in ipairs(def.aliases) do
            islandObj = islands:FindFirstChild(alias)
            if islandObj then break end
        end
        if not islandObj then
            for _,child in ipairs(islands:GetChildren()) do
                for _,alias in ipairs(def.aliases) do
                    if norm(child.Name) == norm(alias) then islandObj = child break end
                end
                if islandObj then break end
            end
        end
        if not islandObj then return nil end

        local island = islandObj:FindFirstChild("Island") or islandObj
        local portal = island:FindFirstChild("Portal")
        local spawn = portal and portal:FindFirstChild("Spawn")
        if not spawn then return nil end

        local path = spawn:GetFullName()
        -- Original remote expects Workspace.* path spelling.
        if path:sub(1,10) == "Workspace." then
            -- already correct
        elseif path:sub(1,10) == "workspace." then
            path = "Workspace." .. path:sub(11)
        else
            path = "Workspace." .. path
        end

        return {
            object=islandObj,
            part=spawn,
            name=def.name,
            world="Overworld",
            canonical=true,
            canonicalOrder=def.order,
            remotePath=path,
        }
    end

    local function rebuild()
        local list = {}
        for _,def in ipairs(canonical) do
            local e = directIslandEntry(def)
            if e then list[#list+1] = e end
        end
        table.sort(list,function(a,b) return (a.canonicalOrder or 999) < (b.canonicalOrder or 999) end)
        S.islands = list

        if S.selectedIsland then
            local wanted = norm(S.selectedIsland.name)
            S.selectedIsland = nil
            for _,e in ipairs(list) do
                if norm(e.name) == wanted then S.selectedIsland = e break end
            end
        end
    end

    local originalRefresh = S.Refresh
    if type(originalRefresh) == "function" then
        function S:Refresh(forceIslands)
            local result = originalRefresh(self, forceIslands)
            rebuild()
            return result
        end
    end

    function S:SelectIsland(entry)
        if not entry or not entry.canonical or not entry.remotePath then
            self.status = "ТП: доступен только канонический остров"
            return false
        end
        self.selectedIsland = entry
        self.status = "Выбрано: " .. entry.name
        return true
    end

    function S:GoIsland(entry)
        entry = entry or self.selectedIsland
        if not entry or not entry.canonical or not entry.remotePath then
            self.status = "ТП: канонический путь не найден"
            return false
        end

        local remote = findRemote()
        if not remote then
            self.status = "ТП: Network Remote не найден"
            return false
        end

        local ok,err = pcall(function()
            remote:FireServer("Teleport", entry.remotePath)
        end)
        if not ok then
            self.status = "ТП ошибка: " .. tostring(err)
            return false
        end

        self.target = nil
        self.travelUntil = os.clock() + 1.2
        self.status = "ТП: " .. entry.name
        return true
    end

    rebuild()
    S.version = "0.4.3-native-tp"
    S.status = "ТП островов: штатный BGS Teleport"
    return S
end
