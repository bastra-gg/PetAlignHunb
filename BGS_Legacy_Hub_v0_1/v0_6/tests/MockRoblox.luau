-- Deterministic client/server fixture. No live Roblox calls or network.
local nativeTypeof=typeof
local now=0
local os=setmetatable({clock=function() return now end,time=function() return 1700000000+now end},{__index=os})
local Vector3={}
local V={}
V.__index=function(v,k)
    if k=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if k=='Unit' then local m=v.Magnitude return Vector3.new(v.X/m,v.Y/m,v.Z/m) end
    return V[k]
end
V.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V.__mul=function(a,b)if type(a)=='number' then a,b=b,a end return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
function Vector3.new(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,_type='Vector3'},V)end
Vector3.zero=Vector3.new()
local Vector2={new=function(x,y) return Vector3.new(x,y,0) end}
Vector2.zero=Vector2.new(0,0)
local CF={}
CF.__index=function(v,k)if k=='UpVector' then return Vector3.new(0,1,0) elseif k=='LookVector' then return Vector3.new(0,0,-1) end return CF[k]end
local CFrame={}
function CFrame.new(x,y,z)return setmetatable({Position=type(x)=='table' and x or Vector3.new(x,y,z),_type='CFrame'},CF)end
CF.__mul=function(a,b)return CFrame.new(a.Position+b.Position)end
CF.__sub=function(a,b)return CFrame.new(a.Position-b)end
function CF:PointToObjectSpace(p)return p-self.Position end
function CF:PointToWorldSpace(p)return p+self.Position end
local function typeof(v)return type(v)=='table' and v._type or nativeTypeof(v)end
local queue={}
local task={}
local function resume(thread,...)
    if coroutine.status(thread)=='dead' then return end
    local ok,delay=coroutine.resume(thread,...)
    assert(ok,delay)
    if coroutine.status(thread)~='dead' then queue[#queue+1]={thread=thread,due=now+(tonumber(delay)or 0.01)} end
end
function task.spawn(fn,...)local thread=type(fn)=='thread' and fn or coroutine.create(fn) resume(thread,...) return thread end
function task.wait(s)return coroutine.yield(s or 0.03)end
function task.cancel(thread)if coroutine.status(thread)~='dead' then coroutine.close(thread) end end
function task.defer(fn,...)local args=table.pack(...) local thread=coroutine.create(function() fn(table.unpack(args,1,args.n))end) queue[#queue+1]={thread=thread,due=now+0.01} return thread end
local function advance(seconds)
    local deadline=now+seconds local guard=0
    while true do
        table.sort(queue,function(a,b)return a.due<b.due end)
        local item=queue[1]
        if not item or item.due>deadline then break end
        table.remove(queue,1) now=item.due guard+=1 assert(guard<10000,'runaway tasks') resume(item.thread)
    end
    now=deadline
end
local function signal()
    local sig={listeners={}}
    function sig:Connect(fn)
        local c={Connected=true,fn=fn}
        function c:Disconnect()self.Connected=false end
        self.listeners[#self.listeners+1]=c return c
    end
    function sig:Fire(...)
        for _,c in ipairs(self.listeners)do if c.Connected then c.fn(...)end end
    end
    return sig
end
local Obj={}
local Instance={}
local workspace
local signals={ChildAdded=true,ChildRemoved=true,DescendantAdded=true,DescendantRemoving=true,CharacterAdded=true,Idled=true,Heartbeat=true,InputBegan=true,InputChanged=true,InputEnded=true,Activated=true,Changed=true}
local function ancestry(o,name,desc)
    while o do local sig=o._signals[name] if sig then sig:Fire(desc)end o=o.Parent end
end
Obj.__index=function(o,k)
    if Obj[k] then return Obj[k]end
    if k=='Position' and o._p.ClassName=='Part' then return o._p.CFrame.Position end
    if k=='AbsolutePosition' then return Vector2.new(10,10) end
    if k=='AbsoluteSize' then return Vector2.new(470,390) end
    if signals[k] then o._signals[k]=o._signals[k] or signal() return o._signals[k]end
    if o._p[k]~=nil then return o._p[k]end
    for _,c in ipairs(o._children)do if c.Name==k then return c end end
end
Obj.__newindex=function(o,k,v)
    if k=='Parent' then
        local old=o._p.Parent
        if old then
            ancestry(old,'DescendantRemoving',o)
            for _,d in ipairs(o:GetDescendants())do ancestry(old,'DescendantRemoving',d)end
            local i=table.find(old._children,o) if i then table.remove(old._children,i)end
        end
        o._p.Parent=v
        if v then
            v._children[#v._children+1]=o ancestry(v,'DescendantAdded',o)
            for _,d in ipairs(o:GetDescendants())do ancestry(v,'DescendantAdded',d)end
        end
    else o._p[k]=v end
end
function Instance.new(class)
    return setmetatable({_p={ClassName=class,Name=class,CFrame=CFrame.new(),Size=Vector3.new(2,2,2),Transparency=0,CanTouch=true,CanCollide=true,Health=100,HipHeight=2,Enabled=true,Visible=true,Text='',HoldDuration=0,MaxActivationDistance=12},_children={},_signals={},_attrs={}},Obj)
end
function Obj:IsA(class)
    return self.ClassName==class or (class=='BasePart' and self.ClassName=='Part') or
        (class=='GuiObject' and ({Frame=true,TextButton=true,TextLabel=true,ScrollingFrame=true})[self.ClassName]) or
        (class=='ValueBase' and self.ClassName:match('Value$')~=nil)
end
function Obj:GetChildren()return table.clone(self._children)end
function Obj:GetDescendants()
    local out={} for _,c in ipairs(self._children)do out[#out+1]=c for _,d in ipairs(c:GetDescendants())do out[#out+1]=d end end return out
end
function Obj:FindFirstChild(name,recursive)
    for _,c in ipairs(self._children)do if c.Name==name then return c end end
    if recursive then for _,c in ipairs(self:GetDescendants())do if c.Name==name then return c end end end
end
function Obj:FindFirstChildWhichIsA(class,recursive)
    for _,c in ipairs(recursive and self:GetDescendants()or self._children)do if c:IsA(class)then return c end end
end
Obj.FindFirstChildOfClass=Obj.FindFirstChildWhichIsA
function Obj:WaitForChild(name)return self:FindFirstChild(name)end
function Obj:IsDescendantOf(parent)local o=self.Parent while o do if o==parent then return true end o=o.Parent end return false end
function Obj:GetAttribute(name)return self._attrs[name]end
function Obj:SetAttribute(name,value)self._attrs[name]=value end
function Obj:GetPropertyChangedSignal(name)self._signals[name]=self._signals[name]or signal() return self._signals[name]end
function Obj:Destroy()self.Parent=nil end
function Obj:MoveTo(pos)self.destination=pos end
function Obj:Move()end
function Obj:InputHoldBegin()self.holding=true end
function Obj:InputHoldEnd()self.holding=false end
function Obj:CaptureController()end
function Obj:Button2Down()end
function Obj:Button2Up()end
local function object(class,name,parent)
    local o=Instance.new(class) o.Name=name o.Parent=parent return o
end
workspace=object('Workspace','Workspace')
local function floor(name,parent,pos,size)
    local p=object('Part',name,parent) p.CFrame=CFrame.new(pos) p.Size=size or Vector3.new(100,4,100) return p
end
local Enum={RaycastFilterType={Include='Include',Exclude='Exclude'}}
local RaycastParams={new=function()return {}end}
function Obj:Raycast(origin,direction,params)
    local candidates=params.FilterType=='Include' and params.FilterDescendantsInstances or self:GetDescendants()
    local best,bestY=nil,-math.huge
    for _,p in ipairs(candidates)do
        local excluded=false
        if params.FilterType=='Exclude'then for _,o in ipairs(params.FilterDescendantsInstances)do if p==o or p:IsDescendantOf(o)then excluded=true end end end
        if p:IsA('BasePart')and p.CanCollide and not excluded then
            local pos=p.Position local top=pos.Y+p.Size.Y/2
            if math.abs(origin.X-pos.X)<=p.Size.X/2 and math.abs(origin.Z-pos.Z)<=p.Size.Z/2 and origin.Y>=top and origin.Y+direction.Y<=top and top>bestY then best=p bestY=top end
        end
    end
    return best and {Position=Vector3.new(origin.X,bestY,origin.Z),Normal=Vector3.new(0,1,0),Instance=best}or nil
end
local RS=object('ReplicatedStorage','ReplicatedStorage')
local player=object('Player','Tester')
local pg=object('PlayerGui','PlayerGui',player)
local character=object('Model','Character',workspace)
local hrp=floor('HumanoidRootPart',character,Vector3.new(0,6,0),Vector3.new(2,2,1))
local human=object('Humanoid','Humanoid',character)
player.Character=character player:SetAttribute('World','Overworld')
local services={Players={LocalPlayer=player},ReplicatedStorage=RS,RunService={Heartbeat=signal()},UserInputService=object('Input','Input'),VirtualUser=object('VirtualUser','VirtualUser')}
local game={PlaceId=123,IsLoaded=function()return true end,GetService=function(_,name)assert(services[name],name)return services[name]end}
local localEnv={}
local function getgenv()return localEnv end
local function setclipboard()end
local function firetouchinterest()end
local function fireproximityprompt()end
local data={PETS={},EGGS_OPENED=0,SPIN_TO_WIN=0}
local requestLog={}
local rejectChest=false local rejectEgg=false local worldDelay=0 local hangData=false
local assets=object('Folder','Assets',RS) local mods=object('Folder','Modules',assets)
local lib=object('Folder','Library',mods) local itemMods=object('Folder','ItemDataService',mods)
local function mod(parent,name,value)local m=object('ModuleScript',name,parent)m.export=value return m end
mod(lib,'index',{PETS='PETS',EGGS_OPENED='EGGS_OPENED',SPIN_TO_WIN='SPIN_TO_WIN'})
mod(itemMods,'EggModule',{['Basic Egg']={Cost={'Coins',10},World='Overworld'}})
mod(itemMods,'SpinToWinModule',{GetHalfDay=function()return 99 end})
local function require(m)return m.export end
local screen=object('ScreenGui','ScreenGui',pg)
local client=object('LocalScript','ClientScript',screen) local clientMods=object('Folder','Modules',client)
local worlds=object('Folder','Worlds',workspace) local floating=object('Folder','FloatingIslands',workspace)
local worldPositions={Overworld=0,['Candy Land']=1000,['Toy Land']=2000,['Beach World']=3000,Atlantis=4000,['Rainbow Land']=5000,Underworld=6000,['Mystic Forest']=7000,Heaven=8000}
for name,x in pairs(worldPositions)do
    local w=object('Model',name,worlds) floor('Ground',w,Vector3.new(x,0,0))
    object('Folder',name,floating)
end
mod(clientMods,'WorldService',{SetWorld=function(_,name)
    if worldDelay>0 then task.wait(worldDelay)end
    player:SetAttribute('World',name)hrp.CFrame=CFrame.new(worldPositions[name],6,0)
end})
local island=object('Model','The Floating Island',floating.Overworld)
local islandFloor=floor('Collision',island,Vector3.new(0,100,0))
local chest=object('Model','Chest',island)
local regen=object('BillboardGui','Regen',chest)regen.Enabled=false
local fast=object('Model','FastSpawn',chest)
local touch=floor('Ignore',fast,Vector3.new(0,105,0),Vector3.new(3,3,3))touch.CanCollide=false
local pickups=object('Folder','Pickups',workspace)
local nested=object('Folder','Coins',pickups)
local coinModel=object('Model','Coin1',nested)
local coin=floor('Hitbox',coinModel,Vector3.new(15,5,0),Vector3.new(2,2,2))coin.CanCollide=false
object('TouchTransmitter','TouchInterest',coin)
local eggFolder=object('Folder','Eggs',workspace)
local egg=object('Model','Basic Egg',eggFolder)
local hot=floor('Hotkey',egg,Vector3.new(0,5,10),Vector3.new(2,2,2))hot.CanCollide=false
local brewingFrame=object('Frame','BrewingFrame',screen)local brewing=object('Frame','Brewing',brewingFrame)
for i=1,3 do
    local slot=object('Frame','Brew'..i,brewing)
    object('Frame','Empty',slot).Visible=true
    local active=object('Frame','Brewing',slot)active.Visible=false
    object('TextButton','Skip',active).Visible=false
    object('TextLabel','ItemName',active).Text=''
end
object('Model','MatchThePet',workspace)
local remote=object('RemoteEvent','NetworkRemoteEvent',RS)
local remoteFn=object('RemoteFunction','NetworkRemoteFunction',RS)
local function record(action,...)requestLog[#requestLog+1]={action=action,args=table.pack(...),time=now}end
remote.FireServer=function(_,action,...)
    local args=table.pack(...)record(action,...)
    if action=='CollectChestReward' and not rejectChest then regen.Enabled=true
    elseif action=='PurchaseEgg' and not rejectEgg then data.EGGS_OPENED+=(args[2]=='Multi'and 3 or 1)
    elseif action=='BrewPotion' then
        for i=1,3 do local slot=brewing['Brew'..i] if slot.Empty.Visible then slot.Empty.Visible=false slot.Brewing.Visible=true slot.Brewing.Skip.Visible=true slot.Brewing.ItemName.Text='Recipe'..args[1]break end end
    elseif action=='ClaimPotion' then local slot=brewing['Brew'..args[1]]slot.Empty.Visible=true slot.Brewing.Visible=false
    end
end
local serverFirst=nil local serverMatched={}
remoteFn.InvokeServer=function(_,action,...)
    record(action,...)
    if action=='GetPlayerData' then if hangData then task.wait(100)end return table.clone(data)end
    if action=='MatchThePet'then
        local index=... local pet=math.ceil(index/2)
        if serverFirst then
            local match=math.ceil(serverFirst/2)==pet
            if match then serverMatched[index]=true serverMatched[serverFirst]=true end
            serverFirst=nil
            local count=0 for _ in pairs(serverMatched)do count+=1 end
            return pet,count==18 and 'complete'or(match and 'match'or 'mismatch')
        end
        serverFirst=index return pet,'first'
    end
end
local function requests(action)local n=0 for _,r in ipairs(requestLog)do if r.action==action then n+=1 end end return n end

-- Minimal GUI value types for construction / interaction smoke checks.
local Color3={fromRGB=function(r,g,b)return {r,g,b}end}
local UDim={new=function(scale,offset)return {Scale=scale or 0,Offset=offset or 0}end}
local UDim2={}
function UDim2.new(a,b,c,d)return {X=UDim.new(a,b),Y=UDim.new(c,d)}end
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
setmetatable(Enum,{__index=function(self,key)
    local group=setmetatable({},{__index=function(_,name)return name end})rawset(self,key,group)return group
end})
