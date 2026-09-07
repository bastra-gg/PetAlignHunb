-- BGS Legacy Hub v0.4.1 canonical-islands patch
-- Keeps only known Bubble Gum Simulator islands and blocks any non-whitelisted teleport target.

return function(S)
    if type(S) ~= "table" then return S end

    local canonical = {
        {name="Starter Area",world="Overworld",height=0},
        {name="The Floating Island",world="Overworld",height=85},
        {name="Space",world="Overworld",height=518},
        {name="The Twilight",world="Overworld",height=1134},
        {name="The Skylands",world="Overworld",height=2105},
        {name="The Void",world="Overworld",height=3208},
        {name="Zen",world="Overworld",height=4065},
        {name="XP Island",world="Overworld"},

        {name="Gumdrop Island",world="Candy Land"},
        {name="Rewards Island",world="Candy Land"},
        {name="Sugar Island",world="Candy Land"},
        {name="Candy Island",world="Candy Land"},
        {name="Sweet Island",world="Candy Land"},

        {name="Block Island",world="Toy Land"},
        {name="Block Rewards",world="Toy Land"},
        {name="Toy Isle",world="Toy Land"},
        {name="Teddy Island",world="Toy Land"},
        {name="Treasure Isle",world="Toy Land"},

        {name="Sea Island",world="Beach World"},
        {name="Sea Rewards",world="Beach World"},
        {name="Shell Isle",world="Beach World"},
        {name="Oceanic Island",world="Beach World"},
        {name="Sea Shell Island",world="Beach World"},

        {name="Water Island",world="Atlantis"},
        {name="Atlantis Rewards",world="Atlantis"},
        {name="Atlantis Isle",world="Atlantis"},
        {name="Treasure Island",world="Atlantis"},
        {name="Sandy Island",world="Atlantis"},

        {name="Red Island",world="Rainbow Land"},
        {name="Rainbow Rewards",world="Rainbow Land"},
        {name="Green Island",world="Rainbow Land"},
        {name="Blue Island",world="Rainbow Land"},
        {name="Purple Island",world="Rainbow Land"},

        {name="Fire Island",world="Underworld"},
        {name="Magma Rewards",world="Underworld"},
        {name="Magma Island",world="Underworld"},
        {name="Inferno Island",world="Underworld"},
        {name="Molten Island",world="Underworld"},

        {name="Crystal Island",world="Mystic Forest"},
        {name="Crystal Rewards",world="Mystic Forest"},
        {name="Mythic Island",world="Mystic Forest"},
        {name="Spirit Island",world="Mystic Forest"},
        {name="Magic Island",world="Mystic Forest"},
    }

    local function norm(v)
        return tostring(v or ""):lower():gsub("[%s%p_]","")
    end

    local defs = {}
    for order,def in ipairs(canonical) do
        def.order = order
        def.key = norm(def.name)
        defs[def.key] = def
    end

    local badWords = {"portal","teleport","door","gate","egg","shop","button","ui","gui","preview","modeldisplay"}
    local function looksDecorative(object)
        local current = object
        for _=1,6 do
            if not current then break end
            local name = tostring(current.Name or ""):lower()
            for _,word in ipairs(badWords) do
                if name:find(word,1,true) then return true end
            end
            current = current.Parent
        end
        return false
    end

    local function candidateScore(entry,def)
        if not entry or not entry.object or not entry.object.Parent or not entry.part or not entry.part.Parent then
            return math.huge
        end

        local score = 0
        if looksDecorative(entry.object) then score = score + 100000 end

        if def.height then
            score = score + math.abs(entry.part.Position.Y - def.height)
        end

        local area = math.max(1,entry.part.Size.X * entry.part.Size.Z)
        score = score - math.min(area,10000) / 1000

        if norm(entry.object.Name) == def.key then score = score - 10 end
        if entry.object.Parent == workspace then score = score - 3 end

        return score
    end

    local function filterCanonical()
        local best = {}

        for _,entry in ipairs(S.islands or {}) do
            local def = defs[norm(entry.name)]
            if def then
                local score = candidateScore(entry,def)
                local previous = best[def.key]
                if not previous or score < previous.score then
                    best[def.key] = {entry=entry,score=score,def=def}
                end
            end
        end

        local filtered = {}
        for _,def in ipairs(canonical) do
            local picked = best[def.key]
            if picked and picked.score < 100000 then
                local entry = picked.entry
                entry.name = def.name
                entry.world = def.world
                entry.height = def.height
                entry.canonical = true
                entry.canonicalOrder = def.order
                filtered[#filtered+1] = entry
            end
        end

        S.islands = filtered

        if S.selectedIsland then
            local selectedKey = norm(S.selectedIsland.name)
            local replacement = nil
            for _,entry in ipairs(filtered) do
                if norm(entry.name) == selectedKey then
                    replacement = entry
                    break
                end
            end
            S.selectedIsland = replacement
        end
    end

    local originalRefresh = S.Refresh
    if type(originalRefresh) == "function" then
        function S:Refresh(forceIslands)
            local result = originalRefresh(self,forceIslands)
            filterCanonical()
            return result
        end
    end

    local originalSelectIsland = S.SelectIsland
    if type(originalSelectIsland) == "function" then
        function S:SelectIsland(entry)
            local def = entry and defs[norm(entry.name)]
            if not def or not entry.canonical then
                self.status = "ТП заблокирован: это не канонический остров"
                return false
            end
            return originalSelectIsland(self,entry)
        end
    end

    local originalGoIsland = S.GoIsland
    if type(originalGoIsland) == "function" then
        function S:GoIsland(entry)
            entry = entry or self.selectedIsland
            local def = entry and defs[norm(entry.name)]
            if not def or not entry.canonical then
                self.status = "ТП заблокирован: цель вне списка BGS"
                return false
            end
            return originalGoIsland(self,entry)
        end
    end

    filterCanonical()
    S.version = "0.4.1-canonical-tp"
    S.status = "ТП: только канонические острова"
    return S
end
