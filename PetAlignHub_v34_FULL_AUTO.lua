-- PetAlignHub v34_FULL_AUTO
-- Полная прога: расчёт -> выравнивание дорожками -> автотелепорт к нужной скале -> удар бага.
-- Камни ищутся НЕ по словам, а по neededDurability + LeftHand/RightHand.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local lp=Players.LocalPlayer

local BASE={Basic=250,Uncommon=500,Rare=750,Epic=1000,Unique=1250}
local STAT={Basic=1,Uncommon=2,Rare=3,Epic=4,Unique=5}
local RAR_ORDER={"Unique","Epic","Rare","Uncommon","Basic"}
local RAR_CHOICES={"Auto","Unique","Epic","Rare","Uncommon","Basic"}

local ROCKS={
{id="AncientJungle",label="Древний лес",value=16.25},
{id="MuscleKing",label="Король мышц",value=12.5},
{id="Legends",label="Легенды",value=2.5},
{id="Inferno",label="Инферно",value=1.125},
{id="Mystic",label="Мистический",value=.75},
{id="Frozen",label="Ледяной",value=.375},
{id="Golden",label="Золотой",value=.2},
{id="Large",label="Большой камень",value=.075},
{id="Punching",label="Пробивной камень",value=.05},
{id="Tiny",label="Маленький камень",value=.025},
}

-- Из твоей калибровки: 5 секунд на дорожке = +gain XP.
local TREAD_INDEX={[1]=36,[2]=33,[3]=31,[4]=29,[5]=28,[6]=26}
local TREAD_SECONDS=5.0

-- Камни Muscle Legends через neededDurability.
local ROCK_REQ={
	Tiny=0,
	Punching=10,
	Large=100,
	Golden=5000,
	Frozen=150000,
	Mystic=400000,
	Inferno=750000,
	Legends=1000000,
	MuscleKing=5000000,
	AncientJungle=10000000,
}

local REQ_LABEL={
	[0]="Tiny Island Rock",
	[10]="Punching Rock",
	[100]="Large Rock",
	[5000]="Golden Rock",
	[150000]="Frost/Frozen Rock",
	[400000]="Mystic/Mythical Rock",
	[750000]="Inferno/Eternal Rock",
	[1000000]="Legends Rock",
	[5000000]="Muscle King Rock",
	[10000000]="Ancient Jungle Rock",
}

local running=false
local rarityIndex=1
local current=nil
local lastReport=""
local rockRowsCache=nil
local rockLockConn=nil
local rockLockedCF=nil
local rockOldSpeed=nil
local rockOldAuto=nil

_G.PetAlignStop=false

local status=nil
local outText=nil
local outFrame=nil

local function statusText(t)
	if status then status.Text=tostring(t or "") end
end

local function round(x)return math.floor((tonumber(x)or 0)+.5)end
local function whole(x)return math.abs(x-round(x))<1e-9 end

local function fmt(n)
	n=tonumber(n)or 0
	local s=tostring(math.floor(n))
	local rev=s:reverse():gsub("(%d%d%d)","%1 "):reverse():gsub("^ ","")
	return rev
end

local function parseNum(s)
	s=tostring(s or ""):lower():gsub(",","."):gsub("%s+","")
	local mult=1
	if s:find("k",1,true)then mult=1e3 s=s:gsub("k","")end
	if s:find("m",1,true)then mult=1e6 s=s:gsub("m","")end
	if s:find("b",1,true)then mult=1e9 s=s:gsub("b","")end
	local n=tonumber(s:match("[%d%.]+"))
	return n and n*mult or nil
end

local function root()
	local c=lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function lvlCap(base,lvl)return base*lvl end
local function cum(base,lvl)return base*lvl*(lvl+1)/2 end
local function totalFrom(base,lvl,xp)return cum(base,lvl-1)+(xp or 0)end

local function levelFromTotal(base,total)
	total=math.max(0,round(total))
	local lvl=1
	while total>=lvlCap(base,lvl) do
		total-=lvlCap(base,lvl)
		lvl+=1
		if lvl>1000 then break end
	end
	return lvl,total
end

local function pathOf(obj)
	local parts={}
	local p=obj
	local n=0
	while p and p~=game and n<18 do
		table.insert(parts,1,p.Name)
		p=p.Parent
		n+=1
	end
	return table.concat(parts,"/")
end

