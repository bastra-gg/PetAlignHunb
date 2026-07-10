-- RockBugHub v19 CompactStable
-- Clean rebuild: single scheduler, hard stop, adaptive network throttle.
-- No getgc patching, no full workspace scans inside fast loops, no unknown train remote spam.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Stats=game:GetService("Stats")
local VirtualUser=game:GetService("VirtualUser")
local UserInputService=game:GetService("UserInputService")

local lp=Players.LocalPlayer
local HUB_VERSION="RockBugHub_v19_CompactStable"

local ENV=(type(getgenv)=="function" and getgenv()) or _G

-- Stop previous clean-runtime build.
pcall(function()
	if ENV.RockBugRuntime and type(ENV.RockBugRuntime.Stop)=="function" then
		ENV.RockBugRuntime:Stop("replaced")
	end
end)

-- Remove old windows only. No invasive getgc scan.
pcall(function()
	local pg=lp:WaitForChild("PlayerGui")
	for _,g in ipairs(pg:GetChildren()) do
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
	lockRock=false,
	lockPosition=false,
	lockCF=nil,
	positionCF=nil,
	activeTool=nil,
	nextAction=0,
	nextEquip=0,
	nextNearCheck=0,
	nextNetUpdate=0,
	nextCooldownSweep=0,
	punchCycle=0,
	pingMs=0,
	remoteTokens=0,
	remoteLastRefill=os.clock(),
	remoteSentWindow=0,
	remoteWindowStart=os.clock(),
	remotePps=0,
	directRemoteEnabled=true,
	antiAfkEnabled=false,
	visualLow=false,
	visualSaved={},
	characterCollisionSaved={},
	characterGhost=false,
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
		Runtime.ui.net.Text=("PING %sms  |  REMOTE %.1f/s"):format(
			tostring(math.floor((Runtime.pingMs or 0)+0.5)),
			Runtime.remotePps or 0
		)
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

	for _,v in ipairs(descendants) do
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

	-- Treat comma as thousands separator unless the number looks like decimal comma.
	raw=raw:gsub(",","")
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

local function chooseSafeRockByRebirths()
	local rebs,source=readRebirths()

	-- Conservative per-hit target. This avoids blindly choosing Jungle.
	-- It is not a full pet-XP calculator because pet level/current XP is unavailable here.
	local safeHitCap=30000

	if rebs then
		local best=nil
		local bestXp=-1

		for _,row in ipairs(ROCKS) do
			if rockCache[row.req] then
				local xp=(rebs+20)*row.mult

				if xp<=safeHitCap and xp>bestXp then
					best=row
					bestXp=xp
				end
			end
		end

		if best then
			return best,("ребы %d (%s) | ~%.1f XP/hit"):format(rebs,source,bestXp)
		end
	end

	-- Safe fallback order. Never default to Jungle.
	local fallback={"Legends","Inferno","Mystic","Frozen","Golden","Large","Punching","Tiny"}

	for _,id in ipairs(fallback) do
		for _,row in ipairs(ROCKS) do
			if row.id==id and rockCache[row.req] then
				return row,rebs and ("ребы "..tostring(rebs).." | safe fallback") or "ребы не найдены | safe fallback"
			end
		end
	end

	return ROCKS[#ROCKS],"камни не найдены"
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
	"LastUse","lastUse","LastSwing","lastSwing","LastAttack","lastAttack",
	"CanUse","canUse","CanSwing","canSwing","Ready","ready"
}

local function clearCooldownsOnce(tool)
	if not tool then return end

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

local function findGuiButtonForTrain(t)
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return nil end

	local scanned=0

	for _,d in ipairs(pg:GetDescendants()) do
		scanned=scanned+1
		if scanned>2600 then break end

		if d:IsA("TextButton") or d:IsA("ImageButton") then
			local full=string.lower(d:GetFullName())

			-- Never touch trade-related UI.
			if not full:find("trade",1,true) then
				local txt=textOfGui(d)
				if containsAny(txt,t.words) then
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

	local clicked=false

	safe(function()
		btn:Activate()
		clicked=true
	end)

	safe(function()
		if type(firesignal)=="function" then
			firesignal(btn.Activated)
			clicked=true
		end
	end)

	if clicked then task.wait(0.18) end
	return clicked
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

local function getPingMs()
	local ok,res=safe(function()
		local network=Stats:FindFirstChild("Network")
		local server=network and network:FindFirstChild("ServerStatsItem")
		local ping=server and server:FindFirstChild("Data Ping")

		if ping then
			local text=tostring(ping:GetValueString())
			return tonumber(text:match("([%d%.]+)"))
		end
	end)

	if ok and res then
		return tonumber(res) or 0
	end

	return 0
end

local function effectiveRates()
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

	return 10,7
end

local function refillRemoteTokens()
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

local function countRemoteSent()
	Runtime.remoteSentWindow=Runtime.remoteSentWindow+1

	local now=os.clock()
	local elapsed=now-Runtime.remoteWindowStart

	if elapsed>=1 then
		Runtime.remotePps=Runtime.remoteSentWindow/elapsed
		Runtime.remoteSentWindow=0
		Runtime.remoteWindowStart=now
	end
end

local function tryPunchRemote()
	if not Runtime.directRemoteEnabled then return false end

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

	return false
end


-- ---------- CHARACTER STABILITY ----------

local function setCharacterGhost(on)
	if on==Runtime.characterGhost then return end
	Runtime.characterGhost=on

	local c=char()
	if not c then return end

	if on then
		Runtime.characterCollisionSaved={}

		for _,part in ipairs(c:GetDescendants()) do
			if part:IsA("BasePart") then
				Runtime.characterCollisionSaved[part]={
					CanCollide=part.CanCollide,
					CanTouch=part.CanTouch,
					Massless=part.Massless,
				}

				safe(function()
					part.CanCollide=false
					part.CanTouch=false
					part.Massless=true
				end)
			end
		end

		local h=hum()
		if h then
			safe(function()
				h.AutoRotate=false
				h.PlatformStand=false
			end)
		end
	else
		for part,state in pairs(Runtime.characterCollisionSaved) do
			if part and part.Parent then
				safe(function()
					part.CanCollide=state.CanCollide
					part.CanTouch=state.CanTouch
					part.Massless=state.Massless
				end)
			end
		end

		Runtime.characterCollisionSaved={}

		local h=hum()
		if h then
			safe(function()
				h.AutoRotate=true
				h.PlatformStand=false
			end)
		end
	end
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

	local hand=c:FindFirstChild("RightHand")
		or c:FindFirstChild("Right Arm")
		or c:FindFirstChild("HumanoidRootPart")

	if hand and hand:IsA("BasePart") then
		safe(function()
			firetouchinterest(hand,target,0)
			firetouchinterest(hand,target,1)
		end)
	end
end

local function insideRockCF(row)
	local info=getRockInfo(row)
	if not info then return nil,"камень не найден" end

	local body=info.body or info.hit
	if not body or not body:IsA("BasePart") then return nil,"нет BasePart камня" end

	local pos=body.Position

	if info.left and info.right
		and info.left:IsA("BasePart")
		and info.right:IsA("BasePart") then
		pos=(info.left.Position+info.right.Position)/2
	elseif info.hit and info.hit:IsA("BasePart") then
		local towardBody=body.Position-info.hit.Position
		if towardBody.Magnitude>0.01 then
			pos=info.hit.Position+towardBody.Unit*math.min(towardBody.Magnitude*0.65,8)
		end
	end

	pos=pos-Vector3.new(0,1.6,0)
	return CFrame.new(pos)*CFrame.Angles(0,math.rad(body.Orientation.Y),0)
end

local function teleportInsideSelected()
	local r=root()
	if not r then return false,"нет HumanoidRootPart" end

	local cf,err=insideRockCF(Runtime.selectedRock)
	if not cf then return false,err end

	setCharacterGhost(true)

	r.CFrame=cf
	r.AssemblyLinearVelocity=Vector3.new(0,0,0)
	r.AssemblyAngularVelocity=Vector3.new(0,0,0)

	Runtime.lockCF=cf
	Runtime.nextLockTick=0
	return true
end

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

		setStatus("VISUAL LOW: ON")
	else
		for obj,saved in pairs(Runtime.visualSaved) do
			if obj and obj.Parent then
				if saved.Enabled~=nil then safe(function() obj.Enabled=saved.Enabled end) end
				if saved.CastShadow~=nil then safe(function() obj.CastShadow=saved.CastShadow end) end
			end
		end

		Runtime.visualSaved={}
		setStatus("VISUAL LOW: OFF")
	end
end

-- ---------- MODE CONTROL ----------

local function unequip()
	local h=hum()
	if h then safe(function() h:UnequipTools() end) end
end

local function stopMode(reason)
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

	setCharacterGhost(false)
	unequip()

	if Runtime.leverRefs.bug then Runtime.leverRefs.bug.Set(false,true) end

	for _,lever in pairs(Runtime.leverRefs.train or {}) do
		if lever then lever.Set(false,true) end
	end

	if Runtime.leverRefs.lockRock then Runtime.leverRefs.lockRock.Set(false,true) end

	setStatus(reason or "STOP")
end

local function panicStop()
	stopMode("PANIC STOP")
	Runtime.lockPosition=false
	Runtime.positionCF=nil

	if Runtime.leverRefs.lockPosition then Runtime.leverRefs.lockPosition.Set(false,true) end

	setVisualLow(false)

	if Runtime.leverRefs.visualLow then Runtime.leverRefs.visualLow.Set(false,true) end
end

local function startBug()
	stopMode(nil)

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
	Runtime.activeTool=tool

	Runtime.modeToken=Runtime.modeToken+1
	Runtime.mode="bug"
	Runtime.lockRock=true
	Runtime.nextAction=0
	Runtime.nextEquip=0
	Runtime.nextCooldownSweep=0
	Runtime.nextNearCheck=0

	if Runtime.leverRefs.lockRock then Runtime.leverRefs.lockRock.Set(true,true) end

	setStatus("BUG ON | "..tostring(msg))
	return true
end

local function startTrain(t)
	stopMode(nil)

	local tool,msg=ensureTrainTool(t)
	Runtime.activeTool=tool
	Runtime.selectedTrain=t

	Runtime.modeToken=Runtime.modeToken+1
	Runtime.mode="train"
	Runtime.nextAction=0
	Runtime.nextEquip=0
	Runtime.nextCooldownSweep=0

	setStatus("TRAIN ON | "..tostring(msg))
	return true
end

-- ---------- SINGLE SCHEDULER ----------

local function scheduler()
	while Runtime.alive do
		local now=os.clock()

		if now>=Runtime.nextNetUpdate then
			Runtime.nextNetUpdate=now+1
			Runtime.pingMs=getPingMs()
			setNetText()

			if Runtime.pingMs>=700 and Runtime.mode=="bug" then
				setStatus("NETWORK THROTTLE: remote paused, ping "..math.floor(Runtime.pingMs))
			elseif Runtime.pingMs>=450 and Runtime.mode then
				setStatus("NETWORK THROTTLE: ping "..math.floor(Runtime.pingMs))
			end
		end

		if Runtime.lockPosition and Runtime.positionCF and now>=Runtime.nextPosTick then
			Runtime.nextPosTick=now+0.05
			local r=root()

			if r then
				r.CFrame=Runtime.positionCF
				r.AssemblyLinearVelocity=Vector3.new(0,0,0)
				r.AssemblyAngularVelocity=Vector3.new(0,0,0)
			end
		end

		if Runtime.mode=="bug" then
			if Runtime.lockRock and Runtime.lockCF and now>=Runtime.nextLockTick then
				Runtime.nextLockTick=now+0.08
				local r=root()

				if r then
					local drift=(r.Position-Runtime.lockCF.Position).Magnitude

					if drift>2.25 then
						r.CFrame=Runtime.lockCF
					end

					r.AssemblyLinearVelocity=Vector3.new(0,0,0)
					r.AssemblyAngularVelocity=Vector3.new(0,0,0)
				end
			end

			if now>=Runtime.nextNearCheck then
				Runtime.nextNearCheck=now+0.35
				local near,why=nearSelectedRock()

				if not near then
					stopMode("AUTO STOP: "..tostring(why))
				end
			end

			if Runtime.mode=="bug" and now>=Runtime.nextAction then
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

				-- Touch only every third cycle.
				if Runtime.punchCycle%3==0 then
					oneTouch()
				end
			end

			if now>=Runtime.nextCooldownSweep then
				Runtime.nextCooldownSweep=now+2
				clearCooldownsOnce(Runtime.activeTool)
			end

			if now>=Runtime.nextEquip then
				Runtime.nextEquip=now+1.5

				if not Runtime.activeTool or Runtime.activeTool.Parent~=char() then
					Runtime.activeTool=ensurePunchTool()
				end
			end
		elseif Runtime.mode=="train" then
			if now>=Runtime.nextAction then
				local ping=Runtime.pingMs or 0
				local rate=12

				if ping>=500 then rate=4
				elseif ping>=300 then rate=7
				elseif ping>=200 then rate=9 end

				Runtime.nextAction=now+(1/rate)

				if Runtime.selectedTrain then
					if not Runtime.activeTool or Runtime.activeTool.Parent~=char() then
						Runtime.activeTool=ensureTrainTool(Runtime.selectedTrain)
					end

					if Runtime.activeTool then
						safe(function() Runtime.activeTool:Activate() end)
					end
				end
			end

			if now>=Runtime.nextCooldownSweep then
				Runtime.nextCooldownSweep=now+2
				clearCooldownsOnce(Runtime.activeTool)
			end

			if now>=Runtime.nextEquip then
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

-- ---------- UI ----------

local gui=Instance.new("ScreenGui")
gui.Name=HUB_VERSION
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=999999
gui.Parent=lp:WaitForChild("PlayerGui")

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
end

local function label(parent,text,size,font,color)
	local l=Instance.new("TextLabel")
	l.Parent=parent
	l.BackgroundTransparency=1
	l.Text=text
	l.TextColor3=color or Color3.fromRGB(235,240,250)
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
	b.TextColor3=Color3.fromRGB(245,248,255)
	b.BackgroundColor3=color
	b.BorderSizePixel=0
	b.AutoButtonColor=true
	b.Font=Enum.Font.GothamBlack
	b.TextSize=12
	corner(b,12)
	return b
end

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,390,0,510)
main.Position=UDim2.new(0,10,0,50)
main.BackgroundColor3=Color3.fromRGB(12,14,18)
main.BorderSizePixel=0
main.Active=true

