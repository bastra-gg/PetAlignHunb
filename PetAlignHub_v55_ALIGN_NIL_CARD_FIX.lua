-- PetAlignHub v59_FINAL_LUA_RECHECKED
-- Удобный дизайн + проверенная математика по всем редкостям.
-- ALIGN: сам ровняет дорожками и останавливается на нужном Total XP.
-- BUG: сам тепает в нужный камень через neededDurability и реально бьёт/активирует.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local VirtualInputManager=nil
pcall(function() VirtualInputManager=game:GetService("VirtualInputManager") end)
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
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

local gui,frame,status,targetText,currentText,planTextUi,bugText,rebBox,rarityBtn,resultsScroll,resultsLabel
local readPetStable,chooseTreadmillForDiff,getPetTotalAny,bindPress,render
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
	s=tostring(s or ""):lower():gsub("%s+","")
	if s=="" then return nil end

	local mult=1
	if s:find("k",1,true)or s:find("к",1,true)then mult=1e3 end
	if s:find("m",1,true)or s:find("м",1,true)then mult=1e6 end
	if s:find("b",1,true)then mult=1e9 end

	local raw=s:match("[%d%.,]+")
	if not raw then return nil end

	local hasComma=raw:find(",",1,true)~=nil
	local hasDot=raw:find(".",1,true)~=nil

	if hasComma and hasDot then
		-- Если есть оба разделителя, последний считается десятичным, остальные — тысячными.
		local lastComma=raw:match("^.*(),") or 0
		local lastDot=raw:match("^.*()%.") or 0
		local dec=(lastComma>lastDot)and","or"."
		local thou=(dec==",")and"%."or","
		raw=raw:gsub(thou,"")
		if dec==","then raw=raw:gsub(",",".")end
	elseif hasComma or hasDot then
		local sep=hasComma and "," or "."
		local before,after=raw:match("^(.*)%"..sep.."([^"..sep.."]*)$")
		local digitsBefore=(before or ""):gsub("%D","")
		local digitsAfter=(after or ""):gsub("%D","")
		local looksThousands=(mult==1 and #digitsAfter==3 and #digitsBefore>=1)
		if looksThousands then
			raw=raw:gsub("%,",""):gsub("%.","")
		elseif sep==","then
			raw=raw:gsub(",",".")
		end
	end

	local n=tonumber(raw)
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
	local cand=nil

	if _G.PetAPI and _G.PetAPI.GetSelectedPet then
		local ok,res=pcall(_G.PetAPI.GetSelectedPet)
		if ok and res then cand=res end
	end

	if not cand then cand=_G.SelectedPet or _G.Pet end
	if not cand then return nil end

	-- Если глобал случайно указывает на ParticleEmitter/Weight/эффект, просто игнорим.
	if typeof(cand)=="Instance"then
		local path=tostring(cand:GetFullName()):lower()
		local name=tostring(cand.Name):lower()
		if path:find("weight",1,true)and not path:find("pet",1,true)and not path:find("питом",1,true)then
			return nil
		end
		if cand:IsA("ParticleEmitter")or cand:IsA("Trail")or cand:IsA("Beam")then
			return nil
		end
	end

	return cand
end


local function safeChildNumber(child)
	if not child then return nil end
	if typeof(child)=="number"then return child end
	if typeof(child)=="string"then return parseNum(child)end
	if typeof(child)=="Instance"then
		if child:IsA("NumberValue")or child:IsA("IntValue")then return child.Value end
		if child:IsA("StringValue")then return parseNum(child.Value)end
	end
	return nil
end

local function readNumber(obj,names)
	if not obj then return nil end

	-- Table API support.
	if typeof(obj)=="table"then
		for _,n in ipairs(names)do
			local ok,v=pcall(function()return obj[n]end)
			if ok then
				local num=safeChildNumber(v)
				if num then return num end
			end
		end
		return nil
	end

	-- Instance support. Важно: НЕ делаем obj[n].
	-- У Roblox Instance прямой индекс несуществующего свойства кидает ошибку:
	-- "Level is not a valid member of ParticleEmitter".
	if typeof(obj)~="Instance"then return nil end

	for _,n in ipairs(names)do
		local child=nil
		pcall(function()child=obj:FindFirstChild(n)end)
		local num=safeChildNumber(child)
		if num then return num end
	end

	local desc={}
	pcall(function()desc=obj:GetDescendants()end)
	for _,d in ipairs(desc)do
		for _,n in ipairs(names)do
			if d.Name==n then
				local num=safeChildNumber(d)
				if num then return num end
			end
		end
	end

	return nil
end

local function setNumber(obj,names,val)
	if not obj or typeof(obj)~="Instance"then return false end

	for _,n in ipairs(names)do
		local child=nil
		pcall(function()child=obj:FindFirstChild(n)end)
		if typeof(child)=="Instance"and(child:IsA("NumberValue")or child:IsA("IntValue"))then
			child.Value=val
			return true
		end
	end

	local desc={}
	pcall(function()desc=obj:GetDescendants()end)
	for _,d in ipairs(desc)do
		for _,n in ipairs(names)do
			if d.Name==n and(d:IsA("NumberValue")or d:IsA("IntValue"))then
				d.Value=val
				return true
			end
		end
	end

	return false
end


local function objHasWord(obj,words)
	local p=obj
	local hops=0
	while p and p~=game and hops<8 do
		local n=tostring(p.Name):lower()
		for _,w in ipairs(words)do
			if n:find(w,1,true)then return true end
		end
		p=p.Parent
		hops+=1
	end
	return false
end

local function petObjScore(obj)
	local score=0
	local path={}
	local p=obj
	local hops=0
	while p and p~=game and hops<10 do
		local n=tostring(p.Name):lower()
		table.insert(path,n)
		if n:find("equipped",1,true)or n:find("equip",1,true)or n:find("экип",1,true)then score+=250 end
		if n:find("pet",1,true)or n:find("питом",1,true)then score+=120 end
		if n:find("player",1,true)or n:find(tostring(lp.Name):lower(),1,true)then score+=50 end
		if n:find("inventory",1,true)or n:find("storage",1,true)then score-=80 end
		p=p.Parent
		hops+=1
	end
	return score,table.concat(path,"/")
end

local function readPetTotalFromData(rarity)
	local base=BASE[rarity]
	if not base then return nil end

	local roots={
		lp,
		lp:FindFirstChild("PlayerGui"),
		lp:FindFirstChild("Backpack"),
		workspace:FindFirstChild(lp.Name),
		game:GetService("ReplicatedStorage"),
	}

	local best=nil
	local bestScore=-math.huge

	for _,rootObj in ipairs(roots)do
		if rootObj then
			for _,obj in ipairs(rootObj:GetDescendants())do
				local n=tostring(obj.Name):lower()
				local isXPName=n=="xp"or n=="exp"or n=="experience"or n=="totalxp"or n=="totalexp"or n:find("petxp",1,true)or n:find("petexp",1,true)
				if isXPName and (obj:IsA("NumberValue")or obj:IsA("IntValue")or obj:IsA("StringValue"))then
					local xp=parseNum(tostring(obj.Value))
					if xp then
						local lvl=readNumber(obj.Parent,{"Level","Lvl","level","lvl"})
						local total=nil
						if n=="totalxp"or n=="totalexp"or n:find("total",1,true)then
							total=xp
						elseif lvl then
							total=totalFrom(base,lvl,xp)
						end

						if total then
							local sc,path=petObjScore(obj)
							if objHasWord(obj,{"equipped","equip","экип"})then sc+=300 end
							if total>=0 then sc+=10 end
							if sc>bestScore then
								bestScore=sc
								best={total=total,lvl=lvl,xp=xp,src="data:"..path}
							end
						end
					end
				end
			end
		end
	end

	if best and bestScore>100 then
		return best.total,best.src,best.lvl,best.xp
	end
	return nil,nil,nil,nil
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

			local a,b=low:match("([%d%s%.%,kкmмb]+)%s*/%s*([%d%s%.%,kкmмb]+)")
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

function getPetTotalAny(rarity)
	-- 1) Сначала пробуем читать именно данные экипированного питомца.
	local dt,ds,dl,dx=readPetTotalFromData(rarity)
	if dt then return dt,ds,dl,dx end

	-- 2) Потом внешние API/таблицы, если другой скрипт/модуль их создал.
	local pet=selectedPet()
	if pet then
		local total=readNumber(pet,{"TotalXP","TotalExp","totalXP","totalExp"})
		if total then return total,"data",nil,nil end

		local lvl=readNumber(pet,{"Level","Lvl","level","lvl"})
		local xp=readNumber(pet,{"XP","Exp","Experience","xp"})
		if lvl and xp then return totalFrom(BASE[rarity],lvl,xp),"data",lvl,xp end
	end

	-- 3) Последний способ — открытое GUI окно питомца с XP.
	return parsePetGuiTotal(rarity)
