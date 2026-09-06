-- RockBugHub cache-busting bootstrap
local URL = "https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_v1_5_core.lua"
local function fetch(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 1000 then return body end
    return nil, body
end
local src, err = fetch(URL .. "?cb=" .. tostring(os.time()))
if not src then src, err = fetch(URL) end
if not src then error("RockBugHub download failed: " .. tostring(err), 0) end
local fn, compileErr = loadstring(src)
if not fn then error("RockBugHub compile failed: " .. tostring(compileErr), 0) end
return fn()
