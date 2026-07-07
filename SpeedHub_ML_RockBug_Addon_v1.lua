-- Muscle Legends RockBug Hub v2
-- Standalone: без Speed Hub. Камни через neededDurability + TP LOCK + BUG HIT + Anti AFK.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local VirtualUser=game:GetService("VirtualUser")
local lp=Players.LocalPlayer

-- Anti AFK
local antiAfkEnabled=true
local antiAfkConn=nil
local function startAntiAfk()
	if antiAfkConn then antiAfkConn:Disconnect() antiAfkConn=nil end
	antiAfkConn=lp.Idled:Connect(function()
		if not antiAfkEnabled then return end
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
end
startAntiAfk()

-- Анти-дубль.
pcall(function()
	local old=lp:WaitForChild("PlayerGui"):FindFirstChild("RockBugHubStandaloneV2")
	if old then old:Destroy() end
end)

local ROCKS={
	{id="AncientJungle",label="Древний лес",req=10000000,color=Color3.fromRGB(120,70,255)},
	{id="MuscleKing",label="Король мышц",req=5000000,color=Color3.fromRGB(255,190,80)},
	{id="Legends",label="Легенды",req=1000000,color=Color3.fromRGB(90,170,255)},
	{id="Inferno",label="Инферно",req=750000,color=Color3.fromRGB(255,85,85)},
	{id="Mystic",label="Мистический",req=400000,color=Color3.fromRGB(180,90,255)},
	{id="Frozen",label="Ледяной",req=150000,color=Color3.fromRGB(95,220,255)},
	{id="Golden",label="Золотой",req=5000,color=Color3.fromRGB(255,210,65)},
	{id="Large",label="Большой",req=100,color=Color3.fromRGB(170,170,190)},
	{id="Punching",label="Пробивной",req=10,color=Color3.fromRGB(255,130,90)},
	{id="Tiny",label="Маленький",req=0,color=Color3.fromRGB(110,255,155)},
}

local selected=ROCKS[1]
local rockCache={}
local lockConn=nil
local hitConn=nil
local lockCF=nil
local oldSpeed=nil
local oldAuto=nil
local hitting=false

local function root()
	local c=lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function char()
	return lp.Character or lp.CharacterAdded:Wait()
end

local function hum()
	local c=lp.Character
	return c and c:FindFirstChildWhichIsA("Humanoid")
end

local function valOf(v)
	if not v then return nil end
	if v:IsA("IntValue")or v:IsA("NumberValue")then return tonumber(v.Value)end
	if v:IsA("StringValue")then return tonumber(v.Value)end
	local ok,res=pcall(function()return tonumber(v.Value)end)
	if ok then return res end
	return nil
end

local function hasHands(obj)
	if not obj then return false end
	local l=obj:FindFirstChild("LeftHand",true)
	local r=obj:FindFirstChild("RightHand",true)
	return l~=nil and r~=nil
end

local function findRockModelFromValue(valueObj)
	local p=valueObj
	for _=1,8 do
		if not p or p==workspace then break end
		if hasHands(p) then return p end
		p=p.Parent
	end

	p=valueObj.Parent
	for _=1,4 do
		if not p or p==workspace then break end
		for _,d in ipairs(p:GetDescendants())do
			if hasHands(d)then return d end
		end
		p=p.Parent
	end

	return valueObj.Parent
end

local function biggestPart(obj)
	if not obj then return nil end
	if obj:IsA("BasePart")then return obj end

	local best=nil
	local vol=-1
	for _,d in ipairs(obj:GetDescendants())do
		if d:IsA("BasePart")then
			local v=d.Size.X*d.Size.Y*d.Size.Z
			if v>vol then
				vol=v
				best=d
			end
		end
	end
	return best
end

local function scanRocks()
	local found={}
	local all=workspace:GetDescendants()

	for _,v in ipairs(all)do
		if tostring(v.Name)=="neededDurability"then
			local req=valOf(v)
			if req~=nil then
				local model=findRockModelFromValue(v)
				local body=biggestPart(model)
				local lh=model and model:FindFirstChild("LeftHand",true)
				local rh=model and model:FindFirstChild("RightHand",true)
				local hit=rh or lh or body

				if body or hit then
					found[req]={
						req=req,
						valueObj=v,
						model=model,
						body=body,
						hit=hit,
						left=lh,
						right=rh,
						name=model and model.Name or "?",
					}
				end
			end
		end
	end

	rockCache=found
	return found
end

local function getRock(row)
	if not row then return nil end
	if not rockCache[row.req]then scanRocks()end
	return rockCache[row.req]
end

local function stopLock()
	if lockConn then lockConn:Disconnect() lockConn=nil end
	lockCF=nil

	local h=hum()
	if h then
		if oldSpeed then pcall(function()h.WalkSpeed=oldSpeed end)end
		if oldAuto~=nil then pcall(function()h.AutoRotate=oldAuto end)end
	end
	oldSpeed=nil
	oldAuto=nil
end

local function startLock(cf)
	stopLock()
	lockCF=cf

	local h=hum()
	if h then
		oldSpeed=h.WalkSpeed
		oldAuto=h.AutoRotate
		pcall(function()h.WalkSpeed=0 end)
		pcall(function()h.AutoRotate=false end)
	end

	lockConn=RunService.Heartbeat:Connect(function()
		local r=root()
		if r and lockCF then
			r.CFrame=lockCF
			r.AssemblyLinearVelocity=Vector3.zero
			r.AssemblyAngularVelocity=Vector3.zero
		end
	end)
end

local function tpInsideRock(row)
	local info=getRock(row)
	if not info then return false,"камень не найден"end

	local body=info.body or info.hit
	if not body then return false,"нет BasePart камня"end

	local r=root()
	if not r then return false,"нет HumanoidRootPart"end

	local size=body.Size
	local offsetY=math.clamp(size.Y*0.08,0,2)

	-- Фикс внутри/около центра камня. Если где-то застревает — можно поставить _G.RockBugInsideOffset.
	local custom=_G.RockBugInsideOffset
	local cf
	if typeof(custom)=="Vector3"then
		cf=body.CFrame*CFrame.new(custom)
	else
		cf=body.CFrame*CFrame.new(0,offsetY,0)
	end

	r.CFrame=cf
	task.wait(.08)
	startLock(cf)
	return true,info
end

local function firePunchRemote()
	pcall(function()
		if lp:FindFirstChild("muscleEvent")then
			lp.muscleEvent:FireServer("punch","rightHand")
		end
	end)

	pcall(function()
		local rs=game:GetService("ReplicatedStorage")
		local re=rs:FindFirstChild("rEvents")
		local ev=re and re:FindFirstChild("muscleEvent")
		if ev and ev.FireServer then
			ev:FireServer("punch","rightHand")
		end
	end)
end

local function activateFistTool()
	local c=lp.Character
	if not c then return end

	for _,tool in ipairs(c:GetChildren())do
		if tool:IsA("Tool")then
			local n=tool.Name:lower()
			local bad=n:find("dumb",1,true)or n:find("weight",1,true)or n:find("barbell",1,true)or n:find("гант",1,true)or n:find("гир",1,true)
			local good=n:find("fist",1,true)or n:find("punch",1,true)or n:find("combat",1,true)or n:find("кулак",1,true)or n:find("удар",1,true)
			if good and not bad then
				pcall(function()tool:Activate()end)
			end
		end
	end
end

local function touchRock(row)
	local info=getRock(row)
	if not info then return end
	local target=info.hit or info.body
	if not target or not target:IsA("BasePart")then return end
	if not firetouchinterest then return end

	local c=lp.Character
	if not c then return end

	local parts={
		c:FindFirstChild("RightHand"),
		c:FindFirstChild("LeftHand"),
		c:FindFirstChild("Right Arm"),
		c:FindFirstChild("Left Arm"),
		c:FindFirstChild("HumanoidRootPart"),
	}

	for _,p in ipairs(parts)do
		if p and p:IsA("BasePart")then
			pcall(function()
				firetouchinterest(p,target,0)
				task.wait()
				firetouchinterest(p,target,1)
			end)
		end
	end
end

local function startHit(row,statusFn)
	hitting=true
	if hitConn then hitConn:Disconnect() hitConn=nil end

	hitConn=RunService.Heartbeat:Connect(function()
		if not hitting then return end
		firePunchRemote()
		activateFistTool()
		touchRock(row)
	end)

	if statusFn then statusFn("BUG HIT: включён")end
end

local function stopHit(statusFn)
	hitting=false
	if hitConn then hitConn:Disconnect() hitConn=nil end
	if statusFn then statusFn("BUG HIT: остановлен")end
end

-- UI
local gui=Instance.new("ScreenGui")
gui.Name="RockBugHubStandaloneV2"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=999999
gui.Parent=lp:WaitForChild("PlayerGui")

local function corner(o,r)
	local c=Instance.new("UICorner",o)
	c.CornerRadius=UDim.new(0,r or 10)
	return c
end

local function stroke(o,col,t)
	local s=Instance.new("UIStroke",o)
	s.Color=col or Color3.fromRGB(140,90,255)
	s.Thickness=t or 1
	return s
end

local main=Instance.new("Frame",gui)
main.Size=UDim2.new(0,352,0,452)
main.Position=UDim2.new(0,14,0,95)
main.BackgroundColor3=Color3.fromRGB(8,8,18)
main.BackgroundTransparency=0.16
main.BorderSizePixel=0
main.Active=true
corner(main,16)
stroke(main,Color3.fromRGB(132,74,255),1.5)

local top=Instance.new("Frame",main)
top.Size=UDim2.new(1,0,0,42)
top.BackgroundColor3=Color3.fromRGB(12,12,28)
top.BackgroundTransparency=0.08
top.BorderSizePixel=0
corner(top,16)

local title=Instance.new("TextLabel",top)
title.Size=UDim2.new(1,-84,1,0)
title.Position=UDim2.new(0,12,0,0)
title.BackgroundTransparency=1
title.Text="Rock Bug Hub"
title.TextColor3=Color3.new(1,1,1)
title.Font=Enum.Font.GothamBlack
title.TextSize=17
title.TextXAlignment=Enum.TextXAlignment.Left

local min=Instance.new("TextButton",top)
min.Size=UDim2.new(0,30,0,28)
min.Position=UDim2.new(1,-68,0,7)
min.Text="−"
min.TextColor3=Color3.new(1,1,1)
min.BackgroundColor3=Color3.fromRGB(47,40,90)
min.Font=Enum.Font.GothamBlack
min.TextSize=17
corner(min,8)

local close=Instance.new("TextButton",top)
close.Size=UDim2.new(0,30,0,28)
close.Position=UDim2.new(1,-34,0,7)
close.Text="×"
close.TextColor3=Color3.fromRGB(255,190,200)
close.BackgroundColor3=Color3.fromRGB(78,25,40)
close.Font=Enum.Font.GothamBlack
close.TextSize=17
corner(close,8)

local mini=Instance.new("TextButton",gui)
mini.Size=UDim2.new(0,86,0,34)
mini.Position=main.Position
mini.Text="ROCK BUG"
mini.TextColor3=Color3.new(1,1,1)
mini.BackgroundColor3=Color3.fromRGB(75,45,170)
mini.BackgroundTransparency=0.06
mini.Font=Enum.Font.GothamBlack
mini.TextSize=11
mini.Visible=false
corner(mini,10)
stroke(mini,Color3.fromRGB(150,92,255),1)

local status=Instance.new("TextLabel",main)
status.Size=UDim2.new(1,-20,0,36)
status.Position=UDim2.new(0,10,0,48)
status.BackgroundColor3=Color3.fromRGB(12,12,30)
status.BackgroundTransparency=0.10
status.Text="SCAN → выбери камень → TP LOCK / BUG HIT"
status.TextColor3=Color3.fromRGB(255,245,185)
status.Font=Enum.Font.GothamBold
status.TextSize=12
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left
status.TextYAlignment=Enum.TextYAlignment.Center
corner(status,10)

local function setStatus(t)
	status.Text=tostring(t)
end

local list=Instance.new("ScrollingFrame",main)
list.Size=UDim2.new(1,-20,0,226)
list.Position=UDim2.new(0,10,0,92)
list.BackgroundColor3=Color3.fromRGB(6,6,16)
list.BackgroundTransparency=0.18
list.BorderSizePixel=0
list.ScrollBarThickness=4
list.CanvasSize=UDim2.new(0,0,0,0)
corner(list,12)
stroke(list,Color3.fromRGB(65,55,120),1)

local pad=Instance.new("UIPadding",list)
pad.PaddingTop=UDim.new(0,6)
pad.PaddingLeft=UDim.new(0,6)
pad.PaddingRight=UDim.new(0,6)
pad.PaddingBottom=UDim.new(0,6)

local layout=Instance.new("UIListLayout",list)
layout.Padding=UDim.new(0,6)
layout.SortOrder=Enum.SortOrder.LayoutOrder

local buttons={}

local function refreshButtons()
	for _,b in pairs(buttons)do b:Destroy()end
	buttons={}

	for i,row in ipairs(ROCKS)do
		local info=rockCache[row.req]
		local b=Instance.new("TextButton",list)
		b.Size=UDim2.new(1,-4,0,38)
		b.BackgroundColor3=(selected.id==row.id) and Color3.fromRGB(88,58,180) or Color3.fromRGB(18,18,42)
		b.BackgroundTransparency=(selected.id==row.id) and 0.04 or 0.16
		b.TextColor3=Color3.fromRGB(255,245,190)
		b.Font=Enum.Font.GothamBlack
		b.TextSize=12
		b.TextXAlignment=Enum.TextXAlignment.Left
		b.Text=("  %s  [%s]  %s"):format(row.label,tostring(row.req),info and "✓ найден" or "× нет")
		b.LayoutOrder=i
		corner(b,9)

		local st=stroke(b,row.color,1)
		st.Transparency=info and 0 or .55

		b.Activated:Connect(function()
			selected=row
			refreshButtons()
			setStatus("Выбран: "..row.label.." | req "..row.req)
		end)

		table.insert(buttons,b)
	end

	list.CanvasSize=UDim2.new(0,0,0,#ROCKS*44+12)
end

local function mkBtn(txt,x,y,w,h,col)
	local b=Instance.new("TextButton",main)
	b.Size=UDim2.new(0,w,0,h)
	b.Position=UDim2.new(0,x,0,y)
	b.Text=txt
	b.TextColor3=Color3.new(1,1,1)
	b.BackgroundColor3=col
	b.Font=Enum.Font.GothamBlack
	b.TextSize=12
	corner(b,9)
	return b
end

local scanBtn=mkBtn("SCAN",10,328,58,34,Color3.fromRGB(78,60,160))
local tpBtn=mkBtn("TP LOCK",74,328,82,34,Color3.fromRGB(45,105,200))
local hitBtn=mkBtn("BUG HIT",162,328,78,34,Color3.fromRGB(32,145,72))
local unlockBtn=mkBtn("UNLOCK",246,328,96,34,Color3.fromRGB(140,75,35))

local copyBtn=mkBtn("COPY",10,370,72,34,Color3.fromRGB(120,85,35))
local antiBtn=mkBtn("AFK ON",90,370,82,34,Color3.fromRGB(45,100,160))
local reportBtn=mkBtn("REPORT",180,370,82,34,Color3.fromRGB(95,70,165))
local stopBtn=mkBtn("STOP",270,370,72,34,Color3.fromRGB(135,34,48))

local lastReport=""

scanBtn.Activated:Connect(function()
	setStatus("Сканирую камни...")
	local found=scanRocks()
	local count=0
	local lines={"RockBug scan report"}
	for _,row in ipairs(ROCKS)do
		local info=found[row.req]
		if info then
			count+=1
			table.insert(lines,("%s req=%s model=%s"):format(row.label,row.req,info.name))
		else
			table.insert(lines,("%s req=%s NOT FOUND"):format(row.label,row.req))
		end
	end
	lastReport=table.concat(lines,"\n")
	refreshButtons()
	setStatus("Скан готов: найдено "..count.."/"..#ROCKS)
end)

tpBtn.Activated:Connect(function()
	local ok,res=tpInsideRock(selected)
	if ok then
		setStatus("LOCK: "..selected.label.." | внутри/центр камня")
		lastReport="TP LOCK OK\nRock: "..selected.label.."\nReq: "..selected.req.."\nModel: "..tostring(res.name)
	else
		setStatus("TP error: "..tostring(res))
		lastReport="TP LOCK ERROR\nRock: "..selected.label.."\nReq: "..selected.req.."\nError: "..tostring(res)
	end
end)

hitBtn.Activated:Connect(function()
	if hitting then
		stopHit(setStatus)
		hitBtn.Text="BUG HIT"
		hitBtn.BackgroundColor3=Color3.fromRGB(32,145,72)
	else
		local ok,msg=tpInsideRock(selected)
		if not ok then
			setStatus("BUG error: "..tostring(msg))
			return
		end
		startHit(selected,setStatus)
		hitBtn.Text="HITTING"
		hitBtn.BackgroundColor3=Color3.fromRGB(20,185,95)
	end
end)

unlockBtn.Activated:Connect(function()
	stopLock()
	setStatus("UNLOCK: позиция отпущена")
end)

copyBtn.Activated:Connect(function()
	if not lastReport or #lastReport<2 then
		local found=scanRocks()
		local lines={"RockBug report"}
		for _,row in ipairs(ROCKS)do
			local info=found[row.req]
			table.insert(lines,("%s req=%s %s"):format(row.label,row.req,info and "FOUND" or "NO"))
		end
		lastReport=table.concat(lines,"\n")
	end
	if setclipboard then
		pcall(setclipboard,lastReport)
		setStatus("Отчёт скопирован.")
	else
		setStatus("Clipboard недоступен.")
	end
end)

antiBtn.Activated:Connect(function()
	antiAfkEnabled=not antiAfkEnabled
	antiBtn.Text=antiAfkEnabled and "AFK ON" or "AFK OFF"
	antiBtn.BackgroundColor3=antiAfkEnabled and Color3.fromRGB(45,100,160) or Color3.fromRGB(120,45,45)
	setStatus("Anti AFK: "..(antiAfkEnabled and "включён" or "выключен"))
end)

reportBtn.Activated:Connect(function()
	scanRocks()
	local lines={"RockBug report"}
	for _,row in ipairs(ROCKS)do
		local info=rockCache[row.req]
		table.insert(lines,("%s req=%s %s"):format(row.label,row.req,info and ("FOUND model="..tostring(info.name)) or "NO"))
	end
	lastReport=table.concat(lines,"\n")
	if setclipboard then
		pcall(setclipboard,lastReport)
		setStatus("REPORT скопирован.")
	else
		setStatus("Clipboard недоступен.")
	end
end)

stopBtn.Activated:Connect(function()
	stopHit()
	stopLock()
	setStatus("STOP ALL: всё остановлено")
	hitBtn.Text="BUG HIT"
	hitBtn.BackgroundColor3=Color3.fromRGB(32,145,72)
end)

min.Activated:Connect(function()
	main.Visible=false
	mini.Visible=true
end)

mini.Activated:Connect(function()
	main.Visible=true
	mini.Visible=false
end)

close.Activated:Connect(function()
	stopHit()
	stopLock()
	if antiAfkConn then antiAfkConn:Disconnect() antiAfkConn=nil end
gui:Destroy()
end)

-- Drag only top bar
local UserInputService=game:GetService("UserInputService")
local dragging=false
local dragStart=nil
local startPos=nil

top.InputBegan:Connect(function(input)
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
		local delta=input.Position-dragStart
		main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
		mini.Position=main.Position
	end
end)

-- First scan
scanRocks()
refreshButtons()
setStatus("Готово. Anti AFK включён. Выбери камень → TP LOCK / BUG HIT.")
