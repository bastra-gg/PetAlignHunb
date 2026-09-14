-- RockBugHub TEST bootstrap T40: preserved T38 core + test patches
local VERSION="4.31HOLO-T40"
local CORE_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_v1_5_core.lua"
local BOSS_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_TEST_BossChestDirect.lua"
local ROCK_PATCH_URL="https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_TEST_AdaptiveRocks.lua"
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
local okBoss,problemBoss=pcall(function()run(BOSS_PATCH_URL,"direct chest patch")end)
if not okBoss then warn("[RockBugHub TEST "..VERSION.."] chest patch failed: "..tostring(problemBoss))end
local okRock,problemRock=pcall(function()run(ROCK_PATCH_URL,"adaptive rocks patch")end)
if not okRock then warn("[RockBugHub TEST "..VERSION.."] adaptive rocks patch failed: "..tostring(problemRock))end
pcall(function()
    local pg=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local stop=nil
    for _=1,30 do
        for _,obj in ipairs(pg:GetDescendants())do
            if obj:IsA("TextButton") then
                local t=tostring(obj.Text or""):gsub("%s+",""):upper()
                if t=="СТОП" or t=="STOP" then stop=obj break end
            end
        end
        if stop then break end
        task.wait(0.1)
    end
    if not stop or not stop.Parent then return end
    local parent=stop.Parent
    local old=parent:FindFirstChild("TestBuildBadge")
    if old then old:Destroy()end
    local badge=Instance.new("TextLabel")
    badge.Name="TestBuildBadge"
    badge.BackgroundColor3=Color3.fromRGB(31,35,46)
    badge.BackgroundTransparency=0.12
    badge.BorderSizePixel=0
    badge.Font=Enum.Font.GothamBold
    badge.Text="TEST • "..(VERSION:match("T%d+$")or VERSION)
    badge.TextColor3=Color3.fromRGB(194,184,255)
    badge.TextSize=8
    badge.ZIndex=math.max(1,stop.ZIndex)
    badge.Parent=parent
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,8)
    corner.Parent=badge
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(142,118,255)
    stroke.Transparency=0.62
    stroke.Thickness=1
    stroke.Parent=badge
    local function place()
        if not badge.Parent or not stop.Parent then return end
        local p=parent.AbsolutePosition
        local s=stop.AbsolutePosition
        local h=math.max(22,math.min(28,stop.AbsoluteSize.Y-2))
        local w=60
        badge.Size=UDim2.fromOffset(w,h)
        badge.Position=UDim2.fromOffset(math.floor(s.X-p.X-w-7),math.floor(s.Y-p.Y+(stop.AbsoluteSize.Y-h)/2))
    end
    place()
    stop:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
    stop:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
    parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
end)
return runtime
