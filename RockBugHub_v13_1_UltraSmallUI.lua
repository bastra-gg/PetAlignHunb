-- ML_TradeRescue_v1
-- Только для трейда: возвращает кликабельность игровых кнопок, убирает мешающие оверлеи RockBug и попапы.
-- Без black screen, без rejoin/kick, без авто-передачи петов.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local StarterGui=game:GetService("StarterGui")
local Lighting=game:GetService("Lighting")
local VirtualUser=game:GetService("VirtualUser")
local UserInputService=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")

local lp=Players.LocalPlayer
local VERSION="ML_TradeRescue_v1"

local enabled=false
local loopConn=nil
local hidden={}
local stats={fix=0,pop=0,trade=0,old=0,last="ready"}

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
		if type(gethui)=="function"then return gethui()end
	end)
	if ok and h then return h end
	local ok2,cg=safe(function()return CoreGui end)
	if ok2 and cg then return cg end
	return lp:WaitForChild("PlayerGui")
end

local uiParent=getUiParent()

pcall(function()
	local old=uiParent:FindFirstChild("ML_TradeRescueGui")
	if old then old:Destroy()end
end)

local function low(s)
	return tostring(s or ""):lower()
end

local function containsAny(s,arr)
	s=low(s)
	for _,w in ipairs(arr)do
		if s:find(low(w),1,true)then return true end
	end
	return false
end

local TRADE_WORDS={
	"trade","обмен","трейд",
	"accept","принять","принято","подтверд","confirm",
	"ready","готов","готово",
	"decline","отклон","cancel","отмена",
	"pet","pets","пет","питом","питомец","питомцы",
	"offer","send","give","отправ","предлож"
}

local POPUP_WORDS={
	"limited","лимит","запас",
	"reward","награ","бесплатная",
	"invite friends","пригласить 10 друзей",
	"tasks","задач","магазин","shop",
	"premium","премиум","удача","пакет",
	"claim","забрать"
}

local function isOldBad(obj)
	local n=tostring(obj.Name)
	if n=="BLACK_OPT_BACKGROUND"then return true end
	if n:find("RockBugHub",1,true)then return true end
	if n:find("EmergencyReset",1,true)then return true end
	if n:find("HardPanicReset",1,true)then return true end
	if n:find("ForceCloseOld",1,true)then return true end
	if n:find("RestoreGameButtons",1,true)then return true end
	return false
end

local function destroyOldBad()
	local roots={lp:FindFirstChild("PlayerGui"),uiParent,CoreGui}
	local seen={}
	for _,root in ipairs(roots)do
		if root and not seen[root]then
			seen[root]=true
			for _,obj in ipairs(root:GetChildren())do
				if isOldBad(obj)then
					safe(function()obj:Destroy()end)
					stats.old+=1
				end
			end
			for _,obj in ipairs(root:GetDescendants())do
				if isOldBad(obj)then
					safe(function()obj:Destroy()end)
					stats.old+=1
				end
			end
		end
	end
end

local function restoreBasic()
	safe(function()RunService:Set3dRenderingEnabled(true)end)
	safe(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)end)

	safe(function()
		Lighting.Brightness=2
		Lighting.FogEnd=100000
		Lighting.Ambient=Color3.fromRGB(120,120,120)
		Lighting.OutdoorAmbient=Color3.fromRGB(120,120,120)
		pcall(function()Lighting.ExposureCompensation=0 end)
	end)

	safe(function()
		local pm=lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("PlayerModule")
		if pm then
			local mod=require(pm)
			local controls=mod:GetControls()
			if controls then controls:Enable()end
		end
	end)

	local c=lp.Character
	if c then
		local hum=c:FindFirstChildWhichIsA("Humanoid")
		local root=c:FindFirstChild("HumanoidRootPart")

		if hum then
			safe(function()
				hum.PlatformStand=false
				hum.Sit=false
				hum.AutoRotate=true
				if hum.WalkSpeed<12 then hum.WalkSpeed=16 end
				if hum.UseJumpPower then
					if hum.JumpPower<35 then hum.JumpPower=50 end
				else
					if hum.JumpHeight<5 then hum.JumpHeight=7.2 end
				end
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end)
		end

		if root then
			safe(function()
				root.Anchored=false
				root.AssemblyLinearVelocity=Vector3.new()
				root.AssemblyAngularVelocity=Vector3.new()
			end)
		end
	end

	stats.fix+=1
