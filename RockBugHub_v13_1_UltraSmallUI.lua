-- RebirthAnim_Killer_v4_SwitchLite
-- Рычажок ON/OFF, без сноса прошлых скриптов.
-- Лёгкий режим: не сканит весь PlayerGui каждую 0.07 сек, поэтому не должен фризить.
-- Работает именно во время ребирт-анимации/оверлея: гасит blur/camera/gui/анимации при их появлении.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")

local lp=Players.LocalPlayer
local VERSION="RebirthAnim_Killer_v4_SwitchLite"

local pg=lp:WaitForChild("PlayerGui")
pcall(function()
	local old=pg:FindFirstChild("RebirthAnimKillerGuiV4")
	if old then old:Destroy()end
end)

local gui=nil
local enabled=false
local conns={}
local activeConns={}
local hidden={}
local savedEffects={}
local savedCamera=nil

local stats={
	gui=0,
	fx=0,
	anim=0,
	cam=0,
	last="ready"
}

local WORDS={
	"rebirth","reborn","re-born","re birth",
	"cutscene","cut_scene","cinematic","animation",
	"transition","fade","flash","blur","camera",
	"перерожд","возрожд","ребирт","ребёрт"
}

local function low(s)
	return tostring(s or ""):lower()
end

local function hasWord(s)
	s=low(s)
	for _,w in ipairs(WORDS)do
		if s:find(w,1,true)then return true end
	end
	return false
end

local function disconnectAll(list)
	for _,c in ipairs(list)do
		pcall(function()c:Disconnect()end)
	end
	table.clear(list)
end

local function isOur(obj)
	return gui and obj and obj:IsDescendantOf(gui)
end

local function protectGui(obj)
	if not obj or isOur(obj)then return true end
	local n=low(obj.Name)
	if n=="chat" or n=="bubblechat" or n=="touchgui" or n=="playerlist"then return true end
	if n=="topbarapp" or n=="robloxgui"then return true end
	return false
end

local function hideGui(obj)
	if not enabled or not obj or protectGui(obj) or hidden[obj]then return end

	local text=""
	pcall(function()
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")then
			text=obj.Text
		end
	end)

	local suspicious=hasWord(obj.Name.." "..text)

	-- Если это большой затемняющий overlay/fade, но без названия rebirth.
	if not suspicious and obj:IsA("GuiObject")then
		pcall(function()
			local cam=workspace.CurrentCamera
			local vp=cam and cam.ViewportSize or Vector2.new(0,0)
			if vp.X>0 and vp.Y>0 then
				local sz=obj.AbsoluteSize
				local area=(sz.X*sz.Y)/(vp.X*vp.Y)
				if area>0.62 and obj.BackgroundTransparency<0.65 then
					suspicious=true
				end
			end
		end)
	end

	if not suspicious then return end

	local rec={}
	if obj:IsA("ScreenGui")then
		pcall(function()
			rec.Enabled=obj.Enabled
			obj.Enabled=false
			hidden[obj]=rec
			stats.gui+=1
		end)
	elseif obj:IsA("GuiObject")then
		pcall(function()
			rec.Visible=obj.Visible
			rec.BackgroundTransparency=obj.BackgroundTransparency
			obj.Visible=false
			obj.BackgroundTransparency=1
			hidden[obj]=rec
			stats.gui+=1
		end)
	end
end

local function restoreGui()
	for obj,rec in pairs(hidden)do
		if obj and obj.Parent then
			if rec.Enabled~=nil then pcall(function()obj.Enabled=rec.Enabled end)end
			if rec.Visible~=nil then pcall(function()obj.Visible=rec.Visible end)end
			if rec.BackgroundTransparency~=nil then pcall(function()obj.BackgroundTransparency=rec.BackgroundTransparency end)end
		end
	end
	table.clear(hidden)
end

local function killEffects()
	for _,e in ipairs(Lighting:GetChildren())do
		if e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect")then
			if not savedEffects[e]then
				pcall(function()savedEffects[e]={Enabled=e.Enabled}end)
			end
			pcall(function()
				if e.Enabled then stats.fx+=1 end
				e.Enabled=false
			end)
		end
	end
