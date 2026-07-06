-- PetAlignHub v13
-- Исправление: усиленный поиск дорожек/камней по Name + TextLabel + SurfaceGui/BillboardGui.
-- Если объект найден: реально телепорт + touch. Если не найден: пишет что именно не нашёл.

local Players=game:GetService("Players")
local lp=Players.LocalPlayer

local BASE={Basic=250,Uncommon=500,Rare=750,Epic=1000,Unique=1250}
local STAT={Basic=1,Uncommon=2,Rare=3,Epic=4,Unique=5}
local RAR_ORDER={"Unique","Epic","Rare","Uncommon","Basic"}
local RAR_CHOICES={"Auto","Unique","Epic","Rare","Uncommon","Basic"}

local ROCKS={
{id="AncientJungle",label="Древний лес",value=16.25,keys={"ancient","jungle","ancient jungle","древ","лес"}},
{id="MuscleKing",label="Король мышц",value=12.5,keys={"muscleking","muscle king","king","король","мышц"}},
{id="Legends",label="Легенды",value=2.5,keys={"legends","legend","легенд"}},
{id="Inferno",label="Инферно",value=1.125,keys={"inferno","инферно"}},
{id="Mystic",label="Мистический",value=.75,keys={"mystic","мист"}},
{id="Frozen",label="Ледяной",value=.375,keys={"frozen","ice","лед","мороз"}},
{id="Golden",label="Золотой",value=.2,keys={"golden","gold","золот"}},
{id="Large",label="Большой",value=.075,keys={"large","big","больш"}},
{id="Punching",label="Груша",value=.05,keys={"punching","punch","bag","груш"}},
{id="Tiny",label="Малый",value=.025,keys={"tiny","small","мал"}},
}

local TREAD_KEYS={
[1]={"+1"," 1 ","1xp","xp1","gain1","treadmill1","treadmill 1","дорожка1","дорожка 1"},
[2]={"+2"," 2 ","2xp","xp2","gain2","treadmill2","treadmill 2","дорожка2","дорожка 2"},
[3]={"+3"," 3 ","3xp","xp3","gain3","treadmill3","treadmill 3","дорожка3","дорожка 3"},
[4]={"+4"," 4 ","4xp","xp4","gain4","treadmill4","treadmill 4","дорожка4","дорожка 4"},
[5]={"+5"," 5 ","5xp","xp5","gain5","treadmill5","treadmill 5","дорожка5","дорожка 5"},
[6]={"+6"," 6 ","6xp","xp6","gain6","treadmill6","treadmill 6","дорожка6","дорожка 6"},
}

local HIT_WAIT=.25
if _G.PetAlignReverseRun==nil then _G.PetAlignReverseRun=true end

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

local function lowerText(x)return tostring(x or ""):lower()end

local function objectText(obj)
	local t={}
	local p=obj
	for _=1,4 do
		if not p then break end
		table.insert(t,p.Name)
		p=p.Parent
	end
	for _,d in ipairs(obj:GetDescendants())do
		if d:IsA("TextLabel")or d:IsA("TextButton")or d:IsA("TextBox")then
			table.insert(t,d.Text)
		elseif d:IsA("StringValue")then
			table.insert(t,d.Value)
		end
	end
	return lowerText(table.concat(t," "))
end

local function hasAny(txt,keys)
	for _,k in ipairs(keys)do
		if txt:find(lowerText(k),1,true)then return true end
	end
	return false
end

local function getPart(obj)
	if obj:IsA("BasePart")then return obj end
	if obj:IsA("Model")then
		if obj.PrimaryPart then return obj.PrimaryPart end
		return obj:FindFirstChildWhichIsA("BasePart",true)
	end
	return obj:FindFirstAncestorWhichIsA("BasePart") or obj:FindFirstChildWhichIsA("BasePart",true)
end

local function findPartSmart(keys,kind)
	local best,bestScore=nil,-999999
	local hrp=nil
	pcall(function()
		local c=lp.Character
		hrp=c and c:FindFirstChild("HumanoidRootPart")
	end)

	for _,obj in ipairs(workspace:GetDescendants())do
		local part=getPart(obj)
		if part then
			local txt=objectText(obj)
			local score=0

			if hasAny(txt,keys)then score+=100 end

			-- Подсказки по типу объекта
			if kind=="tread"then
				if txt:find("tread",1,true)or txt:find("дорож",1,true)or txt:find("xp",1,true)or txt:find("gain",1,true)then score+=30 end
				if obj:FindFirstChildWhichIsA("TouchTransmitter",true)then score+=15 end
			elseif kind=="rock"then
				if txt:find("rock",1,true)or txt:find("кам",1,true)or txt:find("stone",1,true)then score+=30 end
				if obj:FindFirstChildWhichIsA("TouchTransmitter",true)then score+=15 end
			end

			if hrp then
				local dist=(part.Position-hrp.Position).Magnitude
				score-=math.min(dist/60,20)
			end

			if score>bestScore and score>50 then
				bestScore=score
				best=part
			end
		end
	end

	return best,bestScore
