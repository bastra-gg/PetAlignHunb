-- PetRockScanner_v4_IN_ROCK
-- Отдельный сканер камней. Основной PetAlignHub не трогает.
-- Ищет камни по neededDurability + LeftHand/RightHand.
-- NEXT теперь тепает БЛИЖЕ к телу камня, а не далеко от hit-part.

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
	for _=1,6 do
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

					local body=biggestPart(key)
					local hit=lh or rh or body
					if body and hit and body:IsA("BasePart") and hit:IsA("BasePart")then
						local dist=hrp and (body.Position-hrp.Position).Magnitude or 0
						table.insert(rows,{
							req=req,
							name=REQ_NAME[req] or ("Unknown req "..tostring(req)),
							model=key,
							body=body,
							hit=hit,
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
	table.insert(lines,"PetRockScanner v4 in-rock teleport")
	table.insert(lines,"place: "..tostring(game.PlaceId))
	table.insert(lines,"count: "..tostring(#rows))
	table.insert(lines,"method: neededDurability + bodyPart + hitPart")
	table.insert(lines,"")

	for i,r in ipairs(rows)do
		local b=r.body
		local h=r.hit
		local bp=b.Position
		local bs=b.Size
		local hp=h.Position
		local hs=h.Size
		table.insert(lines,("#%02d req=%s name=%s dist=%.1f"):format(i,tostring(r.req),tostring(r.name),r.dist))
		table.insert(lines,"model="..pathOf(r.model))
		table.insert(lines,"body="..pathOf(b))
		table.insert(lines,"hit="..pathOf(h))
		table.insert(lines,"left="..(r.left and pathOf(r.left) or "nil"))
		table.insert(lines,"right="..(r.right and pathOf(r.right) or "nil"))
		table.insert(lines,("bodyPos=(%.1f, %.1f, %.1f) bodySize=(%.1f, %.1f, %.1f)"):format(bp.X,bp.Y,bp.Z,bs.X,bs.Y,bs.Z))
		table.insert(lines,("hitPos=(%.1f, %.1f, %.1f) hitSize=(%.1f, %.1f, %.1f)"):format(hp.X,hp.Y,hp.Z,hs.X,hs.Y,hs.Z))
		table.insert(lines,"")
	end

	table.insert(lines,"Suggested Lua table:")
	table.insert(lines,"_G.PetAlignRockMap={")
	for _,r in ipairs(rows)do
		local b=r.body
		local h=r.hit
		table.insert(lines,('\t[%q]={req=%s,bodyPos=Vector3.new(%.1f,%.1f,%.1f),hitPos=Vector3.new(%.1f,%.1f,%.1f),model=%q,body=%q,hit=%q},'):format(r.name,tostring(r.req),b.Position.X,b.Position.Y,b.Position.Z,h.Position.X,h.Position.Y,h.Position.Z,pathOf(r.model),pathOf(b),pathOf(h)))
	end
	table.insert(lines,"}")

	return table.concat(lines,"\n")
end

local function tpTo(row)
	if not row or not row.body then return end
	local rr=root()
	if not rr then return end

	local body=row.body
	local hit=row.hit

	-- v4: закидываем прямо внутрь/на край камня, а не рядом.
	-- Если слишком глубоко/криво — меняй:
	-- _G.PetRockInsideDepth = 0.15..0.9
	-- _G.PetRockYMode = "center" или "top"
	local depth=_G.PetRockInsideDepth or 0.35
	local yMode=_G.PetRockYMode or "center"

	local dir=rr.Position-body.Position
	dir=Vector3.new(dir.X,0,dir.Z)
	if dir.Magnitude<0.1 then
		dir=Vector3.new(body.CFrame.LookVector.X,0,body.CFrame.LookVector.Z)
	end
	if dir.Magnitude<0.1 then dir=Vector3.new(0,0,-1)else dir=dir.Unit end

	local radius=math.max(body.Size.X,body.Size.Z)/2
	local insideDist=math.max(radius*depth,0.25)

	local y
	if yMode=="top"then
		y=body.Position.Y+body.Size.Y/2+1.2
	else
		y=body.Position.Y+math.clamp(body.Size.Y*0.18,0.4,2.2)
	end

	local pos=Vector3.new(body.Position.X,y,body.Position.Z)+dir*insideDist

	-- Если есть LeftHand/RightHand, слегка тянем к нему, чтобы удар доставал.
	if hit and hit.Parent then
		local hp=hit.Position
		pos=pos:Lerp(Vector3.new(hp.X,y,hp.Z),0.25)
	end

	rr.CFrame=CFrame.lookAt(pos,Vector3.new(body.Position.X,y,body.Position.Z))
	rr.AssemblyLinearVelocity=Vector3.zero
	rr.AssemblyAngularVelocity=Vector3.zero
end


local gui=Instance.new("ScreenGui")
gui.Name="PetRockScannerV4"
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
title.Text="Rock Scanner v4"
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
status.Text="SCAN, потом NEXT. Тепает прямо в камень."
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
	status.Text=("#%02d IN ROCK req=%s %s"):format(cursor,tostring(row.req),row.name)
end)

close.MouseButton1Click:Connect(function()
	gui:Destroy()
end)
