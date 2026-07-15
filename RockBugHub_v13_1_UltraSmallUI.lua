-- Muscle Legends RockBug Hub v13 COMPACT ULTRA FIX
-- Standalone: без Speed Hub. Камни через neededDurability + TP LOCK + BUG HIT + Anti AFK.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local VirtualUser=game:GetService("VirtualUser")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local lp=Players.LocalPlayer
local HUB_VERSION="RockBugHub_v13_1_UltraSmallUI"

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
local fastHitPower=1 -- v10: обычный КД, без FAST-спама

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
	local info=getRock(row)

	local lastTouch=0
	local lastEquip=0
	local lastActivate=0

	task.spawn(function()
		while hitting and myId==hitLoopId do
			local now=os.clock()

			-- Обычный КД: не спамим, не чистим cooldown, не душим телефон.
			if now-lastEquip>2.0 then
				lastEquip=now
				tool=ensurePunchTool(nil) or currentPunchTool()
			end

			firePunchRemote()

			if tool and tool.Parent and now-lastActivate>=(_G.RockBugActivateDelay or 0.22) then
				lastActivate=now
				pcall(function()tool:Activate()end)
			elseif not tool or not tool.Parent then
				activateFistTool(nil)
			end

			if now-lastTouch>=(_G.RockBugTouchDelay or 0.40) then
				lastTouch=now
				touchRock(row)
			end

			task.wait(_G.RockBugHitDelay or 0.16)
		end
	end)

	if statusFn then
		statusFn("BUG HIT: обычный КД"..(ultraOptEnabled and " | ULTRA ON" or "")..(selectedPunchToolName and (" | "..selectedPunchToolName) or ""))
	end
end


local function stopHit(statusFn)
	hitting=false
	hitLoopId+=1
	if hitConn then hitConn:Disconnect() hitConn=nil end
	setLowMap(false,nil,nil)
	if statusFn then statusFn("BUG HIT: остановлен")end
end

-- Separate AUTO KILL + CRYSTALS engines. UI callbacks are assigned below.
local killMode="off"
local killLoopId=0
local killWhitelist={}
local killBlacklist={}
local killStatusFn=function()end
local killRefreshFn=function()end

local PET_TARGETS={
	{name="Orange Hedgehog",crystal="Blue Crystal"},
	{name="Blue Birdie",crystal="Blue Crystal"},
	{name="Red Kitty",crystal="Blue Crystal"},
	{name="Blue Bunny",crystal="Blue Crystal"},
	{name="Dark Vampy",crystal="Blue Crystal"},
	{name="Silver Dog",crystal="Green Crystal"},
	{name="Dark Golem",crystal="Green Crystal"},
	{name="Green Butterfly",crystal="Green Crystal"},
	{name="Crimson Falcon",crystal="Green Crystal"},
	{name="Yellow Butterfly",crystal="Frost Crystal"},
	{name="Purple Dragon",crystal="Frost Crystal"},
	{name="Orange Pegasus",crystal="Frost Crystal"},
	{name="Blue Pheonix",crystal="Frost Crystal"},
	{name="Red Dragon",crystal="Mythical Crystal"},
	{name="Purple Falcon",crystal="Mythical Crystal"},
	{name="Blue Firecaster",crystal="Mythical Crystal"},
	{name="Golden Pheonix",crystal="Mythical Crystal"},
	{name="Red Firecaster",crystal="Inferno Crystal"},
	{name="White Pegasus",crystal="Inferno Crystal"},
	{name="Infernal Dragon",crystal="Inferno Crystal"},
	{name="Green Firecaster",crystal="Legends Crystal"},
	{name="White Pheonix",crystal="Legends Crystal"},
	{name="Magic Butterfly",crystal="Legends Crystal"},
	{name="Ultra Birdie",crystal="Legends Crystal"},
	{name="Frostwave Legends Penguin",crystal="Muscle Elite Crystal"},
	{name="Phantom Genesis Dragon",crystal="Muscle Elite Crystal"},
	{name="Dark Legends Manticore",crystal="Muscle Elite Crystal"},
	{name="Ultimate Supernova Pegasus",crystal="Muscle Elite Crystal"},
	{name="Aether Spirit Bunny",crystal="Muscle Elite Crystal"},
	{name="Cybernetic Showdown Dragon",crystal="Muscle Elite Crystal"},
	{name="Eternal Strike Leviathan",crystal="Galaxy Oracle Crystal"},
	{name="Lighting Strike Phantom",crystal="Galaxy Oracle Crystal"},
	{name="Darkstar Hunter",crystal="Galaxy Oracle Crystal"},
	{name="Golden Viking",crystal="Jungle Crystal"},
	{name="Muscle Sensei",crystal="Jungle Crystal"},
	{name="Neon Guardian",crystal="Jungle Crystal"},
}

local AURA_TARGETS={
	{name="Basic Aura",crystal="Blue Crystal"},
	{name="Advanced Aura",crystal="Green Crystal"},
	{name="Rare Aura",crystal="Frost Crystal"},
	{name="Epic Aura",crystal="Mythical Crystal"},
	{name="Unique Aura",crystal="Inferno Crystal"},
	{name="Ultra Inferno Aura",crystal="Galaxy Oracle Crystal"},
	{name="Azure Tundra Aura",crystal="Galaxy Oracle Crystal"},
	{name="Muscle King Aura",crystal="Galaxy Oracle Crystal"},
	{name="Grand SuperNova Aura",crystal="Jungle Crystal"},
	{name="Eternal Megastrike Aura",crystal="Jungle Crystal"},
	{name="Entropic Blast Aura",crystal="Jungle Crystal"},
}

local FALLBACK_CRYSTALS={
	"Blue Crystal","Green Crystal","Frost Crystal","Mythical Crystal",
	"Inferno Crystal","Legends Crystal","Muscle Elite Crystal",
	"Galaxy Oracle Crystal","Sky Eclipse Crystal","Dark Nebula Crystal","Jungle Crystal",
}

local selectedCrystal="Blue Crystal"
local selectedPet=PET_TARGETS[1]
local selectedAura=AURA_TARGETS[1]
local crystalMode="off"
local crystalLoopId=0
local crystalStatusFn=function()end
local crystalRefreshFn=function()end

local function tableCount(t)
	local n=0
	for _,v in pairs(t)do if v then n+=1 end end
	return n
end

local function getAvailableCrystalNames()
	local names,seen={},{}
	local folder=workspace:FindFirstChild("mapCrystalsFolder")
	if folder then
		for _,obj in ipairs(folder:GetChildren())do
			local name=tostring(obj.Name)
			if string.find(string.lower(name),"crystal",1,true)and not seen[string.lower(name)]then
				seen[string.lower(name)]=true
				table.insert(names,name)
			end
		end
	end
	if #names==0 then
		for _,name in ipairs(FALLBACK_CRYSTALS)do table.insert(names,name)end
	end
	table.sort(names,function(a,b)return string.lower(a)<string.lower(b)end)
	return names
end

local function resolveCrystalName(wanted)
	local names=getAvailableCrystalNames()
	local lower=string.lower(tostring(wanted or ""))
	for _,name in ipairs(names)do
		if string.lower(name)==lower then return name end
	end
	if lower=="frost crystal"then
		for _,name in ipairs(names)do
			if string.lower(name)=="frozen crystal"then return name end
		end
	elseif lower=="frozen crystal"then
		for _,name in ipairs(names)do
			if string.lower(name)=="frost crystal"then return name end
		end
	end
	return wanted
end

local function folderOwnsNamed(folderName,targetName)
	local folder=lp:FindFirstChild(folderName)
	if not folder then return false end
	local wanted=string.lower(tostring(targetName or ""))
	for _,obj in ipairs(folder:GetDescendants())do
		if string.lower(obj.Name)==wanted then return true end
		if obj:IsA("StringValue")then
			local ok,value=pcall(function()return string.lower(tostring(obj.Value))end)
			if ok and value==wanted then return true end
		end
	end
	return false
