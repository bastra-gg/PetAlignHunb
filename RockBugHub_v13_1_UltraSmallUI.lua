-- ML_FloorRescue_v1
-- Срочно возвращает пол под ноги. Без rejoin/kick. Ничего не оптимизирует и не чернит экран.
-- Создаёт локальную платформу под персонажем, чтобы можно было стоять/кликать трейд.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local VirtualUser=game:GetService("VirtualUser")
local UserInputService=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")
local Lighting=game:GetService("Lighting")

local lp=Players.LocalPlayer
local FLOOR_NAME="ML_TEMP_FLOOR_RESCUE"

pcall(function()
	lp.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
end)

local function safe(fn)
	local ok,res=pcall(fn)
	return ok,res
end

local function uiParent()
	local ok,h=safe(function()
		if type(gethui)=="function"then return gethui()end
	end)
	if ok and h then return h end
	local ok2,cg=safe(function()return CoreGui end)
	if ok2 and cg then return cg end
	return lp:WaitForChild("PlayerGui")
end

local function char()
	return lp.Character or lp.CharacterAdded:Wait()
end

local function root()
	local c=char()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function hum()
	local c=char()
	return c and c:FindFirstChildWhichIsA("Humanoid")
end

local function basicRestore()
	safe(function()RunService:Set3dRenderingEnabled(true)end)
	safe(function()
		Lighting.Brightness=2
		Lighting.FogEnd=100000
		Lighting.Ambient=Color3.fromRGB(120,120,120)
		Lighting.OutdoorAmbient=Color3.fromRGB(120,120,120)
		pcall(function()Lighting.ExposureCompensation=0 end)
	end)

	local h=hum()
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

	local r=root()
	if r then
		safe(function()
			r.Anchored=false
			r.AssemblyLinearVelocity=Vector3.new()
			r.AssemblyAngularVelocity=Vector3.new()
		end)
	end
end

local function getFloor()
	local old=workspace:FindFirstChild(FLOOR_NAME)
	if old and old:IsA("BasePart")then return old end

	local p=Instance.new("Part")
	p.Name=FLOOR_NAME
	p.Anchored=true
	p.CanCollide=true
	p.CanTouch=false
	p.CanQuery=false
	p.Size=Vector3.new(90,2,90)
	p.Material=Enum.Material.SmoothPlastic
	p.Color=Color3.fromRGB(50,255,120)
	p.Transparency=0.18
	p.TopSurface=Enum.SurfaceType.Smooth
	p.BottomSurface=Enum.SurfaceType.Smooth
	p.Parent=workspace
	return p
end

local follow=true
local followConn=nil

local function placeFloor(pushUp)
	basicRestore()

	local r=root()
	if not r then return end

	local p=getFloor()
	local pos=r.Position
	p.CFrame=CFrame.new(pos.X,pos.Y-5,pos.Z)

	if pushUp then
		safe(function()
			r.CFrame=CFrame.new(pos.X,pos.Y+7,pos.Z)
			r.AssemblyLinearVelocity=Vector3.new()
			r.AssemblyAngularVelocity=Vector3.new()
		end)
	end
end

local function setFollow(v)
	follow=v and true or false

	if followConn then
		followConn:Disconnect()
		followConn=nil
	end

	if follow then
		followConn=RunService.Heartbeat:Connect(function()
			local r=root()
			local p=workspace:FindFirstChild(FLOOR_NAME)
			if r and p then
				local pos=r.Position
				p.CFrame=CFrame.new(pos.X,pos.Y-5,pos.Z)
			end
			basicRestore()
		end)
	end
end

-- UI
pcall(function()
	local old=uiParent():FindFirstChild("ML_FloorRescueGui")
	if old then old:Destroy()end
end)

local gui=Instance.new("ScreenGui")
gui.Name="ML_FloorRescueGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=10000000
gui.Parent=uiParent()

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,284,0,138)
main.Position=UDim2.new(0,14,0,108)
main.BackgroundColor3=Color3.fromRGB(14,16,22)
main.BackgroundTransparency=0.04
main.BorderSizePixel=0
main.Active=true
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)
local st=Instance.new("UIStroke",main)
st.Color=Color3.fromRGB(70,255,120)
st.Thickness=1.4
st.Transparency=0.1

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-48,0,24)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="FLOOR RESCUE"
title.TextColor3=Color3.fromRGB(235,255,240)
title.Font=Enum.Font.GothamBlack
title.TextSize=14
title.TextXAlignment=Enum.TextXAlignment.Left

local close=Instance.new("TextButton")
close.Parent=main
close.Size=UDim2.new(0,30,0,30)
close.Position=UDim2.new(1,-38,0,8)
close.BackgroundColor3=Color3.fromRGB(90,30,40)
close.Text="×"
close.TextColor3=Color3.fromRGB(255,230,230)
close.Font=Enum.Font.GothamBlack
close.TextSize=18
close.BorderSizePixel=0
Instance.new("UICorner",close).CornerRadius=UDim.new(0,10)

local status=Instance.new("TextLabel")
status.Parent=main
status.Size=UDim2.new(1,-24,0,26)
status.Position=UDim2.new(0,12,0,36)
status.BackgroundTransparency=1
status.Text="пол создан, follow ON"
status.TextColor3=Color3.fromRGB(215,235,220)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextXAlignment=Enum.TextXAlignment.Left

local function btn(text,x,y,w,h)
	local b=Instance.new("TextButton")
	b.Parent=main
	b.Size=UDim2.new(0,w,0,h)
	b.Position=UDim2.new(0,x,0,y)
	b.BackgroundColor3=Color3.fromRGB(44,54,64)
	b.Text=text
	b.TextColor3=Color3.fromRGB(250,250,255)
	b.Font=Enum.Font.GothamBlack
	b.TextSize=11
	b.BorderSizePixel=0
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

local floorBtn=btn("PUT FLOOR",12,70,124,34)
local followBtn=btn("FOLLOW: ON",148,70,124,34)
local upBtn=btn("PUSH UP",12,108,124,24)
local delBtn=btn("DELETE FLOOR",148,108,124,24)

local function upd()
	followBtn.Text=follow and "FOLLOW: ON" or "FOLLOW: OFF"
	status.Text=follow and "пол под тобой, можно трейдить" or "пол стоит на месте"
end

floorBtn.Activated:Connect(function()
	placeFloor(true)
	upd()
end)

followBtn.Activated:Connect(function()
	setFollow(not follow)
	upd()
end)

upBtn.Activated:Connect(function()
	placeFloor(true)
	upd()
end)

delBtn.Activated:Connect(function()
	setFollow(false)
	local p=workspace:FindFirstChild(FLOOR_NAME)
	if p then p:Destroy()end
	status.Text="пол удалён"
	upd()
end)

close.Activated:Connect(function()
	if followConn then followConn:Disconnect()followConn=nil end
	gui:Destroy()
end)

-- drag
local dragging=false
local dragStart=nil
local startPos=nil

main.InputBegan:Connect(function(input)
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
	if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then
		local d=input.Position-dragStart
		main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end)

placeFloor(true)
setFollow(true)
upd()
