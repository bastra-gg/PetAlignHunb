-- BGS Legacy Hub v0.4.4 REAL ISLANDS patch
-- Permanent OG BGS islands only. Landing is resolved from the island's own geometry,
-- never from Portal/Spawn/FastTravel mini-platforms.

return function(S)
    if type(S) ~= "table" then return S end

    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local W = workspace

    local function norm(v)
        return tostring(v or ""):lower():gsub("[%s%p_]", "")
    end

    local WORLD_ORDER = {
        ["Overworld"]=1,["Candy Land"]=2,["Toy Land"]=3,["Beach World"]=4,
        ["Atlantis"]=5,["Rainbow Land"]=6,["Underworld"]=7,["Mystic Forest"]=8,
    }

    -- Canonical permanent progression only: 7 Overworld islands + 5 in each other permanent world.
    local defs = {
        {"The Floating Island","Overworld",1,"normal",85,{"Floating Island","The Floating Island"}},
        {"Space","Overworld",2,"gem",518,{"Space"}},
        {"The Twilight","Overworld",3,"gem",1134,{"Twilight","The Twilight"}},
        {"The Skylands","Overworld",4,"gem",2105,{"Skylands","The Skylands"}},
        {"The Void","Overworld",5,"gem",3208,{"Void","The Void"}},
        {"Zen","Overworld",6,"gem",4065,{"Zen"}},
        {"XP Island","Overworld",7,"gem",5338,{"XP Island"}},

        {"Gumdrop Island","Candy Land",1,"normal",nil,{"Gumdrop Island"}},
        {"Rewards Island","Candy Land",2,"normal",nil,{"Rewards Island"}},
        {"Sugar Island","Candy Land",3,"normal",nil,{"Sugar Island"}},
        {"Candy Island","Candy Land",4,"normal",nil,{"Candy Island"}},
        {"Sweet Island","Candy Land",5,"normal",nil,{"Sweet Island"}},

        {"Block Island","Toy Land",1,"normal",nil,{"Block Island"}},
        {"Block Rewards","Toy Land",2,"normal",nil,{"Block Rewards"}},
        {"Toy Isle","Toy Land",3,"normal",nil,{"Toy Isle"}},
        {"Teddy Island","Toy Land",4,"normal",nil,{"Teddy Island"}},
        {"Treasure Isle","Toy Land",5,"normal",nil,{"Treasure Isle"}},

        {"Sea Island","Beach World",1,"normal",nil,{"Sea Island"}},
        {"Sea Rewards","Beach World",2,"normal",nil,{"Sea Rewards"}},
        {"Shell Isle","Beach World",3,"normal",nil,{"Shell Isle"}},
        {"Oceanic Island","Beach World",4,"normal",nil,{"Oceanic Island"}},
        {"Sea Shell Island","Beach World",5,"normal",nil,{"Sea Shell Island"}},

        {"Water Island","Atlantis",1,"normal",nil,{"Water Island"}},
        {"Atlantis Rewards","Atlantis",2,"normal",nil,{"Atlantis Rewards"}},
        {"Atlantis Isle","Atlantis",3,"normal",nil,{"Atlantis Isle"}},
        {"Treasure Island","Atlantis",4,"normal",nil,{"Treasure Island"}},
        {"Sandy Island","Atlantis",5,"normal",nil,{"Sandy Island"}},

        {"Red Island","Rainbow Land",1,"normal",nil,{"Red Island"}},
        {"Rainbow Rewards","Rainbow Land",2,"normal",nil,{"Rainbow Rewards"}},
        {"Green Island","Rainbow Land",3,"normal",nil,{"Green Island"}},
        {"Blue Island","Rainbow Land",4,"normal",nil,{"Blue Island"}},
        {"Purple Island","Rainbow Land",5,"normal",nil,{"Purple Island"}},

        {"Fire Island","Underworld",1,"normal",nil,{"Fire Island"}},
        {"Magma Rewards","Underworld",2,"normal",nil,{"Magma Rewards"}},
        {"Magma Island","Underworld",3,"normal",nil,{"Magma Island"}},
        {"Inferno Island","Underworld",4,"normal",nil,{"Inferno Island"}},
        {"Molten Island","Underworld",5,"normal",nil,{"Molten Island"}},

        {"Crystal Island","Mystic Forest",1,"gem",nil,{"Crystal Island"}},
        {"Crystal Rewards","Mystic Forest",2,"gem",nil,{"Crystal Rewards"}},
        {"Mythic Island","Mystic Forest",3,"gem",nil,{"Mythic Island"}},
        {"Spirit Island","Mystic Forest",4,"gem",nil,{"Spirit Island"}},
        {"Magic Island","Mystic Forest",5,"gem",nil,{"Magic Island"}},
    }

    local aliasMap = {}
    for _,d in ipairs(defs) do
        for _,a in ipairs(d[6]) do aliasMap[norm(a)] = d end
    end

    local bad = {"portal","teleport","fasttravel","door","gate","hub","map","preview","mini","button","gui","showcase","display"}
    local event = {"christmas","halloween","easter","valentine","spring","fall","carnival","circus","event"}

    local function hasWord(name,list)
        local low=tostring(name or ""):lower()
        for _,w in ipairs(list) do if low:find(w,1,true) then return true end end
        return false
    end

    local function badAncestor(obj,list,limit)
        local p=obj and obj.Parent
        local n=0
        while p and p~=W and n<(limit or 10) do
            if hasWord(p.Name,list) then return true end
            p=p.Parent n=n+1
        end
        return false
    end

    local function badBetween(part,obj)
        local p=part
        while p and p~=obj do
            if hasWord(p.Name,bad) then return true end
            p=p.Parent
        end
        return false
    end

    local function groundOf(obj)
        local best,bestScore=nil,-1
        local total,count=0,0
        local function consider(p)
            if not p:IsA("BasePart") or p.Transparency>=0.98 or badBetween(p,obj) then return end
            local area=math.max(0.01,p.Size.X*p.Size.Z)
            local flat=math.abs(p.CFrame.UpVector.Y)>=0.6 and 2 or 0.45
            local solid=p.CanCollide and 2 or 0.5
            local score=area*flat*solid
            total=total+area count=count+1
            if score>bestScore then best,bestScore=p,score end
        end
        if obj:IsA("BasePart") then consider(obj) else for _,p in ipairs(obj:GetDescendants()) do consider(p) end end
        return best,bestScore,total,count
    end

    local function scoreCandidate(obj,d,ground,gscore,total,count)
        if not ground or badAncestor(obj,event,14) or badAncestor(obj,bad,8) then return -math.huge end
        local score=math.min(gscore,500000)/100 + math.min(total,1000000)/500 + math.min(count,250)*4
        if obj.Parent and norm(obj.Parent.Name)=="islands" then score=score+4000 end
        if d[5] then score=score-math.abs(ground.Position.Y-d[5])*4 end
        if ground.Size.X*ground.Size.Z<60 then score=score-5000 end
        if total<150 then score=score-2500 end
        return score
    end

    local function bestFor(d)
        local best,bestScore=nil,-math.huge
        for _,obj in ipairs(W:GetDescendants()) do
            if (obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart")) and aliasMap[norm(obj.Name)]==d then
                local ground,gscore,total,count=groundOf(obj)
                local score=scoreCandidate(obj,d,ground,gscore,total,count)
                if score>bestScore then
                    bestScore=score
                    best={object=obj,part=ground,landingPart=ground,name=d[1],world=d[2],knownOrder=d[3],kind=d[4],canonical=true,y=ground and ground.Position.Y or 0}
                end
            end
        end
        if bestScore<0 then return nil end
        return best
    end

    local cache,nextScan={},0
    local function rebuild()
        local list={}
        for _,d in ipairs(defs) do
            local e=bestFor(d)
            if e then list[#list+1]=e end
        end
        table.sort(list,function(a,b)
            local wa,wb=WORLD_ORDER[a.world] or 99,WORLD_ORDER[b.world] or 99
            if wa~=wb then return wa<wb end
            return (a.knownOrder or 99)<(b.knownOrder or 99)
        end)
        for i,e in ipairs(list) do e.order=i end
        cache=list nextScan=os.clock()+20
    end

    local oldRefresh=S.Refresh
    if type(oldRefresh)=="function" then
        function S:Refresh(forceIslands)
            local selectedName=self.selectedIsland and self.selectedIsland.name
            local selectedWorld=self.selectedIsland and self.selectedIsland.world
            local result=oldRefresh(self,false)
            if forceIslands or os.clock()>=nextScan or #cache==0 then rebuild() end
            self.islands=cache
            self.selectedIsland=nil
            if selectedName then
                for _,e in ipairs(cache) do if e.name==selectedName and e.world==selectedWorld then self.selectedIsland=e break end end
            end
            return result
        end
    end

    function S:SelectIsland(e)
        if not e or not e.canonical or not e.landingPart or not e.landingPart.Parent then self.status="ТП: невалидный остров" return false end
        self.selectedIsland=e self.status="Выбрано: "..e.name return true
    end

    local function root()
        local c=player and player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function hum()
        local c=player and player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    function S:GoIsland(e)
        e=e or self.selectedIsland
        if not e or not e.canonical or not e.landingPart or not e.landingPart.Parent then self.status="ТП: остров не загружен" return false end
        local r,h=root(),hum()
        if not r or not h or h.Health<=0 then self.status="ТП: жду персонажа" return false end
        h.Sit=false
        pcall(function() h:MoveTo(r.Position) h:Move(Vector3.zero,false) end)
        local extra=math.max(4,h.HipHeight+r.Size.Y/2+1.5)
        local p=e.landingPart.CFrame:PointToWorldSpace(Vector3.new(0,e.landingPart.Size.Y/2+extra,0))
        r.CFrame=CFrame.new(p)*(r.CFrame-r.Position)
        r.AssemblyLinearVelocity=Vector3.zero r.AssemblyAngularVelocity=Vector3.zero
        self.target=nil self.travelUntil=os.clock()+1.25 self.status="ТП на остров: "..e.name
        return true
    end

    rebuild()
    S.islands=cache
    S.selectedIsland=nil
    S.version="0.4.4-real-islands"
    S.canonicalIslandCount=#cache
    S.status="ТП: найдено "..tostring(#cache).." реальных островов"
    return S
end
