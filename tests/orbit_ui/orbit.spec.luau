local count=0
local function check(name,callback)callback();count+=1;print("PASS "..name)end
local h=HUD.mount(runtime,options)
local function step()
 h.openedAt=os.clock()-1;h.visualElapsed=1;run:Step();assert(#errors==0,errors[1])
end
step()
check("floating windows stay within desktop, landscape and portrait bounds",function()
 for _,size in ipairs({{1536,828},{844,354},{390,808},{320,444}})do
  for _,origin in ipairs({{x=12,y=100,w=240,h=150},{x=size[1]-252,y=250,w=240,h=150}})do
   local r=HUD.popupLayout(size[1],size[2],origin)
   assert(r.x-r.w/2>=11.99 and r.x+r.w/2<=size[1]-11.99)
   assert(r.y-r.h/2>=11.99 and r.y+r.h/2<=size[2]-11.99)
   assert(r.w<=364 and r.h<=424)
  end
 end
 local left=HUD.popupLayout(1536,828,{x=120,y=180,w=280,h=160})
 local right=HUD.popupLayout(1536,828,{x=1136,y=180,w=280,h=160})
 assert(left.linked and right.linked and left.x<right.x)
 assert(HUD.popupLayout(390,808).x==195)
end)
check("panels have rounded faces and a separate noninteractive depth layer",function()
 for _,p in ipairs(h.cards)do
  assert(p.frame:FindFirstChildOfClass("UICorner").CornerRadius.Offset==38)
  assert(p.depth.Parent==p.canvas and not p.depth.Active and p.depth.ZIndex<p.frame.ZIndex)
  assert(p.scale.Parent==p.canvas and not p.screenRoot.ClipsDescendants)
 end
end)
check("world decoration budget drops to 84 instances and 43 beams",function()
 local descendants=h.world:GetDescendants();local counts={}
 for _,obj in ipairs(descendants)do counts[obj.ClassName]=(counts[obj.ClassName]or 0)+1 end
 assert(#descendants==84 and counts.Beam==43 and counts.Attachment==39 and counts.Part==2)
 print("METRIC world instances=84 beams=43 attachments=39 parts=2")
end)
check("one shared projection at 30 Hz replaces per-panel projections every frame",function()
 step();h.visualElapsed=0;camera.projectionCount=0
 for i=1,60 do run:Step(1/60)end
 assert(camera.projectionCount==30,camera.projectionCount)
 print("METRIC projections per 60 callbacks="..camera.projectionCount)
 h:SetVisible(false);camera.projectionCount=0
 for i=1,60 do run:Step(1/60)end
 assert(camera.projectionCount==0)
 h:SetVisible(true);step()
end)
check("low FPS reduces decoration with hysteresis and keeps actions usable",function()
 for i=1,80 do run:Step(0.05)end
 assert(h.lowDetail)
 for _,beam in ipairs(h.detailBeams)do assert(not beam.Enabled)end
 local before=runtime.leverRefs.bug.Get();h.cards[1].primary.node.Activated:Fire()
 assert(runtime.leverRefs.bug.Get()~=before)
 for i=1,650 do run:Step(1/60)end
 assert(not h.lowDetail)
 for _,beam in ipairs(h.detailBeams)do assert(beam.Enabled)end
end)
check("a held touch freezes card motion until release",function()
 step();local card=h.cards[1];local oldX=card.screenRoot.Position.X.Offset
 local e={UserInputType="Touch",Position=Vector3.new(oldX,card.screenRoot.Position.Y.Offset)}
 card.primary.node.InputBegan:Fire(e);root.Position=Vector3.new(2,0,0)
 run:Step(1/30);assert(card.screenRoot.Position.X.Offset==oldX)
 input.InputEnded:Fire(e);card.primary.node.Activated:Fire(e);run:Step(1/30)
 assert(card.screenRoot.Position.X.Offset>oldX)
 root.Position=Vector3.new();step()
end)
check("closing animation cannot close a newly opened section",function()
 h:OpenFull("farm",h.cards[2]);h:CloseFull()
 assert(h.closingModal and h.transitionBlocker.Visible)
 local stale=delayed[#delayed]
 h:OpenFull("boss",h.cards[4]);stale()
 assert(h.modalOpen and not h.closingModal and h.modalTab=="boss" and not h.transitionBlocker.Visible)
 h:CloseFull(true);step()
end)
check("hidden and destroyed consoles cancel delayed close work",function()
 h:OpenFull("farm",h.cards[2]);h:CloseFull();local stale=delayed[#delayed]
 h:SetVisible(false);stale();assert(not h.visible and not h.sheet.Visible)
 h:SetVisible(true);step()
end)
check("loot details use a rounded scrollable popup near the selected card",function()
 h.actionPanel=h.cards[4];h:Notify("Boss loot • "..string.rep("item ",200))
 assert(h.noticePanel.Visible and h.notice.Visible and h.notice.Text:find("Boss loot",1,true))
 assert(h.notice.Parent.ClassName=="ScrollingFrame" and h.notice.AutomaticSize=="Y")
 assert(h.notice.Parent.AutomaticCanvasSize=="Y")
 h.noticeClose.Activated:Fire();assert(not h.noticePanel.Visible and not h.notice.Visible)
end)
check("reduced motion remains functional without creating opening tweens",function()
 env.RockBugHologramMotion=false
 h:OpenFull("farm",h.cards[2]);assert(h.windowScale.Scale==1)
 h:CloseFull();assert(not h.modalOpen and not h.closingModal)
 env.RockBugHologramMotion=nil;step()
end)
h:Destroy()
print("Orbit behavior/performance: "..count.." scenarios passed")