end

local function restoreEffects()
	for e,rec in pairs(savedEffects)do
		if e and e.Parent and rec.Enabled~=nil then
			pcall(function()e.Enabled=rec.Enabled end)
		end
	end
	table.clear(savedEffects)
end

local function fixCamera()
	local cam=workspace.CurrentCamera
	local c=lp.Character
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if not cam or not hum then return end

	if not savedCamera then
		savedCamera={}
		pcall(function()
			savedCamera.Type=cam.CameraType
			savedCamera.Subject=cam.CameraSubject
		end)
	end

	pcall(function()
		if cam.CameraType~=Enum.CameraType.Custom or cam.CameraSubject~=hum then
			cam.CameraType=Enum.CameraType.Custom
			cam.CameraSubject=hum
			stats.cam+=1
		end
	end)
end

local function restoreCamera()
	local cam=workspace.CurrentCamera
	if cam and savedCamera then
		pcall(function()
			if savedCamera.Type then cam.CameraType=savedCamera.Type end
			if savedCamera.Subject then cam.CameraSubject=savedCamera.Subject end
		end)
	end
	savedCamera=nil
end

local function stopRebirthTracks()
	local c=lp.Character
	if not c then return end
	local hum=c:FindFirstChildWhichIsA("Humanoid")
	if not hum then return end
	local animator=hum:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _,tr in ipairs(animator:GetPlayingAnimationTracks())do
		local info=""
		pcall(function()
			info=tostring(tr.Name).." "..tostring(tr.Animation and tr.Animation.Name or "").." "..tostring(tr.Animation and tr.Animation.AnimationId or "")
		end)

		if hasWord(info)then
			pcall(function()
				tr:Stop(0)
				stats.anim+=1
			end)
		end
	end
end

local function scanExistingGuiLite()
	local count=0
	for _,obj in ipairs(pg:GetDescendants())do
		hideGui(obj)
		count+=1
		if count%160==0 then task.wait()end
	end
end

local function startKiller()
	stats.gui=0
	stats.fx=0
	stats.anim=0
	stats.cam=0
	stats.last=os.date("%H:%M:%S")

	killEffects()
	fixCamera()
	stopRebirthTracks()
	task.spawn(scanExistingGuiLite)

	table.insert(activeConns,pg.DescendantAdded:Connect(function(obj)
		task.defer(function()
			hideGui(obj)
		end)
	end))

	table.insert(activeConns,Lighting.ChildAdded:Connect(function()
		task.defer(killEffects)
	end))

	table.insert(activeConns,RunService.Heartbeat:Connect(function()
		if not enabled then return end
		killEffects()
		fixCamera()
		stopRebirthTracks()
		stats.last=os.date("%H:%M:%S")
	end))
end

local function stopKiller()
	disconnectAll(activeConns)
	restoreGui()
	restoreEffects()
	restoreCamera()
end

-- UI
gui=Instance.new("ScreenGui")
gui.Name="RebirthAnimKillerGuiV4"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=999999
gui.Parent=pg

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,274,0,128)
main.Position=UDim2.new(0,18,0,122)
main.BackgroundColor3=Color3.fromRGB(10,11,22)
main.BackgroundTransparency=0.08
main.BorderSizePixel=0
main.Active=true

local c=Instance.new("UICorner",main)
c.CornerRadius=UDim.new(0,16)

local st=Instance.new("UIStroke",main)
st.Color=Color3.fromRGB(130,95,255)
st.Thickness=1.2
st.Transparency=0.18

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-54,0,22)
title.Position=UDim2.new(0,10,0,8)
title.BackgroundTransparency=1
title.Text="REBIRTH ANIM KILL"
title.TextColor3=Color3.fromRGB(245,246,255)
title.Font=Enum.Font.GothamBlack
title.TextSize=14
title.TextXAlignment=Enum.TextXAlignment.Left

local close=Instance.new("TextButton")
close.Parent=main
close.Size=UDim2.new(0,30,0,30)
close.Position=UDim2.new(1,-38,0,8)
close.BackgroundColor3=Color3.fromRGB(92,30,45)
close.Text="×"
close.TextColor3=Color3.fromRGB(255,220,225)
close.Font=Enum.Font.GothamBlack
close.TextSize=18
close.BorderSizePixel=0
local cc=Instance.new("UICorner",close)
cc.CornerRadius=UDim.new(0,10)

