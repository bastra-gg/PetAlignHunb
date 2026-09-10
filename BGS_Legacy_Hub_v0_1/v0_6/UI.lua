return function(S,api)
local Players,RS,Run,Input=api.Players,api.RS,api.Run,api.Input
local player,playerGui,root=api.player,api.playerGui,api.root
local connect,clearTarget,stopMove=api.connect,api.clearTarget,api.stopMove
local isGemCurrency=api.isGemCurrency
local gui
-- UI -----------------------------------------------------------------------
local C={
    bg=Color3.fromRGB(14,15,22),panel=Color3.fromRGB(22,24,34),surface=Color3.fromRGB(30,33,45),border=Color3.fromRGB(68,70,92),
    accent=Color3.fromRGB(154,120,244),accent2=Color3.fromRGB(103,177,255),text=Color3.fromRGB(244,245,250),muted=Color3.fromRGB(158,162,184),
    danger=Color3.fromRGB(232,93,121),good=Color3.fromRGB(105,220,151),gem=Color3.fromRGB(181,112,255),normal=Color3.fromRGB(111,222,142),coin=Color3.fromRGB(236,201,91)
}
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local function corner(o,r) make("UICorner",o,{CornerRadius=UDim.new(0,r or 9)}) end
local function stroke(o,color,trans,thickness)
    return make("UIStroke",o,{Color=color or C.border,Thickness=thickness or 1,Transparency=trans==nil and 0.25 or trans})
