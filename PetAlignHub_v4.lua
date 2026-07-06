-- PetAlignHub v4
-- Упор: вписал ребы -> сразу лучший вариант + понятная инструкция.

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local BASE = {Basic=250, Uncommon=500, Rare=750, Epic=1000, Unique=1250}
local STAT = {Basic=1, Uncommon=2, Rare=3, Epic=4, Unique=5}

local RARITIES = {
    {id="Auto", name="Пет: Auto"},
    {id="Unique", name="Пет: Unique"},
    {id="Epic", name="Пет: Epic"},
    {id="Rare", name="Пет: Rare"},
    {id="Uncommon", name="Пет: Uncommon"},
    {id="Basic", name="Пет: Basic"},
}

local ROCKS = {
    {id="Auto", name="Камень: Auto", v=nil},
    {id="Legends", name="Legends", v=2.5},
    {id="MuscleKing", name="MuscleKing", v=12.5},
    {id="AncientJungle", name="AncientJungle", v=16.25},
    {id="Inferno", name="Inferno", v=1.125},
    {id="Mystic", name="Mystic", v=.75},
    {id="Frozen", name="Frozen", v=.375},
    {id="Golden", name="Golden", v=.2},
    {id="Large", name="Large", v=.075},
    {id="Punching", name="Punching", v=.05},
    {id="Tiny", name="Tiny", v=.025},
}

local RAR_ORDER = {"Unique","Epic","Rare","Uncommon","Basic"}
local ROCK_ORDER = {
    {id="Legends", v=2.5},
    {id="MuscleKing", v=12.5},
    {id="AncientJungle", v=16.25},
    {id="Inferno", v=1.125},
    {id="Mystic", v=.75},
    {id="Frozen", v=.375},
    {id="Golden", v=.2},
    {id="Large", v=.075},
    {id="Punching", v=.05},
    {id="Tiny", v=.025},
}

local function round(n) return math.floor(n + 0.5) end
local function whole(n) return math.abs(n - round(n)) < 1e-7 end
local function cum(base,lvl) return base * lvl * (lvl + 1) / 2 end
local function totalFrom(base,lvl,xp) return cum(base,lvl - 1) + xp end

local function fmt(n)
    n = tonumber(n) or 0
    return tostring(math.floor(n + 0.5))
end

local function levelFromTotal(base,total)
    if total <= 0 then return 1,0 end

    local prev = 0
    for lvl = 1,19 do
        local cap = cum(base,lvl)

        if total < cap then
            return lvl, total - prev
        end

        if total == cap then
            return lvl, base * lvl
        end

        prev = cap
    end

    return 20,0
end

local function parseNum(s)
    s = tostring(s or ""):lower():gsub("%s+",""):gsub(",",".")
    local n = tonumber(s:match("([%d%.]+)") or "")
    if not n then return nil end

    local suf = s:match("[kmbtкмбт]") or ""
    local mult = {
        k=1e3, ["к"]=1e3,
        m=1e6, ["м"]=1e6,
        b=1e9, ["б"]=1e9,
        t=1e12, ["т"]=1e12,
    }

    return round(n * (mult[suf] or 1))
end

local function bestForHit(hit,rarity,rockName)
    if not whole(hit) then return nil end

    local base = BASE[rarity]
    local stat = STAT[rarity]
    hit = round(hit)

    local best = nil

    for endLvl = 1,19 do
        local cap = cum(base,endLvl)
        local startTotal = cap - hit

        if startTotal >= 0 then
            local setLvl,setXp = levelFromTotal(base,startTotal)
            local crossed = endLvl - setLvl + 1

            if crossed >= 1 then
                local cand = {
                    rarity = rarity,
                    rock = rockName,
                    hit = hit,
                    setLvl = setLvl,
                    setXp = setXp,
                    startTotal = startTotal,
                    capLvl = endLvl,
                    bonus = crossed * stat,
                    crossed = crossed,
                }

                if not best
                or cand.bonus > best.bonus
                or (cand.bonus == best.bonus and cand.startTotal < best.startTotal) then
                    best = cand
                end
            end
        end
    end

    return best
end

local function makeSuggestions(reb,rarityFilter,rockFilter)
    local list = {}

    for _,rarity in ipairs(RAR_ORDER) do
        if rarityFilter == "Auto" or rarityFilter == rarity then
            for _,rock in ipairs(ROCK_ORDER) do
                if rockFilter == "Auto" or rockFilter == rock.id then
                    local hit = (reb + 20) * rock.v
                    local cand = bestForHit(hit,rarity,rock.id)

                    if cand then
                        table.insert(list,cand)
                    end
                end
            end
        end
    end

    table.sort(list,function(a,b)
        if a.bonus ~= b.bonus then return a.bonus > b.bonus end
        if STAT[a.rarity] ~= STAT[b.rarity] then return STAT[a.rarity] > STAT[b.rarity] end
        if a.hit ~= b.hit then return a.hit > b.hit end
        return a.startTotal < b.startTotal
    end)

    return list
