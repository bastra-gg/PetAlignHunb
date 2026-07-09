-- Muscle Legends RockBug Hub v14 CLEAR TABS
-- Standalone: без Speed Hub. Камни через neededDurability + TP LOCK + BUG HIT + Anti AFK.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local VirtualUser=game:GetService("VirtualUser")
local lp=Players.LocalPlayer
local HUB_VERSION="RockBugHub_v14_ClearTabs"

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

-- Анти-дубль.
pcall(function()
	local old=lp:WaitForChild("PlayerGui"):FindFirstChild("RockBugHub_v13_1_UltraSmallUI")
	if old then old:Destroy() end
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
				task.wait()
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

local function startHit(row,statusFn)
	hitting=true
	hitLoopId+=1
	local myId=hitLoopId

	if hitConn then hitConn:Disconnect() hitConn=nil end

	local tool=ensurePunchTool(statusFn)
	collectPunchRemotes()

	local cycle=0
	local lastEquip=0

	task.spawn(function()
		local nextPunch=os.clock()

		while hitting and myId==hitLoopId do
			local now=os.clock()

			local rate=math.clamp(tonumber(_G.RockBugMaxPunchRate or _G.RockBugMaxPunchRateOverride or 90)or 90,10,240)
			local interval=1/rate
			local extra=math.clamp(tonumber(_G.RockBugExtraCyclesPerTick or 2)or 2,1,10)

			if now>=nextPunch then
				nextPunch+=interval
				if nextPunch<now-0.10 then nextPunch=now+interval end

				tool=currentPunchTool() or tool

				for _=1,extra do
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
						firePunchRemote()
					end

					local touchEvery=math.clamp(tonumber(_G.RockBugTouchEvery or 1)or 1,1,8)
					if cycle%touchEvery==0 then
						local touchLoops=math.clamp(tonumber(_G.RockBugTouchLoops or 3)or 3,1,8)
						for _=1,touchLoops do
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
		statusFn("MAX PUNCH: "..tostring(_G.RockBugMaxPunchRate or 90).."/s x"..tostring(_G.RockBugExtraCyclesPerTick or 2).." | remote x"..tostring(_G.RockBugRemoteLoops or 6).." | act x"..tostring(_G.RockBugActivateBursts or 4))
	end
end


local function stopHit(statusFn)
	hitting=false
	hitLoopId+=1
	if hitConn then hitConn:Disconnect() hitConn=nil end
	setLowMap(false,nil,nil)
	if statusFn then statusFn("BUG HIT: остановлен")end
end


-- AUTO TRAIN: не только punch, а любые тренировочные инструменты.
local function trainToolScore(tool)
	if not tool or not tool:IsA("Tool") then return -999 end

	local n=tostring(tool.Name):lower()
	local full=""
	pcall(function() full=tostring(tool:GetFullName()):lower() end)

	-- Punch оставляем для вкладки БАГ, а КАЧ берёт веса/тренировки.
	if toolScore(tool)>0 then return -999 end

	local bad={"pet","aura","crystal","shop","trade","gift","pack","code","reward","пет","питом","крист","магаз","обмен"}
	for _,w in ipairs(bad) do
		if n:find(w,1,true) or full:find(w,1,true) then return -999 end
	end

	local score=0
	local good={
		{"weight",120},{"dumb",115},{"barbell",115},{"bench",100},
		{"push",95},{"sit",90},{"handstand",90},{"pull",85},
		{"tread",80},{"agility",70},{"durability",70},{"strength",70},
		{"гант",120},{"штанг",115},{"гир",110},{"вес",100},
		{"отжим",95},{"пресс",90},{"бег",80},{"сила",70}
	}

	for _,pair in ipairs(good) do
		if n:find(pair[1],1,true) or full:find(pair[1],1,true) then
			score=math.max(score,pair[2])
		end
	end

	-- Если это Tool и не Punch/не мусор — даём запасной шанс.
	if score<=0 then score=10 end

	return score
end

local function findBestTrainTool()
	local c=lp.Character
	local bp=lp:FindFirstChildOfClass("Backpack")
	local best=nil
	local bestScore=-999

	local function scan(container,bonus)
		if not container then return end
		for _,tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				local sc=trainToolScore(tool)+bonus
				if sc>bestScore then
					bestScore=sc
					best=tool
				end
			end
		end
	end

	scan(c,20)
	scan(bp,0)

	if bestScore<=0 then return nil end
	return best,bestScore
end

local function ensureTrainTool(statusFn)
	local c=lp.Character
	local h=hum()
	if not c or not h then return nil end

	for _,tool in ipairs(c:GetChildren()) do
		if tool:IsA("Tool") and trainToolScore(tool)>0 then
			selectedTrainToolName=tool.Name
			return tool
		end
	end

	local best=findBestTrainTool()
	if best and best.Parent~=c then
		pcall(function() h:EquipTool(best) end)
		task.wait(0.06)
	end

	if best then
		clearToolCooldowns(best)
		selectedTrainToolName=best.Name
		if statusFn then statusFn("КАЧ: выбран "..best.Name) end
		return best
	end

	if statusFn then statusFn("КАЧ: Tool не найден") end
	return nil
end

local function fireTrainRemoteSpam()
	if _G.RockBugAutoTrainUseRemote==false then return end

	local loops=math.clamp(tonumber(_G.RockBugAutoTrainRemoteLoops or 2)or 2,0,12)
	if loops<=0 then return end

	local function fireOne(ev)
		if not ev or not ev.FireServer then return end
		pcall(function()
			ev:FireServer("rep")
			ev:FireServer("train")
			ev:FireServer("strength")
			ev:FireServer("weight")
		end)
	end

	for _=1,loops do
		pcall(function()
			if lp:FindFirstChild("muscleEvent") then fireOne(lp.muscleEvent) end
		end)

		pcall(function()
			local rs=game:GetService("ReplicatedStorage")
			local re=rs:FindFirstChild("rEvents")
			local ev=re and re:FindFirstChild("muscleEvent")
			fireOne(ev)
		end)
	end
end

local function startAutoTrain(statusFn)
	autoTrainEnabled=true
	autoTrainLoopId+=1
	local myId=autoTrainLoopId

	task.spawn(function()
		local tool=ensureTrainTool(statusFn)
		local nextRep=os.clock()
		local lastEquip=0

		while autoTrainEnabled and myId==autoTrainLoopId do
			local now=os.clock()
			local rate=math.clamp(tonumber(_G.RockBugAutoTrainRate or 35)or 35,3,120)
			local interval=1/rate

			if now>=nextRep then
				nextRep+=interval
				if nextRep<now-0.15 then nextRep=now+interval end

				tool=tool or ensureTrainTool(nil)

				if tool and tool.Parent then
					clearToolCooldowns(tool)
					local bursts=math.clamp(tonumber(_G.RockBugAutoTrainActivateBursts or 2)or 2,1,10)
					for _=1,bursts do
						pcall(function() tool:Activate() end)
					end
				end

				fireTrainRemoteSpam()
			end

			if now-lastEquip>=1.1 then
				lastEquip=now
				tool=ensureTrainTool(nil) or tool
			end

			task.wait(math.clamp(nextRep-os.clock(),0,0.02))
		end
	end)

	if statusFn then
		statusFn("АВТО КАЧ: ON | "..tostring(_G.RockBugAutoTrainRate or 35).."/s"..(selectedTrainToolName and (" | "..selectedTrainToolName) or ""))
	end
end

local function stopAutoTrain(statusFn)
	autoTrainEnabled=false
	autoTrainLoopId+=1
	if statusFn then statusFn("АВТО КАЧ: OFF") end
end



-- UI v14 CLEAR TABS: большой переход между вкладками, без скрытых мелких кнопок
local gui=Instance.new("ScreenGui")
gui.Name="RockBugHub_v14_ClearTabs"
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

local function label(parent,text,size,font,color)
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

local function button(parent,text,color)
	local b=Instance.new("TextButton")
	b.Parent=parent
	b.Text=text
	b.TextColor3=Color3.fromRGB(238,241,255)
	b.BackgroundColor3=color
	b.BackgroundTransparency=0.05
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
main.Size=UDim2.new(0,326,0,462)
main.Position=UDim2.new(0,10,0,58)
main.BackgroundColor3=Color3.fromRGB(8,10,18)
main.BackgroundTransparency=0.08
main.BorderSizePixel=0
main.Active=true
corner(main,22)
stroke(main,Color3.fromRGB(95,85,180),1.4,0.18)

local top=Instance.new("Frame")
top.Parent=main
top.Size=UDim2.new(1,-14,0,46)
top.Position=UDim2.new(0,7,0,7)
top.BackgroundColor3=Color3.fromRGB(14,16,30)
top.BackgroundTransparency=0.08
top.BorderSizePixel=0
corner(top,18)
stroke(top,Color3.fromRGB(70,68,130),1,0.45)

local title=label(top,"BUG HUB v14",18,Enum.Font.GothamBlack,Color3.fromRGB(248,249,255))
title.Size=UDim2.new(1,-95,0,22)
title.Position=UDim2.new(0,12,0,5)

local sub=label(top,"большие вкладки сверху",10,Enum.Font.GothamBold,Color3.fromRGB(165,172,205))
sub.Size=UDim2.new(1,-95,0,16)
sub.Position=UDim2.new(0,13,0,26)

local min=button(top,"−",Color3.fromRGB(42,39,78))
min.Size=UDim2.new(0,29,0,29)
min.Position=UDim2.new(1,-66,0,9)
min.TextSize=18

local close=button(top,"×",Color3.fromRGB(78,28,42))
close.Size=UDim2.new(0,29,0,29)
close.Position=UDim2.new(1,-33,0,9)
close.TextSize=18
close.TextColor3=Color3.fromRGB(255,210,218)

local mini=button(gui,"BUG HUB v14",Color3.fromRGB(46,42,120))
mini.Size=UDim2.new(0,98,0,36)
mini.Position=main.Position
mini.Visible=false
mini.TextSize=10

-- Самый заметный переход между вкладками
local tabHint=label(main,"ВЫБЕРИ РЕЖИМ:",10,Enum.Font.GothamBlack,Color3.fromRGB(150,160,200))
tabHint.Size=UDim2.new(1,-18,0,14)
tabHint.Position=UDim2.new(0,9,0,58)
tabHint.TextXAlignment=Enum.TextXAlignment.Center

local tabFrame=Instance.new("Frame")
tabFrame.Parent=main
tabFrame.Size=UDim2.new(1,-14,0,54)
tabFrame.Position=UDim2.new(0,7,0,74)
tabFrame.BackgroundTransparency=1

local tabBug=button(tabFrame,"🪨 БАГ\nкамень",Color3.fromRGB(65,75,145))
tabBug.Size=UDim2.new(0.5,-5,1,0)
tabBug.Position=UDim2.new(0,0,0,0)
tabBug.TextSize=13
tabBug.TextWrapped=true

local tabTrain=button(tabFrame,"💪 КАЧ\nавто треня",Color3.fromRGB(28,42,68))
tabTrain.Size=UDim2.new(0.5,-5,1,0)
tabTrain.Position=UDim2.new(0.5,5,0,0)
tabTrain.TextSize=13
tabTrain.TextWrapped=true

local modeTitle=label(main,"РЕЖИМ: БАГ КАМНЯ",13,Enum.Font.GothamBlack,Color3.fromRGB(255,238,185))
modeTitle.Size=UDim2.new(1,-14,0,24)
modeTitle.Position=UDim2.new(0,7,0,134)
modeTitle.BackgroundColor3=Color3.fromRGB(13,15,30)
modeTitle.BackgroundTransparency=0.10
modeTitle.BorderSizePixel=0
modeTitle.TextXAlignment=Enum.TextXAlignment.Center
corner(modeTitle,12)
stroke(modeTitle,Color3.fromRGB(60,58,110),1,0.50)

local status=label(main,"Готово",11,Enum.Font.GothamBold,Color3.fromRGB(210,216,245))
status.Size=UDim2.new(1,-14,0,30)
status.Position=UDim2.new(0,7,0,424)
status.BackgroundColor3=Color3.fromRGB(9,11,24)
status.BackgroundTransparency=0.20
status.BorderSizePixel=0
status.TextXAlignment=Enum.TextXAlignment.Center
corner(status,13)
stroke(status,Color3.fromRGB(55,52,95),1,0.55)

local function setStatus(t)
	status.Text=tostring(t or "")
end

local pageBug=Instance.new("Frame")
pageBug.Parent=main
pageBug.Size=UDim2.new(1,-14,0,254)
pageBug.Position=UDim2.new(0,7,0,164)
pageBug.BackgroundTransparency=1

local pageTrain=Instance.new("Frame")
pageTrain.Parent=main
pageTrain.Size=pageBug.Size
pageTrain.Position=pageBug.Position
pageTrain.BackgroundTransparency=1
pageTrain.Visible=false

local function setMode(mode)
	local isBug=mode=="bug"
	pageBug.Visible=isBug
	pageTrain.Visible=not isBug

	tabBug.BackgroundColor3=isBug and Color3.fromRGB(65,75,145) or Color3.fromRGB(28,42,68)
	tabTrain.BackgroundColor3=(not isBug) and Color3.fromRGB(65,75,145) or Color3.fromRGB(28,42,68)

	tabBug.TextColor3=isBug and Color3.fromRGB(255,245,210) or Color3.fromRGB(200,208,235)
	tabTrain.TextColor3=(not isBug) and Color3.fromRGB(255,245,210) or Color3.fromRGB(200,208,235)

	modeTitle.Text=isBug and "РЕЖИМ: БАГ КАМНЯ" or "РЕЖИМ: АВТО КАЧАНИЕ"
	modeTitle.TextColor3=isBug and Color3.fromRGB(255,238,185) or Color3.fromRGB(175,255,205)
	setStatus(isBug and "Вкладка БАГ" or "Вкладка КАЧ")
end

tabBug.Activated:Connect(function() setMode("bug") end)
tabTrain.Activated:Connect(function() setMode("train") end)

-- ВКЛАДКА БАГ
local selectedCard=Instance.new("Frame")
selectedCard.Parent=pageBug
selectedCard.Size=UDim2.new(1,0,0,44)
selectedCard.Position=UDim2.new(0,0,0,0)
selectedCard.BackgroundColor3=Color3.fromRGB(15,18,32)
selectedCard.BackgroundTransparency=0.07
selectedCard.BorderSizePixel=0
corner(selectedCard,18)
stroke(selectedCard,Color3.fromRGB(65,62,120),1,0.45)

local selectedSmall=label(selectedCard,"ВЫБРАННЫЙ КАМЕНЬ",9,Enum.Font.GothamBlack,Color3.fromRGB(135,145,180))
selectedSmall.Size=UDim2.new(1,-24,0,14)
selectedSmall.Position=UDim2.new(0,10,0,5)

local selectedName=label(selectedCard,"-",17,Enum.Font.GothamBlack,Color3.fromRGB(255,238,185))
selectedName.Size=UDim2.new(1,-20,0,24)
selectedName.Position=UDim2.new(0,10,0,18)

local list=Instance.new("ScrollingFrame")
list.Parent=pageBug
list.Size=UDim2.new(1,0,0,106)
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
		card.Size=UDim2.new(1,-4,0,38)
		card.LayoutOrder=i
		card.Text=""
		card.AutoButtonColor=true
		card.BackgroundColor3=active and Color3.fromRGB(46,42,105) or Color3.fromRGB(14,16,31)
		card.BackgroundTransparency=active and 0.02 or 0.10
		card.BorderSizePixel=0
		corner(card,15)
		stroke(card,active and Color3.fromRGB(145,120,255) or Color3.fromRGB(52,52,95),active and 1.4 or 1,active and 0.08 or 0.45)

		local bar=Instance.new("Frame")
		bar.Parent=card
		bar.Size=UDim2.new(0,4,1,-12)
		bar.Position=UDim2.new(0,8,0,6)
		bar.BackgroundColor3=info and row.color or Color3.fromRGB(75,78,100)
		bar.BorderSizePixel=0
		corner(bar,6)

		local name=label(card,row.label,12,Enum.Font.GothamBlack,active and Color3.fromRGB(255,240,190) or Color3.fromRGB(230,234,255))
		name.Size=UDim2.new(1,-62,0,17)
		name.Position=UDim2.new(0,20,0,4)

		local meta=label(card,"req "..tostring(row.req),10,Enum.Font.GothamBold,Color3.fromRGB(145,153,185))
		meta.Size=UDim2.new(1,-72,0,16)
		meta.Position=UDim2.new(0,20,0,21)

		local ok=label(card,info and "найден" or "нет",10,Enum.Font.GothamBlack,info and Color3.fromRGB(100,255,160) or Color3.fromRGB(150,150,170))
		ok.Size=UDim2.new(0,46,0,20)
		ok.Position=UDim2.new(1,-54,0,9)
		ok.TextXAlignment=Enum.TextXAlignment.Center
		ok.BackgroundColor3=info and Color3.fromRGB(15,55,34) or Color3.fromRGB(36,36,48)
		ok.BackgroundTransparency=0.12
		corner(ok,11)

		card.Activated:Connect(function()
			selected=row
			updateSelected()
			refreshButtons()
			if ultraOptEnabled then
				setLowMap(false,nil,nil)
				local old=_G.RockBugLowMapTransparency
				_G.RockBugLowMapTransparency=1
				local info=getRock(selected)
				setLowMap(true,info and info.model,nil)
				_G.RockBugLowMapTransparency=old
			end
			setStatus("Камень: "..row.label)
		end)

		table.insert(buttons,card)
	end

	list.CanvasSize=UDim2.new(0,0,0,#ROCKS*45+16)
	updateSelected()
end

local function makeSwitch(parent,labelText,desc,y,initial,callback)
	local row=Instance.new("Frame")
	row.Parent=parent
	row.Size=UDim2.new(1,0,0,40)
	row.Position=UDim2.new(0,0,0,y)
	row.BackgroundColor3=Color3.fromRGB(14,16,31)
	row.BackgroundTransparency=0.08
	row.BorderSizePixel=0
	corner(row,15)
	stroke(row,Color3.fromRGB(52,52,95),1,0.55)

	local t=label(row,labelText,12,Enum.Font.GothamBlack,Color3.fromRGB(235,238,255))
	t.Size=UDim2.new(1,-98,0,18)
	t.Position=UDim2.new(0,12,0,3)

	local d=label(row,desc or "",9,Enum.Font.GothamBold,Color3.fromRGB(142,150,183))
	d.Size=UDim2.new(1,-100,0,17)
	d.Position=UDim2.new(0,12,0,20)

	local sw=Instance.new("TextButton")
	sw.Parent=row
	sw.Size=UDim2.new(0,72,0,26)
	sw.Position=UDim2.new(1,-82,0,7)
	sw.BorderSizePixel=0
	sw.AutoButtonColor=true
	sw.Font=Enum.Font.GothamBlack
	sw.TextSize=10
	corner(sw,13)

	local state=initial and true or false
	local obj={}

	local function paint()
		sw.Text=state and "ON" or "OFF"
		sw.TextColor3=state and Color3.fromRGB(230,255,236) or Color3.fromRGB(235,238,255)
		sw.BackgroundColor3=state and Color3.fromRGB(30,135,72) or Color3.fromRGB(70,44,55)
	end

	function obj.Set(v,silent)
		state=v and true or false
		paint()
		if callback and not silent then callback(state,obj) end
	end

	function obj.Get()
		return state
	end

	sw.Activated:Connect(function()
		obj.Set(not state,false)
	end)

	row.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.Touch then
			obj.Set(not state,false)
		end
	end)

	paint()
	return obj
end

local lockSw
local bugSw
local ultraSw
local afkSw
local trainSw
local trainRemoteSw

lockSw=makeSwitch(pageBug,"TP LOCK","держать персонажа в камне",166,false,function(on,self)
	if on then
		local ok,res=tpInsideRock(selected)
		if ok then
			setStatus("LOCK: "..selected.label)
		else
			setStatus("LOCK error: "..tostring(res))
			self.Set(false,true)
		end
	else
		stopLock()
		setStatus("UNLOCK")
	end
end)

bugSw=makeSwitch(pageBug,"MAX PUNCH","максимальные удары по камню",210,false,function(on,self)
	if on then
		local ok,msg=tpInsideRock(selected)
		if not ok then
			setStatus("BUG error: "..tostring(msg))
			self.Set(false,true)
			return
		end
		startHit(selected,setStatus)
	else
		stopHit(setStatus)
	end
end)

-- ВКЛАДКА КАЧ
local trainInfo=label(pageTrain,"Тут не камень. Это авто качание тренировочным Tool: weight / dumbbell / barbell / bench / push и т.д.",10,Enum.Font.GothamBold,Color3.fromRGB(180,190,225))
trainInfo.Size=UDim2.new(1,0,0,38)
trainInfo.Position=UDim2.new(0,0,0,0)
trainInfo.BackgroundColor3=Color3.fromRGB(13,15,30)
trainInfo.BackgroundTransparency=0.10
trainInfo.BorderSizePixel=0
trainInfo.TextXAlignment=Enum.TextXAlignment.Center
corner(trainInfo,14)
stroke(trainInfo,Color3.fromRGB(55,60,110),1,0.50)

trainSw=makeSwitch(pageTrain,"AUTO TRAIN","спамить тренировочный Tool",48,false,function(on,self)
	if on then
		startAutoTrain(setStatus)
	else
		stopAutoTrain(setStatus)
	end
end)

trainRemoteSw=makeSwitch(pageTrain,"TRAIN REMOTE","добавлять rep/train remote",92,_G.RockBugAutoTrainUseRemote~=false,function(on)
	_G.RockBugAutoTrainUseRemote=on
	setStatus("TRAIN REMOTE "..(on and "ON" or "OFF"))
end)

ultraSw=makeSwitch(pageTrain,"ULTRA MAP","убрать карту, оставить нужное",136,false,function(on,self)
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

afkSw=makeSwitch(pageTrain,"ANTI AFK","не кикать за простой",180,antiAfkEnabled,function(on)
	antiAfkEnabled=on
	setStatus("AFK "..(on and "ON" or "OFF"))
end)

local allOffSw=makeSwitch(pageTrain,"ALL OFF","выключить всё",224,false,function(on,self)
	if on then
		stopAutoTrain()
		stopHit()
		stopLock()
		ultraOptEnabled=false
		setLowMap(false,nil,nil)
		if bugSw then bugSw.Set(false,true) end
		if lockSw then lockSw.Set(false,true) end
		if ultraSw then ultraSw.Set(false,true) end
		if trainSw then trainSw.Set(false,true) end
		setStatus("ALL OFF")
		task.defer(function() self.Set(false,true) end)
	end
end)

min.Activated:Connect(function()
	main.Visible=false
	mini.Visible=true
end)

mini.Activated:Connect(function()
	main.Visible=true
	mini.Visible=false
end)

close.Activated:Connect(function()
	stopAutoTrain()
	stopHit()
	stopLock()
	setLowMap(false,nil,nil)
	if antiAfkConn then antiAfkConn:Disconnect() antiAfkConn=nil end
	gui:Destroy()
end)

-- drag за верх
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
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
		local delta=input.Position-dragStart
		main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
		mini.Position=main.Position
	end
end)

rockCache=scanRocks()
refreshButtons()
setMode("bug")
setStatus("Готово. Вкладки сверху: БАГ / КАЧ")
