-- BGS Legacy Hub 0.2.0: searchable egg catalogue, independent travel, map-wide collection.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
if not game:IsLoaded()then game.Loaded:Wait()end
local player=Players.LocalPlayer
while not player do task.wait()player=Players.LocalPlayer end
local playerGui=player:WaitForChild("PlayerGui",60)
if not playerGui then warn("BGS: PlayerGui недоступен")return end
local env=_G
if type(getgenv)=="function"then local ok,value=pcall(getgenv)if ok and type(value)=="table"then env=value end end
if env.BGSLegacy and type(env.BGSLegacy.Stop)=="function"then pcall(function()env.BGSLegacy:Stop("reload")end)end
local createController=(function()
-- One scheduler owns movement; selection, travel and purchasing are separate actions.
return function(api)
    local S={alive=true,autoBubble=false,autoHatch=false,autoCollect=false,teleportOnSelect=true,
        bubbleDelay=0.2,hatchDelay=0.8,teleportHeights=5,collectMode="smart",currency="Все",
        eggs={},pickups={},currencies={"Все"},selectedEgg=nil,conns={},version="0.2.0",
        status="Готово",bubbleStatus="Выключено",hatchStatus="Выбери яйцо",collectStatus="Выключено",
        lastBubble=-math.huge,lastHatch=-math.huge,nextScan=0,nextMove=0,travelUntil=0,
        skipped=setmetatable({},{__mode="k"}),busy=false,errors=0}
    local function status(message)S.status=message end
    local function stopMovement()
        S.target=nil S.arrivedAt=nil S.lastDistance=nil S.stallSince=nil S.touchAt=nil
        api.stopMove()
    end
    function S:Refresh()
        local selected=self.selectedEgg and self.selectedEgg.object
        self.eggs,self.pickups,self.currencies=api.scan()
        self.selectedEgg=nil
        for _,entry in ipairs(self.eggs)do if entry.object==selected then self.selectedEgg=entry break end end
        self.nextScan=api.now()+3
        self.revision=(self.revision or 0)+1
    end
    function S:SelectEgg(entry)
        if not api.validEgg(entry)then status("Яйцо исчезло — обнови список")return false end
        self.selectedEgg=entry self.lastHatch=api.now() self.hatchStatus="Выбрано: "..entry.name
        status(self.hatchStatus)
        if self.teleportOnSelect then return self:GoToEgg()end
        return true
    end
    function S:GoToEgg()
        local entry=self.selectedEgg
        if not api.validEgg(entry)then status("Сначала выбери доступное яйцо")return false end
        if not api.ready()then status("Жду персонажа")return false end
        stopMovement()
        local ok,problem=api.toEgg(entry)
        if ok then
            self.travelUntil=api.now()+3 self.lastHatch=api.now()
            status("У яйца: "..entry.name)
        else status(problem or "Не удалось переместиться к яйцу")end
        return ok
    end
    function S:HatchOnce()
        local entry=self.selectedEgg
        if not api.ready()or not api.validEgg(entry)then status("Выбери доступное яйцо")return false end
        if api.now()-self.lastHatch<self.hatchDelay then return false end
        if api.eggDistance(entry)>14 then status("Сначала нажми «К яйцу»")return false end
        self.lastHatch=api.now()
        local ok,problem=api.hatch(entry)
        self.hatchStatus=ok and("Запрос: "..entry.name)or(problem or"Открытие недоступно")
        status(self.hatchStatus)
        return ok
    end
    function S:SetMode(key,value)
        if key~="autoBubble"and key~="autoHatch"and key~="autoCollect"then return end
        value=value==true
        if key=="autoHatch"and value and not api.validEgg(self.selectedEgg)then status("Выбери яйцо во вкладке «Яйца»")return end
        self[key]=value
        if key~="autoBubble"then stopMovement()end
        if key=="autoBubble"then self.bubbleStatus=value and"Включено"or"Выключено"end
        if key=="autoHatch"then self.hatchStatus=value and"Подхожу к выбранному яйцу"or"Выключено"end
        if key=="autoCollect"then self.collectStatus=value and"Ищу ближайшую добычу"or"Выключено"end
    end
    function S:HardStop()
        self.autoBubble=false self.autoHatch=false self.autoCollect=false
        self.travelUntil=0 stopMovement()
        self.bubbleStatus="Выключено"self.hatchStatus="Выключено"self.collectStatus="Выключено"
        status("Все действия остановлены")
    end
    function S:Stop()
        if not self.alive then return end
        self:HardStop() self.alive=false
        api.destroy()
    end
    local function nearest(now)
        local best,bestDistance=nil,math.huge -- deliberately no collection radius
        for _,item in ipairs(S.pickups)do
            if api.validPickup(item)and(S.currency=="Все"or item.currency==S.currency)
                and now>=(S.skipped[item.object]or 0)then
                local distance=api.pickupDistance(item)
                if distance<bestDistance then best,bestDistance=item,distance end
            end
        end
        return best,bestDistance
    end
    local function collect(now)
        if now<S.travelUntil then S.collectStatus="Пауза после ручного телепорта"return end
        local target=S.target
        if target and(not api.validPickup(target)or(S.currency~="Все"and target.currency~=S.currency))then stopMovement()target=nil end
        if not target then
            target=nearest(now)
            if not target then S.collectStatus="Нет доступной добычи · жду появления"return end
            S.target=target S.lastDistance=nil S.stallSince=now S.arrivedAt=nil S.touchAt=nil
        end
        local distance=api.pickupDistance(target)
        S.collectStatus=target.currency.." · "..math.floor(distance).." studs"
        if distance<=5 then
            S.arrivedAt=S.arrivedAt or now
            if not S.touchAt or now-S.touchAt>=0.6 then api.touch(target)S.touchAt=now end
            if now-S.arrivedAt>=1.8 then
                -- No invented success counter: a target that persists gets a cooldown.
                S.skipped[target.object]=now+10 stopMovement()
            end
            return
        end
        S.arrivedAt=nil
        if not S.lastDistance or distance<S.lastDistance-0.75 then S.stallSince=now S.lastDistance=distance end
        if now<S.nextMove then return end
        S.nextMove=now+0.2
        local far=distance>S.teleportHeights*api.bodyHeight()
        local teleport=S.collectMode=="teleport"or far or now-(S.stallSince or now)>=1.2 or api.blocked(target)
        local ok,problem=api.toPickup(target,teleport)
        if ok==false then
            S.skipped[target.object]=now+5 stopMovement()
            S.collectStatus=problem or"Цель временно недоступна"
        end
    end
    local function step(now)
        if not S.alive then return end
        if now>=S.nextScan then S:Refresh()end
        if not api.ready()then return end
        if S.autoBubble and now-S.lastBubble>=S.bubbleDelay then
            S.lastBubble=now
            local ok,problem=api.bubble()
            S.bubbleStatus=ok and"Надуваю пузыри"or(problem or"Ожидание подключения")
        end
        if S.autoHatch then
            local entry=S.selectedEgg
            if not api.validEgg(entry)then S.hatchStatus="Выбранное яйцо недоступно · выбери снова"return end
            if S.autoCollect then S.collectStatus="Пауза на время автооткрытия"end
            if api.eggDistance(entry)>14 then
                if now>=S.nextMove then
                    S.nextMove=now+1
                    local ok,problem=api.toEgg(entry)
                    S.hatchStatus=ok and"У яйца · готовлю открытие"or(problem or"Телепорт недоступен")
                    S.lastHatch=now
                end
            elseif now-S.lastHatch>=S.hatchDelay then S:HatchOnce()end
        elseif S.autoCollect then collect(now)end
    end
    function S:Tick()
        if self.busy or not self.alive then return end
        self.busy=true
        local ok,problem=pcall(step,api.now())
        self.busy=false
        if not ok then self.errors+=1 status("Ошибка: "..tostring(problem):sub(1,130))end
    end
    return S
end

end)()
local conns,gui={},nil
local function connect(signal,fn)local c=signal:Connect(fn)table.insert(conns,c)return c end
local function root()return player.Character and player.Character:FindFirstChild("HumanoidRootPart")end
local function humanoid()return player.Character and player.Character:FindFirstChildOfClass("Humanoid")end
local function ready()local h=humanoid()return root()~=nil and h~=nil and h.Health>0 end
local function stopMove()local h=humanoid()local r=root()if h and r then h:MoveTo(r.Position)h:Move(Vector3.zero,false)end end
local network,nextNetwork=nil,0
local function send(action,...)
    if not network or not network.Parent then
        if os.clock()<nextNetwork then return false,"NetworkRemoteEvent не найден"end
        nextNetwork=os.clock()+3
        local candidate=RS:FindFirstChild("NetworkRemoteEvent",true)
        network=candidate and candidate:IsA("RemoteEvent")and candidate or nil
    end
    if not network then return false,"NetworkRemoteEvent не найден"end
    local ok,problem=pcall(network.FireServer,network,action,...)
    return ok,problem
