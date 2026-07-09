-- Muscle Legends RockBug Hub v16 SliderLevers
-- Standalone: без Speed Hub. Камни через neededDurability + TP LOCK + BUG HIT + Anti AFK.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local VirtualUser=game:GetService("VirtualUser")
local lp=Players.LocalPlayer
local HUB_VERSION="RockBugHub_v16_SliderLevers"

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

-- Анти-дубль: сносит старые окна RockBugHub, чтобы не путаться.
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

-- UI v16: обычный ползунок-рычажок.
local gui=Instance.new("ScreenGui")
gui.Name="RockBugHub_v16_SliderLevers"
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
	s.Color=col or Color3.fromRGB(120,110,210)
	s.Thickness=t or 1
	s.Transparency=trans or 0
	s.Parent=o
	return s
end

local function makeText(parent,text,size,font,color)
	local l=Instance.new("TextLabel")
	l.Parent=parent
	l.BackgroundTransparency=1
	l.Text=text or ""
	l.TextColor3=color or Color3.fromRGB(232,236,255)
	l.Font=font or Enum.Font.GothamBold
	l.TextSize=size or 12
	l.TextXAlignment=Enum.TextXAlignment.Left
	l.TextYAlignment=Enum.TextYAlignment.Center
	l.TextWrapped=true
	return l
end

local function makeBtn(parent,text,color)
	local b=Instance.new("TextButton")
	b.Parent=parent
	b.Text=text
	b.TextColor3=Color3.fromRGB(238,241,255)
	b.BackgroundColor3=color
	b.BackgroundTransparency=0.06
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
main.Size=UDim2.new(0,350,0,500)
main.Position=UDim2.new(0,10,0,54)
main.BackgroundColor3=Color3.fromRGB(8,10,18)
main.BackgroundTransparency=0.08
main.BorderSizePixel=0
main.Active=true
corner(main,22)
stroke(main,Color3.fromRGB(95,85,180),1.4,0.2)

local top=Instance.new("Frame")
top.Parent=main
top.Size=UDim2.new(1,-14,0,46)
top.Position=UDim2.new(0,7,0,7)
top.BackgroundColor3=Color3.fromRGB(14,16,30)
top.BackgroundTransparency=0.08
top.BorderSizePixel=0
corner(top,18)
stroke(top,Color3.fromRGB(70,68,130),1,0.45)

local title=makeText(top,"BUG HUB v16",18,Enum.Font.GothamBlack,Color3.fromRGB(248,249,255))
title.Size=UDim2.new(1,-96,0,22)
title.Position=UDim2.new(0,14,0,6)

local sub=makeText(top,"slider levers • auto rock • hard stop\n author The Great Bastra",10,Enum.Font.GothamBold,Color3.fromRGB(165,172,205))
sub.Size=UDim2.new(1,-96,0,16)
sub.Position=UDim2.new(0,15,0,26)

local min=makeBtn(top,"−",Color3.fromRGB(42,39,78))
min.Size=UDim2.new(0,29,0,29)
min.Position=UDim2.new(1,-66,0,9)
min.TextSize=18

local close=makeBtn(top,"×",Color3.fromRGB(78,28,42))
close.Size=UDim2.new(0,29,0,29)
close.Position=UDim2.new(1,-33,0,9)
close.TextSize=18
close.TextColor3=Color3.fromRGB(255,210,218)

local mini=makeBtn(gui,"BUG v16",Color3.fromRGB(46,42,120))
mini.Size=UDim2.new(0,90,0,36)
mini.Position=main.Position
mini.Visible=false
mini.TextSize=11

local tabs=Instance.new("Frame")
tabs.Parent=main
tabs.Size=UDim2.new(1,-14,0,52)
tabs.Position=UDim2.new(0,7,0,58)
tabs.BackgroundTransparency=1

local tabBug=makeBtn(tabs,"⬅ ВКЛАДКА БАГ",Color3.fromRGB(45,145,95))
tabBug.Size=UDim2.new(0.5,-4,1,0)
tabBug.Position=UDim2.new(0,0,0,0)
tabBug.TextSize=15

local tabTrain=makeBtn(tabs,"ВКЛАДКА КАЧ ➜",Color3.fromRGB(32,42,65))
tabTrain.Size=UDim2.new(0.5,-4,1,0)
tabTrain.Position=UDim2.new(0.5,4,0,0)
tabTrain.TextSize=15