local uiScale=Instance.new("UIScale")
uiScale.Scale=0.82
uiScale.Parent=main

corner(main,20)
stroke(main,Color3.fromRGB(75,90,115),1.4,0.15)

local rail=Instance.new("Frame")
rail.Parent=main
rail.Size=UDim2.new(0,78,1,0)
rail.BackgroundColor3=Color3.fromRGB(20,23,29)
rail.BorderSizePixel=0
corner(rail,20)

local brand=label(rail,"B\nA\nS\nT\nR\nA",17,Enum.Font.GothamBlack,Color3.fromRGB(160,210,255))
brand.Size=UDim2.new(1,0,0,160)
brand.Position=UDim2.new(0,0,0,12)
brand.TextXAlignment=Enum.TextXAlignment.Center

local bugTab=button(rail,"БАГ",Color3.fromRGB(38,105,155))
bugTab.Size=UDim2.new(1,-14,0,42)
bugTab.Position=UDim2.new(0,7,0,188)

local trainTab=button(rail,"КАЧ",Color3.fromRGB(35,40,50))
trainTab.Size=UDim2.new(1,-14,0,42)
trainTab.Position=UDim2.new(0,7,0,238)

local rescanBtn=button(rail,"SCAN",Color3.fromRGB(35,40,50))
rescanBtn.Size=UDim2.new(1,-14,0,36)
rescanBtn.Position=UDim2.new(0,7,0,296)

