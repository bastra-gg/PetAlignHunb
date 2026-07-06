-- PetAlignHub v45_ADAPTIVE_UI_FIX
-- Удобный дизайн + проверенная математика по всем редкостям.
-- ALIGN: сам ровняет дорожками и останавливается на нужном Total XP.
-- BUG: сам тепает в нужный камень через neededDurability и реально бьёт/активирует.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
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

-- Дорожки из твоей калибровки: за 5 сек даёт +gain XP.
local TREAD_INDEX={[1]=36,[2]=33,[3]=31,[4]=29,[5]=28,[6]=26}
local TREAD_SECONDS=5.0

-- Камни через neededDurability.
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
	[150000]="Frozen/Frost Rock",
	[400000]="Mystic/Mythical Rock",
	[750000]="Inferno/Eternal Rock",
	[1000000]="Legends Rock",
	[5000000]="Muscle King Rock",
	[10000000]="Ancient Jungle Rock",
}

local running=false
local rarityIndex=1
local current=nil
local rockRowsCache=nil
local lastReport=""
local selectedCard=1
local choiceCards={}
local choiceRows={}

_G.PetAlignStop=false

local gui,frame,status,targetText,currentText,planTextUi,bugText,rebBox,rarityBtn,resultsScroll,resultsLabel,uiScale
local updateAdaptive=function()end
local uiFront=function()end
local rockLockConn=nil
local rockLockedCF=nil
local rockOldSpeed=nil
local rockOldAuto=nil

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
	local base=BASE[rarity]
	if not pg or not base then return nil,nil,nil,nil end

	local best=nil
	local bestScore=-math.huge

	for _,v in ipairs(pg:GetDescendants())do
		if v:IsA("TextLabel")or v:IsA("TextButton")or v:IsA("TextBox")then
			local txt=tostring(v.Text or "")
			local low=txt:lower()

			local a,b=low:match("([%d%s%.%,]+)%s*/%s*([%d%s%.%,]+)")
			if a and b and (low:find("эксп",1,true)or low:find("опыт",1,true)or low:find("xp",1,true)or low:find("exp",1,true))then
				local xp=parseNum(a)
				local cap=parseNum(b)

				if xp and cap and cap>0 then
					local lvlFloat=cap/base

					if math.abs(lvlFloat-round(lvlFloat))<0.001 and lvlFloat>=1 then
						local lvl=round(lvlFloat)
						local score=100000 - math.abs(xp) - math.abs(cap)
						if xp<=cap then score+=500 end

						if score>bestScore then
							bestScore=score
							best={lvl=lvl,xp=xp,cap=cap}
						end
					end
				end
			end
		end
	end

	if best then
		return totalFrom(base,best.lvl,best.xp),"gui",best.lvl,best.xp
	end

	return nil,nil,nil,nil
end

local function detectGuiRarity()
	for _,rarity in ipairs(RAR_ORDER)do
		local total,src,lvl,xp=parsePetGuiTotal(rarity)
		if total then return rarity,total,src,lvl,xp end
	end
	return nil,nil,nil,nil,nil
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

				-- Самопроверка формулы: старт + удар должен ровно попадать в cap.
				cand.valid=(cand.startTotal+cand.hit==cand.endTotal)

				if cand.valid and (not best or cand.bonus>best.bonus or(cand.bonus==best.bonus and cand.startTotal<best.startTotal))then
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

local function planToString(plan)
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

local function validateMath()
	local issues={}
	for _,rarity in ipairs(RAR_ORDER)do
		local base=BASE[rarity]
		for lvl=1,30 do
			local total=cum(base,lvl)
			local l,x=levelFromTotal(base,total)
			if not(l==lvl+1 and x==0)then
				table.insert(issues,rarity.." cap fail lvl "..lvl)
			end
		end
	end
	return #issues==0,issues
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
		statusText("Скан скал...")
		rockRowsCache=scanNeededRocks()
	end

	for _,row in ipairs(rockRowsCache)do
		if row.req==req and row.body and row.body.Parent then return row end
	end

	rockRowsCache=scanNeededRocks()
	for _,row in ipairs(rockRowsCache)do
		if row.req==req and row.body and row.body.Parent then return row end
	end

	return nil
