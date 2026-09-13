local count=0
local function check(name,fn)fn();count+=1;print("PASS "..name)end
local host=Instance.new("Frame")
check("new switch uses one original callback and reflects rejected starts",function()
 local calls=0
 local ref,row=oC(host,"","Автотренажёр","Телепорт и повторения",false,function(value,control)calls+=1;if value then control.Set(false,true)end end)
 row.Activated:Fire();assert(calls==1 and not ref.Get())
 assert(row.Size.Y.Offset==58 and ref.NameLabel.TextSize==14)
 ref.Set(true,true);assert(calls==1 and ref.Get())
 runtime.language="en";ref.Refresh()
 local found=false;for _,node in ipairs(row:GetChildren())do if node.Text=="ON"then found=true end end
 assert(found);runtime.language="ru"
end)
check("numeric input preserves validation, clamp and commit",function()
 local value;local ref,row=oI(host,"Цель","Количество",1,function(v)value=v end,1,100)
 ref.Box.Text="250";ref.Box.FocusLost:Fire();assert(value==100 and ref.Get()==100 and ref.Box.Text=="100")
 ref.Box.Text="ошибка";ref.Box.FocusLost:Fire();assert(ref.Get()==100 and value==100)
 assert(row.Size.Y.Offset==58 and ref.Box.Size.Y.Offset==38)
end)
check("whole selection row opens the original picker and live value stays readable",function()
 local calls=0;local ref=oY(host,"ЛОКАЦИЯ","ВЫБРАТЬ",function()calls+=1 end)
 ref.Row.Activated:Fire();assert(calls==1)
 ref.Set("Muscle King Gym");assert(ref.Get()=="Muscle King Gym")
 assert(ref.Row.Size.Y.Offset==58)
 local values=0;for _,node in ipairs(ref.Row:GetChildren())do if node.Text=="Muscle King Gym"then assert(node.TextSize==14 and node.Position.X.Offset==12);values+=1 end end
 assert(values==1)
end)
check("percentage slider retains step rounding and its existing callback",function()
 local value;local ref,row=q.layoutUI.makePercentSlider(host,"Размер текста",100,80,125,5,function(v)value=v end)
 ref.Set(123,false);assert(value==125 and ref.Get()==125)
 ref.Set(79,true);assert(value==125 and ref.Get()==80)
 assert(row.Size.Y.Offset==58 and ref.Track.Size.Y.Offset==32)
end)
print("Drawer controls: "..count.." scenarios passed")