end

local function treadmillPlan(diff)
    diff = round(diff)

    if diff < 0 then
        return "ПЕРЕКАЧАНО на "..fmt(math.abs(diff)).." XP. Жми Next или бери другого пета."
    end

    if diff == 0 then
        return "Уже ровно. Камень можно бить."
    end

    local parts = {}

    for g = 6,1,-1 do
        local count = math.floor(diff / g)

        if count > 0 then
            table.insert(parts,"+"..g.."×"..count)
            diff = diff - count * g
        end
    end

    return table.concat(parts,"  ")
end

local function safeDetectRebirths()
    if _G.PetAPI and _G.PetAPI.GetRebirths then
        local ok,res = pcall(_G.PetAPI.GetRebirths)
        if ok and tonumber(res) then return round(tonumber(res)) end
    end

    if _G.Rebirths and tonumber(_G.Rebirths) then
        return round(tonumber(_G.Rebirths))
    end

    local ls = lp:FindFirstChild("leaderstats")
    if ls then
        for _,v in ipairs(ls:GetChildren()) do
            local n = v.Name:lower()

            if n == "rebirths" or n == "rebirth" or n == "rebs" or n == "reb" or n == "перерождения" then
                if v:IsA("IntValue") or v:IsA("NumberValue") then
                    return round(v.Value)
                end

                if v:IsA("StringValue") then
                    return parseNum(v.Value)
                end
            end
        end
    end

    return nil
end

local function selectedPet()
    if _G.PetAPI and _G.PetAPI.GetSelectedPet then
        local ok,res = pcall(_G.PetAPI.GetSelectedPet)
        if ok then return res end
    end

    if _G.SelectedPet then return _G.SelectedPet end
    if _G.Pet then return _G.Pet end

    return nil
end

local function readNumber(obj,names)
    if not obj then return nil end

    if type(obj) == "table" then
        for _,name in ipairs(names) do
            if tonumber(obj[name]) then return tonumber(obj[name]) end
        end
    end

    if typeof(obj) == "Instance" then
        for _,name in ipairs(names) do
            local v = obj:FindFirstChild(name,true)

            if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
                return v.Value
            end
        end
    end

    return nil
end

local function setNumber(obj,names,value)
    if not obj then return false end

    if type(obj) == "table" then
        obj[names[1]] = value
        return true
    end

    if typeof(obj) == "Instance" then
        for _,name in ipairs(names) do
            local v = obj:FindFirstChild(name,true)

            if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
                v.Value = value
                return true
            end
        end
    end

    return false
end

local function petCurrentTotal(rarity,manualLvl,manualXp)
    local pet = selectedPet()

    if pet then
        local total = readNumber(pet,{"TotalXP","TotalExp","totalXP","totalExp"})
        if total then return total end

        local lvl = readNumber(pet,{"Level","Lvl","level","lvl"}) or manualLvl
        local xp = readNumber(pet,{"XP","Exp","Experience","xp"}) or manualXp

        return totalFrom(BASE[rarity],lvl,xp)
    end

    return totalFrom(BASE[rarity],manualLvl,manualXp)
end

-- UI

local gui = Instance.new("ScreenGui")
gui.Name = "PetAlignHubV4"
gui.ResetOnSpawn = false
gui.Parent = lp:WaitForChild("PlayerGui")

local frame = Instance.new("Frame",gui)
frame.Size = UDim2.new(0,410,0,430)
frame.Position = UDim2.new(0.5,-205,0.5,-215)
frame.BackgroundColor3 = Color3.fromRGB(14,13,30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner",frame).CornerRadius = UDim.new(0,16)

local stroke = Instance.new("UIStroke",frame)
stroke.Color = Color3.fromRGB(120,70,210)
stroke.Thickness = 1.5

local title = Instance.new("TextLabel",frame)
title.Size = UDim2.new(1,-56,0,40)
title.Position = UDim2.new(0,14,0,8)
title.BackgroundTransparency = 1
title.Text = "Pet Align Hub v4"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton",frame)
close.Size = UDim2.new(0,36,0,36)
close.Position = UDim2.new(1,-46,0,8)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255,180,190)
close.BackgroundColor3 = Color3.fromRGB(64,20,34)
close.Font = Enum.Font.GothamBlack
close.TextSize = 20
Instance.new("UICorner",close).CornerRadius = UDim.new(0,12)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local function label(text,x,y,w)
    local l = Instance.new("TextLabel",frame)
    l.Size = UDim2.new(0,w or 120,0,20)
    l.Position = UDim2.new(0,x,0,y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(205,195,255)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local function box(x,y,w,text)
    local b = Instance.new("TextBox",frame)
    b.Size = UDim2.new(0,w,0,34)
    b.Position = UDim2.new(0,x,0,y)
    b.Text = text or ""
    b.ClearTextOnFocus = false
    b.TextColor3 = Color3.new(1,1,1)
    b.PlaceholderColor3 = Color3.fromRGB(150,140,185)
    b.BackgroundColor3 = Color3.fromRGB(31,29,61)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,10)
    return b
