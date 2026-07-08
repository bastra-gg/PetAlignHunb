-- RebirthAnim_Killer_v2_CloseOld
-- Маленькое окно: ON/OFF + X.
-- Пробует убрать/срезать ЛОКАЛЬНУЮ анимацию/катсцену ребирта.
-- Не качает силу и не делает ребирт сам.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local UserInputService=game:GetService("UserInputService")

local lp=Players.LocalPlayer
local VERSION="RebirthAnim_Killer_v2_CloseOld"
local function killPreviousCdTester()
	_G.RebirthCDCleanerStop=true
	_G.RebirthCDTryRemoveStop=true

	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	local old=pg:FindFirstChild("RebirthCDTryRemoveGui")
	if old then
		-- Если старая кнопка ON, пробуем нажать её, чтобы остановить внутренний цикл.
		local btn=nil
		for _,d in ipairs(old:GetDescendants())do
			if d:IsA("TextButton") and tostring(d.Text):find("CD REMOVE",1,true)then
				btn=d
				break
			end
		end

		if btn then
			pcall(function()
				if tostring(btn.Text):find("ON",1,true)then
					btn:Activate()
				end
			end)
			pcall(function()
				if firesignal then firesignal(btn.Activated)end
			end)
			pcall(function()
				if firesignal then firesignal(btn.MouseButton1Click)end
			end)
		end

		task.wait(0.12)
		pcall(function()old:Destroy()end)
	end
end

-- Сразу убираем прошлое надоедливое окно, если оно есть.
pcall(killPreviousCdTester)


pcall(function()
	local pg=lp:WaitForChild("PlayerGui")
	local old=pg:FindFirstChild("RebirthAnimKillerGuiV2")
	if old then old:Destroy()end
	local oldV1=pg:FindFirstChild("RebirthAnimKillerGui")
	if oldV1 then oldV1:Destroy()end
end)

local enabled=false
local loopId=0
local conns={}
local hidden={}
local disabled={}
local stats={
	tracks=0,
	guis=0,
	effects=0,
	scripts=0,
	last="готово"
}

local WORDS={
	"rebirth","reborn","re-born","re birth",
	"cutscene","cut_scene","cinematic","animation",
	"transition","fade","flash","blur","camera",
	"рebirth","ребирт","ребёрт","перерожд","возрожд"
}

local function low(s)
	return tostring(s or ""):lower()
end

local function match(s)
	s=low(s)
	for _,w in ipairs(WORDS)do
		if s:find(w,1,true)then return true end
	end
	return false
end

local function protectGui(obj)
	if not obj then return true end
	if obj:IsDescendantOf(gui or nil)then return true end
	local n=low(obj.Name)
	-- не трогаем стандартные кнопки/основные UI, только подозрительные overlay/cutscene.
	if n=="chat" or n=="bubblechat" or n=="touchgui" or n=="playerlist"then return true end
	return false
end

local function stopRebirthTracks()
	local c=lp.Character
	if not c then return end
	local hum=c:FindFirstChildWhichIsA("Humanoid")
	if not hum then return end

	local animator=hum:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _,tr in ipairs(animator:GetPlayingAnimationTracks())do
		local okName=""
		pcall(function()
			okName=tostring(tr.Name).." "..tostring(tr.Animation and tr.Animation.Name or "").." "..tostring(tr.Animation and tr.Animation.AnimationId or "")
		end)

		-- Если название явное — стопаем. Если включён aggressive, стопаем всё на короткое время после ребирта.
		if match(okName) or _G.RebirthAnimKillAllTracks then
			pcall(function()
				tr:Stop(0)
				stats.tracks+=1
			end)
		end
	end
end

local function killGuiObj(obj)
	if not obj or hidden[obj] or protectGui(obj)then return end

	local text=""
	pcall(function()
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")then
			text=obj.Text
		end
	end)

	local full=low(obj.Name).." "..low(text)
	if not match(full)then return end

	if obj:IsA("ScreenGui")then
		hidden[obj]={Enabled=obj.Enabled}
		pcall(function()obj.Enabled=false end)
		stats.guis+=1
	elseif obj:IsA("GuiObject")then
		hidden[obj]={Visible=obj.Visible,BackgroundTransparency=obj.BackgroundTransparency}
		pcall(function()
			obj.Visible=false
			obj.BackgroundTransparency=1
		end)
		stats.guis+=1
	end
