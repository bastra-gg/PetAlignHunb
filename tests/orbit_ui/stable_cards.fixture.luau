-- RockBugHub TEST T51: one owner for FARM card captions; no caption flicker.
local env=_G
if type(getgenv)=="function"then local ok,v=pcall(getgenv)if ok and type(v)=="table"then env=v end end
local q=env.RockBugRuntime
if type(q)~="table"then return end
if env.RockBugStableFarmCards and type(env.RockBugStableFarmCards.Destroy)=="function"then pcall(env.RockBugStableFarmCards.Destroy)end

local state={alive=true,locks={},connections={}}
env.RockBugStableFarmCards=state
q.stableFarmCards=state

local function ru()return q.language~="en"end
local function compact(v)
 v=tonumber(v)if not v then return "—"end
 local a=math.abs(v)
 for _,u in ipairs({{1e15,"Q"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}})do
  if a>=u[1]then local s=("%.2f%s"):format(v/u[1],u[2]);return s:gsub("%.00([KMBTQ])$","%1"):gsub("(%.[0-9])0([KMBTQ])$","%1%2")end
 end
 return tostring(math.floor(v+0.5))
end
local function rockName()
 local r=q.selectedRock
 if not r then return "—"end
 if q.layoutUI and type(q.layoutUI.rockName)=="function"then local ok,n=pcall(q.layoutUI.rockName,r);if ok and type(n)=="string"and n~=""then return n end end
 return tostring(r.label or r.en or r.id or"—")
end
local function machineName(m)
 if not m then return "—"end
 local base=tostring(m.label or m.name or m.kind or"Тренажёр")
 local v=tostring(m.variant or m.explicitVariant or"")
 if v~=""and not string.lower(base):find(string.lower(v),1,true)then base=base.." • "..v end
 return base
end

-- T38 rewrites card strings every 0.5s. Lock the final caption synchronously,
-- instead of repainting from several patches on different timers.
local function desired(node,text)
 if not node or not node.Parent then return end
 local lock=state.locks[node]
 if not lock then
  lock={node=node,value=text,busy=false}
  state.locks[node]=lock
  lock.connection=node:GetPropertyChangedSignal("Text"):Connect(function()
   if not state.alive or lock.busy or not node.Parent then return end
   if node.Text~=lock.value then lock.busy=true node.Text=lock.value lock.busy=false end
  end)
  table.insert(state.connections,lock.connection)
 else
  lock.value=text
 end
 if node.Text~=text then lock.busy=true node.Text=text lock.busy=false end
end

local function update()
 local holo=q.hologram
 if type(holo)~="table"or holo.destroyed or holo.group~="farm"or type(holo.cards)~="table"then return end
 local isRu=ru()

 local rock=holo.cards[1]
 if rock then
  desired(rock.primary and rock.primary.text,isRu and"Автоудар"or"Auto punch")
  desired(rock.more and rock.more.text,isRu and"Выбрать камень  →"or"Choose rock  →")
  local d=q.adaptiveRockDurability
  local mode=q.adaptiveRockAuto==false and(isRu and"ВРУЧНУЮ"or"MANUAL")or(isRu and"АВТО"or"AUTO")
  desired(rock.hint,d and(mode.." • "..compact(d).." • "..rockName())or(mode.." • "..(isRu and"долговечность не найдена"or"durability not found")))
 end

 local machine=holo.cards[2]
 if machine then
  desired(machine.primary and machine.primary.text,isRu and"Автотренажёр"or"Auto machine")
  desired(machine.more and machine.more.text,isRu and"Залы и тренажёры  →"or"Gyms & machines  →")
  local m=q.selectedMachine
  local mode=q.adaptiveMachineAuto==true and(isRu and"АВТО"or"AUTO")or(isRu and"ВРУЧНУЮ"or"MANUAL")
  local text=m and(mode.." • "..tostring(m.zone or"—").." • "..machineName(m))or(mode.." • "..(isRu and"тренажёр не выбран"or"machine not selected"))
  desired(machine.hint,text)
 end

 local training=holo.cards[3]
 if training then
  -- Leave the untouched training card exactly as the base UI defines it.
 end

 local boss=holo.cards[4]
 if boss then
  desired(boss.primary and boss.primary.text,isRu and"Автобосс"or"Autoboss")
  local itemCount=tonumber(q.bossLootItemCount)or 0
  local loot=itemCount>0 and(tostring(itemCount)..(isRu and" наград"or" rewards"))or(isRu and"пока нет"or"none yet")
  desired(boss.more and boss.more.text,(isRu and"Лут: "or"Loot: ")..loot.."  →")
  local status=tostring(q.bossCycleStatus or"")
  if status==""then status=(q.bossCycle and q.bossCycle.enabled)and(isRu and"Работает в фоне"or"Running in background")or(isRu and"Выключен"or"Off")end
  desired(boss.hint,status)
 end
end

task.spawn(function()
 while state.alive and q.alive do update()task.wait(0.25)end
end)

function state.Destroy()
 if not state.alive then return end
 state.alive=false
 for _,c in ipairs(state.connections)do pcall(function()c:Disconnect()end)end
 state.connections={}state.locks={}
 if env.RockBugStableFarmCards==state then env.RockBugStableFarmCards=nil end
 if q.stableFarmCards==state then q.stableFarmCards=nil end
end

update()
return state

