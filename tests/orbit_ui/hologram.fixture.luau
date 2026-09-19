-- Small Roblox boundary double; exercises the complete HUD mount/render/input
-- lifecycle. It is not a substitute for a live Roblox device check.
local signals={}
local function signal()
    local s={listeners={}}
    function s:Connect(callback)
        local c={Connected=true,callback=callback}
        function c:Disconnect()self.Connected=false end
        table.insert(self.listeners,c);return c
    end
    function s:Fire(...)
        for _,c in ipairs(self.listeners)do if c.Connected then c.callback(...)end end
    end
    table.insert(signals,s);return s
end
local vector={}
vector.__index=vector
local Vector3={}
function Vector3.new(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vector)end
function vector.__unm(a)return Vector3.new(-a.X,-a.Y,-a.Z)end
function vector.__add(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
function vector.__sub(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
function vector.__mul(a,n)return Vector3.new(a.X*n,a.Y*n,a.Z*n)end
function vector:Dot(b)return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
local Vector2={new=Vector3.new}
local CFrame={}
local cf={};cf.__index=cf
function CFrame.fromMatrix(p,r,u,b)return setmetatable({Position=p,RightVector=r,UpVector=u,BackVector=b,LookVector=-b},cf)end
function CFrame.new(x,y,z)
    local p=type(x)=="table"and x or Vector3.new(x,y,z)
    return CFrame.fromMatrix(p,Vector3.new(1,0,0),Vector3.new(0,1,0),Vector3.new(0,0,1))
end
function CFrame.Angles(_,y,_)
    return CFrame.fromMatrix(Vector3.new(),Vector3.new(math.cos(y),0,-math.sin(y)),Vector3.new(0,1,0),Vector3.new(math.sin(y),0,math.cos(y)))
end
function cf:VectorToWorldSpace(v)return self.RightVector*v.X+self.UpVector*v.Y+self.BackVector*v.Z end
function cf:PointToObjectSpace(v)return self:VectorToObjectSpace(v-self.Position)end
function cf:VectorToObjectSpace(v)return Vector3.new(v:Dot(self.RightVector),v:Dot(self.UpVector),v:Dot(self.BackVector))end
function cf.__mul(a,b)return CFrame.fromMatrix(a.Position+a:VectorToWorldSpace(b.Position),a:VectorToWorldSpace(b.RightVector),a:VectorToWorldSpace(b.UpVector),a:VectorToWorldSpace(b.BackVector))end
local UDim={new=function(s,o)return {Scale=s,Offset=o}end}
local UDim2={}
function UDim2.new(xs,xo,ys,yo)return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)}end
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
local Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local ColorSequence={new=function(...)return {...}end}
local NumberSequence={new=function(...)return {...}end}
local Enum={Font={Gotham="Gotham",GothamBold="GothamBold"},TextXAlignment={Left="Left",Center="Center"},TextYAlignment={Center="Center"},TextTruncate={AtEnd="AtEnd",None="None"},NormalId={Back="Back"},SurfaceGuiSizingMode={FixedSize="FixedSize"},ZIndexBehavior={Sibling="Sibling"},UserInputType={MouseButton1="MouseButton1",Touch="Touch",MouseMovement="MouseMovement"},UserInputState={Begin="Begin",End="End",Cancel="Cancel",Change="Change"},ContextActionResult={Pass="Pass",Sink="Sink"},RenderPriority={Camera={Value=200}},KeyCode={RightShift="RightShift"}}
local objects={}
local node={};node.__index=node
function node:IsA(class)return self.ClassName==class or class=="GuiButton"and self.ClassName=="TextButton"end
function node:GetPropertyChangedSignal(key)
 self.propertySignals=self.propertySignals or {};self.propertySignals[key]=self.propertySignals[key]or signal();return self.propertySignals[key]
end
function node:GetDescendants()
 local result={};local function walk(parent)for _,child in ipairs(parent:GetChildren())do table.insert(result,child);walk(child)end end
 walk(self);return result
