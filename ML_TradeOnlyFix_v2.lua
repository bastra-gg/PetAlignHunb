local VERSION = "4.18"
local CORE_URL = "https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/ML_TradeOnlyFix_v2_core.lua?v=" .. VERSION

local StarterGui = game:GetService("StarterGui")

local function notify(message, duration)
    warn("[RockBugHub Loader] " .. tostring(message))
    task.spawn(function()
        for _ = 1, 4 do
            local ok = pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "RockBugHub " .. VERSION,
                    Text = tostring(message),
                    Duration = duration or 7,
                })
            end)
            if ok then
                return
            end
            task.wait(0.5)
        end
    end)
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

notify("Загрузка ядра...", 3)

if type(loadstring) ~= "function" then
    notify("Исполнитель не поддерживает loadstring", 10)
    return
end

local downloaded, source = pcall(function()
    return game:HttpGet(CORE_URL, false)
end)

if not downloaded or type(source) ~= "string" or #source < 100000 then
    notify("Не удалось скачать ядро: " .. tostring(source):sub(1, 90), 10)
    return
end

local chunk, compileError = loadstring(source)
if type(chunk) ~= "function" then
    notify("Ошибка компиляции: " .. tostring(compileError):sub(1, 100), 12)
    return
end

local ran, runtimeError = xpcall(chunk, function(err)
    local trace = ""
    if debug and type(debug.traceback) == "function" then
        trace = "\n" .. tostring(debug.traceback())
    end
    return tostring(err) .. trace
end)

if not ran then
    notify("Ошибка запуска: " .. tostring(runtimeError):sub(1, 100), 12)
end
