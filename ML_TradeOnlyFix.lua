-- RockBugHub MAIN protected launcher
-- TEST-style startup: one HttpGet -> loadstring -> run.
-- The downloaded payload is still the protected MAIN VM bundle.
local VERSION="4.25.2"
local CORE_URL="https://szfjrpkdbccsveklkwyy.supabase.co/functions/v1/rb-main-core"

local env=_G
if type(getgenv)=="function"then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table"then env=v end
end

local compiler=loadstring or env.loadstring
if type(compiler)~="function"then
    error("RockBugHub MAIN "..VERSION..": executor has no loadstring",0)
end

local stamp="?cb="..tostring(os.time()).."-"..tostring(math.random(100000,999999))
local ok,source=pcall(function()
    return game:HttpGet(CORE_URL..stamp,true)
end)
if not ok or type(source)~="string"then
    error("RockBugHub MAIN "..VERSION..": failed to load protected core • "..tostring(source),0)
end

local chunk,problem=compiler(source)
if type(chunk)~="function"then
    error("RockBugHub MAIN "..VERSION..": compile protected core • "..tostring(problem),0)
end

return chunk()
