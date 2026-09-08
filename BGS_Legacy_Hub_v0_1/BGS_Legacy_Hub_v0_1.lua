-- BGS Legacy Hub loader -> v0.4 core + v0.4.6 island patch + v0.4.8 coin farm fix
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Legacy_Hub_v0_4_core.lua"
local ISLAND_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_RealTP_CurrentIslandCollect_v0_4_6.lua"
local COIN_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_CoinFarmFix_v0_4_8.lua"

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

local S=loadRemote(CORE_URL,"BGS core",true)

local islandPatch=loadRemote(ISLAND_PATCH_URL,"BGS v0.4.6 island patch",false)
if type(islandPatch)=="function" then
    local ok,result=pcall(islandPatch,S)
    if ok and result then S=result elseif not ok then warn("BGS v0.4.6 island patch apply failed: "..tostring(result)) end
end

local coinPatch=loadRemote(COIN_PATCH_URL,"BGS v0.4.8 coin patch",false)
if type(coinPatch)=="function" then
    local ok,result=pcall(coinPatch,S)
    if ok and result then S=result elseif not ok then warn("BGS v0.4.8 coin patch apply failed: "..tostring(result)) end
end

return S
