-- Prepended to the production controller/adapter by run_enchanted_rep.py.
local checks=0
local function check(condition,message)
    assert(condition,message)
    checks+=1
end
local now=0
local function tick(dt)
    now+=dt
    q.runTurboRep(now)
end
local function newTool(delay)
    local field={Value=delay,Parent=true,IsA=function(_,kind)return kind=="NumberValue"end}
    local tool={Name="Weight",Parent=character,field=field}
    function tool:FindFirstChild(name)if name=="repTime"then return self.field end end
    return tool,field
end
local tool,field=newTool(0.73)
q.activeTool=tool q.trainActive=true q.trainOrder={"Weight"}
q.setEnchantedRep(true)
tick(0.02)
check(field.Value==0,"tool repetition delay is removed")
tick(1/60)
check(#calls>=9 and #calls<=10,"first paced burst has at most ten requests")
check(calls[1].n==1 and calls[1][1]=="rep","plain rep request without a seat argument")
local before=#calls
tick(5)
check(#calls-before==10,"long stalls do not cause catch-up floods")
check(legacySends==0,"Enchanted profile excludes the legacy turbo sender")
q.setEnchantedRep(false)
check(field.Value==0.73,"disabling restores the exact original delay")
before=#calls q.enchantedRepController:Step(now+1)
check(#calls==before,"disabled controller cannot send")

q.setEnchantedRep(true) tick(0.02) tick(0.02)
q.networkPaused=true before=#calls tick(1)
check(#calls==before and field.Value==0.73,"network hold stops requests and restores delay")
q.networkPaused=false tick(0.02) before=#calls tick(0.02)
check(#calls-before<=10,"recovery has no stored burst debt")
humanoid.Health=0 before=#calls tick(0.02)
check(#calls==before and field.Value==0.73,"death restores delay and stops sending")
humanoid.Health=100 tick(0.02)
before=#calls
q.trainActive=false tick(0.02)
check(#calls==before and field.Value==0.73,"training stop restores delay immediately on next tick")

q.trainActive=true tick(0.02)
local second,secondField=newTool(1.25)
q.activeTool=second tick(0.02)
check(field.Value==0.73 and secondField.Value==0,"switching tools releases the previous tool")
secondField.Value=0.91 tick(0.02)
q.enchantedRepController:Reset(now)
check(secondField.Value==0.91,"new game-provided cooldown is preserved")
tick(0.02) secondField.Value=1.7
q.enchantedRepController:Reset(now)
check(secondField.Value==1.7,"reset does not overwrite a later game update")

local machine={Parent=true}
q.machineActive=true q.selectedMachine={seat=machine} q.machineAttached=false
before=#calls tick(0.02)
check(#calls==before,"no requests before machine attachment")
q.machineAttached=true tick(0.02) tick(0.02)
check(#calls>before and calls[#calls].n==1,"machine uses the same plain rep protocol")
q.machineAttachInFlight=true before=#calls tick(0.02)
check(#calls==before,"attachment transition pauses repeats")
q.machineAttachInFlight=false q.machineActive=false
q.activeTool=second tick(0.02)
q.boss={enabled=true} before=#calls tick(0.02)
check(#calls==before and secondField.Value==1.7,"boss combat cannot receive rep batches")
q.boss=nil
q.pingAvailable=true q.pingMs=750
tick(0.02) before=#calls tick(0.1)
check(#calls-before>=4 and #calls-before<=5,"high ping reduces traffic to fifty requests per second")
tick(0.1)
check(#calls-before>=9 and #calls-before<=10,"fractional time credit survives between ticks")

q.pingAvailable=false tick(0.02)
afterSend=function()q.setEnchantedRep(false)end
before=#calls tick(0.02)
check(#calls-before==1 and secondField.Value==1.7,"toggle-off during a batch cancels the remaining requests")
afterSend=nil q.setEnchantedRep(true) tick(0.02)
sendFailure=true before=#calls tick(0.02)
check(#calls==before and failures==1 and secondField.Value==1.7,"remote error restores state")
sendFailure=false tick(0.02)
characterRemoving()
check(secondField.Value==1.7 and q.enchantedRepController.target==nil,"respawn signal resets the controller")
q.alive=false before=#calls tick(0.02)
check(#calls==before,"closed runtime cannot send")
print("Enchanted rep scenarios passed:",checks)
