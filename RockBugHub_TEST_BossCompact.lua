-- RockBugHub TEST T43: one background autoboss + compact loot report
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local q=env.RockBugRuntime
if type(q)~="table"then return end

if env.RockBugBossCompact and type(env.RockBugBossCompact.Destroy)=="function"then pcall(env.RockBugBossCompact.Destroy)end
local state={alive=true,lastCount=-1,history={},lastHologram=nil,lastCard=nil}
env.RockBugBossCompact=state
q.bossCompactUI=state

local function ru()return q.language~="en"end
local function short(text,max)
 text=tostring(text or""):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
 max=max or 42
 if #text>max then return text:sub(1,max-1).."…"end
 return text
end
local function cycleOn()
 return q.bossCycle and q.bossCycle.enabled==true
end
local function lootText()
 local text=q.bossLootReport
 if not text or text==""then return ru()and"пока нет"or"none yet"end
 return short(text,38)
end
local function rememberLoot()
 local count=tonumber(q.bossLootCount)or 0
 if count==state.lastCount then return end
 state.lastCount=count
 if count<=0 then return end
 local item={count=count,text=tostring(q.bossLootReport or q.bossLootChest or"Boss Chest"),chest=tostring(q.bossLootChest or"Boss Chest")}
 table.insert(state.history,1,item)
 while #state.history>5 do table.remove(state.history)end
end
local function reportMessage()
 if #state.history==0 then return ru()and"БОСС: наград ещё нет"or"BOSS: no rewards yet"end
 local out={}
 for i=1,math.min(3,#state.history)do out[#out+1]=short(state.history[i].text,54)end
 return (ru()and"ЛУТ: "or"LOOT: ")..table.concat(out,"  |  ")
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
   local msg=reportMessage()
   if holo and type(holo.Notify)=="function"then holo:Notify(msg)end
  end
 end
end
local function patchMainCard()
 local holo=q.hologram
 if type(holo)~="table"or holo.destroyed then return end
 local cards=holo.cards
 local card=type(cards)=="table"and cards[4]or nil
 if not card then return end
 bindCard(card)
 if card.primary and card.primary.text then card.primary.text.Text=ru()and"Автобосс"or"Autoboss"end
 if card.state then
  card.state.Text=cycleOn()and(ru()and"ВКЛ"or"ON")or(ru()and"ВЫКЛ"or"OFF")
 end
 if card.hint then
  local status=tostring(q.bossCycleStatus or"")
  if status==""then status=cycleOn()and(ru()and"Работает в фоне"or"Running in background")or(ru()and"Выключен"or"Off")end
  card.hint.Text=short(status,48)
 end
 if card.more and card.more.text then
  card.more.text.Text=(ru()and"Лут: "or"Loot: ")..lootText()
 end
end

-- Main card already toggles bossCycle. The manual combat-only launch is hidden,
-- so there is only one visible boss mode and it is always the background cycle.
task.spawn(function()
 while state.alive and q.alive do
  rememberLoot()
  patchDetailedBossPage()
  patchMainCard()
  task.wait(0.22)
 end
end)

function state.Destroy()
 state.alive=false
 if env.RockBugBossCompact==state then env.RockBugBossCompact=nil end
 if q.bossCompactUI==state then q.bossCompactUI=nil end
end

rememberLoot()
patchDetailedBossPage()
patchMainCard()
return state