end

local function ownsPet(name)
	return folderOwnsNamed("petsFolder",name)
end

local function ownsAura(name)
	return folderOwnsNamed("trailsFolder",name)or folderOwnsNamed("aurasFolder",name)
end

local function shouldKillPlayer(player)
	if player==lp then return false end
	if killMode=="all"then return true end
	if killMode=="whitelist"then return not killWhitelist[player.UserId]end
	if killMode=="blacklist"then return killBlacklist[player.UserId]==true end
	return false
end

local function attackPlayer(player)
	local myChar=lp.Character
	local targetChar=player and player.Character
	local targetHum=targetChar and targetChar:FindFirstChildWhichIsA("Humanoid")
	local targetRoot=targetChar and targetChar:FindFirstChild("HumanoidRootPart")
	if not myChar or not targetRoot or not targetHum or targetHum.Health<=0 then return end

	local tool=ensurePunchTool(nil)
	if tool then
		clearToolCooldowns(tool)
		pcall(function()tool:Activate()end)
	end
	firePunchRemote()

	if firetouchinterest then
		for _,handName in ipairs({"RightHand","LeftHand","Right Arm","Left Arm"})do
			local hand=myChar:FindFirstChild(handName,true)
			if hand and hand:IsA("BasePart")then
				pcall(function()
					firetouchinterest(hand,targetRoot,0)
					firetouchinterest(hand,targetRoot,1)
				end)
			end
		end
	end
end

local function setKillMode(mode)
	killLoopId+=1
	killMode=mode or "off"
	killRefreshFn()
	if killMode=="off"then
		killStatusFn("АВТОКИЛ: выключен")
		return
	end
	local myId=killLoopId
	killStatusFn("АВТОКИЛ: "..string.upper(killMode))
	task.spawn(function()
		while killMode~="off"and killLoopId==myId do
			for _,player in ipairs(Players:GetPlayers())do
				if killLoopId~=myId then break end
				if shouldKillPlayer(player)then attackPlayer(player)end
			end
			task.wait(0.10)
		end
	end)
end

local function openCrystalOnce(name)
	local rEvents=ReplicatedStorage:FindFirstChild("rEvents")
	local remote=rEvents and rEvents:FindFirstChild("openCrystalRemote")
	if not remote then return false,"openCrystalRemote не найден"end
	local resolved=resolveCrystalName(name)
	local ok,err=pcall(function()remote:InvokeServer("openCrystal",resolved)end)
	return ok,err,resolved
end

local function crystalTargetForMode(mode)
	if mode=="crystal"then return selectedCrystal,selectedCrystal end
	if mode=="pet"and selectedPet then return selectedPet.crystal,selectedPet.name end
	if mode=="aura"and selectedAura then return selectedAura.crystal,selectedAura.name end
	return nil,nil
end

local function setCrystalMode(mode)
	crystalLoopId+=1
	crystalMode=mode or "off"
	crystalRefreshFn()
	if crystalMode=="off"then
		crystalStatusFn("КРИСТАЛЛЫ: выключено")
		return
	end
	local crystalName,targetName=crystalTargetForMode(crystalMode)
	if not crystalName then
		crystalMode="off"
		crystalRefreshFn()
		crystalStatusFn("Сначала выбери цель")
		return
	end
	local myMode=crystalMode
	local myId=crystalLoopId
	crystalStatusFn("АВТО: "..targetName)
	task.spawn(function()
		while crystalMode==myMode and crystalLoopId==myId do
			if myMode=="pet"and ownsPet(targetName)then
				crystalMode="off"
				crystalLoopId+=1
				crystalRefreshFn()
				crystalStatusFn("ПОЛУЧЕН: "..targetName)
				break
			end
			if myMode=="aura"and ownsAura(targetName)then
				crystalMode="off"
				crystalLoopId+=1
				crystalRefreshFn()
				crystalStatusFn("ПОЛУЧЕНА: "..targetName)
				break
			end
			local ok,err,resolved=openCrystalOnce(crystalName)
			if not ok then
				crystalStatusFn("ОШИБКА: "..tostring(err))
				task.wait(1)
			else
				crystalStatusFn("ОТКРЫВАЮ: "..tostring(resolved))
				task.wait(0.35)
			end
		end
	end)
end

-- Legacy UI kept for reference but disabled; the active three-tab UI is below.
if false then
-- UI v12: новый компактный дизайн без SCAN/COPY/лишних надписей
local gui=Instance.new("ScreenGui")
gui.Name="RockBugHub_v13_1_UltraSmallUI"
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
main.Size=UDim2.new(0,300,0,414)
main.Position=UDim2.new(0,10,0,74)
main.BackgroundColor3=Color3.fromRGB(8,10,18)
main.BackgroundTransparency=0.10
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

local icon=Instance.new("TextLabel")
icon.Parent=top
icon.Size=UDim2.new(0,30,0,30)
icon.Position=UDim2.new(0,9,0,8)
icon.BackgroundColor3=Color3.fromRGB(42,38,86)
icon.BackgroundTransparency=0.05
icon.Text="◆"
icon.TextColor3=Color3.fromRGB(150,130,255)
icon.Font=Enum.Font.GothamBlack
icon.TextSize=18
corner(icon,13)

local title=makeText(top,"BUG HUB",18,Enum.Font.GothamBlack,Color3.fromRGB(248,249,255))
title.Size=UDim2.new(1,-108,0,22)
title.Position=UDim2.new(0,46,0,6)

local sub=makeText(top,"камень • lock • punch",10,Enum.Font.GothamBold,Color3.fromRGB(165,172,205))
sub.Size=UDim2.new(1,-108,0,16)
sub.Position=UDim2.new(0,47,0,26)

local min=makeBtn(top,"−",Color3.fromRGB(42,39,78))
min.Size=UDim2.new(0,29,0,29)
min.Position=UDim2.new(1,-66,0,9)
min.TextSize=18

local close=makeBtn(top,"×",Color3.fromRGB(78,28,42))
close.Size=UDim2.new(0,29,0,29)
close.Position=UDim2.new(1,-33,0,9)
close.TextSize=18
close.TextColor3=Color3.fromRGB(255,210,218)

local mini=makeBtn(gui,"BUG HUB",Color3.fromRGB(46,42,120))
mini.Size=UDim2.new(0,90,0,36)
mini.Position=main.Position
mini.Visible=false
mini.TextSize=11

local selectedCard=Instance.new("Frame")
selectedCard.Parent=main
selectedCard.Size=UDim2.new(1,-14,0,48)
selectedCard.Position=UDim2.new(0,7,0,60)
selectedCard.BackgroundColor3=Color3.fromRGB(15,18,32)
selectedCard.BackgroundTransparency=0.07
selectedCard.BorderSizePixel=0
corner(selectedCard,18)
stroke(selectedCard,Color3.fromRGB(65,62,120),1,0.45)

local selectedLabel=makeText(selectedCard,"ВЫБРАНО",9,Enum.Font.GothamBlack,Color3.fromRGB(135,145,180))
selectedLabel.Size=UDim2.new(1,-24,0,14)
selectedLabel.Position=UDim2.new(0,10,0,6)

local selectedName=makeText(selectedCard,"-",18,Enum.Font.GothamBlack,Color3.fromRGB(255,238,185))
selectedName.Size=UDim2.new(1,-20,0,24)
selectedName.Position=UDim2.new(0,10,0,20)

local status=makeText(main,"Готово",11,Enum.Font.GothamBold,Color3.fromRGB(210,216,245))
status.Size=UDim2.new(1,-14,0,28)
status.Position=UDim2.new(0,7,0,114)

