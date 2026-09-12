local count=0
local function check(name,fn)fn()count+=1 print('PASS '..name)end
local function fixture()
    local v={time=0,strength=0,needed=300,active=true,ready=true,attached=false,flight=false,rebirth=false,weights=0,attempts=0,releases=0,phases={}}
    local s=createMachineRecovery({now=function()return v.time end,active=function()return v.active end,
        ready=function()return v.ready end,attached=function()return v.attached end,attachBusy=function()return v.flight end,
        rebirthBusy=function()return v.rebirth end,requirements=function()return v.strength,v.needed,v.locked end,
        releaseWeight=function()v.releases+=1 end,show=function(phase)table.insert(v.phases,phase)end,
        weight=function(current)v.weights+=1 if v.onweight then v.onweight(current)end return not v.noTool end,
        attach=function(current)assert(current())v.attempts+=1 if v.onattach then v.onattach()end end})
    local function tick(dt)v.time+=dt or 0.2 s:Step()end
    return s,v,tick
end
check('Insufficient strength uses weight without any seat or rebirth request',function()
    local s,v,tick=fixture()
    v.onweight=function()v.strength+=50 end
    for _=1,5 do tick()assert(not s:CanRebirth() and v.attempts==0)end
    tick()assert(v.strength==300 and v.attempts==0)
    tick()assert(v.attempts==1 and s.phase=='attaching' and not s:CanRebirth())
end)
check('Accepted but ineffective equip retries until a real seat appears',function()
    local s,v,tick=fixture()v.strength=300
    v.onattach=function()if v.attempts==3 then v.attached=true end return true end
    for _=1,20 do tick()end
    assert(v.attempts==3 and s:CanRebirth())
end)
check('No-op attach cannot enable rebirth even after 30 seconds',function()
    local s,v,tick=fixture()v.strength=400
    for _=1,150 do tick()end
    assert(v.attempts>10 and not s:CanRebirth() and v.weights==0)
end)
check('Fresh seat loss blocks rebirth before next controller tick',function()
    local s,v,tick=fixture()v.attached=true tick()tick()tick()tick()
    assert(s:CanRebirth())v.attached=false assert(not s:CanRebirth())
end)
check('Rebirth resets strength but a surviving attachment keeps training',function()
    local s,v,tick=fixture()v.strength=500 v.attached=true
    tick()tick()tick()tick()assert(s:CanRebirth())
    v.strength=0 tick()assert(s:CanRebirth() and v.weights==0 and v.attempts==0)
end)
check('Lost attachment after rebirth warms up then reseats before next rebirth',function()
    local s,v,tick=fixture()v.strength=500 v.attached=true
    tick()tick()tick()tick()assert(s:CanRebirth())
    v.attached=false v.strength=0 v.onweight=function()v.strength+=150 end
    tick()tick()assert(v.strength==300 and not s:CanRebirth())
    v.onattach=function()v.attached=true end
tick()tick()tick()assert(not s:CanRebirth())tick()tick()assert(s:CanRebirth())
end)
check('Pending rebirth acknowledgement delays new equipment',function()
    local s,v,tick=fixture()v.rebirth=true
    tick()tick()assert(v.weights==0 and v.attempts==0 and not s:CanRebirth())
    v.rebirth=false tick()assert(v.weights==1)
end)
check('Missing weight is retried without pretending to be seated',function()
    local s,v,tick=fixture()v.noTool=true
    for _=1,20 do tick()end
    assert(v.weights>=4 and v.weights<=6 and v.attempts==0 and s.phase=='tool')
    v.noTool=false v.onweight=function()v.strength=300 end
    for _=1,5 do tick()end
    assert(v.attempts>=1 and not s:CanRebirth())
end)
check('Stop during delayed weight equip invalidates continuation',function()
    local s,v,tick=fixture()
    v.onweight=function(current)v.active=false s:Reset()assert(not current())end
    tick()assert(v.attempts==0 and s.phase=='idle')
    tick()assert(v.weights==1)
end)
check('Network pause performs no input and restarts seat stabilization',function()
    local s,v,tick=fixture()v.attached=true tick()tick()tick()tick()assert(s:CanRebirth())
    v.ready=false tick()assert(not s:CanRebirth())
    v.ready=true tick()assert(not s:CanRebirth())tick()tick()tick()assert(s:CanRebirth())
end)
check('Unknown strength waits for actual data',function()
    local s,v,tick=fixture()v.strength=nil tick()
    assert(s.phase=='stats' and v.weights==0 and v.attempts==0)
end)
check('Unknown threshold retries weight after failed seat inputs',function()
    local s,v,tick=fixture()v.needed=nil v.strength=1
    for _=1,30 do tick()end
    assert(v.weights>0 and v.attempts>=3 and not s:CanRebirth())
end)
check('Strength zero takes weight even for an advertised zero entry threshold',function()
    local s,v,tick=fixture()v.needed=0 tick()assert(v.weights==1 and v.attempts==0)
end)
check('Required rebirth count is not treated as strength',function()
    local s,v,tick=fixture()v.locked=true tick()
    assert(s.phase=='locked' and v.weights==0 and v.attempts==0)
end)
local function object(class,name,parent)
    local o={Name=name,ClassName=class,Parent=parent,children={},attributes={}}
    if parent and parent.children then table.insert(parent.children,o)end
    function o:IsA(kind)return self.ClassName==kind or kind=='ValueBase' and (class=='NumberValue' or class=='StringValue')end
    function o:GetAttributes()return self.attributes end
    function o:GetDescendants()local r={}for _,child in ipairs(self.children)do table.insert(r,child)for _,d in ipairs(child:GetDescendants())do table.insert(r,d)end end return r end
    return o
end
check('Actual requirement reader distinguishes fields and reads localized signs',function()
    local model=object('Model','Machine',{}) local seat=object('Part','interactSeat',model)
    local machine={model=model,seat=seat}
    local rebs=object('NumberValue','neededRebirths',model)rebs.Value=10
    local function parse(text)if text:find('312,5K',1,true)then return 312500 end return tonumber(text)end
    assert(readMachineRequirement(machine,'strength',parse)==nil)
    assert(readMachineRequirement(machine,'rebirths',parse)==10)
    local sign=object('TextLabel','Cost',model)sign.Text='Требуется 312,5K силы'
    assert(readMachineRequirement(machine,'strength',parse)==312500)
    seat.attributes.RequiredStrength=100
    assert(readMachineRequirement(machine,'strength',parse)==100)
    seat.attributes.RequiredStrength=0 assert(readMachineRequirement(machine,'strength',parse)==0)
end)
check('Final rebirth send checks live seating gate, not only scheduling flags',function()
    local sent=0
    local remote={IsA=function()return false end,FireServer=function()sent+=1 end}
    local s,v,tick=fixture()v.attached=true
    q={machineRebirthAllowed=function()return s:CanRebirth()end}
    assert(not ih(remote))assert(sent==0)
    tick()tick()tick()tick()assert(ih(remote))assert(sent==1)
    v.attached=false assert(not ih(remote))assert(sent==1)
    v.active=false assert(ih(remote))assert(sent==2)
end)
print(count..' machine recovery scenarios passed')