end


local function mainPart(model)
	if not model then return nil end
	if model:IsA("BasePart")then return model end
	if model.PrimaryPart then return model.PrimaryPart end
	return model:FindFirstChild("treadmillPart",true)
		or model:FindFirstChild("Part",true)
		or model:FindFirstChildWhichIsA("BasePart",true)
end

local function uniqueTreadmillModels()
	local holder=workspace:FindFirstChild("Treadmills")
	local list={}
	local seen={}

	local function addModel(m)
		if not m or seen[m] then return end
		local p=mainPart(m)
		if p then
			seen[m]=true
			table.insert(list,{model=m,part=p,pos=p.Position})
		end
	end

	if holder then
		for _,ch in ipairs(holder:GetChildren())do
			if ch:IsA("Model")then
				addModel(ch)
			elseif ch:IsA("BasePart")then
				addModel(ch)
			end
		end
	end

	if #list==0 then
		for _,obj in ipairs(workspace:GetDescendants())do
			local txt=objectText(obj)
			if txt:find("treadmill",1,true)or txt:find("дорож",1,true)then
				local m=obj:IsA("Model") and obj or obj:FindFirstAncestorWhichIsA("Model") or obj
				addModel(m)
			end
		end
	end

	if #list<=1 then return list end

	local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
	for _,it in ipairs(list)do
		minX=math.min(minX,it.pos.X); maxX=math.max(maxX,it.pos.X)
		minZ=math.min(minZ,it.pos.Z); maxZ=math.max(maxZ,it.pos.Z)
	end

	local axis=(maxX-minX) >= (maxZ-minZ) and "X" or "Z"

	table.sort(list,function(a,b)
		if math.abs(a.pos[axis]-b.pos[axis])>1 then
			return a.pos[axis]<b.pos[axis]
		end
		local other=axis=="X" and "Z" or "X"
		return a.pos[other]<b.pos[other]
	end)

	if _G.PetAlignReverseTreadmills then
		local rev={}
		for i=#list,1,-1 do table.insert(rev,list[i])end
		list=rev
	end

	return list
end

