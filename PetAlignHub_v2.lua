-- PetAlignHub v2
local Players=game:GetService("Players")
local lp=Players.LocalPlayer

local BASE={Basic=250,Uncommon=500,Rare=750,Epic=1000,Unique=1250}
local STAT={Basic=1,Uncommon=2,Rare=3,Epic=4,Unique=5}
local RAR={"Unique","Epic","Rare","Uncommon","Basic"}
local ROCK={
{name="AncientJungle",v=16.25},{name="MuscleKing",v=12.5},{name="Legends",v=2.5},
{name="Inferno",v=1.125},{name="Mystic",v=.75},{name="Frozen",v=.375},
{name="Golden",v=.2},{name="Large",v=.075},{name="Punching",v=.05},{name="Tiny",v=.025}
}

local function whole(n)return math.abs(n-math.floor(n+.5))<1e-7 end
local function round(n)return math.floor(n+.5)end
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

	local pg=lp:FindFirstChild("PlayerGui")
	if pg then
		for _,v in ipairs(pg:GetDescendants())do
			if v:IsA("TextLabel")or v:IsA("TextButton")or v:IsA("TextBox")then
				local txt=tostring(v.Text or "")
				local low=txt:lower()
				if low:find("rebirth")or low:find("перер")or low:find("реб")then
					local num=parseNum(txt)
					if num then return num end
				end
			end
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

local function suggestions(reb)
	local list={}
	for _,rar in ipairs(RAR)do
		for _,r in ipairs(ROCK)do
			local b=bestForHit((reb+20)*r.v,rar,r.name)
			if b then table.insert(list,b)end
		end
	end
	table.sort(list,function(a,b)
		if a.bonus~=b.bonus then return a.bonus>b.bonus end
		if a.hit~=b.hit then return a.hit>b.hit end
		return a.startTotal<b.startTotal
	end)
	return list
end

local function treadmillPlan(diff)
	diff=round(diff)
	if diff<0 then return "перекачано на "..math.abs(diff).." XP"end
	if diff==0 then return "уже ровно"end
	local parts={}
	for g=6,1,-1 do
		local c=math.floor(diff/g)
		if c>0 then table.insert(parts,"+"..g.."×"..c)diff-=c*g end
	end
	return table.concat(parts,"  ")
end

local gui=Instance.new("ScreenGui")
gui.Name="PetAlignHubV2"
gui.ResetOnSpawn=false
gui.Parent=lp:WaitForChild("PlayerGui")

local f=Instance.new("Frame",gui)
f.Size=UDim2.new(0,340,0,318)
f.Position=UDim2.new(.5,-170,.5,-159)
f.BackgroundColor3=Color3.fromRGB(15,14,31)
f.BorderSizePixel=0
f.Active=true
f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,14)

local title=Instance.new("TextLabel",f)
title.Size=UDim2.new(1,-48,0,34)
title.Position=UDim2.new(0,12,0,6)
title.BackgroundTransparency=1
title.Text="Pet Align Hub v2"
title.TextColor3=Color3.new(1,1,1)
title.Font=Enum.Font.GothamBlack
title.TextSize=18
title.TextXAlignment=Enum.TextXAlignment.Left

local close=Instance.new("TextButton",f)
close.Size=UDim2.new(0,30,0,30)
close.Position=UDim2.new(1,-38,0,6)
close.Text="×"
close.TextColor3=Color3.fromRGB(255,180,190)
close.BackgroundColor3=Color3.fromRGB(55,18,30)
close.Font=Enum.Font.GothamBlack
close.TextSize=18
Instance.new("UICorner",close).CornerRadius=UDim.new(0,10)
close.MouseButton1Click:Connect(function()gui:Destroy()end)

local function box(y,label,def)
	local l=Instance.new("TextLabel",f)
	l.Size=UDim2.new(0,135,0,28)
	l.Position=UDim2.new(0,12,0,y)
	l.BackgroundTransparency=1
	l.Text=label
	l.TextColor3=Color3.fromRGB(210,200,255)
	l.Font=Enum.Font.GothamBold
	l.TextSize=13
	l.TextXAlignment=Enum.TextXAlignment.Left

	local b=Instance.new("TextBox",f)
	b.Size=UDim2.new(0,160,0,32)
	b.Position=UDim2.new(1,-172,0,y)
	b.Text=def
	b.ClearTextOnFocus=false
	b.TextColor3=Color3.new(1,1,1)
	b.BackgroundColor3=Color3.fromRGB(31,29,61)
	b.Font=Enum.Font.GothamBold
	b.TextSize=13
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

