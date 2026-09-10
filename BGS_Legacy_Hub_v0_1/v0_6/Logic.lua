-- Pure decisions shared by the runtime and executable regression scenarios.
local L={}
function L.norm(value)
    return tostring(value or ""):lower():gsub("[%s%p_]", "")
end
L.worlds={
    {key="Overworld",display="Overworld · спавн",currency="Coins"},
    {key="Candy Land",display="Candy Land · мир конфет",currency="Candy"},
    {key="Toy Land",display="Toy Land · мир игрушек",currency="Blocks"},
    {key="Beach World",display="Beach World · пляж",currency="Shells"},
    {key="Atlantis",display="Atlantis · Атлантида",currency="Pearls"},
    {key="Rainbow Land",display="Rainbow Land · радужный мир",currency="Stars"},
    {key="Underworld",display="Underworld · вулканический мир",currency="Magma"},
    {key="Mystic Forest",display="Mystic Forest · мифический лес",currency="Crystals"},
    {key="Heaven",display="Heaven · райский мир",currency="Gems"},
}
function L.world(value)
    local key=L.norm(value):gsub("^the", "")
    for _,world in ipairs(L.worlds) do
        if L.norm(world.key)==key then return world.key end
    end
end
L.chests={
    {world="Overworld",name="The Floating Island",aliases={"Floating Island"}},
    {world="Overworld",name="The Skylands",aliases={"The Skyland","Skylands"}},
    {world="Overworld",name="The Void",aliases={"Void"}},
    {world="Candy Land",name="Gumdrop Island"},
    {world="Candy Land",name="Candy Island"},
    {world="Candy Land",name="Sweet Island"},
    {world="Toy Land",name="Block Rewards",aliases={"Block Island"}},
    {world="Toy Land",name="Teddy Island"},
    {world="Toy Land",name="Treasure Isle",aliases={"Treasure Island"}},
    {world="Beach World",name="Sea Island"},
    {world="Beach World",name="Oceanic Island"},
    {world="Beach World",name="Sea Shell Island",aliases={"Sea Shell Isle","See Shell Isle"}},
    {world="Atlantis",name="Water Island"},
    {world="Atlantis",name="Sandy Island"},
    {world="Rainbow Land",name="Red Island"},
    {world="Rainbow Land",name="Blue Island"},
    {world="Rainbow Land",name="Purple Island"},
    {world="Underworld",name="Fire Island"},
    {world="Underworld",name="Inferno Island"},
    {world="Mystic Forest",name="Crystal Island"},
    {world="Heaven",name="Light Island"},
    {world="Heaven",name="Cloud Island",aliases={"Claud Island"}},
    {world="Heaven",name="Spirit Island"},
}
function L.matches(name,def)
    if L.norm(name)==L.norm(def.name) then return true end
    for _,alias in ipairs(def.aliases or {}) do
        if L.norm(name)==L.norm(alias) then return true end
    end
    return false
end
function L.hatchArgs(name,count)
    if count==3 then return table.pack("PurchaseEgg",name,"Multi") end
    return table.pack("PurchaseEgg",name)
end
function L.newLease()
    local self={generation=0,current=nil}
    function self:cancel()
        self.generation+=1
        self.current=nil
    end
    function self:begin(kind,character,saved)
        if self.current then return nil end
        self.generation+=1
        local ticket={generation=self.generation,kind=kind,character=character,saved=saved}
        self.current=ticket
        return ticket
    end
    function self:valid(ticket,character,alive)
        return alive and ticket~=nil and self.current==ticket
            and ticket.generation==self.generation and ticket.character==character
    end
    function self:finish(ticket)
        if self.current==ticket then self.current=nil end
    end
    return self
end
-- One request per group/snapshot. Never count shiny, locked, equipped or duplicate IDs.
function L.shinyGroups(pets,filter)
    local groups,seen={},{}
    for _,pet in ipairs(pets) do
        if pet.id~=nil and type(pet.name)=="string" and not seen[pet.id] then
            seen[pet.id]=true
            if pet.shiny==false and pet.locked==false and pet.equipped==false
                and (not filter or filter=="Все" or filter==pet.name) then
                local group=groups[pet.name] or {}
                groups[pet.name]=group
                group[#group+1]=pet.id
            end
        end
    end
    local out={}
    for name,ids in pairs(groups) do
        if #ids>=10 then
            table.sort(ids,function(a,b) return tostring(a)<tostring(b) end)
            local signature={}
            for _,id in ipairs(ids) do signature[#signature+1]=tostring(id) end
            out[#out+1]={name=name,id=ids[1],count=#ids,signature=table.concat(signature,"|")}
        end
    end
    table.sort(out,function(a,b) return a.name<b.name end)
    return out
end
function L.matchNext(memory,matched,first,count)
    if first then
        for i=1,count do
            if i~=first and not matched[i] and memory[first]~=nil and memory[i]==memory[first] then return i end
        end
        for i=1,count do if i~=first and not matched[i] and memory[i]==nil then return i end end
        for i=1,count do if i~=first and not matched[i] then return i end end
    else
        for i=1,count do
            if not matched[i] and memory[i]~=nil then
                for j=i+1,count do
                    if not matched[j] and memory[j]==memory[i] then return i end
                end
            end
        end
        for i=1,count do if not matched[i] and memory[i]==nil then return i end end
        for i=1,count do if not matched[i] then return i end end
    end
end
return L