end
local function partOf(object)
    if not object then return nil end
    if object:IsA("BasePart")then return object end
    if object:IsA("Attachment")then return object.Parent and object.Parent:IsA("BasePart")and object.Parent end
    return object:IsA("Model")and object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart",true)
end
local function meta(object,keys)
    for _,key in ipairs(keys)do
        local value=object:GetAttribute(key)
        if value==nil then local node=object:FindFirstChild(key)if node and node:IsA("ValueBase")then value=node.Value end end
        if type(value)=="string"or type(value)=="number"then return value end
    end
end
local currencyNames={coins="Coins",coin="Coins",gems="Gems",gem="Gems",candy="Candy",blocks="Blocks",shells="Shells",pearls="Pearls",stars="Stars",magma="Magma",crystals="Crystals"}
local function currencyOf(object,container)
    local current=object
    while current and current~=container do
        local value=meta(current,{"Currency","CurrencyType","PickupType"})
        if value then return tostring(value)end
        local name=current.Name:lower()
        for key,currency in pairs(currencyNames)do if name:find(key,1,true)then return currency end end
        current=current.Parent
    end
    return "Другое"
end
local function eggPart(object)return partOf(object:FindFirstChild("Hotkey",true))or partOf(object)end
local function scan()
    local eggs,pickups,currencies={}, {}, {"Все"}
    local folder=workspace:FindFirstChild("Eggs",true)
    local seen={}
    local function addEgg(object)
        if seen[object]or not object.Parent or not object:IsDescendantOf(workspace)then return end
        local part=eggPart(object)
        if not part then return end
        seen[object]=true
        local world=meta(object,{"World","WorldName","Island","Area"})
        if not world and object.Parent~=folder then world=object.Parent.Name end
        table.insert(eggs,{object=object,part=part,name=object.Name,world=tostring(world or"Текущий мир"),
            price=meta(object,{"Price","Cost","EggPrice"}),currency=meta(object,{"Currency","CurrencyType"})})
    end
    if folder then
        local function visit(object)
            local looksLikeEgg=object.Name:lower():find("egg",1,true)and(object:IsA("Model")or object:IsA("BasePart"))
            if object:FindFirstChild("Hotkey")or(looksLikeEgg and eggPart(object))then addEgg(object)return end
            for _,child in ipairs(object:GetChildren())do
                if child:IsA("Model")or child:IsA("Folder")or child:IsA("BasePart")then visit(child)end
            end
        end
        for _,object in ipairs(folder:GetChildren())do visit(object)end
    end
    table.sort(eggs,function(a,b)return a.world==b.world and(a.name==b.name and a.object:GetFullName()<b.object:GetFullName()or a.name<b.name)or a.world<b.world end)
    local container=workspace:FindFirstChild("Pickups",true)
    local picked,currencySet={},{}
    if container then
        for _,part in ipairs(container:GetDescendants())do
            if part:IsA("BasePart")then
                local object=part
                if part.Parent:IsA("Model")then object=part.Parent end
                if not picked[object]and part.Transparency<1 then
                    picked[object]=true
                    local currency=currencyOf(object,container)
                    table.insert(pickups,{object=object,part=part,currency=currency})
                    if not currencySet[currency]then currencySet[currency]=true table.insert(currencies,currency)end
                end
            end
        end
    end
    table.sort(currencies,function(a,b)if a==b then return false elseif a=="Все"then return true elseif b=="Все"then return false end return a<b end)
    return eggs,pickups,currencies
