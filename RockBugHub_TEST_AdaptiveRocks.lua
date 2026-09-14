-- RockBugHub TEST T40: durability-adaptive rocks
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
if not player then return end

local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local runtime=env.RockBugRuntime
if type(runtime)~="table"then return end

if env.RockBugAdaptiveRocks and type(env.RockBugAdaptiveRocks.Destroy)=="function"then
    pcall(env.RockBugAdaptiveRocks.Destroy)
end

local patch={alive=true,lastDurability=nil,lastRock=nil,lastSource=nil}
env.RockBugAdaptiveRocks=patch
runtime.adaptiveRocks=true
runtime.autoRockSelection=false -- the old rebirth/XP alignment picker must not fight this selector

-- Ordered from strongest requirement to weakest. These are the game's neededDurability values.
local rocks={
    {id="AncientJungle",label="Древний лес",en="Ancient Jungle",req=10000000,mult=16.25},
    {id="MuscleKing",label="Король мышц",en="Muscle King",req=5000000,mult=12.5},
    {id="Legends",label="Легенды",en="Legends",req=1000000,mult=2.5},
    {id="Inferno",label="Инферно",en="Inferno",req=750000,mult=1.125},
    {id="Mystic",label="Мистический",en="Mystic",req=400000,mult=0.75},
    {id="Frozen",label="Ледяной",en="Frozen",req=150000,mult=0.375},
    {id="Golden",label="Золотой",en="Golden",req=5000,mult=0.2},
    {id="Large",label="Большой",en="Large",req=100,mult=0.075},
    {id="Punching",label="Пробивной",en="Punching",req=10,mult=0.05},
    {id="Tiny",label="Маленький",en="Tiny",req=0,mult=0.025},
}

local function compact(value)
    value=tonumber(value)
    if not value then return "—" end
    local abs=math.abs(value)
    for _,unit in ipairs({{1e15,"Q"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}})do
        if abs>=unit[1]then
            local s=("%.2f%s"):format(value/unit[1],unit[2])
            s=s:gsub("%.00([KMBTQ])$","%1"):gsub("(%.[0-9])0([KMBTQ])$","%1%2")
            return s
        end
    end
    return tostring(math.floor(value+0.5))
end

local function parseNumber(value)
    if type(value)=="number"then return value end
    local s=tostring(value or""):lower():gsub("%s+","")
    local n,suffix=s:match("^([%+%-]?[%d%.,]+)([kmbtq]?)$")
    if not n then return tonumber(value)end
    -- Game values are normally raw numbers; this also tolerates 1.5M-style strings.
    if n:find(",",1,true)and not n:find("%.")then
        local a,b=n:match("^(%-?%d+),(%d+)$")
        if a and b and #b<=2 then n=a.."."..b else n=n:gsub(",","")end
    else
        n=n:gsub(",","")
    end
    local num=tonumber(n)
    if not num then return nil end
    local mul={k=1e3,m=1e6,b=1e9,t=1e12,q=1e15}
    return num*(mul[suffix]or 1)
end

local cachedValue=nil
local function durabilityScore(object)
    if not object or not object:IsA("ValueBase")then return nil end
    local name=string.lower(tostring(object.Name or""))
    local score=0
    if name=="durability"then score=1000
    elseif name:find("durability",1,true)then score=900
    elseif name=="endurance"or name:find("endurance",1,true)then score=620
    elseif name:find("долговеч",1,true)or name:find("прочност",1,true)or name:find("вынослив",1,true)then score=600
    else return nil end
    if name:find("mult",1,true)or name:find("boost",1,true)or name:find("gain",1,true)or name:find("percent",1,true)then score=score-800 end
    local leader=player:FindFirstChild("leaderstats")
    if leader and object:IsDescendantOf(leader)then score=score+150 end
    return score
end

local function readDurability()
    if cachedValue and cachedValue.Parent then
        local ok,v=pcall(function()return parseNumber(cachedValue.Value)end)
        if ok and v and v>=0 then return v,cachedValue:GetFullName()end
    end
    for _,key in ipairs({"Durability","durability"})do
        local ok,v=pcall(function()return player:GetAttribute(key)end)
        if ok then v=parseNumber(v)if v and v>=0 then return v,"attribute:"..key end end
    end
    local best,bestScore=nil,-math.huge
    local ok,list=pcall(function()return player:GetDescendants()end)
    if ok then
        for _,object in ipairs(list)do
            local score=durabilityScore(object)
            if score and score>bestScore then
                local good,v=pcall(function()return parseNumber(object.Value)end)
                if good and v and v>=0 then best,bestScore=object,score end
            end
        end
    end
    cachedValue=best
    if best then
        local good,v=pcall(function()return parseNumber(best.Value)end)
        if good and v then return v,best:GetFullName()end
    end
    return nil,nil
end

