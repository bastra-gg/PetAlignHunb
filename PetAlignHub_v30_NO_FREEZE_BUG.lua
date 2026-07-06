-- PetAlignHub v30_NO_FREEZE_BUG
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
-- Карта из твоего v23 отчёта. Эти индексы дают ровно +1..+6 XP за 5 секунд.
if _G.PetAlignTreadmillIndex==nil then
	_G.PetAlignTreadmillIndex={[1]=36,[2]=33,[3]=31,[4]=29,[5]=28,[6]=26}
end
if _G.PetAlignTreadmillGainSeconds==nil then
	_G.PetAlignTreadmillGainSeconds=5.0
end

-- v30: чтобы Roblox не подвисал на GO BUG.
if _G.PetAlignBugAnchor==nil then _G.PetAlignBugAnchor=false end
if _G.PetAlignBugHitDelay==nil then _G.PetAlignBugHitDelay=.35 end
if _G.PetAlignBugHitSeconds==nil then _G.PetAlignBugHitSeconds=2.5 end
if _G.PetAlignRockScanLimit==nil then _G.PetAlignRockScanLimit=3500 end

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


local function sortTreadmillLine(list)
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
		return rev
	end

	return list
end

local function nearestTreadmillModels(limit)
	local all=uniqueTreadmillModels()
	local r=root()
	if not r then return sortTreadmillLine(all) end

	for _,it in ipairs(all)do
		it.dist=(it.pos-r.Position).Magnitude
	end

	table.sort(all,function(a,b)return a.dist<b.dist end)

	local near={}
	for i=1,math.min(limit or 6,#all)do
		table.insert(near,all[i])
	end

	return sortTreadmillLine(near)
end


local function fallbackTreadmillPart(gain)
	-- Если была CAL-калибровка в этой же сессии — используем точные part.
	if _G.PetAlignTreadmillParts and _G.PetAlignTreadmillParts[gain] then
		return _G.PetAlignTreadmillParts[gain],6,gain
	end

	local useAll=false
	if _G.PetAlignTreadmillIndex and _G.PetAlignTreadmillIndex[gain] then
		gain=_G.PetAlignTreadmillIndex[gain]
		useAll=true
	end

	-- Если есть карта, индекс относится ко ВСЕМ дорожкам из Workspace/Treadmills.
	-- Если карты нет, fallback — ближайшие 6.
	local list=useAll and uniqueTreadmillModels() or nearestTreadmillModels(6)
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


local function isInterestingPath(path)
	local low=tostring(path or ""):lower()
	return low:find("xp",1,true)
		or low:find("exp",1,true)
		or low:find("experience",1,true)
		or low:find("опыт",1,true)
		or low:find("pet",1,true)
		or low:find("питом",1,true)
end

local function numericSnapshot()
	local snap={}
	local function add(key,value)
		value=tonumber(value)
		if not value then return end
		if value~=value or math.abs(value)>1e18 then return end
		snap[key]=value
	end

	local roots={lp,lp:FindFirstChild("PlayerGui")}
	for _,rootObj in ipairs(roots)do
		if rootObj then
			for _,v in ipairs(rootObj:GetDescendants())do
				local path=objectPath(v)

				if v:IsA("IntValue")or v:IsA("NumberValue")then
					if isInterestingPath(path) then
						add("value:"..path,v.Value)
					end
				elseif v:IsA("StringValue")then
					if isInterestingPath(path) then
						add("string:"..path,parseNum(v.Value))
					end
				elseif v:IsA("TextLabel")or v:IsA("TextButton")or v:IsA("TextBox")then
					local txt=tostring(v.Text or "")
					local low=txt:lower()
					local pathKey="gui:"..path.." text="..txt:gsub("\n"," "):sub(1,70)

					local a,b=low:match("([%d%s%.%,]+)%s*/%s*([%d%s%.%,]+)")
					if a and b then
						-- для калибровки берём любые дроби из UI, но в отчёте будет виден источник
						add(pathKey,parseNum(a))
					elseif isInterestingPath(path) or low:find("опыт",1,true) or low:find("xp",1,true) or low:find("exp",1,true) then
						local n=parseNum(txt)
						if n then add(pathKey,n) end
					end
				end
			end
		end
	end

	return snap
end

local function snapshotChanges(before,after)
	local rows={}
	for key,av in pairs(before or {})do
		local bv=after and after[key]
		if bv and bv~=av then
			table.insert(rows,{key=key,before=av,after=bv,delta=bv-av})
		end
	end

	table.sort(rows,function(a,b)
		local ap=a.delta>0 and 1 or 0
		local bp=b.delta>0 and 1 or 0
		if ap~=bp then return ap>bp end
		if math.abs(a.delta)~=math.abs(b.delta)then return math.abs(a.delta)>math.abs(b.delta)end
		return a.key<b.key
	end)

	return rows
end

local function chooseDirectDelta(beforeTotal,afterTotal,beforeSnap,afterSnap)
	local totalDelta=(beforeTotal and afterTotal) and (afterTotal-beforeTotal) or nil
	if totalDelta and totalDelta>0 then
		return round(totalDelta),"pet_total",snapshotChanges(beforeSnap,afterSnap)
	end

	local changes=snapshotChanges(beforeSnap,afterSnap)

	for _,r in ipairs(changes)do
		local low=r.key:lower()
		if r.delta>0 and (low:find("xp",1,true) or low:find("exp",1,true) or low:find("опыт",1,true) or low:find("pet",1,true) or low:find("питом",1,true))then
			return round(r.delta),"direct_change:"..r.key,changes
		end
	end

	for _,r in ipairs(changes)do
		if r.delta>0 then
			return round(r.delta),"direct_change:"..r.key,changes
		end
	end

	return 0,"no_positive_direct_change",changes
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

local function parsePetGuiTotal(rarity)
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg or not BASE[rarity] then return nil end

	local lvl=nil
	local xp=nil

	for _,v in ipairs(pg:GetDescendants())do
		if v:IsA("TextLabel")or v:IsA("TextButton")or v:IsA("TextBox")then
			local txt=tostring(v.Text or "")
			local low=txt:lower()

			local lv=low:match("уровень%s*(%d+)")
				or low:match("level%s*(%d+)")
				or low:match("lvl%s*(%d+)")

			if lv then
				lvl=tonumber(lv)
			end

			-- варианты типа 675/675 опыта, 0/250 exp
			local a,b=low:match("([%d%s%.%,]+)%s*/%s*([%d%s%.%,]+)")
			if a and b and (low:find("опыт") or low:find("xp") or low:find("exp")) then
				xp=parseNum(a)
			end
		end
	end

	if lvl and xp then
		return totalFrom(BASE[rarity],lvl,xp),lvl,xp
	end

	return nil
end

local function getPetTotalAny(pet,rarity)
	local total=petTotalRaw(pet,rarity)
	if total then return total,"data" end

	local guiTotal,lvl,xp=parsePetGuiTotal(rarity)
	if guiTotal then
		return guiTotal,"gui",lvl,xp
	end

	return nil,nil
end


local function runOnTreadmill(part,seconds,pet,rarity,targetTotal)
	local RunService=game:GetService("RunService")
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

	dir=Vector3.new(dir.X,0,dir.Z)
	if dir.Magnitude<0.05 then dir=Vector3.new(0,0,-1) end
	dir=dir.Unit

	if _G.PetAlignReverseRun then
		dir=-dir
	end

	local speed=_G.PetAlignRunSpeed or 20
	local length=math.max(part.Size.X,part.Size.Z)
	local runOffset=math.clamp(length*0.40,2.5,math.max(2.5,length/2-1.2))

	local up=part.CFrame.UpVector
	local heightAbove=_G.PetAlignHeightOffset or math.clamp((hum.HipHeight or 2)+1.15,2.75,4.15)
	local startPos=part.Position - dir*runOffset + up*(part.Size.Y/2 + heightAbove)

	local oldSpeed=hum.WalkSpeed
	local oldAutoRotate=hum.AutoRotate
	local oldJumpPower=hum.JumpPower
	local oldJumpHeight=hum.JumpHeight

	local startTotal=getPetTotalAny(pet,rarity)

	hum.WalkSpeed=speed
	hum.AutoRotate=true
	pcall(function() hum.JumpPower=0 end)
	pcall(function() hum.JumpHeight=0 end)

	r.CFrame=CFrame.lookAt(startPos,startPos+dir)
	task.wait(0.18)

	local started=os.clock()
	local minRun=_G.PetAlignMinTreadmillRunSeconds or 2.25
	local maxRun=seconds or (_G.PetAlignTreadmillMaxRunSeconds or 90)

	while not _G.PetAlignStop do
		local elapsed=os.clock()-started
		local now=nil

		if elapsed>=minRun then
			now=getPetTotalAny(pet,rarity)
			-- Не стопаемся от старого/левого GUI-числа: нужен реальный прирост после старта.
			if targetTotal and now and now>=targetTotal and (not startTotal or now>startTotal)then
				break
			end
		end

		if elapsed>=maxRun then
			break
		end

		if now and targetTotal then
			status.Text="Бег до XP: "..fmt(now).."/"..fmt(targetTotal)
		end

		hum:Move(dir,false)
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)

		RunService.Heartbeat:Wait()
	end

	hum:Move(Vector3.zero,false)
	hum.WalkSpeed=oldSpeed
	hum.AutoRotate=oldAutoRotate
	pcall(function() hum.JumpPower=oldJumpPower end)
	pcall(function() hum.JumpHeight=oldJumpHeight end)
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