end
local function validEgg(entry)return entry and entry.object.Parent and entry.part.Parent and entry.object:IsDescendantOf(workspace)end
local function validPickup(entry)
    return entry and entry.object.Parent and entry.part.Parent and entry.part.Transparency<1
        and entry.object:IsDescendantOf(workspace)and entry.object:GetAttribute("Collected")~=true
end
local function standingPoint(position,object)
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={player.Character,object}
    pcall(function()ray.RespectCanCollide=true end)
    local hit=workspace:Raycast(position+Vector3.new(0,12,0),Vector3.new(0,-70,0),ray)
    local h,r=humanoid(),root()
    local height=h.HipHeight+r.Size.Y/2
    local leg=player.Character:FindFirstChild("Left Leg")
    if h.RigType==Enum.HumanoidRigType.R6 and leg then height+=leg.Size.Y end
    return hit and hit.Normal.Y>0.6 and Vector3.new(position.X,hit.Position.Y+height+0.15,position.Z)or position+Vector3.new(0,2,0)
end
local function teleport(point)
    local r,h=root(),humanoid()
    if not ready()then return false,"Жду персонажа"end
    stopMove()h.Sit=false
    r.CFrame=CFrame.new(point)*(r.CFrame-r.Position)
    r.AssemblyLinearVelocity=Vector3.zero r.AssemblyAngularVelocity=Vector3.zero
    return true
