local count=0
local function check(name,callback)callback();count+=1;print("PASS "..name)end
local h=HUD.mount(runtime,options)
local function step()
 h.openedAt=os.clock()-1;run:Step();assert(#errors==0,errors[1])
end
local function screenPoint(p,b)
 return p.bounds.x+(b.x+b.w/2)*p.scale.Scale,p.bounds.y+(b.y+b.h/2)*p.scale.Scale
end
local function eventAt(p,b,touch)
 local x,y=screenPoint(p,b)
 return {UserInputType=touch and "Touch"or"MouseButton1",Position=Vector3.new(x,y)}
end
local binding="RockBugHologramT37_17"
local function click(p,b,touch)
 local action=actions.bindings[binding];local e=eventAt(p,b,touch)
 assert(action(binding,"Begin",e)=="Sink")
 assert(action(binding,"End",e)=="Sink")
end
check("mount provides four farm cards and permanently hides the old shell",function()
 step();assert(h.ready and #h.cards==4 and #h.panels==7 and not classic.Enabled and not n7.Visible and not n_.Visible)
 assert(h.cards[1].title.Text=="КАМНИ" and h.cards[2].title.Text=="ТРЕНАЖЁРЫ" and h.cards[3].title.Text=="КАЧ" and h.cards[4].title.Text=="БОСС")
 for _,o in ipairs(objects)do if o.ClassName=="Part"and o~=root then assert(o.CanQuery==false and o.CanCollide==false and o.CanTouch==false)end end
end)
check("native bottom buttons replace the content on desktop",function()
 h.groupButtons.growth.Activated:Fire();step()
 assert(h.group=="growth" and h.cards[1].title.Text=="МАГАЗИН" and h.cards[2].title.Text=="ЯЙЦА" and h.cards[3].title.Text=="КВЕСТЫ")
 h.groupButtons.kill.Activated:Fire();step();assert(h.cards[1].title.Text=="ВСЕ ИГРОКИ" and h.cards[3].title.Text=="ТОЛЬКО ЦЕЛИ")
 assert(not runtime.leverRefs.kill.all.Get())
 h.groupButtons.farm.Activated:Fire();step();assert(h.cards[1].title.Text=="КАМНИ")
end)
check("quick controls call the existing mode setters exactly once",function()
 click(h.cards[2],h.cards[2].primary)
 assert(runtime.leverRefs.machineFarm.Get())
 click(h.cards[3],h.cards[3].primary,true)
 assert(runtime.leverRefs.train.Weight.Get())
end)
check("all machines expands from its card without showing the old menu",function()
 click(h.cards[2],h.cards[2].more,true)
 assert(h.modalOpen and h.modalTab=="farm" and h.sheet.Visible and not h.nav.Visible)
 assert(next(run.bindings)==nil and next(actions.bindings)==nil)
 assert(not classic.Enabled and not n7.Visible and not n_.Visible)
 assert(q.hologramContent.Pages.farm.Parent==h.body and q.hologramContent.Pages.farm.Visible)
 assert(h.modalTween.played and h.modalTween.object==h.window)
 h.close.Activated:Fire();step();assert(not h.modalOpen and h.nav.Visible)
end)
check("all locations opens the entire teleport tab in the new window",function()
 h.groupButtons.growth.Activated:Fire();step()
 click(h.cards[4],h.cards[4].more)
 assert(h.modalOpen and h.modalTab=="teleport" and #h.modalTabs==5)
 assert(q.hologramContent.Pages.teleport.Parent==h.body)
 h:CloseFull();step()
end)
check("full tab switching keeps original controls and handlers",function()
 h:OpenFull("farm")
 local trainTab
 for _,tab in ipairs(h.modalTabs)do if tab.id=="train"then trainTab=tab end end
 assert(trainTab);trainTab.node.Activated:Fire()
 assert(h.modalTab=="train" and nV.Visible and not nU.Visible)
 local original=nV:FindFirstChild("OriginalControl")
 original.Activated:Fire();assert(q.controlHits.train==1)
 h:CloseFull();step()
end)
check("all twelve existing tabs remain reachable through expanded sections",function()
 for tab,page in pairs(initialPages)do
  assert(h:OpenFull(tab));assert(page.Parent==h.body and page.Visible and opened==tab)
  for other,otherPage in pairs(initialPages)do if other~=tab then assert(not otherPage.Visible)end end
 end
 h:CloseFull();step()
end)
check("pickers, confirmation, global actions and status move with full content",function()
 h:OpenFull("crystal")
 assert(p0.Parent==h.dialogHost and q.layoutUI.hologramDeleteOverlay.Parent==h.dialogHost)
 assert(nL.Parent==q.layoutUI.systemPage and nM.Parent==h.footer and nG.Parent==h.quickHost)
 p0.Visible=true;q.layoutUI.hologramDeleteOverlay.Visible=true
 h:CloseFull();assert(not p0.Visible and not q.layoutUI.hologramDeleteOverlay.Visible)
 step()
end)
check("legacy responsive layout cannot leave full-page content cropped",function()
 h:OpenFull("farm")
 nU.Size=UDim2.new(1,-12,1,-138);nU.Position=UDim2.fromOffset(6,87)
 nL.Size=UDim2.new(1,-12,0,26)
 q.hologramContent:Layout()
 assert(nU.Size.Y.Scale==1 and nU.Size.Y.Offset==0 and nU.Position.Y.Offset==0 and nU.ClipsDescendants)
 assert(nL.Size.Y.Offset==132 and not classic.Enabled)
 h:CloseFull();step()
end)
check("repeated full tab changes disconnect old tab handlers",function()
 h:OpenFull("farm");local previous=table.clone(h.modalTabs)
 h:OpenFull("train")
 for _,tab in ipairs(previous)do assert(not tab.connection.Connected and tab.node.destroyed)end
 h:CloseFull();step()
end)
check("phone landscape shows all four cards and portrait has four working sub-tabs",function()
 camera.ViewportSize=Vector3.new(844,390);h:SelectGroup("farm");step()
 for _,card in ipairs(h.cards)do assert(card.gui.Enabled)end
 assert(not h.strength.gui.Enabled and h.nav.Visible)
 camera.ViewportSize=Vector3.new(390,844);step()
 assert(h.cardTabs.Visible and h.cards[1].gui.Enabled and not h.cards[2].gui.Enabled)
 h.cardButtons[4].Activated:Fire();step();assert(h.cards[4].gui.Enabled and not h.cards[1].gui.Enabled)
 h.groupButtons.growth.Activated:Fire();step();assert(h.cardPage==1 and h.cards[1].title.Text=="МАГАЗИН")
 camera.ViewportSize=Vector3.new(1536,864);h:SelectGroup("farm");step()
end)
check("every overview button and label fits its panel",function()
 for _,p in ipairs(h.panels)do
  assert(p.frame.ClipsDescendants)
  for _,b in ipairs(p.buttons)do assert(b.x>=0 and b.y>=0 and b.x+b.w<=p.cw and b.y+b.h<=p.ch and b.node.ClipsDescendants)end
 end
end)
check("all kill quick controls retain the existing adapters and stop works",function()
 h:SelectGroup("kill");step()
 click(h.cards[3],h.cards[3].primary);assert(runtime.leverRefs.kill.blacklist.Get())
 click(h.cards[4],h.cards[4].primary);assert(not runtime.leverRefs.kill.blacklist.Get())
 h:SelectGroup("farm");step()
end)
check("dragging away and back cancels mouse and touch clicks",function()
 for _,touch in ipairs({false,true})do
  local e=eventAt(h.cards[1],h.cards[1].primary,touch);local initial=e.Position
  local action=actions.bindings[binding];local before=runtime.leverRefs.bug.Get()
  action(binding,"Begin",e)
  local movement=touch and e or {UserInputType="MouseMovement"};movement.Position=initial+Vector3.new(30,0,0);input.InputChanged:Fire(movement)
  e.Position=initial;movement.Position=initial;input.InputChanged:Fire(movement);action(binding,"End",e)
  assert(runtime.leverRefs.bug.Get()==before)
 end
end)
check("opening animation, game UI, chat and full modal block hologram hits",function()
 h.openedAt=os.clock()+1;run:Step();local x,y=screenPoint(h.cards[1],h.cards[1].primary);assert(h:Hit(x,y)==nil);step()
 x,y=screenPoint(h.cards[1],h.cards[1].primary)
 playerGui.hitObjects={Instance.new("TextButton")};assert(h:Hit(x,y)==nil);playerGui.hitObjects={}
 input.focus={};assert(h:Hit(x,y)==nil);input.focus=nil
 guiService.MenuIsOpen=true;assert(h:Hit(x,y)==nil);guiService.MenuIsOpen=false
 h:OpenFull("bug");assert(h:Hit(x,y)==nil);h:CloseFull();step()
end)
check("resize, respawn and close camera invalidate held clicks",function()
 for _,kind in ipairs({"resize","respawn","camera"})do
  local e=eventAt(h.cards[1],h.cards[1].primary);local action=actions.bindings[binding];local before=runtime.leverRefs.bug.Get()
  action(binding,"Begin",e)
  if kind=="resize"then camera.ViewportSize=Vector3.new(390,844)elseif kind=="respawn"then player.Character=nil else camera.CFrame=CFrame.new(0,0,0.5)end
  step();camera.ViewportSize=Vector3.new(1536,864);player.Character=character;camera.CFrame=CFrame.new(0,0,20);step()
  assert(action(binding,"End",e)=="Pass" and runtime.leverRefs.bug.Get()==before)
 end
end)
check("hidden and first-person settings use the new full window",function()
 camera.CFrame=CFrame.new(0,0,0.5);step();assert(not h.ready)
 h.menu.Activated:Fire();assert(h.modalOpen and h.modalTab=="system" and #h.modalTabs==12 and not classic.Enabled)
 h:SetVisible(false);assert(not h.sheet.Visible)
 h.menu.Activated:Fire();assert(h.modalOpen and not classic.Enabled)
 camera.CFrame=CFrame.new(0,0,20);h:CloseFull();assert(not h.visible);h:SetVisible(true);step()
end)
check("hide removes all effects, navigation and pending action feedback",function()
 h:Notify("Test");h.handle.Activated:Fire()
 assert(not h.visible and not h.world.Parent and not h.nav.Visible and not h.cardTabs.Visible and not h.notice.Visible)
 assert(next(run.bindings)==nil and next(actions.bindings)==nil and runtime.leverRefs.machineFarm.Get())
 h:Notify("Late");assert(not h.notice.Visible)
 h.handle.Activated:Fire();step()
end)
check("queued clicks cannot run after hiding",function()
 local queue={};local spawn=task.spawn;task.spawn=function(callback)table.insert(queue,callback)end
 local before=runtime.leverRefs.bug.Get();click(h.cards[1],h.cards[1].primary);assert(#queue==1)
 h:SetVisible(false);queue[1]();assert(runtime.leverRefs.bug.Get()==before)
 task.spawn=spawn;h:SetVisible(true);step()
end)
check("failed quick actions show feedback without reviving old windows",function()
 local callback=h.cards[1].primary.callback;h.cards[1].primary.callback=function()error("fixture error")end
 click(h.cards[1],h.cards[1].primary)
 assert(h.notice.Visible and h.notice.Text:find("fixture error",1,true)and #errors==1 and not classic.Enabled)
 local old=delayed[#delayed];h:Notify("New message");old();assert(h.notice.Visible);delayed[#delayed]();assert(not h.notice.Visible)
 h.cards[1].primary.callback=callback;table.clear(errors)
end)
check("ultra mode preserves a full window while suspending all rendering",function()
 h:OpenFull("farm");h:SetSuspended(true)
 assert(not h.overlay.Enabled and not h.sheet.Visible and next(run.bindings)==nil)
 h:SetSuspended(false);assert(h.sheet.Visible and h.modalTab=="farm" and not classic.Enabled)
 h:CloseFull();step()
end)
check("closing a popup cancels its animation and returns to its group",function()
 h:SelectGroup("growth");step();click(h.cards[1],h.cards[1].more)
 local tween=h.modalTween;h:CloseFull();step()
 assert(tween.cancelled and h.group=="growth"and h.cards[1].title.Text=="МАГАЗИН")
end)
check("full-window language and stop actions work without closing the HUD",function()
 h:OpenFull("farm");runtime.language="en";h:RefreshLanguage()
 assert(h.windowTitle.Text=="Machines" and h.groupButtons.growth.Text=="GROWTH")
 h.stop.Activated:Fire();assert(q.stoppedModes and runtime.alive and h.sheet.Visible)
 runtime.language="ru";h:RefreshLanguage();h:CloseFull();step()
end)
check("drawer fits desktop and both phone orientations without a modal backdrop",function()
 for _,size in ipairs({Vector3.new(1536,828),Vector3.new(844,354),Vector3.new(390,808),Vector3.new(320,444)})do
  h.sheet.AbsoluteSize=size;h:OpenFull("farm")
  assert(h.window.Size.X.Offset<=380 and h.window.Size.Y.Offset<=460)
  assert(h.window.Size.X.Offset<=size.X-24 and h.window.Size.Y.Offset<=size.Y-24)
  assert(h.body.Size.Y.Offset+h.window.Size.Y.Offset>=160)
  assert(h.sheet.ClassName=="Frame" and not h.sheet.Active and h.sheet.BackgroundTransparency==1)
 end
 h.sheet.AbsoluteSize=Vector3.new(1536,828);h:CloseFull();step()
end)
check("drawer slides from the clicked side and rotates while already open",function()
 h:OpenFull("farm",h.cards[2]);assert(not h.drawerLeft and h.window.AnchorPoint.X==1)
 h.sheet.AbsoluteSize=Vector3.new(390,808);h.sheet:GetPropertyChangedSignal("AbsoluteSize"):Fire()
 assert(h.window.Size.X.Offset==366 and h.window.Size.Y.Offset==460)
 h:CloseFull();h:OpenFull("bug",h.cards[1]);assert(h.drawerLeft and h.window.AnchorPoint.X==0)
 h.sheet.AbsoluteSize=Vector3.new(1536,828);h:CloseFull();step()
end)
check("only relevant refresh occupies drawer space; utility actions stay accessible",function()
 h:OpenFull("farm");assert(h.quickHost.Visible and h.body.Position.Y.Offset==134)
 h:OpenFull("train");assert(not h.quickHost.Visible and h.body.Position.Y.Offset==94)
 h:OpenFull("system");assert(nL.Parent==q.layoutUI.systemPage and nL.Size.Y.Offset==132)
 h:CloseFull();step()
end)
check("chest input cannot be intercepted by open or hidden hub controls",function()
 h:OpenFull("boss");h:SetChestInput(true)
 assert(not h.overlay.Enabled and not h.sheet.Visible and next(actions.bindings)==nil)
 h:SetSuspended(true);h:SetChestInput(false);assert(not h.overlay.Enabled)
 h:SetSuspended(false);assert(h.modalOpen and h.sheet.Visible and h.modalTab=="boss")
 h:CloseFull();h:SetVisible(false);h:SetChestInput(true);h:SetChestInput(false)
 assert(not h.visible and not h.world.Parent and not h.nav.Visible)
 h:SetVisible(true);step()
end)
check("all overview panels render as opaque screen layers above gain popups",function()
 for _,p in ipairs(h.panels)do
  assert(p.gui.ClassName=="ScreenGui" and p.gui.DisplayOrder==1000009 and p.gui.DisplayOrder<h.overlay.DisplayOrder)
  assert(p.gui.IgnoreGuiInset and p.gui.ScreenInsets=="None" and p.gui.ClipToDeviceSafeArea==false)
  if p.id~="title"then assert(p.frame.ClassName=="TextButton" and p.frame.Active and p.frame.BackgroundTransparency==0)else assert(not p.frame.Active)end
  assert(p.frame.Parent==p.screenRoot and p.screenRoot.Parent==p.gui)
 end
 for _,o in ipairs(h.surfaces:GetDescendants())do assert(o.ClassName~="SurfaceGui")end
end)
check("covered game controls do not veto the visible hub button",function()
 local group=h.group;h:SelectGroup("farm");step()
 local panel=h.cards[1];local x,y=screenPoint(panel,panel.primary)
 local gameLayer=Instance.new("ScreenGui");gameLayer.Parent=playerGui;gameLayer.DisplayOrder=50
 local gameButton=Instance.new("TextButton");gameButton.Parent=gameLayer
 playerGui.hitObjects={panel.frame,gameButton}
 assert(h:Hit(x,y)==panel.primary)
 local old=runtime.leverRefs.bug.Get();click(panel,panel.primary)
 assert(runtime.leverRefs.bug.Get()~=old)
 -- A covered margin has no automation action; the native shield remains the UI target.
 assert(not h:Hit(panel.bounds.x+2,panel.bounds.y+2))
 playerGui.hitObjects={};gameLayer:Destroy();h:SelectGroup(group);step()
end)
check("native controls and higher-priority dialogs still block overview actions",function()
 local panel=h.cards[1];local x,y=screenPoint(panel,panel.primary)
 playerGui.hitObjects={h.groupButtons.farm,panel.frame};assert(h:Hit(x,y)==nil)
 local dialog=Instance.new("ScreenGui");dialog.Parent=playerGui;dialog.DisplayOrder=h.overlay.DisplayOrder+1
 local control=Instance.new("TextButton");control.Parent=dialog
 playerGui.hitObjects={control,panel.frame};assert(h:Hit(x,y)==nil)
 playerGui.hitObjects={};dialog:Destroy()
end)
check("projection follows the character, camera and FOV using viewport coordinates",function()
 local oldRoot,oldCamera,oldFOV,oldGroup=root.Position,camera.CFrame,camera.FieldOfView,h.group
 for _,size in ipairs({Vector3.new(1536,864),Vector3.new(844,390),Vector3.new(390,844)})do
  camera.ViewportSize=size;root.Position=Vector3.new(2,1,0);camera.CFrame=CFrame.new(0,1,20)*CFrame.Angles(0,0.1,0);camera.FieldOfView=85
  h:SelectGroup("farm");step()
  for _,panel in ipairs(h.panels)do if panel.gui.Enabled then
   local point=camera:WorldToViewportPoint(panel.part.CFrame.Position)
   assert(math.abs(panel.screenRoot.Position.X.Offset-point.X)<0.001 and math.abs(panel.screenRoot.Position.Y.Offset-point.Y)<0.001)
   assert(math.abs(panel.bounds.w-panel.cw*panel.scale.Scale)<0.001 and math.abs(panel.bounds.h-panel.ch*panel.scale.Scale)<0.001)
   for _,button in ipairs(panel.buttons)do local x,y=screenPoint(panel,button);assert(h:Hit(x,y)==button)end
  end end
 end
 camera.ViewportSize=Vector3.new(1536,864);root.Position=oldRoot;camera.CFrame=oldCamera;camera.FieldOfView=oldFOV;h:SelectGroup(oldGroup);step()
end)
check("hiding, missing character and chest collection disable every projected layer",function()
 h:SetVisible(false);for _,panel in ipairs(h.panels)do assert(not panel.gui.Enabled)end
 h:SetVisible(true);step();player.Character=nil;step();for _,panel in ipairs(h.panels)do assert(not panel.gui.Enabled)end
 player.Character=character;step();h:SetChestInput(true);for _,panel in ipairs(h.panels)do assert(not panel.gui.Enabled)end
 h:SetChestInput(false);step();assert(h.cards[1].gui.Enabled)
end)
check("native mobile activation works even when the GUI consumes the context action",function()
 local group=h.group;h:SelectGroup("farm");step()
 local panel=h.cards[1];local b=panel.primary;local e=eventAt(panel,b,true)
 playerGui.hitObjects={b.node,panel.frame}
 local before=runtime.leverRefs.bug.Get();b.node.InputBegan:Fire(e);b.node.Activated:Fire(e)
 assert(runtime.leverRefs.bug.Get()~=before)
 b.node.Activated:Fire(e);assert(runtime.leverRefs.bug.Get()~=before)
 playerGui.hitObjects={};h:SelectGroup(group);step()
end)
check("native and context routes toggle only once regardless of release ordering",function()
 local group=h.group;h:SelectGroup("farm");step()
 for _,nativeFirst in ipairs({false,true})do
  local panel=h.cards[1];local b=panel.primary;local e=eventAt(panel,b,true);local action=actions.bindings[binding]
  local before=runtime.leverRefs.bug.Get()
  action(binding,"Begin",e);b.node.InputBegan:Fire(e)
  if nativeFirst then b.node.Activated:Fire(e);action(binding,"End",e)
  else action(binding,"End",e);b.node.Activated:Fire(e)end
  assert(runtime.leverRefs.bug.Get()~=before)
 end
 h:SelectGroup(group);step()
end)
check("native drags and hide invalidate an activation without a context callback",function()
 local panel=h.cards[1];local b=panel.primary;local e=eventAt(panel,b,true);local calls=0;local callback=b.callback
 b.callback=function()calls+=1 end
 b.node.InputBegan:Fire(e);local position=e.Position;e.Position=position+Vector3.new(40,0,0);input.InputChanged:Fire(e)
 e.Position=position;input.InputChanged:Fire(e);b.node.Activated:Fire(e);assert(calls==0)
 b.node.InputBegan:Fire(e);h:SetVisible(false);b.node.Activated:Fire(e);assert(calls==0)
 b.callback=callback;h:SetVisible(true);step()
end)
check("destroy cleans native/full/world UI and repeat launch stays hidden",function()
 h:SetVisible(false);local connections=table.clone(h.connections);local tabs=table.clone(h.modalTabs)
 h:Destroy();h:Destroy()
 assert(h.world.destroyed and h.surfaces.destroyed and h.overlay.destroyed and runtime.hologram==nil)
 for _,c in ipairs(connections)do assert(not c.Connected)end
 for _,t in ipairs(tabs)do assert(not t.connection.Connected)end
 classic.Enabled=true;local other=HUD.mount(runtime,options)
 assert(not other.visible and not classic.Enabled and other.group=="growth")
 other:Destroy()
end)
print("Hologram lifecycle/content: "..count.." scenarios passed")