end

local function makeRockReport()
	local rows=scanNeededRocks()
	rockRowsCache=rows

	local lines={}
	table.insert(lines,"PetAlign v45 rock scan")
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

local function pressW(down)
	pcall(function()
		if down then
			if keypress then keypress(0x57) end
		else
			if keyrelease then keyrelease(0x57) end
		end
	end)

	pcall(function()
		VirtualInputManager:SendKeyEvent(down,Enum.KeyCode.W,false,game)
	end)
end

local function makeSmall()
	pcall(function()
		local re=ReplicatedStorage:FindFirstChild("rEvents")
		local remote=re and re:FindFirstChild("changeSpeedSizeRemote")
		if remote then remote:InvokeServer("changeSize",1)end
	end)
end

local function clamp(n,a,b)
	if n<a then return a end
	if n>b then return b end
	return n
end

local function runOnTreadmill(part,targetTotal,rarity)
	local c=lp.Character or lp.CharacterAdded:Wait()
	local r=root()
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if not r or not hum or not part then return false end

	makeSmall()
	pcall(uiFront)

	local dir
	if part.Size.Z>=part.Size.X then
		dir=part.CFrame.LookVector
	else
		dir=part.CFrame.RightVector
	end
	dir=Vector3.new(dir.X,0,dir.Z)
	if dir.Magnitude<0.05 then dir=Vector3.new(0,0,-1)end
	dir=dir.Unit

	if _G.PetAlignReverseRun==nil then _G.PetAlignReverseRun=true end
	if _G.PetAlignReverseRun then dir=-dir end

	local side=Vector3.new(-dir.Z,0,dir.X)
	local speed=_G.PetAlignRunSpeed or 18
	local length=math.max(part.Size.X,part.Size.Z)
	local width=math.min(part.Size.X,part.Size.Z)
	local heightAbove=_G.PetAlignHeightOffset or math.clamp((hum.HipHeight or 2)+1.15,2.75,4.15)

	local y=part.Position.Y+part.Size.Y/2+heightAbove
	local startPos=Vector3.new(part.Position.X,y,part.Position.Z)

	local oldSpeed=hum.WalkSpeed
	local oldAuto=hum.AutoRotate
	local oldJP=hum.JumpPower
	local oldJH=hum.JumpHeight

	hum.WalkSpeed=speed
	hum.AutoRotate=true
	pcall(function()hum.JumpPower=0 end)
	pcall(function()hum.JumpHeight=0 end)

	r.CFrame=CFrame.lookAt(startPos,startPos+dir)
	task.wait(.25)

	local started=os.clock()
	local maxRun=_G.PetAlignTreadmillMaxRunSeconds or 160
	local minRun=_G.PetAlignMinTreadmillRunSeconds or 3
	local nextKey=0
	local nextClamp=0
	local stable=0
	local lastNow=nil

	local maxLong=math.max(2,length/2-1.4)
	local maxSide=math.max(1,width/2-0.8)

	pressW(true)

	while not _G.PetAlignStop do
		local elapsed=os.clock()-started

		if elapsed>=minRun then
			local now=getPetTotalAny(rarity)
			if now then
				if now>=targetTotal then
					stable+=1
				else
					stable=0
				end

				lastNow=now
				statusText("ALIGN: "..fmt(now).."/"..fmt(targetTotal).." | ok "..stable.."/5")

				-- v43: не стопает от одного кривого чтения. Нужно 5 стабильных чтений цели.
				if stable>=5 then break end
			end
		end

		if elapsed>maxRun then break end

		r=root()
		if not r then break end

		hum:Move(dir,false)
		pcall(function()hum:ChangeState(Enum.HumanoidStateType.Running)end)

		if os.clock()>=nextKey then
			nextKey=os.clock()+0.18
			pressW(true)
		end

		-- Более жёсткое удержание на полотне: кнопки не пропадают, скорость вперёд не форсится.
		if os.clock()>=nextClamp then
			nextClamp=os.clock()+0.06

			local rel=r.Position-part.Position
			local long=rel:Dot(dir)
			local sideOff=rel:Dot(side)

			local fixedLong=clamp(long,-maxLong,maxLong)
			local fixedSide=clamp(sideOff,-maxSide,maxSide)

			if math.abs(long-fixedLong)>0.05 or math.abs(sideOff-fixedSide)>0.05 then
				local fixed=Vector3.new(part.Position.X,r.Position.Y,part.Position.Z)+dir*fixedLong+side*fixedSide
				r.CFrame=CFrame.lookAt(fixed,fixed+dir)
				r.AssemblyAngularVelocity=Vector3.zero
			end
		end

		pcall(uiFront)
		RunService.Heartbeat:Wait()
	end

	pressW(false)
	hum:Move(Vector3.zero,false)

	hum.WalkSpeed=oldSpeed
	hum.AutoRotate=oldAuto
	pcall(function()hum.JumpPower=oldJP end)
	pcall(function()hum.JumpHeight=oldJH end)

	pcall(uiFront)

	return true
