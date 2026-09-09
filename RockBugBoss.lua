-- RockBug Boss 1.2: standalone UI + account-bound access.
-- Shares under-arena combat, a safe exit to the surface, strength warmup and the chest cycle with the test hub.
-- A client-side Lua gate is not tamper-proof DRM. UserId alone never grants access.
if not game:IsLoaded() then game.Loaded:Wait() end
local a,b,c = game:GetService("Players"),game:GetService("ReplicatedStorage"),game:GetService("RunService")
local input,http = game:GetService("UserInputService"),game:GetService("HttpService")
local j=a.LocalPlayer
while not j do task.wait() j=a.LocalPlayer end
local pg=j:WaitForChild("PlayerGui",60)
if not pg then return end
local env=_G
if type(getgenv)=="function" then local ok,v=pcall(getgenv) if ok and type(v)=="table" then env=v end end
if env.RockBugBossStandalone and type(env.RockBugBossStandalone.Destroy)=="function" then env.RockBugBossStandalone:Destroy() end
local q={alive=true,killMode="off",connections={},punchCycle=0,directRemoteEnabled=true,remoteSentWindow=0,remoteWindowStart=os.clock(),equipInFlight=false,networkPaused=false,authorized=false,rewardsEnabled=true}
env.RockBugBossStandalone=q
local function B(fn) return pcall(fn) end
local function aM() return j.Character end
local function aN() local ch=aM() return ch and ch:FindFirstChildWhichIsA("Humanoid") end
local function aO() local ch=aM() return ch and ch:FindFirstChild("HumanoidRootPart") end
local function aJ(conn) table.insert(q.connections,conn) return conn end
local function jT() if q.boss then q.boss:Stop(nil,true) end end
local function cN(cO)return tostring(cO and cO.Name or""):lower()end;
local function cP(bP,cQ)bP=tostring(bP or""):lower()for o,cR in ipairs(cQ)do if bP:find(tostring(cR):lower(),1,true)then return true end end;
return false end;
q.punchWords={"punch","fist","combat","кулак","удар"}q.trainWords={"weight","dumb","barbell","bench","push","sit","handstand","tread","гант","гир","штанг","отжим","пресс","бег"}local function cU(cO)if not cO or not cO:IsA("Tool")then return false end;
local bS=cN(cO)if cP(bS,q.trainWords)then return false end;
if cP(bS,q.punchWords)then return true end;
for o,bn in ipairs(cO:GetDescendants())do if cP(bn.Name,q.trainWords)then return false end;
if cP(bn.Name,q.punchWords)then return true end end;
return false end;

local function cY(cZ)local aK=aM()local aC=j:FindFirstChildOfClass("Backpack")if aK then for o,cO in ipairs(aK:GetChildren())do if cO:IsA("Tool")and cZ(cO)then return cO,true end end end;
if aC then for o,cO in ipairs(aC:GetChildren())do if cO:IsA("Tool")and cZ(cO)then return cO,false end end end;
return nil,false end;
local function c_(cO)if not cO then return false end;
local aK=aM()local d0=aN()if not aK or not d0 then return false end;
if cO.Parent==aK then return true end;
local d1=os.clock()+0.45;
while q.equipInFlight do if os.clock()>=d1 then return false end;
task.wait(0.015)end;
if cO.Parent==aK then return true end;
q.equipInFlight=true;
local d2=false;
local D=B(function()d0:EquipTool(cO)if cO.Parent~=aK then task.wait(0.025)end;
if cO.Parent~=aK then d0:UnequipTools()task.wait(0.015)d0:EquipTool(cO)if cO.Parent~=aK then task.wait(0.035)end end;
d2=cO.Parent==aK end)q.equipInFlight=false;
return D and d2 end;
q.cooldownFields={"Cooldown","cooldown","CD","cd","Delay","delay","AttackCooldown","attackCooldown","SwingCooldown","swingCooldown","AttackTime","attackTime","PunchCooldown","punchCooldown","LastUse","lastUse","LastSwing","lastSwing","LastAttack","lastAttack","CanUse","canUse","CanSwing","canSwing","Ready","ready"}local function d4(cO)if not cO then return end;
B(function()cO.Enabled=true end)local function d5(bg)for o,u in ipairs(q.cooldownFields)do local R=bg:FindFirstChild(u)if R then B(function()if R:IsA("NumberValue")or R:IsA("IntValue")then R.Value=0 end;
if R:IsA("BoolValue")then R.Value=true end;
if R:IsA("StringValue")then R.Value="0"end end)end;
B(function()local be=bg:GetAttribute(u)if be~=nil then if type(be)=="number"then bg:SetAttribute(u,0)end;
if type(be)=="boolean"then bg:SetAttribute(u,true)end;
if type(be)=="string"then bg:SetAttribute(u,"0")end end end)end end;
d5(cO)for o,bn in ipairs(cO:GetDescendants())do d5(bn)end end;
local function d6()return cY(cU)end;

local function dj()local cO,d2=d6()if not cO then return nil,"Punch Tool не найден"end;
if not d2 and not c_(cO)then return nil,"не удалось надеть Punch"end;
return cO,"Punch: "..cO.Name end;

local function eg()local aj=j:FindFirstChild("muscleEvent")if aj and aj:IsA("RemoteEvent")then return aj end;
local I=b:FindFirstChild("rEvents")local eh=I and I:FindFirstChild("muscleEvent")if eh and eh:IsA("RemoteEvent")then return eh end;
return nil end;
local function ei()local b6=os.clock()local b9=b6-q.remoteWindowStart;
if b9>=1 then q.remotePps=q.remoteSentWindow/b9;
q.remoteSentWindow=0;
q.remoteWindowStart=b6 end end;

-- The first direct punch path is preserved; failed sends are not burst-retried.
local function ek() return false end

local purple=Color3.fromRGB(169,131,255)
local white=Color3.fromRGB(241,235,255)
local muted=Color3.fromRGB(158,146,181)
local function make(class,parent,props)
    local obj=Instance.new(class)
    for key,value in pairs(props or {}) do obj[key]=value end
    obj.Parent=parent return obj
