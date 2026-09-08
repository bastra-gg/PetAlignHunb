-- BGS Legacy Hub -> CLEAN v0.5.2
local URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Legacy_Hub_v0_5_2.lua?v=0.5.2-loader"
local ok,source=pcall(function() return game:HttpGet(URL) end)
if not ok then error("BGS v0.5.2 loader HttpGet failed: "..tostring(source),0) end
local chunk,err=loadstring(source)
if not chunk then error("BGS v0.5.2 loader compile failed: "..tostring(err),0) end
return chunk()
