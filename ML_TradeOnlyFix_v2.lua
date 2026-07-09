-- ML_FULL_RECOVERY_v1
-- Максимальный recovery без rejoin/kick.
-- Делает все мягкие восстановления разом, но по шагам и с STOP, чтобы не убить FPS.
-- НЕ FireServer/InvokeServer. НЕ авто-трейд. НЕ чёрный экран. НЕ Heartbeat-цикл.

local Players=game:GetService("Players")
local StarterGui=game:GetService("StarterGui")
local ReplicatedFirst=game:GetService("ReplicatedFirst")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")
local Lighting=game:GetService("Lighting")
local Stats=game:GetService("Stats")

local lp=Players.LocalPlayer
local VERSION="ML_FULL_RECOVERY_v1"

local running=false
local runId=0
local lastReport="Нажми FULL RECOVERY. Если не помогло — COPY REPORT."
local hidden={}
local createdFloor=nil

local TARGET_BUTTON_PATHS={
	"gameGui/sideButtons/tradeButton",
	"gameGui/gameGuiScript/playerTradeFrame/nameLabel/tradeButton",
	"gameGui/gameGuiScript/tradeRequestMenu/tradeButton",
	"gameGui/tradePanel/acceptButton",
	"gameGui/tradePanel/declineButton",
	"gameGui/tradePanel/sideButtons/petsButton",
}

local BAD_GUI_NAMES={
	"BLACK_OPT_BACKGROUND",
	"RockBugHub",
	"EmergencyReset",
	"HardPanicReset",
	"ForceCloseOld",
	"RestoreGameButtons",
	"TradeOnlyFix",
	"TradeRescue",
	"ServerResync",
	"GameGuiRelink",
	"UIScriptsHardRestart",
	"ML_TradeAnalyzerGui",
	"ML_TradeDirectGui",
	"ML_ServerResyncGui",
	"ML_GameGuiRelinkGui",
	"ML_UIScriptsHardRestartGui",
}