end
local function label(parent,text,size,color)
    return make("TextLabel",parent,{Text=text,TextSize=size or 13,Font=Enum.Font.Gotham,TextColor3=color or C.text,BackgroundTransparency=1,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
end
gui=make("ScreenGui",playerGui,{Name="BGSLegacyHubNext",ResetOnSpawn=false,DisplayOrder=999999,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local main=make("Frame",gui,{Name="Main",Size=UDim2.fromOffset(470,390),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true,Active=true})
S.gui=gui
corner(main,14) stroke(main,C.accent,0.12,1.2)
local header=make("Frame",main,{Size=UDim2.new(1,0,0,50),BackgroundColor3=C.panel,BorderSizePixel=0,Active=true})
local accentLine=make("Frame",header,{Size=UDim2.new(0,4,0,26),Position=UDim2.fromOffset(10,12),BackgroundColor3=C.accent,BorderSizePixel=0}) corner(accentLine,5)
local title=label(header,"BGS LEGACY",16) title.Font=Enum.Font.GothamBold title.Position=UDim2.fromOffset(22,7) title.Size=UDim2.new(1,-190,0,20)
local subtitle=label(header,"v0.6 · миры / сундуки / питомцы",9,C.muted) subtitle.Position=UDim2.fromOffset(22,27) subtitle.Size=UDim2.new(1,-190,0,15)
local function button(parent,text,callback,height)
    local b=make("TextButton",parent,{Size=UDim2.new(1,-6,0,height or 38),Text=text,TextSize=12,TextColor3=C.text,Font=Enum.Font.GothamMedium,TextWrapped=true,BackgroundColor3=C.surface,BorderSizePixel=0,AutoButtonColor=true})
    corner(b,8) connect(b.Activated,callback) return b
end
local stopBtn=button(header,"СТОП",function() S:HardStop() end,28) stopBtn.Size=UDim2.fromOffset(58,28) stopBtn.Position=UDim2.new(1,-132,0,11) stopBtn.TextColor3=C.danger
local mini=button(header,"—",function() end,28) mini.Size=UDim2.fromOffset(28,28) mini.Position=UDim2.new(1,-68,0,11)
local close=button(header,"×",function() S:Stop("closed") end,28) close.Size=UDim2.fromOffset(28,28) close.Position=UDim2.new(1,-36,0,11)

local tabs=make("Frame",main,{Position=UDim2.fromOffset(9,58),Size=UDim2.new(1,-18,0,31),BackgroundTransparency=1})
local holder=make("Frame",main,{Position=UDim2.fromOffset(11,97),Size=UDim2.new(1,-22,1,-130),BackgroundTransparency=1})
local footer=label(main,"Готово",10,C.muted) footer.Position=UDim2.new(0,13,1,-28) footer.Size=UDim2.new(1,-42,0,22) footer.TextWrapped=false footer.TextTruncate=Enum.TextTruncate.AtEnd
local grip=make("TextButton",main,{Text="◢",TextSize=15,TextColor3=C.accent,Size=UDim2.fromOffset(24,24),Position=UDim2.new(1,-25,1,-25),BackgroundTransparency=1})
local pageNames={"Фарм","Яйца","Острова","Монеты","Авто"}
local pages,tabButtons={},{}
local function setTab(index)
    for i,p in ipairs(pages) do
        p.Visible=i==index
        tabButtons[i].BackgroundColor3=i==index and C.accent or C.panel
        tabButtons[i].TextColor3=i==index and C.bg or C.muted
    end
end
for i,name in ipairs(pageNames) do
    local b=button(tabs,name,function() setTab(i) end,31)
    b.Size=UDim2.new(0.2,-4,1,0) b.Position=UDim2.new((i-1)*0.2,2,0,0) tabButtons[i]=b
    local page=make("ScrollingFrame",holder,{Name="Page"..i,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=C.accent,ScrollingDirection=Enum.ScrollingDirection.Y})
    make("UIListLayout",page,{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
    make("UIPadding",page,{PaddingBottom=UDim.new(0,7),PaddingLeft=UDim.new(0,1),PaddingTop=UDim.new(0,2)})
    pages[i]=page
end
setTab(1)
local function textRow(parent,text,height,color)
    local l=label(parent,text,11,color or C.muted) l.Size=UDim2.new(1,-9,0,height or 34) return l
end
local draws={}
local function toggle(parent,titleText,description,read,write)
    local b=button(parent,"",function() write(not read()) end,51) stroke(b,C.border,0.48)
    local t=label(b,titleText,12) t.Font=Enum.Font.GothamMedium t.Position=UDim2.fromOffset(11,7) t.Size=UDim2.new(1,-76,0,17)
    local d=label(b,description,9,C.muted) d.Position=UDim2.fromOffset(11,27) d.Size=UDim2.new(1,-78,0,17) d.TextWrapped=false d.TextTruncate=Enum.TextTruncate.AtEnd
    local pill=make("Frame",b,{Size=UDim2.fromOffset(38,21),Position=UDim2.new(1,-49,0.5,-10),BorderSizePixel=0}) corner(pill,20)
    local dot=make("Frame",pill,{Size=UDim2.fromOffset(15,15),BackgroundColor3=C.text,BorderSizePixel=0}) corner(dot,20)
    draws[#draws+1]=function()
        local on=read() pill.BackgroundColor3=on and C.accent or C.border dot.Position=UDim2.fromOffset(on and 20 or 3,3)
    end
end
local activeSlider=nil
local function slider(parent,titleText,key,min,max,stepv,unit)
    local box=make("Frame",parent,{Size=UDim2.new(1,-6,0,58),BackgroundColor3=C.panel,BorderSizePixel=0}) corner(box,8)
    local n=label(box,titleText,11) n.Position=UDim2.fromOffset(11,6) n.Size=UDim2.new(1,-112,0,18)
    local value=label(box,"",11,C.accent) value.Position=UDim2.new(1,-102,0,6) value.Size=UDim2.fromOffset(90,18) value.TextXAlignment=Enum.TextXAlignment.Right
    local track=make("TextButton",box,{Text="",Size=UDim2.new(1,-26,0,23),Position=UDim2.fromOffset(13,29),BackgroundTransparency=1,AutoButtonColor=false})
    local rail=make("Frame",track,{Size=UDim2.new(1,0,0,4),Position=UDim2.new(0,0,0.5,-2),BackgroundColor3=C.border,BorderSizePixel=0}) corner(rail,4)
    local fill=make("Frame",rail,{BackgroundColor3=C.accent,BorderSizePixel=0}) corner(fill,4)
    local knob=make("Frame",rail,{Size=UDim2.fromOffset(11,11),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=C.text,BorderSizePixel=0}) corner(knob,11)
    local function update(x)
        local a=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
        S[key]=math.clamp(math.floor((min+a*(max-min))/stepv+0.5)*stepv,min,max)
    end
    connect(track.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then activeSlider={input=input,update=update} update(input.Position.X) end
    end)
    draws[#draws+1]=function()
        local a=(S[key]-min)/(max-min) fill.Size=UDim2.fromScale(a,1) knob.Position=UDim2.fromScale(a,0.5)
        value.Text=(stepv>=1 and string.format("%.0f",S[key]) or string.format("%.2f",S[key])).." "..unit
    end
end

-- Searchable picker. Items may provide borderColor.
local overlay=make("Frame",main,{Name="Picker",Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BackgroundTransparency=0.01,BorderSizePixel=0,Visible=false,ZIndex=20,Active=true})
local pickerTitle=label(overlay,"Выбор",14) pickerTitle.Font=Enum.Font.GothamBold pickerTitle.Position=UDim2.fromOffset(15,11) pickerTitle.Size=UDim2.new(1,-65,0,26)
local pickerClose=button(overlay,"×",function() overlay.Visible=false end,28) pickerClose.Size=UDim2.fromOffset(28,28) pickerClose.Position=UDim2.new(1,-40,0,10)
local search=make("TextBox",overlay,{PlaceholderText="Поиск…",Text="",ClearTextOnFocus=false,Size=UDim2.new(1,-30,0,34),Position=UDim2.fromOffset(15,46),TextSize=12,TextColor3=C.text,PlaceholderColor3=C.muted,Font=Enum.Font.Gotham,BackgroundColor3=C.surface,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left}) corner(search,8)
make("UIPadding",search,{PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9)})
local choices=make("ScrollingFrame",overlay,{Size=UDim2.new(1,-30,1,-94),Position=UDim2.fromOffset(15,88),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=4,ScrollBarImageColor3=C.accent,ScrollingDirection=Enum.ScrollingDirection.Y})
make("UIListLayout",choices,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local pickerItems,pickerChoose={},nil
local choiceConns={}
local function renderChoices()
    for _,c in ipairs(choiceConns) do pcall(function() c:Disconnect() end) end choiceConns={}
    for _,child in ipairs(choices:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    local filter=search.Text:lower() local found=0
    for _,item in ipairs(pickerItems) do
        local hay=(item.title.." "..(item.detail or "")):lower()
        if filter=="" or hay:find(filter,1,true) then
            found=found+1
            local b=make("TextButton",choices,{Text="",Size=UDim2.new(1,-5,0,50),BackgroundColor3=item.selected and C.panel or C.surface,BorderSizePixel=0,LayoutOrder=found}) corner(b,8)
            stroke(b,item.borderColor or C.border,item.borderColor and 0.10 or 0.48,item.borderColor and 1.4 or 1)
            local t=label(b,item.title,12) t.Font=Enum.Font.GothamMedium t.Position=UDim2.fromOffset(11,5) t.Size=UDim2.new(1,-22,0,18)
            local d=label(b,item.detail or "",9,C.muted) d.Position=UDim2.fromOffset(11,26) d.Size=UDim2.new(1,-22,0,17) d.TextWrapped=false d.TextTruncate=Enum.TextTruncate.AtEnd
            choiceConns[#choiceConns+1]=b.Activated:Connect(function() overlay.Visible=false if pickerChoose then pickerChoose(item.value) end end)
        end
    end
    if found==0 then textRow(choices,"Ничего не найдено",42) end
end
connect(search:GetPropertyChangedSignal("Text"),renderChoices)
local function picker(titleText,items,choose)
    pickerItems=items pickerChoose=choose pickerTitle.Text=titleText search.Text="" choices.CanvasPosition=Vector2.zero renderChoices() overlay.Visible=true
end
local function borderForKind(kind,currency)
    if kind=="gem" or isGemCurrency(currency) then return C.gem end
    return C.normal
end
local function eggDetail(e)
    local price=e.price and (tostring(e.price).." "..tostring(e.currency or "")) or "цена из игры"
    return e.world.." · "..price
end
local function islandDetail(i)
    local tag=i.kind=="gem" and "GEMS" or "обычный"
    return i.world.." · "..(i.part and "на карте" or "загрузится при переходе")
end

-- ФАРМ
toggle(pages[1],"Авто надувание","Параллельно остальным функциям",function() return S.autoBubble end,function(v) S:SetMode("autoBubble",v) end)
toggle(pages[1],"Авто продажа","Только при заполненной сумке",function() return S.autoSell end,function(v) S:SetMode("autoSell",v) end)
local sellNow=button(pages[1],"ПРОДАТЬ СЕЙЧАС",function() S:SellNow() end,36) stroke(sellNow,C.accent2,0.25)
slider(pages[1],"Интервал надувания","bubbleDelay",0.2,2,0.05,"сек")
local farmInfo=textRow(pages[1],"",32,C.accent)
local sellInfo=textRow(pages[1],"",32,C.good)

-- ЯЙЦА
textRow(pages[2],"Список: от самого низкого яйца к самому высокому.",26,C.muted)
textRow(pages[2],"Фиолетовая рамка = Gems · зелёная = обычная валюта.",26,C.muted)
local eggButton=button(pages[2],"ВЫБРАТЬ ЯЙЦО  ›",function()
    S:Refresh()
    local items={}
    for idx,e in ipairs(S.eggs) do
        items[#items+1]={title=string.format("%02d. %s",idx,e.name),detail=eggDetail(e),value=e,selected=S.selectedEgg and S.selectedEgg.object==e.object,borderColor=borderForKind(e.kind,e.currency)}
    end
    picker("Яйца · снизу → вверх · "..#items,items,function(e) S:SelectEgg(e) end)
end,46) stroke(eggButton,C.accent,0.25)
local eggInfo=textRow(pages[2],"Выбери яйцо.",30)
local eggActions=make("Frame",pages[2],{Size=UDim2.new(1,-6,0,35),BackgroundTransparency=1})
local goEgg=button(eggActions,"К яйцу",function() S:GoToEgg() end,35) goEgg.Size=UDim2.new(0.5,-4,1,0)
local once=button(eggActions,"Открыть ×1",function() S:HatchOnce() end,35) once.Size=UDim2.new(0.5,-4,1,0) once.Position=UDim2.new(0.5,4,0,0)
toggle(pages[2],"Автооткрытие","Открывает именно выбранное имя яйца",function() return S.autoHatch end,function(v) S:SetMode("autoHatch",v) end)
toggle(pages[2],"ТП при выборе","Сразу переносит к Hotkey яйца",function() return S.teleportOnSelect end,function(v) S.teleportOnSelect=v end)
slider(pages[2],"Интервал открытий","hatchDelay",0.65,3,0.05,"сек")
local hatchInfo=textRow(pages[2],"",30,C.accent)

-- ОСТРОВА
textRow(pages[3],"Сортировка внутри мира: снизу → вверх.",25,C.muted)
textRow(pages[3],"Фиолетовая рамка = gem-остров · зелёная = обычный.",25,C.muted)
local islandButton=button(pages[3],"ВЫБРАТЬ ОСТРОВ  ›",function()
    S:Refresh()
    local items={}
    for idx,i in ipairs(S.islands) do
        items[#items+1]={title=string.format("%02d. %s",idx,i.name),detail=islandDetail(i),value=i,selected=S.selectedIsland and S.selectedIsland.object==i.object,borderColor=borderForKind(i.kind)}
    end
    picker("Острова · снизу → вверх · "..#items,items,function(i) S:SelectIsland(i) S:GoIsland(i) end)
end,46) stroke(islandButton,C.accent2,0.2)
local islandInfo=textRow(pages[3],"",30)
button(pages[3],"ТП К ВЫБРАННОМУ",function() S:GoIsland() end,36)
button(pages[3],"ОБНОВИТЬ СПИСОК",function() S:Refresh() S.status="Списки обновлены" end,36)

-- МОНЕТЫ
toggle(pages[4],"Авто сбор","Проходит СКВОЗЬ hitbox монеты",function() return S.autoCollect end,function(v) S:SetMode("autoCollect",v) end)
local currencyButton=button(pages[4],"Валюта: Все  ›",function()
    S:Refresh() local items={}
    for _,c in ipairs(S.currencies) do items[#items+1]={title=c,detail=c=="Все" and "Любая валюта" or "Только эта валюта",value=c,selected=S.currency==c,borderColor=isGemCurrency(c) and C.gem or C.normal} end
    picker("Валюта",items,function(c) S.currency=c clearTarget() stopMove() end)
end)
local moveButton=button(pages[4],"Перемещение: умное  ›",function()
    picker("Сбор · перемещение",{{title="Умное",detail="Идёт; если застрял — короткий ТП и проходит сквозь hitbox",value="smart",selected=S.collectMode=="smart"},{title="Всегда ТП",detail="ТП перед монетой → движение через неё",value="teleport",selected=S.collectMode=="teleport"}},function(v) S.collectMode=v clearTarget() end)
end)
slider(pages[4],"ТП дальше чем","teleportHeights",1,15,1,"ростов")
local collectInfo=textRow(pages[4],"",34,C.accent)
local mapInfo=textRow(pages[4],"",30)
textRow(pages[4],"Если одна точка не берётся 4 сек — она пропускается на 12 сек, поэтому фарм больше не должен висеть на ней бесконечно.",50,C.muted)

-- ЕЩЁ
button(pages[5],"Обновить всё",function() S:Refresh() S.status="Списки обновлены" end,36)
local hard2=button(pages[5],"Остановить всё",function() S:HardStop() end,36) hard2.TextColor3=C.danger
textRow(pages[5],"Окно таскается за верх, меняет размер за угол и сворачивается кнопкой «—».",44)
textRow(pages[5],"BGS Legacy Hub 0.6.0",24,C.accent)

-- 0.6 controls share the same picker and redraw loop as the existing UI.
local function addPickerButton(page,title,items,choose)
    return button(page,title,function() picker(title,items(),choose) end,40)
end
addPickerButton(pages[2],"Количество яиц: 1 / 3",function()
    return {{title="Открывать 1 яйцо",detail="Один запрос открытия",value=1,selected=S.hatchCount==1},
        {title="Открывать 3 яйца",detail="Игровой режим Multi · нужен доступ к ×3",value=3,selected=S.hatchCount==3}}
end,function(v) S.hatchCount=v end)
toggle(pages[2],"Яйца из любого места","Фарм монет продолжает работать; доступ проверяет игра",function() return S.hatchAnywhere end,function(v) S.hatchAnywhere=v end)
local worldButton=addPickerButton(pages[4],"Выбрать мир фарма",function()
    local items={}
    for _,w in ipairs(S.worlds) do items[#items+1]={title=w.display,detail=w.currency,value=w.key,selected=S.farmWorld==w.key} end
    return items
end,function(v) S:SetFarmWorld(v) end)
worldButton.LayoutOrder=-3
local goWorld=button(pages[4],"В МИР ФАРМА",function() S:GoFarmWorld() end,36) goWorld.LayoutOrder=-2
toggle(pages[4],"Только текущий остров","Выключи для сбора по выбранному миру",function() return S.collectCurrentIslandOnly end,function(v)
    S.collectCurrentIslandOnly=v clearTarget()
    if root() then S.anchor=root().Position end
    if not v then S:GoFarmWorld() end
end)
draws[#draws+1]=function() worldButton.Text="Мир фарма: "..S.farmWorld.."  ›" end
toggle(pages[3],"AFK сбор сундуков","Забрать → вернуться → продолжить прежние функции",function() return S.autoChestRoute end,function(v) S:SetMode("autoChestRoute",v) end)
addPickerButton(pages[3],"Сундуки · выбор 23 островов",function()
    local items={}
    for _,d in ipairs(S.chestDefs) do
        local key=d.world.."/"..d.name
        items[#items+1]={title=(S.chestEnabled[key] and "✓ " or "○ ")..d.name,detail=d.world.." · "..(S.chestResults[key] or "Ещё не проверен"),value=key,selected=S.chestEnabled[key]}
    end
    return items
end,function(key) S.chestEnabled[key]=not S.chestEnabled[key] end)
local chestInfo=textRow(pages[3],"",44,C.good)
toggle(pages[5],"Авто золотые / Shiny","10 одинаковых обычных · без экипнутых и закрытых",function() return S.autoShiny end,function(v) S:SetMode("autoShiny",v) end)
local shinyInfo=textRow(pages[5],"",38,C.good)
addPickerButton(pages[5],"Выбор зелья",function()
    local items={}
    for i,name in ipairs(S.potionNames) do items[#items+1]={title=name,detail="Рецепт лаборатории №"..i,value=i,selected=S.potionRecipe==i} end
    return items
end,function(v) S.potionRecipe=v end)
toggle(pages[5],"Авто крафт и сбор зелий","Выбранный рецепт · свободные слоты лаборатории",function() return S.autoPotions end,function(v) S:SetMode("autoPotions",v) end)
local potionInfo=textRow(pages[5],"",44,C.accent2)
addPickerButton(pages[5],"Выбор мини-игры",function()
    local items={}
    for _,name in ipairs({"Match The Pet","Spin To Win","Doggy Jump"}) do
        items[#items+1]={title=name,detail=name=="Match The Pet" and "Запоминает карточки и собирает пары" or "Доступ и награды проверяет игра",value=name,selected=S.minigame==name}
    end
    return items
end,function(v) S:SetMode("autoMinigames",false) S.minigame=v end)
toggle(pages[5],"Авто мини-игра","Запусти выбранную мини-игру в её мире",function() return S.autoMinigames end,function(v) S:SetMode("autoMinigames",v) end)
local miniInfo=textRow(pages[5],"",44,C.accent)
button(pages[5],"Скопировать диагностику",function() S:Diagnostic() end,36)
draws[#draws+1]=function()
    chestInfo.Text=S.chestStatus shinyInfo.Text=S.shinyStatus
    potionInfo.Text=S.potionNames[S.potionRecipe].." · "..S.potionStatus
    miniInfo.Text=S.minigame.." · "..S.minigameStatus
end

-- Window movement/minimize/resize ------------------------------------------
local minimized=false
local savedSize,savedPosition=nil,nil
local drag,resize=nil,nil
local function viewport() return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600) end
local function fit()
    if minimized then return end
    local view=viewport()
    local minW=math.min(360,math.max(240,view.X-12))
    local w=math.clamp(main.Size.X.Offset,minW,math.max(minW,view.X-12))
    local minH=math.min(300,math.max(220,view.Y-58))
    local h=math.clamp(main.Size.Y.Offset,minH,math.max(minH,view.Y-58))
    main.Size=UDim2.fromOffset(w,h)
    local pos=main.AbsolutePosition
    local x=math.clamp(pos.X,0,math.max(0,view.X-w))
    local y=math.clamp(pos.Y,0,math.max(0,view.Y-h-30))
    main.AnchorPoint=Vector2.new(0,0)
    main.Position=UDim2.fromOffset(x,y)
end
local reopen=make("TextButton",gui,{Name="Mini",Text="BGS",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.text,BackgroundColor3=C.panel,Size=UDim2.fromOffset(48,42),Position=UDim2.fromOffset(20,110),Visible=false,BorderSizePixel=0,Active=true}) corner(reopen,11) stroke(reopen,C.accent,0.15)
local function toggleWindow()
    minimized=not minimized
    if minimized then savedSize=main.Size savedPosition=main.Position reopen.Position=UDim2.fromOffset(main.AbsolutePosition.X,main.AbsolutePosition.Y) overlay.Visible=false end
    main.Visible=not minimized reopen.Visible=minimized
    if not minimized then main.Size=savedSize or main.Size main.Position=savedPosition or main.Position fit() end
end
connect(mini.Activated,toggleWindow)
local miniMoved=false
local function beginDrag(surface,target,isMini)
    connect(surface.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            drag={input=input,start=input.Position,position=target.AbsolutePosition,target=target,isMini=isMini}
            if isMini then miniMoved=false end
        end
    end)
end
beginDrag(header,main,false) beginDrag(reopen,reopen,true)
connect(reopen.Activated,function() if not miniMoved then toggleWindow() end end)
connect(grip.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then resize={input=input,start=input.Position,size=main.AbsoluteSize} end
end)
connect(Input.InputChanged,function(input)
    local mouse=input.UserInputType==Enum.UserInputType.MouseMovement
    if activeSlider and (mouse or input==activeSlider.input) then activeSlider.update(input.Position.X) end
    if drag and (mouse or input==drag.input) then
        local delta=input.Position-drag.start local view=viewport() local target=drag.target
        if drag.isMini and delta.Magnitude>6 then miniMoved=true end
        local x=math.clamp(drag.position.X+delta.X,0,math.max(0,view.X-target.AbsoluteSize.X))
        local y=math.clamp(drag.position.Y+delta.Y,0,math.max(0,view.Y-target.AbsoluteSize.Y-30))
        target.AnchorPoint=Vector2.new(0,0) target.Position=UDim2.fromOffset(x,y)
    end
    if resize and (mouse or input==resize.input) then
        local delta=input.Position-resize.start local view=viewport()
        main.Size=UDim2.fromOffset(math.clamp(resize.size.X+delta.X,360,math.max(360,view.X-20)),math.clamp(resize.size.Y+delta.Y,300,math.max(300,view.Y-58)))
    end
end)
connect(Input.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then drag=nil resize=nil activeSlider=nil end
end)

local function refreshUI()
    for _,draw in ipairs(draws) do draw() end
    footer.Text=S.status
    farmInfo.Text="Пузыри: "..S.bubbleStatus
    sellInfo.Text="Продажа: "..S.sellStatus
    hatchInfo.Text=S.hatchStatus
    once.Text="Открыть ×"..S.hatchCount
    collectInfo.Text=S.collectStatus
    local e=S.selectedEgg
    eggButton.Text=e and (e.name.."  ›") or ("ВЫБРАТЬ ЯЙЦО · "..#S.eggs.."  ›")
    eggInfo.Text=e and eggDetail(e) or ("Найдено яиц: "..#S.eggs)
    local i=S.selectedIsland
    islandButton.Text=i and (i.name.."  ›") or ("ВЫБРАТЬ ОСТРОВ · "..#S.islands.."  ›")
    islandInfo.Text=i and islandDetail(i) or ("Найдено островов: "..#S.islands)
    currencyButton.Text="Валюта: "..S.currency.."  ›"
    moveButton.Text="Перемещение: "..(S.collectMode=="smart" and "умное" or "всегда ТП").."  ›"
    mapInfo.Text="Pickups на карте: "..#S.pickups
end

S:Start()
gui.Name="BGSLegacyHub"
main.AnchorPoint=Vector2.new(0.5,0.5)
task.defer(fit)
local nextTick,nextPaint=0,0
connect(Run.Heartbeat,function()
    if not S.alive then return end
    local now=os.clock()
    if now>=nextTick then nextTick=now+0.10 S:Tick() end
    if now>=nextPaint then nextPaint=now+0.20 refreshUI() end
end)
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit) end

S.startupReady=true
return S

end
