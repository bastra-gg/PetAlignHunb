-- BGS Legacy Hub loader -> v0.5.1
-- Clean chain: core -> v0.5.0 features -> v0.5.1 fix.
-- Old 0.4.6 / 0.4.8 wrappers are intentionally removed to avoid stacked Tick/Refresh scans.

local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Legacy_Hub_v0_4_core.lua"
local FEATURE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Features_v0_5_0.lua?v=0.5.0"
local FIX_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Fix_v0_5_1.lua?v=0.5.1"

local function loadRemote(url,label,required)
    local ok,source=pcall(function() return game:HttpGet(url) end)
    if not ok then
        if required then error(label.." HttpGet failed: "..tostring(source),0) end
        warn(label.." HttpGet failed: "..tostring(source))
        return nil
    end
    local chunk,compileError=loadstring(source)
    if not chunk then
        if required then error(label.." compile failed: "..tostring(compileError),0) end
        warn(label.." compile failed: "..tostring(compileError))
        return nil
    end
    return chunk()
end

local function applyPatch(S,url,label,required)
    local patch=loadRemote(url,label,required)
    if type(patch)~="function" then return S end
    local ok,result=pcall(patch,S)
    if ok and result then return result end
    if not ok then
        if required then error(label.." apply failed: "..tostring(result),0) end
        warn(label.." apply failed: "..tostring(result))
    end
    return S
end

local S=loadRemote(CORE_URL,"BGS core",true)
S=applyPatch(S,FEATURE_URL,"BGS v0.5.0 feature patch",true)
S=applyPatch(S,FIX_URL,"BGS v0.5.1 farm/TP fix",true)
return S
