-- BGS Legacy Hub CLEAN loader v0.5.2
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Legacy_Hub_v0_4_core.lua?v=0.5.2-core"
local PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_CleanPatch_v0_5_2.lua?v=0.5.2-clean"

local function loadRemote(url,label)
    local ok,source=pcall(function() return game:HttpGet(url) end)
    if not ok then error(label.." HttpGet failed: "..tostring(source),0) end
    local chunk,err=loadstring(source)
    if not chunk then error(label.." compile failed: "..tostring(err),0) end
    return chunk()
end

local S=loadRemote(CORE_URL,"BGS core")
local patch=loadRemote(PATCH_URL,"BGS v0.5.2 clean patch")
if type(patch)~="function" then error("BGS v0.5.2 patch did not return a function",0) end
local ok,result=pcall(patch,S)
if not ok then error("BGS v0.5.2 apply failed: "..tostring(result),0) end
return result or S
