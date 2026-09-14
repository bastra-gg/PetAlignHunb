-- RockBugHub TEST bootstrap T39: preserved T38 core + direct boss-chest test patch
local VERSION="4.31HOLO-T39"
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_v1_5_core.lua"
local PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_TEST_BossChestDirect.lua"
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
env.RockBugTestVersion=VERSION
local compiler=loadstring or env.loadstring
if type(compiler)~="function"then error("RockBugHub TEST "..VERSION..": executor has no loadstring",0)end
local function run(url,label)
    local stamp="?v="..VERSION.."-"..tostring(os.time()).."-"..tostring(math.random(100000,999999))
    local ok,source=pcall(function()return game:HttpGet(url..stamp,true)end)
    if not ok or type(source)~="string"then error("RockBugHub TEST "..VERSION..": failed to load "..label.." • "..tostring(source),0)end
    local chunk,problem=compiler(source)
    if type(chunk)~="function"then error("RockBugHub TEST "..VERSION..": compile "..label.." • "..tostring(problem),0)end
    return chunk()
end
local result=run(CORE_URL,"core")
local runtime=env.RockBugRuntime or result
if type(runtime)=="table"then runtime.testVersion=VERSION end
local ok,problem=pcall(function()run(PATCH_URL,"direct chest patch")end)
if not ok then warn("[RockBugHub TEST "..VERSION.."] chest patch failed: "..tostring(problem))end
pcall(function()
    if type(runtime)~="table"or type(runtime.layoutUI)~="table"then return end
    local page=runtime.layoutUI.interfacePage
    if not page or not page.Parent then return end
    local old=page:FindFirstChild("TestBuildVersionRow")
    if old then old:Destroy()end
    local row=Instance.new("Frame")
    row.Name="TestBuildVersionRow"
    row.Size=UDim2.new(1,-4,0,28)
    row.LayoutOrder=999
    row.BackgroundColor3=Color3.fromRGB(24,25,32)
    row.BackgroundTransparency=0.22
    row.BorderSizePixel=0
    row.Parent=page
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,8)
    corner.Parent=row
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(142,118,255)
    stroke.Transparency=0.72
    stroke.Thickness=1
    stroke.Parent=row
    local caption=Instance.new("TextLabel")
    caption.Name="Caption"
    caption.BackgroundTransparency=1
    caption.Position=UDim2.fromOffset(10,0)
    caption.Size=UDim2.new(0.45,-10,1,0)
    caption.Font=Enum.Font.GothamMedium
    caption.TextSize=9
    caption.TextXAlignment=Enum.TextXAlignment.Left
    caption.TextColor3=Color3.fromRGB(145,147,160)
    caption.Text="TEST BUILD"
    caption.Parent=row
    local value=Instance.new("TextLabel")
    value.Name="Version"
    value.BackgroundTransparency=1
    value.Position=UDim2.new(0.45,0,0,0)
    value.Size=UDim2.new(0.55,-10,1,0)
    value.Font=Enum.Font.GothamBold
    value.TextSize=9
    value.TextXAlignment=Enum.TextXAlignment.Right
    value.TextColor3=Color3.fromRGB(194,184,255)
    value.Text=VERSION
    value.Parent=row
end)
return runtime
