-- ML_GameGuiRelink_v1
-- Цель: восстановить обработчики кнопок gameGui/trade без спама и без циклов.
-- НЕ FireServer/InvokeServer, НЕ kick/rejoin, НЕ чёрный экран, НЕ Heartbeat.
-- Одна кнопка REPAIR -> STOP. Если не поможет, COPY REPORT.

local Players=game:GetService("Players")
local StarterGui=game:GetService("StarterGui")
local CoreGui=game:GetService("CoreGui")
local UserInputService=game:GetService("UserInputService")
local Stats=game:GetService("Stats")

local lp=Players.LocalPlayer
local VERSION="ML_GameGuiRelink_v1"

local running=false
local runId=0
local lastReport="Нажми REPAIR. Если не поможет — COPY REPORT."

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

local function pathOf(obj)
	local parts={}
	local cur=obj
	local n=0
	while cur and cur~=game and n<20 do
		table.insert(parts,1,tostring(cur.Name))
		cur=cur.Parent
		n+=1
	end
	return table.concat(parts,"/")
end

local TARGET_BUTTON_PATHS={
	"gameGui/sideButtons/tradeButton",
	"gameGui/gameGuiScript/playerTradeFrame/nameLabel/tradeButton",
	"gameGui/gameGuiScript/tradeRequestMenu/tradeButton",
	"gameGui/tradePanel/acceptButton",
	"gameGui/tradePanel/declineButton",
	"gameGui/tradePanel/sideButtons/petsButton",
}

local function setStatus(t)
	if _G.MLRelinkStatus then
		_G.MLRelinkStatus.Text=tostring(t)
	end
end

local function setBtn()
	if _G.MLRelinkButton then
		_G.MLRelinkButton.Text=running and "STOP" or "REPAIR"
		_G.MLRelinkButton.BackgroundColor3=running and Color3.fromRGB(135,55,65) or Color3.fromRGB(45,130,75)
	end
end

local function getPing()
	local ok,res=safe(function()
		local net=Stats:FindFirstChild("Network")
		local item=net and net:FindFirstChild("ServerStatsItem")
		local ping=item and item:FindFirstChild("Data Ping")
		if ping then return ping:GetValueString() end
	end)
	if ok and res then return tostring(res) end
	return "unknown"
end

local function countCons(sig)
	if type(getconnections)~="function" or not sig then
		return -1,-1
	end
	local ok,cons=pcall(getconnections,sig)
	if not ok or type(cons)~="table" then
		return -1,-1
	end
	local enabled=0
	for _,c in ipairs(cons) do
		local disabled=false
		safe(function()
			if c.Enabled==false then disabled=true end
		end)
		if not disabled then enabled+=1 end
	end
	return enabled,#cons
end

local function buttonConnText(btn)
	if not btn or not btn:IsA("GuiButton") then return "not_button" end
	local ae,at=countCons(btn.Activated)
	local me,mt=countCons(btn.MouseButton1Click)
	if ae<0 then return "no_getconnections" end
	return ("Activated=%s/%s Mouse=%s/%s"):format(ae,at,me,mt)
end

local function totalTargetConnections()
	local total=0
	local known=false

	for _,path in ipairs(TARGET_BUTTON_PATHS) do
		local b=getPath(path)
		if b and b:IsA("GuiButton") then
			local ae,at=countCons(b.Activated)
			local me,mt=countCons(b.MouseButton1Click)
			if ae>=0 then
				known=true
				total+=ae+me
			end
		end
	end

	return known,total
end

local function setScriptEnabled(scr,on)
	if not scr then return end
	safe(function() scr.Disabled=not on end)
	safe(function() scr.Enabled=on end)
end

