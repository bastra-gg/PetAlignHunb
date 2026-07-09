-- RockBug_EmergencyReset_v1
-- Аварийный откат после сломанного RockBugHub v20/v21/v22.
-- Без rejoin/kick. Только локально возвращает рендер, текстуры, персонажа и пытается остановить старые циклы.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local UserInputService=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")

local lp=Players.LocalPlayer
local VERSION="RockBug_EmergencyReset_v1"

local stats={
	gui=0,
	gcTables=0,
	gcFuncs=0,
	conns=0,
	props=0,
	char=0,
	render=0,
	last="ready"
}

local function say(s)
	stats.last=s
end

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

local function tryDisconnect(x)
	return pcall(function()
		if x then x:Disconnect()end
	end)
end

local function safeSet(obj,key,val)
	pcall(function()
		if obj then obj[key]=val end
	end)
end

local function restoreLightingPlayable()
	pcall(function()
		RunService:Set3dRenderingEnabled(true)
		stats.render+=1
	end)

	pcall(function()
		Lighting.GlobalShadows=true
		Lighting.Brightness=2
		Lighting.FogEnd=100000
		Lighting.FogColor=Color3.fromRGB(192,192,192)
		Lighting.Ambient=Color3.fromRGB(127,127,127)
		Lighting.OutdoorAmbient=Color3.fromRGB(127,127,127)
		Lighting.ColorShift_Top=Color3.fromRGB(0,0,0)
		Lighting.ColorShift_Bottom=Color3.fromRGB(0,0,0)
		Lighting.EnvironmentDiffuseScale=1
		Lighting.EnvironmentSpecularScale=1
		pcall(function()Lighting.ExposureCompensation=0 end)
		stats.render+=1
	end)

	pcall(function()
		local ugs=UserSettings():GetService("UserGameSettings")
		ugs.SavedQualityLevel=Enum.SavedQualitySetting.Automatic
		stats.render+=1
	end)

	pcall(function()
		local rs=settings().Rendering
		rs.QualityLevel=Enum.QualityLevel.Automatic
		stats.render+=1
	end)
end

local function restoreLowStateTable(t)
	if type(t)~="table"then return false end
	if type(t.saved)~="table" and type(t.lighting)~="table" and type(t.settings)~="table"then return false end

	-- Вернуть 3D и настройки, если это lowMapState.
	pcall(function()
		RunService:Set3dRenderingEnabled(true)
	end)

	if type(t.lighting)=="table"then
		for k,v in pairs(t.lighting)do
			pcall(function()Lighting[k]=v end)
		end
	end

	if type(t.settings)=="table"then
		pcall(function()
			local ugs=UserSettings():GetService("UserGameSettings")
			if t.settings.SavedQualityLevel~=nil then ugs.SavedQualityLevel=t.settings.SavedQualityLevel end
		end)
		pcall(function()
			local rs=settings().Rendering
			if t.settings.QualityLevel~=nil then rs.QualityLevel=t.settings.QualityLevel end
		end)
	end

	if type(t.saved)=="table"then
		for obj,rec in pairs(t.saved)do
			if typeof(obj)=="Instance" and type(rec)=="table"then
				if rec.Parent~=nil then
					pcall(function()obj.Parent=rec.Parent end)
				end
				for k,v in pairs(rec)do
					if k~="Parent"then
						pcall(function()obj[k]=v end)
					end
				end
				stats.props+=1
			end
		end
	end

	pcall(function()t.on=false end)
	pcall(function()t.saved={} end)
	pcall(function()t.count=0 end)
	pcall(function()t.removed=0 end)
	stats.gcTables+=1
	return true
end

local function getUp(fn,i)
	if debug and debug.getupvalue then
		return debug.getupvalue(fn,i)
	end
	if debug and debug.getupvalues then
		local ups=debug.getupvalues(fn)
		if ups then return tostring(i),ups[i]end
	end
	return nil,nil
end

local function setUp(fn,i,val)
	if debug and debug.setupvalue then
		return pcall(debug.setupvalue,fn,i,val)
	end
	return false
end

local function killRockBugGc()
	if type(getgc)~="function"then return end
	local ok,gc=pcall(getgc,true)
	if not ok or type(gc)~="table"then return end

	for _,obj in ipairs(gc)do
		if type(obj)=="table"then
			pcall(function()
				restoreLowStateTable(obj)
			end)
		elseif type(obj)=="function"then
			local touched=false
			for i=1,40 do
				local name,val=getUp(obj,i)
				if not name then break end
				name=tostring(name)

				if name=="lowMapState" and type(val)=="table"then
					restoreLowStateTable(val)
					touched=true
				elseif name=="hitting" or name=="ultraOptEnabled" or name=="fastHitEnabled" then
					setUp(obj,i,false)
					touched=true
				elseif name=="lockCF" then
					setUp(obj,i,nil)
					touched=true
				elseif name=="hitLoopId" or name=="loopId" then
					if type(val)=="number"then setUp(obj,i,val+9999)end
					touched=true
				elseif name=="lockConn" or name=="hitConn" or name=="animSpeedConn" or name=="bugTimerConn" then
					tryDisconnect(val)
					setUp(obj,i,nil)
					touched=true
				end
			end
			if touched then stats.gcFuncs+=1 end
		end
	end
