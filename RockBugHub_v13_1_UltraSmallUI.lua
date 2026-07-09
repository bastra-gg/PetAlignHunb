-- ML_RestoreGameButtons_v1
-- Без окна. Возвращает внутриигровые кнопки/тач-контролы/CoreGui после сломанного RockBugHub.
-- Не делает rejoin/kick. Работает 120 секунд и постоянно перебивает отключение кнопок.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local StarterGui=game:GetService("StarterGui")
local Lighting=game:GetService("Lighting")
local VirtualUser=game:GetService("VirtualUser")

local lp=Players.LocalPlayer

-- анти AFK на время передачи
pcall(function()
	lp.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
end)

local function safe(fn)
	pcall(fn)
end

local function getRoots()
	local roots={}
	safe(function() table.insert(roots, lp:WaitForChild("PlayerGui")) end)
	safe(function()
		if type(gethui)=="function" then table.insert(roots,gethui()) end
	end)
	safe(function() table.insert(roots, game:GetService("CoreGui")) end)
	return roots
end

local function enableCore()
	safe(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)
	end)

	safe(function()
		RunService:Set3dRenderingEnabled(true)
	end)

	safe(function()
		Lighting.Brightness=2
		Lighting.FogEnd=100000
		Lighting.Ambient=Color3.fromRGB(120,120,120)
		Lighting.OutdoorAmbient=Color3.fromRGB(120,120,120)
		pcall(function()Lighting.ExposureCompensation=0 end)
	end)
end

local function enablePlayerControls()
	safe(function()
		local ps=lp:FindFirstChild("PlayerScripts")
		if not ps then return end
		local pm=ps:FindFirstChild("PlayerModule")
		if not pm then return end
		local mod=require(pm)
		local controls=mod:GetControls()
		if controls then controls:Enable() end
	end)

	local c=lp.Character
	if c then
		local h=c:FindFirstChildWhichIsA("Humanoid")
		local r=c:FindFirstChild("HumanoidRootPart")

		if h then
			safe(function()
				h.PlatformStand=false
				h.Sit=false
				h.AutoRotate=true
				if h.WalkSpeed<12 then h.WalkSpeed=16 end
				if h.UseJumpPower then
					if h.JumpPower<35 then h.JumpPower=50 end
				else
					if h.JumpHeight<5 then h.JumpHeight=7.2 end
				end
				h:ChangeState(Enum.HumanoidStateType.Running)
			end)
		end

		if r then
			safe(function()
				r.Anchored=false
				r.AssemblyLinearVelocity=Vector3.new()
				r.AssemblyAngularVelocity=Vector3.new()
			end)
		end
	end
end

local function isBadExploitGui(obj)
	local n=tostring(obj.Name)
	if n:find("RockBugHub",1,true) then return true end
	if n=="BLACK_OPT_BACKGROUND" then return true end
	if n:find("RebirthAnimKiller",1,true) then return true end
	if n:find("RebirthCDTryRemove",1,true) then return true end
	if n:find("EmergencyReset",1,true) then return true end
	if n:find("HardPanicReset",1,true) then return true end
	return false
end

local function removeBlockingExploitGui()
	for _,root in ipairs(getRoots())do
		if root then
			for _,obj in ipairs(root:GetChildren())do
				if isBadExploitGui(obj) then
					safe(function() obj:Destroy() end)
				end
			end
			for _,obj in ipairs(root:GetDescendants())do
				if isBadExploitGui(obj) then
					safe(function() obj:Destroy() end)
				end
			end
		end
	end
end

local function enableGameButtons()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	for _,sg in ipairs(pg:GetChildren())do
		if sg:IsA("ScreenGui") and not isBadExploitGui(sg) then
			safe(function()
				sg.Enabled=true
				sg.ResetOnSpawn=false
			end)
		end
	end

	-- Вернуть Roblox mobile controls / jump / joystick.
	local touch=pg:FindFirstChild("TouchGui")
	if touch then
		safe(function() touch.Enabled=true end)
		for _,d in ipairs(touch:GetDescendants())do
			if d:IsA("GuiObject")then
				safe(function()
					d.Visible=true
					d.Active=true
				end)
			end
			if d:IsA("GuiButton")then
				safe(function()
					d.Selectable=true
					d.AutoButtonColor=true
					d.Modal=false
				end)
			end
		end
	end

	-- Не открываем скрытые меню игры, но чиним уже видимые кнопки.
	for _,d in ipairs(pg:GetDescendants())do
		if d:IsA("GuiButton") and not isBadExploitGui(d) then
			safe(function()
				d.Active=true
				d.Selectable=true
				d.AutoButtonColor=true
				d.Modal=false
			end)
		end
	end
end

local function restoreVisualSmall()
	for _,obj in ipairs(workspace:GetDescendants())do
		if obj:IsA("BasePart")then
			safe(function()
				obj.LocalTransparencyModifier=0
			end)
		elseif obj:IsA("Decal") or obj:IsA("Texture")then
			safe(function()
				if obj.Transparency>=0.95 then obj.Transparency=0 end
			end)
		end
	end
end

local function onePass()
	enableCore()
	enablePlayerControls()
	removeBlockingExploitGui()
	enableGameButtons()
end

-- сразу
onePass()
task.spawn(restoreVisualSmall)

-- держим 120 сек, чтобы старый лок/отключение кнопок перебивались
local untilTime=os.clock()+120
local conn
conn=RunService.Heartbeat:Connect(function()
	if os.clock()>untilTime then
		if conn then conn:Disconnect() end
		return
	end
	onePass()
end)