local function selectedPet()
	if _G.PetAPI and _G.PetAPI.GetSelectedPet then
		local ok,res=pcall(_G.PetAPI.GetSelectedPet)
		if ok and res then return res end
	end
	return _G.SelectedPet or _G.Pet
end

local function readNumber(obj,names)
	if not obj then return nil end
	for _,n in ipairs(names)do
		local v=obj[n]
		if type(v)=="number"then return v end
		if typeof(v)=="Instance"and(v:IsA("NumberValue")or v:IsA("IntValue"))then return v.Value end
	end
	for _,d in ipairs(obj:GetDescendants())do
		for _,n in ipairs(names)do
			if d.Name==n then
				if d:IsA("NumberValue")or d:IsA("IntValue")then return d.Value end
				if d:IsA("StringValue")then return parseNum(d.Value)end
			end
		end
	end
	return nil
end

local function setNumber(obj,names,val)
	if not obj then return false end
	for _,n in ipairs(names)do
		local v=obj[n]
		if typeof(v)=="Instance"and(v:IsA("NumberValue")or v:IsA("IntValue"))then
			v.Value=val
			return true
		end
	end
	for _,d in ipairs(obj:GetDescendants())do
		for _,n in ipairs(names)do
			if d.Name==n and(d:IsA("NumberValue")or d:IsA("IntValue"))then
				d.Value=val
				return true
			end
		end
	end
	return false
end

local function parsePetGuiTotal(rarity)
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg or not BASE[rarity]then return nil end

	local lvl=nil
	local xp=nil

	for _,v in ipairs(pg:GetDescendants())do
		if v:IsA("TextLabel")or v:IsA("TextButton")or v:IsA("TextBox")then
			local txt=tostring(v.Text or "")
			local low=txt:lower()

			local lv=low:match("уровень%s*(%d+)")or low:match("level%s*(%d+)")or low:match("lvl%s*(%d+)")
			if lv then lvl=tonumber(lv)end

			local a,b=low:match("([%d%s%.%,]+)%s*/%s*([%d%s%.%,]+)")
			if a and b and(low:find("опыт",1,true)or low:find("xp",1,true)or low:find("exp",1,true))then
				xp=parseNum(a)
			end
		end
	end

	if lvl and xp then return totalFrom(BASE[rarity],lvl,xp),"gui",lvl,xp end
	return nil,nil
end

local function getPetTotalAny(rarity)
	local pet=selectedPet()
	if pet then
		local total=readNumber(pet,{"TotalXP","TotalExp","totalXP","totalExp"})
		if total then return total,"data",nil,nil end

		local lvl=readNumber(pet,{"Level","Lvl","level","lvl"})
		local xp=readNumber(pet,{"XP","Exp","Experience","xp"})
		if lvl and xp then return totalFrom(BASE[rarity],lvl,xp),"data",lvl,xp end
	end

	return parsePetGuiTotal(rarity)
end

local function bestForHit(rawHit,rarity,rock)
	if not whole(rawHit)then return nil end
	local base,stat=BASE[rarity],STAT[rarity]
	local hit=round(rawHit)
	local best=nil

	for endLvl=1,40 do
		local endTotal=cum(base,endLvl)
		local startTotal=endTotal-hit
		if startTotal>=0 then
			local sl,sx=levelFromTotal(base,startTotal)
			local cross=endLvl-sl+1
			if cross>=1 then
				local cand={
					rarity=rarity,
					rock=rock.id,
					rockLabel=rock.label,
					rockValue=rock.value,
					hit=hit,
					setLvl=sl,
					setXp=sx,
					startTotal=startTotal,
					capLvl=endLvl,
					endTotal=endTotal,
					bonus=cross*stat,
					crossed=cross,
					stat=stat,
				}
				if not best or cand.bonus>best.bonus or(cand.bonus==best.bonus and cand.startTotal<best.startTotal)then
					best=cand
				end
			end
		end
	end

	return best
end

local function allCandidates(reb,filter)
	local rows={}
	for _,rarity in ipairs(RAR_ORDER)do
		if filter=="Auto"or filter==rarity then
			for _,rock in ipairs(ROCKS)do
				local hit=(reb+20)*rock.value
				local cand=bestForHit(hit,rarity,rock)
				if cand then table.insert(rows,cand)end
			end
		end
	end

	table.sort(rows,function(a,b)
		if a.bonus~=b.bonus then return a.bonus>b.bonus end
		if a.stat~=b.stat then return a.stat>b.stat end
		if a.hit~=b.hit then return a.hit>b.hit end
		return a.startTotal<b.startTotal
	end)

	return rows
