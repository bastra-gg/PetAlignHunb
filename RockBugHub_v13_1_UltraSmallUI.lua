-- RockBug_HardPanicReset_v2
-- Специально под сломанный RockBugHub v20/v21 FastAnimBlack.
-- Без kick/rejoin. Агрессивно останавливает старые циклы, возвращает карту/рендер и вытаскивает из камня.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local VirtualUser=game:GetService("VirtualUser")
local CoreGui=game:GetService("CoreGui")
local UserInputService=game:GetService("UserInputService")

local lp=Players.LocalPlayer
local VERSION="RockBug_HardPanicReset_v2"

-- анти-afk, чтобы не кикнуло пока вытаскивает
pcall(function()
	lp.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
end)

local stats={
	gui=0,
	upv=0,
	low=0,
	con=0,
	prop=0,
	char=0,
	render=0,
	msg="start"
}

local function safe(fn)
	local ok,res=pcall(fn)
	return ok,res
end

local function uiParent()
	local ok,h=safe(function()
		if type(gethui)=="function"then return gethui()end
	end)
	if ok and h then return h end
	local ok2,cg=safe(function()return CoreGui end)
	if ok2 and cg then return cg end
	return lp:WaitForChild("PlayerGui")
end

local function disc(x)
	pcall(function()
		if x then x:Disconnect()end
	end)
end

local function sset(obj,k,v)
	pcall(function()
		if obj then obj[k]=v end
	end)
end

local function getUp(fn,i)
	if debug and debug.getupvalue then
		return debug.getupvalue(fn,i)
	end
	if debug and debug.getupvalues then
		local ups=debug.getupvalues(fn)
		if ups then return tostring(i),ups[i] end
	end
	return nil,nil
end

local function setUp(fn,i,v)
	if debug and debug.setupvalue then
		local ok=pcall(debug.setupvalue,fn,i,v)
		if ok then stats.upv+=1 end
		return ok
	end
	return false
end

