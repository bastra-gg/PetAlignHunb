-- PetAlignHub v3
-- app-style calculator for your private/test build
local Players=game:GetService("Players")
local lp=Players.LocalPlayer

local BASE={Basic=250,Uncommon=500,Rare=750,Epic=1000,Unique=1250}
local STAT={Basic=1,Uncommon=2,Rare=3,Epic=4,Unique=5}
local RAR={"Unique","Epic","Rare","Uncommon","Basic"}
local ROCKS={
	{name="Legends",v=2.5},
	{name="MuscleKing",v=12.5},
	{name="AncientJungle",v=16.25},
	{name="Inferno",v=1.125},
	{name="Mystic",v=.75},
	{name="Frozen",v=.375},
	{name="Golden",v=.2},
	{name="Large",v=.075},
	{name="Punching",v=.05},
	{name="Tiny",v=.025},
}

local function round(n)return math.floor(n+.5)end
local function whole(n)return math.abs(n-round(n))<1e-7 end
local function cum(base,lvl)return base*lvl*(lvl+1)/2 end
local function totalFrom(base,lvl,xp)return cum(base,lvl-1)+xp end

local function levelFromTotal(base,total)
	if total<=0 then return 1,0 end
	local prev=0
	for lvl=1,19 do
		local cap=cum(base,lvl)
		if total<cap then return lvl,total-prev end
		if total==cap then return lvl,base*lvl end
		prev=cap
	end
	return 20,0
end

local function parseNum(s)
	s=tostring(s or ""):lower():gsub("%s+",""):gsub(",",".")
	local n=tonumber(s:match("([%d%.]+)") or "")
	if not n then return nil end
	local suf=s:match("[kmbtкмбт]") or ""
	local mult={k=1e3,["к"]=1e3,m=1e6,["м"]=1e6,b=1e9,["б"]=1e9,t=1e12,["т"]=1e12}
	return round(n*(mult[suf] or 1))
end

local function readNumber(obj,names)
	if not obj then return nil end
	if type(obj)=="table" then
		for _,n in ipairs(names)do if tonumber(obj[n])then return tonumber(obj[n])end end
		return nil
	end
	if typeof(obj)=="Instance" then
		for _,n in ipairs(names)do
			local v=obj:FindFirstChild(n,true)
			if v and (v:IsA("IntValue")or v:IsA("NumberValue"))then return v.Value end
			if v and v:IsA("StringValue")then return parseNum(v.Value)end
		end
	end
	return nil
end

local function setNumber(obj,names,value)
	if not obj then return false end
	if type(obj)=="table" then for _,n in ipairs(names)do obj[n]=value return true end end
	if typeof(obj)=="Instance" then
		for _,n in ipairs(names)do
			local v=obj:FindFirstChild(n,true)
			if v and (v:IsA("IntValue")or v:IsA("NumberValue"))then v.Value=value return true end
		end
	end
	return false
end

local function detectRebirths()
	local direct=readNumber(lp,{"Rebirths","Rebirth","rebirths","rebirth","Перерождения","Перерождение"})
	if direct and direct>0 then return round(direct)end
	local ls=lp:FindFirstChild("leaderstats")
	if ls then
		for _,v in ipairs(ls:GetChildren())do
			local n=v.Name:lower()
			if n:find("reb")or n:find("перер")then
				local num=(v:IsA("IntValue")or v:IsA("NumberValue"))and v.Value or parseNum(v.Value)
				if num then return round(num)end
			end
		end
	end
	for _,v in ipairs(lp:GetDescendants())do
		if v:IsA("IntValue")or v:IsA("NumberValue")then
			local n=v.Name:lower()
			if n:find("rebirth")or n=="reb"or n:find("перер")then return round(v.Value)end
		end
	end
	return nil
end