local status=makeText(main,"Вкладки сверху: БАГ / КАЧ",11,Enum.Font.GothamBold,Color3.fromRGB(210,216,245))
status.Size=UDim2.new(1,-14,0,30)
status.Position=UDim2.new(0,7,0,118)
status.BackgroundColor3=Color3.fromRGB(9,11,24)
status.BackgroundTransparency=0.18
status.BorderSizePixel=0
status.TextXAlignment=Enum.TextXAlignment.Center
corner(status,13)
stroke(status,Color3.fromRGB(55,52,95),1,0.55)

local function setStatus(t)
	status.Text=tostring(t or "")
end

local pageBug=Instance.new("Frame")
pageBug.Parent=main
pageBug.Size=UDim2.new(1,-14,0,332)
pageBug.Position=UDim2.new(0,7,0,156)
pageBug.BackgroundTransparency=1

local pageTrain=Instance.new("Frame")
pageTrain.Parent=main
pageTrain.Size=pageBug.Size
pageTrain.Position=pageBug.Position
pageTrain.BackgroundTransparency=1
pageTrain.Visible=false

local versionText=makeText(main,HUB_VERSION.." • v16",9,Enum.Font.GothamBlack,Color3.fromRGB(150,158,190))
versionText.Size=UDim2.new(1,-18,0,12)
versionText.Position=UDim2.new(0,9,0,486)
versionText.TextXAlignment=Enum.TextXAlignment.Center

local function showTab(name)
	local bug=name=="bug"
	pageBug.Visible=bug
	pageTrain.Visible=not bug
	tabBug.BackgroundColor3=bug and Color3.fromRGB(45,145,95) or Color3.fromRGB(32,42,65)
	tabTrain.BackgroundColor3=(not bug) and Color3.fromRGB(45,145,95) or Color3.fromRGB(32,42,65)
	setStatus(bug and "Вкладка БАГ" or "Вкладка КАЧ")
end

tabBug.Activated:Connect(function() showTab("bug") end)
tabTrain.Activated:Connect(function() showTab("train") end)

local function makeLever(parent,label,desc,y,initial,callback)
	local row=Instance.new("TextButton")
	row.Parent=parent
	row.Size=UDim2.new(1,0,0,46)
	row.Position=UDim2.new(0,0,0,y)
	row.Text=""
	row.AutoButtonColor=false
	row.BackgroundColor3=Color3.fromRGB(14,16,31)
	row.BackgroundTransparency=0.08
	row.BorderSizePixel=0
	corner(row,15)
	stroke(row,Color3.fromRGB(52,52,95),1,0.55)

	local t=makeText(row,label,13,Enum.Font.GothamBlack,Color3.fromRGB(235,238,255))
	t.Size=UDim2.new(1,-104,0,18)
	t.Position=UDim2.new(0,12,0,5)

	local d=makeText(row,desc or "",9,Enum.Font.GothamBold,Color3.fromRGB(142,150,183))
	d.Size=UDim2.new(1,-104,0,17)
	d.Position=UDim2.new(0,12,0,25)

	local track=Instance.new("Frame")
	track.Parent=row
	track.Size=UDim2.new(0,72,0,28)
	track.Position=UDim2.new(1,-84,0,9)
	track.BackgroundColor3=Color3.fromRGB(65,42,50)
	track.BorderSizePixel=0
	corner(track,14)
	stroke(track,Color3.fromRGB(255,255,255),1,0.86)

	local knob=Instance.new("Frame")
	knob.Parent=track
	knob.Size=UDim2.new(0,24,0,24)
	knob.Position=UDim2.new(0,2,0,2)
	knob.BackgroundColor3=Color3.fromRGB(238,238,245)
	knob.BorderSizePixel=0
	corner(knob,12)
	stroke(knob,Color3.fromRGB(20,20,25),1,0.75)

	local state=initial and true or false
	local obj={}

	local function paint()
		if state then
			track.BackgroundColor3=Color3.fromRGB(34,145,78)
			knob.Position=UDim2.new(1,-26,0,2)
			row.BackgroundColor3=Color3.fromRGB(13,32,24)
		else
			track.BackgroundColor3=Color3.fromRGB(95,45,58)
			knob.Position=UDim2.new(0,2,0,2)
			row.BackgroundColor3=Color3.fromRGB(14,16,31)
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

	row.Activated:Connect(function()
		obj.Set(not state,false)
	end)

	paint()
	return obj