end

local function killRockBugConnections()
	if type(getconnections)~="function"then return end

	local signals={}
	pcall(function()table.insert(signals,RunService.Heartbeat)end)
	pcall(function()table.insert(signals,RunService.RenderStepped)end)
	pcall(function()table.insert(signals,RunService.Stepped)end)

	for _,sig in ipairs(signals)do
		local ok,cons=pcall(getconnections,sig)
		if ok and type(cons)=="table"then
			for _,cn in ipairs(cons)do
				local fn=nil
				pcall(function()fn=cn.Function end)
				if type(fn)=="function"then
					local rock=false
					for i=1,35 do
						local name,val=getUp(fn,i)
						if not name then break end
						name=tostring(name)
						if name=="lockCF" or name=="hitting" or name=="lowMapState" or name=="hitLoopId" or name=="ultraOptEnabled" or name=="bugTimerStartedAt"then
							rock=true
							break
						end
					end
					if rock then
						pcall(function()cn:Disable()end)
						pcall(function()cn:Disconnect()end)
						stats.conns+=1
					end
				end
			end
		end
	end
end

local function destroyBadGuis()
	local roots={}
	pcall(function()table.insert(roots,lp:FindFirstChild("PlayerGui"))end)
	pcall(function()table.insert(roots,getUiParent())end)
	pcall(function()table.insert(roots,CoreGui)end)

	local seen={}
	for _,root in ipairs(roots)do
		if root and not seen[root]then
			seen[root]=true
			for _,obj in ipairs(root:GetDescendants())do
				local n=tostring(obj.Name)
				if n:find("RockBugHub",1,true)
					or n:find("BLACK_OPT_BACKGROUND",1,true)
					or n:find("RebirthAnimKiller",1,true)
					or n:find("RebirthCDTryRemove",1,true)
				then
					if n~="RockBugEmergencyResetGui"then
						pcall(function()obj:Destroy()end)
						stats.gui+=1
					end
				end
			end
		end
	end
end

local function restoreWorkspaceVisuals()
	local terrain=workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		pcall(function()terrain.Decoration=true stats.props+=1 end)
		pcall(function()terrain.WaterWaveSize=0.15 end)
		pcall(function()terrain.WaterWaveSpeed=10 end)
		pcall(function()terrain.WaterReflectance=1 end)
		pcall(function()terrain.WaterTransparency=0.3 end)
	end

	local n=0
	for _,obj in ipairs(workspace:GetDescendants())do
		if obj:IsA("BasePart")then
			pcall(function()
				obj.LocalTransparencyModifier=0
				obj.CastShadow=true
				stats.props+=1
			end)
		elseif obj:IsA("Decal") or obj:IsA("Texture")then
			pcall(function()
				obj.Transparency=0
				stats.props+=1
			end)
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles")then
			pcall(function()
				obj.Enabled=true
				stats.props+=1
			end)
		elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")then
			pcall(function()
				obj.Enabled=true
				stats.props+=1
			end)
		elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("Highlight")then
			pcall(function()
				obj.Enabled=true
				stats.props+=1
			end)
		end

		n+=1
		if n%600==0 then task.wait()end
	end

	for _,obj in ipairs(Lighting:GetDescendants())do
		if obj:IsA("PostEffect")then
			pcall(function()
				obj.Enabled=true
				stats.props+=1
			end)
		end
	end
end

local function resetCharacter(pushUp)
	local c=lp.Character
	if not c then return end
	local hum=c:FindFirstChildWhichIsA("Humanoid")
	local root=c:FindFirstChild("HumanoidRootPart")

	if hum then
		pcall(function()
			hum.PlatformStand=false
			hum.Sit=false
			hum.AutoRotate=true
			if hum.WalkSpeed<8 then hum.WalkSpeed=16 end
			if hum.UseJumpPower and hum.JumpPower<20 then hum.JumpPower=50 end
			if not hum.UseJumpPower and hum.JumpHeight<4 then hum.JumpHeight=7.2 end
			hum:ChangeState(Enum.HumanoidStateType.Running)
			stats.char+=1
		end)

		local animator=hum:FindFirstChildOfClass("Animator")
		if animator then
			for _,tr in ipairs(animator:GetPlayingAnimationTracks())do
				pcall(function()tr:AdjustSpeed(1)end)
			end
		end
	end

	if root then
		pcall(function()
			root.Anchored=false
			root.AssemblyLinearVelocity=Vector3.new()
			root.AssemblyAngularVelocity=Vector3.new()
			if pushUp then
				root.CFrame=root.CFrame+Vector3.new(0,10,0)
			end
			stats.char+=1
		end)
	end