local function selectedPet()
	if _G.PetAPI and _G.PetAPI.GetSelectedPet then return _G.PetAPI.GetSelectedPet()end
	if _G.SelectedPet then return _G.SelectedPet end
	if _G.Pet then return _G.Pet end
	return nil
end

local function petTotal(pet,rarity)
	local base=BASE[rarity]
	local total=readNumber(pet,{"TotalXP","TotalExp","totalXP","totalExp"})
	if total then return total end
	local lvl=readNumber(pet,{"Level","Lvl","level","lvl"})or 1
	local xp=readNumber(pet,{"XP","Exp","Experience","xp"})or 0
	return totalFrom(base,lvl,xp)
end

local function bestForHit(hit,rarity,rockName)
	local base,stat=BASE[rarity],STAT[rarity]
	if not whole(hit)then return nil end
	hit=round(hit)
	local best=nil
	for endLvl=1,19 do
		local cap=cum(base,endLvl)
		local startTotal=cap-hit
		if startTotal>=0 then
			local sl,sx=levelFromTotal(base,startTotal)
			local cross=endLvl-sl+1
			if cross>=1 then
				local cand={rarity=rarity,rock=rockName,hit=hit,startTotal=startTotal,setLvl=sl,setXp=sx,capLvl=endLvl,bonus=cross*stat,cross=cross}
				if not best or cand.bonus>best.bonus or(cand.bonus==best.bonus and cand.startTotal<best.startTotal)then best=cand end
			end
		end
	end
	return best
end

local function treadmillPlan(diff)
	diff=round(diff)
	if diff<0 then return "перекачано на "..math.abs(diff).." XP"end
	if diff==0 then return "уже ровно"end
	local p={}
	for g=6,1,-1 do
		local c=math.floor(diff/g)
		if c>0 then table.insert(p,"+"..g.."×"..c) diff-=c*g end
	end
	return table.concat(p,"  ")
end

local function allSuggestions(reb,rarityFilter,rockFilter)
	local list={}
	for _,rar in ipairs(RAR)do
		if rarityFilter=="All" or rar==rarityFilter then
			for _,r in ipairs(ROCKS)do
				if rockFilter=="All" or r.name==rockFilter then
					local b=bestForHit((reb+20)*r.v,rar,r.name)
					if b then table.insert(list,b)end
				end
			end
		end
	end
	table.sort(list,function(a,b)
		if a.bonus~=b.bonus then return a.bonus>b.bonus end
		if a.rarity~=b.rarity then return STAT[a.rarity]>STAT[b.rarity] end
		if a.hit~=b.hit then return a.hit>b.hit end
		return a.startTotal<b.startTotal
	end)
	return list
end

local gui=Instance.new("ScreenGui")
gui.Name="PetAlignHubV3"
gui.ResetOnSpawn=false
gui.Parent=lp:WaitForChild("PlayerGui")

local f=Instance.new("Frame",gui)
f.Size=UDim2.new(0,390,0,430)
f.Position=UDim2.new(.5,-195,.5,-215)
f.BackgroundColor3=Color3.fromRGB(14,13,30)
f.BorderSizePixel=0
f.Active=true
f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,16)

local stroke=Instance.new("UIStroke",f)
stroke.Color=Color3.fromRGB(95,55,180)
stroke.Thickness=1.5

local title=Instance.new("TextLabel",f)
title.Size=UDim2.new(1,-54,0,38)
title.Position=UDim2.new(0,14,0,8)
title.BackgroundTransparency=1
title.Text="Pet Align Hub v3"
title.TextColor3=Color3.new(1,1,1)
title.Font=Enum.Font.GothamBlack
title.TextSize=20
title.TextXAlignment=Enum.TextXAlignment.Left

local close=Instance.new("TextButton",f)
close.Size=UDim2.new(0,34,0,34)
close.Position=UDim2.new(1,-44,0,8)
close.Text="×"
close.TextColor3=Color3.fromRGB(255,180,190)
close.BackgroundColor3=Color3.fromRGB(62,20,34)
close.Font=Enum.Font.GothamBlack
close.TextSize=19
Instance.new("UICorner",close).CornerRadius=UDim.new(0,11)
close.MouseButton1Click:Connect(function()gui:Destroy()end)

