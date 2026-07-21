-- RockBugHub v20 Validated Compact + AutoKill/Shop + Mobile patch
-- Clean rebuild: single scheduler, hard stop, adaptive network throttle.
-- No getgc patching, no full workspace scans inside fast loops, no unknown train remote spam.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Stats=game:GetService("Stats")
local VirtualUser=game:GetService("VirtualUser")
local UserInputService=game:GetService("UserInputService")
local StarterGui=game:GetService("StarterGui")
local NetworkClient=nil
pcall(function() NetworkClient=game:GetService("NetworkClient") end)

-- Delta/auto-execute can run before the client has finished creating LocalPlayer.
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local lp=Players.LocalPlayer
while not lp do
	task.wait()
	lp=Players.LocalPlayer
end

local playerGui=lp:WaitForChild("PlayerGui",60)
if not playerGui then
	warn("[RockBugHub] PlayerGui was not created")
	pcall(function()
		StarterGui:SetCore("SendNotification",{
			Title="RockBugHub",
			Text="Ошибка запуска: PlayerGui не найден",
			Duration=8,
		})
	end)
	return
end

pcall(function()
	StarterGui:SetCore("SendNotification",{
		Title="RockBugHub",
		Text="Скрипт загружен, создаю интерфейс...",
		Duration=3,
	})
end)

local HUB_VERSION="RockBugHub_v20_ValidatedCompact"

local ENV=(type(getgenv)=="function" and getgenv()) or _G

-- Stop previous clean-runtime build.
pcall(function()
	if ENV.RockBugRuntime and type(ENV.RockBugRuntime.Stop)=="function" then
		ENV.RockBugRuntime:Stop("replaced")
	end
end)

-- Remove old windows only. No invasive getgc scan.
pcall(function()
	for _,g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and tostring(g.Name):find("RockBugHub",1,true) then
			g:Destroy()
		end
	end
end)

local Runtime={
	alive=true,
	mode=nil,              -- nil / "bug" / "train"
	modeToken=0,
	connections={},
	selectedTrain=nil,
	selectedRock=nil,
	autoRockSelection=true,
	petGradeIndex=5,
	lastAutoRockRebs=nil,
	autoRockReason=nil,
	autoRebirth=false,
	rebirthInFlight=false,
	rebirthToken=0,
	rebirthGoalEnabled=false,
	rebirthGoal=100,
	rebirthGoalCurrent=nil,
	rebirthGoalCompleted=false,
	rebirthGoalAwaitingFrom=nil,
	rebirthGoalAwaitingSince=0,
	rebirthGoalAwaitingUntil=0,
	rebirthGoalReadFailures=0,
	rebirthGoalStatusAt=0,
	rebirthCounter=nil,
	rebirthCounterSource=nil,
	rebirthCounterExact=false,
	rebirthCounterWatched=nil,
	rebirthCounterConn=nil,
	autoSize=false,
	sizeTarget=1,
	sizeInFlight=false,
	kingLock=false,
	kingCF=nil,
	kingRoot=nil,
	kingSavedAnchored=nil,
	kingPresenceInFlight=false,
	kingPresenceToken=0,
	kingTriggerPart=nil,
	kingTouchTrigger=nil,
	kingTouchContacts={},
	kingHoldPosition=nil,
	kingHoldGyro=nil,
	nextKingTouchPulse=0,
	lockRock=false,
	lockPosition=false,
	lockCF=nil,
	positionCF=nil,
	activeTool=nil,
	nextAction=0,
	nextEquip=0,
	nextNearCheck=0,
	nextPosTick=0,
	nextRebirth=0,
	nextSize=0,
	nextKingTick=0,
	nextNetUpdate=0,
	nextCooldownSweep=0,
	punchCycle=0,
	pingMs=0,
	pingAvailable=false,
	netGuardEnabled=true,
	autoWifiHold=true,
	networkPaused=false,
	manualNetworkHold=false,
	networkState="HEALTHY",
	networkBadSamples=0,
	networkGoodSamples=0,
	networkHoldSince=0,
	networkLastGoodAt=os.clock(),
	networkProbeDeadline=os.clock()+5,
	networkProbeUnsupported=false,
	networkReason=nil,
	networkRecoveries=0,
	networkHoldRoot=nil,
	networkHoldCF=nil,
	networkHoldSavedAnchored=nil,
	nextNetworkHoldTick=0,
	networkReplicatorSeen=false,
	networkReplicatorMissingSince=nil,
	networkHttpSupported=false,
	networkHttpProbeInFlight=false,
	networkHttpProbeStartedAt=0,
	networkHttpProbeGeneration=0,
	networkHttpLastSuccess=os.clock(),
	networkHttpLastFinish=0,
	networkTrafficLastSeen=os.clock(),
	networkHttpBadSamples=0,
	networkHttpRequiredRecovery=false,
	nextNetworkHttpProbe=0,
	transientFailures={},
	respawnGeneration=0,
	autoResumeAfterRespawn=true,
	schedulerRestarts=0,
	remoteTokens=0,
	remoteLastRefill=os.clock(),
	remoteSentWindow=0,
	remoteWindowStart=os.clock(),
	remotePps=0,
	directRemoteEnabled=true,
	antiAfkEnabled=true,
	visualLow=false,
	visualSaved={},
	killMode="off",
	killToken=0,
	killWhitelist={},
	killBlacklist={},
	crystalMode="off",
	crystalToken=0,
	purchaseAttempts=0,
	selectedCrystal="Blue Crystal",
	selectedPet=nil,
	selectedAura=nil,
	characterCollisionSaved={},
	characterLockSaved=nil,
	lastSchedulerTick=0,
	lastError=nil,
	status="ready",
	ui=nil,
	leverRefs={},
}

ENV.RockBugRuntime=Runtime

-- Fallbacks are only used if the live shop has not replicated yet. Normally
-- the selectors are populated from ReplicatedStorage.cPetShopFolder, so new
-- shop items appear automatically without updating this file.
local FALLBACK_SHOP_PETS={
	"Orange Hedgehog","Blue Birdie","Red Kitty","Blue Bunny","Dark Vampy",
	"Silver Dog","Dark Golem","Green Butterfly","Crimson Falcon",
	"Yellow Butterfly","Purple Dragon","Orange Pegasus","Blue Pheonix",
	"Red Dragon","Purple Falcon","Blue Firecaster","Golden Pheonix",
	"Red Firecaster","White Pegasus","Infernal Dragon","Green Firecaster",
	"White Pheonix","Magic Butterfly","Ultra Birdie","Frostwave Legends Penguin",
	"Phantom Genesis Dragon","Dark Legends Manticore","Ultimate Supernova Pegasus",
	"Aether Spirit Bunny","Cybernetic Showdown Dragon","Eternal Strike Leviathan",
	"Lighting Strike Phantom","Darkstar Hunter","Golden Viking","Muscle Sensei",
	"Neon Guardian",
}

local FALLBACK_SHOP_AURAS={
	"Astral Electro","Azure Tundra","Blue Aura","Dark Electro","Dark Lightning","Dark Storm",
	"Electro","Enchanted Mirage","Entropic Blast","Eternal Megastrike","Grand Supernova",
	"Green Aura","Inferno","Lightning","Muscle King","Power Lightning","Purple Aura",
	"Purple Nova","Red Aura","Supernova","Ultra Inferno","Ultra Mirage","Unstable Mirage",
	"Yellow Aura",
}

-- Most direct-shop aura object names do not contain the word "Aura". Keep an
-- exact-name lookup so they are not incorrectly mixed into the pet selector.
local SHOP_AURA_NAME_SET={}
for _,name in ipairs(FALLBACK_SHOP_AURAS) do
	SHOP_AURA_NAME_SET[string.lower(name)]=true
end

local FALLBACK_CRYSTALS={
	"Blue Crystal","Green Crystal","Frost Crystal","Mythical Crystal",
	"Inferno Crystal","Legends Crystal","Muscle Elite Crystal",
	"Galaxy Oracle Crystal","Dark Nebula Crystal","Sky Eclipse Crystal","Jungle Crystal",
}

Runtime.selectedPet="Muscle King"
Runtime.selectedAura="Muscle King"

local function safe(fn)
	local ok,res=pcall(fn)
	return ok,res
end

local function shopPrice(item)
	if not item then return nil end
	local value=item:FindFirstChild("priceValue",true)
	if not value then return nil end
	local ok,price=safe(function() return tonumber(value.Value) end)
	return ok and price or nil
end

local function isAuraShopItem(item)
	if not item then return false end
	local name=string.lower(tostring(item.Name))
	if SHOP_AURA_NAME_SET[name] then return true end
	-- All current direct-shop auras expose this marker, including the 19 whose
	-- object names do not contain "Aura". Its presence is the type signal; the
	-- stored BoolValue itself is false in the live catalog.
	if item:FindFirstChild("isPowerUp",true) then return true end
	if string.find(name,"aura",1,true) or string.find(name,"trail",1,true) then
		return true
	end
	if item:IsA("Trail") or item:FindFirstChildWhichIsA("Trail",true) then
		return true
	end
	for _,attributeName in ipairs({"Type","ItemType","Category"}) do
		local ok,value=safe(function() return item:GetAttribute(attributeName) end)
		if ok and type(value)=="string" then
			local lower=string.lower(value)
			if string.find(lower,"aura",1,true) or string.find(lower,"trail",1,true) then
				return true
			end
		end
	end
	return false
end

local function shopCatalog(kind)
	local result={}
	local seen={}
	local folder=ReplicatedStorage:FindFirstChild("cPetShopFolder")

	if folder then
		for _,item in ipairs(folder:GetChildren()) do
			local aura=isAuraShopItem(item)
			if (kind=="aura" and aura) or (kind=="pet" and not aura) then
				local name=tostring(item.Name)
				if name~="" and not seen[name] then
					seen[name]=true
					table.insert(result,{name=name,price=shopPrice(item)})
				end
			end
		end
	end

	if #result==0 then
		local fallback=kind=="aura" and FALLBACK_SHOP_AURAS or FALLBACK_SHOP_PETS
		for _,name in ipairs(fallback) do
			table.insert(result,{name=name,price=nil})
		end
	end

	table.sort(result,function(a,b)
		local ap=a.price or math.huge
		local bp=b.price or math.huge
		if ap==bp then return string.lower(a.name)<string.lower(b.name) end
		return ap<bp
	end)
	return result
end

local function formatShopPrice(price)
	if not price then return "цена из игры" end
	local text=tostring(math.floor(price+0.5))
	local formatted=text:reverse():gsub("(%d%d%d)","%1 "):reverse():gsub("^ ","")
	return formatted.." гемов"
end

local function normalizeShopSelection(kind)
	local key=kind=="aura" and "selectedAura" or "selectedPet"
	local current=Runtime[key]
	local catalog=shopCatalog(kind)
	for _,entry in ipairs(catalog) do
		if entry.name==current then return current end
	end
	Runtime[key]=catalog[1] and catalog[1].name or nil
	return Runtime[key]
end

local function addConn(c)
	if c then
		table.insert(Runtime.connections,c)
	end
	return c
end

local function disconnectAll()
	for _,c in ipairs(Runtime.connections) do
		safe(function() c:Disconnect() end)
	end
	Runtime.connections={}
end

local function char()
	return lp.Character
end

local function hum()
	local c=char()
	return c and c:FindFirstChildWhichIsA("Humanoid")
end

local function root()
	local c=char()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function setStatus(text)
	Runtime.status=tostring(text or "")
	if Runtime.ui and Runtime.ui.status and Runtime.ui.status.Parent then
		Runtime.ui.status.Text=Runtime.status
	end
end

local function formatServerDuration(value)
	local seconds=math.max(0,math.floor(tonumber(value) or 0))
	local days=math.floor(seconds/86400)
	seconds=seconds%86400
	local hours=math.floor(seconds/3600)
	local minutes=math.floor((seconds%3600)/60)
	local secs=seconds%60
	if days>0 then
		return ("%dд %02d:%02d:%02d"):format(days,hours,minutes,secs)
	end
	return ("%02d:%02d:%02d"):format(hours,minutes,secs)
end

local function observedServerAge()
	-- Roblox does not replicate the real server process uptime to LocalScripts.
	-- On a freshly opened VIP server this connection timer is the closest safe
	-- estimate because the owner normally creates the instance with the first join.
	local ok,value=safe(function() return workspace.DistributedGameTime end)
	if ok and type(value)=="number" and value==value and value>=0 then
		return value
	end
	return nil
end

local function setNetText()
	if Runtime.ui and Runtime.ui.uptime and Runtime.ui.uptime.Parent then
		local age=observedServerAge()
		local isVip=tostring(game.PrivateServerId or "")~=""
		local prefix=isVip and "VIP-СЕРВЕР ~ " or "В СЕРВЕРЕ "
		Runtime.ui.uptime.Text=prefix..(age and formatServerDuration(age) or "--:--:--")
	end

	if Runtime.ui and Runtime.ui.net and Runtime.ui.net.Parent then
		local pingText=Runtime.pingAvailable and tostring(math.floor((Runtime.pingMs or 0)+0.5)).."ms" or "?"
		if Runtime.networkPaused then
			local held=math.max(0,os.clock()-(Runtime.networkHoldSince or os.clock()))
			Runtime.ui.net.Text=("СЕТЬ: ПАУЗА %.1fs | %s"):format(held,pingText)
		elseif Runtime.networkProbeUnsupported then
			Runtime.ui.net.Text=("СЕТЬ: ОГРАНИЧЕНО | УДАР %.1f/s"):format(Runtime.remotePps or 0)
		else
			Runtime.ui.net.Text=("PING %s | УДАР %.1f/s"):format(pingText,Runtime.remotePps or 0)
		end
	end
end

-- ---------- ROCK DATA ----------

local ROCKS={
	{id="AncientJungle",label="Древний лес",req=10000000,mult=16.25},
	{id="MuscleKing",label="Король мышц",req=5000000,mult=12.5},
	{id="Legends",label="Легенды",req=1000000,mult=2.5},
	{id="Inferno",label="Инферно",req=750000,mult=1.125},
	{id="Mystic",label="Мистический",req=400000,mult=0.75},
	{id="Frozen",label="Ледяной",req=150000,mult=0.375},
	{id="Golden",label="Золотой",req=5000,mult=0.2},
	{id="Large",label="Большой",req=100,mult=0.075},
	{id="Punching",label="Пробивной",req=10,mult=0.05},
	{id="Tiny",label="Маленький",req=0,mult=0.025},
}

local rockCache={}

local function valOf(v)
	if not v then return nil end
	local ok,res=pcall(function() return v.Value end)
	if not ok then return nil end
	return tonumber(res)
end

local function hasHands(obj)
	if not obj then return false end
	return obj:FindFirstChild("LeftHand",true)~=nil and obj:FindFirstChild("RightHand",true)~=nil
end

local function findRockModelFromValue(valueObj)
	local p=valueObj
	for _=1,8 do
		if not p or p==workspace then break end
		if hasHands(p) then return p end
		p=p.Parent
	end

	p=valueObj
	for _=1,8 do
		if not p or p==workspace then break end
		if p:IsA("Model") then return p end
		p=p.Parent
	end

	return valueObj.Parent
end

local function biggestPart(obj)
	if not obj then return nil end
	if obj:IsA("BasePart") then return obj end

	local best=nil
	local bestVol=-1

	for _,d in ipairs(obj:GetDescendants()) do
		if d:IsA("BasePart") then
			local vol=d.Size.X*d.Size.Y*d.Size.Z
			if vol>bestVol then
				bestVol=vol
				best=d
			end
		end
	end

	return best
end

local function scanRocks()
	local found={}
	local descendants=workspace:GetDescendants()

	for i,v in ipairs(descendants) do
		if tostring(v.Name)=="neededDurability" then
			local req=valOf(v)

			if req~=nil then
				local model=findRockModelFromValue(v)
				local body=biggestPart(model)
				local left=model and model:FindFirstChild("LeftHand",true)
				local right=model and model:FindFirstChild("RightHand",true)
				local hit=right or left or body

				if body or hit then
					-- If duplicates exist, prefer the one with actual hands.
					local current=found[req]
					local better=(not current) or (hasHands(model) and not hasHands(current.model))

					if better then
						found[req]={
							req=req,
							model=model,
							body=body,
							hit=hit,
							left=left,
							right=right,
							name=model and model.Name or "?",
						}
					end
				end
			end
		end

		-- Do not hold the client for the whole scan on large maps.
		if i%800==0 then task.wait() end
	end

	rockCache=found
	return found
end

local function getRockInfo(row)
	if not row then return nil end
	return rockCache[row.req]
end

-- ---------- REBIRTH READER / AUTO ROCK ----------

local function parseCompactNumber(text)
	local s=tostring(text or ""):lower()
	s=s:gsub("%s+"," ")

	-- Number + optional suffix immediately after the number.
	local raw,suffix=s:match("([%d][%d,%.]*)%s*([kmbt]?)")
	if not raw then return nil end

	-- Support decimal comma (1,5K), but keep 1,000 and 1,000,000 as grouped integers.
	if not raw:find(".",1,true) and raw:match("^%d+,%d%d?$") then
		raw=raw:gsub(",",".")
	else
		raw=raw:gsub(",","")
	end
	local n=tonumber(raw)
	if not n then return nil end

	local mult={k=1e3,m=1e6,b=1e9,t=1e12}
	if suffix~="" then
		n=n*(mult[suffix] or 1)
	end

	return math.floor(n+0.5)
end

local function looksLikeRebirthName(s)
	s=tostring(s or ""):lower()
	return s:find("rebirth",1,true)
		or s:find("rebs",1,true)
		or s:find("реб",1,true)
		or s:find("перерожд",1,true)
end

local function readRebirthValue(object)
	if not object or not object.Parent then return nil end
	local ok,value=pcall(function() return object.Value end)
	if not ok then return nil end
	return tonumber(value) or parseCompactNumber(value)
end

local function rebirthCounterNameScore(name)
	local text=tostring(name or ""):lower():gsub("[%s_%-]","")
	if text:find("cost",1,true) or text:find("price",1,true)
		or text:find("need",1,true) or text:find("require",1,true) then
		return 0
	end
	if text=="rebirths" or text=="rebirth" or text=="rebs"
		or text=="ребирты" or text=="ребы" or text=="перерождения" then
		return 3
	end
	return looksLikeRebirthName(text) and 1 or 0
end

local function isExactRebirthCounterObject(object,score)
	if not object or not object.Parent or (tonumber(score) or 0)<3 then return false end
	if not (object:IsA("IntValue") or object:IsA("NumberValue") or object:IsA("StringValue")) then return false end
	local ok,raw=pcall(function() return object.Value end)
	if not ok then return false end
	local number=tonumber(raw)
	return number~=nil and number==number and number~=math.huge and number~=-math.huge
		and number>=0 and math.abs(number-math.floor(number+0.5))<0.000001
end

local function rememberRebirthCounter(object,source,score)
	if object and object.Parent and object:IsA("ValueBase") then
		Runtime.rebirthCounter=object
		Runtime.rebirthCounterSource=source
		local resolvedScore=tonumber(score) or rebirthCounterNameScore(object.Name)
		Runtime.rebirthCounterExact=isExactRebirthCounterObject(object,resolvedScore)
	end
end

local function readRebirths()
	-- Once a real ValueBase is found, every later check is a local property read.
	-- No repeated descendant or GUI scan is needed during auto rebirth.
	local cached=Runtime.rebirthCounter
	if cached and cached.Parent and Runtime.rebirthCounterExact and Runtime.rebirthCounterSource=="leaderstats" then
		local number=readRebirthValue(cached)
		if number~=nil then return number,Runtime.rebirthCounterSource or "cached",cached end
	elseif not cached or not cached.Parent then
		Runtime.rebirthCounter=nil
		Runtime.rebirthCounterSource=nil
		Runtime.rebirthCounterExact=false
	end

	local leader=lp:FindFirstChild("leaderstats")
	if leader then
		local best,bestNumber,bestScore=nil,nil,0
		for _,d in ipairs(leader:GetChildren()) do
			local score=d:IsA("ValueBase") and rebirthCounterNameScore(d.Name) or 0
			if score>bestScore then
				local number=readRebirthValue(d)
				if number~=nil then
					best,bestNumber,bestScore=d,number,score
				end
			end
		end
		if best then
			rememberRebirthCounter(best,"leaderstats",bestScore)
			return bestNumber,"leaderstats",best
		end
	end

	if cached and cached.Parent then
		local number=readRebirthValue(cached)
		if number~=nil then return number,Runtime.rebirthCounterSource or "cached",cached end
	end

	-- Slow discovery is only a fallback until a real counter has been cached.
	local checked=0
	local best,bestNumber,bestScore=nil,nil,0
	for _,d in ipairs(lp:GetDescendants()) do
		checked=checked+1
		if checked>1800 then break end

		local score=d:IsA("ValueBase") and rebirthCounterNameScore(d.Name) or 0
		if score>bestScore then
			local number=readRebirthValue(d)
			if number~=nil then
				best,bestNumber,bestScore=d,number,score
				if score>=3 then break end
			end
		end
	end
	if best then
		rememberRebirthCounter(best,"value",bestScore)
		return bestNumber,"value",best
	end

	-- Conservative GUI fallback.
	local pg=lp:FindFirstChild("PlayerGui")
	if pg then
		local scanned=0

		for _,d in ipairs(pg:GetDescendants()) do
			-- Never parse RockBugHub's own labels (goal input/status) as the
			-- game's rebirth counter.
			if Runtime.uiRoot and d:IsDescendantOf(Runtime.uiRoot) then continue end

			scanned=scanned+1
			if scanned>2600 then break end

			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				local text=tostring(d.Text or "")
				if looksLikeRebirthName(text) or looksLikeRebirthName(d.Name) then
					local n=parseCompactNumber(text)
					if n then return n,"gui",nil end
				end
			end
		end
	end

	return nil,"not found",nil
end

local function formatWholeNumber(value)
	local number=math.max(0,math.floor(tonumber(value) or 0))
	local text=("%.0f"):format(number)
	return text:reverse():gsub("(%d%d%d)","%1 "):reverse():gsub("^ ","")
end

local function refreshRebirthGoalUI(current,overrideText)
	if current~=nil then Runtime.rebirthGoalCurrent=math.max(0,math.floor(tonumber(current) or 0)) end
	local ui=Runtime.ui and Runtime.ui.rebirthGoalProgress
	if not ui or not ui.Parent then return end

	local target=math.max(1,math.floor(tonumber(Runtime.rebirthGoal) or 1))
	local known=Runtime.rebirthGoalCurrent
	if overrideText then
		ui.Text=overrideText
	elseif Runtime.rebirthGoalCompleted then
		ui.Text=("ЦЕЛЬ ДОСТИГНУТА • %s / %s"):format(formatWholeNumber(known or target),formatWholeNumber(target))
	elseif Runtime.rebirthGoalEnabled then
		if known~=nil then
			ui.Text=("Сейчас: %s • цель: %s • осталось: %s"):format(
				formatWholeNumber(known),formatWholeNumber(target),formatWholeNumber(math.max(0,target-known))
			)
		else
			ui.Text=("Сейчас: — • цель: %s"):format(formatWholeNumber(target))
		end
	else
		ui.Text=("Лимит выключен • цель: %s"):format(formatWholeNumber(target))
	end
