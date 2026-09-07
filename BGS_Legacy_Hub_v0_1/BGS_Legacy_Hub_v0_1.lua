-- BGS Legacy Hub v0.1.1 SAFE
-- For the user's own Bubble Gum Simulator-style game/server.
-- Safety layer: no teleports, no anti-cheat bypass, remote budget, distance checks,
-- respawn grace, error backoff and automatic hard stop after repeated failures.

local VERSION="0.1.1-safe"
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
if not game:IsLoaded() then game.Loaded:Wait() end
local LP=Players.LocalPlayer
local PG=LP:WaitForChild("PlayerGui")

local env=type(getgenv)=="function" and getgenv() or _G
if env.BGSLegacy and env.BGSLegacy.Stop then pcall(function() env.BGSLegacy:Stop() end) end

local S={
 alive=true,
 safeMode=true,
 autoBubble=false,
 autoHatch=false,
 walkToEgg=false,
 autoCollect=false,
 selectedEgg=nil,
 eggs={},
 eggIndex=1,
 collectRadius=140,
 status="SAFE готово",
 conns={},
 failures=0,
 maxFailures=5,
 pausedUntil=0,
 respawnGraceUntil=0,
 remoteTimes={},
 maxRemotePerSecond=7,
 lastFire={},
 lastMove=0,
 moveDelay=.28,
}
env.BGSLegacy=S

local function root()
 local c=LP.Character return c and c:FindFirstChild("HumanoidRootPart")
end
local function hum()
 local c=LP.Character return c and c:FindFirstChildOfClass("Humanoid")
end
local function characterReady()
 local h=hum() local r=root()
 return h and r and h.Health>0
end

local function stopAutomation(reason)
 S.autoBubble=false
 S.autoHatch=false
 S.walkToEgg=false
 S.autoCollect=false
 S.status="SAFE STOP: "..tostring(reason or "manual")
end

local function fail(reason)
 S.failures=S.failures+1
 S.status="ошибка "..S.failures.."/"..S.maxFailures..": "..tostring(reason)
 S.pausedUntil=os.clock()+math.min(4,0.8*S.failures)
 if S.failures>=S.maxFailures then stopAutomation("слишком много ошибок") end
end
local function success()
 if S.failures>0 then S.failures=math.max(0,S.failures-1) end
end

local function net()
 local n=RS:FindFirstChild("NetworkRemoteEvent")
 if n and n:IsA("RemoteEvent") then return n end
 for _,v in ipairs(RS:GetDescendants()) do
  if v:IsA("RemoteEvent") and string.lower(v.Name):find("network",1,true) then return v end
 end
end
local Network=net()

