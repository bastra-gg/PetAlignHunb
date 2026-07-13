-- RockBugHub v20 Validated Compact
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
	autoSize=false,
	sizeTarget=1,
	sizeInFlight=false,
	kingLock=false,
	kingCF=nil,
	kingRoot=nil,
	kingSavedAnchored=nil,
	kingPresenceInFlight=false,
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
	characterCollisionSaved={},
	characterLockSaved=nil,
	lastSchedulerTick=0,
	lastError=nil,
	status="ready",
	ui=nil,
	leverRefs={},
}

ENV.RockBugRuntime=Runtime

local function safe(fn)
	local ok,res=pcall(fn)
	return ok,res
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

local function setNetText()
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

local function readRebirths()
	local leader=lp:FindFirstChild("leaderstats")

	if leader then
		for _,d in ipairs(leader:GetChildren()) do
			if looksLikeRebirthName(d.Name) then
				local ok,val=pcall(function() return d.Value end)
				if ok then
					local n=tonumber(val) or parseCompactNumber(val)
					if n then return n,"leaderstats" end
				end
			end
		end
	end

	-- Search value objects only once on request, not in fast loops.
	local checked=0
	for _,d in ipairs(lp:GetDescendants()) do
		checked=checked+1
		if checked>1800 then break end

		if looksLikeRebirthName(d.Name) then
			local ok,val=pcall(function() return d.Value end)
			if ok then
				local n=tonumber(val) or parseCompactNumber(val)
				if n then return n,"value" end
			end
		end
	end

	-- Conservative GUI fallback.
	local pg=lp:FindFirstChild("PlayerGui")
	if pg then
		local scanned=0

		for _,d in ipairs(pg:GetDescendants()) do
			scanned=scanned+1
			if scanned>2600 then break end

			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				local text=tostring(d.Text or "")
				if looksLikeRebirthName(text) or looksLikeRebirthName(d.Name) then
					local n=parseCompactNumber(text)
					if n then return n,"gui" end
				end
			end
		end
	end

	return nil,"not found"
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
		local best=nil

		for _,row in ipairs(ROCKS) do
			if rockCache[row.req] then
				-- All rock multipliers are exact fortieths. Integer arithmetic avoids
				-- float rounding falsely marking a rebirth as compatible/incompatible.
				local multiplier40=math.floor(row.mult*40+0.5)
				local hitXp40=(rebs+20)*multiplier40

				for level=1,19 do
					local cumulativeXp=grade.base*level*(level+1)/2
					local cumulativeXp40=cumulativeXp*40

					if hitXp40>0 and cumulativeXp40%hitXp40==0 then
						local hits=cumulativeXp40/hitXp40
						local candidate={row=row,level=level,hits=hits,hitXp40=hitXp40}
						if not best
							or candidate.hits<best.hits
							or (candidate.hits==best.hits and candidate.hitXp40>best.hitXp40)
							or (candidate.hits==best.hits and candidate.hitXp40==best.hitXp40 and candidate.level<best.level) then
							best=candidate
						end
						break
					end
				end
			end
		end

		if best then
			local reason=("%d реб • %s XP • L%d / %d уд."):format(
				rebs,compactXp(best.hitXp40),best.level,best.hits
			)
			return best.row,reason,rebs,true
		end

		-- There is no mathematically exact pet-XP cycle at every rebirth count.
		-- Pick the weakest available rock instead of pretending a random match is safe.
		for i=#ROCKS,1,-1 do
			local row=ROCKS[i]
			if rockCache[row.req] then
				local hitXp40=(rebs+20)*math.floor(row.mult*40+0.5)
				return row,("%d реб • exact нет • %s XP"):format(rebs,compactXp(hitXp40)),rebs,false
			end
		end
	end

	for i=#ROCKS,1,-1 do
		local row=ROCKS[i]
		if rockCache[row.req] then
			return row,"ребы не найдены ("..tostring(source)..")",nil,false
		end
	end

	return ROCKS[#ROCKS],"камни не найдены",nil,false
end

local function applyAutoRockSelection(force)
	if not Runtime.autoRockSelection and not force then return false end
	local row,reason,rebs,exact=chooseSafeRockByRebirths()
	if not force and rebs~=nil and Runtime.lastAutoRockRebs==rebs then return false end

	local previous=Runtime.selectedRock
	Runtime.selectedRock=row
	Runtime.lastAutoRockRebs=rebs
	Runtime.autoRockReason=reason
	Runtime.autoRockExact=exact

	if Runtime.ui then
		if Runtime.ui.autoRockTitle and Runtime.ui.autoRockTitle.Parent then
			Runtime.ui.autoRockTitle.Text=exact and "АВТО-КАМЕНЬ ПО РЕБАМ" or "АВТО-КАМЕНЬ: НЕТ EXACT"
		end
		if Runtime.ui.autoRockName and Runtime.ui.autoRockName.Parent then
			Runtime.ui.autoRockName.Text=row.label.." • "..tostring(reason)
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
				heldRoot.Anchored=true
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
		r.Anchored=true
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
	Runtime.nextRebirth=now+0.5
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

local function tryRebirth()
	if Runtime.networkPaused then return false,"network hold" end
	local remote=findRebirthRemote()
	if not remote then return false,"rebirthRemote не найден" end

	local ok,err=safe(function()
		if remote:IsA("RemoteFunction") then
			remote:InvokeServer("rebirthRequest")
		else
			remote:FireServer("rebirthRequest")
		end
	end)

	return ok,err
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

local function findKingTriggerPart()
	local targetPosition=kingTargetCF().Position
	local best=nil
	local bestScore=-math.huge
	local scanned=0

	for _,d in ipairs(workspace:GetDescendants()) do
		scanned=scanned+1
		if scanned>12000 then break end

		if d:IsA("BasePart") then
			local distance=(d.Position-targetPosition).Magnitude
			if distance<=320 then
				local full=tostring(d:GetFullName()):lower()
				local score=-distance*0.08
				local hasTouch=d:FindFirstChildOfClass("TouchTransmitter")~=nil

				if hasTouch then score=score+100 end
				if full:find("muscle king",1,true) or full:find("muscleking",1,true) then score=score+80 end
				if full:find("king",1,true) then score=score+35 end
				if containsAny(full,{"trigger","zone","area","hill","gym","capture","touch"}) then score=score+45 end

				if score>bestScore and (hasTouch or score>=45) then
					best=d
					bestScore=score
				end
			end
		end
	end

	return best
end

local function triggerKingPresence(r)
	if Runtime.kingPresenceInFlight or not Runtime.kingLock or not r or not r.Parent then return false end
	Runtime.kingPresenceInFlight=true

	local ok,err=xpcall(function()
		local cf=Runtime.kingCF or kingTargetCF()
		r.Anchored=false
		r.CFrame=cf*CFrame.new(0,6,0)
		r.AssemblyLinearVelocity=Vector3.new(0,-18,0)
		r.AssemblyAngularVelocity=Vector3.new(0,0,0)
		task.wait(0.18)

		if not Runtime.alive or not Runtime.kingLock or Runtime.kingRoot~=r or not r.Parent then return end

		r.CFrame=cf
		r.AssemblyLinearVelocity=Vector3.new(0,0,0)
		r.AssemblyAngularVelocity=Vector3.new(0,0,0)

		local trigger=findKingTriggerPart()
		if trigger and type(firetouchinterest)=="function" then
			local c=char()
			local contacts={
				r,
				c and (c:FindFirstChild("LeftFoot") or c:FindFirstChild("Left Leg")),
				c and (c:FindFirstChild("RightFoot") or c:FindFirstChild("Right Leg")),
			}

			for _,part in ipairs(contacts) do
				if part and part:IsA("BasePart") then
					safe(function()
						firetouchinterest(part,trigger,0)
						firetouchinterest(part,trigger,1)
					end)
				end
			end
		end

		task.wait(0.18)
		if Runtime.alive and Runtime.kingLock and Runtime.kingRoot==r and r.Parent then
			r.CFrame=cf
			r.AssemblyLinearVelocity=Vector3.new(0,0,0)
			r.AssemblyAngularVelocity=Vector3.new(0,0,0)
			r.Anchored=true
		end
	end,function(e)
		return tostring(e)
	end)

	Runtime.kingPresenceInFlight=false
	if not ok and Runtime.alive then setStatus("KING TRIGGER: "..tostring(err)) end
	return ok
end

local function disableKingLock()
	local savedRoot=Runtime.kingRoot
	if savedRoot and savedRoot.Parent and Runtime.kingSavedAnchored~=nil then
		safe(function() savedRoot.Anchored=Runtime.kingSavedAnchored end)
	end

	Runtime.kingLock=false
	Runtime.kingCF=nil
	Runtime.kingRoot=nil
	Runtime.kingSavedAnchored=nil
	Runtime.kingPresenceInFlight=false
end

local function enableKingLock()
	local r=root()
	if not r then return false,"нет root" end

	disableKingLock()

	Runtime.kingCF=kingTargetCF()
	Runtime.kingLock=true
	Runtime.kingRoot=r
	Runtime.kingSavedAnchored=r.Anchored
	Runtime.nextKingTick=0

	triggerKingPresence(r)
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
	Runtime.lockPosition=false
	Runtime.positionCF=nil
	Runtime.autoRebirth=false
	Runtime.rebirthInFlight=false
	Runtime.autoSize=false
	disableKingLock()

	if Runtime.leverRefs.lockPosition then Runtime.leverRefs.lockPosition.Set(false,true) end
	if Runtime.leverRefs.autoRebirth then Runtime.leverRefs.autoRebirth.Set(false,true) end
	if Runtime.leverRefs.autoSize then Runtime.leverRefs.autoSize.Set(false,true) end
	if Runtime.leverRefs.kingLock then Runtime.leverRefs.kingLock.Set(false,true) end

	setVisualLow(false)
	if Runtime.leverRefs.visualLow then Runtime.leverRefs.visualLow.Set(false,true) end
end

local function startBug()
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
			Runtime.nextRebirth=now+1.2
			Runtime.rebirthInFlight=true
			task.spawn(function()
				local ok,err=tryRebirth()
				Runtime.rebirthInFlight=false
				if not ok and Runtime.alive and Runtime.autoRebirth then
					setStatus("AUTO REB: "..tostring(err))
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
					Runtime.kingRoot=r
					Runtime.kingSavedAnchored=r.Anchored
					if not Runtime.kingPresenceInFlight then
						task.spawn(function() triggerKingPresence(r) end)
					end
				elseif not r.Anchored or (r.Position-Runtime.kingCF.Position).Magnitude>0.75 then
					if not Runtime.kingPresenceInFlight then
						task.spawn(function() triggerKingPresence(r) end)
					end
				end
			end
		end

		if Runtime.mode=="train" and Runtime.lockPosition and Runtime.positionCF and now>=Runtime.nextPosTick then
			Runtime.nextPosTick=now+0.05
			local r=root()

			if r then
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
	Accent=Color3.fromRGB(158,112,255),
	Accent2=Color3.fromRGB(198,128,255),
	Success=Color3.fromRGB(177,126,255),
	Danger=Color3.fromRGB(255,102,119),
	Text=Color3.fromRGB(232,239,247),
	Muted=Color3.fromRGB(184,190,208),
	Border=Color3.fromRGB(116,102,150),
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
	return b
end

local function viewportSize()
	local camera=workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(800,600)
end

local initialViewport=viewportSize()
local minWindowWidth=math.max(240,math.min(360,initialViewport.X-12))
local minWindowHeight=math.max(280,math.min(340,initialViewport.Y-12))
local defaultWidth=math.min(760,math.max(minWindowWidth,math.floor(initialViewport.X*0.78)))
local defaultHeight=math.min(540,math.max(minWindowHeight,math.floor(initialViewport.Y*0.75)))

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
local mainStroke=stroke(main,THEME.Border,1.2,0.38)
gradient(mainStroke,THEME.Accent,THEME.Border,35)
gradient(main,THEME.Panel,THEME.Bg,125)

local topBar=Instance.new("Frame")
topBar.Parent=main
topBar.Size=UDim2.new(1,0,0,62)
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
brand.Size=UDim2.fromOffset(40,38)
brand.Position=UDim2.fromOffset(12,12)
brand.TextColor3=THEME.Accent
brand.TextSize=15

local title=label(topBar,"ROCK BUG HUB",16,Enum.Font.GothamBold,THEME.Text)
title.Size=UDim2.new(1,-170,0,24)
title.Position=UDim2.fromOffset(68,9)

local author=label(topBar,"УПРАВЛЕНИЕ СКРИПТОМ",9,Enum.Font.GothamBold,THEME.Muted)
author.Size=UDim2.new(1,-170,0,16)
author.Position=UDim2.fromOffset(69,34)

local closeBtn=button(topBar,"×",THEME.SurfaceAlt)
closeBtn.Size=UDim2.fromOffset(30,30)
closeBtn.Position=UDim2.new(1,-42,0,16)
closeBtn.TextColor3=THEME.Danger
closeBtn.TextSize=19

local minimizeBtn=button(topBar,"−",THEME.SurfaceAlt)
minimizeBtn.Size=UDim2.fromOffset(30,30)
minimizeBtn.Position=UDim2.new(1,-78,0,16)
minimizeBtn.TextColor3=THEME.Muted
minimizeBtn.TextSize=18

local rail=Instance.new("Frame")
rail.Parent=main
rail.Size=UDim2.new(0,108,1,-62)
rail.Position=UDim2.fromOffset(0,62)
rail.BackgroundColor3=THEME.Panel
rail.BackgroundTransparency=0.20
rail.BorderSizePixel=0

local railLine=Instance.new("Frame")
railLine.Parent=rail
railLine.Size=UDim2.new(0,1,1,0)
railLine.Position=UDim2.new(1,-1,0,0)
railLine.BackgroundColor3=THEME.Border
railLine.BackgroundTransparency=0.62
railLine.BorderSizePixel=0

local function styleTab(tab,y)
	tab.Size=UDim2.new(1,-18,0,82)
	tab.Position=UDim2.fromOffset(9,y)
	tab.TextSize=12
	tab.TextWrapped=true
	tab.BackgroundTransparency=0.52
	local tabStroke=stroke(tab,THEME.Border,1,0.70)
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

local bugTab=button(rail,"◈\nКАМЕНЬ",THEME.Accent)
styleTab(bugTab,10)

local trainTab=button(rail,"▤\nКАЧ",THEME.Surface)
styleTab(trainTab,100)

local rebTab=button(rail,"↻\nРЕБИРТ",THEME.Surface)
styleTab(rebTab,190)

local rescanBtn=button(rail,"ОБНОВИТЬ",THEME.SurfaceAlt)
rescanBtn.Size=UDim2.new(1,-14,0,34)
rescanBtn.Position=UDim2.fromOffset(7,280)
rescanBtn.TextSize=10

local panicBtn=button(rail,"СТОП",THEME.Danger)
panicBtn.Size=UDim2.new(1,-14,0,38)
panicBtn.Position=UDim2.new(0,7,1,-47)
panicBtn.TextSize=11

local content=Instance.new("Frame")
content.Parent=main
content.Size=UDim2.new(1,-108,1,-62)
content.Position=UDim2.fromOffset(108,62)
content.BackgroundColor3=THEME.Bg
content.BackgroundTransparency=0.38
content.BorderSizePixel=0
content.ClipsDescendants=true

local quickBar=Instance.new("Frame")
quickBar.Parent=content
quickBar.Size=UDim2.new(1,-18,0,98)
quickBar.Position=UDim2.fromOffset(9,8)
quickBar.BackgroundColor3=THEME.Surface
quickBar.BackgroundTransparency=0.14
quickBar.BorderSizePixel=0
corner(quickBar,10)
stroke(quickBar,THEME.Accent,1,0.66)
gradient(quickBar,THEME.Surface,THEME.Panel,0)

local quickTitle=label(quickBar,"⚡  ВАЖНОЕ",13,Enum.Font.GothamBold,THEME.Text)
quickTitle.Size=UDim2.new(1,-22,0,24)
quickTitle.Position=UDim2.fromOffset(11,7)

local quickBody=Instance.new("Frame")
quickBody.Parent=quickBar
quickBody.Size=UDim2.new(1,-16,0,56)
quickBody.Position=UDim2.fromOffset(8,35)
quickBody.BackgroundTransparency=1

local statusPanel=Instance.new("Frame")
statusPanel.Parent=content
statusPanel.Size=UDim2.new(1,-18,0,58)
statusPanel.Position=UDim2.new(0,9,1,-66)
statusPanel.BackgroundColor3=THEME.Surface
statusPanel.BackgroundTransparency=0.30
statusPanel.BorderSizePixel=0
corner(statusPanel,10)
stroke(statusPanel,THEME.Border,1,0.68)

local statusTitle=label(statusPanel,"⌁  СТАТУС",10,Enum.Font.GothamBold,THEME.Accent)
statusTitle.Size=UDim2.new(1,-16,0,18)
statusTitle.Position=UDim2.fromOffset(8,2)

local status=label(statusPanel,"●  готово",10,Enum.Font.GothamBold,THEME.Text)
status.Size=UDim2.new(0.62,-10,0,28)
status.Position=UDim2.fromOffset(6,24)
status.BackgroundColor3=THEME.SurfaceAlt
status.BackgroundTransparency=0.34
status.BorderSizePixel=0
status.TextXAlignment=Enum.TextXAlignment.Center
status.TextWrapped=false
status.TextTruncate=Enum.TextTruncate.AtEnd
corner(status,7)
stroke(status,THEME.Border,1,0.72)

local net=label(statusPanel,"PING ? | УДАР 0/s",9,Enum.Font.GothamBold,THEME.Accent)
net.Size=UDim2.new(0.38,-8,0,28)
net.Position=UDim2.new(0.62,2,0,24)
net.BackgroundColor3=THEME.SurfaceAlt
net.BackgroundTransparency=0.34
net.BorderSizePixel=0
net.TextXAlignment=Enum.TextXAlignment.Center
net.TextWrapped=false
net.TextTruncate=Enum.TextTruncate.AtEnd
corner(net,7)
stroke(net,THEME.Border,1,0.72)

Runtime.ui={status=status,net=net}

local function makePage(color)
	local page=Instance.new("ScrollingFrame")
	page.Parent=content
	page.Size=UDim2.new(1,-18,1,-188)
	page.Position=UDim2.fromOffset(9,114)
	page.BackgroundTransparency=1
	page.BorderSizePixel=0
	page.ScrollBarThickness=3
	page.ScrollBarImageColor3=color
	page.CanvasSize=UDim2.new(0,0,0,0)
	page.ScrollingDirection=Enum.ScrollingDirection.Y
	return page
end

local bugPage=makePage(THEME.Accent)
local trainPage=makePage(THEME.Success)
trainPage.Visible=false
local rebPage=makePage(THEME.Accent2)
rebPage.Visible=false

local resizeHandle=button(main,"◢",THEME.SurfaceAlt)
resizeHandle.Size=UDim2.fromOffset(24,24)
resizeHandle.Position=UDim2.new(1,-24,1,-24)
resizeHandle.TextColor3=THEME.Accent
resizeHandle.TextSize=13
resizeHandle.BackgroundTransparency=0.42

local miniButton=button(gui,"RH\n+",THEME.Panel)
miniButton.Size=UDim2.fromOffset(52,52)
miniButton.Position=main.Position
miniButton.TextColor3=THEME.Accent
miniButton.TextSize=12
miniButton.Visible=false
miniButton.Active=true
miniButton.ZIndex=30
stroke(miniButton,THEME.Accent,1.2,0.30)
gradient(miniButton,THEME.Surface,THEME.Bg,135)

local function listLayout(frame)
	local pad=Instance.new("UIPadding")
	pad.Parent=frame
	pad.PaddingTop=UDim.new(0,4)
	pad.PaddingBottom=UDim.new(0,12)
	pad.PaddingLeft=UDim.new(0,2)
	pad.PaddingRight=UDim.new(0,5)

	local list=Instance.new("UIListLayout")
	list.Parent=frame
	list.SortOrder=Enum.SortOrder.LayoutOrder
	list.Padding=UDim.new(0,8)
	return list
end

local bugList=listLayout(bugPage)
local trainList=listLayout(trainPage)
local rebList=listLayout(rebPage)

local function updateCanvas()
	task.defer(function()
		bugPage.CanvasSize=UDim2.new(0,0,0,bugList.AbsoluteContentSize.Y+20)
		trainPage.CanvasSize=UDim2.new(0,0,0,trainList.AbsoluteContentSize.Y+20)
		rebPage.CanvasSize=UDim2.new(0,0,0,rebList.AbsoluteContentSize.Y+20)
	end)
end

addConn(bugList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
addConn(trainList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
addConn(rebList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))

local function card(parent,height)
	local f=Instance.new("Frame")
	f.Parent=parent
	f.Size=UDim2.new(1,0,0,height)
	f.BackgroundColor3=THEME.Surface
	f.BackgroundTransparency=0.16
	f.BorderSizePixel=0
	corner(f,10)
	stroke(f,THEME.Border,1,0.52)
	gradient(f,THEME.Surface,THEME.Bg,115)
	return f
end

local function makeFeaturePanel(parent,titleText,height,columns)
	local panel=card(parent,height)
	panel.LayoutOrder=1

	local icon=label(panel,"ϟ",16,Enum.Font.GothamBold,THEME.Accent)
	icon.Size=UDim2.fromOffset(24,24)
	icon.Position=UDim2.fromOffset(12,7)
	icon.TextXAlignment=Enum.TextXAlignment.Center

	local heading=label(panel,titleText,14,Enum.Font.GothamBold,THEME.Text)
	heading.Size=UDim2.new(1,-50,0,24)
	heading.Position=UDim2.fromOffset(42,7)

	local body=Instance.new("Frame")
	body.Parent=panel
	body.Size=UDim2.new(1,-22,1,-45)
	body.Position=UDim2.fromOffset(11,37)
	body.BackgroundTransparency=1

	local grid=Instance.new("UIGridLayout")
	grid.Parent=body
	grid.SortOrder=Enum.SortOrder.LayoutOrder
	grid.CellPadding=UDim2.fromOffset(10,10)
	grid.CellSize=UDim2.new(1/(columns or 2),-5,0,92)
	return panel,body,grid
end

local function makeSettingsPanel(parent,titleText,height)
	local panel=card(parent,height)

	local icon=label(panel,"☷",15,Enum.Font.GothamBold,THEME.Accent)
	icon.Size=UDim2.fromOffset(24,24)
	icon.Position=UDim2.fromOffset(12,7)
	icon.TextXAlignment=Enum.TextXAlignment.Center

	local heading=label(panel,titleText,14,Enum.Font.GothamBold,THEME.Text)
	heading.Size=UDim2.new(1,-50,0,24)
	heading.Position=UDim2.fromOffset(42,7)

	local body=Instance.new("Frame")
	body.Parent=panel
	body.Size=UDim2.new(1,-18,1,-42)
	body.Position=UDim2.fromOffset(9,36)
	body.BackgroundTransparency=1

	local list=Instance.new("UIListLayout")
	list.Parent=body
	list.SortOrder=Enum.SortOrder.LayoutOrder
	list.Padding=UDim.new(0,4)
	return panel,body,list
end

local function makeSlider(parent,name,desc,initial,callback)
	local row=Instance.new("TextButton")
	row.Parent=parent
	row.Size=UDim2.new(1,0,0,56)
	row.Text=""
	row.AutoButtonColor=false
	row.BackgroundColor3=THEME.Surface
	row.BackgroundTransparency=0.22
	row.BorderSizePixel=0
	corner(row,6)
	stroke(row,THEME.Border,1,0.82)

	local n=label(row,name,13,Enum.Font.GothamBold,THEME.Text)
	n.Size=UDim2.new(1,-80,0,20)
	n.Position=UDim2.new(0,11,0,5)

	local d=label(row,desc,9,Enum.Font.Gotham,THEME.Muted)
	d.Size=UDim2.new(1,-80,0,18)
	d.Position=UDim2.new(0,11,0,30)

	local track=Instance.new("Frame")
	track.Parent=row
	track.Size=UDim2.new(0,54,0,25)
	track.Position=UDim2.new(1,-62,0,15)
	track.BorderSizePixel=0
	track.BackgroundTransparency=0.04
	corner(track,13)

	local knob=Instance.new("Frame")
	knob.Parent=track
	knob.Size=UDim2.new(0,19,0,19)
	knob.Position=UDim2.new(0,3,0,3)
	knob.BackgroundColor3=THEME.Text
	knob.BorderSizePixel=0
	corner(knob,10)

	local state=initial and true or false
	local api={}

	local function paint()
		if state then
			track.BackgroundColor3=THEME.Success
			knob.Position=UDim2.new(1,-22,0,3)
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
	local rowStroke=stroke(row,THEME.Border,1.2,0.52)

	local glyph=label(row,name=="АНТИ-AFK" and "♢" or "◌",17,Enum.Font.GothamBold,THEME.Accent)
	glyph.Size=UDim2.fromOffset(20,24)
	glyph.Position=UDim2.fromOffset(5,16)
	glyph.TextXAlignment=Enum.TextXAlignment.Center

	local n=label(row,name,11,Enum.Font.GothamBold,THEME.Text)
	n.Size=UDim2.new(1,-48,1,0)
	n.Position=UDim2.fromOffset(28,0)

	local stateDot=Instance.new("Frame")
	stateDot.Parent=row
	stateDot.Size=UDim2.fromOffset(10,10)
	stateDot.Position=UDim2.new(1,-17,0,8)
	stateDot.BorderSizePixel=0
	corner(stateDot,5)

	local state=initial and true or false
	local api={}
	local function paint()
		row.BackgroundColor3=state and THEME.SurfaceAlt or THEME.Surface
		row.BackgroundTransparency=state and 0.08 or 0.30
		n.TextColor3=state and THEME.Text or THEME.Muted
		rowStroke.Color=state and THEME.Accent or THEME.Border
		rowStroke.Transparency=state and 0.18 or 0.62
		glyph.TextColor3=state and THEME.Accent2 or THEME.Muted
		stateDot.BackgroundColor3=state and THEME.Accent or THEME.Muted
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
	local tileStroke=stroke(tile,THEME.Border,1.2,0.50)

	local glyph=label(tile,iconText,22,Enum.Font.GothamBold,THEME.Text)
	glyph.Size=UDim2.fromOffset(32,30)
	glyph.Position=UDim2.new(0.5,-16,0,5)
	glyph.TextXAlignment=Enum.TextXAlignment.Center

	local stateDot=Instance.new("Frame")
	stateDot.Parent=tile
	stateDot.Size=UDim2.fromOffset(8,8)
	stateDot.Position=UDim2.new(1,-15,0,8)
	stateDot.BorderSizePixel=0
	corner(stateDot,4)

	local n=label(tile,name,13,Enum.Font.GothamBold,THEME.Text)
	n.Size=UDim2.new(1,-12,0,22)
	n.Position=UDim2.fromOffset(6,37)
	n.TextXAlignment=Enum.TextXAlignment.Center

	local d=label(tile,desc,9,Enum.Font.Gotham,THEME.Muted)
	d.Size=UDim2.new(1,-12,0,24)
	d.Position=UDim2.fromOffset(6,62)
	d.TextXAlignment=Enum.TextXAlignment.Center

	local state=initial and true or false
	local api={}
	local function paint()
		tile.BackgroundColor3=state and THEME.SurfaceAlt or THEME.Surface
		tile.BackgroundTransparency=state and 0.06 or 0.22
		tileStroke.Color=state and THEME.Accent or THEME.Border
		tileStroke.Transparency=state and 0.12 or 0.54
		glyph.TextColor3=state and THEME.Accent or THEME.Text
		stateDot.BackgroundColor3=state and THEME.Success or THEME.Muted
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
	row.Size=UDim2.new(1,0,0,56)
	row.BackgroundColor3=THEME.Surface
	row.BackgroundTransparency=0.22
	row.BorderSizePixel=0
	corner(row,6)
	stroke(row,THEME.Border,1,0.82)

	local n=label(row,name,13,Enum.Font.GothamBold,THEME.Text)
	n.Size=UDim2.new(1,-88,0,20)
	n.Position=UDim2.new(0,11,0,5)

	local d=label(row,desc,9,Enum.Font.Gotham,THEME.Muted)
	d.Size=UDim2.new(1,-88,0,18)
	d.Position=UDim2.new(0,11,0,30)

	local box=Instance.new("TextBox")
	box.Parent=row
	box.Size=UDim2.new(0,68,0,30)
	box.Position=UDim2.new(1,-76,0,13)
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
	stroke(box,THEME.Accent2,1,0.45)

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

-- BUG PAGE

local bugFeaturePanel,bugFeatureBody=makeFeaturePanel(bugPage,"ГЛАВНЫЕ ФУНКЦИИ",240,2)
local bugSettingsPanel,bugSettingsBody=makeSettingsPanel(bugPage,"НАСТРОЙКИ КАМНЯ",254)
bugSettingsPanel.LayoutOrder=2

local selectCard=card(bugSettingsBody,62)
selectCard.LayoutOrder=1
local selectTitle=label(selectCard,"АВТО-КАМЕНЬ ПО РЕБАМ",9,Enum.Font.GothamBlack,THEME.Accent2)
selectTitle.Size=UDim2.new(1,-20,0,18)
selectTitle.Position=UDim2.new(0,12,0,8)

local selectName=label(selectCard,"-",10,Enum.Font.GothamBlack,THEME.Warm)
selectName.Size=UDim2.new(1,-20,0,28)
selectName.Position=UDim2.new(0,12,0,30)

Runtime.ui.autoRockTitle=selectTitle
Runtime.ui.autoRockName=selectName

local rockCard=card(bugSettingsBody,142)
rockCard.LayoutOrder=2
local rockTitle=label(rockCard,"КАМНИ",12,Enum.Font.GothamBlack,THEME.Text)
rockTitle.Size=UDim2.new(1,-20,0,20)
rockTitle.Position=UDim2.new(0,12,0,8)

local rockList=Instance.new("ScrollingFrame")
rockList.Parent=rockCard
rockList.Size=UDim2.new(1,-14,0,105)
rockList.Position=UDim2.new(0,7,0,30)
rockList.BackgroundTransparency=1
rockList.BorderSizePixel=0
rockList.ScrollBarThickness=2
rockList.CanvasSize=UDim2.new(0,0,0,0)

local rockLayout=Instance.new("UIListLayout")
rockLayout.Parent=rockList
rockLayout.SortOrder=Enum.SortOrder.LayoutOrder
rockLayout.Padding=UDim.new(0,5)

local rockButtons={}
local rockButtonConnections={}

local function disconnectRockButtonConnections()
	for _,connection in ipairs(rockButtonConnections) do
		safe(function() connection:Disconnect() end)
	end

	rockButtonConnections={}
end

local function refreshRockList()
	disconnectRockButtonConnections()

	for _,b in ipairs(rockButtons) do
		if b and b.Parent then b:Destroy() end
	end
	rockButtons={}

	for i,row in ipairs(ROCKS) do
		local info=rockCache[row.req]
		local active=Runtime.selectedRock and Runtime.selectedRock.id==row.id

		local b=button(rockList,(active and "● " or "○ ")..row.label.."  |  "..(info and "found" or "missing"),
			active and THEME.Accent or THEME.SurfaceAlt)
		b.Size=UDim2.new(1,-3,0,32)
		b.LayoutOrder=i
		b.TextXAlignment=Enum.TextXAlignment.Left

		local p=Instance.new("UIPadding")
		p.Parent=b
		p.PaddingLeft=UDim.new(0,10)

		local connection=b.Activated:Connect(function()
			Runtime.autoRockSelection=false
			Runtime.selectedRock=row
			selectTitle.Text="ВЫБРАНО ВРУЧНУЮ"
			selectName.Text=row.label.." | req "..tostring(row.req)
			refreshRockList()
			setStatus("Камень: "..row.label)
		end)
		table.insert(rockButtonConnections,connection)

		table.insert(rockButtons,b)
	end

	rockList.CanvasSize=UDim2.new(0,0,0,#ROCKS*37+4)
end

Runtime.refreshRockList=refreshRockList

local lockRockSlider
local bugSlider

lockRockSlider=makeFeatureToggle(bugFeatureBody,"◇","ФИКСАЦИЯ","держит у камня",false,function(on,api)
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

bugSlider=makeFeatureToggle(bugFeatureBody,"▷","АВТОУДАР","сам бьёт камень",false,function(on,api)
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

local remoteSlider=makeFeatureToggle(bugFeatureBody,"◎","УСКОРЕНИЕ","ускоряет отправку",true,function(on)
	Runtime.directRemoteEnabled=on
	setStatus("УСКОРЕНИЕ: "..(on and "включено" or "выключено"))
end)

-- TRAIN PAGE

local trainFeaturePanel,trainFeatureBody=makeFeaturePanel(trainPage,"ВЫБЕРИ ВИД КАЧА",342,2)
trainFeaturePanel.LayoutOrder=1
local trainSettingsPanel,trainSettingsBody=makeSettingsPanel(trainPage,"ДОПОЛНИТЕЛЬНО",220)
trainSettingsPanel.LayoutOrder=2

local lockPosSlider=makeSlider(trainSettingsBody,"ФИКСАЦИЯ ПОЗИЦИИ","не даёт персонажу сдвигаться",false,function(on,api)
	if on then
		local r=root()

		if not r then
			setStatus("LOCK POSITION: нет root")
			api.Set(false,true)
			return
		end

		Runtime.positionCF=r.CFrame
		Runtime.lockPosition=true
		Runtime.nextPosTick=0
		disableKingLock()
		if Runtime.leverRefs.kingLock then Runtime.leverRefs.kingLock.Set(false,true) end
		setStatus("ПОЗИЦИЯ: зафиксирована")
	else
		Runtime.lockPosition=false
		Runtime.positionCF=nil
		setStatus("ПОЗИЦИЯ: свободна")
	end
end)

Runtime.leverRefs.lockPosition=lockPosSlider

local visualSlider=makeSlider(trainSettingsBody,"МЕНЬШЕ ЭФФЕКТОВ","повышает плавность игры",false,function(on)
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

local wifiHoldSlider=makeSlider(trainSettingsBody,"ПАУЗА СЕТИ","ручная заморозка при плохом Wi-Fi",false,function(on)
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

local rebFeaturePanel,rebFeatureBody=makeFeaturePanel(rebPage,"РЕБИРТ И РАЗМЕР",240,2)
rebFeaturePanel.LayoutOrder=1
local rebSettingsPanel,rebSettingsBody=makeSettingsPanel(rebPage,"РАЗМЕР ПЕРСОНАЖА",106)
rebSettingsPanel.LayoutOrder=2

local rebInfo=card(rebPage,66)
rebInfo.LayoutOrder=3
local rebInfoTitle=label(rebInfo,"AUTO REBIRTH",12,Enum.Font.GothamBlack,THEME.Accent2)
rebInfoTitle.Size=UDim2.new(1,-20,0,20)
rebInfoTitle.Position=UDim2.new(0,10,0,8)

local rebInfoText=label(rebInfo,"Rebirth каждые 1.2с • King Gym: -8626 / 17 / -5730",9,Enum.Font.GothamBold,THEME.Muted)
rebInfoText.Size=UDim2.new(1,-20,0,28)
rebInfoText.Position=UDim2.new(0,10,0,31)

local autoRebSlider=makeFeatureToggle(rebFeatureBody,"↻","АВТО РЕБИРТ","реб при готовности",false,function(on,api)
	if on and not findRebirthRemote() then
		api.Set(false,true)
		setStatus("РЕБИРТ: функция игры не найдена")
		return
	end

	Runtime.autoRebirth=on
	Runtime.nextRebirth=0
	setStatus("АВТО РЕБИРТ: "..(on and "включён" or "выключен"))
end)

Runtime.leverRefs.autoRebirth=autoRebSlider

local sizeInput=makeNumberInput(rebSettingsBody,"НУЖНЫЙ РАЗМЕР","введи число от 0.1 до 1000",1,function(value)
	Runtime.sizeTarget=value
	if Runtime.autoSize then Runtime.nextSize=0 end
	setStatus("РАЗМЕР: "..tostring(value))
end)

local autoSizeSlider=makeFeatureToggle(rebFeatureBody,"◫","АВТО РАЗМЕР","держит введённое число",false,function(on,api)
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

local kingLockSlider=makeFeatureToggle(rebFeatureBody,"♛","KING ЗОНА","держит в King Gym",false,function(on,api)
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

local activeTab="bug"
local minimized=false
local expandedSize=main.Size

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
	bugPage.Visible=(not minimized) and bug
	trainPage.Visible=(not minimized) and train
	rebPage.Visible=(not minimized) and reb
	paintTab(bugTab,bug)
	paintTab(trainTab,train)
	paintTab(rebTab,reb)
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
	else
		main.Size=expandedSize
		main.Position=clampOffsetPosition(miniButton.Position,expandedSize)
		miniButton.Visible=false
		main.Visible=true
		showTab(activeTab)
	end
end

addConn(bugTab.Activated:Connect(function() showTab("bug") end))
addConn(trainTab.Activated:Connect(function() showTab("train") end))
addConn(rebTab.Activated:Connect(function() showTab("reb") end))
addConn(minimizeBtn.Activated:Connect(function() setMinimized(true) end))

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
			local dynamicMinWidth=math.max(240,math.min(360,viewport.X-12))
			local dynamicMinHeight=math.max(280,math.min(340,viewport.Y-12))
			local maxWidth=math.max(dynamicMinWidth,viewport.X-main.Position.X.Offset-4)
			local maxHeight=math.max(dynamicMinHeight,viewport.Y-main.Position.Y.Offset-4)
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
	if not Runtime.autoResumeAfterRespawn or not resumeMode then return end

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

		local resumed=false
		if resumeMode=="bug" then
			resumed=startBug()
		elseif resumeMode=="train" and resumeTrain then
			resumed=startTrain(resumeTrain)
		end

		if resumed and resumePositionLock and resumePositionCF then
			Runtime.lockPosition=true
			Runtime.positionCF=resumePositionCF
			Runtime.nextPosTick=0
			if Runtime.leverRefs.lockPosition then Runtime.leverRefs.lockPosition.Set(true,true) end
		end

		if resumed then
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
