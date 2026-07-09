-- Muscle Legends RockBug Hub v17 NeoPatch
-- Standalone: без Speed Hub. Камни через neededDurability + TP LOCK + BUG HIT + Anti AFK.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local VirtualUser=game:GetService("VirtualUser")
local lp=Players.LocalPlayer
local HUB_VERSION="RockBugHub_v17_NeoPatch"

-- Anti AFK
local antiAfkEnabled=true
local antiAfkConn=nil
local function startAntiAfk()
	if antiAfkConn then antiAfkConn:Disconnect() antiAfkConn=nil end
	antiAfkConn=lp.Idled:Connect(function()
		if not antiAfkEnabled then return end
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
end
startAntiAfk()

-- Анти-дубль: сносит старые окна RockBugHub.
pcall(function()
	local pg=lp:WaitForChild("PlayerGui")
	for _,g in ipairs(pg:GetChildren()) do
		if g:IsA("ScreenGui") and tostring(g.Name):find("RockBugHub",1,true) then
			g:Destroy()
		end
	end
end)




local ROCKS={
	{id="AncientJungle",label="Древний лес",req=10000000,color=Color3.fromRGB(120,70,255)},
	{id="MuscleKing",label="Король мышц",req=5000000,color=Color3.fromRGB(255,190,80)},
	{id="Legends",label="Легенды",req=1000000,color=Color3.fromRGB(90,170,255)},
	{id="Inferno",label="Инферно",req=750000,color=Color3.fromRGB(255,85,85)},
	{id="Mystic",label="Мистический",req=400000,color=Color3.fromRGB(180,90,255)},
	{id="Frozen",label="Ледяной",req=150000,color=Color3.fromRGB(95,220,255)},
	{id="Golden",label="Золотой",req=5000,color=Color3.fromRGB(255,210,65)},
	{id="Large",label="Большой",req=100,color=Color3.fromRGB(170,170,190)},
	{id="Punching",label="Пробивной",req=10,color=Color3.fromRGB(255,130,90)},
	{id="Tiny",label="Маленький",req=0,color=Color3.fromRGB(110,255,155)},
}

local selected=ROCKS[1]
local rockCache={}
local lockConn=nil
local hitConn=nil
local lockCF=nil
local oldSpeed=nil
local oldAuto=nil
local hitting=false
local fastHitEnabled=false
local ultraOptEnabled=false
local fastHitPower=1
local autoTrainEnabled=false
local autoTrainLoopId=0
local selectedTrainToolName=nil

-- MAX PUNCH / AUTO TRAIN под постоянную ссылку:
-- Вкладка БАГ = TP LOCK + MAX PUNCH по камню.
-- Вкладка КАЧ = Auto Train не только ударами, а любым тренировочным Tool.
if not _G.RockBugV13TabsNoForce then
	_G.RockBugMaxPunchRate=tonumber(_G.RockBugMaxPunchRateOverride) or 90
	_G.RockBugExtraCyclesPerTick=tonumber(_G.RockBugExtraCyclesPerTickOverride) or 2
	_G.RockBugRemoteLoops=tonumber(_G.RockBugRemoteLoopsOverride) or 6
	_G.RockBugActivateBursts=tonumber(_G.RockBugActivateBurstsOverride) or 4
	_G.RockBugTouchLoops=tonumber(_G.RockBugTouchLoopsOverride) or 3
	_G.RockBugTouchEvery=tonumber(_G.RockBugTouchEveryOverride) or 1
	_G.RockBugAnimSpeed=tonumber(_G.RockBugAnimSpeedOverride) or 4

	_G.RockBugAutoTrainRate=tonumber(_G.RockBugAutoTrainRateOverride) or 35
	_G.RockBugAutoTrainActivateBursts=tonumber(_G.RockBugAutoTrainActivateBurstsOverride) or 2
	_G.RockBugAutoTrainRemoteLoops=tonumber(_G.RockBugAutoTrainRemoteLoopsOverride) or 2
	_G.RockBugAutoTrainUseRemote=(_G.RockBugAutoTrainUseRemote~=false)
end

local function root()
	local c=lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function char()
	return lp.Character or lp.CharacterAdded:Wait()
end

local function hum()
	local c=lp.Character
	return c and c:FindFirstChildWhichIsA("Humanoid")
end

local function valOf(v)
	if not v then return nil end
	if v:IsA("IntValue")or v:IsA("NumberValue")then return tonumber(v.Value)end
	if v:IsA("StringValue")then return tonumber(v.Value)end
	local ok,res=pcall(function()return tonumber(v.Value)end)
	if ok then return res end
	return nil
end

local function hasHands(obj)
	if not obj then return false end
	local l=obj:FindFirstChild("LeftHand",true)
	local r=obj:FindFirstChild("RightHand",true)
	return l~=nil and r~=nil
end

local function findRockModelFromValue(valueObj)
	local p=valueObj
	for _=1,8 do
		if not p or p==workspace then break end
		if hasHands(p) then return p end
		p=p.Parent
	end

	p=valueObj.Parent
	for _=1,4 do
		if not p or p==workspace then break end
		for _,d in ipairs(p:GetDescendants())do
			if hasHands(d)then return d end
		end
		p=p.Parent
	end

	return valueObj.Parent
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

local function scanRocks()
	local found={}
	local all=workspace:GetDescendants()

	for _,v in ipairs(all)do
		if tostring(v.Name)=="neededDurability"then
			local req=valOf(v)
			if req~=nil then
				local model=findRockModelFromValue(v)
				local body=biggestPart(model)
				local lh=model and model:FindFirstChild("LeftHand",true)
				local rh=model and model:FindFirstChild("RightHand",true)
				local hit=rh or lh or body

				if body or hit then
					found[req]={
						req=req,
						valueObj=v,
						model=model,
						body=body,
						hit=hit,
						left=lh,
						right=rh,
						name=model and model.Name or "?",
					}
				end
			end
		end
	end

	rockCache=found
	return found
end

local function getRock(row)
	if not row then return nil end
	if not rockCache[row.req]then scanRocks()end
	return rockCache[row.req]
end

local lowMapState={
	on=false,
	saved={},
	count=0,
	lighting={},
}

local function isProtectedFromLowMap(obj,keepModel)
	local c=lp.Character
	if c and obj:IsDescendantOf(c)then return true end
	if keepModel and obj:IsDescendantOf(keepModel)then return true end
	return false
end

local function lowSave(obj,key,val)
	local rec=lowMapState.saved[obj]
	if not rec then
		rec={}
		lowMapState.saved[obj]=rec
	end
	if rec[key]==nil then rec[key]=val end
end

local function setLowMap(enabled,keepModel,statusFn)
	if enabled then
		if lowMapState.on then return end
		lowMapState.on=true
		lowMapState.saved={}
		lowMapState.count=0

		local lighting=game:GetService("Lighting")
		pcall(function()
			lowMapState.lighting.GlobalShadows=lighting.GlobalShadows
			lighting.GlobalShadows=false
		end)

		for _,obj in ipairs(workspace:GetDescendants())do
			if not isProtectedFromLowMap(obj,keepModel)then
				if obj:IsA("BasePart")then
					lowSave(obj,"LocalTransparencyModifier",obj.LocalTransparencyModifier)
					lowSave(obj,"CastShadow",obj.CastShadow)
					pcall(function()
						obj.LocalTransparencyModifier=math.max(obj.LocalTransparencyModifier,_G.RockBugLowMapTransparency or 1)
						obj.CastShadow=false
					end)
					lowMapState.count+=1

				elseif obj:IsA("ParticleEmitter")or obj:IsA("Trail")or obj:IsA("Beam")or obj:IsA("Fire")or obj:IsA("Smoke")or obj:IsA("Sparkles")then
					lowSave(obj,"Enabled",obj.Enabled)
					pcall(function()obj.Enabled=false end)
					lowMapState.count+=1

				elseif obj:IsA("Decal")or obj:IsA("Texture")then
					lowSave(obj,"Transparency",obj.Transparency)
					pcall(function()obj.Transparency=1 end)
					lowMapState.count+=1

				elseif obj:IsA("PointLight")or obj:IsA("SpotLight")or obj:IsA("SurfaceLight")then
					lowSave(obj,"Enabled",obj.Enabled)
					pcall(function()obj.Enabled=false end)
					lowMapState.count+=1
				end
			end
		end

		if statusFn then statusFn("LOW MAP ON: карта приглушена ("..lowMapState.count..")")end
	else
		if not lowMapState.on then return end
		lowMapState.on=false

		for obj,rec in pairs(lowMapState.saved)do
			if obj and obj.Parent then
				for k,v in pairs(rec)do
					pcall(function()obj[k]=v end)
				end
			end
		end
		lowMapState.saved={}

		local lighting=game:GetService("Lighting")
		pcall(function()
			if lowMapState.lighting.GlobalShadows~=nil then
				lighting.GlobalShadows=lowMapState.lighting.GlobalShadows
			end
		end)
		lowMapState.lighting={}

		if statusFn then statusFn("LOW MAP OFF: карта восстановлена")end
	end
end

local function stopLock()
	if lockConn then lockConn:Disconnect() lockConn=nil end
	lockCF=nil

	local h=hum()
	if h then
		if oldSpeed then pcall(function()h.WalkSpeed=oldSpeed end)end
		if oldAuto~=nil then pcall(function()h.AutoRotate=oldAuto end)end
	end
	oldSpeed=nil
	oldAuto=nil
end

local function startLock(cf)
	stopLock()
	lockCF=cf

	local h=hum()
	if h then
		oldSpeed=h.WalkSpeed
		oldAuto=h.AutoRotate
		pcall(function()h.WalkSpeed=0 end)
		pcall(function()h.AutoRotate=false end)
	end

	lockConn=RunService.Heartbeat:Connect(function()
		local r=root()
		if r and lockCF then
			r.CFrame=lockCF
			r.AssemblyLinearVelocity=Vector3.zero
			r.AssemblyAngularVelocity=Vector3.zero
		end
	end)
end

local function tpInsideRock(row)
	local info=getRock(row)
	if not info then return false,"камень не найден"end

	local body=info.body or info.hit
	if not body then return false,"нет BasePart камня"end

	local r=root()
	if not r then return false,"нет HumanoidRootPart"end

	local size=body.Size
	local offsetY=math.clamp(size.Y*0.08,0,2)

	-- Фикс внутри/около центра камня. Если где-то застревает — можно поставить _G.RockBugInsideOffset.
	local custom=_G.RockBugInsideOffset
	local cf
	if typeof(custom)=="Vector3"then
		cf=body.CFrame*CFrame.new(custom)
	else
		cf=body.CFrame*CFrame.new(0,offsetY,0)
	end

	r.CFrame=cf
	task.wait(.08)
	startLock(cf)
	return true,info
end

local function firePunchRemote()
	-- Основной рабочий вариант для Muscle Legends: punch + rightHand.
	pcall(function()
		if lp:FindFirstChild("muscleEvent")then
			lp.muscleEvent:FireServer("punch","rightHand")
			lp.muscleEvent:FireServer("punch","leftHand")
		end
	end)

	pcall(function()
		local rs=game:GetService("ReplicatedStorage")
		local re=rs:FindFirstChild("rEvents")
		local ev=re and re:FindFirstChild("muscleEvent")
		if ev and ev.FireServer then
			ev:FireServer("punch","rightHand")
			ev:FireServer("punch","leftHand")
			ev:FireServer("punch")
		end
	end)
end

local lastEquipTry=0
local selectedPunchToolName=nil

local function toolScore(tool)
	if not tool or not tool:IsA("Tool")then return -999 end

	local n=tostring(tool.Name):lower()
	local full=""
	pcall(function() full=tostring(tool:GetFullName()):lower() end)

	-- Для багов по камню нужен именно Punch. Вес/гантели/штанги/тренировки не подходят.
	local hardBad={
		"weight","dumb","barbell","bench","push","sit","handstand",
		"гант","гир","штанг","вес","отжим","пресс"
	}
	for _,w in ipairs(hardBad)do
		if n:find(w,1,true) or full:find(w,1,true) then
			return -999
		end
	end

	-- Лучший вариант: точное имя Punch.
	if n=="punch" or n=="punches" or n=="удар" or n=="кулак" then
		return 10000
	end

	-- Потом любые варианты с punch/кулак.
	if n:find("punch",1,true) or n:find("кулак",1,true) or n:find("удар",1,true) then
		return 9000
	end

	-- Если внутри Tool есть скрипты/ремоуты с punch — тоже вероятно правильный инструмент.
	for _,d in ipairs(tool:GetDescendants())do
		local dn=tostring(d.Name):lower()
		if dn:find("punch",1,true) or dn:find("кулак",1,true) or dn:find("удар",1,true) then
			return 7500
		end
	end

	-- Fist оставляем только как запасной вариант, если Punch реально не найден.
	if n:find("fist",1,true) or n:find("combat",1,true) or n:find("hand",1,true) then
		return 1200
	end

	return -999
end


local function clearToolCooldowns(tool)
	if not tool then return end

	local cooldownNames={
		"Cooldown","cooldown","CD","cd","Delay","delay",
		"AttackCooldown","attackCooldown","SwingCooldown","swingCooldown",
		"LastUse","lastUse","LastSwing","lastSwing","LastAttack","lastAttack",
		"CanUse","canUse","CanSwing","canSwing","Ready","ready"
	}

	local function fixObj(obj)
		for _,name in ipairs(cooldownNames)do
			local child=nil
			pcall(function()child=obj:FindFirstChild(name)end)
			if child then
				pcall(function()
					if child:IsA("NumberValue")or child:IsA("IntValue")then child.Value=0 end
					if child:IsA("BoolValue")then child.Value=true end
					if child:IsA("StringValue")then child.Value="0" end
				end)
			end
		end

		pcall(function()
			for _,name in ipairs(cooldownNames)do
				local v=obj:GetAttribute(name)
				if v~=nil then
					if type(v)=="number"then obj:SetAttribute(name,0)end
					if type(v)=="boolean"then obj:SetAttribute(name,true)end
					if type(v)=="string"then obj:SetAttribute(name,"0")end
				end
			end
		end)
	end

	fixObj(tool)
	for _,d in ipairs(tool:GetDescendants())do
		fixObj(d)
	end
end

local function clearAllLocalCooldowns()
	local c=lp.Character
	local bp=lp:FindFirstChildOfClass("Backpack")

	for _,container in ipairs({c,bp})do
		if container then
			for _,tool in ipairs(container:GetChildren())do
				if tool:IsA("Tool")then
					clearToolCooldowns(tool)
				end
			end
		end
	end
end

local function findBestPunchTool()
	local c=lp.Character
	local bp=lp:FindFirstChildOfClass("Backpack")
	local best=nil
	local bestScore=-999

	local function scan(container,bonus)
		if not container then return end
		for _,tool in ipairs(container:GetChildren())do
			if tool:IsA("Tool")then
				local sc=toolScore(tool)+bonus
				if sc>bestScore then
					bestScore=sc
					best=tool
				end
			end
		end
	end

	-- Сначала уже экипнутый нормальный предмет, потом Backpack.
	scan(c,20)
	scan(bp,0)

	if bestScore<=0 then return nil end
	return best,bestScore
end

local function ensurePunchTool(statusFn)
	local c=lp.Character
	local h=hum()
	if not c or not h then return nil end

	local equipped=nil
	local equippedBad=false

	for _,tool in ipairs(c:GetChildren())do
		if tool:IsA("Tool")then
			if toolScore(tool)>0 then
				equipped=tool
			else
				equippedBad=true
			end
		end
	end

	if equipped then
		selectedPunchToolName=equipped.Name
		return equipped
	end

	if equippedBad then
		pcall(function()h:UnequipTools()end)
		task.wait(.05)
	end

	local best=findBestPunchTool()
	if best and best.Parent~=c then
		pcall(function()h:EquipTool(best)end)
		task.wait(.08)
	end

	if best then
		clearToolCooldowns(best)
		selectedPunchToolName=best.Name
		if statusFn then statusFn("BUG HIT: выбран Punch → "..best.Name)end
		return best
	end

	if statusFn then statusFn("BUG HIT: предмет не найден, бью remote/touch")end
	return nil
end

local function activateFistTool(statusFn)
	if os.clock()-lastEquipTry>1.2 then
		lastEquipTry=os.clock()
		ensurePunchTool(statusFn)
	end

	local c=lp.Character
	if not c then return end

	for _,tool in ipairs(c:GetChildren())do
		if tool:IsA("Tool") and toolScore(tool)>0 then
			clearToolCooldowns(tool)
			pcall(function()tool:Activate()end)
		end
	end
end


local function touchRock(row)
	local info=getRock(row)
	if not info then return end
	local target=info.hit or info.body
	if not target or not target:IsA("BasePart")then return end
	if not firetouchinterest then return end

	local c=lp.Character
	if not c then return end

	local parts={
		c:FindFirstChild("RightHand"),
		c:FindFirstChild("LeftHand"),
		c:FindFirstChild("Right Arm"),
		c:FindFirstChild("Left Arm"),
		c:FindFirstChild("HumanoidRootPart"),
	}

	for _,p in ipairs(parts)do
		if p and p:IsA("BasePart")then
			pcall(function()
				firetouchinterest(p,target,0)
				firetouchinterest(p,target,1)
			end)
		end
	end
end

local hitLoopId=0

local function currentPunchTool()
	local c=lp.Character
	if not c then return nil end
	for _,tool in ipairs(c:GetChildren())do
		if tool:IsA("Tool") and toolScore(tool)>0 then
			return tool
		end
	end
	return nil
end


local function collectPunchRemotes()
	-- v15 fix: в старой сборке вызов был, функции не было, поэтому MAX PUNCH мог падать до запуска.
	return {}
end

local activeHitState=nil

local function collectPunchRemotes()
	-- v16 fix: если старые сборки потеряли кэш, не даём MAX PUNCH упасть до старта.
	return {}
end

local function rockTargetPart(row)
	local info=getRock(row)
	if not info then return nil end
	return info.hit or info.body
end

local function stillNearSelectedRock(row)
	local r=root()
	local target=rockTargetPart(row)
	if not r or not target or not target:IsA("BasePart") then
		return false,"нет цели"
	end

	local dist=(r.Position-target.Position).Magnitude
	local maxSize=math.max(target.Size.X,target.Size.Y,target.Size.Z)
	local limit=math.max(70,maxSize+38)

	if dist>limit then
		return false,"вышел из камня"
	end

	return true
end

local function hardStopBug(statusFn,stopLockToo)
	hitting=false
	hitLoopId+=100000

	if activeHitState then
		activeHitState.dead=true
		activeHitState.token+=100000
	end

	activeHitState=nil

	if hitConn then
		hitConn:Disconnect()
		hitConn=nil
	end

	if stopLockToo then
		stopLock()
	end

	-- Чтоб не продолжало махать после OFF.
	pcall(function()
		local h=hum()
		if h then h:UnequipTools() end
	end)

	if statusFn then statusFn("MAX PUNCH: OFF / HARD STOP") end
end

local function startHit(row,statusFn)
	hardStopBug(nil,false)

	hitting=true
	hitLoopId+=1
	local myId=hitLoopId
	local state={dead=false,token=hitLoopId,row=row}
	activeHitState=state

	local tool=ensurePunchTool(statusFn)
	collectPunchRemotes()

	local cycle=0
	local lastEquip=0
	local lastNearCheck=0

	task.spawn(function()
		local nextPunch=os.clock()

		while hitting and activeHitState==state and not state.dead and state.token==myId do
			local now=os.clock()

			-- Автостоп: если уже не у камня, не продолжаем багать снаружи.
			if now-lastNearCheck>=0.35 then
				lastNearCheck=now
				local ok,why=stillNearSelectedRock(row)
				if not ok then
					hardStopBug(statusFn,true)
					if statusFn then statusFn("AUTO STOP: "..tostring(why)) end
					break
				end
			end

			local rate=math.clamp(tonumber(_G.RockBugMaxPunchRate or _G.RockBugMaxPunchRateOverride or 90)or 90,10,240)
			local interval=1/rate
			local extra=math.clamp(tonumber(_G.RockBugExtraCyclesPerTick or 2)or 2,1,10)

			if now>=nextPunch then
				nextPunch+=interval
				if nextPunch<now-0.10 then nextPunch=now+interval end

				tool=currentPunchTool() or tool

				for _=1,extra do
					if not hitting or activeHitState~=state or state.dead or state.token~=myId then break end

					cycle+=1

					if tool and tool.Parent then
						clearToolCooldowns(tool)
						local bursts=math.clamp(tonumber(_G.RockBugActivateBursts or 4)or 4,1,10)
						for _=1,bursts do
							pcall(function() tool:Activate() end)
						end
					else
						activateFistTool(nil)
						tool=currentPunchTool()
					end

					local remoteLoops=math.clamp(tonumber(_G.RockBugRemoteLoops or 6)or 6,1,14)
					for _=1,remoteLoops do
						if not hitting or activeHitState~=state or state.dead or state.token~=myId then break end
						firePunchRemote()
					end

					local touchEvery=math.clamp(tonumber(_G.RockBugTouchEvery or 1)or 1,1,8)
					if cycle%touchEvery==0 then
						local touchLoops=math.clamp(tonumber(_G.RockBugTouchLoops or 3)or 3,1,8)
						for _=1,touchLoops do
							if not hitting or activeHitState~=state or state.dead or state.token~=myId then break end
							touchRock(row)
						end
					end
				end
			end

			if now-lastEquip>=0.8 then
				lastEquip=now
				tool=ensurePunchTool(nil) or currentPunchTool() or tool
			end

			task.wait(math.clamp(nextPunch-os.clock(),0,0.01))
		end
	end)

	if statusFn then
		statusFn("MAX PUNCH: ON | "..tostring(_G.RockBugMaxPunchRate or 90).."/s | auto-stop")
	end
end

local function stopHit(statusFn)
	hardStopBug(statusFn,true)
end


-- AUTO TRAIN v16: отдельные рычаги под каждый вид + auto equip через Tool и GUI fallback.
local trainLoops={}
local trainPosConn=nil
local trainPosCF=nil

local TRAIN_TYPES={
	{id="Punch",label="PUNCH",desc="удары / сила",words={"punch","fist","combat","кулак","удар"},remote="punch"},
	{id="Weight",label="WEIGHT",desc="вес / гантели / штанга",words={"weight","dumb","dumbbell","barbell","bench","вес","гант","штанг","гир"},remote="weight"},
	{id="Push",label="PUSH",desc="отжимания",words={"push","pushup","push-up","отжим"},remote="push"},
	{id="Sit",label="SIT",desc="пресс / situps",words={"sit","situp","sit-up","abs","пресс"},remote="sit"},
	{id="Hand",label="HAND",desc="стойка на руках",words={"handstand","hand stand","hand","стойк"},remote="handstand"},
	{id="Tread",label="TREAD",desc="бег / treadmill / agility",words={"tread","treadmill","run","agility","speed","бег","дорож","ловк","скор"},remote="treadmill"},
}

local ROCK_MULT={
	AncientJungle=16.25,
	MuscleKing=12.5,
	Legends=2.5,
	Inferno=1.125,
	Mystic=0.75,
	Frozen=0.375,
	Golden=0.2,
	Large=0.075,
	Punching=0.05,
	Tiny=0.025,
}

local function parseNumText(s)
	s=tostring(s or ""):lower()
	s=s:gsub(",", ""):gsub(" ", "")
	local mult=1
	if s:find("k") then mult=1e3 end
	if s:find("m") then mult=1e6 end
	if s:find("b") then mult=1e9 end
	local num=tonumber((s:gsub("[^%d%.%-]","")))
	if not num then return nil end
	return math.floor(num*mult+0.5)
end

local function readRebirths()
	local names={"rebirth","rebirths","rebs","реб","перерожд"}

	local function nameLooks(n)
		n=tostring(n or ""):lower()
		for _,w in ipairs(names) do
			if n:find(w,1,true) then return true end
		end
		return false
	end

	local function scanValues(root,limit)
		if not root then return nil end
		local n=0
		for _,d in ipairs(root:GetDescendants()) do
			n+=1
			if n>limit then break end
			if nameLooks(d.Name) then
				if d:IsA("IntValue") or d:IsA("NumberValue") then
					return tonumber(d.Value)
				elseif d:IsA("StringValue") then
					local v=parseNumText(d.Value)
					if v then return v end
				end
			end
		end
		return nil
	end

	local ls=lp:FindFirstChild("leaderstats")
	if ls then
		for _,d in ipairs(ls:GetChildren()) do
			if nameLooks(d.Name) then
				local ok,val=pcall(function() return d.Value end)
				if ok then
					local n=tonumber(val) or parseNumText(val)
					if n then return n end
				end
			end
		end
	end

	local v=scanValues(lp,1200)
	if v then return v end

	local pg=lp:FindFirstChild("PlayerGui")
	if pg then
		local scanned=0
		for _,d in ipairs(pg:GetDescendants()) do
			scanned+=1
			if scanned>2500 then break end
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				local text=tostring(d.Text or "")
				if nameLooks(text) or nameLooks(d.Name) then
					local n=parseNumText(text)
					if n then return n end
				end
			end
		end
	end

	return nil
end

local function isIntegerish(x)
	return math.abs(x-math.floor(x+0.5))<1e-7
end

local function chooseRockByRebirths()
	local reb=readRebirths()
	local cap=237500 -- safe cap под Unique, чтобы не ставить Jungle когда он одним ударом всё ломает.

	if reb then
		local best=nil
		local bestXp=-1
		local fallback=nil
		local fallbackXp=-1

		for _,row in ipairs(ROCKS) do
			local mult=ROCK_MULT[row.id]
			if mult and rockCache[row.req] then
				local xp=(reb+20)*mult
				if xp<=cap then
					if isIntegerish(xp) and xp>bestXp then
						best=row
						bestXp=xp
					end
					if xp>fallbackXp then
						fallback=row
						fallbackXp=xp
					end
				end
			end
		end

		if best then return best,"rebirths "..tostring(reb).." | XP/hit "..tostring(math.floor(bestXp+0.5)) end
		if fallback then return fallback,"rebirths "..tostring(reb).." | fallback XP/hit "..tostring(math.floor(fallbackXp+0.5)) end
	end

	-- Если ребы не прочитались, НЕ ставим Jungle. Безопасный дефолт — Legends, если найден.
	for _,id in ipairs({"Legends","MuscleKing","Inferno","Mystic","Frozen","Golden","Large","Punching","Tiny"}) do
		for _,row in ipairs(ROCKS) do
			if row.id==id and rockCache[row.req] then
				return row, reb and ("rebirths "..tostring(reb)) or "rebirths not found | safe default"
			end
		end
	end

	return ROCKS[#ROCKS],"no rocks"
end

local function textOfGui(obj)
	local s=tostring(obj.Name)
	pcall(function()
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			s=s.." "..tostring(obj.Text)
		end
	end)
	return s:lower()
end

local function hasAnyWord(s,words)
	s=tostring(s or ""):lower()
	for _,w in ipairs(words) do
		if s:find(tostring(w):lower(),1,true) then return true end
	end
	return false
end

local function findButtonAncestor(obj)
	local cur=obj
	for _=1,8 do
		if not cur then break end
		if cur:IsA("TextButton") or cur:IsA("ImageButton") then return cur end
		cur=cur.Parent
	end
	return nil
end

local function clickButton(btn)
	if not btn then return false end
	pcall(function()
		btn.Visible=true
		btn.Active=true
	end)
	pcall(function()
		if btn:IsA("GuiButton") then
			btn.Selectable=true
			btn.AutoButtonColor=true
			btn.Modal=false
		end
	end)
	local ok=false
	pcall(function() btn:Activate() ok=true end)
	pcall(function() if firesignal then firesignal(btn.Activated) ok=true end end)
	pcall(function() if firesignal then firesignal(btn.MouseButton1Click) ok=true end end)
	return ok
end

local function clickGuiForType(t)
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return false end

	local scanned=0
	local clicked=false

	for _,d in ipairs(pg:GetDescendants()) do
		scanned+=1
		if scanned>4000 or clicked then break end

		if d:IsA("TextButton") or d:IsA("ImageButton") or d:IsA("TextLabel") then
			local txt=textOfGui(d)
			if hasAnyWord(txt,t.words) then
				local btn=d:IsA("GuiButton") and d or findButtonAncestor(d)
				if btn then
					clicked=clickButton(btn)
				end
			end
		end
	end

	if clicked then task.wait(0.18) end
	return clicked
end

local function scoreToolForType(tool,t)
	if not tool or not tool:IsA("Tool") then return -999 end

	local n=tostring(tool.Name):lower()
	local full=""
	pcall(function() full=tostring(tool:GetFullName()):lower() end)

	local bad={"pet","aura","crystal","shop","trade","gift","pack","code","reward","пет","питом","крист","магаз","обмен"}
	for _,w in ipairs(bad) do
		if n:find(w,1,true) or full:find(w,1,true) then return -999 end
	end

	local score=0
	for _,w in ipairs(t.words) do
		w=tostring(w):lower()
		if n:find(w,1,true) then score=math.max(score,260) end
		if full:find(w,1,true) then score=math.max(score,190) end
	end

	if t.id=="Punch" and toolScore(tool)>0 then
		score=math.max(score,300)
	end

	return score
end

local function findToolForType(t)
	local c=lp.Character
	local bp=lp:FindFirstChildOfClass("Backpack")
	local best=nil
	local bestScore=-999

	local function scan(container,bonus)
		if not container then return end
		for _,tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				local sc=scoreToolForType(tool,t)+bonus
				if sc>bestScore then
					bestScore=sc
					best=tool
				end
			end
		end
	end

	scan(c,40)
	scan(bp,0)

	if bestScore<=0 then return nil end
	return best,bestScore
end

local function equipTrainTool(t,statusFn)
	local c=lp.Character
	local h=hum()
	if not c or not h then return nil end

	for _,tool in ipairs(c:GetChildren()) do
		if tool:IsA("Tool") and scoreToolForType(tool,t)>0 then
			clearToolCooldowns(tool)
			return tool
		end
	end

	local best=findToolForType(t)

	if not best then
		-- GUI fallback: пробуем нажать кнопку выбора тренировки, потом ищем Tool снова.
		if clickGuiForType(t) then
			task.wait(0.25)
			best=findToolForType(t)
		end
	end

	if best and best.Parent~=c then
		pcall(function() h:UnequipTools() end)
		task.wait(0.05)
		pcall(function() h:EquipTool(best) end)
		task.wait(0.08)
	end

	if best then
		clearToolCooldowns(best)
		if statusFn then statusFn("КАЧ "..t.label..": выбран "..best.Name) end
		return best
	end

	if statusFn then statusFn("КАЧ "..t.label..": Tool не найден, попробовал GUI") end
	return nil
end

local function fireTrainRemote(t)
	local loops=math.clamp(tonumber(_G.RockBugTrainRemoteLoops or _G.RockBugAutoTrainRemoteLoops or 2)or 2,0,14)
	if loops<=0 then return end

	local function send(ev)
		if not ev or not ev.FireServer then return end

		if t.remote=="punch" then
			pcall(function()
				ev:FireServer("punch","rightHand")
				ev:FireServer("punch","leftHand")
				ev:FireServer("punch")
			end)
		else
			pcall(function()
				ev:FireServer("rep")
				ev:FireServer("train")
				ev:FireServer(t.remote)
				ev:FireServer(t.id)
			end)
		end
	end

	for _=1,loops do
		pcall(function()
			if lp:FindFirstChild("muscleEvent") then send(lp.muscleEvent) end
		end)
		pcall(function()
			local rs=game:GetService("ReplicatedStorage")
			local re=rs:FindFirstChild("rEvents")
			local ev=re and re:FindFirstChild("muscleEvent")
			send(ev)
		end)
	end
end

local function stopTrainType(id,statusFn)
	local state=trainLoops[id]
	if state then
		state.on=false
		state.token+=100000
	end
	trainLoops[id]=nil
	if statusFn then statusFn("КАЧ "..id..": OFF") end
end

local function stopAllTrain(statusFn)
	for id,_ in pairs(trainLoops) do
		stopTrainType(id,nil)
	end
	if statusFn then statusFn("КАЧ: всё OFF") end
end

local function startTrainType(t,statusFn)
	stopAllTrain(nil)

	local state={on=true,token=1}
	trainLoops[t.id]=state

	task.spawn(function()
		local my=state.token
		local tool=equipTrainTool(t,statusFn)
		local nextRep=os.clock()
		local lastEquip=0
		local lastGuiTry=0

		while state.on and state.token==my do
			local now=os.clock()
			local rate=math.clamp(tonumber(_G.RockBugTrainRate or _G.RockBugAutoTrainRate or 35)or 35,3,160)
			local interval=1/rate

			if now>=nextRep then
				nextRep+=interval
				if nextRep<now-0.15 then nextRep=now+interval end

				tool=tool or equipTrainTool(t,nil)

				if tool and tool.Parent then
					clearToolCooldowns(tool)
					local bursts=math.clamp(tonumber(_G.RockBugTrainActivateBursts or _G.RockBugAutoTrainActivateBursts or 2)or 2,1,14)
					for _=1,bursts do
						pcall(function() tool:Activate() end)
					end
				elseif now-lastGuiTry>1.2 then
					lastGuiTry=now
					clickGuiForType(t)
					tool=equipTrainTool(t,nil)
				end

				fireTrainRemote(t)
			end

			if now-lastEquip>=1.0 then
				lastEquip=now
				tool=equipTrainTool(t,nil) or tool
			end

			task.wait(math.clamp(nextRep-os.clock(),0,0.018))
		end
	end)

	if statusFn then statusFn("КАЧ "..t.label..": ON") end
end

local function startTrainPositionLock(statusFn)
	if trainPosConn then trainPosConn:Disconnect() trainPosConn=nil end

	local r=root()
	if not r then
		if statusFn then statusFn("LOCK POS: нет root") end
		return false
	end

	trainPosCF=r.CFrame

	local h=hum()
	if h then pcall(function() h.AutoRotate=false end) end

	trainPosConn=RunService.Heartbeat:Connect(function()
		local rr=root()
		if rr and trainPosCF then
			rr.CFrame=trainPosCF
			rr.AssemblyLinearVelocity=Vector3.zero
			rr.AssemblyAngularVelocity=Vector3.zero
		end
	end)

	if statusFn then statusFn("LOCK POS: ON") end
	return true
end

local function stopTrainPositionLock(statusFn)
	if trainPosConn then trainPosConn:Disconnect() trainPosConn=nil end
	trainPosCF=nil

	local h=hum()
	if h then pcall(function() h.AutoRotate=true end) end

	if statusFn then statusFn("LOCK POS: OFF") end
end


-- UI v17: полностью новый внешний вид, функционал оставлен.
local gui=Instance.new("ScreenGui")
gui.Name="RockBugHub_v17_NeoPatch"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=999999
gui.Parent=lp:WaitForChild("PlayerGui")

local UserInputService=game:GetService("UserInputService")

local function corner(o,r)
	local c=Instance.new("UICorner")
	c.CornerRadius=UDim.new(0,r or 12)
	c.Parent=o
	return c
end

local function stroke(o,col,t,trans)
	local s=Instance.new("UIStroke")
	s.Color=col or Color3.fromRGB(110,185,255)
	s.Thickness=t or 1
	s.Transparency=trans or 0.35
	s.Parent=o
	return s
end

local function txt(parent,text,size,font,color,xalign)
	local l=Instance.new("TextLabel")
	l.Parent=parent
	l.BackgroundTransparency=1
	l.Text=text or ""
	l.TextColor3=color or Color3.fromRGB(235,242,255)
	l.Font=font or Enum.Font.GothamBold
	l.TextSize=size or 12
	l.TextWrapped=true
	l.TextXAlignment=xalign or Enum.TextXAlignment.Left
	l.TextYAlignment=Enum.TextYAlignment.Center
	return l
end

local function btn(parent,text,color)
	local b=Instance.new("TextButton")
	b.Parent=parent
	b.Text=text
	b.TextColor3=Color3.fromRGB(240,246,255)
	b.BackgroundColor3=color or Color3.fromRGB(24,34,56)
	b.BackgroundTransparency=0.03
	b.BorderSizePixel=0
	b.AutoButtonColor=true
	b.Font=Enum.Font.GothamBlack
	b.TextSize=12
	corner(b,14)
	stroke(b,Color3.fromRGB(255,255,255),1,0.88)
	return b
end

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,356,0,520)
main.Position=UDim2.new(0,10,0,42)
main.BackgroundColor3=Color3.fromRGB(4,7,13)
main.BackgroundTransparency=0.04
main.BorderSizePixel=0
main.Active=true
corner(main,24)
stroke(main,Color3.fromRGB(70,180,255),1.6,0.15)

local glow=Instance.new("Frame")
glow.Parent=main
glow.Size=UDim2.new(1,-12,0,5)
glow.Position=UDim2.new(0,6,0,6)
glow.BackgroundColor3=Color3.fromRGB(70,190,255)
glow.BorderSizePixel=0
corner(glow,8)

local head=Instance.new("Frame")
head.Parent=main
head.Size=UDim2.new(1,-16,0,70)
head.Position=UDim2.new(0,8,0,14)
head.BackgroundColor3=Color3.fromRGB(9,15,26)
head.BackgroundTransparency=0.03
head.BorderSizePixel=0
corner(head,20)
stroke(head,Color3.fromRGB(80,165,255),1,0.45)

local title=txt(head,"THE GREAT BASTRA",19,Enum.Font.GothamBlack,Color3.fromRGB(245,250,255))
title.Size=UDim2.new(1,-88,0,24)
title.Position=UDim2.new(0,14,0,8)

local sub=txt(head,"RockBug Hub v17 • NeoPatch",10,Enum.Font.GothamBold,Color3.fromRGB(135,210,255))
sub.Size=UDim2.new(1,-88,0,18)
sub.Position=UDim2.new(0,15,0,32)

local sub2=txt(head,"max punch • auto train • hard stop",9,Enum.Font.GothamSemibold,Color3.fromRGB(145,155,180))
sub2.Size=UDim2.new(1,-88,0,16)
sub2.Position=UDim2.new(0,15,0,49)

local min=btn(head,"—",Color3.fromRGB(24,35,60))
min.Size=UDim2.new(0,30,0,30)
min.Position=UDim2.new(1,-70,0,12)
min.TextSize=18

local close=btn(head,"×",Color3.fromRGB(88,25,43))
close.Size=UDim2.new(0,30,0,30)
close.Position=UDim2.new(1,-36,0,12)
close.TextSize=18
close.TextColor3=Color3.fromRGB(255,215,225)

local mini=btn(gui,"BASTRA",Color3.fromRGB(15,45,85))
mini.Size=UDim2.new(0,86,0,34)
mini.Position=main.Position
mini.Visible=false
mini.TextSize=11

local tabs=Instance.new("Frame")
tabs.Parent=main
tabs.Size=UDim2.new(1,-16,0,42)
tabs.Position=UDim2.new(0,8,0,92)
tabs.BackgroundColor3=Color3.fromRGB(7,10,20)
tabs.BackgroundTransparency=0.05
tabs.BorderSizePixel=0
corner(tabs,17)
stroke(tabs,Color3.fromRGB(58,72,110),1,0.55)

local tabBug=btn(tabs,"БАГ",Color3.fromRGB(20,95,135))
tabBug.Size=UDim2.new(0.5,-4,1,-8)
tabBug.Position=UDim2.new(0,4,0,4)
tabBug.TextSize=14

local tabTrain=btn(tabs,"КАЧ",Color3.fromRGB(15,20,34))
tabTrain.Size=UDim2.new(0.5,-4,1,-8)
tabTrain.Position=UDim2.new(0.5,0,0,4)
tabTrain.TextSize=14

local status=txt(main,"Загрузка...",10,Enum.Font.GothamBold,Color3.fromRGB(215,230,255),Enum.TextXAlignment.Center)
status.Size=UDim2.new(1,-16,0,30)
status.Position=UDim2.new(0,8,0,142)
status.BackgroundColor3=Color3.fromRGB(8,14,24)
status.BackgroundTransparency=0.04
status.BorderSizePixel=0
corner(status,14)
stroke(status,Color3.fromRGB(55,90,125),1,0.55)

local function setStatus(t)
	status.Text=tostring(t or "")
end

local pageBug=Instance.new("ScrollingFrame")
pageBug.Parent=main
pageBug.Size=UDim2.new(1,-16,0,304)
pageBug.Position=UDim2.new(0,8,0,180)
pageBug.BackgroundTransparency=1
pageBug.BorderSizePixel=0
pageBug.ScrollBarThickness=3
pageBug.ScrollBarImageColor3=Color3.fromRGB(80,180,255)
pageBug.CanvasSize=UDim2.new(0,0,0,0)

local pageTrain=Instance.new("ScrollingFrame")
pageTrain.Parent=main
pageTrain.Size=pageBug.Size
pageTrain.Position=pageBug.Position
pageTrain.BackgroundTransparency=1
pageTrain.BorderSizePixel=0
pageTrain.ScrollBarThickness=3
pageTrain.ScrollBarImageColor3=Color3.fromRGB(80,255,165)
pageTrain.CanvasSize=UDim2.new(0,0,0,0)
pageTrain.Visible=false

local function padList(frame)
	local p=Instance.new("UIPadding")
	p.PaddingTop=UDim.new(0,4)
	p.PaddingBottom=UDim.new(0,12)
	p.PaddingLeft=UDim.new(0,2)
	p.PaddingRight=UDim.new(0,6)
	p.Parent=frame

	local l=Instance.new("UIListLayout")
	l.Parent=frame
	l.SortOrder=Enum.SortOrder.LayoutOrder
	l.Padding=UDim.new(0,8)
	return l
end

local bugLayout=padList(pageBug)
local trainLayout=padList(pageTrain)

local version=txt(main,HUB_VERSION.."  |  by The Great Bastra",8,Enum.Font.GothamBlack,Color3.fromRGB(120,150,185),Enum.TextXAlignment.Center)
version.Size=UDim2.new(1,-18,0,14)
version.Position=UDim2.new(0,9,0,500)

local function updateCanvas()
	task.defer(function()
		pageBug.CanvasSize=UDim2.new(0,0,0,bugLayout.AbsoluteContentSize.Y+24)
		pageTrain.CanvasSize=UDim2.new(0,0,0,trainLayout.AbsoluteContentSize.Y+24)
	end)
end
bugLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
trainLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

local function showTab(name)
	local bug=name=="bug"
	pageBug.Visible=bug
	pageTrain.Visible=not bug
	tabBug.BackgroundColor3=bug and Color3.fromRGB(20,120,170) or Color3.fromRGB(15,20,34)
	tabTrain.BackgroundColor3=(not bug) and Color3.fromRGB(25,140,85) or Color3.fromRGB(15,20,34)
	setStatus(bug and "Вкладка БАГ" or "Вкладка КАЧ")
end

tabBug.Activated:Connect(function() showTab("bug") end)
tabTrain.Activated:Connect(function() showTab("train") end)

local function panel(parent,h)
	local f=Instance.new("Frame")
	f.Parent=parent
	f.Size=UDim2.new(1,0,0,h)
	f.BackgroundColor3=Color3.fromRGB(9,14,25)
	f.BackgroundTransparency=0.03
	f.BorderSizePixel=0
	corner(f,18)
	stroke(f,Color3.fromRGB(45,75,110),1,0.56)
	return f
end

local function makeLever(parent,label,desc,initial,callback)
	local row=panel(parent,54)

	local t=txt(row,label,13,Enum.Font.GothamBlack,Color3.fromRGB(238,244,255))
	t.Size=UDim2.new(1,-110,0,20)
	t.Position=UDim2.new(0,13,0,7)

	local d=txt(row,desc or "",9,Enum.Font.GothamBold,Color3.fromRGB(130,148,178))
	d.Size=UDim2.new(1,-110,0,18)
	d.Position=UDim2.new(0,13,0,28)

	local hit=Instance.new("TextButton")
	hit.Parent=row
	hit.Size=UDim2.new(0,82,0,34)
	hit.Position=UDim2.new(1,-94,0,10)
	hit.Text=""
	hit.AutoButtonColor=false
	hit.BackgroundColor3=Color3.fromRGB(75,38,50)
	hit.BorderSizePixel=0
	corner(hit,17)
	stroke(hit,Color3.fromRGB(255,255,255),1,0.84)

	local knob=Instance.new("Frame")
	knob.Parent=hit
	knob.Size=UDim2.new(0,28,0,28)
	knob.Position=UDim2.new(0,3,0,3)
	knob.BackgroundColor3=Color3.fromRGB(235,239,250)
	knob.BorderSizePixel=0
	corner(knob,14)
	stroke(knob,Color3.fromRGB(10,10,15),1,0.75)

	local dot=Instance.new("Frame")
	dot.Parent=knob
	dot.Size=UDim2.new(0,8,0,8)
	dot.Position=UDim2.new(0.5,-4,0.5,-4)
	dot.BackgroundColor3=Color3.fromRGB(75,85,100)
	dot.BorderSizePixel=0
	corner(dot,4)

	local state=initial and true or false
	local obj={}

	local function paint()
		if state then
			hit.BackgroundColor3=Color3.fromRGB(22,140,82)
			knob.Position=UDim2.new(1,-31,0,3)
			dot.BackgroundColor3=Color3.fromRGB(22,140,82)
			row.BackgroundColor3=Color3.fromRGB(8,28,22)
		else
			hit.BackgroundColor3=Color3.fromRGB(75,38,50)
			knob.Position=UDim2.new(0,3,0,3)
			dot.BackgroundColor3=Color3.fromRGB(75,85,100)
			row.BackgroundColor3=Color3.fromRGB(9,14,25)
		end
	end

	function obj.Set(v,silent)
		state=v and true or false
		paint()
		if callback and not silent then callback(state,obj) end
	end

	function obj.Get()
		return state
	end

	hit.Activated:Connect(function()
		obj.Set(not state,false)
	end)

	row.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.Touch then
			obj.Set(not state,false)
		end
	end)

	paint()
	return obj,row
