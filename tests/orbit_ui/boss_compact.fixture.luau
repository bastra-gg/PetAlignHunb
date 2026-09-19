-- RockBugHub TEST T56 flicker fix: BossCompact no longer competes with StableFarmCards for the main boss card.
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local q=env.RockBugRuntime
if type(q)~="table"then return end

if env.RockBugBossCompact and type(env.RockBugBossCompact.Destroy)=="function"then pcall(env.RockBugBossCompact.Destroy)end
local state={alive=true,lastCount=-1,history={},lastCard=nil}
env.RockBugBossCompact=state
q.bossCompactUI=state

local function ru()return q.language~="en"end
local function short(text,max)
 text=tostring(text or""):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
 max=max or 42
 if #text>max then return text:sub(1,max-1).."…"end
 return text
end
local function copyItems(src)
 local out={}
 if type(src)=="table"then for i,v in ipairs(src)do out[i]=tostring(v)end end
 return out
end
local function rememberLoot()
 local win=tonumber(q.bossLootCount)or 0
 if win==state.lastCount then return end
 state.lastCount=win
 if win<=0 then return end
 local items=copyItems(q.bossLootItems)
 local entry={
  win=win,
  chest=tostring(q.bossLootChest or"Boss Chest"),
  items=items,
  itemCount=tonumber(q.bossLootItemCount)or#items,
  text=tostring(q.bossLootReport or q.bossLootChest or"Boss Chest"),
 }
 table.insert(state.history,1,entry)
 while #state.history>5 do table.remove(state.history)end
end
local function reportMessage()
 local latest=state.history[1]
 if not latest then return ru()and"БОСС: наград ещё нет"or"BOSS: no rewards yet"end
 if #latest.items>0 then
  return (ru()and"ПОСЛЕДНЯЯ ПОБЕДА • "or"LAST WIN • ")..tostring(#latest.items)..(ru()and" наград: "or" rewards: ")..table.concat(latest.items," • ")
 end
 return (ru()and"ПОСЛЕДНЯЯ ПОБЕДА • "or"LAST WIN • ")..latest.chest
end

local function patchDetailedBossPage()
 local refs=q.leverRefs or{}
 local cycle=refs.bossCycle
 if type(cycle)=="table"then
  if cycle.NameLabel and cycle.NameLabel.Parent then cycle.NameLabel.Text=ru()and"АВТОБОСС"or"AUTOBOSS"end
  if cycle.DescriptionLabel and cycle.DescriptionLabel.Parent then cycle.DescriptionLabel.Text=ru()and"в фоне • бой → сундук → возврат"or"background • fight → chest → return"end
 end
 local page=q.layoutUI and q.layoutUI.bossPage
 if not page then return end
 for _,obj in ipairs(page:GetDescendants())do
  if obj:IsA("TextButton")and obj.Name=="BossLaunchButton"then obj.Visible=false
  elseif obj:IsA("TextLabel")then
   local t=tostring(obj.Text or"")
   if t=="БОСС И НАГРАДЫ"then obj.Text=ru()and"АВТОБОСС"or"AUTOBOSS"end
  end
 end
end

local function bindCard(card)
 if not card or state.lastCard==card then return end
 state.lastCard=card
 if card.more then
  card.more.callback=function()
   local holo=q.hologram
   if holo and type(holo.Notify)=="function"then holo:Notify(reportMessage())end
  end
 end
end

-- IMPORTANT: StableFarmCards is the sole writer for the visible main boss card.
-- BossCompact only binds the loot-details callback and patches the detailed boss page.
local function bindMainCardOnly()
 local holo=q.hologram
 if type(holo)~="table"or holo.destroyed then return end
 local cards=holo.cards
 local card=type(cards)=="table"and cards[4]or nil
 if card then bindCard(card)end
end

task.spawn(function()
 while state.alive and q.alive do
  rememberLoot()
  patchDetailedBossPage()
  bindMainCardOnly()
  task.wait(0.5)
 end
end)

function state.Destroy()
 state.alive=false
 if env.RockBugBossCompact==state then env.RockBugBossCompact=nil end
 if q.bossCompactUI==state then q.bossCompactUI=nil end
end

rememberLoot()
patchDetailedBossPage()
bindMainCardOnly()
return state
