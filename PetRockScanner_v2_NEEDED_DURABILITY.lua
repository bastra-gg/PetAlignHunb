-- PetRockScanner_v2_NEEDED_DURABILITY
-- Отдельный быстрый сканер настоящих камней Muscle Legends.
-- Ищет модели, где есть neededDurability + LeftHand/RightHand.
-- Основной PetAlignHub не трогает.

local Players=game:GetService("Players")
local lp=Players.LocalPlayer

local REQ_NAME={
	[0]="Tiny Island Rock",
	[10]="Punching Rock",
	[100]="Large Rock",
	[5000]="Golden Rock",
	[150000]="Frost Gym Rock",
	[400000]="Mythical Gym Rock / Mystic Rock",
	[750000]="Eternal Gym Rock / Inferno Rock",
	[1000000]="Legend Gym Rock / Legends Rock",
	[5000000]="Muscle King Gym Rock",
	[10000000]="Ancient Jungle Rock",
}

local lastRows={}
local lastReport=""
local cursor=0

local function root()
	local c=lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function pathOf(obj)
	local parts={}
	local p=obj
	local n=0
	while p and p~=game and n<16 do
		table.insert(parts,1,p.Name)
		p=p.Parent
		n+=1
	end
	return table.concat(parts,"/")
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

local function valOf(v)
	if not v then return nil end
	if v:IsA("IntValue")or v:IsA("NumberValue")then return tonumber(v.Value)end
	if v:IsA("StringValue")then return tonumber(v.Value)end
	local ok,res=pcall(function()return tonumber(v.Value)end)
	return ok and res or nil
end

local function rockModelFromNeeded(v)
	local p=v.Parent
	for _=1,5 do
		if not p or p==workspace then break end
		local lh=p:FindFirstChild("LeftHand",true)
		local rh=p:FindFirstChild("RightHand",true)
		if lh and rh then return p,lh,rh end
		p=p.Parent
	end
	return v.Parent,nil,nil
end

local function scan()
	local rows={}
	local seen={}
	local hrp=root()

	for _,v in ipairs(workspace:GetDescendants())do
		if v.Name=="neededDurability" then
			local req=valOf(v)
			if req then
				local model,lh,rh=rockModelFromNeeded(v)
				local key=model or v.Parent
				if key and not seen[key]then
					seen[key]=true

					local part=lh or rh or biggestPart(key)
					if part and part:IsA("BasePart")then
						local dist=hrp and (part.Position-hrp.Position).Magnitude or 0
						table.insert(rows,{
							req=req,
							name=REQ_NAME[req] or ("Unknown req "..tostring(req)),
							model=key,
							part=part,
							left=lh,
							right=rh,
							dist=dist,
						})
					end
				end
			end
		end
	end

	table.sort(rows,function(a,b)
		if a.req~=b.req then return a.req<b.req end
		return a.dist<b.dist
	end)

	return rows
end