local panicBtn=button(rail,"STOP",Color3.fromRGB(125,32,47))
panicBtn.Size=UDim2.new(1,-14,0,48)
panicBtn.Position=UDim2.new(0,7,1,-60)

local content=Instance.new("Frame")
content.Parent=main
content.Size=UDim2.new(1,-92,1,-16)
content.Position=UDim2.new(0,86,0,8)
content.BackgroundColor3=Color3.fromRGB(8,10,14)
content.BorderSizePixel=0
corner(content,16)

local title=label(content,"COMPACT NET",19,Enum.Font.GothamBlack,Color3.fromRGB(240,245,255))
title.Size=UDim2.new(1,-86,0,26)
title.Position=UDim2.new(0,14,0,8)

local author=label(content,"The Great Bastra • v19",10,Enum.Font.GothamBold,Color3.fromRGB(120,170,215))
author.Size=UDim2.new(1,-86,0,18)
author.Position=UDim2.new(0,15,0,31)

local minBtn=button(content,"—",Color3.fromRGB(35,45,62))
minBtn.Size=UDim2.new(0,32,0,32)
minBtn.Position=UDim2.new(1,-76,0,8)
minBtn.TextSize=17

local closeBtn=button(content,"×",Color3.fromRGB(90,28,42))
closeBtn.Size=UDim2.new(0,32,0,32)
closeBtn.Position=UDim2.new(1,-40,0,8)
closeBtn.TextSize=18

