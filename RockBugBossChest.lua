-- RockBugBossChest portable loader
local VERSION="1.0.0"
local URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugBossChest_core.lua"
local CONTRACT="-- RockBugBossChest core contract: 1"
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local Players=game:GetService("Players")
if not game:IsLoaded()then game.Loaded:Wait()end
while not Players.LocalPlayer do task.wait()end
local function get(url)
 local ok,body=pcall(function()return game:HttpGet(url)end)
 if ok and type(body)=="string"and body:find(CONTRACT,1,true)then return body end
 local transports={request,http_request}
 if type(syn)=="table"then transports[#transports+1]=syn.request end
 if type(http)=="table"then transports[#transports+1]=http.request end
 if type(fluxus)=="table"then transports[#transports+1]=fluxus.request end
 for _,fn in ipairs(transports)do
  if type(fn)=="function"then
   local good,res=pcall(fn,{Url=url,Method="GET",Headers={["Cache-Control"]="no-cache"}})
   if good and type(res)=="table"then local text=res.Body or res.body;if type(text)=="string"and text:find(CONTRACT,1,true)then return text end end
  end
 end
 error("RockBugBossChest: core download failed",0)
end
local compiler=loadstring or env.loadstring
if type(compiler)~="function"then error("RockBugBossChest: executor has no loadstring",0)end
local src=get(URL.."?v="..VERSION.."&t="..tostring(os.time()))
local chunk,compileError=compiler(src)
if type(chunk)~="function"then error("RockBugBossChest compile: "..tostring(compileError),0)end
local runtime=chunk()
if type(runtime)~="table"or runtime.startupReady~=true then error("RockBugBossChest: core did not start",0)end
return runtime
