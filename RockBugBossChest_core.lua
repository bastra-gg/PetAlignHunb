-- RockBugBossChest core contract: 1
local a=game:GetService("Players")
local b=game:GetService("UserInputService")
if not game:IsLoaded()then game.Loaded:Wait()end
local c=a.LocalPlayer
while not c do task.wait()c=a.LocalPlayer end
local d=c:WaitForChild("PlayerGui",60)
if not d then error("RockBugBossChest: PlayerGui not found",0)end

local e=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then e=v end end
if e.RockBugBossChestStandalone and type(e.RockBugBossChestStandalone.Destroy)=="function"then pcall(e.RockBugBossChestStandalone.Destroy)end

local s={startupReady=true,alive=true,busy=false,last=nil}
e.RockBugBossChestStandalone=s

local function f(v)return string.lower(tostring(v or""))end
local g={
 ["common boss chest"]={100,"Common Boss Chest"},
 ["rare boss chest"]={200,"Rare Boss Chest"},
 ["epic boss chest"]={300,"Epic Boss Chest"},
 ["legendary boss chest"]={400,"Legendary Boss Chest"},
 ["mythic boss chest"]={500,"Mythic Boss Chest"},
}
local function h(text)
 local x=f(text)
 for n,v in pairs(g)do if x:find(n,1,true)then return v[1],v[2]end end
 if x:find("сундук",1,true)and x:find("босс",1,true)then
  if x:find("мифик",1,true)or x:find("мифич",1,true)then return 500,"Mythic Boss Chest"end
  if x:find("легендар",1,true)then return 400,"Legendary Boss Chest"end
  if x:find("эпич",1,true)then return 300,"Epic Boss Chest"end
  if x:find("редк",1,true)then return 200,"Rare Boss Chest"end
  if x:find("общ",1,true)or x:find("обыч",1,true)then return 100,"Common Boss Chest"end
  return 50,"Boss Chest"
 end
 if x:find("boss chest",1,true)then return 50,"Boss Chest"end
 return nil,nil
end
local function i(text)
 local x=f(text)
 return x:find("claim reward",1,true)~=nil or x:find("claim",1,true)~=nil or x:find("collect",1,true)~=nil or x:find("reward",1,true)~=nil or x:find("получить награду",1,true)~=nil or x:find("собрать награду",1,true)~=nil or x:find("забрать награду",1,true)~=nil