end


local function touchPart(part)
	if not part then return end
	local c=lp.Character
	local r=root()
	if not c or not r then return end

	local rh=c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm") or r
	local lh=c:FindFirstChild("LeftHand") or c:FindFirstChild("Left Arm") or r

	for _,hand in ipairs({rh,lh,r})do
		pcall(function()
			firetouchinterest(hand,part,1)
			task.wait(.02)
			firetouchinterest(hand,part,0)
		end)
		pcall(function()
			firetouchinterest(hand,part,0)
			task.wait(.02)
			firetouchinterest(hand,part,1)
		end)
	end
end

local function firePunchRemote()
	pcall(function()
		if lp:FindFirstChild("muscleEvent")then
			lp.muscleEvent:FireServer("punch","rightHand")
		end
	end)
end


local function isBadToolName(n)
	n=tostring(n or ""):lower()
	return n:find("dumb",1,true)
		or n:find("гант",1,true)
		or n:find("weight",1,true)
		or n:find("barbell",1,true)
		or n:find("bench",1,true)
		or n:find("гир",1,true)
end

local function isHitToolName(n)
	n=tostring(n or ""):lower()
	return n:find("punch",1,true)
		or n:find("fist",1,true)
		or n:find("hit",1,true)
		or n:find("combat",1,true)
		or n:find("кулак",1,true)
		or n:find("удар",1,true)
end

local function equipHitTool()
	local c=lp.Character or lp.CharacterAdded:Wait()
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if not hum then return nil end

	local currentTool=c:FindFirstChildWhichIsA("Tool")
	if currentTool then
		if isHitToolName(currentTool.Name) and not isBadToolName(currentTool.Name)then
			pcall(function() if currentTool:FindFirstChild("attackTime")then currentTool.attackTime.Value=0.065 end end)
			return currentTool
		end
		if isBadToolName(currentTool.Name)then
			pcall(function() hum:UnequipTools() end)
			task.wait(.12)
		end
	end

	local bp=lp:FindFirstChild("Backpack")
	if not bp then return nil end

	for _,t in ipairs(bp:GetChildren())do
		if t:IsA("Tool") and isHitToolName(t.Name) and not isBadToolName(t.Name)then
			pcall(function()hum:EquipTool(t)end)
			task.wait(.15)
			pcall(function() if t:FindFirstChild("attackTime")then t.attackTime.Value=0.065 end end)
			return t
		end
	end

	-- Важно: не берём первую попавшуюся Tool, иначе он качает гантелью.
	return nil
end


