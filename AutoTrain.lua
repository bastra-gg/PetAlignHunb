-- AutoTrain protected launcher
local URL="https://szfjrpkdbccsveklkwyy.supabase.co/functions/v1/rb-bootstrap?r=36a2d3ab5626b8471143c2c4"
local ok,src=pcall(function() return game:HttpGet(URL.."&cb="..tostring(os.time()),true) end)
if not ok or type(src)~="string" then error("AutoTrain: load failed",0) end
local compiler=loadstring or load
if type(compiler)~="function" then error("AutoTrain: loadstring unavailable",0) end
local fn,err=compiler(src)
if type(fn)~="function" then error("AutoTrain: "..tostring(err),0) end
return fn()
