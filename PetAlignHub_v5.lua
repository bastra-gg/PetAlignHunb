-- PetAlignHub v5
-- Почти как HTML-прога: настройки слева, результаты карточками справа, инструкция снизу.
-- Для твоей тестовой сборки. Не вызывает remotes, Apply работает только через _G.PetAPI / _G.SelectedPet.

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local RARITIES = {
	{id="Basic", label="Базовый", base=250, stat=1},
	{id="Uncommon", label="Необычный", base=500, stat=2},
	{id="Rare", label="Редкий", base=750, stat=3},
	{id="Epic", label="Эпический", base=1000, stat=4},
	{id="Unique", label="Уникальный", base=1250, stat=5},
}

local RAR_ORDER = {"Unique","Epic","Rare","Uncommon","Basic"}

local ROCKS = {
	{id="AncientJungle", label="Древний лес", value=16.25},
	{id="MuscleKing", label="Король мышц", value=12.5},
	{id="Legends", label="Легенды", value=2.5},
	{id="Inferno", label="Инферно", value=1.125},
	{id="Mystic", label="Мистический", value=.75},
	{id="Frozen", label="Ледяной", value=.375},
	{id="Golden", label="Золотой", value=.2},
	{id="Large", label="Большой", value=.075},
	{id="Punching", label="Груша", value=.05},
	{id="Tiny", label="Малый", value=.025},
}

local rarityData = {}
for _,r in ipairs(RARITIES) do rarityData[r.id] = r end

local rockData = {}
for _,r in ipairs(ROCKS) do rockData[r.id] = r end

local function round(n)
	return math.floor((tonumber(n) or 0) + 0.5)
end

local function whole(n)
	return math.abs((tonumber(n) or 0) - round(n)) < 1e-7
end

local function fmt(n)
	n = round(n)
	local s = tostring(n)
	local left,num,right = string.match(s,'^([^%d]*%d)(%d*)(.-)$')
	if not left then return s end
	return left .. (num:reverse():gsub("(%d%d%d)","%1 "):reverse()) .. right
end

local function cum(base,lvl)
	return base * lvl * (lvl + 1) / 2
end

local function totalFrom(base,lvl,xp)
	return cum(base,lvl - 1) + xp
end

local function levelCap(base,lvl)
	return base * lvl
end

local function levelFromTotal(base,total)
	if total <= 0 then return 1,0 end

	local prev = 0
	for lvl = 1,19 do
		local cap = cum(base,lvl)

		if total < cap then
			return lvl,total - prev
		end

		if total == cap then
			return lvl,base * lvl
		end

		prev = cap
	end

	return 20,0
end

local function parseNum(s)
	s = tostring(s or ""):lower()
	s = s:gsub("%s+",""):gsub(",",".")
	s = s:gsub("ребиртов",""):gsub("ребов",""):gsub("реб","")

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

local function readNumber(obj,names)
	if not obj then return nil end

	if type(obj) == "table" then
		for _,name in ipairs(names) do
			local v = obj[name]
			if tonumber(v) then return tonumber(v) end
		end
	end

	if typeof(obj) == "Instance" then
		for _,name in ipairs(names) do
			local v = obj:FindFirstChild(name,true)

			if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
				return v.Value
			end

			if v and v:IsA("StringValue") then
				return parseNum(v.Value)
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

local function selectedPet()
	if _G.PetAPI and _G.PetAPI.GetSelectedPet then
		local ok,res = pcall(_G.PetAPI.GetSelectedPet)
		if ok then return res end
	end

	if _G.SelectedPet then return _G.SelectedPet end
	if _G.Pet then return _G.Pet end

	return nil
end

local function detectRebirths()
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
			if n:find("reb") or n:find("перер") or n == "ребы" then
				if v:IsA("IntValue") or v:IsA("NumberValue") then return round(v.Value) end
				if v:IsA("StringValue") then return parseNum(v.Value) end
			end
		end
	end

	return nil
end

local function currentPetTotal(rarity,manualLvl,manualXp)
	local pet = selectedPet()
	local base = rarityData[rarity].base

	if pet then
		local total = readNumber(pet,{"TotalXP","TotalExp","totalXP","totalExp"})
		if total then return total end

		local lvl = readNumber(pet,{"Level","Lvl","level","lvl"}) or manualLvl
		local xp = readNumber(pet,{"XP","Exp","Experience","xp"}) or manualXp
		return totalFrom(base,lvl,xp)
	end

	return totalFrom(base,manualLvl,manualXp)
end

