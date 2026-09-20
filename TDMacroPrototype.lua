-- TD Macro Prototype
-- Standalone prototype: records keyboard/mouse input with timestamps and replays it.
-- Game-specific map detection / x2 / replay / auto-skip hooks can be wired in later.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
if not player then return end

local env = _G
if type(getgenv) == "function" then
    local ok, v = pcall(getgenv)
    if ok and type(v) == "table" then env = v end
end

if env.TDMacroPrototype and type(env.TDMacroPrototype.Destroy) == "function" then
    pcall(function() env.TDMacroPrototype:Destroy() end)
end

local state = {
    recording = false,
    playing = false,
    startedAt = 0,
    actions = {},
    macros = {},
    selected = nil,
    connections = {},
    gui = nil,
    currentName = "Macro 1",
    currentTag = tostring(game.PlaceId),
    autoPlay = false,
}

env.TDMacroPrototype = state

local function keep(c)
    state.connections[#state.connections+1] = c
    return c
end

local function now()
    return os.clock() - state.startedAt
end

local function addAction(kind, data)
    if not state.recording then return end
    data = data or {}
    data.kind = kind
    data.t = now()
    state.actions[#state.actions+1] = data
end

local function canFile()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local FILE = "td_macro_prototype.json"

local function encodeMacros()
    return HttpService:JSONEncode({macros=state.macros})
end

local function saveDisk()
    if not canFile() then return false end
    local ok = pcall(writefile, FILE, encodeMacros())
    return ok
end

local function loadDisk()
    if not canFile() or not isfile(FILE) then return end
    local ok, raw = pcall(readfile, FILE)
    if not ok or type(raw) ~= "string" then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok2 and type(data) == "table" and type(data.macros) == "table" then
        state.macros = data.macros
    end
end

local function macroKey(name, tag)
    return tostring(tag or game.PlaceId) .. "::" .. tostring(name or "Macro")
end

local function saveCurrent()
    if #state.actions == 0 then return nil end
    local key = macroKey(state.currentName, state.currentTag)
    state.macros[key] = {
        name = state.currentName,
        tag = state.currentTag,
        placeId = game.PlaceId,
        actions = state.actions,
        savedAt = os.time(),
    }
    state.selected = key
    saveDisk()
    return key
end

local function beginRecord()
    if state.playing then return end
    state.actions = {}
    state.recording = true
    state.startedAt = os.clock()
end

local function stopRecord(save)
    if not state.recording then return end
    state.recording = false
    if save then saveCurrent() end
end

local keyMap = {}
for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
    keyMap[item.Name] = item
end

local inputMap = {}
for _, item in ipairs(Enum.UserInputType:GetEnumItems()) do
    inputMap[item.Name] = item
end

local function sendAction(a)
    if a.kind == "key_down" then
        local key = keyMap[a.key]
        if key then VirtualInputManager:SendKeyEvent(true, key, false, game) end
    elseif a.kind == "key_up" then
        local key = keyMap[a.key]
        if key then VirtualInputManager:SendKeyEvent(false, key, false, game) end
    elseif a.kind == "mouse_down" then
        VirtualInputManager:SendMouseButtonEvent(a.x, a.y, a.button or 0, true, game, 0)
    elseif a.kind == "mouse_up" then
        VirtualInputManager:SendMouseButtonEvent(a.x, a.y, a.button or 0, false, game, 0)
    elseif a.kind == "wheel" then
        pcall(function()
            VirtualInputManager:SendMouseWheelEvent(a.x or 0, a.y or 0, a.delta or 0, game)
        end)
    end
end

local function playMacro(key)
    if state.recording or state.playing then return false end
    local macro = state.macros[key]
    if type(macro) ~= "table" or type(macro.actions) ~= "table" then return false end

    state.playing = true
    state.selected = key

    task.spawn(function()
        local start = os.clock()
        for _, a in ipairs(macro.actions) do
            if not state.playing then break end
            local waitFor = (tonumber(a.t) or 0) - (os.clock() - start)
            if waitFor > 0 then task.wait(waitFor) end
            if not state.playing then break end
            pcall(sendAction, a)
        end
        state.playing = false
    end)
    return true
end

local function stopPlayback()
    state.playing = false
end

loadDisk()

-- input recorder
keep(UIS.InputBegan:Connect(function(input, gp)
    if not state.recording or gp then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        addAction("key_down", {key=input.KeyCode.Name})
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        local p = UIS:GetMouseLocation()
        addAction("mouse_down", {x=math.floor(p.X), y=math.floor(p.Y), button=0})
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        local p = UIS:GetMouseLocation()
        addAction("mouse_down", {x=math.floor(p.X), y=math.floor(p.Y), button=1})
    end
end))

keep(UIS.InputEnded:Connect(function(input, gp)
    if not state.recording or gp then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        addAction("key_up", {key=input.KeyCode.Name})
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        local p = UIS:GetMouseLocation()
        addAction("mouse_up", {x=math.floor(p.X), y=math.floor(p.Y), button=0})
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        local p = UIS:GetMouseLocation()
        addAction("mouse_up", {x=math.floor(p.X), y=math.floor(p.Y), button=1})
    end
end))

keep(UIS.InputChanged:Connect(function(input, gp)
    if not state.recording or gp then return end
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        local p = UIS:GetMouseLocation()
        addAction("wheel", {x=math.floor(p.X), y=math.floor(p.Y), delta=input.Position.Z})
    end
end))

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "TDMacroPrototypeUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end
state.gui = gui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromOffset(520, 340)
root.Position = UDim2.new(0.5, -260, 0.5, -170)
root.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
root.BorderSizePixel = 0
root.Parent = gui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 18)
rootCorner.Parent = root

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Transparency = 0.45
stroke.Color = Color3.fromRGB(94, 104, 130)
stroke.Parent = root

local shadow = Instance.new("Frame")
shadow.Size = UDim2.new(1, 18, 1, 18)
shadow.Position = UDim2.fromOffset(-9, 8)
shadow.BackgroundColor3 = Color3.new(0,0,0)
shadow.BackgroundTransparency = 0.55
shadow.BorderSizePixel = 0
shadow.ZIndex = -1
shadow.Parent = root
local shc = Instance.new("UICorner"); shc.CornerRadius=UDim.new(0,22); shc.Parent=shadow

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 58)
top.BackgroundTransparency = 1
top.Parent = root

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -120, 0, 28)
title.Position = UDim2.fromOffset(20, 10)
title.BackgroundTransparency = 1
title.Text = "TD MACRO LAB"
title.TextColor3 = Color3.fromRGB(235,238,247)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -120, 0, 18)
sub.Position = UDim2.fromOffset(20, 34)
sub.BackgroundTransparency = 1
sub.Text = "prototype / input recorder"
sub.TextColor3 = Color3.fromRGB(120,128,151)
sub.Font = Enum.Font.Gotham
sub.TextSize = 11
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Parent = top

