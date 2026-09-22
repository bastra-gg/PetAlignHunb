-- Alliance TD Match Time Probe
-- Read-only diagnostic: scans GUI / replicated values / attributes for match-time candidates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
    repeat task.wait() player = Players.LocalPlayer until player
end

local playerGui = player:WaitForChild("PlayerGui")
local DURATION = 18
local SAMPLE_INTERVAL = 0.25
local RESCAN_AT = 8

local function safeName(x)
    local ok, v = pcall(function() return x:GetFullName() end)
    return ok and v or tostring(x)
end

local function parseTimeText(v)
    local s = tostring(v or "")
    local m, sec = s:match("(%d+)%s*:%s*(%d%d?)")
    if m and sec and tonumber(sec) and tonumber(sec) < 60 then
        return tonumber(m) * 60 + tonumber(sec), s
    end
    local h, mm, ss = s:match("(%d+)%s*:%s*(%d%d?)%s*:%s*(%d%d?)")
    if h and mm and ss and tonumber(mm) < 60 and tonumber(ss) < 60 then
        return tonumber(h) * 3600 + tonumber(mm) * 60 + tonumber(ss), s
    end
    return nil, s
end

local keywords = {
    "time","timer","clock","elapsed","duration","match","game","round","wave",
    "врем","тайм","матч","раунд","волна"
}

local function relevantName(s)
    s = string.lower(tostring(s or ""))
    for _, k in ipairs(keywords) do
        if s:find(k, 1, true) then return true end
    end
    return false
end

local tracks = {}
local order = {}

local function register(id, kind, path, label, getter)
    if tracks[id] then return end
    tracks[id] = {
        id=id, kind=kind, path=path, label=label or "",
        getter=getter, samples=0, changes=0, inc=0, dec=0, same=0,
        jumps=0, resets=0, first=nil, last=nil, min=nil, max=nil,
        firstRaw=nil, lastRaw=nil, errors=0
    }
    order[#order+1] = id
end

local function addGui(obj)
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end
    local txt = tostring(obj.Text or "")
    local parsed = parseTimeText(txt)
    local nameBlob = obj.Name .. " " .. (obj.Parent and obj.Parent.Name or "")
    if not parsed and not relevantName(nameBlob) then return end
    local id = "GUI|" .. safeName(obj)
    register(id, "GUI", safeName(obj), nameBlob, function()
        if not obj.Parent then return nil end
        local raw = tostring(obj.Text or "")
        local n = parseTimeText(raw)
        if n ~= nil then return n, raw end
        local only = tonumber(raw:match("^%s*(-?%d+%.?%d*)%s*$"))
        return only, raw
    end)
end

local function addValue(obj)
    if not (obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("StringValue")) then return end
    if not relevantName(obj.Name .. " " .. (obj.Parent and obj.Parent.Name or "")) then return end
    local id = "VAL|" .. safeName(obj)
    register(id, "VALUE", safeName(obj), obj.Name, function()
        if not obj.Parent then return nil end
        local raw = obj.Value
        if type(raw) == "number" then return raw, tostring(raw) end
        local t = parseTimeText(raw)
        if t ~= nil then return t, tostring(raw) end
        return tonumber(raw), tostring(raw)
    end)
end

local function addAttributes(obj)
    local ok, attrs = pcall(function() return obj:GetAttributes() end)
    if not ok or type(attrs) ~= "table" then return end
    for key, _ in pairs(attrs) do
        if relevantName(key .. " " .. obj.Name) then
            local id = "ATTR|" .. safeName(obj) .. "|" .. tostring(key)
            register(id, "ATTR", safeName(obj), tostring(key), function()
                if not obj.Parent and obj ~= Workspace and obj ~= ReplicatedStorage then return nil end
                local raw = obj:GetAttribute(key)
                if type(raw) == "number" then return raw, tostring(raw) end
                local t = parseTimeText(raw)
                if t ~= nil then return t, tostring(raw) end
                return tonumber(raw), tostring(raw)
            end)
        end
    end
end

local function scanRoot(root)
    addGui(root)
    addValue(root)
    addAttributes(root)
    for _, obj in ipairs(root:GetDescendants()) do
        addGui(obj)
        addValue(obj)
        addAttributes(obj)
    end
end

local function rescan()
    scanRoot(playerGui)
    scanRoot(ReplicatedStorage)
    scanRoot(Workspace)
end

local function sampleTrack(t)
    local ok, value, raw = pcall(t.getter)
    if not ok then
        t.errors += 1
        return
    end
    if type(value) ~= "number" then return end

    t.samples += 1
    if t.first == nil then
        t.first = value
        t.firstRaw = raw
        t.min, t.max = value, value
    else
        local d = value - t.last
        if math.abs(d) < 0.0001 then
            t.same += 1
        else
            t.changes += 1
            if d > 0 then t.inc += 1 else t.dec += 1 end
            if math.abs(d) > 2.5 then t.jumps += 1 end
            if t.last > 5 and value <= 2 then t.resets += 1 end
        end
        if value < t.min then t.min = value end
        if value > t.max then t.max = value end
    end
    t.last = value
    t.lastRaw = raw
end

print("[MatchTimeProbe] scanning...")
rescan()

local started = os.clock()
local rescanned = false
while os.clock() - started < DURATION do
    for _, id in ipairs(order) do
        sampleTrack(tracks[id])
    end
    if not rescanned and os.clock() - started >= RESCAN_AT then
        rescanned = true
        rescan()
    end
    task.wait(SAMPLE_INTERVAL)
end

local rows = {}
for _, id in ipairs(order) do
    local t = tracks[id]
    if t.samples > 0 then
        local monotonic = math.max(t.inc, t.dec)
        local score = t.changes * 10 + monotonic * 4 - t.jumps * 2 - t.resets * 5
        if relevantName(t.label .. " " .. t.path) then score += 15 end
        if t.kind == "GUI" then score += 5 end
        t.score = score
        rows[#rows+1] = t
    end
end

table.sort(rows, function(a,b)
    if a.score ~= b.score then return a.score > b.score end
    return a.changes > b.changes
end)

local out = {}
out[#out+1] = "=== MATCH TIME PROBE REPORT ==="
out[#out+1] = "duration=" .. tostring(DURATION) .. "s candidates=" .. tostring(#rows)
out[#out+1] = "Legend: dir=UP/DOWN/MIXED, resets>0 usually means wave/local timer."
out[#out+1] = ""

for i = 1, math.min(#rows, 35) do
    local t = rows[i]
    local dir = "STILL"
    if t.inc > 0 and t.dec == 0 then dir = "UP"
    elseif t.dec > 0 and t.inc == 0 then dir = "DOWN"
    elseif t.inc > 0 or t.dec > 0 then dir = "MIXED" end
    out[#out+1] = string.format(
        "#%02d score=%d kind=%s dir=%s changes=%d jumps=%d resets=%d first=%s last=%s min=%s max=%s\n%s\nlabel=%s",
        i, t.score or 0, t.kind, dir, t.changes, t.jumps, t.resets,
        tostring(t.firstRaw or t.first), tostring(t.lastRaw or t.last),
        tostring(t.min), tostring(t.max), t.path, t.label
    )
    out[#out+1] = ""
end

local report = table.concat(out, "\n")
print(report)

local copied = false
if type(setclipboard) == "function" then
    copied = pcall(setclipboard, report)
end
if type(writefile) == "function" then
    pcall(writefile, "MatchTimeProbe_report.txt", report)
end

print("[MatchTimeProbe] DONE" .. (copied and " • report copied to clipboard" or ""))
