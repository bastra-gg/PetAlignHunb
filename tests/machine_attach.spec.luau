local count=0
local function check(name,fn)reset()fn()count+=1 print('PASS '..name)end
check('Actual adapter never treats successful FireServer as seating',function()
    ep(machine,1)advance(1)
    assert(v.sends==1 and not q.machineAttached and not q.machineAttachInFlight)
end)
check('No-op transports rotate to keyboard and physical Seat Sit',function()
    for _=1,5 do ep(machine,1)advance(2)end
    assert(v.sends==1 and v.helpers==1 and v.begins==1 and v.ends==1 and v.down==1 and v.up==1 and v.sits==1)
    assert(q.machineAttached and not q.machineAttachInFlight)
end)
check('Hung machine InvokeServer does not block remaining input methods',function()
    v.remoteFunction=true v.hang=true
    for _=1,5 do ep(machine,1)advance(2)end
    assert(v.invokes==1 and q.machineAttached and not q.machineAttachInFlight)
end)
check('Helper errors clear in-flight state for the next attempt',function()
    q.machineAttachAttempt=1 v.helperError=true
    ep(machine,1)advance(1)
    assert(v.helpers==1 and q.machineRecoveryError and not q.machineAttachInFlight)
    ep(machine,1)advance(2)assert(v.begins==1)
end)
check('Stop releases a held prompt and cancels delayed input',function()
    q.machineAttachAttempt=2 prompt.HoldDuration=3
    ep(machine,1)advance(0.1)assert(v.begins==1 and v.ends==0)
    q.cancelMachineAttach()q.machineActive=false q.machineToken+=1
    advance(5)assert(v.ends==1 and not q.machineAttachInFlight and not q.machineAttached)
end)
check('Stop releases held E exactly once',function()
    q.machineAttachAttempt=3
    ep(machine,1)advance(0.03)assert(v.down==1 and v.up==0)
    q.cancelMachineAttach()q.machineActive=false
    advance(1)assert(v.up==1 and not q.machineAttachInFlight)
end)
check('Respawn invalidates a delayed seating observation',function()
    ep(machine,1)advance(0.1)v.character={}v.attached=true
    advance(1)assert(not q.machineAttached and not q.machineAttachInFlight)
end)
check('Failed InputHoldBegin still releases and permits retry',function()
    q.machineAttachAttempt=2 v.beginError=true
    ep(machine,1)advance(1)
    assert(v.begins==1 and v.ends==1 and not q.machineAttachInFlight)
    ep(machine,1)advance(1)assert(v.down==1 and v.up==1)
end)
check('Manual machine change cannot be acknowledged by an old job',function()
    ep(machine,1)advance(0.1)q.machineToken+=1 q.selectedMachine={}
    v.attached=true advance(1)assert(not q.machineAttached)
end)
print(count..' machine input adapter scenarios passed')