local function bugHit(data)
	local row=getRockRow(data.rock)
	if not row then
		statusText("BUG: не нашёл камень "..data.rockLabel..". Жми SCAN.")
		return false
	end

	statusText("BUG: теп в камень "..data.rockLabel)
	if not goRock(row)then
		statusText("BUG: не смог тепнуться.")
		return false
	end

	local tool=equipHitTool()
	local seconds=_G.PetAlignBugHitSeconds or 4.0
	local delay=_G.PetAlignBugHitDelay or .28
	local started=os.clock()
	local hits=0

	while not _G.PetAlignStop and os.clock()-started<seconds do
		hits+=1

		firePunchRemote()
		if row.hit and row.hit.Parent then touchPart(row.hit)end
		if row.body and row.body.Parent then touchPart(row.body)end
		if tool and tool.Parent then
			pcall(function()tool:Activate()end)
			firePunchRemote()
		end

		statusText("BUG: удар "..hits.." → "..data.rockLabel..(tool and " | fist" or " | touch"))
		task.wait(delay)
	end

	stopRockLock()
	return true
end

local function getData()
	local reb=parseNum(rebBox.Text)
	if not reb then return nil,nil,"Впиши ребы.",{} end

	local filter=RAR_CHOICES[rarityIndex]
	local now=nil

	if filter=="Auto"then
		local detected,total=detectGuiRarity()
		if detected and total then
			filter=detected
			now=total
		end
	else
		now=getPetTotalAny(filter)
	end

	local rows=allCandidates(reb,filter)
	if #rows==0 then return nil,nil,"Нет точных вариантов.",{} end

	-- Карточки должны быть именно вариантами выбора.
	choiceRows=rows

	if selectedCard<1 then selectedCard=1 end
	if selectedCard>#rows then selectedCard=1 end

	local data=rows[selectedCard]

	-- Если выбранная карточка уже ниже текущего XP, но юзер сам её выбрал — показываем её,
	-- а не перескакиваем молча. Для Auto по умолчанию первая карточка обычно лучшая.
	if not data then
		data=chooseCandidate(reb,filter,now)
	end

	if data and not now then
		now=getPetTotalAny(data.rarity)
	end

	if not data then return nil,now,"Не нашёл достижимый баг.",rows end

	current=data
	return data,now,nil,rows
end


local function setZ(obj,z)
	pcall(function()obj.ZIndex=z end)
	for _,ch in ipairs(obj:GetChildren())do
		setZ(ch,z)
	end
end

function uiFront()
	updateAdaptive()
	if gui then
		gui.DisplayOrder=999999
		gui.IgnoreGuiInset=true
		gui.ResetOnSpawn=false
	end
	if frame then
		frame.Visible=true
		frame.Active=true
		setZ(frame,20)
	end
end