local function basicUnlock()
	safe(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true) end)

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
		local hum=c:FindFirstChildWhichIsA("Humanoid")
		local root=c:FindFirstChild("HumanoidRootPart")
		if hum then
			safe(function()
				hum.PlatformStand=false
				hum.Sit=false
				hum.AutoRotate=true
				if hum.WalkSpeed<12 then hum.WalkSpeed=16 end
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

	local gameGui=getPath("gameGui")
	if gameGui and gameGui:IsA("ScreenGui") then
		safe(function()
			gameGui.Enabled=true
			gameGui.DisplayOrder=math.max(gameGui.DisplayOrder,200)
			gameGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
		end)
	end

	for _,path in ipairs(TARGET_BUTTON_PATHS) do
		local b=getPath(path)
		if b and b:IsA("GuiObject") then
			safe(function()
				b.Visible=true
				b.Active=true
				b.ZIndex=math.max(b.ZIndex,200)
			end)
			if b:IsA("GuiButton") then
				safe(function()
					b.Selectable=true
					b.AutoButtonColor=true
					b.Modal=false
				end)
			end
		end
	end
end

local function restartOriginalScript()
	local scr=getPath("gameGui/gameGuiScript")
	if not scr or not scr:IsA("LocalScript") then
		return false,"gameGuiScript not found/not LocalScript"
	end

	setStatus("restart original...")
	setScriptEnabled(scr,false)
	task.wait(0.25)
	setScriptEnabled(scr,true)
	task.wait(0.9)

	return true,"original toggled"
end

local function cleanClones()
	local gameGui=getPath("gameGui")
	if not gameGui then return 0 end
	local n=0

	for _,d in ipairs(gameGui:GetChildren()) do
		local name=tostring(d.Name)
		if name:find("ML_RELINK_",1,true) then
			safe(function()
				if d:IsA("LocalScript") then setScriptEnabled(d,false) end
				d:Destroy()
			end)
			n+=1
		end
	end

	return n
end

local function cloneGameGuiScript()
	local gameGui=getPath("gameGui")
	local scr=getPath("gameGui/gameGuiScript")

	if not gameGui then return false,"gameGui missing" end
	if not scr or not scr:IsA("LocalScript") then return false,"gameGuiScript missing" end

	cleanClones()
	task.wait(0.15)

	local ok,clone=safe(function()
		scr.Archivable=true
		return scr:Clone()
	end)

	if not ok or not clone then
		return false,"clone failed"
	end

	clone.Name="ML_RELINK_gameGuiScript_CLONE"
	setScriptEnabled(clone,false)
	clone.Parent=gameGui

	-- Клон содержит свои playerTradeFrame/tradeRequestMenu. Поднимем только trade-похожие части, без открытия магазина.
	for _,d in ipairs(clone:GetDescendants()) do
		local n=tostring(d.Name):lower()
		if d:IsA("GuiObject") and (n:find("trade",1,true) or n:find("pet",1,true) or n:find("offer",1,true) or n:find("accept",1,true)) then
			safe(function()
				d.Visible=true
				d.Active=true
				d.ZIndex=math.max(d.ZIndex,350)
			end)
			if d:IsA("GuiButton") then
				safe(function()
					d.Selectable=true
					d.AutoButtonColor=true
					d.Modal=false
				end)
			end
		end
	end

	setStatus("starting clone...")
	task.wait(0.25)
	setScriptEnabled(clone,true)
	task.wait(1.5)

	return true,"clone started: "..clone.Name
end

local function findCloneConnections()
	local gameGui=getPath("gameGui")
	if not gameGui then return "no gameGui" end

	local lines={}
	local found=0
	for _,d in ipairs(gameGui:GetDescendants()) do
		if d:IsA("GuiButton") then
			local p=pathOf(d)
			local low=p:lower()
			if low:find("ml_relink",1,true) and (low:find("trade",1,true) or low:find("accept",1,true) or low:find("pet",1,true)) then
				found+=1
				if found<=25 then
					lines[#lines+1]=p.." | "..buttonConnText(d)
				end
			end
		end
	end

	if #lines==0 then return "no clone trade buttons found" end
	return table.concat(lines,"\n")
end

local function makeReport()
	local lines={}
	local function add(s) lines[#lines+1]=s end

	add("=== ML GAMEGUI RELINK REPORT ===")
	add("version: "..VERSION)
	add("ping: "..getPing())
	add("PlayerGui: "..tostring(pg()~=nil))
	add("")

	local scr=getPath("gameGui/gameGuiScript")
	if scr then
		local dis,en="?","?"
		safe(function() dis=tostring(scr.Disabled) end)
		safe(function() en=tostring(scr.Enabled) end)
		add("gameGuiScript: "..scr.ClassName.." Disabled="..dis.." Enabled="..en)
	else
		add("gameGuiScript: NOT FOUND")
	end

	add("")
	add("[ORIGINAL BUTTON CONNECTIONS]")
	for _,path in ipairs(TARGET_BUTTON_PATHS) do
		local b=getPath(path)
		if b then
			local vis,act,z="?","?","?"
			safe(function() vis=tostring(b.Visible) end)
			safe(function() act=tostring(b.Active) end)
			safe(function() z=tostring(b.ZIndex) end)
			add(path.." | "..b.ClassName.." visible="..vis.." active="..act.." z="..z.." | "..buttonConnText(b))
		else
			add(path.." | NOT FOUND")
		end
	end

	add("")
	add("[CLONE BUTTON CONNECTIONS]")
	add(findCloneConnections())

	lastReport=table.concat(lines,"\n")
	return lastReport
end

local function repair(my)
	local log={}
	local function add(s)
		log[#log+1]=s
		setStatus(s)
	end

	add("basic unlock...")
	basicUnlock()
	task.wait(0.3)

	local known,before=totalTargetConnections()
	add("before conns: "..(known and tostring(before) or "unknown"))
	task.wait(0.1)

	if running and runId==my then
		local ok,msg=restartOriginalScript()
		add("restart: "..tostring(ok).." | "..tostring(msg))
	end

	basicUnlock()
	task.wait(0.4)

	local known2,afterRestart=totalTargetConnections()
	add("after restart conns: "..(known2 and tostring(afterRestart) or "unknown"))

	if running and runId==my and known2 and afterRestart==0 then
		local ok,msg=cloneGameGuiScript()
		add("clone: "..tostring(ok).." | "..tostring(msg))
		basicUnlock()
	end

	task.wait(0.4)
	makeReport()

	if running and runId==my then
		running=false
		setBtn()
		setStatus("done | try trade or COPY REPORT")
		if _G.MLRelinkBox then
			_G.MLRelinkBox.Text=lastReport
		end
	end
end

-- UI
local parent=getUiParent()
pcall(function()
	local old=parent:FindFirstChild("ML_GameGuiRelinkGui")
	if old then old:Destroy() end
end)

local gui=Instance.new("ScreenGui")
gui.Name="ML_GameGuiRelinkGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=10000000
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=parent

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,324,0,178)
main.Position=UDim2.new(0,14,0,112)
main.BackgroundColor3=Color3.fromRGB(14,15,22)
main.BackgroundTransparency=0.04
main.BorderSizePixel=0
main.Active=true
main.ZIndex=1000
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)

local stroke=Instance.new("UIStroke",main)
stroke.Color=Color3.fromRGB(90,190,255)
stroke.Thickness=1.3
stroke.Transparency=0.1

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-48,0,24)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="GAMEGUI RELINK"
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
status.Size=UDim2.new(1,-24,0,38)
status.Position=UDim2.new(0,12,0,38)
status.BackgroundTransparency=1
status.Text="готово | REPAIR можно остановить той же кнопкой"
status.TextColor3=Color3.fromRGB(215,225,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left
status.ZIndex=1001
_G.MLRelinkStatus=status

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

local repairBtn=mk("REPAIR",12,84,92,34)
local copyBtn=mk("COPY REPORT",114,84,104,34)
local cleanBtn=mk("CLEAN CLONE",228,84,84,34)

local box=Instance.new("TextBox")
box.Parent=main
box.Size=UDim2.new(1,-24,0,44)
box.Position=UDim2.new(0,12,0,126)
box.BackgroundColor3=Color3.fromRGB(8,9,14)
box.BackgroundTransparency=0.05
box.BorderSizePixel=0
box.TextColor3=Color3.fromRGB(220,230,245)
box.Font=Enum.Font.Code
box.TextSize=8
box.TextXAlignment=Enum.TextXAlignment.Left
box.TextYAlignment=Enum.TextYAlignment.Top
box.ClearTextOnFocus=false
box.MultiLine=true
box.Text="report preview"
box.ZIndex=1001
Instance.new("UICorner",box).CornerRadius=UDim.new(0,10)

_G.MLRelinkButton=repairBtn
_G.MLRelinkBox=box

repairBtn.Activated:Connect(function()
	if running then
		running=false
		runId+=1
		setBtn()
		makeReport()
		box.Text=lastReport
		setStatus("stopped | copy report")
		return
	end

	running=true
	runId+=1
	setBtn()
	box.Text="repair running..."
	task.spawn(repair,runId)
end)

copyBtn.Activated:Connect(function()
	local rep=makeReport()
	box.Text=rep
	local ok=false
	safe(function()
		if setclipboard then
			setclipboard(rep)
			ok=true
		end
	end)
	setStatus(ok and "report copied" or "no setclipboard | copy box")
end)

cleanBtn.Activated:Connect(function()
	local n=cleanClones()
	basicUnlock()
	makeReport()
	box.Text=lastReport
	setStatus("cleaned clones: "..tostring(n))
end)

close.Activated:Connect(function()
	running=false
	runId+=1
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
	if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
		local d=input.Position-dragStart
		main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end)

setBtn()
makeReport()
box.Text=lastReport
