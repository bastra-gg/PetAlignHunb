-- ML_TradeOnlyFix_v2
-- Только починка трейда. Без чёрного экрана, без оптимизации, без rejoin/kick.
-- Окно с кнопками: открыть ОБМЕН, вывести трейд наверх, разблокировать клики, принять/готово.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local StarterGui=game:GetService("StarterGui")
local VirtualUser=game:GetService("VirtualUser")
local UserInputService=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")

local lp=Players.LocalPlayer
local VERSION="ML_TradeOnlyFix_v2"

local enabled=false
local loopConn=nil
local hidden={}
local stats={fix=0,front=0,click=0,hide=0,old=0,last="ready"}

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

local function getUiParent()
	local ok,h=safe(function()
		if type(gethui)=="function" then return gethui() end
	end)
	if ok and h then return h end
	local ok2,cg=safe(function()return CoreGui end)
	if ok2 and cg then return cg end
	return lp:WaitForChild("PlayerGui")
end

local function low(s)
	return tostring(s or ""):lower()
end

local function hasAny(s,arr)
	s=low(s)
	for _,w in ipairs(arr)do
		if s:find(low(w),1,true)then return true end
	end
	return false
end

local TRADE_WORDS={
	"trade","обмен","трейд",
	"accept","принять","confirm","подтверд","ready","готов",
	"decline","отклон","cancel","отмена",
	"pet","pets","пет","питом","питомец","питомцы",
	"username","онлайн","online"
}

local OPEN_TRADE_WORDS={
	"trade","обмен","трейд"
}

local ACCEPT_WORDS={
	"accept","принять","confirm","подтверд","ready","готов"
}

local POPUP_WORDS={
	"лимитированный запас","бесплатная награда","выполните 3","заданий",
	"пригласить 10 друзей","играть за","получите","забрать",
	"limited supply","free reward","complete 3","claim","invite 10"
}

local function textOf(obj)
	local s=tostring(obj.Name)
	safe(function()
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			s=s.." "..tostring(obj.Text)
		end
	end)
	return s
end

local function packText(obj)
	local s=tostring(obj.Name)
	for _,d in ipairs(obj:GetDescendants())do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			s=s.." "..tostring(d.Name).." "..tostring(d.Text)
		end
	end
	return s
end

local function isOurGui(obj)
	return obj and tostring(obj.Name)=="ML_TradeOnlyFixGui"
end

local function isBadOld(obj)
	local n=tostring(obj.Name)
	if n=="BLACK_OPT_BACKGROUND" then return true end
	if n:find("RockBugHub",1,true) then return true end
	if n:find("EmergencyReset",1,true) then return true end
	if n:find("HardPanicReset",1,true) then return true end
	if n:find("ForceCloseOld",1,true) then return true end
	if n:find("RestoreGameButtons",1,true) then return true end
	if n:find("TradeRescue",1,true) then return true end
	-- FloorRescue НЕ трогаем, он держит пол.
	return false
end

local function destroyOldBlockers()
	local roots={lp:FindFirstChild("PlayerGui"),getUiParent(),CoreGui}
	local seen={}
	for _,root in ipairs(roots)do
		if root and not seen[root]then
			seen[root]=true
			for _,obj in ipairs(root:GetChildren())do
				if isBadOld(obj)then
					safe(function()obj:Destroy()end)
					stats.old+=1
				end
			end
			for _,obj in ipairs(root:GetDescendants())do
				if isBadOld(obj)then
					safe(function()obj:Destroy()end)
					stats.old+=1
				end
			end
		end
	end
end

