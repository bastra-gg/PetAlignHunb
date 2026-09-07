-- BGS Legacy Hub v0.4.2 canonical teleport patch
-- Rebuilds island list only from structured Worlds -> <world> -> Islands -> canonical island -> Portal -> Spawn.
-- If a canonical island has no trustworthy portal spawn, it is not exposed in the TP list.

return function(S)
    if type(S) ~= "table" then return S end

    local canonical = {
        {world="Overworld", worldAliases={"The Overworld","Overworld"}, name="The Floating Island", aliases={"The Floating Island","Floating Island"}, order=1},
        {world="Overworld", worldAliases={"The Overworld","Overworld"}, name="Space", aliases={"Space","Outer Space"}, order=2},
        {world="Overworld", worldAliases={"The Overworld","Overworld"}, name="The Twilight", aliases={"The Twilight","Twilight"}, order=3},
        {world="Overworld", worldAliases={"The Overworld","Overworld"}, name="The Skylands", aliases={"The Skylands","Skylands"}, order=4},
        {world="Overworld", worldAliases={"The Overworld","Overworld"}, name="The Void", aliases={"The Void","Void"}, order=5},
        {world="Overworld", worldAliases={"The Overworld","Overworld"}, name="Zen", aliases={"Zen"}, order=6},
        {world="Overworld", worldAliases={"The Overworld","Overworld"}, name="XP Island", aliases={"XP Island"}, order=7},

        {world="Candy Land", worldAliases={"Candy Land","CandyLand"}, name="Gumdrop Island", aliases={"Gumdrop Island"}, order=101},
        {world="Candy Land", worldAliases={"Candy Land","CandyLand"}, name="Rewards Island", aliases={"Rewards Island"}, order=102},
        {world="Candy Land", worldAliases={"Candy Land","CandyLand"}, name="Sugar Island", aliases={"Sugar Island"}, order=103},
        {world="Candy Land", worldAliases={"Candy Land","CandyLand"}, name="Candy Island", aliases={"Candy Island"}, order=104},
        {world="Candy Land", worldAliases={"Candy Land","CandyLand"}, name="Sweet Island", aliases={"Sweet Island"}, order=105},

        {world="Toy Land", worldAliases={"Toy Land","ToyLand"}, name="Block Island", aliases={"Block Island"}, order=201},
        {world="Toy Land", worldAliases={"Toy Land","ToyLand"}, name="Block Rewards", aliases={"Block Rewards"}, order=202},
        {world="Toy Land", worldAliases={"Toy Land","ToyLand"}, name="Toy Isle", aliases={"Toy Isle"}, order=203},
        {world="Toy Land", worldAliases={"Toy Land","ToyLand"}, name="Teddy Island", aliases={"Teddy Island"}, order=204},
        {world="Toy Land", worldAliases={"Toy Land","ToyLand"}, name="Treasure Isle", aliases={"Treasure Isle"}, order=205},

        {world="Beach World", worldAliases={"Beach World","BeachWorld"}, name="Sea Island", aliases={"Sea Island"}, order=301},
        {world="Beach World", worldAliases={"Beach World","BeachWorld"}, name="Sea Rewards", aliases={"Sea Rewards"}, order=302},
        {world="Beach World", worldAliases={"Beach World","BeachWorld"}, name="Shell Isle", aliases={"Shell Isle"}, order=303},
        {world="Beach World", worldAliases={"Beach World","BeachWorld"}, name="Oceanic Island", aliases={"Oceanic Island"}, order=304},
        {world="Beach World", worldAliases={"Beach World","BeachWorld"}, name="Sea Shell Island", aliases={"Sea Shell Island"}, order=305},

        {world="Atlantis", worldAliases={"Atlantis"}, name="Water Island", aliases={"Water Island"}, order=401},
        {world="Atlantis", worldAliases={"Atlantis"}, name="Atlantis Rewards", aliases={"Atlantis Rewards"}, order=402},
        {world="Atlantis", worldAliases={"Atlantis"}, name="Atlantis Isle", aliases={"Atlantis Isle"}, order=403},
        {world="Atlantis", worldAliases={"Atlantis"}, name="Treasure Island", aliases={"Treasure Island"}, order=404},
        {world="Atlantis", worldAliases={"Atlantis"}, name="Sandy Island", aliases={"Sandy Island"}, order=405},

        {world="Rainbow Land", worldAliases={"Rainbow Land","RainbowLand"}, name="Red Island", aliases={"Red Island"}, order=501},
        {world="Rainbow Land", worldAliases={"Rainbow Land","RainbowLand"}, name="Rainbow Rewards", aliases={"Rainbow Rewards"}, order=502},
        {world="Rainbow Land", worldAliases={"Rainbow Land","RainbowLand"}, name="Green Island", aliases={"Green Island"}, order=503},
        {world="Rainbow Land", worldAliases={"Rainbow Land","RainbowLand"}, name="Blue Island", aliases={"Blue Island"}, order=504},
        {world="Rainbow Land", worldAliases={"Rainbow Land","RainbowLand"}, name="Purple Island", aliases={"Purple Island"}, order=505},

        {world="Underworld", worldAliases={"Underworld"}, name="Fire Island", aliases={"Fire Island"}, order=601},
        {world="Underworld", worldAliases={"Underworld"}, name="Magma Rewards", aliases={"Magma Rewards"}, order=602},
        {world="Underworld", worldAliases={"Underworld"}, name="Magma Island", aliases={"Magma Island"}, order=603},
        {world="Underworld", worldAliases={"Underworld"}, name="Inferno Island", aliases={"Inferno Island"}, order=604},
        {world="Underworld", worldAliases={"Underworld"}, name="Molten Island", aliases={"Molten Island"}, order=605},

        {world="Mystic Forest", worldAliases={"Mystic Forest","MysticForest"}, name="Crystal Island", aliases={"Crystal Island"}, order=701},
        {world="Mystic Forest", worldAliases={"Mystic Forest","MysticForest"}, name="Crystal Rewards", aliases={"Crystal Rewards"}, order=702},
        {world="Mystic Forest", worldAliases={"Mystic Forest","MysticForest"}, name="Mythic Island", aliases={"Mythic Island"}, order=703},
        {world="Mystic Forest", worldAliases={"Mystic Forest","MysticForest"}, name="Spirit Island", aliases={"Spirit Island"}, order=704},
        {world="Mystic Forest", worldAliases={"Mystic Forest","MysticForest"}, name="Magic Island", aliases={"Magic Island"}, order=705},
    }

    local function norm(v)
        return tostring(v or ""):lower():gsub("[%s%p_]","")
    end

    local function partOf(o)
        if not o then return nil end
        if o:IsA("BasePart") then return o end
        if o:IsA("Attachment") then
            return o.Parent and o.Parent:IsA("BasePart") and o.Parent or nil
        end
        if o:IsA("Model") and o.PrimaryPart then return o.PrimaryPart end
        return o:FindFirstChildWhichIsA("BasePart",true)
    end

    local function findChildByAliases(parent,aliases,recursive)
        if not parent then return nil end
        local wanted={}
        for _,a in ipairs(aliases) do wanted[norm(a)]=true end
        local list=recursive and parent:GetDescendants() or parent:GetChildren()
        for _,o in ipairs(list) do
            if wanted[norm(o.Name)] then return o end
        end
        return nil
    end

    local function portalSpawn(island)
        if not island then return nil end
        -- Prefer exact Portal -> Spawn hierarchy.
        for _,o in ipairs(island:GetDescendants()) do
            if norm(o.Name)=="portal" then
                local spawn=o:FindFirstChild("Spawn",true)
                local p=partOf(spawn)
                if p then return p end
            end
        end
        -- Some recreations use a Teleport container instead of Portal.
        for _,o in ipairs(island:GetDescendants()) do
            local n=norm(o.Name)
            if n=="teleport" or n=="teleporter" then
                local spawn=o:FindFirstChild("Spawn",true)
                local p=partOf(spawn)
                if p then return p end
            end
        end
        return nil
    end

    local function getWorldsRoot()
        local direct=workspace:FindFirstChild("Worlds")
        if direct then return direct end
        for _,o in ipairs(workspace:GetChildren()) do
            if norm(o.Name)=="worlds" then return o end
        end
        return nil
    end

    local function structuredScan()
        local out={}
        local worlds=getWorldsRoot()
        if not worlds then return out end

        for _,def in ipairs(canonical) do
            local world=findChildByAliases(worlds,def.worldAliases,false)
            if world then
                local islands=findChildByAliases(world,{"Islands"},false)
                if not islands then islands=findChildByAliases(world,{"Islands"},true) end
                if islands then
                    local island=findChildByAliases(islands,def.aliases,false)
                    if not island then island=findChildByAliases(islands,def.aliases,true) end
                    if island then
                        local spawn=portalSpawn(island)
                        if spawn then
                            out[#out+1]={
                                object=island,
                                part=spawn,
                                teleportPart=spawn,
                                name=def.name,
                                world=def.world,
                                canonical=true,
                                canonicalOrder=def.order,
                            }
                        end
                    end
                end
            end
        end

        table.sort(out,function(a,b)
            return (a.canonicalOrder or 999999) < (b.canonicalOrder or 999999)
        end)
        return out
    end

    local originalRefresh=S.Refresh
    function S:Refresh(forceIslands)
        local result=nil
        if type(originalRefresh)=="function" then result=originalRefresh(self,false) end
        self.islands=structuredScan()
        self.selectedIsland=nil
        self.nextIslandScan=os.clock()+60
        return result
    end

    local originalSelect=S.SelectIsland
    function S:SelectIsland(entry)
        if not entry or not entry.canonical or not entry.teleportPart or not entry.teleportPart.Parent then
            self.status="ТП заблокирован: нет канонической Portal/Spawn точки"
            return false
        end
        self.selectedIsland=entry
        self.status="Выбрано: "..entry.name
        return true
    end

    function S:GoIsland(entry)
        entry=entry or self.selectedIsland
        if not entry or not entry.canonical or not entry.teleportPart or not entry.teleportPart.Parent then
            self.status="ТП заблокирован: цель не каноническая"
            return false
        end

        local Players=game:GetService("Players")
        local lp=Players.LocalPlayer
        local c=lp and lp.Character
        local r=c and c:FindFirstChild("HumanoidRootPart")
        local h=c and c:FindFirstChildOfClass("Humanoid")
        if not r or not h or h.Health<=0 then
            self.status="Жду персонажа"
            return false
        end

        pcall(function()
            h:MoveTo(r.Position)
            h:Move(Vector3.zero,false)
            h.Sit=false
        end)

        local target=entry.teleportPart
        local cf=target.CFrame + Vector3.new(0,math.max(3,target.Size.Y/2+2),0)
        r.CFrame=cf
        r.AssemblyLinearVelocity=Vector3.zero
        r.AssemblyAngularVelocity=Vector3.zero
        self.target=nil
        self.travelUntil=os.clock()+1.0
        self.status="ТП: "..entry.name
        return true
    end

    S.islands=structuredScan()
    S.selectedIsland=nil
    S.version="0.4.2-canonical-spawn"
    S.status="ТП: только канонические Portal/Spawn точки"
    return S
end
