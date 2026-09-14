-- RockBugHub TEST bootstrap T39: preserved T38 core + direct boss-chest test patch
local VERSION="4.31HOLO-T39"
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_v1_5_core.lua"
local PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_TEST_BossChestDirect.lua"
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
env.RockBugTestVersion=VERSION
local compiler=loadstring or env.loadstring
if type(compiler)~="function"then error("RockBugHub TEST "..VERSION..": executor has no loadstring",0)end
local function run(url,label)
    local stamp="?v="..VERSION.."-"..tostring(os.time()).."-"..tostring(math.random(100000,999999))
    local ok,source=pcall(function()return game:HttpGet(url..stamp,true)end)
    if not ok or type(source)~="string"then error("RockBugHub TEST "..VERSION..": failed to load "..label.." • "..tostring(source),0)end
    local chunk,problem=compiler(source)
    if type(chunk)~="function"then error("RockBugHub TEST "..VERSION..": compile "..label.." • "..tostring(problem),0)end
    return chunk()
end
local result=run(CORE_URL,"core")
local runtime=env.RockBugRuntime or result
if type(runtime)=="table"then runtime.testVersion=VERSION end
local ok,problem=pcall(function()run(PATCH_URL,"direct chest patch")end)
if not ok then warn("[RockBugHub TEST "..VERSION.."] chest patch failed: "..tostring(problem))end
pcall(function()
    local pg=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    for _,obj in ipairs(pg:GetDescendants())do
        if (obj:IsA("TextLabel")or obj:IsA("TextButton"))and type(obj.Text)=="string"and obj.Text:find("4.31HOLO%-T38")then
            obj.Text=obj.Text:gsub("4.31HOLO%-T38",VERSION)
        end
    end
end)
return runtime
