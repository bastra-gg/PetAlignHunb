-- PetAlignHub v6
-- Мини-режим: ребы + редкость + лучший баг. Клик по карточке = спросить pet и запустить ровнение.
-- Для твоей тестовой сборки. Без RemoteEvent-спама.

local Players=game:GetService("Players")
local lp=Players.LocalPlayer

local BASE={Basic=250,Uncommon=500,Rare=750,Epic=1000,Unique=1250}
local STAT={Basic=1,Uncommon=2,Rare=3,Epic=4,Unique=5}
local RAR_ORDER={"Unique","Epic","Rare","Uncommon","Basic"}
local RAR_CHOICES={"Auto","Unique","Epic","Rare","Uncommon","Basic"}

local ROCKS={
{id="AncientJungle",label="Древний лес",value=16.25,names={"AncientJungle","Ancient Jungle","Jungle"}},
{id="MuscleKing",label="Король мышц",value=12.5,names={"MuscleKing","Muscle King","King"}},
{id="Legends",label="Легенды",value=2.5,names={"Legends","Legend"}},
{id="Inferno",label="Инферно",value=1.125,names={"Inferno"}},
{id="Mystic",label="Мистический",value=.75,names={"Mystic"}},
{id="Frozen",label="Ледяной",value=.375,names={"Frozen","Ice"}},
{id="Golden",label="Золотой",value=.2,names={"Golden","Gold"}},
{id="Large",label="Большой",value=.075,names={"Large"}},
{id="Punching",label="Груша",value=.05,names={"Punching","PunchingBag"}},
{id="Tiny",label="Малый",value=.025,names={"Tiny","Small"}},
}

local TREAD_NAMES={
[1]={"Treadmill1","Treadmill +1","+1","XP1"},
[2]={"Treadmill2","Treadmill +2","+2","XP2"},
[3]={"Treadmill3","Treadmill +3","+3","XP3"},
[4]={"Treadmill4","Treadmill +4","+4","XP4"},
[5]={"Treadmill5","Treadmill +5","+5","XP5"},
[6]={"Treadmill6","Treadmill +6","+6","XP6"},
}

local function round(n)return math.floor((tonumber(n)or 0)+.5)end
local function whole(n)return math.abs((tonumber(n)or 0)-round(n))<1e-7 end
local function cum(base,lvl)return base*lvl*(lvl+1)/2 end
local function totalFrom(base,lvl,xp)return cum(base,lvl-1)+xp end
local function lvlCap(base,lvl)return base*lvl end

local function fmt(n)
	local s=tostring(round(n))
	local sign=""
	if s:sub(1,1)=="-"then sign="-"s=s:sub(2)end
	return sign..s:reverse():gsub("(%d%d%d)","%1 "):reverse():gsub("^ ","")
end

local function parseNum(s)
	s=tostring(s or ""):lower():gsub("%s+",""):gsub(",",".")
	s=s:gsub("ребиртов",""):gsub("ребов",""):gsub("реб","")
	local n=tonumber(s:match("([%d%.]+)")or"")
	if not n then return nil end
	local suf=s:match("[kmbtкмбт]")or""
	local mult={k=1e3,["к"]=1e3,m=1e6,["м"]=1e6,b=1e9,["б"]=1e9,t=1e12,["т"]=1e12}
	return round(n*(mult[suf]or 1))
end

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

local function readNumber(obj,names)
	if not obj then return nil end
	if type(obj)=="table"then
		for _,n in ipairs(names)do if tonumber(obj[n])then return tonumber(obj[n])end end
	end
	if typeof(obj)=="Instance"then
		for _,n in ipairs(names)do
			local v=obj:FindFirstChild(n,true)
			if v and(v:IsA("IntValue")or v:IsA("NumberValue"))then return v.Value end
			if v and v:IsA("StringValue")then return parseNum(v.Value)end
		end
	end
	return nil
end