local versionText=makeText(main,HUB_VERSION,9,Enum.Font.GothamBlack,Color3.fromRGB(150,158,190))
versionText.Name="VersionText"
versionText.Size=UDim2.new(1,-18,0,14)
versionText.Position=UDim2.new(0,9,0,396)
versionText.TextXAlignment=Enum.TextXAlignment.Center
status.BackgroundColor3=Color3.fromRGB(9,11,24)
status.BackgroundTransparency=0.20
status.BorderSizePixel=0
status.TextXAlignment=Enum.TextXAlignment.Center
corner(status,13)
stroke(status,Color3.fromRGB(55,52,95),1,0.55)

local function setStatus(t)
	status.Text=tostring(t or "")
end

local list=Instance.new("ScrollingFrame")
list.Parent=main
list.Size=UDim2.new(1,-14,0,130)
list.Position=UDim2.new(0,7,0,150)
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
listLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center

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
		card.Size=UDim2.new(1,-4,0,40)
		card.LayoutOrder=i
		card.Text=""
		card.AutoButtonColor=true
		card.BackgroundColor3=active and Color3.fromRGB(46,42,105) or Color3.fromRGB(14,16,31)
		card.BackgroundTransparency=active and 0.02 or 0.10
		card.BorderSizePixel=0
		corner(card,15)
		stroke(card,active and Color3.fromRGB(145,120,255) or Color3.fromRGB(52,52,95),active and 1.4 or 1,active and 0.08 or 0.45)

		local leftBar=Instance.new("Frame")
		leftBar.Parent=card
		leftBar.Size=UDim2.new(0,4,1,-12)
		leftBar.Position=UDim2.new(0,8,0,6)
		leftBar.BackgroundColor3=info and row.color or Color3.fromRGB(75,78,100)
		leftBar.BorderSizePixel=0
		corner(leftBar,6)

		local name=makeText(card,row.label,12,Enum.Font.GothamBlack,active and Color3.fromRGB(255,240,190) or Color3.fromRGB(230,234,255))
		name.Size=UDim2.new(1,-62,0,18)
		name.Position=UDim2.new(0,20,0,4)

		local meta=makeText(card,"req "..tostring(row.req),10,Enum.Font.GothamBold,Color3.fromRGB(145,153,185))
		meta.Size=UDim2.new(1,-72,0,18)
		meta.Position=UDim2.new(0,20,0,22)

		local ok=makeText(card,info and "найден" or "нет",10,Enum.Font.GothamBlack,info and Color3.fromRGB(100,255,160) or Color3.fromRGB(150,150,170))
		ok.Size=UDim2.new(0,46,0,20)
		ok.Position=UDim2.new(1,-54,0,10)
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

	list.CanvasSize=UDim2.new(0,0,0,#ROCKS*47+16)
	updateSelected()
end

local row1=Instance.new("Frame")
row1.Parent=main
row1.Size=UDim2.new(1,-14,0,36)
row1.Position=UDim2.new(0,7,0,288)
row1.BackgroundTransparency=1

local lockBtn=makeBtn(row1,"LOCK",Color3.fromRGB(42,84,160))
lockBtn.Size=UDim2.new(0.5,-5,1,0)
lockBtn.Position=UDim2.new(0,0,0,0)

local hitBtn=makeBtn(row1,"BUG HIT",Color3.fromRGB(30,125,72))
hitBtn.Size=UDim2.new(0.5,-5,1,0)
hitBtn.Position=UDim2.new(0.5,5,0,0)

local row2=Instance.new("Frame")
row2.Parent=main
row2.Size=UDim2.new(1,-14,0,36)
row2.Position=UDim2.new(0,7,0,330)
row2.BackgroundTransparency=1

local unlockBtn=makeBtn(row2,"UNLOCK",Color3.fromRGB(120,70,38))
unlockBtn.Size=UDim2.new(0.5,-5,1,0)
unlockBtn.Position=UDim2.new(0,0,0,0)

local ultraBtn=makeBtn(row2,"ULTRA",Color3.fromRGB(82,58,135))
ultraBtn.Size=UDim2.new(0.5,-5,1,0)
ultraBtn.Position=UDim2.new(0.5,5,0,0)

local row3=Instance.new("Frame")
row3.Parent=main
row3.Size=UDim2.new(1,-14,0,36)
row3.Position=UDim2.new(0,7,0,372)
row3.BackgroundTransparency=1

local antiBtn=makeBtn(row3,"AFK ON",Color3.fromRGB(42,84,145))
antiBtn.Size=UDim2.new(0.5,-5,1,0)
antiBtn.Position=UDim2.new(0,0,0,0)

local stopBtn=makeBtn(row3,"STOP",Color3.fromRGB(122,34,48))
stopBtn.Size=UDim2.new(0.5,-5,1,0)
stopBtn.Position=UDim2.new(0.5,5,0,0)
stopBtn.TextColor3=Color3.fromRGB(255,230,236)

local lastReport=""

lockBtn.Activated:Connect(function()
	local ok,res=tpInsideRock(selected)
	if ok then
		setStatus("LOCK: "..selected.label)
		lastReport="TP LOCK OK\nRock: "..selected.label.."\nReq: "..selected.req.."\nModel: "..tostring(res.name)
	else
		setStatus("LOCK error: "..tostring(res))
		lastReport="TP LOCK ERROR\nRock: "..selected.label.."\nReq: "..selected.req.."\nError: "..tostring(res)
	end
end)

hitBtn.Activated:Connect(function()
	if hitting then
		stopHit(setStatus)
		hitBtn.Text="BUG HIT"
		hitBtn.BackgroundColor3=Color3.fromRGB(30,125,72)
	else
		local ok,msg=tpInsideRock(selected)
		if not ok then
			setStatus("BUG error: "..tostring(msg))
			return
		end
		startHit(selected,setStatus)
		hitBtn.Text="HITTING"
		hitBtn.BackgroundColor3=Color3.fromRGB(28,150,82)
	end
end)

unlockBtn.Activated:Connect(function()
	stopLock()
	setStatus("UNLOCK: отпущено")
end)

ultraBtn.Activated:Connect(function()
	ultraOptEnabled=not ultraOptEnabled
	ultraBtn.Text=ultraOptEnabled and "ULTRA ON" or "ULTRA"
	ultraBtn.BackgroundColor3=ultraOptEnabled and Color3.fromRGB(118,65,160) or Color3.fromRGB(82,58,135)

	if ultraOptEnabled then
		local old=_G.RockBugLowMapTransparency
		_G.RockBugLowMapTransparency=1
		local info=getRock(selected)
		setLowMap(true,info and info.model,setStatus)
		_G.RockBugLowMapTransparency=old
	else
		setLowMap(false,nil,setStatus)
	end
end)

antiBtn.Activated:Connect(function()
	antiAfkEnabled=not antiAfkEnabled
	antiBtn.Text=antiAfkEnabled and "AFK ON" or "AFK OFF"
	antiBtn.BackgroundColor3=antiAfkEnabled and Color3.fromRGB(42,84,145) or Color3.fromRGB(105,42,48)
	setStatus("AFK "..(antiAfkEnabled and "ON" or "OFF"))
end)

stopBtn.Activated:Connect(function()
	stopHit()
	stopLock()
	ultraOptEnabled=false
	ultraBtn.Text="ULTRA"
	ultraBtn.BackgroundColor3=Color3.fromRGB(82,58,135)
	setLowMap(false,nil,nil)
	setStatus("Остановлено")
	hitBtn.Text="BUG HIT"
	hitBtn.BackgroundColor3=Color3.fromRGB(30,125,72)
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
	stopHit()
	stopLock()
	setLowMap(false,nil,nil)
	if antiAfkConn then antiAfkConn:Disconnect() antiAfkConn=nil end
	gui:Destroy()
end)

-- drag только за верх
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

-- Auto scan без отдельной кнопки
local found=scanRocks()
refreshButtons()
local count=0
for _,row in ipairs(ROCKS)do
	if found[row.req]then count+=1 end
end
setStatus("Готово • "..count.."/"..#ROCKS.." • "..HUB_VERSION)
end

-- UI v13.2: separate ROCK / AUTO KILL / CRYSTALS tabs and scrollable neon pickers.
local UserInputService=game:GetService("UserInputService")
local ACCENT=Color3.fromRGB(155,92,255)
local ACCENT2=Color3.fromRGB(94,64,220)
local BG=Color3.fromRGB(7,8,16)
local PANEL=Color3.fromRGB(15,17,31)
local CARD=Color3.fromRGB(23,26,46)
local TEXT=Color3.fromRGB(239,241,255)
local MUTED=Color3.fromRGB(157,163,195)
local GOOD=Color3.fromRGB(84,224,168)
local BAD=Color3.fromRGB(242,83,112)

local gui=Instance.new("ScreenGui")
gui.Name="RockBugHub_v13_1_UltraSmallUI"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=999999
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=lp:WaitForChild("PlayerGui")

local function uiCorner(object,radius)
	local c=Instance.new("UICorner")
	c.CornerRadius=UDim.new(0,radius or 12)
	c.Parent=object
	return c
end

local function uiStroke(object,color,thickness,transparency)
	local s=Instance.new("UIStroke")
	s.Color=color or ACCENT
	s.Thickness=thickness or 1
	s.Transparency=transparency or 0
	s.Parent=object
	return s
end

local function uiText(parent,value,size,font,color)
	local label=Instance.new("TextLabel")
	label.Parent=parent
	label.BackgroundTransparency=1
	label.BorderSizePixel=0
	label.Text=tostring(value or "")
	label.TextColor3=color or TEXT
	label.Font=font or Enum.Font.GothamBold
	label.TextSize=size or 12
	label.TextXAlignment=Enum.TextXAlignment.Left
	label.TextYAlignment=Enum.TextYAlignment.Center
	label.TextWrapped=true
	return label
end

local function uiButton(parent,value,color)
	local button=Instance.new("TextButton")
	button.Parent=parent
	button.AutoButtonColor=true
	button.BackgroundColor3=color or CARD
	button.BackgroundTransparency=0.04
	button.BorderSizePixel=0
	button.Text=tostring(value or "")
	button.TextColor3=TEXT
	button.Font=Enum.Font.GothamBlack
	button.TextSize=11
	uiCorner(button,12)
	uiStroke(button,ACCENT,1,0.66)
	return button
end

local function uiCard(parent)
	local card=Instance.new("Frame")
	card.Parent=parent
	card.BackgroundColor3=CARD
	card.BackgroundTransparency=0.08
	card.BorderSizePixel=0
	uiCorner(card,14)
	uiStroke(card,ACCENT,1,0.62)
	return card
end

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,346,0,468)
main.Position=UDim2.new(0,12,0,72)
main.BackgroundColor3=BG
main.BackgroundTransparency=0.06
main.BorderSizePixel=0
main.Active=true
uiCorner(main,20)
uiStroke(main,ACCENT,1.5,0.18)

local mainGradient=Instance.new("UIGradient")
mainGradient.Color=ColorSequence.new({
	ColorSequenceKeypoint.new(0,Color3.fromRGB(14,12,28)),
	ColorSequenceKeypoint.new(0.55,Color3.fromRGB(7,8,16)),
	ColorSequenceKeypoint.new(1,Color3.fromRGB(17,10,29)),
})
mainGradient.Rotation=120
mainGradient.Parent=main

local top=uiCard(main)
top.Size=UDim2.new(1,-14,0,45)
top.Position=UDim2.new(0,7,0,7)
top.Active=true

local logo=uiText(top,"RB",15,Enum.Font.GothamBlack,Color3.fromRGB(221,205,255))
logo.Size=UDim2.new(0,34,0,31)
logo.Position=UDim2.new(0,7,0,7)
logo.BackgroundColor3=Color3.fromRGB(50,35,91)
logo.BackgroundTransparency=0.04
logo.TextXAlignment=Enum.TextXAlignment.Center
uiCorner(logo,10)
uiStroke(logo,ACCENT,1.2,0.18)

local title=uiText(top,"ROCK BUG HUB",15,Enum.Font.GothamBlack,TEXT)
title.Size=UDim2.new(1,-126,0,20)
title.Position=UDim2.new(0,48,0,4)

local subtitle=uiText(top,"v13.1 • KILL + CRYSTALS",9,Enum.Font.GothamBold,MUTED)
subtitle.Size=UDim2.new(1,-126,0,15)
subtitle.Position=UDim2.new(0,48,0,23)

local minButton=uiButton(top,"-",Color3.fromRGB(42,37,74))
minButton.Size=UDim2.new(0,29,0,29)
minButton.Position=UDim2.new(1,-65,0,8)
minButton.TextSize=17

local closeButton=uiButton(top,"X",Color3.fromRGB(82,29,48))
closeButton.Size=UDim2.new(0,29,0,29)
closeButton.Position=UDim2.new(1,-32,0,8)
closeButton.TextColor3=Color3.fromRGB(255,207,220)

local mini=uiButton(gui,"RB",Color3.fromRGB(45,31,88))
mini.Size=UDim2.new(0,43,0,43)
mini.Position=main.Position
mini.Visible=false
mini.TextSize=13
uiStroke(mini,ACCENT,1.5,0.12)

local tabBar=Instance.new("Frame")
tabBar.Parent=main
tabBar.Size=UDim2.new(1,-14,0,34)
tabBar.Position=UDim2.new(0,7,0,59)
tabBar.BackgroundTransparency=1

local tabButtons={}
local pages={}
local function createTab(id,label,index)
	local button=uiButton(tabBar,label,Color3.fromRGB(22,23,42))
	button.Size=UDim2.new(1/3,-4,1,0)
	button.Position=UDim2.new((index-1)/3,(index-1)*2,0,0)
	button.TextSize=10
	button.Name="Tab_"..id
	tabButtons[id]=button

	local page=Instance.new("Frame")
	page.Parent=main
	page.Name="Page_"..id
	page.Size=UDim2.new(1,-14,0,309)
	page.Position=UDim2.new(0,7,0,100)
	page.BackgroundTransparency=1
	page.Visible=false
	pages[id]=page
	return button,page
end

local rockTab,rockPage=createTab("rock","КАМЕНЬ",1)
local killTab,killPage=createTab("kill","АВТОКИЛ",2)
local crystalTab,crystalPage=createTab("crystal","КРИСТАЛЛЫ",3)

local status=uiText(main,"ГОТОВО",10,Enum.Font.GothamBlack,Color3.fromRGB(220,224,255))
status.Size=UDim2.new(1,-14,0,35)
status.Position=UDim2.new(0,7,0,422)
status.BackgroundColor3=Color3.fromRGB(13,14,27)
status.BackgroundTransparency=0.05
status.BorderSizePixel=0
status.TextXAlignment=Enum.TextXAlignment.Center
status.TextTruncate=Enum.TextTruncate.AtEnd
uiCorner(status,12)
uiStroke(status,ACCENT,1,0.63)

local function setStatus(value)
	status.Text=tostring(value or "")
end
killStatusFn=setStatus
crystalStatusFn=setStatus

local activeTab="rock"
local function showTab(id)
	activeTab=id
	for pageId,page in pairs(pages)do page.Visible=pageId==id end
	for tabId,button in pairs(tabButtons)do
		local active=tabId==id
		button.BackgroundColor3=active and Color3.fromRGB(66,43,116)or Color3.fromRGB(22,23,42)
		button.TextColor3=active and Color3.fromRGB(255,244,255)or MUTED
		local s=button:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color=active and Color3.fromRGB(190,125,255)or ACCENT
			s.Transparency=active and 0.05 or 0.72
			s.Thickness=active and 1.4 or 1
		end
	end
end

rockTab.Activated:Connect(function()showTab("rock")end)
killTab.Activated:Connect(function()showTab("kill")end)
crystalTab.Activated:Connect(function()showTab("crystal")end)

-- ROCK page: all original controls stay available.
local rockSelected=uiCard(rockPage)
rockSelected.Size=UDim2.new(1,0,0,43)
rockSelected.Position=UDim2.new(0,0,0,0)

local rockCaption=uiText(rockSelected,"ВЫБРАННЫЙ КАМЕНЬ",8,Enum.Font.GothamBlack,MUTED)
rockCaption.Size=UDim2.new(1,-16,0,13)
rockCaption.Position=UDim2.new(0,9,0,4)

local rockName=uiText(rockSelected,"-",14,Enum.Font.GothamBlack,Color3.fromRGB(246,225,255))
rockName.Size=UDim2.new(1,-16,0,21)
rockName.Position=UDim2.new(0,9,0,17)

local rockList=Instance.new("ScrollingFrame")
rockList.Parent=rockPage
rockList.Size=UDim2.new(1,0,0,143)
rockList.Position=UDim2.new(0,0,0,49)
rockList.BackgroundColor3=Color3.fromRGB(9,10,20)
rockList.BackgroundTransparency=0.08
rockList.BorderSizePixel=0
rockList.ScrollBarThickness=3
rockList.ScrollBarImageColor3=ACCENT
rockList.CanvasSize=UDim2.new(0,0,0,0)
rockList.Active=true
uiCorner(rockList,14)
uiStroke(rockList,ACCENT,1,0.70)

local rockPadding=Instance.new("UIPadding")
rockPadding.Parent=rockList
rockPadding.PaddingTop=UDim.new(0,6)
rockPadding.PaddingBottom=UDim.new(0,6)
rockPadding.PaddingLeft=UDim.new(0,6)
rockPadding.PaddingRight=UDim.new(0,6)

local rockLayout=Instance.new("UIListLayout")
rockLayout.Parent=rockList
rockLayout.SortOrder=Enum.SortOrder.LayoutOrder
rockLayout.Padding=UDim.new(0,5)

local rockButtons={}
local function updateRockSelected()
	rockName.Text=selected and(selected.label.."  •  "..tostring(selected.req))or "-"
end

local function refreshRockButtons()
	for _,button in ipairs(rockButtons)do if button.Parent then button:Destroy()end end
	rockButtons={}
	for index,row in ipairs(ROCKS)do
		local found=rockCache[row.req]~=nil
		local active=selected and selected.id==row.id
		local button=uiButton(rockList,"",active and Color3.fromRGB(57,38,105)or Color3.fromRGB(19,21,38))
		button.Name="Rock_"..row.id
		button.Size=UDim2.new(1,-2,0,35)
		button.LayoutOrder=index
		local s=button:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color=active and Color3.fromRGB(204,139,255)or Color3.fromRGB(79,61,125)
			s.Transparency=active and 0.05 or 0.66
		end

		local marker=Instance.new("Frame")
		marker.Parent=button
		marker.Size=UDim2.new(0,3,1,-10)
		marker.Position=UDim2.new(0,7,0,5)
		marker.BackgroundColor3=found and row.color or Color3.fromRGB(89,91,112)
		marker.BorderSizePixel=0
		uiCorner(marker,4)

		local name=uiText(button,row.label,11,Enum.Font.GothamBlack,active and Color3.fromRGB(255,235,255)or TEXT)
		name.Size=UDim2.new(1,-95,1,0)
		name.Position=UDim2.new(0,17,0,0)

		local req=uiText(button,tostring(row.req),9,Enum.Font.GothamBold,found and GOOD or MUTED)
		req.Size=UDim2.new(0,72,1,0)
		req.Position=UDim2.new(1,-78,0,0)
		req.TextXAlignment=Enum.TextXAlignment.Right

		button.Activated:Connect(function()
			selected=row
			updateRockSelected()
			refreshRockButtons()
			if ultraOptEnabled then
				setLowMap(false,nil,nil)
				local old=_G.RockBugLowMapTransparency
				_G.RockBugLowMapTransparency=1
				local info=getRock(selected)
				setLowMap(true,info and info.model,nil)
				_G.RockBugLowMapTransparency=old
			end
			setStatus("КАМЕНЬ: "..row.label)
		end)
		table.insert(rockButtons,button)
	end
	rockList.CanvasSize=UDim2.new(0,0,0,#ROCKS*40+12)
	updateRockSelected()
end

local rockRow1=Instance.new("Frame")
rockRow1.Parent=rockPage
rockRow1.Size=UDim2.new(1,0,0,34)
rockRow1.Position=UDim2.new(0,0,0,199)
rockRow1.BackgroundTransparency=1

local lockButton=uiButton(rockRow1,"LOCK",Color3.fromRGB(42,72,143))
lockButton.Size=UDim2.new(0.5,-4,1,0)
local hitButton=uiButton(rockRow1,"BUG HIT",Color3.fromRGB(31,117,77))
hitButton.Size=UDim2.new(0.5,-4,1,0)
hitButton.Position=UDim2.new(0.5,4,0,0)

local rockRow2=Instance.new("Frame")
rockRow2.Parent=rockPage
rockRow2.Size=UDim2.new(1,0,0,34)
rockRow2.Position=UDim2.new(0,0,0,237)
rockRow2.BackgroundTransparency=1

local unlockButton=uiButton(rockRow2,"UNLOCK",Color3.fromRGB(113,67,38))
unlockButton.Size=UDim2.new(0.5,-4,1,0)
local ultraButton=uiButton(rockRow2,"ULTRA",Color3.fromRGB(76,48,130))
ultraButton.Size=UDim2.new(0.5,-4,1,0)
ultraButton.Position=UDim2.new(0.5,4,0,0)

local rockRow3=Instance.new("Frame")
rockRow3.Parent=rockPage
rockRow3.Size=UDim2.new(1,0,0,34)
rockRow3.Position=UDim2.new(0,0,0,275)
rockRow3.BackgroundTransparency=1

local antiButton=uiButton(rockRow3,"ANTI-AFK ON",Color3.fromRGB(42,70,135))
antiButton.Size=UDim2.new(0.5,-4,1,0)
local stopButton=uiButton(rockRow3,"STOP ALL",Color3.fromRGB(126,37,58))
stopButton.Size=UDim2.new(0.5,-4,1,0)
stopButton.Position=UDim2.new(0.5,4,0,0)

lockButton.Activated:Connect(function()
	local ok,result=tpInsideRock(selected)
	setStatus(ok and("LOCK: "..selected.label)or("LOCK ERROR: "..tostring(result)))
end)

hitButton.Activated:Connect(function()
	if hitting then
		stopHit(setStatus)
		hitButton.Text="BUG HIT"
		hitButton.BackgroundColor3=Color3.fromRGB(31,117,77)
		return
	end
	local ok,message=tpInsideRock(selected)
	if not ok then setStatus("BUG ERROR: "..tostring(message))return end
	startHit(selected,setStatus)
	hitButton.Text="HITTING"
	hitButton.BackgroundColor3=Color3.fromRGB(34,153,92)
end)

unlockButton.Activated:Connect(function()
	stopLock()
	setStatus("UNLOCK: свободно")
end)

ultraButton.Activated:Connect(function()
	ultraOptEnabled=not ultraOptEnabled
	ultraButton.Text=ultraOptEnabled and "ULTRA ON"or "ULTRA"
	ultraButton.BackgroundColor3=ultraOptEnabled and Color3.fromRGB(122,62,174)or Color3.fromRGB(76,48,130)
	if ultraOptEnabled then
		local old=_G.RockBugLowMapTransparency
		_G.RockBugLowMapTransparency=1
		local info=getRock(selected)
		setLowMap(true,info and info.model,setStatus)
		_G.RockBugLowMapTransparency=old
	else
		setLowMap(false,nil,setStatus)
	end
end)

antiButton.Activated:Connect(function()
	antiAfkEnabled=not antiAfkEnabled
	antiButton.Text=antiAfkEnabled and "ANTI-AFK ON"or "ANTI-AFK OFF"
	antiButton.BackgroundColor3=antiAfkEnabled and Color3.fromRGB(42,70,135)or Color3.fromRGB(102,40,50)
	setStatus("ANTI-AFK: "..(antiAfkEnabled and "ON"or "OFF"))
end)

-- AUTO KILL page.
local killHeader=uiCard(killPage)
killHeader.Size=UDim2.new(1,0,0,39)
local killTitle=uiText(killHeader,"ТРИ РЕЖИМА АВТОКИЛА",12,Enum.Font.GothamBlack,Color3.fromRGB(239,225,255))
killTitle.Size=UDim2.new(1,-16,1,0)
killTitle.Position=UDim2.new(0,9,0,0)

local killModes=Instance.new("Frame")
killModes.Parent=killPage
killModes.Size=UDim2.new(1,0,0,48)
killModes.Position=UDim2.new(0,0,0,46)
killModes.BackgroundTransparency=1

local killAllButton=uiButton(killModes,"ВСЕ",Color3.fromRGB(34,42,70))
killAllButton.Size=UDim2.new(1/3,-4,1,0)
local killWhiteButton=uiButton(killModes,"КРОМЕ БЕЛЫХ",Color3.fromRGB(34,42,70))
killWhiteButton.Size=UDim2.new(1/3,-4,1,0)
killWhiteButton.Position=UDim2.new(1/3,2,0,0)
killWhiteButton.TextSize=9
local killBlackButton=uiButton(killModes,"ТОЛЬКО ЦЕЛИ",Color3.fromRGB(34,42,70))
killBlackButton.Size=UDim2.new(1/3,-4,1,0)
killBlackButton.Position=UDim2.new(2/3,4,0,0)
killBlackButton.TextSize=9

local whiteCard=uiCard(killPage)
whiteCard.Size=UDim2.new(1,0,0,78)
whiteCard.Position=UDim2.new(0,0,0,102)
local whiteTitle=uiText(whiteCard,"БЕЛЫЙ СПИСОК",11,Enum.Font.GothamBlack,TEXT)
whiteTitle.Size=UDim2.new(1,-18,0,24)
whiteTitle.Position=UDim2.new(0,9,0,5)
local whiteInfo=uiText(whiteCard,"Выбранные игроки не атакуются",9,Enum.Font.GothamBold,MUTED)
whiteInfo.Size=UDim2.new(1,-18,0,16)
whiteInfo.Position=UDim2.new(0,9,0,26)
local whitePickerButton=uiButton(whiteCard,"ВЫБРАТЬ ИГРОКОВ • 0",Color3.fromRGB(46,38,82))
whitePickerButton.Size=UDim2.new(1,-18,0,27)
whitePickerButton.Position=UDim2.new(0,9,0,45)

local blackCard=uiCard(killPage)
blackCard.Size=UDim2.new(1,0,0,78)
blackCard.Position=UDim2.new(0,0,0,187)
local blackTitle=uiText(blackCard,"ЧЁРНЫЙ СПИСОК / ЦЕЛИ",11,Enum.Font.GothamBlack,TEXT)
blackTitle.Size=UDim2.new(1,-18,0,24)
blackTitle.Position=UDim2.new(0,9,0,5)
local blackInfo=uiText(blackCard,"Атакуются только выбранные игроки",9,Enum.Font.GothamBold,MUTED)
blackInfo.Size=UDim2.new(1,-18,0,16)
blackInfo.Position=UDim2.new(0,9,0,26)
local blackPickerButton=uiButton(blackCard,"ВЫБРАТЬ ЦЕЛИ • 0",Color3.fromRGB(46,38,82))
blackPickerButton.Size=UDim2.new(1,-18,0,27)
blackPickerButton.Position=UDim2.new(0,9,0,45)

local killHint=uiText(killPage,"Повторное нажатие активного режима выключает автокил.",9,Enum.Font.GothamBold,MUTED)
killHint.Size=UDim2.new(1,0,0,35)
killHint.Position=UDim2.new(0,0,0,273)
killHint.TextXAlignment=Enum.TextXAlignment.Center

killRefreshFn=function()
	whitePickerButton.Text="ВЫБРАТЬ ИГРОКОВ • "..tableCount(killWhitelist)
	blackPickerButton.Text="ВЫБРАТЬ ЦЕЛИ • "..tableCount(killBlacklist)
	local mapping={all=killAllButton,whitelist=killWhiteButton,blacklist=killBlackButton}
	for mode,button in pairs(mapping)do
		local active=killMode==mode
		button.BackgroundColor3=active and Color3.fromRGB(108,54,169)or Color3.fromRGB(34,42,70)
		local s=button:FindFirstChildOfClass("UIStroke")
		if s then s.Transparency=active and 0.05 or 0.66 end
	end
end

local function toggleKillMode(mode)
	setKillMode(killMode==mode and "off"or mode)
end
killAllButton.Activated:Connect(function()toggleKillMode("all")end)
killWhiteButton.Activated:Connect(function()toggleKillMode("whitelist")end)
killBlackButton.Activated:Connect(function()toggleKillMode("blacklist")end)

-- CRYSTALS page.
local crystalHeader=uiCard(crystalPage)
crystalHeader.Size=UDim2.new(1,0,0,39)
local crystalTitle=uiText(crystalHeader,"АВТОПОКУПКА ИЗ ЛЮБОЙ ТОЧКИ",11,Enum.Font.GothamBlack,Color3.fromRGB(239,225,255))
crystalTitle.Size=UDim2.new(1,-16,1,0)
crystalTitle.Position=UDim2.new(0,9,0,0)

local function createCrystalRow(y,label)
	local card=uiCard(crystalPage)
	card.Size=UDim2.new(1,0,0,75)
	card.Position=UDim2.new(0,0,0,y)
	local caption=uiText(card,label,10,Enum.Font.GothamBlack,MUTED)
	caption.Size=UDim2.new(1,-18,0,18)
	caption.Position=UDim2.new(0,9,0,4)
	local pick=uiButton(card,"ВЫБРАТЬ",Color3.fromRGB(44,36,79))
	pick.Size=UDim2.new(1,-92,0,39)
	pick.Position=UDim2.new(0,8,0,28)
	pick.TextXAlignment=Enum.TextXAlignment.Left
	pick.TextTruncate=Enum.TextTruncate.AtEnd
	local pad=Instance.new("UIPadding")
	pad.Parent=pick
	pad.PaddingLeft=UDim.new(0,10)
	local toggle=uiButton(card,"СТАРТ",Color3.fromRGB(38,105,78))
	toggle.Size=UDim2.new(0,76,0,39)
	toggle.Position=UDim2.new(1,-84,0,28)
	return pick,toggle
end

local crystalPickerButton,crystalToggle=createCrystalRow(46,"КРИСТАЛЛ")
local petPickerButton,petToggle=createCrystalRow(128,"ПИТОМЕЦ — ОТКРЫВАТЬ ДО ПОЛУЧЕНИЯ")
local auraPickerButton,auraToggle=createCrystalRow(210,"АУРА — ОТКРЫВАТЬ ДО ПОЛУЧЕНИЯ")

local crystalHint=uiText(crystalPage,"Одновременно работает только один режим.",9,Enum.Font.GothamBold,MUTED)
crystalHint.Size=UDim2.new(1,0,0,20)
crystalHint.Position=UDim2.new(0,0,0,289)
crystalHint.TextXAlignment=Enum.TextXAlignment.Center

crystalRefreshFn=function()
	crystalPickerButton.Text=tostring(selectedCrystal or "ВЫБРАТЬ КРИСТАЛЛ")
	petPickerButton.Text=selectedPet and(selectedPet.name.."  •  "..selectedPet.crystal)or "ВЫБРАТЬ ПИТОМЦА"
	auraPickerButton.Text=selectedAura and(selectedAura.name.."  •  "..selectedAura.crystal)or "ВЫБРАТЬ АУРУ"
	local mapping={crystal=crystalToggle,pet=petToggle,aura=auraToggle}
	for mode,button in pairs(mapping)do
		local active=crystalMode==mode
		button.Text=active and "СТОП"or "СТАРТ"
		button.BackgroundColor3=active and Color3.fromRGB(137,42,67)or Color3.fromRGB(38,105,78)
	end
end

crystalToggle.Activated:Connect(function()setCrystalMode(crystalMode=="crystal"and "off"or "crystal")end)
petToggle.Activated:Connect(function()setCrystalMode(crystalMode=="pet"and "off"or "pet")end)
auraToggle.Activated:Connect(function()setCrystalMode(crystalMode=="aura"and "off"or "aura")end)

-- Shared scrollable neon picker used by player, crystal, pet and aura selections.
local pickerShade=Instance.new("TextButton")
pickerShade.Parent=main
pickerShade.Size=UDim2.new(1,0,1,0)
pickerShade.Position=UDim2.new(0,0,0,0)
pickerShade.BackgroundColor3=Color3.fromRGB(2,2,7)
pickerShade.BackgroundTransparency=0.18
pickerShade.BorderSizePixel=0
pickerShade.Text=""
pickerShade.AutoButtonColor=false
pickerShade.Visible=false
pickerShade.ZIndex=50

local pickerPanel=Instance.new("Frame")
pickerPanel.Parent=pickerShade
pickerPanel.Size=UDim2.new(1,-26,0,402)
pickerPanel.Position=UDim2.new(0,13,0,33)
pickerPanel.BackgroundColor3=Color3.fromRGB(10,10,22)
pickerPanel.BackgroundTransparency=0.01
pickerPanel.BorderSizePixel=0
pickerPanel.ZIndex=51
uiCorner(pickerPanel,18)
uiStroke(pickerPanel,Color3.fromRGB(197,126,255),1.7,0.05)

local pickerGlow=uiStroke(pickerPanel,Color3.fromRGB(104,56,230),4,0.70)
pickerGlow.ApplyStrokeMode=Enum.ApplyStrokeMode.Border

local pickerTitle=uiText(pickerPanel,"ВЫБОР",13,Enum.Font.GothamBlack,TEXT)
pickerTitle.Size=UDim2.new(1,-54,0,37)
pickerTitle.Position=UDim2.new(0,13,0,5)
pickerTitle.ZIndex=52

local pickerClose=uiButton(pickerPanel,"X",Color3.fromRGB(80,30,52))
pickerClose.Size=UDim2.new(0,31,0,31)
pickerClose.Position=UDim2.new(1,-39,0,8)
pickerClose.ZIndex=53

local pickerSearch=Instance.new("TextBox")
pickerSearch.Parent=pickerPanel
pickerSearch.Size=UDim2.new(1,-20,0,34)
pickerSearch.Position=UDim2.new(0,10,0,47)
pickerSearch.BackgroundColor3=Color3.fromRGB(22,23,42)
pickerSearch.BackgroundTransparency=0.03
pickerSearch.BorderSizePixel=0
pickerSearch.ClearTextOnFocus=false
pickerSearch.PlaceholderText="Поиск..."
pickerSearch.PlaceholderColor3=Color3.fromRGB(117,122,151)
pickerSearch.Text=""
pickerSearch.TextColor3=TEXT
pickerSearch.Font=Enum.Font.GothamBold
pickerSearch.TextSize=11
pickerSearch.TextXAlignment=Enum.TextXAlignment.Left
pickerSearch.ZIndex=52
uiCorner(pickerSearch,11)
uiStroke(pickerSearch,ACCENT,1,0.62)
local searchPad=Instance.new("UIPadding")
searchPad.Parent=pickerSearch
searchPad.PaddingLeft=UDim.new(0,11)
searchPad.PaddingRight=UDim.new(0,11)

local pickerList=Instance.new("ScrollingFrame")
pickerList.Parent=pickerPanel
pickerList.Size=UDim2.new(1,-20,0,258)
pickerList.Position=UDim2.new(0,10,0,89)
pickerList.BackgroundColor3=Color3.fromRGB(6,7,15)
pickerList.BackgroundTransparency=0.04
pickerList.BorderSizePixel=0
pickerList.ScrollBarThickness=4
pickerList.ScrollBarImageColor3=Color3.fromRGB(179,111,255)
pickerList.CanvasSize=UDim2.new(0,0,0,0)
pickerList.Active=true
pickerList.ZIndex=52
uiCorner(pickerList,12)
uiStroke(pickerList,ACCENT,1,0.72)

local pickerPadding=Instance.new("UIPadding")
pickerPadding.Parent=pickerList
pickerPadding.PaddingTop=UDim.new(0,7)
pickerPadding.PaddingBottom=UDim.new(0,7)
pickerPadding.PaddingLeft=UDim.new(0,7)
pickerPadding.PaddingRight=UDim.new(0,7)

local pickerLayout=Instance.new("UIListLayout")
pickerLayout.Parent=pickerList
pickerLayout.SortOrder=Enum.SortOrder.LayoutOrder
pickerLayout.Padding=UDim.new(0,6)

local pickerDone=uiButton(pickerPanel,"ГОТОВО",Color3.fromRGB(73,45,126))
pickerDone.Size=UDim2.new(1,-20,0,37)
pickerDone.Position=UDim2.new(0,10,0,355)
pickerDone.ZIndex=53

local pickerState=nil
local pickerItems={}

local function closePicker()
	pickerState=nil
	pickerShade.Visible=false
	pickerSearch.Text=""
end

local function renderPicker(resetScroll)
	local oldCanvas=pickerList.CanvasPosition
	for _,button in ipairs(pickerItems)do if button.Parent then button:Destroy()end end
	pickerItems={}
	if not pickerState then return end
	local query=string.lower(pickerSearch.Text or "")
	local visibleCount=0
	for _,option in ipairs(pickerState.options)do
		local id=tostring(option.id or option.label)
		local hay=string.lower(tostring(option.label or "").." "..tostring(option.sub or ""))
		if query==""or string.find(hay,query,1,true)then
			visibleCount+=1
			local selectedNow=pickerState.selected[id]==true
			local item=uiButton(pickerList,"",selectedNow and Color3.fromRGB(68,42,116)or Color3.fromRGB(19,21,38))
			item.Size=UDim2.new(1,-2,0,48)
			item.LayoutOrder=visibleCount
			item.ZIndex=53
			local itemStroke=item:FindFirstChildOfClass("UIStroke")
			if itemStroke then
				itemStroke.Color=selectedNow and Color3.fromRGB(214,151,255)or ACCENT
				itemStroke.Transparency=selectedNow and 0.04 or 0.72
				itemStroke.Thickness=selectedNow and 1.4 or 1
			end

			local itemName=uiText(item,option.label,11,Enum.Font.GothamBlack,TEXT)
			itemName.Size=UDim2.new(1,-50,0,21)
			itemName.Position=UDim2.new(0,11,0,4)
			itemName.ZIndex=54
			local itemSub=uiText(item,option.sub or "",9,Enum.Font.GothamBold,MUTED)
			itemSub.Size=UDim2.new(1,-50,0,17)
			itemSub.Position=UDim2.new(0,11,0,25)
			itemSub.ZIndex=54
			local check=uiText(item,selectedNow and "ON"or ">",10,Enum.Font.GothamBlack,selectedNow and Color3.fromRGB(230,188,255)or MUTED)
			check.Size=UDim2.new(0,32,1,0)
			check.Position=UDim2.new(1,-40,0,0)
			check.TextXAlignment=Enum.TextXAlignment.Center
			check.ZIndex=54

			item.Activated:Connect(function()
				if not pickerState then return end
				if pickerState.multiple then
					pickerState.selected[id]=not pickerState.selected[id]
					renderPicker(false)
				else
					local callback=pickerState.onDone
					closePicker()
					if callback then callback(option)end
				end
			end)
			table.insert(pickerItems,item)
		end
	end
	pickerList.CanvasSize=UDim2.new(0,0,0,visibleCount*54+14)
	if resetScroll then
		pickerList.CanvasPosition=Vector2.new(0,0)
	else
		task.defer(function()
			if pickerList.Parent then pickerList.CanvasPosition=oldCanvas end
		end)
	end
	if pickerState.multiple then
		pickerDone.Text="ГОТОВО • "..tableCount(pickerState.selected)
	else
		pickerDone.Text="ЗАКРЫТЬ"
	end
end

local function openPicker(titleText,options,config)
	config=config or {}
	local draft={}
	for key,value in pairs(config.selected or {})do if value then draft[tostring(key)]=true end end
	pickerState={
		options=options or {},
		multiple=config.multiple==true,
		selected=draft,
		onDone=config.onDone,
	}
	pickerTitle.Text=titleText
	pickerSearch.Text=""
	pickerShade.Visible=true
	renderPicker(true)
end

pickerClose.Activated:Connect(closePicker)
pickerDone.Activated:Connect(function()
	if not pickerState then return end
	local state=pickerState
	if state.multiple and state.onDone then state.onDone(state.selected)end
	closePicker()
end)
pickerSearch:GetPropertyChangedSignal("Text"):Connect(function()
	if pickerState then renderPicker(true)end
end)

local function currentPlayerOptions()
	local options={}
	for _,player in ipairs(Players:GetPlayers())do
		if player~=lp then
			table.insert(options,{
				id=tostring(player.UserId),
				label=player.DisplayName,
				sub="@"..player.Name.."  •  ID "..tostring(player.UserId),
			})
		end
	end
	table.sort(options,function(a,b)return string.lower(a.label)<string.lower(b.label)end)
	return options
end

whitePickerButton.Activated:Connect(function()
	openPicker("БЕЛЫЙ СПИСОК",currentPlayerOptions(),{
		multiple=true,
		selected=killWhitelist,
		onDone=function(draft)
			killWhitelist={}
			for id,value in pairs(draft)do if value then killWhitelist[tonumber(id)or id]=true end end
			killRefreshFn()
			setStatus("БЕЛЫЙ СПИСОК: "..tableCount(killWhitelist))
		end,
	})
end)

blackPickerButton.Activated:Connect(function()
	openPicker("ЦЕЛИ АВТОКИЛА",currentPlayerOptions(),{
		multiple=true,
		selected=killBlacklist,
		onDone=function(draft)
			killBlacklist={}
			for id,value in pairs(draft)do if value then killBlacklist[tonumber(id)or id]=true end end
			killRefreshFn()
			setStatus("ЦЕЛЕЙ: "..tableCount(killBlacklist))
		end,
	})
end)

crystalPickerButton.Activated:Connect(function()
	local options={}
	for _,name in ipairs(getAvailableCrystalNames())do
		table.insert(options,{id=name,label=name,sub="Доступен на текущей карте"})
	end
	openPicker("ВЫБОР КРИСТАЛЛА",options,{
		selected={[selectedCrystal]=true},
		onDone=function(option)
			selectedCrystal=option.label
			crystalRefreshFn()
			setStatus("КРИСТАЛЛ: "..selectedCrystal)
		end,
	})
end)

petPickerButton.Activated:Connect(function()
	local options={}
	for index,target in ipairs(PET_TARGETS)do
		table.insert(options,{id=tostring(index),label=target.name,sub="Кристалл: "..target.crystal,target=target})
	end
	openPicker("ВЫБОР ПИТОМЦА",options,{
		selected=selectedPet and {[tostring(table.find(PET_TARGETS,selectedPet)or 0)]=true}or {},
		onDone=function(option)
			selectedPet=option.target
			crystalRefreshFn()
			setStatus("ПИТОМЕЦ: "..selectedPet.name)
		end,
	})
end)

auraPickerButton.Activated:Connect(function()
	local options={}
	for index,target in ipairs(AURA_TARGETS)do
		table.insert(options,{id=tostring(index),label=target.name,sub="Кристалл: "..target.crystal,target=target})
	end
	openPicker("ВЫБОР АУРЫ",options,{
		selected=selectedAura and {[tostring(table.find(AURA_TARGETS,selectedAura)or 0)]=true}or {},
		onDone=function(option)
			selectedAura=option.target
			crystalRefreshFn()
			setStatus("АУРА: "..selectedAura.name)
		end,
	})
end)

local function stopEverything()
	stopHit()
	stopLock()
	ultraOptEnabled=false
	setLowMap(false,nil,nil)
	setKillMode("off")
	setCrystalMode("off")
	hitButton.Text="BUG HIT"
	hitButton.BackgroundColor3=Color3.fromRGB(31,117,77)
	ultraButton.Text="ULTRA"
	ultraButton.BackgroundColor3=Color3.fromRGB(76,48,130)
	setStatus("ВСЁ ОСТАНОВЛЕНО")
end

stopButton.Activated:Connect(stopEverything)

local miniMoved=false

minButton.Activated:Connect(function()
	closePicker()
	main.Visible=false
	mini.Position=main.Position
	mini.Visible=true
end)
mini.Activated:Connect(function()
	if miniMoved then return end
	main.Visible=true
	mini.Visible=false
end)

closeButton.Activated:Connect(function()
	stopHit()
	stopLock()
	setLowMap(false,nil,nil)
	setKillMode("off")
	setCrystalMode("off")
	if antiAfkConn then antiAfkConn:Disconnect()antiAfkConn=nil end
	gui:Destroy()
end)

-- Drag full window by its header.
local dragging=false
local dragStart=nil
local startPosition=nil
top.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=true
		dragStart=input.Position
		startPosition=main.Position
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and(input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then
		local delta=input.Position-dragStart
		main.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
	end
end)

-- The minimized square is independently draggable on touch and mouse.
local miniDragging=false
local miniDragStart=nil
local miniStart=nil
miniMoved=false
mini.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		miniDragging=true
		miniMoved=false
		miniDragStart=input.Position
		miniStart=mini.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if miniDragging and(input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then
		local delta=input.Position-miniDragStart
		if delta.Magnitude>5 then miniMoved=true end
		mini.Position=UDim2.new(miniStart.X.Scale,miniStart.X.Offset+delta.X,miniStart.Y.Scale,miniStart.Y.Offset+delta.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if miniDragging and(input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch)then
		miniDragging=false
		if miniMoved then main.Position=mini.Position end
	end
end)

local found=scanRocks()
refreshRockButtons()
killRefreshFn()
crystalRefreshFn()
showTab("rock")
local foundCount=0
for _,row in ipairs(ROCKS)do if found[row.req]then foundCount+=1 end end
setStatus("ГОТОВО • КАМНИ "..foundCount.."/"..#ROCKS.." • "..HUB_VERSION)