local function pruneBudget(now)
 local out={}
 for _,t in ipairs(S.remoteTimes) do if now-t<1 then out[#out+1]=t end end
 S.remoteTimes=out
end
local function budgetOK(now)
 pruneBudget(now)
 return #S.remoteTimes<S.maxRemotePerSecond
end

local function fire(action,delay,...)
 local now=os.clock()
 if now<S.pausedUntil or now<S.respawnGraceUntil then return false end
 if not characterReady() then return false end
 Network=Network and Network.Parent and Network or net()
 if not Network then fail("NetworkRemoteEvent не найден") return false end
 if now-(S.lastFire[action] or 0)<delay then return false end
 if S.safeMode and not budgetOK(now) then
  S.status="SAFE: лимит remote/sec"
  return false
 end
 S.lastFire[action]=now
 if S.safeMode then S.remoteTimes[#S.remoteTimes+1]=now end
 local ok,e=pcall(function() Network:FireServer(action,...) end)
 if not ok then fail(e) return false end
 success()
 return true
end

local function hotkey(egg)
 if not egg then return nil end
 local h=egg:FindFirstChild("Hotkey",true)
 if h and h:IsA("BasePart") then return h end
 if h and h:IsA("Attachment") and h.Parent and h.Parent:IsA("BasePart") then return h.Parent end
 return egg:IsA("BasePart") and egg or egg:FindFirstChildWhichIsA("BasePart",true)
end

local function scanEggs()
 local f=workspace:FindFirstChild("Eggs")
 local a={}
 if f then
  for _,e in ipairs(f:GetChildren()) do if hotkey(e) then a[#a+1]=e.Name end end
 end
 table.sort(a)
 S.eggs=a
 if #a>0 then
  local found=false
  for i,n in ipairs(a) do if n==S.selectedEgg then S.eggIndex=i found=true break end end
  if not found then S.eggIndex=1 S.selectedEgg=a[1] end
  S.status="SAFE | яиц найдено: "..#a
 else
  S.selectedEgg=nil
  S.status="workspace.Eggs не найден/пуст"
 end
end

local function selectedEgg()
 local f=workspace:FindFirstChild("Eggs")
 return f and S.selectedEgg and f:FindFirstChild(S.selectedEgg)
end
local function dist(p)
 local r=root() return r and p and (r.Position-p.Position).Magnitude or math.huge
end

local function moveTo(pos)
 local now=os.clock()
 if now<S.pausedUntil or now<S.respawnGraceUntil then return false end
 if now-S.lastMove<S.moveDelay then return false end
 local h=hum() local r=root()
 if not h or not r or h.Health<=0 then return false end
 if S.safeMode and (pos-r.Position).Magnitude>S.collectRadius+35 then
  S.status="SAFE: цель слишком далеко"
  return false
 end
 S.lastMove=now
 local ok,e=pcall(function() h:MoveTo(pos) end)
 if not ok then fail(e) return false end
 return true
end

local function nearestPickup()
 local f=workspace:FindFirstChild("Pickups")
 local r=root()
 if not f or not r then return end
 local best,bd=nil,S.collectRadius
 for _,v in ipairs(f:GetChildren()) do
  if v:IsA("BasePart") and v.Transparency<1 then
   local d=(r.Position-v.Position).Magnitude
   local n=string.lower(v.Name)
   if d<bd and (v:FindFirstChild("TouchInterest") or v.Name=="Part" or n:find("coin",1,true) or n:find("gem",1,true) or n:find("pickup",1,true)) then
    best,bd=v,d
   end
  end
 end
 return best,bd
end

-- UI ----------------------------------------------------------------------
local old=PG:FindFirstChild("BGSLegacyHub") if old then old:Destroy() end
local g=Instance.new("ScreenGui",PG) g.Name="BGSLegacyHub" g.ResetOnSpawn=false
local m=Instance.new("Frame",g) m.Size=UDim2.fromOffset(390,392) m.Position=UDim2.new(.5,-195,.5,-196)
m.BackgroundColor3=Color3.fromRGB(16,17,22) m.BorderSizePixel=0 m.Active=true
local c=Instance.new("UICorner",m) c.CornerRadius=UDim.new(0,14)
local st=Instance.new("UIStroke",m) st.Color=Color3.fromRGB(84,105,255)
local h=Instance.new("Frame",m) h.Size=UDim2.new(1,0,0,48) h.BackgroundColor3=Color3.fromRGB(24,25,33) h.BorderSizePixel=0
local hc=Instance.new("UICorner",h) hc.CornerRadius=UDim.new(0,14)
local t=Instance.new("TextLabel",h) t.BackgroundTransparency=1 t.Position=UDim2.fromOffset(13,0) t.Size=UDim2.new(1,-60,1,0)
t.Text="BGS LEGACY HUB  "..VERSION t.TextColor3=Color3.fromRGB(245,245,250) t.Font=Enum.Font.GothamBold t.TextSize=15 t.TextXAlignment=Enum.TextXAlignment.Left
local close=Instance.new("TextButton",h) close.Size=UDim2.fromOffset(32,30) close.Position=UDim2.new(1,-40,0,9)
close.Text="×" close.TextSize=19 close.BackgroundColor3=Color3.fromRGB(45,47,60) close.TextColor3=Color3.new(1,1,1)
local cc=Instance.new("UICorner",close) cc.CornerRadius=UDim.new(0,8)
local status=Instance.new("TextLabel",m) status.BackgroundTransparency=1 status.Position=UDim2.fromOffset(13,52) status.Size=UDim2.new(1,-26,0,34)
status.TextColor3=Color3.fromRGB(180,184,200) status.Font=Enum.Font.Gotham status.TextSize=11 status.TextXAlignment=Enum.TextXAlignment.Left status.TextWrapped=true

local body=Instance.new("Frame",m) body.BackgroundTransparency=1 body.Position=UDim2.fromOffset(12,91) body.Size=UDim2.new(1,-24,1,-103)
local lay=Instance.new("UIListLayout",body) lay.Padding=UDim.new(0,7)
local redraw={}
local function round(x) local u=Instance.new("UICorner",x) u.CornerRadius=UDim.new(0,9) end
local function toggle(label,key)
 local b=Instance.new("TextButton",body) b.Size=UDim2.new(1,0,0,36) b.Text="" b.BackgroundColor3=Color3.fromRGB(31,33,42) round(b)
 local l=Instance.new("TextLabel",b) l.BackgroundTransparency=1 l.Position=UDim2.fromOffset(10,0) l.Size=UDim2.new(1,-70,1,0)
 l.Text=label l.TextColor3=Color3.fromRGB(235,236,244) l.Font=Enum.Font.GothamMedium l.TextSize=13 l.TextXAlignment=Enum.TextXAlignment.Left
 local r=Instance.new("TextLabel",b) r.BackgroundTransparency=1 r.Position=UDim2.new(1,-55,0,0) r.Size=UDim2.fromOffset(45,36) r.Font=Enum.Font.GothamBold r.TextSize=12
 local function draw() r.Text=S[key] and "ON" or "OFF" r.TextColor3=S[key] and Color3.fromRGB(108,132,255) or Color3.fromRGB(145,145,155) end
 b.Activated:Connect(function() S[key]=not S[key] draw() end) redraw[key]=draw draw()
end
local function action(text,cb)
 local b=Instance.new("TextButton",body) b.Size=UDim2.new(1,0,0,36) b.Text=text b.BackgroundColor3=Color3.fromRGB(38,40,52)
 b.TextColor3=Color3.fromRGB(239,240,248) b.Font=Enum.Font.GothamBold b.TextSize=12 round(b) b.Activated:Connect(cb) return b
end

toggle("SAFE MODE","safeMode")
toggle("Авто надувание","autoBubble")
toggle("Авто открытие яйца","autoHatch")
toggle("Самому идти к яйцу","walkToEgg")
toggle("Авто сбор монет / валюты","autoCollect")
local eggBtn
eggBtn=action("ЯЙЦО: скан...",function()
 if #S.eggs==0 then scanEggs() end
 if #S.eggs>0 then S.eggIndex=(S.eggIndex%#S.eggs)+1 S.selectedEgg=S.eggs[S.eggIndex] eggBtn.Text="ЯЙЦО: "..S.selectedEgg end
end)
action("ПЕРЕСКАНИРОВАТЬ ЯЙЦА",function() scanEggs() eggBtn.Text=S.selectedEgg and ("ЯЙЦО: "..S.selectedEgg) or "ЯЙЦО: не найдено" end)
action("HARD STOP",function()
 stopAutomation("manual")
 for _,k in ipairs({"autoBubble","autoHatch","walkToEgg","autoCollect"}) do if redraw[k] then redraw[k]() end end
end)

local dragging,ds,sp=false,nil,nil
h.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true ds=i.Position sp=m.Position end end)
S.conns[#S.conns+1]=UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
S.conns[#S.conns+1]=UIS.InputChanged:Connect(function(i)
 if dragging and ds and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
  local d=i.Position-ds m.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
 end
end)

local lb,lh,lc=0,0,0
S.conns[#S.conns+1]=Run.Heartbeat:Connect(function()
 if not S.alive then return end
 local n=os.clock()
 status.Text=S.status.." | remote "..(Network and "OK" or "нет").." | eggs "..#S.eggs.." | failures "..S.failures
 if n<S.pausedUntil or n<S.respawnGraceUntil then return end

 if S.autoBubble and n-lb>=.20 then
  lb=n
  if fire("BlowBubble",.20) then S.status="SAFE | надуваю" end
 end

 if S.autoHatch and n-lh>=.65 then
  lh=n
  if not S.selectedEgg then scanEggs() end
  local e=selectedEgg() local p=hotkey(e)
  if p then
   local d=dist(p)
   -- The original BGS scripts also required being close to the egg; enforce it here.
   if d<=14.5 then
    if fire("PurchaseEgg",.65,S.selectedEgg) then S.status="SAFE | открываю "..S.selectedEgg end
   elseif S.walkToEgg then
    -- egg walk gets a slightly larger safe movement allowance without teleporting
    local oldRadius=S.collectRadius
    S.collectRadius=math.max(S.collectRadius,math.min(300,d+5))
    moveTo(p.Position)
    S.collectRadius=oldRadius
    S.status="иду к "..S.selectedEgg.." | "..math.floor(d).." studs"
   else
    S.status="подойди к "..S.selectedEgg.." ("..math.floor(d).." studs)"
   end
  end
 end

 if S.autoCollect and n-lc>=.30 then
  lc=n
  local p,d=nearestPickup()
  if p then
   moveTo(p.Position)
   S.status="SAFE | собираю валюту ("..math.floor(d).." studs)"
  else
   S.status="валюта рядом не найдена"
  end
 end
end)

S.conns[#S.conns+1]=LP.CharacterAdded:Connect(function()
 S.respawnGraceUntil=os.clock()+2.5
 S.pausedUntil=S.respawnGraceUntil
 S.status="SAFE: пауза после респавна"
end)

function S:Stop()
 if not self.alive then return end
 stopAutomation("closed")
 self.alive=false
 for _,x in ipairs(self.conns) do pcall(function() x:Disconnect() end) end
 pcall(function() g:Destroy() end)
end
close.Activated:Connect(function() S:Stop() end)

task.delay(.7,function()
 Network=net()
 scanEggs()
 eggBtn.Text=S.selectedEgg and ("ЯЙЦО: "..S.selectedEgg) or "ЯЙЦО: не найдено"
 if not Network then S.status="NetworkRemoteEvent не найден — нужна диагностика копии" end
end)

print("BGS Legacy Hub "..VERSION.." loaded")
return S