local ver=Instance.new("TextLabel")
ver.Parent=main
ver.Size=UDim2.new(1,-20,0,16)
ver.Position=UDim2.new(0,10,0,31)
ver.BackgroundTransparency=1
ver.Text=VERSION
ver.TextColor3=Color3.fromRGB(155,165,205)
ver.Font=Enum.Font.GothamBold
ver.TextSize=9
ver.TextXAlignment=Enum.TextXAlignment.Left

local label=Instance.new("TextLabel")
label.Parent=main
label.Size=UDim2.new(0,122,0,28)
label.Position=UDim2.new(0,10,0,55)
label.BackgroundTransparency=1
label.Text="ANIM KILL"
label.TextColor3=Color3.fromRGB(225,230,255)
label.Font=Enum.Font.GothamBlack
label.TextSize=13
label.TextXAlignment=Enum.TextXAlignment.Left

local switch=Instance.new("TextButton")
switch.Parent=main
switch.Size=UDim2.new(0,74,0,34)
switch.Position=UDim2.new(1,-86,0,52)
switch.Text=""
switch.BackgroundColor3=Color3.fromRGB(70,72,88)
switch.BorderSizePixel=0
switch.AutoButtonColor=false
local swc=Instance.new("UICorner",switch)
swc.CornerRadius=UDim.new(1,0)

local knob=Instance.new("Frame")
knob.Parent=switch
knob.Size=UDim2.new(0,28,0,28)
knob.Position=UDim2.new(0,3,0,3)
knob.BackgroundColor3=Color3.fromRGB(235,238,255)
knob.BorderSizePixel=0
local kc=Instance.new("UICorner",knob)
kc.CornerRadius=UDim.new(1,0)

local swText=Instance.new("TextLabel")
swText.Parent=switch
swText.Size=UDim2.new(1,0,1,0)
swText.BackgroundTransparency=1
swText.Text="OFF"
swText.TextColor3=Color3.fromRGB(210,215,235)
swText.Font=Enum.Font.GothamBlack
swText.TextSize=10
swText.TextXAlignment=Enum.TextXAlignment.Right
swText.Position=UDim2.new(0,-9,0,0)

local status=Instance.new("TextLabel")
status.Parent=main
status.Size=UDim2.new(1,-20,0,32)
status.Position=UDim2.new(0,10,0,89)
status.BackgroundTransparency=1
status.Text="выключено"
status.TextColor3=Color3.fromRGB(210,218,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Center

local function updateSwitch()
	if enabled then
		switch.BackgroundColor3=Color3.fromRGB(125,55,170)
		knob:TweenPosition(UDim2.new(1,-31,0,3),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.12,true)
		swText.Text="ON"
		swText.TextXAlignment=Enum.TextXAlignment.Left
		swText.Position=UDim2.new(0,10,0,0)
		status.Text=("вкл | fx%s gui%s anim%s cam%s"):format(tostring(stats.fx),tostring(stats.gui),tostring(stats.anim),tostring(stats.cam))
	else
		switch.BackgroundColor3=Color3.fromRGB(70,72,88)
		knob:TweenPosition(UDim2.new(0,3,0,3),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.12,true)
		swText.Text="OFF"
		swText.TextXAlignment=Enum.TextXAlignment.Right
		swText.Position=UDim2.new(0,-9,0,0)
		status.Text="выключено"
	end
end

local function setEnabled(v)
	v=v and true or false
	if enabled==v then return end
	enabled=v
	if enabled then
		startKiller()
	else
		stopKiller()
	end
	updateSwitch()
end

switch.Activated:Connect(function()
	setEnabled(not enabled)
end)

close.Activated:Connect(function()
	setEnabled(false)
	disconnectAll(conns)
	disconnectAll(activeConns)
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

table.insert(conns,UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=false
	end
end))

table.insert(conns,UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then
		local d=input.Position-dragStart
		main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end))

updateSwitch()
