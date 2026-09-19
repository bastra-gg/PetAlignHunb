-- BossRadar protected launcher
local URL="https://szfjrpkdbccsveklkwyy.supabase.co/functions/v1/boss-radar-bootstrap"
local ok,src=pcall(function()return game:HttpGet(URL.."?v="..tostring(os.time()),true)end)
if not ok or type(src)~="string"then error("BossRadar: load failed",0)end
local compiler=loadstring or load
if type(compiler)~="function"then error("BossRadar: loadstring unavailable",0)end
local fn,err=compiler(src)
if type(fn)~="function"then error("BossRadar: "..tostring(err),0)end
return fn()