local function render()
	uiFront()

	local data,now,err,rows=getData()

	if err then
		targetText.Text=err
		currentText.Text="Открой нужного питомца, чтобы читался XP."
		planTextUi.Text="-"
		bugText.Text="-"
		lastReport=err
	else
		local diff=now and (data.startTotal-now) or nil
		local plan=nil
		local planErr=nil

		if diff and diff>=0 then
			plan,planErr=makePlan(diff)
		end

		targetText.Text=
			"Пет: "..data.rarity..
			"\nКамень: "..data.rockLabel..
			"\nЦель: "..fmt(data.setLvl).." lvl, "..fmt(data.setXp).." XP"..
			"\nTotal: "..fmt(data.startTotal).." | hit +"..fmt(data.hit)

		if now then
			currentText.Text="Сейчас: "..fmt(now).." XP\nДо цели: "..(diff and fmt(diff)or"?").." XP"
		else
			currentText.Text="Сейчас: XP не прочитан\nОткрой окно питомца."
		end

		if diff then
			if diff<0 then
				planTextUi.Text="Этот вариант ниже текущего XP на "..fmt(math.abs(diff))..".\nВыбери другую карточку."
			else
				planTextUi.Text="Дорожки: "..planToString(plan).."\nАвтостоп после 5 стабильных чтений XP."
			end
		else
			planTextUi.Text="План появится после чтения XP."
		end

		bugText.Text="BUG: теп в "..data.rockLabel.."\nRemote punch + touch руками."

		lastReport=
			"PetAlign v45\n"..
			"Selected card: #"..tostring(selectedCard).."\n"..
			"Pet: "..data.rarity.."\n"..
			"Rock: "..data.rockLabel.."\n"..
			"Set: "..fmt(data.setLvl).." lvl, "..fmt(data.setXp).." XP\n"..
			"TargetTotal: "..fmt(data.startTotal).."\n"..
			"Hit: +"..fmt(data.hit).."\n"..
			"Bonus: +"..fmt(data.bonus).." stats\n"..
			"Now: "..fmt(now or 0).."\n"..
			"Align: "..(plan and planToString(plan) or "-")
	end

	if resultsLabel then
		resultsLabel.Text="Вариантов: "..tostring(rows and #rows or 0)
	end

	if choiceCards and resultsScroll then
		local count=(rows and #rows) or 0
		for i=1,count do
			local row=rows[i]
			local card=choiceCards[i]
			if not card then
				local idx=i
				card=Instance.new("TextButton")
				card.Name="ChoiceCard"..idx
				card.Parent=resultsScroll
				card.Size=UDim2.new(1,-4,0,68)
				card.BackgroundColor3=Color3.fromRGB(28,29,55)
				card.BorderSizePixel=0
				card.AutoButtonColor=false
				card.Font=Enum.Font.GothamBlack
				card.TextSize=10
				card.TextWrapped=true
				card.TextXAlignment=Enum.TextXAlignment.Left
				card.TextYAlignment=Enum.TextYAlignment.Top
				card.TextColor3=Color3.fromRGB(255,238,170)
				card.LayoutOrder=idx
				Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
				local st=Instance.new("UIStroke",card)
				st.Color=Color3.fromRGB(95,75,180)
				st.Thickness=1
				card.MouseButton1Click:Connect(function()
					selectedCard=idx
					render()
					statusText("Выбрана карточка #"..idx)
				end)
				choiceCards[idx]=card
			end
			card.Visible=true
			card.LayoutOrder=i
			card.Text=("#%d  %s  •  +%s статов\n%s\nПоставить: %s lvl, %s XP  |  Hit +%s  |  Total %s"):format(
				i,row.rarity,fmt(row.bonus),row.rockLabel,fmt(row.setLvl),fmt(row.setXp),fmt(row.hit),fmt(row.startTotal)
			)
			if i==selectedCard then
				card.BackgroundColor3=Color3.fromRGB(72,58,145)
			else
				card.BackgroundColor3=Color3.fromRGB(28,29,55)
			end
		end
		for i=count+1,#choiceCards do
			choiceCards[i].Visible=false
		end
		resultsScroll.CanvasSize=UDim2.new(0,0,0,count*74+8)
	end

	uiFront()
end


local function doAlign()
	if running then return end
	running=true
	_G.PetAlignStop=false
	stopRockLock()
	uiFront()

	render()
	local data,now,err=getData()

	if err then statusText(err) running=false uiFront() return end
	if not now then statusText("ALIGN: XP не прочитан.") running=false uiFront() return end

	if now>=data.startTotal then
		statusText("ALIGN: выбранная карточка уже ниже/ровно. Выбери другую.")
		running=false
		uiFront()
		return
	end

	local plan,planErr=makePlan(data.startTotal-now)
	if planErr then statusText("ALIGN: "..planErr) running=false uiFront() return end

	statusText("ALIGN старт: "..planToString(plan))

	for _,p in ipairs(plan)do
		if _G.PetAlignStop then break end

		local nowCheck=getPetTotalAny(data.rarity)
		if nowCheck and nowCheck>=data.startTotal then
			-- Не вылетаем сразу. Проверку стабильности добьёт runOnTreadmill/финал.
			break
		end

		local part,idx,total=treadmillPart(p.gain)
		if not part then
			statusText("ALIGN: не нашёл дорожку +"..p.gain.." idx="..tostring(idx).."/"..tostring(total))
			running=false
			uiFront()
			return
		end

		local segmentTarget=nowCheck and math.min(data.startTotal,nowCheck+p.gain*p.count)or data.startTotal
		statusText("ALIGN: +"..p.gain.."×"..p.count.." до "..fmt(segmentTarget))
		runOnTreadmill(part,segmentTarget,data.rarity)
		uiFront()
	end

	-- Финальная проверка тоже стабильная, чтобы не писать готово от одного ложного чтения.
	local good=0
	local final=nil
	for _=1,12 do
		final=getPetTotalAny(data.rarity)
		if final and final>=data.startTotal then good+=1 else good=0 end
		if good>=3 then break end
		task.wait(.2)
	end

	if good>=3 then
		statusText("ALIGN готов: "..fmt(final)..". Жми BUG.")
	else
		statusText("ALIGN не добрал: "..fmt(final or 0).."/"..fmt(data.startTotal))
	end

	render()
	uiFront()
	running=false
end


local function doBug()
	if running then return end
	running=true
	_G.PetAlignStop=false
	stopRockLock()

	render()
	local data,now,err=getData()

	if err then statusText(err) running=false return end

	-- BUG кнопка теперь именно запускает баг: теп к нужному камню и удар.
	-- Не блокируем из-за XP, потому что чтение GUI может лагать/обновляться позже.
	if now and now<data.startTotal then
		statusText("BUG: XP ниже цели, но запускаю камень: "..data.rockLabel)
		task.wait(.25)
	end

	statusText("BUG: тепаю к "..data.rockLabel)
	local ok=bugHit(data)

	if ok then
		statusText("BUG готов.")
	else
		statusText("BUG не сработал.")
	end

	render()
	running=false
end


-- UI
gui=Instance.new("ScreenGui")
gui.Name="PetAlignComfortV45"
gui.ResetOnSpawn=false
gui.DisplayOrder=999999
gui.IgnoreGuiInset=true
gui.Parent=lp:WaitForChild("PlayerGui")

frame=Instance.new("Frame",gui)
frame.AnchorPoint=Vector2.new(.5,.5)
frame.Size=UDim2.new(0,480,0,560)
frame.Position=UDim2.new(.5,0,.5,0)
frame.BackgroundColor3=Color3.fromRGB(11,11,24)
uiScale=Instance.new("UIScale",frame)

function updateAdaptive()
	local cam=workspace.CurrentCamera
	local vp=cam and cam.ViewportSize or Vector2.new(900,600)

	-- База 480x560. На телефоне окно уменьшается под экран, на большом экране остаётся нормальным.
	local s=math.min(1,(vp.X*.92)/480,(vp.Y*.88)/560)
	if s<.58 then s=.58 end
	if uiScale then uiScale.Scale=s end

	if frame then
		frame.AnchorPoint=Vector2.new(.5,.5)
		frame.Position=UDim2.new(.5,0,.5,0)
	end
end

pcall(function()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateAdaptive)
	end
end)
task.defer(updateAdaptive)
frame.BorderSizePixel=0
frame.Active=true
frame.Draggable=true
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,16)
local stroke=Instance.new("UIStroke",frame)
stroke.Color=Color3.fromRGB(120,74,255)
stroke.Thickness=1.6

