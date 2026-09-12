local now=0
local os={clock=function()return now end}
local queue={}
local task={}
local function resume(thread)
    if coroutine.status(thread)=='dead' then return end
    local ok,delay=coroutine.resume(thread)assert(ok,delay)
    if coroutine.status(thread)~='dead' then table.insert(queue,{thread=thread,at=now+(delay or 0.01)})end
end
function task.spawn(fn)local t=coroutine.create(fn)resume(t)return t end
function task.wait(delay)return coroutine.yield(delay or 0.03)end
function task.cancel(thread)if coroutine.status(thread)~='dead' then coroutine.close(thread)end end
local function advance(dt)
    local target=now+dt
    for _=1,10000 do
        table.sort(queue,function(a,b)return a.at<b.at end)
        if not queue[1] or queue[1].at>target then now=target return end
        local item=table.remove(queue,1)now=item.at resume(item.thread)
    end
    error('runaway fixture')
end
local v,q,machine,ep
local prompt,remote
local function aM()return v.character end
local function aN()return v.human end
local function f7()return remote end
local Enum={KeyCode={E='E'}}
local manager={}
function manager:SendKeyEvent(down)
    if down then v.down+=1 else v.up+=1 end
end
local game={GetService=function(_,name)assert(name=='VirtualInputManager')return manager end}
local function fireproximityprompt()v.helpers+=1 if v.helperError then error('helper failed')end end
local function reset()
    now=0 queue={}
    v={character={},human={Health=100},attached=false,sends=0,invokes=0,helpers=0,begins=0,ends=0,down=0,up=0,sits=0,seatWorks=true}
    prompt={HoldDuration=0.2}
    function prompt:InputHoldBegin()v.begins+=1 if v.beginError then error('native input blocked')end end
    function prompt:InputHoldEnd()v.ends+=1 end
    local seat={Parent={}}
    function seat:FindFirstChildWhichIsA()return prompt end
    function seat:IsA(kind)return kind=='Seat' end
    function seat:Sit()v.sits+=1 if v.seatWorks then v.attached=true end end
    machine={seat=seat,model={}}
    remote={}
    function remote:IsA(kind)return kind=='RemoteFunction' and v.remoteFunction end
    function remote:FireServer(action,target)assert(action=='useMachine' and target==machine.seat)v.sends+=1 end
    function remote:InvokeServer(action,target)
        assert(action=='useMachine' and target==machine.seat)v.invokes+=1
        if v.hang then task.wait(100)end
    end
    q.alive=true q.machineActive=true q.machineToken=1 q.selectedMachine=machine
    q.machineAttachAttempt=0 q.machineAttachJob=nil q.machineAttachInFlight=false q.machineAttached=false
    q.machineRemoteFlight=nil q.networkPaused=false
    q.machinePresence=function()return v.attached end
end
q={}