end

local function button(x,y,w,text,color)
    local b = Instance.new("TextButton",frame)
    b.Size = UDim2.new(0,w,0,34)
    b.Position = UDim2.new(0,x,0,y)
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.BackgroundColor3 = color or Color3.fromRGB(62,50,120)
    b.Font = Enum.Font.GothamBlack
    b.TextSize = 13
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,10)
    return b
end

label("Rebirths",14,56)
local rebBox = box(14,78,130,"")
rebBox.PlaceholderText = "впиши ребы"

local readBtn = button(152,78,78,"Read",Color3.fromRGB(105,55,210))

label("Pet rarity",246,56)
local rarityBtn = button(246,78,150,"Auto",Color3.fromRGB(62,50,120))

label("Rock",14,120)
local rockBtn = button(14,142,180,"Auto",Color3.fromRGB(62,50,120))

label("Current pet lvl / XP",214,120)
local lvlBox = box(214,142,70,"1")
local xpBox = box(292,142,104,"0")

local status = Instance.new("TextLabel",frame)
status.Size = UDim2.new(1,-28,0,28)
status.Position = UDim2.new(0,14,0,184)
status.BackgroundColor3 = Color3.fromRGB(24,21,48)
status.TextColor3 = Color3.fromRGB(255,226,122)
status.Font = Enum.Font.GothamBlack
status.TextSize = 13
status.Text = "Впиши ребы — лучший вариант появится сам"
Instance.new("UICorner",status).CornerRadius = UDim.new(0,9)

local out = Instance.new("TextLabel",frame)
out.Size = UDim2.new(1,-28,0,142)
out.Position = UDim2.new(0,14,0,220)
out.BackgroundColor3 = Color3.fromRGB(8,8,21)
out.TextColor3 = Color3.fromRGB(255,238,170)
out.Font = Enum.Font.GothamBold
out.TextSize = 13
out.TextWrapped = true
out.TextYAlignment = Enum.TextYAlignment.Top
out.TextXAlignment = Enum.TextXAlignment.Left
out.Text = "Инструкция:\n1) Впиши ребы.\n2) Выбери редкость/камень или оставь Auto.\n3) Впиши текущий lvl/XP пета.\n4) Выполни план дорожек и бей камень."
Instance.new("UICorner",out).CornerRadius = UDim.new(0,12)

local prevBtn = button(14,378,70,"Prev",Color3.fromRGB(60,58,112))
local nextBtn = button(92,378,70,"Next",Color3.fromRGB(60,58,112))
local copyBtn = button(170,378,74,"Copy",Color3.fromRGB(45,100,180))
local helpBtn = button(252,378,70,"Help",Color3.fromRGB(45,100,180))
local applyBtn = button(330,378,66,"Set",Color3.fromRGB(30,135,80))

local rarityIndex = 1
local rockIndex = 1
local list = {}
local index = 1
local last = nil
local calculating = false

local function rarityFilter()
    return RARITIES[rarityIndex].id
end

local function rockFilter()
    return ROCKS[rockIndex].id
end

local function setStatus(text)
    status.Text = text
end

