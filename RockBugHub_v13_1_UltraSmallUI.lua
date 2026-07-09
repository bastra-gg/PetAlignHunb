-- RockBug_ForceCloseOld_v1
-- Без окна. Прямо жмёт кнопки старого RockBugHub: STOP / UNLOCK / BLACK OFF / X.
-- Потом добивает GUI и возвращает базовый рендер/персонажа. Без kick/rejoin.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local VirtualUser=game:GetService("VirtualUser")

local lp=Players.LocalPlayer

pcall(function()
	lp.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
end)

local function safe(fn)
	pcall(fn)
end

local function clickButton(btn)
	if not btn or not btn:IsA("TextButton") then return end

	-- Самое важное: это вызывает старые обработчики старого скрипта,
	-- а не просто Destroy GUI. Так он сам сделает stopHit / stopLock / setLowMap(false).
	safe(function() btn:Activate() end)
	safe(function()
		if firesignal then firesignal(btn.Activated) end
	end)
	safe(function()
		if firesignal then firesignal(btn.MouseButton1Click) end
	end)
end

local function isRockBugGui(obj)
	if not obj then return false end
	local n=tostring(obj.Name)
	if n:find("RockBugHub",1,true) then return true end
	if n:find("RockBug",1,true) and n:find("Hub",1,true) then return true end

	for _,d in ipairs(obj:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local t=tostring(d.Text)
			if t:find("RockBugHub",1,true)
				or t:find("BUG v20",1,true)
				or t:find("BUG v21",1,true)
				or t:find("BUG v22",1,true)
				or t:find("FAST ANIM",1,true)
				or t:find("ULTRA BLACK",1,true)
			then
				return true
			end
		end
	end

	return false
end

local function getRoots()
	local roots={}
	safe(function() table.insert(roots, lp:FindFirstChild("PlayerGui")) end)
	safe(function()
		if type(gethui)=="function" then table.insert(roots, gethui()) end
	end)
	safe(function() table.insert(roots, game:GetService("CoreGui")) end)
	return roots
end

local function restoreRender()
	safe(function()
		RunService:Set3dRenderingEnabled(true)
	end)

	safe(function()
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
		safe(function() Lighting.ExposureCompensation=0 end)
	end)

	safe(function()
		UserSettings():GetService("UserGameSettings").SavedQualityLevel=Enum.SavedQualitySetting.Automatic
	end)

	safe(function()
		settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic
	end)
end

local function restoreBody(push)
	local c=lp.Character
	if not c then return end

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

		local animator=hum:FindFirstChildOfClass("Animator")
		if animator then
			for _,tr in ipairs(animator:GetPlayingAnimationTracks())do
				safe(function() tr:AdjustSpeed(1) end)
			end
		end
	end

	if root then
		safe(function()
			root.Anchored=false
			root.AssemblyLinearVelocity=Vector3.new()
			root.AssemblyAngularVelocity=Vector3.new()
			if push then
				root.CFrame=root.CFrame+Vector3.new(0,22,0)
			end
		end)
	end
end

local function visualRestoreLite()
	local terrain=workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		safe(function() terrain.Decoration=true end)
		safe(function() terrain.WaterTransparency=0.3 end)
		safe(function() terrain.WaterReflectance=1 end)
	end

	local n=0
	for _,obj in ipairs(workspace:GetDescendants())do
		if obj:IsA("BasePart")then
			safe(function()
				obj.LocalTransparencyModifier=0
				obj.CastShadow=true
			end)
		elseif obj:IsA("Decal") or obj:IsA("Texture")then
			safe(function()
				if obj.Transparency>=0.9 then obj.Transparency=0 end
			end)
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles")then
			safe(function() obj.Enabled=true end)
		elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
			safe(function() obj.Enabled=true end)
		elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("Highlight")then
			safe(function() obj.Enabled=true end)
		end

		n+=1
		if n%800==0 then task.wait() end
	end

	for _,obj in ipairs(Lighting:GetDescendants())do
		if obj:IsA("PostEffect")then
			safe(function() obj.Enabled=true end)
		end
	end
end

local function getUp(fn,i)
	if debug and debug.getupvalue then
		return debug.getupvalue(fn,i)
	end
	if debug and debug.getupvalues then
		local ups=debug.getupvalues(fn)
		if ups then return tostring(i), ups[i] end
	end
	return nil,nil
end

local function setUp(fn,i,v)
	if debug and debug.setupvalue then
		pcall(debug.setupvalue,fn,i,v)
	end
end

local function restoreLowState(t)
	if type(t)~="table" then return end
	if type(t.saved)=="table" then
		for obj,rec in pairs(t.saved)do
			if typeof(obj)=="Instance" and type(rec)=="table"then
				if rec.Parent~=nil then safe(function() obj.Parent=rec.Parent end) end
				for k,v in pairs(rec)do
					if k~="Parent" then safe(function() obj[k]=v end) end
				end
			end
		end
	end
	if type(t.lighting)=="table" then
		for k,v in pairs(t.lighting)do
			safe(function() Lighting[k]=v end)
		end
	end
	safe(function() t.on=false end)
	safe(function() t.saved={} end)
	safe(function() t.lighting={} end)
	safe(function() t.settings={} end)
	safe(function() t.count=0 end)
	safe(function() t.removed=0 end)
end

local function patchOldClosures()
	if type(getgc)~="function" then return end

	local ok,gc=pcall(getgc,true)
	if not ok or type(gc)~="table" then return end

	for _,obj in ipairs(gc)do
		if type(obj)=="table"then
			safe(function()
				if obj.saved or obj.lighting or obj.settings then
					restoreLowState(obj)
				end
			end)
		elseif type(obj)=="function"then
			local rock=false

			for i=1,80 do
				local name,val=getUp(obj,i)
				if not name then break end
				name=tostring(name)
				if name=="HUB_VERSION" and tostring(val):find("RockBugHub",1,true)then rock=true end
				if name=="lowMapState" or name=="hitting" or name=="lockCF" or name=="hitLoopId" or name=="ultraOptEnabled"then rock=true end
			end

			if rock then
				for i=1,100 do
					local name,val=getUp(obj,i)
					if not name then break end
					name=tostring(name)

					if name=="hitting" or name=="ultraOptEnabled" or name=="fastHitEnabled" then
						setUp(obj,i,false)
					elseif name=="lockCF" then
						setUp(obj,i,nil)
					elseif name=="hitLoopId" and type(val)=="number"then
						setUp(obj,i,val+999999)
					elseif name=="lockConn" or name=="hitConn" or name=="animSpeedConn" or name=="bugTimerConn" then
						safe(function() if val then val:Disconnect() end end)
						setUp(obj,i,nil)
					elseif name=="lowMapState" and type(val)=="table"then
						restoreLowState(val)
					elseif name=="blackBg" and typeof(val)=="Instance"then
						safe(function() val.Visible=false end)
						safe(function() val:Destroy() end)
					end
				end
			end
		end
	end
end

local function pressOldGuiButtons()
	for _,root in ipairs(getRoots())do
		if root then
			for _,gui in ipairs(root:GetChildren())do
				if isRockBugGui(gui)then
					-- Порядок важен:
					-- 1) STOP: stopHit + setLowMap(false)
					-- 2) UNLOCK: stopLock
					-- 3) BLACK/ULTRA: если включено, выключит
					-- 4) X: штатное закрытие
					local buttons={}
					for _,d in ipairs(gui:GetDescendants())do
						if d:IsA("TextButton")then
							table.insert(buttons,d)
						end
					end

					local function pressTexts(list)
						for _,want in ipairs(list)do
							for _,b in ipairs(buttons)do
								local txt=tostring(b.Text)
								if txt:upper():find(want,1,true)then
									clickButton(b)
									task.wait(0.08)
								end
							end
						end
					end

					pressTexts({"STOP","UNLOCK","BLACK ON","ULTRA ON","ULTRA BLACK"})
					task.wait(0.15)
					pressTexts({"×","X"})

					task.wait(0.2)
				end
			end
		end
	end
