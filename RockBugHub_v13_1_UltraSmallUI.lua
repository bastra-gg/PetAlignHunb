-- Muscle Legends RockBug Hub v22 FAST SPAM
-- Standalone: без Speed Hub. Камни через neededDurability + TP LOCK + BUG HIT + Anti AFK.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local VirtualUser=game:GetService("VirtualUser")
local lp=Players.LocalPlayer
local HUB_VERSION="RockBugHub_v22_FastSpam"

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
	local old=lp:WaitForChild("PlayerGui"):FindFirstChild("RockBugHub_v22_FastSpam")
	if old then old:Destroy() end
end)

-- v22: снести ТОЛЬКО старую v20-оболочку.
-- Важно: если v20 был вручную переименован в v21, он уже НЕ определяется как v20.
local function killV20Only()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	for _,name in ipairs({
		"RockBugHub_v20_FastAnimBlack"
	})do
		local old=pg:FindFirstChild(name)
		if old then
			pcall(function()old:Destroy()end)
		end
	end

	-- Сбросить возможный след v20: ускоренные AnimationTrack обратно на 1.
	pcall(function()
		local c=lp.Character
		local h=c and c:FindFirstChildWhichIsA("Humanoid")
		local animator=h and h:FindFirstChildOfClass("Animator")
		if animator then
			for _,tr in ipairs(animator:GetPlayingAnimationTracks())do
				pcall(function()tr:AdjustSpeed(1)end)
			end
		end
	end)
end

pcall(killV20Only)

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
local fastHitPower=1 -- v22 FS: основной буст теперь через spam remote/tool/touch

-- v22 FAST SPAM: только ускорение ударов, остальное поведение v22 оставлено.
-- Если лагает/режет сервером — перед запуском можно поставить overrides:
-- _G.RockBugRemoteDelayOverride=0.035
-- _G.RockBugRemoteLoopsOverride=3
-- _G.RockBugActivateDelayOverride=0.04
-- _G.RockBugActivateBurstsOverride=2
-- _G.RockBugTouchDelayOverride=0.10
-- _G.RockBugHitDelayOverride=0.025
if not _G.RockBugV22NoForceSpeed then
	_G.RockBugRemoteDelay=tonumber(_G.RockBugRemoteDelayOverride) or 0.022
	_G.RockBugRemoteLoops=tonumber(_G.RockBugRemoteLoopsOverride) or 5
	_G.RockBugActivateDelay=tonumber(_G.RockBugActivateDelayOverride) or 0.022
	_G.RockBugActivateBursts=tonumber(_G.RockBugActivateBurstsOverride) or 3
	_G.RockBugTouchDelay=tonumber(_G.RockBugTouchDelayOverride) or 0.065
	_G.RockBugTouchLoops=tonumber(_G.RockBugTouchLoopsOverride) or 2
	_G.RockBugHitDelay=tonumber(_G.RockBugHitDelayOverride) or 0.014
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

-- v21 FIX: безопасный буст скорости анимации.
-- В v20 ошибка была в том, что hum() вызывался ДО объявления функции.
-- Здесь блок стоит после hum(), поэтому не должен крашить цикл.
_G.RockBugAnimSpeed=tonumber(_G.RockBugAnimSpeedOverride) or 3.1
_G.RockBugAnimBoostAll=(_G.RockBugAnimBoostAll==true)

local animSpeedConn=nil
local lastAnimBoost=0

local function animTrackInfo(tr)
	local info=""
	pcall(function()
		info=tostring(tr.Name).." "..tostring(tr.Animation and tr.Animation.Name or "").." "..tostring(tr.Animation and tr.Animation.AnimationId or "")
	end)
	return info:lower()
end

local function isSafeToBoostTrack(tr)
	if not tr then return false end
	if _G.RockBugAnimBoostAll then return true end

	local info=animTrackInfo(tr)
	-- Не трогаем базовое движение, чтобы тело/прыжок не ломались.
	if info:find("walk",1,true) or info:find("run",1,true) or info:find("idle",1,true) or info:find("jump",1,true) or info:find("fall",1,true) or info:find("swim",1,true)then
		return false
	end

	-- Punch-анимации часто имеют только id без нормального имени, поэтому всё кроме движения можно ускорять.
	return true
