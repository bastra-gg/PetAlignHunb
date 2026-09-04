-- RockBugHub portable bootstrap. The game features remain in the core.
local VERSION = "4.19.1"
local BASE_URL = "https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/ML_TradeOnlyFix_v2_core.lua"
local CONTRACT = "-- RockBugHub core startup contract: 1"
local environment = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then environment = value end
end

local report = {version = VERSION, stage = "waiting", attempts = {}, success = false}
pcall(function() environment.RockBugLaunchReport = report end)
local statusGui, statusLabel
local Players = game:GetService("Players")

local function showStatus(message, isError)
    warn("[RockBugHub Loader " .. VERSION .. "] " .. tostring(message))
    -- A notification must never be able to abort the loader.
    pcall(function()
        if not statusGui or not statusGui.Parent then
            local player = Players.LocalPlayer
            local parent = player and player:FindFirstChildOfClass("PlayerGui")
            if not parent then return end
            local old = parent:FindFirstChild("RBHLaunchStatus")
            if old then old:Destroy() end
            statusGui = Instance.new("ScreenGui")
            statusGui.Name = "RBHLaunchStatus"
            statusGui.ResetOnSpawn = false
            statusGui.DisplayOrder = 1000000
            statusGui.IgnoreGuiInset = true
            statusGui.Parent = parent
            statusLabel = Instance.new("TextLabel")
            statusLabel.Name = "Status"
            statusLabel.AnchorPoint = Vector2.new(0.5, 0)
            statusLabel.Position = UDim2.new(0.5, 0, 0, 18)
            statusLabel.Size = UDim2.new(0.9, 0, 0, 76)
            statusLabel.BackgroundColor3 = Color3.fromRGB(16, 19, 25)
            statusLabel.BackgroundTransparency = 0.08
            statusLabel.BorderSizePixel = 0
            statusLabel.Font = Enum.Font.GothamBold
            statusLabel.TextSize = 14
            statusLabel.TextWrapped = true
            statusLabel.ZIndex = 1000000
            statusLabel.Parent = statusGui
            local limit = Instance.new("UISizeConstraint")
            limit.MaxSize = Vector2.new(520, 100)
            limit.Parent = statusLabel
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 10)
            corner.Parent = statusLabel
        end
        statusLabel.Text = "RockBugHub " .. VERSION .. "\n" .. tostring(message):sub(1, 240)
        statusLabel.TextColor3 = isError and Color3.fromRGB(255, 120, 130) or Color3.fromRGB(185, 155, 255)
    end)
end

local function traceError(err)
    local message = tostring(err)
    if debug and type(debug.traceback) == "function" then
        local ok, trace = pcall(debug.traceback, message, 2)
        if ok then return trace end
    end
    return message
end

local function waitFor(check, seconds, message)
    local deadline = os.clock() + seconds
    repeat
        if check() then return end
        task.wait(0.1)
    until os.clock() >= deadline
    error(message, 0)
end

local function timedCall(callback, seconds)
    local done, ok, value = false, false, nil
    task.spawn(function()
        ok, value = pcall(callback)
        done = true
    end)
    local deadline = os.clock() + seconds
    while not done and os.clock() < deadline do task.wait(0.05) end
    -- Late HTTP replies are ignored; they never compile or execute the core.
    if not done then return false, "тайм-аут HTTP" end
    return ok, value
end

local function validSource(source)
    return type(source) == "string"
        and source:find(CONTRACT, 1, true) ~= nil
        and source:find('local m="' .. VERSION .. '"', 1, true) ~= nil
        and source:find("q.startupReady=true", 1, true) ~= nil
end

local function downloadCore()
    local transports = {}
    local seen = {}
    local function add(name, fn)
        if type(fn) ~= "function" or seen[fn] then return end
        seen[fn] = true
        table.insert(transports, {name = name, get = function(url)
            local response = fn({Url = url, Method = "GET"})
            if type(response) ~= "table" then error("HTTP API вернул не таблицу", 0) end
            local code = tonumber(response.StatusCode or response.Status)
            if (code and (code < 200 or code >= 300)) or response.Success == false then
                error("HTTP " .. tostring(code or response.StatusMessage or "failed"), 0)
            end
            local body = response.Body or response.body
            if type(body) ~= "string" then error("нет тела HTTP-ответа", 0) end
            return body
        end})
    end
    table.insert(transports, {name = "game:HttpGet", get = function(url)
        return game:HttpGet(url)
    end})
    add("request", request)
    add("http_request", http_request)
    if type(http) == "table" then add("http.request", http.request) end
    if type(syn) == "table" then add("syn.request", syn.request) end
    if type(fluxus) == "table" then add("fluxus.request", fluxus.request) end
    -- Some environments expose executor APIs only in their shared table.
    if type(environment) == "table" then
        add("getgenv.request", environment.request)
        add("getgenv.http_request", environment.http_request)
    end
    local urls = {
        BASE_URL .. "?v=" .. VERSION .. "&cb=" .. tostring(os.time()),
        BASE_URL,
    }
    local deadline = os.clock() + 45
    for _, url in ipairs(urls) do
        for _, transport in ipairs(transports) do
            local remaining = deadline - os.clock()
            if remaining <= 0 then error("Загрузка ядра: превышено 45 секунд. См. консоль.", 0) end
            local ok, source = timedCall(function() return transport.get(url) end, math.min(12, remaining))
            if ok and validSource(source) then
                report.transport = transport.name
                return source
            end
            local problem = ok and "неполное/устаревшее ядро или не Lua-файл" or tostring(source)
            local attempt = transport.name .. ": " .. problem
            table.insert(report.attempts, attempt)
            warn("[RockBugHub HTTP] " .. attempt)
        end
    end
    error("Ядро не загружено: " .. tostring(report.attempts[#report.attempts]), 0)
end

local ok, failure = xpcall(function()
    showStatus("Ожидание игры и игрока...", false)
    waitFor(function() return game:IsLoaded() end, 60, "Игра не загрузилась за 60 секунд")
    waitFor(function() return Players.LocalPlayer ~= nil end, 60, "LocalPlayer не появился за 60 секунд")
    waitFor(function() return Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") ~= nil end, 60, "PlayerGui не появился за 60 секунд")
    local compiler = loadstring
    if type(compiler) ~= "function" then compiler = environment.loadstring end
    if type(compiler) ~= "function" then error("Исполнитель не предоставляет loadstring", 0) end
    report.stage = "download"
    showStatus("1/3: загрузка ядра...", false)
    local source = downloadCore()
    report.stage = "compile"
    showStatus("2/3: компиляция ядра...", false)
    local compiled, chunk, compileError = pcall(compiler, source)
    if not compiled then error("Ошибка компилятора: " .. tostring(chunk), 0) end
    if type(chunk) ~= "function" then error("Ошибка компиляции: " .. tostring(compileError), 0) end
    report.stage = "startup"
    showStatus("3/3: создание интерфейса...", false)
    local runtime = chunk()
    if type(runtime) ~= "table" or runtime.startupReady ~= true
        or runtime.alive ~= true or not runtime.uiRoot or not runtime.uiRoot.Parent then
        error("Ядро не подтвердило создание интерфейса. См. консоль.", 0)
    end
    report.stage = "ready"
    report.success = true
end, traceError)

if not ok then
    report.error = tostring(failure)
    showStatus("Ошибка [" .. report.stage .. "]: " .. report.error .. "\nПолная ошибка — в консоли исполнителя.", true)
    return
end
if statusGui then pcall(function() statusGui:Destroy() end) end