local restoreBtn=button(gui,"BASTRA",Color3.fromRGB(24,70,105))
restoreBtn.Size=UDim2.new(0,78,0,34)
restoreBtn.Position=UDim2.new(0,10,0,50)
restoreBtn.TextSize=11
restoreBtn.Visible=false

local net=label(content,"PING 0ms | REMOTE 0/s",9,Enum.Font.GothamBold,Color3.fromRGB(150,160,180))
net.Size=UDim2.new(1,-28,0,18)
net.Position=UDim2.new(0,14,0,52)
net.TextXAlignment=Enum.TextXAlignment.Center

local status=label(content,"ready",10,Enum.Font.GothamBold,Color3.fromRGB(220,230,245))
status.Size=UDim2.new(1,-28,0,32)
status.Position=UDim2.new(0,14,0,72)
status.BackgroundColor3=Color3.fromRGB(18,22,30)
status.BackgroundTransparency=0
status.BorderSizePixel=0
status.TextXAlignment=Enum.TextXAlignment.Center
corner(status,11)

Runtime.ui={status=status,net=net}

local bugPage=Instance.new("ScrollingFrame")
bugPage.Parent=content
bugPage.Size=UDim2.new(1,-20,1,-120)
bugPage.Position=UDim2.new(0,10,0,112)
bugPage.BackgroundTransparency=1
bugPage.BorderSizePixel=0
bugPage.ScrollBarThickness=3
bugPage.ScrollBarImageColor3=Color3.fromRGB(90,160,220)
bugPage.CanvasSize=UDim2.new(0,0,0,0)

