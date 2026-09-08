-- BGS Legacy Hub loader -> v0.4 core + v0.4.6 feature patch + v0.4.7 version patch
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Legacy_Hub_v0_4_core.lua"
local PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_RealTP_CurrentIslandCollect_v0_4_6.lua"
local VERSION_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_VersionPatch_v0_4_7.lua"

local okCore,coreSource=pcall(function() return game:HttpGet(CORE_URL) end)
if not okCore then error("BGS loader HttpGet failed: "..tostring(coreSource),0) end
local coreChunk,coreCompileError=loadstring(coreSource)
if not coreChunk then error("BGS core compile failed: "..tostring(coreCompileError),0) end
local S=coreChunk()

local okPatch,patchSource=pcall(function() return game:HttpGet(PATCH_URL) end)
if okPatch then
    local patchChunk,patchCompileError=loadstring(patchSource)
    if patchChunk then
        local patch=patchChunk()
        if type(patch)=="function" then
            local okApply,result=pcall(patch,S)
            if okApply and result then S=result elseif not okApply then warn("BGS v0.4.6 patch apply failed: "..tostring(result)) end
        end
    else
        warn("BGS v0.4.6 patch compile failed: "..tostring(patchCompileError))
    end
else
    warn("BGS v0.4.6 patch HttpGet failed: "..tostring(patchSource))
end

local okVersion,versionSource=pcall(function() return game:HttpGet(VERSION_PATCH_URL) end)
if okVersion then
    local versionChunk,versionCompileError=loadstring(versionSource)
    if versionChunk then
        local versionPatch=versionChunk()
        if type(versionPatch)=="function" then
            local okApply,result=pcall(versionPatch,S)
            if okApply and result then S=result elseif not okApply then warn("BGS v0.4.7 version patch apply failed: "..tostring(result)) end
        end
    else
        warn("BGS v0.4.7 version patch compile failed: "..tostring(versionCompileError))
    end
else
    warn("BGS v0.4.7 version patch HttpGet failed: "..tostring(versionSource))
end

return S