end


local function detectGuiRarity()
	-- Сначала GUI-полоска 0/250, 0/500, 0/750...
	for _,rarity in ipairs(RAR_ORDER)do
		local total,src,lvl,xp=parsePetGuiTotal(rarity)
		if total then return rarity,total,src,lvl,xp end
	end

	-- Потом DataModel экипнутого питомца.
	for _,rarity in ipairs(RAR_ORDER)do
		local total,src,lvl,xp=readPetTotalFromData(rarity)
		if total then return rarity,total,src,lvl,xp end
	end

	return nil,nil,nil,nil,nil
end


local function makeCandidateForEnd(rawHit,rarity,rock,endLvl,allowApprox)
	local exact=whole(rawHit)
	if not exact and not allowApprox then return nil end

	local base,stat=BASE[rarity],STAT[rarity]
	local hit=round(rawHit)
	if hit<=0 then return nil end

	local endTotal=cum(base,endLvl)
	local startTotal=endTotal-hit
	if startTotal<0 then return nil end

	local sl,sx=levelFromTotal(base,startTotal)
	local cross=endLvl-sl+1
	if cross<1 then return nil end

	return {
		rarity=rarity,
		rock=rock.id,
		rockLabel=rock.label,
		rockValue=rock.value,
		hit=hit,
		rawHit=rawHit,
		approx=not exact,
		setLvl=sl,
		setXp=sx,
		startTotal=startTotal,
		capLvl=endLvl,
		endTotal=endTotal,
		bonus=cross*stat,
		crossed=cross,
		stat=stat,
		valid=true,
	}
end

local function bestForHit(rawHit,rarity,rock,allowApprox,minStartTotal)
	minStartTotal=minStartTotal or 0
	local best=nil
	local base=BASE[rarity] or 250
	local hit=round(rawHit)
	if hit<=0 then return nil end

	local needTotal=math.max(minStartTotal+hit,hit)
	local approxLvl=math.ceil((math.sqrt(1+(8*needTotal/base))-1)/2)+35
	local hardCap=_G.PetAlignMaxCalcLevel or math.max(900,approxLvl+80)
	local maxLvl=math.clamp(approxLvl,60,hardCap)

	for endLvl=1,maxLvl do
		local cand=makeCandidateForEnd(rawHit,rarity,rock,endLvl,allowApprox)
		if cand and cand.startTotal>=minStartTotal then
			if not best
				or cand.bonus>best.bonus
				or (cand.bonus==best.bonus and cand.startTotal<best.startTotal)
				or (cand.bonus==best.bonus and cand.startTotal==best.startTotal and cand.hit>best.hit)
			then
				best=cand
			end
		end
	end

	return best