local function setNumber(obj,names,value)
	if not obj then return false end
	if type(obj)=="table"then obj[names[1]]=value return true end
	if typeof(obj)=="Instance"then
		for _,n in ipairs(names)do
			local v=obj:FindFirstChild(n,true)
			if v and(v:IsA("IntValue")or v:IsA("NumberValue"))then v.Value=value return true end
		end
	end
	return false
end

local function root()
	local c=lp.Character or lp.CharacterAdded:Wait()
	return c:FindFirstChild("HumanoidRootPart")or c:FindFirstChild("Torso")or c:FindFirstChild("UpperTorso")
end

local function findByNames(names)
	for _,obj in ipairs(workspace:GetDescendants())do
		local low=obj.Name:lower()
		for _,n in ipairs(names)do
			local q=tostring(n):lower()
			if low==q or low:find(q,1,true)then
				if obj:IsA("BasePart")then return obj end
				local p=obj:FindFirstChildWhichIsA("BasePart",true)
				if p then return p end
			end
		end
	end
	return nil
end

local function tpTo(part)
	local r=root()
	if not r or not part then return false end
	r.CFrame=part.CFrame+Vector3.new(0,4,0)
	return true
end

local function selectedPet()
	if _G.PetAPI and _G.PetAPI.GetSelectedPet then local ok,res=pcall(_G.PetAPI.GetSelectedPet)if ok and res then return res end end
	return _G.SelectedPet or _G.Pet
end

local function hasPet(rarity)
	if _G.PetAPI and _G.PetAPI.HasPet then local ok,res=pcall(_G.PetAPI.HasPet,rarity)if ok then return res end end
	return nil
end

local function selectPet(rarity)
	if _G.PetAPI and _G.PetAPI.SelectPet then pcall(_G.PetAPI.SelectPet,rarity)end
end

local function petTotal(pet,rarity)
	local total=readNumber(pet,{"TotalXP","TotalExp","totalXP","totalExp"})
	if total then return total end
	local lvl=readNumber(pet,{"Level","Lvl","level","lvl"})or 1
	local xp=readNumber(pet,{"XP","Exp","Experience","xp"})or 0
	return totalFrom(BASE[rarity],lvl,xp)
end

local function detectRebirths()
	if _G.PetAPI and _G.PetAPI.GetRebirths then local ok,res=pcall(_G.PetAPI.GetRebirths)if ok and tonumber(res)then return round(res)end end
	if _G.Rebirths and tonumber(_G.Rebirths)then return round(_G.Rebirths)end
	local ls=lp:FindFirstChild("leaderstats")
	if ls then
		for _,v in ipairs(ls:GetChildren())do
			local n=v.Name:lower()
			if n:find("reb")or n:find("перер")then
				if v:IsA("IntValue")or v:IsA("NumberValue")then return round(v.Value)end
				if v:IsA("StringValue")then return parseNum(v.Value)end
			end
		end
	end
	return nil
end

local function bestForHit(rawHit,rarity,rock)
	if not whole(rawHit)then return nil end
	local base,stat=BASE[rarity],STAT[rarity]
	local hit=round(rawHit)
	local best=nil
	for endLvl=1,19 do
		local endTotal=cum(base,endLvl)
		local startTotal=endTotal-hit
		if startTotal>=0 then
			local sl,sx=levelFromTotal(base,startTotal)
			local cross=endLvl-sl+1
			if cross>=1 then
				local cand={rarity=rarity,rock=rock.id,rockLabel=rock.label,hit=hit,setLvl=sl,setXp=sx,startTotal=startTotal,capLvl=endLvl,bonus=cross*stat,crossed=cross,left=lvlCap(base,sl)-sx}
				if not best or cand.bonus>best.bonus or(cand.bonus==best.bonus and cand.startTotal<best.startTotal)then best=cand end
			end
		end
	end
	return best
end

