-- RockBug Boss launcher v1.9
-- Both Boss entry points use the same native Luau runtime and server key checks.
local SOURCE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugBossAutoCollect.lua"
local env=_G
if type(getgenv)=="function" then
 local ok,value=pcall(getgenv)
 if ok and type(value)=="table" then env=value end
end
local compiler=loadstring or env.loadstring
if type(compiler)~="function" then error("RockBug Boss: исполнитель не поддерживает loadstring",0) end

local function notify(text)
 warn("[RockBug Boss] "..text)
 pcall(function()game:GetService("StarterGui"):SetCore("SendNotification",{Title="RockBug Boss",Text=text,Duration=12})end)
end
local function valid(body)
 return type(body)=="string" and #body>1000 and #body<1000000
  and body:find("-- RockBugBossAutoCollect",1,true)==1
end
local function download()
 local url=SOURCE_URL.."?v=1.9-"..tostring(os.time()).."-"..tostring(math.random(100000,999999))
 local ok,body=pcall(function()return game:HttpGet(url,true)end)
 if ok and valid(body) then return body end
 -- Some executors expose HTTP only through request; reject HTTP error pages.
 local candidates={}
 local function add(fn)if type(fn)=="function" then candidates[#candidates+1]=fn end end
 add(request) add(http_request) add(env.request) add(env.http_request)
 for _,provider in ipairs({"syn","fluxus","http"})do
  local object=env[provider]
  if type(object)=="table" then add(object.request) end
 end
 local seen={}
 for _,fn in ipairs(candidates)do
  if not seen[fn] then
   seen[fn]=true
   local good,result=pcall(fn,{Url=url,Method="GET",Headers={["Cache-Control"]="no-cache"},Timeout=12})
   if good then
    local status=type(result)=="table" and tonumber(result.StatusCode or result.status_code) or 200
    local text=type(result)=="table" and (result.Body or result.body) or result
    if (not status or status>=200 and status<300) and valid(text) then return text end
   end
  end
 end
 error("Не удалось скачать Boss. Проверь интернет и доступ исполнителя к GitHub.",0)
end
local done,cancelled,downloaded=false,false,false
-- Timeouts stay visible instead of an endless silent startup.
task.delay(25,function()
 if not done and not downloaded then cancelled=true notify("Загрузка заняла больше 25 секунд. Повтори запуск.")end
end)
local ok,result=pcall(function()
 local source=download()
 if cancelled then error("Время загрузки истекло",0)end
 downloaded=true
 local chunk,problem=compiler(source,"@RockBugBoss")
 if type(chunk)~="function" then error("Ошибка сборки Boss: "..tostring(problem),0)end
 local runtime=chunk()
 if type(runtime)~="table" or runtime.alive~=true then error("Boss не завершил запуск. Повтори вход в игру.",0)end
 return runtime
end)
done=true
if not ok then notify(tostring(result)) error(result,0)end
return result
