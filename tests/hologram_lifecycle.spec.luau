local count=0
local function check(name,callback)callback();count+=1;print("PASS "..name)end
local h=HUD.mount(runtime,options)
local function step()
    h.openedAt=os.clock()-1
    run:Step()
    assert(#errors==0,errors[1])
end
check("mount renders eight panels facing the camera",function()
    step()
    assert(h.ready and #h.panels==8 and not classic.Enabled)
    for _,p in ipairs(h.panels)do assert(p.gui.Enabled and p.gui.Face=="Back");assert(p.part.Size.X>0 and p.part.Size.Y>0)end
    for _,o in ipairs(objects)do if o.ClassName=="Part"and o~=root then assert(o.CanQuery==false and o.CanCollide==false and o.CanTouch==false)end end
    assert(h.pets.slots[1].Text=="Rare Golem" and h.pets.count.Text=="2 / 3 экипировано")
    assert(h.session.rebirths.Text=="Ребирты: +2")
end)
local function screenPoint(p,b)
    local localPoint=Vector3.new(((b.x+b.w/2)/p.cw-0.5)*p.part.Size.X,(0.5-(b.y+b.h/2)/p.ch)*p.part.Size.Y,p.part.Size.Z/2)
    local worldPoint=p.part.CFrame.Position+p.part.CFrame:VectorToWorldSpace(localPoint)
    return worldPoint.X,worldPoint.Y
end
local function eventAt(p,b,touch)
    local x,y=screenPoint(p,b)
    return {UserInputType=touch and "Touch"or"MouseButton1",Position=Vector3.new(x,y)}
end
local binding="RockBugHologramT33_17"
check("mouse press and release toggle the existing machine control exactly once",function()
    local p=h.automation;local b=p.buttons[3];local e=eventAt(p,b)
    local action=actions.bindings[binding]
    assert(action(binding,"Begin",e)=="Sink")
    assert(not runtime.leverRefs.machineFarm.Get())
    assert(action(binding,"End",e)=="Sink")
    assert(runtime.leverRefs.machineFarm.Get())
    assert(action(binding,"End",e)=="Pass")
end)
check("touch teleport invokes the existing destination adapter",function()
    local e=eventAt(h.teleport,h.teleport.buttons[2],true)
    local action=actions.bindings[binding]
    assert(action(binding,"Begin",e)=="Sink")
    assert(action(binding,"End",e)=="Sink")
    assert(runtime.lastTeleport=="Legend Beach")
end)
check("game GUI and chat focus take precedence over hologram clicks",function()
    local x,y=screenPoint(h.automation,h.automation.buttons[1])
    playerGui.hitObjects={Instance.new("TextButton")};assert(h:Hit(x,y)==nil)
    playerGui.hitObjects={};input.focus={};assert(h:Hit(x,y)==nil);input.focus=nil
    guiService.MenuIsOpen=true;assert(h:Hit(x,y)==nil);guiService.MenuIsOpen=false
end)
check("hide detaches effects and removes input/render work without stopping automation",function()
    h.handle.Activated:Fire()
    assert(not h.visible and not h.world.Parent and next(run.bindings)==nil and next(actions.bindings)==nil)
    assert(h.overlay.Enabled and runtime.leverRefs.machineFarm.Get() and runtime.alive)
    for _,p in ipairs(h.panels)do assert(not p.gui.Enabled)end
    h.handle.Activated:Fire();step();assert(h.visible and h.ready)
end)
check("phone rotation displays only the selected content plus navigation",function()
    camera.ViewportSize=Vector3.new(390,844);step()
    local enabled=0;for _,p in ipairs(h.panels)do if p.gui.Enabled then enabled+=1 end end
    assert(enabled==3 and h.automation.gui.Enabled and h.title.gui.Enabled and h.nav.gui.Enabled)
    h.nav.buttons[2].callback();step();assert(h.pets.gui.Enabled and not h.automation.gui.Enabled)
    camera.ViewportSize=Vector3.new(844,390);step();assert(h.strength.gui.Enabled and h.pets.gui.Enabled)
end)
check("settings open the classic panel and the same handle restores the hologram",function()
    h.nav.buttons[5].callback();assert(opened=="interface" and classic.Enabled and not h.visible)
    h.handle.Activated:Fire();step();assert(not classic.Enabled and h.visible)
end)
check("respawn removes stale geometry and attaches to the next character",function()
    player.Character=nil;step();assert(not h.ready and not h.world.Parent)
    player.Character=character;step();assert(h.ready and h.world.Parent==camera)
end)
check("camera replacement adopts the new viewport and first person releases all hits",function()
    local oldCamera=workspace.CurrentCamera
    local replacement={CFrame=CFrame.new(0,0,12),ViewportSize=Vector3.new(1536,864),FieldOfView=70,ScreenPointToRay=camera.ScreenPointToRay}
    workspace.CurrentCamera=replacement;step();assert(h.world.Parent==replacement)
    replacement.CFrame=CFrame.new(0,0,0.5);step();assert(not h.ready and not h.world.Parent)
    workspace.CurrentCamera=oldCamera;step();assert(h.ready)
end)
check("ultra mode suspends rendering and restores the previous visibility",function()
    h:SetSuspended(true);assert(not h.overlay.Enabled and not h.world.Parent and next(run.bindings)==nil)
    h:SetSuspended(false);step();assert(h.visible and h.ready)
    h:SetVisible(false);h:SetSuspended(true);h:SetSuspended(false)
    assert(not h.visible and next(run.bindings)==nil)
end)
check("destroy and repeat launch leave no geometry or live handlers behind",function()
    local connections=table.clone(h.connections)
    h:Destroy();h:Destroy();assert(runtime.hologram==nil and next(run.bindings)==nil and next(actions.bindings)==nil)
    assert(h.world.destroyed and h.surfaces.destroyed and h.overlay.destroyed)
    for _,connection in ipairs(connections)do assert(not connection.Connected)end
    local other=HUD.mount(runtime,options)
    assert(not other.visible and other.overlay.Enabled)
    other:Destroy()
end)
print("Hologram lifecycle: "..count.." scenarios passed")
