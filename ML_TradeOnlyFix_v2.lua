-- ML_TradeAnalyzer_v1
-- ТОЛЬКО анализ трейда. Ничего не нажимает, не открывает, не спамит, не меняет игру.
-- Одна кнопка SCAN / STOP. Скан идёт кусками, чтобы не убить FPS.
-- После скана жми COPY REPORT и кидай отчёт.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterGui=game:GetService("StarterGui")
local UserInputService=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")

local lp=Players.LocalPlayer
local VERSION="ML_TradeAnalyzer_v1"

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

local uiParent=getUiParent()

pcall(function()
	local old=uiParent:FindFirstChild("ML_TradeAnalyzerGui")
	if old then old:Destroy()end
end)

local scanId=0
local scanning=false
local lastReport="Скан ещё не запускался."

local TRADE_WORDS={
	"trade","trading","обмен","трейд",
	"accept","ready","confirm","decline","cancel",
	"принять","готов","готово","подтверд","отмена","отклон",
	"pet","pets","пет","питом","питомец","питомцы",
	"offer","send","give","username","online","онлайн"
}

local REMOTE_WORDS={
	"trade","trading","обмен","трейд",
	"accept","ready","confirm","decline","cancel",
	"pet","pets","offer","send","give"
}

local POPUP_WORDS={
	"limited","лимит","запас",
	"reward","награ","бесплат",
	"claim","забрать",
	"invite","приглас",
	"task","задач",
	"shop","магазин","premium","премиум","luck","удача","pack","пакет"
}

local function low(s)
	return tostring(s or ""):lower()
end

local function hasAny(s,list)
	s=low(s)
	for _,w in ipairs(list)do
		if s:find(low(w),1,true)then return true end
	end
	return false
end

local function trim(s,n)
	s=tostring(s or "")
	s=s:gsub("\n"," "):gsub("\r"," ")
	if #s>n then return s:sub(1,n).."..." end
	return s
end

local function pathOf(obj)
	local parts={}
	local cur=obj
	local limit=0

	while cur and cur~=game and limit<18 do
		table.insert(parts,1,tostring(cur.Name))
		cur=cur.Parent
		limit+=1
	end

	return table.concat(parts,"/")
end

local function textOf(obj)
	local s=tostring(obj.Name)

	pcall(function()
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")then
			s=s.." | text="..tostring(obj.Text)
		end
	end)

	return s
end