end

local function textOf(obj)
	local out=tostring(obj.Name)
	safe(function()
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")then
			out=out.." "..tostring(obj.Text)
		end
	end)
	return out
end

local function guiTextPack(obj)
	local s=tostring(obj.Name)
	for _,d in ipairs(obj:GetDescendants())do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")then
			s=s.." "..tostring(d.Name).." "..tostring(d.Text)
		end
	end
	return s
end

local function enableGameButtons()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	for _,sg in ipairs(pg:GetChildren())do
		if sg:IsA("ScreenGui") and not isOldBad(sg)then
			safe(function()
				sg.Enabled=true
			end)
		end
	end

	local touch=pg:FindFirstChild("TouchGui")
	if touch then
		safe(function()touch.Enabled=true end)
	end

	for _,d in ipairs(pg:GetDescendants())do
		if d:IsA("GuiObject") and not isOldBad(d)then
			safe(function()
				d.Active=true
			end)
		end
		if d:IsA("GuiButton") and not isOldBad(d)then
			safe(function()
				d.Active=true
				d.Selectable=true
				d.AutoButtonColor=true
				d.Modal=false
			end)
		end
	end
end

local function focusTradeGui()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	for _,sg in ipairs(pg:GetChildren())do
		if sg:IsA("ScreenGui") and not isOldBad(sg)then
			local pack=guiTextPack(sg)
			if containsAny(pack,TRADE_WORDS)then
				safe(function()
					sg.Enabled=true
					sg.DisplayOrder=999500
					sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
				end)

				for _,d in ipairs(sg:GetDescendants())do
					if d:IsA("GuiObject")then
						local txt=textOf(d)
						if containsAny(txt,TRADE_WORDS)then
							safe(function()
								d.Visible=true
								d.Active=true
								d.ZIndex=math.max(d.ZIndex,900)
								stats.trade+=1
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
			end
		end
	end
end

local function hideOne(obj)
	if hidden[obj]then return end
	if not obj:IsA("GuiObject")then return end
	if obj:IsDescendantOf(gui)then return end
	if isOldBad(obj)then return end

	local rec={Visible=obj.Visible,BackgroundTransparency=obj.BackgroundTransparency}
	hidden[obj]=rec

	safe(function()
		obj.Visible=false
		obj.BackgroundTransparency=1
	end)
	stats.pop+=1
end

local function clearPopups()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	for _,sg in ipairs(pg:GetChildren())do
		if sg:IsA("ScreenGui") and not isOldBad(sg)then
			local pack=guiTextPack(sg)
			local isTrade=containsAny(pack,TRADE_WORDS)
			local isPopup=containsAny(pack,POPUP_WORDS)

			if isPopup and not isTrade then
				-- Не Destroy, только скрыть. Restore вернёт.
				for _,d in ipairs(sg:GetDescendants())do
					if d:IsA("GuiObject")then hideOne(d)end
				end
			else
				for _,d in ipairs(sg:GetDescendants())do
					if d:IsA("GuiObject")then
						local t=textOf(d)
						if containsAny(t,POPUP_WORDS) and not containsAny(t,TRADE_WORDS)then
							hideOne(d)
						end
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
			if rec.BackgroundTransparency~=nil then safe(function()obj.BackgroundTransparency=rec.BackgroundTransparency end)end
		end
	end
	hidden={}
end

local function clickAccept()
	local pg=lp:FindFirstChild("PlayerGui")
	if not pg then return end

	local ACCEPT_WORDS={"accept","принять","confirm","подтверд","ready","готов"}
	for _,d in ipairs(pg:GetDescendants())do
		if d:IsA("TextButton") and d.Visible then
			local t=textOf(d)
			if containsAny(t,ACCEPT_WORDS)then
				safe(function()d:Activate()end)
				safe(function()if firesignal then firesignal(d.Activated)end end)
				safe(function()if firesignal then firesignal(d.MouseButton1Click)end end)
				stats.trade+=1
			end
		end
	end
end

local function onePass()
	destroyOldBad()
	restoreBasic()
	enableGameButtons()
	focusTradeGui()
	stats.last=os.date("%H:%M:%S")
end

-- UI
gui=Instance.new("ScreenGui")
gui.Name="ML_TradeRescueGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=10000000
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=uiParent

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,304,0,176)
main.Position=UDim2.new(0,14,0,116)
main.BackgroundColor3=Color3.fromRGB(14,15,22)
main.BackgroundTransparency=0.04
main.BorderSizePixel=0
main.Active=true
main.ZIndex=50
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)
local st=Instance.new("UIStroke",main)
st.Color=Color3.fromRGB(80,170,255)
st.Thickness=1.4
st.Transparency=0.08

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-48,0,24)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="TRADE RESCUE"
title.TextColor3=Color3.fromRGB(235,245,255)
title.Font=Enum.Font.GothamBlack
title.TextSize=14
title.TextXAlignment=Enum.TextXAlignment.Left
title.ZIndex=51

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
close.ZIndex=52
Instance.new("UICorner",close).CornerRadius=UDim.new(0,10)

