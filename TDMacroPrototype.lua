-- TD Macro Lab
-- Records tower actions and replays the same server remotes without moving the camera.

local VERSION = 2
local SCRIPT_VERSION = "1.4.19"
local REMOTE_BUS_VERSION = 5
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

function Core.mapBindingKey(fingerprint)
    fingerprint = type(fingerprint) == "table" and fingerprint or {}
    return table.concat({
        tostring(fingerprint.placeId or 0),
        tostring(fingerprint.mapKey or "unknown"),
    }, "::")
end

function Core.boundMacroId(currentFingerprint, manualMatches, mapMatches)
    -- Exact map+spawn bindings must win over broad map bindings. Some TD maps
    -- expose the same generic workspace map name, so map-only keys can collide.
    local exactKey = Core.fingerprintKey(currentFingerprint)
    if type(manualMatches) == "table" and manualMatches[exactKey] then
        return manualMatches[exactKey], "exact"
    end
    local mapKey = Core.mapBindingKey(currentFingerprint)
    if type(mapMatches) == "table" and mapMatches[mapKey] then
        return mapMatches[mapKey], "map"
    end
    -- Before v1.3.0 the button called "bind to map" actually saved a full
    -- map+spawn fingerprint. Treat every old entry from this map as a map
    -- binding so existing configs start working without rebinding.
    if type(manualMatches) == "table" then
        local prefix = mapKey .. "::"
        for oldKey, macroId in pairs(manualMatches) do
            if tostring(oldKey):sub(1, #prefix) == prefix then return macroId, "legacy_map" end
        end
    end
    return nil, nil
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

function Core.normalizeCameraTrack(track)
    local output = {}
    for index, source in ipairs(type(track) == "table" and track or {}) do
        if type(source) == "table" and type(source.cframe) == "table" and #source.cframe >= 12 then
            output[#output + 1] = {
                t = math.max(0, tonumber(source.t) or 0),
                cframe = source.cframe,
                fov = tonumber(source.fov),
                _order = index,
            }
        end
    end
    table.sort(output, function(a, b)
        if a.t == b.t then return a._order < b._order end
        return a.t < b.t
    end)
    for _, frame in ipairs(output) do frame._order = nil end
    return output
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
    local normalizedEvents = Core.normalizeEvents(events, recordedViewport)
    local detectedRemote = false
    for _, event in ipairs(normalizedEvents) do
        if event.kind == "remote" then detectedRemote = true break end
    end
    local cameraTrack = Core.normalizeCameraTrack(source.cameraTrack)
    if #cameraTrack == 0 then
        local initialCamera = type(source.camera) == "table" and source.camera or macroFingerprint.camera
        if type(initialCamera) == "table" and type(initialCamera.cframe) == "table" then
            cameraTrack[#cameraTrack + 1] = {t = 0, cframe = initialCamera.cframe, fov = initialCamera.fov}
        end
        for _, event in ipairs(normalizedEvents) do
            if event.kind == "mouse_down" and type(event.camera) == "table" and type(event.camera.cframe) == "table" then
                cameraTrack[#cameraTrack + 1] = {
                    t = event.t,
                    cframe = event.camera.cframe,
                    fov = event.camera.fov,
                }
            end
        end
        cameraTrack = Core.normalizeCameraTrack(cameraTrack)
    end
    return {
        version = VERSION,
        recordMode = source.recordMode or (detectedRemote and "remote" or "input"),
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
        cameraTrack = cameraTrack,
        clock = type(source.clock) == "table" and source.clock or nil,
        slots = type(source.slots) == "table" and source.slots or {"1", "2", "3", "4", "5"},
        events = normalizedEvents,
        savedAt = tonumber(source.savedAt) or os.time(),
        lastUsed = tonumber(source.lastUsed) or 0,
        isDefault = source.isDefault == true,
        legacy = (tonumber(source.version) or 0) < VERSION,
    }
end

function Core.chooseMacro(macros, currentFingerprint, manualMatches, mapMatches)
    local boundId = Core.boundMacroId(currentFingerprint, manualMatches, mapMatches)
    local candidates = {}
    if not boundId then return nil, candidates end
    for _, macro in ipairs(type(macros) == "table" and macros or {}) do
        if macro.id == boundId and tonumber(macro.placeId) == tonumber(currentFingerprint.placeId) then
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

function Core.observeAutoContext(context, key, jobId, wave, resultsVisible)
    context = type(context) == "table" and context or {}
    local newMap = context.key ~= key or context.jobId ~= jobId
    local newRound = not newMap and not resultsVisible and wave ~= nil and wave <= 1
        and ((tonumber(context.wave) or 0) > 1 or context.sawResults == true)
    if newMap or newRound then
        context = {key = key, jobId = jobId, consumed = false, sawResults = false}
    end
    if wave ~= nil then context.wave = wave end
    if resultsVisible then context.sawResults = true end
    return context, newMap or newRound
end

function Core.newestConfig(primary, fallback)
    if not primary then return fallback end
    if not fallback then return primary end
    if (tonumber(fallback.saveRevision) or 0) > (tonumber(primary.saveRevision) or 0) then return fallback end
    return primary
end

local aliases = {
    -- The live Alliance TD HUD shows the *current* speed, so the same control
    -- can be captioned 1x/1.5x before it ever reaches 2x.
    x2 = {"x2", "2x", "1x", "1.5x", "game speed", "speed button", "speed", "скорость"},
    autoSkip = {
        "auto skip", "autoskip", "auto wave", "auto skip wave", "auto skip waves",
        "wave skip", "skip waves", "skip wave", "авто пропуск", "автопропуск",
    },
    playAgain = {
        "play again", "playagain", "replay", "retry", "try again", "restart match", "again", "return match",
        "играть снова", "сыграть снова", "повторить", "заново",
    },
}

function Core.bindingScore(kind, text, name)
    local clean = Core.cleanText(text)
    local cleanName = Core.cleanText(name)
    local compact = clean:gsub("%s+", "")
    local compactName = cleanName:gsub("%s+", "")
    local padded = " " .. clean .. " "
    local paddedName = " " .. cleanName .. " "
    local score = 0
    for _, alias in ipairs(aliases[kind] or {}) do
        local target = Core.cleanText(alias)
        local compactTarget = target:gsub("%s+", "")
        if clean == target then score = math.max(score, 100) end
        if cleanName == target then score = math.max(score, 88) end
        if padded:find(" " .. target .. " ", 1, true) then score = math.max(score, 70) end
        if paddedName:find(" " .. target .. " ", 1, true) then score = math.max(score, 55) end
        -- Roblox GUI names are commonly AutoSkipButton/PlayAgainButton. They do
        -- not contain separators, so word-only matching silently missed them.
        if #compactTarget >= 4 and compact:find(compactTarget, 1, true) then score = math.max(score, 82) end
        if #compactTarget >= 4 and compactName:find(compactTarget, 1, true) then score = math.max(score, 86) end
        if (compactTarget == "x2" or compactTarget == "2x")
            and (compact:find(compactTarget, 1, true) or compactName:find(compactTarget, 1, true)) then
            score = math.max(score, 78)
        end
    end
    return score
end

local defaultConfig = {
    version = VERSION,
    macros = {},
    manualMatches = {},
    mapMatches = {},
    bindings = {
        x2 = {mode = "auto"},
        autoSkip = {mode = "auto"},
        playAgain = {mode = "auto"},
        matchTimer = {mode = "auto"},
    },
    slotLabels = {"1", "2", "3", "4", "5"},
    settings = {
        auto = false,
        -- Persisted separately from temporary runtime stops.
        autoPreference = false,
        autoLoop = true,
        x2 = true,
        autoSkip = true,
        autoPlayAgain = true,
        playbackSpeed = 1,
        lateTolerance = 0.35,
        initialDelay = 1.2,
        endTimeout = 600,
        lockCamera = false,
        remoteMode = true,
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
    recordedCameraTrack = {},
    recordingLive = false,
    -- Explicit pre-wave/combat phase. Opening actions are replayed immediately;
    -- actions after this flips true are synchronized to the live wave timer.
    recordingCombatStarted = false,
    recordingPreCombatDirection = nil,
    recordingClock = nil,
    recordingClockInitial = nil,
    recordingClockDirection = "up",
    recordingClockChanges = 0,
    recordingClockFirstChangeAt = nil,
    recordingClockFirstValue = nil,
    recordingWave = nil,
    recordingWaveStartClock = nil,
    recordingWaveStartedAt = nil,
    recordedPlacements = {},
    recordedUnitInstances = {},
    pendingPlacements = {},
    lastUserGameInput = 0,
    lastUserActionHint = "",
    replayUnits = {},
    remoteHookReady = false,
    remoteHookError = nil,
    clockCacheAt = 0,
    clockCache = nil,
    clockTimerSource = nil,
    clockWaveSource = nil,
    currentSlot = nil,
    pendingPlacementSlot = nil,
    nextUnitId = 0,
    touchInputIds = {},
    touchGestures = {},
    nextTouchId = 0,
    syntheticTouchId = 1000,
    playing = false,
    paused = false,
    playToken = 0,
    pauseStarted = 0,
    pauseAccum = 0,
    generatedInput = false,
    pressedKeys = {},
    pressedButtons = {},
    pressedTouches = {},
    playbackCameraType = nil,
    playbackCameraSubject = nil,
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
    bindingScanAt = 0,
    bindingScan = {},
    controlRunId = 0,
    autoRunToken = 0,
    playbackSource = nil,
    playbackUsesRemote = false,
    waitFreshMatch = false,
    cashCacheAt = 0,
    cashCache = nil,
    cashSource = nil,
    cashDiscoveryAt = 0,
    cashDiscoveryQueued = false,
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
    state.config.saveRevision = math.max((tonumber(state.config.saveRevision) or 0) + 1, os.time() * 1000)
    env.TDMacroSavedConfig = copyTable(state.config)
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
    local loaded = Core.newestConfig(readJson(CONFIG_FILE), readJson(FALLBACK_FILE))
    loaded = Core.newestConfig(loaded, env.TDMacroSavedConfig)
    local savedAutoPreference = loaded and loaded.settings and loaded.settings.autoPreference
    local savedAuto = loaded and loaded.settings and loaded.settings.auto

    state.config = mergeDefaults(loaded, copyTable(defaultConfig))

    -- 1.4.4: AUTOSTART preference is owned only by the toggle.
    -- Runtime code may temporarily set settings.auto=false, but that must not
    -- erase the user's choice for the next script launch.
    if type(savedAutoPreference) == "boolean" then
        state.config.settings.autoPreference = savedAutoPreference
    else
        -- Migration from <=1.4.3.
        state.config.settings.autoPreference = savedAuto == true
    end
    state.config.settings.auto = state.config.settings.autoPreference == true

    local normalized = {}
    for index, macro in ipairs(type(state.config.macros) == "table" and state.config.macros or {}) do
        normalized[#normalized + 1] = Core.normalizeMacro(macro, "Macro " .. index)
    end
    state.config.macros = normalized

    -- 1.4.19: recordings are map-specific by design. Older builds saved the
    -- fingerprint inside the macro but did not always create the lookup entry,
    -- so AUTO could only find the first/explicitly bound map. Repair missing
    -- exact and map bindings without overwriting anything the user bound.
    state.config.manualMatches = type(state.config.manualMatches) == "table" and state.config.manualMatches or {}
    state.config.mapMatches = type(state.config.mapMatches) == "table" and state.config.mapMatches or {}
    local exactWinners, mapWinners = {}, {}
    local function betterBindingMacro(candidate, current)
        if not current then return true end
        if (candidate.isDefault == true) ~= (current.isDefault == true) then return candidate.isDefault == true end
        local candidateUsed, currentUsed = tonumber(candidate.lastUsed) or 0, tonumber(current.lastUsed) or 0
        if candidateUsed ~= currentUsed then return candidateUsed > currentUsed end
        return (tonumber(candidate.savedAt) or 0) > (tonumber(current.savedAt) or 0)
    end
    for _, macro in ipairs(state.config.macros) do
        local exactKey = tostring(macro.fingerprintKey or Core.fingerprintKey(macro.fingerprint))
        if not state.config.manualMatches[exactKey] and betterBindingMacro(macro, exactWinners[exactKey]) then
            exactWinners[exactKey] = macro
        end
        local mapKey = Core.mapBindingKey(macro.fingerprint)
        if not state.config.mapMatches[mapKey] and betterBindingMacro(macro, mapWinners[mapKey]) then
            mapWinners[mapKey] = macro
        end
    end
    for key, macro in pairs(exactWinners) do state.config.manualMatches[key] = macro.id end
    for key, macro in pairs(mapWinners) do state.config.mapMatches[key] = macro.id end

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

local function snapshotToCFrame(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.cframe) ~= "table" or #snapshot.cframe < 12 then return nil end
    local ok, value = pcall(function() return CFrame.new(table.unpack(snapshot.cframe, 1, 12)) end)
    return ok and value or nil
end

local function recordCameraFrame(force)
    if not state.recording or (state.config and state.config.settings.remoteMode) then return end
    local snapshot = cameraSnapshot()
    local current = snapshotToCFrame(snapshot)
    if not current then return end
    local previous = state.recordedCameraTrack[#state.recordedCameraTrack]
    if not force and previous then
        local previousCFrame = snapshotToCFrame(previous)
        if previousCFrame then
            local positionChanged = (current.Position - previousCFrame.Position).Magnitude > 0.015
            local directionChanged = current.LookVector:Dot(previousCFrame.LookVector) < 0.99998
                or current.UpVector:Dot(previousCFrame.UpVector) < 0.99998
            local fovChanged = math.abs((snapshot.fov or 70) - (previous.fov or 70)) > 0.02
            if not positionChanged and not directionChanged and not fovChanged then return end
        end
    end
    state.recordedCameraTrack[#state.recordedCameraTrack + 1] = {
        t = math.max(0, os.clock() - state.recordingStarted),
        cframe = snapshot.cframe,
        fov = snapshot.fov,
    }
end

local cameraSampleAccumulator = 0
keep(RunService.Heartbeat:Connect(function(delta)
    if not state.recording or state.destroyed then
        cameraSampleAccumulator = 0
        return
    end
    cameraSampleAccumulator += delta
    if cameraSampleAccumulator >= 1 / 12 then
        cameraSampleAccumulator = 0
        recordCameraFrame(false)
    end
end))

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
local activateRecordingTimeline = function() end
local armMatchControls = function() end
local isMatchOver = function() return false end

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

local function guiButtonFor(object)
    local current = object
    for _ = 1, 7 do
        if not current then break end
        if current:IsA("GuiButton") then return current end
        current = current.Parent
    end
    return nil
end

local function guiObjectText(object, includeParents)
    if not object then return "" end
    local parts = {object.Name}
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        parts[#parts + 1] = object.Text
    end
    local count = 0
    for _, child in ipairs(object:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
            parts[#parts + 1] = child.Text
            count += 1
            if count >= 24 then break end
        end
    end
    if includeParents then
        local parent = object.Parent
        for _ = 1, 3 do
            if not parent or parent:IsA("LayerCollector") then break end
            parts[#parts + 1] = parent.Name
            local buttonCount = 0
            for _, sibling in ipairs(parent:GetChildren()) do
                if sibling:IsA("GuiButton") then buttonCount += 1 end
            end
            -- A wrapper with one button may keep its caption as a sibling. A
            -- panel with several buttons must not lend every caption to every button.
            if buttonCount > 1 then break end
            for _, sibling in ipairs(parent:GetChildren()) do
                if sibling ~= object and (sibling:IsA("TextLabel") or sibling:IsA("TextButton")) then
                    parts[#parts + 1] = sibling.Text
                end
            end
            parent = parent.Parent
        end
    end
    return table.concat(parts, " ")
end

-- Build a cheap semantic signature for a single visible GUI node. Roblox
-- games often keep the caption, hitbox and state in three different siblings;
-- limiting discovery to GuiButton therefore misses controls which still click
-- perfectly through VirtualInputManager.
local function guiSemanticText(object)
    if not object then return "" end
    local parts = {object.Name, object.ClassName}
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        parts[#parts + 1] = tostring(object.Text or "")
    end
    local ok, attributes = pcall(function() return object:GetAttributes() end)
    if ok then
        for key, value in pairs(attributes) do
            if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
                parts[#parts + 1] = tostring(key)
                parts[#parts + 1] = tostring(value)
            end
        end
    end
    if object:IsA("GuiButton") then
        local count = 0
        for _, child in ipairs(object:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                parts[#parts + 1] = tostring(child.Text or "")
                parts[#parts + 1] = child.Name
                count += 1
                if count >= 12 then break end
            end
        end
    end
    local parent = object.Parent
    for _ = 1, 6 do
        if not parent or parent:IsA("LayerCollector") then break end
        parts[#parts + 1] = parent.Name
        if parent:IsA("TextButton") then parts[#parts + 1] = tostring(parent.Text or "") end
        parent = parent.Parent
    end
    return table.concat(parts, " ")
end

local function clickableGuiFor(anchor, kind)
    if not anchor or not anchor:IsA("GuiObject") then return nil end
    local button = guiButtonFor(anchor)
    if button and instanceVisible(button) then return button end
    local position, size = anchor.AbsolutePosition, anchor.AbsoluteSize
    local x, y = position.X + size.X / 2, position.Y + size.Y / 2
    local ok, objects = pcall(function() return GuiService:GetGuiObjectsAtPosition(x, y) end)
    if ok then
        for _, object in ipairs(objects) do
            if object:IsA("GuiButton") and instanceVisible(object)
                and not (state.gui and object:IsDescendantOf(state.gui)) then
                return object
            end
        end
    end
    -- Some HUDs place "AUTO SKIP" next to (not inside) a transparent button.
    -- Associate a matching/unique nearby button before falling back to clicking
    -- the text anchor itself.
    local parent = anchor.Parent
    for _ = 1, 3 do
        if not parent or parent:IsA("LayerCollector") then break end
        local visibleButtons = {}
        local bestRelated, bestRelatedScore = nil, 0
        for _, candidate in ipairs(parent:GetDescendants()) do
            if candidate:IsA("GuiButton") and instanceVisible(candidate)
                and not (state.gui and candidate:IsDescendantOf(state.gui)) then
                visibleButtons[#visibleButtons + 1] = candidate
                if kind then
                    local relatedScore = Core.bindingScore(kind, guiObjectText(candidate, true), candidate.Name)
                    if relatedScore > bestRelatedScore then
                        bestRelated, bestRelatedScore = candidate, relatedScore
                    end
                end
                if #visibleButtons >= 24 then break end
            end
        end
        if bestRelated and bestRelatedScore >= 55 then return bestRelated end
        if #visibleButtons == 1 then return visibleButtons[1] end
        parent = parent.Parent
    end
    -- A label/frame is still a useful anchor: sending a real pointer event to
    -- its centre reaches the game's invisible hitbox even without a GuiButton.
    return anchor
end

local function actionHintAtPoint(x, y)
    local object = guiAtPoint(x, y)
    if not object then return "" end
    local parts = {}
    local current = object
    for _ = 1, 4 do
        if not current then break end
        parts[#parts + 1] = current.Name
        if current:IsA("TextLabel") or current:IsA("TextButton") then parts[#parts + 1] = current.Text end
        current = current.Parent
    end
    return Core.cleanText(table.concat(parts, " "))
end

local function eventPosition(input)
    local position = input.Position
    return math.floor(position.X), math.floor(position.Y)
end

local function isMovementControlPoint(x, y)
    if not UIS.TouchEnabled then return false end
    local ok, objects = pcall(function() return GuiService:GetGuiObjectsAtPosition(x, y) end)
    if ok then
        for _, object in ipairs(objects) do
            local current = object
            for _ = 1, 7 do
                if not current then break end
                local name = Core.cleanText(current.Name):gsub("%s+", "")
                if name:find("thumbstick", 1, true) or name:find("joystick", 1, true)
                    or name:find("touchcontrol", 1, true) or name:find("movementcontrol", 1, true) then
                    return true
                end
                current = current.Parent
            end
        end
    end
    local screen = viewport()
    return x <= screen.w * 0.34 and y >= screen.h * 0.56
end

local function parseClockText(text)
    text = tostring(text or "")
    local minutes, seconds = text:match("(%d+)%s*:%s*(%d%d?)")
    if minutes and seconds and tonumber(seconds) < 60 then return tonumber(minutes) * 60 + tonumber(seconds) end
    return nil
end

local function detectGameClock()
    if os.clock() - state.clockCacheAt < 0.12 then
        return state.clockCache == false and nil or state.clockCache
    end
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    local bestTimer, bestTimerScore = nil, 0
    local bestWave, bestWaveScore = nil, 0
    local timerBinding = state.config and state.config.bindings and state.config.bindings.matchTimer
    if timerBinding and timerBinding.mode == "manual" then
        local bound = resolveGuiPath(timerBinding.path)
        if bound and instanceVisible(bound) then
            local candidates = {bound}
            for _, child in ipairs(bound:GetDescendants()) do candidates[#candidates + 1] = child end
            for _, object in ipairs(candidates) do
                if object:IsA("TextLabel") or object:IsA("TextButton") then
                    local clock = parseClockText(object.Text)
                    if clock then
                        bestTimer = {time = clock, text = object.Text, path = guiPath(object), source = object}
                        bestTimerScore = 1000
                        break
                    end
                end
            end
        end
    end
    for _, object in ipairs(playerGui:GetDescendants()) do
        if (object:IsA("TextLabel") or object:IsA("TextButton")) and instanceVisible(object)
            and not (state.gui and object:IsDescendantOf(state.gui)) then
            local text = tostring(object.Text or "")
            local clean = Core.cleanText(text .. " " .. object.Name .. " " .. (object.Parent and object.Parent.Name or ""))
            local clock = parseClockText(text)
            if clock then
                local score = 20
                if clean:find("timer", 1, true) or clean:find("time", 1, true)
                    or clean:find("clock", 1, true) or clean:find("время", 1, true) then score += 60 end
                if clean:find("wave", 1, true) or clean:find("волна", 1, true) then score += 20 end
                if object.AbsoluteSize.X >= 35 and object.AbsoluteSize.X <= 300 then score += 5 end
                if score > bestTimerScore then
                    bestTimerScore = score
                    bestTimer = {time = clock, text = text, path = guiPath(object), source = object}
                end
            end
            if clean:find("wave", 1, true) or clean:find("волна", 1, true) then
                local number = tonumber(text:match("(%d+)"))
                if number then
                    local score = 50
                    if Core.cleanText(object.Name):find("wave", 1, true) then score += 30 end
                    if score > bestWaveScore then
                        bestWaveScore = score
                        bestWave = number
                        state.clockWaveSource = object
                    end
                end
            end
        end
    end
    if not bestTimer and not bestWave then
        state.clockCacheAt = os.clock()
        state.clockCache = false
        return nil
    end
    local result = {
        wave = bestWave,
        time = bestTimer and bestTimer.time or nil,
        text = bestTimer and bestTimer.text or nil,
        timerPath = bestTimer and bestTimer.path or nil,
    }
    state.clockTimerSource = bestTimer and bestTimer.source or state.clockTimerSource
    state.clockCacheAt = os.clock()
    state.clockCache = result
    return result
end

local function readGameClockFast()
    local timerSource = state.clockTimerSource
    local waveSource = state.clockWaveSource
    local time, timerText, timerPath = nil, nil, nil
    local wave = nil

    if timerSource and timerSource:IsDescendantOf(game) and instanceVisible(timerSource)
        and (timerSource:IsA("TextLabel") or timerSource:IsA("TextButton") or timerSource:IsA("TextBox")) then
        timerText = tostring(timerSource.Text or "")
        time = parseClockText(timerText)
        timerPath = guiPath(timerSource)
    end
    if waveSource and waveSource:IsDescendantOf(game) and instanceVisible(waveSource)
        and (waveSource:IsA("TextLabel") or waveSource:IsA("TextButton") or waveSource:IsA("TextBox")) then
        wave = tonumber(tostring(waveSource.Text or ""):match("(%d+)"))
    end

    if time == nil and wave == nil then return nil end
    return {wave = wave, time = time, text = timerText, timerPath = timerPath}
end


local function parseCashNumber(value)
    if type(value) == "number" then
        return value >= 0 and value or nil
    end
    local text = tostring(value or "")
        :gsub(",", "")
        :gsub("%s+", "")
        :gsub("[$€£¥₽]", "")
    local amount, suffix = text:match("^([%d%.]+)([kKmMbBtT]?)$")
    if not amount then
        amount, suffix = text:match("([%d%.]+)([kKmMbBtT]?)$")
    end
    amount = tonumber(amount)
    if not amount then return nil end
    suffix = string.lower(tostring(suffix or ""))
    local multiplier = suffix == "k" and 1e3
        or suffix == "m" and 1e6
        or suffix == "b" and 1e9
        or suffix == "t" and 1e12
        or 1
    return amount * multiplier
end

local function readCashSourceFast(source)
    if not source or not source:IsDescendantOf(game) then return nil end
    if source:IsA("IntValue") or source:IsA("NumberValue") then
        return tonumber(source.Value)
    end
    if source:IsA("TextLabel") or source:IsA("TextButton") or source:IsA("TextBox") then
        return parseCashNumber(source.Text)
    end
    return nil
end

local function detectMatchCash(force)
    -- The hot path must be O(1): once the real match-money object is known we
    -- read only that object. Never rescan the whole PlayerGui from an input or
    -- RemoteEvent path.
    local fastValue = readCashSourceFast(state.cashSource)
    if fastValue ~= nil then
        state.cashCacheAt = os.clock()
        state.cashCache = fastValue
        return fastValue, state.cashSource
    end
    if state.cashSource then
        state.cashSource = nil
        state.cashCache = nil
    end
    if not force then return nil, nil end

    state.cashDiscoveryAt = os.clock()
    local bestValue, bestScore, bestSource = nil, -math.huge, nil

    -- Prefer replicated values explicitly named as match money. Never accept
    -- "Coins" here: Alliance TD uses Coins as the persistent lobby wallet.
    for _, root in ipairs({player, player:FindFirstChild("leaderstats")}) do
        if root then
            for _, object in ipairs(root:GetDescendants()) do
                if object:IsA("IntValue") or object:IsA("NumberValue") then
                    local name = Core.cleanText(object.Name):gsub("%s+", "")
                    local score = nil
                    if name == "cash" or name == "money" or name == "matchcash"
                        or name == "matchmoney" or name == "ingamecash" then
                        score = 220
                    elseif name:find("cash", 1, true) or name:find("matchmoney", 1, true) then
                        score = 180
                    end
                    if score and tonumber(object.Value) ~= nil and score > bestScore then
                        bestValue, bestScore, bestSource = tonumber(object.Value), score, object
                    end
                end
            end
        end
    end

    -- GUI fallback is intentionally discovery-only. It may be a large tree, so
    -- it is never polled every frame / every 0.2 s like 1.4.6 did.
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if playerGui and not bestSource then
        for _, object in ipairs(playerGui:GetDescendants()) do
            if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
                and instanceVisible(object) and not (state.gui and object:IsDescendantOf(state.gui)) then
                local raw = tostring(object.Text or "")
                local value = parseCashNumber(raw)
                if value ~= nil then
                    local parent = object.Parent
                    local context = object.Name
                    for _ = 1, 3 do
                        if not parent or parent:IsA("LayerCollector") then break end
                        context ..= " " .. parent.Name
                        parent = parent.Parent
                    end
                    local clean = Core.cleanText(context .. " " .. raw)
                    local compact = clean:gsub("%s+", "")
                    local score = 0

                    if compact:find("matchcash", 1, true) or compact:find("ingamecash", 1, true) then score += 180 end
                    if clean:find(" cash", 1, true) or clean:find("cash ", 1, true)
                        or compact:find("cash", 1, true) then score += 130 end
                    if clean:find(" money", 1, true) or clean:find("money ", 1, true)
                        or compact:find("money", 1, true) then score += 115 end
                    if raw:find("$", 1, true) then score += 90 end
                    if compact:find("coin", 1, true) or compact:find("gem", 1, true)
                        or compact:find("summon", 1, true) or compact:find("shop", 1, true)
                        or compact:find("lobby", 1, true) then
                        score -= 180
                    end

                    if object.AbsoluteSize.X >= 25 and object.AbsoluteSize.X <= 320 then score += 5 end
                    if score > bestScore and score >= 70 then
                        bestValue, bestScore, bestSource = value, score, object
                    end
                end
            end
        end
    end

    state.cashCacheAt = os.clock()
    state.cashCache = bestValue
    state.cashSource = bestSource
    return bestValue, bestSource
end

local function requestCashDiscovery(force)
    if readCashSourceFast(state.cashSource) ~= nil then return end
    -- Recording must never launch a full PlayerGui discovery in parallel with
    -- the player's taps. We resolve the source once before recording starts.
    if state.recording then return end
    if state.cashDiscoveryQueued then return end
    if not force and os.clock() - state.cashDiscoveryAt < 1.25 then return end
    state.cashDiscoveryQueued = true
    task.spawn(function()
        if not state.destroyed then pcall(detectMatchCash, true) end
        state.cashDiscoveryQueued = false
    end)
end

local function waitForRecordedCash(event, token, opening)
    local required = tonumber(event and event.cashBefore)
    if not required then return true end

    local warned = false
    local unseenSince = os.clock()
    local startedAt = os.clock()
    local pauseOrigin = state.pauseAccum or 0
    while token == state.playToken and state.playing and not state.destroyed do
        while state.paused and token == state.playToken do task.wait(0.05) end
        if isMatchOver() then return false end
        if token ~= state.playToken or not state.playing or state.destroyed then return false end
        if opening and os.clock() - startedAt - ((state.pauseAccum or 0) - pauseOrigin) >= 30 then
            log("Старт остановлен: не удалось дождаться записанного cash", true)
            return false
        end
        local current = detectMatchCash(false)
        if current ~= nil then
            unseenSince = os.clock()
            if current + 0.5 >= required then return true end
            if not warned then
                warned = true
                log(string.format("Жду cash: %.0f / %.0f", current, required))
            end
        else
            requestCashDiscovery(false)
            if not opening and os.clock() - unseenSince >= 2.0 then
                -- Money sync is a safety guard, not permission to freeze the macro.
                return true
            end
        end
        task.wait(0.08)
    end
    return false
end

local function addRecordedEvent(kind, data)
    if not state.recording or state.generatedInput then return end
    if state.config and state.config.settings.remoteMode and not state.recordingLive then return end
    data = data or {}
    data.kind = kind
    data.t = math.max(0, os.clock() - state.recordingStarted)
    if kind == "remote" and state.config and state.config.settings.remoteMode then
        -- Do not infer "opening" later from event order. Record the actual phase.
        data.opening = state.recordingCombatStarted ~= true
        if data.cashBefore == nil then
            data.cashBefore = readCashSourceFast(state.cashSource) or state.cashCache
        end
    end
    local clock = state.recordingClock
    if not clock and kind ~= "remote" then clock = detectGameClock() end
    if clock then
        data.wave = clock.wave
        data.gameClock = clock.time
        if clock.wave ~= nil then
            if state.recordingWave ~= clock.wave then
                state.recordingWave = clock.wave
                state.recordingWaveStartClock = clock.time
                state.recordingWaveStartedAt = os.clock()
            end
            if clock.time ~= nil and state.recordingWaveStartClock ~= nil then
                data.waveTime = math.abs(clock.time - state.recordingWaveStartClock)
            elseif state.recordingWaveStartedAt then
                data.waveTime = math.max(0, os.clock() - state.recordingWaveStartedAt)
            end
        end
    end
    state.recordedEvents[#state.recordedEvents + 1] = data
    if state.labels.recordCount then state.labels.recordCount.Text = tostring(#state.recordedEvents) .. " событий" end
    return data
end

local function instancePath(instance)
    if typeof(instance) ~= "Instance" then return nil end
    local parts = {}
    local current = instance
    while current and current ~= game do
        local ordinal = 1
        local parent = current.Parent
        if parent then
            ordinal = 0
            for _, sibling in ipairs(parent:GetChildren()) do
                if sibling.Name == current.Name and sibling.ClassName == current.ClassName then
                    ordinal += 1
                    if sibling == current then break end
                end
            end
        end
        table.insert(parts, 1, {name = current.Name, class = current.ClassName, ordinal = math.max(1, ordinal)})
        current = current.Parent
    end
    return current == game and parts or nil
end

local function resolveInstancePath(path)
    if type(path) ~= "table" then return nil end
    local current = game
    for _, part in ipairs(path) do
        local found = nil
        local ordinal = 0
        for _, child in ipairs(current:GetChildren()) do
            if child.Name == part.name and (not part.class or child.ClassName == part.class) then
                ordinal += 1
                if ordinal == (tonumber(part.ordinal) or 1) then
                    found = child
                    break
                end
            end
        end
        if not found then return nil end
        current = found
    end
    return current
end

local function instancePosition(instance)
    if typeof(instance) ~= "Instance" then return nil end
    if instance:IsA("BasePart") then return instance.Position end
    if instance:IsA("Model") then
        local ok, pivot = pcall(function() return instance:GetPivot() end)
        if ok then return pivot.Position end
    end
    local part = instance:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function findPlacementRef(instance)
    local current = instance
    while current and current ~= workspace do
        if state.recordedUnitInstances[current] then return state.recordedUnitInstances[current] end
        current = current.Parent
    end
    local position = instancePosition(instance)
    if not position then return nil end
    local bestId, bestDistance = nil, math.huge
    for _, placement in ipairs(state.recordedPlacements) do
        local target = placement.position
        if target then
            local distance = (position - target).Magnitude
            if distance < bestDistance and distance <= 12 then
                bestId, bestDistance = placement.unitId, distance
            end
        end
    end
    return bestId
end

local function serializeValue(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if depth > 7 then return {__td = "truncated"} end
    local valueType = typeof(value)
    if value == nil then return {__td = "nil"} end
    if valueType == "string" or valueType == "number" or valueType == "boolean" then return value end
    if valueType == "Vector3" then return {__td = "Vector3", x = value.X, y = value.Y, z = value.Z} end
    if valueType == "Vector2" then return {__td = "Vector2", x = value.X, y = value.Y} end
    if valueType == "CFrame" then return {__td = "CFrame", components = {value:GetComponents()}} end
    if valueType == "Color3" then return {__td = "Color3", r = value.R, g = value.G, b = value.B} end
    if valueType == "EnumItem" then
        return {__td = "Enum", enum = tostring(value.EnumType):gsub("^Enum%.", ""), item = value.Name}
    end
    if valueType == "Instance" then
        local unitId = findPlacementRef(value)
        if unitId then return {__td = "unitRef", unitId = unitId, name = value.Name} end
        return {__td = "Instance", path = instancePath(value), name = value.Name, class = value.ClassName}
    end
    if valueType == "table" then
        if seen[value] then return {__td = "cycle"} end
        seen[value] = true
        local entries = {}
        for key, item in pairs(value) do
            entries[#entries + 1] = {
                key = serializeValue(key, depth + 1, seen),
                value = serializeValue(item, depth + 1, seen),
            }
        end
        seen[value] = nil
        return {__td = "table", entries = entries}
    end
    return {__td = "unsupported", valueType = valueType, text = tostring(value)}
end

local function serializeArguments(arguments)
    local output = {}
    local count = arguments.n or #arguments
    for index = 1, count do output[index] = serializeValue(arguments[index], 0, {}) end
    return output, count
end

local function collectActionText(value, parts, depth)
    depth = depth or 0
    if depth > 4 then return end
    local valueType = typeof(value)
    if valueType == "string" then
        parts[#parts + 1] = Core.cleanText(value)
    elseif valueType == "table" then
        for key, item in pairs(value) do
            collectActionText(key, parts, depth + 1)
            collectActionText(item, parts, depth + 1)
        end
    end
end

local function findWorldPosition(value, depth)
    depth = depth or 0
    if depth > 5 then return nil end
    local valueType = typeof(value)
    if valueType == "Vector3" then return value end
    if valueType == "CFrame" then return value.Position end
    if valueType == "table" then
        for _, item in pairs(value) do
            local position = findWorldPosition(item, depth + 1)
            if position then return position end
        end
    end
    return nil
end

local function classifyRemote(remote, arguments)
    local parts = {Core.cleanText(remote.Name)}
    for index = 1, arguments.n or #arguments do collectActionText(arguments[index], parts, 0) end
    if os.clock() - state.lastUserGameInput <= 1.25 and state.lastUserActionHint ~= "" then
        parts[#parts + 1] = state.lastUserActionHint
    end
    local text = " " .. table.concat(parts, " ") .. " "
    local position = nil
    for index = 1, arguments.n or #arguments do
        position = findWorldPosition(arguments[index], 0)
        if position then break end
    end
    local function contains(words)
        for _, word in ipairs(words) do
            if text:find(word, 1, true) then return true end
        end
        return false
    end
    local action = nil
    if contains({"upgrade", "levelup", "improve", "апгрейд", "улучш"}) then
        action = "upgrade"
    elseif contains({"sell", "remove tower", "delete tower", "продать", "продажа"}) then
        action = "sell"
    elseif contains({"place", "deploy", "spawn tower", "summon", "постав", "размест"}) then
        action = "place"
    elseif position and os.clock() - state.lastUserGameInput <= 0.65 then
        -- Generic placement remotes often expose only a world position. Keep
        -- the association window short so one tap cannot tag background traffic
        -- for the next second and a half.
        action = "place"
    else
        for index = 1, arguments.n or #arguments do
            local value = arguments[index]
            if typeof(value) == "Instance" and findPlacementRef(value) then
                action = "unit_action"
                break
            end
        end
    end
    return action, position, text
end

local function firstUsefulString(arguments)
    local fallback = nil
    for index = 1, arguments.n or #arguments do
        local value = arguments[index]
        if typeof(value) == "string" and #value > 0 and #value <= 80 then
            fallback = fallback or value
            local clean = Core.cleanText(value)
            if not clean:find("place", 1, true) and not clean:find("deploy", 1, true)
                and not clean:find("upgrade", 1, true) and not clean:find("sell", 1, true) then return value end
        end
        if typeof(value) == "Instance" and not value:IsA("RemoteEvent") and not value:IsA("RemoteFunction") then return value.Name end
    end
    return fallback
end

local function captureRemote(remote, method, arguments, calledAt, cashBefore)
    if not state.recording or state.destroyed or state.generatedInput then return end
    if typeof(remote) ~= "Instance" or (not remote:IsA("RemoteEvent") and not remote:IsA("RemoteFunction")) then return end
    local action, position = classifyRemote(remote, arguments)
    local recentInput = (tonumber(calledAt) or os.clock()) - state.lastUserGameInput <= 1.5
    if not action and not recentInput then return end
    if not action then
        local remoteName = Core.cleanText(remote.Name)
        if remoteName:find("ping", 1, true) or remoteName:find("heartbeat", 1, true)
            or remoteName:find("camera", 1, true) or remoteName:find("position", 1, true) then
            return
        end
        -- Some Alliance TD tower actions have no useful action word/position in
        -- their arguments. They still need to be replayed exactly as recorded.
        -- This runs only AFTER the game's real Remote call (v1.2.1 ordering), so
        -- restoring generic requests cannot block the player's click.
        action = "request"
    end
    if not state.recordingLive then
        -- Timer detection is only a convenience. The first real tower request must never be lost.
        activateRecordingTimeline(detectGameClock(), nil, nil, false)
    end
    if not state.recordingLive then return end
    local unitId = nil
    if action == "place" then
        unitId = "u" .. tostring(#state.recordedPlacements + 1)
        state.recordedPlacements[#state.recordedPlacements + 1] = {
            unitId = unitId,
            position = position,
            unitName = firstUsefulString(arguments),
        }
    end
    local encoded, count = serializeArguments(arguments)
    local recorded = addRecordedEvent("remote", {
        action = action,
        method = method,
        remotePath = instancePath(remote),
        remoteName = remote.Name,
        args = encoded,
        argCount = count,
        unitId = unitId,
        unitName = firstUsefulString(arguments),
        position = position and {x = position.X, y = position.Y, z = position.Z} or nil,
        cashBefore = tonumber(cashBefore),
    })
    if recorded then
        if action == "place" then
            state.pendingPlacements[#state.pendingPlacements + 1] = {
                unitId = unitId,
                unitName = recorded.unitName,
                position = position,
                createdAt = os.clock(),
            }
        end
        log("REC " .. action .. " · " .. tostring(recorded.unitName or remote.Name))
    end
end

local function installRemoteHook()
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        state.remoteHookError = "executor не поддерживает hookmetamethod"
        return false
    end
    local bus = env.__TDMacroRemoteBus
    if type(bus) ~= "table" or type(bus.setListener) ~= "function" or bus.version ~= REMOTE_BUS_VERSION then
        if type(bus) == "table" and type(bus.setListener) == "function" then
            pcall(function() bus:setListener(nil) end)
        end
        bus = {listener = nil, cashSnapshot = nil, version = REMOTE_BUS_VERSION}
        local oldNamecall
        local callback = function(self, ...)
            local method = getnamecallmethod()
            local listener = bus.listener
            local fromExecutor = type(checkcaller) == "function" and checkcaller() or false
            if listener and not fromExecutor and (method == "FireServer" or method == "InvokeServer") then
                local arguments = table.pack(...)
                local calledAt = os.clock()
                local cashBefore = bus.cashSnapshot

                -- v1.2.1 fix: absolutely no recording callback/function is allowed
                -- before the game's own Remote call. The real click/action goes
                -- through first; capture work happens only afterwards.
                local results = table.pack(oldNamecall(self, ...))
                task.defer(function()
                    if bus.listener == listener then pcall(listener, self, method, arguments, calledAt, cashBefore) end
                end)
                return table.unpack(results, 1, results.n)
            end
            return oldNamecall(self, ...)
        end
        local wrapped = type(newcclosure) == "function" and newcclosure(callback) or callback
        local ok, result = pcall(function()
            oldNamecall = hookmetamethod(game, "__namecall", wrapped)
        end)
        if not ok or type(oldNamecall) ~= "function" then
            state.remoteHookError = "не удалось поставить Remote hook"
            return false
        end
        function bus:setListener(listener)
            self.listener = listener
        end
        env.__TDMacroRemoteBus = bus
    end
    bus:setListener(captureRemote)
    state.remoteBus = bus
    state.remoteHookReady = true
    return true
end

-- Keep the money snapshot fresh outside __namecall. This is O(1) after the
-- source is discovered and preserves cash-before-action without putting any
-- recording logic back in front of the game's real click/Remote path.
local cashSnapshotAccumulator = 0
keep(RunService.Heartbeat:Connect(function(delta)
    if state.destroyed or not state.recording or not state.remoteBus then
        cashSnapshotAccumulator = 0
        return
    end
    cashSnapshotAccumulator += delta
    if cashSnapshotAccumulator < 0.05 then return end
    cashSnapshotAccumulator = 0
    local value = readCashSourceFast(state.cashSource)
    if value ~= nil then
        state.cashCache = value
        state.cashCacheAt = os.clock()
        state.remoteBus.cashSnapshot = value
    end
end))

keep(workspace.DescendantAdded:Connect(function(object)
    if not state.recording or not state.recordingLive or not state.config or not state.config.settings.remoteMode then return end
    if not object:IsA("Model") and not object:IsA("BasePart") then return end
    local candidate = object:IsA("BasePart") and (object:FindFirstAncestorOfClass("Model") or object) or object
    if player.Character and candidate:IsDescendantOf(player.Character) then return end
    local candidatePosition = instancePosition(candidate)
    local candidateName = Core.cleanText(candidate.Name)
    for index = #state.pendingPlacements, 1, -1 do
        local pending = state.pendingPlacements[index]
        if os.clock() - pending.createdAt > 3 then
            table.remove(state.pendingPlacements, index)
        else
            local positionMatches = pending.position and candidatePosition
                and (candidatePosition - pending.position).Magnitude <= 14
            local wantedName = Core.cleanText(pending.unitName or "")
            local nameMatches = wantedName ~= "" and (candidateName:find(wantedName, 1, true)
                or wantedName:find(candidateName, 1, true))
            if positionMatches or (not pending.position and nameMatches) then
                state.recordedUnitInstances[candidate] = pending.unitId
                table.remove(state.pendingPlacements, index)
                break
            end
        end
    end
end))

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
    local pointed = guiAtPoint(x, y)
    local object = guiButtonFor(pointed) or pointed
    state.config.bindings[kind] = {
        mode = "manual",
        nx = math.clamp(x / size.w, 0, 1),
        ny = math.clamp(y / size.h, 0, 1),
        path = guiPath(object),
        objectName = object and object.Name or nil,
        objectText = object and guiObjectText(object, true) or nil,
    }
    state.bindingScanAt = 0
    state.bindingCapture = nil
    saveDisk()
    log("Привязка " .. kind .. " сохранена")
    refreshBindings()
    return true
end

keep(UIS.InputBegan:Connect(function(input, processed)
    if state.destroyed or state.generatedInput then return end
    if state.bindingCapture and captureBinding(state.bindingCapture, input) then return end

    -- SERVER recording must be completely passive on the real input path.
    -- Do not query GuiService, inspect controls or touch the player's gesture.
    -- We only timestamp the input so the later RemoteEvent can be associated
    -- with a user action. The game receives the tap with essentially no work
    -- done by this callback.
    if state.recording and state.config.settings.remoteMode then
        local inputType = input.UserInputType
        if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseButton2
            or inputType == Enum.UserInputType.Touch then
            state.lastUserGameInput = os.clock()
            state.lastUserActionHint = ""
        end
        return
    end

    if input.UserInputType == Enum.UserInputType.Touch then
        local x, y = eventPosition(input)
        if isMovementControlPoint(x, y) then return end
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.Touch then
        local x, y = eventPosition(input)
        if not isOwnPoint(x, y) then
            state.lastUserGameInput = os.clock()
            state.lastUserActionHint = actionHintAtPoint(x, y)
        end
    elseif input.UserInputType == Enum.UserInputType.Keyboard and not state.config.settings.remoteMode then
        state.lastUserGameInput = os.clock()
    end
    if not state.recording then return end
    if state.config.settings.remoteMode then return end

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
    if state.config.settings.remoteMode then return end
    local inputType = input.UserInputType
    if inputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
        local focused = UIS:GetFocusedTextBox()
        if focused and state.gui and focused:IsDescendantOf(state.gui) then return end
        addRecordedEvent("key_up", {key = input.KeyCode.Name, slot = slotCodes[input.KeyCode]})
    elseif inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseButton2 or inputType == Enum.UserInputType.Touch then
        if inputType == Enum.UserInputType.Touch and not state.touchInputIds[input] then return end
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
    if state.config.settings.remoteMode then return end
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

local function resetMatchTracking(delay)
    state.replayCheck = nil
    state.autoRunToken += 1
    state.controlRunId += 1
    state.controllerNotBefore = delay and delay > 0 and (os.clock() + delay) or 0
    state.stableKey = nil
    state.stableSince = 0
    state.playbackFinishedAt = 0
    state.lastFingerprint = nil
    state.matchSpawnPosition = nil
    state.clockCacheAt = 0
    state.clockCache = nil
    state.clockTimerSource = nil
    state.clockWaveSource = nil
    state.cashCacheAt = 0
    state.cashCache = nil
    state.cashSource = nil
    state.cashDiscoveryAt = 0
    state.cashDiscoveryQueued = false
    state.mapCacheKey = nil
    state.mapCacheAt = 0
    state.bindingScanAt = 0
    state.bindingScan = {}
end

local function releaseAll()
    state.generatedInput = true
    for keyName in pairs(state.pressedKeys) do
        local keyCode = Enum.KeyCode[keyName]
        if keyCode then pcall(function() VIM:SendKeyEvent(false, keyCode, false, game) end) end
    end
    local size = viewport()
    for button in pairs(state.pressedButtons) do
        if not UIS.TouchEnabled then
            pcall(function() VIM:SendMouseButtonEvent(size.w / 2, size.h / 2, button, false, game, 0) end)
        end
    end
    for touchId, point in pairs(state.pressedTouches) do
        pcall(function() VIM:SendTouchEvent(touchId, 2, point.x, point.y) end)
    end
    state.pressedKeys = {}
    state.pressedButtons = {}
    state.pressedTouches = {}
    state.generatedInput = false
end

local function releaseCameraControl()
    local camera = workspace.CurrentCamera
    if camera and state.playbackCameraType then
        pcall(function()
            if state.playbackCameraSubject then camera.CameraSubject = state.playbackCameraSubject end
            camera.CameraType = state.playbackCameraType
        end)
    end
    state.playbackCameraType = nil
    state.playbackCameraSubject = nil
end

local function stopPlayback(reason, emergency)
    state.playToken += 1
    state.playing = false
    state.paused = false
    state.playbackSource = nil
    state.playbackUsesRemote = false
    releaseAll()
    releaseCameraControl()
    if emergency then
        state.config.settings.auto = false
        state.config.settings.autoPreference = false
        resetMatchTracking(0)
        transition("IDLE", reason or "Emergency stop")
        saveDisk()
    end
    if reason then log(reason, emergency == true) end
    refreshAll()
end

local function stopCurrentMacro(reason)
    local keepAutomation = state.config.settings.auto == true
    stopPlayback(nil, false)
    state.autoRunToken += 1
    state.controlRunId += 1
    if keepAutomation then
        state.playbackFinishedAt = os.clock()
        transition("WAIT_END", "макрос остановлен · жду конец матча")
    else
        state.playbackFinishedAt = 0
        transition("IDLE", reason or "макрос остановлен")
    end
    if reason then log(reason) end
    refreshAll()
end

local function deserializeValue(value, depth)
    depth = depth or 0
    if depth > 8 or type(value) ~= "table" or value.__td == nil then return value end
    if value.__td == "nil" then return nil end
    if value.__td == "Vector3" then return Vector3.new(value.x or 0, value.y or 0, value.z or 0) end
    if value.__td == "Vector2" then return Vector2.new(value.x or 0, value.y or 0) end
    if value.__td == "CFrame" and type(value.components) == "table" then
        return CFrame.new(table.unpack(value.components, 1, 12))
    end
    if value.__td == "Color3" then return Color3.new(value.r or 0, value.g or 0, value.b or 0) end
    if value.__td == "Enum" and Enum[value.enum] then return Enum[value.enum][value.item] end
    if value.__td == "Instance" then return resolveInstancePath(value.path) end
    if value.__td == "unitRef" then
        local deadline = os.clock() + 2.5
        while state.playing and os.clock() < deadline and not state.replayUnits[value.unitId] do task.wait(0.05) end
        return state.replayUnits[value.unitId]
    end
    if value.__td == "table" then
        local output = {}
        for _, entry in ipairs(type(value.entries) == "table" and value.entries or {}) do
            local key = deserializeValue(entry.key, depth + 1)
            if key ~= nil then output[key] = deserializeValue(entry.value, depth + 1) end
        end
        return output
    end
    return nil
end

local function nearbyUnitCandidates(position)
    local output = {}
    if not position then return output end
    local parts = {}
    local ok = pcall(function()
        local parameters = OverlapParams.new()
        parameters.FilterType = Enum.RaycastFilterType.Exclude
        parameters.FilterDescendantsInstances = player.Character and {player.Character} or {}
        parts = workspace:GetPartBoundsInRadius(position, 14, parameters)
    end)
    if not ok then return output end
    for _, object in ipairs(parts) do
        local candidate = object:FindFirstAncestorOfClass("Model") or object
        if not output[candidate] then
            local candidatePosition = instancePosition(candidate)
            if candidatePosition and (candidatePosition - position).Magnitude <= 14 then output[candidate] = true end
        end
    end
    return output
end

local function resolvePlacedUnit(event, before, token)
    if not event.unitId or type(event.position) ~= "table" then return false end
    local position = Vector3.new(event.position.x or 0, event.position.y or 0, event.position.z or 0)
    local deadline = os.clock() + 2.5
    local best, bestDistance = nil, math.huge
    repeat
        if token and (token ~= state.playToken or not state.playing or state.destroyed) then return false end
        for candidate in pairs(nearbyUnitCandidates(position)) do
            if not before[candidate] and candidate:IsDescendantOf(workspace) then
                local candidatePosition = instancePosition(candidate)
                local distance = candidatePosition and (candidatePosition - position).Magnitude or math.huge
                if distance < bestDistance then best, bestDistance = candidate, distance end
            end
        end
        if best then
            state.replayUnits[event.unitId] = best
            return true
        end
        task.wait(0.1)
    until not state.playing or os.clock() >= deadline
    return false
end

local function returnedInstance(value, depth)
    depth = depth or 0
    if depth > 4 then return nil end
    if typeof(value) == "Instance" then return value end
    if typeof(value) == "table" then
        for _, item in pairs(value) do
            local found = returnedInstance(item, depth + 1)
            if found then return found end
        end
    end
    return nil
end

local function replayRemoteEvent(event, openingToken)
    local sendToken = openingToken or state.playToken
    if not state.playing or state.destroyed then return false end
    if isMatchOver(true) then
        log("Действие отменено: матч уже завершён")
        return false
    end
    local remote = resolveInstancePath(event.remotePath)
    if not remote or (not remote:IsA("RemoteEvent") and not remote:IsA("RemoteFunction")) then
        log("Remote не найден: " .. tostring(event.remoteName), true)
        return false
    end
    local arguments = {}
    for index = 1, tonumber(event.argCount) or #(event.args or {}) do
        arguments[index] = deserializeValue(event.args and event.args[index], 0)
    end
    if sendToken ~= state.playToken or not state.playing or state.destroyed then return false end
    local position = type(event.position) == "table"
        and Vector3.new(event.position.x or 0, event.position.y or 0, event.position.z or 0) or nil
    local before = event.action == "place" and nearbyUnitCandidates(position) or {}
    if isMatchOver(true) then return false end
    local ok, result = pcall(function()
        if event.method == "InvokeServer" and remote:IsA("RemoteFunction") then
            return remote:InvokeServer(table.unpack(arguments, 1, tonumber(event.argCount) or #arguments))
        end
        remote:FireServer(table.unpack(arguments, 1, tonumber(event.argCount) or #arguments))
        return nil
    end)
    if not ok then
        log("Remote ошибка " .. tostring(event.action) .. ": " .. tostring(result), true)
        return false
    end
    if result == false then
        log("Сервер отклонил " .. tostring(event.action) .. " · " .. tostring(event.unitName or event.remoteName), true)
        return false
    end
    if sendToken ~= state.playToken or not state.playing or state.destroyed then return false end
    if event.action == "place" and event.unitId then
        local created = returnedInstance(result, 0)
        if created and created:IsDescendantOf(workspace) then
            state.replayUnits[event.unitId] = created
        elseif openingToken then
            if not resolvePlacedUnit(event, before, openingToken) then
                log("Установка не подтверждена: " .. tostring(event.unitName or event.remoteName), true)
                return false
            end
        else
            task.spawn(resolvePlacedUnit, event, before, state.playToken)
        end
    end
    log(string.format("%s · %s%s", tostring(event.action), tostring(event.unitName or event.remoteName),
        event.wave and (" · wave " .. tostring(event.wave)) or ""))
    return true
end

local function collectOpeningPlacements(events)
    local source = type(events) == "table" and events or {}
    local explicitPhase = false
    for _, event in ipairs(source) do
        if event.kind == "remote" and event.opening ~= nil then
            explicitPhase = true
            break
        end
    end
    if explicitPhase then
        local opening = {}
        for _, event in ipairs(source) do
            if event.kind == "remote" and event.opening == true then
                opening[#opening + 1] = event
            end
        end
        return opening, true
    end

    -- Compatibility for macros recorded before 1.4.3.
    local opening = {}
    local started = false
    local openingWave = nil
    for _, event in ipairs(source) do
        if event.kind == "remote" then
            local wave = tonumber(event.wave)
            if started and openingWave ~= nil and wave ~= nil and wave ~= openingWave then break end
            if event.action == "place" then
                if not started then
                    started = true
                    openingWave = wave
                end
                opening[#opening + 1] = event
            elseif started and (event.action == "upgrade" or event.action == "sell"
                or event.action == "unit_action") then
                break
            end
        end
    end
    return opening, false
end

-- Observe from launch, including while opening actions wait for cash/server.
-- If attached after the boundary, a moving combat clock must still unlock wave 1.
local function observePlaybackClock(timing, current, clockConfig)
    if not current then return end
    local direction = clockConfig and clockConfig.direction or "up"
    local previousWave, previousClock = timing.wave, timing.lastClock
    local changedWave = current.wave ~= nil and current.wave ~= previousWave
    local changedClock = current.time ~= nil and previousClock ~= nil and current.time ~= previousClock
    local observedDirection = changedClock and (current.time > previousClock and "up" or "down") or nil
    local jump = changedClock and math.abs(current.time - previousClock) > 3
    local anchorClock = current.time
    local anchored = false

    if timing.strictFirstWave and not timing.combatStarted then
        local waveStarted = current.wave ~= nil and (current.wave > 1
            or (previousWave ~= nil and previousWave < 1 and current.wave >= 1))
        local waveWithoutTimer = current.wave ~= nil and current.wave >= 1 and current.time == nil
        local boundary = changedClock and (jump
            or (timing.preCombatDirection ~= nil and observedDirection ~= timing.preCombatDirection)
            or (observedDirection == "up" and previousClock <= 1.5)
            or (observedDirection == "down" and previousClock >= 15))
        local activeWave = current.wave == nil or current.wave >= 1
        local missedBoundary = activeWave and changedClock and observedDirection == direction
        if waveStarted or waveWithoutTimer or (activeWave and boundary) or missedBoundary then
            timing.combatStarted = true
            anchored = true
            timing.useAbsoluteClock = missedBoundary and not waveStarted and not jump
                and not (timing.preCombatDirection ~= nil and observedDirection ~= timing.preCombatDirection)
            if changedClock and not jump and not waveStarted then anchorClock = previousClock end
        end
        if observedDirection then timing.preCombatDirection = observedDirection end
    elseif changedWave or jump then
        anchored = true
        timing.useAbsoluteClock = false
    end
    if anchored then
        timing.waveStartClock = anchorClock
        timing.waveStartedAt = os.clock()
    end
    if current.wave ~= nil then timing.wave = current.wave end
    if current.time ~= nil then timing.lastClock = current.time end
end

local function waitForRecordedMoment(event, clockConfig, timing, token, playbackStarted)
    local direction = clockConfig and clockConfig.direction or "up"
    local eventWave = tonumber(event.wave)
    local eventWaveTime = tonumber(event.waveTime)
    local eventGameClock = tonumber(event.gameClock)
    while token == state.playToken and state.playing and not state.destroyed do
        while state.paused and token == state.playToken do task.wait(0.05) end
        if token ~= state.playToken or not state.playing or state.destroyed or isMatchOver() then return false end
        local current = detectGameClock()
        observePlaybackClock(timing, current, clockConfig)
        if timing.strictFirstWave and not timing.combatStarted and current then
            task.wait(0.04)
            continue
        end

        local hasWaveClock = current and eventWave ~= nil and current.wave ~= nil
        if hasWaveClock then
            if current.wave > eventWave then return true end
            if current.wave < eventWave then
                task.wait(0.06)
                continue
            end
        end
        if current and eventWaveTime ~= nil and current.wave == eventWave
            and not (timing.useAbsoluteClock and eventGameClock ~= nil and current.time ~= nil) then
            local waveElapsed
            if current.time ~= nil and timing.waveStartClock ~= nil then
                waveElapsed = math.abs(current.time - timing.waveStartClock)
            elseif timing.waveStartedAt then
                waveElapsed = os.clock() - timing.waveStartedAt
            end
            if waveElapsed and waveElapsed >= eventWaveTime then return true end
            task.wait(0.04)
        elseif current and eventGameClock ~= nil and current.time ~= nil and (not eventWave or not current.wave or current.wave == eventWave) then
            local reached
            if direction == "down" then
                reached = current.time <= eventGameClock
            else
                reached = current.time >= eventGameClock
            end
            if reached then return true end
            task.wait(0.04)
        else
            -- Old recordings may include lobby time before their first server action.
            -- Remove only that leading delay and preserve all later event intervals.
            local elapsed = os.clock() - playbackStarted - state.pauseAccum
            local target = math.max(0, (tonumber(event.t) or 0) - (timing.fallbackOrigin or 0))
            local remaining = target - elapsed
            if remaining <= 0 then return true end
            task.wait(math.min(0.04, remaining))
        end
    end
    return false
end

local function sendEvent(event, recordedViewport)
    if isMatchOver(true) then return end
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
                -- Never reuse the low IDs assigned to the player's real fingers;
                -- doing so can release/replace the mobile movement thumbstick.
                local touchId = 1000 + (tonumber(event.touchId) or 1)
                sentTouch = pcall(function() VIM:SendTouchEvent(touchId, down and 0 or 2, x, y) end)
                if sentTouch then
                    if down then state.pressedTouches[touchId] = {x = x, y = y} else state.pressedTouches[touchId] = nil end
                end
            end
            if not sentTouch then
                if UIS.TouchEnabled then
                    local touchId = 2000 + button
                    VIM:SendTouchEvent(touchId, down and 0 or 2, x, y)
                    if down then state.pressedTouches[touchId] = {x = x, y = y} else state.pressedTouches[touchId] = nil end
                else
                    VIM:SendMouseButtonEvent(x, y, button, down, game, 0)
                    if down then state.pressedButtons[button] = true else state.pressedButtons[button] = nil end
                end
            end
        elseif event.kind == "mouse_wheel" then
            local x, y = Core.eventPoint(event, size, recordedViewport)
            if not UIS.TouchEnabled then
                VIM:SendMouseWheelEvent(x, y, (tonumber(event.delta) or 0) > 0, game)
            end
        end
    end)
    state.generatedInput = false
    if not ok then log("Ошибка события: " .. tostring(err), true) end
end

local function macroMatches(macro, currentFingerprint)
    if not macro or tonumber(macro.placeId) ~= game.PlaceId then return false end
    local key = Core.fingerprintKey(currentFingerprint)
    local boundId = Core.boundMacroId(currentFingerprint, state.config.manualMatches, state.config.mapMatches)
    if boundId then return boundId == macro.id end
    return tostring(macro.fingerprintKey) == key
end

local function playMacro(macro, force, fromAuto, expectedFingerprint)
    if state.recording then log("Сначала останови запись") return false end
    if isMatchOver(true) then log("Запуск отменён: матч уже завершён") return false end
    if state.playing then
        if fromAuto then
            log("Автозапуск пропущен · макрос уже идёт")
            return true
        end
        stopPlayback("Предыдущий запуск остановлен")
    end
    if not macro or type(macro.events) ~= "table" or #macro.events == 0 then
        log("У выбранного макроса нет событий", true)
        return false
    end
    local hasRemoteEvents = false
    for _, event in ipairs(macro.events) do
        if event.kind == "remote" then hasRemoteEvents = true break end
    end
    if not hasRemoteEvents and (not workspace.CurrentCamera or not rootPart()) then
        log("Камера или персонаж ещё не готовы", true)
        return false
    end
    if fromAuto then state.mapCacheAt = 0 end
    local currentFingerprint = fromAuto and fingerprint(state.matchSpawnPosition) or (expectedFingerprint or fingerprint())
    if fromAuto then
        local bound = Core.boundMacroId(currentFingerprint, state.config.manualMatches, state.config.mapMatches)
        if bound ~= macro.id or (expectedFingerprint
            and Core.mapBindingKey(expectedFingerprint) ~= Core.mapBindingKey(currentFingerprint))
            or (state.config.autoContext and state.config.autoContext.consumed
                and state.config.autoContext.key == Core.mapBindingKey(currentFingerprint)) then
            log("Автозапуск отменён: привязка/карта изменилась или матч уже занят")
            return false
        end
    end
    if not force and not macroMatches(macro, currentFingerprint) then
        log("Карта/спавн не совпадают. Автозапуск запрещён", true)
        return false
    end

    if not fromAuto then
        -- A manual launch owns this run and cancels any queued AUTO prepare task.
        state.autoRunToken += 1
        state.controlRunId += 1
    end
    state.playToken += 1
    local token = state.playToken
    state.playing = true
    state.playbackUsesRemote = hasRemoteEvents == true
    if hasRemoteEvents then requestCashDiscovery(true) end
    state.paused = false
    state.playbackSource = fromAuto and "auto" or "manual"
    state.pauseAccum = 0
    state.playbackFinishedAt = 0
    state.replayUnits = {}
    local liveClock = detectGameClock()
    state.config.autoContext = {key = Core.mapBindingKey(currentFingerprint), jobId = game.JobId,
        wave = liveClock and tonumber(liveClock.wave), consumed = true, sawResults = false}
    state.selectedId = macro.id
    macro.lastUsed = os.time()
    saveDisk()
    if fromAuto then transition("PLAYING", macro.name) end
    if not hasRemoteEvents then restoreCamera(macro.camera or (macro.fingerprint and macro.fingerprint.camera)) end
    local lockedCamera = cameraSnapshot()
    local speed = math.clamp(tonumber(state.config.settings.playbackSpeed) or 1, 0.25, 3)
    local playbackStarted = os.clock()
    local cameraFrames = {}
    for _, frame in ipairs(type(macro.cameraTrack) == "table" and macro.cameraTrack or {}) do
        local cframe = snapshotToCFrame(frame)
        if cframe then cameraFrames[#cameraFrames + 1] = {t = tonumber(frame.t) or 0, cframe = cframe, fov = tonumber(frame.fov)} end
    end
    if not hasRemoteEvents and (state.config.settings.lockCamera or #cameraFrames >= 2) then
        local camera = workspace.CurrentCamera
        if camera then
            state.playbackCameraType = camera.CameraType
            state.playbackCameraSubject = camera.CameraSubject
            pcall(function() camera.CameraType = Enum.CameraType.Scriptable end)
        end
    end
    log((force and "Force Play: " or "Запуск: ") .. macro.name .. " · " .. #macro.events .. " событий")
    refreshAll()
    armMatchControls()

    if not hasRemoteEvents and state.config.settings.lockCamera and lockedCamera then
        task.spawn(function()
            while token == state.playToken and state.playing and not state.destroyed do
                if not state.paused then restoreCamera(lockedCamera) end
                RunService.RenderStepped:Wait()
            end
        end)
    elseif not hasRemoteEvents and #cameraFrames >= 2 then
        task.spawn(function()
            local index = 1
            while token == state.playToken and state.playing and not state.destroyed do
                if state.paused then
                    RunService.RenderStepped:Wait()
                else
                    local elapsed = (os.clock() - playbackStarted - state.pauseAccum) * speed
                    while index < #cameraFrames - 1 and cameraFrames[index + 1].t <= elapsed do index += 1 end
                    local first = cameraFrames[index]
                    local second = cameraFrames[math.min(index + 1, #cameraFrames)]
                    local span = math.max(0.001, second.t - first.t)
                    local alpha = math.clamp((elapsed - first.t) / span, 0, 1)
                    local camera = workspace.CurrentCamera
                    if camera then
                        pcall(function()
                            camera.CFrame = first.cframe:Lerp(second.cframe, alpha)
                            if first.fov and second.fov then camera.FieldOfView = first.fov + (second.fov - first.fov) * alpha end
                        end)
                    end
                    RunService.RenderStepped:Wait()
                end
            end
        end)
    end

    task.spawn(function()
        local tolerance = math.max(0.05, tonumber(state.config.settings.lateTolerance) or 0.35)
        local lastSent = 0
        local waveTiming = {
            wave = nil,
            waveStartClock = nil,
            waveStartedAt = nil,
            lastClock = nil,
            fallbackOrigin = 0,
            strictFirstWave = false,
            combatStarted = true,
            preCombatDirection = nil,
        }
        local openingSent = {}
        if hasRemoteEvents then
            for _, event in ipairs(macro.events) do
                if event.kind == "remote" then
                    waveTiming.fallbackOrigin = tonumber(event.t) or 0
                    break
                end
            end
            -- Keep the match clock running while opening actions are being confirmed.
            playbackStarted = os.clock()
            state.pauseAccum = 0
            log("Макрос активен · синхронизация по событиям")

            local opening, explicitOpeningPhase = collectOpeningPlacements(macro.events)
            waveTiming.strictFirstWave = explicitOpeningPhase
            waveTiming.combatStarted = not explicitOpeningPhase
            observePlaybackClock(waveTiming, detectGameClock(), macro.clock)
            task.spawn(function()
                while token == state.playToken and state.playing and not state.destroyed do
                    observePlaybackClock(waveTiming, detectGameClock(), macro.clock)
                    task.wait(0.04)
                end
            end)
            local openingOrigin = opening[1] and (tonumber(opening[1].t) or 0) or 0
            local openingStarted = os.clock()
            local openingPauseOrigin = state.pauseAccum
            local confirmedOpening = 0
            for _, event in ipairs(opening) do
                local target = math.max(0, (tonumber(event.t) or 0) - openingOrigin) / speed
                while token == state.playToken and state.playing and not state.destroyed do
                    local elapsed = os.clock() - openingStarted - (state.pauseAccum - openingPauseOrigin)
                    if not state.paused and elapsed >= target then break end
                    task.wait(0.04)
                end
                if token ~= state.playToken or not state.playing or state.destroyed then return end
                if not waitForRecordedCash(event, token, true) then
                    if token == state.playToken then stopCurrentMacro("Старт прерван: cash не подтверждён") end
                    return
                end
                while state.paused and token == state.playToken do task.wait(0.05) end
                if token ~= state.playToken or not state.playing or state.destroyed then return end
                if not replayRemoteEvent(event, token) then
                    if token == state.playToken then stopCurrentMacro("Старт прерван: действие не подтверждено") end
                    return
                end
                openingSent[event] = true
                confirmedOpening += 1
                lastSent = os.clock()
            end
            if confirmedOpening > 0 then log("Стартовые действия подтверждены · " .. tostring(confirmedOpening)) end
        end

        for _, event in ipairs(macro.events) do
            if token ~= state.playToken or state.destroyed then break end
            if openingSent[event] then continue end
            if event.kind == "remote" then
                if not waitForRecordedMoment(event, macro.clock, waveTiming, token, playbackStarted) then break end
                if not waitForRecordedCash(event, token) then break end
            elseif hasRemoteEvents then
                -- Server macros can contain legacy input events from older
                -- recordings. The Remote already performs the action; replaying
                -- synthetic mobile touches can break Roblox's movement thumbstick.
                continue
            else
                while state.paused and token == state.playToken do task.wait(0.05) end
                while token == state.playToken do
                    local elapsed = (os.clock() - playbackStarted - state.pauseAccum) * speed
                    local remaining = (tonumber(event.t) or 0) - elapsed
                    if remaining <= 0 then break end
                    task.wait(math.min(0.03, remaining / speed))
                end
            end
            if token ~= state.playToken then break end

            local elapsed = (os.clock() - playbackStarted - state.pauseAccum) * speed
            local late = elapsed - (tonumber(event.t) or 0)
            if event.kind == "remote" then
                replayRemoteEvent(event)
                lastSent = os.clock()
            elseif late > tolerance and event.kind == "mouse_wheel" then
                -- Wheel bursts are disposable; clicks and releases are never dropped.
            else
                if late > tolerance then
                    local spacing = 0.025 - (os.clock() - lastSent)
                    if spacing > 0 then task.wait(spacing) end
                end
                sendEvent(event, macro.viewport)
                lastSent = os.clock()
            end
        end

        if token == state.playToken then
            state.playing = false
            state.paused = false
            state.playbackSource = nil
            state.playbackUsesRemote = false
            releaseAll()
            releaseCameraControl()
            state.playbackFinishedAt = os.clock()
            log("Воспроизведение завершено")
            if state.config.settings.auto then
                transition("WAIT_END", "жду конец матча")
            else
                transition("IDLE")
            end
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

activateRecordingTimeline = function(clock, anchorAt, initialClock, combatStarted)
    if not state.recording or state.recordingLive then return end
    state.recordingLive = true
    state.recordingCombatStarted = combatStarted == true
    state.recordingPreCombatDirection = nil
    state.recordingStarted = tonumber(anchorAt) or os.clock()
    state.recordingClock = clock
    state.recordingClockInitial = initialClock or clock
    state.recordingClockChanges = 0
    state.recordingClockFirstChangeAt = nil
    state.recordingClockFirstValue = nil
    state.recordingWave = clock and clock.wave or nil
    state.recordingWaveStartClock = clock and clock.time or nil
    state.recordingWaveStartedAt = state.recordingStarted
    transition("RECORDING", state.recordingCombatStarted and "игровой таймер запущен" or "записываю стартовые действия")
    log(state.recordingCombatStarted and "Запись серверных действий началась"
        or "Стартовые действия записываются до первой волны")
    refreshAll()
end

local function anchorCombatTimeline(clock, anchorClock)
    if not state.recording or not state.recordingLive or state.recordingCombatStarted then return end
    local now = os.clock()
    state.recordingCombatStarted = true
    state.recordingPreCombatDirection = nil
    state.recordingStarted = now
    state.recordingClock = clock
    state.recordingClockInitial = clock or state.recordingClockInitial
    state.recordingWave = clock and clock.wave or state.recordingWave
    state.recordingWaveStartClock = anchorClock ~= nil and anchorClock
        or (clock and clock.time) or state.recordingWaveStartClock
    state.recordingWaveStartedAt = now
    transition("RECORDING", "первая волна синхронизирована")
    log("Первая волна: новый ноль синхронизации")
end

local clockAccumulator = 0
keep(RunService.Heartbeat:Connect(function(delta)
    if state.destroyed or not state.recording or not state.config or not state.config.settings.remoteMode then
        clockAccumulator = 0
        return
    end
    clockAccumulator += delta
    if clockAccumulator < 0.2 then return end
    clockAccumulator = 0
    -- Recording must not rescan PlayerGui every 0.2 s. The sources were
    -- discovered once before recording; from here we read only those objects.
    local current = readGameClockFast()
    if not current then return end
    local previous = state.recordingClock
    state.recordingClock = current
    if not state.recordingLive then
        local timerChanged = previous and current.time ~= nil and previous.time ~= nil and current.time ~= previous.time
        if current.wave ~= nil then
            if current.wave >= 1 and timerChanged then
                state.recordingClockDirection = current.time > previous.time and "up" or "down"
                activateRecordingTimeline(current, nil, nil, true)
            elseif current.wave >= 1 and current.time == nil and previous and previous.wave and previous.wave < 1 then
                activateRecordingTimeline(current, nil, nil, true)
            end
            return
        end
        if timerChanged and previous.wave == nil then
            state.recordingClockDirection = current.time > previous.time and "up" or "down"
            state.recordingClockChanges += 1
            if not state.recordingClockFirstChangeAt then
                state.recordingClockFirstChangeAt = os.clock()
                state.recordingClockFirstValue = current
            end
            if state.recordingClockChanges >= 2 then
                activateRecordingTimeline(current, state.recordingClockFirstChangeAt, state.recordingClockFirstValue, true)
            end
        end
        return
    end

    if not state.recordingCombatStarted then
        local startCombat = false
        local anchorClock = current.time

        if current.wave ~= nil and current.wave > 1 then
            startCombat = true
        elseif previous and previous.wave ~= nil and previous.wave < 1
            and current.wave ~= nil and current.wave >= 1 then
            startCombat = true
        elseif previous and current.wave == 1 and previous.wave == 1
            and current.time ~= nil and previous.time ~= nil and current.time ~= previous.time then
            local nextDirection = current.time > previous.time and "up" or "down"
            local clockJump = math.abs(current.time - previous.time)
            local directionFlip = state.recordingPreCombatDirection ~= nil
                and nextDirection ~= state.recordingPreCombatDirection
            local boundaryStart = state.recordingPreCombatDirection == nil and (
                (nextDirection == "up" and previous.time <= 1.5)
                or (nextDirection == "down" and previous.time >= 15)
            )

            if clockJump > 3 or directionFlip or boundaryStart then
                startCombat = true
                if boundaryStart and clockJump <= 3 then anchorClock = previous.time end
                state.recordingClockDirection = nextDirection
            end
            state.recordingPreCombatDirection = nextDirection
        end

        if startCombat then anchorCombatTimeline(current, anchorClock) end
    end

    if previous and current.time and previous.time and current.time ~= previous.time
        and (not current.wave or not previous.wave or current.wave == previous.wave) then
        local nextDirection = current.time > previous.time and "up" or "down"
        local timerReset = math.abs(current.time - previous.time) > 3
        if #state.recordedEvents == 0 and current.wave == 1
            and (nextDirection ~= state.recordingClockDirection or timerReset) then
            -- Preserve the old zero-correction when nothing has been recorded yet.
            local now = os.clock()
            state.recordingStarted = now
            state.recordingClockInitial = current
            state.recordingWave = current.wave
            state.recordingWaveStartClock = current.time
            state.recordingWaveStartedAt = now
        end
        state.recordingClockDirection = nextDirection
    end
    if current.wave ~= nil and current.wave ~= state.recordingWave then
        state.recordingWave = current.wave
        state.recordingWaveStartClock = current.time
        state.recordingWaveStartedAt = os.clock()
    end
end))

local function startRecording()
    if state.playing then stopPlayback("Воспроизведение остановлено перед записью") end
    if state.recording then return end
    -- Recording temporarily pauses the controller without changing AUTOSTART.
    state.autoRunToken += 1
    state.controlRunId += 1
    state.replayCheck = nil
    transition(state.config.settings.remoteMode and "WAIT_WAVE" or "IDLE")
    state.recordedEvents = {}
    state.recordingViewport = viewport()
    local currentRoot = rootPart()
    state.recordingFingerprint = fingerprint(currentRoot and currentRoot.Position or nil)
    state.recordingCamera = cameraSnapshot()
    state.recordingStarted = os.clock()
    state.recordedCameraTrack = {}
    state.recordedPlacements = {}
    state.recordedUnitInstances = {}
    state.pendingPlacements = {}
    state.recordingLive = not state.config.settings.remoteMode
    state.recordingCombatStarted = not state.config.settings.remoteMode
    state.recordingPreCombatDirection = nil
    -- One discovery before recording becomes active, then recording itself
    -- performs only O(1) reads from the discovered timer/wave objects.
    state.recordingClock = detectGameClock()
    state.config.autoContext = {key = Core.mapBindingKey(state.recordingFingerprint), jobId = game.JobId,
        wave = state.recordingClock and tonumber(state.recordingClock.wave), consumed = true, sawResults = false}
    saveDisk()
    state.recordingClockInitial = state.recordingClock
    state.recordingClockChanges = 0
    state.recordingClockFirstChangeAt = nil
    state.recordingClockFirstValue = nil
    state.recordingWave = nil
    state.recordingWaveStartClock = nil
    state.recordingWaveStartedAt = nil
    state.recordingClockDirection = "up"
    state.currentSlot = nil
    state.pendingPlacementSlot = nil
    state.nextUnitId = 0
    state.touchInputIds = {}
    state.touchGestures = {}
    state.nextTouchId = 0
    if state.config.settings.remoteMode and readCashSourceFast(state.cashSource) == nil then
        -- One discovery before recording becomes active. During recording the
        -- source is read directly; __namecall never performs discovery work.
        pcall(detectMatchCash, true)
    end
    if state.remoteBus then state.remoteBus.cashSnapshot = readCashSourceFast(state.cashSource) or state.cashCache end
    state.recording = true
    if state.config.settings.remoteMode then
        if not state.remoteHookReady then
            state.recording = false
            transition("ERROR", state.remoteHookError or "Remote hook недоступен")
            refreshAll()
            return
        end
        log("Запись вооружена · жду ход таймера первой волны")
    else
        recordCameraFrame(true)
        log("Input-запись начата · " .. state.recordingFingerprint.mapKey .. " · " .. state.recordingFingerprint.spawnKey)
    end
    refreshAll()
    -- Free the whole game screen while recording; the small TD button restores this window.
    if state.recording and state.window and state.showButton then
        state.window.Visible = false
        local shadow = state.window.Parent and state.window.Parent:FindFirstChild("Shadow")
        if shadow then shadow.Visible = false end
        state.showButton.Visible = true
    end
end

local function stopAndSave(name)
    if not state.recording then log("Запись не запущена") return nil end
    if not state.config.settings.remoteMode then recordCameraFrame(true) end
    state.recording = false
    state.recordingLive = false
    transition(state.config.settings.auto and "WAIT_END" or "IDLE", "запись завершена")
    local events = Core.normalizeEvents(state.recordedEvents, state.recordingViewport)
    if #events == 0 then log("Пустая запись не сохранена", true) refreshAll() return nil end
    local macro = Core.normalizeMacro({
        version = VERSION,
        recordMode = state.config.settings.remoteMode and "remote" or "input",
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
        cameraTrack = state.recordedCameraTrack,
        clock = {
            direction = state.recordingClockDirection,
            startWave = state.recordingClockInitial and state.recordingClockInitial.wave or nil,
            startTime = state.recordingClockInitial and state.recordingClockInitial.time or nil,
            timerPath = state.recordingClockInitial and state.recordingClockInitial.timerPath or nil,
        },
        slots = copyTable(state.config.slotLabels),
        events = events,
        savedAt = os.time(),
    })
    state.config.macros[#state.config.macros + 1] = macro
    state.selectedId = macro.id

    -- Every freshly recorded macro belongs to the map/spawn it was recorded on.
    -- Save both the exact binding and a map fallback immediately, so AUTO works
    -- on the second/third map without requiring a separate "bind" click.
    local exactBindingKey = tostring(macro.fingerprintKey or Core.fingerprintKey(macro.fingerprint))
    local mapBindingKey = Core.mapBindingKey(macro.fingerprint)
    state.config.manualMatches[exactBindingKey] = macro.id
    state.config.mapMatches[mapBindingKey] = macro.id

    saveDisk()
    log("Сохранено и привязано: " .. macro.name .. " · " .. #events .. " событий")
    refreshAll()
    return macro
end

local function buttonText(button)
    return guiObjectText(button, true)
end

local function bindingGeometryScore(kind, object)
    if not object or not object:IsA("GuiObject") then return -100 end
    local size = object.AbsoluteSize
    if size.X < 4 or size.Y < 4 then return -100 end
    local screen = viewport()
    local centreY = object.AbsolutePosition.Y + size.Y / 2
    local score = 0
    if size.X >= 20 and size.Y >= 16 then score += 5 end
    if size.X > screen.w * 0.72 or size.Y > screen.h * 0.45 then score -= 28 end
    if kind == "x2" or kind == "autoSkip" then
        -- Both match controls live in the HUD, not in the unit bar at the
        -- bottom. This is only a tie-breaker; semantic text remains primary.
        if centreY <= screen.h * 0.45 then score += 5 end
        if centreY >= screen.h * 0.78 then score -= 8 end
    elseif kind == "playAgain" then
        if size.X >= 90 then score += 5 end
        if centreY >= screen.h * 0.2 and centreY <= screen.h * 0.85 then score += 3 end
    end
    return score
end

local function scanBindingCandidates(force)
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return {} end
    if not force and os.clock() - state.bindingScanAt < 0.65 then
        local valid = true
        for _, result in pairs(state.bindingScan) do
            if result.object and (not result.object:IsDescendantOf(game) or not instanceVisible(result.object)) then
                valid = false
                break
            end
        end
        if valid then return state.bindingScan end
    end
    local results = {
        x2 = {object = nil, score = 0, source = nil},
        autoSkip = {object = nil, score = 0, source = nil},
        playAgain = {object = nil, score = 0, source = nil},
    }
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("GuiObject") and instanceVisible(object)
            and not (state.gui and object:IsDescendantOf(state.gui)) then
            local isText = object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")
            local isUseful = isText or object:IsA("GuiButton")
                or Core.bindingScore("x2", "", object.Name) > 0
                or Core.bindingScore("autoSkip", "", object.Name) > 0
                or Core.bindingScore("playAgain", "", object.Name) > 0
            if isUseful then
                local semantic = guiSemanticText(object)
                for kind, result in pairs(results) do
                    local score = Core.bindingScore(kind, semantic, object.Name)
                    if score > 0 then
                        local target = clickableGuiFor(object, kind)
                        score += bindingGeometryScore(kind, target or object)
                        if target and target:IsA("GuiButton") then score += 8 end
                        if target and target.Active then score += 3 end
                        local parentText = Core.cleanText(object.Parent and object.Parent.Name or "")
                        if parentText:find("game", 1, true) or parentText:find("match", 1, true)
                            or parentText:find("wave", 1, true) or parentText:find("hud", 1, true) then
                            score += 4
                        end
                        if score > result.score then
                            result.object, result.score, result.source = target or object, score, object
                        end
                    end
                end
            end
        end
    end
    state.bindingScanAt = os.clock()
    state.bindingScan = results
    return results
end

local function findBindingCandidate(kind, force)
    local result = scanBindingCandidates(force)[kind]
    return result and result.object or nil, result and result.score or 0, result and result.source or nil
end

local function findManualBindingCandidate(kind, binding)
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil, 0 end
    local wantedName = Core.cleanText(binding and binding.objectName or "")
    local wantedText = Core.cleanText(binding and binding.objectText or "")
    local best, bestScore = nil, 0
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("GuiObject") and instanceVisible(object) and not (state.gui and object:IsDescendantOf(state.gui)) then
            local text = guiSemanticText(object)
            local target = clickableGuiFor(object, kind)
            local score = Core.bindingScore(kind, text, object.Name) + bindingGeometryScore(kind, target or object)
            local objectName = Core.cleanText((target and target.Name) or object.Name)
            local objectText = Core.cleanText(guiObjectText(target or object, true))
            if wantedName ~= "" and objectName == wantedName then score += 55 end
            if wantedText ~= "" and objectText == wantedText then score += 45 end
            if score > bestScore then best, bestScore = target or object, score end
        end
    end
    return best, bestScore
end

local function bindingPoint(kind, forDetection)
    local binding = state.config.bindings[kind] or {mode = "auto"}
    -- Always prefer the live HUD. A saved manual point is only a fallback, so
    -- changing resolution or rebuilding the match GUI cannot pin us to stale
    -- coordinates from the previous server.
    local automatic, automaticScore = findBindingCandidate(kind)
    if automatic and automaticScore >= 64 then
        local position, size = automatic.AbsolutePosition, automatic.AbsoluteSize
        return position.X + size.X / 2, position.Y + size.Y / 2, automatic
    end
    if binding.mode == "manual" then
        local object = resolveGuiPath(binding.path)
        object = clickableGuiFor(object, kind)
        if object and object:IsA("GuiObject") and instanceVisible(object) then
            local position, size = object.AbsolutePosition, object.AbsoluteSize
            return position.X + size.X / 2, position.Y + size.Y / 2, object
        end
        -- Match UIs are usually destroyed and rebuilt between games. Recover a
        -- manual binding by its saved name/text instead of keeping a dead path.
        local recovered, score = findManualBindingCandidate(kind, binding)
        if recovered and score >= 64 then
            binding.path = guiPath(recovered)
            binding.objectName = recovered.Name
            binding.objectText = buttonText(recovered)
            local position, size = recovered.AbsolutePosition, recovered.AbsoluteSize
            return position.X + size.X / 2, position.Y + size.Y / 2, recovered
        end
        if forDetection then return nil end
        local size = viewport()
        if tonumber(binding.nx) and tonumber(binding.ny) then
            return binding.nx * size.w, binding.ny * size.h, nil
        end
        return nil
    end
    return nil
end

local function activateGuiButton(object)
    if not object or not object:IsA("GuiButton") then return false, nil end
    local inspectedConnections = false
    if type(getconnections) == "function" then
        for _, signal in ipairs({object.Activated, object.MouseButton1Click}) do
            local ok, connections = pcall(getconnections, signal)
            if ok and type(connections) == "table" and #connections > 0 then
                inspectedConnections = true
                local fired = false
                for _, connection in ipairs(connections) do
                    local enabled = true
                    pcall(function() enabled = connection.Enabled ~= false end)
                    if enabled then
                        local called = false
                        local fireOk = pcall(function()
                            if type(connection.Fire) == "function" then
                                connection:Fire()
                                called = true
                            elseif type(connection.Function) == "function" then
                                connection.Function()
                                called = true
                            end
                        end)
                        fired = fired or (fireOk and called)
                    end
                end
                if fired then return true, "сигнал" end
            elseif ok and type(connections) == "table" then
                inspectedConnections = true
            end
        end
    end
    if not inspectedConnections and type(firesignal) == "function" then
        local ok = pcall(function() firesignal(object.Activated) end)
        if ok then return true, "сигнал" end
    end
    return false, nil
end

local function visibleControlTexts(object)
    local output = {}
    if not object then return output end
    local candidates = {object}
    for _, child in ipairs(object:GetDescendants()) do candidates[#candidates + 1] = child end
    for _, candidate in ipairs(candidates) do
        if (candidate:IsA("TextLabel") or candidate:IsA("TextButton")) and instanceVisible(candidate) then
            output[#output + 1] = tostring(candidate.Text or "")
        end
    end
    return output
end

local function parseSpeedValue(value)
    if type(value) == "number" then
        return value >= 0.25 and value <= 4 and value or nil
    end
    local text = string.lower(tostring(value or "")):gsub(",", "."):gsub("%s+", "")
    local amount = text:match("x(%d+%.?%d*)") or text:match("(%d+%.?%d*)x")
    amount = tonumber(amount)
    return amount and amount >= 0.25 and amount <= 4 and amount or nil
end

local function controlSpeed(object)
    if not object then return nil end
    for _, attribute in ipairs({"Speed", "GameSpeed", "CurrentSpeed", "Multiplier", "Value"}) do
        local amount = parseSpeedValue(object:GetAttribute(attribute))
        if amount then return amount end
    end
    local best = nil
    local texts = visibleControlTexts(object)
    texts[#texts + 1] = guiObjectText(object, true)
    for _, raw in ipairs(texts) do
        local amount = parseSpeedValue(raw)
        if amount and (not best or amount > best) then best = amount end
    end
    return best
end

local function controlState(kind, object)
    if not object then return nil end
    if kind == "x2" then
        local amount = controlSpeed(object)
        if amount then return amount >= 1.99 end
    end
    for _, attribute in ipairs({"Toggled", "Toggle", "IsOn", "On", "Selected", "Checked", "State", "Value"}) do
        local value = object:GetAttribute(attribute)
        if type(value) == "boolean" then return value end
        if type(value) == "string" then
            local clean = Core.cleanText(value)
            if clean == "on" or clean == "enabled" or clean == "true" or clean == "вкл" then return true end
            if clean == "off" or clean == "disabled" or clean == "false" or clean == "выкл" then return false end
        end
    end
    local texts = visibleControlTexts(object)
    if kind ~= "x2" then
        local clean = " " .. Core.cleanText(table.concat(texts, " ")) .. " "
        for _, word in ipairs({"off", "disabled", "false", "выкл", "отключено"}) do
            if clean:find(" " .. word .. " ", 1, true) then return false end
        end
        for _, word in ipairs({"on", "enabled", "true", "вкл", "включено"}) do
            if clean:find(" " .. word .. " ", 1, true) then return true end
        end
    end
    return nil
end

local function clickBinding(kind, quiet, physicalOnly, requireLive)
    local x, y, object = bindingPoint(kind, requireLive == true)
    if not x then
        if not quiet then log(kind .. ": кнопка не найдена") end
        return false
    end
    local direct = not physicalOnly and activateGuiButton(object)
    if direct then
        if not quiet then log(kind .. ": включено напрямую") end
        return true
    end

    -- During server-macro playback on mobile, never synthesize a touch
    -- as a fallback for HUD automation. Direct GuiButton activation above is
    -- safe; an ambiguous synthetic tap can interfere with the real thumbstick.
    if UIS.TouchEnabled and state.playing and state.playbackUsesRemote then
        if not quiet then log(kind .. ": mobile touch fallback пропущен") end
        return false
    end

    state.generatedInput = true
    local ok = true
    if UIS.TouchEnabled then
        state.syntheticTouchId += 1
        local touchId = state.syntheticTouchId
        local downOk = pcall(function() VIM:SendTouchEvent(touchId, 0, x, y) end)
        if downOk then
            state.pressedTouches[touchId] = {x = x, y = y}
            task.wait(0.045)
        end
        local upOk = pcall(function() VIM:SendTouchEvent(touchId, 2, x, y) end)
        state.pressedTouches[touchId] = nil
        ok = downOk and upOk
    else
        local downOk = pcall(function() VIM:SendMouseButtonEvent(x, y, 0, true, game, 0) end)
        if downOk then
            state.pressedButtons[0] = true
            task.wait(0.045)
        end
        local upOk = pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
        state.pressedButtons[0] = nil
        ok = downOk and upOk
    end
    state.generatedInput = false

    if not quiet then
        if ok then log(kind .. ": нажато") else log(kind .. ": ошибка нажатия", true) end
    end
    return ok
end

local function pressSpeedKey()
    state.generatedInput = true
    local downOk = pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.Z, false, game) end)
    if downOk then
        state.pressedKeys.Z = true
        task.wait(0.045)
    end
    local upOk = pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.Z, false, game) end)
    state.pressedKeys.Z = nil
    state.generatedInput = false
    return downOk and upOk
end

local function setMaximumGameSpeed(runId)
    local maxSeen, wrapped = 0, false
    for attempt = 1, 5 do
        if runId ~= state.controlRunId or state.destroyed
            or not (state.config.settings.auto or state.playing) then return end
        local _, _, object = bindingPoint("x2", true)
        local before = controlSpeed(object)
        if before then maxSeen = math.max(maxSeen, before) end
        if before and before >= 1.99 then
            log("скорость: x2 уже включена")
            return
        end
        if not pressSpeedKey() then
            log("скорость: клавиша Z не сработала", true)
            return
        end
        task.wait(0.18)
        local _, _, currentObject = bindingPoint("x2", true)
        local after = controlSpeed(currentObject or object)
        if after then
            local previousMax = maxSeen
            if after > previousMax + 0.01 then
                maxSeen = after
            elseif after < previousMax - 0.01 then
                wrapped = true
            elseif after >= 1.49 and (wrapped or (before and math.abs(after - before) <= 0.01)) then
                log(string.format("скорость: максимум x%.1f через Z", after))
                return
            end
            if after >= 1.99 then
                log("скорость: x2 включена через Z")
                return
            end
        elseif attempt >= 2 then
            log("скорость: Z отправлена дважды")
            return
        end
        task.wait(0.16)
    end
    if maxSeen >= 1.49 then
        log(string.format("скорость: максимум x%.1f", maxSeen))
    else
        log("скорость: значение не распознано", true)
    end
end

armMatchControls = function()
    state.controlRunId += 1
    local runId = state.controlRunId
    local pending = {}
    if state.config.settings.autoSkip then pending.autoSkip = {attempts = 0, maxAttempts = 3} end
    if not state.config.settings.x2 and not next(pending) then return end

    task.spawn(function()
        if state.config.settings.x2 then setMaximumGameSpeed(runId) end
        local deadline = os.clock() + 12
        while runId == state.controlRunId and (state.config.settings.auto or state.playing) and not state.destroyed
            and os.clock() < deadline and next(pending) do
            for kind, item in pairs(pending) do
                local _, _, object = bindingPoint(kind, false)
                if object then
                    local before = controlState(kind, object)
                    if before == true then
                        log(kind .. ": уже включено")
                        pending[kind] = nil
                    elseif item.attempts < item.maxAttempts then
                        item.attempts += 1
                        if clickBinding(kind, true) then
                            task.wait(0.16)
                            local _, _, currentObject = bindingPoint(kind, false)
                            local after = controlState(kind, currentObject or object)
                            if after == true or after == nil then
                                log(kind .. ": включено")
                                pending[kind] = nil
                            elseif item.attempts >= item.maxAttempts then
                                log(kind .. ": кнопка отвечает, состояние не включилось", true)
                                pending[kind] = nil
                            end
                        end
                    end
                end
            end
            if next(pending) then task.wait(0.35) end
        end
        if runId == state.controlRunId then
            for kind in pairs(pending) do log(kind .. ": кнопка не появилась", true) end
        end
    end)
end

local endWords = {
    "victory", "defeat", "defeated", "completed", "you win", "you lost", "you lose", "game over", "победа", "поражение",
    "завершено", "матч окончен", "играть снова", "сыграть снова",
}

local function endDetected(visibleOnly)
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
    if not visibleOnly and state.playbackFinishedAt > 0 and os.clock() - state.playbackFinishedAt >= timeout then
        return true, "таймаут"
    end
    return false
end

isMatchOver = function(force)
    if not force and state.matchOverCacheAt and os.clock() - state.matchOverCacheAt < 0.15 then
        return state.matchOverCache == true
    end
    state.matchOverCache = endDetected(true) == true
    state.matchOverCacheAt = os.clock()
    return state.matchOverCache
end

local function waitForReplayTransition(autoRunToken)
    local deadline = os.clock() + 30
    local nextAttempt = os.clock() + 0.8
    local attempts = 0
    local initialClock = detectGameClock()
    local tracking = state.replayCheck
    if not tracking or tracking.token ~= autoRunToken then
        tracking = {token = autoRunToken, sawResults = endDetected(true) == true,
            initialWave = initialClock and tonumber(initialClock.wave)}
        state.replayCheck = tracking
    end
    local sawResults = tracking.sawResults
    local initialWave = tracking.initialWave
    local hiddenSince, hiddenClock = nil, nil
    while os.clock() < deadline do
        if autoRunToken ~= state.autoRunToken or not state.config.settings.auto
            or state.destroyed or state.recording or state.playing
            or state.controllerState ~= "REPLAY" then return nil end
        local resultsVisible = endDetected(true) == true
        local clock = detectGameClock()
        local wave = clock and tonumber(clock.wave)
        if resultsVisible then
            sawResults = true
            tracking.sawResults = true
            hiddenSince, hiddenClock = nil, nil
        elseif sawResults or (initialWave and initialWave > 1 and wave and wave <= 1) then
            if not hiddenSince then
                hiddenSince = os.clock()
                hiddenClock = clock and clock.time
            end
            local newWave = wave ~= nil and wave <= 1
            local movingClock = wave == nil and clock and clock.time ~= nil
                and hiddenClock ~= nil and clock.time ~= hiddenClock
            if (newWave or movingClock) and rootPart() and workspace.CurrentCamera
                and os.clock() - hiddenSince >= 1 then
                log("Играть снова: новая катка подтверждена")
                state.replayCheck = nil
                return true
            end
        end
        if state.config.settings.autoPlayAgain and state.config.settings.autoLoop ~= false and os.clock() >= nextAttempt then
            -- Reacquire rebuilt/late result controls. Never tap old saved coordinates.
            state.bindingScanAt = 0
            local x, _, object = bindingPoint("playAgain", true)
            local enabled = x ~= nil
            if object then
                pcall(function() if object.Interactable == false then enabled = false end end)
            end
            if enabled and not hiddenSince then
                attempts += 1
                -- A signal can run without changing the game. Try actual input next.
                local sent = clickBinding("playAgain", true, attempts % 2 == 0, true)
                if sent then log("Играть снова: попытка " .. tostring(attempts) .. " · жду переход") end
            end
            nextAttempt = os.clock() + 2
        end
        task.wait(0.2)
    end
    log("Играть снова: переход не подтверждён · продолжу проверять")
    return false
end

local function prepareAutoRun(immediate, preparedFingerprint, autoRunToken)
    if autoRunToken ~= state.autoRunToken or not state.config.settings.auto
        or state.destroyed or state.recording or state.playing then return end
    state.mapCacheAt = 0
    local current = fingerprint(state.matchSpawnPosition)
    if preparedFingerprint and Core.mapBindingKey(preparedFingerprint) ~= Core.mapBindingKey(current) then
        resetMatchTracking(0)
        transition("WAIT_MATCH", "карта изменилась · проверяю новую привязку")
        return
    end
    local macro = Core.chooseMacro(state.config.macros, current, state.config.manualMatches, state.config.mapMatches)
    if not macro then
        resetMatchTracking(1)
        transition("WAIT_MATCH", "Для этой карты нет действующей привязки")
        return
    end
    state.lastFingerprint = current
    log("Авто: " .. macro.name .. " · карта " .. current.mapKey)
    if not immediate then task.wait(math.max(0, tonumber(state.config.settings.initialDelay) or 1.2)) end
    if autoRunToken ~= state.autoRunToken or not state.config.settings.auto
        or state.destroyed or state.recording or state.playing then return end
    if isMatchOver() then
        transition("WAIT_END", "матч завершён до запуска")
        return
    end
    if not playMacro(macro, false, true, current) then
        resetMatchTracking(1)
        transition("WAIT_MATCH", "проверяю карту и привязку повторно")
    end
    refreshAll()
end

local controllerAccumulator = 0
keep(RunService.Heartbeat:Connect(function(delta)
    if state.destroyed then return end
    controllerAccumulator += delta
    local controllerInterval = state.controllerState == "WAIT_MATCH" and 0.15 or 0.5
    if controllerAccumulator < controllerInterval then return end
    controllerAccumulator = 0
    if not state.config or state.recording then return end
    -- A defeat can arrive while playback is waiting for money or a later wave.
    local resultsVisible, resultReason = endDetected(true)
    state.matchOverCache, state.matchOverCacheAt = resultsVisible, os.clock()
    if resultsVisible then
        if state.config.autoContext then state.config.autoContext.sawResults = true end
        if state.playing then
            stopPlayback("Матч завершён · оставшиеся действия отменены", false)
            state.controlRunId += 1
            state.playbackFinishedAt = os.clock()
        end
        if state.config.settings.auto and state.controllerState ~= "REPLAY" then
            transition("WAIT_END", resultReason)
        end
    end
    if not state.config.settings.auto then return end

    local current = fingerprint(state.matchSpawnPosition)
    local mapKey = Core.mapBindingKey(current)
    if state.autoCandidateKey ~= mapKey then
        state.autoCandidateKey = mapKey
        state.autoCandidateSince = os.clock()
    end
    local mapStable = os.clock() - (state.autoCandidateSince or 0) >= 0.5
    local liveClock = detectGameClock()
    local liveWave = liveClock and tonumber(liveClock.wave) or nil
    if mapStable then
        local previous = state.config.autoContext
        local context, fresh = Core.observeAutoContext(previous, mapKey, game.JobId, liveWave, resultsVisible)
        state.config.autoContext = context
        if fresh and not resultsVisible then
            if state.playing and previous then
                stopPlayback("Началась новая карта/катка · старый макрос остановлен", false)
            end
            if not state.playing then
                resetMatchTracking(0)
                transition("WAIT_MATCH", "новая карта/катка · проверяю привязку")
            end
        end
    end
    if state.playing then
        if state.controllerState ~= "PLAYING" then transition("PLAYING", "текущий макрос уже идёт") end
        return
    end
    if os.clock() < state.controllerNotBefore then return end

    if state.controllerState == "IDLE" then
        transition("WAIT_MATCH")
    elseif state.controllerState == "WAIT_MATCH" then
        if not mapStable or not workspace.CurrentCamera or not rootPart() then return end
        local context = state.config.autoContext
        if context and context.consumed then
            transition("WAIT_END", "этот матч уже запускался · жду следующую катку")
            return
        end
        if liveWave and liveWave > 1 then
            if context then context.consumed = true end
            transition("WAIT_END", "матч уже идёт · автозапуск со следующей катки")
            return
        end
        local macro = Core.chooseMacro(state.config.macros, current, state.config.manualMatches, state.config.mapMatches)
        if not macro then
            if state.unboundMapLogged ~= mapKey then
                state.unboundMapLogged = mapKey
                log("Автозапуск: для этой карты нет привязанного макроса · " .. current.mapKey)
            end
            return
        end
        state.unboundMapLogged = nil
        state.matchSpawnPosition = rootPart().Position
        transition("PREPARE", "найден привязанный макрос · " .. macro.name)
        local autoRunToken = state.autoRunToken
        task.spawn(function() prepareAutoRun(true, current, autoRunToken) end)
    elseif state.controllerState == "WAIT_END" then
        local ended, reason = endDetected()
        if state.replayCheck and state.replayCheck.token == state.autoRunToken then
            ended, reason = true, "повторная проверка перехода"
        end
        if ended then
            transition("REPLAY", reason)
            local autoRunToken = state.autoRunToken
            task.spawn(function()
                local ok, confirmed = pcall(waitForReplayTransition, autoRunToken)
                if not ok then
                    log("Играть снова: ошибка проверки · " .. tostring(confirmed), true)
                    confirmed = false
                end
                if confirmed == nil or autoRunToken ~= state.autoRunToken
                    or not state.config.settings.auto or state.playing or state.recording or state.destroyed then return end
                if not confirmed then
                    state.controllerNotBefore = os.clock() + 3
                    transition("WAIT_END", "жду кнопку или подтверждение новой катки")
                    refreshAll()
                    return
                end
                if state.config.autoContext then
                    state.config.autoContext.consumed = false
                    state.config.autoContext.sawResults = false
                    state.config.autoContext.wave = nil
                end
                resetMatchTracking(0)
                transition("WAIT_MATCH", "новая катка · проверяю привязку")
                saveDisk()
                refreshAll()
            end)
        end
    end
end))

loadConfig()
installRemoteHook()
if #state.config.macros > 0 then state.selectedId = state.config.macros[1].id end

local palette = {
    bg = Color3.fromRGB(25, 34, 49),
    panel = Color3.fromRGB(34, 47, 65),
    panel2 = Color3.fromRGB(43, 58, 78),
    panelHover = Color3.fromRGB(53, 70, 92),
    accent = Color3.fromRGB(71, 219, 194),
    accentDark = Color3.fromRGB(29, 108, 103),
    accent2 = Color3.fromRGB(105, 169, 255),
    danger = Color3.fromRGB(239, 94, 111),
    text = Color3.fromRGB(244, 248, 253),
    muted = Color3.fromRGB(166, 181, 201),
    line = Color3.fromRGB(77, 98, 124),
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
    local baseColor = color or palette.panel2
    object.BackgroundColor3 = baseColor
    object:SetAttribute("TDMacroBaseColor", baseColor)
    object.Position = position
    object.Size = size
    object.Font = Enum.Font.GothamSemibold
    object.Text = text
    object.TextSize = 11
    object.TextScaled = false
    object.TextColor3 = palette.text
    object.TextTruncate = Enum.TextTruncate.AtEnd
    object.Parent = parent
    round(object, 10)
    local outline = stroke(object, palette.line, 0.25)
    keep(object.MouseEnter:Connect(function()
        local current = object:GetAttribute("TDMacroBaseColor") or baseColor
        TweenService:Create(object, TweenInfo.new(0.1), {BackgroundColor3 = current:Lerp(Color3.new(1, 1, 1), 0.08)}):Play()
    end))
    keep(object.MouseLeave:Connect(function()
        TweenService:Create(object, TweenInfo.new(0.1), {BackgroundColor3 = object:GetAttribute("TDMacroBaseColor") or baseColor}):Play()
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
    round(object, 10)
    stroke(object, palette.line, 0.18)
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
    local titleLabel = label(object, title, UDim2.fromOffset(12, 0), UDim2.new(1, -68, 1, 0), 11)
    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -10, 0.5, 0)
    track.Size = UDim2.fromOffset(42, 22)
    track.Parent = object
    round(track, 11)
    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Size = UDim2.fromOffset(16, 16)
    knob.Parent = track
    round(knob, 8)
    object.Text = ""
    local function update()
        local enabled = getter()
        local base = enabled and Color3.fromRGB(36, 68, 72) or palette.panel2
        object:SetAttribute("TDMacroBaseColor", base)
        object.BackgroundColor3 = base
        track.BackgroundColor3 = enabled and palette.accentDark or Color3.fromRGB(62, 77, 97)
        knob.BackgroundColor3 = enabled and palette.accent or palette.muted
        knob.Position = enabled and UDim2.new(1, -19, 0.5, 0) or UDim2.fromOffset(3, 11)
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
shadow.BackgroundTransparency = 0.62
shadow.Position = UDim2.new(0.5, -270, 0.5, -179)
shadow.Size = UDim2.fromOffset(548, 366)
shadow.ZIndex = 0
shadow.Parent = gui
round(shadow, 22)

local window = Instance.new("Frame")
window.Name = "Window"
window.BackgroundColor3 = palette.bg
window.BackgroundTransparency = 0.04
window.Position = UDim2.new(0.5, -274, 0.5, -183)
window.Size = UDim2.fromOffset(548, 366)
window.ClipsDescendants = true
window.Parent = gui
round(window, 20)
stroke(window, Color3.fromRGB(99, 126, 157), 0.08)
state.window = window

local header = Instance.new("Frame")
header.BackgroundColor3 = palette.panel
header.Size = UDim2.new(1, 0, 0, 50)
header.Parent = window
local headerGradient = Instance.new("UIGradient")
headerGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 71, 91)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 48, 68)),
})
headerGradient.Rotation = 12
headerGradient.Parent = header

local title = label(header, "ALLIANCE MACRO", UDim2.fromOffset(16, 5), UDim2.new(1, -190, 0, 24), 15)
title.Font = Enum.Font.GothamBold
local subtitle = label(header, "ЗАПИСЬ И АВТОЗАПУСК ПО КАРТЕ", UDim2.fromOffset(16, 27), UDim2.new(1, -190, 0, 16), 9, palette.muted)
subtitle.Font = Enum.Font.GothamMedium
local versionLabel = label(header, "v" .. SCRIPT_VERSION, UDim2.new(1, -176, 0, 5), UDim2.fromOffset(124, 38), 11, palette.accent, Enum.TextXAlignment.Right)
versionLabel.Font = Enum.Font.GothamSemibold
local hideButton = button(header, "—", UDim2.new(1, -40, 0, 9), UDim2.fromOffset(30, 30), function()
    window.Visible = false
    shadow.Visible = false
    state.showButton.Visible = true
end)
hideButton.TextSize = 18
hideButton.TextScaled = false

local nav = Instance.new("Frame")
nav.BackgroundColor3 = palette.panel
nav.BackgroundTransparency = 0.12
nav.Position = UDim2.fromOffset(10, 58)
nav.Size = UDim2.new(0, 108, 1, -68)
nav.Parent = window
round(nav, 14)
stroke(nav, palette.line, 0.3)
local navTitle = label(nav, "РАЗДЕЛЫ", UDim2.fromOffset(11, 4), UDim2.new(1, -22, 0, 25), 9, palette.muted)
navTitle.Font = Enum.Font.GothamSemibold

local content = Instance.new("Frame")
content.BackgroundColor3 = palette.panel
content.BackgroundTransparency = 0.28
content.Position = UDim2.fromOffset(128, 58)
content.Size = UDim2.new(1, -138, 1, -68)
content.ClipsDescendants = true
content.Parent = window
round(content, 14)
stroke(content, palette.line, 0.34)

local function createPage(name)
    local page = Instance.new("Frame")
    page.Name = name
    page.BackgroundTransparency = 1
    page.Position = UDim2.fromOffset(10, 10)
    page.Size = UDim2.new(1, -20, 1, -20)
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
        local active = pageName == name
        local base = active and Color3.fromRGB(42, 81, 84) or palette.panel
        item:SetAttribute("TDMacroBaseColor", base)
        item.BackgroundColor3 = base
        item.TextColor3 = active and palette.accent or palette.muted
    end
    if name == "MACROS" then refreshMacros() end
    if name == "BINDINGS" then refreshBindings() end
end

local navItems = {
    {page = "RECORD", text = "ЗАПИСЬ"},
    {page = "MACROS", text = "МАКРОСЫ"},
    {page = "AUTO", text = "АВТО"},
    {page = "BINDINGS", text = "КНОПКИ"},
    {page = "LOG", text = "ЖУРНАЛ"},
}
for index, navItem in ipairs(navItems) do
    local name = navItem.page
    local item = button(nav, navItem.text, UDim2.fromOffset(7, 32 + (index - 1) * 48), UDim2.new(1, -14, 0, 41), function() showPage(name) end, palette.panel)
    item.TextSize = 10
    item.TextXAlignment = Enum.TextXAlignment.Left
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 11)
    padding.Parent = item
    navButtons[name] = item
end

local recordPage = createPage("RECORD")
local macrosPage = createPage("MACROS")
local autoPage = createPage("AUTO")
local bindingsPage = createPage("BINDINGS")
local logPage = createPage("LOG")

local statusCard = Instance.new("Frame")
statusCard.BackgroundColor3 = palette.panel
statusCard.Size = UDim2.new(1, 0, 0, 57)
statusCard.Parent = recordPage
round(statusCard, 10)
stroke(statusCard, palette.line, 0.2)
local statusRail = Instance.new("Frame")
statusRail.BackgroundColor3 = palette.accent
statusRail.BorderSizePixel = 0
statusRail.Position = UDim2.fromOffset(0, 9)
statusRail.Size = UDim2.fromOffset(3, 39)
statusRail.Parent = statusCard
round(statusRail, 2)

label(statusCard, "СОСТОЯНИЕ", UDim2.fromOffset(12, 5), UDim2.fromOffset(95, 20), 10, palette.muted)
state.labels.controller = label(statusCard, state.controllerState, UDim2.fromOffset(12, 22), UDim2.fromOffset(125, 30), 16, palette.accent)
state.labels.controller.Font = Enum.Font.GothamBold
state.labels.fingerprint = label(statusCard, "", UDim2.fromOffset(145, 6), UDim2.new(1, -157, 0, 24), 11, palette.text, Enum.TextXAlignment.Right)
state.labels.storage = label(statusCard, "", UDim2.fromOffset(145, 30), UDim2.new(1, -157, 0, 22), 10, palette.muted, Enum.TextXAlignment.Right)

state.labels.nameBox = textBox(recordPage, "Macro " .. (#state.config.macros + 1), "Название макроса", UDim2.fromOffset(0, 65), UDim2.new(1, -145, 0, 34))
state.labels.recordCount = label(recordPage, "0 событий", UDim2.new(1, -137, 0, 65), UDim2.fromOffset(137, 34), 11, palette.muted, Enum.TextXAlignment.Right)

state.labels.recordButton = button(recordPage, "НАЧАТЬ ЗАПИСЬ", UDim2.fromOffset(0, 107), UDim2.new(1, 0, 0, 35), startRecording, palette.accentDark)
state.labels.saveButton = button(recordPage, "ОСТАНОВИТЬ И СОХРАНИТЬ", UDim2.fromOffset(0, 147), UDim2.new(1, 0, 0, 35), function()
    stopAndSave(state.labels.nameBox.Text)
end, Color3.fromRGB(54, 91, 137))

state.labels.playSelectedButton = button(recordPage, "ЗАПУСТИТЬ ВЫБРАННЫЙ МАКРОС", UDim2.fromOffset(0, 187), UDim2.new(1, 0, 0, 35), function()
    -- Manual launch is intentionally allowed after the player has walked away from the recorded spawn.
    playMacro(selectedMacro(), true, false)
end, palette.accentDark)
state.labels.recordHint = label(recordPage,
    "1. Начни запись до первой волны.  2. Ставь и улучшай юнитов.  3. Останови и сохрани. Камера и ходьба не записываются.",
    UDim2.fromOffset(2, 231), UDim2.new(1, -4, 0, 42), 10, palette.muted)
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
local renameButton = button(macrosPage, "ПЕРЕИМЕНОВАТЬ", UDim2.new(0.42, 4, 1, -84), UDim2.new(0.19, -4, 0, 35), function()
    local macro = selectedMacro()
    if macro and state.labels.renameBox.Text ~= "" then
        macro.name = state.labels.renameBox.Text
        saveDisk()
        refreshMacros()
    end
end)
renameButton.TextSize = 10
button(macrosPage, "ОСНОВНЫМ", UDim2.new(0.61, 4, 1, -84), UDim2.new(0.2, -4, 0, 35), function()
    local macro = selectedMacro()
    if not macro then return end
    for _, other in ipairs(state.config.macros) do
        if other.fingerprintKey == macro.fingerprintKey then other.isDefault = false end
    end
    macro.isDefault = true
    saveDisk()
    refreshMacros()
end)
button(macrosPage, "УДАЛИТЬ", UDim2.new(0.81, 4, 1, -84), UDim2.new(0.19, -4, 0, 35), function()
    local macro = selectedMacro()
    if not macro then return end
    for index, other in ipairs(state.config.macros) do
        if other.id == macro.id then table.remove(state.config.macros, index) break end
    end
    state.selectedId = state.config.macros[1] and state.config.macros[1].id or nil
    saveDisk()
    refreshMacros()
end, Color3.fromRGB(117, 49, 62))

button(macrosPage, "ЗАПУСТИТЬ", UDim2.new(0, 0, 1, -41), UDim2.new(0.34, -4, 0, 35), function()
    playMacro(selectedMacro(), true, false)
end, palette.accentDark)
button(macrosPage, "ПРИВЯЗАТЬ К КАРТЕ", UDim2.new(0.34, 4, 1, -41), UDim2.new(0.39, -4, 0, 35), function()
    local macro = selectedMacro()
    if not macro then log("Выбери макрос") return end
    local current = fingerprint()
    state.config.mapMatches[Core.mapBindingKey(current)] = macro.id
    -- Keep the exact entry for backward compatibility with old configs/tools.
    state.config.manualMatches[current.key] = macro.id
    saveDisk()
    log("Карта привязана к " .. macro.name .. " · автозапуск будет сразу")
end)
button(macrosPage, "СТОП МАКРОСА", UDim2.new(0.73, 4, 1, -41), UDim2.new(0.27, -4, 0, 35), function()
    stopCurrentMacro("Макрос остановлен пользователем")
end, palette.danger)

label(autoPage, "АВТОМАТИКА МАТЧА", UDim2.fromOffset(2, 0), UDim2.new(1, -4, 0, 22), 10, palette.muted)
makeToggle(autoPage, "АВТОЗАПУСК", UDim2.fromOffset(0, 27), function() return state.config.settings.autoPreference end, function(value)
    state.config.settings.auto = value
    state.config.settings.autoPreference = value
    -- Invalidate queued automatic work without cancelling manual controls/timers.
    state.autoRunToken += 1
    state.replayCheck = nil
    state.controllerNotBefore = 0
    saveDisk()
    if state.playing or state.recording then
        if state.playing then transition("PLAYING", "текущий запуск сохранён · авто для следующих каток") end
        return
    end
    if not value then
        state.controlRunId += 1
        transition("IDLE", "автозапуск выключен")
        return
    end
    local clock = detectGameClock()
    local wave = clock and tonumber(clock.wave)
    if wave and wave > 1 then
        local current = fingerprint()
        state.config.autoContext = {key = Core.mapBindingKey(current), jobId = game.JobId,
            wave = wave, consumed = true, sawResults = false}
        saveDisk()
    end
    transition("WAIT_MATCH", "автозапуск включён · проверяю текущую катку")
end)
makeToggle(autoPage, "ПОВТОР МАТЧЕЙ", UDim2.new(0.5, 8, 0, 27), function() return state.config.settings.autoLoop end, function(value) state.config.settings.autoLoop = value end)
makeToggle(autoPage, "МАКС. СКОРОСТЬ", UDim2.fromOffset(0, 73), function() return state.config.settings.x2 end, function(value)
    state.config.settings.x2 = value
    if value and (state.playing or state.config.settings.auto) then task.defer(armMatchControls) end
end)
makeToggle(autoPage, "АВТОПРОПУСК ВОЛН", UDim2.new(0.5, 8, 0, 73), function() return state.config.settings.autoSkip end, function(value)
    state.config.settings.autoSkip = value
    if value and (state.playing or state.config.settings.auto) then task.defer(armMatchControls) end
end)
makeToggle(autoPage, "ИГРАТЬ СНОВА", UDim2.fromOffset(0, 119), function() return state.config.settings.autoPlayAgain end, function(value) state.config.settings.autoPlayAgain = value end)
makeToggle(autoPage, "СЕРВЕРНЫЙ РЕЖИМ", UDim2.new(0.5, 8, 0, 119), function() return state.config.settings.remoteMode end, function(value) state.config.settings.remoteMode = value end)

state.labels.pauseButton = button(autoPage, "ПАУЗА / ПРОДОЛЖИТЬ", UDim2.new(0, 0, 1, -43), UDim2.new(0.5, -5, 0, 42), togglePause)
button(autoPage, "ОСТАНОВИТЬ ВСЁ", UDim2.new(0.5, 5, 1, -43), UDim2.new(0.5, -5, 0, 42), function()
    stopPlayback("EMERGENCY STOP", true)
end, palette.danger)

label(bindingsPage, "Скорость переключается через Z. Остальные кнопки ищутся автоматически.", UDim2.fromOffset(2, 0), UDim2.new(1, -4, 0, 34), 10, palette.muted)
for index, item in ipairs({
    {key = "x2", title = "СКОРОСТЬ ИГРЫ", keyboard = true},
    {key = "autoSkip", title = "ПРОПУСК ВОЛН"},
    {key = "playAgain", title = "ИГРАТЬ СНОВА"},
    {key = "matchTimer", title = "ИГРОВОЙ ТАЙМЕР"},
}) do
    local row = Instance.new("Frame")
    row.BackgroundColor3 = palette.panel
    row.Position = UDim2.fromOffset(0, 40 + (index - 1) * 47)
    row.Size = UDim2.new(1, 0, 0, 41)
    row.Parent = bindingsPage
    round(row, 10)
    stroke(row, palette.line, 0.25)
    label(row, item.title, UDim2.fromOffset(11, 0), UDim2.new(0.42, -11, 1, 0), 12)
    local status = label(row, "", item.keyboard and UDim2.new(0.58, 0, 0, 0) or UDim2.new(0.42, 0, 0, 0),
        item.keyboard and UDim2.new(0.38, 0, 1, 0) or UDim2.new(0.25, 0, 1, 0), 10, palette.muted, Enum.TextXAlignment.Center)
    state.labels["binding_" .. item.key] = status
    if item.keyboard then
        status.Text = "КЛАВИША Z"
        status.TextColor3 = palette.accent
    else
        button(row, "АВТО", UDim2.new(0.68, 0, 0, 4), UDim2.new(0.14, -5, 0, 33), function()
            state.config.bindings[item.key] = {mode = "auto"}
            state.bindingScanAt = 0
            if item.key ~= "matchTimer" then findBindingCandidate(item.key, true) end
            saveDisk()
            refreshBindings()
        end)
        button(row, "ВРУЧН.", UDim2.new(0.82, 0, 0, 4), UDim2.new(0.18, -7, 0, 33), function()
            state.bindingCapture = item.key
            log("BIND " .. item.key .. ": кликни нужную кнопку в игре")
            refreshBindings()
        end, Color3.fromRGB(54, 91, 137))
    end
end

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

local showButton = button(gui, "TD", UDim2.new(1, -58, 0, 72), UDim2.fromOffset(46, 38), function()
    window.Visible = true
    shadow.Visible = true
    state.showButton.Visible = false
end, palette.accentDark)
showButton.TextSize = 12
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
    local width = math.min(548, size.w - 18)
    local height = math.min(366, size.h - 24)
    width = math.max(300, width)
    height = math.max(320, height)
    window.Size = UDim2.fromOffset(width, height)
    window.Position = UDim2.fromOffset(math.max(8, (size.w - width) / 2), math.max(8, (size.h - height) / 2))
    shadow.Size = UDim2.fromOffset(width, height)
    shadow.Position = UDim2.fromOffset(window.Position.X.Offset + 4, window.Position.Y.Offset + 4)
    local compact = width < 470
    navTitle.Visible = not compact
    if compact then
        nav.Position = UDim2.fromOffset(10, 58)
        nav.Size = UDim2.new(1, -20, 0, 34)
        content.Position = UDim2.fromOffset(10, 100)
        content.Size = UDim2.new(1, -20, 1, -110)
        for index, itemData in ipairs(navItems) do
            local item = navButtons[itemData.page]
            item.Position = UDim2.new((index - 1) / #navItems, 2, 0, 0)
            item.Size = UDim2.new(1 / #navItems, -4, 1, 0)
            item.TextXAlignment = Enum.TextXAlignment.Center
            local padding = item:FindFirstChildOfClass("UIPadding")
            if padding then padding.PaddingLeft = UDim.new(0, 0) end
        end
    else
        nav.Position = UDim2.fromOffset(10, 58)
        nav.Size = UDim2.new(0, 108, 1, -68)
        content.Position = UDim2.fromOffset(128, 58)
        content.Size = UDim2.new(1, -138, 1, -68)
        for index, itemData in ipairs(navItems) do
            local item = navButtons[itemData.page]
            item.Position = UDim2.fromOffset(7, 32 + (index - 1) * 48)
            item.Size = UDim2.new(1, -14, 0, 41)
            item.TextXAlignment = Enum.TextXAlignment.Left
            local padding = item:FindFirstChildOfClass("UIPadding")
            if padding then padding.PaddingLeft = UDim.new(0, 11) end
        end
    end
    if state.labels.recordHint then state.labels.recordHint.Visible = not compact and height >= 350 end
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
        local empty = button(list, "Нет макросов · открой «Запись»", UDim2.new(), UDim2.new(1, 0, 0, 48), function() showPage("RECORD") end)
        empty.LayoutOrder = 1
        return
    end
    for index, macro in ipairs(state.config.macros) do
        local duration = #macro.events > 0 and (tonumber(macro.events[#macro.events].t) or 0) or 0
        local marker = macro.isDefault and "★ " or ""
        local text = string.format("%s%s  [%s]\n%s · %s · %.1f сек · %d событий", marker, macro.name,
            macro.recordMode == "remote" and "СЕРВЕР" or "СТАРЫЙ",
            tostring(macro.fingerprint.mapKey), tostring(macro.fingerprint.spawnKey), duration, #macro.events)
        local row = button(list, text, UDim2.new(), UDim2.new(1, 0, 0, 51), function()
            state.selectedId = macro.id
            state.labels.renameBox.Text = macro.name
            refreshMacros()
            refreshAll()
        end, macro.id == state.selectedId and Color3.fromRGB(42, 81, 84) or palette.panel2)
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
    for _, kind in ipairs({"x2", "autoSkip", "playAgain", "matchTimer"}) do
        local target = state.labels["binding_" .. kind]
        if target then
            local binding = state.config.bindings[kind] or {mode = "auto"}
            if kind == "x2" then
                target.Text = "КЛАВИША Z"
                target.TextColor3 = palette.accent
            elseif state.bindingCapture == kind then
                target.Text = "ЖДУ КЛИК"
                target.TextColor3 = Color3.fromRGB(255, 202, 91)
            elseif binding.mode == "manual" then
                target.Text = "УКАЗАНО"
                target.TextColor3 = palette.accent2
            elseif kind == "matchTimer" then
                local clock = detectGameClock()
                target.Text = clock and "НАЙДЕН ✓" or "НЕ НАЙДЕН"
                target.TextColor3 = clock and palette.accent or palette.muted
            else
                local candidate, score = findBindingCandidate(kind)
                target.Text = candidate and score >= 64 and "НАЙДЕН ✓" or "ИЩУ…"
                target.TextColor3 = candidate and score >= 64 and palette.accent or palette.muted
            end
        end
    end
end

local controllerNames = {
    IDLE = "ГОТОВ",
    WAIT_WAVE = "ЖДУ ВОЛНУ",
    RECORDING = "ЗАПИСЬ",
    WAIT_MATCH = "ЖДУ МАТЧ",
    PREPARE = "ПОДГОТОВКА",
    PLAYING = "ЗАПУСК",
    WAIT_END = "ЖДУ КОНЕЦ",
    REPLAY = "ПОВТОР",
    ERROR = "ОШИБКА",
}

refreshAll = function()
    if not state.config or state.destroyed then return end
    for _, update in ipairs(state.rows) do pcall(update) end
    if state.labels.controller then state.labels.controller.Text = controllerNames[state.controllerState] or state.controllerState end
    if state.labels.speed then state.labels.speed.Text = string.format("СКОРОСТЬ ВОСПРОИЗВЕДЕНИЯ  ×%.2f", tonumber(state.config.settings.playbackSpeed) or 1) end
    if state.labels.recordCount then
        state.labels.recordCount.Text = state.recording
            and (state.recordingLive and (#state.recordedEvents .. " событий") or "ЖДУ НАЧАЛО ВОЛН")
            or (state.playing and (state.paused and "ПАУЗА" or "ВОСПРОИЗВЕДЕНИЕ") or "ГОТОВ")
        state.labels.recordCount.TextColor3 = state.recording and palette.danger or (state.playing and palette.accent or palette.muted)
    end
    if state.labels.recordButton then state.labels.recordButton.Text = state.recording and "ИДЁТ ЗАПИСЬ…" or "НАЧАТЬ ЗАПИСЬ" end
    if state.labels.playSelectedButton then
        local macro = selectedMacro()
        state.labels.playSelectedButton.Text = macro and ("ЗАПУСТИТЬ: " .. macro.name) or "СНАЧАЛА СОЗДАЙ МАКРОС"
    end
    local current = fingerprint()
    if state.labels.fingerprint then state.labels.fingerprint.Text = current.mapKey .. " · " .. current.spawnKey end
    if state.labels.storage then
        local hook = state.remoteHookReady and "СЕРВЕРНЫЙ РЕЖИМ ГОТОВ" or "ОШИБКА СЕРВЕРНОГО РЕЖИМА"
        state.labels.storage.Text = state.memoryOnly and "MEMORY ONLY · записи пропадут после перезапуска"
            or ("TDMacroLab/config.json · " .. #state.config.macros .. " macros · " .. hook)
        state.labels.storage.TextColor3 = state.memoryOnly and Color3.fromRGB(255, 202, 91)
            or (state.remoteHookReady and palette.muted or palette.danger)
    end
    if activePage == "BINDINGS" then refreshBindings() end
end

function state:Destroy()
    if self.destroyed then return end
    -- Flush the current switches before hot-reload/close. In particular,
    -- AUTOSTART must survive the next script launch unchanged.
    pcall(saveDisk)
    self.destroyed = true
    self.recording = false
    self.playToken += 1
    self.playing = false
    releaseAll()
    releaseCameraControl()
    if self.remoteBus and type(self.remoteBus.setListener) == "function" then
        pcall(function() self.remoteBus:setListener(nil) end)
    end
    for _, connection in ipairs(self.connections) do pcall(function() connection:Disconnect() end) end
    self.connections = {}
    if self.gui then pcall(function() self.gui:Destroy() end) end
    if env.TDMacroPrototype == self then env.TDMacroPrototype = nil end
    if env.TDMacroLab == self then env.TDMacroLab = nil end
end

state.StartRecording = startRecording
state.StopAndSave = stopAndSave
state.PlaySelected = function(force) return playMacro(selectedMacro(), force == true, false) end
state.Stop = function() stopCurrentMacro("Макрос остановлен через API") end
state.StopAll = function() stopPlayback("Полная остановка через API", true) end
state.Pause = togglePause
state.Fingerprint = fingerprint
state.Core = Core

showPage("RECORD")
refreshMacros()
refreshAll()
log("TD Macro Lab v" .. SCRIPT_VERSION .. " загружен" .. (state.memoryOnly and " · MEMORY ONLY" or ""))
