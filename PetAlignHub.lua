-- PetAlignHub.lua
-- Для твоей тестовой сборки/личного сервера. Без RemoteEvent-спама.
-- Loader: loadstring(game:HttpGet("RAW_URL", true))()

local Players=game:GetService("Players")
local lp=Players.LocalPlayer

local BASE={Basic=250,Uncommon=500,Rare=750,Epic=1000,Unique=1250}
local ROCK={AncientJungle=16.25,MuscleKing=12.5,Legends=2.5,Inferno=1.125,Mystic=.75,Frozen=.375,Golden=.2,Large=.075,Punching=.05,Tiny=.025}

local function cum(base,lvl) return base*lvl*(lvl+1)/2 end

local function levelFromTotal(base,total)
	if total<=0 then return 1,0 end
	local prev=0
	for lvl=1,19 do
		local cap=cum(base,lvl)
		if total<cap then return lvl,total-prev end
		if total==cap then return lvl,base*lvl end
		prev=cap
	end
	return 20,0
end

local function calcAlign(reb,rarity,rock,capLvl)
	local base=BASE[rarity]
	local mult=ROCK[rock]
	if not base then return false,"Rarity: Basic/Uncommon/Rare/Epic/Unique" end
	if not mult then return false,"Rock: Legends/MuscleKing/AncientJungle/etc" end

	local hit=math.floor(((reb+20)*mult)+0.5)
	local target=cum(base,capLvl)
	local need=target-hit
	if need<0 then return false,"Удар больше капа. Выбери выше cap lvl." end

	local lvl,xp=levelFromTotal(base,need)
	return true,{level=lvl,xp=xp,total=need,hit=hit,capLvl=capLvl}
end

local function findPet()
	if _G.SelectedPet then return _G.SelectedPet end
	if _G.Pet then return _G.Pet end
	return nil
end

local function setValue(obj,names,value)
	for _,n in ipairs(names) do
		local v=obj and obj:FindFirstChild(n)
		if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
			v.Value=value
			return true
		end
	end
	return false
end

local function applyPet(data)
	if _G.PetAPI and _G.PetAPI.SetPetXP then
		_G.PetAPI.SetPetXP(findPet(),data.level,data.xp,data.total)
		return true,"Applied через _G.PetAPI.SetPetXP"
	end

	local pet=findPet()
	if not pet then return false,"Пет не найден: задай _G.SelectedPet = pet" end

	local a=setValue(pet,{"Level","Lvl","level","lvl"},data.level)
	local b=setValue(pet,{"XP","Exp","Experience","xp"},data.xp)
	local c=setValue(pet,{"TotalXP","TotalExp","totalXP"},data.total)
	if a or b or c then return true,"Applied в Value-объекты пета" end

	return false,"Не нашёл Level/XP/TotalXP внутри пета"
end

local gui=Instance.new("ScreenGui")
gui.Name="PetAlignHub"
gui.ResetOnSpawn=false
gui.Parent=lp:WaitForChild("PlayerGui")

local f=Instance.new("Frame",gui)
f.Size=UDim2.new(0,310,0,280)
f.Position=UDim2.new(.5,-155,.5,-140)
f.BackgroundColor3=Color3.fromRGB(18,18,35)
f.BorderSizePixel=0
f.Active=true
f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,14)

local t=Instance.new("TextLabel",f)
t.Size=UDim2.new(1,-44,0,34)
t.Position=UDim2.new(0,12,0,6)
t.BackgroundTransparency=1
t.Text="Pet Align Hub"
t.TextColor3=Color3.new(1,1,1)
t.Font=Enum.Font.GothamBlack
t.TextSize=18
t.TextXAlignment=Enum.TextXAlignment.Left

local x=Instance.new("TextButton",f)
x.Size=UDim2.new(0,30,0,30)
x.Position=UDim2.new(1,-36,0,6)
x.Text="×"
x.TextColor3=Color3.fromRGB(255,180,190)
x.BackgroundColor3=Color3.fromRGB(45,20,30)
x.Font=Enum.Font.GothamBlack
x.TextSize=18
Instance.new("UICorner",x).CornerRadius=UDim.new(0,10)
x.MouseButton1Click:Connect(function() gui:Destroy() end)

local function box(y,label,def)
	local l=Instance.new("TextLabel",f)
	l.Size=UDim2.new(0,120,0,26)
	l.Position=UDim2.new(0,12,0,y)
	l.BackgroundTransparency=1
	l.Text=label
	l.TextColor3=Color3.fromRGB(210,200,255)
	l.Font=Enum.Font.GothamBold
	l.TextSize=13
	l.TextXAlignment=Enum.TextXAlignment.Left

	local b=Instance.new("TextBox",f)
	b.Size=UDim2.new(0,150,0,30)
	b.Position=UDim2.new(1,-162,0,y)
	b.Text=def
	b.ClearTextOnFocus=false
	b.TextColor3=Color3.new(1,1,1)
	b.BackgroundColor3=Color3.fromRGB(30,30,58)
	b.Font=Enum.Font.GothamBold
	b.TextSize=13
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
	return b
end

local reb=box(50,"Rebirths","45164")
local cap=box(88,"Cap lvl","13")
local rar=box(126,"Rarity","Unique")
local roc=box(164,"Rock","Legends")

local out=Instance.new("TextLabel",f)
out.Size=UDim2.new(1,-24,0,46)
out.Position=UDim2.new(0,12,0,202)
out.BackgroundColor3=Color3.fromRGB(14,14,28)
out.TextColor3=Color3.fromRGB(255,230,140)
out.Font=Enum.Font.GothamBold
out.TextSize=13
out.TextWrapped=true
out.Text="Жми Calc"
Instance.new("UICorner",out).CornerRadius=UDim.new(0,10)

local c=Instance.new("TextButton",f)
c.Size=UDim2.new(.48,-14,0,30)
c.Position=UDim2.new(0,12,1,-38)
c.Text="Calc"
c.TextColor3=Color3.new(1,1,1)
c.BackgroundColor3=Color3.fromRGB(105,55,210)
c.Font=Enum.Font.GothamBlack
c.TextSize=14
Instance.new("UICorner",c).CornerRadius=UDim.new(0,10)

local a=Instance.new("TextButton",f)
a.Size=UDim2.new(.48,-14,0,30)
a.Position=UDim2.new(.52,2,1,-38)
a.Text="Apply"
a.TextColor3=Color3.new(1,1,1)
a.BackgroundColor3=Color3.fromRGB(30,135,80)
a.Font=Enum.Font.GothamBlack
a.TextSize=14
Instance.new("UICorner",a).CornerRadius=UDim.new(0,10)

local last

local function refresh()
	local ok,data=calcAlign(tonumber(reb.Text),rar.Text:gsub("%s+",""),roc.Text:gsub("%s+",""),tonumber(cap.Text))
	if not ok then out.Text=data last=nil return end
	last=data
	out.Text=("Поставить: %s lvl, %s XP\nHit: %s | Total: %s"):format(data.level,data.xp,data.hit,data.total)
	if setclipboard then setclipboard(("Level=%s XP=%s TotalXP=%s Hit=%s"):format(data.level,data.xp,data.total,data.hit)) end
end

c.MouseButton1Click:Connect(refresh)
a.MouseButton1Click:Connect(function()
	if not last then refresh() end
	if not last then return end
	local ok,msg=applyPet(last)
	out.Text=(ok and "✅ " or "❌ ")..msg..("\n%s lvl, %s XP"):format(last.level,last.xp)
end)

refresh()