end

local function killEffects()
	for _,e in ipairs(Lighting:GetChildren())do
		if e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect")then
			if not disabled[e]then
				disabled[e]={Enabled=e.Enabled}
			end
			pcall(function()e.Enabled=false end)
			stats.effects+=1
		end
	end

	pcall(function()
		Lighting.GlobalShadows=false
	end)
end

local function disableRebirthLocalScripts()
	if not _G.RebirthAnimDisableScripts then return end
	local roots={lp:FindFirstChild("PlayerGui"),lp.Character,lp:FindFirstChild("Backpack")}
	for _,root in ipairs(roots)do
		if root then
			for _,obj in ipairs(root:GetDescendants())do
				if (obj:IsA("LocalScript") or obj:IsA("ModuleScript")) and match(obj.Name) and not disabled[obj]then
					disabled[obj]={Disabled=obj:IsA("LocalScript") and obj.Disabled or nil}
					pcall(function()
						if obj:IsA("LocalScript")then obj.Disabled=true end
					end)
					stats.scripts+=1
				end
			end
		end
	end
end

local function onePass()
	stats.tracks=0
	stats.guis=0
	stats.effects=0
	stats.scripts=0

	stopRebirthTracks()
	killEffects()

	local pg=lp:FindFirstChild("PlayerGui")
	if pg then
		for _,obj in ipairs(pg:GetDescendants())do
			killGuiObj(obj)
		end
	end

	disableRebirthLocalScripts()

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
		end
	end
	disabled={}
end

-- UI
local gui=Instance.new("ScreenGui")
gui.Name="RebirthAnimKillerGuiV2"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=999999
gui.Parent=lp:WaitForChild("PlayerGui")

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,260,0,128)
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
title.Text="ANIM KILL + OLD CLOSE"
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
ver.Text=VERSION.." | X kills old CD"
ver.TextColor3=Color3.fromRGB(155,165,205)
ver.Font=Enum.Font.GothamBold
ver.TextSize=9
ver.TextXAlignment=Enum.TextXAlignment.Left

local btn=Instance.new("TextButton")
btn.Parent=main
btn.Size=UDim2.new(1,-20,0,42)
btn.Position=UDim2.new(0,10,0,54)
btn.BackgroundColor3=Color3.fromRGB(38,125,72)
btn.Text="ANIM KILL: OFF"
btn.TextColor3=Color3.fromRGB(255,255,255)
btn.Font=Enum.Font.GothamBlack
btn.TextSize=13
btn.BorderSizePixel=0
local bc=Instance.new("UICorner",btn)
bc.CornerRadius=UDim.new(0,13)

local status=Instance.new("TextLabel")
status.Parent=main
status.Size=UDim2.new(1,-20,0,24)
status.Position=UDim2.new(0,10,0,99)
status.BackgroundTransparency=1
status.Text="выключено"
status.TextColor3=Color3.fromRGB(210,218,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Center

local function updateUi()
	btn.Text=enabled and "ANIM KILL: ON" or "ANIM KILL: OFF"
	btn.BackgroundColor3=enabled and Color3.fromRGB(130,50,160) or Color3.fromRGB(38,125,72)

	if enabled then
		status.Text=("t%s gui%s fx%s | %s"):format(
			tostring(stats.tracks),
			tostring(stats.guis),
			tostring(stats.effects),
			stats.last
		)
	else
		status.Text="выключено"
	end
end

btn.Activated:Connect(function()
	enabled=not enabled
	loopId+=1
	local my=loopId

	if enabled then
		onePass()
		updateUi()

		task.spawn(function()
			while enabled and my==loopId do
				onePass()
				updateUi()
				task.wait(_G.RebirthAnimKillDelay or 0.08)
			end
		end)
	else
		restoreAll()
		updateUi()
	end
end)

close.Activated:Connect(function()
	enabled=false
	loopId+=1
	restoreAll()
	pcall(killPreviousCdTester)
	for _,cn in ipairs(conns)do
		pcall(function()cn:Disconnect()end)
	end
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

updateUi()