end

local function boostOneTrack(tr)
	if not isSafeToBoostTrack(tr)then return end
	local speed=math.clamp(tonumber(_G.RockBugAnimSpeed or 2.35) or 2.35,0.5,6)
	pcall(function()
		tr:AdjustSpeed(speed)
	end)
end

local function boostPunchAnimations()
	if not hitting then return end
	local h=hum()
	if not h then return end
	local animator=h:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _,tr in ipairs(animator:GetPlayingAnimationTracks())do
		boostOneTrack(tr)
	end
end

local function startAnimSpeedBoost()
	if animSpeedConn then animSpeedConn:Disconnect() animSpeedConn=nil end

	local h=hum()
	if not h then return end
	local animator=h:FindFirstChildOfClass("Animator")
	if not animator then return end

	animSpeedConn=animator.AnimationPlayed:Connect(function(tr)
		if not hitting then return end
		task.defer(function()
			boostOneTrack(tr)
		end)
	end)

	boostPunchAnimations()
end

local function stopAnimSpeedBoost()
	if animSpeedConn then animSpeedConn:Disconnect() animSpeedConn=nil end

	local h=hum()
	if not h then return end
	local animator=h:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _,tr in ipairs(animator:GetPlayingAnimationTracks())do
		pcall(function()
			tr:AdjustSpeed(1)
		end)
	end
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
	removed=0,
	lighting={},
	settings={},
}

local function getKeepChar()
	return lp.Character
end

local function protectObj(obj,keepModel)
	if not obj then return false end
	local c=getKeepChar()
	if c and (obj==c or obj:IsDescendantOf(c) or c:IsDescendantOf(obj))then return true end
	if keepModel and (obj==keepModel or obj:IsDescendantOf(keepModel) or keepModel:IsDescendantOf(obj))then return true end
	if obj==workspace.CurrentCamera then return true end
	if workspace:FindFirstChildOfClass("Terrain") and obj==workspace:FindFirstChildOfClass("Terrain")then return true end
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

local function safeSet(obj,key,val)
	pcall(function()obj[key]=val end)
end

local function ultraPartOff(obj)
	-- Агрессивная оптимизация, но без поломки функционала:
	-- физику/касания не трогаем, чтобы удар/камень не отваливались.
	lowSave(obj,"LocalTransparencyModifier",obj.LocalTransparencyModifier)
	lowSave(obj,"CastShadow",obj.CastShadow)
	pcall(function()lowSave(obj,"Reflectance",obj.Reflectance)end)

	safeSet(obj,"LocalTransparencyModifier",1)
	safeSet(obj,"CastShadow",false)
	pcall(function()obj.Reflectance=0 end)
end

local function ultraEffectOff(obj)
	if obj:IsA("ParticleEmitter")or obj:IsA("Trail")or obj:IsA("Beam")or obj:IsA("Fire")or obj:IsA("Smoke")or obj:IsA("Sparkles")then
		lowSave(obj,"Enabled",obj.Enabled)
		safeSet(obj,"Enabled",false)
		return true
	end
	if obj:IsA("Decal")or obj:IsA("Texture")then
		lowSave(obj,"Transparency",obj.Transparency)
		safeSet(obj,"Transparency",1)
		return true
	end
	if obj:IsA("PointLight")or obj:IsA("SpotLight")or obj:IsA("SurfaceLight")then
		lowSave(obj,"Enabled",obj.Enabled)
		safeSet(obj,"Enabled",false)
		return true
	end
	if obj:IsA("BillboardGui")or obj:IsA("SurfaceGui")then
		lowSave(obj,"Enabled",obj.Enabled)
		safeSet(obj,"Enabled",false)
		return true
	end
	if obj:IsA("Highlight")then
		lowSave(obj,"Enabled",obj.Enabled)
		safeSet(obj,"Enabled",false)
		return true
	end
	if obj:IsA("Sound")then
		pcall(function()
			lowSave(obj,"Volume",obj.Volume)
			obj.Volume=0
		end)
		return true
	end
	return false