local function label(txt,x,y,w)
	local l=Instance.new("TextLabel",f)
	l.Size=UDim2.new(0,w or 100,0,22)
	l.Position=UDim2.new(0,x,0,y)
	l.BackgroundTransparency=1
	l.Text=txt
	l.TextColor3=Color3.fromRGB(205,195,255)
	l.Font=Enum.Font.GothamBold
	l.TextSize=12
	l.TextXAlignment=Enum.TextXAlignment.Left
	return l
end

local function box(x,y,w,def)
	local b=Instance.new("TextBox",f)
	b.Size=UDim2.new(0,w,0,34)
	b.Position=UDim2.new(0,x,0,y)
	b.Text=def
	b.ClearTextOnFocus=false
	b.TextColor3=Color3.new(1,1,1)
	b.PlaceholderColor3=Color3.fromRGB(160,150,190)
	b.BackgroundColor3=Color3.fromRGB(31,29,61)
	b.Font=Enum.Font.GothamBold
	b.TextSize=13
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

local function smallBtn(x,y,w,text,color)
	local b=Instance.new("TextButton",f)
	b.Size=UDim2.new(0,w,0,34)
	b.Position=UDim2.new(0,x,0,y)
	b.Text=text
	b.TextColor3=Color3.new(1,1,1)
	b.BackgroundColor3=color or Color3.fromRGB(65,56,120)
	b.Font=Enum.Font.GothamBlack
	b.TextSize=13
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

label("Rebirths",14,56)
local reb=box(14,78,116,"0")
local autoRead=smallBtn(136,78,76,"Auto",Color3.fromRGB(105,55,210))

label("Rarity",220,56)
local rarityBtn=smallBtn(220,78,156,"Unique",Color3.fromRGB(55,45,105))

label("Rock",14,120)
local rockBtn=smallBtn(14,142,176,"Legends",Color3.fromRGB(55,45,105))

label("Current pet",204,120)
local curLvl=box(204,142,72,"1")
local curXp=box(284,142,92,"0")

local mode=Instance.new("TextLabel",f)
mode.Size=UDim2.new(1,-28,0,26)
mode.Position=UDim2.new(0,14,0,182)
mode.BackgroundColor3=Color3.fromRGB(22,20,44)
mode.TextColor3=Color3.fromRGB(255,226,122)
mode.Font=Enum.Font.GothamBlack
mode.TextSize=13
mode.Text="инструкция: выбери редкость → Auto → Next по вариантам"
Instance.new("UICorner",mode).CornerRadius=UDim.new(0,9)

local out=Instance.new("TextLabel",f)
out.Size=UDim2.new(1,-28,0,142)
out.Position=UDim2.new(0,14,0,216)
out.BackgroundColor3=Color3.fromRGB(9,9,22)
out.TextColor3=Color3.fromRGB(255,236,165)
out.Font=Enum.Font.GothamBold
out.TextSize=13
out.TextWrapped=true
out.TextYAlignment=Enum.TextYAlignment.Top
out.TextXAlignment=Enum.TextXAlignment.Left
out.Text="Жми Auto"
Instance.new("UICorner",out).CornerRadius=UDim.new(0,12)

local calcBtn=smallBtn(14,372,82,"Calc",Color3.fromRGB(105,55,210))
local nextBtn=smallBtn(104,372,82,"Next",Color3.fromRGB(64,62,120))
local helpBtn=smallBtn(194,372,82,"Help",Color3.fromRGB(44,98,170))
local applyBtn=smallBtn(284,372,92,"Apply",Color3.fromRGB(30,135,80))

local rarityIndex=1
local rockIndex=1
local list,idx,last={},1,nil
local help=false

