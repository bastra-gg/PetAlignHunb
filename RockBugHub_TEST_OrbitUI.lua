-- ORBIT_UI_BEGIN
local HUD=(function()
-- RockBugHub UI T79; closed-form spring motion engine + animated hologram.
-- All geometry is local, non-colliding and excluded from game raycasts.
local HUD = {}

function HUD.versionTag(runtime,env)
    local raw=tostring((env and env.RockBugTestVersion) or (runtime and runtime.testVersion) or "T79")
    return raw:match("T%d+") or raw
end

HUD.groups={
 farm={ru="ФАРМ",en="FARM",tabs={"bug","farm","train","boss","reb"},cards={
  {ru="КАМНИ",en="ROCKS",tab="bug",key="bug",actionRu="Автоудар",actionEn="Auto punch",moreRu="Выбрать камень",moreEn="Choose rock"},
  {ru="ТРЕНАЖЁРЫ",en="MACHINES",tab="farm",key="machineFarm",actionRu="Автотренажёр",actionEn="Auto machine",moreRu="Все тренажёры",moreEn="All machines"},
  {ru="КАЧ",en="TRAINING",tab="train",key="train.Weight",actionRu="Качать гантель",actionEn="Auto weight",moreRu="Все упражнения",moreEn="All exercises"},
  {ru="БОСС",en="BOSS",tab="boss",key="bossCycle",actionRu="Босс и сундук",actionEn="Boss & chest",moreRu="Настроить босса",moreEn="Boss settings"},
 }},
 growth={ru="РАЗВИТИЕ",en="GROWTH",tabs={"crystal","egg","quest","teleport","system"},cards={
  {ru="МАГАЗИН",en="SHOP",tab="crystal",key="crystal.crystal",actionRu="Автокристалл",actionEn="Auto crystal",moreRu="Весь магазин",moreEn="Full shop"},
  {ru="ЯЙЦА",en="EGGS",tab="egg",key="proteinEgg",actionRu="Protein Egg",actionEn="Protein Egg",moreRu="Все настройки яиц",moreEn="All egg settings"},
  {ru="КВЕСТЫ",en="QUESTS",tab="quest",key="autoQuest",actionRu="Автоквест",actionEn="Auto quest",moreRu="Все квесты",moreEn="All quests"},
  {ru="ПИТОМЦЫ / МИР",en="PETS / WORLD",tab="teleport",actionTab="system",actionRu="Питомцы и другое",actionEn="Pets & more",moreRu="Все локации",moreEn="All destinations"},
 }},
 kill={ru="КИЛЛ",en="KILL",tabs={"kill"},cards={
  {ru="ВСЕ ИГРОКИ",en="ALL PLAYERS",tab="kill",key="kill.all",actionRu="Атаковать всех",actionEn="Attack all",moreRu="Полные настройки",moreEn="Full settings"},
  {ru="КРОМЕ ДРУЗЕЙ",en="EXCEPT FRIENDS",tab="kill",key="kill.whitelist",actionRu="Пропускать друзей",actionEn="Skip friends",moreRu="Список исключений",moreEn="Exclusion list"},
  {ru="ТОЛЬКО ЦЕЛИ",en="SELECTED TARGETS",tab="kill",key="kill.blacklist",actionRu="Атаковать цели",actionEn="Attack targets",moreRu="Выбрать цели",moreEn="Choose targets"},
  {ru="УПРАВЛЕНИЕ",en="CONTROL",tab="kill",actionRu="Остановить килл",actionEn="Stop kill",stopKill=true,moreRu="Все функции килла",moreEn="All kill functions"},
 }},
 settings={ru="НАСТРОЙКИ",en="SETTINGS",tabs={"system","interface","bug","farm","train","boss","reb","crystal","egg","quest","teleport","kill"}},
}
HUD.sections={bug={"Камни","Rocks"},farm={"Тренажёры","Machines"},train={"Кач","Training"},boss={"Босс","Boss"},reb={"Ребирты","Rebirths"},crystal={"Магазин","Shop"},egg={"Яйца","Eggs"},quest={"Квесты","Quests"},teleport={"Локации","Locations"},system={"Петы / Ещё","Pets / More"},interface={"Вид интерфейса","Appearance"},kill={"Килл","Kill"}}

function HUD.layout(width, height)
    if height > width then return "portrait", 7.0, 16.0 end
    if width < 1080 or height < 620 then return "compact", 16.0, 8.2 end
    return "wide", 12.4, 9.0
end

function HUD.drawerSize(width,height)
    return math.min(364,math.max(1,width-24)),math.min(424,math.max(1,height-24))
end

-- Layout is independent of input dispatch. Native GuiButtons remain the targets.
function HUD.popupLayout(width,height,origin,popupWidth,popupHeight)
    local w,h=HUD.drawerSize(width,height)
    w=math.min(w,popupWidth or w); h=math.min(h,popupHeight or h)
    local x,y=width/2,height/2
    local sourceX,sourceY=x,y
    local linked=false
    if origin then
        sourceX=origin.x+origin.w/2; sourceY=origin.y+origin.h/2
        local left=sourceX<width/2
        local candidate=left and origin.x+origin.w+18+w/2 or origin.x-18-w/2
        if width>=700 and candidate-w/2>=12 and candidate+w/2<=width-12 then
            x=candidate; linked=true
            sourceX=left and origin.x+origin.w or origin.x
        else x=width/2+(sourceX-width/2)*0.12 end
        y=sourceY
    end
    x=math.clamp(x,w/2+12,math.max(w/2+12,width-w/2-12))
    y=math.clamp(y,h/2+12,math.max(h/2+12,height-h/2-12))
    return {x=x,y=y,w=w,h=h,sourceX=sourceX,sourceY=sourceY,linked=linked}
end

function HUD.mount(runtime, options)
    local player = options.player
    local versionTag=HUD.versionTag(runtime,options.env)
    local playerGui = player:WaitForChild("PlayerGui")
    local run = game:GetService("RunService")
    local input = game:GetService("UserInputService")
    local guiService = game:GetService("GuiService")
    local cyan, mint = Color3.fromRGB(65, 224, 255), Color3.fromRGB(69, 250, 193)
    local white, muted = Color3.fromRGB(229, 250, 255), Color3.fromRGB(170, 214, 228)
    local background = Color3.fromRGB(30, 62, 79)
    local rowRest, rowPressed = 0.78, 0.48
    local savedGroup=options.env.RockBugHologramGroup
    assert(options.content,"Missing hologram content bridge")
    local self = {visible=false, suspended=false, destroyed=false, group=HUD.groups[savedGroup] and savedGroup~="settings" and savedGroup or "farm", cardPage=1, cards={}, modalTabs={}, modalOpen=false, panels={}, connections={}, pressed={}, beams={}, samples={}, fps=0, inputGeneration=0, noticeToken=0, motion={}, modalToken=0, visualElapsed=0, lowDetail=false}
    runtime.hologram = self -- Allows cleanup even if construction fails.
    local binding = "RockBugHologram" .. versionTag .. "_" .. tostring(player.UserId)
    local panelOrder=1000009
    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(self.connections, connection)
        return connection
    end
    local function create(class, properties, parent)
        local object = Instance.new(class)
        for key, value in pairs(properties or {}) do object[key] = value end
        object.Parent = parent
        return object
    end
    -- T79 motion engine.
    -- Closed-form damped spring, inspired by the MIT luau-spring approach.
    -- It is frame-drop stable and keeps the UI self-contained: no remote runtime dependency.
    local function springStep(x,v,target,frequency,damping,dt)
        dt=math.max(0,math.min(dt or 0,0.2))
        local omega=math.max(0.001,2*math.pi*frequency)
        local y=x-target
        damping=math.max(0.05,damping or 1)

        if damping<0.999 then
            local wd=omega*math.sqrt(math.max(0.0001,1-damping*damping))
            local e=math.exp(-damping*omega*dt)
            local c=y
            local d=(v+damping*omega*y)/wd
            local cosv=math.cos(wd*dt)
            local sinv=math.sin(wd*dt)
            local ny=e*(c*cosv+d*sinv)
            local nv=e*((-damping*omega)*(c*cosv+d*sinv)+(-c*wd*sinv+d*wd*cosv))
            return target+ny,nv
        end

        -- Critical damping: exact solution, no Euler wobble after a dropped frame.
        local e=math.exp(-omega*dt)
        local c1=y
        local c2=v+omega*y
        local ny=(c1+c2*dt)*e
        local nv=(v-omega*c2*dt)*e
        return target+ny,nv
    end

    local function mixValue(a,b,t)
        local kind=typeof(a)
        if type(a)=="number"and type(b)=="number"then return a+(b-a)*t end
        if kind=="UDim2"and typeof(b)=="UDim2"then
            return UDim2.new(
                a.X.Scale+(b.X.Scale-a.X.Scale)*t,
                a.X.Offset+(b.X.Offset-a.X.Offset)*t,
                a.Y.Scale+(b.Y.Scale-a.Y.Scale)*t,
                a.Y.Offset+(b.Y.Offset-a.Y.Offset)*t
            )
        end
        if kind=="Vector2"and typeof(b)=="Vector2"then
            return Vector2.new(a.X+(b.X-a.X)*t,a.Y+(b.Y-a.Y)*t)
        end
        if kind=="Color3"and typeof(b)=="Color3"then
            return Color3.new(
                math.clamp(a.R+(b.R-a.R)*t,0,1),
                math.clamp(a.G+(b.G-a.G)*t,0,1),
                math.clamp(a.B+(b.B-a.B)*t,0,1)
            )
        end
        return t>=1 and b or a
    end

    local function animateEase(object,duration,properties,style,direction)
        local prior=self.motion[object]
        if prior and prior.Cancel then prior:Cancel() end
        if self.lowDetail or options.env.RockBugHologramMotion==false then
            for key,value in pairs(properties)do object[key]=value end
            return nil
        end

        local startValues={}
        for key in pairs(properties)do
            local ok,value=pcall(function()return object[key]end)
            if ok then startValues[key]=value end
        end

        -- JS-style motion semantics: normal transitions are critically damped,
        -- "Back" transitions get a small physical overshoot instead of a canned curve.
        local damping=1
        if style==Enum.EasingStyle.Back then damping=0.72
        elseif style==Enum.EasingStyle.Elastic then damping=0.58
        elseif style==Enum.EasingStyle.Quart then damping=0.9
        elseif direction==Enum.EasingDirection.In then damping=0.98 end

        local frequency=math.clamp(1/math.max(0.055,tonumber(duration)or 0.2),3.0,14.0)
        local handle={cancelled=false}
        function handle:Cancel()self.cancelled=true end
        self.motion[object]=handle

        task.spawn(function()
            local value,velocity=0,0
            local started=os.clock()
            local last=started
            while not handle.cancelled and not self.destroyed and object.Parent do
                local now=os.clock()
                local dt=math.max(1/240,now-last)
                last=now
                value,velocity=springStep(value,velocity,1,frequency,damping,dt)

                for key,target in pairs(properties)do
                    local initial=startValues[key]
                    if initial~=nil then
                        pcall(function()object[key]=mixValue(initial,target,value)end)
                    end
                end

                if math.abs(1-value)<0.0015 and math.abs(velocity)<0.015 then break end
                if now-started>1.35 then break end
                run.RenderStepped:Wait()
            end

            if not handle.cancelled and not self.destroyed and object.Parent then
                for key,target in pairs(properties)do pcall(function()object[key]=target end)end
            end
            if self.motion[object]==handle then self.motion[object]=nil end
        end)
        return handle
    end
    local function animate(object,duration,properties)
        return animateEase(object,duration,properties,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
    end
    local function tapPulse(scaleObject)
        if not scaleObject or not scaleObject.Parent then return end
        if self.lowDetail or options.env.RockBugHologramMotion==false then scaleObject.Scale=1 return end
        animateEase(scaleObject,0.065,{Scale=0.935},Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
        task.delay(0.06,function()
            if self.destroyed or not scaleObject.Parent then return end
            animateEase(scaleObject,0.15,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
        end)
    end
    local function assign(object,key,value)
        if object[key]~=value then object[key]=value end
    end
    local function setText(object,value)
        -- T64's stable caption module owns farm captions. Respect its locks;
        -- update their value outside FARM so they cannot restore a stale caption.
        local captions=runtime.stableFarmCards
        local lock=captions and captions.locks and captions.locks[object]
        if lock then
            if self.group=="farm" then return end
            lock.value=value
        end
        assign(object,"Text",value)
    end
    function self:CancelMotion()
        self.modalToken+=1;self.closingModal=false
        for _,tween in pairs(self.motion)do tween:Cancel()end
        self.motion={}
        if self.transitionBlocker then self.transitionBlocker.Visible=false end
    end
    local function round(object, radius)
        create("UICorner", {CornerRadius=UDim.new(0,radius or 12)}, object)
    end
    local function edge(object, transparency, thickness)
        return create("UIStroke", {ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Color=cyan, Transparency=transparency or 0.45, Thickness=thickness or 1.4}, object)
    end
    local function tr(ru, en) return runtime.language == "en" and en or ru end
    local function number(value)
        value = tonumber(value)
        if not value or value ~= value then return "—" end
        local absolute = math.abs(value)
        for _, unit in ipairs({{1e15,"Q"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}) do
            if absolute >= unit[1] then return string.format("%.2f%s",value/unit[1],unit[2]):gsub("%.00", "") end
        end
        return string.format("%.0f",value)
    end
    local function label(parent, text, x, y, w, h, size, color, bold)
        return create("TextLabel", {AutoLocalize=false, Active=false, ZIndex=2, BackgroundTransparency=1, BorderSizePixel=0, Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h), Text=text, TextSize=size or 20, TextColor3=color or white, Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, TextTruncate=Enum.TextTruncate.AtEnd}, parent)
    end
    local function part(name, parent)
        return create("Part", {Name=name, Anchored=true, CanCollide=false, CanTouch=false, CanQuery=false, CastShadow=false, Transparency=1, Size=Vector3.new(1,1,0.025)}, parent)
    end
    self.world = create("Model", {Name="RockBugHubHologram"..versionTag})
    self.surfaces = create("Folder", {Name="RockBugHubHologramSurfaces"}, playerGui)
    self.overlay = create("ScreenGui", {Name="RockBugHubHologramControl", ResetOnSpawn=false, DisplayOrder=1000010, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, playerGui)
    -- Compact utility controls live in the lower-right gap between Roblox controls.
    -- Keep them small and together so they do not sit over the center hotbar.
    self.menu = create("TextButton", {Name="OpenFullMenu", AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-108,1,-66), Size=UDim2.fromOffset(82,34), BackgroundColor3=background, BackgroundTransparency=0.08, TextColor3=white, TextSize=10, Font=Enum.Font.GothamBold, Text=tr("НАСТР.","SET"), AutoButtonColor=false, ZIndex=12},self.overlay)
    self.menuScale=create("UIScale",{Scale=1},self.menu)
    round(self.menu,13); edge(self.menu,0.5)
    self.handle = create("TextButton", {Name="ToggleHologram", AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-20,1,-66), Size=UDim2.fromOffset(82,34), BackgroundColor3=background, BackgroundTransparency=0.08, TextColor3=cyan, TextSize=10, Font=Enum.Font.GothamBold, Text="", AutoButtonColor=false, ZIndex=12}, self.overlay)
    self.handleScale=create("UIScale",{Scale=1},self.handle)
    round(self.handle,13); edge(self.handle,0.12)
    self.noticePanel=create("Frame",{Name="DetailsPopup",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(336,180),BackgroundColor3=Color3.fromRGB(45,91,112),BorderSizePixel=0,Visible=false,ZIndex=40,Active=true},self.overlay)
    self.noticeScale=create("UIScale",{Scale=1},self.noticePanel)
    round(self.noticePanel,24);edge(self.noticePanel,0.2,1.5)
    local noticeTitle=label(self.noticePanel,tr("ПОДРОБНОСТИ","DETAILS"),16,8,270,30,12,cyan,true)
    local noticeScroll=create("ScrollingFrame",{Position=UDim2.fromOffset(16,44),Size=UDim2.new(1,-32,1,-58),CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,Active=true},self.noticePanel)
    self.notice=label(noticeScroll,"",0,0,300,0,14,white)
    self.notice.Name="ActionResult";self.notice.Size=UDim2.new(1,-8,0,0)
    self.notice.TextWrapped=true;self.notice.TextTruncate=Enum.TextTruncate.None
    self.notice.AutomaticSize=Enum.AutomaticSize.Y;self.notice.Visible=false
    self.noticeClose=create("TextButton",{Text="×",Position=UDim2.new(1,-42,0,6),Size=UDim2.fromOffset(34,34),BackgroundTransparency=1,TextColor3=white,TextSize=22,Font=Enum.Font.GothamBold,Active=true},self.noticePanel)
    connect(self.noticeClose.Activated,function()self.noticeToken+=1;self.noticePanel.Visible=false;self.notice.Visible=false end)

    function self:Notify(message)
        if self.destroyed or self.suspended or self.chestInput or not self.visible then return end
        self.noticeToken+=1
        local token=self.noticeToken
        self.notice.Text=tostring(message);self.notice.Visible=true
        noticeTitle.Text=tr("ПОДРОБНОСТИ","DETAILS")
        local size=self.overlay.AbsoluteSize
        if not size or size.X<1 or size.Y<1 then size=workspace.CurrentCamera.ViewportSize end
        local origin=self:OriginBounds(self.actionPanel,size)
        local layout=HUD.popupLayout(size.X,size.Y,origin,336,180)
        self.noticePanel.Size=UDim2.fromOffset(layout.w,layout.h)
        self.noticePanel.Position=UDim2.fromOffset(layout.x,layout.y+12)
        self.noticeScale.Scale=0.9
        self.noticePanel.Visible=true;noticeScroll.CanvasPosition=Vector2.new(0,0)
        animateEase(self.noticePanel,0.22,{Position=UDim2.fromOffset(layout.x,layout.y)},Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
        animateEase(self.noticeScale,0.26,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
        task.delay(8,function()
            if self.destroyed or token~=self.noticeToken then return end
            animateEase(self.noticeScale,0.16,{Scale=0.94},Enum.EasingStyle.Quad,Enum.EasingDirection.In)
            animateEase(self.noticePanel,0.16,{Position=UDim2.fromOffset(layout.x,layout.y+8)},Enum.EasingStyle.Quad,Enum.EasingDirection.In)
            task.delay(0.16,function()
                if not self.destroyed and token==self.noticeToken then self.notice.Visible=false;self.noticePanel.Visible=false end
            end)
        end)
    end

    function self:ClearPresses()
        for _,p in ipairs(self.panels)do for _,b in ipairs(p.buttons)do
            if b.press then b.press.cancelled=true end
            if b.node.Parent then
                b.node.BackgroundTransparency=rowRest
                if b.scale then b.scale.Scale=1 end
                if b.stroke then b.stroke.Transparency=0.78 b.stroke.Thickness=1 end
            end
        end end
        self.pressed={}; self.inputGeneration+=1
    end

    function self:Destroy()
        if self.destroyed then return end
        self.destroyed=true; self.visible=false
        self:ClearPresses(); self.noticeToken+=1
        self:CancelMotion()
        if options.content then pcall(function()options.content:Close()end)end
        for _,tab in ipairs(self.modalTabs)do tab.connection:Disconnect()end
        pcall(function()run:UnbindFromRenderStep(binding)end)
        for _, connection in ipairs(self.connections) do pcall(function()connection:Disconnect()end) end
        self.connections={}; self.pressed={}
        for _, object in ipairs({self.world,self.surfaces,self.overlay}) do if object then pcall(function()object:Destroy()end) end end
        if runtime.hologram == self then runtime.hologram=nil end
    end

    local function panel(id, title, x, y, width, height, canvasHeight)
        local p = {id=id, x=x, y=y, w=width, h=height, cw=400, ch=canvasHeight, buttons={}}
        -- Screen-space layers can sit above game gain popups; SurfaceGui cannot.
        -- The camera projects the original character-relative anchors every frame.
        p.gui = create("ScreenGui", {Name="RockBugPanel_"..id, ResetOnSpawn=false, DisplayOrder=panelOrder, IgnoreGuiInset=true, ScreenInsets=Enum.ScreenInsets.None, ClipToDeviceSafeArea=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Enabled=false}, self.surfaces)
        p.screenRoot=create("Frame",{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=false},p.gui)
        p.canvas=create("Frame",{Size=UDim2.fromOffset(p.cw,p.ch),BackgroundTransparency=1,BorderSizePixel=0},p.screenRoot)
        p.depth=create("Frame",{Position=UDim2.fromOffset(5,7),Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(17,48,67),BorderSizePixel=0,BackgroundTransparency=0.12,ZIndex=1,Active=false},p.canvas)
        round(p.depth,40);edge(p.depth,0.7,1)
        p.frame = create("Frame", {Size=UDim2.fromOffset(p.cw,p.ch), Active=false, BackgroundColor3=Color3.fromRGB(255,255,255), BackgroundTransparency=0, BorderSizePixel=0, ClipsDescendants=true, ZIndex=2}, p.canvas)
        -- A separate background shield sits below controls, never around them.
        p.shield=create("TextButton",{Name="PanelBackground",Size=UDim2.fromScale(1,1),Text="",Active=true,Selectable=false,AutoButtonColor=false,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=1},p.frame)
        p.scale=create("UIScale",{Scale=1},p.canvas)
        round(p.frame,38); p.stroke=edge(p.frame,0.1,2)
        -- UIGradient multiplies the base color: white preserves these teal values.
        create("UIGradient", {Rotation=100, Color=ColorSequence.new(Color3.fromRGB(44,94,115),Color3.fromRGB(24,57,78))},p.frame)
        local rim=create("Frame",{Position=UDim2.fromOffset(8,8), Size=UDim2.new(1,-16,1,-16), BackgroundTransparency=1},p.frame)
        round(rim,32); edge(rim,0.8,1)
        create("Frame",{Position=UDim2.fromOffset(26,0),Size=UDim2.fromOffset(80,3),BackgroundColor3=cyan,BorderSizePixel=0},p.frame)
        if title then
            p.title=label(p.frame,title,24,16,352,30,21,cyan,true)
            create("Frame",{Position=UDim2.fromOffset(24,56),Size=UDim2.fromOffset(352,1),BackgroundColor3=cyan,BackgroundTransparency=0.7,BorderSizePixel=0},p.frame)
        end
        table.insert(self.panels,p)
        self[id]=p
        return p
    end
    local function button(p, text, x, y, w, h, callback)
        local row=create("TextButton",{Text="",Active=true,ZIndex=3,AutoButtonColor=false,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=cyan,BackgroundTransparency=rowRest,BorderSizePixel=0,ClipsDescendants=true},p.frame)
        round(row,18)
        local rowScale=create("UIScale",{Scale=1},row)
        local rowStroke=edge(row,0.78,1)
        local textNode=label(row,text,14,0,w-28,h,19,white,false)
        local b={x=x,y=y,w=w,h=h,node=row,text=textNode,callback=callback,owner=p,scale=rowScale,stroke=rowStroke}
        -- Roblox resolves the visible button. Pointer tracking only cancels drags;
        -- it is not a second dispatcher or a prerequisite for Activated.
        connect(row.InputBegan,function(event)
            if event.UserInputType~=Enum.UserInputType.MouseButton1 and event.UserInputType~=Enum.UserInputType.Touch then return end
            local key=event.UserInputType==Enum.UserInputType.Touch and event or "mouse"
            b.press={button=b,x=event.Position.X,y=event.Position.Y,generation=self.inputGeneration,key=key,cancelled=not self:CanActivateButton(b)}
            self.pressed[key]=b.press
            if not b.press.cancelled then
                row.BackgroundTransparency=rowPressed
                animateEase(rowStroke,0.08,{Transparency=0.12,Thickness=1.8},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
                tapPulse(rowScale)
            end
        end)
        connect(row.Activated,function(event)
            local pressed=b.press;b.press=nil
            row.BackgroundTransparency=rowRest
            animateEase(rowStroke,0.18,{Transparency=0.78,Thickness=1},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
            if rowScale.Scale<0.99 then animateEase(rowScale,0.16,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)end
            if pressed and self.pressed[pressed.key]==pressed then self.pressed[pressed.key]=nil end
            local pointer=not event or event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch
            if pointer and pressed and (pressed.cancelled or pressed.generation~=self.inputGeneration)then return end
            if self:CanActivateButton(b)then self:ActivateButton(b,self.inputGeneration)end
        end)
        connect(row.MouseEnter,function()
            if self:CanActivateButton(b)then animate(row,0.12,{BackgroundTransparency=0.62})end
        end)
        connect(row.MouseLeave,function()animate(row,0.16,{BackgroundTransparency=rowRest})end)
        table.insert(p.buttons,b)
        return b
    end

    local function lever(key)
        local ref=runtime.leverRefs
        for component in tostring(key or ""):gmatch("[^.]+")do ref=ref and ref[component]end
        return ref and ref.Get and ref.Set and ref or nil
    end
    local function open(tab,origin)self:OpenFull(tab,origin or self.actionPanel)end
    local function nativeButton(parent,text,position,size,callback)
        local b=create("TextButton",{Position=position,Size=size,Text=text,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=white,BackgroundColor3=background,BackgroundTransparency=0.1,BorderSizePixel=0,AutoButtonColor=false,ClipsDescendants=true,TextTruncate=Enum.TextTruncate.AtEnd},parent)
        round(b,16)
        local stroke=edge(b,0.6)
        local scale=create("UIScale",{Scale=1},b)
        connect(b.InputBegan,function(event)
            if event.UserInputType==Enum.UserInputType.Touch or event.UserInputType==Enum.UserInputType.MouseButton1 then
                tapPulse(scale)
                animateEase(stroke,0.08,{Transparency=0.14,Thickness=1.8},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
            end
        end)
        connect(b.Activated,function(...)
            animateEase(stroke,0.18,{Transparency=0.6,Thickness=1},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
            callback(...)
        end)
        connect(b.MouseEnter,function()
            animate(b,0.12,{BackgroundTransparency=0})
            animateEase(stroke,0.12,{Transparency=0.28},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
        end)
        connect(b.MouseLeave,function()
            animate(b,0.16,{BackgroundTransparency=0.1})
            animateEase(stroke,0.16,{Transparency=0.6},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
        end)
        return b
    end

    -- Native bottom buttons receive touch/clicks directly, independently of 3D rays.
    self.nav=create("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-10),Size=UDim2.new(1,-24,0,40),BackgroundTransparency=1,Visible=false},self.overlay)
    create("UISizeConstraint",{MaxSize=Vector2.new(328,40)},self.nav)
    self.groupButtons={}
    for i,id in ipairs({"farm","growth","kill"})do
        local group=id
        self.groupButtons[group]=nativeButton(self.nav,tr(HUD.groups[group].ru,HUD.groups[group].en),UDim2.new((i-1)/3,3,0,0),UDim2.new(1/3,-6,1,0),function()self:SelectGroup(group)end)
    end
    self.cardTabs=create("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-58),Size=UDim2.new(1,-32,0,32),BackgroundTransparency=1,Visible=false},self.overlay)
    self.cardButtons={}
    for i=1,4 do
        local index=i
        local b=nativeButton(self.cardTabs,"",UDim2.new((i-1)/4,2,0,0),UDim2.new(0.25,-4,1,0),function()self:ClearPresses();self.cardPage=index;self.nextRefresh=nil;self.openedAt=os.clock();self.visualElapsed=1 end)
        b.TextSize=10;table.insert(self.cardButtons,b)
    end

    -- A floating console grows from the chosen card, with a visible connection.
    self.sheet=create("Frame",{Name="OrbitConsole",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false,Visible=false,ZIndex=20},self.overlay)
    self.link=create("Frame",{Name="CardConnection",AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=cyan,BackgroundTransparency=0.3,BorderSizePixel=0,Active=false,Visible=false,ZIndex=20},self.sheet)
    self.windowShell=create("Frame",{Name="FloatingConsole",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(364,424),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=21},self.sheet)
    self.windowScale=create("UIScale",{Scale=1},self.windowShell)
    local depth=create("Frame",{Position=UDim2.fromOffset(5,7),Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(17,48,67),BorderSizePixel=0,ZIndex=1},self.windowShell)
    round(depth,32);edge(depth,0.7,1)
    self.window=create("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(255,255,255),BorderSizePixel=0,Active=true,ClipsDescendants=true,ZIndex=2},self.windowShell)
    round(self.window,28);self.windowStroke=edge(self.window,0.25,1.5)
    create("UIGradient",{Rotation=105,Color=ColorSequence.new(Color3.fromRGB(49,99,119),Color3.fromRGB(29,64,85))},self.window)
    self.windowContext=label(self.window,"",18,9,220,16,10,cyan,true)
    self.windowContext.Name="OrbitContext"
    self.windowTitle=label(self.window,"",18,26,210,28,18,white,true)
    self.windowTitle.Size=UDim2.new(1,-136,0,28)
    self.close=nativeButton(self.window,"×",UDim2.new(1,-50,0,14),UDim2.fromOffset(36,36),function()self:CloseFull()end)
    self.stop=nativeButton(self.window,"STOP",UDim2.new(1,-112,0,14),UDim2.fromOffset(56,36),function()options.content:StopModes()end)
    self.stop.TextColor3=Color3.fromRGB(255,173,174)
    self.sectionTabs=create("ScrollingFrame",{Position=UDim2.fromOffset(14,62),Size=UDim2.new(1,-28,0,42),CanvasSize=UDim2.fromOffset(0,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,ScrollingDirection=Enum.ScrollingDirection.X,Active=true,ClipsDescendants=true},self.window)
    self.quickHost=create("Frame",{Position=UDim2.fromOffset(16,112),Size=UDim2.new(1,-32,0,34),BackgroundTransparency=1,ClipsDescendants=true},self.window)
    self.body=create("Frame",{Position=UDim2.fromOffset(16,112),Size=UDim2.new(1,-32,1,-150),BackgroundTransparency=1,ClipsDescendants=true},self.window)
    self.footer=create("Frame",{Position=UDim2.new(0,16,1,-32),Size=UDim2.new(1,-32,0,24),BackgroundTransparency=1,ClipsDescendants=true},self.window)
    self.dialogHost=create("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=80,Active=false},self.window)
    self.transitionBlocker=create("TextButton",{Size=UDim2.fromScale(1,1),Text="",BackgroundTransparency=1,Active=true,Selectable=false,Visible=false,ZIndex=100},self.window)

    function self:OriginBounds(origin,size)
        local bounds=origin and origin.bounds
        if not bounds then return nil end
        -- The overlay uses the safe screen area; cards use viewport coordinates.
        local camera=workspace.CurrentCamera
        local view=camera and camera.ViewportSize or size
        return {x=bounds.x*size.X/view.X,y=bounds.y*size.Y/view.Y,w=bounds.w*size.X/view.X,h=bounds.h*size.Y/view.Y}
    end
    function self:LayoutDrawer(animateOpen)
        if not self.modalOpen then return end
        local size=self.sheet.AbsoluteSize
        if not size or size.X<1 or size.Y<1 then size=workspace.CurrentCamera.ViewportSize end
        local layout=HUD.popupLayout(size.X,size.Y,self:OriginBounds(self.modalOrigin,size))
        self.popupLayout=layout
        self.windowShell.Size=UDim2.fromOffset(layout.w,layout.h)
        local target=UDim2.fromOffset(layout.x,layout.y)
        self.popupStart=UDim2.fromOffset(layout.x+(layout.sourceX-layout.x)*0.24,layout.y+(layout.sourceY-layout.y)*0.24)
        if animateOpen then
            self.windowShell.Position=self.popupStart
            self.windowScale.Scale=0.84
            self.windowStroke.Transparency=0.92
            self.modalTween=animateEase(self.windowShell,0.28,{Position=target},Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
            animateEase(self.windowScale,0.34,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
            animateEase(self.windowStroke,0.28,{Transparency=0.25,Thickness=1.5},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
        else
            if self.motion[self.windowShell]then self.motion[self.windowShell]:Cancel()end
            if self.motion[self.windowScale]then self.motion[self.windowScale]:Cancel()end
            self.windowShell.Position=target;self.windowScale.Scale=1
        end
        local linked=layout.linked and self.modalOrigin~=nil
        self.link.Visible=linked
        if linked then
            local endX=layout.sourceX<layout.x and layout.x-layout.w/2 or layout.x+layout.w/2
            local dx,dy=endX-layout.sourceX,layout.y-layout.sourceY
            self.link.Position=UDim2.fromOffset(layout.sourceX,layout.sourceY)
            self.link.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),2)
            self.link.Rotation=math.deg(math.atan2(dy,dx))
        end
        for _,panel in ipairs(self.panels)do panel.gui.Enabled=linked and panel==self.modalOrigin and not self.suspended and not self.chestInput end
        local refresh=self.modalTab=="bug" or self.modalTab=="farm"
        self.quickHost.Visible=refresh
        local top=refresh and 150 or 112
        self.body.Position=UDim2.fromOffset(16,top)
        self.body.Size=UDim2.new(1,-32,1,-top-36)
    end
    connect(self.sheet:GetPropertyChangedSignal("AbsoluteSize"),function()self:LayoutDrawer(false)end)

    function self:OpenFull(tab,origin,requestedGroup)
        if self.destroyed or self.suspended or self.chestInput or not HUD.sections[tab] then return false end
        local group=requestedGroup or self.group
        local function contains(id)
            for _,entry in ipairs(HUD.groups[id].tabs)do if entry==tab then return true end end
            return false
        end
        if not contains(group) then
            for _,id in ipairs({"farm","growth","kill","settings"})do if contains(id)then group=id;break end end
        end
        local ok=options.content:Attach(tab,self.body,self.dialogHost,self.quickHost,self.footer)
        if not ok then self:Notify(tr("Раздел недоступен","Section unavailable"));return false end
        local wasOpen=self.modalOpen
        self:CancelMotion()
        if not wasOpen then self.modalReturnVisible=self.visible;self.modalOrigin=origin end
        self.visible=true;self.modalOpen=true;self.modalTab=tab;self.modalGroup=group
        for _,entry in ipairs(self.modalTabs)do entry.connection:Disconnect();entry.node:Destroy()end
        self.modalTabs={}
        local selectedIndex=1
        for i,id in ipairs(HUD.groups[group].tabs)do
            local section=id
            local title=HUD.sections[section]
            local b=create("TextButton",{Position=UDim2.fromOffset((i-1)*110,0),Size=UDim2.fromOffset(104,36),Text=tr(title[1],title[2]),Font=Enum.Font.GothamBold,TextSize=13,TextColor3=section==tab and background or white,BackgroundColor3=section==tab and cyan or Color3.fromRGB(37,75,94),BorderSizePixel=0,AutoButtonColor=true},self.sectionTabs)
            round(b,14)
            local connection=b.Activated:Connect(function()self:OpenFull(section,nil,group)end)
            table.insert(self.modalTabs,{node=b,connection=connection,id=section})
            if section==tab then selectedIndex=i end
        end
        self.sectionTabs.CanvasSize=UDim2.fromOffset(#self.modalTabs*110,0)
        self.sectionTabs.CanvasPosition=Vector2.new(math.max(0,(selectedIndex-2)*110),0)
        self.windowTitle.Text=tr(HUD.sections[tab][1],HUD.sections[tab][2])
        self.windowContext.Text=tr(HUD.groups[group].ru,HUD.groups[group].en).." / RB • "..versionTag
        self:ApplyVisibility()
        self:LayoutDrawer(not wasOpen)
        if wasOpen then
            local targetY=(self.modalTab=="bug" or self.modalTab=="farm")and 150 or 112
            self.body.Position=UDim2.fromOffset(28,targetY+8)
            animateEase(self.body,0.20,{Position=UDim2.fromOffset(16,targetY)},Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
            self.sectionTabs.Position=UDim2.fromOffset(14,66)
            animateEase(self.sectionTabs,0.18,{Position=UDim2.fromOffset(14,62)},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
        end
        return true
    end
    function self:CloseFull(immediate)
        if self.destroyed or not self.modalOpen or self.closingModal then return end
        self:CancelMotion()
        if runtime.closePicker then runtime.closePicker()end
        if runtime.closeDeleteConfirmation then runtime.closeDeleteConfirmation()end
        local token=self.modalToken
        local function finish()
            if self.destroyed or token~=self.modalToken then return end
            self.closingModal=false;self.modalOpen=false;self.modalTab=nil;self.modalOrigin=nil
            self.visible=self.modalReturnVisible~=false
            options.content:Close();self:ApplyVisibility()
        end
        if immediate or self.lowDetail or options.env.RockBugHologramMotion==false then finish();return end
        self.closingModal=true;self.transitionBlocker.Visible=true
        animateEase(self.windowStroke,0.14,{Transparency=0.92},Enum.EasingStyle.Quad,Enum.EasingDirection.In)
        animateEase(self.windowShell,0.18,{Position=self.popupStart or self.windowShell.Position},Enum.EasingStyle.Quad,Enum.EasingDirection.In)
        animateEase(self.windowScale,0.18,{Scale=0.86},Enum.EasingStyle.Quad,Enum.EasingDirection.In)
        task.delay(0.19,finish)
    end
    function self:RefreshLanguage()
        self.menu.Text=tr("НАСТРОЙКИ","SETTINGS")
        self.stop.Text=tr("СТОП","STOP")
        for id,node in pairs(self.groupButtons)do node.Text=tr(HUD.groups[id].ru,HUD.groups[id].en)end
        for _,entry in ipairs(self.modalTabs)do local title=HUD.sections[entry.id];entry.node.Text=tr(title[1],title[2])end
        if self.modalTab then local title=HUD.sections[self.modalTab];self.windowTitle.Text=tr(title[1],title[2]);self.windowContext.Text=tr(HUD.groups[self.modalGroup].ru,HUD.groups[self.modalGroup].en).." / RB • "..versionTag end
        self.nextRefresh=nil
    end
    function self:SelectGroup(id)
        if not HUD.groups[id] or id=="settings" or self.destroyed then return false end
        if self.modalOpen then self.modalOpen=false;options.content:Close()end
        self:ClearPresses();self.group=id;self.cardPage=1;self.nextRefresh=nil
        options.env.RockBugHologramGroup=id
        self.visible=true;self:ApplyVisibility()
        if not self.lowDetail and options.env.RockBugHologramMotion~=false then
            for i,node in pairs(self.groupButtons)do
                local scale=node:FindFirstChildOfClass("UIScale")
                if scale and i==id then
                    scale.Scale=0.9
                    animateEase(scale,0.22,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
                end
            end
        end
        return true
    end

    local strength=panel("strength","СИЛА / СЕК",-4,2.45,3.6,2.28,254)
    strength.value=label(strength.frame,"—",24,62,348,62,52,white,true)
    strength.total=label(strength.frame,"",26,125,348,26,17,muted)
    strength.bars={}
    for i=1,20 do strength.bars[i]=create("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromOffset(25+(i-1)*17.5,225),Size=UDim2.fromOffset(11,2),BackgroundColor3=cyan,BackgroundTransparency=0.25,BorderSizePixel=0},strength.frame)end
    local session=panel("session","СЕССИЯ",4,2.45,3.6,2.28,254)
    session.time=label(session.frame,"00:00:00",24,64,350,42,36,white,true)
    session.gain=label(session.frame,"",24,116,350,25,19,mint)
    session.rebirths=label(session.frame,"",24,150,350,25,19,white)
    session.network=label(session.frame,"",24,196,350,25,17,muted)
    button(session,"Ребирты →",264,16,112,32,function()open("reb",session)end).text.TextSize=14
    for i=1,4 do
        local index=i
        local left=i%2==1
        local p=panel("card"..i,"",left and -4 or 4,i<=2 and 0 or -2.35,3.6,2.07,230)
        p.index=i
        p.primary=button(p,"",20,66,360,46,function()
            local def=HUD.groups[self.group].cards[index]
            if def.stopKill then
                for _,ref in pairs(runtime.leverRefs.kill or {})do if ref.Get()then ref.Set(false,false)end end
            elseif def.key then
                local ref=lever(def.key)
                if ref then local target=not ref.Get();ref.Set(target,false);if ref.Get()~=target then self:Notify(runtime.status or tr("Проверьте настройки","Check settings"))end
                else open(def.tab,p)end
            else open(def.actionTab or def.tab,p)end
        end)
        p.primary.text.Size=UDim2.fromOffset(260,46)
        p.state=label(p.primary.node,"",276,0,70,46,17,mint,true)
        p.hint=label(p.frame,"",24,119,350,36,16,muted)
        p.hint.TextWrapped=true;p.hint.TextTruncate=Enum.TextTruncate.AtEnd
        p.more=button(p,"",20,172,360,42,function()open(HUD.groups[self.group].cards[index].tab,p)end)
        table.insert(self.cards,p)
    end
    local title=panel("title",nil,0,2.75,3.85,0.96,100)
    title.frame.BackgroundTransparency=1;title.frame.Active=false
    title.shield:Destroy();title.depth:Destroy()
    for _,child in ipairs(title.frame:GetChildren())do if child:IsA("UIStroke")or child:IsA("Frame")then child:Destroy()end end
    local brand=label(title.frame,"RockBugHub",0,0,400,53,43,white,true);brand.TextXAlignment=Enum.TextXAlignment.Center
    local tagline=label(title.frame,"TRAIN / EXPLORE / "..versionTag,0,58,400,26,14,cyan);tagline.TextXAlignment=Enum.TextXAlignment.Center

    -- Shared vertices: 43 beams / 39 attachments, instead of 129 / 258.
    self.ringRoot=part("Orbit",self.world)
    self.crystalRoot=part("Crystal",self.world)
    self.detailBeams={}
    local function vertex(parent,position)return create("Attachment",{Position=position},parent)end
    local function beam(parent,a,b,width,transparency,detail)
        local object=create("Beam",{Attachment0=a,Attachment1=b,Width0=width,Width1=width,Color=ColorSequence.new(cyan),Transparency=NumberSequence.new(transparency),FaceCamera=true,LightEmission=1,Segments=1},parent)
        table.insert(self.beams,object)
        if detail then table.insert(self.detailBeams,object)end
    end
    for ring,radius in ipairs({2.6,3.05})do
        local vertices={}
        for i=0,15 do vertices[i+1]=vertex(self.ringRoot,Vector3.new(math.cos(i*math.pi/8)*radius,0,math.sin(i*math.pi/8)*radius))end
        for i=1,16 do if i%8~=0 then beam(self.ringRoot,vertices[i],vertices[i%16+1],ring==1 and 0.034 or 0.018,ring==1 and 0.2 or 0.5,ring==2)end end
    end
    local top=vertex(self.crystalRoot,Vector3.new(0,0.65,0))
    local bottom=vertex(self.crystalRoot,Vector3.new(0,-0.3,0))
    local vertices={}
    for i=1,5 do vertices[i]=vertex(self.crystalRoot,Vector3.new(math.cos(i*math.pi*0.4)*0.25,0,math.sin(i*math.pi*0.4)*0.25))end
    for i=1,5 do
        beam(self.crystalRoot,vertices[i],vertices[i%5+1],0.018,0.2,true)
        beam(self.crystalRoot,vertices[i],top,0.018,0.2,true)
        beam(self.crystalRoot,vertices[i],bottom,0.018,0.2,true)
    end

    local function refresh(now)
        local group=HUD.groups[self.group]
        for id,node in pairs(self.groupButtons)do
            setText(node,tr(HUD.groups[id].ru,HUD.groups[id].en))
            node.BackgroundColor3=id==self.group and cyan or background
            node.TextColor3=id==self.group and background or white
        end
        for i,p in ipairs(self.cards)do
            local def=group.cards[i]
            setText(p.title,tr(def.ru,def.en))
            setText(p.primary.text,tr(def.actionRu,def.actionEn))
            setText(p.more.text,tr(def.moreRu,def.moreEn).."  →")
            setText(self.cardButtons[i],tr(def.ru,def.en))
            self.cardButtons[i].BackgroundColor3=i==self.cardPage and Color3.fromRGB(19,67,82) or background
            local ref=def.key and lever(def.key)
            local refValue=ref and ref.Get() or nil
            setText(p.state,ref and (refValue and tr("ВКЛ","ON") or tr("ВЫКЛ","OFF")) or "→")
            p.state.TextColor3=ref and refValue and mint or muted
            if ref then
                if p.lastRefValue~=nil and p.lastRefValue~=refValue and p.primary and p.primary.scale then
                    p.primary.scale.Scale=refValue and 0.92 or 1.04
                    animateEase(p.primary.scale,0.22,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
                    if p.primary.stroke then
                        p.primary.stroke.Transparency=refValue and 0.06 or 0.5
                        animateEase(p.primary.stroke,0.28,{Transparency=0.78,Thickness=1},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
                    end
                end
                p.lastRefValue=refValue
            else
                p.lastRefValue=nil
            end
            local hint=tr("Настройки выбранного режима","Settings for this mode")
            if def.tab=="farm" then hint=tostring(runtime.machineActive and runtime.machineRecoveryStatus or runtime.selectedMachine and (runtime.selectedMachine.label or runtime.selectedMachine.name or runtime.selectedMachine.kind) or tr("Выберите тренажёр","Choose a machine"))
            elseif def.tab=="bug" then hint=tr("Авто ребирт: ","Auto rebirth: ")..(runtime.autoRebirth and "ON" or "OFF")
            elseif def.tab=="train" then hint=tr("Упражнения, фиксация и темп","Exercises, position lock and pace")
            elseif def.tab=="boss" then hint=tr("Автобой, награда и возврат","Auto fight, reward and return")
            elseif def.tab=="crystal" then hint=tostring(runtime.selectedCrystal or tr("Выберите товар","Choose an item"))
            elseif def.tab=="egg" then hint=tr("Интервал: ","Interval: ")..tostring((tonumber(runtime.eggIntervalMultiplier)or 1)*30)..tr(" мин."," min")
            elseif def.tab=="quest" then hint=tostring(runtime.questLastMessage or tr("Выбор NPC и заданий","NPC and quest selection"))
            elseif def.tab=="kill" then hint=tr("Режим: ","Mode: ")..tostring(runtime.killMode or "off")
            elseif def.tab=="teleport" and runtime.equippedPetState then
                local ok,_,slots,count=pcall(runtime.equippedPetState)
                setText(p.hint,ok and slots and tr("Питомцы: ","Pets: ")..tostring(count).." / "..tostring(slots) or tr("Данные питомцев загружаются","Loading pet data"))
            end
            setText(p.hint,hint)
        end
        setText(strength.title,tr("СИЛА / СЕК","STRENGTH / SEC"));setText(session.title,tr("СЕССИЯ","SESSION"))
        local elapsed=math.max(0,math.floor(now-(runtime.sessionStatsStartedAt or now)))
        setText(session.time,string.format("%02d:%02d:%02d",math.floor(elapsed/3600),math.floor(elapsed/60)%60,elapsed%60))
        setText(session.gain,tr("Сила: +","Strength: +")..number(runtime.sessionStrengthGained))
        setText(session.rebirths,tr("Ребирты: +","Rebirths: +")..number(runtime.sessionRebirthGained))
        setText(session.network,(runtime.pingAvailable and number(runtime.pingMs).." ms" or "— ms").." / "..number(self.fps).." FPS")
        setText(session.buttons[1].text,tr("Ребирты →","Rebirths →"))
        setText(strength.total,tr("Всего: ","Total: ")..number(runtime.sessionStrengthCurrent))
        local gained=tonumber(runtime.sessionStrengthGained)or 0
        local rate=self.lastSample and math.max(0,gained-self.lastSample.gained)/math.max(0.01,now-self.lastSample.time)or 0
        self.lastSample={time=now,gained=gained}
        table.insert(self.samples,rate);if #self.samples>20 then table.remove(self.samples,1)end
        setText(strength.value,number(rate))
        local maximum=1;for _,value in ipairs(self.samples)do maximum=math.max(maximum,value)end
        for i,bar in ipairs(strength.bars)do bar.Size=UDim2.fromOffset(11,math.max(2,(self.samples[i]or 0)/maximum*57))end
        setText(self.menu,tr("НАСТР.","SET"))
    end

    function self:CanActivateButton(button)
        return not self.destroyed and runtime.alive and self.visible and not self.suspended
            and not self.chestInput and self.ready and self.inputReady and not self.modalOpen
            and button.owner.gui.Enabled and button.node.Parent~=nil
            and not input:GetFocusedTextBox() and not guiService.MenuIsOpen
    end
    function self:ActivateButton(button,generation)
        task.spawn(function()
            if generation~=self.inputGeneration or not self:CanActivateButton(button) then return end
            self.actionPanel=button.owner
            local callback=button.callback
            -- Card 4 is shared between groups. In FARM its secondary action is
            -- always boss settings; in other groups it follows that group's card 4.
            if runtime.bossCompactUI and button==self.cards[4].more then
                if self.group=="farm" then
                    callback=function()self:OpenFull("boss",button.owner)end
                else
                    callback=function()self:OpenFull(HUD.groups[self.group].cards[4].tab,button.owner)end
                end
            end
            local ok,reason=pcall(callback)
            self.nextRefresh=nil
            if not ok then
                local message=tr("Не удалось выполнить действие: ","Action failed: ")..tostring(reason)
                options.report(message);self:Notify(message)
            end
        end)
    end
    local function render(dt)
        if self.destroyed or not runtime.alive then return end
        self.fps=self.fps==0 and 1/math.max(dt,0.001) or self.fps+(1/math.max(dt,0.001)-self.fps)*math.min(1,dt*2)
        self.slowTime=self.fps<38 and (self.slowTime or 0)+dt or 0
        self.fastTime=self.fps>50 and (self.fastTime or 0)+dt or 0
        local low=self.lowDetail
        if self.slowTime>2 then low=true elseif self.fastTime>5 then low=false end
        if low~=self.lowDetail then
            self.lowDetail=low
            for _,object in ipairs(self.detailBeams)do object.Enabled=not low end
        end
        self.visualElapsed+=dt
        local interval=self.lowDetail and 1/20 or 1/30
        local camera=workspace.CurrentCamera
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local viewport=camera and camera.ViewportSize
        local changed=self.inputCamera~=camera or self.inputRoot~=root or (viewport and (self.viewportX~=viewport.X or self.viewportY~=viewport.Y))
        if self.visualElapsed+0.000001<interval and not changed and self.nextRefresh then return end
        local elapsed=self.visualElapsed;self.visualElapsed=0
        if changed then
            self:ClearPresses();self.inputCamera=camera;self.inputRoot=root
            self.viewportX=viewport and viewport.X;self.viewportY=viewport and viewport.Y
        end
        if not camera or not root then
            self.ready=false;self.world.Parent=nil
            for _,p in ipairs(self.panels)do assign(p.gui,"Enabled",false)end
            return
        end
        local depth=-camera.CFrame:PointToObjectSpace(root.Position).Z
        if depth<1 or viewport.X<1 or viewport.Y<1 then
            if self.ready then self:ClearPresses()end
            self.ready=false;self.world.Parent=nil
            for _,p in ipairs(self.panels)do assign(p.gui,"Enabled",false)end
            return
        end
        assign(self.world,"Parent",camera);self.ready=true
        if (guiService.MenuIsOpen or input:GetFocusedTextBox())and next(self.pressed)then self:ClearPresses()end
        local now=os.clock()
        local mode,designW,designH=HUD.layout(viewport.X,viewport.Y)
        local worldH=2*depth*math.tan(math.rad(camera.FieldOfView/2))
        local scale=math.min(worldH*(mode=="wide"and 0.82 or 0.9)/designH,worldH*viewport.X/viewport.Y*0.9/designW)*0.88
        local pixelsPerUnit=viewport.Y/worldH*scale
        assign(self.cardTabs,"Visible",mode=="portrait")
        if self.layoutMode~=mode then
            self.layoutMode=mode
            self.nav.Position=mode=="wide"and UDim2.new(0.5,0,0.86,0)or UDim2.new(0.5,0,1,-10)
        end
        local age=now-(self.openedAt or now)
        local animateOpen=not self.lowDetail and options.env.RockBugHologramMotion~=false
        self.inputReady=not animateOpen or age>=0.34
        -- Every panel shares a camera-aligned plane: one projection suffices.
        local center=camera:WorldToViewportPoint(root.Position)
        local held=next(self.pressed)~=nil
        for _,p in ipairs(self.panels)do
            local x,y,w=p.x,p.y,p.w
            local enabled=true
            if mode=="compact"then
                if p.index then x,y,w=p.index%2==1 and -5.2 or 5.2,p.index<=2 and 1.25 or -2.10,5.65
                elseif p.id=="title"then x,y,w=0,2.75,4.2 else enabled=false end
            elseif mode=="portrait"then
                if p.index and p.index==self.cardPage then x,y,w=0,-3.7,6.5
                elseif p.id=="title"then x,y,w=0,4.35,5.4 else enabled=false end
            end
            if enabled and not held then
                local progress=animateOpen and math.clamp((age-(p.index or 0)*0.018)/0.26,0,1)or 1
                local ease=1-(1-progress)^3
                local spread=0.86+0.14*ease
                local pixelScale=w*pixelsPerUnit/p.cw*(0.94+0.06*ease)
                local targetX,targetY=center.X+x*pixelsPerUnit*spread,center.Y-y*pixelsPerUnit*spread
                local alpha=changed and 1 or math.min(1,1-math.exp(-elapsed*18))
                if not p.px or age<0.36 then alpha=1 end
                p.px=(p.px or targetX)+(targetX-(p.px or targetX))*alpha
                p.py=(p.py or targetY)+(targetY-(p.py or targetY))*alpha
                local pixelW,pixelH=p.cw*pixelScale,p.ch*pixelScale
                p.bounds={x=p.px-pixelW/2,y=p.py-pixelH/2,w=pixelW,h=pixelH}
                enabled=center.Z>0 and p.bounds.x<viewport.X and p.bounds.y<viewport.Y and p.bounds.x+pixelW>0 and p.bounds.y+pixelH>0
                if not p.lastX or math.abs(p.lastX-p.px)>0.25 or math.abs(p.lastY-p.py)>0.25 then
                    p.screenRoot.Position=UDim2.fromOffset(p.px,p.py);p.lastX=p.px;p.lastY=p.py
                end
                if not p.lastScale or math.abs(p.lastScale-pixelScale)>0.0005 then
                    p.screenRoot.Size=UDim2.fromOffset(pixelW,pixelH);p.scale.Scale=pixelScale;p.lastScale=pixelScale
                end
            end
            assign(p.gui,"Enabled",enabled)
        end
        local effectInterval=self.lowDetail and 0.1 or 0.035
        if not self.lastEffects or now-self.lastEffects>=effectInterval or changed then
            self.lastEffects=now
            local humanoid=character:FindFirstChildOfClass("Humanoid")
            local leg=character:FindFirstChild("Left Leg")
            local footY=root.Position.Y-root.Size.Y/2-(humanoid and humanoid.HipHeight or 2)-(leg and leg.Size.Y or 0)
            local ringSpin=self.lowDetail and 0 or now*0.34
            self.ringRoot.CFrame=CFrame.new(root.Position.X,footY+0.05,root.Position.Z)*CFrame.Angles(0,ringSpin,0)
            local basis=CFrame.fromMatrix(root.Position,camera.CFrame.RightVector,camera.CFrame.UpVector,-camera.CFrame.LookVector)
            local bob=self.lowDetail and 0 or math.sin(now*2.15)*0.085*scale
            local sway=self.lowDetail and 0 or math.sin(now*1.35)*0.035
            self.crystalRoot.CFrame=basis*CFrame.new(0,(mode=="portrait"and 5.45 or 3.7)*scale+bob,0)*CFrame.Angles(0,0,sway)
        end
        if not self.nextRefresh or now>=self.nextRefresh then self.nextRefresh=now+0.5;refresh(now)end
    end
    function self:ApplyVisibility()
        run:UnbindFromRenderStep(binding)
        self:CancelMotion()
        self:ClearPresses(); self.ready=false; self.inputReady=false
        self.noticeToken+=1; self.notice.Visible=false;self.noticePanel.Visible=false
        local blocked=self.suspended or self.chestInput
        local show=self.visible and not self.modalOpen and not blocked and not self.destroyed
        self.world.Parent=nil
        for _,p in ipairs(self.panels) do p.gui.Enabled=false end
        if self.overlay then self.overlay.Enabled=not blocked and not self.destroyed end
        self.nav.Visible=show;self.cardTabs.Visible=false
        self.sheet.Visible=self.modalOpen and not blocked
        self.handle.Visible=not self.modalOpen;self.menu.Visible=not self.modalOpen
        options.content:HideLegacy()
        if show then
            if options.classicGui then options.classicGui.Enabled=false end
            self.openedAt=os.clock(); self.nextRefresh=nil; self.lastSample=nil;self.visualElapsed=1
            if not self.lowDetail and options.env.RockBugHologramMotion~=false then
                for index,p in ipairs(self.panels)do
                    p.canvas.Position=UDim2.fromOffset(0,14)
                    p.frame.BackgroundTransparency=0.22
                    p.stroke.Transparency=0.92
                    task.delay(math.min(0.16,(index-1)*0.018),function()
                        if self.destroyed or not self.visible or self.modalOpen or not p.canvas.Parent then return end
                        animateEase(p.canvas,0.26,{Position=UDim2.fromOffset(0,0)},Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
                        animateEase(p.frame,0.22,{BackgroundTransparency=0},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
                        animateEase(p.stroke,0.30,{Transparency=0.1,Thickness=2},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
                    end)
                end
            else
                for _,p in ipairs(self.panels)do
                    p.canvas.Position=UDim2.fromOffset(0,0)
                    p.frame.BackgroundTransparency=0
                    p.stroke.Transparency=0.1
                end
            end
            run:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value+1,function(dt)
                local ok,reason=pcall(render,dt)
                if not ok then
                    self:SetVisible(false)
                    self:OpenFull("system",nil,"settings")
                    options.report("HUD: "..tostring(reason))
                end
            end)
        end
        if self.modalOpen and not blocked then self:LayoutDrawer(false)end
        self.handle.Text=self.visible and tr("СКРЫТЬ · RB","HIDE · RB") or tr("ПОКАЗАТЬ","SHOW · RB")
    end
    function self:SetVisible(value)
        if self.destroyed then return end
        self.visible=value==true
        if not self.visible then
            if self.modalTween then self.modalTween:Cancel()end
            self.modalOpen=false;options.content:Close()
        end
        options.env.RockBugHologramVisible=self.visible
        self:ApplyVisibility()
    end
    function self:SetSuspended(value)
        if self.destroyed then return end
        self.suspended=value==true
        self:ApplyVisibility()
    end
    function self:SetChestInput(value)
        if self.destroyed then return end
        self.chestInput=value==true;self:ApplyVisibility()
    end
    connect(self.handle.InputBegan,function(event)
        if event.UserInputType==Enum.UserInputType.Touch or event.UserInputType==Enum.UserInputType.MouseButton1 then tapPulse(self.handleScale)end
    end)
    connect(self.menu.InputBegan,function(event)
        if event.UserInputType==Enum.UserInputType.Touch or event.UserInputType==Enum.UserInputType.MouseButton1 then tapPulse(self.menuScale)end
    end)
    connect(self.handle.Activated,function()self:SetVisible(not self.visible)end)
    connect(self.menu.Activated,function()self:OpenFull("system",nil,"settings")end)
    connect(input.InputChanged,function(event)
        local key=event.UserInputType==Enum.UserInputType.Touch and event or event.UserInputType==Enum.UserInputType.MouseMovement and "mouse" or nil
        local pressed=key and self.pressed[key]
        if pressed and (pressed.x-event.Position.X)^2+(pressed.y-event.Position.Y)^2>144 then
            pressed.cancelled=true
            pressed.button.node.BackgroundTransparency=rowRest
            if pressed.button.stroke then animateEase(pressed.button.stroke,0.14,{Transparency=0.78,Thickness=1},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)end
            if pressed.button.scale then animateEase(pressed.button.scale,0.14,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)end
        end
    end)
    connect(input.InputEnded,function(event)
        local key=event.UserInputType==Enum.UserInputType.Touch and event or event.UserInputType==Enum.UserInputType.MouseButton1 and "mouse" or nil
        local pressed=key and self.pressed[key]
        if not pressed then return end
        self.pressed[key]=nil
        if event.UserInputState==Enum.UserInputState.Cancel then pressed.cancelled=true end
        if pressed.button.node.Parent then
            pressed.button.node.BackgroundTransparency=rowRest
            if pressed.button.stroke then animateEase(pressed.button.stroke,0.14,{Transparency=0.78,Thickness=1},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)end
            if pressed.button.scale then animateEase(pressed.button.scale,0.14,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)end
        end
        -- Keep cancellation on the button until Activated or the next press:
        -- InputEnded can arrive before Activated on touch clients.
    end)
    connect(input.InputBegan,function(event,processed)
        if not processed and not input:GetFocusedTextBox() and event.KeyCode==Enum.KeyCode.RightShift then self:SetVisible(not self.visible) end
    end)
    self.visible=options.env.RockBugHologramVisible~=false
    self.suspended=runtime.ultraBlack==true
    if options.classicGui then options.classicGui.Enabled=false end
    self:ApplyVisibility()
    return self
end

return HUD
end)()
-- ORBIT_UI_END


-- ORBIT_INSTALL_BEGIN
local env=_G
if type(getgenv)=="function"then local ok,value=pcall(getgenv)if ok and type(value)=="table"then env=value end end
local runtime=env.RockBugRuntime
if type(runtime)~="table"or not runtime.alive or not runtime.hologramContent then return end
local previous=runtime.hologram
if type(previous)~="table"or previous.destroyed then return end
local player=game:GetService("Players").LocalPlayer
if not player then return end
local visible,group=previous.visible,previous.group
local oldPage=previous.modalOpen and previous.modalTab or nil
local oldModalGroup=previous.modalGroup
local wasSuspended,wasChest=previous.suspended,previous.chestInput
-- The pinned core owns all controls and automation callbacks. Keep them alive.
local containers={"body","dialogHost","quickHost","footer"}
previous:SetSuspended(true)
env.RockBugHologramVisible=visible;env.RockBugHologramGroup=group
local ok,new=pcall(HUD.mount,runtime,{
    player=player,env=env,classicGui=runtime.uiRoot,content=runtime.hologramContent,
    report=function(message)runtime.status=message;warn("[RockBugHub Orbit] "..tostring(message))end,
})
if not ok then
    local partial=runtime.hologram
    if partial and partial~=previous and type(partial.Destroy)=="function"then pcall(function()partial:Destroy()end)end
    runtime.hologram=previous;previous:SetSuspended(wasSuspended)
    if oldPage then previous:OpenFull(oldPage,nil,oldModalGroup)end
    error(new,0)
end
for _,key in ipairs(containers)do
    local oldHost,newHost=previous[key],new[key]
    if oldHost and newHost then for _,child in ipairs(oldHost:GetChildren())do child.Parent=newHost end end
end
previous:Destroy()
new.cardPage=previous.cardPage or 1
new:SetSuspended(wasSuspended)
new:SetChestInput(wasChest)
if oldPage and not wasSuspended and not wasChest then new:OpenFull(oldPage,nil,oldModalGroup)end
runtime.orbitUIVersion=HUD.versionTag(runtime,env)
return new
-- ORBIT_INSTALL_END