local function addLine(t,s)
	t[#t+1]=s
end

local function yieldIf(n)
	if n%120==0 then task.wait()end
end

local function isCancelled(my)
	return (not scanning) or scanId~=my
end

local function getGuiArea(obj)
	local ok,res=pcall(function()
		local cam=workspace.CurrentCamera
		local vp=cam and cam.ViewportSize or Vector2.new(0,0)
		if vp.X<=0 or vp.Y<=0 then return 0 end
		local sz=obj.AbsoluteSize
		return (sz.X*sz.Y)/(vp.X*vp.Y)
	end)
	if ok then return tonumber(res) or 0 end
	return 0
end

local function analyze(my)
	local out={}

	addLine(out,"=== ML TRADE ANALYZER REPORT ===")
	addLine(out,"version: "..VERSION)
	addLine(out,"player: "..lp.Name)
	addLine(out,"time: "..os.date("%Y-%m-%d %H:%M:%S"))
	addLine(out,"mode: analyze only, no clicks, no remotes fired")
	addLine(out,"")

	local pg=lp:FindFirstChild("PlayerGui")
	addLine(out,"[BASIC]")
	addLine(out,"PlayerGui: "..tostring(pg~=nil))

	local okCore=true
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,true)
	end)
	addLine(out,"CoreGui check: attempted Backpack enable = "..tostring(okCore))

	local touch=pg and pg:FindFirstChild("TouchGui")
	addLine(out,"TouchGui exists: "..tostring(touch~=nil))
	if touch then
		addLine(out,"TouchGui enabled: "..tostring(touch.Enabled))
	end
	addLine(out,"")

	if isCancelled(my)then return "CANCELLED"end

	addLine(out,"[SCREEN GUIS]")
	if not pg then
		addLine(out,"NO PlayerGui")
	else
		local count=0
		for _,sg in ipairs(pg:GetChildren())do
			if isCancelled(my)then return "CANCELLED"end
			if sg:IsA("ScreenGui")then
				count+=1
				local pack=tostring(sg.Name)
				local textCount=0
				for _,d in ipairs(sg:GetDescendants())do
					if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")then
						textCount+=1
						if textCount<=80 then
							pack=pack.." "..tostring(d.Name).." "..tostring(d.Text)
						end
					end
					if textCount%120==0 then task.wait()end
				end

				local tag={}
				if hasAny(pack,TRADE_WORDS)then tag[#tag+1]="TRADE-LIKE"end
				if hasAny(pack,POPUP_WORDS)then tag[#tag+1]="POPUP-LIKE"end
				if tostring(sg.Name):find("RockBug",1,true)then tag[#tag+1]="OLD-ROCKBUG"end
				if #tag>0 then
					addLine(out,("- %s | Enabled=%s | DisplayOrder=%s | %s"):format(
						sg.Name,
						tostring(sg.Enabled),
						tostring(sg.DisplayOrder),
						table.concat(tag,",")
					))
				end
			end
			yieldIf(count)
		end
		addLine(out,"ScreenGui total: "..tostring(count))
	end
	addLine(out,"")

	if isCancelled(my)then return "CANCELLED"end

	addLine(out,"[TRADE GUI BUTTON/TEXT CANDIDATES]")
	if pg then
		local n=0
		local shown=0
		for _,d in ipairs(pg:GetDescendants())do
			if isCancelled(my)then return "CANCELLED"end
			n+=1

			if d:IsA("TextButton") or d:IsA("TextLabel") or d:IsA("TextBox")then
				local txt=textOf(d)
				if hasAny(txt,TRADE_WORDS)then
					shown+=1
					if shown<=90 then
						local vis="?"
						local act="?"
						local z="?"
						pcall(function()vis=tostring(d.Visible)end)
						pcall(function()act=tostring(d.Active)end)
						pcall(function()z=tostring(d.ZIndex)end)
						addLine(out,("[%02d] %s | class=%s | visible=%s active=%s z=%s"):format(
							shown,
							pathOf(d),
							d.ClassName,
							vis,
							act,
							z
						))
						addLine(out,"     "..trim(txt,150))
					end
				end
			end

			yieldIf(n)
			if n>7000 then
				addLine(out,"STOP: GUI scan cap 7000 reached")
				break
			end
		end
		addLine(out,"Trade-like GUI hits shown/total: "..tostring(math.min(shown,90)).."/"..tostring(shown))
	end
	addLine(out,"")

	if isCancelled(my)then return "CANCELLED"end

	addLine(out,"[POSSIBLE CLICK BLOCKERS]")
	if pg then
		local n=0
		local shown=0
		for _,d in ipairs(pg:GetDescendants())do
			if isCancelled(my)then return "CANCELLED"end
			n+=1

			if d:IsA("GuiObject")then
				local area=getGuiArea(d)
				if area>0.30 then
					local txt=textOf(d)
					local isTrade=hasAny(txt,TRADE_WORDS)
					local isPopup=hasAny(txt,POPUP_WORDS)
					local active=false
					local visible=false
					local bg=1
					pcall(function()active=d.Active end)
					pcall(function()visible=d.Visible end)
					pcall(function()bg=d.BackgroundTransparency end)

					if visible and (active or bg<0.95 or isPopup) and not isTrade then
						shown+=1
						if shown<=50 then
							addLine(out,("[%02d] blocker? area=%.2f active=%s bgT=%s class=%s path=%s"):format(
								shown,
								area,
								tostring(active),
								tostring(bg),
								d.ClassName,
								pathOf(d)
							))
							addLine(out,"     "..trim(txt,120))
						end
					end
				end
			end

			yieldIf(n)
			if n>7000 then
				addLine(out,"STOP: blocker scan cap 7000 reached")
				break
			end
		end
		addLine(out,"Blocker candidates shown/total: "..tostring(math.min(shown,50)).."/"..tostring(shown))
	end
	addLine(out,"")

	if isCancelled(my)then return "CANCELLED"end

	addLine(out,"[REMOTE CANDIDATES]")
	local remoteShown=0
	local remoteTotal=0
	local n=0
	for _,d in ipairs(ReplicatedStorage:GetDescendants())do
		if isCancelled(my)then return "CANCELLED"end
		n+=1

		if d:IsA("RemoteEvent") or d:IsA("RemoteFunction")then
			local p=pathOf(d)
			if hasAny(p,REMOTE_WORDS)then
				remoteTotal+=1
				remoteShown+=1
				if remoteShown<=80 then
					addLine(out,("[%02d] %s | %s"):format(remoteShown,d.ClassName,p))
				end
			end
		end

		yieldIf(n)
		if n>12000 then
			addLine(out,"STOP: remote scan cap 12000 reached")
			break
		end
	end
	addLine(out,"Remote trade-like shown/total: "..tostring(math.min(remoteShown,80)).."/"..tostring(remoteTotal))
	addLine(out,"")

	if isCancelled(my)then return "CANCELLED"end

	addLine(out,"[PLAYER DATA / PET / TRADE OBJECT NAMES]")
	local roots={
		lp,
		lp:FindFirstChild("PlayerScripts"),
		lp:FindFirstChild("Backpack"),
		lp.Character,
		ReplicatedStorage
	}
	local shown=0
	local scanned=0

	for _,root in ipairs(roots)do
		if root then
			for _,d in ipairs(root:GetDescendants())do
				if isCancelled(my)then return "CANCELLED"end
				scanned+=1

				local p=pathOf(d)
				if hasAny(p,{"trade","trading","обмен","pet","pets","пет","питом"})then
					shown+=1
					if shown<=100 then
						local val=""
						pcall(function()
							if d:IsA("StringValue") or d:IsA("NumberValue") or d:IsA("IntValue") or d:IsA("BoolValue")then
								val=" value="..tostring(d.Value)
							end
						end)
						addLine(out,("[%02d] %s | %s%s"):format(shown,d.ClassName,p,val))
					end
				end

				yieldIf(scanned)
				if scanned>16000 then
					addLine(out,"STOP: data scan cap 16000 reached")
					break
				end
			end
		end
	end
	addLine(out,"Object name hits shown/total: "..tostring(math.min(shown,100)).."/"..tostring(shown))
	addLine(out,"")

	addLine(out,"[END]")
	addLine(out,"Send this full report.")
	return table.concat(out,"\n")
end

-- UI
local gui=Instance.new("ScreenGui")
gui.Name="ML_TradeAnalyzerGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=10000000
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=uiParent

local main=Instance.new("Frame")
main.Parent=gui
main.Size=UDim2.new(0,330,0,248)
main.Position=UDim2.new(0,14,0,100)
main.BackgroundColor3=Color3.fromRGB(14,15,22)
main.BackgroundTransparency=0.04
main.BorderSizePixel=0
main.Active=true
main.ZIndex=50
Instance.new("UICorner",main).CornerRadius=UDim.new(0,16)

local stroke=Instance.new("UIStroke",main)
stroke.Color=Color3.fromRGB(100,160,255)
stroke.Thickness=1.3
stroke.Transparency=0.1

local title=Instance.new("TextLabel")
title.Parent=main
title.Size=UDim2.new(1,-48,0,24)
title.Position=UDim2.new(0,12,0,8)
title.BackgroundTransparency=1
title.Text="TRADE ANALYZER"
title.TextColor3=Color3.fromRGB(235,245,255)
title.Font=Enum.Font.GothamBlack
title.TextSize=14
title.TextXAlignment=Enum.TextXAlignment.Left
title.ZIndex=51

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
close.ZIndex=52
Instance.new("UICorner",close).CornerRadius=UDim.new(0,10)

local status=Instance.new("TextLabel")
status.Parent=main
status.Size=UDim2.new(1,-24,0,28)
status.Position=UDim2.new(0,12,0,36)
status.BackgroundTransparency=1
status.Text="готово | скан не запущен"
status.TextColor3=Color3.fromRGB(210,220,245)
status.Font=Enum.Font.GothamBold
status.TextSize=10
status.TextXAlignment=Enum.TextXAlignment.Left
status.ZIndex=51

local function mkBtn(text,x,y,w,h)
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
	b.ZIndex=52
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

local scanBtn=mkBtn("SCAN",12,68,96,32)
local copyBtn=mkBtn("COPY REPORT",118,68,104,32)
local clearBtn=mkBtn("CLEAR",232,68,84,32)

local box=Instance.new("TextBox")
box.Parent=main
box.Size=UDim2.new(1,-24,1,-112)
box.Position=UDim2.new(0,12,0,108)
box.BackgroundColor3=Color3.fromRGB(8,9,14)
box.BackgroundTransparency=0.05
box.BorderSizePixel=0
box.TextColor3=Color3.fromRGB(225,230,245)
box.Font=Enum.Font.Code
box.TextSize=9
box.TextXAlignment=Enum.TextXAlignment.Left
box.TextYAlignment=Enum.TextYAlignment.Top
box.ClearTextOnFocus=false
box.MultiLine=true
box.TextWrapped=false
box.TextEditable=false
box.Text="Нажми SCAN. Если FPS просел — жми эту же кнопку STOP."
box.ZIndex=51
Instance.new("UICorner",box).CornerRadius=UDim.new(0,10)

local function setScanUi()
	scanBtn.Text=scanning and "STOP" or "SCAN"
	scanBtn.BackgroundColor3=scanning and Color3.fromRGB(140,55,65) or Color3.fromRGB(45,120,75)
end

scanBtn.Activated:Connect(function()
	if scanning then
		scanning=false
		scanId+=1
		status.Text="остановлено"
		setScanUi()
		return
	end

	scanning=true
	scanId+=1
	local my=scanId
	status.Text="скан идёт кусками..."
	box.Text="Scanning... кнопка стала STOP, ей же можно остановить."
	setScanUi()

	task.spawn(function()
		local report=analyze(my)
		if report=="CANCELLED"then
			lastReport="CANCELLED BY USER"
			box.Text=lastReport
			status.Text="скан остановлен"
		else
			lastReport=report
			box.Text=report
			status.Text="готово | длина отчёта: "..tostring(#report)
		end
		scanning=false
		setScanUi()
	end)
end)

copyBtn.Activated:Connect(function()
	local text=lastReport or box.Text or ""
	local ok=false

	safe(function()
		if setclipboard then
			setclipboard(text)
			ok=true
		end
	end)

	if ok then
		status.Text="отчёт скопирован"
	else
		status.Text="setclipboard нет | выдели текст вручную"
	end
end)

clearBtn.Activated:Connect(function()
	lastReport=""
	box.Text=""
	status.Text="очищено"
end)

close.Activated:Connect(function()
	scanning=false
	scanId+=1
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

setScanUi()