local function basicControlFix()
	safe(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)end)

	local pg=lp:FindFirstChild("PlayerGui")
	if pg then
		local touch=pg:FindFirstChild("TouchGui")
		if touch then
			safe(function()touch.Enabled=true end)
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
	end

	safe(function()
		local ps=lp:FindFirstChild("PlayerScripts")
		local pm=ps and ps:FindFirstChild("PlayerModule")
		if pm then
			local mod=require(pm)
			local controls=mod:GetControls()
			if controls then controls:Enable()end
		end
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

	stats.fix+=1
end

local function clickButton(b)
	if not b or not b:IsA("GuiButton")then return end
	safe(function()b.Active=true end)
	safe(function()b.Selectable=true end)
	safe(function()b.AutoButtonColor=true end)
	safe(function()b.Modal=false end)
	safe(function()b:Activate()end)
	safe(function()if firesignal then firesignal(b.Activated)end end)
	safe(function()if firesignal then firesignal(b.MouseButton1Click)end end)
	stats.click+=1
end

local function openTradePanel()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	for _,d in ipairs(pg:GetDescendants())do
		if d:IsA("TextButton")then
			local t=textOf(d)
			if hasAny(t,OPEN_TRADE_WORDS)then
				clickButton(d)
			end
		end
	end
end

local function isTradeGui(sg)
	if not sg then return false end
	local txt=packText(sg)
	return hasAny(txt,TRADE_WORDS)
end

local function bringTradeFront()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	for _,sg in ipairs(pg:GetChildren())do
		if sg:IsA("ScreenGui") and not isBadOld(sg)then
			if isTradeGui(sg)then
				safe(function()
					sg.Enabled=true
					sg.DisplayOrder=999900
					sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
				end)

				for _,d in ipairs(sg:GetDescendants())do
					if d:IsA("GuiObject")then
						local txt=textOf(d)
						if hasAny(txt,TRADE_WORDS) or d:IsA("GuiButton")then
							safe(function()
								d.Visible=true
								d.Active=true
								d.ZIndex=math.max(d.ZIndex,850)
							end)
						end
					end
					if d:IsA("GuiButton")then
						safe(function()
							d.Active=true
							d.Selectable=true
							d.AutoButtonColor=true
							d.Modal=false
						end)
					end
				end

				stats.front+=1
			end
		end
	end
end

local function unblockClicks()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end
	local cam=workspace.CurrentCamera
	local vp=cam and cam.ViewportSize or Vector2.new(0,0)

	for _,d in ipairs(pg:GetDescendants())do
		if d:IsA("GuiObject") and not isBadOld(d) then
			local isTrade=hasAny(textOf(d),TRADE_WORDS) or (d:FindFirstAncestorWhichIsA("ScreenGui") and isTradeGui(d:FindFirstAncestorWhichIsA("ScreenGui")))
			if isTrade then
				safe(function()
					d.Active=true
					if d:IsA("GuiButton")then
						d.Selectable=true
						d.AutoButtonColor=true
						d.Modal=false
					end
				end)
			else
				-- если большой прозрачный/полупрозрачный блокер перекрывает экран, отключаем ему перехват кликов, но не скрываем.
				safe(function()
					if vp.X>0 and vp.Y>0 then
						local area=(d.AbsoluteSize.X*d.AbsoluteSize.Y)/(vp.X*vp.Y)
						if area>0.35 then
							d.Active=false
							if d:IsA("GuiButton")then d.Modal=false end
						end
					end
				end)
			end
		end
	end
end

local function hidePopups()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	for _,sg in ipairs(pg:GetChildren())do
		if sg:IsA("ScreenGui") and not isBadOld(sg) and not isTradeGui(sg) and not isOurGui(sg)then
			local txt=packText(sg)
			if hasAny(txt,POPUP_WORDS)then
				for _,d in ipairs(sg:GetDescendants())do
					if d:IsA("GuiObject") and not hidden[d]then
						hidden[d]={Visible=d.Visible,Active=d.Active,BackgroundTransparency=d.BackgroundTransparency}
						safe(function()
							d.Visible=false
							d.Active=false
							d.BackgroundTransparency=1
						end)
						stats.hide+=1
					end
				end
			end
		end
	end
end

local function restoreHidden()
	for obj,rec in pairs(hidden)do
		if obj and obj.Parent then
			if rec.Visible~=nil then safe(function()obj.Visible=rec.Visible end)end
			if rec.Active~=nil then safe(function()obj.Active=rec.Active end)end
			if rec.BackgroundTransparency~=nil then safe(function()obj.BackgroundTransparency=rec.BackgroundTransparency end)end
		end
	end
	hidden={}
end

local function clickAcceptReady()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	for _,d in ipairs(pg:GetDescendants())do
		if d:IsA("TextButton") and d.Visible then
			local t=textOf(d)
			if hasAny(t,ACCEPT_WORDS)then
				clickButton(d)
			end
		end
	end
end

local function onePass()
	destroyOldBlockers()
	basicControlFix()
	bringTradeFront()
	unblockClicks()
	stats.last=os.date("%H:%M:%S")
end

-- UI
local uiRoot=getUiParent()
pcall(function()
	local old=uiRoot:FindFirstChild("ML_TradeOnlyFixGui")
	if old then old:Destroy()end
end)

local gui=Instance.new("ScreenGui")
gui.Name="ML_TradeOnlyFixGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=10000000
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=uiRoot

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,306,0,210)
main.Position=UDim2.new(0,14,0,110)
main.BackgroundColor3=Color3.fromRGB(15,16,22)
main.BackgroundTransparency=0.04
main.BorderSizePixel=0
main.Active=true
main.ZIndex=1000
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)
local st=Instance.new("UIStroke",main)
st.Color=Color3.fromRGB(75,180,255)
st.Thickness=1.4
st.Transparency=0.08

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-48,0,24)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="TRADE ONLY FIX"
title.TextColor3=Color3.fromRGB(235,245,255)
title.Font=Enum.Font.GothamBlack
title.TextSize=14
title.TextXAlignment=Enum.TextXAlignment.Left
title.ZIndex=1001

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
close.ZIndex=1002
Instance.new("UICorner",close).CornerRadius=UDim.new(0,10)

