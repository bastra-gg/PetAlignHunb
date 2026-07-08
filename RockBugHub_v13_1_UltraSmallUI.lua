-- RebirthCD_TryRemove_v1
-- Окно + одна кнопка ON/OFF. Пытается снять ЛОКАЛЬНЫЙ cooldown/debounce ребирта.
-- Если КД серверный — скрипт не сможет убрать его, но будет чистить всё, что есть на клиенте.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")

local lp=Players.LocalPlayer
local VERSION="RebirthCD_TryRemove_v1"

pcall(function()
	local old=lp:WaitForChild("PlayerGui"):FindFirstChild("RebirthCDTryRemoveGui")
	if old then old:Destroy()end
end)

local enabled=false
local loopId=0
local stats={
	values=0,
	attrs=0,
	tables=0,
	upvalues=0,
	scans=0,
	last=""
}

local KEYWORDS={
	"cooldown","cool_down","cd","debounce","delay","timer",
	"lastrebirth","last_rebirth","rebirthcooldown","rebirth_cd",
	"canrebirth","can_rebirth","rebirthdebounce","rebirth_debounce"
}

local function lower(s)
	return tostring(s or ""):lower()
end

local function matchKey(s)
	s=lower(s)
	for _,k in ipairs(KEYWORDS)do
		if s:find(k,1,true)then return true end
	end
	return false
end

local function shouldZeroByName(name)
	name=lower(name)
	if not matchKey(name)then return false end
	if name:find("damage",1,true) or name:find("strength",1,true) or name:find("muscle",1,true)then
		return false
	end
	return true
end

local function patchValueObject(obj)
	local n=obj.Name
	if not shouldZeroByName(n)then return false end

	local ok=false
	if obj:IsA("BoolValue")then
		pcall(function()obj.Value=false ok=true end)
	elseif obj:IsA("IntValue")or obj:IsA("NumberValue")then
		pcall(function()obj.Value=0 ok=true end)
	elseif obj:IsA("StringValue")then
		pcall(function()obj.Value="0" ok=true end)
	end

	if ok then stats.values+=1 end
	return ok
end

local function patchAttributes(obj)
	local ok=false
	pcall(function()
		for k,v in pairs(obj:GetAttributes())do
			if shouldZeroByName(k)then
				if typeof(v)=="boolean"then
					obj:SetAttribute(k,false)
					ok=true
				elseif typeof(v)=="number"then
					obj:SetAttribute(k,0)
					ok=true
				elseif typeof(v)=="string"then
					obj:SetAttribute(k,"0")
					ok=true
				end
			end
		end
	end)
	if ok then stats.attrs+=1 end
	return ok
end

local function scanInstances()
	local roots={
		lp,
		lp:FindFirstChild("PlayerGui"),
		lp:FindFirstChild("Backpack"),
		lp.Character,
		ReplicatedStorage,
	}

	for _,root in ipairs(roots)do
		if root then
			patchAttributes(root)
			for _,obj in ipairs(root:GetDescendants())do
				patchValueObject(obj)
				patchAttributes(obj)
			end
		end
	end
end

local function patchTable(t)
	local changed=false

	for k,v in pairs(t)do
		local key=lower(k)
		if shouldZeroByName(key)then
			if type(v)=="boolean"then
				pcall(function()t[k]=false changed=true end)
			elseif type(v)=="number"then
				pcall(function()t[k]=0 changed=true end)
			elseif type(v)=="string"then
				pcall(function()t[k]="0" changed=true end)
			end
		end
	end

	if changed then stats.tables+=1 end
end

local function patchGcTables()
	if type(getgc)~="function"then return end

	local ok,gc=pcall(getgc,true)
	if not ok or type(gc)~="table"then return end

	local checked=0
	for _,obj in ipairs(gc)do
		checked+=1
		if checked>4500 then break end

		if type(obj)=="table"then
			pcall(function()patchTable(obj)end)
		end
	end
end

local function getUpvalueCompat(fn,i)
	if debug and debug.getupvalue then
		return debug.getupvalue(fn,i)
	end
	if debug and debug.getupvalues then
		local ups=debug.getupvalues(fn)
		if ups then
			local v=ups[i]
			return tostring(i),v
		end
	end
	return nil,nil
end

local function setUpvalueCompat(fn,i,val)
	if debug and debug.setupvalue then
		return pcall(debug.setupvalue,fn,i,val)
	end
	return false
end

