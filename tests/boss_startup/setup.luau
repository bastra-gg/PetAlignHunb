Enum.Font.GothamMedium='GothamMedium'
Vector3.zero=Vector3.new()
local threads={}
local task={}
local function resume(thread,...)
 local ok,err=coroutine.resume(thread,...)
 assert(ok,err)
end
function task.spawn(fn,...)
 local thread=coroutine.create(fn);threads[#threads+1]=thread;resume(thread,...);return thread
end
function task.wait(seconds)return coroutine.yield(seconds or 0.03)end
function task.defer(fn,...)return task.spawn(fn,...)end
function task.delay(seconds,fn,...)
 local args=table.pack(...)
 return task.spawn(function()task.wait(seconds);fn(table.unpack(args,1,args.n))end)
end
function task.cancel(thread)if coroutine.status(thread)~='dead' then coroutine.close(thread)end end
local run={Heartbeat=signal(),RenderStepped=signal()}
local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal()}
local players=Instance.new('Players')
local player=Instance.new('Player');player.Name='Fixture';player.UserId=17;player.CharacterRemoving=signal();player.CharacterAdded=signal();player.Parent=players;players.LocalPlayer=player
function players:GetPlayers()return {player}end
local playerGui=Instance.new('PlayerGui');playerGui.Parent=player
local character=Instance.new('Model');player.Character=character
local humanoid=Instance.new('Humanoid');humanoid.Health=100;humanoid.Parent=character
function node:FindFirstChildWhichIsA(class)return self:FindFirstChildOfClass(class)end
function node:GetAttribute()return nil end
local workspace=Instance.new('Workspace')
workspace.CurrentCamera=Instance.new('Camera');workspace.CurrentCamera.ViewportSize=Vector3.new(1280,720)
local storage=Instance.new('ReplicatedStorage')
local http={}
function http:JSONEncode(data)return 'json' end
function http:JSONDecode(raw)
 if raw=='valid' then return {ok=true,user_id=17}end
 if raw=='invalid' then return {error='invalid'}end
 error('invalid json')
end
local notices={}
local starter={SetCore=function(_,_,data)notices[#notices+1]=data end}
local game={PlaceId=3623096087,JobId='test',Loaded=signal()}
function game:IsLoaded()return true end
function game:GetService(name)return assert(({Players=players,RunService=run,UserInputService=input,ReplicatedStorage=storage,HttpService=http,VirtualUser={},StarterGui=starter})[name],name)end
function game:HttpPost()return 'invalid'end
local testTime=0
local mockOs=table.clone(os);mockOs.clock=function()return testTime end
local env={os=mockOs,game=game,workspace=workspace,Instance=Instance,Enum=Enum,Color3=Color3,UDim=UDim,UDim2=UDim2,Vector2=Vector2,Vector3=Vector3,CFrame=CFrame,task=task,warn=function(...)print('warning',...)end}
setmetatable(env,{__index=getfenv()})
function env.getgenv()return env end
local function advance(seconds)
 testTime+=seconds or 0.03
 local stop=#threads
 for i=1,stop do if coroutine.status(threads[i])=='suspended' then resume(threads[i])end end
end
local function compile(src)
 local fn,err=loadstring(src,'@BossFixture');assert(fn,err);setfenv(fn,env);return fn
end

env.loadstring=function(text,name)
 local fn,err=loadstring(text,name);if fn then setfenv(fn,env)end;return fn,err
end
