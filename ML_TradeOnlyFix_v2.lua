-- ML_ServerResync_Trade_v1
-- Мягкий ресинк после зависшего "loading/input locked" состояния.
-- НЕ жмёт трейд, НЕ FireServer/InvokeServer, НЕ чёрный экран, НЕ сканит каждый кадр.
-- Одна кнопка RESYNC -> STOP. Работает медленно 15 сек, можно остановить той же кнопкой.

local Players=game:GetService("Players")
local StarterGui=game:GetService("StarterGui")
local ReplicatedFirst=game:GetService("ReplicatedFirst")
local UserInputService=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")
local Stats=game:GetService("Stats")

local lp=Players.LocalPlayer
local VERSION="ML_ServerResync_Trade_v1"

local running=false
local runId=0
local hidden={}
local lastReport="Сначала нажми RESYNC или COPY REPORT."

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
	local limit=0
	while cur and cur~=game and limit<20 do
		table.insert(parts,1,tostring(cur.Name))
		cur=cur.Parent
		limit+=1
	end
	return table.concat(parts,"/")
end

local EXACT_TRADE_PATHS={
	"gameGui",
	"gameGui/sideButtons/tradeButton",
	"gameGui/gameGuiScript",
	"gameGui/gameGuiScript/playerTradeFrame",
	"gameGui/gameGuiScript/playerTradeFrame/nameLabel/tradeButton",
	"gameGui/gameGuiScript/tradeRequestMenu",
	"gameGui/gameGuiScript/tradeRequestMenu/tradeButton",
	"gameGui/tradePanel",
	"gameGui/tradePanel/acceptButton",
	"gameGui/tradePanel/declineButton",
	"gameGui/tradePanel/sideButtons/petsButton",
}

local function setStatus(t)
	if _G.MLServerResyncStatus then
		_G.MLServerResyncStatus.Text=tostring(t)
	end
end

local function setBtn()
	if _G.MLServerResyncButton then
		_G.MLServerResyncButton.Text=running and "STOP" or "RESYNC"
		_G.MLServerResyncButton.BackgroundColor3=running and Color3.fromRGB(135,55,65) or Color3.fromRGB(45,130,75)
	end
end