end
local function j(x)
 local t={}
 local function q(v)if v and tostring(v)~=""then t[#t+1]=tostring(v)end end
 q(x.Name)
 if x:IsA("ProximityPrompt")then pcall(function()q(x.ActionText)q(x.ObjectText)end)end
 local p=x.Parent
 for _=1,7 do if not p or p==workspace then break end;q(p.Name)p=p.Parent end
 return table.concat(t," ")
end
local function k(x)
 local y=x
 for _=1,8 do
  if not y or y==workspace then break end
  if y:IsA("Attachment")then local ok,v=pcall(function()return y.WorldCFrame end)if ok then return v end end
  if y:IsA("BasePart")then return y.CFrame end
  if y:IsA("Model")then local ok,v=pcall(function()return y:GetPivot()end)if ok then return v end end
  y=y.Parent
 end
 return nil
end
local function l()
 local ch=c.Character
 local r=ch and ch:FindFirstChild("HumanoidRootPart")
 local hum=ch and ch:FindFirstChildWhichIsA("Humanoid")
 return ch,r,hum
end
local function m()
 local _,r=l()if not r then return nil,nil end
 local ok,all=pcall(function()return workspace:GetDescendants()end)
 if not ok then return nil,nil end
 local best,name,bestScore=nil,nil,-math.huge
 for idx,x in ipairs(all)do
  if idx>26000 then break end
  if x:IsA("ProximityPrompt")and x.Enabled then
   local object,action="",""
   pcall(function()object=tostring(x.ObjectText or"")action=tostring(x.ActionText or"")end)
   local full=j(x)
   local tier,tierName=h(object.." "..full)
   if tier then
    local score=tier
    if i(action)or i(full)then score+=450 end
    local cf=k(x)
    if cf then score-=math.min((r.Position-cf.Position).Magnitude,1200)*0.01 else score-=10000 end
    if score>bestScore then best,name,bestScore=x,tierName,score end
   end
  end
 end
 return best,name
end
local function n(prompt)
 local _,r,hum=l()if not r or not hum or hum.Health<=0 then return false,"Персонаж не готов"end
 local cf=k(prompt)if not cf then return false,"Не нашёл позицию сундука"end
 r.Anchored=false
 hum.Sit=false
 r.CFrame=cf*CFrame.new(0,3,-4)
 r.AssemblyLinearVelocity=Vector3.zero
 r.AssemblyAngularVelocity=Vector3.zero
 return true
end
local function o(prompt)
 if not prompt or not prompt.Parent or not prompt.Enabled then return false end
 local ok=false
 if type(fireproximityprompt)=="function"then
  ok=pcall(function()fireproximityprompt(prompt,0)end)
 end
 if not ok then
  ok=pcall(function()
   prompt:InputHoldBegin()
   task.wait(math.max(0.05,tonumber(prompt.HoldDuration)or 0)+0.03)
   prompt:InputHoldEnd()
  end)
 end
 return ok
end

local old=d:FindFirstChild("RockBugBossChestMenu")
if old then old:Destroy()end
local gui=Instance.new("ScreenGui")
gui.Name="RockBugBossChestMenu";gui.ResetOnSpawn=false;gui.DisplayOrder=999995;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=d
local win=Instance.new("Frame")
win.Name="Window";win.Size=UDim2.fromOffset(310,176);win.Position=UDim2.new(0.5,-155,0.5,-88);win.BackgroundColor3=Color3.fromRGB(20,21,27);win.BackgroundTransparency=0.06;win.BorderSizePixel=0;win.Parent=gui
local corner=Instance.new("UICorner",win);corner.CornerRadius=UDim.new(0,14)
local stroke=Instance.new("UIStroke",win);stroke.Color=Color3.fromRGB(142,118,255);stroke.Transparency=0.35;stroke.Thickness=1
local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,-56,0,42);title.Position=UDim2.fromOffset(16,4);title.BackgroundTransparency=1;title.Text="BOSS CHEST TEST";title.TextColor3=Color3.fromRGB(238,239,244);title.TextSize=16;title.Font=Enum.Font.GothamBold;title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=win
local close=Instance.new("TextButton")
close.Size=UDim2.fromOffset(34,30);close.Position=UDim2.new(1,-42,0,10);close.BackgroundColor3=Color3.fromRGB(38,39,47);close.BorderSizePixel=0;close.Text="×";close.TextColor3=Color3.fromRGB(238,239,244);close.TextSize=18;close.Font=Enum.Font.GothamBold;close.Parent=win
local cc=Instance.new("UICorner",close);cc.CornerRadius=UDim.new(0,9)
local status=Instance.new("TextLabel")
status.Size=UDim2.new(1,-32,0,42);status.Position=UDim2.fromOffset(16,48);status.BackgroundTransparency=1;status.Text="Готов. Сам ничего не делает.";status.TextColor3=Color3.fromRGB(159,161,174);status.TextSize=13;status.Font=Enum.Font.Gotham;status.TextWrapped=true;status.TextXAlignment=Enum.TextXAlignment.Left;status.Parent=win
local run=Instance.new("TextButton")
run.Size=UDim2.new(1,-32,0,52);run.Position=UDim2.fromOffset(16,108);run.BackgroundColor3=Color3.fromRGB(142,118,255);run.BorderSizePixel=0;run.Text="ТП К СУНДУКУ + ЗАБРАТЬ";run.TextColor3=Color3.fromRGB(20,18,28);run.TextSize=14;run.Font=Enum.Font.GothamBold;run.Parent=win
local rc=Instance.new("UICorner",run);rc.CornerRadius=UDim.new(0,11)

local dragging=false;local dragStart,startPos
win.InputBegan:Connect(function(inp)
 if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=true;dragStart=inp.Position;startPos=win.Position end
end)
win.InputEnded:Connect(function(inp)if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
b.InputChanged:Connect(function(inp)
 if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch)then
  local delta=inp.Position-dragStart
  win.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
 end
end)

local function setStatus(text,bad)
 if not status or not status.Parent then return end
 status.Text=text
 status.TextColor3=bad and Color3.fromRGB(240,108,119)or Color3.fromRGB(159,161,174)
end
local function p()
 if s.busy or not s.alive then return end
 s.busy=true;run.Active=false;run.Text="ИЩУ СУНДУК...";setStatus("Ищу активный Boss Chest...",false)
 task.spawn(function()
  local prompt,chestName
  for _=1,20 do
   if not s.alive then break end
   prompt,chestName=m()
   if prompt then break end
   task.wait(0.2)
  end
  if not s.alive then s.busy=false return end
  if not prompt then
   setStatus("Сундук не найден. Подойди/дождись награды и нажми ещё раз.",true)
  else
   s.last=chestName
   setStatus("Нашёл: "..tostring(chestName).." • телепорт...",false)
   local moved,problem=n(prompt)
   if not moved then
    setStatus(problem or "Не удалось телепортироваться",true)
   else
    task.wait(0.38)
    local fired=false
    for _=1,3 do
     if prompt and prompt.Parent and prompt.Enabled then fired=o(prompt)or fired end
     if fired then break end
     task.wait(0.18)
    end
    if fired then setStatus("Нажал: "..tostring(chestName),false)else setStatus("Сундук найден, но prompt не нажался",true)end
   end
  end
  s.busy=false
  if run and run.Parent then run.Active=true;run.Text="ТП К СУНДУКУ + ЗАБРАТЬ"end
 end)
end
run.Activated:Connect(p)
local function destroy()
 if not s.alive then return end
 s.alive=false;s.busy=false
 if gui and gui.Parent then gui:Destroy()end
 if e.RockBugBossChestStandalone==s then e.RockBugBossChestStandalone=nil end
end
s.Destroy=destroy
close.Activated:Connect(destroy)
return s
