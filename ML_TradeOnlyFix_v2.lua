-- ML_TradeDirect_v1
-- Минимальный прямой трейд-кликер по найденным путям из отчёта.
-- НЕТ скана каждый кадр, НЕТ чёрного экрана, НЕТ rejoin/kick, НЕТ авто-ремотов.
-- Только точечные кнопки gameGui/tradePanel и related trade buttons.

local Players=game:GetService("Players")
local StarterGui=game:GetService("StarterGui")
local UserInputService=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")

local lp=Players.LocalPlayer
local VERSION="ML_TradeDirect_v1"

local function safe(fn)
	local ok,res=pcall(fn)
	return ok,res
end

local function getUiParent()
	local ok,h=safe(function()
		if type(gethui)=="function" then return gethui() end
	end)
	if ok and h then return h end
	local ok2,cg=safe(function() return CoreGui end)
	if ok2 and cg then return cg end
	return lp:WaitForChild("PlayerGui")
end

local function pg()
	return lp:FindFirstChild("PlayerGui")
end

local function getPath(path)
	local cur=pg()
	if not cur then return nil end
	for part in string.gmatch(path,"[^/]+") do
		cur=cur:FindFirstChild(part)
		if not cur then return nil end
	end
	return cur
end

local function setMsg(t)
	if _G.MLTradeDirectStatus then
		_G.MLTradeDirectStatus.Text=tostring(t)
	end
end

local function click(btn)
	if not btn then
		setMsg("не найдено")
		return false
	end

	safe(function()
		if btn:IsA("GuiObject") then
			btn.Visible=true
			btn.Active=true
			btn.ZIndex=math.max(btn.ZIndex,999)
		end
	end)

	safe(function()
		if btn:IsA("GuiButton") then
			btn.Selectable=true
			btn.AutoButtonColor=true
			btn.Modal=false
		end
	end)

	local ok=false
	safe(function()
		btn:Activate()
		ok=true
	end)
	safe(function()
		if firesignal then
			firesignal(btn.Activated)
			ok=true
		end
	end)
	safe(function()
		if firesignal then
			firesignal(btn.MouseButton1Click)
			ok=true
		end
	end)

	setMsg(ok and ("clicked: "..btn.Name) or ("try clicked: "..btn.Name))
	return ok
end

local popupHidden={}

local function restorePopups()
	for obj,rec in pairs(popupHidden) do
		if obj and obj.Parent then
			if rec.Enabled~=nil then safe(function() obj.Enabled=rec.Enabled end) end
			if rec.Visible~=nil then safe(function() obj.Visible=rec.Visible end) end
			if rec.Active~=nil then safe(function() obj.Active=rec.Active end) end
		end
	end
	popupHidden={}
	setMsg("popups restored")
end

local function hidePopupGuis()
	local p=pg()
	if not p then return end

	-- Только конкретные GUI из твоего отчёта. gameGui НЕ трогаем.
	local names={
		"premiumGui",
		"cPetShopGui",
		"questsGui",
		"updatesMenuGui",
		"packsGui",
		"ultimatesGui",
		"limitedStockGui",
		"freeGiftsGui",
		"inviteFriendsGui",
		"currencyFrameGui",
		"rightSideGui",
		"specialOfferGui",
		"countdownEventsGui",
		"fortuneWheelMenuGui",
		"fortuneOtherMenusGui",
	}

	for _,name in ipairs(names) do
		local g=p:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and not popupHidden[g] then
			popupHidden[g]={Enabled=g.Enabled}
			safe(function() g.Enabled=false end)
		end
	end

	setMsg("popup guis hidden")
end