end

local selectedCard=Instance.new("Frame")
selectedCard.Parent=pageBug
selectedCard.Size=UDim2.new(1,0,0,44)
selectedCard.Position=UDim2.new(0,0,0,0)
selectedCard.BackgroundColor3=Color3.fromRGB(15,18,32)
selectedCard.BackgroundTransparency=0.07
selectedCard.BorderSizePixel=0
corner(selectedCard,18)
stroke(selectedCard,Color3.fromRGB(65,62,120),1,0.45)

local selectedLabel=makeText(selectedCard,"ВЫБРАНО АВТО ПО РЕБАМ",9,Enum.Font.GothamBlack,Color3.fromRGB(135,145,180))
selectedLabel.Size=UDim2.new(1,-24,0,14)
selectedLabel.Position=UDim2.new(0,10,0,5)

local selectedName=makeText(selectedCard,"-",17,Enum.Font.GothamBlack,Color3.fromRGB(255,238,185))
selectedName.Size=UDim2.new(1,-20,0,24)
selectedName.Position=UDim2.new(0,10,0,18)

local list=Instance.new("ScrollingFrame")
list.Parent=pageBug
list.Size=UDim2.new(1,0,0,112)
list.Position=UDim2.new(0,0,0,52)
list.BackgroundColor3=Color3.fromRGB(7,8,17)
list.BackgroundTransparency=0.18
list.BorderSizePixel=0
list.ScrollBarThickness=3
list.ScrollBarImageColor3=Color3.fromRGB(100,92,180)
list.CanvasSize=UDim2.new(0,0,0,0)
list.Active=true
corner(list,18)
stroke(list,Color3.fromRGB(48,48,90),1,0.52)

local listPad=Instance.new("UIPadding")
listPad.Parent=list
listPad.PaddingTop=UDim.new(0,8)
listPad.PaddingBottom=UDim.new(0,8)
listPad.PaddingLeft=UDim.new(0,8)
listPad.PaddingRight=UDim.new(0,8)

local listLayout=Instance.new("UIListLayout")
listLayout.Parent=list
listLayout.SortOrder=Enum.SortOrder.LayoutOrder
listLayout.Padding=UDim.new(0,7)

local buttons={}

local function updateSelected()
	if selected then
		selectedName.Text=selected.label.."  •  "..tostring(selected.req)
	else
		selectedName.Text="-"
	end
end

