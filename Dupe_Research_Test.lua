--[[
  Muscle Legends • Trade Research Lab v0.1
  Passive remote recorder for analysing a MANUAL trade flow.

  It never calls FireServer/InvokeServer, never sends a trade request and never
  confirms anything. Run it alone, then perform the harmless UI steps yourself.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local State = {
	active = true,
	maxEntries = 160,
	entries = {},
	ui = {},
}

local function notify(title, message)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = message,
			Duration = 6,
		})
	end)
end

local function safeFullName(instance)
	local ok, value = pcall(function()
		return instance:GetFullName()
	end)
	return ok and value or instance.Name
end

local function short(value, depth)
	depth = depth or 0
	if depth > 2 then
		return "…"
	end

	local kind = typeof(value)
	if kind == "string" then
		local text = value:gsub("[\r\n]", " ")
		if #text > 80 then
			text = text:sub(1, 77) .. "…"
		end
		return string.format("%q", text)
	elseif kind == "Instance" then
		return "<" .. safeFullName(value) .. ">"
	elseif kind == "table" then
		local bits = {}
		local count = 0
		for key, item in pairs(value) do
			count += 1
			if count > 6 then
				table.insert(bits, "…")
				break
			end
			table.insert(bits, "[" .. short(key, depth + 1) .. "]=" .. short(item, depth + 1))
		end
		return "{" .. table.concat(bits, ", ") .. "}"
	end

	local text = tostring(value)
	if #text > 100 then
		text = text:sub(1, 97) .. "…"
	end
	return text
end

local function serialiseArgs(args)
	local lines = {}
	for index, value in ipairs(args) do
		table.insert(lines, "  " .. index .. ": " .. short(value))
	end
	return #lines > 0 and table.concat(lines, "\n") or "  (no arguments)"
end

local function relevant(path)
	path = string.lower(path)
	return path:find("trade", 1, true)
		or path:find("pet", 1, true)
		or path:find("inventory", 1, true)
		or path:find("fuse", 1, true)
		or path:find("evolve", 1, true)
end

local function refresh()
	local output = State.ui.output
	if not output then
		return
	end

	local lines = {}
	for _, entry in ipairs(State.entries) do
		table.insert(lines, entry.text)
	end
	output.Text = #lines > 0 and table.concat(lines, "\n\n") or "No server calls recorded yet."
	State.ui.counter.Text = string.format("REC %s  •  %d/%d", State.active and "ON" or "PAUSE", #State.entries, State.maxEntries)
end

local function addEntry(remote, method, args)
	local path = safeFullName(remote)
	local tag = relevant(path) and "[TARGET] " or "[other] "
	local entry = {
		text = string.format("%s%s\n%s\n%s", tag, method .. "  " .. path, os.date("!%H:%M:%S"), serialiseArgs(args)),
	}
	table.insert(State.entries, entry)
	if #State.entries > State.maxEntries then
		table.remove(State.entries, 1)
	end
	refresh()
end

local function copyLog()
	if typeof(setclipboard) ~= "function" then
		notify("Trade Lab", "Clipboard API is unavailable in this executor.")
		return
	end
	local text = {"Muscle Legends Trade Lab v0.1", "Passive capture — no remotes were sent by this script.", ""}
	for _, entry in ipairs(State.entries) do
		table.insert(text, entry.text)
		table.insert(text, "")
	end
	setclipboard(table.concat(text, "\n"))
	notify("Trade Lab", "Log copied. Send it here as text.")
end

local function makeButton(parent, text, x, callback)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Color3.fromRGB(31, 39, 57)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamSemibold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(232, 238, 255)
	button.TextSize = 12
	button.Position = UDim2.fromOffset(x, 38)
	button.Size = UDim2.fromOffset(86, 27)
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
	button.MouseButton1Click:Connect(callback)
	return button
end

local function createUi()
	local parent = LocalPlayer:WaitForChild("PlayerGui")
	if typeof(gethui) == "function" then
		parent = gethui()
	end

	local old = parent:FindFirstChild("ML_TradeResearchLab")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ML_TradeResearchLab"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	frame.BorderSizePixel = 0
	frame.Position = UDim2.new(0.5, -190, 0.5, -145)
	frame.Size = UDim2.fromOffset(380, 290)
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "TRADE RESEARCH LAB"
	title.TextColor3 = Color3.fromRGB(112, 235, 181)
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(14, 10)
	title.Size = UDim2.fromOffset(280, 20)
	title.Parent = frame

	local counter = Instance.new("TextLabel")
	counter.BackgroundTransparency = 1
	counter.Font = Enum.Font.Code
	counter.TextColor3 = Color3.fromRGB(170, 184, 207)
	counter.TextSize = 11
	counter.TextXAlignment = Enum.TextXAlignment.Right
	counter.Position = UDim2.fromOffset(205, 12)
	counter.Size = UDim2.fromOffset(160, 18)
	counter.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.Text = "Clear → manually open trade / offer one junk pet → stop before confirmation → Copy."
	hint.TextColor3 = Color3.fromRGB(171, 181, 200)
	hint.TextSize = 10
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.Position = UDim2.fromOffset(14, 70)
	hint.Size = UDim2.fromOffset(350, 31)
	hint.Parent = frame

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundColor3 = Color3.fromRGB(19, 24, 36)
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 4
	scroll.Position = UDim2.fromOffset(14, 105)
	scroll.Size = UDim2.fromOffset(352, 170)
	scroll.Parent = frame
	Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 7)

	local output = Instance.new("TextLabel")
	output.AutomaticSize = Enum.AutomaticSize.Y
	output.BackgroundTransparency = 1
	output.Font = Enum.Font.Code
	output.TextColor3 = Color3.fromRGB(218, 225, 240)
	output.TextSize = 10
	output.TextWrapped = true
	output.TextXAlignment = Enum.TextXAlignment.Left
	output.TextYAlignment = Enum.TextYAlignment.Top
	output.Position = UDim2.fromOffset(7, 6)
	output.Size = UDim2.new(1, -14, 0, 0)
	output.Parent = scroll
	output:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		scroll.CanvasSize = UDim2.fromOffset(0, output.AbsoluteSize.Y + 12)
	end)

	State.ui.counter = counter
	State.ui.output = output

	makeButton(frame, "Clear", 14, function()
		table.clear(State.entries)
		refresh()
	end)
	makeButton(frame, "Pause", 107, function(button)
		State.active = not State.active
		button.Text = State.active and "Pause" or "Resume"
		refresh()
	end)
	makeButton(frame, "Copy log", 200, copyLog)
	makeButton(frame, "Close", 280, function()
		gui:Destroy()
	end).Size = UDim2.fromOffset(70, 27)

	refresh()
end

if typeof(hookmetamethod) ~= "function" or typeof(getnamecallmethod) ~= "function" or typeof(newcclosure) ~= "function" then
	notify("Trade Lab", "This executor cannot passively observe remotes.")
	return
end

createUi()

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(remote, ...)
	local method = getnamecallmethod()
	local isExecutorCall = typeof(checkcaller) == "function" and checkcaller()
	if State.active and not isExecutorCall and (method == "FireServer" or method == "InvokeServer") then
		if typeof(remote) == "Instance" and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
			local args = table.pack(...)
			local packed = {}
			for index = 1, args.n do
				packed[index] = args[index]
			end
			addEntry(remote, method, packed)
		end
	end
	return oldNamecall(remote, ...)
end))

notify("Trade Lab", "Passive recorder ready. It does not send any remote calls.")