local function makeReport(rows)
	local lines={}
	table.insert(lines,"PetRockScanner v2 neededDurability")
	table.insert(lines,"place: "..tostring(game.PlaceId))
	table.insert(lines,"count: "..tostring(#rows))
	table.insert(lines,"method: object named neededDurability + LeftHand/RightHand")
	table.insert(lines,"")

	for i,r in ipairs(rows)do
		local p=r.part
		local pos=p.Position
		local size=p.Size
		table.insert(lines,("#%02d req=%s name=%s dist=%.1f"):format(i,tostring(r.req),tostring(r.name),r.dist))
		table.insert(lines,"model="..pathOf(r.model))
		table.insert(lines,"part="..pathOf(r.part))
		table.insert(lines,"left="..(r.left and pathOf(r.left) or "nil"))
		table.insert(lines,"right="..(r.right and pathOf(r.right) or "nil"))
		table.insert(lines,("pos=(%.1f, %.1f, %.1f) size=(%.1f, %.1f, %.1f)"):format(pos.X,pos.Y,pos.Z,size.X,size.Y,size.Z))
		table.insert(lines,"")
	end

	table.insert(lines,"Suggested Lua table:")
	table.insert(lines,"_G.PetAlignRockMap={")
	for _,r in ipairs(rows)do
		table.insert(lines,('\t[%q]={req=%s,pos=Vector3.new(%.1f,%.1f,%.1f),model=%q,part=%q},'):format(r.name,tostring(r.req),r.part.Position.X,r.part.Position.Y,r.part.Position.Z,pathOf(r.model),pathOf(r.part)))
	end
	table.insert(lines,"}")

	return table.concat(lines,"\n")
end

local function tpTo(row)
	if not row or not row.part then return end
	local rr=root()
	if not rr then return end

	local p=row.part
	local dir=rr.Position-p.Position
	dir=Vector3.new(dir.X,0,dir.Z)
	if dir.Magnitude<0.1 then dir=Vector3.new(0,0,-1)else dir=dir.Unit end

	local dist=math.max(p.Size.X,p.Size.Z)/2+5.5
	local y=p.Position.Y+p.Size.Y/2+3.4
	local pos=Vector3.new(p.Position.X,y,p.Position.Z)+dir*dist
	rr.CFrame=CFrame.lookAt(pos,Vector3.new(p.Position.X,y,p.Position.Z))
end

local gui=Instance.new("ScreenGui")
gui.Name="PetRockScannerV2"
gui.ResetOnSpawn=false
gui.Parent=lp:WaitForChild("PlayerGui")

local frame=Instance.new("Frame",gui)
frame.Size=UDim2.new(0,270,0,116)
frame.Position=UDim2.new(.5,-135,.5,-58)
frame.BackgroundColor3=Color3.fromRGB(15,13,28)
frame.BorderSizePixel=0
frame.Active=true
frame.Draggable=true
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,12)
local stroke=Instance.new("UIStroke",frame)
stroke.Color=Color3.fromRGB(132,70,255)
stroke.Thickness=1.2

local title=Instance.new("TextLabel",frame)
title.Size=UDim2.new(1,-42,0,28)
title.Position=UDim2.new(0,10,0,6)
title.BackgroundTransparency=1
title.Text="Rock Scanner v2"
title.TextColor3=Color3.new(1,1,1)
title.Font=Enum.Font.GothamBlack
title.TextSize=15
title.TextXAlignment=Enum.TextXAlignment.Left

local close=Instance.new("TextButton",frame)
close.Size=UDim2.new(0,26,0,26)
close.Position=UDim2.new(1,-34,0,6)
close.Text="×"
close.TextColor3=Color3.fromRGB(255,180,190)
close.BackgroundColor3=Color3.fromRGB(62,20,34)
close.Font=Enum.Font.GothamBlack
close.TextSize=16
Instance.new("UICorner",close).CornerRadius=UDim.new(0,8)

local status=Instance.new("TextLabel",frame)
status.Size=UDim2.new(1,-20,0,30)
status.Position=UDim2.new(0,10,0,36)
status.BackgroundTransparency=1
status.Text="SCAN: neededDurability. NEXT: проверка."
status.TextColor3=Color3.fromRGB(200,190,225)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left

local function mkBtn(txt,x,w,color)
	local b=Instance.new("TextButton",frame)
	b.Size=UDim2.new(0,w,0,28)
	b.Position=UDim2.new(0,x,1,-38)
	b.Text=txt
	b.TextColor3=Color3.new(1,1,1)
	b.BackgroundColor3=color
	b.Font=Enum.Font.GothamBlack
	b.TextSize=11
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
	return b
end

local scanBtn=mkBtn("SCAN",10,64,Color3.fromRGB(45,100,180))
local copyBtn=mkBtn("COPY",82,64,Color3.fromRGB(45,130,70))
local nextBtn=mkBtn("NEXT",154,64,Color3.fromRGB(100,70,160))

scanBtn.MouseButton1Click:Connect(function()
	status.Text="Сканирую neededDurability..."
	task.spawn(function()
		local ok,err=pcall(function()
			lastRows=scan()
			lastReport=makeReport(lastRows)
			cursor=0
			if setclipboard then pcall(setclipboard,lastReport)end
			status.Text="Готово: "..#lastRows.." камней. Отчёт скопирован."
		end)
		if not ok then status.Text="SCAN error: "..tostring(err):sub(1,80)end
	end)
end)

copyBtn.MouseButton1Click:Connect(function()
	if lastReport~="" and setclipboard then
		pcall(setclipboard,lastReport)
		status.Text="Отчёт скопирован."
	else
		status.Text="Сначала SCAN."
	end
end)

nextBtn.MouseButton1Click:Connect(function()
	if #lastRows==0 then status.Text="Сначала SCAN." return end
	cursor+=1
	if cursor>#lastRows then cursor=1 end
	local row=lastRows[cursor]
	tpTo(row)
	status.Text=("#%02d req=%s %s"):format(cursor,tostring(row.req),row.name)
end)

close.MouseButton1Click:Connect(function()
	gui:Destroy()
end)