end
function node:GetChildren()
    local children={};for _,o in ipairs(objects)do if o.Parent==self then table.insert(children,o)end end;return children
end
function node:FindFirstChild(name)
    for _,o in ipairs(self:GetChildren())do if o.Name==name then return o end end
end
function node:FindFirstChildOfClass(class)
    for _,o in ipairs(self:GetChildren())do if o.ClassName==class then return o end end
end
function node:FindFirstAncestorWhichIsA(class)
 local ancestor=self.Parent;while ancestor do if ancestor:IsA(class)then return ancestor end;ancestor=ancestor.Parent end
end
function node:IsDescendantOf(target)
 local ancestor=self.Parent;while ancestor do if ancestor==target then return true end;ancestor=ancestor.Parent end;return false
end
function node:FindFirstAncestorOfClass(class)return self:FindFirstAncestorWhichIsA(class)end
function node:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
function node:Destroy()
    for _,o in ipairs(self:GetChildren())do o:Destroy()end
    self.Parent=nil;self.destroyed=true
end
function node:GetGuiObjectsAtPosition()return self.hitObjects or {}end
local Instance={}
function Instance.new(class)
    local o=setmetatable({ClassName=class,Name=class,DisplayOrder=0,TextSize=14,InputBegan=signal(),FocusLost=signal(),Activated=signal(),MouseButton1Click=signal(),MouseEnter=signal(),MouseLeave=signal(),Active=class=="TextButton",Size=UDim2.fromOffset(100,100),Position=UDim2.fromOffset(0,0)},node)
    table.insert(objects,o);return o
end
local run={bindings={}}
function run:BindToRenderStep(name,priority,callback)self.bindings[name]=callback end
function run:UnbindFromRenderStep(name)self.bindings[name]=nil end
function run:Step(dt)for _,callback in pairs(self.bindings)do callback(dt or 1/60)end end
local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal()}
function input:GetFocusedTextBox()return self.focus end
local actions={bindings={}}
function actions:BindActionAtPriority(name,callback)self.bindings[name]=callback end
function actions:UnbindAction(name)self.bindings[name]=nil end
local guiService={MenuIsOpen=false}
local TweenInfo={new=function(...)return {...}end}
local tweens={}
local tweenService={}
function tweenService:Create(object,info,target)
 local tween={target=target,object=object}
 function tween:Play()self.played=true;for key,value in pairs(self.target)do self.object[key]=value end end
 function tween:Cancel()self.cancelled=true end
 table.insert(tweens,tween);return tween
end
Enum.EasingStyle={Quad="Quad"};Enum.EasingDirection={Out="Out"};Enum.ScrollingDirection={X="X"}
Enum.ScreenInsets={None="None"}
Enum.AutomaticSize={Y="Y"}
Enum.ApplyStrokeMode={Border="Border"}
local game={}
local players={}
function game:GetService(name)return assert(({Players=players,RunService=run,UserInputService=input,ContextActionService=actions,GuiService=guiService,TweenService=tweenService})[name],name)end
local camera={CFrame=CFrame.new(0,0,20),ViewportSize=Vector3.new(1536,864),FieldOfView=70}
function camera:ScreenPointToRay(x,y)
    -- The fixture's screen coordinates are points on z=0, for exact click tests.
    return {Origin=Vector3.new(x,y,20),Direction=Vector3.new(0,0,-1)}
end
function camera:WorldToScreenPoint(position)return Vector3.new(768+position.X,432-position.Y,20),true end
function camera:WorldToViewportPoint(position)
 self.projectionCount=(self.projectionCount or 0)+1
 local point=self.CFrame:PointToObjectSpace(position);local depth=-point.Z
 local focal=self.ViewportSize.Y/(2*math.tan(math.rad(self.FieldOfView/2)))
 local x,y=self.ViewportSize.X/2+point.X*focal/depth,self.ViewportSize.Y/2-point.Y*focal/depth
 return Vector3.new(x,y,depth),depth>0 and x>=0 and x<=self.ViewportSize.X and y>=0 and y<=self.ViewportSize.Y