local title=Instance.new("TextLabel",frame)
title.Size=UDim2.new(1,-54,0,34)
title.Position=UDim2.new(0,14,0,8)
title.BackgroundTransparency=1
title.Text="Pet Align Program v45"
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

rebBox=Instance.new("TextBox",frame)
rebBox.Size=UDim2.new(0,266,0,36)
rebBox.Position=UDim2.new(0,14,0,50)
rebBox.Text=""
rebBox.PlaceholderText="ребы: 63.4k"
rebBox.ClearTextOnFocus=false
rebBox.TextColor3=Color3.new(1,1,1)
rebBox.PlaceholderColor3=Color3.fromRGB(155,145,185)
rebBox.BackgroundColor3=Color3.fromRGB(31,29,61)
rebBox.Font=Enum.Font.GothamBold
rebBox.TextSize=14
Instance.new("UICorner",rebBox).CornerRadius=UDim.new(0,10)

rarityBtn=Instance.new("TextButton",frame)
rarityBtn.Size=UDim2.new(0,142,0,36)
rarityBtn.Position=UDim2.new(1,-156,0,50)
rarityBtn.Text="Auto"
rarityBtn.TextColor3=Color3.new(1,1,1)
rarityBtn.BackgroundColor3=Color3.fromRGB(62,50,120)
rarityBtn.Font=Enum.Font.GothamBlack
rarityBtn.TextSize=13
Instance.new("UICorner",rarityBtn).CornerRadius=UDim.new(0,10)


