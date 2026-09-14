-- RockBugHub TEST bootstrap: preserved T38 core + direct boss-chest test patch
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_v1_5_core.lua"
local PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_TEST_BossChestDirect.lua"
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local compiler=loadstring or env.loadstring
if type(compiler)~="function"then error("RockBugHub TEST: executor has no loadstring",0)end
local function run(url,label)
    local stamp="?v="..tostring(os.time()).."-"..tostring(math.random(100000,999999))
    local ok,source=pcall(function()return game:HttpGet(url..stamp,true)end)
    if not ok or type(source)~="string"then error("RockBugHub TEST: failed to load "..label.." • "..tostring(source),0)end
    local chunk,problem=compiler(source)
    if type(chunk)~="function"then error("RockBugHub TEST: compile "..label.." • "..tostring(problem),0)end
    return chunk()
end
local result=run(CORE_URL,"core")
local runtime=env.RockBugRuntime or result
local ok,problem=pcall(function()run(PATCH_URL,"direct chest patch")end)
if not ok then warn("[RockBugHub TEST] chest patch failed: "..tostring(problem))end
return runtime