local trainPage=Instance.new("ScrollingFrame")
trainPage.Parent=content
trainPage.Size=bugPage.Size
trainPage.Position=bugPage.Position
trainPage.BackgroundTransparency=1
trainPage.BorderSizePixel=0
trainPage.ScrollBarThickness=3
trainPage.ScrollBarImageColor3=Color3.fromRGB(80,200,125)
trainPage.CanvasSize=UDim2.new(0,0,0,0)
trainPage.Visible=false

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

local function updateCanvas()
	task.defer(function()
		bugPage.CanvasSize=UDim2.new(0,0,0,bugList.AbsoluteContentSize.Y+20)
		trainPage.CanvasSize=UDim2.new(0,0,0,trainList.AbsoluteContentSize.Y+20)
	end)
end

addConn(bugList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
addConn(trainList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))

local function card(parent,height)
	local f=Instance.new("Frame")
	f.Parent=parent
	f.Size=UDim2.new(1,0,0,height)
	f.BackgroundColor3=Color3.fromRGB(18,21,27)
	f.BorderSizePixel=0
	corner(f,14)
	stroke(f,Color3.fromRGB(55,65,80),1,0.55)
	return f
end

local function makeSlider(parent,name,desc,initial,callback)
	local row=card(parent,54)

	local n=label(row,name,13,Enum.Font.GothamBlack,Color3.fromRGB(238,242,250))
	n.Size=UDim2.new(1,-100,0,21)
	n.Position=UDim2.new(0,12,0,6)

	local d=label(row,desc,9,Enum.Font.GothamBold,Color3.fromRGB(135,145,165))
	d.Size=UDim2.new(1,-100,0,18)
	d.Position=UDim2.new(0,12,0,29)

	local track=Instance.new("TextButton")
	track.Parent=row
	track.Size=UDim2.new(0,74,0,32)
	track.Position=UDim2.new(1,-86,0,11)
	track.Text=""
	track.AutoButtonColor=false
	track.BorderSizePixel=0
	corner(track,16)

	local knob=Instance.new("Frame")
	knob.Parent=track
	knob.Size=UDim2.new(0,26,0,26)
	knob.Position=UDim2.new(0,3,0,3)
	knob.BackgroundColor3=Color3.fromRGB(242,245,250)
	knob.BorderSizePixel=0
	corner(knob,13)

	local state=initial and true or false
	local api={}

	local function paint()
		if state then
			track.BackgroundColor3=Color3.fromRGB(40,150,85)
			knob.Position=UDim2.new(1,-29,0,3)
		else
			track.BackgroundColor3=Color3.fromRGB(92,48,58)
			knob.Position=UDim2.new(0,3,0,3)
		end
	end

	function api.Set(v,silent)
		state=v and true or false
		paint()

		if callback and not silent then
			callback(state,api)
		end
	end

	function api.Get()
		return state
	end

	addConn(track.Activated:Connect(function()
		api.Set(not state,false)
	end))

	paint()
	return api,row