local function basicUnlock()
	safe(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)
	end)

	safe(function()
		local ps=lp:FindFirstChild("PlayerScripts")
		local pm=ps and ps:FindFirstChild("PlayerModule")
		if pm then
			local mod=require(pm)
			local controls=mod:GetControls()
			if controls then controls:Enable() end
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

	-- Только конкретные найденные кнопки.
	for _,path in ipairs({
		"gameGui/sideButtons/tradeButton",
		"gameGui/gameGuiScript/playerTradeFrame/nameLabel/tradeButton",
		"gameGui/gameGuiScript/tradeRequestMenu/tradeButton",
		"gameGui/tradePanel/declineButton",
		"gameGui/tradePanel/acceptButton",
		"gameGui/tradePanel/sideButtons/petsButton",
		"gameGui/tradePanel/sideButtons/aurasButton",
	}) do
		local obj=getPath(path)
		if obj and obj:IsA("GuiObject") then
			safe(function()
				obj.Visible=true
				obj.Active=true
				obj.ZIndex=math.max(obj.ZIndex,999)
			end)
			if obj:IsA("GuiButton") then
				safe(function()
					obj.Selectable=true
					obj.AutoButtonColor=true
					obj.Modal=false
				end)
			end
		end
	end

	setMsg("unlocked exact trade buttons")
end

local function tradeFront()
	local g=getPath("gameGui")
	if g and g:IsA("ScreenGui") then
		safe(function()
			g.Enabled=true
			g.DisplayOrder=999999
			g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
		end)
	end

	local panel=getPath("gameGui/tradePanel")
	if panel and panel:IsA("GuiObject") then
		safe(function()
			panel.Visible=true
			panel.Active=true
			panel.ZIndex=math.max(panel.ZIndex,900)
		end)
		for _,d in ipairs(panel:GetDescendants()) do
			if d:IsA("GuiObject") then
				safe(function()
					d.Active=true
					d.ZIndex=math.max(d.ZIndex,900)
				end)
			end
			if d:IsA("GuiButton") then
				safe(function()
					d.Selectable=true
					d.AutoButtonColor=true
					d.Modal=false
				end)
			end
		end
	end

	basicUnlock()
	setMsg("tradePanel front")
end

local function diag()
	local lines={}
	local function add(s) lines[#lines+1]=s end
	add("=== TRADE DIRECT DIAG ===")
	add("version: "..VERSION)

	for _,path in ipairs({
		"gameGui/sideButtons/tradeButton",
		"gameGui/gameGuiScript/playerTradeFrame/nameLabel/tradeButton",
		"gameGui/gameGuiScript/tradeRequestMenu/tradeButton",
		"gameGui/tradePanel",
		"gameGui/tradePanel/declineButton",
		"gameGui/tradePanel/acceptButton",
		"gameGui/tradePanel/sideButtons/petsButton",
		"gameGui/tradePanel/sideButtons/aurasButton",
	}) do
		local o=getPath(path)
		if o then
			local vis,act,z,cls="?","?","?",o.ClassName
			safe(function() vis=tostring(o.Visible) end)
			safe(function() act=tostring(o.Active) end)
			safe(function() z=tostring(o.ZIndex) end)
			add(path.." | "..cls.." | visible="..vis.." active="..act.." z="..z)
		else
			add(path.." | NOT FOUND")
		end
	end

	local text=table.concat(lines,"\n")
	safe(function()
		if setclipboard then setclipboard(text) end
	end)
	setMsg("diag copied / ready")
	return text
end

-- UI
local parent=getUiParent()
pcall(function()
	local old=parent:FindFirstChild("ML_TradeDirectGui")
	if old then old:Destroy() end
end)

local gui=Instance.new("ScreenGui")
gui.Name="ML_TradeDirectGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=10000000
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=parent

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,286,0,202)
main.Position=UDim2.new(0,14,0,116)
main.BackgroundColor3=Color3.fromRGB(14,15,22)
main.BackgroundTransparency=0.04
main.BorderSizePixel=0
main.Active=true
main.ZIndex=1000
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)
local st=Instance.new("UIStroke",main)
st.Color=Color3.fromRGB(90,180,255)
st.Thickness=1.3
st.Transparency=0.1

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-48,0,24)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="TRADE DIRECT"
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
status.Size=UDim2.new(1,-24,0,28)
status.Position=UDim2.new(0,12,0,36)
status.BackgroundTransparency=1
status.Text="готово"
status.TextColor3=Color3.fromRGB(215,225,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextXAlignment=Enum.TextXAlignment.Left
status.ZIndex=1001
_G.MLTradeDirectStatus=status

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

local unlockBtn=mk("UNLOCK",12,70,126,30)
local frontBtn=mk("FRONT",148,70,126,30)
local openBtn=mk("OPEN TRADE",12,106,126,30)
local requestBtn=mk("REQUEST/REPLY",148,106,126,30)
local petsBtn=mk("PETS TAB",12,142,126,30)
local acceptBtn=mk("ACCEPT",148,142,126,30)
local hideBtn=mk("HIDE POPUPS",12,176,126,22)
local restoreBtn=mk("RESTORE",148,176,126,22)

unlockBtn.Activated:Connect(basicUnlock)
frontBtn.Activated:Connect(tradeFront)
openBtn.Activated:Connect(function() click(getPath("gameGui/sideButtons/tradeButton")) end)
requestBtn.Activated:Connect(function()
	-- сначала ответ на запрос, потом кнопка у игрока
	if not click(getPath("gameGui/gameGuiScript/tradeRequestMenu/tradeButton")) then
		click(getPath("gameGui/gameGuiScript/playerTradeFrame/nameLabel/tradeButton"))
	end
end)
petsBtn.Activated:Connect(function() click(getPath("gameGui/tradePanel/sideButtons/petsButton")) end)
acceptBtn.Activated:Connect(function() click(getPath("gameGui/tradePanel/acceptButton")) end)
hideBtn.Activated:Connect(hidePopupGuis)
restoreBtn.Activated:Connect(restorePopups)

close.Activated:Connect(function()
	gui:Destroy()
end)

-- долгое нажатие/правый клик не надо, но кнопка diag есть через title двойной click
title.InputBegan:Connect(function()
	diag()
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
	if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
		local d=input.Position-dragStart
		main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end)

basicUnlock()