end
local S=createController({
    now=os.clock,ready=ready,scan=scan,validEgg=validEgg,validPickup=validPickup,stopMove=stopMove,
    eggDistance=function(entry)return (entry.part.Position-root().Position).Magnitude end,
    pickupDistance=function(entry)return (entry.part.Position-root().Position).Magnitude end,
    bodyHeight=function()local r,h=root(),humanoid()return math.max(5,r.Size.Y+2*h.HipHeight)end,
    toEgg=function(entry)
        if not validEgg(entry)then return false,"Яйцо исчезло"end
        local p=entry.part.Position+entry.part.CFrame.LookVector*4
        return teleport(standingPoint(p,entry.object))
    end,
    toPickup=function(entry,useTeleport)
        if not validPickup(entry)then return false,"Добыча исчезла"end
        local point=standingPoint(entry.part.Position,entry.object)
        if useTeleport then return teleport(point)end
        humanoid():MoveTo(point)return true
    end,
    blocked=function(entry)
        local ray=RaycastParams.new()ray.FilterType=Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances={player.Character,entry.object}
        pcall(function()ray.RespectCanCollide=true end)
        local r=root()
        return workspace:Raycast(r.Position,entry.part.Position-r.Position,ray)~=nil
    end,
    touch=function(entry)
        local r=root()
        if type(firetouchinterest)=="function"then
            local ok=pcall(firetouchinterest,r,entry.part,0)
            if ok then pcall(firetouchinterest,r,entry.part,1)end
        else humanoid():MoveTo(entry.part.Position)end
    end,
    bubble=function()return send("BlowBubble")end,
    hatch=function(entry)
        if tostring(entry.currency):lower():find("robux",1,true)then return false,"Это яйцо покупается за Robux вручную"end
        return send("PurchaseEgg",entry.name)
    end,
    destroy=function()
        for _,conn in ipairs(conns)do pcall(function()conn:Disconnect()end)end
        table.clear(conns)
        if gui then gui:Destroy()end
    end,
})
env.BGSLegacy=S
local C={bg=Color3.fromRGB(16,17,24),panel=Color3.fromRGB(24,26,36),surface=Color3.fromRGB(32,35,47),
    border=Color3.fromRGB(65,65,88),accent=Color3.fromRGB(163,126,246),text=Color3.fromRGB(242,242,250),
    muted=Color3.fromRGB(159,163,185),danger=Color3.fromRGB(226,99,127)}
local function make(class,parent,props)
    local object=Instance.new(class)
    for key,value in pairs(props or{})do object[key]=value end
    object.Parent=parent return object
