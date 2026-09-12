-- BGS Legacy Hub: stable entrypoint, single runtime (no stacked patches).
local URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/BGS_Legacy_Hub_v0_1/BGS_Legacy_Hub_v0_6_0.lua?v=0.6.1"
local ok,source=pcall(function() return game:HttpGet(URL) end)
if not ok or type(source)~="string" or #source<100 then error("BGS 0.6: загрузка не удалась · "..tostring(source),0) end
local chunk,err=loadstring(source)
if not chunk then error("BGS 0.6: ошибка компиляции · "..tostring(err),0) end
return chunk()