local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(10,10)
dot.Position = UDim2.new(1,-44,0,24)
dot.BackgroundColor3 = Color3.fromRGB(105,113,135)
dot.BorderSizePixel = 0
dot.Parent = top
local dc = Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot

local side = Instance.new("Frame")
side.Size = UDim2.fromOffset(118, 258)
side.Position = UDim2.fromOffset(12, 68)
side.BackgroundColor3 = Color3.fromRGB(21,24,32)
side.BorderSizePixel = 0
side.Parent = root
local sc = Instance.new("UICorner"); sc.CornerRadius=UDim.new(0,14); sc.Parent=side

local content = Instance.new("Frame")
content.Size = UDim2.new(1,-148,1,-82)
content.Position = UDim2.fromOffset(140,68)
content.BackgroundColor3 = Color3.fromRGB(20,22,29)
content.BorderSizePixel = 0
content.Parent = root
local cc = Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,14); cc.Parent=content

local tabs = {}
local pages = {}

local function mkTab(text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-16,0,38)
    b.Position = UDim2.fromOffset(8,y)
    b.BackgroundColor3 = Color3.fromRGB(25,28,37)
    b.AutoButtonColor = false
    b.Text = text
    b.TextColor3 = Color3.fromRGB(155,163,183)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.Parent = side
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=b
    tabs[text]=b
    return b
end

local function mkPage(name)
    local p=Instance.new("Frame")
    p.Name=name
    p.Size=UDim2.fromScale(1,1)
    p.BackgroundTransparency=1
    p.Visible=false
    p.Parent=content
    pages[name]=p
    return p
end

local recordTab=mkTab("RECORD",8)
local libraryTab=mkTab("LIBRARY",52)
local autoTab=mkTab("AUTO",96)
local logTab=mkTab("LOG",140)

