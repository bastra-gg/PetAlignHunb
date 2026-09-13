-- RockBugHub T37. Bundled into the existing launcher by scripts/build_hologram.py.
-- All geometry is local, non-colliding and excluded from game raycasts.
local HUD = {}

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

function HUD.screenHit(bounds,x,y)
    if not bounds or bounds.w<=0 or bounds.h<=0 then return nil end
    local u,v=(x-bounds.x)/bounds.w,(y-bounds.y)/bounds.h
    if u < 0 or u > 1 or v < 0 or v > 1 then return nil end
    return u,v
end

function HUD.layout(width, height)
    if height > width then return "portrait", 7.0, 16.0 end
    if width < 1080 or height < 620 then return "compact", 16.0, 8.2 end
    return "wide", 12.4, 9.0
end

function HUD.drawerSize(width,height)
    return math.min(380,math.max(1,width-24)),math.min(460,math.max(1,height-24))
end

function HUD.acceptRelease(pressed, released, x, y)
    return pressed and not pressed.cancelled and pressed.button == released and (pressed.x-x)^2 + (pressed.y-y)^2 <= 144
end

function HUD.mount(runtime, options)
    local player = options.player
    local playerGui = player:WaitForChild("PlayerGui")
    local run = game:GetService("RunService")
    local input = game:GetService("UserInputService")
    local actions = game:GetService("ContextActionService")
    local guiService = game:GetService("GuiService")
    local cyan, mint = Color3.fromRGB(65, 224, 255), Color3.fromRGB(69, 250, 193)
    local white, muted = Color3.fromRGB(211, 249, 255), Color3.fromRGB(121, 177, 194)
    local background = Color3.fromRGB(4, 19, 29)
    local savedGroup=options.env.RockBugHologramGroup
    local tweenService=game:GetService("TweenService")
    assert(options.content,"Missing hologram content bridge")
    local self = {visible=false, suspended=false, destroyed=false, group=HUD.groups[savedGroup] and savedGroup~="settings" and savedGroup or "farm", cardPage=1, cards={}, modalTabs={}, modalOpen=false, panels={}, connections={}, pressed={}, beams={}, samples={}, fps=0, inputGeneration=0, noticeToken=0}
    runtime.hologram = self -- Allows cleanup even if construction fails.
    local binding = "RockBugHologramT37_" .. tostring(player.UserId)
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
        return create("TextLabel", {AutoLocalize=false, BackgroundTransparency=1, BorderSizePixel=0, Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h), Text=text, TextSize=size or 20, TextColor3=color or white, Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, TextTruncate=Enum.TextTruncate.AtEnd}, parent)
    end
    local function part(name, parent)
        return create("Part", {Name=name, Anchored=true, CanCollide=false, CanTouch=false, CanQuery=false, CastShadow=false, Transparency=1, Size=Vector3.new(1,1,0.025)}, parent)
    end
    self.world = create("Model", {Name="RockBugHubHologramT37"})
    self.surfaces = create("Folder", {Name="RockBugHubHologramSurfaces"}, playerGui)
    self.overlay = create("ScreenGui", {Name="RockBugHubHologramControl", ResetOnSpawn=false, DisplayOrder=1000010, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, playerGui)
    self.handle = create("TextButton", {Name="ToggleHologram", AnchorPoint=Vector2.new(0,0), Position=UDim2.fromOffset(16,12), Size=UDim2.fromOffset(108,36), BackgroundColor3=background, BackgroundTransparency=0.08, TextColor3=cyan, TextSize=12, Font=Enum.Font.GothamBold, Text="", AutoButtonColor=true}, self.overlay)
    round(self.handle,14); edge(self.handle,0.12)
    self.menu = create("TextButton", {Name="OpenFullMenu", AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-16,0,12), Size=UDim2.fromOffset(88,36), BackgroundColor3=background, BackgroundTransparency=0.08, TextColor3=white, TextSize=13, Font=Enum.Font.GothamBold, Text=tr("НАСТРОЙКИ","SETTINGS"), AutoButtonColor=true},self.overlay)
    round(self.menu,14); edge(self.menu,0.5)
    self.notice=label(self.overlay,"",16,64,340,64,15,white)
    self.notice.Name="ActionResult"; self.notice.Size=UDim2.new(1,-32,0,64)
    self.notice.BackgroundColor3=background; self.notice.BackgroundTransparency=0.08
    self.notice.TextWrapped=true; self.notice.TextTruncate=Enum.TextTruncate.AtEnd
    self.notice.TextXAlignment=Enum.TextXAlignment.Center; self.notice.Visible=false
    create("UISizeConstraint",{MaxSize=Vector2.new(420,64)},self.notice)
    create("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},self.notice)
    round(self.notice,14); edge(self.notice,0.3)

    function self:Notify(message)
        if self.destroyed or self.suspended or not self.visible then return end
        self.noticeToken+=1
        local token=self.noticeToken
        self.notice.Text=tostring(message)
        self.notice.Visible=true
        task.delay(4,function()
            if not self.destroyed and token==self.noticeToken then self.notice.Visible=false end
        end)
    end

    function self:ClearPresses()
        for _,pressed in pairs(self.pressed) do
            if pressed.button.node.Parent then pressed.button.node.BackgroundTransparency=0.94 end
        end
        self.pressed={}; self.inputGeneration+=1
        for _,p in ipairs(self.panels)do for _,b in ipairs(p.buttons)do b.nativePress=nil end end
    end

    function self:Destroy()
        if self.destroyed then return end
        self.destroyed=true; self.visible=false
        self:ClearPresses(); self.noticeToken+=1
        if self.modalTween then self.modalTween:Cancel()end
        if options.content then pcall(function()options.content:Close()end)end
        for _,tab in ipairs(self.modalTabs)do tab.connection:Disconnect()end
        pcall(function()run:UnbindFromRenderStep(binding)end)
        pcall(function()actions:UnbindAction(binding)end)
        for _, connection in ipairs(self.connections) do pcall(function()connection:Disconnect()end) end
        self.connections={}; self.pressed={}
        for _, object in ipairs({self.world,self.surfaces,self.overlay}) do if object then pcall(function()object:Destroy()end) end end
        if runtime.hologram == self then runtime.hologram=nil end
    end

    local function panel(id, title, x, y, width, height, canvasHeight)
        local p = {id=id, x=x, y=y, w=width, h=height, cw=400, ch=canvasHeight, buttons={}}
        p.part = part(id, self.world)
        -- Screen-space layers can sit above game gain popups; SurfaceGui cannot.
        -- The camera projects the original character-relative anchors every frame.
        p.gui = create("ScreenGui", {Name="RockBugPanel_"..id, ResetOnSpawn=false, DisplayOrder=panelOrder, IgnoreGuiInset=true, ScreenInsets=Enum.ScreenInsets.None, ClipToDeviceSafeArea=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Enabled=false}, self.surfaces)
        p.screenRoot=create("Frame",{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true},p.gui)
        -- This button shields the covered game UI. Actions still use the existing
        -- press/release dispatcher, so dragging never becomes an accidental toggle.
        p.frame = create("TextButton", {Size=UDim2.fromOffset(p.cw,p.ch), Text="", Active=true, AutoButtonColor=false, BackgroundColor3=background, BackgroundTransparency=0, BorderSizePixel=0, ClipsDescendants=true}, p.screenRoot)
        p.scale=create("UIScale",{Scale=1},p.frame)
        round(p.frame,24); p.stroke=edge(p.frame,0.1,2)
        create("UIGradient", {Rotation=100, Color=ColorSequence.new(Color3.fromRGB(42,76,93),Color3.fromRGB(9,27,37))},p.frame)
        local rim=create("Frame",{Position=UDim2.fromOffset(8,8), Size=UDim2.new(1,-16,1,-16), BackgroundTransparency=1},p.frame)
        round(rim,18); edge(rim,0.8,1)
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
        -- One shared screen rectangle drives rendering and the press/release hit test.
        local row=create("TextButton",{Text="",Active=true,AutoButtonColor=false,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=cyan,BackgroundTransparency=0.94,BorderSizePixel=0,ClipsDescendants=true},p.frame)
        round(row,10)
        local textNode=label(row,text,14,0,w-28,h,19,white,false)
        local b={x=x,y=y,w=w,h=h,node=row,text=textNode,callback=callback,owner=p}
        -- Some clients route a ScreenGui touch to Activated before ContextActionService.
        -- Both routes share the same press and handled flag: never dispatch twice.
        connect(row.InputBegan,function(event)
            if event.UserInputType~=Enum.UserInputType.MouseButton1 and event.UserInputType~=Enum.UserInputType.Touch then return end
            if not self.inputReady or self:Hit(event.Position.X,event.Position.Y)~=b then return end
            b.nativeHandled=false
            b.nativePress={button=b,x=event.Position.X,y=event.Position.Y,generation=self.inputGeneration,key=event.UserInputType==Enum.UserInputType.Touch and event or "mouse"}
        end)
        connect(row.Activated,function(event)
            local pressed=b.nativePress;b.nativePress=nil
            if not event or b.nativeHandled or not pressed or pressed.generation~=self.inputGeneration then return end
            if HUD.acceptRelease(pressed,self:Hit(event.Position.X,event.Position.Y),event.Position.X,event.Position.Y)then
                b.nativeHandled=true;self:ActivateButton(b,pressed.generation)
            end
        end)
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
        local b=create("TextButton",{Position=position,Size=size,Text=text,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=white,BackgroundColor3=background,BackgroundTransparency=0.1,BorderSizePixel=0,AutoButtonColor=true,ClipsDescendants=true,TextTruncate=Enum.TextTruncate.AtEnd},parent)
        round(b,10);edge(b,0.6)
        connect(b.Activated,callback)
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
        local b=nativeButton(self.cardTabs,"",UDim2.new((i-1)/4,2,0,0),UDim2.new(0.25,-4,1,0),function()self:ClearPresses();self.cardPage=index;self.nextRefresh=nil end)
        b.TextSize=10;table.insert(self.cardButtons,b)
    end

    -- A transparent, non-modal host leaves the game usable outside the drawer.
    self.sheet=create("Frame",{Name="SectionDrawer",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false,Visible=false,ZIndex=20},self.overlay)
    self.window=create("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(380,460),BackgroundColor3=Color3.fromRGB(12,25,34),BorderSizePixel=0,Active=true,ClipsDescendants=true,ZIndex=21},self.sheet)
    round(self.window,12);edge(self.window,0.65,1)
    self.windowTitle=label(self.window,"",12,9,240,32,16,white,true)
    self.windowTitle.Size=UDim2.new(1,-132,0,32)
    self.close=nativeButton(self.window,"×",UDim2.new(1,-44,0,8),UDim2.fromOffset(34,34),function()self:CloseFull()end)
    self.stop=nativeButton(self.window,"STOP",UDim2.new(1,-106,0,8),UDim2.fromOffset(56,34),function()options.content:StopModes()end)
    self.stop.TextColor3=Color3.fromRGB(255,134,136)
    self.sectionTabs=create("ScrollingFrame",{Position=UDim2.fromOffset(10,48),Size=UDim2.new(1,-20,0,42),CanvasSize=UDim2.fromOffset(0,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.X,Active=true,ClipsDescendants=true},self.window)
    self.quickHost=create("Frame",{Position=UDim2.fromOffset(12,94),Size=UDim2.new(1,-24,0,34),BackgroundTransparency=1,ClipsDescendants=true},self.window)
    self.body=create("Frame",{Position=UDim2.fromOffset(12,94),Size=UDim2.new(1,-24,1,-128),BackgroundTransparency=1,ClipsDescendants=true},self.window)
    self.footer=create("Frame",{Position=UDim2.new(0,12,1,-30),Size=UDim2.new(1,-24,0,24),BackgroundTransparency=1,ClipsDescendants=true},self.window)
    self.dialogHost=create("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=80,Active=false},self.window)

    function self:LayoutDrawer(animate)
        if not self.modalOpen then return end
        local size=self.sheet.AbsoluteSize
        if not size or size.X<1 or size.Y<1 then size=workspace.CurrentCamera.ViewportSize end
        local width,height=HUD.drawerSize(size.X,size.Y)
        local position=UDim2.new(self.drawerLeft and 0 or 1,self.drawerLeft and 12 or -12,0.5,0)
        self.window.AnchorPoint=Vector2.new(self.drawerLeft and 0 or 1,0.5)
        self.window.Size=UDim2.fromOffset(width,height)
        if self.modalTween then self.modalTween:Cancel()end
        if animate then
            self.window.Position=UDim2.new(self.drawerLeft and 0 or 1,self.drawerLeft and -width or width,0.5,0)
            self.modalTween=tweenService:Create(self.window,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=position})
            self.modalTween:Play()
        else self.window.Position=position end
        local refresh=self.modalTab=="bug" or self.modalTab=="farm"
        self.quickHost.Visible=refresh
        local top=refresh and 134 or 94
        self.body.Position=UDim2.fromOffset(12,top)
        self.body.Size=UDim2.new(1,-24,1,-top-34)
    end
    connect(self.sheet:GetPropertyChangedSignal("AbsoluteSize"),function()self:LayoutDrawer(false)end)

    function self:OpenFull(tab,origin,requestedGroup)
        if self.destroyed or self.suspended or not HUD.sections[tab] then return false end
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
        if not wasOpen then self.modalReturnVisible=self.visible end
        self.visible=true;self.modalOpen=true;self.modalTab=tab;self.modalGroup=group
        for _,entry in ipairs(self.modalTabs)do entry.connection:Disconnect();entry.node:Destroy()end
        self.modalTabs={}
        local selectedIndex=1
        for i,id in ipairs(HUD.groups[group].tabs)do
            local section=id
            local title=HUD.sections[section]
            local b=create("TextButton",{Position=UDim2.fromOffset((i-1)*110,0),Size=UDim2.fromOffset(104,36),Text=tr(title[1],title[2]),Font=Enum.Font.GothamBold,TextSize=13,TextColor3=section==tab and background or white,BackgroundColor3=section==tab and cyan or Color3.fromRGB(28,46,58),BorderSizePixel=0,AutoButtonColor=true},self.sectionTabs)
            round(b,8)
            local connection=b.Activated:Connect(function()self:OpenFull(section,nil,group)end)
            table.insert(self.modalTabs,{node=b,connection=connection,id=section})
            if section==tab then selectedIndex=i end
        end
        self.sectionTabs.CanvasSize=UDim2.fromOffset(#self.modalTabs*110,0)
        self.sectionTabs.CanvasPosition=Vector2.new(math.max(0,(selectedIndex-2)*110),0)
        self.windowTitle.Text=tr(HUD.sections[tab][1],HUD.sections[tab][2])
        if self.modalTween then self.modalTween:Cancel()end
        self:ApplyVisibility()
        if not wasOpen then self.drawerLeft=origin and origin.x<0 or false end
        self:LayoutDrawer(not wasOpen)
        return true
    end
    function self:CloseFull()
        if self.destroyed then return end
        if self.modalTween then self.modalTween:Cancel()end
        self.modalOpen=false;self.modalTab=nil;self.visible=self.modalReturnVisible~=false;options.content:Close();self:ApplyVisibility()
    end
    function self:RefreshLanguage()
        self.menu.Text=tr("НАСТРОЙКИ","SETTINGS")
        self.stop.Text=tr("СТОП","STOP")
        for id,node in pairs(self.groupButtons)do node.Text=tr(HUD.groups[id].ru,HUD.groups[id].en)end
        for _,entry in ipairs(self.modalTabs)do local title=HUD.sections[entry.id];entry.node.Text=tr(title[1],title[2])end
        if self.modalTab then local title=HUD.sections[self.modalTab];self.windowTitle.Text=tr(title[1],title[2])end
        self.nextRefresh=nil
    end
    function self:SelectGroup(id)
        if not HUD.groups[id] or id=="settings" or self.destroyed then return false end
        if self.modalOpen then self.modalOpen=false;options.content:Close()end
        self:ClearPresses();self.group=id;self.cardPage=1;self.nextRefresh=nil
        options.env.RockBugHologramGroup=id
        self.visible=true;self:ApplyVisibility()
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
    for _,child in ipairs(title.frame:GetChildren())do if child:IsA("UIStroke")or child:IsA("Frame")then child:Destroy()end end
    local brand=label(title.frame,"RockBugHub",0,0,400,53,43,white,true);brand.TextXAlignment=Enum.TextXAlignment.Center
    local tagline=label(title.frame,"TRAIN / EXPLORE / BEYOND",0,58,400,26,14,cyan);tagline.TextXAlignment=Enum.TextXAlignment.Center

    self.ringRoot=part("Orbit",self.world)
    local function beam(a,b,width,transparency)
        local first=create("Attachment",{Position=a},self.ringRoot)
        local second=create("Attachment",{Position=b},self.ringRoot)
        local object=create("Beam",{Attachment0=first,Attachment1=second,Width0=width,Width1=width,Color=ColorSequence.new(cyan),Transparency=NumberSequence.new(transparency),FaceCamera=true,LightEmission=1,Segments=1},self.ringRoot)
        table.insert(self.beams,object)
        return object
    end
    for _,ring in ipairs({{2.55,0,0.038,0.16},{2.95,0.05,0.02,0.48},{3.48,-0.10,0.028,0.25}}) do
        for i=0,31 do
            if i%8~=7 then
                local a,b=i*math.pi/16,(i+1)*math.pi/16
                beam(Vector3.new(math.cos(a)*ring[1],ring[2],math.sin(a)*ring[1]),Vector3.new(math.cos(b)*ring[1],ring[2],math.sin(b)*ring[1]),ring[3],ring[4])
            end
        end
    end
    -- A light wireframe crystal inspired by the generated concept. No uploaded
    -- MeshPart permissions, collisions, lights or particle emitters are needed.
    self.crystalRoot=part("Crystal",self.world)
    local function crystal(cx,cy,cz,radius,height)
        local top=Vector3.new(cx,cy+height,cz)
        local bottom=Vector3.new(cx,cy-height*0.35,cz)
        local points={}
        for i=1,5 do points[i]=Vector3.new(cx+math.cos(i*math.pi*0.4)*radius,cy,cz+math.sin(i*math.pi*0.4)*radius) end
        for i=1,5 do
            for _,pair in ipairs({{points[i],points[i%5+1]},{points[i],top},{points[i],bottom}}) do
                local a=create("Attachment",{Position=pair[1]},self.crystalRoot)
                local b=create("Attachment",{Position=pair[2]},self.crystalRoot)
                local object=create("Beam",{Attachment0=a,Attachment1=b,Width0=0.018,Width1=0.018,Color=ColorSequence.new(cyan),Transparency=NumberSequence.new(0.17),FaceCamera=true,LightEmission=1,Segments=1},self.crystalRoot)
                table.insert(self.beams,object)
            end
        end
    end
    crystal(0,0,0,0.24,0.75); crystal(-0.43,-0.20,0.03,0.18,0.43); crystal(0.43,-0.13,0.07,0.18,0.49)


    local function refresh(now)
        local group=HUD.groups[self.group]
        for id,node in pairs(self.groupButtons)do
            node.Text=tr(HUD.groups[id].ru,HUD.groups[id].en)
            node.BackgroundColor3=id==self.group and cyan or background
            node.TextColor3=id==self.group and background or white
        end
        for i,p in ipairs(self.cards)do
            local def=group.cards[i]
            p.title.Text=tr(def.ru,def.en)
            p.primary.text.Text=tr(def.actionRu,def.actionEn)
            p.more.text.Text=tr(def.moreRu,def.moreEn).."  →"
            self.cardButtons[i].Text=tr(def.ru,def.en)
            self.cardButtons[i].BackgroundColor3=i==self.cardPage and Color3.fromRGB(19,67,82) or background
            local ref=def.key and lever(def.key)
            p.state.Text=ref and (ref.Get() and tr("ВКЛ","ON") or tr("ВЫКЛ","OFF")) or "→"
            p.state.TextColor3=ref and ref.Get() and mint or muted
            p.hint.Text=tr("Настройки выбранного режима","Settings for this mode")
            if def.tab=="farm" then p.hint.Text=tostring(runtime.machineActive and runtime.machineRecoveryStatus or runtime.selectedMachine and (runtime.selectedMachine.label or runtime.selectedMachine.name or runtime.selectedMachine.kind) or tr("Выберите тренажёр","Choose a machine"))
            elseif def.tab=="bug" then p.hint.Text=tr("Авто ребирт: ","Auto rebirth: ")..(runtime.autoRebirth and "ON" or "OFF")
            elseif def.tab=="train" then p.hint.Text=tr("Упражнения, фиксация и темп","Exercises, position lock and pace")
            elseif def.tab=="boss" then p.hint.Text=tr("Автобой, награда и возврат","Auto fight, reward and return")
            elseif def.tab=="crystal" then p.hint.Text=tostring(runtime.selectedCrystal or tr("Выберите товар","Choose an item"))
            elseif def.tab=="egg" then p.hint.Text=tr("Интервал: ","Interval: ")..tostring((tonumber(runtime.eggIntervalMultiplier)or 1)*30)..tr(" мин."," min")
            elseif def.tab=="quest" then p.hint.Text=tostring(runtime.questLastMessage or tr("Выбор NPC и заданий","NPC and quest selection"))
            elseif def.tab=="kill" then p.hint.Text=tr("Режим: ","Mode: ")..tostring(runtime.killMode or "off")
            elseif def.tab=="teleport" and runtime.equippedPetState then
                local ok,_,slots,count=pcall(runtime.equippedPetState)
                p.hint.Text=ok and slots and tr("Питомцы: ","Pets: ")..tostring(count).." / "..tostring(slots) or tr("Данные питомцев загружаются","Loading pet data")
            end
        end
        strength.title.Text=tr("СИЛА / СЕК","STRENGTH / SEC");session.title.Text=tr("СЕССИЯ","SESSION")
        local elapsed=math.max(0,math.floor(now-(runtime.sessionStatsStartedAt or now)))
        session.time.Text=string.format("%02d:%02d:%02d",math.floor(elapsed/3600),math.floor(elapsed/60)%60,elapsed%60)
        session.gain.Text=tr("Сила: +","Strength: +")..number(runtime.sessionStrengthGained)
        session.rebirths.Text=tr("Ребирты: +","Rebirths: +")..number(runtime.sessionRebirthGained)
        session.network.Text=(runtime.pingAvailable and number(runtime.pingMs).." ms" or "— ms").." / "..number(self.fps).." FPS"
        session.buttons[1].text.Text=tr("Ребирты →","Rebirths →")
        strength.total.Text=tr("Всего: ","Total: ")..number(runtime.sessionStrengthCurrent)
        local gained=tonumber(runtime.sessionStrengthGained)or 0
        local rate=self.lastSample and math.max(0,gained-self.lastSample.gained)/math.max(0.01,now-self.lastSample.time)or 0
        self.lastSample={time=now,gained=gained}
        table.insert(self.samples,rate);if #self.samples>20 then table.remove(self.samples,1)end
        strength.value.Text=number(rate)
        local maximum=1;for _,value in ipairs(self.samples)do maximum=math.max(maximum,value)end
        for i,bar in ipairs(strength.bars)do bar.Size=UDim2.fromOffset(11,math.max(2,(self.samples[i]or 0)/maximum*57))end
        self.menu.Text=tr("НАСТРОЙКИ","SETTINGS")
    end

    function self:Hit(x,y)
        if self.destroyed or not self.visible or self.suspended or not self.ready or not self.inputReady or self.modalOpen or input:GetFocusedTextBox() or guiService.MenuIsOpen then return nil end
        if not workspace.CurrentCamera then return nil end
        local objects=playerGui:GetGuiObjectsAtPosition(x,y)
        for _,object in ipairs(objects) do
            if object:IsA("GuiButton") and object.Active then
                local layer=object:FindFirstAncestorWhichIsA("ScreenGui")
                local ownPanel=layer and layer:IsDescendantOf(self.surfaces)
                if not ownPanel and (not layer or layer.DisplayOrder>=panelOrder)then return nil end
            end
        end
        -- Last-created panels win during the opening overlap, matching ScreenGui order.
        for i=#self.panels,1,-1 do
            local p=self.panels[i]
            if p.gui.Enabled then
                local u,v=HUD.screenHit(p.bounds,x,y)
                if u then
                    for _,b in ipairs(p.buttons) do
                        local px,py=u*p.cw,v*p.ch
                        if px>=b.x and px<=b.x+b.w and py>=b.y and py<=b.y+b.h then return b end
                    end
                    return nil
                end
            end
        end
    end
    function self:ActivateButton(button,generation)
        task.spawn(function()
            if self.destroyed or not runtime.alive or not self.visible or self.suspended or self.chestInput or generation~=self.inputGeneration then return end
            self.actionPanel=button.owner
            local ok,reason=pcall(button.callback)
            self.nextRefresh=nil
            if not ok then
                local message=tr("Не удалось выполнить действие: ","Action failed: ")..tostring(reason)
                options.report(message);self:Notify(message)
            end
        end)
    end
    local function onInput(_,state,event)
        local key=event.UserInputType==Enum.UserInputType.Touch and event or "mouse"
        if state==Enum.UserInputState.Begin then
            local b=self:Hit(event.Position.X,event.Position.Y)
            if not b then return Enum.ContextActionResult.Pass end
            b.nativeHandled=false
            self.pressed[key]={button=b,x=event.Position.X,y=event.Position.Y,generation=self.inputGeneration}
            b.node.BackgroundTransparency=0.65
        elseif state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then
            local pressed=self.pressed[key]
            if not pressed then return Enum.ContextActionResult.Pass end
            self.pressed[key]=nil
            pressed.button.node.BackgroundTransparency=0.94
            if state==Enum.UserInputState.Cancel then pressed.button.nativePress=nil;pressed.button.nativeHandled=true end
            if state==Enum.UserInputState.End and not pressed.button.nativeHandled and pressed.generation==self.inputGeneration and HUD.acceptRelease(pressed,self:Hit(event.Position.X,event.Position.Y),event.Position.X,event.Position.Y) then
                pressed.button.nativeHandled=true
                self:ActivateButton(pressed.button,pressed.generation)
            end
        elseif not self.pressed[key] then return Enum.ContextActionResult.Pass end
        return Enum.ContextActionResult.Sink
    end

    local function render(dt)
        if self.destroyed or not runtime.alive then return end
        local camera=workspace.CurrentCamera
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if self.inputCamera~=camera or self.inputRoot~=root then
            self:ClearPresses(); self.inputCamera=camera; self.inputRoot=root
        end
        if not camera or not root then
            self.ready=false; self.world.Parent=nil
            for _,p in ipairs(self.panels) do p.gui.Enabled=false end
            return
        end
        local viewport=camera.ViewportSize
        local mode,designW,designH=HUD.layout(viewport.X,viewport.Y)
        if self.viewportX~=viewport.X or self.viewportY~=viewport.Y then
            self:ClearPresses(); self.viewportX=viewport.X; self.viewportY=viewport.Y
        end
        local depth=-camera.CFrame:PointToObjectSpace(root.Position).Z
        if depth<1 or viewport.X<1 or viewport.Y<1 then
            if self.ready then self:ClearPresses() end
            self.ready=false; self.world.Parent=nil
            for _,p in ipairs(self.panels) do p.gui.Enabled=false end
            return
        end
        self.world.Parent=camera; self.ready=true
        if (guiService.MenuIsOpen or input:GetFocusedTextBox()) and next(self.pressed) then self:ClearPresses() end
        local now=os.clock()
        self.fps=self.fps==0 and 1/math.max(dt,0.001) or self.fps+(1/math.max(dt,0.001)-self.fps)*math.min(1,dt*2)
        local worldH=2*depth*math.tan(math.rad(camera.FieldOfView/2))
        local scale=math.min(worldH*(mode=="wide" and 0.82 or 0.9)/designH,worldH*viewport.X/viewport.Y*0.9/designW)*0.88
        self.cardTabs.Visible=mode=="portrait" and not self.modalOpen
        self.nav.Position=mode=="wide" and UDim2.new(0.5,0,0.86,0) or UDim2.new(0.5,0,1,-10)
        local progressOpen=math.clamp((now-(self.openedAt or now))/0.28,0,1)
        local spread=1-(1-progressOpen)^3
        self.inputReady=progressOpen>=1
        local center=root.Position
        -- Camera-space basis keeps labels upright as the character turns.
        local basis=CFrame.fromMatrix(center,camera.CFrame.RightVector,camera.CFrame.UpVector,-camera.CFrame.LookVector)
        for _,p in ipairs(self.panels) do
            local x,y,w,h=p.x,p.y,p.w,p.h
            local enabled=true
            if mode=="compact" then
                if p.index then x,y,w,h=p.index%2==1 and -5.2 or 5.2,p.index<=2 and 1.25 or -2.10,5.65,3.24875
                elseif p.id=="title"then x,y,w,h=0,2.75,4.2,1.05
                else enabled=false end
            elseif mode=="portrait"then
                if p.index and p.index==self.cardPage then x,y,w,h=0,-3.7,6.5,6.5*p.ch/p.cw
                elseif p.id=="title"then x,y,w,h=0,4.35,5.4,1.35
                else enabled=false end
            end
            p.gui.Enabled=enabled
            if enabled then
                if p.stroke and p.stroke.Parent then p.stroke.Transparency=p.index==self.cardPage and 0.1 or 0.35 end
                p.part.Size=Vector3.new(w*scale,h*scale,0.025)
                p.part.CFrame=basis*CFrame.new(x*scale*spread,y*scale*spread,0)
                local point=camera:WorldToViewportPoint(p.part.CFrame.Position)
                local edgePoint=camera:WorldToViewportPoint(p.part.CFrame.Position+p.part.CFrame.RightVector*w*scale*0.5)
                local pixelScale=math.abs(edgePoint.X-point.X)*2/p.cw
                local pixelW,pixelH=p.cw*pixelScale,p.ch*pixelScale
                p.bounds={x=point.X-pixelW/2,y=point.Y-pixelH/2,w=pixelW,h=pixelH}
                p.gui.Enabled=point.Z>0 and pixelScale>0 and p.bounds.x<viewport.X and p.bounds.y<viewport.Y and p.bounds.x+pixelW>0 and p.bounds.y+pixelH>0
                p.screenRoot.Position=UDim2.fromOffset(point.X,point.Y)
                p.screenRoot.Size=UDim2.fromOffset(pixelW,pixelH)
                p.scale.Scale=pixelScale
            end
        end
        local humanoid=character:FindFirstChildOfClass("Humanoid")
        local r6Leg=character:FindFirstChild("Left Leg")
        local footY=root.Position.Y-root.Size.Y/2-(humanoid and humanoid.HipHeight or 2)-(r6Leg and r6Leg.Size.Y or 0)
        self.ringRoot.CFrame=CFrame.new(root.Position.X,footY+0.05,root.Position.Z)*CFrame.Angles(0,now*0.12,0)
        self.crystalRoot.CFrame=basis*CFrame.new(0,(mode=="portrait" and 5.45 or 3.7)*scale,0)*CFrame.Angles(0,now*0.35,0)
        if not self.nextRefresh or now>=self.nextRefresh then
            self.nextRefresh=now+0.5
            refresh(now)
        end
    end
    function self:ApplyVisibility()
        run:UnbindFromRenderStep(binding)
        actions:UnbindAction(binding)
        self:ClearPresses(); self.ready=false; self.inputReady=false
        self.noticeToken+=1; self.notice.Visible=false
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
            self.openedAt=os.clock(); self.nextRefresh=nil; self.lastSample=nil
            run:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value+1,function(dt)
                local ok,reason=pcall(render,dt)
                if not ok then
                    self:SetVisible(false)
                    self:OpenFull("system",nil,"settings")
                    options.report("HUD: "..tostring(reason))
                end
            end)
            actions:BindActionAtPriority(binding,onInput,false,2500,Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch)
        end
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
    connect(self.handle.Activated,function()self:SetVisible(not self.visible)end)
    connect(self.menu.Activated,function()self:OpenFull("system",nil,"settings")end)
    connect(input.InputChanged,function(event)
        local key=event.UserInputType==Enum.UserInputType.Touch and event or event.UserInputType==Enum.UserInputType.MouseMovement and "mouse" or nil
        local pressed=key and self.pressed[key]
        if pressed and (pressed.x-event.Position.X)^2+(pressed.y-event.Position.Y)^2>144 then
            pressed.cancelled=true
            pressed.button.node.BackgroundTransparency=0.94
        end
        if key then for _,p in ipairs(self.panels)do for _,b in ipairs(p.buttons)do
            local native=b.nativePress
            if native and native.key==key and (native.x-event.Position.X)^2+(native.y-event.Position.Y)^2>144 then native.cancelled=true end
        end end end
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