end

local function applyQualityUltra()
	local lighting=game:GetService("Lighting")
	pcall(function()
		lowMapState.lighting.GlobalShadows=lighting.GlobalShadows
		lowMapState.lighting.Brightness=lighting.Brightness
		lowMapState.lighting.FogEnd=lighting.FogEnd
		lowMapState.lighting.FogColor=lighting.FogColor
		lowMapState.lighting.Ambient=lighting.Ambient
		lowMapState.lighting.OutdoorAmbient=lighting.OutdoorAmbient
		lowMapState.lighting.ColorShift_Top=lighting.ColorShift_Top
		lowMapState.lighting.ColorShift_Bottom=lighting.ColorShift_Bottom
		pcall(function()lowMapState.lighting.ExposureCompensation=lighting.ExposureCompensation end)
		lowMapState.lighting.EnvironmentDiffuseScale=lighting.EnvironmentDiffuseScale
		lowMapState.lighting.EnvironmentSpecularScale=lighting.EnvironmentSpecularScale
		lowMapState.lighting.Technology=lighting.Technology

		-- v19 BLACK: не "light", а максимально тёмная сцена.
		lighting.GlobalShadows=false
		lighting.Brightness=0
		lighting.FogEnd=5
		lighting.FogColor=Color3.fromRGB(0,0,0)
		lighting.Ambient=Color3.fromRGB(0,0,0)
		lighting.OutdoorAmbient=Color3.fromRGB(0,0,0)
		lighting.ColorShift_Top=Color3.fromRGB(0,0,0)
		lighting.ColorShift_Bottom=Color3.fromRGB(0,0,0)
		pcall(function()lighting.ExposureCompensation=-10 end)
		lighting.EnvironmentDiffuseScale=0
		lighting.EnvironmentSpecularScale=0
		pcall(function()lighting.Technology=Enum.Technology.Compatibility end)
	end)

	pcall(function()
		local terrain=workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			lowSave(terrain,"Decoration",terrain.Decoration)
			lowSave(terrain,"WaterWaveSize",terrain.WaterWaveSize)
			lowSave(terrain,"WaterWaveSpeed",terrain.WaterWaveSpeed)
			lowSave(terrain,"WaterReflectance",terrain.WaterReflectance)
			lowSave(terrain,"WaterTransparency",terrain.WaterTransparency)
			terrain.Decoration=false
			terrain.WaterWaveSize=0
			terrain.WaterWaveSpeed=0
			terrain.WaterReflectance=0
			terrain.WaterTransparency=1
		end
	end)

	pcall(function()
		local ugs=UserSettings():GetService("UserGameSettings")
		lowMapState.settings.SavedQualityLevel=ugs.SavedQualityLevel
		ugs.SavedQualityLevel=Enum.SavedQualitySetting.QualityLevel1
	end)

	pcall(function()
		local rs=settings().Rendering
		lowMapState.settings.QualityLevel=rs.QualityLevel
		rs.QualityLevel=Enum.QualityLevel.Level01
	end)

	-- Настоящая экономия: отключаем 3D-рендер. ScreenGui остаётся, баг-процесс продолжает идти.
	pcall(function()
		RunService:Set3dRenderingEnabled(false)
		lowMapState.settings.Render3DDisabled=true
	end)
end

local function restoreQualityUltra()
	pcall(function()
		if lowMapState.settings.Render3DDisabled then
			RunService:Set3dRenderingEnabled(true)
		end
	end)

	pcall(function()
		local ugs=UserSettings():GetService("UserGameSettings")
		if lowMapState.settings.SavedQualityLevel~=nil then
			ugs.SavedQualityLevel=lowMapState.settings.SavedQualityLevel
		end
	end)

	pcall(function()
		local rs=settings().Rendering
		if lowMapState.settings.QualityLevel~=nil then
			rs.QualityLevel=lowMapState.settings.QualityLevel
		end
	end)

	local lighting=game:GetService("Lighting")
	pcall(function()
		for k,v in pairs(lowMapState.lighting)do
			lighting[k]=v
		end
	end)
	lowMapState.lighting={}
	lowMapState.settings={}