end

local PET_GRADES={
	{name="BASIC",base=250},
	{name="UNCOMMON",base=500},
	{name="RARE",base=750},
	{name="EPIC",base=1000},
	{name="UNIQUE",base=1250},
}

local function currentPetGrade()
	return PET_GRADES[math.clamp(tonumber(Runtime.petGradeIndex) or 5,1,#PET_GRADES)]
end

local function compactXp(value40)
	local value=value40/40
	if value==math.floor(value) then return tostring(math.floor(value)) end
	local text=("%.3f"):format(value):gsub("0+$","")
	return (text:gsub("%.$",""))
end

local function chooseSafeRockByRebirths()
	local rebs,source=readRebirths()
	local grade=currentPetGrade()

	if rebs then
		rebs=math.max(0,math.floor(rebs+0.5))
		local maxPetXp40=grade.base*19*20/2*40

		-- Rocks are ordered from strongest to weakest. Pick the strongest available
		-- multiplier that still fits into the pet's level 19 XP range at these rebirths.
		-- This avoids the old "no exact division -> Tiny" fallback.
		for rockIndex,row in ipairs(ROCKS) do
			if rockCache[row.req] then
				local multiplier40=math.floor(row.mult*40+0.5)
				local hitXp40=(rebs+20)*multiplier40

				if hitXp40>0 and hitXp40<=maxPetXp40 then
					local bestForRock=nil

					for level=1,19 do
						local targetXp40=grade.base*level*(level+1)/2*40
						if targetXp40>=hitXp40 then
							local hits=math.max(1,math.floor(targetXp40/hitXp40))
							local remainder=targetXp40-(hits*hitXp40)
							local accuracy=1-(remainder/targetXp40)
							local candidate={
								row=row,
								rockIndex=rockIndex,
								level=level,
								hits=hits,
								hitXp40=hitXp40,
								remainder40=remainder,
								accuracy=accuracy,
							}

							if not bestForRock
								or candidate.accuracy>bestForRock.accuracy
								or (candidate.accuracy==bestForRock.accuracy and candidate.hits<bestForRock.hits)
								or (candidate.accuracy==bestForRock.accuracy and candidate.hits==bestForRock.hits and candidate.level<bestForRock.level) then
								bestForRock=candidate
							end
						end
					end

					if bestForRock then
						local exact=bestForRock.remainder40==0
						local percent=math.floor(bestForRock.accuracy*1000+0.5)/10
						local reason=("%d реб • %s XP • L%d / %d уд. • %.1f%%"):format(
							rebs,compactXp(bestForRock.hitXp40),bestForRock.level,bestForRock.hits,percent
						)
						local calc={
							rebirths=rebs,
							xp40=bestForRock.hitXp40,
							level=bestForRock.level,
							hits=bestForRock.hits,
							accuracy=percent,
							grade=grade.name,
							exact=exact,
							source=source,
						}
						return row,reason,rebs,exact,calc
					end
				end
			end
		end

		-- At extreme rebirth counts even Tiny can exceed the pet XP range. In that
		-- case the weakest available rock is the only safe direction and the UI says why.
		for i=#ROCKS,1,-1 do
			local row=ROCKS[i]
			if rockCache[row.req] then
				local hitXp40=(rebs+20)*math.floor(row.mult*40+0.5)
				local calc={
					rebirths=rebs,
					xp40=hitXp40,
					level=19,
					hits=1,
					accuracy=0,
					grade=grade.name,
					exact=false,
					overLimit=true,
					source=source,
				}
				return row,("%d реб • XP выше лимита питомца"):format(rebs),rebs,false,calc
			end
		end
	end

	for i=#ROCKS,1,-1 do
		local row=ROCKS[i]
		if rockCache[row.req] then
			return row,"ребы не найдены ("..tostring(source)..")",nil,false,{grade=grade.name,exact=false}
		end
	end

	return ROCKS[#ROCKS],"камни не найдены",nil,false,{grade=grade.name,exact=false}
end

local function applyAutoRockSelection(force)
	if not Runtime.autoRockSelection and not force then return false end
	local row,reason,rebs,exact,calc=chooseSafeRockByRebirths()
	if not force and rebs~=nil and Runtime.lastAutoRockRebs==rebs then return false end

	local previous=Runtime.selectedRock
	Runtime.selectedRock=row
	Runtime.lastAutoRockRebs=rebs
	Runtime.autoRockReason=reason
	Runtime.autoRockExact=exact
	Runtime.autoRockCalc=calc

	if Runtime.ui then
		if Runtime.ui.autoRockTitle and Runtime.ui.autoRockTitle.Parent then
			Runtime.ui.autoRockTitle.Text="АВТОПОДБОР ПО РЕБЁРТАМ"
		end
		if Runtime.ui.autoRockName and Runtime.ui.autoRockName.Parent then
			Runtime.ui.autoRockName.Text=row.label.."  •  питомец "..tostring(calc and calc.grade or "-")
		end
		if Runtime.ui.autoRockStats and Runtime.ui.autoRockStats.Parent then
			local rebText=calc and calc.rebirths~=nil and tostring(calc.rebirths) or "не найдены"
			local xpText=calc and calc.xp40 and compactXp(calc.xp40) or "?"
			if calc and calc.overLimit then
				Runtime.ui.autoRockStats.Text=("Ребёрты: %s  •  XP/удар: %s  •  превышен лимит питомца"):format(rebText,xpText)
			elseif calc and calc.level and calc.hits then
				Runtime.ui.autoRockStats.Text=("Ребёрты: %s  •  XP/удар: %s  •  цель L%d  •  %d уд.  •  %.1f%%"):format(
					rebText,xpText,calc.level,calc.hits,tonumber(calc.accuracy) or (calc.exact and 100 or 0)
				)
			else
				Runtime.ui.autoRockStats.Text=("Ребёрты: %s  •  XP/удар: %s  •  данные персонажа не найдены"):format(rebText,xpText)
			end
		end
	end

	if type(Runtime.refreshRockList)=="function" then Runtime.refreshRockList() end
	if previous and previous.id~=row.id and Runtime.mode=="bug" and type(Runtime.teleportInsideSelected)=="function" then
		Runtime.teleportInsideSelected()
	end
	return true
end

-- ---------- TOOL HELPERS ----------

local function toolName(tool)
	return tostring(tool and tool.Name or ""):lower()
end

local function containsAny(s,words)
	s=tostring(s or ""):lower()
	for _,w in ipairs(words) do
		if s:find(tostring(w):lower(),1,true) then return true end
	end
	return false
end

local PUNCH_GOOD={"punch","fist","combat","кулак","удар"}
local PUNCH_BAD={"weight","dumb","barbell","bench","push","sit","handstand","tread","гант","гир","штанг","отжим","пресс","бег"}

local function isPunchTool(tool)
	if not tool or not tool:IsA("Tool") then return false end

	local n=toolName(tool)
	if containsAny(n,PUNCH_BAD) then return false end
	if containsAny(n,PUNCH_GOOD) then return true end

	for _,d in ipairs(tool:GetDescendants()) do
		if containsAny(d.Name,PUNCH_BAD) then return false end
		if containsAny(d.Name,PUNCH_GOOD) then return true end
	end

	return false
end

local TRAIN_TYPES={
	{id="Punch",label="PUNCH",desc="удары / сила",words={"punch","fist","combat","кулак","удар"}},
	{id="Weight",label="WEIGHT",desc="вес / гантели / штанга",words={"weight","dumb","dumbbell","barbell","bench","вес","гант","штанг","гир"}},
	{id="Push",label="PUSH",desc="отжимания",words={"push","pushup","push-up","отжим"}},
	{id="Sit",label="SIT",desc="пресс / situps",words={"sit","situp","sit-up","abs","пресс"}},
	{id="Hand",label="HANDSTAND",desc="стойка на руках",words={"handstand","hand stand","стойк"}},
	{id="Tread",label="TREADMILL",desc="бег / agility",words={"tread","treadmill","agility","speed","бег","дорож","ловк","скор"}},
}

local function toolMatchesTrain(tool,t)
	if not tool or not tool:IsA("Tool") then return false end

	if t.id=="Punch" then
		return isPunchTool(tool)
	end

	local n=toolName(tool)
	if containsAny(n,t.words) then return true end

	for _,d in ipairs(tool:GetDescendants()) do
		if containsAny(d.Name,t.words) then return true end
	end

	return false
end

local function findTool(predicate)
	local c=char()
	local bp=lp:FindFirstChildOfClass("Backpack")

	if c then
		for _,tool in ipairs(c:GetChildren()) do
			if tool:IsA("Tool") and predicate(tool) then
				return tool,true
			end
		end
	end

	if bp then
		for _,tool in ipairs(bp:GetChildren()) do
			if tool:IsA("Tool") and predicate(tool) then
				return tool,false
			end
		end
	end

	return nil,false
end

local function equipTool(tool)
	if not tool then return false end

	local c=char()
	local h=hum()
	if not c or not h then return false end

	if tool.Parent==c then
		return true
	end

	safe(function() h:UnequipTools() end)
	task.wait(0.04)
	safe(function() h:EquipTool(tool) end)
	task.wait(0.06)

	return tool.Parent==c
end

local COOLDOWN_NAMES={
	"Cooldown","cooldown","CD","cd","Delay","delay",
	"AttackCooldown","attackCooldown","SwingCooldown","swingCooldown",
	"AttackTime","attackTime","PunchCooldown","punchCooldown",
	"LastUse","lastUse","LastSwing","lastSwing","LastAttack","lastAttack",
	"CanUse","canUse","CanSwing","canSwing","Ready","ready"
}

local function clearCooldownsOnce(tool)
	if not tool then return end
	safe(function() tool.Enabled=true end)

	local function fix(obj)
		for _,name in ipairs(COOLDOWN_NAMES) do
			local child=obj:FindFirstChild(name)

			if child then
				safe(function()
					if child:IsA("NumberValue") or child:IsA("IntValue") then child.Value=0 end
					if child:IsA("BoolValue") then child.Value=true end
					if child:IsA("StringValue") then child.Value="0" end
				end)
			end

			safe(function()
				local v=obj:GetAttribute(name)
				if v~=nil then
					if type(v)=="number" then obj:SetAttribute(name,0) end
					if type(v)=="boolean" then obj:SetAttribute(name,true) end
					if type(v)=="string" then obj:SetAttribute(name,"0") end
				end
			end)
		end
	end

	fix(tool)
	for _,d in ipairs(tool:GetDescendants()) do
		fix(d)
	end
end

local function findPunchTool()
	return findTool(isPunchTool)
end

local function findTrainTool(t)
	return findTool(function(tool)
		return toolMatchesTrain(tool,t)
	end)
end

local function textOfGui(obj)
	local s=tostring(obj.Name)

	if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
		s=s.." "..tostring(obj.Text or "")
	end

	return s:lower()
end

local function guiMatchesTrain(text,t)
	local normalized=(" "..tostring(text or ""):lower():gsub("[^%w]+"," ").." ")

	for _,word in ipairs(t.words) do
		local w=tostring(word):lower()

		-- Short ASCII words such as "sit" and "abs" must be whole words;
		-- otherwise "position" would incorrectly match "sit".
		if #w<=3 and w:match("^[%w]+$") then
			if normalized:find(" "..w.." ",1,true) then return true end
		elseif tostring(text or ""):lower():find(w,1,true) then
			return true
		end
	end

	return false
end

local function guiIsActuallyVisible(obj,playerGui)
	local current=obj

	while current and current~=playerGui do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("LayerCollector") and not current.Enabled then return false end
		current=current.Parent
	end

	return current==playerGui
end

local function findGuiButtonForTrain(t)
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return nil end

	local scanned=0

	for _,d in ipairs(pg:GetDescendants()) do
		scanned=scanned+1
		if scanned>2600 then break end

		if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Active and guiIsActuallyVisible(d,pg) then
			local full=string.lower(d:GetFullName())

			-- Never click trading or purchasing UI by fuzzy matching.
			local blocked=containsAny(full,{"trade","purchase","shop","store","buy","магаз","купить"})
			if not blocked then
				local txt=textOfGui(d)
				if guiMatchesTrain(txt,t) then
					return d
				end
			end
		end
	end

	return nil
end

local function trySelectTrainFromGui(t)
	local btn=findGuiButtonForTrain(t)
	if not btn then return false end

	local activated=safe(function()
		btn:Activate()
	end)

	-- Executor-specific signal firing is only a fallback. Calling both paths
	-- can toggle a button twice or execute a purchase/action twice.
	if not activated and type(firesignal)=="function" then
		activated=safe(function()
			firesignal(btn.Activated)
		end)
	end

	if activated then task.wait(0.18) end
	return activated
end

local function ensurePunchTool()
	local tool,equipped=findPunchTool()

	if not tool then
		return nil,"Punch Tool не найден"
	end

	if not equipped and not equipTool(tool) then
		return nil,"не удалось надеть Punch"
	end

	return tool,"Punch: "..tool.Name
end

local function ensureTrainTool(t)
	local tool,equipped=findTrainTool(t)

	if not tool then
		trySelectTrainFromGui(t)
		tool,equipped=findTrainTool(t)
	end

	if not tool then
		return nil,t.label..": предмет не найден"
	end

	if not equipped and not equipTool(tool) then
		return nil,t.label..": не удалось надеть"
	end

	return tool,t.label..": "..tool.Name
end

-- ---------- NETWORK CONTROL ----------

local NET_HOLD_PING_MS=900
local NET_RECOVER_PING_MS=650
local NET_RECOVER_SAMPLES=3
local NET_MIN_HOLD_SECONDS=1.5
local NET_OFFLINE_AFTER_SECONDS=6
local NET_HTTP_INTERVAL=1.25
local NET_HTTP_TIMEOUT=2.75
local NET_REPLICATOR_GRACE=1.0
local NET_HTTP_URL="https://clients3.google.com/generate_204"

local function resolveHttpRequest()
	local candidates={}
	local function addCandidate(candidate)
		if type(candidate)=="function" then table.insert(candidates,candidate) end
	end
	addCandidate(ENV.request)
	addCandidate(ENV.http_request)
	addCandidate(type(ENV.syn)=="table" and ENV.syn.request or nil)
	addCandidate(type(ENV.http)=="table" and ENV.http.request or nil)

	for _,candidate in ipairs(candidates) do
		if type(candidate)=="function" then
			return function(url)
				return candidate({
					Url=url,
					Method="GET",
					Headers={["Cache-Control"]="no-cache"},
				})
			end
		end
	end

	-- Delta's loader already exposes HttpGet even when no request alias exists.
	return function(url)
		return game:HttpGet(url,true)
	end
end

local networkHttpRequest=resolveHttpRequest()

local function getReceiveKbps()
	local ok,value=safe(function() return Stats.DataReceiveKbps end)
	if ok and type(value)=="number" and value==value and value>=0 then
		return value
	end
	return nil
end

local function hasClientReplicator()
	if not NetworkClient then return nil end
	local ok,present=safe(function()
		for _,child in ipairs(NetworkClient:GetChildren()) do
			if child:IsA("ClientReplicator") then return true end
		end
		return false
	end)
	if not ok then return nil end
	return present
end

local function beginNetworkHttpProbe(now)
	if not Runtime.autoWifiHold or Runtime.networkHttpProbeInFlight or now<Runtime.nextNetworkHttpProbe then return end
	Runtime.nextNetworkHttpProbe=now+NET_HTTP_INTERVAL
	Runtime.networkHttpProbeInFlight=true
	Runtime.networkHttpProbeStartedAt=now
	Runtime.networkHttpProbeGeneration=Runtime.networkHttpProbeGeneration+1
	local generation=Runtime.networkHttpProbeGeneration

	task.spawn(function()
		local nonce=tostring(math.floor(os.clock()*1000))
		local ok,response=safe(function()
			return networkHttpRequest(NET_HTTP_URL.."?rh="..nonce)
		end)
		local finished=os.clock()
		if not Runtime.alive or generation~=Runtime.networkHttpProbeGeneration then return end

		Runtime.networkHttpProbeInFlight=false
		Runtime.networkHttpLastFinish=finished

		-- Any real HTTP response proves that DNS/routing works. Some request APIs
		-- represent the expected 204 response as an empty string, others as a table.
		local gotResponse=ok
		if type(response)=="table" then
			local code=tonumber(response.StatusCode or response.Status or response.status_code)
			if code then gotResponse=code>=100 and code<600 end
		end

		if gotResponse then
			Runtime.networkHttpSupported=true
			Runtime.networkHttpLastSuccess=finished
			Runtime.networkHttpBadSamples=0
		else
			Runtime.networkHttpBadSamples=Runtime.networkHttpBadSamples+1
		end
	end)
end

local function validPing(value)
	return type(value)=="number" and value==value and value>0 and value<math.huge
end

local function getPingMs()
	-- Player:GetNetworkPing() is the lightest probe when the client exposes it.
	local directOk,direct=safe(function()
		return lp:GetNetworkPing()*1000
	end)
	if not directOk or not validPing(direct) then direct=nil end

	-- Data Ping also sees replication queues/retransmissions, so use the worse of
	-- both probes instead of hiding a replication stall behind a healthy raw ping.
	local ok,res=safe(function()
		local network=Stats:FindFirstChild("Network")
		local server=network and network:FindFirstChild("ServerStatsItem")
		local ping=server and server:FindFirstChild("Data Ping")

		if ping then
			local text=tostring(ping:GetValueString())
			return tonumber(text:match("([%d%.]+)"))
		end
	end)

	if not ok or not validPing(res) then res=nil end
	if direct and res then return math.max(direct,res) end
	if direct then return direct end
	if res then return res end

	-- Unknown is deliberately nil. Treating it as 0 would enable full remote rate
	-- exactly while replication statistics are unavailable.
	return nil
end

local function releaseNetworkCharacterHold()
	local heldRoot=Runtime.networkHoldRoot
	if heldRoot and heldRoot.Parent and Runtime.networkHoldSavedAnchored~=nil then
		safe(function()
			if Runtime.kingLock and Runtime.kingRoot==heldRoot then
				-- King Gym must remain an unanchored, physical character after
				-- a network hold; the dedicated BodyMovers keep it in place.
				heldRoot.Anchored=false
				Runtime.nextKingTick=0
			else
				heldRoot.Anchored=Runtime.networkHoldSavedAnchored
			end
			heldRoot.AssemblyLinearVelocity=Vector3.new(0,0,0)
			heldRoot.AssemblyAngularVelocity=Vector3.new(0,0,0)
		end)
	end

	Runtime.networkHoldRoot=nil
	Runtime.networkHoldCF=nil
	Runtime.networkHoldSavedAnchored=nil
	Runtime.nextNetworkHoldTick=0
end

local function keepNetworkCharacterHold()
	local r=root()
	if not r then return false end

	if Runtime.networkHoldRoot~=r then
		releaseNetworkCharacterHold()
		Runtime.networkHoldRoot=r
		Runtime.networkHoldCF=r.CFrame
		Runtime.networkHoldSavedAnchored=r.Anchored
	end

	local cf=Runtime.networkHoldCF or r.CFrame
	safe(function()
		r.CFrame=cf
		r.AssemblyLinearVelocity=Vector3.new(0,0,0)
		r.AssemblyAngularVelocity=Vector3.new(0,0,0)
		-- A false-positive Wi-Fi hold must not remove King Gym physics.
		local kingPhysical=Runtime.kingLock and Runtime.kingRoot==r
		if kingPhysical then
			if Runtime.kingHoldPosition and Runtime.kingHoldPosition.Parent==r then
				Runtime.kingHoldPosition.Position=cf.Position
			end
			if Runtime.kingHoldGyro and Runtime.kingHoldGyro.Parent==r then
				Runtime.kingHoldGyro.CFrame=cf
			end
		end
		r.Anchored=not kingPhysical
	end)
	return true
end

local function enterNetworkHold(reason,now)
	if not Runtime.netGuardEnabled then return end
	now=now or os.clock()

	if not Runtime.networkPaused then
		Runtime.networkPaused=true
		Runtime.networkHoldSince=now
		Runtime.networkState="SUSPECT"
		Runtime.transientFailures={}
		Runtime.remoteTokens=0
		Runtime.nextAction=now+0.25
		Runtime.nextRebirth=now+0.5
		Runtime.nextSize=now+0.5
	end

	Runtime.networkReason=tostring(reason or "connection unstable")
	keepNetworkCharacterHold()
	setStatus("СЕТЬ: ПАУЗА • "..Runtime.networkReason)
end

local function leaveNetworkHold(now,reason)
	now=now or os.clock()
	local wasPaused=Runtime.networkPaused
	Runtime.networkPaused=false
	Runtime.networkState="HEALTHY"
	Runtime.networkBadSamples=0
	Runtime.networkGoodSamples=0
	Runtime.networkHoldSince=0
	Runtime.networkReason=nil
	Runtime.networkLastGoodAt=now
	Runtime.networkHttpRequiredRecovery=false
	Runtime.transientFailures={}
	Runtime.remoteTokens=0
	Runtime.remoteLastRefill=now
	Runtime.nextAction=now+0.25
	if Runtime.rebirthGoalEnabled and Runtime.rebirthGoalAwaitingFrom~=nil then
		-- A request may have reached the server just before Wi-Fi disappeared.
		-- Give its replicated Value a fresh settle window after recovery before
		-- allowing any retry, especially when this was the final rebirth.
		Runtime.rebirthGoalAwaitingUntil=math.max(Runtime.rebirthGoalAwaitingUntil or 0,now+2.5)
		Runtime.nextRebirth=Runtime.rebirthGoalAwaitingUntil
	else
		Runtime.nextRebirth=now+0.5
	end
	Runtime.nextSize=now+0.5
	releaseNetworkCharacterHold()

	if wasPaused then
		Runtime.networkRecoveries=Runtime.networkRecoveries+1
		setStatus("СЕТЬ ВОССТАНОВЛЕНА • режим продолжен")
	end
end

local function noteNetworkFailure(reason)
	if not Runtime.netGuardEnabled then return end
	Runtime.networkBadSamples=math.max(1,Runtime.networkBadSamples or 0)
	Runtime.networkGoodSamples=0
	enterNetworkHold(reason or "remote error",os.clock())
end

local function updateNetworkGuard(now)
	local sample=getPingMs()
	local receiveKbps=getReceiveKbps()
	local replicatorPresent=hasClientReplicator()

	if sample then
		Runtime.pingMs=sample
		Runtime.pingAvailable=true
		Runtime.networkProbeUnsupported=false
	end
	if receiveKbps and receiveKbps>0.01 then
		Runtime.networkTrafficLastSeen=now
	end

	-- ClientReplicator represents the actual Roblox server connection. Only a
	-- transition from seen -> missing is authoritative, so restricted executors
	-- cannot create a false offline state merely by hiding NetworkClient children.
	if replicatorPresent==true then
		Runtime.networkReplicatorSeen=true
		Runtime.networkReplicatorMissingSince=nil
	elseif replicatorPresent==false and Runtime.networkReplicatorSeen then
		Runtime.networkReplicatorMissingSince=Runtime.networkReplicatorMissingSince or now
	end

	if Runtime.netGuardEnabled then
		beginNetworkHttpProbe(now)
	end

	if not Runtime.netGuardEnabled then
		Runtime.networkBadSamples=0
		Runtime.networkGoodSamples=0
		return sample
	end

	if Runtime.manualNetworkHold then
		enterNetworkHold("manual WiFi hold",now)
		Runtime.networkState="MANUAL HOLD"
		return sample
	end

	-- Give Stats/GetNetworkPing five seconds to appear. If this executor never
	-- exposes either probe, fall back to a permanently conservative rate instead
	-- of freezing every existing feature forever.
	if sample==nil and not Runtime.pingAvailable and not Runtime.networkHttpSupported
		and not Runtime.networkReplicatorSeen and now>=Runtime.networkProbeDeadline then
		if Runtime.networkPaused then leaveNetworkHold(now,"LIMITED / NO PING PROBE") end
		Runtime.networkProbeUnsupported=true
		Runtime.networkState="LIMITED"
		Runtime.networkBadSamples=0
		Runtime.networkGoodSamples=0
		return nil
	end

	local invalid=(sample==nil)
	local replicatorMissing=Runtime.networkReplicatorSeen
		and Runtime.networkReplicatorMissingSince~=nil
		and now-Runtime.networkReplicatorMissingSince>=NET_REPLICATOR_GRACE
	local httpTimedOut=Runtime.autoWifiHold
		and Runtime.networkHttpSupported
		and Runtime.networkHttpProbeInFlight
		and now-Runtime.networkHttpProbeStartedAt>=NET_HTTP_TIMEOUT
	local httpFailed=Runtime.autoWifiHold
		and Runtime.networkHttpSupported
		and Runtime.networkHttpBadSamples>=2

	if httpTimedOut or httpFailed or replicatorMissing then
		Runtime.networkHttpRequiredRecovery=true
	end

	local recentHttpSuccess=Runtime.networkHttpSupported
		and now-Runtime.networkHttpLastSuccess<=math.max(3,NET_HTTP_INTERVAL*2.5)
	local replicatorReady=not Runtime.networkReplicatorSeen or replicatorPresent==true
	local confirmedOnline=recentHttpSuccess and replicatorReady
	local bad=replicatorMissing or httpTimedOut or httpFailed
		or (invalid and not confirmedOnline)
		or (sample~=nil and sample>=NET_HOLD_PING_MS)
	local good=((sample~=nil and sample<=NET_RECOVER_PING_MS) or (invalid and confirmedOnline))
		and not replicatorMissing and not httpTimedOut and not httpFailed

	if bad then
		Runtime.networkBadSamples=Runtime.networkBadSamples+1
		Runtime.networkGoodSamples=0
		local reason
		if replicatorMissing then
			reason="Roblox connection missing"
		elseif httpTimedOut then
			reason="WiFi probe timeout"
		elseif httpFailed then
			reason="WiFi probe failed"
		else
			reason=invalid and "ping unavailable" or ("ping "..math.floor(sample).."ms")
		end
		enterNetworkHold(reason,now)

		if Runtime.networkBadSamples>=2 then
			Runtime.networkState="GRACE"
		end
	elseif good then
		Runtime.networkBadSamples=0
		Runtime.networkGoodSamples=math.min(NET_RECOVER_SAMPLES,Runtime.networkGoodSamples+1)
		Runtime.networkLastGoodAt=now
		if not Runtime.networkPaused then Runtime.networkState="HEALTHY" end
	else
		-- Middle band is intentional hysteresis: do not oscillate between hold/resume.
		Runtime.networkBadSamples=math.max(0,Runtime.networkBadSamples-1)
		Runtime.networkGoodSamples=0
	end

	if Runtime.networkPaused then
		local held=now-Runtime.networkHoldSince
		if held>=NET_OFFLINE_AFTER_SECONDS and Runtime.networkState~="HEALTHY" then
			Runtime.networkState="OFFLINE WAIT"
		end

		local recoveredAfterHold=Runtime.networkHttpLastSuccess>=Runtime.networkHoldSince
			or Runtime.networkTrafficLastSeen>=Runtime.networkHoldSince
		local recoveryProof=not Runtime.networkHttpRequiredRecovery
			or (recoveredAfterHold and replicatorReady)
		if good and recoveryProof and Runtime.networkGoodSamples>=NET_RECOVER_SAMPLES and held>=NET_MIN_HOLD_SECONDS then
			leaveNetworkHold(now,"RECOVERED")
		end
	end

	return sample
end

local function clearTransientFailure(key)
	Runtime.transientFailures[key]=nil
end

local function transientFailureExpired(key,now,grace)
	local started=Runtime.transientFailures[key]
	if not started then
		Runtime.transientFailures[key]=now
		return false,0
	end

	local elapsed=now-started
	return elapsed>=grace,elapsed
end

local function effectiveRates()
	if Runtime.networkPaused then
		return 1,0
	end
	if Runtime.netGuardEnabled and not Runtime.pingAvailable then
		return 3,1
	end

	local ping=Runtime.pingMs or 0

	if ping>=700 then
		return 3,0
	elseif ping>=450 then
		return 4,1
	elseif ping>=300 then
		return 6,3
	elseif ping>=200 then
		return 8,5
	end

	return 9,5
end

local function refillRemoteTokens()
	if Runtime.networkPaused then
		Runtime.remoteTokens=0
		Runtime.remoteLastRefill=os.clock()
		return
	end

	local now=os.clock()
	local _,limit=effectiveRates()
	local elapsed=now-Runtime.remoteLastRefill

	Runtime.remoteLastRefill=now
	Runtime.remoteTokens=math.min(limit,Runtime.remoteTokens+elapsed*limit)
end

local function findMuscleRemote()
	local direct=lp:FindFirstChild("muscleEvent")
	if direct and direct:IsA("RemoteEvent") then return direct end

	local events=ReplicatedStorage:FindFirstChild("rEvents")
	local remote=events and events:FindFirstChild("muscleEvent")

	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	return nil
end

local function updateRemotePps()
	local now=os.clock()
	local elapsed=now-Runtime.remoteWindowStart

	if elapsed>=1 then
		Runtime.remotePps=Runtime.remoteSentWindow/elapsed
		Runtime.remoteSentWindow=0
		Runtime.remoteWindowStart=now
	end
end

local function countRemoteSent()
	Runtime.remoteSentWindow=Runtime.remoteSentWindow+1
	updateRemotePps()
end

local function tryPunchRemote()
	if not Runtime.directRemoteEnabled then return false end
	if Runtime.networkPaused then return false,"network hold" end

	refillRemoteTokens()

	if Runtime.remoteTokens<1 then
		return false
	end

	local remote=findMuscleRemote()
	if not remote then return false end

	Runtime.remoteTokens=Runtime.remoteTokens-1

	local hand=(Runtime.punchCycle%2==0) and "rightHand" or "leftHand"

	local ok=safe(function()
		remote:FireServer("punch",hand)
	end)

	if ok then
		countRemoteSent()
		return true
	end

	local _,limit=effectiveRates()
	Runtime.remoteTokens=math.min(limit,Runtime.remoteTokens+1)
	noteNetworkFailure("punch remote error")

	return false
end

local function tryTrainRemote()
	if not Runtime.directRemoteEnabled then return false end
	if Runtime.networkPaused then return false,"network hold" end

	refillRemoteTokens()

	if Runtime.remoteTokens<1 then
		return false
	end

	local remote=findMuscleRemote()
	if not remote then return false end

	Runtime.remoteTokens=Runtime.remoteTokens-1

	local ok=safe(function()
		remote:FireServer("rep")
	end)

	if ok then
		countRemoteSent()
		return true
	end

	local _,limit=effectiveRates()
	Runtime.remoteTokens=math.min(limit,Runtime.remoteTokens+1)
	noteNetworkFailure("train remote error")

	return false
end

-- ---------- AUTO KILL / CRYSTALS ----------

local function selectedCount(values)
	local count=0
	for _,enabled in pairs(values or {}) do
		if enabled then count=count+1 end
	end
	return count
end

local function refreshExtraUI()
	if type(Runtime.refreshExtraUI)=="function" then
		safe(Runtime.refreshExtraUI)
	end
end

local function availableCrystalNames()
	local names={}
	local seen={}
	local folder=workspace:FindFirstChild("mapCrystalsFolder")

	if folder then
		for _,item in ipairs(folder:GetChildren()) do
			local name=tostring(item.Name)
			local key=string.lower(name)
			if key:find("crystal",1,true) and not seen[key] then
				seen[key]=true
				table.insert(names,name)
			end
		end
	end

	if #names==0 then
		for _,name in ipairs(FALLBACK_CRYSTALS) do
			table.insert(names,name)
		end
	end

	table.sort(names,function(a,b)
		return string.lower(a)<string.lower(b)
	end)
	return names
end

local function resolveCrystalName(wanted)
	local wantedLower=string.lower(tostring(wanted or ""))
	local names=availableCrystalNames()

	for _,name in ipairs(names) do
		if string.lower(name)==wantedLower then return name end
	end

	local alias=wantedLower=="frost crystal" and "frozen crystal"
		or (wantedLower=="frozen crystal" and "frost crystal")
	if alias then
		for _,name in ipairs(names) do
			if string.lower(name)==alias then return name end
		end
	end

	return wanted
end

local function folderOwnsNamed(folderName,targetName)
	local folder=lp:FindFirstChild(folderName)
	if not folder then return false end
	local target=string.lower(tostring(targetName or ""))

	for _,item in ipairs(folder:GetDescendants()) do
		if string.lower(tostring(item.Name))==target then return true end
		if item:IsA("StringValue") then
			local ok,value=safe(function() return string.lower(tostring(item.Value)) end)
			if ok and value==target then return true end
		end
	end

	return false
end

local function ownsPet(name)
	return folderOwnsNamed("petsFolder",name)
end

local function ownsAura(name)
	return folderOwnsNamed("trailsFolder",name) or folderOwnsNamed("aurasFolder",name)
end

local function shouldKillPlayer(player,mode)
	if not player or player==lp then return false end
	if mode=="all" then return true end
	if mode=="whitelist" then return Runtime.killWhitelist[player.UserId]~=true end
	if mode=="blacklist" then return Runtime.killBlacklist[player.UserId]==true end
	return false
end

local function touchKillTarget(player,tool)
	local localCharacter=char()
	local targetCharacter=player and player.Character
	local targetHumanoid=targetCharacter and targetCharacter:FindFirstChildWhichIsA("Humanoid")
	local targetRoot=targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

	if not localCharacter or not targetRoot or not targetHumanoid or targetHumanoid.Health<=0 then return end

	if tool and tool.Parent then
		clearCooldownsOnce(tool)
		safe(function() tool:Activate() end)
	end
	tryPunchRemote()

	if type(firetouchinterest)=="function" then
		for _,handName in ipairs({"RightHand","LeftHand","Right Arm","Left Arm"}) do
			local hand=localCharacter:FindFirstChild(handName,true)
			if hand and hand:IsA("BasePart") then
				safe(function()
					firetouchinterest(hand,targetRoot,0)
					firetouchinterest(hand,targetRoot,1)
				end)
			end
		end
	end
end

local function stopKillAutomation(message)
	Runtime.killToken=Runtime.killToken+1
	Runtime.killMode="off"
	for _,lever in pairs(Runtime.leverRefs.kill or {}) do
		if lever then lever.Set(false,true) end
	end
	refreshExtraUI()
	if message then setStatus(message) end
end

local function startKillAutomation(mode)
	Runtime.killToken=Runtime.killToken+1
	Runtime.killMode=mode
	local token=Runtime.killToken
	refreshExtraUI()
	setStatus("АВТОКИЛ: "..string.upper(mode))

	task.spawn(function()
		while Runtime.alive and Runtime.killMode==mode and Runtime.killToken==token do
			if not Runtime.networkPaused then
				local tool=ensurePunchTool()
				for _,player in ipairs(Players:GetPlayers()) do
					if Runtime.killToken~=token then break end
					if shouldKillPlayer(player,mode) then
						touchKillTarget(player,tool)
					end
				end
			end
			task.wait(0.10)
		end
	end)
end

local function openCrystalOnce(name)
	local events=ReplicatedStorage:FindFirstChild("rEvents")
	local remote=events and events:FindFirstChild("openCrystalRemote")
	if not remote then return false,"openCrystalRemote не найден" end
	local resolved=resolveCrystalName(name)

	local ok,err=safe(function()
		if remote:IsA("RemoteFunction") then
			remote:InvokeServer("openCrystal",resolved)
		else
			remote:FireServer("openCrystal",resolved)
		end
	end)
	return ok,err,resolved
end

local function buyShopItemOnce(name)
	local folder=ReplicatedStorage:FindFirstChild("cPetShopFolder")
	local remote=ReplicatedStorage:FindFirstChild("cPetShopRemote")
	if not folder then return false,"cPetShopFolder не найден" end
	if not remote then return false,"cPetShopRemote не найден" end

	-- Resolve the exact selected object again on every attempt. Keeping an old
	-- instance here caused mismatched purchases after the shop refreshed.
	local item=folder:FindFirstChild(tostring(name or ""))
	if not item then return false,"товар не найден: "..tostring(name) end

	local ok,err=safe(function()
		if remote:IsA("RemoteFunction") then
			remote:InvokeServer(item)
		else
			remote:FireServer(item)
		end
	end)
	return ok,err,item.Name
end

local function purchaseTarget(mode)
	if mode=="crystal" then return Runtime.selectedCrystal end
	if mode=="pet" then return Runtime.selectedPet end
	if mode=="aura" then return Runtime.selectedAura end
	return nil
end

local function stopCrystalAutomation(message)
	Runtime.crystalToken=Runtime.crystalToken+1
	Runtime.crystalMode="off"
	for _,lever in pairs(Runtime.leverRefs.crystal or {}) do
		if lever then lever.Set(false,true) end
	end
	refreshExtraUI()
	if message then setStatus(message) end
end

local function startCrystalAutomation(mode)
	if mode=="pet" then normalizeShopSelection("pet") end
	if mode=="aura" then normalizeShopSelection("aura") end
	local targetName=purchaseTarget(mode)
	if not targetName then
		setStatus("СНАЧАЛА ВЫБЕРИ ЦЕЛЬ")
		return false
	end
	if mode~="crystal" then
		local folder=ReplicatedStorage:FindFirstChild("cPetShopFolder")
		if not folder or not folder:FindFirstChild(targetName) then
			setStatus("ТОВАР НЕ НАЙДЕН В МАГАЗИНЕ: "..tostring(targetName))
			return false
		end
	end

	Runtime.crystalToken=Runtime.crystalToken+1
	Runtime.crystalMode=mode
	Runtime.purchaseAttempts=0
	local token=Runtime.crystalToken
	refreshExtraUI()
	setStatus((mode=="crystal" and "ОТКРЫТИЕ: " or "ПРЯМАЯ ПОКУПКА: ")..targetName)

	task.spawn(function()
		while Runtime.alive and Runtime.crystalMode==mode and Runtime.crystalToken==token do
			if not Runtime.networkPaused then
				local ok,err,resolved
				if mode=="crystal" then
					ok,err,resolved=openCrystalOnce(targetName)
				else
					ok,err,resolved=buyShopItemOnce(targetName)
				end
				if ok then
					Runtime.purchaseAttempts=Runtime.purchaseAttempts+1
					local action=mode=="crystal" and "ОТКРЫТИЕ" or "ПОКУПКА"
					setStatus(action.." #"..Runtime.purchaseAttempts..": "..tostring(resolved))
				else
					setStatus("ОШИБКА ПОКУПКИ: "..tostring(err))
				end
			end
			task.wait(0.5)
		end
	end)
	return true
end

local function stopExtraAutomation(message)
	stopKillAutomation(nil)
	stopCrystalAutomation(nil)
	if message then setStatus(message) end
end

-- ---------- REBIRTH / MUSCLE KING ----------

local DEFAULT_KING_CF=CFrame.new(
	-8625.93262,17.2325287,-5730.47217,
	0.765763462,-1.84813775e-09,0.643122315,
	-1.32089262e-09,1,4.44647785e-09,
	-0.643122315,-4.25444568e-09,0.765763462
)

local function findRebirthRemote()
	local events=ReplicatedStorage:FindFirstChild("rEvents")
	local remote=events and events:FindFirstChild("rebirthRemote")

	if remote and (remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent")) then
		return remote
	end

	return nil
end

local function tryRebirth(remote)
	if Runtime.networkPaused then return false,"network hold" end
	remote=remote or findRebirthRemote()
	if not remote then return false,"rebirthRemote не найден" end

	local response=nil
	local ok,err=safe(function()
		if remote:IsA("RemoteFunction") then
			response=remote:InvokeServer("rebirthRequest")
		else
			remote:FireServer("rebirthRequest")
		end
	end)

	return ok,err,remote:IsA("RemoteFunction"),response
end

local function clearRebirthGoalPending()
	Runtime.rebirthGoalAwaitingFrom=nil
	Runtime.rebirthGoalAwaitingSince=0
	Runtime.rebirthGoalAwaitingUntil=0
	Runtime.rebirthGoalReadFailures=0
end

local function stopRebirthAutomation(reason,completed,current)
	Runtime.rebirthToken=Runtime.rebirthToken+1
	Runtime.autoRebirth=false
	Runtime.rebirthGoalEnabled=false
	Runtime.rebirthGoalCompleted=completed==true
	Runtime.nextRebirth=0
	clearRebirthGoalPending()

	if current~=nil then Runtime.rebirthGoalCurrent=math.max(0,math.floor(tonumber(current) or 0)) end
	if Runtime.leverRefs.autoRebirth then Runtime.leverRefs.autoRebirth.Set(false,true) end
	if Runtime.leverRefs.rebirthGoal then Runtime.leverRefs.rebirthGoal.Set(false,true) end
	refreshRebirthGoalUI(Runtime.rebirthGoalCurrent)
	if reason then setStatus(reason) end
end

local function stopRebirthAtGoal(current)
	local target=math.max(1,math.floor(tonumber(Runtime.rebirthGoal) or 1))
	local reached=math.max(0,math.floor(tonumber(current) or target))
	stopRebirthAutomation(
		("ЦЕЛЬ ДОСТИГНУТА: %s / %s • АВТОРЕБИРТ СТОП"):format(formatWholeNumber(reached),formatWholeNumber(target)),
		true,
		reached
	)
end

local function observeRebirthCounter(counter,value)
	if not Runtime.alive then return end
	if counter and Runtime.rebirthCounterWatched and counter~=Runtime.rebirthCounterWatched then return end
	local current=tonumber(value)
	if current==nil then return end
	current=math.max(0,math.floor(current+0.5))
	Runtime.rebirthGoalCurrent=current

	local awaiting=Runtime.rebirthGoalAwaitingFrom
	if awaiting~=nil and current>awaiting then
		clearRebirthGoalPending()
	end
	refreshRebirthGoalUI(current)

	if Runtime.rebirthGoalEnabled then
		local target=math.max(1,math.floor(tonumber(Runtime.rebirthGoal) or 1))
		if current>=target then
			stopRebirthAtGoal(current)
		else
			-- A real Value change is the acknowledgement. Continue immediately;
			-- there is no fixed polling delay after a successful rebirth.
			Runtime.nextRebirth=0
		end
	end
end

local function ensureRebirthCounterWatcher()
	local current,source,counter=readRebirths()
	local exactNumericCounter=counter and (counter:IsA("IntValue") or counter:IsA("NumberValue"))
	if not exactNumericCounter
		or not Runtime.rebirthCounterExact
		or source~="leaderstats"
		or not counter:IsDescendantOf(lp) then
		if Runtime.rebirthCounterConn then safe(function() Runtime.rebirthCounterConn:Disconnect() end) end
		Runtime.rebirthCounterConn=nil
		Runtime.rebirthCounterWatched=nil
		return current,source,nil
	end

	if Runtime.rebirthCounterWatched~=counter or not Runtime.rebirthCounterConn then
		if Runtime.rebirthCounterConn then safe(function() Runtime.rebirthCounterConn:Disconnect() end) end
		Runtime.rebirthCounterWatched=counter
		local ok,connection=safe(function()
			return counter:GetPropertyChangedSignal("Value"):Connect(function()
				if not Runtime.alive or Runtime.rebirthCounterWatched~=counter then return end
				local value=readRebirthValue(counter)
				if value~=nil then observeRebirthCounter(counter,value) end
			end)
		end)
		Runtime.rebirthCounterConn=ok and addConn(connection) or nil
		if not Runtime.rebirthCounterConn then
			Runtime.rebirthCounterWatched=nil
			return current,source,nil
		end
	end

	if current~=nil then observeRebirthCounter(counter,current) end
	return current,source,counter
end

local function rebirthGoalRetryDelay(current,target,isRemoteFunction)
	local pingSeconds=Runtime.pingAvailable and math.max(0,tonumber(Runtime.pingMs) or 0)/1000 or 0.1
	-- Successful rebirths do not wait for this timeout: the Value signal schedules
	-- the next request immediately. This is only a safety window before retrying a
	-- request whose replicated acknowledgement never arrived.
	local delay=math.clamp(0.35+pingSeconds*3,0.65,1.5)
	if target-current<=2 then delay=math.max(delay,2.0) end
	if not isRemoteFunction then delay=math.max(delay,1.0) end
	return math.min(delay,2.5)
end

local function runRebirthAttempt(runToken)
	local function currentRun()
		return Runtime.alive
			and Runtime.autoRebirth
			and Runtime.rebirthToken==runToken
	end

	local before=nil
	local counter=nil
	local target=nil
	if Runtime.rebirthGoalEnabled then
		local value,_,resolvedCounter=ensureRebirthCounterWatcher()
		if not currentRun() then return end

		if value==nil or not resolvedCounter then
			local now=os.clock()
			Runtime.rebirthGoalCurrent=nil
			Runtime.rebirthGoalReadFailures=Runtime.rebirthGoalReadFailures+1
			Runtime.nextRebirth=now+1
			refreshRebirthGoalUI(nil,"Точный счётчик Rebirths не найден • запрос на паузе")
			if Runtime.rebirthGoalReadFailures==1 or now-Runtime.rebirthGoalStatusAt>=3 then
				Runtime.rebirthGoalStatusAt=now
				setStatus("ЦЕЛЬ: ТОЧНЫЙ СЧЁТЧИК REBIRTHS НЕ НАЙДЕН • ПАУЗА")
			end
			return
		end

		Runtime.rebirthGoalReadFailures=0
		counter=resolvedCounter
		before=math.max(0,math.floor(value+0.5))
		target=math.max(1,math.floor(tonumber(Runtime.rebirthGoal) or 1))
		refreshRebirthGoalUI(before)
		if before>=target then
			stopRebirthAtGoal(before)
			return
		end

		local awaiting=Runtime.rebirthGoalAwaitingFrom
		if awaiting~=nil then
			if before>awaiting then
				clearRebirthGoalPending()
			else
				local now=os.clock()
				if now<Runtime.rebirthGoalAwaitingUntil then
					Runtime.nextRebirth=Runtime.rebirthGoalAwaitingUntil
					return
				end

				-- The previous request was rejected or its counter update never arrived.
				-- Release exactly one slot and retry; inFlight still prevents overlap.
				clearRebirthGoalPending()
			end
		end
	end

	if not currentRun() then return end
	local remote=findRebirthRemote()
	if not remote then
		Runtime.nextRebirth=os.clock()+1
		setStatus("AUTO REB: rebirthRemote не найден")
		return
	end
	if target and not remote:IsA("RemoteFunction") then
		stopRebirthAutomation("ЦЕЛЬ РЕБИРТОВ: НУЖЕН ТОЧНЫЙ REMOTEFUNCTION",false,before)
		return
	end

	local isRemoteFunction=remote:IsA("RemoteFunction")
	local retryDelay=target and rebirthGoalRetryDelay(before,target,isRemoteFunction) or 0.1
	if Runtime.rebirthGoalEnabled then
		-- Arm acknowledgement BEFORE InvokeServer: Value may change while the
		-- yielding call is still waiting for its response.
		local sentAt=os.clock()
		Runtime.rebirthGoalAwaitingFrom=before
		Runtime.rebirthGoalAwaitingSince=sentAt
		Runtime.rebirthGoalAwaitingUntil=sentAt+retryDelay
	end

	local ok,err=tryRebirth(remote)
	if not currentRun() then return end

	if not ok then
		if Runtime.rebirthGoalEnabled then
			if Runtime.rebirthGoalAwaitingFrom==before then
				-- An InvokeServer error does not prove that the server rejected the
				-- request. Keep the same acknowledgement window to avoid a duplicate.
				Runtime.nextRebirth=Runtime.rebirthGoalAwaitingUntil
				setStatus("AUTO REB: ЖДУ СЧЁТЧИК ПОСЛЕ ОШИБКИ СЕТИ")
			else
				-- The Value signal already confirmed this request while it was yielding.
				Runtime.nextRebirth=0
			end
		else
			Runtime.nextRebirth=os.clock()+0.25
			setStatus("AUTO REB: "..tostring(err))
		end
		return
	end

	if Runtime.rebirthGoalEnabled and counter then
		local after=readRebirthValue(counter)
		if after~=nil then observeRebirthCounter(counter,after) end
		if not currentRun() then return end

		if Runtime.rebirthGoalAwaitingFrom==before then
			-- No change yet: wait only the short post-response replication window.
			Runtime.rebirthGoalAwaitingUntil=math.max(Runtime.rebirthGoalAwaitingUntil,os.clock()+retryDelay)
			Runtime.nextRebirth=Runtime.rebirthGoalAwaitingUntil
		else
			Runtime.nextRebirth=0
		end
	elseif not Runtime.rebirthGoalEnabled then
		-- Unlimited mode is limited only by the yielding server call plus a tiny
		-- client-side guard, matching the game's usual fast rebirth cadence.
		Runtime.nextRebirth=os.clock()+0.05
	end
end

local function findSizeRemote()
	local events=ReplicatedStorage:FindFirstChild("rEvents")
	local remote=events and events:FindFirstChild("changeSpeedSizeRemote")

	if remote and (remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent")) then
		return remote
	end

	return nil
end

local function trySetSize(value)
	if Runtime.networkPaused then return false,"network hold" end
	local remote=findSizeRemote()
	if not remote then return false,"changeSpeedSizeRemote не найден" end

	local size=tonumber(value)
	if not size then return false,"неверный размер" end
	size=math.clamp(size,0.1,1000)

	local ok,err=safe(function()
		if remote:IsA("RemoteFunction") then
			remote:InvokeServer("changeSize",size)
		else
			remote:FireServer("changeSize",size)
		end
	end)

	return ok,err
end

local function kingTargetCF()
	local custom=ENV.RockBugKingCF
	if typeof(custom)=="CFrame" then return custom end
	return DEFAULT_KING_CF
end

local function destroyKingPhysicalHold()
	for _,field in ipairs({"kingHoldPosition","kingHoldGyro"}) do
		local mover=Runtime[field]
		if mover and mover.Parent then safe(function() mover:Destroy() end) end
		Runtime[field]=nil
	end

	-- Also clean an orphan left by an interrupted creation between the two
	-- BodyMovers or by a replaced runtime.
	local candidates={Runtime.kingRoot,root()}
	local seen={}
	for _,candidate in ipairs(candidates) do
		if candidate and not seen[candidate] then
			seen[candidate]=true
			for _,child in ipairs(candidate:GetChildren()) do
				if child.Name=="RockBugKingPhysicalHold" or child.Name=="RockBugKingPhysicalGyro" then
					safe(function() child:Destroy() end)
				end
			end
		end
	end
end

local function releaseKingTouch(clearTrigger)
	local trigger=Runtime.kingTouchTrigger
	if trigger and trigger.Parent and type(firetouchinterest)=="function" then
		for _,part in ipairs(Runtime.kingTouchContacts or {}) do
			if part and part.Parent and part:IsA("BasePart") then
				safe(function() firetouchinterest(part,trigger,1) end)
			end
		end
	end
	Runtime.kingTouchContacts={}
	Runtime.kingTouchTrigger=nil
	if clearTrigger then Runtime.kingTriggerPart=nil end
end

local function kingTriggerScore(part,targetPosition)
	local distance=(part.Position-targetPosition).Magnitude
	if distance>320 then return nil end

	local full=tostring(part:GetFullName()):lower()
	local hasTouch=part:FindFirstChildOfClass("TouchTransmitter")~=nil
	local kingNamed=full:find("muscle king",1,true) or full:find("muscleking",1,true) or full:find("king",1,true)
	local zoneNamed=containsAny(full,{"trigger","zone","area","hill","capture","touch","boost"})
	local excludedGeometry=containsAny(full,{"rock","mountain","machine","crystal","shop","neededdurability"})
	if excludedGeometry then return nil end
	if not hasTouch and not zoneNamed then return nil end
	if not kingNamed and not zoneNamed and distance>35 then return nil end
	local score=-distance*0.08

	if hasTouch then score=score+100 end
	if full:find("muscle king",1,true) or full:find("muscleking",1,true) then score=score+170 end
	if full:find("king",1,true) then score=score+80 end
	if zoneNamed then score=score+55 end
	if part.CanTouch then score=score+8 end
	if not part.CanCollide then score=score+6 end
	if part.Size.X>=8 and part.Size.Z>=8 then score=score+8 end

	-- A generic touch part can only be a very close fallback. Named King/zone
	-- ancestry wins over unrelated portals or pads in the same area.
	return score
end

local function findKingTriggerPart()
	if Runtime.kingTriggerPart and Runtime.kingTriggerPart.Parent then
		return Runtime.kingTriggerPart
	end

	local targetPosition=kingTargetCF().Position
	local best=nil
	local bestScore=-math.huge

	local function consider(part)
		if not part or not part:IsA("BasePart") then return end
		local score=kingTriggerScore(part,targetPosition)
		if score and score>bestScore then
			best=part
			bestScore=score
		end
	end

	-- Spatial lookup avoids missing the zone merely because it appeared after
	-- the old arbitrary 12,000-descendant scan limit.
	local spatialOk,nearby=safe(function()
		return workspace:GetPartBoundsInRadius(targetPosition,320)
	end)
	if spatialOk and type(nearby)=="table" then
		for _,part in ipairs(nearby) do consider(part) end
	end

	if not best then
		for _,part in ipairs(workspace:GetDescendants()) do consider(part) end
	end

	Runtime.kingTriggerPart=best
	return best
end

local function kingPhysicalCF(trigger)
	local base=Runtime.kingCF or kingTargetCF()
	if not trigger or not trigger.Parent then return base end
	if (trigger.Position-base.Position).Magnitude>160 then return base end

	local localPosition=trigger.CFrame:PointToObjectSpace(base.Position)
	local half=trigger.Size*0.5
	local alreadyInside=
		math.abs(localPosition.X)<=half.X+3
		and math.abs(localPosition.Y)<=half.Y+4
		and math.abs(localPosition.Z)<=half.Z+3
	if alreadyInside then return base end

	local y=trigger.Position.Y
	if trigger.CanCollide or trigger.Size.Y<4 then
		y=y+half.Y+2.8
	end
	return CFrame.new(trigger.Position.X,y,trigger.Position.Z)*base.Rotation
end

local function installKingPhysicalHold(r,cf)
	destroyKingPhysicalHold()
	r.Anchored=false
	r.CFrame=cf
	r.AssemblyLinearVelocity=Vector3.new(0,0,0)
	r.AssemblyAngularVelocity=Vector3.new(0,0,0)

	local ok,err=xpcall(function()
		local position=Instance.new("BodyPosition")
		position.Name="RockBugKingPhysicalHold"
		position.MaxForce=Vector3.new(1e9,1e9,1e9)
		position.P=50000
		position.D=1800
		position.Position=cf.Position
		position.Parent=r
		Runtime.kingHoldPosition=position

		local gyro=Instance.new("BodyGyro")
		gyro.Name="RockBugKingPhysicalGyro"
		gyro.MaxTorque=Vector3.new(1e9,1e9,1e9)
		gyro.P=40000
		gyro.D=1200
		gyro.CFrame=cf
		gyro.Parent=r
		Runtime.kingHoldGyro=gyro
	end,function(e)
		return tostring(e)
	end)

	if not ok then destroyKingPhysicalHold() end
	return ok,err
end

local function pulseKingTouch(trigger)
	Runtime.nextKingTouchPulse=os.clock()+2
	if not trigger or not trigger.Parent or type(firetouchinterest)~="function" then return end
	local c=char()
	local contacts={
		Runtime.kingRoot,
		c and (c:FindFirstChild("LeftFoot") or c:FindFirstChild("Left Leg")),
		c and (c:FindFirstChild("RightFoot") or c:FindFirstChild("Right Leg")),
		c and (c:FindFirstChild("LowerTorso") or c:FindFirstChild("Torso")),
	}

	local openContacts=Runtime.kingTouchContacts or {}
	local sameOpenTouch=Runtime.kingTouchTrigger==trigger and #openContacts>0
	if sameOpenTouch then
		for _,part in ipairs(openContacts) do
			if not part or not part.Parent then
				sameOpenTouch=false
				break
			end
		end
	end
	if sameOpenTouch then return end
	if #openContacts>0 or Runtime.kingTouchTrigger then releaseKingTouch(false) end

	Runtime.kingTouchContacts={}
	Runtime.kingTouchTrigger=trigger
	for _,part in ipairs(contacts) do
		if part and part.Parent and part:IsA("BasePart") then
			table.insert(Runtime.kingTouchContacts,part)
		-- Keep the touch open while King Gym is enabled. The old code sent
		-- touch-end immediately, which explicitly removed physical presence.
			safe(function() firetouchinterest(part,trigger,0) end)
		end
	end
end

local function triggerKingPresence(r)
	if Runtime.kingPresenceInFlight or not Runtime.kingLock or not r or not r.Parent then return false end
	Runtime.kingPresenceInFlight=true
	local token=Runtime.kingPresenceToken

	local ok,err=xpcall(function()
		destroyKingPhysicalHold()
		releaseKingTouch(false)

		local trigger=findKingTriggerPart()
		local cf=kingPhysicalCF(trigger)
		Runtime.kingCF=cf
		local entryCF=cf*CFrame.new(0,8,0)

		r.Anchored=false
		r.CFrame=entryCF
		r.AssemblyAngularVelocity=Vector3.new(0,0,0)

		-- Cross the zone over several replicated physics frames instead of an
		-- instantaneous CFrame jump, so the server observes a real entry.
		for step=1,12 do
			if not Runtime.alive or Runtime.networkPaused or not Runtime.kingLock or Runtime.kingPresenceToken~=token
				or Runtime.kingRoot~=r or not r.Parent then return end
			local alpha=step/12
			r.CFrame=entryCF:Lerp(cf,alpha)
			r.AssemblyLinearVelocity=Vector3.new(0,-4,0)
			r.AssemblyAngularVelocity=Vector3.new(0,0,0)
			RunService.Heartbeat:Wait()
		end

		task.wait(0.12)
		if not Runtime.alive or Runtime.networkPaused or not Runtime.kingLock or Runtime.kingPresenceToken~=token
			or Runtime.kingRoot~=r or not r.Parent then return end

		pulseKingTouch(trigger)
		local holdOk,holdErr=installKingPhysicalHold(r,cf)
		if not holdOk then error(holdErr or "physical hold failed") end
	end,function(e)
		return tostring(e)
	end)

	if Runtime.kingPresenceToken==token then Runtime.kingPresenceInFlight=false end
	if not ok and Runtime.alive and Runtime.kingLock and Runtime.kingPresenceToken==token then
		setStatus("KING PHYSICS: "..tostring(err))
	end
	return ok
end

local function disableKingLock()
	local savedRoot=Runtime.kingRoot
	Runtime.kingPresenceToken=Runtime.kingPresenceToken+1
	Runtime.kingLock=false
	destroyKingPhysicalHold()
	releaseKingTouch(true)

	if savedRoot and savedRoot.Parent and Runtime.kingSavedAnchored~=nil then
		safe(function() savedRoot.Anchored=Runtime.kingSavedAnchored end)
	end

	Runtime.kingCF=nil
	Runtime.kingRoot=nil
	Runtime.kingSavedAnchored=nil
	Runtime.kingPresenceInFlight=false
	Runtime.nextKingTouchPulse=0
end

local function enableKingLock()
	local r=root()
	if not r then return false,"нет root" end

	disableKingLock()

	Runtime.kingCF=kingTargetCF()
	Runtime.kingLock=true
	Runtime.kingRoot=r
	if Runtime.networkHoldRoot==r and Runtime.networkHoldSavedAnchored~=nil then
		Runtime.kingSavedAnchored=Runtime.networkHoldSavedAnchored
	else
		Runtime.kingSavedAnchored=r.Anchored
	end
	Runtime.nextKingTick=0

	if Runtime.networkPaused then
		-- Network hold owns the root until replication is healthy again. The
		-- scheduler will perform the physical entry immediately after release.
		return true
	end

	local ok=triggerKingPresence(r)
	if not ok then
		disableKingLock()
		return false,"не удалось создать физическое присутствие"
	end
	return true
end

-- ---------- STABLE CHARACTER LOCK ----------

local function restoreCharacterLock()
	local saved=Runtime.characterLockSaved

	-- Nothing was locked by this runtime, so do not overwrite game-owned state.
	if not saved then
		Runtime.characterCollisionSaved={}
		return
	end

	-- Restore the exact instances that were changed. After respawn, using root()
	-- here could apply the previous character's state to the new character.
	local r=saved.root
	local h=saved.humanoid

	if r and r.Parent then
		safe(function()
			r.Anchored=saved.rootAnchored
			r.AssemblyLinearVelocity=Vector3.new(0,0,0)
			r.AssemblyAngularVelocity=Vector3.new(0,0,0)
		end)
	end

	if h and h.Parent then
		safe(function()
			h.AutoRotate=saved.autoRotate
			if saved.walkSpeed~=nil then h.WalkSpeed=saved.walkSpeed end
		end)
	end

	for part,state in pairs(Runtime.characterCollisionSaved) do
		if part and part.Parent then
			safe(function()
				part.CanCollide=state.CanCollide
				part.CanTouch=state.CanTouch
			end)
		end
	end

	Runtime.characterCollisionSaved={}
	Runtime.characterLockSaved=nil
end

local function lockCharacterAt(cf)
	local c=char()
	local r=root()
	local h=hum()
	if not c or not r then return false,"нет персонажа" end

	-- Restore any previous lock first, then save a fresh clean state.
	restoreCharacterLock()

	Runtime.characterLockSaved={
		character=c,
		root=r,
		humanoid=h,
		rootAnchored=r.Anchored,
		autoRotate=h and h.AutoRotate or true,
		walkSpeed=h and h.WalkSpeed or 16,
	}
	Runtime.characterCollisionSaved={}

	for _,part in ipairs(c:GetDescendants()) do
		if part:IsA("BasePart") then
			Runtime.characterCollisionSaved[part]={
				CanCollide=part.CanCollide,
				CanTouch=part.CanTouch,
			}
			part.CanCollide=false
		end
	end

	if h then
		h.AutoRotate=false
		h.WalkSpeed=0
	end

	r.CFrame=cf
	r.AssemblyLinearVelocity=Vector3.new(0,0,0)
	r.AssemblyAngularVelocity=Vector3.new(0,0,0)

	-- Keep the assembly movable so punch animation/touch can replicate.
	-- The scheduler only corrects the CFrame after real drift.
	r.Anchored=false

	Runtime.lockCF=cf
	return true
end

-- ---------- SAFE TOUCH / LOCK ----------

local function targetPart()
	local info=getRockInfo(Runtime.selectedRock)
	return info and (info.hit or info.body) or nil
end

local function oneTouch()
	if type(firetouchinterest)~="function" then return end

	local target=targetPart()
	local c=char()

	if not target or not c or not target:IsA("BasePart") then return end

	local hands={
		c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"),
		c:FindFirstChild("LeftHand") or c:FindFirstChild("Left Arm"),
	}

	if not hands[1] and not hands[2] then
		hands[1]=c:FindFirstChild("HumanoidRootPart")
	end

	for _,hand in ipairs(hands) do
		if hand and hand:IsA("BasePart") then
			safe(function()
				firetouchinterest(hand,target,0)
				firetouchinterest(hand,target,1)
			end)
		end
	end
end

local function insideRockCF(row)
	local info=getRockInfo(row)
	if not info then return nil,"камень не найден" end

	local body=info.body
	local left=info.left
	local right=info.right
	local hit=info.hit
	local cf=nil

	-- Stand inside the server-facing hit part so physical punches can register.
	if hit and hit:IsA("BasePart") then
		local offsetY=math.clamp(hit.Size.Y*0.03,0,0.75)
		cf=hit.CFrame*CFrame.new(0,offsetY,0)
	elseif left and left:IsA("BasePart") and right and right:IsA("BasePart") then
		local center=(left.Position+right.Position)/2
		local rot=(body and body:IsA("BasePart")) and (body.CFrame-body.Position) or CFrame.new()
		cf=CFrame.new(center)*rot
	elseif body and body:IsA("BasePart") then
		local offsetY=math.clamp(body.Size.Y*0.08,0,2)
		cf=body.CFrame*CFrame.new(0,offsetY,0)
	end

	if not cf then return nil,"нет точки внутри камня" end

	local custom=ENV.RockBugInsideOffset
	if typeof(custom)=="Vector3" then
		cf=cf*CFrame.new(custom)
	end

	return cf
end

local function teleportInsideSelected()
	local cf,err=insideRockCF(Runtime.selectedRock)
	if not cf then return false,err end

	local ok,why=lockCharacterAt(cf)
	if not ok then return false,why end

	Runtime.nextLockTick=0
	return true
end

Runtime.teleportInsideSelected=teleportInsideSelected

local function nearSelectedRock()
	local r=root()
	local target=targetPart()

	if not r or not target then return false,"нет цели" end

	local distance=(r.Position-target.Position).Magnitude
	local maxSize=math.max(target.Size.X,target.Size.Y,target.Size.Z)
	local limit=math.max(70,maxSize+38)

	if distance>limit then
		return false,"вышел из камня"
	end

	return true
end

local function insideSelectedRockLockZone(r)
	local info=getRockInfo(Runtime.selectedRock)
	local zone=info and (info.body or info.hit)
	if not r or not zone or not zone:IsA("BasePart") then return false end

	local localPosition=zone.CFrame:PointToObjectSpace(r.Position)
	local half=zone.Size*0.5
	local maxSize=math.max(zone.Size.X,zone.Size.Y,zone.Size.Z)
	local margin=math.clamp(maxSize*0.18,8,22)

	return math.abs(localPosition.X)<=half.X+margin
		and math.abs(localPosition.Y)<=half.Y+margin
		and math.abs(localPosition.Z)<=half.Z+margin
end

-- ---------- SAFE VISUAL LOW ----------

local function setVisualLow(on)
	if on==Runtime.visualLow then return end
	Runtime.visualLow=on

	if on then
		Runtime.visualSaved={}

		local scanned=0
		for _,d in ipairs(workspace:GetDescendants()) do
			scanned=scanned+1
			if scanned>6500 then break end

			if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
				Runtime.visualSaved[d]={Enabled=d.Enabled}
				d.Enabled=false
			elseif d:IsA("BasePart") then
				Runtime.visualSaved[d]={CastShadow=d.CastShadow}
				d.CastShadow=false
			end

			if scanned%500==0 then task.wait() end
		end

		setStatus("МЕНЬШЕ ЭФФЕКТОВ: включено")
	else
		for obj,saved in pairs(Runtime.visualSaved) do
			if obj and obj.Parent then
				if saved.Enabled~=nil then safe(function() obj.Enabled=saved.Enabled end) end
				if saved.CastShadow~=nil then safe(function() obj.CastShadow=saved.CastShadow end) end
			end
		end

		Runtime.visualSaved={}
		setStatus("МЕНЬШЕ ЭФФЕКТОВ: выключено")
	end
end

-- ---------- MODE CONTROL ----------

local function unequip()
	local h=hum()
	if h then safe(function() h:UnequipTools() end) end
end

local function setAllModeLeversOff()
	if Runtime.leverRefs.bug then Runtime.leverRefs.bug.Set(false,true) end
	if Runtime.leverRefs.lockRock then Runtime.leverRefs.lockRock.Set(false,true) end

	for _,lever in pairs(Runtime.leverRefs.train or {}) do
		if lever then lever.Set(false,true) end
	end
end

local function clearModeState(reason,updateLevers)
	Runtime.modeToken=Runtime.modeToken+1
	Runtime.mode=nil
	Runtime.selectedTrain=nil
	Runtime.activeTool=nil
	Runtime.nextAction=0
	Runtime.nextEquip=0
	Runtime.nextCooldownSweep=0
	Runtime.punchCycle=0
	Runtime.lockRock=false
	Runtime.lockCF=nil
	Runtime.transientFailures={}

	restoreCharacterLock()
	unequip()

	if updateLevers then
		setAllModeLeversOff()
	end

	if reason then setStatus(reason) end
end

local function stopMode(reason)
	clearModeState(reason or "STOP",true)
end

local function panicStop()
	clearModeState("ВСЁ ОСТАНОВЛЕНО",true)
	stopExtraAutomation(nil)
	Runtime.lockPosition=false
	Runtime.positionCF=nil
	stopRebirthAutomation(nil,false)
	Runtime.autoSize=false
	disableKingLock()

	if Runtime.leverRefs.lockPosition then Runtime.leverRefs.lockPosition.Set(false,true) end
	if Runtime.leverRefs.autoSize then Runtime.leverRefs.autoSize.Set(false,true) end
	if Runtime.leverRefs.kingLock then Runtime.leverRefs.kingLock.Set(false,true) end

	setVisualLow(false)
	if Runtime.leverRefs.visualLow then Runtime.leverRefs.visualLow.Set(false,true) end
end

local function startBug()
	stopKillAutomation(nil)
	-- Reset the previous mode and all of its UI levers before enabling BUG.
	clearModeState(nil,true)

	-- Position lock belongs to TRAIN and would fight the rock CFrame lock.
	Runtime.lockPosition=false
	Runtime.positionCF=nil
	disableKingLock()
	if Runtime.leverRefs.lockPosition then
		Runtime.leverRefs.lockPosition.Set(false,true)
	end
	if Runtime.leverRefs.kingLock then
		Runtime.leverRefs.kingLock.Set(false,true)
	end

	if not Runtime.selectedRock then
		setStatus("камень не выбран")
		return false
	end

	local ok,err=teleportInsideSelected()
	if not ok then
		setStatus("BUG: "..tostring(err))
		return false
	end

	local tool,msg=ensurePunchTool()
	if not tool then
		restoreCharacterLock()
		setStatus(tostring(msg))
		return false
	end

	Runtime.activeTool=tool
	Runtime.modeToken=Runtime.modeToken+1
	Runtime.mode="bug"
	Runtime.lockRock=true
	Runtime.nextAction=0
	Runtime.nextEquip=0
	Runtime.nextCooldownSweep=0
	Runtime.nextNearCheck=0
	local _,remoteLimit=effectiveRates()
	Runtime.remoteTokens=remoteLimit

	if Runtime.leverRefs.bug then Runtime.leverRefs.bug.Set(true,true) end
	if Runtime.leverRefs.lockRock then Runtime.leverRefs.lockRock.Set(true,true) end

	clearCooldownsOnce(tool)
	safe(function() tool:Activate() end)
	oneTouch()

	setStatus("АВТОУДАР: включён • "..tostring(Runtime.selectedRock.label))
	return true
end

local function startTrain(t)
	stopKillAutomation(nil)
	-- Clear BUG/TP LOCK and stale TRAIN levers before enabling this one.
	clearModeState(nil,true)

	local tool,msg=ensureTrainTool(t)
	if not tool then
		setStatus(tostring(msg))
		return false
	end

	Runtime.activeTool=tool
	Runtime.selectedTrain=t
	Runtime.modeToken=Runtime.modeToken+1
	Runtime.mode="train"
	Runtime.nextAction=0
	Runtime.nextEquip=0
	Runtime.nextCooldownSweep=0
	local _,remoteLimit=effectiveRates()
	Runtime.remoteTokens=remoteLimit

	local lever=Runtime.leverRefs.train and Runtime.leverRefs.train[t.id]
	if lever then lever.Set(true,true) end

	clearCooldownsOnce(tool)
	safe(function() tool:Activate() end)
	tryTrainRemote()

	setStatus("КАЧ: "..tostring(t.label).." включён")
	return true
end

-- ---------- SINGLE SCHEDULER ----------

local function scheduler()
	while Runtime.alive do
		local now=os.clock()
		Runtime.lastSchedulerTick=now

		if now>=Runtime.nextNetUpdate then
			Runtime.nextNetUpdate=now+0.5
			updateNetworkGuard(now)
			updateRemotePps()
			setNetText()
		end

		if Runtime.networkPaused and now>=Runtime.nextNetworkHoldTick then
			Runtime.nextNetworkHoldTick=now+0.05
			keepNetworkCharacterHold()
		end

		if not Runtime.networkPaused and Runtime.autoRebirth and not Runtime.rebirthInFlight and now>=Runtime.nextRebirth then
			Runtime.nextRebirth=now+0.05
			Runtime.rebirthInFlight=true
			local runToken=Runtime.rebirthToken
			task.spawn(function()
				local ok,err=xpcall(function()
					runRebirthAttempt(runToken)
				end,function(e)
					local trace=""
					if debug and type(debug.traceback)=="function" then trace="\n"..tostring(debug.traceback()) end
					return tostring(e)..trace
				end)
				Runtime.rebirthInFlight=false
				if not ok and Runtime.alive and Runtime.rebirthToken==runToken then
					Runtime.nextRebirth=os.clock()+1
					setStatus("AUTO REB ERROR: "..tostring(err):sub(1,90))
				end
			end)
		end

		if not Runtime.networkPaused and Runtime.autoSize and not Runtime.sizeInFlight and now>=Runtime.nextSize then
			Runtime.nextSize=now+0.25
			Runtime.sizeInFlight=true
			local requestedSize=Runtime.sizeTarget
			task.spawn(function()
				local ok,err=trySetSize(requestedSize)
				Runtime.sizeInFlight=false
				if not ok and Runtime.alive and Runtime.autoSize then
					setStatus("AUTO SIZE: "..tostring(err))
				end
			end)
		end

		if not Runtime.networkPaused and Runtime.kingLock and Runtime.kingCF and now>=Runtime.nextKingTick then
			Runtime.nextKingTick=now+0.25
			local r=root()

			if r then
				if Runtime.kingRoot~=r then
					-- Cancel every object/contact owned by the previous character
					-- before accepting the respawned root. Otherwise the cancelled
					-- coroutine can leave kingPresenceInFlight stuck forever.
					destroyKingPhysicalHold()
					releaseKingTouch(false)
					Runtime.kingPresenceToken=Runtime.kingPresenceToken+1
					Runtime.kingPresenceInFlight=false
					Runtime.kingRoot=r
					Runtime.kingSavedAnchored=r.Anchored
					if not Runtime.kingPresenceInFlight then
						task.spawn(function() triggerKingPresence(r) end)
					end
				else
					local position=Runtime.kingHoldPosition
					local gyro=Runtime.kingHoldGyro
					local holdAlive=position and position.Parent==r and gyro and gyro.Parent==r
					local drift=(r.Position-Runtime.kingCF.Position).Magnitude

					if r.Anchored or not holdAlive or drift>3 then
						if not Runtime.kingPresenceInFlight then
							task.spawn(function() triggerKingPresence(r) end)
						end
					else
						-- BodyMovers freeze the character without removing it from
						-- the server's unanchored physics simulation.
						r.Anchored=false
						position.Position=Runtime.kingCF.Position
						gyro.CFrame=Runtime.kingCF
						if now>=Runtime.nextKingTouchPulse then
							pulseKingTouch(findKingTriggerPart())
						end
					end
				end
			end
		end

		if not Runtime.networkPaused and Runtime.lockPosition and Runtime.positionCF and now>=Runtime.nextPosTick then
			Runtime.nextPosTick=now+0.05
			local r=root()

			if r then
				-- Keep normal position lock inside the replicated physics world.
				-- Anchoring only looks frozen locally and can suppress zone presence.
				r.Anchored=false
				r.CFrame=Runtime.positionCF
				r.AssemblyLinearVelocity=Vector3.new(0,0,0)
				r.AssemblyAngularVelocity=Vector3.new(0,0,0)
			end
		end

		if Runtime.mode=="bug" then
			-- Keep physical punching enabled; correct only after actual drift.
			if Runtime.lockRock and Runtime.lockCF then
				local r=root()
				if not r then
					if not Runtime.networkPaused then
						local expired=transientFailureExpired("bugRoot",now,2.5)
						if expired then stopMode("AUTO STOP: нет root после grace") end
					end
				elseif (r.Position-Runtime.lockCF.Position).Magnitude>1.25 then
					clearTransientFailure("bugRoot")
					local drift=(r.Position-Runtime.lockCF.Position).Magnitude
					if insideSelectedRockLockZone(r) then
						-- Physics may push the character from the center toward a valid edge.
						-- Follow that stable contact point instead of teleporting to center.
						Runtime.lockCF=r.CFrame
					elseif drift>8 then
						r.CFrame=Runtime.lockCF
						r.AssemblyLinearVelocity=Vector3.new(0,0,0)
						r.AssemblyAngularVelocity=Vector3.new(0,0,0)
					end
				else
					clearTransientFailure("bugRoot")
				end
			end

			if not Runtime.networkPaused and now>=Runtime.nextNearCheck then
				Runtime.nextNearCheck=now+0.35
				local near,why=nearSelectedRock()

				if not near then
					local expired=transientFailureExpired("rockNear",now,2.5)
					if expired then stopMode("AUTO STOP: "..tostring(why).." после grace") end
				else
					clearTransientFailure("rockNear")
				end
			end

			if not Runtime.networkPaused and Runtime.mode=="bug" and now>=Runtime.nextAction then
				local actionRate=effectiveRates()
				Runtime.nextAction=now+(1/actionRate)
				Runtime.punchCycle=Runtime.punchCycle+1

				if not Runtime.activeTool or Runtime.activeTool.Parent~=char() then
					local tool,msg=ensurePunchTool()
					Runtime.activeTool=tool
					if not tool then setStatus(msg) end
				end

				if Runtime.activeTool then
					safe(function() Runtime.activeTool:Activate() end)
				end

				-- One bounded direct remote attempt, never loops.
				tryPunchRemote()

				-- Touch on every bounded action so Delta can register either hand.
				oneTouch()
			end

			if not Runtime.networkPaused and now>=Runtime.nextCooldownSweep then
				Runtime.nextCooldownSweep=now+2
				clearCooldownsOnce(Runtime.activeTool)
			end

			if not Runtime.networkPaused and now>=Runtime.nextEquip then
				Runtime.nextEquip=now+1.5

				if not Runtime.activeTool or Runtime.activeTool.Parent~=char() then
					Runtime.activeTool=ensurePunchTool()
				end
			end
		elseif Runtime.mode=="train" then
			if not Runtime.networkPaused and now>=Runtime.nextAction then
				-- Match the validated punch cadence and its adaptive network throttle.
				local rate=effectiveRates()
				Runtime.nextAction=now+(1/rate)

				if Runtime.selectedTrain then
					if not Runtime.activeTool or Runtime.activeTool.Parent~=char() then
						Runtime.activeTool=ensureTrainTool(Runtime.selectedTrain)
					end

					if Runtime.activeTool then
						safe(function() Runtime.activeTool:Activate() end)
						tryTrainRemote()
					end
				end
			end

			if not Runtime.networkPaused and now>=Runtime.nextCooldownSweep then
				Runtime.nextCooldownSweep=now+2
				clearCooldownsOnce(Runtime.activeTool)
			end

			if not Runtime.networkPaused and now>=Runtime.nextEquip then
				Runtime.nextEquip=now+1.5

				if Runtime.selectedTrain then
					Runtime.activeTool=ensureTrainTool(Runtime.selectedTrain)
				end
			end
		end

		task.wait(0.015)
	end
end

-- ---------- ANTI AFK ----------

local antiAfkConn=addConn(lp.Idled:Connect(function()
	if not Runtime.antiAfkEnabled then return end

	safe(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end))

local function buildUI()
-- ---------- UI ----------

local gui=Instance.new("ScreenGui")
gui.Name=HUB_VERSION
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=999999
gui.Parent=playerGui
Runtime.uiRoot=gui

local THEME={
	Bg=Color3.fromRGB(11,17,27),
	Panel=Color3.fromRGB(18,27,40),
	Surface=Color3.fromRGB(24,34,49),
	SurfaceAlt=Color3.fromRGB(31,43,60),
	Accent=Color3.fromRGB(171,83,255),
	Accent2=Color3.fromRGB(226,104,255),
	Neon=Color3.fromRGB(86,190,255),
	Success=Color3.fromRGB(183,92,255),
	Danger=Color3.fromRGB(255,102,119),
	Text=Color3.fromRGB(232,239,247),
	Muted=Color3.fromRGB(184,190,208),
	Border=Color3.fromRGB(118,72,178),
	Warm=Color3.fromRGB(255,180,84),
}

local function corner(o,r)
	local c=Instance.new("UICorner")
	c.CornerRadius=UDim.new(0,r)
	c.Parent=o
end

local function stroke(o,color,thickness,transparency)
	local s=Instance.new("UIStroke")
	s.Color=color
	s.Thickness=thickness
	s.Transparency=transparency
	s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
	s.LineJoinMode=Enum.LineJoinMode.Round
	s.Parent=o
	return s
end

local function gradient(o,fromColor,toColor,rotation)
	local g=Instance.new("UIGradient")
	g.Color=ColorSequence.new(fromColor,toColor)
	g.Rotation=rotation or 0
	g.Parent=o
	return g
end

local function neonStroke(o,thickness,transparency)
	local s=stroke(o,THEME.Accent,thickness or 1.2,transparency or 0.42)
	gradient(s,THEME.Accent2,THEME.Neon,28)
	return s
end

local function label(parent,text,size,font,color)
	local l=Instance.new("TextLabel")
	l.Parent=parent
	l.BackgroundTransparency=1
	l.Text=text
	l.TextColor3=color or THEME.Text
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
	b.TextColor3=THEME.Text
	b.BackgroundColor3=color
	b.BackgroundTransparency=0.10
	b.BorderSizePixel=0
	b.AutoButtonColor=true
	b.Font=Enum.Font.GothamBlack
	b.TextSize=13
	corner(b,8)
	local edge=neonStroke(b,1,0.68)
	edge.Name="NeonEdge"
	return b
end

local function viewportSize()
	local camera=workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(800,600)
end

local function windowMetrics(viewport)
	local availableWidth=math.max(220,math.floor(viewport.X)-8)
	local availableHeight=math.max(240,math.floor(viewport.Y)-8)
	local mobile=viewport.X<=700 or viewport.Y<=500
	local minWidth=math.min(300,availableWidth)
	local minHeight=math.min(280,availableHeight)
	local widthRatio=mobile and 0.96 or 0.62
	local heightRatio=mobile and 0.96 or 0.68
	local defaultWidth=math.min(560,math.max(minWidth,math.floor(viewport.X*widthRatio)))
	local defaultHeight=math.min(410,math.max(minHeight,math.floor(viewport.Y*heightRatio)))
	return minWidth,minHeight,availableWidth,availableHeight,defaultWidth,defaultHeight
end

local initialViewport=viewportSize()
local minWindowWidth,minWindowHeight,maxWindowWidth,maxWindowHeight,defaultWidth,defaultHeight=windowMetrics(initialViewport)

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.fromOffset(defaultWidth,defaultHeight)
main.Position=UDim2.fromOffset(
	math.max(6,math.floor((initialViewport.X-defaultWidth)/2)),
	math.max(18,math.floor((initialViewport.Y-defaultHeight)/2))
)
main.BackgroundColor3=THEME.Bg
main.BackgroundTransparency=0.08
main.BorderSizePixel=0
main.Active=true
main.ClipsDescendants=true
corner(main,14)
local mainStroke=neonStroke(main,1.6,0.24)
gradient(main,THEME.Panel,THEME.Bg,125)

local topBar=Instance.new("Frame")
topBar.Parent=main
topBar.Size=UDim2.new(1,0,0,48)
topBar.BackgroundColor3=THEME.Panel
topBar.BackgroundTransparency=0.18
topBar.BorderSizePixel=0
topBar.Active=true
gradient(topBar,THEME.Panel,THEME.Surface,0)

local headerLine=Instance.new("Frame")
headerLine.Parent=topBar
headerLine.Size=UDim2.new(1,0,0,1)
headerLine.Position=UDim2.new(0,0,1,-1)
headerLine.BackgroundColor3=THEME.Border
headerLine.BackgroundTransparency=0.58
headerLine.BorderSizePixel=0

local brand=button(topBar,">_",THEME.SurfaceAlt)
brand.Size=UDim2.fromOffset(30,30)
brand.Position=UDim2.fromOffset(9,9)
brand.TextColor3=THEME.Accent
brand.TextSize=12

local title=label(topBar,"ROCK BUG HUB",14,Enum.Font.GothamBold,THEME.Text)
title.Size=UDim2.new(1,-130,0,20)
title.Position=UDim2.fromOffset(49,5)

local author=label(topBar,"УПРАВЛЕНИЕ СКРИПТОМ",8,Enum.Font.GothamBold,THEME.Muted)
author.Size=UDim2.new(1,-130,0,14)
author.Position=UDim2.fromOffset(50,26)

local closeBtn=button(topBar,"×",THEME.SurfaceAlt)
closeBtn.Size=UDim2.fromOffset(26,26)
closeBtn.Position=UDim2.new(1,-34,0,11)
closeBtn.TextColor3=THEME.Danger
closeBtn.TextSize=19

local minimizeBtn=button(topBar,"−",THEME.SurfaceAlt)
minimizeBtn.Size=UDim2.fromOffset(26,26)
minimizeBtn.Position=UDim2.new(1,-64,0,11)
minimizeBtn.TextColor3=THEME.Muted
minimizeBtn.TextSize=18

local rail=Instance.new("Frame")
rail.Parent=main
rail.Size=UDim2.new(0,82,1,-48)
rail.Position=UDim2.fromOffset(0,48)
rail.BackgroundColor3=THEME.Panel
rail.BackgroundTransparency=0.20
rail.BorderSizePixel=0
rail.ClipsDescendants=true

local railScroll=Instance.new("ScrollingFrame")
railScroll.Parent=rail
railScroll.Size=UDim2.new(1,0,1,-40)
railScroll.Position=UDim2.fromOffset(0,0)
railScroll.BackgroundTransparency=1
railScroll.BorderSizePixel=0
railScroll.Active=true
railScroll.ScrollingEnabled=true
railScroll.ScrollingDirection=Enum.ScrollingDirection.Y
railScroll.CanvasSize=UDim2.fromOffset(0,322)
railScroll.ScrollBarThickness=2
railScroll.ScrollBarImageColor3=THEME.Accent
railScroll.ScrollBarImageTransparency=0.18
railScroll.ElasticBehavior=Enum.ElasticBehavior.WhenScrollable

local railLine=Instance.new("Frame")
railLine.Parent=rail
railLine.Size=UDim2.new(0,1,1,0)
railLine.Position=UDim2.new(1,-1,0,0)
railLine.BackgroundColor3=THEME.Border
railLine.BackgroundTransparency=0.62
railLine.BorderSizePixel=0

local function styleTab(tab,y)
	tab.Size=UDim2.new(1,-12,0,52)
	tab.Position=UDim2.fromOffset(6,y)
	tab.TextSize=9
	tab.TextWrapped=true
	tab.BackgroundTransparency=0.52
	local tabStroke=neonStroke(tab,1.1,0.66)
	tabStroke.Name="TabStroke"

	local mark=Instance.new("Frame")
	mark.Name="ActiveMark"
	mark.Parent=tab
	mark.Size=UDim2.new(0,4,1,-12)
	mark.Position=UDim2.fromOffset(0,6)
	mark.BackgroundColor3=THEME.Accent
	mark.BorderSizePixel=0
	mark.Visible=false
	corner(mark,2)
end

local bugTab=button(railScroll,"КАМНИ\nАВТОФАРМ",THEME.Accent)
styleTab(bugTab,6)

local trainTab=button(railScroll,"КАЧ\nТРЕНИРОВКА",THEME.Surface)
styleTab(trainTab,62)

local rebTab=button(railScroll,"РЕБИРТ\nИ КИНГ",THEME.Surface)
styleTab(rebTab,118)

local killTab=button(railScroll,"PVP\nАВТОКИЛ",THEME.Surface)
styleTab(killTab,174)

local crystalTab=button(railScroll,"SHOP\nГЕМЫ",THEME.Surface)
styleTab(crystalTab,230)

local rescanBtn=button(railScroll,"ПЕРЕСЧИТАТЬ",THEME.SurfaceAlt)
rescanBtn.Size=UDim2.new(1,-12,0,28)
rescanBtn.Position=UDim2.fromOffset(6,286)
rescanBtn.TextSize=9

local panicBtn=button(rail,"СТОП",THEME.Danger)
panicBtn.Size=UDim2.new(1,-12,0,28)
panicBtn.Position=UDim2.new(0,6,1,-34)
panicBtn.TextSize=9

local content=Instance.new("Frame")
content.Parent=main
content.Size=UDim2.new(1,-82,1,-48)
content.Position=UDim2.fromOffset(82,48)
content.BackgroundColor3=THEME.Bg
content.BackgroundTransparency=0.38
content.BorderSizePixel=0
content.ClipsDescendants=true

local quickBar=Instance.new("Frame")
quickBar.Parent=content
quickBar.Size=UDim2.new(1,-12,0,64)
quickBar.Position=UDim2.fromOffset(6,5)
quickBar.BackgroundColor3=THEME.Surface
quickBar.BackgroundTransparency=0.14
quickBar.BorderSizePixel=0
corner(quickBar,10)
neonStroke(quickBar,1.2,0.52)
gradient(quickBar,THEME.Surface,THEME.Panel,0)

local quickTitle=label(quickBar,"⚡  ВАЖНОЕ",11,Enum.Font.GothamBold,THEME.Text)
quickTitle.Size=UDim2.new(1,-16,0,18)
quickTitle.Position=UDim2.fromOffset(8,3)

local quickBody=Instance.new("Frame")
quickBody.Parent=quickBar
quickBody.Size=UDim2.new(1,-12,0,34)
quickBody.Position=UDim2.fromOffset(6,24)
quickBody.BackgroundTransparency=1

local statusPanel=Instance.new("Frame")
statusPanel.Parent=content
statusPanel.Size=UDim2.new(1,-12,0,40)
statusPanel.Position=UDim2.new(0,6,1,-46)
statusPanel.BackgroundColor3=THEME.Surface
statusPanel.BackgroundTransparency=0.30
statusPanel.BorderSizePixel=0
corner(statusPanel,10)
neonStroke(statusPanel,1.1,0.58)

local statusTitle=label(statusPanel,"⌁  СТАТУС",8,Enum.Font.GothamBold,THEME.Accent)
statusTitle.Size=UDim2.new(0.34,-6,0,12)
statusTitle.Position=UDim2.fromOffset(6,1)

local serverUptime=label(statusPanel,"VIP-СЕРВЕР ~ 00:00:00",8,Enum.Font.GothamBold,THEME.Accent2)
serverUptime.Size=UDim2.new(0.66,-10,0,12)
serverUptime.Position=UDim2.new(0.34,4,0,1)
serverUptime.TextXAlignment=Enum.TextXAlignment.Right
serverUptime.TextWrapped=false
serverUptime.TextTruncate=Enum.TextTruncate.AtEnd

local status=label(statusPanel,"ГОТОВО",9,Enum.Font.GothamBold,THEME.Text)
status.Size=UDim2.new(0.62,-7,0,21)
status.Position=UDim2.fromOffset(4,14)
status.BackgroundColor3=THEME.SurfaceAlt
status.BackgroundTransparency=0.34
status.BorderSizePixel=0
status.TextXAlignment=Enum.TextXAlignment.Center
status.TextWrapped=false
status.TextTruncate=Enum.TextTruncate.AtEnd
corner(status,7)
neonStroke(status,1,0.66)

local net=label(statusPanel,"PING ? | УДАР 0/s",8,Enum.Font.GothamBold,THEME.Accent)
net.Size=UDim2.new(0.38,-5,0,21)
net.Position=UDim2.new(0.62,1,0,14)
net.BackgroundColor3=THEME.SurfaceAlt
net.BackgroundTransparency=0.34
net.BorderSizePixel=0
net.TextXAlignment=Enum.TextXAlignment.Center
net.TextWrapped=false
net.TextTruncate=Enum.TextTruncate.AtEnd
corner(net,7)
neonStroke(net,1,0.66)

Runtime.ui={status=status,net=net,uptime=serverUptime}

local function makePage(color)
	local page=Instance.new("ScrollingFrame")
	page.Parent=content
	page.Size=UDim2.new(1,-12,1,-126)
	page.Position=UDim2.fromOffset(6,75)
	page.BackgroundTransparency=1
	page.BorderSizePixel=0
	page.ScrollBarThickness=3
	page.ScrollBarImageColor3=color
	page.ScrollBarImageTransparency=0.12
	page.CanvasSize=UDim2.new(0,0,0,0)
	page.ScrollingDirection=Enum.ScrollingDirection.Y
	page.ScrollingEnabled=true
	page.Active=true
	page.ElasticBehavior=Enum.ElasticBehavior.WhenScrollable
	page.VerticalScrollBarInset=Enum.ScrollBarInset.ScrollBar
	return page
end

local bugPage=makePage(THEME.Accent)
local trainPage=makePage(THEME.Success)
trainPage.Visible=false
local rebPage=makePage(THEME.Accent2)
rebPage.Visible=false
local killPage=makePage(THEME.Danger)
killPage.Visible=false
local crystalPage=makePage(THEME.Neon)
crystalPage.Visible=false

local resizeHandle=button(main,"◢",THEME.SurfaceAlt)
resizeHandle.Size=UDim2.fromOffset(18,18)
resizeHandle.Position=UDim2.new(1,-18,1,-18)
resizeHandle.TextColor3=THEME.Accent
resizeHandle.TextSize=13
resizeHandle.BackgroundTransparency=0.42

local miniButton=button(gui,"RH\n+",THEME.Panel)
miniButton.Size=UDim2.fromOffset(42,42)
miniButton.Position=main.Position
miniButton.TextColor3=THEME.Accent
miniButton.TextSize=12
miniButton.Visible=false
miniButton.Active=true
miniButton.ZIndex=30
neonStroke(miniButton,1.5,0.18)
gradient(miniButton,THEME.Surface,THEME.Bg,135)

local function listLayout(frame)
	local pad=Instance.new("UIPadding")
	pad.Parent=frame
	pad.PaddingTop=UDim.new(0,2)
	pad.PaddingBottom=UDim.new(0,2)
	pad.PaddingLeft=UDim.new(0,1)
	pad.PaddingRight=UDim.new(0,1)

	local list=Instance.new("UIListLayout")
	list.Parent=frame
	list.SortOrder=Enum.SortOrder.LayoutOrder
	list.Padding=UDim.new(0,5)
	return list
end

local bugList=listLayout(bugPage)
local trainList=listLayout(trainPage)
local rebList=listLayout(rebPage)
local killList=listLayout(killPage)
local crystalList=listLayout(crystalPage)

local function updateCanvas()
	task.defer(function()
		bugPage.CanvasSize=UDim2.new(0,0,0,bugList.AbsoluteContentSize.Y+20)
		trainPage.CanvasSize=UDim2.new(0,0,0,trainList.AbsoluteContentSize.Y+20)
		rebPage.CanvasSize=UDim2.new(0,0,0,rebList.AbsoluteContentSize.Y+20)
		killPage.CanvasSize=UDim2.new(0,0,0,killList.AbsoluteContentSize.Y+20)
		crystalPage.CanvasSize=UDim2.new(0,0,0,crystalList.AbsoluteContentSize.Y+20)
	end)
end

addConn(bugList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
addConn(trainList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
addConn(rebList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
addConn(killList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
addConn(crystalList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))

local function card(parent,height)
	local f=Instance.new("Frame")
	f.Parent=parent
	f.Size=UDim2.new(1,0,0,height)
	f.BackgroundColor3=THEME.Surface
	f.BackgroundTransparency=0.16
	f.BorderSizePixel=0
	corner(f,10)
	neonStroke(f,1.1,0.48)
	gradient(f,THEME.Surface,THEME.Bg,115)
	return f
end

local function makeFeaturePanel(parent,titleText,height,columns)
	local panel=card(parent,height)
	panel.LayoutOrder=1

	local icon=label(panel,"ϟ",14,Enum.Font.GothamBold,THEME.Accent)
	icon.Size=UDim2.fromOffset(20,20)
	icon.Position=UDim2.fromOffset(8,4)
	icon.TextXAlignment=Enum.TextXAlignment.Center

	local heading=label(panel,titleText,12,Enum.Font.GothamBold,THEME.Text)
	heading.Size=UDim2.new(1,-40,0,20)
	heading.Position=UDim2.fromOffset(32,4)

	local body=Instance.new("Frame")
	body.Parent=panel
	body.Size=UDim2.new(1,-14,1,-34)
	body.Position=UDim2.fromOffset(7,28)
	body.BackgroundTransparency=1

	local grid=Instance.new("UIGridLayout")
	grid.Parent=body
	grid.SortOrder=Enum.SortOrder.LayoutOrder
	grid.CellPadding=UDim2.fromOffset(5,5)
	grid.CellSize=UDim2.new(1/(columns or 2),-4,0,50)
	return panel,body,grid
end

local function makeSettingsPanel(parent,titleText,height)
	local panel=card(parent,height)

	local icon=label(panel,"☷",13,Enum.Font.GothamBold,THEME.Accent)
	icon.Size=UDim2.fromOffset(20,20)
	icon.Position=UDim2.fromOffset(8,4)
	icon.TextXAlignment=Enum.TextXAlignment.Center

	local heading=label(panel,titleText,12,Enum.Font.GothamBold,THEME.Text)
	heading.Size=UDim2.new(1,-40,0,20)
	heading.Position=UDim2.fromOffset(32,4)

	local body=Instance.new("Frame")
	body.Parent=panel
	body.Size=UDim2.new(1,-14,1,-34)
	body.Position=UDim2.fromOffset(7,28)
	body.BackgroundTransparency=1

	local list=Instance.new("UIListLayout")
	list.Parent=body
	list.SortOrder=Enum.SortOrder.LayoutOrder
	list.Padding=UDim.new(0,3)
	return panel,body,list
end

local function makeSlider(parent,name,desc,initial,callback)
	local row=Instance.new("TextButton")
	row.Parent=parent
	row.Size=UDim2.new(1,0,0,44)
	row.Text=""
	row.AutoButtonColor=false
	row.BackgroundColor3=THEME.Surface
	row.BackgroundTransparency=0.22
	row.BorderSizePixel=0
	corner(row,6)
	neonStroke(row,1,0.72)

	local n=label(row,name,11,Enum.Font.GothamBold,THEME.Text)
	n.Size=UDim2.new(1,-62,0,16)
	n.Position=UDim2.new(0,8,0,3)

	local d=label(row,desc,8,Enum.Font.Gotham,THEME.Muted)
	d.Size=UDim2.new(1,-62,0,15)
	d.Position=UDim2.new(0,8,0,21)

	local track=Instance.new("Frame")
	track.Parent=row
	track.Size=UDim2.new(0,44,0,22)
	track.Position=UDim2.new(1,-50,0,11)
	track.BorderSizePixel=0
	track.BackgroundTransparency=0.04
	corner(track,13)

	local knob=Instance.new("Frame")
	knob.Parent=track
	knob.Size=UDim2.new(0,16,0,16)
	knob.Position=UDim2.new(0,3,0,3)
	knob.BackgroundColor3=THEME.Text
	knob.BorderSizePixel=0
	corner(knob,10)

	local state=initial and true or false
	local api={}

	local function paint()
		if state then
			track.BackgroundColor3=THEME.Success
			knob.Position=UDim2.new(1,-19,0,3)
		else
			track.BackgroundColor3=THEME.SurfaceAlt
			knob.Position=UDim2.new(0,3,0,3)
		end
	end

	function api.Set(v,silent)
		state=v and true or false
		paint()
		if callback and not silent then callback(state,api) end
	end

	function api.Get()
		return state
	end

	addConn(row.Activated:Connect(function()
		api.Set(not state,false)
	end))

	paint()
	return api,row
end

local function makePinnedToggle(parent,name,initial,callback)
	local row=Instance.new("TextButton")
	row.Parent=parent
	row.Text=""
	row.AutoButtonColor=false
	row.BackgroundColor3=THEME.SurfaceAlt
	row.BackgroundTransparency=0.18
	row.BorderSizePixel=0
	corner(row,8)
	local rowStroke=neonStroke(row,1.2,0.52)

	local glyph=label(row,name=="АНТИ-AFK" and "♢" or "◌",15,Enum.Font.GothamBold,THEME.Accent)
	glyph.Size=UDim2.fromOffset(18,20)
	glyph.Position=UDim2.fromOffset(4,11)
	glyph.TextXAlignment=Enum.TextXAlignment.Center

	local n=label(row,name,10,Enum.Font.GothamBold,THEME.Text)
	n.Size=UDim2.new(1,-31,1,0)
	n.Position=UDim2.fromOffset(25,0)

	local state=initial and true or false
	local api={}
	local function paint()
		row.BackgroundColor3=state and THEME.SurfaceAlt or THEME.Surface
		row.BackgroundTransparency=state and 0.08 or 0.30
		n.TextColor3=state and THEME.Text or THEME.Muted
		rowStroke.Color=state and THEME.Accent or THEME.Border
		rowStroke.Thickness=state and 2.2 or 1.1
		rowStroke.Transparency=state and 0.02 or 0.62
		glyph.TextColor3=state and THEME.Accent2 or THEME.Muted
	end

	function api.Set(v,silent)
		state=v and true or false
		paint()
		if callback and not silent then callback(state,api) end
	end

	function api.Get()
		return state
	end

	addConn(row.Activated:Connect(function()
		api.Set(not state,false)
	end))

	paint()
	return api,row
end

local function makeFeatureToggle(parent,iconText,name,desc,initial,callback)
	local tile=Instance.new("TextButton")
	tile.Parent=parent
	tile.Text=""
	tile.AutoButtonColor=false
	tile.BackgroundColor3=THEME.SurfaceAlt
	tile.BackgroundTransparency=0.16
	tile.BorderSizePixel=0
	corner(tile,8)
	local tileStroke=neonStroke(tile,1.2,0.50)

	local glyph=label(tile,iconText,16,Enum.Font.GothamBold,THEME.Text)
	glyph.Size=UDim2.fromOffset(20,16)
	glyph.Position=UDim2.new(0.5,-10,0,2)
	glyph.TextXAlignment=Enum.TextXAlignment.Center

	local n=label(tile,name,10,Enum.Font.GothamBold,THEME.Text)
	n.Size=UDim2.new(1,-10,0,15)
	n.Position=UDim2.fromOffset(5,18)
	n.TextXAlignment=Enum.TextXAlignment.Center

	local d=label(tile,desc,8,Enum.Font.Gotham,THEME.Muted)
	d.Size=UDim2.new(1,-10,0,12)
	d.Position=UDim2.fromOffset(5,33)
	d.TextXAlignment=Enum.TextXAlignment.Center

	local state=initial and true or false
	local api={}
	local function paint()
		tile.BackgroundColor3=state and THEME.SurfaceAlt or THEME.Surface
		tile.BackgroundTransparency=state and 0.06 or 0.22
		tileStroke.Color=state and THEME.Accent or THEME.Border
		tileStroke.Thickness=state and 2.2 or 1.1
		tileStroke.Transparency=state and 0.02 or 0.58
		glyph.TextColor3=state and THEME.Accent or THEME.Text
		n.TextColor3=state and THEME.Text or THEME.Muted
	end

	function api.Set(v,silent)
		state=v and true or false
		paint()
		if callback and not silent then callback(state,api) end
	end

	function api.Get()
		return state
	end

	addConn(tile.Activated:Connect(function()
		api.Set(not state,false)
	end))

	paint()
	return api,tile
end

local function makeNumberInput(parent,name,desc,initial,callback)
	local row=Instance.new("Frame")
	row.Parent=parent
	row.Size=UDim2.new(1,0,0,44)
	row.BackgroundColor3=THEME.Surface
	row.BackgroundTransparency=0.22
	row.BorderSizePixel=0
	corner(row,6)
	neonStroke(row,1,0.72)

	local n=label(row,name,11,Enum.Font.GothamBold,THEME.Text)
	n.Size=UDim2.new(1,-70,0,16)
	n.Position=UDim2.new(0,8,0,3)

	local d=label(row,desc,8,Enum.Font.Gotham,THEME.Muted)
	d.Size=UDim2.new(1,-70,0,15)
	d.Position=UDim2.new(0,8,0,21)

	local box=Instance.new("TextBox")
	box.Parent=row
	box.Size=UDim2.new(0,58,0,26)
	box.Position=UDim2.new(1,-64,0,9)
	box.BackgroundColor3=THEME.SurfaceAlt
	box.BackgroundTransparency=0.05
	box.BorderSizePixel=0
	box.TextColor3=THEME.Text
	box.PlaceholderColor3=THEME.Muted
	box.PlaceholderText="1"
	box.ClearTextOnFocus=false
	box.Font=Enum.Font.GothamBlack
	box.TextSize=12
	box.Text=tostring(initial or 1)
	corner(box,10)
	neonStroke(box,1.2,0.34)

	local value=tonumber(initial) or 1
	local api={}

	local function commit()
		local parsed=tonumber((tostring(box.Text):gsub(",",".")))
		if not parsed then
			box.Text=tostring(value)
			setStatus(name..": введи число")
			return
		end

		value=math.clamp(parsed,0.1,1000)
		box.Text=tostring(value)
		if callback then callback(value,api) end
	end

	function api.Get()
		return value
	end

	function api.Set(v,silent)
		local parsed=tonumber(v)
		if not parsed then return end
		value=math.clamp(parsed,0.1,1000)
		box.Text=tostring(value)
		if callback and not silent then callback(value,api) end
	end

	addConn(box.FocusLost:Connect(commit))
	return api,row
end

local function makeSelectionRow(parent,titleText,initialText,callback)
	local row=Instance.new("TextButton")
	row.Parent=parent
	row.Size=UDim2.new(1,0,0,32)
	row.Text=""
	row.AutoButtonColor=true
	row.BackgroundColor3=THEME.Surface
	row.BackgroundTransparency=0.20
	row.BorderSizePixel=0
	corner(row,7)
	local edge=neonStroke(row,1,0.66)

	local titleLabel=label(row,titleText,8,Enum.Font.GothamBlack,THEME.Accent2)
	titleLabel.Size=UDim2.new(0.30,-7,1,0)
	titleLabel.Position=UDim2.fromOffset(7,0)

	local valueLabel=label(row,initialText or "ВЫБРАТЬ",9,Enum.Font.GothamBold,THEME.Text)
	valueLabel.Size=UDim2.new(0.70,-28,1,0)
	valueLabel.Position=UDim2.new(0.30,0,0,0)
	valueLabel.TextXAlignment=Enum.TextXAlignment.Right
	valueLabel.TextWrapped=false
	valueLabel.TextTruncate=Enum.TextTruncate.AtEnd

	local arrow=label(row,"›",16,Enum.Font.GothamBlack,THEME.Accent)
	arrow.Size=UDim2.fromOffset(20,32)
	arrow.Position=UDim2.new(1,-22,0,0)
	arrow.TextXAlignment=Enum.TextXAlignment.Center

	addConn(row.Activated:Connect(function()
		edge.Transparency=0.08
		task.defer(function() if edge.Parent then edge.Transparency=0.66 end end)
		if callback then callback() end
	end))

	return {
		Row=row,
		Set=function(value) valueLabel.Text=tostring(value or "ВЫБРАТЬ") end,
		Get=function() return valueLabel.Text end,
	}
end

-- One modal picker for players, crystals, pets and auras. The list has search,
-- touch scrolling and a persistent neon selection frame.
local pickerShade=Instance.new("TextButton")
pickerShade.Parent=main
pickerShade.Size=UDim2.new(1,0,1,0)
pickerShade.BackgroundColor3=Color3.fromRGB(3,5,12)
pickerShade.BackgroundTransparency=0.16
pickerShade.BorderSizePixel=0
pickerShade.Text=""
pickerShade.AutoButtonColor=false
pickerShade.Visible=false
pickerShade.ZIndex=80

local pickerPanel=Instance.new("Frame")
pickerPanel.Parent=pickerShade
pickerPanel.Size=UDim2.new(1,-34,1,-46)
pickerPanel.Position=UDim2.fromOffset(17,23)
pickerPanel.BackgroundColor3=THEME.Bg
pickerPanel.BackgroundTransparency=0.02
pickerPanel.BorderSizePixel=0
pickerPanel.ZIndex=81
corner(pickerPanel,14)
neonStroke(pickerPanel,2,0.04)
gradient(pickerPanel,THEME.Panel,THEME.Bg,125)

local pickerTitle=label(pickerPanel,"ВЫБОР",13,Enum.Font.GothamBlack,THEME.Text)
pickerTitle.Size=UDim2.new(1,-54,0,36)
pickerTitle.Position=UDim2.fromOffset(12,3)
pickerTitle.ZIndex=82

local pickerClose=button(pickerPanel,"×",THEME.SurfaceAlt)
pickerClose.Size=UDim2.fromOffset(30,30)
pickerClose.Position=UDim2.new(1,-38,0,7)
pickerClose.TextColor3=THEME.Danger
pickerClose.TextSize=18
pickerClose.ZIndex=83

local pickerSearch=Instance.new("TextBox")
pickerSearch.Parent=pickerPanel
pickerSearch.Size=UDim2.new(1,-20,0,32)
pickerSearch.Position=UDim2.fromOffset(10,43)
pickerSearch.BackgroundColor3=THEME.SurfaceAlt
pickerSearch.BackgroundTransparency=0.08
pickerSearch.BorderSizePixel=0
pickerSearch.ClearTextOnFocus=false
pickerSearch.PlaceholderText="Поиск..."
pickerSearch.PlaceholderColor3=THEME.Muted
pickerSearch.Text=""
pickerSearch.TextColor3=THEME.Text
pickerSearch.Font=Enum.Font.GothamBold
pickerSearch.TextSize=11
pickerSearch.TextXAlignment=Enum.TextXAlignment.Left
pickerSearch.ZIndex=82
corner(pickerSearch,8)
neonStroke(pickerSearch,1.2,0.48)
local pickerSearchPad=Instance.new("UIPadding")
pickerSearchPad.Parent=pickerSearch
pickerSearchPad.PaddingLeft=UDim.new(0,10)
pickerSearchPad.PaddingRight=UDim.new(0,10)

local pickerList=Instance.new("ScrollingFrame")
pickerList.Parent=pickerPanel
pickerList.Size=UDim2.new(1,-20,1,-132)
pickerList.Position=UDim2.fromOffset(10,82)
pickerList.BackgroundColor3=THEME.Bg
pickerList.BackgroundTransparency=0.10
pickerList.BorderSizePixel=0
pickerList.ScrollBarThickness=4
pickerList.ScrollBarImageColor3=THEME.Accent
pickerList.CanvasSize=UDim2.new(0,0,0,0)
pickerList.ScrollingDirection=Enum.ScrollingDirection.Y
pickerList.ZIndex=82
pickerList.Active=true
corner(pickerList,10)
neonStroke(pickerList,1,0.68)

local pickerPadding=Instance.new("UIPadding")
pickerPadding.Parent=pickerList
pickerPadding.PaddingTop=UDim.new(0,6)
pickerPadding.PaddingBottom=UDim.new(0,6)
pickerPadding.PaddingLeft=UDim.new(0,6)
pickerPadding.PaddingRight=UDim.new(0,6)

local pickerLayout=Instance.new("UIListLayout")
pickerLayout.Parent=pickerList
pickerLayout.SortOrder=Enum.SortOrder.LayoutOrder
pickerLayout.Padding=UDim.new(0,5)

local pickerDone=button(pickerPanel,"ГОТОВО",THEME.SurfaceAlt)
pickerDone.Size=UDim2.new(1,-20,0,34)
pickerDone.Position=UDim2.new(0,10,1,-42)
pickerDone.ZIndex=83

local pickerState=nil
local pickerItems={}
local pickerItemConnections={}

local function clearPickerItems()
	for _,connection in ipairs(pickerItemConnections) do
		safe(function() connection:Disconnect() end)
	end
	pickerItemConnections={}
	for _,item in ipairs(pickerItems) do
		if item.Parent then item:Destroy() end
	end
	pickerItems={}
end

local function closePicker()
	pickerState=nil
	pickerShade.Visible=false
	pickerSearch.Text=""
	clearPickerItems()
end

local function renderPicker(resetScroll)
	local oldCanvas=pickerList.CanvasPosition
	clearPickerItems()
	if not pickerState then return end

	local query=string.lower(tostring(pickerSearch.Text or ""))
	local visibleCount=0
	for _,option in ipairs(pickerState.options) do
		local id=tostring(option.id or option.label)
		local hay=string.lower(tostring(option.label or "").." "..tostring(option.sub or ""))
		if query=="" or hay:find(query,1,true) then
			visibleCount=visibleCount+1
			local chosen=pickerState.selected[id]==true
			local item=button(pickerList,"",chosen and THEME.SurfaceAlt or THEME.Surface)
			item.Size=UDim2.new(1,-2,0,45)
			item.LayoutOrder=visibleCount
			item.ZIndex=83
			item.BackgroundTransparency=chosen and 0.02 or 0.20
			local itemStroke=item:FindFirstChild("NeonEdge")
			if itemStroke then
				itemStroke.Transparency=chosen and 0.02 or 0.66
				itemStroke.Thickness=chosen and 2 or 1
			end

			local nameLabel=label(item,option.label,10,Enum.Font.GothamBlack,chosen and THEME.Accent2 or THEME.Text)
			nameLabel.Size=UDim2.new(1,-48,0,20)
			nameLabel.Position=UDim2.fromOffset(9,3)
			nameLabel.ZIndex=84
			local subLabel=label(item,option.sub or "",8,Enum.Font.Gotham,THEME.Muted)
			subLabel.Size=UDim2.new(1,-48,0,16)
			subLabel.Position=UDim2.fromOffset(9,23)
			subLabel.ZIndex=84
			local marker=label(item,chosen and "ON" or "›",9,Enum.Font.GothamBlack,chosen and THEME.Accent2 or THEME.Muted)
			marker.Size=UDim2.fromOffset(34,45)
			marker.Position=UDim2.new(1,-40,0,0)
			marker.TextXAlignment=Enum.TextXAlignment.Center
			marker.ZIndex=84

			local itemConnection=item.Activated:Connect(function()
				if not pickerState then return end
				if pickerState.multiple then
					pickerState.selected[id]=not pickerState.selected[id]
					renderPicker(false)
				else
					local done=pickerState.onDone
					closePicker()
					if done then done(option) end
				end
			end)
			table.insert(pickerItemConnections,itemConnection)
			table.insert(pickerItems,item)
		end
	end

	if visibleCount==0 then
		local empty=label(pickerList,"НИЧЕГО НЕ НАЙДЕНО",10,Enum.Font.GothamBold,THEME.Muted)
		empty.Size=UDim2.new(1,-2,0,42)
		empty.LayoutOrder=1
		empty.TextXAlignment=Enum.TextXAlignment.Center
		empty.ZIndex=83
		table.insert(pickerItems,empty)
	end

	pickerList.CanvasSize=UDim2.new(0,0,0,math.max(54,visibleCount*50+12))
	if resetScroll then
		pickerList.CanvasPosition=Vector2.new(0,0)
	else
		task.defer(function()
			if pickerList.Parent then pickerList.CanvasPosition=oldCanvas end
		end)
	end
	pickerDone.Text=pickerState.multiple and ("ГОТОВО • "..selectedCount(pickerState.selected)) or "ЗАКРЫТЬ"
end

local function openPicker(titleText,options,config)
	config=config or {}
	local selected={}
	for id,enabled in pairs(config.selected or {}) do
		if enabled then selected[tostring(id)]=true end
	end
	pickerState={
		options=options or {},
		multiple=config.multiple==true,
		selected=selected,
		onDone=config.onDone,
	}
	pickerTitle.Text=titleText
	pickerSearch.Text=""
	pickerShade.Visible=true
	renderPicker(true)
end

addConn(pickerClose.Activated:Connect(closePicker))
addConn(pickerDone.Activated:Connect(function()
	if not pickerState then return end
	local state=pickerState
	if state.multiple and state.onDone then state.onDone(state.selected) end
	closePicker()
end))
addConn(pickerSearch:GetPropertyChangedSignal("Text"):Connect(function()
	if pickerState then renderPicker(true) end
end))

Runtime.closePicker=closePicker

-- BUG PAGE

local bugFeaturePanel,bugFeatureBody=makeFeaturePanel(bugPage,"КАМЕНЬ И УДАРЫ",86,3)
bugFeaturePanel.LayoutOrder=1
local bugSettingsPanel,bugSettingsBody=makeSettingsPanel(bugPage,"ПОДБОР КАМНЯ",141)
bugSettingsPanel.LayoutOrder=2

local selectCard=card(bugSettingsBody,66)
selectCard.LayoutOrder=1
local selectTitle=label(selectCard,"АВТОПОДБОР ПО РЕБЁРТАМ",8,Enum.Font.GothamBold,THEME.Accent2)
selectTitle.Size=UDim2.new(1,-16,0,13)
selectTitle.Position=UDim2.new(0,8,0,3)

local selectName=label(selectCard,"-",10,Enum.Font.GothamBold,THEME.Warm)
selectName.Size=UDim2.new(1,-16,0,17)
selectName.Position=UDim2.new(0,8,0,16)

local calcStats=label(selectCard,"Ребёрты: -  •  XP/удар: -  •  цель: -  •  ударов: -",8,Enum.Font.Gotham,THEME.Text)
calcStats.Size=UDim2.new(1,-16,0,27)
calcStats.Position=UDim2.new(0,8,0,34)
calcStats.TextYAlignment=Enum.TextYAlignment.Top

Runtime.ui.autoRockTitle=selectTitle
Runtime.ui.autoRockName=selectName
Runtime.ui.autoRockStats=calcStats

local rockCard=card(bugSettingsBody,38)
rockCard.LayoutOrder=2
local currentRockLabel=label(rockCard,"камень не выбран",10,Enum.Font.GothamBold,THEME.Text)
currentRockLabel.Size=UDim2.new(1,-16,0,14)
currentRockLabel.Position=UDim2.fromOffset(8,2)
currentRockLabel.TextXAlignment=Enum.TextXAlignment.Center

local rockScale=Instance.new("TextButton")
rockScale.Parent=rockCard
rockScale.Size=UDim2.new(1,-16,0,17)
rockScale.Position=UDim2.fromOffset(8,17)
rockScale.Text=""
rockScale.AutoButtonColor=false
rockScale.BackgroundTransparency=1
rockScale.BorderSizePixel=0
rockScale.Active=true

local rockTrack=Instance.new("Frame")
rockTrack.Parent=rockScale
rockTrack.Size=UDim2.new(1,0,0,4)
rockTrack.Position=UDim2.new(0,0,0.5,-2)
rockTrack.BackgroundColor3=THEME.Border
rockTrack.BackgroundTransparency=0.34
rockTrack.BorderSizePixel=0
corner(rockTrack,3)

local rockFill=Instance.new("Frame")
rockFill.Parent=rockTrack
rockFill.Size=UDim2.new(0,0,1,0)
rockFill.BackgroundColor3=THEME.Accent
rockFill.BorderSizePixel=0
corner(rockFill,3)
gradient(rockFill,THEME.Accent2,THEME.Neon,0)

for i=1,#ROCKS do
	local tick=Instance.new("Frame")
	tick.Parent=rockTrack
	tick.Size=UDim2.fromOffset(1,8)
	tick.Position=UDim2.new((i-1)/(#ROCKS-1),0,0.5,-4)
	tick.AnchorPoint=Vector2.new(0.5,0)
	tick.BackgroundColor3=THEME.Text
	tick.BackgroundTransparency=0.42
	tick.BorderSizePixel=0
end

local rockKnob=Instance.new("Frame")
rockKnob.Parent=rockTrack
rockKnob.Size=UDim2.fromOffset(12,12)
rockKnob.AnchorPoint=Vector2.new(0.5,0.5)
rockKnob.Position=UDim2.new(0,0,0.5,0)
rockKnob.BackgroundColor3=THEME.Text
rockKnob.BorderSizePixel=0
corner(rockKnob,6)
neonStroke(rockKnob,2,0.04)

local rockButtonConnections={}
local rockScaleDragging=false

local function disconnectRockButtonConnections()
	for _,connection in ipairs(rockButtonConnections) do
		safe(function() connection:Disconnect() end)
	end

	rockButtonConnections={}
end

local function currentRockIndex()
	for i,row in ipairs(ROCKS) do
		if Runtime.selectedRock and Runtime.selectedRock.id==row.id then return i end
	end
	return #ROCKS
end

local refreshRockList

local function chooseManualRock(index)
	index=math.clamp(math.floor(tonumber(index) or #ROCKS),1,#ROCKS)
	local row=ROCKS[index]
	Runtime.autoRockSelection=false
	Runtime.selectedRock=row
	selectTitle.Text="РУЧНАЯ НАСТРОЙКА"
	selectName.Text=row.label.."  •  множитель "..tostring(row.mult)

	local rebs=Runtime.autoRockCalc and Runtime.autoRockCalc.rebirths
	if rebs then
		local xp40=(rebs+20)*math.floor(row.mult*40+0.5)
		calcStats.Text=("Ребёрты: %d  •  XP/удар: %s  •  ручной выбор"):format(rebs,compactXp(xp40))
	else
		calcStats.Text="Ребёрты не найдены  •  ручной выбор"
	end

	refreshRockList()
	setStatus("Камень: "..row.label)
end

refreshRockList=function()
	local row=Runtime.selectedRock
	if not row then
		currentRockLabel.Text="камень не выбран"
		rockFill.Size=UDim2.new(0,0,1,0)
		rockKnob.Position=UDim2.new(0,0,0.5,0)
		return
	end

	local info=rockCache[row.req]
	local index=currentRockIndex()
	local ratio=(index-1)/(#ROCKS-1)
	currentRockLabel.Text=row.label..(info and "  —  доступен" or "  —  не найден")
	rockFill.Size=UDim2.new(ratio,0,1,0)
	rockKnob.Position=UDim2.new(ratio,0,0.5,0)
end

local function rockIndexFromX(x)
	local width=math.max(1,rockTrack.AbsoluteSize.X)
	local ratio=math.clamp((x-rockTrack.AbsolutePosition.X)/width,0,1)
	return math.clamp(math.floor(ratio*(#ROCKS-1)+1.5),1,#ROCKS)
end

local function selectRockFromInput(input)
	if input and input.Position then chooseManualRock(rockIndexFromX(input.Position.X)) end
end

table.insert(rockButtonConnections,rockScale.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		rockScaleDragging=true
		selectRockFromInput(input)
	end
end))

table.insert(rockButtonConnections,UserInputService.InputChanged:Connect(function(input)
	if rockScaleDragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
		selectRockFromInput(input)
	end
end))

table.insert(rockButtonConnections,UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		rockScaleDragging=false
	end
end))

Runtime.refreshRockList=refreshRockList

local lockRockSlider
local bugSlider

lockRockSlider=makeFeatureToggle(bugFeatureBody,"◇","У КАМНЯ","не даёт отойти",false,function(on,api)
	if on then
		local ok,err=teleportInsideSelected()

		if not ok then
			setStatus("LOCK: "..tostring(err))
			api.Set(false,true)
			return
		end

		Runtime.lockRock=true
		Runtime.nextLockTick=0
		setStatus("ФИКСАЦИЯ: включена")
	else
		if Runtime.mode=="bug" then
			stopMode("ФИКСАЦИЯ И АВТОУДАР: выключены")
		else
			Runtime.lockRock=false
			Runtime.lockCF=nil
			restoreCharacterLock()
			setStatus("ФИКСАЦИЯ: выключена")
		end
	end
end)

bugSlider=makeFeatureToggle(bugFeatureBody,"▷","АВТОУДАР","бьёт автоматически",false,function(on,api)
	if on then
		if not startBug() then
			api.Set(false,true)
		end
	else
		stopMode("АВТОУДАР: выключен")
	end
end)

Runtime.leverRefs.lockRock=lockRockSlider
Runtime.leverRefs.bug=bugSlider

local remoteSlider=makeFeatureToggle(bugFeatureBody,"◎","БЫСТРЫЙ УДАР","ускоряет команды",true,function(on)
	Runtime.directRemoteEnabled=on
	setStatus("УСКОРЕНИЕ: "..(on and "включено" or "выключено"))
end)

-- TRAIN PAGE

local trainFeaturePanel,trainFeatureBody=makeFeaturePanel(trainPage,"ВИД ТРЕНИРОВКИ",139,3)
trainFeaturePanel.LayoutOrder=1
local trainSettingsPanel,trainSettingsBody=makeFeaturePanel(trainPage,"НАСТРОЙКИ ТРЕНИРОВКИ",86,3)
trainSettingsPanel.LayoutOrder=2

local lockPosSlider=makeFeatureToggle(trainSettingsBody,"◇","ЗАКРЕПИТЬСЯ","держит на месте",false,function(on,api)
	if on then
		local r=root()

		if not r then
			setStatus("LOCK POSITION: нет root")
			api.Set(false,true)
			return
		end

		disableKingLock()
		r.Anchored=false
		Runtime.positionCF=r.CFrame
		Runtime.lockPosition=true
		Runtime.nextPosTick=0
		if Runtime.leverRefs.kingLock then Runtime.leverRefs.kingLock.Set(false,true) end
		setStatus("ПОЗИЦИЯ: зафиксирована")
	else
		Runtime.lockPosition=false
		Runtime.positionCF=nil
		setStatus("ПОЗИЦИЯ: свободна")
	end
end)

Runtime.leverRefs.lockPosition=lockPosSlider

local visualSlider=makeFeatureToggle(trainSettingsBody,"◫","ЛЁГКАЯ ГРАФИКА","снижает нагрузку",false,function(on)
	setVisualLow(on)
end)

Runtime.leverRefs.visualLow=visualSlider

local afkSlider,afkQuickRow=makePinnedToggle(quickBody,"АНТИ-AFK",true,function(on)
	Runtime.antiAfkEnabled=on
	setStatus("АНТИ-AFK: "..(on and "включён" or "выключен"))
end)
afkQuickRow.Size=UDim2.new(0.5,-3,1,0)
afkQuickRow.Position=UDim2.fromOffset(0,0)

local netGuardSlider,netQuickRow=makePinnedToggle(quickBody,"ЗАЩИТА СЕТИ",true,function(on)
	Runtime.netGuardEnabled=on
	if not on then
		Runtime.manualNetworkHold=false
		if Runtime.leverRefs.wifiHold then Runtime.leverRefs.wifiHold.Set(false,true) end
		leaveNetworkHold(os.clock(),"OFF")
		setStatus("ЗАЩИТА СЕТИ: выключена")
	else
		Runtime.networkBadSamples=0
		Runtime.networkGoodSamples=0
		setStatus("ЗАЩИТА СЕТИ: включена")
	end
end)
netQuickRow.Size=UDim2.new(0.5,-3,1,0)
netQuickRow.Position=UDim2.new(0.5,3,0,0)

Runtime.leverRefs.netGuard=netGuardSlider

local wifiHoldSlider=makeFeatureToggle(trainSettingsBody,"◌","РУЧНАЯ ПАУЗА","удерживает клиент",false,function(on)
	Runtime.manualNetworkHold=on
	if on then
		Runtime.netGuardEnabled=true
		if Runtime.leverRefs.netGuard then Runtime.leverRefs.netGuard.Set(true,true) end
		enterNetworkHold("manual WiFi hold",os.clock())
		Runtime.networkState="MANUAL HOLD"
		setStatus("ПАУЗА СЕТИ: включена")
	else
		leaveNetworkHold(os.clock(),"MANUAL RELEASE")
		setStatus("ПАУЗА СЕТИ: выключена")
	end
end)

Runtime.leverRefs.wifiHold=wifiHoldSlider

Runtime.leverRefs.train={}

local trainIcons={
	Punch="▷",
	Weight="▣",
	Push="▽",
	Sit="⌁",
	Hand="♢",
	Tread="↗",
}

local trainNames={
	Punch="УДАРЫ",
	Weight="ГАНТЕЛИ",
	Push="ОТЖИМАНИЯ",
	Sit="ПРЕСС",
	Hand="СТОЙКА",
	Tread="БЕГ",
}

local trainDescs={
	Punch="сила",
	Weight="гантели и штанга",
	Push="обычные отжимания",
	Sit="упражнение на пресс",
	Hand="стойка на руках",
	Tread="скорость и ловкость",
}

local function turnOffOtherTrain(id)
	for otherId,lever in pairs(Runtime.leverRefs.train) do
		if otherId~=id and lever.Get() then
			lever.Set(false,true)
		end
	end
end

for _,t in ipairs(TRAIN_TYPES) do
	local slider
	slider=makeFeatureToggle(trainFeatureBody,trainIcons[t.id] or "◈",trainNames[t.id] or t.label,trainDescs[t.id] or t.desc,false,function(on,api)
		if on then
			turnOffOtherTrain(t.id)
			if not startTrain(t) then
				api.Set(false,true)
			end
		else
			if Runtime.mode=="train" and Runtime.selectedTrain and Runtime.selectedTrain.id==t.id then
				stopMode(t.label..": OFF")
			end
		end
	end)

	Runtime.leverRefs.train[t.id]=slider
end

-- REBIRTH PAGE

local rebFeaturePanel,rebFeatureBody=makeFeaturePanel(rebPage,"АВТОМАТИЗАЦИЯ",86,3)
rebFeaturePanel.LayoutOrder=1
local rebSettingsPanel,rebSettingsBody=makeSettingsPanel(rebPage,"ТОЧНЫЙ РАЗМЕР",78)
rebSettingsPanel.LayoutOrder=2

local rebInfo=card(rebPage,52)
rebInfo.LayoutOrder=3
local rebInfoTitle=label(rebInfo,"ЦЕЛЬ РЕБИРТОВ",10,Enum.Font.GothamBlack,THEME.Accent2)
rebInfoTitle.Size=UDim2.new(1,-126,0,15)
rebInfoTitle.Position=UDim2.new(0,8,0,4)
rebInfoTitle.TextTruncate=Enum.TextTruncate.AtEnd

local rebGoalProgress=label(rebInfo,"Лимит выключен • цель: 100",8,Enum.Font.GothamBold,THEME.Muted)
rebGoalProgress.Size=UDim2.new(1,-126,0,18)
rebGoalProgress.Position=UDim2.new(0,8,0,24)
rebGoalProgress.TextTruncate=Enum.TextTruncate.AtEnd

local rebGoalBox=Instance.new("TextBox")
rebGoalBox.Parent=rebInfo
rebGoalBox.Size=UDim2.fromOffset(58,28)
rebGoalBox.Position=UDim2.new(1,-116,0,12)
rebGoalBox.BackgroundColor3=THEME.SurfaceAlt
rebGoalBox.BackgroundTransparency=0.05
rebGoalBox.BorderSizePixel=0
rebGoalBox.TextColor3=THEME.Text
rebGoalBox.PlaceholderColor3=THEME.Muted
rebGoalBox.PlaceholderText="100"
rebGoalBox.ClearTextOnFocus=false
rebGoalBox.Font=Enum.Font.GothamBlack
rebGoalBox.TextSize=11
rebGoalBox.Text="100"
corner(rebGoalBox,9)
neonStroke(rebGoalBox,1.2,0.34)

local rebGoalTrack=Instance.new("TextButton")
rebGoalTrack.Parent=rebInfo
rebGoalTrack.Size=UDim2.fromOffset(44,22)
rebGoalTrack.Position=UDim2.new(1,-50,0,15)
rebGoalTrack.Text=""
rebGoalTrack.AutoButtonColor=false
rebGoalTrack.BorderSizePixel=0
corner(rebGoalTrack,13)
local rebGoalStroke=neonStroke(rebGoalTrack,1.2,0.48)

local rebGoalKnob=Instance.new("Frame")
rebGoalKnob.Parent=rebGoalTrack
rebGoalKnob.Size=UDim2.fromOffset(16,16)
rebGoalKnob.BorderSizePixel=0
rebGoalKnob.BackgroundColor3=THEME.Text
corner(rebGoalKnob,10)

local rebGoalState=false
local rebGoalApi={}
local autoRebSlider

local function paintRebirthGoalLever()
	rebGoalTrack.BackgroundColor3=rebGoalState and THEME.Accent or THEME.SurfaceAlt
	rebGoalKnob.Position=rebGoalState and UDim2.new(1,-19,0,3) or UDim2.new(0,3,0,3)
	rebGoalStroke.Color=rebGoalState and THEME.Accent2 or THEME.Border
	rebGoalStroke.Thickness=rebGoalState and 2 or 1.2
end

local function commitRebirthGoalInput()
	local parsed=parseCompactNumber((tostring(rebGoalBox.Text):gsub("%s+","")))
	if not parsed or parsed<1 then
		rebGoalBox.Text=("%.0f"):format(Runtime.rebirthGoal)
		setStatus("ЦЕЛЬ РЕБИРТОВ: введи целое число от 1")
		return false
	end

	local target=math.clamp(math.floor(parsed+0.5),1,1e15)
	Runtime.rebirthGoal=target
	Runtime.rebirthGoalCompleted=false
	rebGoalBox.Text=("%.0f"):format(target)
	refreshRebirthGoalUI(Runtime.rebirthGoalCurrent)

	if Runtime.rebirthGoalEnabled then
		Runtime.rebirthToken=Runtime.rebirthToken+1
		clearRebirthGoalPending()
		Runtime.nextRebirth=0
		local current,_,counter=ensureRebirthCounterWatcher()
		Runtime.rebirthGoalCurrent=current and math.max(0,math.floor(current+0.5)) or nil
		if not counter then
			refreshRebirthGoalUI(nil,"Точный счётчик Rebirths не найден • запрос на паузе")
			setStatus("НОВАЯ ЦЕЛЬ: ЖДУ ТОЧНЫЙ СЧЁТЧИК REBIRTHS")
		elseif current~=nil and current>=target then
			stopRebirthAtGoal(current)
		else
			refreshRebirthGoalUI(current)
			setStatus("НОВАЯ ЦЕЛЬ РЕБИРТОВ: "..formatWholeNumber(target))
		end
	end
	return true
end

local function changeRebirthGoal(on,api)
	if on then
		local rebirthRemote=findRebirthRemote()
		if not rebirthRemote or not rebirthRemote:IsA("RemoteFunction") then
			api.Set(false,true)
			setStatus("ЦЕЛЬ РЕБИРТОВ: ТОЧНЫЙ REMOTEFUNCTION НЕ НАЙДЕН")
			return
		end
		if not commitRebirthGoalInput() then
			api.Set(false,true)
			return
		end

		local current,_,counter=ensureRebirthCounterWatcher()
		if current==nil or not counter then
			api.Set(false,true)
			Runtime.rebirthGoalCurrent=nil
			refreshRebirthGoalUI(nil,"Точный счётчик Rebirths не найден • лимит не запущен")
			setStatus("ЦЕЛЬ РЕБИРТОВ: ТОЧНЫЙ REBIRTHS.VALUE НЕ НАЙДЕН")
			return
		end
		if current>=Runtime.rebirthGoal then
			stopRebirthAtGoal(current)
			return
		end

		Runtime.rebirthToken=Runtime.rebirthToken+1
		Runtime.rebirthGoalEnabled=true
		Runtime.rebirthGoalCompleted=false
		Runtime.rebirthGoalCurrent=math.max(0,math.floor(current+0.5))
		clearRebirthGoalPending()
		Runtime.autoRebirth=true
		Runtime.nextRebirth=0
		if autoRebSlider then autoRebSlider.Set(true,true) end
		refreshRebirthGoalUI(Runtime.rebirthGoalCurrent)
		setStatus(("АВТОРЕБИРТ ДО ЦЕЛИ: %s"):format(formatWholeNumber(Runtime.rebirthGoal)))
	else
		stopRebirthAutomation("ЛИМИТ РЕБИРТОВ: выключен",false)
	end
end

function rebGoalApi.Set(value,silent)
	rebGoalState=value and true or false
	paintRebirthGoalLever()
	if not silent then changeRebirthGoal(rebGoalState,rebGoalApi) end
end

function rebGoalApi.Get()
	return rebGoalState
end

addConn(rebGoalTrack.Activated:Connect(function()
	rebGoalApi.Set(not rebGoalState,false)
end))
addConn(rebGoalBox.FocusLost:Connect(commitRebirthGoalInput))
paintRebirthGoalLever()

Runtime.ui.rebirthGoalProgress=rebGoalProgress
Runtime.ui.rebirthGoalInput=rebGoalBox
Runtime.leverRefs.rebirthGoal=rebGoalApi
refreshRebirthGoalUI(nil)

autoRebSlider=makeFeatureToggle(rebFeatureBody,"↻","АВТОРЕБИРТ","без ограничения",false,function(on,api)
	if on and not findRebirthRemote() then
		api.Set(false,true)
		setStatus("РЕБИРТ: функция игры не найдена")
		return
	end

	if on then
		Runtime.rebirthToken=Runtime.rebirthToken+1
		Runtime.rebirthGoalEnabled=false
		Runtime.rebirthGoalCompleted=false
		clearRebirthGoalPending()
		Runtime.autoRebirth=true
		Runtime.nextRebirth=0
		if Runtime.leverRefs.rebirthGoal then Runtime.leverRefs.rebirthGoal.Set(false,true) end
		refreshRebirthGoalUI(Runtime.rebirthGoalCurrent)
		setStatus("АВТО РЕБИРТ: включён без лимита")
	else
		stopRebirthAutomation("АВТО РЕБИРТ: выключен",false)
	end
end)

Runtime.leverRefs.autoRebirth=autoRebSlider

local sizeInput=makeNumberInput(rebSettingsBody,"РАЗМЕР ПЕРСОНАЖА","значение от 0.1 до 1000",1,function(value)
	Runtime.sizeTarget=value
	if Runtime.autoSize then Runtime.nextSize=0 end
	setStatus("РАЗМЕР: "..tostring(value))
end)

local autoSizeSlider=makeFeatureToggle(rebFeatureBody,"◫","ФИКС. РАЗМЕР","держит значение",false,function(on,api)
	if on and not findSizeRemote() then
		api.Set(false,true)
		setStatus("РАЗМЕР: функция игры не найдена")
		return
	end

	Runtime.sizeTarget=sizeInput.Get()
	Runtime.autoSize=on
	Runtime.nextSize=0
	setStatus(("АВТО РАЗМЕР: %s | %s"):format(on and "включён" or "выключен",tostring(Runtime.sizeTarget)))
end)

Runtime.leverRefs.autoSize=autoSizeSlider

local kingLockSlider=makeFeatureToggle(rebFeatureBody,"♛","KING GYM","удерживает в зоне",false,function(on,api)
	if on then
		if Runtime.mode=="bug" then stopMode("BUG STOP / KING LOCK") end

		Runtime.lockPosition=false
		Runtime.positionCF=nil
		if Runtime.leverRefs.lockPosition then Runtime.leverRefs.lockPosition.Set(false,true) end

		local ok,err=enableKingLock()
		if not ok then
			api.Set(false,true)
			setStatus("KING ЗОНА: "..tostring(err))
			return
		end

		setStatus("KING ЗОНА: включена")
	else
		disableKingLock()
		setStatus("KING ЗОНА: выключена")
	end
end)

Runtime.leverRefs.kingLock=kingLockSlider

-- AUTO KILL PAGE

local killFeaturePanel,killFeatureBody=makeFeaturePanel(killPage,"РЕЖИМ АВТОКИЛА",86,3)
killFeaturePanel.LayoutOrder=1
local killSettingsPanel,killSettingsBody=makeSettingsPanel(killPage,"СПИСКИ ИГРОКОВ",141)
killSettingsPanel.LayoutOrder=2

Runtime.leverRefs.kill={}

local function turnOffOtherKillLevers(activeMode)
	if Runtime.mode then stopMode("ОСНОВНОЙ РЕЖИМ ОСТАНОВЛЕН / АВТОКИЛ") end
	for mode,lever in pairs(Runtime.leverRefs.kill) do
		if mode~=activeMode and lever then lever.Set(false,true) end
	end
end

local killAllLever
killAllLever=makeFeatureToggle(killFeatureBody,"✦","ВСЕ ИГРОКИ","без исключений",false,function(on,api)
	if on then
		turnOffOtherKillLevers("all")
		startKillAutomation("all")
	else
		if Runtime.killMode=="all" then stopKillAutomation("АВТОКИЛ: выключен") end
	end
end)
Runtime.leverRefs.kill.all=killAllLever

local killWhiteLever
killWhiteLever=makeFeatureToggle(killFeatureBody,"♢","КРОМЕ БЕЛЫХ","не трогает список",false,function(on,api)
	if on then
		turnOffOtherKillLevers("whitelist")
		startKillAutomation("whitelist")
	else
		if Runtime.killMode=="whitelist" then stopKillAutomation("АВТОКИЛ: выключен") end
	end
end)
Runtime.leverRefs.kill.whitelist=killWhiteLever

local killBlackLever
killBlackLever=makeFeatureToggle(killFeatureBody,"◎","ТОЛЬКО ЦЕЛИ","чёрный список",false,function(on,api)
	if on then
		turnOffOtherKillLevers("blacklist")
		startKillAutomation("blacklist")
	else
		if Runtime.killMode=="blacklist" then stopKillAutomation("АВТОКИЛ: выключен") end
	end
end)
Runtime.leverRefs.kill.blacklist=killBlackLever

local function currentPlayerOptions()
	local options={}
	for _,player in ipairs(Players:GetPlayers()) do
		if player~=lp then
			table.insert(options,{
				id=tostring(player.UserId),
				label=player.DisplayName,
				sub="@"..player.Name.."  •  ID "..tostring(player.UserId),
				player=player,
			})
		end
	end
	table.sort(options,function(a,b) return string.lower(a.label)<string.lower(b.label) end)
	return options
end

local whiteSelection
whiteSelection=makeSelectionRow(killSettingsBody,"БЕЛЫЙ СПИСОК","0 игроков",function()
	openPicker("БЕЛЫЙ СПИСОК",currentPlayerOptions(),{
		multiple=true,
		selected=Runtime.killWhitelist,
		onDone=function(selected)
			Runtime.killWhitelist={}
			for id,enabled in pairs(selected) do
				if enabled then Runtime.killWhitelist[tonumber(id) or id]=true end
			end
			refreshExtraUI()
			setStatus("БЕЛЫЙ СПИСОК: "..selectedCount(Runtime.killWhitelist))
		end,
	})
end)

local blackSelection
blackSelection=makeSelectionRow(killSettingsBody,"ЦЕЛИ","0 игроков",function()
	openPicker("ЦЕЛИ АВТОКИЛА",currentPlayerOptions(),{
		multiple=true,
		selected=Runtime.killBlacklist,
		onDone=function(selected)
			Runtime.killBlacklist={}
			for id,enabled in pairs(selected) do
				if enabled then Runtime.killBlacklist[tonumber(id) or id]=true end
			end
			refreshExtraUI()
			setStatus("ЦЕЛЕЙ АВТОКИЛА: "..selectedCount(Runtime.killBlacklist))
		end,
	})
end)

local killHint=label(killSettingsBody,"Белые — защищены. Цели — единственные атакуемые игроки.",8,Enum.Font.Gotham,THEME.Muted)
killHint.Size=UDim2.new(1,0,0,32)
killHint.TextXAlignment=Enum.TextXAlignment.Center

-- CRYSTALS AND DIRECT GEM SHOP PAGE

normalizeShopSelection("pet")
normalizeShopSelection("aura")

local crystalFeaturePanel,crystalFeatureBody=makeFeaturePanel(crystalPage,"ПОКУПКА КАЖДЫЕ 0.5 СЕК",86,3)
crystalFeaturePanel.LayoutOrder=1
local crystalSettingsPanel,crystalSettingsBody=makeSettingsPanel(crystalPage,"ТОЧНЫЙ ВЫБОР ТОВАРА",141)
crystalSettingsPanel.LayoutOrder=2

Runtime.leverRefs.crystal={}

local function turnOffOtherCrystalLevers(activeMode)
	for mode,lever in pairs(Runtime.leverRefs.crystal) do
		if mode~=activeMode and lever then lever.Set(false,true) end
	end
end

local crystalLever
crystalLever=makeFeatureToggle(crystalFeatureBody,"C","КРИСТАЛЛЫ","открывать • 0.5 сек",false,function(on,api)
	if on then
		turnOffOtherCrystalLevers("crystal")
		if not startCrystalAutomation("crystal") then api.Set(false,true) end
	else
		if Runtime.crystalMode=="crystal" then stopCrystalAutomation("КРИСТАЛЛЫ: выключено") end
	end
end)
Runtime.leverRefs.crystal.crystal=crystalLever

local petLever
petLever=makeFeatureToggle(crystalFeatureBody,"P","ПЕТ ЗА ГЕМЫ","точная покупка • 0.5 сек",false,function(on,api)
	if on then
		turnOffOtherCrystalLevers("pet")
		if not startCrystalAutomation("pet") then api.Set(false,true) end
	else
		if Runtime.crystalMode=="pet" then stopCrystalAutomation("АВТОПИТОМЕЦ: выключен") end
	end
end)
Runtime.leverRefs.crystal.pet=petLever

local auraLever
auraLever=makeFeatureToggle(crystalFeatureBody,"A","АУРА ЗА ГЕМЫ","точная покупка • 0.5 сек",false,function(on,api)
	if on then
		turnOffOtherCrystalLevers("aura")
		if not startCrystalAutomation("aura") then api.Set(false,true) end
	else
		if Runtime.crystalMode=="aura" then stopCrystalAutomation("АВТОАУРА: выключена") end
	end
end)
Runtime.leverRefs.crystal.aura=auraLever

local crystalSelection
crystalSelection=makeSelectionRow(crystalSettingsBody,"КРИСТАЛЛ ДЛЯ ОТКРЫТИЯ",Runtime.selectedCrystal,function()
	local options={}
	for _,name in ipairs(availableCrystalNames()) do
		table.insert(options,{id=name,label=name,sub="рулетка • открытие каждые 0.5 сек"})
	end
	openPicker("ВЫБОР КРИСТАЛЛА",options,{
		selected={[Runtime.selectedCrystal]=true},
		onDone=function(option)
			stopCrystalAutomation(nil)
			Runtime.selectedCrystal=option.label
			refreshExtraUI()
			setStatus("КРИСТАЛЛ: "..Runtime.selectedCrystal)
		end,
	})
end)

local petSelection
petSelection=makeSelectionRow(crystalSettingsBody,"ПЕТ ИЗ МАГАЗИНА",Runtime.selectedPet or "ВЫБРАТЬ",function()
	local options={}
	for _,entry in ipairs(shopCatalog("pet")) do
		table.insert(options,{
			id=entry.name,
			label=entry.name,
			sub="Прямая покупка • "..formatShopPrice(entry.price),
		})
	end
	openPicker("ПЕТ ЗА ГЕМЫ • БЕЗ РУЛЕТКИ",options,{
		selected={[tostring(Runtime.selectedPet or "")]=true},
		onDone=function(option)
			stopCrystalAutomation(nil)
			Runtime.selectedPet=option.label
			refreshExtraUI()
			setStatus("ПЕТ ИЗ МАГАЗИНА: "..Runtime.selectedPet)
		end,
	})
end)

local auraSelection
auraSelection=makeSelectionRow(crystalSettingsBody,"АУРА ИЗ МАГАЗИНА",Runtime.selectedAura or "ВЫБРАТЬ",function()
	local options={}
	for _,entry in ipairs(shopCatalog("aura")) do
		table.insert(options,{
			id=entry.name,
			label=entry.name,
			sub="Прямая покупка • "..formatShopPrice(entry.price),
		})
	end
	openPicker("АУРА ЗА ГЕМЫ • БЕЗ РУЛЕТКИ",options,{
		selected={[tostring(Runtime.selectedAura or "")]=true},
		onDone=function(option)
			stopCrystalAutomation(nil)
			Runtime.selectedAura=option.label
			refreshExtraUI()
			setStatus("АУРА ИЗ МАГАЗИНА: "..Runtime.selectedAura)
		end,
	})
end)

Runtime.refreshExtraUI=function()
	whiteSelection.Set(selectedCount(Runtime.killWhitelist).." игроков")
	blackSelection.Set(selectedCount(Runtime.killBlacklist).." игроков")
	crystalSelection.Set(Runtime.selectedCrystal)
	petSelection.Set(Runtime.selectedPet or "ВЫБРАТЬ")
	auraSelection.Set(Runtime.selectedAura or "ВЫБРАТЬ")
end
refreshExtraUI()

local activeTab="bug"
local minimized=false
local expandedSize=main.Size

local function applyResponsiveLayout()
	local compact=main.AbsoluteSize.X<380
	local railWidth=compact and 72 or 82
	rail.Size=UDim2.new(0,railWidth,1,-48)
	content.Size=UDim2.new(1,-railWidth,1,-48)
	content.Position=UDim2.fromOffset(railWidth,48)
	railScroll.ScrollBarThickness=compact and 3 or 2
	title.TextSize=compact and 12 or 14
	author.TextSize=compact and 7 or 8
	updateCanvas()
end

local function paintTab(tab,active)
	tab.BackgroundColor3=active and THEME.SurfaceAlt or THEME.Surface
	tab.BackgroundTransparency=active and 0.18 or 0.52
	tab.TextColor3=active and THEME.Accent or THEME.Muted
	local mark=tab:FindFirstChild("ActiveMark")
	if mark then mark.Visible=active end
	local tabStroke=tab:FindFirstChild("TabStroke")
	if tabStroke then
		tabStroke.Color=active and THEME.Accent or THEME.Border
		tabStroke.Transparency=active and 0.28 or 0.72
	end
end

local function showTab(name)
	activeTab=name
	local bug=name=="bug"
	local train=name=="train"
	local reb=name=="reb"
	local kill=name=="kill"
	local crystal=name=="crystal"
	bugPage.Visible=(not minimized) and bug
	trainPage.Visible=(not minimized) and train
	rebPage.Visible=(not minimized) and reb
	killPage.Visible=(not minimized) and kill
	crystalPage.Visible=(not minimized) and crystal
	paintTab(bugTab,bug)
	paintTab(trainTab,train)
	paintTab(rebTab,reb)
	paintTab(killTab,kill)
	paintTab(crystalTab,crystal)
end

local function clampOffsetPosition(position,size)
	local viewport=viewportSize()
	local width=size.X.Offset
	local height=size.Y.Offset
	local maxX=math.max(4,viewport.X-width-4)
	local maxY=math.max(4,viewport.Y-height-4)
	return UDim2.fromOffset(
		math.clamp(position.X.Offset,4,maxX),
		math.clamp(position.Y.Offset,4,maxY)
	)
end

local function setMinimized(on)
	minimized=on and true or false
	if minimized then
		expandedSize=main.Size
		miniButton.Position=clampOffsetPosition(main.Position,miniButton.Size)
		main.Visible=false
		miniButton.Visible=true
		bugPage.Visible=false
		trainPage.Visible=false
		rebPage.Visible=false
		killPage.Visible=false
		crystalPage.Visible=false
	else
		main.Size=expandedSize
		main.Position=clampOffsetPosition(miniButton.Position,expandedSize)
		miniButton.Visible=false
		main.Visible=true
		showTab(activeTab)
	end
end

local viewportConnection=nil

local function fitWindowToViewport(useDefaultSize)
	local viewport=viewportSize()
	local minWidth,minHeight,maxWidth,maxHeight,wantedWidth,wantedHeight=windowMetrics(viewport)
	local sourceSize=minimized and expandedSize or main.Size
	local width=useDefaultSize and wantedWidth or math.clamp(sourceSize.X.Offset,minWidth,maxWidth)
	local height=useDefaultSize and wantedHeight or math.clamp(sourceSize.Y.Offset,minHeight,maxHeight)
	local fittedSize=UDim2.fromOffset(width,height)
	expandedSize=fittedSize

	if minimized then
		miniButton.Position=clampOffsetPosition(miniButton.Position,miniButton.Size)
	else
		main.Size=fittedSize
		main.Position=clampOffsetPosition(main.Position,fittedSize)
	end
	applyResponsiveLayout()
end

local function bindViewportCamera()
	if viewportConnection then
		safe(function() viewportConnection:Disconnect() end)
		viewportConnection=nil
	end
	local camera=workspace.CurrentCamera
	if camera then
		viewportConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.defer(function()
				if Runtime.alive then fitWindowToViewport(false) end
			end)
		end)
		table.insert(Runtime.connections,viewportConnection)
	end
end

addConn(main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(applyResponsiveLayout)
end))
addConn(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindViewportCamera()
	fitWindowToViewport(false)
end))
bindViewportCamera()
applyResponsiveLayout()

addConn(bugTab.Activated:Connect(function() showTab("bug") end))
addConn(trainTab.Activated:Connect(function() showTab("train") end))
addConn(rebTab.Activated:Connect(function() showTab("reb") end))
addConn(killTab.Activated:Connect(function() showTab("kill") end))
addConn(crystalTab.Activated:Connect(function() showTab("crystal") end))
addConn(minimizeBtn.Activated:Connect(function()
	if Runtime.closePicker then Runtime.closePicker() end
	setMinimized(true)
end))

addConn(rescanBtn.Activated:Connect(function()
	setStatus("ОБНОВЛЯЮ КАМНИ...")
	scanRocks()
	Runtime.autoRockSelection=true
	Runtime.lastAutoRockRebs=nil
	applyAutoRockSelection(true)
	setStatus("КАМЕНЬ: "..tostring(Runtime.selectedRock and Runtime.selectedRock.label or "не найден"))
end))

addConn(panicBtn.Activated:Connect(function()
	panicStop()
end))

local draggingMain=false
local draggingMini=false
local resizing=false
local miniMoved=false
local dragStart=nil
local startPos=nil
local resizeStartSize=nil

local function pointerInput(input)
	return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch
end

addConn(topBar.InputBegan:Connect(function(input)
	if pointerInput(input) then
		local localX=input.Position.X-main.AbsolutePosition.X
		if localX<main.AbsoluteSize.X-82 then
			draggingMain=true
			dragStart=input.Position
			startPos=main.Position
		end
	end
end))

addConn(miniButton.InputBegan:Connect(function(input)
	if pointerInput(input) then
		draggingMini=true
		miniMoved=false
		dragStart=input.Position
		startPos=miniButton.Position
	end
end))

addConn(resizeHandle.InputBegan:Connect(function(input)
	if pointerInput(input) then
		resizing=true
		dragStart=input.Position
		resizeStartSize=main.Size
	end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
	if pointerInput(input) then
		draggingMain=false
		draggingMini=false
		resizing=false
	end
end))

addConn(UserInputService.InputChanged:Connect(function(input)
	if dragStart and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
		local delta=input.Position-dragStart
		if draggingMain and startPos then
			local wanted=UDim2.fromOffset(startPos.X.Offset+delta.X,startPos.Y.Offset+delta.Y)
			main.Position=clampOffsetPosition(wanted,main.Size)
		elseif draggingMini and startPos then
			if delta.Magnitude>5 then miniMoved=true end
			local wanted=UDim2.fromOffset(startPos.X.Offset+delta.X,startPos.Y.Offset+delta.Y)
			miniButton.Position=clampOffsetPosition(wanted,miniButton.Size)
		elseif resizing and resizeStartSize then
			local viewport=viewportSize()
			local dynamicMinWidth,dynamicMinHeight,viewportMaxWidth,viewportMaxHeight=windowMetrics(viewport)
			local maxWidth=math.min(viewportMaxWidth,math.max(dynamicMinWidth,viewport.X-main.Position.X.Offset-4))
			local maxHeight=math.min(viewportMaxHeight,math.max(dynamicMinHeight,viewport.Y-main.Position.Y.Offset-4))
			local width=math.clamp(resizeStartSize.X.Offset+delta.X,dynamicMinWidth,maxWidth)
			local height=math.clamp(resizeStartSize.Y.Offset+delta.Y,dynamicMinHeight,maxHeight)
			main.Size=UDim2.fromOffset(width,height)
			expandedSize=main.Size
		end
	end
end))

addConn(miniButton.Activated:Connect(function()
	if miniMoved then
		miniMoved=false
		return
	end
	setMinimized(false)
end))

function Runtime:Stop(reason)
	if not self.alive then return end

	self.alive=false
	self.manualNetworkHold=false
	leaveNetworkHold(os.clock(),"STOP")
	panicStop()
	disconnectRockButtonConnections()
	disconnectAll()

	if gui and gui.Parent then
		gui:Destroy()
	end

	if ENV.RockBugRuntime==self then
		ENV.RockBugRuntime=nil
	end
end

addConn(closeBtn.Activated:Connect(function()
	Runtime:Stop("closed")
end))

addConn(lp.CharacterAdded:Connect(function(newCharacter)
	local resumeMode=Runtime.mode
	local resumeTrain=Runtime.selectedTrain
	local resumePositionLock=Runtime.lockPosition
	local resumePositionCF=Runtime.positionCF

	Runtime.respawnGeneration=Runtime.respawnGeneration+1
	local generation=Runtime.respawnGeneration
	Runtime.activeTool=nil
	Runtime.lockCF=nil
	Runtime.positionCF=nil
	Runtime.lockRock=false
	Runtime.lockPosition=false
	stopMode(resumeMode and "RESPAWN: жду персонажа для восстановления" or "RESPAWN: режимы остановлены")
	local resumeToken=Runtime.modeToken

	if Runtime.leverRefs.lockPosition then Runtime.leverRefs.lockPosition.Set(false,true) end
	if not Runtime.autoResumeAfterRespawn or (not resumeMode and not resumePositionLock) then return end

	task.spawn(function()
		local deadline=os.clock()+15
		local readyRoot=nil
		local readyHum=nil

		repeat
			if not Runtime.alive or Runtime.respawnGeneration~=generation or Runtime.modeToken~=resumeToken then return end
			readyRoot=newCharacter and newCharacter:FindFirstChild("HumanoidRootPart")
			readyHum=newCharacter and newCharacter:FindFirstChildWhichIsA("Humanoid")
			if readyRoot and readyHum then break end
			task.wait(0.2)
		until os.clock()>=deadline

		if not readyRoot or not readyHum then
			setStatus("RESPAWN RECOVERY: персонаж не загрузился за 15с")
			return
		end

		-- Allow Backpack/tools to replicate before one bounded restart attempt.
		task.wait(0.8)
		if not Runtime.alive or Runtime.respawnGeneration~=generation or Runtime.modeToken~=resumeToken then return end

		local resumed=resumeMode==nil
		if resumeMode=="bug" then
			resumed=startBug()
		elseif resumeMode=="train" and resumeTrain then
			resumed=startTrain(resumeTrain)
		end

		local positionResumed=false
		if resumePositionLock and resumePositionCF then
			readyRoot.Anchored=false
			Runtime.lockPosition=true
			Runtime.positionCF=resumePositionCF
			Runtime.nextPosTick=0
			positionResumed=true
			if Runtime.leverRefs.lockPosition then Runtime.leverRefs.lockPosition.Set(true,true) end
		end

		if resumed or positionResumed then
			setStatus("RESPAWN RECOVERY: режим восстановлен")
		else
			setStatus("RESPAWN RECOVERY: не удалось восстановить предмет")
		end
	end)
end))

-- Initial scan / exact rebirth calculator.
scanRocks()
applyAutoRockSelection(true)
showTab("bug")
updateCanvas()
setStatus("ГОТОВО • "..tostring(Runtime.selectedRock and Runtime.selectedRock.label or "камень не найден"))

end

local uiOk,uiErr=xpcall(buildUI,function(err)
	local trace=""
	if debug and type(debug.traceback)=="function" then trace="\n"..tostring(debug.traceback()) end
	return tostring(err)..trace
end)

if not uiOk then
	Runtime.alive=false
	disconnectAll()
	if ENV.RockBugRuntime==Runtime then ENV.RockBugRuntime=nil end
	if Runtime.uiRoot and Runtime.uiRoot.Parent then safe(function() Runtime.uiRoot:Destroy() end) end
	warn("[RockBugHub] UI startup failed: "..tostring(uiErr))
	pcall(function()
		StarterGui:SetCore("SendNotification",{
			Title="RockBugHub",
			Text="UI error: "..tostring(uiErr):sub(1,120),
			Duration=10,
		})
	end)
	return
end

task.spawn(function()
	local recentFailures={}
	while Runtime.alive do
		local ok,err=xpcall(scheduler,function(e)
			local trace=""
			if debug and type(debug.traceback)=="function" then
				trace="\n"..tostring(debug.traceback())
			end
			return tostring(e)..trace
		end)

		if ok or not Runtime.alive then return end

		Runtime.lastError=err
		Runtime.schedulerRestarts=Runtime.schedulerRestarts+1
		local now=os.clock()
		local kept={}
		for _,stamp in ipairs(recentFailures) do
			if now-stamp<=30 then table.insert(kept,stamp) end
		end
		table.insert(kept,now)
		recentFailures=kept

		-- Preserve every mode/lever on isolated failures. A hard stop remains for
		-- a genuine crash loop so the client cannot spin forever at full CPU.
		if #recentFailures>=4 then
			warn("RockBugHub scheduler stopped: "..tostring(err))
			Runtime:Stop("scheduler repeatedly failed")
			return
		end

		enterNetworkHold("scheduler recovery",now)
		setStatus(("SCHEDULER RECOVERY %d/3 | state preserved | %s"):format(#recentFailures,tostring(err):sub(1,70)))
		task.wait(math.min(0.5*#recentFailures,1.5))
	end
end)
