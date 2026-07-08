-- RebirthAnim_Killer_v3_Slider
-- Исправлено: кнопка не крашится, есть ползунок силы, X закрывает окно.
-- Цель: срезать локальную анимацию/катсцену ребирта, не делая сам ребирт.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")

local lp=Players.LocalPlayer
local VERSION="RebirthAnim_Killer_v3_Slider"

local gui=nil
local enabled=false
local loopId=0
local conns={}
local hidden={}
local disabled={}
local savedCam={}
local intensity=3 -- 1..5

local stats={
	tracks=0,
	allTracks=0,
	guis=0,
	effects=0,
	camera=0,
	scripts=0,
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

local function matchWords(s)
	s=low(s)
	for _,w in ipairs(WORDS)do
		if s:find(w,1,true)then return true end
	end
	return false
end

local function safeDisconnect(c)
	pcall(function()
		if c then c:Disconnect()end
	end)
end

local function killOldWindows()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	-- Убираем старые окна аним киллера.
	for _,name in ipairs({
		"RebirthAnimKillerGui",
		"RebirthAnimKillerGuiV2",
		"RebirthAnimKillerGuiV3",
		"RebirthCDTryRemoveGui"
	})do
		local old=pg:FindFirstChild(name)
		if old then
			-- Если это старый CD cleaner и он ON, пробуем нажать OFF перед Destroy.
			pcall(function()
				for _,d in ipairs(old:GetDescendants())do
					if d:IsA("TextButton") and tostring(d.Text):find("ON",1,true)then
						d:Activate()
					end
				end
			end)
			task.wait(0.04)
			pcall(function()old:Destroy()end)
		end
	end
end

pcall(killOldWindows)

local function ourGuiDesc(obj)
	return gui and obj and pcall(function()return obj:IsDescendantOf(gui)end) and obj:IsDescendantOf(gui)
end

local function protectedGui(obj)
	if not obj then return true end
	if ourGuiDesc(obj)then return true end

	local n=low(obj.Name)
	if n=="chat" or n=="bubblechat" or n=="touchgui" or n=="playerlist"then return true end
	if n=="topbarapp" or n=="robloxgui"then return true end

	return false
end

local function saveHidden(obj)
	if hidden[obj]then return end
	local rec={}
	pcall(function()
		if obj:IsA("ScreenGui")then rec.Enabled=obj.Enabled end
	end)
	pcall(function()
		if obj:IsA("GuiObject")then
			rec.Visible=obj.Visible
			rec.BackgroundTransparency=obj.BackgroundTransparency
		end
	end)
	hidden[obj]=rec
end

local function hideGuiObj(obj)
	if not obj or hidden[obj] or protectedGui(obj)then return end

	local text=""
	pcall(function()
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")then
			text=obj.Text
		end
	end)

	local full=low(obj.Name).." "..low(text)
	local suspicious=matchWords(full)

	-- Сила 4-5: скрываем ещё и большие overlay-фреймы, если они перекрывают экран.
	if not suspicious and intensity>=4 and obj:IsA("GuiObject")then
		pcall(function()
			local cam=workspace.CurrentCamera
			local vp=cam and cam.ViewportSize or Vector2.new(0,0)
			if vp.X>0 and vp.Y>0 then
				local sz=obj.AbsoluteSize
				local area=(sz.X*sz.Y)/(vp.X*vp.Y)
				if area>0.55 and obj.BackgroundTransparency<0.75 then
					suspicious=true
				end
			end
		end)
	end

	if not suspicious then return end

	saveHidden(obj)

	if obj:IsA("ScreenGui")then
		pcall(function()obj.Enabled=false end)
		stats.guis+=1
	elseif obj:IsA("GuiObject")then
		pcall(function()
			obj.Visible=false
			obj.BackgroundTransparency=1
		end)
		stats.guis+=1
	end
end

local function killGuiOverlays()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	for _,obj in ipairs(pg:GetDescendants())do
		hideGuiObj(obj)
	end
end

local function saveDisabled(obj)
	if disabled[obj]then return end
	local rec={}
	pcall(function()
		if obj:IsA("PostEffect") or obj:IsA("Sound")then rec.Enabled=obj.Enabled end
	end)
	pcall(function()
		if obj:IsA("LocalScript")then rec.Disabled=obj.Disabled end
	end)
	pcall(function()
		if obj:IsA("Sound")then rec.Volume=obj.Volume end
	end)
	disabled[obj]=rec
end

local function killEffects()
	for _,e in ipairs(Lighting:GetChildren())do
		if e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect")then
			saveDisabled(e)
			pcall(function()e.Enabled=false end)
			stats.effects+=1
		end
	end

	-- Сила 3+: гасим подозрительные звуки ребирта.
	if intensity>=3 then
		local roots={workspace,lp:FindFirstChild("PlayerGui"),lp.Character}
		for _,root in ipairs(roots)do
			if root then
				for _,obj in ipairs(root:GetDescendants())do
					if obj:IsA("Sound") and matchWords(obj.Name)then
						saveDisabled(obj)
						pcall(function()
							obj.Volume=0
							obj:Stop()
						end)
						stats.effects+=1
					end
				end
			end
		end
	end
end

local function killCameraCutscene()
	if intensity<2 then return end

	local cam=workspace.CurrentCamera
	local c=lp.Character
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if not cam or not hum then return end

	if not savedCam.type then
		pcall(function()
			savedCam.type=cam.CameraType
			savedCam.subject=cam.CameraSubject
		end)
	end

	pcall(function()
		cam.CameraType=Enum.CameraType.Custom
		cam.CameraSubject=hum
		stats.camera+=1
	end)
end

local function stopTracks()
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

		local shouldStop=matchWords(info)

		-- Сила 5: агрессивно стопаем почти всё на момент ребирт-катсцены.
		if intensity>=5 then
			shouldStop=true
		elseif intensity>=4 and not info:lower():find("walk",1,true) and not info:lower():find("run",1,true)then
			shouldStop=shouldStop or matchWords(info)
		end

		if shouldStop then
			pcall(function()
				tr:Stop(0)
				stats.tracks+=1
			end)
		end
	end
end

local function disableScripts()
	if intensity<5 then return end

	local roots={lp:FindFirstChild("PlayerGui"),lp.Character}
	for _,root in ipairs(roots)do
		if root then
			for _,obj in ipairs(root:GetDescendants())do
				if obj:IsA("LocalScript") and matchWords(obj.Name) and not ourGuiDesc(obj)then
					saveDisabled(obj)
					pcall(function()obj.Disabled=true end)
					stats.scripts+=1
				end
			end
		end
	end
end

local function onePass()
	stats.tracks=0
	stats.allTracks=0
	stats.guis=0
	stats.effects=0
	stats.camera=0
	stats.scripts=0

	killEffects()
	killCameraCutscene()
	killGuiOverlays()
	stopTracks()
	disableScripts()

	stats.last=os.date("%H:%M:%S")
end

local function restoreAll()
	for obj,rec in pairs(hidden)do
		if obj and obj.Parent then
			if rec.Enabled~=nil then pcall(function()obj.Enabled=rec.Enabled end)end
			if rec.Visible~=nil then pcall(function()obj.Visible=rec.Visible end)end
			if rec.BackgroundTransparency~=nil then pcall(function()obj.BackgroundTransparency=rec.BackgroundTransparency end)end
		end
	end
	hidden={}

	for obj,rec in pairs(disabled)do
		if obj and obj.Parent then
			if rec.Enabled~=nil then pcall(function()obj.Enabled=rec.Enabled end)end
			if rec.Disabled~=nil then pcall(function()obj.Disabled=rec.Disabled end)end
			if rec.Volume~=nil then pcall(function()obj.Volume=rec.Volume end)end
		end
	end
	disabled={}

	local cam=workspace.CurrentCamera
	if cam and savedCam.type then
		pcall(function()
			cam.CameraType=savedCam.type
			cam.CameraSubject=savedCam.subject
		end)
	end
	savedCam={}
end

-- UI
gui=Instance.new("ScreenGui")
gui.Name="RebirthAnimKillerGuiV3"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=999999
gui.Parent=lp:WaitForChild("PlayerGui")

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,286,0,176)
main.Position=UDim2.new(0,18,0,118)
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

