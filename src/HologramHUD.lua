-- RockBugHub T33. Bundled into the existing launcher by scripts/build_hologram.py.
-- All geometry is local, non-colliding and excluded from game raycasts.
local HUD = {}

function HUD.planeHit(ox, oy, oz, dx, dy, dz, width, height, thickness)
    -- Back (+Z) face: its horizontal axis agrees with camera screen-right.
    if dz >= -0.00001 or width <= 0 or height <= 0 then return nil end
    local distance = (thickness / 2 - oz) / dz
    if distance <= 0 then return nil end
    local u, v = 0.5 + (ox + dx * distance) / width, 0.5 - (oy + dy * distance) / height
    if u < 0 or u > 1 or v < 0 or v > 1 then return nil end
    return u, v, distance
end

function HUD.layout(width, height)
    if height > width then return "portrait", 7.0, 16.0 end
    if width < 1080 or height < 620 then return "compact", 17.3, 8.0 end
    return "wide", 12.4, 8.8
end

function HUD.acceptRelease(pressed, released, x, y)
    return pressed and pressed.button == released and (pressed.x-x)^2 + (pressed.y-y)^2 <= 144
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
    local self = {visible=false, suspended=false, destroyed=false, page="automation", panels={}, connections={}, pressed={}, beams={}, samples={}, fades={}, fps=0}
    runtime.hologram = self -- Allows cleanup even if construction fails.
    local binding = "RockBugHologramT33_" .. tostring(player.UserId)
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
        return create("UIStroke", {Color=cyan, Transparency=transparency or 0.45, Thickness=thickness or 1.4}, object)
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
        return create("TextLabel", {BackgroundTransparency=1, BorderSizePixel=0, Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h), Text=text, TextSize=size or 20, TextColor3=color or white, Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, TextTruncate=Enum.TextTruncate.AtEnd}, parent)
    end
    local function part(name, parent)
        return create("Part", {Name=name, Anchored=true, CanCollide=false, CanTouch=false, CanQuery=false, CastShadow=false, Transparency=1, Size=Vector3.new(1,1,0.025)}, parent)
    end
    self.world = create("Model", {Name="RockBugHubHologramT33"})
    self.surfaces = create("Folder", {Name="RockBugHubHologramSurfaces"}, playerGui)
    self.overlay = create("ScreenGui", {Name="RockBugHubHologramControl", ResetOnSpawn=false, DisplayOrder=1000010, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, playerGui)
    self.handle = create("TextButton", {Name="ToggleHologram", AnchorPoint=Vector2.new(0,0), Position=UDim2.fromOffset(16,12), Size=UDim2.fromOffset(148,44), BackgroundColor3=background, BackgroundTransparency=0.08, TextColor3=cyan, TextSize=14, Font=Enum.Font.GothamBold, Text="", AutoButtonColor=true}, self.overlay)
    round(self.handle,14); edge(self.handle,0.12)

    function self:Destroy()
        if self.destroyed then return end
        self.destroyed=true; self.visible=false
        run:UnbindFromRenderStep(binding)
        actions:UnbindAction(binding)
        for _, connection in ipairs(self.connections) do connection:Disconnect() end
        self.connections={}; self.pressed={}
        for _, object in ipairs({self.world,self.surfaces,self.overlay}) do if object then object:Destroy() end end
        if runtime.hologram == self then runtime.hologram=nil end
    end

    local function panel(id, title, x, y, width, height, canvasHeight)
        local p = {id=id, x=x, y=y, w=width, h=height, cw=400, ch=canvasHeight, buttons={}}
        p.part = part(id, self.world)
        p.gui = create("SurfaceGui", {Name=id, Adornee=p.part, Face=Enum.NormalId.Back, SizingMode=Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize=Vector2.new(p.cw,p.ch), AlwaysOnTop=true, LightInfluence=0, Active=false, Enabled=false, ZOffset=0.1}, self.surfaces)
        p.frame = create("Frame", {Size=UDim2.fromScale(1,1), BackgroundColor3=background, BackgroundTransparency=0.16, BorderSizePixel=0}, p.gui)
        round(p.frame,24); edge(p.frame,0.1,2)
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
        -- Render-only frame: manual ray/plane input keeps CanQuery=false.
        local row=create("Frame",{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=cyan,BackgroundTransparency=0.94,BorderSizePixel=0},p.frame)
        round(row,10)
        local textNode=label(row,text,14,0,w-28,h,19,white,false)
        local b={x=x,y=y,w=w,h=h,node=row,text=textNode,callback=callback}
        table.insert(p.buttons,b)
        return b
    end
    local function open(tab)
        self:SetVisible(false)
        options.openClassic(tab)
    end
    local function lever(key)
        if key=="weight" then return runtime.leverRefs.train and runtime.leverRefs.train.Weight end
        return runtime.leverRefs[key]
    end
    local function toggle(p, ru, en, key, index)
        local b=button(p,ru,20,66+(index-1)*52,360,46,function()
            local ref=lever(key)
            if ref and ref.Get and ref.Set then ref.Set(not ref.Get(),false) end
        end)
        b.text.Size=UDim2.fromOffset(258,46)
        b.ru=ru; b.en=en; b.key=key
        b.track=create("Frame",{Position=UDim2.fromOffset(290,11),Size=UDim2.fromOffset(54,26),BackgroundColor3=muted,BackgroundTransparency=0.7,BorderSizePixel=0},b.node)
        round(b.track,20)
        b.knob=create("Frame",{Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(18,18),BackgroundColor3=white,BorderSizePixel=0},b.track)
        round(b.knob,20)
        return b
    end

    local strength=panel("strength","СИЛА / СЕК",-4,2.22,3.35,2.12,254)
    strength.value=label(strength.frame,"—",24,62,348,62,52,white,true)
    strength.total=label(strength.frame,"",26,125,348,26,17,muted)
    strength.bars={}
    for i=1,20 do
        strength.bars[i]=create("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromOffset(25+(i-1)*17.5,225),Size=UDim2.fromOffset(11,2),BackgroundColor3=cyan,BackgroundTransparency=0.1+i%3*0.12,BorderSizePixel=0},strength.frame)
    end
    local automation=panel("automation","АВТОМАТИКА",-4,-0.52,3.35,2.80,336)
    self.toggles={toggle(automation,"Качать гантель","Auto weight","weight",1),toggle(automation,"Авто ребирт","Auto rebirth","autoRebirth",2),toggle(automation,"Тренажёр","Auto machine","machineFarm",3),toggle(automation,"Босс и сундук","Boss & chest","bossCycle",4)}
    button(automation,"Настроить тренажёр  →",20,282,360,38,function()open("farm")end)

    local pets=panel("pets","ПИТОМЦЫ",-4,-3.02,3.35,1.60,192)
    pets.slots={}
    for i=1,3 do
        local b=button(pets,"—",20+(i-1)*122,66,116,64,function()open("crystal")end)
        b.text.TextSize=16; b.text.TextWrapped=true; b.text.TextTruncate=Enum.TextTruncate.None
        b.text.TextXAlignment=Enum.TextXAlignment.Center; b.text.Size=UDim2.fromOffset(104,60); b.text.Position=UDim2.fromOffset(6,0)
        edge(b.node,0.65); pets.slots[i]=b.text
    end
    pets.count=label(pets.frame,"",24,143,300,24,17,muted)
    button(pets,"→",336,140,44,32,function()open("crystal")end)

    local session=panel("session","СЕССИЯ",4,2.22,3.35,2.12,254)
    session.time=label(session.frame,"00:00:00",24,64,350,42,36,white,true)
    session.gain=label(session.frame,"",24,120,350,25,19,mint)
    session.rebirths=label(session.frame,"",24,154,350,25,19,white)
    session.network=label(session.frame,"",24,199,350,25,17,muted)

    local teleport=panel("teleport","ТЕЛЕПОРТ",4,-0.52,3.35,2.80,336)
    for i,id in ipairs({"Starter Island","Legend Beach","Frost Gym","Jungle Gym"}) do
        local destination=id
        local b=button(teleport,string.format("0%d   %s    →",i,id),20,66+(i-1)*52,360,46,function()
            local ok,reason=runtime.teleportToIsland(destination)
            if not ok and reason then options.report(tostring(reason)) end
        end)
        b.text.TextSize=18
    end
    button(teleport,"Все локации  →",20,282,360,38,function()open("teleport")end)

    local progress=panel("progress","ПРОГРЕСС",4,-3.02,3.35,1.60,192)
    progress.status=label(progress.frame,"",24,65,350,42,17,white)
    progress.status.TextWrapped=true; progress.status.TextTruncate=Enum.TextTruncate.None
    local track=create("Frame",{Position=UDim2.fromOffset(24,121),Size=UDim2.fromOffset(350,8),BackgroundColor3=muted,BackgroundTransparency=0.8,BorderSizePixel=0},progress.frame)
    round(track,5)
    progress.fill=create("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=mint,BorderSizePixel=0},track); round(progress.fill,5)
    progress.detail=label(progress.frame,"",24,142,292,26,16,muted)
    button(progress,"→",336,140,44,32,function()open("reb")end)

    local title=panel("title",nil,0,2.70,3.85,0.96,100)
    title.frame.BackgroundTransparency=1
    for _,child in ipairs(title.frame:GetChildren()) do if child:IsA("UIStroke") or child:IsA("Frame") then child:Destroy() end end
    local brand=label(title.frame,"RockBugHub",0,0,400,53,45,white,true); brand.TextXAlignment=Enum.TextXAlignment.Center
    local tagline=label(title.frame,"TRAIN  /  EXPLORE  /  BEYOND",0,58,400,26,15,cyan); tagline.TextXAlignment=Enum.TextXAlignment.Center

    local nav=panel("nav",nil,0,-3.4,4.30,0.74,110)
    nav.cw=640; nav.gui.CanvasSize=Vector2.new(640,110)
    for i,entry in ipairs({{"AUTO","automation"},{"PETS","pets"},{"WORLD","teleport"},{"STATS","session"},{"MENU","menu"}}) do
        local id=entry[2]
        local b=button(nav,entry[1],10+(i-1)*124,14,120,82,function()
            if id=="menu" then open("interface") else self.page=id end
        end)
        b.text.TextSize=24; b.text.TextXAlignment=Enum.TextXAlignment.Center
        b.page=id
    end

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
    self.crystalEdges={}
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
        strength.title.Text=tr("СИЛА / СЕК","STRENGTH / SEC")
        automation.title.Text=tr("АВТОМАТИКА","AUTOMATION")
        pets.title.Text=tr("ПИТОМЦЫ","PETS")
        session.title.Text=tr("СЕССИЯ","SESSION")
        teleport.title.Text=tr("ТЕЛЕПОРТ","TELEPORT")
        progress.title.Text=tr("ПРОГРЕСС","PROGRESS")
        local elapsed=math.max(0,math.floor(now-(runtime.sessionStatsStartedAt or now)))
        session.time.Text=string.format("%02d:%02d:%02d",math.floor(elapsed/3600),math.floor(elapsed/60)%60,elapsed%60)
        session.gain.Text=tr("Сила: +","Strength: +")..number(runtime.sessionStrengthGained)
        session.rebirths.Text=tr("Ребирты: +","Rebirths: +")..number(runtime.sessionRebirthGained)
        session.network.Text=(runtime.pingAvailable and number(runtime.pingMs).." ms" or "— ms").."   /   "..(self.fps>0 and number(self.fps) or "—").." FPS"
        strength.total.Text=tr("Всего: ","Total: ")..number(runtime.sessionStrengthCurrent)
        local gained=tonumber(runtime.sessionStrengthGained) or 0
        local rate=self.lastSample and math.max(0,gained-self.lastSample.gained)/math.max(0.01,now-self.lastSample.time) or 0
        self.lastSample={time=now,gained=gained}
        table.insert(self.samples,rate); if #self.samples>20 then table.remove(self.samples,1) end
        strength.value.Text=number(rate)
        local maximum=1
        for _,value in ipairs(self.samples) do maximum=math.max(maximum,value) end
        for i,bar in ipairs(strength.bars) do bar.Size=UDim2.fromOffset(11,math.max(2,(self.samples[i] or 0)/maximum*57)) end
        for _,b in ipairs(self.toggles) do
            local ref=lever(b.key)
            local enabled=ref and ref.Get and ref.Get()==true
            b.text.Text=tr(b.ru,b.en)
            b.track.BackgroundColor3=enabled and mint or muted
            b.track.BackgroundTransparency=enabled and 0.05 or 0.7
            b.knob.Position=UDim2.fromOffset(enabled and 32 or 4,4)
        end
        if runtime.equippedPetState then
            local ok,_,slots,count,ordered=pcall(runtime.equippedPetState)
            if ok then
                pets.count.Text=tostring(count).." / "..tostring(slots)..tr(" экипировано"," equipped")
                for i,node in ipairs(pets.slots) do node.Text=ordered[i] and ordered[i].Name or "—" end
            end
        end
        local current,goal=tonumber(runtime.sessionRebirthCurrent) or 0,tonumber(runtime.rebirthGoal) or 0
        local ratio=runtime.rebirthGoalEnabled and goal>0 and math.clamp(current/goal,0,1) or 0
        progress.fill.Size=UDim2.fromScale(ratio,1)
        progress.status.Text=tostring(runtime.machineActive and runtime.machineRecoveryStatus or runtime.autoQuest and runtime.questLastMessage or runtime.status or "")
        progress.detail.Text=runtime.rebirthGoalEnabled and (number(current).." / "..number(goal)..tr(" ребиртов"," rebirths")) or tr("Цель ребиртов не задана","No rebirth target")
        automation.buttons[5].text.Text=tr("Настроить тренажёр  →","Machine settings  →")
        teleport.buttons[5].text.Text=tr("Все локации  →","All destinations  →")
        self.handle.Text=self.visible and tr("СКРЫТЬ  ·  RB","HIDE  ·  RB") or tr("ПОКАЗАТЬ  ·  RB","SHOW  ·  RB")
        for _,b in ipairs(nav.buttons) do b.node.BackgroundTransparency=b.page==self.page and 0.72 or 0.96 end
    end

    function self:Hit(x,y)
        if self.destroyed or not self.visible or self.suspended or not self.ready or input:GetFocusedTextBox() or guiService.MenuIsOpen then return nil end
        local camera=workspace.CurrentCamera
        if not camera then return nil end
        local objects=playerGui:GetGuiObjectsAtPosition(x,y)
        for _,object in ipairs(objects) do
            if object:IsA("GuiButton") and object.Active then return nil end
        end
        local ray=camera:ScreenPointToRay(x,y)
        local closest, distance=nil,math.huge
        for _,p in ipairs(self.panels) do
            if p.gui.Enabled then
                local origin=p.part.CFrame:PointToObjectSpace(ray.Origin)
                local direction=p.part.CFrame:VectorToObjectSpace(ray.Direction)
                local u,v,t=HUD.planeHit(origin.X,origin.Y,origin.Z,direction.X,direction.Y,direction.Z,p.part.Size.X,p.part.Size.Y,p.part.Size.Z)
                if u and t<distance then
                    for _,b in ipairs(p.buttons) do
                        local px,py=u*p.cw,v*p.ch
                        if px>=b.x and px<=b.x+b.w and py>=b.y and py<=b.y+b.h then closest=b; distance=t; break end
                    end
                end
            end
        end
        return closest
    end
    local function onInput(_,state,event)
        local key=event.UserInputType==Enum.UserInputType.Touch and event or "mouse"
        if state==Enum.UserInputState.Begin then
            local b=self:Hit(event.Position.X,event.Position.Y)
            if not b then return Enum.ContextActionResult.Pass end
            self.pressed[key]={button=b,x=event.Position.X,y=event.Position.Y}
            b.node.BackgroundTransparency=0.65
        elseif state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then
            local pressed=self.pressed[key]
            if not pressed then return Enum.ContextActionResult.Pass end
            self.pressed[key]=nil
            pressed.button.node.BackgroundTransparency=0.94
            if state==Enum.UserInputState.End and HUD.acceptRelease(pressed,self:Hit(event.Position.X,event.Position.Y),event.Position.X,event.Position.Y) then
                task.spawn(function()
                    if self.destroyed or not runtime.alive then return end
                    local ok,reason=pcall(pressed.button.callback)
                    if not ok then options.report("HUD: "..tostring(reason)) end
                end)
            end
        elseif not self.pressed[key] then return Enum.ContextActionResult.Pass end
        return Enum.ContextActionResult.Sink
    end

    local function render(dt)
        if self.destroyed or not runtime.alive then return end
        local camera=workspace.CurrentCamera
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if not camera or not root then
            self.ready=false; self.world.Parent=nil
            for _,p in ipairs(self.panels) do p.gui.Enabled=false end
            return
        end
        local viewport=camera.ViewportSize
        local mode,designW,designH=HUD.layout(viewport.X,viewport.Y)
        local depth=-camera.CFrame:PointToObjectSpace(root.Position).Z
        if depth<1 or viewport.X<1 or viewport.Y<1 then
            self.ready=false; self.world.Parent=nil
            for _,p in ipairs(self.panels) do p.gui.Enabled=false end
            return
        end
        self.world.Parent=camera; self.ready=true
        local now=os.clock()
        self.fps=self.fps==0 and 1/math.max(dt,0.001) or self.fps+(1/math.max(dt,0.001)-self.fps)*math.min(1,dt*2)
        local worldH=2*depth*math.tan(math.rad(camera.FieldOfView/2))
        local scale=math.min(worldH*(mode=="wide" and 0.82 or 0.94)/designH,worldH*viewport.X/viewport.Y*0.94/designW)
        local progressOpen=math.clamp((now-(self.openedAt or now))/0.28,0,1)
        local spread=1-(1-progressOpen)^3
        local center=root.Position
        -- Camera-space basis keeps labels upright as the character turns.
        local basis=CFrame.fromMatrix(center,camera.CFrame.RightVector,camera.CFrame.UpVector,-camera.CFrame.LookVector)
        for _,p in ipairs(self.panels) do
            local x,y,w,h=p.x,p.y,p.w,p.h
            local enabled=true
            if mode=="compact" then
                if p.id=="strength" then x,y,w,h=-5.25,0.6,5.4,3.42
                elseif p.id=="title" then x,y=0,2.75
                elseif p.id=="nav" then x,y,w,h=0,-3.05,10.5,1.80
                elseif p.id==self.page then x,y,w,h=5.15,0.45,6.1,6.1*p.ch/p.cw
                else enabled=false end
            elseif mode=="portrait" then
                if p.id=="title" then x,y,w,h=0,4.35,5.4,1.35
                elseif p.id=="nav" then x,y,w,h=0,-7.2,6.5,1.12
                elseif p.id==self.page then x,y,w,h=0,-3.7,6.5,6.5*p.ch/p.cw
                else enabled=false end
            end
            p.gui.Enabled=enabled
            if enabled then
                local yaw=mode=="wide" and (x< -2 and 0.07 or x>2 and -0.07 or 0) or 0
                p.part.Size=Vector3.new(w*scale,h*scale,0.025)
                p.part.CFrame=basis*CFrame.new(x*scale*spread,y*scale*spread,0)*CFrame.Angles(0,yaw,0)
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
        self.pressed={}; self.ready=false
        local show=self.visible and not self.suspended and not self.destroyed
        self.world.Parent=nil
        for _,p in ipairs(self.panels) do p.gui.Enabled=false end
        if self.overlay then self.overlay.Enabled=not self.suspended and not self.destroyed end
        if show then
            if options.classicGui then options.classicGui.Enabled=false end
            self.openedAt=os.clock(); self.nextRefresh=nil; self.lastSample=nil
            run:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value+1,function(dt)
                local ok,reason=pcall(render,dt)
                if not ok then
                    self:SetVisible(false)
                    options.openClassic("interface")
                    options.report("HUD: "..tostring(reason))
                end
            end)
            actions:BindActionAtPriority(binding,onInput,false,2500,Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch)
        end
        self.handle.Text=self.visible and tr("СКРЫТЬ  ·  RB","HIDE  ·  RB") or tr("ПОКАЗАТЬ  ·  RB","SHOW  ·  RB")
    end
    function self:SetVisible(value)
        if self.destroyed then return end
        self.visible=value==true
        options.env.RockBugHologramVisible=self.visible
        self:ApplyVisibility()
    end
    function self:SetSuspended(value)
        if self.destroyed then return end
        self.suspended=value==true
        self:ApplyVisibility()
    end
    connect(self.handle.Activated,function()self:SetVisible(not self.visible)end)
    connect(input.InputBegan,function(event,processed)
        if not processed and not input:GetFocusedTextBox() and event.KeyCode==Enum.KeyCode.RightShift then self:SetVisible(not self.visible) end
    end)
    self.visible=options.env.RockBugHologramVisible~=false
    self.suspended=runtime.ultraBlack==true
    self:ApplyVisibility()
    return self
end

return HUD