local function getBest(reb,filter)
	local best=nil
	for _,rarity in ipairs(RAR_ORDER)do
		if filter=="Auto"or filter==rarity then
			for _,rock in ipairs(ROCKS)do
				local cand=bestForHit((reb+20)*rock.value,rarity,rock)
				if cand and(not best or cand.bonus>best.bonus or(cand.bonus==best.bonus and STAT[cand.rarity]>STAT[best.rarity])or(cand.bonus==best.bonus and cand.hit>best.hit))then
					best=cand
				end
			end
		end
	end
	return best
end

local function makePlan(diff)
	diff=round(diff)
	if diff<0 then return nil,"Пет выше точки на "..fmt(math.abs(diff)).." XP."end
	local plan={}
	for g=6,1,-1 do
		local c=math.floor(diff/g)
		if c>0 then table.insert(plan,{gain=g,count=c})diff-=c*g end
	end
	return plan,nil
end

local function planText(plan)
	if not plan or #plan==0 then return "уже ровно"end
	local t={}
	for _,p in ipairs(plan)do table.insert(t,"+"..p.gain.."×"..p.count)end
	return table.concat(t,"  ")
end

local gui=Instance.new("ScreenGui")
gui.Name="PetAlignHubV6"
gui.ResetOnSpawn=false
gui.Parent=lp:WaitForChild("PlayerGui")

local frame=Instance.new("Frame",gui)
frame.Size=UDim2.new(0,360,0,250)
frame.Position=UDim2.new(.5,-180,.5,-125)
frame.BackgroundColor3=Color3.fromRGB(12,11,26)
frame.BorderSizePixel=0
frame.Active=true
frame.Draggable=true
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,16)
local st=Instance.new("UIStroke",frame)
st.Color=Color3.fromRGB(132,70,255)
st.Thickness=1.5

local title=Instance.new("TextLabel",frame)
title.Size=UDim2.new(1,-54,0,36)
title.Position=UDim2.new(0,14,0,8)
title.BackgroundTransparency=1
title.Text="Pet Align Hub v6"
title.TextColor3=Color3.new(1,1,1)
title.Font=Enum.Font.GothamBlack
title.TextSize=19
title.TextXAlignment=Enum.TextXAlignment.Left

local close=Instance.new("TextButton",frame)
close.Size=UDim2.new(0,32,0,32)
close.Position=UDim2.new(1,-42,0,8)
close.Text="×"
close.TextColor3=Color3.fromRGB(255,180,190)
close.BackgroundColor3=Color3.fromRGB(62,20,34)
close.Font=Enum.Font.GothamBlack
close.TextSize=18
Instance.new("UICorner",close).CornerRadius=UDim.new(0,10)
close.MouseButton1Click:Connect(function()gui:Destroy()end)

local rebBox=Instance.new("TextBox",frame)
rebBox.Size=UDim2.new(0,210,0,38)
rebBox.Position=UDim2.new(0,14,0,54)
rebBox.Text=""
rebBox.PlaceholderText="Впиши ребы"
rebBox.ClearTextOnFocus=false
rebBox.TextColor3=Color3.new(1,1,1)
rebBox.PlaceholderColor3=Color3.fromRGB(160,150,190)
rebBox.BackgroundColor3=Color3.fromRGB(31,29,61)
rebBox.Font=Enum.Font.GothamBold
rebBox.TextSize=15
Instance.new("UICorner",rebBox).CornerRadius=UDim.new(0,11)

local rarityBtn=Instance.new("TextButton",frame)
rarityBtn.Size=UDim2.new(0,116,0,38)
rarityBtn.Position=UDim2.new(1,-130,0,54)
rarityBtn.Text="Auto"
rarityBtn.TextColor3=Color3.new(1,1,1)
rarityBtn.BackgroundColor3=Color3.fromRGB(62,50,120)
rarityBtn.Font=Enum.Font.GothamBlack
rarityBtn.TextSize=14
Instance.new("UICorner",rarityBtn).CornerRadius=UDim.new(0,11)

