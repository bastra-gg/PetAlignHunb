-- BGS Legacy Hub loader -> v0.5.0
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Legacy_Hub_v0_4_core.lua"
local ISLAND_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_RealTP_CurrentIslandCollect_v0_4_6.lua"
local COIN_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_CoinFarmFix_v0_4_8.lua"
local FEATURE_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Features_v0_5_0.lua?v=0.5.0"

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
S=applyPatch(S,ISLAND_PATCH_URL,"BGS v0.4.6 island patch",false)
S=applyPatch(S,COIN_PATCH_URL,"BGS v0.4.8 coin patch",false)
S=applyPatch(S,FEATURE_PATCH_URL,"BGS v0.5.0 feature patch",true)
return S
