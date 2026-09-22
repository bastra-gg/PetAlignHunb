-- RockBugHub MAIN protected launcher
-- Same simple startup path as TEST; the protected MAIN code still comes from rb-bootstrap.
local VERSION="4.25.2"
local CORE_URL="https://szfjrpkdbccsveklkwyy.supabase.co/functions/v1/rb-bootstrap?r=b84fd76c51a903e2c4175a60"

local env=_G
if type(getgenv)=="function"then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table"then env=v end
end

local compiler=loadstring or env.loadstring
if type(compiler)~="function"then
    error("RockBugHub MAIN "..VERSION..": executor has no loadstring",0)
end

local function run(url,label)
    local stamp="&v=main-"..VERSION.."-"..tostring(os.time()).."-"..tostring(math.random(100000,999999))
    local ok,source=pcall(function()
        return game:HttpGet(url..stamp,true)
    end)
    if not ok or type(source)~="string"then
        error("RockBugHub MAIN "..VERSION..": failed to load "..label.." • "..tostring(source),0)
    end

    local chunk,problem=compiler(source)
    if type(chunk)~="function"then
        error("RockBugHub MAIN "..VERSION..": compile "..label.." • "..tostring(problem),0)
    end
    return chunk()
end

return run(CORE_URL,"protected core")