end

-- BUG PAGE
local selectedBox=panel(pageBug,64)
local selectedLabel=txt(selectedBox,"АВТО-КАМЕНЬ ПО РЕБАМ",9,Enum.Font.GothamBlack,Color3.fromRGB(115,180,255))
selectedLabel.Size=UDim2.new(1,-22,0,16)
selectedLabel.Position=UDim2.new(0,13,0,8)

local selectedName=txt(selectedBox,"-",18,Enum.Font.GothamBlack,Color3.fromRGB(255,238,185))
selectedName.Size=UDim2.new(1,-22,0,28)
selectedName.Position=UDim2.new(0,13,0,28)

local rockBox=panel(pageBug,154)
local rockTitle=txt(rockBox,"КАМНИ",12,Enum.Font.GothamBlack,Color3.fromRGB(210,225,255))
rockTitle.Size=UDim2.new(1,-20,0,18)
rockTitle.Position=UDim2.new(0,12,0,8)

local rockList=Instance.new("ScrollingFrame")
rockList.Parent=rockBox
rockList.Size=UDim2.new(1,-16,0,115)
rockList.Position=UDim2.new(0,8,0,31)
rockList.BackgroundTransparency=1
rockList.BorderSizePixel=0
rockList.ScrollBarThickness=2
rockList.CanvasSize=UDim2.new(0,0,0,0)