local function restoreRender()
	pcall(function()
		RunService:Set3dRenderingEnabled(true)
		stats.render+=1
	end)

	pcall(function()
		Lighting.GlobalShadows=true
		Lighting.Brightness=2
		Lighting.FogEnd=100000
		Lighting.FogColor=Color3.fromRGB(192,192,192)
		Lighting.Ambient=Color3.fromRGB(120,120,120)
		Lighting.OutdoorAmbient=Color3.fromRGB(120,120,120)
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

local function restoreLowMapState(t)
	if type(t)~="table"then return false end

	local looksLike=false
	if type(t.saved)=="table"then looksLike=true end
	if type(t.lighting)=="table"then looksLike=true end
	if type(t.settings)=="table"then looksLike=true end
	if t.on~=nil and t.count~=nil and t.removed~=nil then looksLike=true end
	if not looksLike then return false end

	pcall(function()RunService:Set3dRenderingEnabled(true)end)

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
				-- Parent первым: это возвращает объекты, которые v20 сделал Parent=nil
				if rec.Parent~=nil then
					pcall(function()obj.Parent=rec.Parent end)
				end
				for k,v in pairs(rec)do
					if k~="Parent"then
						pcall(function()obj[k]=v end)
					end
				end
				stats.prop+=1
			end
		end
	end

	pcall(function()t.on=false end)
	pcall(function()t.saved={} end)
	pcall(function()t.lighting={} end)
	pcall(function()t.settings={} end)
	pcall(function()t.count=0 end)
	pcall(function()t.removed=0 end)

	stats.low+=1
	return true
end

local function patchRockFunction(fn)
	local touched=false
	local hasRock=false

	-- сначала понять, что функция от RockBug
	for i=1,60 do
		local name,val=getUp(fn,i)
		if not name then break end
		name=tostring(name)
		if name=="HUB_VERSION" and tostring(val):find("RockBugHub",1,true)then
			hasRock=true
		end
		if name=="lowMapState" or name=="lockCF" or name=="hitting" or name=="hitLoopId" or name=="ultraOptEnabled" then
			hasRock=true
		end
	end

	if not hasRock then return false end

	for i=1,80 do
		local name,val=getUp(fn,i)
		if not name then break end
		name=tostring(name)

		if name=="lowMapState" and type(val)=="table"then
			restoreLowMapState(val)
			touched=true

		elseif name=="hitting" or name=="ultraOptEnabled" or name=="fastHitEnabled" or name=="antiAfkEnabled" then
			setUp(fn,i,false)
			touched=true

		elseif name=="lockCF" then
			setUp(fn,i,nil)
			touched=true

		elseif name=="oldSpeed" then
			setUp(fn,i,nil)
			touched=true

		elseif name=="oldAuto" then
			setUp(fn,i,nil)
			touched=true

		elseif name=="hitLoopId" then
			if type(val)=="number"then setUp(fn,i,val+999999)end
			touched=true

		elseif name=="lockConn" or name=="hitConn" or name=="animSpeedConn" or name=="bugTimerConn" or name=="antiAfkConn" then
			disc(val)
			setUp(fn,i,nil)
			touched=true

		elseif name=="blackBg" and typeof(val)=="Instance"then
			pcall(function()val.Visible=false end)
			pcall(function()val:Destroy()end)
			touched=true
		end
	end

	return touched
end

local function killGetgc()
	if type(getgc)~="function"then return end

	local ok,gc=pcall(getgc,true)
	if not ok or type(gc)~="table"then return end

	for _,obj in ipairs(gc)do
		if type(obj)=="table"then
			pcall(function()
				restoreLowMapState(obj)
			end)
		elseif type(obj)=="function"then
			pcall(function()
				if patchRockFunction(obj)then stats.upv+=1 end
			end)
		end
	end
end

local function killConnections()
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
					for i=1,60 do
						local name,val=getUp(fn,i)
						if not name then break end
						name=tostring(name)
						if name=="lockCF" or name=="hitting" or name=="hitLoopId" or name=="lowMapState" or name=="ultraOptEnabled" or name=="HUB_VERSION"then
							rock=true
							break
						end
					end

					if rock then
						pcall(function()cn:Disable()end)
						pcall(function()cn:Disconnect()end)
						stats.con+=1
					end
				end
			end
		end
	end
end

local function nukeRockGuis()
	local roots={}
	pcall(function()table.insert(roots,lp:FindFirstChild("PlayerGui"))end)
	pcall(function()table.insert(roots,uiParent())end)
	pcall(function()table.insert(roots,CoreGui)end)

	local seen={}
	local function shouldKill(obj)
		local n=tostring(obj.Name)
		if n=="RockBugHardPanicResetGui"then return false end
		if n:find("RockBugHub",1,true)then return true end
		if n:find("BLACK_OPT_BACKGROUND",1,true)then return true end
		if n:find("BUG v20",1,true)then return true end
		if n:find("BUG v21",1,true)then return true end
		if n:find("BUG v22",1,true)then return true end
		return false
	end

	for _,root in ipairs(roots)do
		if root and not seen[root]then
			seen[root]=true

			-- ВАЖНО: убиваем и прямых детей тоже, не только Descendants.
			for _,obj in ipairs(root:GetChildren())do
				if shouldKill(obj)then
					pcall(function()obj:Destroy()end)
					stats.gui+=1
				end
			end

			for _,obj in ipairs(root:GetDescendants())do
				if shouldKill(obj)then
					pcall(function()obj:Destroy()end)
					stats.gui+=1
				end
			end
		end
	end
end

local function restoreVisualProps()
	local terrain=workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		pcall(function()terrain.Decoration=true stats.prop+=1 end)
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
				stats.prop+=1
			end)
		elseif obj:IsA("Decal") or obj:IsA("Texture")then
			pcall(function()
				if obj.Transparency>=0.95 then obj.Transparency=0 end
				stats.prop+=1
			end)
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles")then
			pcall(function()
				obj.Enabled=true
				stats.prop+=1
			end)
		elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")then
			pcall(function()
				obj.Enabled=true
				stats.prop+=1
			end)
		elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("Highlight")then
			pcall(function()
				obj.Enabled=true
				stats.prop+=1
			end)
		end

		n+=1
		if n%700==0 then task.wait()end
	end

	for _,obj in ipairs(Lighting:GetDescendants())do
		if obj:IsA("PostEffect")then
			pcall(function()
				obj.Enabled=true
				stats.prop+=1
			end)
		end
	end
end

local rescueConn=nil
local rescueEnd=0
local safeCF=nil

local function resetBody(push)
	local c=lp.Character
	if not c then return end
	local h=c:FindFirstChildWhichIsA("Humanoid")
	local r=c:FindFirstChild("HumanoidRootPart")

	if h then
		pcall(function()
			h.PlatformStand=false
			h.Sit=false
			h.AutoRotate=true
			if h.WalkSpeed<12 then h.WalkSpeed=16 end
			if h.UseJumpPower then
				if h.JumpPower<35 then h.JumpPower=50 end
			else
				if h.JumpHeight<5 then h.JumpHeight=7.2 end
			end
			h:ChangeState(Enum.HumanoidStateType.Running)
			stats.char+=1
		end)

		local animator=h:FindFirstChildOfClass("Animator")
		if animator then
			for _,tr in ipairs(animator:GetPlayingAnimationTracks())do
				pcall(function()tr:AdjustSpeed(1)end)
			end
		end
	end

	if r then
		pcall(function()
			r.Anchored=false
			r.AssemblyLinearVelocity=Vector3.new()
			r.AssemblyAngularVelocity=Vector3.new()
			if push then
				r.CFrame=r.CFrame+Vector3.new(0,18,0)
			end
			stats.char+=1
		end)
	end