local function refreshButtons()
	for _,b in pairs(buttons)do
		if b and b.Parent then b:Destroy()end
	end
	buttons={}

	for i,row in ipairs(ROCKS)do
		local info=rockCache[row.req]
		local active=selected and selected.id==row.id

		local card=Instance.new("TextButton")
		card.Parent=list
		card.Name="Rock_"..row.id
		card.Size=UDim2.new(1,-4,0,36)
		card.LayoutOrder=i
		card.Text=""
		card.AutoButtonColor=true
		card.BackgroundColor3=active and Color3.fromRGB(46,42,105) or Color3.fromRGB(14,16,31)
		card.BackgroundTransparency=active and 0.02 or 0.10
		card.BorderSizePixel=0
		corner(card,15)
		stroke(card,active and Color3.fromRGB(145,120,255) or Color3.fromRGB(52,52,95),active and 1.4 or 1,active and 0.08 or 0.45)

		local name=makeText(card,row.label,12,Enum.Font.GothamBlack,active and Color3.fromRGB(255,240,190) or Color3.fromRGB(230,234,255))
		name.Size=UDim2.new(1,-62,0,17)
		name.Position=UDim2.new(0,14,0,4)

		local meta=makeText(card,"req "..tostring(row.req),10,Enum.Font.GothamBold,Color3.fromRGB(145,153,185))
		meta.Size=UDim2.new(1,-72,0,16)
		meta.Position=UDim2.new(0,14,0,20)

		local ok=makeText(card,info and "найден" or "нет",10,Enum.Font.GothamBlack,info and Color3.fromRGB(100,255,160) or Color3.fromRGB(150,150,170))
		ok.Size=UDim2.new(0,46,0,20)
		ok.Position=UDim2.new(1,-54,0,8)
		ok.TextXAlignment=Enum.TextXAlignment.Center
		ok.BackgroundColor3=info and Color3.fromRGB(15,55,34) or Color3.fromRGB(36,36,48)
		ok.BackgroundTransparency=0.12
		corner(ok,11)

		card.Activated:Connect(function()
			selected=row
			selectedLabel.Text="ВЫБРАНО ВРУЧНУЮ"
			updateSelected()
			refreshButtons()
			setStatus("Камень: "..row.label)
		end)

		table.insert(buttons,card)
	end

	list.CanvasSize=UDim2.new(0,0,0,#ROCKS*43+16)
	updateSelected()
end

local lockLever
local bugLever
local posLever
local ultraLever
local afkLever
local trainLevers={}

lockLever=makeLever(pageBug,"TP LOCK","держать внутри камня",172,false,function(on,self)
	if on then
		local ok,res=tpInsideRock(selected)
		if ok then setStatus("LOCK: "..selected.label) else setStatus("LOCK error: "..tostring(res)) self.Set(false,true) end
	else
		stopLock()
		setStatus("UNLOCK")
	end
end)

bugLever=makeLever(pageBug,"MAX PUNCH","hard stop при OFF + auto stop вне камня",224,false,function(on,self)
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

local jumpTrain=makeBtn(pageBug,"ПЕРЕЙТИ В КАЧ ➜",Color3.fromRGB(45,95,145))
jumpTrain.Size=UDim2.new(1,0,0,30)
jumpTrain.Position=UDim2.new(0,0,0,282)
jumpTrain.TextSize=13
jumpTrain.Activated:Connect(function() showTab("train") end)

local jumpBug=makeBtn(pageTrain,"⬅ ВЕРНУТЬСЯ В БАГ",Color3.fromRGB(45,95,145))
jumpBug.Size=UDim2.new(1,0,0,28)
jumpBug.Position=UDim2.new(0,0,0,0)
jumpBug.TextSize=13
jumpBug.Activated:Connect(function() showTab("bug") end)

posLever=makeLever(pageTrain,"LOCK POSITION","держать текущую позицию в кач",36,false,function(on,self)
	if on then
		local ok=startTrainPositionLock(setStatus)
		if not ok then self.Set(false,true) end
	else
		stopTrainPositionLock(setStatus)
	end
end)

ultraLever=makeLever(pageTrain,"ULTRA MAP","убрать карту, оставить нужное",84,false,function(on)
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

afkLever=makeLever(pageTrain,"ANTI AFK","не кикать за простой",132,antiAfkEnabled,function(on)
	antiAfkEnabled=on
	setStatus("AFK "..(on and "ON" or "OFF"))
end)

local trainScroll=Instance.new("ScrollingFrame")
trainScroll.Parent=pageTrain
trainScroll.Size=UDim2.new(1,0,0,150)
trainScroll.Position=UDim2.new(0,0,0,180)
trainScroll.BackgroundColor3=Color3.fromRGB(7,8,17)
trainScroll.BackgroundTransparency=0.18
trainScroll.BorderSizePixel=0
trainScroll.ScrollBarThickness=3
trainScroll.CanvasSize=UDim2.new(0,0,0,0)
corner(trainScroll,18)
stroke(trainScroll,Color3.fromRGB(48,48,90),1,0.52)

local function turnOffOtherTrain(id)
	for tid,lever in pairs(trainLevers) do
		if tid~=id and lever and lever.Get() then
			lever.Set(false,true)
			stopTrainType(tid,nil)
		end
	end
end

for i,t in ipairs(TRAIN_TYPES) do
	local y=(i-1)*50+7
	local lever=makeLever(trainScroll,t.label,t.desc,y,false,function(on,self)
		if on then
			turnOffOtherTrain(t.id)
			startTrainType(t,setStatus)
		else
			stopTrainType(t.id,setStatus)
		end
	end)
	trainLevers[t.id]=lever
end
trainScroll.CanvasSize=UDim2.new(0,0,0,#TRAIN_TYPES*50+14)

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

top.InputBegan:Connect(function(input)
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
	selectedLabel.Text="ВЫБРАНО АВТО ПО РЕБАМ"
end

refreshButtons()
showTab("bug")
setStatus("v16: "..tostring(why or "ready"))