local status=Instance.new("TextLabel")
status.Parent=main
status.Size=UDim2.new(1,-24,0,42)
status.Position=UDim2.new(0,12,0,36)
status.BackgroundTransparency=1
status.TextColor3=Color3.fromRGB(215,225,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left
status.ZIndex=1001

local function mk(text,x,y,w,h)
	local b=Instance.new("TextButton")
	b.Parent=main
	b.Size=UDim2.new(0,w,0,h)
	b.Position=UDim2.new(0,x,0,y)
	b.BackgroundColor3=Color3.fromRGB(45,52,74)
	b.Text=text
	b.TextColor3=Color3.fromRGB(250,250,255)
	b.Font=Enum.Font.GothamBlack
	b.TextSize=10
	b.BorderSizePixel=0
	b.ZIndex=1002
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

local toggleBtn=mk("FIX: OFF",12,84,132,32)
local openBtn=mk("OPEN ОБМЕН",160,84,132,32)
local frontBtn=mk("TRADE FRONT",12,122,132,32)
local unblockBtn=mk("UNBLOCK CLICKS",160,122,132,32)
local acceptBtn=mk("ACCEPT/READY",12,160,132,32)
local popBtn=mk("HIDE POPUPS",160,160,132,32)

local function upd()
	toggleBtn.Text=enabled and "FIX: ON" or "FIX: OFF"
	toggleBtn.BackgroundColor3=enabled and Color3.fromRGB(45,135,75) or Color3.fromRGB(45,52,74)
	status.Text=("v2 | %s | old:%s fix:%s front:%s click:%s hide:%s"):format(
		stats.last,
		tostring(stats.old),
		tostring(stats.fix),
		tostring(stats.front),
		tostring(stats.click),
		tostring(stats.hide)
	)
end

toggleBtn.Activated:Connect(function()
	enabled=not enabled
	if loopConn then loopConn:Disconnect() loopConn=nil end
	if enabled then
		onePass()
		loopConn=RunService.Heartbeat:Connect(function()
			if enabled then
				onePass()
				upd()
			end
		end)
	end
	upd()
end)

openBtn.Activated:Connect(function()
	onePass()
	openTradePanel()
	upd()
end)

frontBtn.Activated:Connect(function()
	onePass()
	bringTradeFront()
	upd()
end)

unblockBtn.Activated:Connect(function()
	unblockClicks()
	upd()
end)

acceptBtn.Activated:Connect(function()
	clickAcceptReady()
	upd()
end)

popBtn.Activated:Connect(function()
	hidePopups()
	bringTradeFront()
	unblockClicks()
	upd()
end)

close.Activated:Connect(function()
	enabled=false
	if loopConn then loopConn:Disconnect() loopConn=nil end
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

-- fix one bad drag typo if executor uses this: patch below by direct assignment is safer
main.InputChanged:Connect(function()end)

onePass()
upd()
