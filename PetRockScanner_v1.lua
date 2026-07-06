-- PetRockScanner v1
-- Маленький отдельный сканер камней/скал. Основной PetAlignHub не трогает.
-- Кнопки: SCAN = найти/скопировать отчёт, COPY = ещё раз копировать, NEXT = тепнуть к следующему кандидату.

local Players=game:GetService("Players")
local lp=Players.LocalPlayer

local ROCK_NAMES={
	"tiny rock","small rock","малый камень","маленький камень",
	"punching rock","punch rock","ударный камень","камень для ударов",
	"large rock","big rock","большой камень","большая скала",
	"golden rock","gold rock","золотой камень",
	"frozen rock","ice rock","frost rock","ледяной камень","замороженный камень",
	"mythical rock","mystic rock","mystic","мистический камень",
	"eternal rock","eternal","вечный камень",
	"legends rock","legend rock","legends","legend","камень легенд","легендарный камень",
	"inferno rock","inferno","инферно камень","камень инферно",
	"muscle king rock","muscle king","king rock","король мышц",
	"ancient jungle rock","ancient jungle","древний лес","древний камень",
	"rock","rocks","stone","камень","скала","скалы"
}

local BAD={
	"tread","treadmill","дорож","бег",
	"throw","throwing","брос","launch","catapult",
	"trainer","training","тренаж","machine","машин",
	"weight","barbell","dumbbell","bench","lift",
	"speed","agility","jump","chest","egg","pet","aura","shop","магаз"
}

local function root()
	local c=lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function low(s)return tostring(s or ""):lower()end

local function pathOf(obj)
	local parts={}
	local p=obj
	local n=0
	while p and p~=game and n<12 do
		table.insert(parts,1,p.Name)
		p=p.Parent
		n+=1
	end
	return table.concat(parts,"/")
end

local function hasAny(txt,list)
	txt=low(txt)
	for _,w in ipairs(list)do
		if txt:find(low(w),1,true)then return true,w end
	end
	return false,nil
end

local function allText(obj)
	local t={obj.Name,pathOf(obj)}
	local p=obj.Parent
	if p then table.insert(t,p.Name)end

	local model=obj:IsA("Model") and obj or obj:FindFirstAncestorWhichIsA("Model")
	if model then table.insert(t,model.Name) table.insert(t,pathOf(model))end

	for _,d in ipairs(obj:GetDescendants())do
		if d:IsA("TextLabel")or d:IsA("TextButton")or d:IsA("TextBox")then
			local tx=tostring(d.Text or "")
			if #tx>0 then table.insert(t,tx)end
		end
	end

	return table.concat(t," ")
end

local function biggestPart(obj)
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

local function modelKey(obj)
	local m=obj:IsA("Model") and obj or obj:FindFirstAncestorWhichIsA("Model")
	return m or obj
end

local function scanRocks()
	local hrp=root()
	local rows={}
	local byObj={}
	local scanned=0

	local function addCandidate(obj,reason,extraText)
		if not obj then return end
		local key=modelKey(obj)
		if byObj[key]then return end

		local part=biggestPart(key) or biggestPart(obj)
		if not part then return end

		local txt=low((extraText or "").." "..allText(key).." "..allText(part))
		local isRock,rockWord=hasAny(txt,ROCK_NAMES)
		if not isRock then return end

		local bad,badWord=hasAny(txt,BAD)
		if bad then return end

		local score=0
		if rockWord then score+=120 end
		if reason=="label"then score+=260 end
		if txt:find("rock",1,true)or txt:find("rocks",1,true)then score+=90 end
		if txt:find("камень",1,true)or txt:find("скал",1,true)then score+=90 end
		if pathOf(key):lower():find("rocks",1,true)then score+=120 end
		if part.Anchored then score+=35 else score-=80 end

		local vol=part.Size.X*part.Size.Y*part.Size.Z
		score+=math.clamp(vol/80,0,80)

		local dist=hrp and (part.Position-hrp.Position).Magnitude or 0
		score-=math.clamp(dist/700,0,70)

		byObj[key]=true
		table.insert(rows,{
			score=score,
			reason=reason,
			word=rockWord,
			obj=key,
			part=part,
			dist=dist,
			txt=txt
		})
	end

	-- 1) Сначала надписи над камнями.
	for _,obj in ipairs(workspace:GetDescendants())do
		scanned+=1
		if scanned%350==0 then task.wait()end

		if obj:IsA("TextLabel")or obj:IsA("TextButton")or obj:IsA("TextBox")then
			local txt=tostring(obj.Text or "")
			local ok=hasAny(txt,ROCK_NAMES)
			local bad=hasAny(txt,BAD)
			if ok and not bad then
				local gui=obj:FindFirstAncestorWhichIsA("BillboardGui") or obj:FindFirstAncestorWhichIsA("SurfaceGui")
				local adornee=gui and gui.Adornee
				if adornee then
					addCandidate(adornee,"label",txt)
				elseif gui and gui.Parent then
					addCandidate(gui.Parent,"label",txt)
				else
					addCandidate(obj.Parent,"label",txt)
				end
			end
		end
	end

	-- 2) Потом сами объекты/модели.
	scanned=0
	for _,obj in ipairs(workspace:GetDescendants())do
		scanned+=1
		if scanned%500==0 then task.wait()end

		if obj:IsA("Model")or obj:IsA("BasePart")then
			local txt=allText(obj)
			local ok=hasAny(txt,ROCK_NAMES)
			local bad=hasAny(txt,BAD)
			if ok and not bad then
				addCandidate(obj,"name",txt)
			end
		end
	end

	table.sort(rows,function(a,b)
		if math.abs(a.score-b.score)>1 then return a.score>b.score end
		return a.dist<b.dist
	end)

	return rows