local btn=Instance.new("TextButton")
btn.Parent=main
btn.Size=UDim2.new(1,-20,0,38)
btn.Position=UDim2.new(0,10,0,52)
btn.BackgroundColor3=Color3.fromRGB(38,125,72)
btn.Text="ANIM KILL: OFF"
btn.TextColor3=Color3.fromRGB(255,255,255)
btn.Font=Enum.Font.GothamBlack
btn.TextSize=13
btn.BorderSizePixel=0
local bc=Instance.new("UICorner",btn)
bc.CornerRadius=UDim.new(0,13)

local sliderLabel=Instance.new("TextLabel")
sliderLabel.Parent=main
sliderLabel.Size=UDim2.new(1,-20,0,18)
sliderLabel.Position=UDim2.new(0,10,0,95)
sliderLabel.BackgroundTransparency=1
sliderLabel.TextColor3=Color3.fromRGB(225,230,255)
sliderLabel.Font=Enum.Font.GothamBlack
sliderLabel.TextSize=11
sliderLabel.TextXAlignment=Enum.TextXAlignment.Left

local slider=Instance.new("Frame")
slider.Parent=main
slider.Size=UDim2.new(1,-20,0,18)
slider.Position=UDim2.new(0,10,0,116)
slider.BackgroundColor3=Color3.fromRGB(28,30,52)
slider.BorderSizePixel=0
local sc=Instance.new("UICorner",slider)
sc.CornerRadius=UDim.new(0,9)