end

-- BUG PAGE

local selectCard=card(bugPage,72)
local selectTitle=label(selectCard,"АВТО-КАМЕНЬ ПО РЕБАМ",9,Enum.Font.GothamBlack,Color3.fromRGB(120,190,255))
selectTitle.Size=UDim2.new(1,-20,0,18)
selectTitle.Position=UDim2.new(0,12,0,8)

local selectName=label(selectCard,"-",17,Enum.Font.GothamBlack,Color3.fromRGB(255,235,175))
selectName.Size=UDim2.new(1,-20,0,28)
selectName.Position=UDim2.new(0,12,0,30)

local rockCard=card(bugPage,165)
local rockTitle=label(rockCard,"КАМНИ",12,Enum.Font.GothamBlack,Color3.fromRGB(230,235,245))
rockTitle.Size=UDim2.new(1,-20,0,20)
rockTitle.Position=UDim2.new(0,12,0,8)

local rockList=Instance.new("ScrollingFrame")
rockList.Parent=rockCard
rockList.Size=UDim2.new(1,-16,0,126)
rockList.Position=UDim2.new(0,8,0,32)
rockList.BackgroundTransparency=1
rockList.BorderSizePixel=0
rockList.ScrollBarThickness=2
rockList.CanvasSize=UDim2.new(0,0,0,0)