local card=Instance.new("TextButton",frame)
card.Size=UDim2.new(1,-28,0,106)
card.Position=UDim2.new(0,14,0,106)
card.Text=""
card.BackgroundColor3=Color3.fromRGB(18,45,35)
card.BorderSizePixel=0
card.AutoButtonColor=true
Instance.new("UICorner",card).CornerRadius=UDim.new(0,14)
local cs=Instance.new("UIStroke",card)
cs.Color=Color3.fromRGB(86,255,154)
cs.Thickness=1.5

local cardText=Instance.new("TextLabel",card)
cardText.Size=UDim2.new(1,-20,1,-16)
cardText.Position=UDim2.new(0,10,0,8)
cardText.BackgroundTransparency=1
cardText.TextColor3=Color3.fromRGB(255,238,170)
cardText.Font=Enum.Font.GothamBold
cardText.TextSize=13
cardText.TextWrapped=true
cardText.TextYAlignment=Enum.TextYAlignment.Top
cardText.TextXAlignment=Enum.TextXAlignment.Left
cardText.Text="Впиши ребы — лучший баг появится тут."

local status=Instance.new("TextLabel",frame)
status.Size=UDim2.new(1,-28,0,22)
status.Position=UDim2.new(0,14,1,-28)
status.BackgroundTransparency=1
status.Text="Клик по карточке = начать авто-ровнение"
status.TextColor3=Color3.fromRGB(175,165,210)
status.Font=Enum.Font.GothamBold
status.TextSize=11
status.TextXAlignment=Enum.TextXAlignment.Left

local confirm=Instance.new("Frame",frame)
confirm.Size=UDim2.new(1,-28,0,112)
confirm.Position=UDim2.new(0,14,0,106)
confirm.BackgroundColor3=Color3.fromRGB(20,18,40)
confirm.Visible=false
confirm.ZIndex=5
Instance.new("UICorner",confirm).CornerRadius=UDim.new(0,14)

local q=Instance.new("TextLabel",confirm)
q.Size=UDim2.new(1,-20,0,54)
q.Position=UDim2.new(0,10,0,8)
q.BackgroundTransparency=1
q.TextColor3=Color3.fromRGB(255,238,170)
q.Font=Enum.Font.GothamBlack
q.TextSize=14
q.TextWrapped=true
q.ZIndex=6
q.Text="Есть нужный пет?"

local yes=Instance.new("TextButton",confirm)
yes.Size=UDim2.new(.48,-8,0,34)
yes.Position=UDim2.new(0,10,1,-44)
yes.Text="Да, ровняй"
yes.TextColor3=Color3.new(1,1,1)
yes.BackgroundColor3=Color3.fromRGB(30,135,80)
yes.Font=Enum.Font.GothamBlack
yes.TextSize=13
yes.ZIndex=6
Instance.new("UICorner",yes).CornerRadius=UDim.new(0,10)

local no=Instance.new("TextButton",confirm)
no.Size=UDim2.new(.48,-8,0,34)
no.Position=UDim2.new(.52,-2,1,-44)
no.Text="Нет"
no.TextColor3=Color3.new(1,1,1)
no.BackgroundColor3=Color3.fromRGB(80,40,55)
no.Font=Enum.Font.GothamBlack
no.TextSize=13
no.ZIndex=6
Instance.new("UICorner",no).CornerRadius=UDim.new(0,10)

local rarityIndex=1
local current=nil
local running=false