end

local function makePlan(diff)
	diff=round(diff)
	if diff<0 then return nil,"выше цели на "..fmt(math.abs(diff)).." XP"end
	local plan={}
	for g=6,1,-1 do
		local c=math.floor(diff/g)
		if c>0 then
			table.insert(plan,{gain=g,count=c})
			diff-=c*g
		end
	end
	return plan,nil
end

local function planText(plan)
	if not plan or #plan==0 then return "уже ровно"end
	local t={}
	for _,p in ipairs(plan)do table.insert(t,"+"..p.gain.."×"..p.count)end
	return table.concat(t,"  ")
end

local function planSeconds(plan)
	local s=0
	if plan then
		for _,p in ipairs(plan)do s+=p.count*TREAD_SECONDS end
	end
	return s
end

local function chooseCandidate(reb,filter,now)
	local rows=allCandidates(reb,filter)
	if #rows==0 then return nil,rows end

	if now then
		for _,r in ipairs(rows)do
			if r.startTotal>=now then
				return r,rows
			end
		end
	end

	return rows[1],rows
end

local function biggestPart(obj)
	if not obj then return nil end
	if obj:IsA("BasePart")then return obj end
	local best=nil
	local vol=-1
	for _,d in ipairs(obj:GetDescendants())do
		if d:IsA("BasePart")then
			local v=d.Size.X*d.Size.Y*d.Size.Z
			if v>vol then
				vol=v
				best=d
			end
		end
	end
	return best
end

local function valOf(v)
	if not v then return nil end
	if v:IsA("IntValue")or v:IsA("NumberValue")then return tonumber(v.Value)end
	if v:IsA("StringValue")then return tonumber(v.Value)end
	local ok,res=pcall(function()return tonumber(v.Value)end)
	return ok and res or nil
end

local function rockModelFromNeeded(v)
	local p=v.Parent
	for _=1,6 do
		if not p or p==workspace then break end
		local lh=p:FindFirstChild("LeftHand",true)
		local rh=p:FindFirstChild("RightHand",true)
		if lh and rh then return p,lh,rh end
		p=p.Parent
	end
	return v.Parent,nil,nil
end

local function scanNeededRocks()
	local rows={}
	local seen={}
	local hrp=root()
	local scanned=0

	for _,v in ipairs(workspace:GetDescendants())do
		scanned+=1
		if scanned%500==0 then task.wait()end

		if v.Name=="neededDurability"then
			local req=valOf(v)
			if req then
				local model,lh,rh=rockModelFromNeeded(v)
				local key=model or v.Parent
				if key and not seen[key]then
					seen[key]=true
					local body=biggestPart(key)
					local hit=lh or rh or body
					if body and hit and body:IsA("BasePart")and hit:IsA("BasePart")then
						local dist=hrp and (body.Position-hrp.Position).Magnitude or 0
						table.insert(rows,{
							req=req,
							label=REQ_LABEL[req] or ("Unknown req "..tostring(req)),
							model=key,
							body=body,
							hit=hit,
							left=lh,
							right=rh,
							dist=dist,
						})
					end
				end
			end
		end
	end

	table.sort(rows,function(a,b)
		if a.req~=b.req then return a.req<b.req end
		return a.dist<b.dist
	end)

	return rows
end

local function getRockRow(rockId)
	local req=ROCK_REQ[rockId]
	if not req then return nil end

	if not rockRowsCache then
		statusText("Сканирую скалы...")
		rockRowsCache=scanNeededRocks()
	end

	for _,row in ipairs(rockRowsCache)do
		if row.req==req and row.body and row.body.Parent then
			return row
		end
	end

	rockRowsCache=scanNeededRocks()
	for _,row in ipairs(rockRowsCache)do
		if row.req==req and row.body and row.body.Parent then
			return row
		end
	end

	return nil
end