end

local function setLowMap(enabled,keepModel,statusFn)
	if enabled then
		if lowMapState.on then return end
		lowMapState.on=true
		lowMapState.saved={}
		lowMapState.count=0
		lowMapState.removed=0

		applyQualityUltra()

		-- Удаляем с клиента целые верхние объекты Workspace, если они не нужны процессу.
		for _,obj in ipairs(workspace:GetChildren())do
			if obj~=workspace.CurrentCamera and not protectObj(obj,keepModel)then
				if obj:IsA("Camera") or obj:IsA("Terrain") then
					-- skip
				else
					lowSave(obj,"Parent",obj.Parent)
					pcall(function()
						obj.Parent=nil
						lowMapState.removed+=1
					end)
				end
			end
			if lowMapState.removed%40==0 then task.wait() end
		end

		-- В оставшихся контейнерах гасим всё, кроме персонажа и выбранного камня.
		local n=0
		for _,obj in ipairs(workspace:GetDescendants())do
			if not protectObj(obj,keepModel)then
				if obj:IsA("BasePart")then
					ultraPartOff(obj)
					n+=1
				elseif ultraEffectOff(obj)then
					n+=1
				end
			end
			if n%300==0 then task.wait() end
		end

		for _,obj in ipairs(game:GetService("Lighting"):GetDescendants())do
			if obj:IsA("PostEffect")then
				lowSave(obj,"Enabled",obj.Enabled)
				safeSet(obj,"Enabled",false)
				n+=1
			end
		end

		lowMapState.count=n
		if statusFn then
			statusFn("ULTRA BLACK ON: быстрый режим, процесс сохранён")
		end
	else
		if not lowMapState.on then return end
		lowMapState.on=false

		restoreQualityUltra()

		for obj,rec in pairs(lowMapState.saved)do
			if obj then
				-- Parent восстанавливаем первым, чтобы объект вернулся в Workspace.
				if rec.Parent~=nil then
					safeSet(obj,"Parent",rec.Parent)
				end
				for k,v in pairs(rec)do
					if k~="Parent"then
						safeSet(obj,k,v)
					end
				end
			end
		end

		lowMapState.saved={}
		lowMapState.count=0
		lowMapState.removed=0
		if statusFn then statusFn("ULTRA OFF: карта восстановлена")end
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

local cachedPunchRemotes=nil

local function collectPunchRemotes()
	if cachedPunchRemotes then return cachedPunchRemotes end
	cachedPunchRemotes={}

	local function add(ev)
		if ev and ev:IsA("RemoteEvent")then
			for _,old in ipairs(cachedPunchRemotes)do
				if old==ev then return end
			end
			table.insert(cachedPunchRemotes,ev)
		end
	end

	pcall(function()
		if lp:FindFirstChild("muscleEvent")then add(lp.muscleEvent)end
	end)

	pcall(function()
		local rs=game:GetService("ReplicatedStorage")
		local re=rs:FindFirstChild("rEvents")
		if re then add(re:FindFirstChild("muscleEvent"))end
	end)

	pcall(function()
		local rs=game:GetService("ReplicatedStorage")
		for _,d in ipairs(rs:GetDescendants())do
			if d:IsA("RemoteEvent")then
				local n=tostring(d.Name):lower()
				local full=tostring(d:GetFullName()):lower()
				if n=="muscleevent" or n:find("punch",1,true) or (n:find("muscle",1,true) and full:find("event",1,true))then
					add(d)
				end
			end
		end
	end)

	return cachedPunchRemotes
end

local function firePunchRemote()
	local remotes=collectPunchRemotes()

	for _,ev in ipairs(remotes)do
		pcall(function()
			ev:FireServer("punch","rightHand")
			ev:FireServer("punch","leftHand")
			ev:FireServer("punch")
		end)
	end
end