end

local function sortCandidates(rows)
	table.sort(rows,function(a,b)
		if (a.approx and 1 or 0)~=(b.approx and 1 or 0) then return not a.approx end
		if a.bonus~=b.bonus then return a.bonus>b.bonus end
		if a.startTotal~=b.startTotal then return a.startTotal<b.startTotal end
		if a.stat~=b.stat then return a.stat>b.stat end
		return a.hit>b.hit
	end)
end

local function allCandidates(reb,filter,minStartTotal)
	local rows={}
	minStartTotal=round(minStartTotal or 0)

	for _,rarity in ipairs(RAR_ORDER)do
		if filter=="Auto"or filter==rarity then
			for _,rock in ipairs(ROCKS)do
				local hit=(reb+20)*rock.value
				local cand=bestForHit(hit,rarity,rock,false,minStartTotal)
				if cand then table.insert(rows,cand)end
			end
		end
	end

	if #rows==0 and _G.PetAlignAllowApprox~=false then
		for _,rarity in ipairs(RAR_ORDER)do
			if filter=="Auto"or filter==rarity then
				for _,rock in ipairs(ROCKS)do
					local hit=(reb+20)*rock.value
					local cand=bestForHit(hit,rarity,rock,true,minStartTotal)
					if cand then table.insert(rows,cand)end
				end
			end
		end
	end

	sortCandidates(rows)
	return rows
end

local function chooseCandidate(reb,filter,now)
	local rows=allCandidates(reb,filter,(now and now+1) or 0)
	if #rows==0 then return nil,rows end
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
	if v:IsA("StringValue")then return parseNum(v.Value)end
	local ok,res=pcall(function()return v.Value end)
	return ok and parseNum(res) or nil
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

		if tostring(v.Name):lower()=="neededdurability"then
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
	table.insert(lines,"PetAlign v59 rock scan")
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
		if VirtualInputManager then VirtualInputManager:SendKeyEvent(down,Enum.KeyCode.W,false,game) end
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

local function runOnTreadmill(part,targetTotal,rarity,expectedGain)
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

	local oldSpeed=hum.WalkSpeed
	local oldAuto=hum.AutoRotate

	-- Не трогаем JumpPower/JumpHeight.
	hum.WalkSpeed=speed
	hum.AutoRotate=true
	pcall(function() hum.Sit=false end)
	pcall(function() hum.PlatformStand=false end)

	local heightAbove=math.clamp((hum.HipHeight or 2)+1.15,2.7,4.0)
	local y=part.Position.Y+part.Size.Y/2+heightAbove
	local center=Vector3.new(part.Position.X,y,part.Position.Z)

	local function place()
		local rr=root()
		if rr then
			rr.CFrame=CFrame.lookAt(center,center+dir)
			rr.AssemblyAngularVelocity=Vector3.zero
		end
	end

	place()
	task.wait(.18)

	local started=os.clock()
	local maxRun=_G.PetAlignOneStepMaxSeconds or 34
	local minRun=_G.PetAlignMinTreadmillRunSeconds or 1.2
	local stable=0
	local startXp=readPetStable(rarity,3,.04) or 0
	local lastXp=startXp
	local lastGainTime=os.clock()
	local flipped=false
	local mode=1

	local maxLong=math.max(1.6,length/2-1.15)
	local maxSide=math.max(.7,width/2-.65)
	local stepSign=-1

	while not _G.PetAlignStop do
		local elapsed=os.clock()-started

		if elapsed>=minRun then
			local now=readPetStable(rarity,3,.03)
			if now then
				if now>=targetTotal then stable+=1 else stable=0 end
				statusText("ALIGN: "..fmt(now).."/"..fmt(targetTotal).." | бег m"..mode.." | "..stable.."/4")
				if stable>=4 then break end

				if now>lastXp then
					lastXp=now
					lastGainTime=os.clock()
				end

				local noGain=os.clock()-lastGainTime
				if not flipped and noGain>6 then
					flipped=true
					dir=-dir
					side=Vector3.new(-dir.Z,0,dir.X)
					statusText("ALIGN: XP не идёт, меняю сторону")
					place()
					task.wait(.15)
				elseif mode==1 and noGain>10 then
					mode=2
					statusText("ALIGN: включаю мягкий бег")
				elseif mode==2 and noGain>16 then
					mode=3
					statusText("ALIGN: включаю аварийный шаг")
				end
			end
		end

		if elapsed>maxRun then break end

		r=root()
		if not r then break end

		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
		hum:Move(dir,false)
		pcall(function() hum:MoveTo(r.Position+dir*16) end)

		-- m1: только Humanoid move. m2: мягкая скорость. m3: микрошаг по полотну.
		if mode>=2 then
			local v=r.AssemblyLinearVelocity
			r.AssemblyLinearVelocity=Vector3.new(dir.X*speed,v.Y,dir.Z*speed)
		end

		if mode>=3 then
			local rel=r.Position-part.Position
			local long=rel:Dot(dir)
			if long>maxLong-.35 then stepSign=-1 end
			if long<-maxLong+.35 then stepSign=1 end
			local target=center+dir*(long+stepSign*.55)
			r.CFrame=CFrame.lookAt(Vector3.new(target.X,r.Position.Y,target.Z),Vector3.new(target.X,r.Position.Y,target.Z)+dir)
		end

		local rel=r.Position-part.Position
		local long=rel:Dot(dir)
		local sideOff=rel:Dot(side)

		if math.abs(long)>maxLong or math.abs(sideOff)>maxSide then
			local fixedLong=math.clamp(long,-maxLong,maxLong)
			local fixedSide=math.clamp(sideOff,-maxSide,maxSide)
			local fixed=Vector3.new(part.Position.X,r.Position.Y,part.Position.Z)+dir*fixedLong+side*fixedSide
			r.CFrame=CFrame.lookAt(fixed,fixed+dir)
			r.AssemblyAngularVelocity=Vector3.zero
		end

		RunService.Heartbeat:Wait()
	end

	pressW(false)
	hum:Move(Vector3.zero,false)
	pcall(function()
		local rr=root()
		if rr then
			local v=rr.AssemblyLinearVelocity
			rr.AssemblyLinearVelocity=Vector3.new(0,v.Y,0)
			hum:MoveTo(rr.Position)
		end
	end)

	hum.WalkSpeed=oldSpeed
	hum.AutoRotate=oldAuto

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
	if not reb or reb<0 then return nil,nil,"Впиши ребы вручную, например 63.4k или 0.",{} end

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

	local rows=allCandidates(reb,filter,(now and now+1) or 0)
	if #rows==0 then return nil,now,"Нет вариантов выше текущего XP. Проверь ребы/редкость.",{} end

	choiceRows=rows

	if selectedCard<1 then selectedCard=1 end
	if selectedCard>#rows then selectedCard=1 end

	local data=rows[selectedCard]
	if not data then data=rows[1] selectedCard=1 end

	current=data
	return data,now,nil,rows
