-- BGS Legacy Hub loader -> v0.3 core
local URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Legacy_Hub_v0_3_core.lua"
local ok,source=pcall(function() return game:HttpGet(URL) end)
if not ok then error("BGS loader HttpGet failed: "..tostring(source),0) end
local chunk,compileError=loadstring(source)
if not chunk then error("BGS core compile failed: "..tostring(compileError),0) end
return chunk()