local recordPage=mkPage("RECORD")
local libraryPage=mkPage("LIBRARY")
local autoPage=mkPage("AUTO")
local logPage=mkPage("LOG")

local function setTab(name)
    for n,p in pairs(pages) do p.Visible=(n==name) end
    for n,b in pairs(tabs) do
        b.BackgroundColor3 = n==name and Color3.fromRGB(61,66,87) or Color3.fromRGB(25,28,37)
        b.TextColor3 = n==name and Color3.fromRGB(245,247,252) or Color3.fromRGB(155,163,183)
    end
end

local function label(parent,text,x,y,w,h,size,bold)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.fromOffset(w,h)
    l.Position=UDim2.fromOffset(x,y)
    l.BackgroundTransparency=1
    l.Text=text
    l.TextColor3=Color3.fromRGB(224,228,238)
    l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize=size or 12
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.Parent=parent
    return l
end

local function textbox(parent,placeholder,x,y,w)
    local t=Instance.new("TextBox")
    t.Size=UDim2.fromOffset(w,38)
    t.Position=UDim2.fromOffset(x,y)
    t.BackgroundColor3=Color3.fromRGB(28,31,40)
    t.BorderSizePixel=0
    t.PlaceholderText=placeholder
    t.PlaceholderColor3=Color3.fromRGB(105,111,130)
    t.Text=""
    t.TextColor3=Color3.fromRGB(236,239,247)
    t.Font=Enum.Font.Gotham
    t.TextSize=12
    t.ClearTextOnFocus=false
    t.Parent=parent
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=t
    return t
end

local function button(parent,text,x,y,w,h)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(w,h)
    b.Position=UDim2.fromOffset(x,y)
    b.BackgroundColor3=Color3.fromRGB(68,73,95)
    b.BorderSizePixel=0
    b.AutoButtonColor=false
    b.Text=text
    b.TextColor3=Color3.fromRGB(245,247,252)
    b.Font=Enum.Font.GothamBold
    b.TextSize=12
    b.Parent=parent
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=b
    return b
end

-- RECORD PAGE
label(recordPage,"Recorder",16,14,250,24,16,true)
label(recordPage,"Name",16,48,100,18,11,false)
local nameBox=textbox(recordPage,"Macro name",16,68,150)
nameBox.Text=state.currentName
label(recordPage,"Map / spawn tag",180,48,130,18,11,false)
local tagBox=textbox(recordPage,"PlaceId / tag",180,68,150)
tagBox.Text=state.currentTag

local recBtn=button(recordPage,"START RECORD",16,120,150,42)
local stopBtn=button(recordPage,"STOP + SAVE",180,120,150,42)
stopBtn.BackgroundColor3=Color3.fromRGB(44,47,60)

local stat=label(recordPage,"Idle",16,180,314,22,13,true)
local count=label(recordPage,"0 actions",16,208,314,18,11,false)
local fileInfo=label(recordPage,canFile() and "Disk save: available" or "Disk save: memory only",16,232,314,18,10,false)
fileInfo.TextColor3=Color3.fromRGB(128,136,156)

-- LIBRARY PAGE
label(libraryPage,"Saved macros",16,14,250,24,16,true)
local listFrame=Instance.new("ScrollingFrame")
listFrame.Size=UDim2.new(1,-32,1,-58)
listFrame.Position=UDim2.fromOffset(16,48)
listFrame.BackgroundTransparency=1
listFrame.BorderSizePixel=0
listFrame.ScrollBarThickness=3
listFrame.CanvasSize=UDim2.fromOffset(0,0)
listFrame.Parent=libraryPage
local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,8); layout.Parent=listFrame

