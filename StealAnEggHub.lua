-- EggHub portable loader
local VERSION = "1.1.0-safe"
local URL = "https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/StealAnEggHub_safe_core.lua"
local CONTRACT = "-- EggHub core startup contract: 1"

local env = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then env = value end
end

local Players = game:GetService("Players")
if not game:IsLoaded() then game.Loaded:Wait() end
while not Players.LocalPlayer do task.wait() end

local function httpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and body:find(CONTRACT,1,true) then return body end

    local transports = {request, http_request}
    if type(syn)=="table" then transports[#transports+1]=syn.request end
    if type(http)=="table" then transports[#transports+1]=http.request end
    for _, fn in ipairs(transports) do
        if type(fn)=="function" then
            local good, response = pcall(fn, {Url=url, Method="GET", Headers={['Cache-Control']='no-cache'}})
            if good and type(response)=="table" then
                local text=response.Body or response.body
                if type(text)=="string" and text:find(CONTRACT,1,true) then return text end
            end
        end
    end
    error("EggHub: core download failed",0)
end

local compiler = loadstring or env.loadstring
if type(compiler) ~= "function" then error("EggHub: executor has no loadstring",0) end
local source = httpGet(URL.."?v="..VERSION.."&t="..tostring(os.time()))
local chunk, compileError = compiler(source)
if type(chunk) ~= "function" then error("EggHub compile: "..tostring(compileError),0) end
local runtime = chunk()
if type(runtime) ~= "table" or runtime.startupReady ~= true then error("EggHub: core did not start",0) end
return runtime