local function planCount(plan)
	local n=0
	if plan then
		for _,p in ipairs(plan)do n+=p.count end
	end
	return n
end

local function rockHitXP(reb,rock)
	local raw=(reb+20)*rock.value
	if not whole(raw)then return nil end
	return round(raw)
end

local function smartAlignPlan(diff,reb)
	diff=round(diff)
	local treadPlan,err=makePlan(diff)
	if err then return nil,err end

	local treadSec=_G.PetAlignTreadmillGainSeconds or 5.0
	local rockSec=_G.PetAlignPreRockHitSeconds or 0.55

	local best={
		rock=nil,
		rockHits=0,
		rockXp=0,
		rem=diff,
		treadPlan=treadPlan,
		time=planCount(treadPlan)*treadSec
	}

	for _,rock in ipairs(ROCKS)do
		local hit=rockHitXP(reb,rock)
		if hit and hit>0 and hit<=diff then
			local maxHits=math.floor(diff/hit)

			-- Проверяем не только максимум: иногда на 1-2 удара меньше даёт меньше дорожек.
			local minHits=math.max(1,maxHits-12)
			for count=maxHits,minHits,-1 do
				local rem=diff-hit*count
				local p=makePlan(rem)
				local time=count*rockSec+planCount(p)*treadSec

				if time+0.05<best.time then
					best={
						rock=rock,
						rockHits=count,
						rockXp=hit,
						rem=rem,
						treadPlan=p,
						time=time
					}
				end
			end
		end
	end

	return best,nil
