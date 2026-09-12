local count=0
local function check(name,fn)fn()count+=1 print("PASS "..name)end
check("Actual restore enables saved rebirth only after seating",function()
    local snapshot=reset(true)
    assert(restore(snapshot,function()return running end))
    assert(q.autoRebirth and time>=2.4 and not q.bossRestorePending and q.machineActive)
end)
check("Actual restore preserves disabled rebirth",function()
    local snapshot=reset(false)
    assert(restore(snapshot,function()return running end))
    assert(not q.autoRebirth and q.machineActive)
end)
check("No seat acknowledgement leaves rebirth off",function()
    local snapshot=reset(true)seatAt=nil
    assert(not restore(snapshot,function()return running end))
    assert(not q.autoRebirth and not q.machineActive and not q.bossRestorePending)
    assert(q.bossCycleError and time>=20)
end)
check("Stop during actual restore leaves modes stopped",function()
    local snapshot=reset(true)mutation=function()running=false end
    assert(not restore(snapshot,function()return running end))
    assert(not q.autoRebirth and not q.machineActive and not q.bossRestorePending)
end)
check("Manual machine change is not stopped or overwritten",function()
    local snapshot=reset(true)
    local other={}
    mutation=function()q.machineToken+=1 q.selectedMachine=other end
    assert(not restore(snapshot,function()return running end))
    assert(q.machineActive and q.selectedMachine==other and not q.autoRebirth)
end)
check("Manual rebirth setting invalidates saved resume",function()
    local snapshot=reset(true)mutation=function()q.rebirthToken+=1 end
    assert(not restore(snapshot,function()return running end))assert(not q.autoRebirth)
end)
check("Death during restore prevents rebirth",function()
    local snapshot=reset(true)mutation=function()humanoid.Health=0 end
    assert(not restore(snapshot,function()return running end))assert(not q.autoRebirth)
end)
check("Completed rebirth target remains stopped",function()
    local snapshot=reset(true)snapshot.fields.rebirthGoalEnabled=true snapshot.fields.rebirthGoalCompleted=true
    assert(restore(snapshot,function()return running end))assert(not q.autoRebirth)
end)
print(tostring(count).." restore integration scenarios passed")