end
local workspace={CurrentCamera=camera}
local delayed={}
local task={spawn=function(callback)callback()end,delay=function(_,callback)table.insert(delayed,callback)end}
local player=Instance.new("Player");player.UserId=17;players.LocalPlayer=player
local playerGui=Instance.new("PlayerGui");playerGui.Parent=player
local character=Instance.new("Model");player.Character=character
local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Parent=character;root.Position=Vector3.new();root.Size=Vector3.new(2,2,1)
local humanoid=Instance.new("Humanoid");humanoid.HipHeight=2;humanoid.Parent=character
local function ref()
    local enabled=false
    return {Get=function()return enabled end,Set=function(value,silent)assert(silent==false);enabled=value end}
end
local runtime={alive=true,language="ru",leverRefs={train={Weight=ref()},autoRebirth=ref(),machineFarm=ref(),bossCycle=ref()},sessionStatsStartedAt=os.clock()-90,sessionStrengthCurrent=1500,sessionStrengthGained=100,sessionRebirthGained=2,sessionRebirthCurrent=12,pingMs=48,pingAvailable=true,rebirthGoalEnabled=true,rebirthGoal=100,status="Тренажёр готов"}
function runtime.equippedPetState()return {},3,2,{{Name="Rare Golem"},{Name="Darkstar Hunter"}}end
function runtime.teleportToIsland(id)runtime.lastTeleport=id;return true end
local env={}
local classic=Instance.new("ScreenGui");classic.Enabled=true
local errors={}
local opened
local options={player=player,env=env,classicGui=classic,report=function(message)table.insert(errors,message)end,openClassic=function(tab)opened=tab;classic.Enabled=true end}

local q=runtime
q.uiRoot=classic
local n7=Instance.new("Frame");n7.Parent=classic
local n_=Instance.new("TextButton");n_.Parent=classic
local nG=Instance.new("TextButton");nG.Parent=n7
local nL=Instance.new("Frame");nL.Parent=n7
local nM=Instance.new("Frame");nM.Parent=n7
local p0=Instance.new("TextButton");p0.Parent=n7
local nT=Instance.new("ScrollingFrame");local nU=Instance.new("ScrollingFrame")
local nV=Instance.new("ScrollingFrame");local nW=Instance.new("ScrollingFrame")
local nX=Instance.new("ScrollingFrame");local nY=Instance.new("ScrollingFrame")
q.layoutUI={hologramDeleteOverlay=Instance.new("TextButton")}
for _,id in ipairs({"boss","egg","teleport","quest","system","interface"})do q.layoutUI[id.."Page"]=Instance.new("ScrollingFrame")end
q.controlHits={}
local initialPages={bug=nT,farm=nU,train=nV,reb=nW,kill=nX,crystal=nY,boss=q.layoutUI.bossPage,egg=q.layoutUI.eggPage,teleport=q.layoutUI.teleportPage,quest=q.layoutUI.questPage,system=q.layoutUI.systemPage,interface=q.layoutUI.interfacePage}
for id,page in pairs(initialPages)do
 page.Parent=n7
 local control=Instance.new("TextButton");control.Name="OriginalControl";control.Parent=page
 control.Activated:Connect(function()q.controlHits[id]=(q.controlHits[id]or 0)+1 end)
end
local sL=false
local function sR(tab)
 for id,page in pairs(initialPages)do page.Visible=id==tab end
 opened=tab
end
function q.closePicker()p0.Visible=false end
function q.closeDeleteConfirmation()q.layoutUI.hologramDeleteOverlay.Visible=false end
q.leverRefs.bug=ref();q.leverRefs.crystal={crystal=ref()};q.leverRefs.proteinEgg=ref();q.leverRefs.autoQuest=ref()
q.leverRefs.kill={all=ref(),whitelist=ref(),blacklist=ref()}

local function jT()q.stoppedModes=true end