end

local function smartPlanText(route)
	if not route then return "нет маршрута" end
	local a={}
	if route.rock and route.rockHits>0 then
		table.insert(a,route.rock.label.."×"..route.rockHits.." ("..fmt(route.rockXp).." XP)")
	end
	table.insert(a,planText(route.treadPlan))
	return table.concat(a," → ")
end


-- UI
local gui=Instance.new("ScreenGui")
gui.Name="PetAlignHubV30"
gui.ResetOnSpawn=false
gui.Parent=lp:WaitForChild("PlayerGui")

local frame=Instance.new("Frame",gui)
frame.Size=UDim2.new(0,370,0,292)
frame.Position=UDim2.new(.5,-185,.5,-146)
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
title.Text="Pet Align Hub v30"
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
close.MouseButton1Click:Connect(function() _G.PetAlignStop=true _G.PetAlignBugStop=true running=false gui:Destroy() end)

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
status.Position=UDim2.new(0,14,1,-66)
status.BackgroundTransparency=1
status.Text="Клик = ровнять, BUG = перейти к багу"
status.TextColor3=Color3.fromRGB(175,165,210)
status.Font=Enum.Font.GothamBold
status.TextSize=11
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left

local calBtn=Instance.new("TextButton",frame)
calBtn.Size=UDim2.new(0,58,0,26)
calBtn.Position=UDim2.new(0,14,1,-34)
calBtn.Text="CAL"
calBtn.TextColor3=Color3.new(1,1,1)
calBtn.BackgroundColor3=Color3.fromRGB(45,100,180)
calBtn.Font=Enum.Font.GothamBlack
calBtn.TextSize=12
Instance.new("UICorner",calBtn).CornerRadius=UDim.new(0,8)

local bugBtn=Instance.new("TextButton",frame)
bugBtn.Size=UDim2.new(0,70,0,26)
bugBtn.Position=UDim2.new(0,78,1,-34)
bugBtn.Text="GO BUG"
bugBtn.TextColor3=Color3.new(1,1,1)
bugBtn.BackgroundColor3=Color3.fromRGB(45,130,70)
bugBtn.Font=Enum.Font.GothamBlack
bugBtn.TextSize=11
Instance.new("UICorner",bugBtn).CornerRadius=UDim.new(0,8)

local resumeBtn=Instance.new("TextButton",frame)
resumeBtn.Size=UDim2.new(0,86,0,26)
resumeBtn.Position=UDim2.new(0,154,1,-34)
resumeBtn.Text="RESUME"
resumeBtn.TextColor3=Color3.new(1,1,1)
resumeBtn.BackgroundColor3=Color3.fromRGB(85,70,160)
resumeBtn.Font=Enum.Font.GothamBlack
resumeBtn.TextSize=11
Instance.new("UICorner",resumeBtn).CornerRadius=UDim.new(0,8)

local stopBtn=Instance.new("TextButton",frame)
stopBtn.Size=UDim2.new(0,74,0,26)
stopBtn.Position=UDim2.new(1,-88,1,-34)
stopBtn.Text="STOP"
stopBtn.TextColor3=Color3.new(1,1,1)
stopBtn.BackgroundColor3=Color3.fromRGB(125,35,48)
stopBtn.Font=Enum.Font.GothamBlack
stopBtn.TextSize=12
Instance.new("UICorner",stopBtn).CornerRadius=UDim.new(0,8)

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
	status.Text="Карточка = умный маршрут: камень → дорожки → GO BUG."
end


local function pathOf(obj)
	local parts={}
	local p=obj
	while p and p~=game do
		table.insert(parts,1,p.Name)
		p=p.Parent
	end
	return table.concat(parts,"/")