local function patchGcUpvalues()
	if type(getgc)~="function"then return end
	if not debug then return end

	local ok,gc=pcall(getgc,true)
	if not ok or type(gc)~="table"then return end

	local checked=0
	for _,obj in ipairs(gc)do
		checked+=1
		if checked>4500 then break end

		if type(obj)=="function"then
			for i=1,24 do
				local name,val=getUpvalueCompat(obj,i)
				if not name then break end

				if shouldZeroByName(name)then
					if type(val)=="boolean"then
						local okSet=setUpvalueCompat(obj,i,false)
						if okSet then stats.upvalues+=1 end
					elseif type(val)=="number"then
						local okSet=setUpvalueCompat(obj,i,0)
						if okSet then stats.upvalues+=1 end
					elseif type(val)=="table"then
						pcall(function()patchTable(val)end)
					end
				end
			end
		end
	end
end

local function onePass()
	stats.values=0
	stats.attrs=0
	stats.tables=0
	stats.upvalues=0
	stats.scans+=1

	scanInstances()
	patchGcTables()
	patchGcUpvalues()

	stats.last=os.date("%H:%M:%S")
end

-- UI
local gui=Instance.new("ScreenGui")
gui.Name="RebirthCDTryRemoveGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=999999
gui.Parent=lp:WaitForChild("PlayerGui")

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,250,0,120)
main.Position=UDim2.new(0,18,0,110)
main.BackgroundColor3=Color3.fromRGB(10,11,22)
main.BackgroundTransparency=0.08
main.BorderSizePixel=0
main.Active=true

local c=Instance.new("UICorner",main)
c.CornerRadius=UDim.new(0,16)

local st=Instance.new("UIStroke",main)
st.Color=Color3.fromRGB(130,95,255)
st.Thickness=1.2
st.Transparency=0.18

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-20,0,22)
title.Position=UDim2.new(0,10,0,8)
title.BackgroundTransparency=1
title.Text="REBIRTH CD TEST"
title.TextColor3=Color3.fromRGB(245,246,255)
title.Font=Enum.Font.GothamBlack
title.TextSize=14
title.TextXAlignment=Enum.TextXAlignment.Left

local ver=Instance.new("TextLabel")
ver.Parent=main
ver.Size=UDim2.new(1,-20,0,16)
ver.Position=UDim2.new(0,10,0,29)
ver.BackgroundTransparency=1
ver.Text=VERSION
ver.TextColor3=Color3.fromRGB(155,165,205)
ver.Font=Enum.Font.GothamBold
ver.TextSize=9
ver.TextXAlignment=Enum.TextXAlignment.Left

local btn=Instance.new("TextButton")
btn.Parent=main
btn.Size=UDim2.new(1,-20,0,42)
btn.Position=UDim2.new(0,10,0,50)
btn.BackgroundColor3=Color3.fromRGB(38,125,72)
btn.Text="CD REMOVE: OFF"
btn.TextColor3=Color3.fromRGB(255,255,255)
btn.Font=Enum.Font.GothamBlack
btn.TextSize=13
btn.BorderSizePixel=0

local bc=Instance.new("UICorner",btn)
bc.CornerRadius=UDim.new(0,13)

local status=Instance.new("TextLabel")
status.Parent=main
status.Size=UDim2.new(1,-20,0,20)
status.Position=UDim2.new(0,10,0,96)
status.BackgroundTransparency=1
status.Text="готово"
status.TextColor3=Color3.fromRGB(210,218,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextXAlignment=Enum.TextXAlignment.Center

local function updateUi()
	btn.Text=enabled and "CD REMOVE: ON" or "CD REMOVE: OFF"
	btn.BackgroundColor3=enabled and Color3.fromRGB(130,50,160) or Color3.fromRGB(38,125,72)

	if enabled then
		status.Text=("clean %s | v%s a%s t%s u%s"):format(
			stats.last,
			tostring(stats.values),
			tostring(stats.attrs),
			tostring(stats.tables),
			tostring(stats.upvalues)
		)
	else
		status.Text="выключено"
	end
end

btn.Activated:Connect(function()
	enabled=not enabled
	loopId+=1
	local my=loopId

	if enabled then
		onePass()
		updateUi()

		task.spawn(function()
			while enabled and my==loopId do
				onePass()
				updateUi()
				task.wait(_G.RebirthCDCleanDelay or 0.35)
			end
		end)
	else
		updateUi()
	end
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

updateUi()