local rl=Instance.new("UIListLayout")
rl.Parent=rockList
rl.SortOrder=Enum.SortOrder.LayoutOrder
rl.Padding=UDim.new(0,5)

local buttons={}

local function updateSelected()
	if selected then
		selectedName.Text=selected.label.."  •  req "..tostring(selected.req)
	else
		selectedName.Text="-"
	end
end

local function refreshButtons()
	for _,b in pairs(buttons) do
		if b and b.Parent then b:Destroy() end
	end
	buttons={}

	for i,row in ipairs(ROCKS) do
		local info=rockCache[row.req]
		local active=selected and selected.id==row.id

		local card=Instance.new("TextButton")
		card.Parent=rockList
		card.Size=UDim2.new(1,-4,0,32)
		card.LayoutOrder=i
		card.Text=(active and "◆ " or "◇ ")..row.label.."  |  "..(info and "found" or "missing")
		card.TextColor3=active and Color3.fromRGB(255,240,185) or Color3.fromRGB(218,228,245)
		card.TextXAlignment=Enum.TextXAlignment.Left
		card.Font=Enum.Font.GothamBlack
		card.TextSize=11
		card.AutoButtonColor=true
		card.BackgroundColor3=active and Color3.fromRGB(35,67,106) or Color3.fromRGB(14,22,36)
		card.BorderSizePixel=0
		corner(card,12)
		stroke(card,active and Color3.fromRGB(120,190,255) or Color3.fromRGB(55,70,95),1,active and 0.2 or 0.65)

		local pad=Instance.new("UIPadding")
		pad.Parent=card
		pad.PaddingLeft=UDim.new(0,12)

		card.Activated:Connect(function()
			selected=row
			selectedLabel.Text="ВЫБРАНО ВРУЧНУЮ"
			updateSelected()
			refreshButtons()
			setStatus("Камень: "..row.label)
		end)

		table.insert(buttons,card)
	end

	rockList.CanvasSize=UDim2.new(0,0,0,#ROCKS*37+6)
	updateSelected()
end

local lockLever
local bugLever
local posLever
local ultraLever
local afkLever
local trainLevers={}

lockLever=makeLever(pageBug,"TP LOCK","держит персонажа внутри выбранного камня",false,function(on,self)
	if on then
		local ok,res=tpInsideRock(selected)
		if ok then setStatus("LOCK: "..selected.label) else setStatus("LOCK error: "..tostring(res)) self.Set(false,true) end
	else
		stopLock()
		setStatus("UNLOCK")
	end
end)

bugLever=makeLever(pageBug,"MAX PUNCH","hard stop при OFF, автостоп вне камня",false,function(on,self)
	if on then
		local ok,msg=tpInsideRock(selected)
		if not ok then
			setStatus("BUG error: "..tostring(msg))
			self.Set(false,true)
			return
		end
		if lockLever then lockLever.Set(true,true) end
		startHit(selected,setStatus)
	else
		hardStopBug(setStatus,true)
		if lockLever then lockLever.Set(false,true) end
	end
end)

local goTrain=btn(pageBug,"ОТКРЫТЬ ВКЛАДКУ КАЧ ➜",Color3.fromRGB(20,80,125))
goTrain.Size=UDim2.new(1,0,0,38)
goTrain.TextSize=13
goTrain.Activated:Connect(function() showTab("train") end)

-- TRAIN PAGE
local goBug=btn(pageTrain,"⬅ НАЗАД В БАГ",Color3.fromRGB(20,80,125))
goBug.Size=UDim2.new(1,0,0,38)
goBug.TextSize=13
goBug.Activated:Connect(function() showTab("bug") end)

posLever=makeLever(pageTrain,"LOCK POSITION","держать текущую позицию во время кача",false,function(on,self)
	if on then
		local ok=startTrainPositionLock(setStatus)
		if not ok then self.Set(false,true) end
	else
		stopTrainPositionLock(setStatus)
	end
end)

ultraLever=makeLever(pageTrain,"ULTRA MAP","низкая карта, вернуть можно выключением",false,function(on)
	ultraOptEnabled=on
	if on then
		local old=_G.RockBugLowMapTransparency
		_G.RockBugLowMapTransparency=1
		local info=getRock(selected)
		setLowMap(true,info and info.model,setStatus)
		_G.RockBugLowMapTransparency=old
	else
		setLowMap(false,nil,setStatus)
	end
end)

afkLever=makeLever(pageTrain,"ANTI AFK","анти-кик за простой",antiAfkEnabled,function(on)
	antiAfkEnabled=on
	setStatus("AFK "..(on and "ON" or "OFF"))
end)

local trainTitle=panel(pageTrain,42)
local trainText=txt(trainTitle,"ОТДЕЛЬНЫЕ ВИДЫ КАЧА",13,Enum.Font.GothamBlack,Color3.fromRGB(220,238,255),Enum.TextXAlignment.Center)
trainText.Size=UDim2.new(1,-20,1,0)
trainText.Position=UDim2.new(0,10,0,0)

local function turnOffOtherTrain(id)
	for tid,lever in pairs(trainLevers) do
		if tid~=id and lever and lever.Get() then
			lever.Set(false,true)
			stopTrainType(tid,nil)
		end
	end
end

for _,t in ipairs(TRAIN_TYPES) do
	local lever=makeLever(pageTrain,t.label,t.desc,false,function(on,self)
		if on then
			turnOffOtherTrain(t.id)
			startTrainType(t,setStatus)
		else
			stopTrainType(t.id,setStatus)
		end
	end)
	trainLevers[t.id]=lever
end

min.Activated:Connect(function()
	main.Visible=false
	mini.Visible=true
end)

mini.Activated:Connect(function()
	main.Visible=true
	mini.Visible=false
end)

close.Activated:Connect(function()
	stopAllTrain()
	stopTrainPositionLock()
	hardStopBug(nil,true)
	setLowMap(false,nil,nil)
	if antiAfkConn then antiAfkConn:Disconnect() antiAfkConn=nil end
	gui:Destroy()
end)

local dragging=false
local dragStart=nil
local startPos=nil

head.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=true
		dragStart=input.Position
		startPos=main.Position
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
		local delta=input.Position-dragStart
		main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
		mini.Position=main.Position
	end
end)

rockCache=scanRocks()

local autoRock,why=chooseRockByRebirths()
if autoRock then
	selected=autoRock
	selectedLabel.Text="АВТО-КАМЕНЬ ПО РЕБАМ"
end

refreshButtons()
showTab("bug")
updateCanvas()
setStatus("v17 patch: "..tostring(why or "ready"))