end

local function calibrateTreadmills()
	if running then
		status.Text="Сначала STOP."
		return
	end

	running=true
	_G.PetAlignStop=false

	local rarity=current and current.rarity or RAR_CHOICES[rarityIndex]
	if rarity=="Auto" or not BASE[rarity] then
		rarity="Unique"
	end

	local pet=selectedPet()
	local firstTotal,source=getPetTotalAny(pet,rarity)
	if not firstTotal then
		status.Text="CAL: открой окно питомца с уровнем/XP или задай _G.SelectedPet."
		running=false
		return
	end

	local list=uniqueTreadmillModels()
	if #list==0 then
		status.Text="CAL: не нашёл Treadmills."
		running=false
		return
	end

	local seconds=_G.PetAlignCalibrateSeconds or 5.0
	local results={}
	local oldReverse=_G.PetAlignReverseRun

	status.Text="CAL ALL: источник XP: "..tostring(source).." • дорожек "..#list

	for i,it in ipairs(list)do
		if _G.PetAlignStop then break end

		local before,sourceBefore=getPetTotalAny(pet,rarity)
		local snapBefore=numericSnapshot()
		status.Text="CAL ALL #"..i.."/"..#list.." старт="..fmt(before or 0)

		runOnTreadmill(it.part,seconds,pet,rarity,nil)
		task.wait(0.35)

		local after,sourceAfter=getPetTotalAny(pet,rarity)
		local snapAfter=numericSnapshot()
		local delta,directSource,changes=chooseDirectDelta(before,after,snapBefore,snapAfter)

		table.insert(results,{
			index=i,
			path=pathOf(it.model),
			part=pathOf(it.part),
			partObj=it.part,
			delta=round(delta),
			perSec=delta/seconds,
			before=before,
			after=after,
			sourceBefore=sourceBefore,
			sourceAfter=sourceAfter,
			directSource=directSource,
			changes=changes,
			x=it.pos.X,
			y=it.pos.Y,
			z=it.pos.Z
		})

		status.Text="CAL ALL #"..i.." direct +"..fmt(delta)
		task.wait(0.35)
	end

	local sorted={}
	for _,r in ipairs(results)do table.insert(sorted,r)end
	table.sort(sorted,function(a,b)
		if a.delta~=b.delta then return a.delta<b.delta end
		return a.index<b.index
	end)

	local hasPositive=false
	for _,r in ipairs(results)do
		if r.delta>0 then hasPositive=true end
	end

	local map={}
	local partsMap={}
	if hasPositive then
		for gain=1,6 do
			local best=nil
			for _,r in ipairs(results)do
				if r.delta==gain then
					best=r
					break
				end
			end
			if best then
				map[gain]=best.index
				partsMap[gain]=best.partObj
			else
				map[gain]="?"
			end
		end
	else
		for gain=1,6 do
			map[gain]="?"
		end
	end

	if hasPositive then
		_G.PetAlignTreadmillIndex=map
		_G.PetAlignTreadmillParts=partsMap
	end

	local lines={}
	table.insert(lines,"PetAlignHub treadmill calibration v24 ALL DIRECT")
	table.insert(lines,"place: "..tostring(game.PlaceId))
	table.insert(lines,"rarity used: "..tostring(rarity))
	table.insert(lines,"xp source: "..tostring(source or "unknown"))
	table.insert(lines,"seconds per treadmill: "..tostring(seconds))
	table.insert(lines,"tested ALL treadmills found in Workspace/Treadmills")
	table.insert(lines,"positive deltas found: "..tostring(hasPositive))
	table.insert(lines,"")
	table.insert(lines,"Suggested map:")
	local mapParts={}
	for gain=1,6 do
		table.insert(mapParts,"["..gain.."]="..tostring(map[gain] or "?"))
	end
	table.insert(lines,"_G.PetAlignTreadmillIndex={"..table.concat(mapParts,", ").."}")
	table.insert(lines,"")
	table.insert(lines,"Raw tested order:")
	for _,r in ipairs(results)do
		table.insert(lines,("#%02d testedIndex=%s directDelta=%s perSec=%.2f pos=(%.1f, %.1f, %.1f)"):format(r.index,r.index,fmt(r.delta),r.perSec,r.x,r.y,r.z))
		table.insert(lines,"model="..r.path)
		table.insert(lines,"part="..r.part)
		table.insert(lines,"totalBefore="..tostring(r.before).." totalAfter="..tostring(r.after).." source="..tostring(r.sourceBefore).."/"..tostring(r.sourceAfter))
		table.insert(lines,"directSource="..tostring(r.directSource))
		if r.changes and #r.changes>0 then
			table.insert(lines,"topChanges:")
			for ci=1,math.min(5,#r.changes)do
				local ch=r.changes[ci]
				table.insert(lines,("  delta=%s before=%s after=%s key=%s"):format(fmt(ch.delta),tostring(ch.before),tostring(ch.after),ch.key))
			end
		end
		table.insert(lines,"")
	end
	table.insert(lines,"Sorted by directDelta:")
	for rank,r in ipairs(sorted)do
		table.insert(lines,("#%02d testedIndex=%s directDelta=%s perSec=%.2f"):format(rank,r.index,fmt(r.delta),r.perSec))
	end

	local report=table.concat(lines,"\n")
	_G.PetAlignCalibrateReport=report
	if setclipboard then
		pcall(setclipboard,report)
	end

	status.Text="CAL ALL готов. Отчёт скопирован."
	running=false
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
	-- один заход на дорожку + прямой постоянный бег.
	local target=_G.PetAlignSegmentTarget or _G.PetAlignTargetTotal
	local seconds=math.max(8,count*(_G.PetAlignTreadmillGainSeconds or 5.0)*2.2)
	status.Text="Бег +"..gain..fallbackInfo.." ×"..count.." до XP "..fmt(target or 0)
	runOnTreadmill(part,seconds,_G.PetAlignCurrentPet,_G.PetAlignCurrentRarity,target)
	return true
end

local ROCK_EXACT={
	AncientJungle={"ancient jungle rock","ancient jungle","древний лес","древний камень","камень древнего леса"},
	MuscleKing={"muscle king rock","muscle king","king rock","король мышц","камень короля"},
	Legends={"legends rock","legend rock","legends","legend","камень легенд","легендарный камень"},
	Inferno={"inferno rock","inferno","инферно камень","камень инферно","инферно"},
	Mystic={"mystic rock","mystic","мистический камень","мистик"},
	Frozen={"frozen rock","ice rock","frost rock","frozen","ледяной камень","замороженный камень"},
	Golden={"golden rock","gold rock","golden","золотой камень"},
	Large={"large rock","big rock","large","большой камень","большая скала"},
	Punching={"punching rock","punch rock","punching","камень для ударов","ударный камень"},
	Tiny={"tiny rock","small rock","tiny","малый камень","маленький камень"},
}

local ROCK_BAD_WORDS={
	"tread","treadmill","дорож","бег",
	"throw","throwing","брос","launch","catapult",
	"trainer","тренаж","training","machine","машин",
	"weight","barbell","dumbbell","bench","lift",
	"agility","speed","jump","chest","egg","pet","aura",
}

local function hasBadRockWord(txt)
	txt=tostring(txt or ""):lower()
	for _,w in ipairs(ROCK_BAD_WORDS)do
		if txt:find(w,1,true)then return true end
	end
	return false
end

local function lightPath(obj,depth)
	local parts={}
	local p=obj
	local n=0
	while p and p~=game and n<(depth or 5)do
		table.insert(parts,1,p.Name)
		p=p.Parent
		n+=1
	end
	return table.concat(parts,"/")
end

local function nameMatch(txt,names)
	txt=tostring(txt or ""):lower()
	for _,name in ipairs(names or {})do
		if txt:find(tostring(name):lower(),1,true)then return true end
	end
	return false
end

local function chooseLargestPartNear(modelOrObj,nearPos)
	local best=nil
	local bestScore=-math.huge
	local checked=0

	local function consider(p)
		if not p or not p:IsA("BasePart")then return end
		checked+=1
		if checked>350 then return end
		local s=p.Size.X*p.Size.Y*p.Size.Z
		local d=nearPos and (p.Position-nearPos).Magnitude or 0
		local score=s-d*1.2
		if p.Anchored then score+=80 end
		if score>bestScore then
			bestScore=score
			best=p
		end
	end

	if modelOrObj:IsA("BasePart")then consider(modelOrObj)end
	for _,d in ipairs(modelOrObj:GetDescendants())do
		consider(d)
		if checked>350 then break end
	end

	return best
end

local function findRockPart(rockId)
	_G.PetAlignRockCache=_G.PetAlignRockCache or {}
	if _G.PetAlignRockCache[rockId] and _G.PetAlignRockCache[rockId].Parent then
		return _G.PetAlignRockCache[rockId]
	end

	local names=ROCK_EXACT[rockId] or {}
	local keys=nil
	for _,r in ipairs(ROCKS)do
		if r.id==rockId then keys=r.keys break end
	end
	if not keys then return nil end

	local hrp=root()
	local best=nil
	local bestScore=-math.huge
	local scanned=0
	local limit=_G.PetAlignRockScanLimit or 3500

	for _,obj in ipairs(workspace:GetDescendants())do
		scanned+=1
		if scanned%180==0 then task.wait() end
		if scanned>limit then break end

		local txt=""
		local labelHit=false
		local part=nil
		local model=nil

		if obj:IsA("TextLabel")or obj:IsA("TextButton")or obj:IsA("TextBox")then
			local t=tostring(obj.Text or "")
			if nameMatch(t,names) and not hasBadRockWord(t)then
				labelHit=true
				local gui=obj:FindFirstAncestorWhichIsA("BillboardGui") or obj:FindFirstAncestorWhichIsA("SurfaceGui")
				local adornee=gui and gui.Adornee
				if adornee and adornee:IsA("BasePart")then
					part=adornee
					model=adornee:FindFirstAncestorWhichIsA("Model") or adornee
				else
					local parent=gui and gui.Parent or obj.Parent
					model=parent and (parent:FindFirstAncestorWhichIsA("Model") or parent)
					if model then part=chooseLargestPartNear(model,hrp and hrp.Position or nil)end
				end
				txt=t:lower().." "..lightPath(part or model or obj,6):lower()
			end
		elseif obj:IsA("BasePart")then
			part=obj
			model=obj:FindFirstAncestorWhichIsA("Model") or obj
			txt=(obj.Name.." "..lightPath(obj,6).." "..(model and model.Name or "")):lower()
		elseif obj:IsA("Model")then
			model=obj
			txt=(obj.Name.." "..lightPath(obj,6)):lower()
			if not hasBadRockWord(txt) and (nameMatch(txt,names) or nameMatch(txt,keys) or txt:find("rock",1,true) or txt:find("камень",1,true))then
				part=chooseLargestPartNear(obj,hrp and hrp.Position or nil)
			end
		end

		if part and txt~="" and not hasBadRockWord(txt)then
			local score=0
			if labelHit then score+=600 end
			if nameMatch(txt,names)then score+=260 end
			if nameMatch(txt,keys)then score+=80 end
			if txt:find("rock",1,true)or txt:find("rocks",1,true)then score+=120 end
			if txt:find("камень",1,true)or txt:find("скал",1,true)then score+=120 end
			if txt:find("/rocks",1,true)or txt:find("rocks/",1,true)then score+=180 end
			if part.Anchored then score+=35 else score-=80 end
			if hrp then score-=math.clamp((part.Position-hrp.Position).Magnitude/600,0,50)end

			if score>bestScore then
				bestScore=score
				best=part
			end
		end
	end

	if best and bestScore>120 then
		_G.PetAlignRockCache[rockId]=best
		return best
	end

	return nil
end

local function equipHitTool()
	local c=lp.Character or lp.CharacterAdded:Wait()
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if not c or not hum then return nil end

	local existing=c:FindFirstChildWhichIsA("Tool")
	if existing then return existing end

	local bp=lp:FindFirstChild("Backpack")
	if not bp then return nil end

	local best=nil
	for _,t in ipairs(bp:GetChildren())do
		if t:IsA("Tool")then
			local n=t.Name:lower()
			if n:find("punch",1,true)or n:find("fist",1,true)or n:find("hit",1,true)or n:find("удар",1,true)or n:find("кулак",1,true)then
				best=t
				break
			end
			best=best or t
		end
	end

	if best then
		pcall(function() hum:EquipTool(best) end)
		task.wait(.15)
	end
	return best
end

local function rockCFrame(part)
	local c=lp.Character or lp.CharacterAdded:Wait()
	local r=root()
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")

	local dir
	if r then
		dir=Vector3.new(r.Position.X-part.Position.X,0,r.Position.Z-part.Position.Z)
	end
	if not dir or dir.Magnitude<0.1 then
		dir=Vector3.new(part.CFrame.LookVector.X,0,part.CFrame.LookVector.Z)
	end
	if dir.Magnitude<0.1 then dir=Vector3.new(0,0,-1) end
	dir=dir.Unit

	local radius=math.max(part.Size.X,part.Size.Z)/2
	local dist=radius+(_G.PetAlignRockSideDistance or 5.2)
	local y=part.Position.Y + part.Size.Y/2 + math.clamp((hum and hum.HipHeight or 2)+1.25,2.8,4.5)
	local pos=Vector3.new(part.Position.X,0,part.Position.Z)+dir*dist
	pos=Vector3.new(pos.X,y,pos.Z)

	return CFrame.lookAt(pos,Vector3.new(part.Position.X,y,part.Position.Z))
end

local function touchAndActivate(part,tool)
	pcall(function() touchPart(part) end)
	if tool and tool.Parent then
		pcall(function() tool:Activate() end)
	end
end

local function hitRock(rockId)
	if _G.PetAPI and _G.PetAPI.HitRock then
		status.Text="PetAPI: бью камень "..rockId
		local ok=pcall(_G.PetAPI.HitRock,rockId)
		if ok then return true end
	end

	local part=findRockPart(rockId)
	if part then
		local r=root()
		if r then r.CFrame=rockCFrame(part) end
		local tool=equipHitTool()
		touchAndActivate(part,tool)
		status.Text="Готов к багу: "..rockId
		return true
	end

	local n=copyScanReport("не нашёл камень", "rock", rockId)
	status.Text="Камень не найден. Скан скопирован в буфер ("..n.." кандидатов). Пришли его мне."
	return false
end

local bugRunning=false

local function doPreRockHits(route,pet,rarity,targetTotal)
	if not route or not route.rock or route.rockHits<=0 then return true end

	local rockId=route.rock.id
	local part=findRockPart(rockId)
	if not part then
		local n=copyScanReport("не нашёл камень", "rock", rockId)
		status.Text="Скалу для ускорения не нашёл, пропускаю камень. Скан скопирован ("..n..")."
		task.wait(.6)
		return true,0
	end

	local c=lp.Character or lp.CharacterAdded:Wait()
	local r=root()
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	local oldAuto=hum and hum.AutoRotate
	local oldSpeed=hum and hum.WalkSpeed
	local oldAnchored=r and r.Anchored

	local fixed=rockCFrame(part)

	-- Один телепорт к скале, дальше фиксируем позицию, но НЕ телепаем по КД.
	if r then
		r.CFrame=fixed
		r.AssemblyLinearVelocity=Vector3.zero
		r.AssemblyAngularVelocity=Vector3.zero
		if _G.PetAlignBugAnchor then r.Anchored=true end
	end
	if hum then
		hum.AutoRotate=false
		hum.WalkSpeed=0
		hum:Move(Vector3.zero,false)
	end

	local tool=equipHitTool()
	local hits=0
	local maxHits=route.rockHits+(_G.PetAlignPreRockExtraHits or 3)

	while not _G.PetAlignStop and hits<maxHits do
		local now=getPetTotalAny(pet,rarity)
		if now and now>=targetTotal then break end

		hits+=1
		status.Text="Скала до ровного XP: "..route.rock.label.." "..hits.."/"..route.rockHits
		touchAndActivate(part,tool)

		task.wait(_G.PetAlignPreRockHitDelay or .55)

		now=getPetTotalAny(pet,rarity)
		if now and now>=targetTotal then break end
	end

	if r and _G.PetAlignBugAnchor then r.Anchored=oldAnchored end
	if hum then
		hum.AutoRotate=oldAuto
		hum.WalkSpeed=oldSpeed
	end

	task.wait(.15)
	return true,hits
end


local function runBugHit(resume)
	if bugRunning then return end

	local data=_G.PetAlignReadyBug or current
	if not data then
		status.Text="Сначала выбери баг/ровнение."
		return
	end

	bugRunning=true
	running=true
	_G.PetAlignStop=false
	_G.PetAlignBugStop=false

	status.Text="Ищу скалу "..tostring(data.rockLabel or data.rock).."..."
	local part=findRockPart(data.rock)
	if not part then
		status.Text="Скала не найдена. Нужен CAL/скрин/скан отдельно, чтобы не фризить."
		bugRunning=false
		running=false
		return
	end

	local c=lp.Character or lp.CharacterAdded:Wait()
	local r=root()
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	local oldAuto=hum and hum.AutoRotate
	local oldSpeed=hum and hum.WalkSpeed
	local oldAnchored=r and r.Anchored

	local fixed=rockCFrame(part)
	if r then
		r.CFrame=fixed
		r.AssemblyLinearVelocity=Vector3.zero
		r.AssemblyAngularVelocity=Vector3.zero
		if _G.PetAlignBugAnchor then
			if _G.PetAlignBugAnchor then r.Anchored=true end
		end
	end
	if hum then
		hum.AutoRotate=false
		hum.WalkSpeed=0
		hum:Move(Vector3.zero,false)
	end

	local tool=equipHitTool()
	local seconds=_G.PetAlignBugHitSeconds or 2.5
	local delayTime=_G.PetAlignBugHitDelay or .35
	local started=os.clock()
	local hits=0

	status.Text=(resume and "RESUME BUG: " or "GO BUG: ")..tostring(data.rockLabel or data.rock)

	while not _G.PetAlignStop and not _G.PetAlignBugStop and os.clock()-started<seconds do
		hits+=1
		status.Text="BUG hit "..hits.." → "..tostring(data.rockLabel or data.rock)
		touchAndActivate(part,tool)
		task.wait(delayTime)
	end

	if r and _G.PetAlignBugAnchor then
		r.Anchored=oldAnchored
	end
	if hum then
		hum.AutoRotate=oldAuto
		hum.WalkSpeed=oldSpeed
	end

	status.Text="Баг-удар закончен. RESUME = повторить, STOP = стоп."
	bugRunning=false
	running=false
end


local function runAlign()
	if running or not current then return end
	running=true
	_G.PetAlignStop=false
	_G.PetAlignBugStop=false
	confirm.Visible=false

	local has=hasPet(current.rarity)
	if has==false then status.Text="У тебя нет "..current.rarity.." pet." running=false return end
	selectPet(current.rarity)

	local pet=selectedPet()
	local reb=parseNum(rebBox.Text) or 0

	if _G.PetAPI and _G.PetAPI.SetPetXP then
		status.Text="Выставляю XP через PetAPI..."
		pcall(_G.PetAPI.SetPetXP,pet,current.setLvl,current.setXp,current.startTotal)
		task.wait(.25)
		_G.PetAlignReadyBug=current
		status.Text="Ровно. Нажми GO BUG для камня: "..current.rockLabel
		running=false
		return
	end

	local now,source=getPetTotalAny(pet,current.rarity)
	if not now then
		now=0
		status.Text="XP не прочитан. Ровняю как с 1 lvl 0 XP."
		task.wait(.6)
	else
		status.Text="XP прочитан: "..fmt(now).." ("..tostring(source)..")"
		task.wait(.25)
	end

	if now>=current.startTotal then
		_G.PetAlignReadyBug=current
		status.Text="Уже ровно/выше цели. Нажми GO BUG."
		running=false
		return
	end

	local route,err=smartAlignPlan(current.startTotal-now,reb)
	if err then status.Text=err running=false return end

	if route and route.rock and not findRockPart(route.rock.id)then
		status.Text="Скалу "..route.rock.label.." не нашёл, иду только дорожками."
		route.rock=nil
		route.rockHits=0
		route.rockXp=0
		route.treadPlan=makePlan(current.startTotal-now)
		task.wait(.6)
	end

	status.Text="Маршрут: скала если быстрее → дорожки: "..smartPlanText(route)
	_G.PetAlignStop=false
	_G.PetAlignCurrentPet=pet
	_G.PetAlignCurrentRarity=current.rarity
	_G.PetAlignTargetTotal=current.startTotal
	task.wait(.25)

	-- Если быстрее сначала камень — бьём камень, потом пересчитываем остаток.
	if route.rock and route.rockHits>0 then
		local ok=doPreRockHits(route,pet,current.rarity,current.startTotal)
		if not ok then running=false return end
	end

	local nowAfterRock=getPetTotalAny(pet,current.rarity) or now
	if nowAfterRock>=current.startTotal then
		_G.PetAlignReadyBug=current
		status.Text="Ровно после камня. Нажми GO BUG → "..current.rockLabel
		running=false
		return
	end

	local treadPlan,err2=makePlan(current.startTotal-nowAfterRock)
	if err2 then status.Text=err2 running=false return end

	status.Text="Добиваю дорожками до нужного XP: "..planText(treadPlan)

	for _,p in ipairs(treadPlan)do
		if _G.PetAlignStop then status.Text="Остановлено." running=false return end

		local nowCheck=getPetTotalAny(pet,current.rarity)
		if nowCheck and nowCheck>=current.startTotal then
			break
		end

		if nowCheck then
			_G.PetAlignSegmentTarget=math.min(current.startTotal,nowCheck+p.gain*p.count)
		else
			_G.PetAlignSegmentTarget=current.startTotal
		end

		local ok=useTreadmill(p.gain,p.count)
		_G.PetAlignSegmentTarget=nil
		if not ok then running=false return end

		nowCheck=getPetTotalAny(pet,current.rarity)
		if nowCheck and nowCheck>=current.startTotal then
			break
		end
	end

	local finalTotal=getPetTotalAny(pet,current.rarity)
	if finalTotal and finalTotal<current.startTotal then
		status.Text="Не добрал XP: "..fmt(finalTotal).."/"..fmt(current.startTotal)..". Нажми карточку ещё раз."
		running=false
		return
	end

	if pet then
		setNumber(pet,{"Level","Lvl","level","lvl"},current.setLvl)
		setNumber(pet,{"XP","Exp","Experience","xp"},current.setXp)
		setNumber(pet,{"TotalXP","TotalExp","totalXP"},current.startTotal)
	end

	_G.PetAlignReadyBug=current
	status.Text="Ровно. Нажми GO BUG → "..current.rockLabel
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
	q.Text="Запустить ровнение для "..current.rarity.." pet?\nЦель: "..fmt(current.setLvl).." lvl, "..fmt(current.setXp).." XP"
	confirm.Visible=true
end)

no.MouseButton1Click:Connect(function()
	confirm.Visible=false
	status.Text="Отменено."
end)

yes.MouseButton1Click:Connect(function()
	status.Text="Запуск ровнения..."
	task.spawn(function()
		local ok,err=pcall(runAlign)
		if not ok then
			status.Text="Ошибка ровнения: "..tostring(err):sub(1,120)
			running=false
			_G.PetAlignStop=true
		end
	end)
end)


calBtn.MouseButton1Click:Connect(function()
	task.spawn(calibrateTreadmills)
end)

bugBtn.MouseButton1Click:Connect(function()
	task.spawn(function() runBugHit(false) end)
end)

resumeBtn.MouseButton1Click:Connect(function()
	task.spawn(function() runBugHit(true) end)
end)

stopBtn.MouseButton1Click:Connect(function()
	_G.PetAlignStop=true
	_G.PetAlignBugStop=true
	running=false
	status.Text="Остановлено."
end)

local d=detectRebirths()
if d then rebBox.Text=tostring(d) end
render()