local function connCount(sig)
	if type(getconnections)~="function" or not sig then return "no_getconnections" end
	local ok,cons=pcall(getconnections,sig)
	if not ok or type(cons)~="table" then return "err" end
	local enabled=0
	for _,c in ipairs(cons) do
		local dis=false
		pcall(function()
			if c.Enabled==false then dis=true end
		end)
		if not dis then enabled+=1 end
	end
	return tostring(enabled).."/"..tostring(#cons)
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

local function basicUnlock()
	safe(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
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

	local cam=workspace.CurrentCamera
	local c=lp.Character
	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	local root=c and c:FindFirstChild("HumanoidRootPart")

	if cam and hum then
		safe(function()
			cam.CameraType=Enum.CameraType.Custom
			cam.CameraSubject=hum
		end)
	end

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

	-- точечно делаем найденные trade элементы кликабельными, без открытия/нажатия
	for _,path in ipairs(EXACT_TRADE_PATHS) do
		local o=getPath(path)
		if o and o:IsA("ScreenGui") then
			safe(function()
				o.Enabled=true
				o.DisplayOrder=math.max(o.DisplayOrder,100)
			end)
		elseif o and o:IsA("GuiObject") then
			safe(function()
				o.Visible=true
				o.Active=true
				o.ZIndex=math.max(o.ZIndex,100)
			end)
			if o:IsA("GuiButton") then
				safe(function()
					o.Selectable=true
					o.AutoButtonColor=true
					o.Modal=false
				end)
			end
		end
	end
end

local function restartGameGuiScripts()
	local p=pg()
	if not p then return 0 end
	local gameGui=p:FindFirstChild("gameGui")
	if not gameGui then return 0 end

	local restarted=0
	local targets={}

	local exact=gameGui:FindFirstChild("gameGuiScript")
	if exact and exact:IsA("LocalScript") then
		table.insert(targets,exact)
	end

	for _,d in ipairs(gameGui:GetDescendants()) do
		if d:IsA("LocalScript") then
			local n=tostring(d.Name):lower()
			if n:find("game",1,true) or n:find("trade",1,true) or n:find("gui",1,true) then
				table.insert(targets,d)
			end
		end
		if #targets>=12 then break end
	end

	local seen={}
	for _,s in ipairs(targets) do
		if not seen[s] then
			seen[s]=true
			safe(function()
				s.Disabled=true
			end)
			task.wait(0.08)
			safe(function()
				s.Disabled=false
			end)
			restarted+=1
		end
	end

	return restarted
end

local function requestStream()
	local c=lp.Character
	local root=c and c:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local ok=safe(function()
		lp:RequestStreamAroundAsync(root.Position, 4)
	end)

	-- маленький сетевой "пинок" через обычное движение, не remotes
	local hum=c:FindFirstChildWhichIsA("Humanoid")
	if hum then
		safe(function()
			hum.Jump=true
			hum:Move(Vector3.new(0,0,-0.01),true)
			task.wait(0.05)
			hum:Move(Vector3.new(0,0,0),true)
		end)
	end

	return ok
end

local function areaOf(o)
	local ok,res=safe(function()
		local cam=workspace.CurrentCamera
		local vp=cam and cam.ViewportSize or Vector2.new(0,0)
		if vp.X<=0 or vp.Y<=0 then return 0 end
		local sz=o.AbsoluteSize
		return (sz.X*sz.Y)/(vp.X*vp.Y)
	end)
	if ok then return tonumber(res) or 0 end
	return 0
end

local LOADING_WORDS={
	"loading","load","загрузка","intro","fade","black","transition","teleport","blocker","input","cover","wait"
}

local function hideLoadingBlockers()
	local p=pg()
	if not p then return 0 end
	local gameGui=p:FindFirstChild("gameGui")
	if not gameGui then return 0 end

	local count=0
	local scanned=0

	for _,d in ipairs(gameGui:GetDescendants()) do
		scanned+=1
		if scanned>1200 then break end

		if d:IsA("GuiObject") then
			local name=tostring(d.Name):lower()
			local area=areaOf(d)
			local visible=false
			local active=false
			local bg=1

			safe(function() visible=d.Visible end)
			safe(function() active=d.Active end)
			safe(function() bg=d.BackgroundTransparency end)

			if visible and area>0.35 and (active or bg<0.95) then
				local isLoading=false
				for _,w in ipairs(LOADING_WORDS) do
					if name:find(w,1,true) then isLoading=true break end
				end

				-- Только подозрительные loading/fade/blocker, не весь GUI.
				if isLoading and not hidden[d] then
					hidden[d]={Visible=d.Visible,Active=d.Active,BackgroundTransparency=d.BackgroundTransparency}
					safe(function()
						d.Visible=false
						d.Active=false
						d.BackgroundTransparency=1
					end)
					count+=1
				end
			end
		end
	end

	return count
end

local function restoreHidden()
	for obj,rec in pairs(hidden) do
		if obj and obj.Parent then
			if rec.Visible~=nil then safe(function() obj.Visible=rec.Visible end) end
			if rec.Active~=nil then safe(function() obj.Active=rec.Active end) end
			if rec.BackgroundTransparency~=nil then safe(function() obj.BackgroundTransparency=rec.BackgroundTransparency end) end
		end
	end
	hidden={}
	setStatus("hidden restored")
end

local function makeReport()
	local lines={}
	local function add(s) lines[#lines+1]=s end

	add("=== ML SERVER RESYNC REPORT ===")
	add("version: "..VERSION)
	add("ping: "..getPing())
	add("PlayerGui: "..tostring(pg()~=nil))
	add("hidden loading blockers: "..tostring((function() local n=0 for _ in pairs(hidden) do n+=1 end return n end)()))
	add("")

	for _,path in ipairs(EXACT_TRADE_PATHS) do
		local o=getPath(path)
		if o then
			local info=path.." | "..o.ClassName
			if o:IsA("GuiObject") then
				local vis,act,z="?","?","?"
				safe(function() vis=tostring(o.Visible) end)
				safe(function() act=tostring(o.Active) end)
				safe(function() z=tostring(o.ZIndex) end)
				info=info.." | visible="..vis.." active="..act.." z="..z
			elseif o:IsA("ScreenGui") then
				info=info.." | enabled="..tostring(o.Enabled).." order="..tostring(o.DisplayOrder)
			end

			if o:IsA("GuiButton") then
				info=info.." | ActivatedConns="..connCount(o.Activated).." MouseConns="..connCount(o.MouseButton1Click)
			end

			if o:IsA("LocalScript") then
				info=info.." | Disabled="..tostring(o.Disabled)
			end

			add(info)
		else
			add(path.." | NOT FOUND")
		end
	end

	lastReport=table.concat(lines,"\n")
	return lastReport
end

local function resyncLoop(my)
	local restartedOnce=false
	local start=os.clock()
	local steps=0
	local hiddenCount=0
	local restarted=0
	local streamed=false

	while running and runId==my and os.clock()-start<15 do
		steps+=1
		basicUnlock()

		if not restartedOnce then
			restartedOnce=true
			restarted=restartGameGuiScripts()
			streamed=requestStream()
		end

		hiddenCount+=hideLoadingBlockers()

		setStatus(("resync %.0fs | scripts:%s stream:%s hidden:%s ping:%s"):format(
			math.max(0,15-(os.clock()-start)),
			tostring(restarted),
			tostring(streamed),
			tostring(hiddenCount),
			getPing()
		))

		task.wait(0.55)
	end

	if runId==my then
		running=false
		setBtn()
		makeReport()
		setStatus("done | copy report")
	end
end

-- UI
local parent=getUiParent()
pcall(function()
	local old=parent:FindFirstChild("ML_ServerResyncGui")
	if old then old:Destroy() end
end)

local gui=Instance.new("ScreenGui")
gui.Name="ML_ServerResyncGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=10000000
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=parent

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,318,0,166)
main.Position=UDim2.new(0,14,0,112)
main.BackgroundColor3=Color3.fromRGB(14,15,22)
main.BackgroundTransparency=0.04
main.BorderSizePixel=0
main.Active=true
main.ZIndex=1000
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)
local st=Instance.new("UIStroke",main)
st.Color=Color3.fromRGB(90,190,255)
st.Thickness=1.3
st.Transparency=0.1

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-48,0,24)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="SERVER RESYNC"
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
status.Size=UDim2.new(1,-24,0,40)
status.Position=UDim2.new(0,12,0,38)
status.BackgroundTransparency=1
status.Text="готово | RESYNC можно остановить той же кнопкой"
status.TextColor3=Color3.fromRGB(215,225,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left
status.ZIndex=1001
_G.MLServerResyncStatus=status

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

local resyncBtn=mk("RESYNC",12,88,94,34)
local copyBtn=mk("COPY REPORT",116,88,104,34)
local restoreBtn=mk("RESTORE HIDDEN",230,88,76,34)
local reportBox=Instance.new("TextBox")
reportBox.Parent=main
reportBox.Size=UDim2.new(1,-24,0,30)
reportBox.Position=UDim2.new(0,12,0,130)
reportBox.BackgroundColor3=Color3.fromRGB(8,9,14)
reportBox.BackgroundTransparency=0.05
reportBox.BorderSizePixel=0
reportBox.TextColor3=Color3.fromRGB(220,230,245)
reportBox.Font=Enum.Font.Code
reportBox.TextSize=8
reportBox.ClearTextOnFocus=false
reportBox.TextXAlignment=Enum.TextXAlignment.Left
reportBox.Text="report preview here"
reportBox.ZIndex=1001
Instance.new("UICorner",reportBox).CornerRadius=UDim.new(0,10)

_G.MLServerResyncButton=resyncBtn

resyncBtn.Activated:Connect(function()
	if running then
		running=false
		runId+=1
		setBtn()
		makeReport()
		reportBox.Text=lastReport
		setStatus("stopped | copy report")
		return
	end

	running=true
	runId+=1
	setBtn()
	reportBox.Text="running..."
	task.spawn(resyncLoop,runId)
end)

copyBtn.Activated:Connect(function()
	local rep=makeReport()
	reportBox.Text=rep
	local ok=false
	safe(function()
		if setclipboard then
			setclipboard(rep)
			ok=true
		end
	end)
	setStatus(ok and "report copied" or "no setclipboard | copy from box")
end)

restoreBtn.Activated:Connect(function()
	restoreHidden()
	makeReport()
	reportBox.Text=lastReport
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
reportBox.Text=lastReport