local function rebuildLibrary()
    for _,c in ipairs(listFrame:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local n=0
    for key,m in pairs(state.macros) do
        n+=1
        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,-4,0,58)
        row.BackgroundColor3=Color3.fromRGB(28,31,40)
        row.BorderSizePixel=0
        row.Parent=listFrame
        local rc=Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,10); rc.Parent=row
        label(row,tostring(m.name or key),12,7,190,18,12,true)
        local meta=label(row,tostring(m.tag or "").."  •  "..tostring(#(m.actions or {})).." actions",12,29,210,16,10,false)
        meta.TextColor3=Color3.fromRGB(120,128,149)
        local play=button(row,"PLAY",228,11,76,36)
        keep(play.Activated:Connect(function() playMacro(key) end))
    end
    listFrame.CanvasSize=UDim2.fromOffset(0,n*66)
end

-- AUTO PAGE
label(autoPage,"Automation",16,14,250,24,16,true)
local autoLabel=label(autoPage,"Auto-select by tag",16,54,200,22,12,true)
local autoToggle=button(autoPage,state.autoPlay and "ON" or "OFF",236,48,94,34)
autoToggle.BackgroundColor3=state.autoPlay and Color3.fromRGB(60,93,77) or Color3.fromRGB(47,50,63)
label(autoPage,"Prototype behavior: when enabled, choose the first macro whose tag matches game.PlaceId.",16,98,314,50,10,false)
local autoRun=button(autoPage,"RUN MATCHING NOW",16,162,314,40)

local function findMatching()
    local target=tostring(game.PlaceId)
    for key,m in pairs(state.macros) do
        if tostring(m.tag)==target then return key end
    end
end

-- LOG PAGE
label(logPage,"Runtime",16,14,250,24,16,true)
local logText=label(logPage,"Waiting.",16,52,314,160,11,false)
logText.TextWrapped=true
logText.TextYAlignment=Enum.TextYAlignment.Top

local function refreshStatus(msg)
    if state.recording then
        dot.BackgroundColor3=Color3.fromRGB(226,81,91)
        stat.Text="Recording"
        recBtn.Text="RECORDING..."
        recBtn.BackgroundColor3=Color3.fromRGB(102,45,52)
    elseif state.playing then
        dot.BackgroundColor3=Color3.fromRGB(90,183,126)
        stat.Text="Playing"
        recBtn.Text="START RECORD"
        recBtn.BackgroundColor3=Color3.fromRGB(68,73,95)
    else
        dot.BackgroundColor3=Color3.fromRGB(105,113,135)
        stat.Text="Idle"
        recBtn.Text="START RECORD"
        recBtn.BackgroundColor3=Color3.fromRGB(68,73,95)
    end
    count.Text=tostring(#state.actions).." actions"
    if msg then logText.Text=msg end
end

keep(nameBox.FocusLost:Connect(function() state.currentName = nameBox.Text ~= "" and nameBox.Text or "Macro" end))
keep(tagBox.FocusLost:Connect(function() state.currentTag = tagBox.Text ~= "" and tagBox.Text or tostring(game.PlaceId) end))

keep(recBtn.Activated:Connect(function()
    if state.recording then return end
    state.currentName=nameBox.Text~="" and nameBox.Text or "Macro"
    state.currentTag=tagBox.Text~="" and tagBox.Text or tostring(game.PlaceId)
    beginRecord()
    refreshStatus("Recording started: "..state.currentName)
end))

keep(stopBtn.Activated:Connect(function()
    if state.recording then
        stopRecord(true)
        rebuildLibrary()
        refreshStatus("Saved: "..state.currentName)
    elseif state.playing then
        stopPlayback()
        refreshStatus("Playback stopped.")
    end
end))

keep(autoToggle.Activated:Connect(function()
    state.autoPlay=not state.autoPlay
    autoToggle.Text=state.autoPlay and "ON" or "OFF"
    autoToggle.BackgroundColor3=state.autoPlay and Color3.fromRGB(60,93,77) or Color3.fromRGB(47,50,63)
end))

keep(autoRun.Activated:Connect(function()
    local key=findMatching()
    if key then
        playMacro(key)
        refreshStatus("Auto selected: "..key)
    else
        refreshStatus("No macro with tag "..tostring(game.PlaceId))
    end
end))

for name,b in pairs(tabs) do keep(b.Activated:Connect(function() setTab(name); if name=="LIBRARY" then rebuildLibrary() end end)) end

-- drag
local dragging=false
local dragStart,rootStart
keep(top.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=i.Position; rootStart=root.Position
    end
end))
keep(UIS.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        local d=i.Position-dragStart
        root.Position=UDim2.new(rootStart.X.Scale,rootStart.X.Offset+d.X,rootStart.Y.Scale,rootStart.Y.Offset+d.Y)
    end
end))
keep(UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
end))

function state:Destroy()
    self.recording=false
    self.playing=false
    for _,c in ipairs(self.connections) do pcall(function() c:Disconnect() end) end
    self.connections={}
    if self.gui then self.gui:Destroy() end
end

rebuildLibrary()
setTab("RECORD")
refreshStatus("Prototype loaded.")