local function bestGlitch(rawHit,rarityId,rockId)
	if not whole(rawHit) then return nil end

	local r = rarityData[rarityId]
	local hit = round(rawHit)
	local best = nil

	for endLvl = 1,19 do
		local endTotal = cum(r.base,endLvl)
		local startTotal = endTotal - hit

		if startTotal >= 0 then
			local startLvl,startXp = levelFromTotal(r.base,startTotal)
			local crossed = endLvl - startLvl + 1

			if crossed >= 1 then
				local cand = {
					rarity = rarityId,
					rarityLabel = r.label,
					rock = rockId,
					rockLabel = rockData[rockId].label,
					hit = hit,
					setLvl = startLvl,
					setXp = startXp,
					startTotal = startTotal,
					capLvl = endLvl,
					bonus = crossed * r.stat,
					crossed = crossed,
					left = levelCap(r.base,startLvl) - startXp,
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

local function getSuggestions(rebirths,rarityFilter,rockFilter)
	local list = {}

	for _,rarity in ipairs(RAR_ORDER) do
		if rarityFilter == "Auto" or rarityFilter == rarity then
			for _,rock in ipairs(ROCKS) do
				if rockFilter == "Auto" or rockFilter == rock.id then
					local rawHit = (rebirths + 20) * rock.value
					local cand = bestGlitch(rawHit,rarity,rock.id)

					if cand then
						table.insert(list,cand)
					end
				end
			end
		end
	end

	table.sort(list,function(a,b)
		if a.bonus ~= b.bonus then return a.bonus > b.bonus end
		if rarityData[a.rarity].stat ~= rarityData[b.rarity].stat then
			return rarityData[a.rarity].stat > rarityData[b.rarity].stat
		end
		if a.hit ~= b.hit then return a.hit > b.hit end
		return a.startTotal < b.startTotal
	end)

	return list
end

local function treadmillPlan(diff)
	diff = round(diff)

	if diff < 0 then
		return "ПЕРЕКАЧАНО на "..fmt(math.abs(diff)).." XP. Жми другую карточку/Next."
	end

	if diff == 0 then
		return "Уже ровно. Бей камень."
	end

	local parts = {}
	for g = 6,1,-1 do
		local count = math.floor(diff / g)

		if count > 0 then
			table.insert(parts,"дорожка +"..g.." × "..count)
			diff = diff - count * g
		end
	end

	return table.concat(parts,"\n")
end

-- UI helpers

local gui = Instance.new("ScreenGui")
gui.Name = "PetAlignHubV5"
gui.ResetOnSpawn = false
gui.Parent = lp:WaitForChild("PlayerGui")

local frame = Instance.new("Frame",gui)
frame.Size = UDim2.new(0,650,0,430)
frame.Position = UDim2.new(0.5,-325,0.5,-215)
frame.BackgroundColor3 = Color3.fromRGB(12,11,26)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner",frame).CornerRadius = UDim.new(0,18)

local stroke = Instance.new("UIStroke",frame)
stroke.Color = Color3.fromRGB(132,70,255)
stroke.Thickness = 1.6

local title = Instance.new("TextLabel",frame)
title.Size = UDim2.new(1,-60,0,40)
title.Position = UDim2.new(0,16,0,8)
title.BackgroundTransparency = 1
title.Text = "Калькулятор багов • Script Edition"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton",frame)
close.Size = UDim2.new(0,36,0,36)
close.Position = UDim2.new(1,-48,0,8)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255,180,190)
close.BackgroundColor3 = Color3.fromRGB(62,20,34)
close.Font = Enum.Font.GothamBlack
close.TextSize = 20
Instance.new("UICorner",close).CornerRadius = UDim.new(0,12)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local left = Instance.new("Frame",frame)
left.Size = UDim2.new(0,245,0,360)
left.Position = UDim2.new(0,14,0,56)
left.BackgroundColor3 = Color3.fromRGB(17,16,36)
left.BorderSizePixel = 0
Instance.new("UICorner",left).CornerRadius = UDim.new(0,15)

local right = Instance.new("Frame",frame)
right.Size = UDim2.new(1,-280,0,360)
right.Position = UDim2.new(0,270,0,56)
right.BackgroundColor3 = Color3.fromRGB(17,16,36)
right.BorderSizePixel = 0
Instance.new("UICorner",right).CornerRadius = UDim.new(0,15)

local function makeLabel(parent,text,x,y,w)
	local l = Instance.new("TextLabel",parent)
	l.Size = UDim2.new(0,w or 200,0,18)
	l.Position = UDim2.new(0,x,0,y)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromRGB(205,195,255)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 12
	l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

local function makeBox(parent,x,y,w,text,placeholder)
	local b = Instance.new("TextBox",parent)
	b.Size = UDim2.new(0,w,0,34)
	b.Position = UDim2.new(0,x,0,y)
	b.Text = text or ""
	b.PlaceholderText = placeholder or ""
	b.ClearTextOnFocus = false
	b.TextColor3 = Color3.new(1,1,1)
	b.PlaceholderColor3 = Color3.fromRGB(155,145,190)
	b.BackgroundColor3 = Color3.fromRGB(31,29,61)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	Instance.new("UICorner",b).CornerRadius = UDim.new(0,10)
	return b
