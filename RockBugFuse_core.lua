-- RockBugFuse core contract: 1
local a=game:GetService("Players")
if not game:IsLoaded()then game.Loaded:Wait()end
local b=a.LocalPlayer
while not b do task.wait()b=a.LocalPlayer end
local c=b.Character or b.CharacterAdded:Wait()
local d=c:WaitForChild("HumanoidRootPart",15)
if not d then error("RockBugFuse: HumanoidRootPart not found",0)end
local e=_G
if type(getgenv)=="function"then local f,g=pcall(getgenv)if f and type(g)=="table"then e=g end end
if e.RockBugFuseBusy then return{startupReady=true,busy=true}end
e.RockBugFuseBusy=true
local function h(v)return string.lower(tostring(v or""))end
local function i(v)local s=h(v)return s:find("fuse",1,true)or s:find("fusion",1,true)or s:find("fusing",1,true)or s:find("merge",1,true)or s:find("combine",1,true)or s:find("слияни",1,true)or s:find("объедин",1,true)or s:find("фьюз",1,true)or s:find("фуз",1,true)end
local function j(v)local s=h(v)if i(s)then return 220 end;if s:find("craft",1,true)and(s:find("machine",1,true)or s:find("station",1,true)or s:find("pet",1,true))then return 150 end;if(s:find("pet",1,true)or s:find("питом",1,true))and(s:find("machine",1,true)or s:find("station",1,true)or s:find("машин",1,true))then return 90 end;return 0 end
local function k(x)local t={}local function q(v)if v and v~=""then t[#t+1]=tostring(v)end end;q(x.Name)if x:IsA("ProximityPrompt")then pcall(function()q(x.ActionText)q(x.ObjectText)end)end;local p=x.Parent;for _=1,6 do if not p or p==workspace then break end;q(p.Name)p=p.Parent end;return table.concat(t," ")end
local function l(x)local y=x;for _=1,8 do if not y or y==workspace then break end;local z=nil;if y:IsA("Attachment")then local ok,v=pcall(function()return y.WorldCFrame end)if ok then z=v end elseif y:IsA("BasePart")then z=y.CFrame elseif y:IsA("Model")then local ok,v=pcall(function()return y:GetPivot()end)if ok then z=v end end;if z then return z end;y=y.Parent end;return nil end
local function m()local ok,all=pcall(function()return workspace:GetDescendants()end)if not ok then return nil,nil end;local bp,bs,bn,bns=nil,-1,nil,-1;for n,x in ipairs(all)do if n>18000 then break end;if x:IsA("ProximityPrompt")or x:IsA("Model")or x:IsA("BasePart")or x:IsA("Attachment")then local s=j(k(x));if s>0 then if x:IsA("ProximityPrompt")then s=s+220;if x.Enabled then s=s+25 end;if s>bs then bp,bs=x,s end else if x:IsA("Model")then s=s+35 elseif x:IsA("BasePart")then s=s+20 end;if s>bns then bn,bns=x,s end end end end end;return bp,bn end
local function n(x)local cf=l(x)if not cf then return false end;d.Anchored=false;d.CFrame=cf*CFrame.new(0,3,-4);d.AssemblyLinearVelocity=Vector3.new(0,0,0);d.AssemblyAngularVelocity=Vector3.new(0,0,0);return true end
local function o(origin)local best,dist=nil,math.huge;local ok,all=pcall(function()return workspace:GetDescendants()end)if not ok then return nil end;for _,x in ipairs(all)do if x:IsA("ProximityPrompt")then local cf=l(x)if cf then local q=(d.Position-cf.Position).Magnitude;local s=j(k(x));if q<=18 and(s>0 or q<dist)then local rank=q-(s>0 and 12 or 0);if rank<dist then best,dist=x,rank end end end end end;return best end
local function p(x)if not x or not x.Parent then return false end;local ok=false;if type(fireproximityprompt)=="function"then ok=pcall(function()fireproximityprompt(x,0)end)end;if not ok then ok=pcall(function()x:InputHoldBegin()task.wait(math.max(0.05,tonumber(x.HoldDuration)or 0)+0.03)x:InputHoldEnd()end)end;return ok end
local success,err=xpcall(function()local prompt,node=nil,nil;for _=1,12 do prompt,node=m()if prompt or node then break end;task.wait(0.25)end;if prompt then n(prompt)elseif node then n(node)else error("RockBugFuse: fusion machine not found",0)end;task.wait(0.45);if not prompt or not prompt.Parent then prompt=o(node)end;if not prompt then error("RockBugFuse: combine prompt not found",0)end;if not p(prompt)then error("RockBugFuse: prompt press failed",0)end;return true end,function(x)return tostring(x)end)
e.RockBugFuseBusy=nil
if not success then warn("[RockBugFuse] "..tostring(err))return{startupReady=true,success=false,error=tostring(err)}end
return{startupReady=true,success=true}