local function render()
    if calculating then return end
    calculating = true

    local reb = parseNum(rebBox.Text)
    local manualLvl = tonumber(lvlBox.Text) or 1
    local manualXp = tonumber(xpBox.Text) or 0

    if not reb then
        list = {}
        last = nil
        setStatus("Впиши ребы — например 45164 или 45k")
        out.Text = "Инструкция:\n1) Впиши ребы.\n2) Выбери редкость/камень или оставь Auto.\n3) Впиши текущий lvl/XP пета.\n4) Выполни план дорожек и бей камень."
        calculating = false
        return
    end

    list = makeSuggestions(reb,rarityFilter(),rockFilter())

    if #list == 0 then
        last = nil
        setStatus("Нет точной математической точки")
        out.Text = "На этих ребах с выбранными фильтрами нет точного варианта.\n\nПопробуй Rock = Auto или Pet = Auto."
        calculating = false
        return
    end

    if index > #list then index = 1 end
    if index < 1 then index = #list end

    local s = list[index]
    last = s

    local currentTotal = petCurrentTotal(s.rarity,manualLvl,manualXp)
    local diff = s.startTotal - currentTotal
    local plan = treadmillPlan(diff)

    setStatus(("Лучший #%s/%s • %s • %s • +%s"):format(index,#list,s.rarity,s.rock,s.bonus))

    local text = ""
    text = text .. ("✅ ЛУЧШИЙ ВАРИАНТ\n")
    text = text .. ("Пет: %s\n"):format(s.rarity)
    text = text .. ("Камень: %s\n"):format(s.rock)
    text = text .. ("Поставь: %s lvl, %s XP\n\n"):format(fmt(s.setLvl),fmt(s.setXp))
    text = text .. ("ДОРОЖКИ:\n%s\n\n"):format(plan)
    text = text .. ("ПОТОМ:\n1) остановись ровно на точке\n2) ударь %s\n3) проверь статы питомца\n\n"):format(s.rock)
    text = text .. ("Hit: %s XP | cap lvl: %s | бонус: +%s"):format(fmt(s.hit),fmt(s.capLvl),fmt(s.bonus))

    out.Text = text

    calculating = false
end

local function cycleRarity()
    rarityIndex = rarityIndex + 1
    if rarityIndex > #RARITIES then rarityIndex = 1 end
    rarityBtn.Text = RARITIES[rarityIndex].name:gsub("Пет: ","")
    index = 1
    render()
end

local function cycleRock()
    rockIndex = rockIndex + 1
    if rockIndex > #ROCKS then rockIndex = 1 end
    rockBtn.Text = ROCKS[rockIndex].name:gsub("Камень: ","")
    index = 1
    render()
end

rarityBtn.MouseButton1Click:Connect(cycleRarity)
rockBtn.MouseButton1Click:Connect(cycleRock)

rebBox:GetPropertyChangedSignal("Text"):Connect(function()
    index = 1
    render()
end)

lvlBox:GetPropertyChangedSignal("Text"):Connect(render)
xpBox:GetPropertyChangedSignal("Text"):Connect(render)

readBtn.MouseButton1Click:Connect(function()
    local r = safeDetectRebirths()

    if r then
        rebBox.Text = tostring(r)
    else
        setStatus("Read не нашёл ребы. Впиши вручную.")
    end

    render()
end)

prevBtn.MouseButton1Click:Connect(function()
    if #list == 0 then render() return end
    index = index - 1
    render()
end)

nextBtn.MouseButton1Click:Connect(function()
    if #list == 0 then render() return end
    index = index + 1
    render()
end)

copyBtn.MouseButton1Click:Connect(function()
    if not last then render() end

    if last and setclipboard then
        setclipboard(
            ("Pet=%s | Rock=%s | Set=%s lvl, %s XP | Hit=%s | Bonus=+%s")
            :format(last.rarity,last.rock,fmt(last.setLvl),fmt(last.setXp),fmt(last.hit),fmt(last.bonus))
        )

        setStatus("Скопировано")
    end
end)

helpBtn.MouseButton1Click:Connect(function()
    out.Text =
[[ИНСТРУКЦИЯ

Rebirths — твои ребы.
Pet rarity — редкость пета. Auto сам выберет лучший.
Rock — камень. Auto сам выберет лучший.
Current pet lvl/XP — текущий уровень и опыт пета.

Скрипт сам считает:
1) какого пета брать
2) какой камень бить
3) до какого lvl/XP ровнять
4) какие дорожки нажать

Если пишет “перекачано” — этот пет уже выше точки. Жми Next.]]
end)

applyBtn.MouseButton1Click:Connect(function()
    if not last then render() end
    if not last then return end

    local pet = selectedPet()

    if _G.PetAPI and _G.PetAPI.SetPetXP then
        _G.PetAPI.SetPetXP(pet,last.setLvl,last.setXp,last.startTotal)
        setStatus("Set через PetAPI")
        return
    end

    if not pet then
        setStatus("Set: пет не выбран. Это необязательно.")
        return
    end

    local a = setNumber(pet,{"Level","Lvl","level","lvl"},last.setLvl)
    local b = setNumber(pet,{"XP","Exp","Experience","xp"},last.setXp)
    local c = setNumber(pet,{"TotalXP","TotalExp","totalXP"},last.startTotal)

    if a or b or c then
        setStatus("Set применён")
    else
        setStatus("Set не нашёл Level/XP")
    end
end)

render()