local fill=Instance.new("Frame")
fill.Parent=slider
fill.Size=UDim2.new(0,0,1,0)
fill.BackgroundColor3=Color3.fromRGB(130,95,255)
fill.BorderSizePixel=0
local fc=Instance.new("UICorner",fill)
fc.CornerRadius=UDim.new(0,9)

local knob=Instance.new("Frame")
knob.Parent=slider
knob.Size=UDim2.new(0,22,0,22)
knob.Position=UDim2.new(0,0,0.5,-11)
knob.BackgroundColor3=Color3.fromRGB(255,245,190)
knob.BorderSizePixel=0
local kc=Instance.new("UICorner",knob)
kc.CornerRadius=UDim.new(1,0)

local status=Instance.new("TextLabel")
status.Parent=main
status.Size=UDim2.new(1,-20,0,32)
status.Position=UDim2.new(0,10,0,138)
status.BackgroundTransparency=1
status.Text="выключено"
status.TextColor3=Color3.fromRGB(210,218,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Center

local function updateSliderUi()
	local alpha=(intensity-1)/4
	fill.Size=UDim2.new(alpha,0,1,0)
	knob.Position=UDim2.new(alpha,-11,0.5,-11)
	local names={"SAFE","CAM","NORMAL","STRONG","MAX"}
	sliderLabel.Text="СИЛА: "..tostring(intensity).."/5  "..names[intensity]
end

local function updateUi()
	btn.Text=enabled and "ANIM KILL: ON" or "ANIM KILL: OFF"
	btn.BackgroundColor3=enabled and Color3.fromRGB(130,50,160) or Color3.fromRGB(38,125,72)

	if enabled then
		status.Text=("fx%s gui%s anim%s cam%s | %s"):format(
			tostring(stats.effects),
			tostring(stats.guis),
			tostring(stats.tracks),
			tostring(stats.camera),
			stats.last
		)
	else
		status.Text="выключено"
	end

	updateSliderUi()
end

local function setEnabled(v)
	enabled=v and true or false
	loopId+=1
	local my=loopId

	if enabled then
		onePass()
		updateUi()

		task.spawn(function()
			while enabled and my==loopId do
				onePass()
				updateUi()
				task.wait(_G.RebirthAnimKillDelay or 0.07)
			end
		end)
	else
		restoreAll()
		updateUi()
	end
end

local lastClick=0
local function toggle()
	if os.clock()-lastClick<0.15 then return end
	lastClick=os.clock()
	setEnabled(not enabled)
end

btn.Activated:Connect(toggle)
btn.MouseButton1Click:Connect(toggle)

close.Activated:Connect(function()
	setEnabled(false)
	for _,cn in ipairs(conns)do
		safeDisconnect(cn)
	end
	pcall(killOldWindows)
	gui:Destroy()
end)

-- slider input
local sliding=false

local function applySliderFromX(x)
	local absX=slider.AbsolutePosition.X
	local w=math.max(1,slider.AbsoluteSize.X)
	local a=math.clamp((x-absX)/w,0,1)
	intensity=math.clamp(math.floor(a*4+1.5),1,5)
	updateSliderUi()
	if enabled then
		onePass()
		updateUi()
	end
end

slider.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		sliding=true
		applySliderFromX(input.Position.X)
	end
end)

knob.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		sliding=true
		applySliderFromX(input.Position.X)
	end
end)

table.insert(conns,UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		sliding=false
	end
end))

table.insert(conns,UserInputService.InputChanged:Connect(function(input)
	if sliding and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then
		applySliderFromX(input.Position.X)
	end
end))

-- drag window
local dragging=false
local dragStart=nil
local startPos=nil

main.InputBegan:Connect(function(input)
	if sliding then return end
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
	if dragging and not sliding and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then
		local d=input.Position-dragStart
		main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end))

updateUi()