end

local lastRows={}
local lastReport=""
local cursor=0

local function makeReport(rows)
	local lines={}
	table.insert(lines,"PetRockScanner v1")
	table.insert(lines,"place: "..tostring(game.PlaceId))
	table.insert(lines,"count: "..tostring(#rows))
	table.insert(lines,"format: score/reason/name/path/pos/size/dist")
	table.insert(lines,"")

	for i,r in ipairs(rows)do
		local p=r.part
		local pos=p.Position
		local size=p.Size
		table.insert(lines,("#%02d score=%.1f reason=%s word=%s dist=%.1f"):format(i,r.score,tostring(r.reason),tostring(r.word),r.dist))
		table.insert(lines,"model="..pathOf(r.obj))
		table.insert(lines,"part="..pathOf(p))
		table.insert(lines,("pos=(%.1f, %.1f, %.1f) size=(%.1f, %.1f, %.1f) anchored=%s"):format(pos.X,pos.Y,pos.Z,size.X,size.Y,size.Z,tostring(p.Anchored)))
		local textShort=r.txt:gsub("%s+"," ")
		table.insert(lines,"text="..textShort:sub(1,220))
		table.insert(lines,"")
	end

	return table.concat(lines,"\n")
end

local function tpToRow(row)
	if not row or not row.part then return end
	local r=root()
	if not r then return end

	local part=row.part
	local dir=(r.Position-part.Position)
	dir=Vector3.new(dir.X,0,dir.Z)
	if dir.Magnitude<0.1 then dir=Vector3.new(0,0,-1)else dir=dir.Unit end

	local dist=math.max(part.Size.X,part.Size.Z)/2+5
	local y=part.Position.Y+part.Size.Y/2+3.4
	local pos=Vector3.new(part.Position.X,y,part.Position.Z)+dir*dist
	r.CFrame=CFrame.lookAt(pos,Vector3.new(part.Position.X,y,part.Position.Z))
end

-- UI
local gui=Instance.new("ScreenGui")
gui.Name="PetRockScannerV1"
gui.ResetOnSpawn=false
gui.Parent=lp:WaitForChild("PlayerGui")

local frame=Instance.new("Frame",gui)
frame.Size=UDim2.new(0,260,0,116)
frame.Position=UDim2.new(.5,-130,.5,-58)
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
title.Text="Rock Scanner v1"
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
status.Size=UDim2.new(1,-20,0,28)
status.Position=UDim2.new(0,10,0,36)
status.BackgroundTransparency=1
status.Text="SCAN скопирует отчёт. NEXT проверка кандидатов."
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
	status.Text="Сканирую камни..."
	task.spawn(function()
		local ok,err=pcall(function()
			lastRows=scanRocks()
			lastReport=makeReport(lastRows)
			cursor=0
			if setclipboard then pcall(setclipboard,lastReport)end
			status.Text="Готово: "..#lastRows.." кандидатов. Отчёт скопирован."
		end)
		if not ok then status.Text="SCAN error: "..tostring(err):sub(1,80)end
	end)
end)

copyBtn.MouseButton1Click:Connect(function()
	if lastReport~="" and setclipboard then
		pcall(setclipboard,lastReport)
		status.Text="Отчёт снова скопирован."
	else
		status.Text="Сначала SCAN."
	end
end)

nextBtn.MouseButton1Click:Connect(function()
	if #lastRows==0 then status.Text="Сначала SCAN." return end
	cursor+=1
	if cursor>#lastRows then cursor=1 end
	local row=lastRows[cursor]
	tpToRow(row)
	status.Text=("#%02d score %.1f | %s"):format(cursor,row.score,row.word or "?")
end)

close.MouseButton1Click:Connect(function()
	gui:Destroy()
end)