end


local function alignPickRow(rows,now,preferIndex,preferData)
	if not rows or #rows==0 then return nil,nil,"noRows" end
	now=round(now or 0)

	-- Если игрок выбрал конкретную карточку в Auto-списке, после перечитывания XP
	-- не выбираем тупо тот же номер в уже отфильтрованном списке. Сначала ищем тот же вариант.
	if preferData then
		for i,row in ipairs(rows)do
			if row.startTotal and row.startTotal>now
				and row.rarity==preferData.rarity
				and row.rock==preferData.rock
				and round(row.hit or 0)==round(preferData.hit or 0)
				and round(row.startTotal or 0)==round(preferData.startTotal or 0)
			then
				return row,i,"selectedExact"
			end
		end

		for i,row in ipairs(rows)do
			if row.startTotal and row.startTotal>now
				and row.rarity==preferData.rarity
				and row.rock==preferData.rock
			then
				return row,i,"selectedSameRock"
			end
		end
	end

	local preferred=rows[preferIndex or 1]
	if preferred and preferred.startTotal and preferred.startTotal>now then
		return preferred,preferIndex,"selectedIndex"
	end

	for i,row in ipairs(rows)do
		if row.startTotal and row.startTotal>now then
			return row,i,"autoAbove"
		end
	end

	return nil,nil,"allBelow"
end