end

local function makeButton(parent,x,y,w,text,color)
	local b = Instance.new("TextButton",parent)
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

makeLabel(left,"Перерождения",14,14)
local rebBox = makeBox(left,14,35,135,"","45164")
local readBtn = makeButton(left,158,35,72,"Read",Color3.fromRGB(105,55,210))

makeLabel(left,"Редкость питомца",14,80)
local rarityBtn = makeButton(left,14,101,216,"Auto",Color3.fromRGB(56,45,108))

makeLabel(left,"Камень",14,146)
local rockBtn = makeButton(left,14,167,216,"Auto",Color3.fromRGB(56,45,108))

makeLabel(left,"Текущий pet lvl / XP",14,212)
local lvlBox = makeBox(left,14,233,80,"1","lvl")
local xpBox = makeBox(left,102,233,128,"0","xp")

local warn = Instance.new("TextLabel",left)
warn.Size = UDim2.new(1,-28,0,72)
warn.Position = UDim2.new(0,14,0,278)
warn.BackgroundColor3 = Color3.fromRGB(25,22,45)
warn.TextColor3 = Color3.fromRGB(255,226,122)
warn.Font = Enum.Font.GothamBold
warn.TextSize = 11
warn.TextWrapped = true
warn.TextYAlignment = Enum.TextYAlignment.Top
warn.Text = "Примечание: это математика XP. Реальный баг проверяй по статам питомца, не только по lvl/XP."
Instance.new("UICorner",warn).CornerRadius = UDim.new(0,11)

local resTitle = Instance.new("TextLabel",right)
resTitle.Size = UDim2.new(1,-24,0,28)
resTitle.Position = UDim2.new(0,12,0,8)
resTitle.BackgroundTransparency = 1
resTitle.Text = "Результаты"
resTitle.TextColor3 = Color3.new(1,1,1)
resTitle.Font = Enum.Font.GothamBlack
resTitle.TextSize = 18
resTitle.TextXAlignment = Enum.TextXAlignment.Left

local mini = Instance.new("TextLabel",right)
mini.Size = UDim2.new(0,190,0,24)
mini.Position = UDim2.new(1,-202,0,11)
mini.BackgroundTransparency = 1
mini.Text = "введи ребы"
mini.TextColor3 = Color3.fromRGB(155,150,180)
mini.Font = Enum.Font.GothamBold
mini.TextSize = 11
mini.TextXAlignment = Enum.TextXAlignment.Right

local scroll = Instance.new("ScrollingFrame",right)
scroll.Size = UDim2.new(1,-24,0,202)
scroll.Position = UDim2.new(0,12,0,43)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0,0,0,0)

local listLayout = Instance.new("UIListLayout",scroll)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0,8)

local inst = Instance.new("TextLabel",right)
inst.Size = UDim2.new(1,-24,0,94)
inst.Position = UDim2.new(0,12,1,-104)
inst.BackgroundColor3 = Color3.fromRGB(8,8,21)
inst.TextColor3 = Color3.fromRGB(255,238,170)
inst.Font = Enum.Font.GothamBold
inst.TextSize = 12
inst.TextWrapped = true
inst.TextYAlignment = Enum.TextYAlignment.Top
inst.TextXAlignment = Enum.TextXAlignment.Left
inst.Text = "Инструкция появится после ввода ребов."
Instance.new("UICorner",inst).CornerRadius = UDim.new(0,12)

local rarityChoices = {"Auto","Unique","Epic","Rare","Uncommon","Basic"}
local rarityIndex = 1

local rockChoices = {"Auto","Legends","MuscleKing","AncientJungle","Inferno","Mystic","Frozen","Golden","Large","Punching","Tiny"}
local rockIndex = 1

local suggestions = {}
local chosen = nil
local busy = false

local function currentRarity()
	return rarityChoices[rarityIndex]
end

local function currentRock()
	return rockChoices[rockIndex]
end

local function updateInstruction(s)
	if not s then
		inst.Text = "Инструкция:\n1) Впиши ребы.\n2) Оставь Auto или выбери pet/камень.\n3) Впиши текущий lvl/XP пета.\n4) Нажми карточку результата."
		return
	end

	local manualLvl = tonumber(lvlBox.Text) or 1
	local manualXp = tonumber(xpBox.Text) or 0
	local nowTotal = currentPetTotal(s.rarity,manualLvl,manualXp)
	local plan = treadmillPlan(s.startTotal - nowTotal)

	inst.Text =
		"ИНСТРУКЦИЯ\n" ..
		"1) Возьми pet: "..s.rarityLabel.."\n" ..
		"2) Выставь: "..fmt(s.setLvl).." lvl, "..fmt(s.setXp).." XP\n" ..
		"3) Дорожки:\n"..plan.."\n" ..
		"4) Ударь: "..s.rockLabel.." камень\n" ..
		"5) Проверь статы. Ожидание: +"..fmt(s.bonus)
