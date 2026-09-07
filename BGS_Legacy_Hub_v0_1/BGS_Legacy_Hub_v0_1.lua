-- BGS Legacy Hub loader -> v0.4 core + v0.4.3 native canonical TP patch
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Legacy_Hub_v0_4_core.lua"
local PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Canonical_RemoteTP_Patch_v0_4_3.lua"

local okCore,coreSource=pcall(function() return game:HttpGet(CORE_URL) end)
if not okCore then error("BGS loader HttpGet failed: "..tostring(coreSource),0) end
local coreChunk,coreCompileError=loadstring(coreSource)
if not coreChunk then error("BGS core compile failed: "..tostring(coreCompileError),0) end
local S=coreChunk()

local okPatch,patchSource=pcall(function() return game:HttpGet(PATCH_URL) end)
if not okPatch then
    warn("BGS native TP patch HttpGet failed: "..tostring(patchSource))
    return S
end
local patchChunk,patchCompileError=loadstring(patchSource)
if not patchChunk then
    warn("BGS native TP patch compile failed: "..tostring(patchCompileError))
    return S
end
local patch=patchChunk()
if type(patch)=="function" then
    local okApply,result=pcall(patch,S)
    if okApply and result then
        S=result
    elseif not okApply then
        warn("BGS native TP patch apply failed: "..tostring(result))
    end
end
return S