local function firePunchRemoteSpam()
	local loops=math.clamp(tonumber(_G.RockBugRemoteLoops or 5)or 5,1,12)
	for _=1,loops do
		firePunchRemote()
	end
end

local function spamActivateTool(tool)
	if not tool or not tool.Parent then return end

	local bursts=math.clamp(tonumber(_G.RockBugActivateBursts or 3)or 3,1,8)

	for i=1,bursts do
		pcall(function()tool:Activate()end)

		-- task.defer даёт ещё несколько Activate почти в тот же кадр, без wait-лага.
		if i<bursts then
			task.defer(function()
				if tool and tool.Parent then
					pcall(function()tool:Activate()end)
					boostPunchAnimations()
				end
			end)
		end
	end

	boostPunchAnimations()
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
			spamActivateTool(tool)
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

local function spamTouchRock(row)
	local loops=math.clamp(tonumber(_G.RockBugTouchLoops or 2)or 2,1,6)
	for _=1,loops do
		touchRock(row)
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
	startAnimSpeedBoost()

	local lastTouch=0
	local lastEquip=0
	local lastActivate=0
	local lastRemote=0

	collectPunchRemotes()

	task.spawn(function()
		while hitting and myId==hitLoopId do
			local now=os.clock()

			if now-lastEquip>1.25 then
				lastEquip=now
				tool=ensurePunchTool(nil) or currentPunchTool()
				startAnimSpeedBoost()
			end

			if now-lastRemote>=(_G.RockBugRemoteDelay or 0.022) then
				lastRemote=now
				firePunchRemoteSpam()
			end

			if tool and tool.Parent and now-lastActivate>=(_G.RockBugActivateDelay or 0.022) then
				lastActivate=now
				spamActivateTool(tool)
			elseif not tool or not tool.Parent then
				activateFistTool(nil)
			end

			if now-lastTouch>=(_G.RockBugTouchDelay or 0.065) then
				lastTouch=now
				spamTouchRock(row)
			end

			if now-lastAnimBoost>0.25 then
				lastAnimBoost=now
				boostPunchAnimations()
			end

			task.wait(_G.RockBugHitDelay or 0.06)
		end
	end)

	if statusFn then
		statusFn("БАГ КАМНЯ: FAST SPAM | remote x"..tostring(_G.RockBugRemoteLoops or 5).." | act x"..tostring(_G.RockBugActivateBursts or 3).." | anim x"..tostring(_G.RockBugAnimSpeed or 3.1)..(ultraOptEnabled and " | ULTRA ON" or "")..(selectedPunchToolName and (" | "..selectedPunchToolName) or ""))
	end
end


local function stopHit(statusFn)
	hitting=false
	hitLoopId+=1
	stopAnimSpeedBoost()
	if hitConn then hitConn:Disconnect() hitConn=nil end
	setLowMap(false,nil,nil)
	pcall(function()if blackBg then blackBg.Visible=false end end)
	if statusFn then statusFn("BUG HIT: остановлен")end
end

-- UI v12: новый компактный дизайн без SCAN/COPY/лишних надписей
local gui=Instance.new("ScreenGui")
gui.Name="RockBugHub_v22_FastSpam"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=999999
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=lp:WaitForChild("PlayerGui")

local blackBg=Instance.new("Frame")
blackBg.Name="BLACK_OPT_BACKGROUND"
blackBg.Parent=gui
blackBg.Size=UDim2.new(1,0,1,0)
blackBg.Position=UDim2.new(0,0,0,0)
blackBg.BackgroundColor3=Color3.fromRGB(0,0,0)
blackBg.BackgroundTransparency=0
blackBg.BorderSizePixel=0
blackBg.ZIndex=0
blackBg.Visible=false

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
main.ZIndex=5
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

local sub=makeText(top,HUB_VERSION.." • FAST SPAM",10,Enum.Font.GothamBold,Color3.fromRGB(165,172,205))
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

local mini=makeBtn(gui,"BUG v22 FS",Color3.fromRGB(46,42,120))
mini.Size=UDim2.new(0,90,0,36)
mini.Position=main.Position
mini.Visible=false
mini.TextSize=11
mini.ZIndex=6

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
selectedName.Size=UDim2.new(1,-120,0,24)
selectedName.Position=UDim2.new(0,10,0,20)

