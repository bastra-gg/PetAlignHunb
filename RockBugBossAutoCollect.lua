-- RockBug Boss AutoCollect compatibility launcher.
-- Uses the paid v1.6 loader; all authorization and module integrity checks
-- remain inside RockBugBoss.lua and its protected backend.
local url = "https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugBoss.lua"
local ok, source = pcall(function()
    return game:HttpGet(url, true)
end)
if not ok then
    error("RockBug Boss AutoCollect: loader download failed: " .. tostring(source), 0)
end
if type(source) ~= "string" or source == "" or source:match("^%s*404:") then
    error("RockBug Boss AutoCollect: empty or missing loader", 0)
end
local compile = loadstring
if type(compile) ~= "function" and type(getgenv) == "function" then
    local envOk, env = pcall(getgenv)
    if envOk and type(env) == "table" then compile = env.loadstring end
end
if type(compile) ~= "function" then
    error("RockBug Boss AutoCollect: executor lacks loadstring", 0)
end
local chunk, problem = compile(source)
if type(chunk) ~= "function" then
    error("RockBug Boss AutoCollect: loader compile failed: " .. tostring(problem), 0)
end
return chunk()
