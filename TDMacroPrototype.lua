-- TD Macro Lab V1
-- Input-driven tower-defense macro recorder. No game remotes are required.

local VERSION = 2
local ROOT_FOLDER = "TDMacroLab"
local CONFIG_FILE = ROOT_FOLDER .. "/config.json"
local FALLBACK_FILE = "td_macro_v2.json"
local LEGACY_FILE = "td_macro_prototype.json"

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
if not player then return end

local env = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then env = value end
end

if env.TDMacroPrototype and type(env.TDMacroPrototype.Destroy) == "function" then
    pcall(function() env.TDMacroPrototype:Destroy() end)
end
if env.TDMacroLab and env.TDMacroLab ~= env.TDMacroPrototype and type(env.TDMacroLab.Destroy) == "function" then
    pcall(function() env.TDMacroLab:Destroy() end)
end

local Core = {}

function Core.cleanText(value)
    local text = string.lower(tostring(value or ""))
    local upper = {"А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"}
    local lower = {"а","б","в","г","д","е","ё","ж","з","и","й","к","л","м","н","о","п","р","с","т","у","ф","х","ц","ч","ш","щ","ъ","ы","ь","э","ю","я"}
    for index, letter in ipairs(upper) do text = text:gsub(letter, lower[index]) end
    text = text:gsub("[%s_%-]+", " ")
    text = text:gsub("[^%w%s\128-\255]", "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Core.round(value, step)
    step = step or 1
    return math.floor((tonumber(value) or 0) / step + 0.5) * step
end

function Core.fingerprintKey(fingerprint)
    fingerprint = type(fingerprint) == "table" and fingerprint or {}
    return table.concat({
        tostring(fingerprint.placeId or 0),
        tostring(fingerprint.mapKey or "unknown"),
        tostring(fingerprint.spawnKey or "unknown"),
    }, "::")
end

function Core.eventPoint(event, currentViewport, recordedViewport)
    currentViewport = currentViewport or {w = 1, h = 1}
    local width = math.max(1, tonumber(currentViewport.w) or 1)
    local height = math.max(1, tonumber(currentViewport.h) or 1)
    local recordedWidth = tonumber(event.vw) or tonumber(recordedViewport and recordedViewport.w)
    local recordedHeight = tonumber(event.vh) or tonumber(recordedViewport and recordedViewport.h)
    if tonumber(event.x) and tonumber(event.y) and recordedWidth and recordedHeight
        and math.abs(width - recordedWidth) <= 2 and math.abs(height - recordedHeight) <= 2 then
        return math.floor(event.x + 0.5), math.floor(event.y + 0.5)
    end
    if tonumber(event.nx) and tonumber(event.ny) then
        return math.floor(event.nx * width + 0.5), math.floor(event.ny * height + 0.5)
    end
    return math.floor(tonumber(event.x) or width / 2), math.floor(tonumber(event.y) or height / 2)
end

function Core.normalizeEvents(events, recordedViewport)
    local output = {}
    local width = math.max(1, tonumber(recordedViewport and recordedViewport.w) or 1)
    local height = math.max(1, tonumber(recordedViewport and recordedViewport.h) or 1)
    for index, source in ipairs(type(events) == "table" and events or {}) do
        if type(source) == "table" and type(source.kind) == "string" and not source._discard then
            local event = {}
            for key, value in pairs(source) do event[key] = value end
            event._discard = nil
            event.t = math.max(0, tonumber(event.t) or 0)
            event._order = index
            if tonumber(event.x) and tonumber(event.y) then
                event.nx = tonumber(event.nx) or math.clamp(event.x / width, 0, 1)
                event.ny = tonumber(event.ny) or math.clamp(event.y / height, 0, 1)
            end
            output[#output + 1] = event
        end
    end
    table.sort(output, function(a, b)
        if a.t == b.t then return a._order < b._order end
        return a.t < b.t
    end)
    local touchDown = {}
    for _, event in ipairs(output) do
        if event.touch and event.kind == "mouse_down" then
            touchDown[tonumber(event.touchId) or 1] = event
        elseif event.touch and event.kind == "mouse_up" then
            local id = tonumber(event.touchId) or 1
            local down = touchDown[id]
            if down and tonumber(down.x) and tonumber(down.y) and tonumber(event.x) and tonumber(event.y) then
                local distance = (Vector2.new(event.x, event.y) - Vector2.new(down.x, down.y)).Magnitude
                local duration = event.t - down.t
                if distance >= 18 or (distance >= 8 and duration >= 0.3) then
                    down._drop = true
                    event._drop = true
                end
            end
            touchDown[id] = nil
        end
    end
    local filtered = {}
    for _, event in ipairs(output) do
        event._order = nil
        if not event._drop then filtered[#filtered + 1] = event end
        event._drop = nil
    end
    return filtered
end

function Core.normalizeMacro(source, fallbackName)
    source = type(source) == "table" and source or {}
    local recordedViewport = type(source.viewport) == "table" and source.viewport or {w = 1920, h = 1080}
    local macroFingerprint = type(source.fingerprint) == "table" and source.fingerprint or {
        placeId = tonumber(source.placeId) or game.PlaceId,
        mapKey = tostring(source.tag or source.placeId or game.PlaceId),
        spawnKey = "legacy",
    }
    macroFingerprint.placeId = tonumber(macroFingerprint.placeId) or tonumber(source.placeId) or game.PlaceId
    macroFingerprint.mapKey = tostring(macroFingerprint.mapKey or source.tag or "unknown")
    macroFingerprint.spawnKey = tostring(macroFingerprint.spawnKey or "legacy")
    local events = source.events or source.actions or {}
    return {
        version = VERSION,
        id = tostring(source.id or HttpService:GenerateGUID(false)),
        name = tostring(source.name or fallbackName or "Macro"),
        placeId = tonumber(source.placeId) or macroFingerprint.placeId,
        fingerprint = macroFingerprint,
        fingerprintKey = Core.fingerprintKey(macroFingerprint),
        settings = type(source.settings) == "table" and source.settings or {
            loop = true, x2 = true, autoSkip = true, autoPlayAgain = true,
        },
        viewport = {w = tonumber(recordedViewport.w) or 1920, h = tonumber(recordedViewport.h) or 1080},
        camera = type(source.camera) == "table" and source.camera or macroFingerprint.camera,
        slots = type(source.slots) == "table" and source.slots or {"1", "2", "3", "4", "5"},
        events = Core.normalizeEvents(events, recordedViewport),
        savedAt = tonumber(source.savedAt) or os.time(),
        lastUsed = tonumber(source.lastUsed) or 0,
        isDefault = source.isDefault == true,
        legacy = (tonumber(source.version) or 0) < VERSION,
    }
end

function Core.chooseMacro(macros, currentFingerprint, manualMatches)
    local key = Core.fingerprintKey(currentFingerprint)
    local candidates = {}
    for _, macro in ipairs(type(macros) == "table" and macros or {}) do
        local macroKey = tostring(macro.fingerprintKey or Core.fingerprintKey(macro.fingerprint))
        if macroKey == key or (type(manualMatches) == "table" and manualMatches[key] == macro.id) then
            candidates[#candidates + 1] = macro
        end
    end
    table.sort(candidates, function(a, b)
        if (a.isDefault == true) ~= (b.isDefault == true) then return a.isDefault == true end
        if (tonumber(a.lastUsed) or 0) ~= (tonumber(b.lastUsed) or 0) then
            return (tonumber(a.lastUsed) or 0) > (tonumber(b.lastUsed) or 0)
        end
        return (tonumber(a.savedAt) or 0) > (tonumber(b.savedAt) or 0)
    end)
    return candidates[1], candidates
end

local aliases = {
    x2 = {"x2", "2x", "speed", "скорость"},
    autoSkip = {"auto skip", "autoskip", "skip", "пропуск", "авто пропуск"},
    playAgain = {"play again", "replay", "retry", "again", "играть снова", "сыграть снова", "повторить"},
}

function Core.bindingScore(kind, text, name)
    local clean = Core.cleanText(text)
    local cleanName = Core.cleanText(name)
    local padded = " " .. clean .. " "
    local paddedName = " " .. cleanName .. " "
    local score = 0
    for _, alias in ipairs(aliases[kind] or {}) do
        local target = Core.cleanText(alias)
        if clean == target then score = math.max(score, 100) end
        if cleanName == target then score = math.max(score, 88) end
        if padded:find(" " .. target .. " ", 1, true) then score = math.max(score, 70) end
        if paddedName:find(" " .. target .. " ", 1, true) then score = math.max(score, 55) end
    end
    return score
end

local defaultConfig = {
    version = VERSION,
    macros = {},
    manualMatches = {},
    bindings = {
        x2 = {mode = "auto"},
        autoSkip = {mode = "auto"},
        playAgain = {mode = "auto"},
    },
    slotLabels = {"1", "2", "3", "4", "5"},
    settings = {
        auto = false,
        autoLoop = true,
        x2 = true,
        autoSkip = true,
        autoPlayAgain = true,
        playbackSpeed = 1,
        lateTolerance = 0.35,
        initialDelay = 1.2,
        endTimeout = 600,
        lockCamera = false,
    },
}

local state = {
    version = VERSION,
    connections = {},
    gui = nil,
    window = nil,
    showButton = nil,
    pages = {},
    rows = {},
    labels = {},
    config = nil,
    selectedId = nil,
    recording = false,
    recordingStarted = 0,
    recordedEvents = {},
    recordingFingerprint = nil,
    recordingViewport = nil,
    recordingCamera = nil,
    currentSlot = nil,
    pendingPlacementSlot = nil,
    nextUnitId = 0,
    touchInputIds = {},
    touchGestures = {},
    nextTouchId = 0,
    playing = false,
    paused = false,
    playToken = 0,
    pauseStarted = 0,
    pauseAccum = 0,
    generatedInput = false,
    pressedKeys = {},
    pressedButtons = {},
    pressedTouches = {},
    controllerState = "IDLE",
    controllerSince = os.clock(),
    controllerNotBefore = 0,
    stableKey = nil,
    stableSince = 0,
    playbackFinishedAt = 0,
    lastFingerprint = nil,
    matchSpawnPosition = nil,
    mapCacheKey = nil,
    mapCacheAt = 0,
    bindingCapture = nil,
    logs = {},
    destroyed = false,
    memoryOnly = false,
}

env.TDMacroPrototype = state
env.TDMacroLab = state

local function keep(connection)
    state.connections[#state.connections + 1] = connection
    return connection
end

local function viewport()
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local insetX, insetY = 0, 0
    pcall(function()
        local topLeft = GuiService:GetGuiInset()
        insetX, insetY = topLeft.X, topLeft.Y
    end)
    return {
        w = math.max(1, math.floor(size.X)),
        h = math.max(1, math.floor(size.Y)),
        insetX = insetX,
        insetY = insetY,
    }
end

local function copyTable(source)
    local result = {}
    for key, value in pairs(type(source) == "table" and source or {}) do
        if type(value) == "table" then result[key] = copyTable(value) else result[key] = value end
    end
    return result
end

local function mergeDefaults(target, defaults)
    target = type(target) == "table" and target or {}
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = type(value) == "table" and copyTable(value) or value
        elseif type(value) == "table" and type(target[key]) == "table" then
            mergeDefaults(target[key], value)
        end
    end
    return target
end

local function selectedMacro()
    for _, macro in ipairs(state.config and state.config.macros or {}) do
        if macro.id == state.selectedId then return macro end
    end
    return nil
end

local function log(message, serious)
    local line = os.date("%H:%M:%S") .. "  " .. tostring(message)
    state.logs[#state.logs + 1] = line
    while #state.logs > 80 do table.remove(state.logs, 1) end
    if serious then warn("[TD Macro] " .. tostring(message)) end
    if state.labels.logText then
        state.labels.logText.Text = table.concat(state.logs, "\n")
        local scroll = state.labels.logScroll
        if scroll then task.defer(function() scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.AbsoluteCanvasSize.Y)) end) end
    end
end

local function canFile()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function readJson(path)
    if not canFile() or not isfile(path) then return nil end
    local ok, raw = pcall(readfile, path)
    if not ok or type(raw) ~= "string" then return nil end
    local decodedOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if decodedOk and type(decoded) == "table" then return decoded end
    return nil
end

local function saveDisk()
    if not canFile() then
        state.memoryOnly = true
        return false
    end
    if type(makefolder) == "function" then pcall(makefolder, ROOT_FOLDER) end
    state.config.version = VERSION
    local ok, encoded = pcall(function() return HttpService:JSONEncode(state.config) end)
    if not ok then log("Не удалось сериализовать config", true) return false end
    local wrote = pcall(writefile, CONFIG_FILE, encoded)
    if not wrote then wrote = pcall(writefile, FALLBACK_FILE, encoded) end
    if not wrote then log("Не удалось сохранить config", true) end
    return wrote
end

local function loadConfig()
    local loaded = readJson(CONFIG_FILE) or readJson(FALLBACK_FILE)
    state.config = mergeDefaults(loaded, copyTable(defaultConfig))
    local normalized = {}
    for index, macro in ipairs(type(state.config.macros) == "table" and state.config.macros or {}) do
        normalized[#normalized + 1] = Core.normalizeMacro(macro, "Macro " .. index)
    end
    state.config.macros = normalized

    local legacy = readJson(LEGACY_FILE)
    if legacy and type(legacy.macros) == "table" then
        local known = {}
        for _, macro in ipairs(state.config.macros) do
            known[macro.id] = true
            known[macro.name .. ":" .. tostring(macro.savedAt)] = true
        end
        local imported = 0
        for index, macro in ipairs(legacy.macros) do
            local normalizedMacro = Core.normalizeMacro(macro, "Imported " .. index)
            local signature = normalizedMacro.name .. ":" .. tostring(normalizedMacro.savedAt)
            if not known[normalizedMacro.id] and not known[signature] then
                normalizedMacro.id = HttpService:GenerateGUID(false)
                normalizedMacro.legacy = true
                state.config.macros[#state.config.macros + 1] = normalizedMacro
                known[signature] = true
                imported += 1
            end
        end
        if imported > 0 then log("Импортировано старых макросов: " .. imported) end
    end
    state.memoryOnly = not canFile()
    saveDisk()
end

local function rootPart()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function cameraSnapshot()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local components = {camera.CFrame:GetComponents()}
    return {
        cframe = components,
        fov = camera.FieldOfView,
        cameraType = camera.CameraType.Name,
    }
end

local function restoreCamera(snapshot)
    local camera = workspace.CurrentCamera
    if not camera or type(snapshot) ~= "table" then return false end
    if type(snapshot.cframe) == "table" and #snapshot.cframe >= 12 then
        pcall(function() camera.CFrame = CFrame.new(table.unpack(snapshot.cframe, 1, 12)) end)
    end
    if tonumber(snapshot.fov) then pcall(function() camera.FieldOfView = snapshot.fov end) end
    return true
end

local function usefulValue(instance)
    if not instance then return nil end
    if instance:IsA("StringValue") or instance:IsA("IntValue") or instance:IsA("NumberValue") then
        local text = tostring(instance.Value)
        if text ~= "" then return text end
    end
    for _, attribute in ipairs({"MapName", "CurrentMap", "Map", "LevelName", "StageName"}) do
        local value = instance:GetAttribute(attribute)
        if value ~= nil and tostring(value) ~= "" then return tostring(value) end
    end
    return nil
end

local function detectMapKey()
    if state.mapCacheKey and os.clock() - state.mapCacheAt < 0.75 then return state.mapCacheKey end
    local function remember(value)
        state.mapCacheKey = value
        state.mapCacheAt = os.clock()
        return value
    end
    local function signatureFor(container)
        local names = {}
        for _, child in ipairs(container:GetChildren()) do
            if not child:IsA("Camera") then names[#names + 1] = child.ClassName .. ":" .. Core.cleanText(child.Name) end
        end
        table.sort(names)
        while #names > 24 do table.remove(names) end
        local source = table.concat(names, "|")
        local hash = 0
        for index = 1, #source do hash = (hash * 33 + string.byte(source, index)) % 2147483647 end
        return tostring(hash)
    end
    for _, attribute in ipairs({"MapName", "CurrentMap", "Map", "LevelName", "StageName"}) do
        local value = workspace:GetAttribute(attribute)
        if value ~= nil and tostring(value) ~= "" then return remember("attr:" .. Core.cleanText(value)) end
    end
    for _, name in ipairs({"CurrentMap", "Map", "ActiveMap"}) do
        local object = workspace:FindFirstChild(name)
        if object then
            local value = usefulValue(object)
            if value then return remember("value:" .. Core.cleanText(value)) end
            if #object:GetChildren() == 1 then
                local child = object:GetChildren()[1]
                return remember("object:" .. Core.cleanText(child.Name) .. ":" .. signatureFor(child))
            end
            return remember("object:" .. Core.cleanText(object.Name) .. ":" .. signatureFor(object))
        end
    end
    local maps = workspace:FindFirstChild("Maps")
    if maps then
        local visible = {}
        for _, child in ipairs(maps:GetChildren()) do
            if child:IsA("Model") or child:IsA("Folder") then visible[#visible + 1] = child.Name end
        end
        if #visible == 1 then return remember("maps:" .. Core.cleanText(visible[1])) end
    end

    local ignored = {
        camera = true, terrain = true, players = true, enemies = true, units = true,
        towers = true, mobs = true, effects = true, projectiles = true, characters = true,
    }
    local names = {}
    for _, child in ipairs(workspace:GetChildren()) do
        local cleaned = Core.cleanText(child.Name)
        if not ignored[cleaned] and not child:IsA("Camera") and not child:IsA("Terrain") then
            names[#names + 1] = child.ClassName .. ":" .. cleaned
        end
    end
    table.sort(names)
    while #names > 16 do table.remove(names) end
    local signature = table.concat(names, "|")
    local hash = 0
    for index = 1, #signature do hash = (hash * 33 + string.byte(signature, index)) % 2147483647 end
    return remember("world:" .. tostring(hash))
end

local function fingerprint(spawnOverride)
    local root = rootPart()
    local position = spawnOverride or (root and root.Position) or Vector3.zero
    local quantized = Vector3.new(Core.round(position.X, 4), Core.round(position.Y, 4), Core.round(position.Z, 4))
    local fp = {
        placeId = game.PlaceId,
        mapKey = detectMapKey(),
        spawnKey = string.format("%.0f,%.0f,%.0f", quantized.X, quantized.Y, quantized.Z),
        spawnPosition = {x = position.X, y = position.Y, z = position.Z},
        camera = cameraSnapshot(),
    }
    fp.key = Core.fingerprintKey(fp)
    return fp
end

local refreshAll = function() end
local refreshMacros = function() end
local refreshBindings = function() end

local function isOwnPoint(x, y)
    if not state.gui then return false end
    local ok, objects = pcall(function() return GuiService:GetGuiObjectsAtPosition(x, y) end)
    if not ok then return false end
    for _, object in ipairs(objects) do
        if object == state.gui or object:IsDescendantOf(state.gui) then return true end
    end
    return false
end

local function instanceVisible(instance)
    if not instance or not instance:IsDescendantOf(game) then return false end
    local current = instance
    while current do
        if current:IsA("GuiObject") and (not current.Visible or current.AbsoluteSize.X < 4 or current.AbsoluteSize.Y < 4) then
            return false
        end
        if current:IsA("LayerCollector") and not current.Enabled then return false end
        current = current.Parent
    end
    return true
end

local function guiPath(instance)
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui or not instance or not instance:IsDescendantOf(playerGui) then return nil end
    local parts = {}
    local current = instance
    while current and current ~= playerGui do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    return parts
end

local function resolveGuiPath(path)
    local current = player:FindFirstChildOfClass("PlayerGui")
    if not current or type(path) ~= "table" then return nil end
    for _, part in ipairs(path) do
        current = current:FindFirstChild(tostring(part))
        if not current then return nil end
    end
    return current
end

local function guiAtPoint(x, y)
    local ok, objects = pcall(function() return GuiService:GetGuiObjectsAtPosition(x, y) end)
    if not ok then return nil end
    for _, object in ipairs(objects) do
        if (object:IsA("GuiButton") or object:IsA("GuiObject")) and not (state.gui and object:IsDescendantOf(state.gui)) then
            return object
        end
    end
    return nil
end

local function eventPosition(input)
    local position = input.Position
    return math.floor(position.X), math.floor(position.Y)
end

local function addRecordedEvent(kind, data)
    if not state.recording or state.generatedInput then return end
    data = data or {}
    data.kind = kind
    data.t = math.max(0, os.clock() - state.recordingStarted)
    state.recordedEvents[#state.recordedEvents + 1] = data
    if state.labels.recordCount then state.labels.recordCount.Text = tostring(#state.recordedEvents) .. " событий" end
    return data
end

local slotCodes = {
    [Enum.KeyCode.One] = 1,
    [Enum.KeyCode.Two] = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four] = 4,
    [Enum.KeyCode.Five] = 5,
}

local function captureBinding(kind, input)
    local inputType = input.UserInputType
    if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then return false end
    local x, y = eventPosition(input)
    if isOwnPoint(x, y) then return false end
    local size = viewport()
    local object = guiAtPoint(x, y)
    state.config.bindings[kind] = {
        mode = "manual",
        nx = math.clamp(x / size.w, 0, 1),
        ny = math.clamp(y / size.h, 0, 1),
        path = guiPath(object),
        objectName = object and object.Name or nil,
    }
    state.bindingCapture = nil
    saveDisk()
    log("Привязка " .. kind .. " сохранена")
    refreshBindings()
    return true
end

keep(UIS.InputBegan:Connect(function(input, processed)
    if state.destroyed or state.generatedInput then return end
    if state.bindingCapture and captureBinding(state.bindingCapture, input) then return end
    if not state.recording then return end

    local inputType = input.UserInputType
    if inputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
        local focused = UIS:GetFocusedTextBox()
        if focused and state.gui and focused:IsDescendantOf(state.gui) then return end
        local slot = slotCodes[input.KeyCode]
        if slot then
            state.currentSlot = slot
            state.pendingPlacementSlot = slot
        end
        addRecordedEvent("key_down", {key = input.KeyCode.Name, slot = slot})
    elseif inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseButton2 or inputType == Enum.UserInputType.Touch then
        local x, y = eventPosition(input)
        if isOwnPoint(x, y) then return end
        local size = viewport()
        local button = inputType == Enum.UserInputType.MouseButton2 and 1 or 0
        local touchId = nil
        if inputType == Enum.UserInputType.Touch then
            state.nextTouchId += 1
            touchId = state.nextTouchId
            state.touchInputIds[input] = touchId
        end
        local metadata = {
            x = x, y = y, nx = math.clamp(x / size.w, 0, 1), ny = math.clamp(y / size.h, 0, 1),
            vw = size.w, vh = size.h,
            button = button, touch = inputType == Enum.UserInputType.Touch,
            touchId = touchId,
            camera = cameraSnapshot(),
        }
        if state.pendingPlacementSlot then
            state.nextUnitId += 1
            metadata.slot = state.pendingPlacementSlot
            metadata.unitId = "u" .. state.nextUnitId
            metadata.semanticHint = "placement"
            state.pendingPlacementSlot = nil
        end
        local recorded = addRecordedEvent("mouse_down", metadata)
        if inputType == Enum.UserInputType.Touch and recorded then
            state.touchGestures[input] = {event = recorded, startX = x, startY = y, moved = false}
        end
    end
end))

keep(UIS.InputEnded:Connect(function(input)
    if state.destroyed or state.generatedInput or not state.recording then return end
    local inputType = input.UserInputType
    if inputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
        local focused = UIS:GetFocusedTextBox()
        if focused and state.gui and focused:IsDescendantOf(state.gui) then return end
        addRecordedEvent("key_up", {key = input.KeyCode.Name, slot = slotCodes[input.KeyCode]})
    elseif inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseButton2 or inputType == Enum.UserInputType.Touch then
        local x, y = eventPosition(input)
        local gesture = inputType == Enum.UserInputType.Touch and state.touchGestures[input] or nil
        if inputType == Enum.UserInputType.Touch then state.touchGestures[input] = nil end
        if gesture and (gesture.moved or (Vector2.new(x, y) - Vector2.new(gesture.startX, gesture.startY)).Magnitude >= 18) then
            gesture.event._discard = true
            state.touchInputIds[input] = nil
            return
        end
        if isOwnPoint(x, y) then return end
        local size = viewport()
        local touchId = inputType == Enum.UserInputType.Touch and (state.touchInputIds[input] or 1) or nil
        if inputType == Enum.UserInputType.Touch then state.touchInputIds[input] = nil end
        addRecordedEvent("mouse_up", {
            x = x, y = y, nx = math.clamp(x / size.w, 0, 1), ny = math.clamp(y / size.h, 0, 1),
            vw = size.w, vh = size.h,
            button = inputType == Enum.UserInputType.MouseButton2 and 1 or 0,
            touch = inputType == Enum.UserInputType.Touch,
            touchId = touchId,
        })
    end
end))

keep(UIS.InputChanged:Connect(function(input)
    if state.destroyed or state.generatedInput or not state.recording then return end
    if input.UserInputType == Enum.UserInputType.Touch then
        local gesture = state.touchGestures[input]
        if gesture then
            local x, y = eventPosition(input)
            if (Vector2.new(x, y) - Vector2.new(gesture.startX, gesture.startY)).Magnitude >= 18 then
                gesture.moved = true
            end
        end
    elseif input.UserInputType == Enum.UserInputType.MouseWheel then
        local x, y = eventPosition(input)
        if isOwnPoint(x, y) then return end
        local size = viewport()
        addRecordedEvent("mouse_wheel", {
            x = x, y = y, nx = math.clamp(x / size.w, 0, 1), ny = math.clamp(y / size.h, 0, 1),
            vw = size.w, vh = size.h,
            delta = input.Position.Z,
        })
    end
end))

local function transition(nextState, reason)
    if state.controllerState == nextState and not reason then return end
    state.controllerState = nextState
    state.controllerSince = os.clock()
    if state.labels.controller then state.labels.controller.Text = nextState end
    if reason then log(nextState .. ": " .. reason) end
end

local function releaseAll()
    state.generatedInput = true
    for keyName in pairs(state.pressedKeys) do
        local keyCode = Enum.KeyCode[keyName]
        if keyCode then pcall(function() VIM:SendKeyEvent(false, keyCode, false, game) end) end
    end
    local size = viewport()
    for button in pairs(state.pressedButtons) do
        pcall(function() VIM:SendMouseButtonEvent(size.w / 2, size.h / 2, button, false, game, 0) end)
    end
    for touchId, point in pairs(state.pressedTouches) do
        pcall(function() VIM:SendTouchEvent(touchId, 2, point.x, point.y) end)
    end
    state.pressedKeys = {}
    state.pressedButtons = {}
    state.pressedTouches = {}
    state.generatedInput = false
end

local function stopPlayback(reason, emergency)
    state.playToken += 1
    state.playing = false
    state.paused = false
    releaseAll()
    if emergency then
        state.config.settings.auto = false
        state.matchSpawnPosition = nil
        transition("IDLE", reason or "Emergency stop")
        saveDisk()
    end
    if reason then log(reason, emergency == true) end
    refreshAll()
end

local function sendEvent(event, recordedViewport)
    local size = viewport()
    state.generatedInput = true
    local ok, err = pcall(function()
        if event.kind == "key_down" or event.kind == "key_up" then
            local keyCode = Enum.KeyCode[tostring(event.key)]
            if keyCode then
                local down = event.kind == "key_down"
                VIM:SendKeyEvent(down, keyCode, false, game)
                if down then state.pressedKeys[event.key] = true else state.pressedKeys[event.key] = nil end
            end
        elseif event.kind == "mouse_down" or event.kind == "mouse_up" then
            local x, y = Core.eventPoint(event, size, recordedViewport)
            local button = tonumber(event.button) or 0
            local down = event.kind == "mouse_down"
            local sentTouch = false
            if event.touch then
                local touchId = tonumber(event.touchId) or 1
                sentTouch = pcall(function() VIM:SendTouchEvent(touchId, down and 0 or 2, x, y) end)
                if sentTouch then
                    if down then state.pressedTouches[touchId] = {x = x, y = y} else state.pressedTouches[touchId] = nil end
                end
            end
            if not sentTouch then
                VIM:SendMouseButtonEvent(x, y, button, down, game, 0)
                if down then state.pressedButtons[button] = true else state.pressedButtons[button] = nil end
            end
        elseif event.kind == "mouse_wheel" then
            local x, y = Core.eventPoint(event, size, recordedViewport)
            VIM:SendMouseWheelEvent(x, y, (tonumber(event.delta) or 0) > 0, game)
        end
    end)
    state.generatedInput = false
    if not ok then log("Ошибка события: " .. tostring(err), true) end
end

local function macroMatches(macro, currentFingerprint)
    if not macro or tonumber(macro.placeId) ~= game.PlaceId then return false end
    local key = Core.fingerprintKey(currentFingerprint)
    if tostring(macro.fingerprintKey) == key then return true end
    return state.config.manualMatches[key] == macro.id
end

local function playMacro(macro, force, fromAuto, expectedFingerprint)
    if state.recording then log("Сначала останови запись") return false end
    if state.playing then stopPlayback("Предыдущий запуск остановлен") end
    if not macro or type(macro.events) ~= "table" or #macro.events == 0 then
        log("У выбранного макроса нет событий", true)
        return false
    end
    if not workspace.CurrentCamera or not rootPart() then
        log("Камера или персонаж ещё не готовы", true)
        return false
    end
    local currentFingerprint = expectedFingerprint or fingerprint()
    if not force and not macroMatches(macro, currentFingerprint) then
        log("Карта/спавн не совпадают. Автозапуск запрещён", true)
        return false
    end

    state.playToken += 1
    local token = state.playToken
    state.playing = true
    state.paused = false
    state.pauseAccum = 0
    state.selectedId = macro.id
    macro.lastUsed = os.time()
    saveDisk()
    if fromAuto then transition("PLAYING", macro.name) end
    restoreCamera(macro.camera or (macro.fingerprint and macro.fingerprint.camera))
    local lockedCamera = cameraSnapshot()
    log((force and "Force Play: " or "Запуск: ") .. macro.name .. " · " .. #macro.events .. " событий")
    refreshAll()

    task.spawn(function()
        local speed = math.clamp(tonumber(state.config.settings.playbackSpeed) or 1, 0.25, 3)
        local tolerance = math.max(0.05, tonumber(state.config.settings.lateTolerance) or 0.35)
        local started = os.clock()
        local lastSent = 0

        for _, event in ipairs(macro.events) do
            if token ~= state.playToken or state.destroyed then break end
            while state.paused and token == state.playToken do task.wait(0.05) end
            while token == state.playToken do
                local elapsed = (os.clock() - started - state.pauseAccum) * speed
                local remaining = (tonumber(event.t) or 0) - elapsed
                if remaining <= 0 then break end
                task.wait(math.min(0.03, remaining / speed))
            end
            if token ~= state.playToken then break end

            local elapsed = (os.clock() - started - state.pauseAccum) * speed
            local late = elapsed - (tonumber(event.t) or 0)
            if late > tolerance and event.kind == "mouse_wheel" then
                -- Wheel bursts are disposable; clicks and releases are never dropped.
            else
                if event.kind == "mouse_down" and type(event.camera) == "table" then
                    restoreCamera(event.camera)
                    task.wait(0.03)
                end
                if late > tolerance then
                    local spacing = 0.025 - (os.clock() - lastSent)
                    if spacing > 0 then task.wait(spacing) end
                end
                sendEvent(event, macro.viewport)
                lastSent = os.clock()
            end
            if state.config.settings.lockCamera and lockedCamera then restoreCamera(lockedCamera) end
        end

        if token == state.playToken then
            state.playing = false
            state.paused = false
            releaseAll()
            state.playbackFinishedAt = os.clock()
            log("Воспроизведение завершено")
            if fromAuto and state.config.settings.auto then transition("WAIT_END", "жду конец матча") else transition("IDLE") end
            refreshAll()
        end
    end)
    return true
end

local function togglePause()
    if not state.playing then log("Сейчас ничего не воспроизводится") return end
    if not state.paused then
        state.paused = true
        state.pauseStarted = os.clock()
        log("Пауза")
    else
        state.pauseAccum += os.clock() - state.pauseStarted
        state.paused = false
        log("Продолжено")
    end
    refreshAll()
end

local function startRecording()
    if state.playing then stopPlayback("Воспроизведение остановлено перед записью") end
    if state.recording then return end
    state.config.settings.auto = false
    transition("IDLE")
    state.recordedEvents = {}
    state.recordingViewport = viewport()
    local currentRoot = rootPart()
    state.recordingFingerprint = fingerprint(currentRoot and currentRoot.Position or nil)
    state.recordingCamera = cameraSnapshot()
    state.recordingStarted = os.clock()
    state.currentSlot = nil
    state.pendingPlacementSlot = nil
    state.nextUnitId = 0
    state.touchInputIds = {}
    state.touchGestures = {}
    state.nextTouchId = 0
    state.recording = true
    log("Запись начата · " .. state.recordingFingerprint.mapKey .. " · " .. state.recordingFingerprint.spawnKey)
    refreshAll()
end

local function stopAndSave(name)
    if not state.recording then log("Запись не запущена") return nil end
    state.recording = false
    local events = Core.normalizeEvents(state.recordedEvents, state.recordingViewport)
    if #events == 0 then log("Пустая запись не сохранена", true) refreshAll() return nil end
    local macro = Core.normalizeMacro({
        version = VERSION,
        id = HttpService:GenerateGUID(false),
        name = name ~= "" and name or ("Macro " .. (#state.config.macros + 1)),
        placeId = game.PlaceId,
        fingerprint = state.recordingFingerprint,
        settings = {
            loop = state.config.settings.autoLoop,
            x2 = state.config.settings.x2,
            autoSkip = state.config.settings.autoSkip,
            autoPlayAgain = state.config.settings.autoPlayAgain,
        },
        viewport = state.recordingViewport,
        camera = state.recordingCamera,
        slots = copyTable(state.config.slotLabels),
        events = events,
        savedAt = os.time(),
    })
    state.config.macros[#state.config.macros + 1] = macro
    state.selectedId = macro.id
    saveDisk()
    log("Сохранено: " .. macro.name .. " · " .. #events .. " событий")
    refreshAll()
    return macro
end

local function buttonText(button)
    local parts = {button.Name}
    if button:IsA("TextButton") then parts[#parts + 1] = button.Text end
    for _, child in ipairs(button:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then parts[#parts + 1] = child.Text end
    end
    return table.concat(parts, " ")
end

local function findBindingCandidate(kind)
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil, 0 end
    local best, bestScore = nil, 0
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("GuiButton") and instanceVisible(object) and not (state.gui and object:IsDescendantOf(state.gui)) then
            local score = Core.bindingScore(kind, buttonText(object), object.Name)
            if score > 0 then
                if object.Active then score += 8 end
                if object.AbsoluteSize.X >= 24 and object.AbsoluteSize.Y >= 18 then score += 5 end
                local parentName = Core.cleanText(object.Parent and object.Parent.Name or "")
                if parentName:find("game", 1, true) or parentName:find("match", 1, true) or parentName:find("wave", 1, true) then
                    score += 4
                end
                if score > bestScore then best, bestScore = object, score end
            end
        end
    end
    return best, bestScore
end

local function bindingPoint(kind, forDetection)
    local binding = state.config.bindings[kind] or {mode = "auto"}
    if binding.mode == "manual" then
        local object = resolveGuiPath(binding.path)
        if object and instanceVisible(object) then
            local position, size = object.AbsolutePosition, object.AbsoluteSize
            return position.X + size.X / 2, position.Y + size.Y / 2, object
        end
        if forDetection then return nil end
        local size = viewport()
        if tonumber(binding.nx) and tonumber(binding.ny) then
            return binding.nx * size.w, binding.ny * size.h, nil
        end
        return nil
    end
    local object, score = findBindingCandidate(kind)
    if object and score >= 70 then
        local position, size = object.AbsolutePosition, object.AbsoluteSize
        return position.X + size.X / 2, position.Y + size.Y / 2, object
    end
    return nil
end

local function clickBinding(kind)
    local x, y = bindingPoint(kind, false)
    if not x then log(kind .. ": кнопка не найдена") return false end
    state.generatedInput = true
    local ok = pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.06)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    state.generatedInput = false
    if ok then log(kind .. ": нажато") else log(kind .. ": ошибка нажатия", true) end
    return ok
end

local endWords = {
    "victory", "defeat", "completed", "you win", "you lost", "победа", "поражение",
    "завершено", "матч окончен", "играть снова", "сыграть снова",
}

local function endDetected()
    local x = bindingPoint("playAgain", true)
    if x then return true, "Play Again видна" end
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, object in ipairs(playerGui:GetDescendants()) do
            if (object:IsA("TextLabel") or object:IsA("TextButton")) and instanceVisible(object) then
                local text = Core.cleanText(object.Text)
                for _, word in ipairs(endWords) do
                    local target = Core.cleanText(word)
                    if text:find(target, 1, true) then
                        local score = text == target and 80 or 40
                        if object.AbsoluteSize.X >= 150 then score += 8 end
                        local parent = object.Parent
                        for _ = 1, 4 do
                            if not parent then break end
                            local name = Core.cleanText(parent.Name)
                            if name:find("result", 1, true) or name:find("victory", 1, true)
                                or name:find("defeat", 1, true) or name:find("gameover", 1, true)
                                or name:find("finish", 1, true) or name:find("end", 1, true) then
                                score += 35
                                break
                            end
                            parent = parent.Parent
                        end
                        if score >= 70 then return true, object.Text end
                    end
                end
            end
        end
    end
    local timeout = tonumber(state.config.settings.endTimeout) or 600
    if state.playbackFinishedAt > 0 and os.clock() - state.playbackFinishedAt >= timeout then
        return true, "таймаут"
    end
    return false
end

local function prepareAutoRun()
    if not state.config.settings.auto or state.destroyed then return end
    transition("PREPARE")
    local currentFingerprint = fingerprint(state.matchSpawnPosition)
    state.lastFingerprint = currentFingerprint
    log("Карта: " .. currentFingerprint.mapKey .. " · спавн " .. currentFingerprint.spawnKey)
    local macro, choices = Core.chooseMacro(state.config.macros, currentFingerprint, state.config.manualMatches)
    if not macro then
        state.config.settings.auto = false
        transition("ERROR", "Нет макроса для этой карты/спавна")
        saveDisk()
        refreshAll()
        return
    end
    state.selectedId = macro.id
    if #choices > 1 then log("Совпадений: " .. #choices .. ", выбран " .. macro.name) else log("Выбран: " .. macro.name) end
    restoreCamera(macro.camera or (macro.fingerprint and macro.fingerprint.camera))
    task.wait(0.35)
    if not state.config.settings.auto then return end
    if state.config.settings.x2 and macro.settings.x2 ~= false then clickBinding("x2") end
    if state.config.settings.autoSkip and macro.settings.autoSkip ~= false then clickBinding("autoSkip") end
    task.wait(math.max(0, tonumber(state.config.settings.initialDelay) or 1.2))
    if state.config.settings.auto then
        if not playMacro(macro, false, true, currentFingerprint) then
            state.config.settings.auto = false
            transition("ERROR", "Запуск макроса не удался")
            saveDisk()
        end
    end
    refreshAll()
end

local controllerAccumulator = 0
keep(RunService.Heartbeat:Connect(function(delta)
    if state.destroyed then return end
    controllerAccumulator += delta
    if controllerAccumulator < 0.5 then return end
    controllerAccumulator = 0
    if not state.config or not state.config.settings.auto or state.recording then return end
    if os.clock() < state.controllerNotBefore then return end

    if state.controllerState == "IDLE" then
        transition("WAIT_MATCH")
        state.stableKey = nil
        state.stableSince = os.clock()
        state.matchSpawnPosition = nil
    elseif state.controllerState == "WAIT_MATCH" then
        if not workspace.CurrentCamera or not rootPart() then
            state.stableKey = nil
            return
        end
        if not state.matchSpawnPosition then state.matchSpawnPosition = rootPart().Position end
        local current = fingerprint(state.matchSpawnPosition)
        if current.key ~= state.stableKey then
            state.stableKey = current.key
            state.stableSince = os.clock()
        elseif os.clock() - state.stableSince >= 2 then
            task.spawn(prepareAutoRun)
        end
    elseif state.controllerState == "WAIT_END" then
        local ended, reason = endDetected()
        if ended then
            transition("REPLAY", reason)
            task.spawn(function()
                task.wait(0.8)
                if state.config.settings.autoPlayAgain then clickBinding("playAgain") end
                if not state.config.settings.autoLoop then
                    state.config.settings.auto = false
                    transition("IDLE", "цикл выключен")
                else
                    state.controllerNotBefore = os.clock() + 5
                    state.stableKey = nil
                    state.matchSpawnPosition = nil
                    transition("WAIT_MATCH", "жду новую карту")
                end
                saveDisk()
                refreshAll()
            end)
        end
    end
end))

loadConfig()
if #state.config.macros > 0 then state.selectedId = state.config.macros[1].id end

local palette = {
    bg = Color3.fromRGB(15, 20, 30),
    panel = Color3.fromRGB(23, 30, 43),
    panel2 = Color3.fromRGB(30, 39, 55),
    accent = Color3.fromRGB(54, 205, 177),
    accent2 = Color3.fromRGB(65, 145, 255),
    danger = Color3.fromRGB(235, 83, 95),
    text = Color3.fromRGB(238, 244, 251),
    muted = Color3.fromRGB(143, 158, 180),
    line = Color3.fromRGB(50, 63, 83),
}

local function round(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = object
    return corner
end

local function stroke(object, color, transparency)
    local item = Instance.new("UIStroke")
    item.Color = color or palette.line
    item.Transparency = transparency or 0
    item.Thickness = 1
    item.Parent = object
    return item
end

local function label(parent, text, position, size, fontSize, color, alignment)
    local object = Instance.new("TextLabel")
    object.BackgroundTransparency = 1
    object.Position = position
    object.Size = size
    object.Font = Enum.Font.Gotham
    object.Text = text or ""
    object.TextSize = fontSize or 13
    object.TextColor3 = color or palette.text
    object.TextXAlignment = alignment or Enum.TextXAlignment.Left
    object.TextYAlignment = Enum.TextYAlignment.Center
    object.TextTruncate = Enum.TextTruncate.AtEnd
    object.Parent = parent
    return object
end

local function button(parent, text, position, size, callback, color)
    local object = Instance.new("TextButton")
    object.AutoButtonColor = false
    object.BackgroundColor3 = color or palette.panel2
    object.Position = position
    object.Size = size
    object.Font = Enum.Font.GothamSemibold
    object.Text = text
    object.TextSize = 12
    object.TextColor3 = palette.text
    object.Parent = parent
    round(object, 7)
    local outline = stroke(object, palette.line, 0.18)
    keep(object.MouseEnter:Connect(function()
        TweenService:Create(object, TweenInfo.new(0.12), {BackgroundColor3 = color or Color3.fromRGB(38, 49, 68)}):Play()
    end))
    keep(object.MouseLeave:Connect(function()
        TweenService:Create(object, TweenInfo.new(0.12), {BackgroundColor3 = color or palette.panel2}):Play()
    end))
    keep(object.Activated:Connect(function()
        outline.Color = palette.accent
        task.delay(0.15, function() if outline.Parent then outline.Color = palette.line end end)
        callback()
    end))
    return object
end

local function textBox(parent, text, placeholder, position, size)
    local object = Instance.new("TextBox")
    object.BackgroundColor3 = palette.panel2
    object.Position = position
    object.Size = size
    object.ClearTextOnFocus = false
    object.Font = Enum.Font.Gotham
    object.Text = text or ""
    object.PlaceholderText = placeholder or ""
    object.PlaceholderColor3 = palette.muted
    object.TextColor3 = palette.text
    object.TextSize = 12
    object.TextXAlignment = Enum.TextXAlignment.Left
    object.Parent = parent
    round(object, 7)
    stroke(object)
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = object
    return object
end

local function makeToggle(parent, title, position, getter, setter)
    local object = button(parent, "", position, UDim2.new(0.5, -8, 0, 38), function()
        setter(not getter())
        saveDisk()
        refreshAll()
    end)
    local titleLabel = label(object, title, UDim2.fromOffset(10, 0), UDim2.new(1, -55, 1, 0), 12)
    local valueLabel = label(object, "", UDim2.new(1, -47, 0, 0), UDim2.fromOffset(38, 38), 11, palette.accent, Enum.TextXAlignment.Center)
    object.Text = ""
    local function update()
        local enabled = getter()
        valueLabel.Text = enabled and "ON" or "OFF"
        valueLabel.TextColor3 = enabled and palette.accent or palette.muted
        object.BackgroundColor3 = enabled and Color3.fromRGB(26, 53, 57) or palette.panel2
        titleLabel.TextColor3 = enabled and palette.text or palette.muted
    end
    state.rows[#state.rows + 1] = update
    update()
    return object
end

local gui = Instance.new("ScreenGui")
gui.Name = "TDMacroLabV1"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
state.gui = gui

local parented = false
if type(gethui) == "function" then
    local ok, hiddenUi = pcall(gethui)
    if ok and hiddenUi then parented = pcall(function() gui.Parent = hiddenUi end) end
end
if not parented then
    parented = pcall(function() gui.Parent = CoreGui end)
end
if not parented then gui.Parent = player:WaitForChild("PlayerGui") end

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.42
shadow.Position = UDim2.new(0.5, -286, 0.5, -195)
shadow.Size = UDim2.fromOffset(580, 398)
shadow.ZIndex = 0
shadow.Parent = gui
round(shadow, 16)

local window = Instance.new("Frame")
window.Name = "Window"
window.BackgroundColor3 = palette.bg
window.Position = UDim2.new(0.5, -290, 0.5, -199)
window.Size = UDim2.fromOffset(580, 398)
window.ClipsDescendants = true
window.Parent = gui
round(window, 15)
stroke(window, palette.line)
state.window = window

local header = Instance.new("Frame")
header.BackgroundColor3 = palette.panel
header.Size = UDim2.new(1, 0, 0, 42)
header.Parent = window

local title = label(header, "TD MACRO LAB", UDim2.fromOffset(14, 0), UDim2.new(1, -130, 1, 0), 14)
title.Font = Enum.Font.GothamBold
local versionLabel = label(header, "V1 · schema 2", UDim2.new(1, -178, 0, 0), UDim2.fromOffset(130, 42), 10, palette.muted, Enum.TextXAlignment.Right)
local hideButton = button(header, "—", UDim2.new(1, -38, 0, 7), UDim2.fromOffset(30, 28), function()
    window.Visible = false
    shadow.Visible = false
    state.showButton.Visible = true
end)
hideButton.TextSize = 18

local nav = Instance.new("Frame")
nav.BackgroundColor3 = palette.bg
nav.Position = UDim2.fromOffset(8, 48)
nav.Size = UDim2.new(1, -16, 0, 32)
nav.Parent = window

local content = Instance.new("Frame")
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(10, 86)
content.Size = UDim2.new(1, -20, 1, -96)
content.ClipsDescendants = true
content.Parent = window

local function createPage(name)
    local page = Instance.new("Frame")
    page.Name = name
    page.BackgroundTransparency = 1
    page.Size = UDim2.fromScale(1, 1)
    page.Visible = false
    page.Parent = content
    state.pages[name] = page
    return page
end

local activePage = "RECORD"
local navButtons = {}
local function showPage(name)
    activePage = name
    for pageName, page in pairs(state.pages) do page.Visible = pageName == name end
    for pageName, item in pairs(navButtons) do
        item.BackgroundColor3 = pageName == name and Color3.fromRGB(31, 70, 72) or palette.panel
        item.TextColor3 = pageName == name and palette.accent or palette.muted
    end
    if name == "MACROS" then refreshMacros() end
    if name == "BINDINGS" then refreshBindings() end
end

for index, name in ipairs({"RECORD", "MACROS", "AUTO", "BINDINGS", "LOG"}) do
    local item = button(nav, name, UDim2.new((index - 1) / 5, 2, 0, 0), UDim2.new(0.2, -4, 1, 0), function() showPage(name) end, palette.panel)
    item.TextSize = index == 4 and 10 or 11
    navButtons[name] = item
end

local recordPage = createPage("RECORD")
local macrosPage = createPage("MACROS")
local autoPage = createPage("AUTO")
local bindingsPage = createPage("BINDINGS")
local logPage = createPage("LOG")

local statusCard = Instance.new("Frame")
statusCard.BackgroundColor3 = palette.panel
statusCard.Size = UDim2.new(1, 0, 0, 63)
statusCard.Parent = recordPage
round(statusCard, 10)
stroke(statusCard)

label(statusCard, "СОСТОЯНИЕ", UDim2.fromOffset(12, 5), UDim2.fromOffset(95, 20), 10, palette.muted)
state.labels.controller = label(statusCard, state.controllerState, UDim2.fromOffset(12, 22), UDim2.fromOffset(125, 30), 16, palette.accent)
state.labels.controller.Font = Enum.Font.GothamBold
state.labels.fingerprint = label(statusCard, "", UDim2.fromOffset(145, 6), UDim2.new(1, -157, 0, 24), 11, palette.text, Enum.TextXAlignment.Right)
state.labels.storage = label(statusCard, "", UDim2.fromOffset(145, 30), UDim2.new(1, -157, 0, 22), 10, palette.muted, Enum.TextXAlignment.Right)

state.labels.nameBox = textBox(recordPage, "Macro " .. (#state.config.macros + 1), "Название макроса", UDim2.fromOffset(0, 73), UDim2.new(1, -145, 0, 36))
state.labels.recordCount = label(recordPage, "0 событий", UDim2.new(1, -137, 0, 73), UDim2.fromOffset(137, 36), 11, palette.muted, Enum.TextXAlignment.Right)

state.labels.recordButton = button(recordPage, "●  RECORD", UDim2.fromOffset(0, 119), UDim2.new(0.5, -5, 0, 40), startRecording, Color3.fromRGB(35, 119, 108))
state.labels.saveButton = button(recordPage, "STOP + SAVE", UDim2.new(0.5, 5, 0, 119), UDim2.new(0.5, -5, 0, 40), function()
    stopAndSave(state.labels.nameBox.Text)
end, Color3.fromRGB(50, 81, 125))

label(recordPage, "UNIT SLOTS", UDim2.fromOffset(2, 169), UDim2.fromOffset(100, 18), 10, palette.muted)
for index = 1, 5 do
    local box = textBox(recordPage, tostring(state.config.slotLabels[index] or index), "Slot " .. index,
        UDim2.new((index - 1) / 5, 2, 0, 191), UDim2.new(0.2, -5, 0, 35))
    box.TextXAlignment = Enum.TextXAlignment.Center
    keep(box.FocusLost:Connect(function()
        state.config.slotLabels[index] = box.Text ~= "" and box.Text or tostring(index)
        saveDisk()
    end))
end
state.labels.recordHint = label(recordPage,
    "Пиши матч целиком: выбор 1–5, постановка, апгрейд и продажа записываются как точный ввод.",
    UDim2.fromOffset(2, 235), UDim2.new(1, -4, 0, 42), 11, palette.muted)
state.labels.recordHint.TextWrapped = true
state.labels.recordHint.TextYAlignment = Enum.TextYAlignment.Top

local macroList = Instance.new("ScrollingFrame")
macroList.Name = "MacroList"
macroList.BackgroundColor3 = palette.panel
macroList.BorderSizePixel = 0
macroList.Size = UDim2.new(1, 0, 1, -93)
macroList.ScrollBarThickness = 3
macroList.ScrollBarImageColor3 = palette.accent
macroList.AutomaticCanvasSize = Enum.AutomaticSize.Y
macroList.CanvasSize = UDim2.new()
macroList.Parent = macrosPage
round(macroList, 10)
stroke(macroList)
local macroPadding = Instance.new("UIPadding")
macroPadding.PaddingTop = UDim.new(0, 6)
macroPadding.PaddingBottom = UDim.new(0, 6)
macroPadding.PaddingLeft = UDim.new(0, 6)
macroPadding.PaddingRight = UDim.new(0, 6)
macroPadding.Parent = macroList
local macroLayout = Instance.new("UIListLayout")
macroLayout.Padding = UDim.new(0, 5)
macroLayout.SortOrder = Enum.SortOrder.LayoutOrder
macroLayout.Parent = macroList
state.labels.macroList = macroList

state.labels.renameBox = textBox(macrosPage, "", "Новое имя", UDim2.new(0, 0, 1, -84), UDim2.new(0.42, -4, 0, 35))
button(macrosPage, "RENAME", UDim2.new(0.42, 4, 1, -84), UDim2.new(0.19, -4, 0, 35), function()
    local macro = selectedMacro()
    if macro and state.labels.renameBox.Text ~= "" then
        macro.name = state.labels.renameBox.Text
        saveDisk()
        refreshMacros()
    end
end)
button(macrosPage, "DEFAULT", UDim2.new(0.61, 4, 1, -84), UDim2.new(0.2, -4, 0, 35), function()
    local macro = selectedMacro()
    if not macro then return end
    for _, other in ipairs(state.config.macros) do
        if other.fingerprintKey == macro.fingerprintKey then other.isDefault = false end
    end
    macro.isDefault = true
    saveDisk()
    refreshMacros()
end)
button(macrosPage, "DELETE", UDim2.new(0.81, 4, 1, -84), UDim2.new(0.19, -4, 0, 35), function()
    local macro = selectedMacro()
    if not macro then return end
    for index, other in ipairs(state.config.macros) do
        if other.id == macro.id then table.remove(state.config.macros, index) break end
    end
    state.selectedId = state.config.macros[1] and state.config.macros[1].id or nil
    saveDisk()
    refreshMacros()
end, Color3.fromRGB(91, 39, 48))

button(macrosPage, "PLAY SELECTED", UDim2.new(0, 0, 1, -41), UDim2.new(0.26, -4, 0, 35), function()
    playMacro(selectedMacro(), false, false)
end, Color3.fromRGB(35, 119, 108))
button(macrosPage, "FORCE PLAY", UDim2.new(0.26, 4, 1, -41), UDim2.new(0.22, -4, 0, 35), function()
    playMacro(selectedMacro(), true, false)
end, Color3.fromRGB(101, 73, 39))
button(macrosPage, "BIND CURRENT", UDim2.new(0.48, 4, 1, -41), UDim2.new(0.27, -4, 0, 35), function()
    local macro = selectedMacro()
    if not macro then log("Выбери макрос") return end
    local current = fingerprint()
    state.config.manualMatches[current.key] = macro.id
    saveDisk()
    log("Текущая карта/спавн привязаны к " .. macro.name)
end)
button(macrosPage, "STOP", UDim2.new(0.75, 4, 1, -41), UDim2.new(0.25, -4, 0, 35), function()
    stopPlayback("Остановлено пользователем", true)
end, palette.danger)

label(autoPage, "MATCH CONTROLLER", UDim2.fromOffset(2, 0), UDim2.new(1, -4, 0, 22), 10, palette.muted)
makeToggle(autoPage, "AUTO", UDim2.fromOffset(0, 27), function() return state.config.settings.auto end, function(value)
    state.config.settings.auto = value
    state.controllerNotBefore = 0
    state.stableKey = nil
    state.matchSpawnPosition = nil
    transition(value and "WAIT_MATCH" or "IDLE", value and "автоматизация включена" or "автоматизация выключена")
end)
makeToggle(autoPage, "LOOP", UDim2.new(0.5, 8, 0, 27), function() return state.config.settings.autoLoop end, function(value) state.config.settings.autoLoop = value end)
makeToggle(autoPage, "x2 SPEED", UDim2.fromOffset(0, 73), function() return state.config.settings.x2 end, function(value) state.config.settings.x2 = value end)
makeToggle(autoPage, "AUTO SKIP", UDim2.new(0.5, 8, 0, 73), function() return state.config.settings.autoSkip end, function(value) state.config.settings.autoSkip = value end)
makeToggle(autoPage, "PLAY AGAIN", UDim2.fromOffset(0, 119), function() return state.config.settings.autoPlayAgain end, function(value) state.config.settings.autoPlayAgain = value end)
makeToggle(autoPage, "LOCK CAMERA", UDim2.new(0.5, 8, 0, 119), function() return state.config.settings.lockCamera end, function(value) state.config.settings.lockCamera = value end)

state.labels.speed = label(autoPage, "", UDim2.fromOffset(2, 169), UDim2.new(1, -4, 0, 28), 12, palette.text, Enum.TextXAlignment.Center)
button(autoPage, "−", UDim2.new(0.5, -91, 0, 169), UDim2.fromOffset(36, 28), function()
    state.config.settings.playbackSpeed = math.max(0.25, (tonumber(state.config.settings.playbackSpeed) or 1) - 0.25)
    saveDisk()
    refreshAll()
end)
button(autoPage, "+", UDim2.new(0.5, 55, 0, 169), UDim2.fromOffset(36, 28), function()
    state.config.settings.playbackSpeed = math.min(3, (tonumber(state.config.settings.playbackSpeed) or 1) + 0.25)
    saveDisk()
    refreshAll()
end)
state.labels.pauseButton = button(autoPage, "PAUSE / RESUME", UDim2.new(0, 0, 1, -43), UDim2.new(0.5, -5, 0, 42), togglePause)
button(autoPage, "EMERGENCY STOP", UDim2.new(0.5, 5, 1, -43), UDim2.new(0.5, -5, 0, 42), function()
    stopPlayback("EMERGENCY STOP", true)
end, palette.danger)

label(bindingsPage, "AUTO ищет кнопку по тексту. BIND сохраняет следующий клик в игре.", UDim2.fromOffset(2, 0), UDim2.new(1, -4, 0, 34), 11, palette.muted)
for index, item in ipairs({
    {key = "x2", title = "x2 SPEED"},
    {key = "autoSkip", title = "AUTO SKIP"},
    {key = "playAgain", title = "PLAY AGAIN / END"},
}) do
    local row = Instance.new("Frame")
    row.BackgroundColor3 = palette.panel
    row.Position = UDim2.fromOffset(0, 40 + (index - 1) * 57)
    row.Size = UDim2.new(1, 0, 0, 49)
    row.Parent = bindingsPage
    round(row, 8)
    stroke(row)
    label(row, item.title, UDim2.fromOffset(11, 0), UDim2.new(0.42, -11, 1, 0), 12)
    local status = label(row, "", UDim2.new(0.42, 0, 0, 0), UDim2.new(0.25, 0, 1, 0), 10, palette.muted, Enum.TextXAlignment.Center)
    state.labels["binding_" .. item.key] = status
    button(row, "AUTO", UDim2.new(0.68, 0, 0, 7), UDim2.new(0.14, -5, 0, 35), function()
        state.config.bindings[item.key] = {mode = "auto"}
        saveDisk()
        refreshBindings()
    end)
    button(row, "BIND", UDim2.new(0.82, 0, 0, 7), UDim2.new(0.18, -7, 0, 35), function()
        state.bindingCapture = item.key
        log("BIND " .. item.key .. ": кликни нужную кнопку в игре")
        refreshBindings()
    end, Color3.fromRGB(50, 81, 125))
end
button(bindingsPage, "TEST x2", UDim2.new(0, 0, 1, -37), UDim2.new(0.32, -4, 0, 36), function() clickBinding("x2") end)
button(bindingsPage, "TEST SKIP", UDim2.new(0.32, 4, 1, -37), UDim2.new(0.34, -4, 0, 36), function() clickBinding("autoSkip") end)
button(bindingsPage, "TEST REPLAY", UDim2.new(0.66, 4, 1, -37), UDim2.new(0.34, -4, 0, 36), function() clickBinding("playAgain") end)

local logScroll = Instance.new("ScrollingFrame")
logScroll.BackgroundColor3 = palette.panel
logScroll.BorderSizePixel = 0
logScroll.Size = UDim2.new(1, 0, 1, 0)
logScroll.ScrollBarThickness = 3
logScroll.ScrollBarImageColor3 = palette.accent
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScroll.CanvasSize = UDim2.new()
logScroll.Parent = logPage
round(logScroll, 10)
stroke(logScroll)
state.labels.logScroll = logScroll
local logText = label(logScroll, "", UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 0), 11, palette.muted)
logText.AutomaticSize = Enum.AutomaticSize.Y
logText.TextWrapped = true
logText.TextYAlignment = Enum.TextYAlignment.Top
state.labels.logText = logText

local showButton = button(gui, "TD", UDim2.new(0, 12, 0.5, -25), UDim2.fromOffset(50, 50), function()
    window.Visible = true
    shadow.Visible = true
    state.showButton.Visible = false
end, Color3.fromRGB(30, 92, 92))
showButton.TextSize = 14
showButton.Visible = false
state.showButton = showButton

local dragging = false
local dragStart, startPosition
keep(header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = window.Position
    end
end))
keep(UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        window.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        shadow.Position = UDim2.new(window.Position.X.Scale, window.Position.X.Offset + 4, window.Position.Y.Scale, window.Position.Y.Offset + 4)
    end
end))
keep(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end))

local function resizeWindow()
    local size = viewport()
    local width = math.min(580, size.w - 18)
    local height = math.min(398, size.h - 24)
    width = math.max(300, width)
    height = math.max(320, height)
    window.Size = UDim2.fromOffset(width, height)
    window.Position = UDim2.fromOffset(math.max(8, (size.w - width) / 2), math.max(8, (size.h - height) / 2))
    shadow.Size = UDim2.fromOffset(width, height)
    shadow.Position = UDim2.fromOffset(window.Position.X.Offset + 4, window.Position.Y.Offset + 4)
    if state.labels.recordHint then state.labels.recordHint.Visible = height >= 380 end
end
resizeWindow()
if workspace.CurrentCamera then keep(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeWindow)) end

refreshMacros = function()
    local list = state.labels.macroList
    if not list then return end
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("GuiButton") then child:Destroy() end
    end
    if #state.config.macros == 0 then
        local empty = button(list, "Нет макросов · открой RECORD", UDim2.new(), UDim2.new(1, 0, 0, 48), function() showPage("RECORD") end)
        empty.LayoutOrder = 1
        return
    end
    for index, macro in ipairs(state.config.macros) do
        local duration = #macro.events > 0 and (tonumber(macro.events[#macro.events].t) or 0) or 0
        local marker = macro.isDefault and "★ " or ""
        local text = string.format("%s%s\n%s · %s · %.1fs · %d ev", marker, macro.name,
            tostring(macro.fingerprint.mapKey), tostring(macro.fingerprint.spawnKey), duration, #macro.events)
        local row = button(list, text, UDim2.new(), UDim2.new(1, 0, 0, 51), function()
            state.selectedId = macro.id
            state.labels.renameBox.Text = macro.name
            refreshMacros()
        end, macro.id == state.selectedId and Color3.fromRGB(31, 70, 72) or palette.panel2)
        row.LayoutOrder = index
        row.TextWrapped = false
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.TextYAlignment = Enum.TextYAlignment.Center
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 10)
        padding.Parent = row
    end
end

refreshBindings = function()
    if not state.config then return end
    for _, kind in ipairs({"x2", "autoSkip", "playAgain"}) do
        local target = state.labels["binding_" .. kind]
        if target then
            local binding = state.config.bindings[kind] or {mode = "auto"}
            if state.bindingCapture == kind then
                target.Text = "ЖДУ КЛИК"
                target.TextColor3 = Color3.fromRGB(255, 202, 91)
            elseif binding.mode == "manual" then
                target.Text = "MANUAL"
                target.TextColor3 = palette.accent2
            else
                local candidate, score = findBindingCandidate(kind)
                target.Text = candidate and score >= 70 and "AUTO ✓" or "AUTO ?"
                target.TextColor3 = candidate and score >= 70 and palette.accent or palette.muted
            end
        end
    end
end

refreshAll = function()
    if not state.config or state.destroyed then return end
    for _, update in ipairs(state.rows) do pcall(update) end
    if state.labels.controller then state.labels.controller.Text = state.controllerState end
    if state.labels.speed then state.labels.speed.Text = string.format("PLAYBACK SPEED  ×%.2f", tonumber(state.config.settings.playbackSpeed) or 1) end
    if state.labels.recordCount then
        state.labels.recordCount.Text = state.recording and (#state.recordedEvents .. " событий") or (state.playing and (state.paused and "PAUSED" or "PLAYING") or "готов")
        state.labels.recordCount.TextColor3 = state.recording and palette.danger or (state.playing and palette.accent or palette.muted)
    end
    if state.labels.recordButton then state.labels.recordButton.Text = state.recording and "●  RECORDING" or "●  RECORD" end
    local current = fingerprint()
    if state.labels.fingerprint then state.labels.fingerprint.Text = current.mapKey .. " · " .. current.spawnKey end
    if state.labels.storage then
        state.labels.storage.Text = state.memoryOnly and "MEMORY ONLY · записи пропадут после перезапуска" or ("TDMacroLab/config.json · " .. #state.config.macros .. " macros")
        state.labels.storage.TextColor3 = state.memoryOnly and Color3.fromRGB(255, 202, 91) or palette.muted
    end
    refreshBindings()
end

function state:Destroy()
    if self.destroyed then return end
    self.destroyed = true
    self.recording = false
    self.playToken += 1
    self.playing = false
    releaseAll()
    for _, connection in ipairs(self.connections) do pcall(function() connection:Disconnect() end) end
    self.connections = {}
    if self.gui then pcall(function() self.gui:Destroy() end) end
    if env.TDMacroPrototype == self then env.TDMacroPrototype = nil end
    if env.TDMacroLab == self then env.TDMacroLab = nil end
end

state.StartRecording = startRecording
state.StopAndSave = stopAndSave
state.PlaySelected = function(force) return playMacro(selectedMacro(), force == true, false) end
state.Stop = function() stopPlayback("Остановлено через API", true) end
state.Pause = togglePause
state.Fingerprint = fingerprint
state.Core = Core

showPage("RECORD")
refreshMacros()
refreshAll()
log("TD Macro Lab V1 загружен" .. (state.memoryOnly and " · MEMORY ONLY" or ""))
