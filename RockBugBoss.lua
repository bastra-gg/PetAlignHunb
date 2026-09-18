-- RockBug Boss paid loader v1.6
-- Keeps the paid autoboss UI/access core, but replaces its legacy reward collection with the proven standalone v3 prompt path.
-- v1.6: the minimized RB button is placed on the reachable right side of the screen.
local CORE_URL="https://szfjrpkdbccsveklkwyy.supabase.co/functions/v1/rb-bootstrap?r=d12a6f9347bc508e19c2e6a1"
local REWARD_URL="https://szfjrpkdbccsveklkwyy.supabase.co/functions/v1/rb-bootstrap?r=6ec0a18f5db29743c84e10f2"
local REWARD_CONTRACT="-- RockBug Boss paid reward collector v3 contract: 1"
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local compiler=loadstring or env.loadstring
if type(compiler)~="function"then error("RockBug Boss: executor has no loadstring",0)end

local function get(url)
 local stamp="&v=paid-1.6-"..tostring(os.time()).."-"..tostring(math.random(100000,999999))
 local ok,body=pcall(function()return game:HttpGet(url..stamp,true)end)
 if ok and type(body)=="string"then return body end
 error("RockBug Boss: download failed • "..tostring(body),0)
end

local coreSource=get(CORE_URL)
local coreChunk,coreProblem=compiler(coreSource)
if type(coreChunk)~="function"then error("RockBug Boss core compile: "..tostring(coreProblem),0)end
local okCore,runtime=pcall(coreChunk)
if not okCore then error("RockBug Boss core start: "..tostring(runtime),0)end
if type(runtime)~="table"or runtime.alive~=true then error("RockBug Boss: core did not start",0)end

-- Keep the minimize/restore button within thumb reach on mobile.
pcall(function()
 local player=game:GetService("Players").LocalPlayer
 local pg=player and player:FindFirstChildOfClass("PlayerGui")
 local gui=pg and pg:FindFirstChild("RockBugBossStandalone")
 if not gui then return end
 local mini,minimize
 for _,obj in ipairs(gui:GetDescendants())do
  if obj:IsA("TextButton")then
   if obj.Text=="RB" and obj.Size.X.Offset<=64 then mini=obj end
   if obj.Text=="−" then minimize=obj end
  end
 end
 if not mini or not minimize then return end
 local function placeMini()
  if not mini.Parent then return end
  local camera=workspace.CurrentCamera
  local vp=camera and camera.ViewportSize or Vector2.new(800,600)
  local w=mini.AbsoluteSize.X>0 and mini.AbsoluteSize.X or 48
  local h=mini.AbsoluteSize.Y>0 and mini.AbsoluteSize.Y or 48
  mini.Position=UDim2.fromOffset(math.max(4,vp.X-w-14),math.max(4,math.floor(vp.Y*0.46-h*0.5)))
 end
 local function keep(conn)
  if type(runtime.connections)=="table"then table.insert(runtime.connections,conn)end
 end
 keep(minimize.Activated:Connect(function()
  task.defer(function()if mini.Parent and mini.Visible then placeMini()end end)
 end))
 local camera=workspace.CurrentCamera
 if camera then
  keep(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
   if mini.Parent and mini.Visible then placeMini()end
  end))
 end
end)

local rewardSource=get(REWARD_URL)
if not rewardSource:find(REWARD_CONTRACT,1,true)then
 runtime.rewardsEnabled=false
 error("RockBug Boss: wrong reward module",0)
end
local rewardChunk,rewardProblem=compiler(rewardSource)
if type(rewardChunk)~="function"then
 runtime.rewardsEnabled=false
 error("RockBug Boss reward compile: "..tostring(rewardProblem),0)
end
local okReward,rewardState=pcall(rewardChunk)
if not okReward or type(rewardState)~="table"or rewardState.startupReady~=true then
 runtime.rewardsEnabled=false
 error("RockBug Boss reward start: "..tostring(rewardState),0)
end
runtime.paidRewardV3=rewardState
return runtime