local function render()
	local reb=parseNum(rebBox.Text)
	if not reb then
		current=nil
		cardText.Text="Впиши ребы — лучший баг появится тут."
		status.Text="Например: 45164 или 45k"
		return
	end
	local filter=RAR_CHOICES[rarityIndex]
	current=getBest(reb,filter)
	if not current then
		cardText.Text="Нет точного варианта на этих ребах."
		status.Text="Попробуй другую редкость или Auto."
		return
	end
	cardText.Text="✅ Лучший баг\nПет: "..current.rarity.."  |  Камень: "..current.rockLabel.."\nПоставить: "..fmt(current.setLvl).." lvl, "..fmt(current.setXp).." XP\nHit: "..fmt(current.hit).." XP  |  Cap: "..fmt(current.capLvl).." lvl\nОжидание: +"..fmt(current.bonus).." статов"
	status.Text="Нажми карточку → подтверждение → авто-ровнение"
end

local function useTreadmill(gain,count)
	if count<=0 then return true end
	if _G.PetAPI and _G.PetAPI.UseTreadmill then
		local ok=pcall(_G.PetAPI.UseTreadmill,gain,count)
		if ok then return true end
	end
	local part=findByNames(TREAD_NAMES[gain])
	if not part then status.Text="Не нашёл дорожку +"..gain..". Нужен PetAPI.UseTreadmill." return false end
	for i=1,count do
		tpTo(part)
		task.wait(0.18)
	end
	return true
end

local function hitRock(rockId)
	if _G.PetAPI and _G.PetAPI.HitRock then
		local ok=pcall(_G.PetAPI.HitRock,rockId)
		if ok then return true end
	end
	local names=nil
	for _,r in ipairs(ROCKS)do if r.id==rockId then names=r.names break end end
	local part=names and findByNames(names)
	if part then tpTo(part) status.Text="Тепнул к камню. Бей "..rockId.."." return true end
	status.Text="Камень не найден. Нужен PetAPI.HitRock или объект камня."
	return false
end

local function runAlign()
	if running or not current then return end
	running=true
	confirm.Visible=false
	local has=hasPet(current.rarity)
	if has==false then status.Text="У тебя нет "..current.rarity.." pet." running=false return end
	selectPet(current.rarity)

	if _G.PetAPI and _G.PetAPI.SetPetXP then
		local pet=selectedPet()
		pcall(_G.PetAPI.SetPetXP,pet,current.setLvl,current.setXp,current.startTotal)
		status.Text="XP выставлен. Тепаю к камню..."
		task.wait(.25)
		hitRock(current.rock)
		running=false
		return
	end

	local pet=selectedPet()
	if not pet then status.Text="Пет не выбран. Нужен _G.SelectedPet или PetAPI." running=false return end
	local now=petTotal(pet,current.rarity)
	local plan,err=makePlan(current.startTotal-now)
	if err then status.Text=err running=false return end
	status.Text="Ровняю: "..planText(plan)
	for _,p in ipairs(plan)do
		local ok=useTreadmill(p.gain,p.count)
		if not ok then running=false return end
	end
	setNumber(pet,{"Level","Lvl","level","lvl"},current.setLvl)
	setNumber(pet,{"XP","Exp","Experience","xp"},current.setXp)
	setNumber(pet,{"TotalXP","TotalExp","totalXP"},current.startTotal)
	status.Text="Ровно. Тепаю к камню..."
	task.wait(.25)
	hitRock(current.rock)
	running=false
end

rarityBtn.MouseButton1Click:Connect(function()
	rarityIndex+=1
	if rarityIndex>#RAR_CHOICES then rarityIndex=1 end
	rarityBtn.Text=RAR_CHOICES[rarityIndex]
	render()
end)

rebBox:GetPropertyChangedSignal("Text"):Connect(render)

card.MouseButton1Click:Connect(function()
	if not current then return end
	q.Text="У тебя есть "..current.rarity.." pet?\nНужно: "..fmt(current.setLvl).." lvl, "..fmt(current.setXp).." XP"
	confirm.Visible=true
end)

no.MouseButton1Click:Connect(function()
	confirm.Visible=false
	status.Text="Отменено."
end)

yes.MouseButton1Click:Connect(runAlign)

local d=detectRebirths()
if d then rebBox.Text=tostring(d) end
render()
