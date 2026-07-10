-- RockBugHub v20 Validated Compact
-- Clean rebuild: single scheduler, hard stop, adaptive network throttle.
-- No getgc patching, no full workspace scans inside fast loops, no unknown train remote spam.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Stats=game:GetService("Stats")
local VirtualUser=game:GetService("VirtualUser")
local UserInputService=game:GetService("UserInputService")

local lp=Players.LocalPlayer
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
	nextPosTick=0,
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