local rockLayout=Instance.new("UIListLayout")
rockLayout.Parent=rockList
rockLayout.SortOrder=Enum.SortOrder.LayoutOrder
rockLayout.Padding=UDim.new(0,5)

local rockButtons={}

local function refreshRockList()
	for _,b in ipairs(rockButtons) do
		if b and b.Parent then b:Destroy() end
	end
	rockButtons={}

	for i,row in ipairs(ROCKS) do
		local info=rockCache[row.req]
		local active=Runtime.selectedRock and Runtime.selectedRock.id==row.id

		local b=button(rockList,(active and "● " or "○ ")..row.label.."  |  "..(info and "found" or "missing"),
			active and Color3.fromRGB(40,85,125) or Color3.fromRGB(22,27,35))
		b.Size=UDim2.new(1,-3,0,32)
		b.LayoutOrder=i
		b.TextXAlignment=Enum.TextXAlignment.Left

		local p=Instance.new("UIPadding")
		p.Parent=b
		p.PaddingLeft=UDim.new(0,10)

		addConn(b.Activated:Connect(function()
			Runtime.selectedRock=row
			selectTitle.Text="ВЫБРАНО ВРУЧНУЮ"
			selectName.Text=row.label.." | req "..tostring(row.req)
			refreshRockList()
			setStatus("Камень: "..row.label)
		end))

		table.insert(rockButtons,b)
	end

	rockList.CanvasSize=UDim2.new(0,0,0,#ROCKS*37+4)
end

local lockRockSlider
local bugSlider

lockRockSlider=makeSlider(bugPage,"TP LOCK","держать позицию внутри камня",false,function(on,api)
	if on then
		local ok,err=teleportInsideSelected()

		if not ok then
			setStatus("LOCK: "..tostring(err))
			api.Set(false,true)
			return
		end

		Runtime.lockRock=true
		Runtime.nextLockTick=0
		setStatus("TP LOCK: ON")
	else
		Runtime.lockRock=false
		Runtime.lockCF=nil
		if Runtime.mode~="bug" then
			setCharacterGhost(false)
		end
		setStatus("TP LOCK: OFF")
	end
end)

bugSlider=makeSlider(bugPage,"STABLE PUNCH","10 действий/с, remote ограничен по ping",false,function(on,api)
	if on then
		if not startBug() then
			api.Set(false,true)
		end
	else
		stopMode("BUG OFF / HARD STOP")
	end
end)

Runtime.leverRefs.lockRock=lockRockSlider
Runtime.leverRefs.bug=bugSlider

local remoteSlider=makeSlider(bugPage,"DIRECT REMOTE","bounded: максимум 7/s при хорошем ping",true,function(on)
	Runtime.directRemoteEnabled=on
	setStatus("DIRECT REMOTE: "..(on and "ON" or "OFF"))
end)

-- TRAIN PAGE

local lockPosSlider=makeSlider(trainPage,"LOCK POSITION","удерживать текущую позицию во время кача",false,function(on,api)
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
		setStatus("LOCK POSITION: ON")
	else
		Runtime.lockPosition=false
		Runtime.positionCF=nil
		setStatus("LOCK POSITION: OFF")
	end
end)

Runtime.leverRefs.lockPosition=lockPosSlider

local visualSlider=makeSlider(trainPage,"VISUAL LOW","только эффекты/тени, не трогает GUI и карту",false,function(on)
	setVisualLow(on)
end)

Runtime.leverRefs.visualLow=visualSlider

local afkSlider=makeSlider(trainPage,"ANTI AFK","по умолчанию выключен",false,function(on)
	Runtime.antiAfkEnabled=on
	setStatus("ANTI AFK: "..(on and "ON" or "OFF"))
end)

local trainHeader=card(trainPage,42)
local th=label(trainHeader,"ОТДЕЛЬНЫЕ ВИДЫ КАЧА",12,Enum.Font.GothamBlack,Color3.fromRGB(225,235,245))
th.Size=UDim2.new(1,-20,1,0)
th.Position=UDim2.new(0,10,0,0)
th.TextXAlignment=Enum.TextXAlignment.Center

Runtime.leverRefs.train={}

local function turnOffOtherTrain(id)
	for otherId,lever in pairs(Runtime.leverRefs.train) do
		if otherId~=id and lever.Get() then
			lever.Set(false,true)
		end
	end
end

for _,t in ipairs(TRAIN_TYPES) do
	local slider
	slider=makeSlider(trainPage,t.label,t.desc,false,function(on,api)
		if on then
			turnOffOtherTrain(t.id)
			startTrain(t)
		else
			if Runtime.mode=="train" and Runtime.selectedTrain and Runtime.selectedTrain.id==t.id then
				stopMode(t.label..": OFF")
			end
		end
	end)

	Runtime.leverRefs.train[t.id]=slider
end

local function showTab(name)
	local bug=name=="bug"
	bugPage.Visible=bug
	trainPage.Visible=not bug
	bugTab.BackgroundColor3=bug and Color3.fromRGB(38,105,155) or Color3.fromRGB(35,40,50)
	trainTab.BackgroundColor3=(not bug) and Color3.fromRGB(35,130,80) or Color3.fromRGB(35,40,50)
end

addConn(bugTab.Activated:Connect(function() showTab("bug") end))
addConn(trainTab.Activated:Connect(function() showTab("train") end))

addConn(rescanBtn.Activated:Connect(function()
	setStatus("SCAN...")
	scanRocks()

	local auto,why=chooseSafeRockByRebirths()
	Runtime.selectedRock=auto
	selectTitle.Text="АВТО-КАМЕНЬ ПО РЕБАМ"
	selectName.Text=auto.label.." | "..tostring(why)
	refreshRockList()
	setStatus("SCAN DONE | "..tostring(why))
end))

addConn(panicBtn.Activated:Connect(function()
	panicStop()
end))

local dragging=false
local dragStart=nil
local startPos=nil

addConn(rail.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=true
		dragStart=input.Position
		startPos=main.Position
	end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=false
	end
end))