local function readPetStableInfo(rarity,tries,delay)
	tries=tries or 5
	delay=delay or .06
	local vals={}
	local lastSrc,lastLvl,lastXp=nil,nil,nil

	for _=1,tries do
		local v,src,lvl,xp=getPetTotalAny(rarity)
		if v then
			table.insert(vals,round(v))
			lastSrc,lastLvl,lastXp=src,lvl,xp
		end
		task.wait(delay)
	end

	if #vals==0 then return nil,nil,nil,nil end
	table.sort(vals)
	return vals[math.ceil(#vals/2)],lastSrc,lastLvl,lastXp
end

local function makeAlignDebugLine(data,now,src,lvl,xp,reason)
	local t={}
	table.insert(t,"ALIGN DEBUG")
	table.insert(t,"Reason: "..tostring(reason or "-"))
	table.insert(t,"Rarity: "..tostring(data and data.rarity or "?"))
	table.insert(t,"NowTotal: "..fmt(now or 0))
	table.insert(t,"Source: "..tostring(src or "?"))
	if lvl then table.insert(t,"Level: "..fmt(lvl))end
	if xp then table.insert(t,"XP: "..fmt(xp))end
	if data then
		table.insert(t,"TargetTotal: "..fmt(data.startTotal))
		table.insert(t,"Need: "..fmt((data.startTotal or 0)-(now or 0)))
		table.insert(t,"Rock: "..tostring(data.rockLabel))
		table.insert(t,"Hit: +"..fmt(data.hit or 0))
	end
	return table.concat(t,"\n")
end



local function setZ(obj,z)
	pcall(function()obj.ZIndex=z end)
	for _,ch in ipairs(obj:GetChildren())do
		setZ(ch,z)
	end
end

function bindPress(btn,callback)
	-- Activated работает и мышью, и тачем, и геймпадом.
	-- MouseButton1Click оставлен как запасной вариант, но с защитой от двойного вызова.
	if not btn or not callback then return end
	pcall(function() btn.Active=true end)
	pcall(function() btn.Selectable=true end)
	local last=0
	local function fire()
		local now=os.clock()
		if now-last<0.12 then return end
		last=now
		callback()
	end
	pcall(function()btn.Activated:Connect(fire)end)
	pcall(function()btn.MouseButton1Click:Connect(fire)end)
end

function readPetStable(rarity,tries,delay)
	tries=tries or 5
	delay=delay or .08
	local vals={}
	for _=1,tries do
		local v=getPetTotalAny(rarity)
		if v then table.insert(vals,round(v))end
		task.wait(delay)
	end
	if #vals==0 then return nil end
	table.sort(vals)
	return vals[math.ceil(#vals/2)]
end

function chooseTreadmillForDiff(diff)
	diff=round(diff)
	if diff<=0 then return nil,nil end
	local gain=math.clamp(diff,1,6)
	local part,idx,total=treadmillPart(gain)
	if part then return part,gain,idx,total end

	for g=gain,1,-1 do
		part,idx,total=treadmillPart(g)
		if part then return part,g,idx,total end
	end

	return nil,nil,idx,total
end

local function doAlign()
	if running then return end
	running=true
	_G.PetAlignStop=false
	stopRockLock()
	pcall(uiFront)

	render()

	local baseData,baseNow,err,rows=getData()
	if err then
		statusText(err)
		lastReport="ALIGN ERROR\n"..tostring(err)
		running=false
		pcall(uiFront)
		return
	end

	-- Надёжное чтение XP прямо перед стартом, не верим старому render().
	local now,src,lvl,xp=readPetStableInfo(baseData.rarity,7,.06)
	if not now then
		statusText("ALIGN: XP не прочитан. Открой окно питомца с XP.")
		lastReport="ALIGN ERROR\nXP не прочитан\nОткрой окно питомца с XP."
		running=false
		pcall(uiFront)
		return
	end

	local reb=parseNum(rebBox.Text)
	local filter=baseData.rarity
	rows=allCandidates(reb,filter,now+1)
	choiceRows=rows

	local data,pickedIndex,why=alignPickRow(rows,now,selectedCard,baseData)
	if not data then
		statusText("ALIGN: нет карточек выше текущего XP. Проверь редкость/ребы.")
		lastReport=makeAlignDebugLine(baseData,now,src,lvl,xp,why)
		running=false
		pcall(uiFront)
		return
	end

	if pickedIndex and pickedIndex~=selectedCard then
		selectedCard=pickedIndex
		current=data
		render()
	end

	statusText("ALIGN: цель "..fmt(data.startTotal).." | сейчас "..fmt(now).." | "..tostring(src or "?"))
	lastReport=makeAlignDebugLine(data,now,src,lvl,xp,why)

	local startTime=os.clock()
	local stable=0

	while not _G.PetAlignStop do
		now,src,lvl,xp=readPetStableInfo(data.rarity,5,.05)

		if not now then
			statusText("ALIGN: потерял чтение XP. Открой окно питомца.")
			lastReport="ALIGN ERROR\nПотерял чтение XP во время выравнивания."
			break
		end

		local diff=round(data.startTotal-now)

		if diff<=0 then
			stable+=1
			statusText("ALIGN: цель достигнута "..fmt(now).."/"..fmt(data.startTotal).." | "..stable.."/5")
			if stable>=5 then break end
			task.wait(.15)
		else
			stable=0

			local part,gain,idx,total=chooseTreadmillForDiff(diff)
			if not part then
				statusText("ALIGN: не нашёл дорожку +"..tostring(math.clamp(diff,1,6)).." idx="..tostring(idx).."/"..tostring(total))
				lastReport=makeAlignDebugLine(data,now,src,lvl,xp,"treadmillNotFound idx="..tostring(idx).." total="..tostring(total))
				break
			end

			local segmentTarget=math.min(data.startTotal,now+gain)
			statusText("ALIGN: осталось "..fmt(diff).." XP → дорожка +"..gain.." ["..tostring(idx).."]")
			runOnTreadmill(part,segmentTarget,data.rarity,gain)
		end

		if os.clock()-startTime>(_G.PetAlignMaxTotalSeconds or 420)then
			statusText("ALIGN: таймаут. Сейчас "..fmt(now).."/"..fmt(data.startTotal))
			lastReport=makeAlignDebugLine(data,now,src,lvl,xp,"timeout")
			break
		end
	end

	local final,fsrc,flvl,fxp=readPetStableInfo(data.rarity,7,.06)
	if final and final>=data.startTotal then
		statusText("ALIGN готов: "..fmt(final).." XP. Можно BUG.")
		lastReport=makeAlignDebugLine(data,final,fsrc,flvl,fxp,"done")
	else
		statusText("ALIGN остановлен: "..fmt(final or 0).."/"..fmt(data.startTotal))
		lastReport=makeAlignDebugLine(data,final or 0,fsrc,flvl,fxp,"stopped")
	end

	render()
	pcall(uiFront)
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


-- UI REBUILD v49 — simple mobile layout, no clipping
gui=Instance.new("ScreenGui")
gui.Name="PetAlignSimpleV59"
gui.ResetOnSpawn=false
gui.DisplayOrder=999999
gui.IgnoreGuiInset=true
gui.Parent=lp:WaitForChild("PlayerGui")

local function makeCorner(obj,r)
	local c=Instance.new("UICorner",obj)
	c.CornerRadius=UDim.new(0,r or 10)
	return c
end

local function makeStroke(obj,col,thick,trans)
	local s=Instance.new("UIStroke",obj)
	s.Color=col or Color3.fromRGB(110,70,255)
	s.Thickness=thick or 1
	s.Transparency=trans or 0
	return s
end

local function mkLabel(parent,txt,x,y,w,h,size,col,bold)
	local l=Instance.new("TextLabel",parent)
	l.Size=UDim2.new(0,w,0,h)
	l.Position=UDim2.new(0,x,0,y)
	l.BackgroundTransparency=1
	l.Text=txt
	l.TextColor3=col or Color3.fromRGB(235,230,255)
	l.Font=bold and Enum.Font.GothamBlack or Enum.Font.GothamBold
	l.TextSize=size or 11
	l.TextXAlignment=Enum.TextXAlignment.Left
	l.TextYAlignment=Enum.TextYAlignment.Center
	l.TextWrapped=true
	return l
end

local BASE_W,BASE_H=350,520

frame=Instance.new("Frame",gui)
frame.Name="Main"
frame.Size=UDim2.new(0,BASE_W,0,BASE_H)
frame.Position=UDim2.new(0,8,0,82)
frame.BackgroundColor3=Color3.fromRGB(10,10,22)
frame.BorderSizePixel=0
frame.Active=true
frame.ClipsDescendants=true
makeCorner(frame,14)
makeStroke(frame,Color3.fromRGB(125,72,255),1.5,.05)

local uiScale=Instance.new("UIScale",frame)
uiScale.Scale=1

local mini=Instance.new("TextButton",gui)
mini.Name="OpenMini"
mini.Size=UDim2.new(0,62,0,34)
mini.Position=UDim2.new(0,8,0,82)
mini.BackgroundColor3=Color3.fromRGB(70,40,160)
mini.Text="PET"
mini.TextColor3=Color3.new(1,1,1)
mini.Font=Enum.Font.GothamBlack
mini.TextSize=13
mini.Visible=false
makeCorner(mini,10)
makeStroke(mini,Color3.fromRGB(150,90,255),1,.1)

local top=Instance.new("Frame",frame)
top.Size=UDim2.new(1,0,0,42)
top.Position=UDim2.new(0,0,0,0)
top.BackgroundColor3=Color3.fromRGB(15,14,34)
top.BorderSizePixel=0
makeCorner(top,14)

mkLabel(top,"Pet Align v59",12,0,190,42,16,Color3.fromRGB(255,255,255),true)
mkLabel(top,"mobile",204,0,70,42,10,Color3.fromRGB(170,140,255),true)

local minBtn=Instance.new("TextButton",top)
minBtn.Size=UDim2.new(0,30,0,28)
minBtn.Position=UDim2.new(1,-68,0,7)
minBtn.Text="−"
minBtn.TextColor3=Color3.new(1,1,1)
minBtn.BackgroundColor3=Color3.fromRGB(45,38,80)
minBtn.Font=Enum.Font.GothamBlack
minBtn.TextSize=17
makeCorner(minBtn,8)

local close=Instance.new("TextButton",top)
close.Size=UDim2.new(0,30,0,28)
close.Position=UDim2.new(1,-34,0,7)
close.Text="×"
close.TextColor3=Color3.fromRGB(255,190,200)
close.BackgroundColor3=Color3.fromRGB(70,22,36)
close.Font=Enum.Font.GothamBlack
close.TextSize=17
makeCorner(close,8)

mkLabel(frame,"Ребы",12,48,70,18,10,Color3.fromRGB(170,165,205),false)
rebBox=Instance.new("TextBox",frame)
rebBox.Size=UDim2.new(0,186,0,32)
rebBox.Position=UDim2.new(0,12,0,68)
rebBox.Text=""
rebBox.PlaceholderText="63.4k"
rebBox.ClearTextOnFocus=false
rebBox.TextColor3=Color3.new(1,1,1)
rebBox.PlaceholderColor3=Color3.fromRGB(135,130,165)
rebBox.BackgroundColor3=Color3.fromRGB(28,25,55)
rebBox.Font=Enum.Font.GothamBlack
rebBox.TextSize=13
makeCorner(rebBox,9)

mkLabel(frame,"Редкость",210,48,90,18,10,Color3.fromRGB(170,165,205),false)
rarityBtn=Instance.new("TextButton",frame)
rarityBtn.Size=UDim2.new(0,126,0,32)
rarityBtn.Position=UDim2.new(0,210,0,68)
rarityBtn.Text="Auto"
rarityBtn.TextColor3=Color3.new(1,1,1)
rarityBtn.BackgroundColor3=Color3.fromRGB(64,50,128)
rarityBtn.Font=Enum.Font.GothamBlack
rarityBtn.TextSize=12
makeCorner(rarityBtn,9)

local function infoCard(x,y,w,h,title,col)
	local f=Instance.new("Frame",frame)
	f.Size=UDim2.new(0,w,0,h)
	f.Position=UDim2.new(0,x,0,y)
	f.BackgroundColor3=col
	f.BorderSizePixel=0
	makeCorner(f,11)
	makeStroke(f,Color3.fromRGB(65,55,110),1,.35)
	mkLabel(f,title,9,5,w-18,18,11,Color3.fromRGB(255,255,255),true)

	local body=Instance.new("TextLabel",f)
	body.Size=UDim2.new(1,-18,1,-28)
	body.Position=UDim2.new(0,9,0,27)
	body.BackgroundTransparency=1
	body.TextColor3=Color3.fromRGB(255,238,170)
	body.Font=Enum.Font.GothamBold
	body.TextSize=9
	body.TextWrapped=true
	body.TextXAlignment=Enum.TextXAlignment.Left
	body.TextYAlignment=Enum.TextYAlignment.Top
	return body
end

targetText=infoCard(12,108,326,76,"ВЫБРАННЫЙ ВАРИАНТ",Color3.fromRGB(22,40,32))
currentText=infoCard(12,192,158,74,"ПЕТ",Color3.fromRGB(25,26,55))
planTextUi=infoCard(180,192,158,74,"ALIGN",Color3.fromRGB(22,34,54))
bugText=infoCard(12,274,326,58,"BUG",Color3.fromRGB(54,24,38))

mkLabel(frame,"Карточки вариантов",12,336,170,18,11,Color3.fromRGB(225,220,255),true)
resultsLabel=mkLabel(frame,"0",256,336,80,18,10,Color3.fromRGB(170,165,205),false)
resultsLabel.TextXAlignment=Enum.TextXAlignment.Right

resultsScroll=Instance.new("ScrollingFrame",frame)
resultsScroll.Size=UDim2.new(0,326,0,92)
resultsScroll.Position=UDim2.new(0,12,0,358)
resultsScroll.BackgroundColor3=Color3.fromRGB(15,16,32)
resultsScroll.BorderSizePixel=0
resultsScroll.ScrollBarThickness=5
resultsScroll.Active=true
resultsScroll.ScrollingEnabled=true
resultsScroll.ZIndex=20
resultsScroll.CanvasSize=UDim2.new(0,0,0,0)
makeCorner(resultsScroll,11)
makeStroke(resultsScroll,Color3.fromRGB(70,58,130),1,.25)

local pad=Instance.new("UIPadding",resultsScroll)
pad.PaddingTop=UDim.new(0,6)
pad.PaddingLeft=UDim.new(0,6)
pad.PaddingRight=UDim.new(0,6)
pad.PaddingBottom=UDim.new(0,6)

local layout=Instance.new("UIListLayout",resultsScroll)
layout.Padding=UDim.new(0,6)
layout.SortOrder=Enum.SortOrder.LayoutOrder

status=Instance.new("TextLabel",frame)
status.Size=UDim2.new(0,326,0,24)
status.Position=UDim2.new(0,12,0,454)
status.BackgroundTransparency=1
status.Text="Выбери карточку. ALIGN ровняет, BUG бьёт."
status.TextColor3=Color3.fromRGB(185,178,220)
status.Font=Enum.Font.GothamBold
status.TextSize=9
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left

local function btn(txt,x,w,col)
	local b=Instance.new("TextButton",frame)
	b.Size=UDim2.new(0,w,0,32)
	b.Position=UDim2.new(0,x,0,482)
	b.Text=txt
	b.TextColor3=Color3.new(1,1,1)
	b.BackgroundColor3=col
	b.Font=Enum.Font.GothamBlack
	b.TextSize=10
	makeCorner(b,9)
	return b
end

local alignBtn=btn("ALIGN",12,62,Color3.fromRGB(55,95,190))
local bugBtn=btn("BUG",80,52,Color3.fromRGB(35,140,70))
local scanBtn=btn("SCAN",138,56,Color3.fromRGB(80,65,160))
local copyBtn=btn("COPY",200,56,Color3.fromRGB(130,85,35))
local stopBtn=btn("STOP",262,76,Color3.fromRGB(130,35,48))

function uiFront()
	if gui then
		gui.DisplayOrder=999999
		gui.IgnoreGuiInset=true
		gui.ResetOnSpawn=false
	end
	if frame then
		frame.Visible=true
		frame.Active=true
	end
end

local function clampFramePos(pos)
	local cam=workspace.CurrentCamera
	local vp=cam and cam.ViewportSize or Vector2.new(900,600)
	local scale=(uiScale and uiScale.Scale) or 1
	local w=BASE_W*scale
	local h=BASE_H*scale
	local minX=4
	local minY=36
	local maxX=math.max(minX,vp.X-w-4)
	local maxY=math.max(minY,vp.Y-h-4)
	local x=math.clamp(pos.X.Offset,minX,maxX)
	local y=math.clamp(pos.Y.Offset,minY,maxY)
	return UDim2.new(0,math.floor(x),0,math.floor(y))
end

local function setFramePos(pos)
	local p=clampFramePos(pos)
	frame.Position=p
	mini.Position=p
end

local function fitToScreen()
	if not frame or not frame.Parent then return end
	local cam=workspace.CurrentCamera
	local vp=cam and cam.ViewportSize or Vector2.new(900,600)
	local s=math.min(1,(vp.X-16)/BASE_W,(vp.Y-74)/BASE_H)
	if s<.65 then s=.65 end
	uiScale.Scale=s
	setFramePos(UDim2.new(0,8,0,math.max(45,math.floor(vp.Y*.12))))
end

pcall(function()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)
	end
end)
task.defer(fitToScreen)

local dragging=false
local dragStart=nil
local startPos=nil
top.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		-- Верхняя панель двигает окно, но зона кнопок справа не начинает drag.
		local localX=input.Position.X-top.AbsolutePosition.X
		local buttonZone=80*((uiScale and uiScale.Scale)or 1)
		if localX>top.AbsoluteSize.X-buttonZone then return end
		dragging=true
		dragStart=input.Position
		startPos=frame.Position
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then
		local delta=input.Position-dragStart
		setFramePos(UDim2.new(0,startPos.X.Offset+delta.X,0,startPos.Y.Offset+delta.Y))
	end
end)

function render()
	local data,now,err,rows=getData()

	if err then
		targetText.Text=err
		currentText.Text="Открой окно питомца."
		planTextUi.Text="-"
		bugText.Text="-"
		lastReport=err
	else
		local diff=now and (data.startTotal-now) or nil
		local plan=nil
		if diff and diff>=0 then plan=makePlan(diff)end

		targetText.Text=
			(data.approx and "≈ " or "")..data.rarity.." | "..data.rockLabel..
			"\nЦель: "..fmt(data.setLvl).." lvl, "..fmt(data.setXp).." XP"..
			"\nTotal "..fmt(data.startTotal).." | hit +"..fmt(data.hit).." | +"..fmt(data.bonus)

		if now then
			currentText.Text="Сейчас: "..fmt(now).." XP\nДо цели: "..(diff and fmt(diff)or"?")
		else
			currentText.Text="XP не прочитан\nОткрой пета."
		end

		if diff then
			if diff<0 then
				planTextUi.Text="Вариант ниже XP.\nВыбери другой."
			else
				planTextUi.Text=planToString(plan).."\nАвтостоп 5 чтений."
			end
		else
			planTextUi.Text="Жду XP."
		end

		bugText.Text="Теп в "..data.rockLabel.."\nRemote punch + touch руками."

		lastReport=
			"PetAlign v59\n"..
			"Card #"..tostring(selectedCard).."\n"..
			"Pet: "..data.rarity.."\n"..
			"Rock: "..data.rockLabel.."\n"..
			"Set: "..fmt(data.setLvl).." lvl, "..fmt(data.setXp).." XP\n"..
			"TargetTotal: "..fmt(data.startTotal).."\n"..
			"Hit: +"..fmt(data.hit).."\n"..
			"Bonus: +"..fmt(data.bonus).." stats\n"..
			"Now: "..fmt(now or 0).."\n"..
			"Align: "..(plan and planToString(plan) or "-")
	end

	local count=(rows and #rows)or 0
	if resultsLabel then resultsLabel.Text=tostring(count).." вариантов" end

	for _,child in ipairs(resultsScroll:GetChildren())do
		if child:IsA("TextButton")then child:Destroy()end
	end
	choiceCards={}
	pcall(function()resultsScroll.CanvasPosition=Vector2.new(0,0)end)

	for i=1,count do
		local row=rows[i]
		local card=choiceCards[i]
		if not card then
			local idx=i
			card=Instance.new("TextButton",resultsScroll)
			card.Name="ChoiceCard"..idx
			card.Size=UDim2.new(1,-4,0,62)
			card.BackgroundColor3=Color3.fromRGB(25,26,50)
			card.BorderSizePixel=0
			card.AutoButtonColor=false
			card.Font=Enum.Font.GothamBlack
			card.TextSize=9
			card.TextWrapped=true
			card.TextXAlignment=Enum.TextXAlignment.Left
			card.TextYAlignment=Enum.TextYAlignment.Center
			card.TextColor3=Color3.fromRGB(255,238,170)
			card.LayoutOrder=idx
			card.ZIndex=21
			makeCorner(card,9)
			makeStroke(card,Color3.fromRGB(85,65,150),1,.25)
			bindPress(card,function()
				selectedCard=idx
				current=choiceRows[idx]
				render()
				statusText("Выбрана карточка #"..idx)
			end)
			choiceCards[idx]=card
		end

		card.Visible=true
		card.LayoutOrder=i
		card.Text=("#%d %s | %s\n%s lvl, %s XP | hit +%s | +%s"):format(
			i,(row.approx and "≈ "..row.rarity or row.rarity),row.rockLabel,fmt(row.setLvl),fmt(row.setXp),fmt(row.hit),fmt(row.bonus)
		)
		if i==selectedCard then
			card.BackgroundColor3=Color3.fromRGB(72,58,145)
		else
			card.BackgroundColor3=Color3.fromRGB(25,26,50)
		end
	end

	for i=count+1,#choiceCards do
		choiceCards[i].Visible=false
	end
	resultsScroll.CanvasSize=UDim2.new(0,0,0,count*68+8)
	uiFront()
end

bindPress(minBtn,function()
	frame.Visible=false
	mini.Visible=true
end)

bindPress(mini,function()
	frame.Visible=true
	mini.Visible=false
end)

bindPress(alignBtn,function()
	task.spawn(function()
		local ok,err=pcall(doAlign)
		if not ok then statusText("ALIGN error: "..tostring(err):sub(1,95)) running=false stopRockLock() end
	end)
end)

bindPress(bugBtn,function()
	task.spawn(function()
		local ok,err=pcall(doBug)
		if not ok then statusText("BUG error: "..tostring(err):sub(1,95)) running=false stopRockLock() end
	end)
end)

bindPress(scanBtn,function()
	task.spawn(function()
		statusText("Скан скал...")
		local ok,err=pcall(function()
			local report,count=makeRockReport()
			lastReport=report
			if setclipboard then pcall(setclipboard,report)end
			statusText("Скалы: "..count..". Отчёт скопирован.")
		end)
		if not ok then statusText("SCAN error: "..tostring(err):sub(1,90))end
	end)
end)

bindPress(copyBtn,function()
	render()
	if setclipboard then
		pcall(setclipboard,lastReport)
		statusText("Отчёт скопирован.")
	else
		statusText("Clipboard недоступен.")
	end
end)

bindPress(stopBtn,function()
	_G.PetAlignStop=true
	running=false
	stopRockLock()
	pressW(false)
	statusText("Остановлено.")
end)

bindPress(rarityBtn,function()
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

bindPress(close,function()
	_G.PetAlignStop=true
	running=false
	stopRockLock()
	pressW(false)
	gui:Destroy()
end)

_G.PetAlignSimple={
	Align=function()task.spawn(doAlign)end,
	Bug=function()task.spawn(doBug)end,
	Stop=function()_G.PetAlignStop=true running=false stopRockLock() pressW(false)end,
	Scan=function()rockRowsCache=scanNeededRocks()end,
}

local d=nil
pcall(function()
	local ls=lp:FindFirstChild("leaderstats")
	if ls then
		for _,v in ipairs(ls:GetChildren())do
			local n=v.Name:lower()
			if n:find("rebirth",1,true)or n:find("перер",1,true)then
				d=parseNum(v.Value)
			end
		end
	end
end)

if d and tonumber(d) and tonumber(d)>=0 then
	rebBox.Text=tostring(d)
else
	rebBox.Text=""
end
statusText("v59: перепроверено, дублей render/uiFront нет, кнопки/карточки через Activated.")
render()