local resultsHead=Instance.new("TextLabel",frame)
resultsHead.Size=UDim2.new(1,-28,0,18)
resultsHead.Position=UDim2.new(0,14,0,92)
resultsHead.BackgroundTransparency=1
resultsHead.Text="ВАРИАНТЫ ВЫРАВНИВАНИЯ / БАГА"
resultsHead.TextColor3=Color3.fromRGB(220,210,255)
resultsHead.Font=Enum.Font.GothamBlack
resultsHead.TextSize=12
resultsHead.TextXAlignment=Enum.TextXAlignment.Left

resultsLabel=Instance.new("TextLabel",frame)
resultsLabel.Size=UDim2.new(0,150,0,18)
resultsLabel.Position=UDim2.new(1,-164,0,92)
resultsLabel.BackgroundTransparency=1
resultsLabel.Text="Вариантов: 0"
resultsLabel.TextColor3=Color3.fromRGB(170,165,205)
resultsLabel.Font=Enum.Font.GothamBold
resultsLabel.TextSize=11
resultsLabel.TextXAlignment=Enum.TextXAlignment.Right

resultsScroll=Instance.new("ScrollingFrame",frame)
resultsScroll.Size=UDim2.new(1,-28,0,170)
resultsScroll.Position=UDim2.new(0,14,0,114)
resultsScroll.BackgroundColor3=Color3.fromRGB(15,16,32)
resultsScroll.BorderSizePixel=0
resultsScroll.ScrollBarThickness=5
resultsScroll.CanvasSize=UDim2.new(0,0,0,0)
resultsScroll.AutomaticCanvasSize=Enum.AutomaticSize.None
Instance.new("UICorner",resultsScroll).CornerRadius=UDim.new(0,12)
local resultsStroke=Instance.new("UIStroke",resultsScroll)
resultsStroke.Color=Color3.fromRGB(72,64,130)
resultsStroke.Thickness=1
local resultsPad=Instance.new("UIPadding",resultsScroll)
resultsPad.PaddingTop=UDim.new(0,6)
resultsPad.PaddingLeft=UDim.new(0,6)
resultsPad.PaddingRight=UDim.new(0,6)
resultsPad.PaddingBottom=UDim.new(0,6)
local resultsLayout=Instance.new("UIListLayout",resultsScroll)
resultsLayout.Padding=UDim.new(0,6)
resultsLayout.SortOrder=Enum.SortOrder.LayoutOrder