end
local function round(obj,radius) make("UICorner",obj,{CornerRadius=UDim.new(0,radius or 12)}) end
local function outline(obj,color,alpha) return make("UIStroke",obj,{Color=color or purple,Transparency=alpha or 0.65,Thickness=1}) end
local gui=make("ScreenGui",pg,{Name="RockBugBossStandalone",ResetOnSpawn=false,DisplayOrder=999990,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=false})
local window=make("Frame",gui,{Size=UDim2.fromOffset(348,302),Position=UDim2.fromOffset(30,80),BackgroundColor3=Color3.fromRGB(20,16,30),BackgroundTransparency=0.08,BorderSizePixel=0,ClipsDescendants=true})
round(window,18) outline(window,purple,0.42)
local scale=make("UIScale",window,{Scale=1})
make("Frame",window,{Size=UDim2.new(1,-34,0,2),Position=UDim2.fromOffset(17,0),BackgroundColor3=purple,BorderSizePixel=0})
local header=make("Frame",window,{Size=UDim2.new(1,0,0,62),BackgroundTransparency=1,Active=true})
local function label(parent,text,x,y,w,h,size,color)
    return make("TextLabel",parent,{Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=color or white,TextSize=size or 14,Font=Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
end
label(header,"RB",18,16,30,28,18,purple)
label(header,"BOSS",59,14,180,23,20)
label(header,"ROCKBUG",60,37,160,14,10,muted)
local function button(parent,text,x,y,w,h,bg)
    local o=make("TextButton",parent,{Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=bg or Color3.fromRGB(39,30,54),TextColor3=white,TextSize=14,Font=Enum.Font.GothamBold,BorderSizePixel=0,AutoButtonColor=true})
    round(o,10) return o
end
local minimize=button(header,"−",260,17,30,30)
local close=button(header,"×",298,17,30,30)
local mini=button(gui,"RB",30,80,48,48,Color3.fromRGB(28,20,42))
outline(mini,purple,0.2) mini.Visible=false
local content=make("Frame",window,{Size=UDim2.fromOffset(312,215),Position=UDim2.fromOffset(18,66),BackgroundTransparency=1,Visible=false})
local account=label(content,"@"..j.Name,0,0,308,22,12,muted)
local status=label(content,"Выключено",0,30,300,28,19)
local targetText=label(content,"Автоматический поиск босса",0,64,300,22,13,muted)
local start=button(content,"Запустить",0,100,312,46,purple)
start.TextColor3=Color3.fromRGB(24,13,40)
local reward=button(content,"Награды автоматически",0,158,312,39,Color3.fromRGB(31,23,45))
reward.TextXAlignment=Enum.TextXAlignment.Left
make("UIPadding",reward,{PaddingLeft=UDim.new(0,12)})
local rewardStroke=outline(reward,purple,0.18)
local rewardKnob=make("Frame",reward,{Position=UDim2.new(1,-48,0,10),Size=UDim2.fromOffset(34,19),BackgroundColor3=purple,BorderSizePixel=0})
round(rewardKnob,20)
local rewardDot=make("Frame",rewardKnob,{Position=UDim2.fromOffset(17,3),Size=UDim2.fromOffset(13,13),BackgroundColor3=white,BorderSizePixel=0}) round(rewardDot,20)
local gate=make("Frame",window,{Size=content.Size,Position=content.Position,BackgroundTransparency=1})
label(gate,"Доступ к аккаунту",0,0,310,30,19)
label(gate,"@"..j.Name,0,33,310,20,13,purple)
local keyInput=make("TextBox",gate,{Size=UDim2.fromOffset(312,42),Position=UDim2.fromOffset(0,67),BackgroundColor3=Color3.fromRGB(32,25,45),PlaceholderText="Вставь ключ",Text="",ClearTextOnFocus=false,TextSize=13,TextColor3=white,PlaceholderColor3=muted,Font=Enum.Font.Gotham,BorderSizePixel=0})
round(keyInput,10) outline(keyInput,purple,0.5)
local unlock=button(gate,"Активировать",0,119,312,42,purple) unlock.TextColor3=Color3.fromRGB(24,13,40)
local gateNote=label(gate,"Ключ нужен только при первом входе",0,170,312,39,12,muted)
gateNote.TextWrapped=true gateNote.TextTruncate=Enum.TextTruncate.None
local cachePath="RockBugBoss_"..tostring(j.UserId)..".key"
local license=nil
local httpBusy=false
local endpoint="https://szfjrpkdbccsveklkwyy.supabase.co/functions/v1/rockbug-boss-keys"
local sessionEndpoint="https://szfjrpkdbccsveklkwyy.supabase.co/functions/v1/rockbug-online"
local sessionHeaders={["x-rockbug-key"]="b071080d347e5e9aac86deaa4f0567b3ca04f0048aa945761d1c2f31121ed5ae"}
local sessionId=http:GenerateGUID(false)
local function post(url,payload,extra)
    local requestFn=request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (env.http and env.http.request)
    local body=http:JSONEncode(payload)
    local headers={["Content-Type"]="application/json"}
    for key,value in pairs(extra or {}) do headers[key]=value end
    local ok,response=pcall(function()
        if type(requestFn)=="function" then return requestFn({Url=url,Method="POST",Headers=headers,Body=body,Timeout=12}) end
        return game:HttpPost(url,body,"application/json")
    end)
    if not ok then return nil end
    local raw=type(response)=="table" and (response.Body or response.body) or response
    if type(raw)~="string" or #raw>65536 then return nil end
    local good,decoded=pcall(function() return http:JSONDecode(raw) end)
    return good and type(decoded)=="table" and decoded or nil
end
local function saveKey(value)
    env.RockBugBossKeys=env.RockBugBossKeys or {}
    env.RockBugBossKeys[tostring(j.UserId)]=value
    if type(writefile)=="function" then return pcall(writefile,cachePath,value) end
    return false
end
local function checkKey(value,redeem)
    return post(endpoint,{action=redeem and "redeem" or "check",key=value,user_id=j.UserId,user_name=j.Name})
end
local errors={invalid="Ключ не подходит",bound="Этот ключ привязан к другому аккаунту",expired="Срок доступа истёк",revoked="Доступ отозван владельцем",rate_limit="Слишком часто. Подожди минуту"}
local function showGate(reason)
    q.authorized=false
    if q.bossCycle then q.bossCycle:Cancel(false)end
    if q.boss then q.boss:Stop(nil,true) end
    content.Visible=false gate.Visible=true gateNote.Text=reason
end
local function activate(value,redeem)
    if httpBusy or not q.alive then return end
    value=tostring(value or ""):gsub("%s",""):upper()
    if value=="" then gateNote.Text="Вставь выданный ключ" return end
    httpBusy=true unlock.Text="Проверяю…" unlock.Active=false
    task.spawn(function()
        local result=checkKey(value,redeem)
        httpBusy=false
        if not q.alive then return end
        unlock.Text="Активировать" unlock.Active=true
        if result and result.ok and tonumber(result.user_id)==j.UserId then
            license=value q.authorized=true q.lastKeyCheck=os.clock()
            local persisted=saveKey(value)
            gate.Visible=false content.Visible=true keyInput.Text=""
            account.Text="@"..j.Name..(persisted and "  ·  доступ сохранён" or "  ·  вход на эту сессию")
        else
            gateNote.Text=result and (errors[result.error] or "Сервис недоступен. Попробуй снова") or "Нет связи. Попробуй снова"
        end
    end)
end
aJ(unlock.Activated:Connect(function() activate(keyInput.Text,true) end))
aJ(keyInput.FocusLost:Connect(function(enter) if enter then activate(keyInput.Text,true) end end))

local function ca()
    local groups={j}
    local stats=j:FindFirstChild("leaderstats")
    if stats then table.insert(groups,1,stats)end
    for _,group in ipairs(groups)do
        for _,node in ipairs(group:GetChildren())do
            local name=node.Name:lower():gsub("[%s_%-]","")
            if node:IsA("ValueBase") and (name=="strength" or name=="сила" or name=="musclepower")then
                local value=tonumber(node.Value)
                if value and value==value and value~=math.huge and value~=-math.huge then return math.max(0,value)end
            end
        end
    end
end
q.trainModes={{id="Weight",label="Гантель",words={"weight","dumbbell","dumb","barbell","гантел","гир","штанг"}}}
local function dk(mode)
    local tool,equipped=cY(function(item)
        return item:IsA("Tool") and cP(item.Name,mode.words)
    end)
    if not tool then return nil,"Гантель не найдена — жду перед вылетом"end
    if not equipped and not c_(tool)then return nil,"Не удалось взять гантель"end
    return tool
end
local function em()
    if not q.alive or not q.authorized or q.networkPaused or q.remotePaused then return false end
    local remote=eg()
    if not remote then return false end
    local ok=pcall(function()remote:FireServer("rep")end)
    if ok then q.remoteSentWindow+=1 ei()end
    return ok
end

q.bossFactory=(function()
-- TEST ONLY: ordinary Punch/touch adapter, not a verified new-boss protocol.
-- This module never changes the boss, another player, or server health values.
return function(runtime, api)
    local state = {
        enabled = false, generation = 0, target = nil,
        height = 8, interval = 0.01, status = "Выключено", candidates = {},
        nextScan = 0, nextAttack = 0, nextUI = 0, retryAt = 0, noProgress = 0,
        lastTargetHealth = nil, lastOwnHealth = nil, lastBossDamage = nil, damageStart = nil, lastTick = nil,
        attempts = 0, observations = 0, damageEvents = 0, busy = false,
        personalDamage = {total = 0, samples = {}, available = false},
    }
    -- Read-only telemetry. Neither HP loss nor sent punch requests count as personal damage.
    function state:ObservePersonalDamage(value, source, now, target)
        local meter = self.personalDamage
        if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
            meter.available = false
            meter.previous = nil
            return
        end
        source = source or "personal-boss-damage"
        local changed = meter.target ~= target or meter.source ~= source
        if changed then
            meter.previous = nil
            meter.samples = {}
            meter.lastHitAt, meter.lastDelta = nil, nil
        end
        meter.available, meter.source, meter.target = true, source, target
        if meter.previous == nil or value < meter.previous then
            meter.previous = value
            meter.since = now
            meter.samples = {}
            meter.lastHitAt, meter.lastDelta = nil, nil
            return
        end
        local delta = value - meter.previous
        meter.previous = value
        if delta > 0 then
            meter.total += delta
            meter.lastHitAt, meter.lastDelta = now, delta
            table.insert(meter.samples, {at = now, amount = delta})
        end
        while meter.samples[1] and now - meter.samples[1].at >= 5 do table.remove(meter.samples, 1) end
    end
    function state:PersonalDamageReadout(now)
        local meter = self.personalDamage
        local recent = 0
        for _, bucket in ipairs(meter.samples) do
            if now - bucket.at < 5 then recent += bucket.amount end
        end
        local age = meter.lastHitAt and math.max(0, now - meter.lastHitAt) or nil
        local status = not self.enabled and "stopped"
            or runtime.networkPaused and "paused"
            or not self.target and "waiting"
            or not meter.available and "unavailable"
            or age and age < 3 and "confirmed"
            or (now - (meter.lastHitAt or meter.since or now) >= 3) and "stale" or "checking"
        return {total = meter.total, recent = recent, available = meter.available,
            age = age, lastDelta = meter.lastDelta, status = status}
    end
    local function show(message)
        state.status = message
        if runtime.refreshBossUI then runtime.refreshBossUI() end
    end
    function state:Stop(message, retreat)
        local wasEnabled = self.enabled
        self.enabled = false
        self.generation += 1
        if wasEnabled then pcall(api.release, retreat == true) end
        self.target = nil
        self.warming = false
        if api.stopTraining then api.stopTraining() end
        self.lastTick = nil
        if runtime.leverRefs and runtime.leverRefs.boss then
            runtime.leverRefs.boss.Set(false, true)
        end
        if message then show(message) end
    end
    function state:Scan()
        local list = api.scan()
        self.candidates = list
        self.nextScan = api.now() + 3
        return list
    end
    function state:Start()
        if self.enabled or not runtime.alive then return self.enabled end
        local health = api.ownHealth()
        api.prepare()
        if not runtime.alive then return false end
        self.generation += 1
        self.enabled = true
        self.nextScan = 0
        self.nextAttack = 0
        self.nextTraining = 0
        self.warming = false
        self.engagedTarget = nil
        self.lastTick = nil
        self.lastOwnHealth = health and health > 0 and health or nil
        self.retryAt = 0
        self.attempts = 0
        self.observations = 0
        self.damageEvents = 0
        self.height = 8
        self.lastBossDamage = nil
        self.damageStart = nil
        self.personalDamage = {total = 0, samples = {}, available = false}
        show(health and health > 0 and "Запущено — ищу текущего босса…" or "Запущено — жду персонажа и текущего босса…")
        return true
    end
    function state:Damage(health)
        if not self.enabled then return end
        if self.lastOwnHealth and health < self.lastOwnHealth then
            self.damageEvents += 1
            self.height = math.min(12, self.height + 1)
            show(("Получен урон • опускаюсь чуть глубже: %.2f"):format(self.height))
        end
        self.lastOwnHealth = health
    end
    local function readBossDamage()
        if not api.damage then return nil end
        local ok, value, source = pcall(api.damage)
        return ok and type(value) == "number" and value or nil, source
    end
    local function step(now)
        if not state.enabled then return end
        if not runtime.alive then state:Stop(nil, false) return end
        if api.conflict() then
            state:Stop("Стоп: включён другой режим боя/перемещения", false)
            return
        end
        local ownHealth = api.ownHealth()
        if not ownHealth or ownHealth <= 0 then
            api.release(false)
            state.target = nil
            state.lastOwnHealth = nil
            state.nextAttack = now + state.interval
            if state.status ~= "Автобосс включён — жду живого персонажа…" then
                show("Автобосс включён — жду живого персонажа…")
            end
            return
        end
        state:Damage(ownHealth)
        if not state.enabled then return end
        local dt = state.lastTick and math.clamp(now - state.lastTick, 0, 0.25) or 0
        state.lastTick = now
        if runtime.networkPaused then
            api.release(false)
            state.target = nil
            state.nextScan = 0
            state.nextAttack = now + state.interval
            if state.status ~= "Пауза сети — атаки не отправляются" then
                show("Пауза сети — атаки не отправляются")
            end
            return
        end
        -- The cycle owns this defeated boss until its chest has been opened.
        -- Never acquire another boss in the gap before the cycle's next tick.
        if api.awaitingReward and api.awaitingReward() then
            api.release(false)
            state.target = nil
            return
        end
        local strength = api.strength()
        if not strength or strength <= 0 then
            if not state.warming then api.release(true) end
            state.warming = true
            state.target = nil
            state.nextScan = 0
            state.nextAttack = now + state.interval
            show(strength == nil and "Жду счётчик силы — вылет приостановлен"
                or "Сила 0 — качаю гантель до прироста силы")
            if strength ~= nil and now >= state.nextTraining then
                state.nextTraining = now + 0.25
                local generation = state.generation
                local ok, reason = api.trainStrength(function()
                    return runtime.alive and state.enabled and state.generation == generation
                        and not runtime.networkPaused and not api.conflict()
                end)
                if state.generation ~= generation or not state.enabled then return end
                if ok == false then
                    state.nextTraining = now + 2
                    show(reason or "Жду гантель — вылет приостановлен")
                end
            end
            return
        end
        if state.warming then
            state.warming = false
            api.stopTraining()
            state.retryAt = 0
            state.nextScan = 0
        end
        if now < state.retryAt then return end
        local info = state.target and api.info(state.target)
        if not info or not info.alive then
            if state.target then
                api.release(true)
                state.target = nil
                state.nextScan = 0
            end
            if now >= state.nextScan then state:Scan() end
            for _, candidate in ipairs(state.candidates) do
                local current = api.info(candidate.model)
                if current and current.alive then
                    state.target = candidate.model
                    info = current
                    break
                end
            end
            if not state.target then
                if state.status ~= "Активный босс не найден — жду появления" then
                    show("Активный босс не найден — жду появления")
                end
                return
            end
            state.lastTargetHealth = info.health
            state.lastBossDamage = readBossDamage()
            state.damageStart = state.lastBossDamage
            state.noProgress = 0
            state.attempts = 0
            state.observations = 0
            state.nextAttack = now
            api.claim(function(health) state:Damage(health) end)
            if not state.enabled then return end
            show(info.name .. " найден — физически занимаю точку под ареной")
        end
        local progressed = info.healthKnown and state.lastTargetHealth and info.health < state.lastTargetHealth
        local bossDamage, damageSource = readBossDamage()
        state:ObservePersonalDamage(bossDamage, damageSource, now, state.target)
        if bossDamage and state.lastBossDamage and bossDamage > state.lastBossDamage then progressed = true end
        if progressed then
            state.observations += 1
            state.noProgress = 0
        elseif info.healthKnown or bossDamage ~= nil then
            state.noProgress += dt
        end
        state.lastTargetHealth = info.health
        state.lastBossDamage = bossDamage
        -- A decrease is only an observation: other players may also attack.
        if (info.healthKnown or bossDamage ~= nil) and state.noProgress >= 2.5 and state.attempts > 0 then
            state.noProgress = 0
            state.nextAttack = now
            show(("Урон не виден • догоняю босса по X/Z, глубина безопасная: %.2f"):format(state.height))
        end
        local positioned, positionProblem = api.hold(info, state.height, state.damageEvents)
        if positioned == false then
            show(positionProblem or "Ожидаю точку под боссом…")
            state.nextAttack = now + state.interval
            return
        end
        if now >= state.nextAttack then
            state.nextAttack = now + state.interval -- no catch-up bursts after lag
            local generation = state.generation
            local target = state.target
            local ok, reason = api.punch(info, function()
                return runtime.alive and state.enabled and state.generation == generation
                    and not runtime.networkPaused and state.target == target
            end)
            if state.generation ~= generation or not state.enabled then return end
            if ok == false then
                api.release(false)
                state.target = nil
                state.retryAt = now + 3
                state.nextScan = state.retryAt
                state.lastTick = nil
                show((reason or "Атака пока недоступна") .. " — повтор через 3 секунды")
                return
            end
            state.attempts += 1
            state.engagedTarget = target
        end
        if now >= state.nextUI then
            state.nextUI = now + 0.4
            local damageText = state.personalDamage.available and (" • мой урон +%s"):format(tostring(state.personalDamage.total)) or ""
            local depthText = (" • глубина: %.2f"):format(state.height)
            show(("%s • %s%s%s • %s"):format(info.name, info.modelName or info.model.Name, damageText, depthText,
                state.personalDamage.available and state.personalDamage.lastHitAt
                    and now - state.personalDamage.lastHitAt < 3 and "личный урон засчитывается"
                    or state.observations > 0 and "HP падает; мой урон не подтверждён" or "проверяю урон…"))
        end
    end
    function state:Tick(now)
        if self.busy or not self.enabled then return end
        self.busy = true
        local ok, problem = pcall(step, now)
        self.busy = false
        if not ok then
            self:Stop("Ошибка босса — отход и стоп: " .. tostring(problem):sub(1, 100), true)
        end
    end
    return state
end


end)()
-- Embedded after the core helpers; no new long-lived outer locals.
do
    local Players, World = a, workspace
    local saved = nil
    local knownBoss = setmetatable({}, {__mode = "k"})
    local knownMeta = setmetatable({}, {__mode = "k"})
    local hitCache = setmetatable({}, {__mode = "k"})
    q.bossFollowCache = setmetatable({}, {__mode = "k"})
    q.bossAnchorCache = setmetatable({}, {__mode = "k"})
    local bossDamageNode = nil
    local bossTitles = {
        commonboss = "COMMON BOSS", uncommonboss = "UNCOMMON BOSS", rareboss = "RARE BOSS",
        epicboss = "EPIC BOSS", legendaryboss = "LEGENDARY BOSS", mythicboss = "MYTHIC BOSS",
        mythicalboss = "MYTHICAL BOSS", uniqueboss = "UNIQUE BOSS",
    }
    local function normalized(value)
        return tostring(value or ""):lower():gsub("[^%w]", "")
    end
    local function bossTitle(value)
        return bossTitles[normalized(value)]
    end
    local function rootOf(model)
        return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
            or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
            or model:FindFirstChildWhichIsA("BasePart", true))
    end
    local function objectPosition(object)
        if not object then return nil end
        if object:IsA("Attachment") then return object.WorldPosition end
        if object:IsA("BasePart") then return object.Position end
        if object:IsA("Model") then return object:GetPivot().Position end
        return nil
    end
    local function replicatedHealth(model)
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then return humanoid, humanoid.Health, humanoid.MaxHealth, true end
        for _, node in ipairs(model:GetDescendants()) do
            local key = normalized(node.Name)
            if (key == "health" or key == "hp" or key == "bosshealth")
                and (node:IsA("NumberValue") or node:IsA("IntValue")) then
                return nil, node.Value, node.Value, true
            end
        end
        for _, key in ipairs({"Health", "HP", "BossHealth"}) do
            local value = model:GetAttribute(key)
            if type(value) == "number" then return nil, value, value, true end
        end
        return nil, 1, 1, false
    end
    local function isPlayerModel(model)
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character and (model == player.Character or model:IsDescendantOf(player.Character)) then return true end
        end
        return false
    end
    function q.bossMovingRootOf(model, fallback)
        local cached = q.bossFollowCache[model]
        if cached and cached.part and cached.part:IsDescendantOf(model)
            and (not cached.humanoid or cached.humanoid.Health > 0) and cached.untilAt > os.clock() then
            return cached.part, cached.humanoid, cached.body
        end
        -- A sign/PrimaryPart is never sufficient evidence of a living boss.
        -- Follow the rendered torso, which may move while HumanoidRootPart stays put.
        local best, bestHumanoid, bestBody, bestScore = nil, nil, nil, -math.huge
        local function consider(body, humanoid)
            if not body or isPlayerModel(body) then return end
            local ancestor = body
            while ancestor and ancestor ~= World do
                local key = normalized(ancestor.Name)
                if key:find("pet", 1, true) or key:find("preview", 1, true)
                    or key:find("template", 1, true) or key:find("reward", 1, true) then return end
                ancestor = ancestor.Parent
            end
            local part = body:FindFirstChild("LowerTorso") or body:FindFirstChild("Torso")
                or body:FindFirstChild("UpperTorso")
            if not part then
                local root = humanoid and humanoid.RootPart or body.PrimaryPart
                for _, joint in ipairs(body:GetDescendants()) do
                    if joint:IsA("Motor6D") and joint.Part0 == root and joint.Part1
                        and joint.Part1:IsDescendantOf(body) then part = joint.Part1 break end
                end
                part = part or body:FindFirstChild("Head") or root
            end
            if not part or not part:IsA("BasePart") then return end
            local score = (humanoid and 2000 or 1000) + (body == model and 400 or 0)
                + (bossTitle(body.Name) and 300 or 0) + (part.Anchored and 0 or 100)
            if score > bestScore then
                best, bestHumanoid, bestBody, bestScore = part, humanoid, body, score
            end
        end
        for _, node in ipairs(model:GetDescendants()) do
            if node:IsA("Humanoid") and node.Health > 0 then
                consider(node.Parent, node)
            elseif node:IsA("AnimationController") and node.Parent and node.Parent:IsA("Model") then
                local humanoid, health, _, known = replicatedHealth(node.Parent)
                if not humanoid and known and health > 0 then consider(node.Parent, nil) end
            end
        end
        local bone, boneScore = nil, 0
        if best then
            for _, node in ipairs(best:GetDescendants()) do
                if node:IsA("Bone") then
                    local key = normalized(node.Name)
                    local score = (key == "hips" or key == "pelvis" or key == "mixamorighips") and 3
                        or key == "root" and 2 or not node.Parent:IsA("Bone") and 1 or 0
                    if score > boneScore then bone, boneScore = node, score end
                end
            end
        end
        q.bossFollowCache[model] = {part = best, humanoid = bestHumanoid, body = bestBody,
            bone = bone, untilAt = os.clock() + 0.5}
        return best, bestHumanoid, bestBody
    end
    function q.bossFollowPosition(target)
        local cached = q.bossFollowCache[target.model]
        if cached and cached.bone and cached.bone.Parent then
            return cached.bone.TransformedWorldCFrame.Position
        end
        return target.root.Position
    end
    local function info(model)
        if not model or not model:IsA("Model") or not model:IsDescendantOf(World) or isPlayerModel(model) then return nil end
        local parent = model
        while parent and parent ~= World do
            local name = parent.Name:lower()
            if name:find("pet", 1, true) or name:find("preview", 1, true) or name:find("template", 1, true) then return nil end
            parent = parent.Parent
        end
        local title = bossTitle(model.Name) or knownBoss[model]
        if not title then return nil end
        knownBoss[model] = title
        local humanoid, health, maxHealth, healthKnown = replicatedHealth(model)
        local root, nestedHumanoid, body = q.bossMovingRootOf(model)
        if nestedHumanoid then
            humanoid = nestedHumanoid
            health, maxHealth, healthKnown = humanoid.Health, humanoid.MaxHealth, true
        elseif body then
            humanoid, health, maxHealth, healthKnown = replicatedHealth(body)
        end
        if not root or not root:IsA("BasePart") then return nil end
        local meta = knownMeta[model] or {}
        return { model = model, name = title, modelName = model.Name, root = root, health = health,
            maxHealth = maxHealth or health, healthKnown = healthKnown,
            alive = model.Parent ~= nil and healthKnown and health > 0, humanoid = humanoid, bodyModel = body,
            detection = meta.detection, confidence = meta.confidence }
    end
    local function attackParts(target)
        local cached = hitCache[target.model]
        if cached and cached.untilAt > os.clock() then return cached.parts end
        local ranked, used = {}, {}
        local bodyModel = target.bodyModel or (target.humanoid and target.humanoid.Parent)
        for _, part in ipairs((bodyModel or target.model):GetDescendants()) do
            if part:IsA("BasePart") then
                local key = normalized(part.Name)
                local score = part == target.root and 240 or 0
                if bodyModel then
                    if part == bodyModel or part:IsDescendantOf(bodyModel) then score += 700 else score -= 350 end
                end
                if key:find("hitbox", 1, true) or key:find("damage", 1, true) then score += 400 end
                if key == "humanoidrootpart" or key == "uppertorso" or key == "torso" or key == "head" then score += 260 end
                if part:FindFirstChildOfClass("TouchTransmitter") then score += 500 end
                if part.CanTouch then score += 40 end
                score += math.min(80, part.Size.Magnitude)
                table.insert(ranked, {part = part, score = score})
            end
        end
        table.sort(ranked, function(x, y) return x.score > y.score end)
        local parts = {}
        for _, item in ipairs(ranked) do
            if not used[item.part] then
                used[item.part] = true
                table.insert(parts, item.part)
                if #parts >= 5 then break end
            end
        end
        hitCache[target.model] = {parts = parts, untilAt = os.clock() + 1}
        return parts
    end
    local function bossDamage()
        if bossDamageNode and bossDamageNode.Parent
            and (bossDamageNode:IsA("NumberValue") or bossDamageNode:IsA("IntValue")) then
            return bossDamageNode.Value, bossDamageNode
        end
        bossDamageNode = nil
        for _, node in ipairs(j:GetDescendants()) do
            if normalized(node.Name) == "bossdamage"
                and (node:IsA("NumberValue") or node:IsA("IntValue")) then
                bossDamageNode = node
                return node.Value, node
            end
        end
        for _, key in ipairs({"BossDamage", "Boss Damage"}) do
            local value = j:GetAttribute(key)
            if type(value) == "number" then return value, "Player.Attribute." .. key end
        end
        return nil
    end
    local dangerTokens = {"attack", "damage", "hitbox", "warning", "telegraph", "danger", "hazard", "aoe", "slam", "strike", "laser", "beam"}
    local function looksRed(part)
        local color = part.Color
        return color.R >= 0.62 and color.R >= color.G * 1.45 and color.R >= color.B * 1.18
    end
    local function dangerName(part)
        local key = normalized(part.Name)
        for _, token in ipairs(dangerTokens) do
            if key:find(token, 1, true) then return true end
        end
        return false
    end
    local function dangerSignature(part)
        local names, node = {}, part
        for _ = 1, 5 do
            if not node or node == World then break end
            table.insert(names, 1, normalized(node.Name))
            node = node.Parent
        end
        return table.concat(names, "/") .. ":" .. part.ClassName
    end
    local function horizontalBox(part, position, padding)
        local point = part.CFrame:PointToObjectSpace(Vector3.new(position.X, part.Position.Y, position.Z))
        return math.abs(point.X) <= part.Size.X * 0.5 + padding
            and math.abs(point.Z) <= part.Size.Z * 0.5 + padding
    end
    local function dangerParts(target)
        if saved and saved.dangerParts and os.clock() < (saved.nextDangerScan or 0) then return saved.dangerParts end
        local result, character = {}, saved and saved.character
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = character and {character} or {}
        overlap.MaxParts = 350
        local ok, nearby = pcall(function() return World:GetPartBoundsInRadius(target.root.Position, 85, overlap) end)
        if ok then
            for _, part in ipairs(nearby) do
                if part:IsA("BasePart") and part.Parent then
                    local broad = math.max(part.Size.X, part.Size.Z) >= 2
                    local spawned = saved and saved.spawnedParts and saved.spawnedParts[part]
                    local insideBoss = part:IsDescendantOf(target.model)
                    local flat = part.Size.Y <= math.max(part.Size.X, part.Size.Z) * 0.30
                    local visible = part.Transparency < 0.97
                    local currentRed = visible and looksRed(part)
                    local old = saved and saved.partState and saved.partState[part]
                    local moved = old and broad and ((part.Position - old.position).Magnitude > 1.5
                        or math.abs(part.CFrame.LookVector:Dot(old.lookVector)) < 0.985)
                    local changed = old and ((part.CanTouch and not old.canTouch)
                        or (visible and old.transparency >= 0.97)
                        or (currentRed and not old.red)
                        or part.Size.Magnitude > old.size * 1.20
                        or part.Transparency < old.transparency - 0.12
                        or (moved and (currentRed or dangerName(part))))
                    if saved and not old then
                        if saved.baselineReady then saved.dynamicParts[part] = true else saved.baselineParts[part] = true end
                    end
                    if saved and changed then saved.dynamicParts[part] = true end
                    local dynamic = spawned or (saved and saved.dynamicParts and saved.dynamicParts[part]) or changed
                    local signature = dangerSignature(part)
                    local confirmed = saved and saved.confirmedHazards and saved.confirmedHazards[signature]
                    local canBeAttack = not insideBoss or spawned or (flat and dynamic)
                    local confirmedActive = confirmed and visible and broad and canBeAttack
                    local redTelegraph = dynamic and currentRed and broad and canBeAttack
                    local named = dynamic and visible and dangerName(part) and broad and canBeAttack
                    local liveHitbox = dynamic and visible and broad and part.CanTouch and canBeAttack
                    if confirmedActive or redTelegraph or named or liveHitbox then
                        table.insert(result, part)
                    end
                    if saved then saved.partState[part] = {canTouch = part.CanTouch, red = currentRed,
                        size = part.Size.Magnitude, transparency = part.Transparency,
                        position = part.Position, lookVector = part.CFrame.LookVector} end
                end
            end
        end
        if saved then
            saved.baselineReady = true
            saved.dangerParts = result
            saved.nextDangerScan = os.clock() + 0.035
        end
        return result
    end
    local function confirmDamageHazards(target)
        if not saved or not target or not target.root or not target.root.Parent then return end
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = {saved.character, target.model}
        overlap.MaxParts = 120
        local ok, nearby = pcall(function() return World:GetPartBoundsInRadius(saved.root.Position, 14, overlap) end)
        if not ok then return end
        for _, part in ipairs(nearby) do
            if part:IsA("BasePart") and part.Parent and part.Transparency < 0.97 then
                local broad = math.max(part.Size.X, part.Size.Z) >= 2
                local flat = part.Size.Y <= math.max(part.Size.X, part.Size.Z) * 0.35
                local dynamic = saved.spawnedParts[part] or saved.dynamicParts[part]
                local translucentRed = looksRed(part) and part.Transparency > 0.04
                if broad and horizontalBox(part, saved.root.Position, 2.8)
                    and (dynamic or dangerName(part) or (flat and translucentRed)) then
                    saved.confirmedHazards[dangerSignature(part)] = true
                    saved.dynamicParts[part] = true
                end
            end
        end
        saved.nextDangerScan = 0
    end
    local function standingPoint(position, target)
        local standing=q.bossStandingCF(position,target.bodyModel or target.model)
        return standing and standing.Position or nil
    end
    local function chooseDodgePoint(target, damageRevision)
        local root = saved.root
        local radius = 6
        for _, part in ipairs(attackParts(target)) do
            if part.Parent then radius = math.max(radius, math.clamp(math.max(part.Size.X, part.Size.Z) * 0.28, 4, 11)) end
        end
        local dangers = dangerParts(target)
        local currentUnsafe = false
        for _, part in ipairs(dangers) do
            if horizontalBox(part, root.Position, 3.2) then currentUnsafe = true break end
        end
        local damaged = damageRevision ~= (saved.damageRevision or 0)
        if damaged then
            saved.damageRevision = damageRevision
            saved.dodgeDirection = -(saved.dodgeDirection or 1)
        end
        saved.dodgeDirection = saved.dodgeDirection or 1
        local delta = root.Position - target.root.Position
        local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
        if not currentUnsafe and not damaged and distance >= radius - 2.2 and distance <= radius + 2.2 then
            return nil, #dangers, false
        end
        local baseAngle = math.atan2(delta.Z, delta.X)
        if currentUnsafe or damaged then baseAngle += saved.dodgeDirection * math.pi * (damaged and 0.72 or 0.52) end
        local best, bestScore, bestAngle = nil, -math.huge, nil
        for offset = 0, 23 do
            local angle = baseAngle + saved.dodgeDirection * offset * math.pi * 2 / 24
            local flat = target.root.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
            local candidate = Vector3.new(flat.X, root.Position.Y, flat.Z)
            local blocked, clearance = false, math.huge
            for _, part in ipairs(dangers) do
                if horizontalBox(part, candidate, 2.1) then blocked = true break end
                local localPoint = part.CFrame:PointToObjectSpace(Vector3.new(candidate.X, part.Position.Y, candidate.Z))
                local dx = math.max(0, math.abs(localPoint.X) - part.Size.X * 0.5)
                local dz = math.max(0, math.abs(localPoint.Z) - part.Size.Z * 0.5)
                clearance = math.min(clearance, math.sqrt(dx * dx + dz * dz))
            end
            if (currentUnsafe or damaged) and (candidate - root.Position).Magnitude < radius * 0.72 then blocked = true end
            if not blocked then
                local moveCost = (candidate - root.Position).Magnitude
                local score = (clearance == math.huge and 40 or math.min(40, clearance * 3)) - moveCost * 0.08 - offset * 0.7
                if score > bestScore then best, bestScore, bestAngle = candidate, score, angle end
            end
        end
        if not best then
            bestAngle = baseAngle + saved.dodgeDirection * math.pi
            best = target.root.Position + Vector3.new(math.cos(bestAngle) * radius * 1.8, 0, math.sin(bestAngle) * radius * 1.8)
        end
        saved.safeAngle = bestAngle
        best = standingPoint(best, target)
        return best, #dangers, currentUnsafe or damaged
    end
    -- Resolve a standing point on real ground, with clearance for both R6 and R15.
    function q.bossStandingCF(position, exclude)
        local root, humanoid, character = aO(), aN(), aM()
        if not root or not humanoid or not character or humanoid.Health <= 0 then return nil end
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        local exclusions = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then table.insert(exclusions, player.Character) end
        end
        if exclude then table.insert(exclusions, exclude) end
        ray.FilterDescendantsInstances = exclusions
        ray.RespectCanCollide = true
        local hit = World:Raycast(position + Vector3.new(0, 45, 0), Vector3.new(0, -180, 0), ray)
        if not hit or hit.Normal.Y < 0.8 then return nil end
        local clearance = math.max(0, humanoid.HipHeight) + root.Size.Y * 0.5 + 0.25
        local leg = character:FindFirstChild("Left Leg")
        if humanoid.RigType == Enum.HumanoidRigType.R6 and leg then clearance += leg.Size.Y end
        local standing = hit.Position + Vector3.new(0, clearance, 0)
        if standing.Y <= World.FallenPartsDestroyHeight + 10 then return nil end
        return CFrame.new(standing) * (root.CFrame - root.Position)
    end
    local function release(retreat)
        local old = saved
        saved = nil
        q.bossDangerCount = 0
        if not old then return end
        local living = old.root.Parent and old.character == aM() and old.humanoid.Health > 0
        if living then
            -- Freeze before removing BodyPosition. Teleport onto the surface in this
            -- same call; never leave a living character falling below the arena.
            old.root.Anchored = true
            local exitCF = retreat and old.origin or nil
            if not exitCF and old.positioned then
                local position = old.root.Position
                local probe = Vector3.new(position.X, old.arenaY or position.Y, position.Z)
                local ok, standing = pcall(q.bossStandingCF, probe, old.targetBody)
                exitCF = ok and standing or nil
                exitCF = exitCF or old.surfaceCF or old.origin
            end
            if exitCF then old.root.CFrame = exitCF end
            old.root.AssemblyLinearVelocity = Vector3.zero
            old.root.AssemblyAngularVelocity = Vector3.zero
            if q.networkHoldRoot == old.root then q.networkHoldCF = old.root.CFrame end
        end
        if old.healthConnection then old.healthConnection:Disconnect() end
        if old.spawnConnection then old.spawnConnection:Disconnect() end
        if old.holdPosition and old.holdPosition.Parent then old.holdPosition:Destroy() end
        for part, canCollide in pairs(old.collisionState or {}) do
            if part and part.Parent then part.CanCollide = canCollide end
        end
        if old.humanoid.Parent then old.humanoid.AutoRotate = old.autoRotate end
        if living then
            old.root.Anchored = old.anchored
        end
    end
    q.bossAdapter = {
        now = os.clock,
        ownHealth = function() local humanoid = aN() return humanoid and humanoid.Health end,
        strength = ca,
        trainStrength = function(current)
            if not current() then return false end
            local character = aM()
            local weight
            for _, mode in ipairs(q.trainModes) do if mode.id == "Weight" then weight = mode break end end
            if not weight then return false, "Гантель не найдена — жду перед боссом" end
            local tool, reason = dk(weight, true)
            -- Equipping can yield; do not activate after Stop, a new mode, or respawn.
            local humanoid = aN()
            if not current() or aM() ~= character or not humanoid or humanoid.Health <= 0 then return false end
            if not tool or tool.Parent ~= aM() then return false, reason end
            q.bossTrainingTool = tool
            d4(tool)
            tool:Activate()
            if current() then em() end
            return true
        end,
        stopTraining = function()
            local tool = q.bossTrainingTool
            q.bossTrainingTool = nil
            if tool and tool.Parent then pcall(function() tool:Deactivate() end) end
        end,
        prepare = function() jT() end,
        conflict = function()
            return q.bugActive or q.trainActive or q.machineActive or q.kingLock
                or q.lockPosition or q.lockRock or q.autoRebirth or q.autoQuest or q.killMode ~= "off"
        end,
        scan = function()
            local list, origin, seen, anchors = {}, aO(), setmetatable({}, {__mode = "k"}), {}
            local linkedThisScan = setmetatable({}, {__mode = "k"})
            local nodes = World:GetDescendants()
            for _, node in ipairs(nodes) do
                if node:IsA("TextLabel") or node:IsA("TextButton") then
                    local title = bossTitle(node.Text)
                    if title then
                        local gui = node:FindFirstAncestorWhichIsA("BillboardGui")
                            or node:FindFirstAncestorWhichIsA("SurfaceGui")
                        local anchor = gui and (gui.Adornee or gui.Parent)
                        local model = anchor and (anchor:IsA("Model") and anchor or anchor:FindFirstAncestorWhichIsA("Model"))
                            or node:FindFirstAncestorWhichIsA("Model")
                        local position = objectPosition(anchor) or (model and objectPosition(model))
                        if model then
                            knownBoss[model], linkedThisScan[model] = title, title
                            if anchor then q.bossAnchorCache[model] = anchor end
                        end
                        if position then table.insert(anchors, {position = position, title = title, direct = model, object = anchor}) end
                    end
                end
            end
            for _, node in ipairs(nodes) do
                if node:IsA("Model") and not seen[node] and not isPlayerModel(node) then
                    seen[node] = true
                    local root = rootOf(node)
                    local exactTitle, linkedTitle = bossTitle(node.Name), linkedThisScan[node]
                    local nearest, anchorTitle, nearestAnchor, direct = math.huge, nil, nil, false
                    if root then
                        for _, anchor in ipairs(anchors) do
                            local distance = (root.Position - anchor.position).Magnitude
                            if distance < nearest then
                                nearest, anchorTitle, nearestAnchor, direct = distance, anchor.title, anchor.object, anchor.direct == node
                            end
                        end
                    end
                    local humanoid, _, _, healthKnown = nil, nil, nil, false
                    if exactTitle or linkedTitle or (root and nearest <= 100) then
                        humanoid, _, _, healthKnown = replicatedHealth(node)
                    end
                    local nearLivingBoss = root and nearest <= 100 and (humanoid ~= nil or healthKnown)
                    local title = exactTitle or linkedTitle or (nearLivingBoss and anchorTitle)
                    if title then
                        knownBoss[node] = title
                        if nearestAnchor then q.bossAnchorCache[node] = nearestAnchor end
                        local score = (exactTitle and 900 or 0) + (direct and 300 or 0)
                            + (humanoid and 600 or 0) + (healthKnown and 350 or 0)
                            + (nearest < math.huge and math.max(0, 500 - nearest * 4) or 0)
                            + (root and not root.Anchored and 80 or 0)
                        knownMeta[node] = {detection = exactTitle and "model-name" or (direct and "label-adornee" or "label-near-live-model"), confidence = score}
                        local candidate = info(node)
                        if candidate and candidate.alive then
                        candidate.distance = origin and (origin.Position - candidate.root.Position).Magnitude or 0
                        candidate.score = score
                        table.insert(list, candidate)
                        end
                    end
                end
            end
            table.sort(list, function(x, y)
                if x.score ~= y.score then return x.score > y.score end
                return x.distance < y.distance
            end)
            return list[1] and {list[1]} or {}
        end,
        info = info,
        damage = bossDamage,
        claim = function(onHealth)
            release(false)
            local root, humanoid = aO(), aN()
            assert(root and humanoid, "Персонаж ещё не готов")
            saved = { character = aM(), root = root, humanoid = humanoid, origin = root.CFrame,
                rotation = root.CFrame - root.CFrame.Position,
                autoRotate = humanoid.AutoRotate, anchored = root.Anchored, spawnedParts = setmetatable({}, {__mode = "k"}),
                baselineParts = setmetatable({}, {__mode = "k"}), dynamicParts = setmetatable({}, {__mode = "k"}),
                partState = setmetatable({}, {__mode = "k"}), baselineReady = false,
                confirmedHazards = {}, lastHealth = humanoid.Health,
                collisionState = setmetatable({}, {__mode = "k"}), touchIndex = 0,
                dangerParts = {}, nextDangerScan = 0, dodgeDirection = 1, damageRevision = 0, nextMoveAt = 0 }
            for _, part in ipairs(saved.character:GetDescendants()) do
                if part:IsA("BasePart") then
                    saved.collisionState[part] = part.CanCollide
                end
            end
            saved.healthConnection = humanoid.HealthChanged:Connect(function(health)
                if saved and saved.lastHealth and health < saved.lastHealth then
                    local current = q.boss and q.boss.target and info(q.boss.target)
                    if current then confirmDamageHazards(current) end
                end
                if saved then saved.lastHealth = health end
                onHealth(health)
            end)
            saved.spawnConnection = World.DescendantAdded:Connect(function(node)
                if saved and node:IsA("BasePart") then
                    saved.spawnedParts[node] = true saved.nextDangerScan = 0
                    if node:IsDescendantOf(saved.character) then
                        saved.collisionState[node] = node.CanCollide
                    end
                end
            end)
        end,
        release = release,
        hold = function(target, height, damageRevision)
            assert(saved and saved.character == aM() and saved.root.Parent, "Персонаж сменился")
            assert(target.root and target.root.Parent, "Босс исчез")
            saved.humanoid.AutoRotate = false
            local depth = math.clamp(tonumber(height) or 8, 8, 12)
            local base = q.bossFollowPosition(target)
            saved.targetBody = target.bodyModel or target.model
            if not saved.arenaY then
                if saved.nextFloorProbe and os.clock() < saved.nextFloorProbe then return false, "Ожидаю пол арены…" end
                saved.nextFloorProbe = os.clock() + 0.5
                local ray = RaycastParams.new()
                ray.FilterType = Enum.RaycastFilterType.Exclude
                local exclusions = {target.root}
                if target.bodyModel then table.insert(exclusions, target.bodyModel) end
                for _, player in ipairs(Players:GetPlayers()) do
                    if player.Character then table.insert(exclusions, player.Character) end
                end
                ray.FilterDescendantsInstances = exclusions
                pcall(function() ray.RespectCanCollide = true end)
                local floorSamples = {}
                for _, offset in ipairs({Vector3.new(9, 0, 0), Vector3.new(-9, 0, 0), Vector3.new(0, 0, 9), Vector3.new(0, 0, -9)}) do
                    local hit = World:Raycast(base + offset + Vector3.new(0, 12, 0), Vector3.new(0, -140, 0), ray)
                    if hit and hit.Normal.Y > 0.8 and hit.Position.Y <= base.Y + 4 then
                        table.insert(floorSamples, hit.Position.Y)
                        saved.surfaceCF = saved.surfaceCF or q.bossStandingCF(hit.Position, saved.targetBody)
                    end
                end
                table.sort(floorSamples)
                if #floorSamples < 2 then return false, "Ожидаю пол под телом босса…" end
                saved.arenaY = floorSamples[math.ceil(#floorSamples * 0.5)]
            end
            if saved.depth ~= depth or not saved.underY then
                saved.depth = depth
                saved.underY = saved.arenaY - depth
            end
            local point = Vector3.new(base.X, saved.underY, base.Z)
            if point.Y <= World.FallenPartsDestroyHeight + 10 then
                return false, "Под ареной граница падения — жду безопасную точку"
            end
            q.bossDangerCount = 0
            saved.root.Anchored = false
            if not saved.holdPosition or not saved.holdPosition.Parent then
                local hold = Instance.new("BodyPosition")
                hold.Name = "RockBugBossPhysicalHold"
                hold.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                hold.P = 80000
                hold.D = 2000
                hold.Position = point
                hold.Parent = saved.root
                saved.holdPosition = hold
            end
            saved.holdPosition.Position = point
            for part in pairs(saved.collisionState) do
                if part.Parent then part.CanCollide = false end
            end
            saved.positioned = true
            saved.root.CFrame = CFrame.new(point) * saved.rotation
            saved.root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            saved.root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            return true
        end,
        punch = function(target, stillActive)
            if not stillActive() then return true end
            local tool, problem = dj()
            if not stillActive() then return true end
            if not tool then return false, tostring(problem) end
            local character = aM()
            if not character or not info(target.model) then return false, "Цель или персонаж исчезли" end
            if not stillActive() then return true end
            local contacts, touched = {}, {}
            q.punchCycle += 1
            local useRight = q.punchCycle % 2 == 0
            local handName = useRight and "RightHand" or "LeftHand"
            local hand = character:FindFirstChild(handName, true)
                or character:FindFirstChild(handName == "RightHand" and "Right Arm" or "Left Arm", true)
            local handle = tool:FindFirstChild("Handle")
            if hand and hand:IsA("BasePart") then table.insert(contacts, hand) end
            if handle and handle:IsA("BasePart") and handle ~= hand then table.insert(contacts, handle) end
            if #contacts == 0 and saved and saved.root then table.insert(contacts, saved.root) end
            local parts = attackParts(target)
            saved.touchIndex = (saved.touchIndex or 0) + 1
            local hitPart = #parts > 0 and parts[(saved.touchIndex - 1) % #parts + 1] or target.root
            if type(firetouchinterest) == "function" and hitPart and hitPart.Parent then
                for _, contact in ipairs(contacts) do
                    if contact and contact.Parent and pcall(firetouchinterest, contact, hitPart, 0) then
                        table.insert(touched, contact)
                    end
                end
            end
            d4(tool)
            tool:Activate()
            if not stillActive() then
                if type(firetouchinterest) == "function" and hitPart and hitPart.Parent then
                    for _, contact in ipairs(touched) do
                        if contact and contact.Parent then pcall(firetouchinterest, contact, hitPart, 1) end
                    end
                end
                return true
            end
            local remote = eg()
            local sent = remote and q.directRemoteEnabled and pcall(function()
                remote:FireServer("punch", useRight and "rightHand" or "leftHand")
            end)
            if sent then q.remoteSentWindow += 1 ei() else ek() end
            if type(firetouchinterest) == "function" and hitPart and hitPart.Parent then
                for _, contact in ipairs(touched) do
                    if contact and contact.Parent then pcall(firetouchinterest, contact, hitPart, 1) end
                end
            end
            return true
        end,
    }
    q.boss = q.bossFactory(q, q.bossAdapter)
    q.bossFactory = nil
    function q:StartBoss() return self.boss:Start() end
    function q:StopBoss() self.boss:Stop("Выключено — возврат к точке старта", true) end
    -- One-shot teleports have no persistent flag for the conflict guard.
    local teleport = q.teleportToIsland
    if type(teleport) == "function" then
        q.teleportToIsland = function(...)
            q.boss:Stop("Телепорт — автоатака выключена", false)
            return teleport(...)
        end
    end
    aJ(c.Heartbeat:Connect(function()
        -- Keep following on every frame even when equipping/punching has yielded.
        if saved and q.boss.enabled and not q.networkPaused and not q.bossAdapter.conflict()
            and (ca() or 0) > 0 and not (q.bossAdapter.awaitingReward and q.bossAdapter.awaitingReward()) then
            local target = q.boss.target and info(q.boss.target)
            if target and target.alive then pcall(q.bossAdapter.hold, target, q.boss.height, q.boss.damageEvents) end
        end
        q.boss:Tick(os.clock())
    end))
    aJ(j.CharacterRemoving:Connect(function()
        if q.boss.enabled then
            pcall(function() release(false) end)
            q.boss.target = nil
            q.boss.lastOwnHealth = nil
            q.boss.status = "Автобосс включён — жду респавн…"
        end
    end))
end


function q.refreshBossUI()
    if not q.alive then return end
    local boss=q.boss
    local active=boss.enabled or q.bossCycle and (q.bossCycle.enabled or q.bossCycle.phase=="returning")
    local message=q.bossCycleStatus or "Выключено"
    if boss.enabled then
        if q.networkPaused then message="Пауза"
        elseif not aN() or aN().Health<=0 then message="Жду персонажа"
        elseif boss.warming then message="Сила 0 — качаю гантель"
        elseif boss.target then message="Бой под ареной"
        else message="Жду босса" end
    elseif tostring(boss.status):find("Ошибка",1,true) then message="Не удалось начать" end
    status.Text=message
    local info=boss.target and q.bossAdapter.info(boss.target)
    targetText.Text=info and info.name or "Автоматический поиск босса"
    start.Text=active and "Остановить" or "Запустить"
    start.BackgroundColor3=active and Color3.fromRGB(65,43,91) or purple
    start.TextColor3=active and white or Color3.fromRGB(24,13,40)
end
aJ(start.Activated:Connect(function()
    if not q.authorized then return end
    if q.boss.enabled or q.bossCycle and q.bossCycle.enabled then q:StopBoss() else
        local other=env.RockBugRuntime
        if other and other.alive and (other.boss and other.boss.enabled or other.bugActive or other.trainActive or other.kingLock or other.lockPosition or other.machineActive) then
            status.Text="Останови режим в основном Hub" return
        end
        q:StartBoss()
    end
    q.refreshBossUI()
end))
aJ(reward.Activated:Connect(function()
    q.rewardsEnabled=not q.rewardsEnabled
    rewardStroke.Transparency=q.rewardsEnabled and 0.18 or 0.85
    rewardKnob.BackgroundColor3=q.rewardsEnabled and purple or Color3.fromRGB(64,56,77)
    rewardDot.Position=UDim2.fromOffset(q.rewardsEnabled and 17 or 3,3)
end))

-- Under-arena fight -> safe surface exit -> chest acknowledgement -> return.
do
    local createCycle=(function()
-- Orchestrates existing modes. Combat and movement use the existing adapter; rewards own movement until acknowledgement.
return function(api)
    local s={enabled=false,phase="off",generation=0,nextScan=0,busy=false,seen=setmetatable({},{__mode="k"})}
    local labels={off="Выключено",waiting="Жду босса · остальные функции работают",fighting="Бой с боссом · при силе 0 сначала гантель",rewards="Жду сундук · открываю награду",returning="Возвращаю прежние занятия"}
    local function phase(value)
        s.phase=value
        api.show(labels[value],s.enabled)
    end
    function s:Cancel(restore)
        self.generation+=1
        self.enabled=false
        api.cancelClaim()
        if self.snapshot then api.stop() end
        self.target=nil
        self.missingSince=nil
        if restore and self.snapshot then phase("returning") else self.snapshot=nil phase("off") end
    end
    function s:SetEnabled(value)
        if value==self.enabled then return end
        if not value then self:Cancel(true) return end
        if self.snapshot then return end
        self.generation+=1
        self.enabled=true
        self.nextScan=0
        phase("waiting")
    end
    local function step()
        if not api.alive() then s:Cancel(false) return end
        if not s.enabled and s.phase~="returning" then return end
        if not api.ready() then return end
        local now=api.now()
        local generation=s.generation
        local function current()return api.alive() and s.generation==generation end
        if s.phase=="waiting" then
            if now<s.nextScan or not api.idle() then return end
            s.nextScan=now+3
            local target
            for _,candidate in ipairs(api.scan()) do
                if not s.seen[candidate.model] and api.targetAlive(candidate.model) then target=candidate.model break end
            end
            if not target then return end
            s.snapshot=api.capture()
            if not s.snapshot then return end
            s.target=target
            s.missingSince=nil
            api.rememberBoss(target,s.snapshot)
            phase("fighting")
            local started=api.start(current)
            if not current() then return end
            if not started then
                s.enabled=false
                api.stop()
                phase("returning")
            end
        elseif s.phase=="fighting" then
            -- Explicit user activity wins; never restore over a newly selected mode.
            if api.conflict() then s:Cancel(false) return end
            if not api.running() then
                s.enabled=false
                phase("returning")
                return
            end
            if api.targetAlive(s.target) then
                api.rememberBoss(s.target,s.snapshot)
                s.missingSince=nil
                return
            end
            s.missingSince=s.missingSince or now
            if now-s.missingSince<1 then return end
            s.seen[s.target]=true
            -- A boss defeated while we were still warming up has no reward to collect.
            if not api.engaged(s.target) then
                api.stop()
                phase("returning")
                return
            end
            api.stop(false) -- release moves onto the surface before removing combat physics
            s.nextRewardNotice=now+15
            phase(api.rewardsEnabled and not api.rewardsEnabled() and "returning" or "rewards")
        elseif s.phase=="rewards" then
            if api.rewardsEnabled and not api.rewardsEnabled() then
                api.cancelClaim()
                phase("returning")
                return
            end
            if api.conflict() then s:Cancel(false) return end
            local result=api.claim(function()return current() and not api.conflict()end,s.snapshot)
            if not current() then return end
            -- Wait at the chest across retries and delayed server responses.
            -- A timeout or successful pcall is never treated as an opened chest.
            if result=="closed" then
                phase("returning")
            elseif now>=s.nextRewardNotice then
                s.nextRewardNotice=now+15
                api.show(result=="missing" and "Жду появления сундука босса"
                    or "Сундук ещё не открылся — повторяю у сундука",s.enabled)
            end
        elseif s.phase=="returning" then
            if api.conflict() then s:Cancel(false) return end
            local snapshot=s.snapshot
            s.snapshot=nil -- consume once, also if restoring encounters a failure
            local restored=not snapshot or api.restore(snapshot,current)
            if not current() then return end
            if restored==false then s.enabled=false end
            s.target=nil
            s.nextScan=api.now()+3
            phase(s.enabled and "waiting" or "off")
        end
    end
    function s:Tick()
        if self.busy then return end
        self.busy=true
        local ok,problem=pcall(step)
        self.busy=false
        if not ok then
            self.enabled=false
            api.cancelClaim()
            api.stop()
            if self.snapshot then phase("returning") else phase("off") end
            api.report(tostring(problem))
        end
    end
    return s
end

    end)()
    local prompts=setmetatable({},{__mode="k"})
    local function track(obj)
        if obj:IsA("ProximityPrompt") and not prompts[obj]then prompts[obj]={tries=0,nextAt=0}end
    end
    for _,obj in ipairs(workspace:GetDescendants())do track(obj)end
    aJ(workspace.DescendantAdded:Connect(track))
    local function hasAny(text,words)
        text=tostring(text or ""):lower()
        for _,word in ipairs(words)do
            if text:find(word,1,true)then return true end
        end
        return false
    end
    local function promptContext(prompt)
        local parts={tostring(prompt.Name),tostring(prompt.ActionText),tostring(prompt.ObjectText)}
        local node=prompt.Parent
        for _=1,7 do
            if not node then break end
            table.insert(parts,tostring(node.Name))
            node=node.Parent
        end
        return table.concat(parts," ")
    end
    local function matches(prompt)
        if not prompt.Parent or not prompt.Enabled then return false end
        local action=tostring(prompt.ActionText)
        local object=tostring(prompt.ObjectText)
        local context=promptContext(prompt)
        local reward=hasAny(action.." "..object,{"claim reward","claim","reward","collect","open","loot","prize"})
            or context:find("Наград",1,true) or context:find("награ",1,true)
            or context:find("Получ",1,true) or context:find("получ",1,true)
            or context:find("Забра",1,true) or context:find("забра",1,true)
        local chest=hasAny(object.." "..context,{"boss chest","chest","boss"})
            or context:find("Сундук",1,true) or context:find("сундук",1,true)
            or context:find("Босс",1,true) or context:find("босс",1,true)
        return reward~=nil and chest~=nil
    end
    -- Kept separate so retry/cancellation behavior can be checked without a live game.
    local createChestCollector=(function()
return function(api)
    local state={prompt=nil,attempted=false,nextAt=0,tries=0,closed=false}
    function state:Cancel()
        if self.prompt then pcall(api.endHold,self.prompt) end
        self.prompt=nil
        self.attempted=false
        self.nextAt=0
        self.tries=0
        self.closed=false
        self.character=nil
    end
    function state:Step(current,snapshot)
        local character=api.character()
        -- A disabled prompt after death is not acknowledgement for the new character.
        if self.character and self.character~=character then self:Cancel() end
        self.character=character
        if not current() or not api.ready() then return "pending" end
        if self.closed then return "closed" end
        if self.prompt and self.attempted and api.closed(self.prompt) then
            pcall(api.endHold,self.prompt)
            self.closed=true
            return "closed"
        end
        if not self.prompt or not api.matches(self.prompt) then
            self.prompt=api.find(snapshot)
            self.attempted=false
            self.nextAt=0
            self.tries=0
        end
        local prompt=self.prompt
        if not prompt then return "missing" end
        local function valid()
            return current() and api.ready() and api.character()==character and self.prompt==prompt
        end
        -- Stay next to the actual prompt between attempts; restore runs once, after closure.
        if not api.move(prompt) or not valid() then return "pending" end
        if api.now()<self.nextAt then return "pending" end
        api.wait(0.3) -- allow the server to observe the teleport before activation
        if not valid() or not api.matches(prompt) or not api.inRange(prompt) then return "pending" end
        self.tries+=1
        self.nextAt=api.now()+2
        self.attempted=true
        local ok,problem=pcall(api.interact,prompt,self.tries,valid)
        pcall(api.endHold,prompt)
        if not valid() then return "pending" end
        if not ok then
            self.attempted=false
            api.report(tostring(problem))
        end
        -- Closure can arrive on a later tick; retain the attempted prompt until then.
        if self.attempted and api.closed(prompt) then self.closed=true return "closed" end
        return "pending"
    end
    return state
end
    end)()
    local function promptPosition(prompt)
        local node=prompt.Parent
        for _=1,7 do
            if not node then return nil end
            if node:IsA("Attachment") then return node.WorldPosition end
            if node:IsA("BasePart") then return node.Position end
            if node:IsA("Model") then return node:GetPivot().Position end
            node=node.Parent
        end
        return nil
    end
    local function chestModel(prompt)
        local node=prompt.Parent
        for _=1,7 do
            if not node then return nil end
            if node:IsA("Model") and hasAny(node.Name,{"boss chest","chest"}) then return node end
            node=node.Parent
        end
        return nil
    end
    local function promptRange(prompt)return math.max(0,tonumber(prompt.MaxActivationDistance)or 10)end
    local function inRange(prompt)
        local root,position=aO(),promptPosition(prompt)
        return root and position and (root.Position-position).Magnitude<=promptRange(prompt)
    end
    local function moveToChest(prompt)
        local root,humanoid,position=aO(),aN(),promptPosition(prompt)
        if not root or not humanoid or humanoid.Health<=0 or not position then return false end
        local range=promptRange(prompt)
        if range<=0 then return false end
        -- The surface exit often already leaves the character inside the prompt.
        -- Do not require a second raycast before trying the interaction.
        if inRange(prompt)then return true end
        local standing
        local radius=math.min(4,range*0.45)
        local exclude=chestModel(prompt)
        for _, offset in ipairs({Vector3.new(radius,0,0),Vector3.new(-radius,0,0),
            Vector3.new(0,0,radius),Vector3.new(0,0,-radius),Vector3.zero})do
            local candidate=q.bossStandingCF(position+offset,exclude)
            if candidate and (candidate.Position-position).Magnitude<=range*0.95 then
                standing=candidate
                break
            end
        end
        -- If the chest blocks the floor ray, retain the already verified arena
        -- height and move only horizontally. This cannot send the player below it.
        if not standing and math.abs(root.Position.Y-position.Y)<=range+6 then
            for _,offset in ipairs({Vector3.new(radius,0,0),Vector3.new(-radius,0,0),
                Vector3.new(0,0,radius),Vector3.new(0,0,-radius),Vector3.zero})do
                local point=Vector3.new(position.X+offset.X,root.Position.Y,position.Z+offset.Z)
                if (point-position).Magnitude<=range*0.95 then
                    standing=CFrame.new(point)*(root.CFrame-root.Position)
                    break
                end
            end
        end
        if not standing then return false end
        if (root.Position-standing.Position).Magnitude<=0.75 then return inRange(prompt) end
        local anchored=root.Anchored
        root.Anchored=true
        humanoid.Sit=false
        root.CFrame=standing
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        root.Anchored=anchored
        return inRange(prompt)
    end
    local collector=createChestCollector({
        now=os.clock,wait=task.wait,character=aM,
        ready=function()local h=aN()return q.alive and q.authorized and not q.remotePaused and not q.networkPaused and h and h.Health>0 and aO()~=nil end,
        matches=matches,closed=function(prompt)return not prompt.Parent or not prompt.Enabled end,
        find=function(snapshot)
            local root=aO()
            local origin=snapshot and snapshot.bossPosition or root and root.Position
            local best,bestDistance=nil,math.huge
            for prompt in pairs(prompts)do
                if not prompt.Parent then prompts[prompt]=nil
                elseif matches(prompt)then
                    local position=promptPosition(prompt)
                    local distance=position and origin and (position-origin).Magnitude
                    if distance and distance<bestDistance then best,bestDistance=prompt,distance end
                end
            end
            return best
        end,
        move=moveToChest,inRange=inRange,
        endHold=function(prompt)prompt:InputHoldEnd()end,
        interact=function(prompt,attempt,valid)
            local hold=tonumber(prompt.HoldDuration)or 0
            if hold~=hold or hold<0 or hold==math.huge then error("Некорректное время открытия сундука")end
            -- A successful pcall only means that the executor accepted the helper;
            -- it does not prove the server claimed the chest. Try the native hold
            -- too when the prompt remains enabled.
            if type(fireproximityprompt)=="function" then
                pcall(fireproximityprompt,prompt)
                task.wait(0.12)
            end
            if not valid() or not matches(prompt) then return end
            prompt:InputHoldBegin()
            local deadline=os.clock()+math.max(0.1,hold)+0.15
            repeat
                task.wait(0.05)
                if not valid() or not matches(prompt) then return end
                if not moveToChest(prompt) then return end
            until os.clock()>=deadline
            prompt:InputHoldEnd()
        end,
        report=function(problem)q.bossCycleError=problem end,
    })
    local function cancelClaim()collector:Cancel()end
    local function claim(current,snapshot)return collector:Step(current,snapshot)end
    local function conflict()
        local other=env.RockBugRuntime
        return q.bossAdapter.conflict() or other and other.alive and
            (other.boss and other.boss.enabled or other.bossCycle and other.bossCycle.enabled
                or other.bugActive or other.trainActive or other.kingLock or other.lockPosition or other.machineActive)
    end
    q.bossCycle=createCycle({
        alive=function()return q.alive end,now=os.clock,
        ready=function()local h=aN()return q.authorized and not q.remotePaused and not q.networkPaused and h and h.Health>0 and aO()~=nil end,
        idle=function()return not q.boss.enabled and not q.equipInFlight and not conflict()end,
        scan=q.bossAdapter.scan,
        targetAlive=function(model)local info=q.bossAdapter.info(model)return info and info.alive end,
        engaged=function(model)return q.boss.engagedTarget==model end,
        rewardsEnabled=function()return q.rewardsEnabled end,
        capture=function()
            local root=aO()
            if not root then return nil end
            local tool=aM():FindFirstChildWhichIsA("Tool")
            return {origin=root.CFrame,tool=tool}
        end,
        rememberBoss=function(model,snapshot)
            local info=q.bossAdapter.info(model)
            if info then snapshot.bossPosition=q.bossFollowPosition(info)end
        end,
        restore=function(snapshot,current)
            local root=aO()
            if not current() or not root then return false end
            local anchored=root.Anchored
            root.Anchored=true
            root.CFrame=snapshot.origin
            root.AssemblyLinearVelocity=Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
            root.Anchored=anchored
            if snapshot.tool and snapshot.tool.Parent and current()then c_(snapshot.tool)end
            return current()
        end,
        claim=claim,cancelClaim=cancelClaim,
        start=function(current)
            collector:Cancel()
            local started=q.boss:Start()
            if not current()then q.boss:Stop(nil,true)return false end
            return started
        end,
        stop=function(retreat)q.boss:Stop("Возврат после боя",retreat~=false)end,
        conflict=conflict,running=function()return q.boss.enabled end,
        show=function(message)q.bossCycleStatus=message if q.refreshBossUI then q.refreshBossUI()end end,
        report=function(problem)q.bossCycleError=problem warn("[RockBugBoss] "..problem)end,
    })
    q.bossAdapter.awaitingReward=function()
        local cycle=q.bossCycle
        if not cycle.enabled or cycle.phase~="fighting" or not cycle.target then return false end
        local info=q.bossAdapter.info(cycle.target)
        return not info or not info.alive
    end
    function q:StartBoss()
        if not self.authorized or self.remotePaused or conflict()then return false end
        self.bossCycle:SetEnabled(true)
        self.bossCycle:Tick()
        return self.bossCycle.enabled
    end
    function q:StopBoss()
        self.bossCycle:Cancel(true)
        self.boss:Stop("Выключено",true)
        self.bossCycle:Tick()
    end
    q.rewardCollector={Destroy=function()q.bossCycle:Cancel(false)collector:Cancel()end}
    task.spawn(function()
        while q.alive do
            if not q.authorized or q.remotePaused then
                if q.bossCycle.enabled or q.bossCycle.snapshot then q.bossCycle:Cancel(false)end
            else q.bossCycle:Tick()end
            task.wait(0.25)
        end
    end)
end

local function viewport() return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600) end
local function clampPosition(frame,x,y)
    local vp=viewport()
    frame.Position=UDim2.fromOffset(math.clamp(x,4,math.max(4,vp.X-frame.AbsoluteSize.X-4)),math.clamp(y,4,math.max(4,vp.Y-frame.AbsoluteSize.Y-40)))
end
local function fit()
    local vp=viewport()
    scale.Scale=math.min(1,math.max(0.5,(vp.X-16)/348),math.max(0.5,(vp.Y-70)/302))
    clampPosition(window,window.Position.X.Offset,window.Position.Y.Offset)
    clampPosition(mini,mini.Position.X.Offset,mini.Position.Y.Offset)
end
local function drag(handle,frame,onTap)
    local active,origin,position,moved=nil,nil,nil,false
    aJ(handle.InputBegan:Connect(function(event)
        if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
            if handle==header and event.Position.X-header.AbsolutePosition.X>248*scale.Scale then return end
            active=event origin=event.Position position=frame.Position moved=false
        end
    end))
    aJ(input.InputChanged:Connect(function(event)
        if active and (event==active or event.UserInputType==Enum.UserInputType.MouseMovement) then
            local delta=event.Position-origin
            if delta.Magnitude>6 then moved=true end
            if moved then clampPosition(frame,position.X.Offset+delta.X,position.Y.Offset+delta.Y) end
        end
    end))
    aJ(input.InputEnded:Connect(function(event)
        if event==active or active and event.UserInputType==Enum.UserInputType.MouseButton1 then
            active=nil
            if not moved and onTap then onTap() end
        end
    end))
end
drag(header,window)
drag(mini,mini,function()mini.Visible=false window.Visible=true fit()end)
aJ(minimize.Activated:Connect(function()
    mini.Position=window.Position window.Visible=false mini.Visible=true fit()
end))
local cameraConnection
local function watchCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    if workspace.CurrentCamera then cameraConnection=aJ(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)) end
    fit()
end
aJ(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera))
watchCamera()
function q:Destroy()
    if not self.alive then return end
    if self.boss then self.boss:Stop(nil,true) end
    self.alive=false self.authorized=false
    if self.rewardCollector then self.rewardCollector:Destroy() end
    for _,connection in ipairs(self.connections) do pcall(function()connection:Disconnect()end) end
    gui:Destroy()
    if env.RockBugBossStandalone==self then env.RockBugBossStandalone=nil end
    task.spawn(function()post(sessionEndpoint,{action="leave",session_id=sessionId,state="stopped"},sessionHeaders)end)