local function bestRockFor(durability)
    if durability==nil then return nil end
    for _,rock in ipairs(rocks)do
        if durability>=rock.req then return rock end
    end
    return rocks[#rocks]
end

local function rockName(rock)
    if not rock then return "—" end
    if runtime.layoutUI and type(runtime.layoutUI.rockName)=="function"then
        local ok,name=pcall(runtime.layoutUI.rockName,rock)
        if ok and type(name)=="string"and name~=""then return name end
    end
    return runtime.language=="en"and rock.en or rock.label
end

local function applySelection(force)
    if not patch.alive then return false end
    local durability,source=readDurability()
    if durability==nil then
        patch.lastDurability=nil
        patch.lastSource=nil
        runtime.adaptiveRockDurability=nil
        runtime.adaptiveRockStatus=runtime.language=="en"and"Durability not found"or"Долговечность не найдена"
        return false
    end
    local rock=bestRockFor(durability)
    if not rock then return false end
    local changed=force or patch.lastDurability~=durability or not runtime.selectedRock or runtime.selectedRock.id~=rock.id
    runtime.autoRockSelection=false
    runtime.selectedRock=rock
    runtime.adaptiveRockDurability=durability
    runtime.adaptiveRockRequirement=rock.req
    runtime.adaptiveRockName=rockName(rock)
    runtime.adaptiveRockStatus=(runtime.language=="en"and"Durability "or"Долговечность ")..compact(durability).." • "..rockName(rock)
    runtime.autoRockReason=runtime.adaptiveRockStatus
    runtime.autoRockCalc={durability=durability,requirement=rock.req,adaptive=true}
    patch.lastDurability=durability
    patch.lastRock=rock.id
    patch.lastSource=source
    return changed
end

local function applyClassicUI()
    local ui=runtime.ui
    local layout=runtime.layoutUI
    if type(ui)~="table"or type(layout)~="table"then return end
    local title=ui.autoRockTitle
    local name=ui.autoRockName
    local stats=ui.autoRockStats
    local rock=runtime.selectedRock
    local durability=runtime.adaptiveRockDurability
    local rn=rockName(rock)
    local ru=runtime.language~="en"
    if title and title.Parent then
        title.Text=ru and"АДАПТИВНЫЙ КАМЕНЬ"or"ADAPTIVE ROCK"
        title.Size=UDim2.new(1,-16,0,36)
        title.Position=UDim2.fromOffset(8,3)
    end
    if layout.autoRockButton and layout.autoRockButton.Parent then layout.autoRockButton.Visible=false end
    if name and name.Parent then
        name.Text=rn..(rock and("  •  "..(ru and"нужно "or"needs ")..compact(rock.req))or"")
    end
    if stats and stats.Parent then
        if durability then
            stats.Text=(ru and"Долговечность: "or"Durability: ")..compact(durability)..(ru and"  •  лучший доступный камень меняется автоматически"or"  •  best available rock updates automatically")
        else
            stats.Text=ru and"Долговечность не найдена — проверь данные игрока"or"Durability not found — check player data"
        end
    end
    if layout.chooseRockButton and layout.chooseRockButton.Parent then
        layout.chooseRockButton.Parent.Visible=false
    end
    if title and title.Parent and title.Parent.Parent and title.Parent.Parent.Parent then
        local body=title.Parent.Parent
        local panel=body.Parent
        pcall(function()panel.Size=UDim2.new(1,0,0,136)end)
        for _,node in ipairs(panel:GetChildren())do
            if node:IsA("TextLabel")then
                local t=string.upper(tostring(node.Text or""))
                if t:find("ВЫБОР КАМНЯ",1,true)or t:find("SELECT ROCK",1,true)then node.Text=ru and"КАМЕНЬ"or"ROCK"end
            end
        end
    end
    if layout.sectionInfo and layout.sectionInfo.bug then
        layout.sectionInfo.bug.hint=ru and"Камень выбирается автоматически по долговечности."or"The best rock is selected automatically from durability."
    end
end

local function applyHologramUI()
    local holo=runtime.hologram
    if type(holo)~="table"or holo.destroyed or holo.group~="farm"then return end
    local cards=holo.cards
    local card=type(cards)=="table"and cards[1]or nil
    if not card then return end
    local ru=runtime.language~="en"
    local rock=runtime.selectedRock
    local durability=runtime.adaptiveRockDurability
    local rn=rockName(rock)
    if card.primary and card.primary.text then card.primary.text.Text=ru and"Автоудар"or"Auto punch"end
    if card.more and card.more.text then
        card.more.text.Text=(ru and"Лучший: "or"Best: ")..rn.."  →"
    end
    if card.hint then
        card.hint.Text=durability and((ru and"Долговечность: "or"Durability: ")..compact(durability).."  •  "..rn)or(ru and"Долговечность не найдена"or"Durability not found")
    end
end

-- Guarantee that both the hologram button and the detailed toggle select the current rock before starting.
local bugRef=runtime.leverRefs and runtime.leverRefs.bug
local originalBugSet=nil
if bugRef and type(bugRef.Set)=="function"then
    originalBugSet=bugRef.Set
    bugRef.Set=function(nextValue,silent)
        if nextValue then applySelection(true)applyClassicUI()end
        return originalBugSet(nextValue,silent)
    end
end

local binding="RockBugAdaptiveRocksT40_"..tostring(player.UserId)
local nextRead=0
pcall(function()RunService:UnbindFromRenderStep(binding)end)
RunService:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value+2,function()
    if not patch.alive or not runtime.alive then return end
    local now=os.clock()
    if now>=nextRead then
        nextRead=now+0.35
        applySelection(false)
        applyClassicUI()
    end
    -- The base T38 hologram redraws its hint every frame, so overwrite only this one card after it renders.
    applyHologramUI()
end)

function patch.Destroy()
    if not patch.alive then return end
    patch.alive=false
    pcall(function()RunService:UnbindFromRenderStep(binding)end)
    if bugRef and originalBugSet and bugRef.Set~=originalBugSet then bugRef.Set=originalBugSet end
    if env.RockBugAdaptiveRocks==patch then env.RockBugAdaptiveRocks=nil end
end

applySelection(true)
applyClassicUI()
applyHologramUI()
return patch