end

local function destroyOldGuiLeftovers()
	for _,root in ipairs(getRoots())do
		if root then
			for _,gui in ipairs(root:GetChildren())do
				if isRockBugGui(gui)then
					safe(function() gui.Enabled=false end)
					safe(function() gui:Destroy() end)
				end
			end
			for _,d in ipairs(root:GetDescendants())do
				local n=tostring(d.Name)
				if n=="BLACK_OPT_BACKGROUND" or n:find("RockBugHub",1,true) then
					safe(function() d:Destroy() end)
				end
			end
		end
	end
end

local function cleanup()
	restoreRender()

	-- Жмём старые кнопки несколько раз, чтобы сработали штатные обработчики старого хаба.
	for _=1,4 do
		pressOldGuiButtons()
		restoreBody(true)
		task.wait(0.12)
	end

	patchOldClosures()
	destroyOldGuiLeftovers()
	restoreRender()
	visualRestoreLite()
	restoreBody(true)

	-- 15 секунд перебиваем старый lock, если он ещё жив.
	local endAt=os.clock()+15
	local safeCF=nil
	local r=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if r then safeCF=r.CFrame+Vector3.new(0,18,0)end

	while os.clock()<endAt do
		restoreBody(false)
		local root=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if root and safeCF then
			safe(function()
				root.Anchored=false
				root.CFrame=safeCF
				root.AssemblyLinearVelocity=Vector3.new()
				root.AssemblyAngularVelocity=Vector3.new()
			end)
		end
		RunService.Heartbeat:Wait()
	end
end

task.spawn(cleanup)