local status=Instance.new("TextLabel")
status.Parent=main
status.Size=UDim2.new(1,-24,0,38)
status.Position=UDim2.new(0,12,0,36)
status.BackgroundTransparency=1
status.TextColor3=Color3.fromRGB(215,225,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left
status.ZIndex=51

local function mkBtn(text,x,y,w,h)
	local b=Instance.new("TextButton")
	b.Parent=main
	b.Size=UDim2.new(0,w,0,h)
	b.Position=UDim2.new(0,x,0,y)
	b.BackgroundColor3=Color3.fromRGB(44,50,72)
	b.Text=text
	b.TextColor3=Color3.fromRGB(250,250,255)
	b.Font=Enum.Font.GothamBlack
	b.TextSize=11
	b.BorderSizePixel=0
	b.ZIndex=52
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

local toggleBtn=mkBtn("TRADE FIX: OFF",12,80,132,34)
local popupBtn=mkBtn("CLEAR POPUPS",160,80,132,34)
local acceptBtn=mkBtn("CLICK ACCEPT",12,122,132,34)
local restoreBtn=mkBtn("RESTORE UI",160,122,132,34)

local function upd()
	toggleBtn.Text=enabled and "TRADE FIX: ON" or "TRADE FIX: OFF"
	toggleBtn.BackgroundColor3=enabled and Color3.fromRGB(40,130,70) or Color3.fromRGB(44,50,72)
	status.Text=("v1 | %s | old:%s fix:%s trade:%s hidden:%s"):format(
		stats.last,
		tostring(stats.old),
		tostring(stats.fix),
		tostring(stats.trade),
		tostring(stats.pop)
	)
end

toggleBtn.Activated:Connect(function()
	enabled=not enabled
	if enabled then
		onePass()
		if loopConn then loopConn:Disconnect()loopConn=nil end
		loopConn=RunService.Heartbeat:Connect(function()
			if enabled then onePass()upd()end
		end)
	else
		if loopConn then loopConn:Disconnect()loopConn=nil end
	end
	upd()
end)

popupBtn.Activated:Connect(function()
	clearPopups()
	focusTradeGui()
	upd()
end)

acceptBtn.Activated:Connect(function()
	clickAccept()
	upd()
end)

restoreBtn.Activated:Connect(function()
	restoreHidden()
	onePass()
	upd()
end)

close.Activated:Connect(function()
	enabled=false
	if loopConn then loopConn:Disconnect()loopConn=nil end
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

onePass()
upd()