end

local rescueConn=nil
local rescueEnd=0
local rescueCF=nil

local function startRescue(seconds)
	if rescueConn then rescueConn:Disconnect() rescueConn=nil end
	local root=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if root then
		rescueCF=root.CFrame+Vector3.new(0,14,0)
	else
		rescueCF=nil
	end
	rescueEnd=os.clock()+(seconds or 20)

	rescueConn=RunService.Heartbeat:Connect(function()
		if os.clock()>rescueEnd then
			if rescueConn then rescueConn:Disconnect() rescueConn=nil end
			return
		end

		resetCharacter(false)
		local c=lp.Character
		local r=c and c:FindFirstChild("HumanoidRootPart")
		if r and rescueCF then
			pcall(function()
				r.Anchored=false
				r.CFrame=rescueCF
				r.AssemblyLinearVelocity=Vector3.new()
				r.AssemblyAngularVelocity=Vector3.new()
			end)
		end
	end)
end

local function stopRescue()
	if rescueConn then rescueConn:Disconnect() rescueConn=nil end
	rescueCF=nil
end

local function clearGlobals()
	for _,k in ipairs({
		"RockBugRemoteDelay","RockBugRemoteLoops","RockBugActivateDelay","RockBugTouchDelay","RockBugHitDelay",
		"RockBugAnimSpeed","RockBugAnimSpeedOverride","RockBugAnimBoostAll","RockBugAnimEveryTrack",
		"RockBugV19NoForceSpeed"
	})do
		pcall(function()_G[k]=nil end)
	end
end

local function emergencyReset()
	say("reset...")
	clearGlobals()
	restoreLightingPlayable()
	killRockBugGc()
	killRockBugConnections()
	destroyBadGuis()
	restoreWorkspaceVisuals()
	resetCharacter(true)
	startRescue(25)
	say("done")
end

-- UI
pcall(function()
	local root=getUiParent()
	local old=root:FindFirstChild("RockBugEmergencyResetGui")
	if old then old:Destroy()end
end)

local uiParent=getUiParent()
local gui=Instance.new("ScreenGui")
gui.Name="RockBugEmergencyResetGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=9999999
gui.Parent=uiParent

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,292,0,164)
main.Position=UDim2.new(0,18,0,120)
main.BackgroundColor3=Color3.fromRGB(12,12,16)
main.BackgroundTransparency=0.05
main.BorderSizePixel=0
main.Active=true
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)
local stroke=Instance.new("UIStroke",main)
stroke.Color=Color3.fromRGB(255,95,95)
stroke.Thickness=1.4
stroke.Transparency=0.12

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-46,0,24)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="EMERGENCY RESET"
title.TextColor3=Color3.fromRGB(255,240,240)
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
status.Size=UDim2.new(1,-24,0,44)
status.Position=UDim2.new(0,12,0,36)
status.BackgroundTransparency=1
status.TextColor3=Color3.fromRGB(215,220,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left

local function makeBtn(text,x,y,w,h)
	local b=Instance.new("TextButton")
	b.Parent=main
	b.Size=UDim2.new(0,w,0,h)
	b.Position=UDim2.new(0,x,0,y)
	b.BackgroundColor3=Color3.fromRGB(45,48,66)
	b.Text=text
	b.TextColor3=Color3.fromRGB(245,245,255)
	b.Font=Enum.Font.GothamBlack
	b.TextSize=11
	b.BorderSizePixel=0
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

local resetBtn=makeBtn("RESET AGAIN",12,86,128,34)
local freeBtn=makeBtn("FREE 25s",152,86,128,34)
local stopBtn=makeBtn("STOP FREE",12,126,128,28)
local hideBtn=makeBtn("HIDE",152,126,128,28)

local function updateStatus()
	status.Text=("status: %s\nui:%s gcT:%s gcF:%s con:%s props:%s char:%s render:%s"):format(
		stats.last,
		tostring(stats.gui),
		tostring(stats.gcTables),
		tostring(stats.gcFuncs),
		tostring(stats.conns),
		tostring(stats.props),
		tostring(stats.char),
		tostring(stats.render)
	)
end

resetBtn.Activated:Connect(function()
	task.spawn(function()
		emergencyReset()
		updateStatus()
	end)
end)

freeBtn.Activated:Connect(function()
	startRescue(25)
	say("free 25s")
	updateStatus()
end)

stopBtn.Activated:Connect(function()
	stopRescue()
	say("free stopped")
	updateStatus()
end)

hideBtn.Activated:Connect(function()
	main.Visible=false
end)

close.Activated:Connect(function()
	stopRescue()
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

task.spawn(function()
	emergencyReset()
	updateStatus()
end)