end

local function clearCards()
	for _,v in ipairs(scroll:GetChildren()) do
		if v:IsA("TextButton") then v:Destroy() end
	end
end

local function makeCard(s,i)
	local card = Instance.new("TextButton",scroll)
	card.Size = UDim2.new(1,-4,0,74)
	card.BackgroundColor3 = i == 1 and Color3.fromRGB(18,45,35) or Color3.fromRGB(20,20,43)
	card.BorderSizePixel = 0
	card.AutoButtonColor = true
	card.Text = ""
	card.LayoutOrder = i
	Instance.new("UICorner",card).CornerRadius = UDim.new(0,13)

	local st = Instance.new("UIStroke",card)
	st.Color = i == 1 and Color3.fromRGB(86,255,154) or Color3.fromRGB(80,65,125)
	st.Thickness = i == 1 and 2 or 1

	local name = Instance.new("TextLabel",card)
	name.Size = UDim2.new(1,-92,0,24)
	name.Position = UDim2.new(0,12,0,8)
	name.BackgroundTransparency = 1
	name.Text = s.rarityLabel.." • "..s.rockLabel
	name.TextColor3 = Color3.new(1,1,1)
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 14
	name.TextXAlignment = Enum.TextXAlignment.Left

	local set = Instance.new("TextLabel",card)
	set.Size = UDim2.new(1,-92,0,22)
	set.Position = UDim2.new(0,12,0,36)
	set.BackgroundTransparency = 1
	set.Text = "Поставь: "..fmt(s.setLvl).." lvl, "..fmt(s.setXp).." XP"
	set.TextColor3 = Color3.fromRGB(255,226,122)
	set.Font = Enum.Font.GothamBold
	set.TextSize = 12
	set.TextXAlignment = Enum.TextXAlignment.Left

	local bonus = Instance.new("TextLabel",card)
	bonus.Size = UDim2.new(0,74,0,48)
	bonus.Position = UDim2.new(1,-82,0,13)
	bonus.BackgroundColor3 = Color3.fromRGB(12,26,22)
	bonus.Text = "+"..fmt(s.bonus).."\nстат"
	bonus.TextColor3 = Color3.fromRGB(86,255,154)
	bonus.Font = Enum.Font.GothamBlack
	bonus.TextSize = 14
	Instance.new("UICorner",bonus).CornerRadius = UDim.new(0,10)

	card.MouseButton1Click:Connect(function()
		chosen = s
		updateInstruction(s)
	end)
end

local function recalc()
	if busy then return end
	busy = true

	local reb = parseNum(rebBox.Text)

	clearCards()

	if not reb then
		suggestions = {}
		chosen = nil
		mini.Text = "введи ребы"
		updateInstruction(nil)
		busy = false
		return
	end

	suggestions = getSuggestions(reb,currentRarity(),currentRock())
	mini.Text = tostring(#suggestions).." вариантов • "..fmt(reb).." ребов"

	if #suggestions == 0 then
		chosen = nil
		inst.Text = "Нет точных вариантов под выбранные фильтры.\nПоставь Pet = Auto и Rock = Auto."
		busy = false
		return
	end

	for i = 1,math.min(#suggestions,12) do
		makeCard(suggestions[i],i)
	end

	scroll.CanvasSize = UDim2.new(0,0,0,math.min(#suggestions,12) * 82)

	chosen = suggestions[1]
	updateInstruction(chosen)

	busy = false
end

rarityBtn.MouseButton1Click:Connect(function()
	rarityIndex = rarityIndex + 1
	if rarityIndex > #rarityChoices then rarityIndex = 1 end
	rarityBtn.Text = rarityChoices[rarityIndex]
	recalc()
end)

rockBtn.MouseButton1Click:Connect(function()
	rockIndex = rockIndex + 1
	if rockIndex > #rockChoices then rockIndex = 1 end
	rockBtn.Text = rockChoices[rockIndex]
	recalc()
end)

readBtn.MouseButton1Click:Connect(function()
	local d = detectRebirths()
	if d then
		rebBox.Text = tostring(d)
	else
		mini.Text = "Read не нашёл ребы"
	end
	recalc()
end)

rebBox:GetPropertyChangedSignal("Text"):Connect(recalc)
lvlBox:GetPropertyChangedSignal("Text"):Connect(function()
	if chosen then updateInstruction(chosen) end
end)
xpBox:GetPropertyChangedSignal("Text"):Connect(function()
	if chosen then updateInstruction(chosen) end
end)

local d = detectRebirths()
if d then rebBox.Text = tostring(d) end
recalc()