local POPUP_GUIS={
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

local LOADING_WORDS={
	"loading","load","загрузка","intro","fade","black","transition","teleport","blocker","input","cover","wait","splash","start"
}

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

	while cur and cur~=game and n<28 do
		table.insert(parts,1,tostring(cur.Name))
		cur=cur.Parent
		n+=1
	end

	return table.concat(parts,"/")
end

local function low(s)
	return tostring(s or ""):lower()
end

local function hasWord(s,words)
	s=low(s)
	for _,w in ipairs(words) do
		if s:find(low(w),1,true) then return true end
	end
	return false
end

local function setStatus(t)
	if _G.MLFullRecoveryStatus then
		_G.MLFullRecoveryStatus.Text=tostring(t)
	end
end

local function setButton()
	if _G.MLFullRecoveryButton then
		_G.MLFullRecoveryButton.Text=running and "STOP" or "FULL RECOVERY"
		_G.MLFullRecoveryButton.BackgroundColor3=running and Color3.fromRGB(135,55,65) or Color3.fromRGB(45,130,75)
	end
end

local function cancelled(my)
	return (not running) or runId~=my
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

local function connCount(sig)
	if type(getconnections)~="function" or not sig then return -1,-1 end

	local ok,cons=pcall(getconnections,sig)
	if not ok or type(cons)~="table" then return -1,-1 end

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

local function buttonConnInfo(btn)
	if not btn or not btn:IsA("GuiButton") then return "not_button",0 end

	local total=0
	local chunks={}
	local signals={
		{"Activated",btn.Activated},
		{"MouseClick",btn.MouseButton1Click},
		{"MouseDown",btn.MouseButton1Down},
		{"MouseUp",btn.MouseButton1Up},
		{"TouchTap",btn.TouchTap},
	}

	for _,pair in ipairs(signals) do
		local e,t=connCount(pair[2])
		if e>=0 then
			total+=e
			chunks[#chunks+1]=pair[1].."="..e.."/"..t
		end
	end

	if #chunks==0 then return "no_getconnections",0 end
	return table.concat(chunks," "),total
end

local function totalTradeConnections()
	local known=false
	local total=0

	for _,p in ipairs(TARGET_BUTTON_PATHS) do
		local b=getPath(p)
		if b and b:IsA("GuiButton") then
			local _,n=buttonConnInfo(b)
			known=true
			total+=n
		end
	end

	return known,total
end

local function isBadGuiName(obj)
	local n=tostring(obj.Name)
	for _,bad in ipairs(BAD_GUI_NAMES) do
		if n==bad or n:find(bad,1,true) then return true end
	end
	return false
end

local function destroyOldFixes()
	local roots={pg(),getUiParent(),CoreGui}
	local seen={}
	local removed=0

	for _,root in ipairs(roots) do
		if root and not seen[root] then
			seen[root]=true

			for _,obj in ipairs(root:GetChildren()) do
				if obj.Name~="ML_FULL_RECOVERY_GUI" and isBadGuiName(obj) then
					safe(function() obj:Destroy() end)
					removed+=1
				end
			end

			for _,obj in ipairs(root:GetDescendants()) do
				if obj.Name~="ML_FULL_RECOVERY_GUI" and isBadGuiName(obj) then
					safe(function() obj:Destroy() end)
					removed+=1
				end
			end
		end
	end

	return removed
end

local function restoreRender()
	safe(function() RunService:Set3dRenderingEnabled(true) end)

	safe(function()
		Lighting.GlobalShadows=true
		Lighting.Brightness=2
		Lighting.FogEnd=100000
		Lighting.Ambient=Color3.fromRGB(120,120,120)
		Lighting.OutdoorAmbient=Color3.fromRGB(120,120,120)
		Lighting.ColorShift_Top=Color3.fromRGB(0,0,0)
		Lighting.ColorShift_Bottom=Color3.fromRGB(0,0,0)
		pcall(function() Lighting.ExposureCompensation=0 end)
	end)

	safe(function()
		settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic
	end)
end

local function restoreBody()
	local c=lp.Character
	if not c then return false end

	local hum=c:FindFirstChildWhichIsA("Humanoid")
	local root=c:FindFirstChild("HumanoidRootPart")
	local cam=workspace.CurrentCamera

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
			for _,tr in ipairs(animator:GetPlayingAnimationTracks()) do
				safe(function() tr:AdjustSpeed(1) end)
			end
		end
	end

	if root then
		safe(function()
			root.Anchored=false
			root.AssemblyLinearVelocity=Vector3.new()
			root.AssemblyAngularVelocity=Vector3.new()
		end)
	end

	if cam and hum then
		safe(function()
			cam.CameraType=Enum.CameraType.Custom
			cam.CameraSubject=hum
		end)
	end

	return true
end

local function restoreControls()
	safe(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true) end)
	safe(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

	safe(function()
		local ps=lp:FindFirstChild("PlayerScripts")
		local pm=ps and ps:FindFirstChild("PlayerModule")
		if pm then
			local mod=require(pm)
			local controls=mod:GetControls()
			if controls then controls:Enable() end
		end
	end)

	local p=pg()
	if p then
		local touch=p:FindFirstChild("TouchGui")
		if touch then
			safe(function() touch.Enabled=true end)
			for _,d in ipairs(touch:GetDescendants()) do
				if d:IsA("GuiObject") then
					safe(function()
						d.Visible=true
						d.Active=true
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
	end
end

local function makeTempFloor()
	local c=lp.Character
	local root=c and c:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	if createdFloor and createdFloor.Parent then
		createdFloor.CFrame=CFrame.new(root.Position.X,root.Position.Y-5,root.Position.Z)
		return true
	end

	local p=workspace:FindFirstChild("ML_FULL_RECOVERY_TEMP_FLOOR")
	if p and p:IsA("BasePart") then
		createdFloor=p
	else
		p=Instance.new("Part")
		p.Name="ML_FULL_RECOVERY_TEMP_FLOOR"
		p.Anchored=true
		p.CanCollide=true
		p.CanTouch=false
		p.CanQuery=false
		p.Size=Vector3.new(90,2,90)
		p.Material=Enum.Material.SmoothPlastic
		p.Color=Color3.fromRGB(60,255,120)
		p.Transparency=0.22
		p.Parent=workspace
		createdFloor=p
	end

	createdFloor.CFrame=CFrame.new(root.Position.X,root.Position.Y-5,root.Position.Z)
	return true
end

local function recoverLowMapState()
	local recovered=0

	local function restoreTable(t)
		if type(t)~="table" then return end

		if type(t.saved)=="table" then
			for obj,rec in pairs(t.saved) do
				if typeof(obj)=="Instance" and type(rec)=="table" then
					if rec.Parent~=nil then
						safe(function() obj.Parent=rec.Parent end)
					end
					for k,v in pairs(rec) do
						if k~="Parent" then
							safe(function() obj[k]=v end)
						end
					end
					recovered+=1
				end
			end
		end

		if type(t.lighting)=="table" then
			for k,v in pairs(t.lighting) do
				safe(function() Lighting[k]=v end)
			end
		end

		safe(function() t.on=false end)
		safe(function() t.saved={} end)
		safe(function() t.lighting={} end)
		safe(function() t.settings={} end)
	end

	if type(getgc)=="function" then
		local ok,gc=pcall(getgc,true)
		if ok and type(gc)=="table" then
			for _,obj in ipairs(gc) do
				if type(obj)=="table" then
					if obj.saved or obj.lighting or obj.settings then
						restoreTable(obj)
					end
				end
			end
		end
	end

	if type(getnilinstances)=="function" then
		local ok,nilobjs=pcall(getnilinstances)
		if ok and type(nilobjs)=="table" then
			local n=0
			for _,obj in ipairs(nilobjs) do
				n+=1
				if n>350 then break end

				if typeof(obj)=="Instance" and not obj.Parent then
					local should=false

					if obj:IsA("Model") or obj:IsA("Folder") then
						if obj:FindFirstChildWhichIsA("BasePart",true) then should=true end
					elseif obj:IsA("BasePart") then
						should=true
					end

					local name=tostring(obj.Name):lower()
					if should and not name:find("gui",1,true) and not name:find("player",1,true) then
						safe(function() obj.Parent=workspace end)
						recovered+=1
					end
				end
			end
		end
	end

	return recovered
end

local function restoreVisualsSmall()
	local n=0

	for _,obj in ipairs(workspace:GetDescendants()) do
		n+=1
		if n>4500 then break end

		if obj:IsA("BasePart") then
			safe(function()
				obj.LocalTransparencyModifier=0
				obj.CastShadow=true
			end)
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			safe(function()
				if obj.Transparency>=0.95 then obj.Transparency=0 end
			end)
		elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
			safe(function() obj.Enabled=true end)
		end

		if n%300==0 then task.wait() end
	end

	return n
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

local function hideLoadingBlockers()
	local p=pg()
	if not p then return 0 end

	local hiddenCount=0
	local scanned=0

	for _,rootName in ipairs({"gameGui","loadingGui","LoadingGui","transitionGui","fadeGui"}) do
		local root=p:FindFirstChild(rootName)
		if root then
			for _,d in ipairs(root:GetDescendants()) do
				scanned+=1
				if scanned>2200 then break end

				if d:IsA("GuiObject") then
					local n=tostring(d.Name)
					local visible=false
					local active=false
					local bg=1

					safe(function() visible=d.Visible end)
					safe(function() active=d.Active end)
					safe(function() bg=d.BackgroundTransparency end)

					if visible and areaOf(d)>0.35 and (active or bg<0.95) and hasWord(n,LOADING_WORDS) then
						if not hidden[d] then
							hidden[d]={Visible=d.Visible,Active=d.Active,BackgroundTransparency=d.BackgroundTransparency}
							safe(function()
								d.Visible=false
								d.Active=false
								d.BackgroundTransparency=1
							end)
							hiddenCount+=1
						end
					end
				end

				if scanned%180==0 then task.wait() end
			end
		end
	end

	return hiddenCount
end

local function hideKnownPopups()
	local p=pg()
	if not p then return 0 end

	local count=0
	for _,name in ipairs(POPUP_GUIS) do
		local g=p:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and not hidden[g] then
			hidden[g]={Enabled=g.Enabled}
			safe(function() g.Enabled=false end)
			count+=1
		end
	end

	return count
end

local function restoreHidden()
	for obj,rec in pairs(hidden) do
		if obj and obj.Parent then
			if rec.Enabled~=nil then safe(function() obj.Enabled=rec.Enabled end) end
			if rec.Visible~=nil then safe(function() obj.Visible=rec.Visible end) end
			if rec.Active~=nil then safe(function() obj.Active=rec.Active end) end
			if rec.BackgroundTransparency~=nil then safe(function() obj.BackgroundTransparency=rec.BackgroundTransparency end) end
		end
	end
	hidden={}
	setStatus("hidden restored")
end

local function bringTradeGui()
	local gameGui=getPath("gameGui")
	if gameGui and gameGui:IsA("ScreenGui") then
		safe(function()
			gameGui.Enabled=true
			gameGui.DisplayOrder=999900
			gameGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
		end)
	end

	for _,p in ipairs(TARGET_BUTTON_PATHS) do
		local b=getPath(p)
		if b and b:IsA("GuiObject") then
			safe(function()
				b.Visible=true
				b.Active=true
				b.ZIndex=math.max(b.ZIndex,900)
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

	local panel=getPath("gameGui/tradePanel")
	if panel and panel:IsA("GuiObject") then
		safe(function()
			panel.Visible=true
			panel.Active=true
			panel.ZIndex=math.max(panel.ZIndex,850)
		end)
	end
end

local function requestStream()
	local c=lp.Character
	local root=c and c:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local ok=safe(function()
		lp:RequestStreamAroundAsync(root.Position,4)
	end)

	local hum=c and c:FindFirstChildWhichIsA("Humanoid")
	if hum then
		safe(function()
			hum:Move(Vector3.new(0,0,-0.01),true)
			task.wait(0.05)
			hum:Move(Vector3.new(0,0,0),true)
			hum.Jump=true
		end)
	end

	return ok
end

local function setScript(scr,on)
	if not scr then return end
	safe(function() scr.Disabled=not on end)
	safe(function() scr.Enabled=on end)
end

local function scoreScript(scr)
	local p=pathOf(scr):lower()
	local s=0

	if p:find("playergui/gamegui/gamguiscript",1,true) or p:find("playergui/gamegui/gameguiscript",1,true) then s+=9999 end
	if p:find("playergui/gamegui",1,true) then s+=120 end
	if p:find("trade",1,true) then s+=100 end
	if p:find("pet",1,true) then s+=55 end
	if p:find("gui",1,true) then s+=35 end
	if p:find("menu",1,true) then s+=20 end
	if p:find("button",1,true) then s+=15 end
	if p:find("playergui",1,true) then s+=10 end

	if p:find("ml_",1,true) then s-=2000 end
	if p:find("floorrescue",1,true) then s-=2000 end
	if p:find("rockbug",1,true) then s-=2000 end
	if p:find("analyzer",1,true) then s-=2000 end
	if p:find("recovery",1,true) then s-=2000 end
	if p:find("resync",1,true) then s-=2000 end
	if p:find("relink",1,true) then s-=2000 end
	if p:find("restart",1,true) then s-=2000 end

	return s
end

local function collectScripts()
	local list={}
	local seen={}

	local exact=getPath("gameGui/gameGuiScript")
	if exact and exact:IsA("LocalScript") then
		table.insert(list,{script=exact,score=99999,path=pathOf(exact)})
		seen[exact]=true
	end

	for _,root in ipairs({pg(),lp:FindFirstChild("PlayerScripts")}) do
		if root then
			local scanned=0

			for _,d in ipairs(root:GetDescendants()) do
				scanned+=1
				if scanned>7500 then break end

				if d:IsA("LocalScript") and not seen[d] then
					local sc=scoreScript(d)
					if sc>0 then
						table.insert(list,{script=d,score=sc,path=pathOf(d)})
						seen[d]=true
					end
				end

				if scanned%300==0 then task.wait() end
			end
		end
	end

	table.sort(list,function(a,b) return a.score>b.score end)

	local cut={}
	for i,v in ipairs(list) do
		if i<=65 then cut[#cut+1]=v end
	end

	return cut
end

local function restartUIScripts(my)
	local restarted=0
	local fixed=false
	local scripts=collectScripts()

	for i,v in ipairs(scripts) do
		if cancelled(my) then break end

		setStatus(("restart script %s/%s: %s"):format(i,#scripts,tostring(v.script.Name)))
		setScript(v.script,false)
		task.wait(0.12)
		setScript(v.script,true)
		restarted+=1

		task.wait(0.35)
		basicUnlock()
		bringTradeGui()

		local known,total=totalTradeConnections()
		if known and total>0 then
			fixed=true
			break
		end
	end

	return restarted,fixed
end

local function cloneGameGuiScript()
	local gameGui=getPath("gameGui")
	local scr=getPath("gameGui/gameGuiScript")

	if not gameGui or not scr or not scr:IsA("LocalScript") then
		return false,"missing gameGui/gameGuiScript"
	end

	for _,d in ipairs(gameGui:GetChildren()) do
		if tostring(d.Name):find("ML_FULL_RECOVERY_CLONE",1,true) then
			safe(function()
				if d:IsA("LocalScript") then setScript(d,false) end
				d:Destroy()
			end)
		end
	end

	local ok,clone=safe(function()
		scr.Archivable=true
		return scr:Clone()
	end)

	if not ok or not clone then return false,"clone failed" end

	clone.Name="ML_FULL_RECOVERY_CLONE_gameGuiScript"
	setScript(clone,false)
	clone.Parent=gameGui
	task.wait(0.2)
	setScript(clone,true)
	task.wait(1.2)

	return true,"clone started"
end

local function nudgeBindableEvents()
	local p=pg()
	if not p then return 0 end

	local fired=0
	local names={"Loaded","Load","Ready","UIReady","ClientReady","Start","Open","Refresh","Update"}

	for _,d in ipairs(p:GetDescendants()) do
		if fired>=20 then break end

		if d:IsA("BindableEvent") and hasWord(d.Name,names) then
			safe(function()
				d:Fire()
				fired+=1
			end)
		elseif d:IsA("BindableFunction") and hasWord(d.Name,names) then
			safe(function()
				d:Invoke()
				fired+=1
			end)
		end
	end

	return fired
end

local function makeReport(extra)
	local lines={}
	local function add(s) lines[#lines+1]=s end

	add("=== ML FULL RECOVERY REPORT ===")
	add("version: "..VERSION)
	add("ping: "..getPing())
	add("PlayerGui: "..tostring(pg()~=nil))
	add("extra: "..tostring(extra or ""))
	add("hidden count: "..tostring((function()
		local n=0
		for _ in pairs(hidden) do n+=1 end
		return n
	end)()))
	add("")

	local known,total=totalTradeConnections()
	add("trade button total enabled connections: "..(known and tostring(total) or "unknown"))
	add("")

	for _,p in ipairs(TARGET_BUTTON_PATHS) do
		local b=getPath(p)
		if b then
			local vis,act,z="?","?","?"
			safe(function() vis=tostring(b.Visible) end)
			safe(function() act=tostring(b.Active) end)
			safe(function() z=tostring(b.ZIndex) end)
			local info,_=buttonConnInfo(b)
			add(p.." | "..b.ClassName.." | visible="..vis.." active="..act.." z="..z.." | "..info)
		else
			add(p.." | NOT FOUND")
		end
	end

	local scripts=collectScripts()
	add("")
	add("[top scripts]")
	for i,v in ipairs(scripts) do
		if i<=25 then
			local dis,en="?","?"
			safe(function() dis=tostring(v.script.Disabled) end)
			safe(function() en=tostring(v.script.Enabled) end)
			add(("[%02d] score=%s Disabled=%s Enabled=%s | %s"):format(i,tostring(v.score),dis,en,v.path))
		end
	end

	lastReport=table.concat(lines,"\n")
	return lastReport
end

local function fullRecovery(my)
	local summary={}
	local function step(name,fn)
		if cancelled(my) then return nil end
		setStatus(name)
		local ok,res=safe(fn)
		summary[#summary+1]=name.." => "..tostring(ok and res or "err")
		task.wait(0.18)
		return res
	end

	step("1/12 stop old fixes",destroyOldFixes)
	step("2/12 render/body/control",function()
		restoreRender()
		restoreControls()
		restoreBody()
		return "ok"
	end)
	step("3/12 floor + visuals",function()
		local f=makeTempFloor()
		local v=restoreVisualsSmall()
		return "floor="..tostring(f).." visual="..tostring(v)
	end)
	step("4/12 recover map/nil",recoverLowMapState)
	step("5/12 hide loading blockers",hideLoadingBlockers)
	step("6/12 hide popups",hideKnownPopups)
	step("7/12 bring trade gui",function()
		bringTradeGui()
		return "ok"
	end)
	step("8/12 request stream/server nudge",requestStream)
	step("9/12 bindable UI nudge",nudgeBindableEvents)

	if not cancelled(my) then
		local known,before=totalTradeConnections()
		summary[#summary+1]="before restart conns="..(known and tostring(before) or "unknown")
	end

	local restarted,fixed=step("10/12 restart UI scripts",function()
		local r,f=restartUIScripts(my)
		return "restarted="..tostring(r).." fixed="..tostring(f)
	end) or "",false

	if not cancelled(my) then
		local known,total=totalTradeConnections()
		if known and total==0 then
			step("11/12 clone gameGuiScript",cloneGameGuiScript)
		else
			summary[#summary+1]="11/12 clone skipped, conns="..tostring(total)
		end
	end

	step("12/12 final unlock/report",function()
		restoreRender()
		restoreControls()
		restoreBody()
		makeTempFloor()
		bringTradeGui()
		local rep=makeReport(table.concat(summary," | "))
		if _G.MLFullRecoveryBox then
			_G.MLFullRecoveryBox.Text=rep
		end
		return "done"
	end)

	if not cancelled(my) then
		running=false
		setButton()
		setStatus("done | пробуй трейд / COPY REPORT")
	end
end

-- UI
local parent=getUiParent()
pcall(function()
	local old=parent:FindFirstChild("ML_FULL_RECOVERY_GUI")
	if old then old:Destroy() end
end)

local gui=Instance.new("ScreenGui")
gui.Name="ML_FULL_RECOVERY_GUI"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=10000000
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=parent

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,340,0,214)
main.Position=UDim2.new(0,14,0,106)
main.BackgroundColor3=Color3.fromRGB(14,15,22)
main.BackgroundTransparency=0.04
main.BorderSizePixel=0
main.Active=true
main.ZIndex=1000
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)

local st=Instance.new("UIStroke",main)
st.Color=Color3.fromRGB(90,190,255)
st.Thickness=1.35
st.Transparency=0.08

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-48,0,24)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="FULL RECOVERY"
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
status.Position=UDim2.new(0,12,0,38)
status.BackgroundTransparency=1
status.Text="готово | FULL RECOVERY можно остановить той же кнопкой"
status.TextColor3=Color3.fromRGB(215,225,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left
status.ZIndex=1001
_G.MLFullRecoveryStatus=status

local function mk(text,x,y,w,h)
	local b=Instance.new("TextButton")
	b.Parent=main
	b.Size=UDim2.new(0,w,0,h)
	b.Position=UDim2.new(0,x,0,y)
	b.BackgroundColor3=Color3.fromRGB(45,52,74)
	b.Text=text
	b.TextColor3=Color3.fromRGB(250,250,255)
	b.Font=Enum.Font.GothamBlack
	b.TextSize=9
	b.BorderSizePixel=0
	b.ZIndex=1002
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

local fullBtn=mk("FULL RECOVERY",12,88,112,34)
local copyBtn=mk("COPY REPORT",132,88,102,34)
local restoreBtn=mk("RESTORE HIDDEN",242,88,86,34)
local floorBtn=mk("FLOOR",12,128,75,28)
local unlockBtn=mk("UNLOCK",94,128,75,28)
local reportBtn=mk("REPORT",176,128,75,28)
local closeBtn=mk("CLOSE",258,128,70,28)

local box=Instance.new("TextBox")
box.Parent=main
box.Size=UDim2.new(1,-24,0,44)
box.Position=UDim2.new(0,12,0,164)
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

_G.MLFullRecoveryButton=fullBtn
_G.MLFullRecoveryBox=box

fullBtn.Activated:Connect(function()
	if running then
		running=false
		runId+=1
		setButton()
		makeReport("stopped by user")
		box.Text=lastReport
		setStatus("stopped | COPY REPORT")
		return
	end

	running=true
	runId+=1
	setButton()
	box.Text="running..."
	task.spawn(fullRecovery,runId)
end)

copyBtn.Activated:Connect(function()
	local rep=makeReport("manual copy")
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

restoreBtn.Activated:Connect(function()
	restoreHidden()
	makeReport("restore hidden")
	box.Text=lastReport
end)

floorBtn.Activated:Connect(function()
	makeTempFloor()
	restoreBody()
	setStatus("floor/body restored")
end)

unlockBtn.Activated:Connect(function()
	restoreRender()
	restoreControls()
	restoreBody()
	bringTradeGui()
	setStatus("unlock/trade front done")
end)

reportBtn.Activated:Connect(function()
	makeReport("manual report")
	box.Text=lastReport
	setStatus("report refreshed")
end)

closeBtn.Activated:Connect(function()
	gui:Destroy()
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

setButton()
makeReport("loaded")
box.Text=lastReport