local bugTimerText=makeText(selectedCard,"⏱ 00:00",14,Enum.Font.GothamBlack,Color3.fromRGB(120,255,170))
bugTimerText.Size=UDim2.new(0,102,0,24)
bugTimerText.Position=UDim2.new(1,-112,0,21)
bugTimerText.TextXAlignment=Enum.TextXAlignment.Right

local bugRunTime=0
local bugTimerStartedAt=nil
local bugTimerConn=nil

local function formatBugTime(sec)
	sec=math.max(0,math.floor(sec or 0))
	local h=math.floor(sec/3600)
	local m=math.floor((sec%3600)/60)
	local s=sec%60
	if h>0 then
		return string.format("%02d:%02d:%02d",h,m,s)
	end
	return string.format("%02d:%02d",m,s)
end

local function getBugTime()
	if bugTimerStartedAt then
		return bugRunTime+(os.clock()-bugTimerStartedAt)
	end
	return bugRunTime
end

local function updateBugTimer()
	if bugTimerText then
		bugTimerText.Text="⏱ "..formatBugTime(getBugTime())
	end
end

local function startBugTimer()
	if not bugTimerStartedAt then
		bugTimerStartedAt=os.clock()
	end
	if not bugTimerConn then
		bugTimerConn=RunService.Heartbeat:Connect(updateBugTimer)
	end
	updateBugTimer()
end

local function pauseBugTimer()
	if bugTimerStartedAt then
		bugRunTime+=(os.clock()-bugTimerStartedAt)
		bugTimerStartedAt=nil
	end
	updateBugTimer()
end

updateBugTimer()

local status=makeText(main,"Готово",11,Enum.Font.GothamBold,Color3.fromRGB(210,216,245))
status.Size=UDim2.new(1,-14,0,28)
status.Position=UDim2.new(0,7,0,114)

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

local hitBtn=makeBtn(row1,"СТАРТ БАГА",Color3.fromRGB(30,125,72))
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

local ultraBtn=makeBtn(row2,"ULTRA BLACK",Color3.fromRGB(82,58,135))
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
		pauseBugTimer()
		hitBtn.Text="СТАРТ БАГА"
		hitBtn.BackgroundColor3=Color3.fromRGB(30,125,72)
	else
		local ok,msg=tpInsideRock(selected)
		if not ok then
			setStatus("BUG error: "..tostring(msg))
			return
		end
		startHit(selected,setStatus)
		startBugTimer()
		hitBtn.Text="ПАУЗА БАГА"
		hitBtn.BackgroundColor3=Color3.fromRGB(28,150,82)
	end
end)

unlockBtn.Activated:Connect(function()
	stopLock()
	setStatus("UNLOCK: отпущено")
end)

ultraBtn.Activated:Connect(function()
	ultraOptEnabled=not ultraOptEnabled
	ultraBtn.Text=ultraOptEnabled and "BLACK ON" or "ULTRA BLACK"
	ultraBtn.BackgroundColor3=ultraOptEnabled and Color3.fromRGB(118,65,160) or Color3.fromRGB(82,58,135)

	if blackBg then blackBg.Visible=ultraOptEnabled end

	if ultraOptEnabled then
		collectPunchRemotes()
		pcall(function() ensurePunchTool(nil) end)
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
	pauseBugTimer()
	stopLock()
	ultraOptEnabled=false
	ultraBtn.Text="ULTRA BLACK"
	ultraBtn.BackgroundColor3=Color3.fromRGB(82,58,135)
	setLowMap(false,nil,nil)
	if blackBg then blackBg.Visible=false end
	setStatus("Остановлено • таймер сохранён")
	hitBtn.Text="СТАРТ БАГА"
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
	if blackBg then blackBg.Visible=false end
	if bugTimerConn then bugTimerConn:Disconnect() bugTimerConn=nil end
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
setStatus("Готово • "..count.."/"..#ROCKS.." • v22 fast spam")