rarityBtn.MouseButton1Click:Connect(function()
	rarityIndex+=1
	if rarityIndex>#RAR then rarityIndex=1 end
	rarityBtn.Text=RAR[rarityIndex]
	idx=1
end)

rockBtn.MouseButton1Click:Connect(function()
	rockIndex+=1
	if rockIndex>#ROCKS then rockIndex=1 end
	rockBtn.Text=ROCKS[rockIndex].name
	idx=1
end)

local function currentTotal(rarity)
	local pet=selectedPet()
	if pet then return petTotal(pet,rarity)end
	local l=tonumber(curLvl.Text)or 1
	local x=tonumber(curXp.Text)or 0
	return totalFrom(BASE[rarity],l,x)
end

local function render()
	local r=tonumber(reb.Text)
	if not r then out.Text="Не вижу ребы. Введи вручную."return end

	list=allSuggestions(r,rarityBtn.Text,rockBtn.Text)
	if #list==0 then out.Text="Нет точных точек под выбранный фильтр."return end
	if idx>#list then idx=1 end
	last=list[idx]

	local diff=last.startTotal-currentTotal(last.rarity)
	local plan=treadmillPlan(diff)

	local text=("#%s/%s  %s + %s\n"):format(idx,#list,last.rarity,last.rock)
	text..=("1) Выставь пета: %s lvl, %s XP\n"):format(last.setLvl,last.setXp)
	text..=("2) Добивка дорожками: %s\n"):format(plan)
	text..=("3) Ударь камень: %s\n"):format(last.rock)
	text..=("Hit: %s XP | Cap lvl: %s | Бонус: +%s\n"):format(last.hit,last.capLvl,last.bonus)
	text..="Проверка: смотри статы питомца, не только lvl/XP."

	out.Text=text
	mode.Text=("выбрано: %s pet • %s rock • reb %s"):format(last.rarity,last.rock,r)
end

autoRead.MouseButton1Click:Connect(function()
	local d=detectRebirths()
	if d then reb.Text=tostring(d)end
	idx=1
	render()
end)

calcBtn.MouseButton1Click:Connect(function()
	idx=1
	render()
end)

nextBtn.MouseButton1Click:Connect(function()
	if #list==0 then render()return end
	idx+=1
	if idx>#list then idx=1 end
	render()
end)

helpBtn.MouseButton1Click:Connect(function()
	help=not help
	if help then
		out.Text="ИНСТРУКЦИЯ\n\nRebirths — твои ребы.\nRarity — редкость питомца.\nRock — камень для удара.\nCurrent pet — текущий lvl/xp, чтобы посчитать дорожки.\n\nCalc — лучший вариант.\nNext — следующий вариант.\nApply — записать lvl/xp, если есть _G.SelectedPet или _G.PetAPI.\n\nЕсли Auto не видит ребы — впиши вручную."
	else
		render()
	end
end)

applyBtn.MouseButton1Click:Connect(function()
	if not last then render()end
	if not last then return end
	local pet=selectedPet()
	if _G.PetAPI and _G.PetAPI.SetPetXP then
		_G.PetAPI.SetPetXP(pet,last.setLvl,last.setXp,last.startTotal)
		out.Text="✅ Applied через PetAPI\n\n"..out.Text
		return
	end
	if not pet then out.Text="❌ Пет не выбран. Задай _G.SelectedPet или PetAPI."return end
	local a=setNumber(pet,{"Level","Lvl","level","lvl"},last.setLvl)
	local b=setNumber(pet,{"XP","Exp","Experience","xp"},last.setXp)
	local c=setNumber(pet,{"TotalXP","TotalExp","totalXP"},last.startTotal)
	out.Text=((a or b or c)and"✅ Applied\n\n"or"❌ Не нашёл Level/XP/TotalXP\n\n")..out.Text
end)

local d=detectRebirths()
if d then reb.Text=tostring(d)end
render()