local function card(parent,x,y,w,h,titleText,color)

	local f=Instance.new("Frame",parent)
	f.Size=UDim2.new(0,w,0,h)
	f.Position=UDim2.new(0,x,0,y)
	f.BackgroundColor3=color
	f.BorderSizePixel=0
	Instance.new("UICorner",f).CornerRadius=UDim.new(0,12)

	local t=Instance.new("TextLabel",f)
	t.Size=UDim2.new(1,-16,0,20)
	t.Position=UDim2.new(0,8,0,6)
	t.BackgroundTransparency=1
	t.Text=titleText
	t.TextColor3=Color3.fromRGB(255,255,255)
	t.Font=Enum.Font.GothamBlack
	t.TextSize=12
	t.TextXAlignment=Enum.TextXAlignment.Left

	local body=Instance.new("TextLabel",f)
	body.Size=UDim2.new(1,-16,1,-30)
	body.Position=UDim2.new(0,8,0,28)
	body.BackgroundTransparency=1
	body.TextColor3=Color3.fromRGB(255,238,170)
	body.Font=Enum.Font.GothamBold
	body.TextSize=11
	body.TextWrapped=true
	body.TextXAlignment=Enum.TextXAlignment.Left
	body.TextYAlignment=Enum.TextYAlignment.Top

	return f,body
end

local _,targetBody=card(frame,14,292,218,102,"ЦЕЛЬ",Color3.fromRGB(22,45,38))
targetText=targetBody

local _,currentBody=card(frame,246,292,220,102,"ТЕКУЩИЙ ПЕТ",Color3.fromRGB(28,30,58))
currentText=currentBody

local _,planBody=card(frame,14,402,218,86,"ВЫРАВНИВАНИЕ",Color3.fromRGB(25,42,63))
planTextUi=planBody

local _,bugBody=card(frame,246,402,220,86,"БАГ",Color3.fromRGB(54,30,42))
bugText=bugBody

status=Instance.new("TextLabel",frame)
status.Size=UDim2.new(1,-28,0,24)
status.Position=UDim2.new(0,14,0,496)
status.BackgroundTransparency=1
status.Text="Выбери карточку ниже. ALIGN — ровняет до цели, BUG — тепает и бьёт нужный камень."
status.TextColor3=Color3.fromRGB(190,180,220)
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

local alignBtn=btn("ALIGN",14,84,Color3.fromRGB(45,100,180))
local bugBtn=btn("BUG",106,70,Color3.fromRGB(45,130,70))
local scanBtn=btn("SCAN",184,76,Color3.fromRGB(85,70,160))
local copyBtn=btn("COPY",268,76,Color3.fromRGB(115,80,45))
local stopBtn=btn("STOP",352,100,Color3.fromRGB(125,35,48))

alignBtn.MouseButton1Click:Connect(function()
	task.spawn(function()
		local ok,err=pcall(doAlign)
		if not ok then statusText("ALIGN error: "..tostring(err):sub(1,110)) running=false stopRockLock() end
	end)
end)

bugBtn.MouseButton1Click:Connect(function()
	task.spawn(function()
		local ok,err=pcall(doBug)
		if not ok then statusText("BUG error: "..tostring(err):sub(1,110)) running=false stopRockLock() end
	end)
end)

scanBtn.MouseButton1Click:Connect(function()
	task.spawn(function()
		statusText("Скан скал...")
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
	pressW(false)
	uiFront()
	statusText("Остановлено.")
end)

rarityBtn.MouseButton1Click:Connect(function()
	rarityIndex+=1
	if rarityIndex>#RAR_CHOICES then rarityIndex=1 end
	rarityBtn.Text=RAR_CHOICES[rarityIndex]
	selectedCard=1
	render()
end)

rebBox:GetPropertyChangedSignal("Text"):Connect(function()
	selectedCard=1
	render()
end)

close.MouseButton1Click:Connect(function()
	_G.PetAlignStop=true
	running=false
	stopRockLock()
	pressW(false)
	gui:Destroy()
end)

_G.PetAlignComfort={
	Align=function()task.spawn(doAlign)end,
	Bug=function()task.spawn(doBug)end,
	Stop=function()_G.PetAlignStop=true running=false stopRockLock()end,
	Scan=function()rockRowsCache=scanNeededRocks()end,
	Validate=validateMath,
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

local okMath,issues=validateMath()
if okMath then
	statusText("v45: фикс uiFront + адаптивное окно.")
else
	statusText("Ошибка математики: "..tostring(issues[1]))
end

render()
