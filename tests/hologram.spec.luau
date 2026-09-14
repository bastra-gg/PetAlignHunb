local HUD=require("../src/HologramHUD")
local count=0
local function check(name,callback)callback();count+=1;print("PASS "..name)end
check("phone rotation and desktop choose legible layouts",function()
 assert(HUD.layout(390,844)=="portrait")
 assert(HUD.layout(844,390)=="compact")
 assert(HUD.layout(1536,864)=="wide")
end)
check("drawer stays compact on desktop and fits narrow viewports",function()
 for _,size in ipairs({{1536,864},{844,390},{390,844},{320,444}})do
  local w,h=HUD.drawerSize(size[1],size[2])
  assert(w<=380 and h<=460 and w<=size[1]-24 and h<=size[2]-24)
 end
end)
print("Hologram layout: "..count.." scenarios passed")