local function makeRockReport()
	local rows=scanNeededRocks()
	rockRowsCache=rows

	local lines={}
	table.insert(lines,"PetAlignHub v34 rock scan")
	table.insert(lines,"place: "..tostring(game.PlaceId))
	table.insert(lines,"count: "..tostring(#rows))
	table.insert(lines,"")

	for i,r in ipairs(rows)do
		local bp=r.body.Position
		local hp=r.hit.Position
		table.insert(lines,("#%02d req=%s label=%s"):format(i,tostring(r.req),tostring(r.label)))
		table.insert(lines,"model="..pathOf(r.model))
		table.insert(lines,"body="..pathOf(r.body))
		table.insert(lines,"hit="..pathOf(r.hit))
		table.insert(lines,("bodyPos=(%.1f, %.1f, %.1f) hitPos=(%.1f, %.1f, %.1f)"):format(bp.X,bp.Y,bp.Z,hp.X,hp.Y,hp.Z))
		table.insert(lines,"")
	end

	return table.concat(lines,"\n"),#rows
end

local function stopRockLock()
	if rockLockConn then
		rockLockConn:Disconnect()
		rockLockConn=nil
	end

	local c=lp.Character
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if hum then
		if rockOldSpeed~=nil then hum.WalkSpeed=rockOldSpeed end
		if rockOldAuto~=nil then hum.AutoRotate=rockOldAuto end
	end

	rockLockedCF=nil
	rockOldSpeed=nil
	rockOldAuto=nil
end

local function startRockLock(cf)
	stopRockLock()

	local rr=root()
	local c=lp.Character
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if not rr then return end

	rockLockedCF=cf
	if hum then
		rockOldSpeed=hum.WalkSpeed
		rockOldAuto=hum.AutoRotate
		hum.WalkSpeed=0
		hum.AutoRotate=false
		hum:Move(Vector3.zero,false)
	end

	rockLockConn=RunService.Heartbeat:Connect(function()
		local r=root()
		local cc=lp.Character
		local h=cc and cc:FindFirstChildWhichIsA("Humanoid")
		if not r or not rockLockedCF then return end

		r.CFrame=rockLockedCF
		r.AssemblyLinearVelocity=Vector3.zero
		r.AssemblyAngularVelocity=Vector3.zero
		if h then h:Move(Vector3.zero,false)end
	end)
end

local function rockCF(row)
	local rr=root()
	if not rr or not row or not row.body then return nil end

	local body=row.body
	local hit=row.hit

	local depth=_G.PetRockInsideDepth or 0.35
	local yMode=_G.PetRockYMode or "center"

	local dir=rr.Position-body.Position
	dir=Vector3.new(dir.X,0,dir.Z)
	if dir.Magnitude<0.1 then
		dir=Vector3.new(body.CFrame.LookVector.X,0,body.CFrame.LookVector.Z)
	end
	if dir.Magnitude<0.1 then dir=Vector3.new(0,0,-1)else dir=dir.Unit end

	local radius=math.max(body.Size.X,body.Size.Z)/2
	local insideDist=math.max(radius*depth,0.25)

	local y
	if yMode=="top"then
		y=body.Position.Y+body.Size.Y/2+1.2
	else
		y=body.Position.Y+math.clamp(body.Size.Y*0.18,0.4,2.2)
	end

	local pos=Vector3.new(body.Position.X,y,body.Position.Z)+dir*insideDist

	if hit and hit.Parent then
		local hp=hit.Position
		pos=pos:Lerp(Vector3.new(hp.X,y,hp.Z),0.25)
	end

	return CFrame.lookAt(pos,Vector3.new(body.Position.X,y,body.Position.Z))
end

local function goRock(row)
	local rr=root()
	local cf=rockCF(row)
	if not rr or not cf then return false end
	rr.CFrame=cf
	rr.AssemblyLinearVelocity=Vector3.zero
	rr.AssemblyAngularVelocity=Vector3.zero
	startRockLock(cf)
	return true
end

local function mainPart(m)
	if not m then return nil end
	if m:IsA("BasePart")then return m end
	local p=m:FindFirstChild("treadmillPart",true)or m:FindFirstChild("TreadmillPart",true)
	if p and p:IsA("BasePart")then return p end
	return biggestPart(m)
end

local function uniqueTreadmillModels()
	local holder=workspace:FindFirstChild("Treadmills")
	local list={}
	local seen={}

	local function addModel(m)
		if not m or seen[m]then return end
		local p=mainPart(m)
		if p then
			seen[m]=true
			table.insert(list,{model=m,part=p,pos=p.Position})
		end
	end

	if holder then
		for _,ch in ipairs(holder:GetChildren())do
			if ch:IsA("Model")or ch:IsA("BasePart")then addModel(ch)end
		end
	end

	if #list<=1 then return list end

	local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
	for _,it in ipairs(list)do
		minX=math.min(minX,it.pos.X); maxX=math.max(maxX,it.pos.X)
		minZ=math.min(minZ,it.pos.Z); maxZ=math.max(maxZ,it.pos.Z)
	end

	local axis=(maxX-minX)>=(maxZ-minZ)and"X"or"Z"
	table.sort(list,function(a,b)
		if math.abs(a.pos[axis]-b.pos[axis])>1 then return a.pos[axis]<b.pos[axis]end
		local other=axis=="X"and"Z"or"X"
		return a.pos[other]<b.pos[other]
	end)

	return list
end

local function treadmillPart(gain)
	local idx=TREAD_INDEX[gain]
	local list=uniqueTreadmillModels()
	if idx and list[idx]then return list[idx].part,idx,#list end
	return nil,idx,#list
end

local function runOnTreadmill(part,targetTotal,rarity)
	local c=lp.Character or lp.CharacterAdded:Wait()
	local r=root()
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if not r or not hum or not part then return false end

	local dir
	if part.Size.Z>=part.Size.X then dir=part.CFrame.LookVector else dir=part.CFrame.RightVector end
	dir=Vector3.new(dir.X,0,dir.Z)
	if dir.Magnitude<0.05 then dir=Vector3.new(0,0,-1)end
	dir=dir.Unit

	if _G.PetAlignReverseRun==nil then _G.PetAlignReverseRun=true end
	if _G.PetAlignReverseRun then dir=-dir end

	local speed=_G.PetAlignRunSpeed or 20
	local length=math.max(part.Size.X,part.Size.Z)
	local runOffset=math.clamp(length*.40,2.5,math.max(2.5,length/2-1.2))
	local up=part.CFrame.UpVector
	local heightAbove=_G.PetAlignHeightOffset or math.clamp((hum.HipHeight or 2)+1.15,2.75,4.15)
	local startPos=part.Position-dir*runOffset+up*(part.Size.Y/2+heightAbove)

	local oldSpeed=hum.WalkSpeed
	local oldAuto=hum.AutoRotate
	local oldJP=hum.JumpPower
	local oldJH=hum.JumpHeight

	hum.WalkSpeed=speed
	hum.AutoRotate=true
	pcall(function()hum.JumpPower=0 end)
	pcall(function()hum.JumpHeight=0 end)
	r.CFrame=CFrame.lookAt(startPos,startPos+dir)
	task.wait(.18)

	local started=os.clock()
	local maxRun=_G.PetAlignTreadmillMaxRunSeconds or 90
	local minRun=_G.PetAlignMinTreadmillRunSeconds or 2

	while not _G.PetAlignStop do
		local elapsed=os.clock()-started

		if elapsed>=minRun then
			local now=getPetTotalAny(rarity)
			if now and now>=targetTotal then break end
			if now then statusText("Бег: "..fmt(now).."/"..fmt(targetTotal))end
		end

		if elapsed>maxRun then break end

		hum:Move(dir,false)
		pcall(function()hum:ChangeState(Enum.HumanoidStateType.Running)end)
		RunService.Heartbeat:Wait()
	end

	hum:Move(Vector3.zero,false)
	hum.WalkSpeed=oldSpeed
	hum.AutoRotate=oldAuto
	pcall(function()hum.JumpPower=oldJP end)
	pcall(function()hum.JumpHeight=oldJH end)
	return true
end

local function touchPart(part)
	if not part then return end
	local r=root()
	if not r then return end
	pcall(function()
		firetouchinterest(r,part,0)
		task.wait(.03)
		firetouchinterest(r,part,1)
	end)
end

local function equipHitTool()
	local c=lp.Character or lp.CharacterAdded:Wait()
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if not hum then return nil end

	local tool=c:FindFirstChildWhichIsA("Tool")
	if tool then return tool end

	local bp=lp:FindFirstChild("Backpack")
	if not bp then return nil end

	for _,t in ipairs(bp:GetChildren())do
		if t:IsA("Tool")then
			pcall(function()hum:EquipTool(t)end)
			task.wait(.15)
			return t
		end
	end
	return nil
end

local function bugHit(data)
	local row=getRockRow(data.rock)
	if not row then
		statusText("Скала "..data.rockLabel.." не найдена. Жми SCAN.")
		return false
	end

	if not goRock(row)then
		statusText("Не смог тепнуться к скале.")
		return false
	end

	local tool=equipHitTool()
	local seconds=_G.PetAlignBugHitSeconds or 3.0
	local delay=_G.PetAlignBugHitDelay or .35
	local started=os.clock()
	local hits=0

	while not _G.PetAlignStop and os.clock()-started<seconds do
		hits+=1
		if row.hit and row.hit.Parent then touchPart(row.hit)end
		if row.body and row.body.Parent then touchPart(row.body)end
		if tool and tool.Parent then pcall(function()tool:Activate()end)end
		statusText("BUG hit "..hits.." → "..data.rockLabel)
		task.wait(delay)
	end

	stopRockLock()
	return true
end

-- UI
local gui=Instance.new("ScreenGui")
gui.Name="PetAlignFullAutoV34"
gui.ResetOnSpawn=false
gui.Parent=lp:WaitForChild("PlayerGui")

local frame=Instance.new("Frame",gui)
frame.Size=UDim2.new(0,390,0,330)
frame.Position=UDim2.new(.5,-195,.5,-165)
frame.BackgroundColor3=Color3.fromRGB(12,11,26)
frame.BorderSizePixel=0
frame.Active=true
frame.Draggable=true
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,14)
local stroke=Instance.new("UIStroke",frame)
stroke.Color=Color3.fromRGB(132,70,255)
stroke.Thickness=1.4

local title=Instance.new("TextLabel",frame)
title.Size=UDim2.new(1,-50,0,30)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="Pet Align FULL v34"
title.TextColor3=Color3.new(1,1,1)
title.Font=Enum.Font.GothamBlack
title.TextSize=17
title.TextXAlignment=Enum.TextXAlignment.Left

local close=Instance.new("TextButton",frame)
close.Size=UDim2.new(0,30,0,30)
close.Position=UDim2.new(1,-38,0,8)
close.Text="×"
close.TextColor3=Color3.fromRGB(255,180,190)
close.BackgroundColor3=Color3.fromRGB(62,20,34)
close.Font=Enum.Font.GothamBlack
close.TextSize=18
Instance.new("UICorner",close).CornerRadius=UDim.new(0,9)

local rebBox=Instance.new("TextBox",frame)
rebBox.Size=UDim2.new(0,216,0,34)
rebBox.Position=UDim2.new(0,12,0,46)
rebBox.Text=""
rebBox.PlaceholderText="ребы: 63.4k"
rebBox.ClearTextOnFocus=false
rebBox.TextColor3=Color3.new(1,1,1)
rebBox.PlaceholderColor3=Color3.fromRGB(155,145,185)
rebBox.BackgroundColor3=Color3.fromRGB(31,29,61)
rebBox.Font=Enum.Font.GothamBold
rebBox.TextSize=14
Instance.new("UICorner",rebBox).CornerRadius=UDim.new(0,10)

local rarityBtn=Instance.new("TextButton",frame)
rarityBtn.Size=UDim2.new(0,136,0,34)
rarityBtn.Position=UDim2.new(1,-148,0,46)
rarityBtn.Text="Auto"
rarityBtn.TextColor3=Color3.new(1,1,1)
rarityBtn.BackgroundColor3=Color3.fromRGB(62,50,120)
rarityBtn.Font=Enum.Font.GothamBlack
rarityBtn.TextSize=13
Instance.new("UICorner",rarityBtn).CornerRadius=UDim.new(0,10)

outFrame=Instance.new("ScrollingFrame",frame)
outFrame.Size=UDim2.new(1,-24,0,188)
outFrame.Position=UDim2.new(0,12,0,90)
outFrame.BackgroundColor3=Color3.fromRGB(18,45,35)
outFrame.BorderSizePixel=0
outFrame.CanvasSize=UDim2.new(0,0,0,520)
outFrame.ScrollBarThickness=4
Instance.new("UICorner",outFrame).CornerRadius=UDim.new(0,12)

outText=Instance.new("TextLabel",outFrame)
outText.Size=UDim2.new(1,-14,0,520)
outText.Position=UDim2.new(0,7,0,7)
outText.BackgroundTransparency=1
outText.TextColor3=Color3.fromRGB(255,238,170)
outText.Font=Enum.Font.GothamBold
outText.TextSize=11
outText.TextWrapped=true
outText.TextXAlignment=Enum.TextXAlignment.Left
outText.TextYAlignment=Enum.TextYAlignment.Top
outText.Text="PLAN покажет маршрут. START выполнит всё."

status=Instance.new("TextLabel",frame)
status.Size=UDim2.new(1,-24,0,18)
status.Position=UDim2.new(0,12,0,282)
status.BackgroundTransparency=1
status.Text="START = ровнять + багать автоматически."
status.TextColor3=Color3.fromRGB(175,165,210)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left

local function btn(txt,x,w,color)
	local b=Instance.new("TextButton",frame)
	b.Size=UDim2.new(0,w,0,24)
	b.Position=UDim2.new(0,x,1,-30)
	b.Text=txt
	b.TextColor3=Color3.new(1,1,1)
	b.BackgroundColor3=color
	b.Font=Enum.Font.GothamBlack
	b.TextSize=10
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
	return b
end

local startBtn=btn("START",12,62,Color3.fromRGB(45,130,70))
local planBtn=btn("PLAN",82,62,Color3.fromRGB(45,100,180))
local scanBtn=btn("SCAN",152,62,Color3.fromRGB(85,70,160))
local copyBtn=btn("COPY",222,58,Color3.fromRGB(115,80,45))
local stopBtn=btn("STOP",288,70,Color3.fromRGB(125,35,48))

local function buildReport()
	local reb=parseNum(rebBox.Text)
	if not reb then return "Впиши ребы. Пример: 63.4k" end

	local filter=RAR_CHOICES[rarityIndex]
	local now,src,lvl,xp=nil,nil,nil,nil

	local tempRows=allCandidates(reb,filter)
	local tempRarity=(tempRows[1] and tempRows[1].rarity) or "Unique"
	now,src,lvl,xp=getPetTotalAny(tempRarity)

	local best,rows=chooseCandidate(reb,filter,now)
	if not best then return "Нет точных вариантов." end

	-- после выбора кандидата читаем XP уже по его редкости
	now,src,lvl,xp=getPetTotalAny(best.rarity)
	best,rows=chooseCandidate(reb,filter,now)

	local lines={}
	table.insert(lines,"FULL AUTO RESULT")
	table.insert(lines,"Ребы: "..fmt(reb).." | Фильтр: "..filter)
	table.insert(lines,"")
	table.insert(lines,"Пет: "..best.rarity)
	table.insert(lines,"Камень бага: "..best.rockLabel)
	table.insert(lines,"Поставить: "..fmt(best.setLvl).." lvl, "..fmt(best.setXp).." XP")
	table.insert(lines,"Total цель: "..fmt(best.startTotal))
	table.insert(lines,"Удар камня: +"..fmt(best.hit).." XP")
	table.insert(lines,"Ожидание: +"..fmt(best.bonus).." статов")
	table.insert(lines,"")

	if now then
		local diff=best.startTotal-now
		table.insert(lines,"Текущий XP: "..fmt(now).." ("..tostring(src)..")")
		if lvl and xp then table.insert(lines,"Видимо: "..fmt(lvl).." lvl, "..fmt(xp).." XP")end

		if diff<0 then
			table.insert(lines,"Пет выше цели на "..fmt(math.abs(diff)).." XP.")
			table.insert(lines,"START выберет ближайший достижимый вариант, если он есть.")
		else
			local plan=makePlan(diff)
			table.insert(lines,"Добрать: "..fmt(diff).." XP")
			table.insert(lines,"Дорожки: "..planText(plan))
			table.insert(lines,"Время дорожек: ~"..fmt(planSeconds(plan)).." сек")
			table.insert(lines,"Потом авто BUG по "..best.rockLabel)
		end
	else
		table.insert(lines,"XP не прочитан. Открой окно питомца с Level/XP.")
	end

	table.insert(lines,"")
	table.insert(lines,"TOP:")
	for i=1,math.min(6,#rows)do
		local r=rows[i]
		table.insert(lines,("#%d %s | %s | set %s lvl %s XP | +%s"):format(i,r.rarity,r.rockLabel,fmt(r.setLvl),fmt(r.setXp),fmt(r.bonus)))
	end

	return table.concat(lines,"\n"),best,now
end

local function render()
	local text,best,now=buildReport()
	lastReport=text
	current=best
	outText.Text=text
	local lines=select(2,text:gsub("\n","\n"))+1
	local h=math.max(520,lines*16+20)
	outFrame.CanvasSize=UDim2.new(0,0,0,h)
	outText.Size=UDim2.new(1,-14,0,h)
end

local function alignOnly(data,now)
	if not data then return false end
	if not now then
		statusText("XP не прочитан. Открой окно питомца.")
		return false
	end

	if now>=data.startTotal then
		statusText("Уже ровно/выше цели.")
		return true
	end

	local plan,err=makePlan(data.startTotal-now)
	if err then statusText(err) return false end

	for _,p in ipairs(plan)do
		if _G.PetAlignStop then return false end

		local nowCheck=getPetTotalAny(data.rarity)
		if nowCheck and nowCheck>=data.startTotal then break end

		local part,idx,total=treadmillPart(p.gain)
		if not part then
			statusText("Не нашёл дорожку +"..p.gain.." idx="..tostring(idx).."/"..tostring(total))
			return false
		end

		local segmentTarget=nowCheck and math.min(data.startTotal,nowCheck+p.gain*p.count)or data.startTotal
		statusText("Дорожка +"..p.gain.."×"..p.count.." → "..fmt(segmentTarget))
		runOnTreadmill(part,segmentTarget,data.rarity)
	end

	local final=getPetTotalAny(data.rarity)
	return final and final>=data.startTotal
end

local function startFull()
	if running then return end
	running=true
	_G.PetAlignStop=false
	stopRockLock()

	render()

	local reb=parseNum(rebBox.Text)
	if not reb then
		statusText("Впиши ребы.")
		running=false
		return
	end

	local filter=RAR_CHOICES[rarityIndex]
	local rows=allCandidates(reb,filter)
	if #rows==0 then
		statusText("Нет вариантов.")
		running=false
		return
	end

	local now=getPetTotalAny(rows[1].rarity)
	local data=chooseCandidate(reb,filter,now)
	now=getPetTotalAny(data.rarity)
	data=chooseCandidate(reb,filter,now)

	if not data then
		statusText("Не нашёл достижимый баг.")
		running=false
		return
	end

	current=data
	render()

	if not rockRowsCache then
		statusText("Сканирую скалы...")
		rockRowsCache=scanNeededRocks()
	end

	if now and now<data.startTotal then
		local ok=alignOnly(data,now)
		if not ok then
			statusText("ALIGN не дошёл до цели.")
			running=false
			return
		end
	end

	if _G.PetAlignStop then running=false return end

	statusText("XP готов. Запускаю BUG → "..data.rockLabel)
	local ok=bugHit(data)

	if ok then
		statusText("FULL AUTO готово.")
	else
		statusText("BUG не сработал.")
	end

	running=false
end

startBtn.MouseButton1Click:Connect(function()
	task.spawn(function()
		local ok,err=pcall(startFull)
		if not ok then statusText("START error: "..tostring(err):sub(1,110)) running=false stopRockLock() end
	end)
end)

planBtn.MouseButton1Click:Connect(render)

scanBtn.MouseButton1Click:Connect(function()
	task.spawn(function()
		statusText("Сканирую скалы...")
		local ok,err=pcall(function()
			local report,count=makeRockReport()
			lastReport=report
			if setclipboard then pcall(setclipboard,report)end
			statusText("Скалы: "..count..". Отчёт скопирован.")
		end)
		if not ok then statusText("SCAN error: "..tostring(err):sub(1,100))end
	end)
end)

copyBtn.MouseButton1Click:Connect(function()
	render()
	if setclipboard then
		pcall(setclipboard,lastReport)
		statusText("Отчёт скопирован.")
	else
		statusText("Clipboard недоступен.")
	end
end)

stopBtn.MouseButton1Click:Connect(function()
	_G.PetAlignStop=true
	running=false
	stopRockLock()
	statusText("Остановлено.")
end)

rarityBtn.MouseButton1Click:Connect(function()
	rarityIndex+=1
	if rarityIndex>#RAR_CHOICES then rarityIndex=1 end
	rarityBtn.Text=RAR_CHOICES[rarityIndex]
	render()
end)

rebBox:GetPropertyChangedSignal("Text"):Connect(render)

close.MouseButton1Click:Connect(function()
	_G.PetAlignStop=true
	running=false
	stopRockLock()
	gui:Destroy()
end)

_G.PetAlignFullAuto={
	Start=function()task.spawn(startFull)end,
	Stop=function()_G.PetAlignStop=true running=false stopRockLock()end,
	Plan=render,
	ScanRocks=function()rockRowsCache=scanNeededRocks()end,
}

local d=nil
pcall(function()
	local ls=lp:FindFirstChild("leaderstats")
	if ls then
		for _,v in ipairs(ls:GetChildren())do
			local n=v.Name:lower()
			if n:find("rebirth",1,true)or n:find("перер",1,true)then
				d=tonumber(v.Value)
			end
		end
	end
end)
if d then rebBox.Text=tostring(d)end
render()