local function fallbackTreadmillPart(gain)
	-- Если в игре все дорожки называются просто Workspace/Treadmills/Treadmill,
	-- берём их по порядку. По умолчанию: 1-я = +1, 6-я = +6.
	if _G.PetAlignTreadmillIndex and _G.PetAlignTreadmillIndex[gain] then
		gain=_G.PetAlignTreadmillIndex[gain]
	end

	local list=uniqueTreadmillModels()
	if #list==0 then return nil,0 end

	local idx=math.clamp(gain,1,#list)
	return list[idx].part,#list,idx
end



local function objectPath(obj)
	local parts={}
	local p=obj
	while p and p~=game do
		table.insert(parts,1,p.Name)
		p=p.Parent
	end
	return table.concat(parts,"/")
end

local function scanCandidates(kind)
	local rows={}
	local hrp=nil
	pcall(function()
		local c=lp.Character
		hrp=c and c:FindFirstChild("HumanoidRootPart")
	end)

	for _,obj in ipairs(workspace:GetDescendants())do
		local part=getPart(obj)
		if part then
			local txt=objectText(obj)
			local score=0

			if kind=="tread"then
				if txt:find("tread",1,true)then score+=45 end
				if txt:find("дорож",1,true)then score+=45 end
				if txt:find("трен",1,true)then score+=40 end
				if txt:find("бег",1,true)then score+=30 end
				if txt:find("agility",1,true)then score+=25 end
				if txt:find("speed",1,true)then score+=18 end
				if txt:find("xp",1,true)then score+=10 end
			elseif kind=="rock"then
				if txt:find("rock",1,true)then score+=45 end
				if txt:find("кам",1,true)then score+=45 end
				if txt:find("stone",1,true)then score+=30 end
				if txt:find("legend",1,true)then score+=30 end
				if txt:find("muscle",1,true)then score+=22 end
			end

			if obj:FindFirstChildWhichIsA("TouchTransmitter",true)then score+=20 end
			if obj:FindFirstChildWhichIsA("ClickDetector",true)then score+=14 end
			if obj:FindFirstChildWhichIsA("ProximityPrompt",true)then score+=14 end

			local dist=999999
			if hrp then
				dist=(part.Position-hrp.Position).Magnitude
				score-=math.min(dist/80,25)
			end

			if score>10 then
				table.insert(rows,{
					score=score,
					dist=dist,
					name=obj.Name,
					part=part.Name,
					path=objectPath(obj),
					text=txt:sub(1,160)
				})
			end
		end
	end

	table.sort(rows,function(a,b)
		if math.floor(a.score)~=math.floor(b.score)then return a.score>b.score end
		return a.dist<b.dist
	end)

	return rows
end

local function copyScanReport(reason,kind,gainOrRock)
	local rows=scanCandidates(kind)
	local lines={}
	table.insert(lines,"PetAlignHub scan report")
	table.insert(lines,"reason: "..tostring(reason))
	table.insert(lines,"kind: "..tostring(kind).." target: "..tostring(gainOrRock))
	table.insert(lines,"place: "..tostring(game.PlaceId))
	table.insert(lines,"--- top candidates ---")

	for i=1,math.min(#rows,35)do
		local r=rows[i]
		table.insert(lines,("#%02d score=%.1f dist=%.1f name=%s part=%s"):format(i,r.score,r.dist,r.name,r.part))
		table.insert(lines,"path="..r.path)
		table.insert(lines,"text="..r.text:gsub("\n"," "))
		table.insert(lines,"")
	end

	local report=table.concat(lines,"\n")
	_G.PetAlignLastScan=report
	if setclipboard then
		pcall(setclipboard,report)
	end
	return #rows
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

local function tpTo(part)
	local r=root()
	if not r or not part then return false end
	r.CFrame=part.CFrame+Vector3.new(0,4,0)
	return true
end

local function touchPart(part)
	local r=root()
	if not r or not part then return end
	pcall(function()
		firetouchinterest(r,part,0)
		task.wait(.05)
		firetouchinterest(r,part,1)
	end)
end

local function petTotalRaw(pet,rarity)
	if not pet then return nil end
	local total=readNumber(pet,{"TotalXP","TotalExp","totalXP","totalExp"})
	if total then return total end
	local lvl=readNumber(pet,{"Level","Lvl","level","lvl"})or 1
	local xp=readNumber(pet,{"XP","Exp","Experience","xp"})or 0
	return totalFrom(BASE[rarity],lvl,xp)
end

local function runOnTreadmill(part,seconds,pet,rarity,targetTotal)
	local c=lp.Character or lp.CharacterAdded:Wait()
	local r=root()
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if not r or not hum or not part then return false end

	local dir
	if part.Size.Z >= part.Size.X then
		dir=part.CFrame.LookVector
	else
		dir=part.CFrame.RightVector
	end

	if _G.PetAlignReverseRun then
		dir=-dir
	end

	local speed=_G.PetAlignRunSpeed or 10
	local center=part.Position + Vector3.new(0,3.2,0)
	local oldSpeed=hum.WalkSpeed

	hum.WalkSpeed=speed
	r.CFrame=CFrame.lookAt(center,center+dir)

	local started=os.clock()
	local lastCenter=0

	while not _G.PetAlignStop and os.clock()-started < seconds do
		if pet and rarity and targetTotal then
			local now=petTotalRaw(pet,rarity)
			if now and now>=targetTotal then
				break
			end
		end

		-- держим персонажа на дорожке, но не телепаем каждую миллисекунду
		if os.clock()-lastCenter>.18 then
			lastCenter=os.clock()
			if (r.Position-center).Magnitude>5 then
				r.CFrame=CFrame.lookAt(center,center+dir)
			else
				r.CFrame=CFrame.lookAt(r.Position,r.Position+dir)
			end
		end

		hum:Move(dir,false)
		r.AssemblyLinearVelocity=Vector3.new(dir.X*speed,r.AssemblyLinearVelocity.Y,dir.Z*speed)
		task.wait(0.035)
	end

	hum:Move(Vector3.zero,false)
	hum.WalkSpeed=oldSpeed
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

-- UI
local gui=Instance.new("ScreenGui")
gui.Name="PetAlignHubV13"
gui.ResetOnSpawn=false
gui.Parent=lp:WaitForChild("PlayerGui")

local frame=Instance.new("Frame",gui)
frame.Size=UDim2.new(0,370,0,258)
frame.Position=UDim2.new(.5,-185,.5,-129)
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
title.Text="Pet Align Hub v13"
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
close.MouseButton1Click:Connect(function() _G.PetAlignStop=true gui:Destroy() end)

local rebBox=Instance.new("TextBox",frame)
rebBox.Size=UDim2.new(0,214,0,38)
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
status.Size=UDim2.new(1,-28,0,30)
status.Position=UDim2.new(0,14,1,-36)
status.BackgroundTransparency=1
status.Text="Клик = ровный бег по дорожке, потом камень"
status.TextColor3=Color3.fromRGB(175,165,210)
status.Font=Enum.Font.GothamBold
status.TextSize=11
status.TextWrapped=true
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
		status.Text="PetAPI: дорожка +"..gain.." × "..count
		local ok=pcall(_G.PetAPI.UseTreadmill,gain,count)
		if ok then return true end
	end
	local part=findPartSmart(TREAD_KEYS[gain],"tread")
	local fallbackInfo=""
	if not part then
		local total,idx
		part,total,idx=fallbackTreadmillPart(gain)
		if part then
			fallbackInfo=" fallback #"..tostring(idx).."/"..tostring(total)
		end
	end
	if not part then
		local n=copyScanReport("не нашёл дорожку", "tread", "+"..gain)
		status.Text="Не нашёл дорожку +"..gain..". Скан скопирован в буфер ("..n.." кандидатов)."
		return false
	end
	-- Дорожка работает только от бега. Больше не телепаем по КД:
	-- один заход на дорожку + постоянный бег со скоростью 10.
	local seconds=math.max(1.2,count*(_G.PetAlignRunSecondsPerUse or 0.22))
	status.Text="Бег по дорожке +"..gain..fallbackInfo.." ~"..string.format("%.1f",seconds).."с"
	runOnTreadmill(part,seconds,_G.PetAlignCurrentPet,_G.PetAlignCurrentRarity,_G.PetAlignTargetTotal)
	return true
end

local function hitRock(rockId)
	if _G.PetAPI and _G.PetAPI.HitRock then
		status.Text="PetAPI: бью камень "..rockId
		local ok=pcall(_G.PetAPI.HitRock,rockId)
		if ok then return true end
	end
	local keys=nil
	for _,r in ipairs(ROCKS)do if r.id==rockId then keys=r.keys break end end
	local part=keys and findPartSmart(keys,"rock")
	if part then
		tpTo(part)
		touchPart(part)
		status.Text="Тепнул/коснулся камня: "..rockId
		return true
	end
	local n=copyScanReport("не нашёл камень", "rock", rockId)
	status.Text="Камень не найден. Скан скопирован в буфер ("..n.." кандидатов). Пришли его мне."
	return false
end

local function runAlign()
	if running or not current then return end
	running=true
	confirm.Visible=false

	local has=hasPet(current.rarity)
	if has==false then status.Text="У тебя нет "..current.rarity.." pet." running=false return end
	selectPet(current.rarity)

	local pet=selectedPet()

	if _G.PetAPI and _G.PetAPI.SetPetXP then
		status.Text="Выставляю XP через PetAPI..."
		pcall(_G.PetAPI.SetPetXP,pet,current.setLvl,current.setXp,current.startTotal)
		task.wait(.25)
		hitRock(current.rock)
		running=false
		return
	end

	local now=0
	if pet then
		now=petTotal(pet,current.rarity)
	else
		now=0
		status.Text="Пет не прочитан. Ровняю как с 1 lvl 0 XP."
		task.wait(.6)
	end

	local plan,err=makePlan(current.startTotal-now)
	if err then status.Text=err running=false return end

	status.Text="Ровняю постоянным бегом: "..planText(plan)
	_G.PetAlignStop=false
	_G.PetAlignCurrentPet=pet
	_G.PetAlignCurrentRarity=current.rarity
	_G.PetAlignTargetTotal=current.startTotal
	for _,p in ipairs(plan)do
		local ok=useTreadmill(p.gain,p.count)
		if not ok then running=false return end
	end

	if pet then
		setNumber(pet,{"Level","Lvl","level","lvl"},current.setLvl)
		setNumber(pet,{"XP","Exp","Experience","xp"},current.setXp)
		setNumber(pet,{"TotalXP","TotalExp","totalXP"},current.startTotal)
	end

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