addConn(UserInputService.InputChanged:Connect(function(input)
	if dragging and dragStart and startPos and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
		local delta=input.Position-dragStart
		main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
		restoreBtn.Position=main.Position
	end
end))

addConn(minBtn.Activated:Connect(function()
	main.Visible=false
	restoreBtn.Visible=true
end))

addConn(restoreBtn.Activated:Connect(function()
	main.Visible=true
	restoreBtn.Visible=false
end))

function Runtime:Stop(reason)
	if not self.alive then return end

	self.alive=false
	panicStop()
	disconnectAll()

	if gui and gui.Parent then
		gui:Destroy()
	end

	ENV.RockBugRuntime=nil
end

addConn(closeBtn.Activated:Connect(function()
	Runtime:Stop("closed")
end))

addConn(lp.CharacterAdded:Connect(function()
	Runtime.activeTool=nil
	Runtime.lockCF=nil
	Runtime.positionCF=nil
	Runtime.lockRock=false
	Runtime.lockPosition=false
	Runtime.characterCollisionSaved={}
	Runtime.characterGhost=false
	stopMode("RESPAWN: режимы остановлены")

	if Runtime.leverRefs.lockPosition then Runtime.leverRefs.lockPosition.Set(false,true) end
end))

-- Initial scan / safe auto-select.
scanRocks()
local autoRock,autoWhy=chooseSafeRockByRebirths()
Runtime.selectedRock=autoRock
selectName.Text=autoRock.label.." | "..tostring(autoWhy)
refreshRockList()
showTab("bug")
updateCanvas()
setStatus("v19 ready | "..tostring(autoWhy))

task.spawn(scheduler)