end
local function corner(object,radius)make("UICorner",object,{CornerRadius=UDim.new(0,radius or 9)})end
local function border(object,color) return make("UIStroke",object,{Color=color or C.border,Thickness=1,Transparency=0.25})end
local function label(parent,text,size,color)
    return make("TextLabel",parent,{Text=text,TextSize=size or 13,Font=Enum.Font.Gotham,TextColor3=color or C.text,
        BackgroundTransparency=1,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
end
gui=make("ScreenGui",playerGui,{Name="BGSLegacyHub",ResetOnSpawn=false,DisplayOrder=999999,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local main=make("Frame",gui,{Name="Main",Size=UDim2.fromOffset(530,432),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),
    BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true,Active=true})corner(main,14)border(main,C.accent)
local header=make("Frame",main,{Size=UDim2.new(1,0,0,53),BackgroundColor3=C.panel,BorderSizePixel=0,Active=true})
local title=label(header,"BGS LEGACY",17)title.Font=Enum.Font.GothamBold title.Position=UDim2.fromOffset(14,8)title.Size=UDim2.new(1,-192,0,22)
local subtitle=label(header,"Яйца · сбор · пузыри",10,C.muted)subtitle.Position=UDim2.fromOffset(14,31)subtitle.Size=UDim2.new(1,-190,0,15)
local function button(parent,text,callback,height)
    local b=make("TextButton",parent,{Size=UDim2.new(1,-6,0,height or 38),Text=text,TextSize=12,TextColor3=C.text,
        Font=Enum.Font.GothamMedium,TextWrapped=true,BackgroundColor3=C.surface,BorderSizePixel=0,AutoButtonColor=true})
    corner(b,8)connect(b.Activated,callback)return b
end
local hard=button(header,"Стоп",function()S:HardStop()end,30)hard.Size=UDim2.fromOffset(62,30)hard.Position=UDim2.new(1,-144,0,11)hard.TextColor3=C.danger
local mini=button(header,"—",function()end,30)mini.Size=UDim2.fromOffset(30,30)mini.Position=UDim2.new(1,-74,0,11)
local close=button(header,"×",function()S:Stop()end,30)close.Size=UDim2.fromOffset(30,30)close.Position=UDim2.new(1,-38,0,11)
local tabs=make("Frame",main,{Position=UDim2.fromOffset(10,61),Size=UDim2.new(1,-20,0,32),BackgroundTransparency=1})
local holder=make("Frame",main,{Position=UDim2.fromOffset(12,104),Size=UDim2.new(1,-24,1,-141),BackgroundTransparency=1})
local footer=label(main,"Готово",11,C.muted)footer.Position=UDim2.new(0,14,1,-30)footer.Size=UDim2.new(1,-45,0,24)footer.TextTruncate=Enum.TextTruncate.AtEnd footer.TextWrapped=false
local grip=make("TextButton",main,{Text="◢",TextSize=16,TextColor3=C.accent,Size=UDim2.fromOffset(26,26),Position=UDim2.new(1,-27,1,-27),BackgroundTransparency=1})
local pageNames={"Яйца","Сбор","Пузыри","Ещё"}
local pages,tabButtons={},{}
local function setTab(index)
    for i,page in ipairs(pages)do page.Visible=i==index tabButtons[i].BackgroundColor3=i==index and C.accent or C.panel tabButtons[i].TextColor3=i==index and C.bg or C.muted end
end
for i,name in ipairs(pageNames)do
    local b=button(tabs,name,function()setTab(i)end,32)
    b.Size=UDim2.new(0.25,-4,1,0)b.Position=UDim2.new((i-1)*0.25,2,0,0)tabButtons[i]=b
    local page=make("ScrollingFrame",holder,{Name="Page"..i,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=C.accent,ScrollingDirection=Enum.ScrollingDirection.Y})
    make("UIListLayout",page,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
    make("UIPadding",page,{PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,1),PaddingTop=UDim.new(0,2)})
    pages[i]=page
end
setTab(1)
local function textRow(parent,text,height,color)
    local l=label(parent,text,12,color or C.muted)l.Size=UDim2.new(1,-10,0,height or 36)return l
end
local draws={}
local function toggle(parent,titleText,description,read,write)
    local b=button(parent,"",function()write(not read())end,54)border(b)
    local title=label(b,titleText,13)title.Font=Enum.Font.GothamMedium title.Position=UDim2.fromOffset(12,8)title.Size=UDim2.new(1,-78,0,18)
    local desc=label(b,description,10,C.muted)desc.Position=UDim2.fromOffset(12,28)desc.Size=UDim2.new(1,-80,0,19)desc.TextTruncate=Enum.TextTruncate.AtEnd desc.TextWrapped=false
    local pill=make("Frame",b,{Size=UDim2.fromOffset(40,22),Position=UDim2.new(1,-52,0.5,-11),BorderSizePixel=0})corner(pill,20)
    local dot=make("Frame",pill,{Size=UDim2.fromOffset(16,16),BackgroundColor3=C.text,BorderSizePixel=0})corner(dot,20)
    table.insert(draws,function()local on=read()pill.BackgroundColor3=on and C.accent or C.border dot.Position=UDim2.fromOffset(on and 21 or 3,3)end)
end
local activeSlider
local function slider(parent,titleText,key,min,max,step,unit)
    local box=make("Frame",parent,{Size=UDim2.new(1,-6,0,61),BackgroundColor3=C.panel,BorderSizePixel=0})corner(box)
    local name=label(box,titleText,12)name.Position=UDim2.fromOffset(12,7)name.Size=UDim2.new(1,-115,0,20)
    local value=label(box,"",12,C.accent)value.Position=UDim2.new(1,-104,0,7)value.Size=UDim2.fromOffset(92,20)value.TextXAlignment=Enum.TextXAlignment.Right
    local track=make("TextButton",box,{Text="",Size=UDim2.new(1,-28,0,24),Position=UDim2.fromOffset(14,31),BackgroundTransparency=1,AutoButtonColor=false})
    local rail=make("Frame",track,{Size=UDim2.new(1,0,0,4),Position=UDim2.new(0,0,0.5,-2),BackgroundColor3=C.border,BorderSizePixel=0})corner(rail,4)
    local fill=make("Frame",rail,{BackgroundColor3=C.accent,BorderSizePixel=0})corner(fill,4)
    local knob=make("Frame",rail,{Size=UDim2.fromOffset(12,12),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=C.text,BorderSizePixel=0})corner(knob,12)
    local function update(x)S[key]=math.clamp(math.floor((min+math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)*(max-min))/step+0.5)*step,min,max)end
    connect(track.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then activeSlider={input=input,update=update}update(input.Position.X)end
    end)
    table.insert(draws,function()
        local alpha=(S[key]-min)/(max-min)fill.Size=UDim2.fromScale(alpha,1)knob.Position=UDim2.fromScale(alpha,0.5)
        value.Text=(step>=1 and string.format("%.0f",S[key])or string.format("%.2f",S[key])).." "..unit
    end)
end
-- Searchable picker stays inside the same window and uses a scrolling list.
local overlay=make("Frame",main,{Name="Picker",Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BackgroundTransparency=0.03,BorderSizePixel=0,Visible=false,ZIndex=20,Active=true})
local pickerTitle=label(overlay,"Выбор яйца",15)pickerTitle.Font=Enum.Font.GothamBold pickerTitle.Position=UDim2.fromOffset(16,12)pickerTitle.Size=UDim2.new(1,-70,0,28)
local pickerClose=button(overlay,"×",function()overlay.Visible=false end,30)pickerClose.Size=UDim2.fromOffset(30,30)pickerClose.Position=UDim2.new(1,-43,0,12)
local search=make("TextBox",overlay,{PlaceholderText="Найти по названию или миру…",Text="",ClearTextOnFocus=false,Size=UDim2.new(1,-32,0,36),Position=UDim2.fromOffset(16,50),
    TextSize=13,TextColor3=C.text,PlaceholderColor3=C.muted,Font=Enum.Font.Gotham,BackgroundColor3=C.surface,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left})corner(search)
make("UIPadding",search,{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
local choices=make("ScrollingFrame",overlay,{Size=UDim2.new(1,-32,1,-106),Position=UDim2.fromOffset(16,96),BackgroundTransparency=1,BorderSizePixel=0,
    AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=4,ScrollBarImageColor3=C.accent,ScrollingDirection=Enum.ScrollingDirection.Y})
make("UIListLayout",choices,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local pickerItems,pickerChoose={},nil
local choiceConnections={}
local function renderChoices()
    for _,conn in ipairs(choiceConnections)do conn:Disconnect()end table.clear(choiceConnections)
    for _,child in ipairs(choices:GetChildren())do if child:IsA("GuiObject")then child:Destroy()end end
    local filter=search.Text:lower()local found=0
    for _,item in ipairs(pickerItems)do
        if filter==""or(item.title.." "..(item.detail or"")):lower():find(filter,1,true)then
            found+=1
            local b=make("TextButton",choices,{Text="",Size=UDim2.new(1,-6,0,54),BackgroundColor3=item.selected and C.border or C.surface,BorderSizePixel=0,LayoutOrder=found})corner(b)
            local title=label(b,item.title,13)title.Font=Enum.Font.GothamMedium title.Size=UDim2.new(1,-24,0,20)title.Position=UDim2.fromOffset(12,6)
            local detail=label(b,item.detail or"",10,C.muted)detail.Size=UDim2.new(1,-24,0,20)detail.Position=UDim2.fromOffset(12,28)
            table.insert(choiceConnections,b.Activated:Connect(function()overlay.Visible=false if pickerChoose then pickerChoose(item.value)end end))
        end
    end
    if found==0 then textRow(choices,"Ничего не найдено. Обнови список или измени поиск.",55)end
end
connect(search:GetPropertyChangedSignal("Text"),renderChoices)
local function picker(title,items,choose)
    pickerItems,pickerChoose=items,choose pickerTitle.Text=title search.Text=""choices.CanvasPosition=Vector2.zero
    renderChoices()overlay.Visible=true
end
local function eggDetail(entry)
    local price=entry.price and(tostring(entry.price).." "..tostring(entry.currency or""))or"Цена в игре"
    local r=root()local distance=r and math.floor((entry.part.Position-r.Position).Magnitude)
    return entry.world.."  ·  "..price..(distance and("  ·  "..distance.." studs")or"")
end
local eggButton=button(pages[1],"ВЫБРАТЬ ЯЙЦО  ›",function()
    S:Refresh()
    local items={}
    for _,entry in ipairs(S.eggs)do table.insert(items,{title=entry.name,detail=eggDetail(entry),value=entry,selected=S.selectedEgg and S.selectedEgg.object==entry.object})end
    picker("Выбери яйцо · "..#items,items,function(entry)S:SelectEgg(entry)end)
end,52)border(eggButton,C.accent)
local eggInfo=textRow(pages[1],"Сначала выбери яйцо из списка.",32)
local eggActions=make("Frame",pages[1],{Size=UDim2.new(1,-6,0,36),BackgroundTransparency=1})
local go=button(eggActions,"К яйцу",function()S:GoToEgg()end,36)go.Size=UDim2.new(0.5,-4,1,0)
local once=button(eggActions,"Открыть 1",function()S:HatchOnce()end,36)once.Size=UDim2.new(0.5,-4,1,0)once.Position=UDim2.new(0.5,4,0,0)
toggle(pages[1],"Автооткрытие","Сбор добычи ждёт, пока открываются яйца",function()return S.autoHatch end,function(v)S:SetMode("autoHatch",v)end)
toggle(pages[1],"Телепорт при выборе","Перемещает сразу, автооткрытие не нужно",function()return S.teleportOnSelect end,function(v)S.teleportOnSelect=v end)
slider(pages[1],"Интервал открытий","hatchDelay",0.65,3,0.05,"сек")
local hatchInfo=textRow(pages[1],"",32,C.accent)

toggle(pages[2],"Собирать добычу","Ближайшая подходящая цель по всей карте",function()return S.autoCollect end,function(v)S:SetMode("autoCollect",v)end)
local currencyButton=button(pages[2],"Валюта: Все  ›",function()
    S:Refresh()local items={}
    for _,currency in ipairs(S.currencies)do table.insert(items,{title=currency,detail=currency=="Все"and"Любая доступная добыча"or"Собирать только эту валюту",value=currency,selected=S.currency==currency})end
    picker("Валюта для сбора",items,function(value)S.currency=value S.target=nil stopMove()end)
end)
local modeButton=button(pages[2],"Перемещение: шаг / телепорт  ›",function()
    picker("Как собирать",{
        {title="Умное перемещение",detail="Рядом — шаг, далеко или преграда — телепорт",value="smart",selected=S.collectMode=="smart"},
        {title="Всегда телепорт",detail="Сразу перемещаться к ближайшей добыче",value="teleport",selected=S.collectMode=="teleport"},
    },function(value)S.collectMode=value end)
end)
slider(pages[2],"ТП дальше чем","teleportHeights",1,15,1,"ростов")
local collectInfo=textRow(pages[2],"",42,C.accent)
local mapInfo=textRow(pages[2],"",40)
textRow(pages[2],"Поиск охватывает все загруженные объекты Pickups. Если цель не подбирается, скрипт временно пропускает её.",48)

toggle(pages[3],"Надувать пузыри","Работает вместе со сбором или открытием",function()return S.autoBubble end,function(v)S:SetMode("autoBubble",v)end)
slider(pages[3],"Интервал надувания","bubbleDelay",0.2,2,0.05,"сек")
local bubbleInfo=textRow(pages[3],"",32,C.accent)
textRow(pages[3],"Надувание не управляет перемещением персонажа. Частота ограничена выбранным интервалом.",48)
button(pages[4],"Обновить яйца и добычу",function()S:Refresh()S.status="Список обновлён"end)
button(pages[4],"Остановить все действия",function()S:HardStop()end).TextColor3=C.danger
textRow(pages[4],"Перетаскивай окно за заголовок. Размер меняется за нижний правый угол. «—» сворачивает окно в небольшой квадрат.",64)
textRow(pages[4],"Во время автооткрытия сбор ждёт, чтобы персонажа не тянуло в две стороны. После выключения открытий сбор продолжится.",64)
textRow(pages[4],"BGS Legacy Hub 0.2.0",24,C.accent)

local minimized=false
local savedSize,savedPosition
local drag,resize
local function viewport()return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600)end
local function fit()
    if minimized then return end
    local view=viewport()
    main.Size=UDim2.fromOffset(math.min(main.Size.X.Offset,math.max(240,view.X-24)),math.min(main.Size.Y.Offset,math.max(210,view.Y-64)))
    local half=main.AbsoluteSize*0.5
    local center=main.AbsolutePosition+half
    main.Position=UDim2.fromOffset(math.clamp(center.X,half.X+4,math.max(half.X+4,view.X-half.X-4)),math.clamp(center.Y,half.Y+4,math.max(half.Y+4,view.Y-half.Y-34)))
end
local reopen=make("TextButton",gui,{Name="Mini",Text="BGS",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=C.text,BackgroundColor3=C.panel,
    Size=UDim2.fromOffset(50,46),Position=UDim2.fromOffset(20,120),Visible=false,BorderSizePixel=0,Active=true})corner(reopen,12)border(reopen,C.accent)
local function toggleWindow()
    minimized=not minimized
    if minimized then savedSize=main.Size savedPosition=main.Position reopen.Position=UDim2.fromOffset(main.AbsolutePosition.X,main.AbsolutePosition.Y)overlay.Visible=false end
    main.Visible=not minimized reopen.Visible=minimized
    if not minimized then main.Size=savedSize or main.Size main.Position=savedPosition or main.Position fit()end
end
connect(mini.Activated,toggleWindow)
local miniMoved=false
local function dragSurface(surface,target,isMini)
    connect(surface.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            drag={input=input,start=input.Position,position=target.AbsolutePosition,target=target,isMini=isMini}if isMini then miniMoved=false end
        end
    end)
end
dragSurface(header,main,false)dragSurface(reopen,reopen,true)
connect(reopen.Activated,function()if not miniMoved then toggleWindow()end end)
connect(grip.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then resize={input=input,start=input.Position,size=main.AbsoluteSize}end
end)
connect(Input.InputChanged,function(input)
    local mouse=input.UserInputType==Enum.UserInputType.MouseMovement
    if activeSlider and(mouse or input==activeSlider.input)then activeSlider.update(input.Position.X)end
    if drag and(mouse or input==drag.input)then
        local delta=input.Position-drag.start local view=viewport()local target=drag.target
        if drag.isMini and delta.Magnitude>6 then miniMoved=true end
        local x=math.clamp(drag.position.X+delta.X,0,math.max(0,view.X-target.AbsoluteSize.X))
        local y=math.clamp(drag.position.Y+delta.Y,0,math.max(0,view.Y-target.AbsoluteSize.Y-32))
        target.Position=UDim2.fromOffset(x+target.AbsoluteSize.X*target.AnchorPoint.X,y+target.AbsoluteSize.Y*target.AnchorPoint.Y)
    end
    if resize and(mouse or input==resize.input)then
        local delta=input.Position-resize.start local view=viewport()
        main.Size=UDim2.fromOffset(math.clamp(resize.size.X+delta.X,math.min(320,view.X-24),view.X-24),math.clamp(resize.size.Y+delta.Y,math.min(280,view.Y-64),view.Y-64))
    end
end)
connect(Input.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then drag=nil resize=nil activeSlider=nil end
end)
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit)end
task.defer(fit)
local function refreshUI()
    for _,draw in ipairs(draws)do draw()end
    footer.Text=S.status
    local entry=S.selectedEgg
    eggButton.Text=entry and(entry.name.."  ›")or("ВЫБРАТЬ ЯЙЦО  ·  "..#S.eggs.." доступно  ›")
    eggInfo.Text=entry and eggDetail(entry)or"Выбери яйцо: название, мир и цена находятся в списке."
    hatchInfo.Text=S.hatchStatus collectInfo.Text=S.collectStatus bubbleInfo.Text=S.bubbleStatus
    currencyButton.Text="Валюта: "..S.currency.."  ›"
    modeButton.Text="Перемещение: "..(S.collectMode=="smart"and"шаг / телепорт"or"всегда ТП").."  ›"
    mapInfo.Text="Радиус: вся загруженная карта · объектов: "..#S.pickups
end
refreshUI()

local nextTick,nextPaint=0,0
connect(Run.Heartbeat,function()
    if not S.alive then return end
    local now=os.clock()
    if now>=nextTick then nextTick=now+0.1 S:Tick()end
    if now>=nextPaint then nextPaint=now+0.2 refreshUI()end
end)
connect(player.CharacterAdded,function()S.target=nil S.travelUntil=os.clock()+2 end)
S.startupReady=true
print("BGS Legacy Hub "..S.version.." loaded")
return S