local reb=box(48,"Rebirths","0")
local cur=box(86,"Current pet","auto")

local out=Instance.new("TextLabel",f)
out.Size=UDim2.new(1,-24,0,112)
out.Position=UDim2.new(0,12,0,126)
out.BackgroundColor3=Color3.fromRGB(10,10,23)
out.TextColor3=Color3.fromRGB(255,230,140)
out.Font=Enum.Font.GothamBold
out.TextSize=13
out.TextWrapped=true
out.TextYAlignment=Enum.TextYAlignment.Top
out.Text="Жми Auto"
Instance.new("UICorner",out).CornerRadius=UDim.new(0,10)

local buttons={}
local function btn(i,text,color)
	local b=Instance.new("TextButton",f)
	b.Size=UDim2.new(.25,-9,0,32)
	b.Position=UDim2.new((i-1)*.25,12-(i-1)*3,1,-42)
	b.Text=text
	b.TextColor3=Color3.new(1,1,1)
	b.BackgroundColor3=color
	b.Font=Enum.Font.GothamBlack
	b.TextSize=13
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	buttons[text]=b
	return b
end

btn(1,"Auto",Color3.fromRGB(105,55,210))
btn(2,"Next",Color3.fromRGB(65,65,120))
btn(3,"Copy",Color3.fromRGB(45,105,180))
btn(4,"Apply",Color3.fromRGB(30,135,80))

local list,idx,last={},1,nil

local function render()
	local r=tonumber(reb.Text)
	if not r then out.Text="Не вижу ребы. Введи вручную или проверь leaderstats."return end
	list=suggestions(r)
	if #list==0 then out.Text="Нет точных математических точек на этих ребах."return end
	if idx>#list then idx=1 end
	local s=list[idx]
	last=s

	local pet=selectedPet()
	local align="пет не выбран"
	if pet then
		local pt=petTotal(pet,s.rarity)
		align=treadmillPlan(s.startTotal-pt)
	end

	out.Text=("#%s/%s  %s + %s\nПоставить: %s lvl, %s XP\nHit: %s | Cap: %s | Bonus: +%s\nДорожки: %s"):format(idx,#list,s.rarity,s.rock,s.setLvl,s.setXp,s.hit,s.capLvl,s.bonus,align)

	if cur.Text=="auto"and pet then
		local lvl=readNumber(pet,{"Level","Lvl","level","lvl"})or"?"
		local xp=readNumber(pet,{"XP","Exp","Experience","xp"})or"?"
		cur.Text=tostring(lvl).." lvl, "..tostring(xp).." XP"
	end
end

buttons.Auto.MouseButton1Click:Connect(function()
	local d=detectRebirths()
	if d then reb.Text=tostring(d)end
	idx=1
	render()
end)

buttons.Next.MouseButton1Click:Connect(function()
	if #list==0 then render()return end
	idx+=1
	if idx>#list then idx=1 end
	render()
end)

buttons.Copy.MouseButton1Click:Connect(function()
	if not last then render()end
	if last and setclipboard then
		setclipboard(("Pet=%s Rock=%s Set=%s lvl, %s XP Hit=%s Bonus=+%s"):format(last.rarity,last.rock,last.setLvl,last.setXp,last.hit,last.bonus))
	end
end)

buttons.Apply.MouseButton1Click:Connect(function()
	if not last then render()end
	if not last then return end
	local pet=selectedPet()
	if _G.PetAPI and _G.PetAPI.SetPetXP then
		_G.PetAPI.SetPetXP(pet,last.setLvl,last.setXp,last.startTotal)
		out.Text="✅ Applied через PetAPI\n"..out.Text
		return
	end
	if not pet then out.Text="❌ Пет не выбран. Задай _G.SelectedPet или PetAPI."return end
	local a=setNumber(pet,{"Level","Lvl","level","lvl"},last.setLvl)
	local b=setNumber(pet,{"XP","Exp","Experience","xp"},last.setXp)
	local c=setNumber(pet,{"TotalXP","TotalExp","totalXP"},last.startTotal)
	out.Text=((a or b or c)and"✅ Applied\n"or"❌ Не нашёл Level/XP/TotalXP\n")..out.Text
end)

local d=detectRebirths()
if d then reb.Text=tostring(d)end
render()