end

local function startFree(seconds)
	if rescueConn then rescueConn:Disconnect() rescueConn=nil end

	local r=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if r then
		safeCF=r.CFrame+Vector3.new(0,22,0)
	else
		safeCF=nil
	end

	rescueEnd=os.clock()+(seconds or 30)

	rescueConn=RunService.Heartbeat:Connect(function()
		if os.clock()>rescueEnd then
			if rescueConn then rescueConn:Disconnect() rescueConn=nil end
			return
		end

		resetBody(false)

		local c=lp.Character
		local root=c and c:FindFirstChild("HumanoidRootPart")
		if root and safeCF then
			pcall(function()
				root.Anchored=false
				root.CFrame=safeCF
				root.AssemblyLinearVelocity=Vector3.new()
				root.AssemblyAngularVelocity=Vector3.new()
			end)
		end
	end)
end

local function stopFree()
	if rescueConn then rescueConn:Disconnect() rescueConn=nil end
	safeCF=nil
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

local function hardReset()
	stats.msg="reset..."
	clearGlobals()
	restoreRender()
	killGetgc()
	killConnections()
	nukeRockGuis()
	restoreVisualProps()
	resetBody(true)
	startFree(30)
	stats.msg="DONE"
end

-- UI
pcall(function()
	local root=uiParent()
	local old=root:FindFirstChild("RockBugHardPanicResetGui")
	if old then old:Destroy()end
end)

local gui=Instance.new("ScreenGui")
gui.Name="RockBugHardPanicResetGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=9999999
gui.Parent=uiParent()

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,304,0,170)
main.Position=UDim2.new(0,14,0,110)
main.BackgroundColor3=Color3.fromRGB(12,10,14)
main.BackgroundTransparency=0.04
main.BorderSizePixel=0
main.Active=true
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)
local st=Instance.new("UIStroke",main)
st.Color=Color3.fromRGB(255,80,80)
st.Thickness=1.5
st.Transparency=0.08

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-48,0,24)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="HARD PANIC RESET"
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
status.Size=UDim2.new(1,-24,0,48)
status.Position=UDim2.new(0,12,0,36)
status.BackgroundTransparency=1
status.TextColor3=Color3.fromRGB(220,226,250)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left

local function btn(text,x,y,w,h)
	local b=Instance.new("TextButton")
	b.Parent=main
	b.Size=UDim2.new(0,w,0,h)
	b.Position=UDim2.new(0,x,0,y)
	b.BackgroundColor3=Color3.fromRGB(48,48,66)
	b.Text=text
	b.TextColor3=Color3.fromRGB(250,250,255)
	b.Font=Enum.Font.GothamBlack
	b.TextSize=11
	b.BorderSizePixel=0
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

local resetBtn=btn("HARD RESET",12,90,132,34)
local freeBtn=btn("FREE 30s",160,90,132,34)
local visualBtn=btn("VISUAL ONLY",12,130,132,28)
local stopBtn=btn("STOP FREE",160,130,132,28)

local function upd()
	status.Text=("v2 | %s\nui:%s upv:%s low:%s con:%s prop:%s char:%s render:%s"):format(
		tostring(stats.msg),
		tostring(stats.gui),
		tostring(stats.upv),
		tostring(stats.low),
		tostring(stats.con),
		tostring(stats.prop),
		tostring(stats.char),
		tostring(stats.render)
	)
end

resetBtn.Activated:Connect(function()
	task.spawn(function()
		hardReset()
		upd()
	end)
end)

freeBtn.Activated:Connect(function()
	startFree(30)
	stats.msg="free 30s"
	upd()
end)

visualBtn.Activated:Connect(function()
	task.spawn(function()
		restoreRender()
		restoreVisualProps()
		stats.msg="visual done"
		upd()
	end)
end)

stopBtn.Activated:Connect(function()
	stopFree()
	stats.msg="free stopped"
	upd()
end)

close.Activated:Connect(function()
	stopFree()
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
	hardReset()
	upd()
end)