end
aJ(close.Activated:Connect(function()q:Destroy()end))
q.refreshBossUI()
task.spawn(function()
    local value=env.RockBugBossKeys and env.RockBugBossKeys[tostring(j.UserId)]
    if not value and type(readfile)=="function" then local ok,v=pcall(readfile,cachePath) if ok and type(v)=="string" and #v<128 then value=v end end
    if value then activate(value,false) end
end)
task.spawn(function()
    while q.alive do
        task.wait(30)
        if q.alive and q.authorized and license then
            local result=checkKey(license,false)
            if not q.alive then return end
            if result and result.ok then q.lastKeyCheck=os.clock()
            elseif result and errors[result.error] and result.error~="rate_limit" then showGate(errors[result.error])
            elseif os.clock()-(q.lastKeyCheck or 0)>120 then showGate("Нет связи с проверкой доступа. Повтори вход.") end
        end
    end
end)
task.spawn(function()
    local commandVersion=0
    while q.alive do
        if q.authorized then
            local result=post(sessionEndpoint,{action="heartbeat",session_id=sessionId,player_user_id=j.UserId,player_name=j.Name,display_name=j.DisplayName,version="Boss 1.1",place_id=game.PlaceId,job_id=game.JobId,state=q.remotePaused and "paused" or "running",details={device=input.TouchEnabled and "mobile" or "desktop"}},sessionHeaders)
            if not q.alive then return end
            if result and result.command and tonumber(result.command_version) and result.command_version>commandVersion then
                commandVersion=result.command_version
                if result.command=="pause" then q.resumeBoss=q.boss.enabled or q.bossCycle.enabled q:StopBoss() q.remotePaused=true
                elseif result.command=="resume" then q.remotePaused=false if q.resumeBoss and q.authorized then q:StartBoss() end q.resumeBoss=false
                elseif result.command=="stop" then q:Destroy() end
                post(sessionEndpoint,{action="ack",session_id=sessionId,command_version=commandVersion,state=not q.alive and "stopped" or q.remotePaused and "paused" or "running"},sessionHeaders)
            end
        end
        for _=1,12 do if not q.alive then return end task.wait(1) end
    end
end)
return q
