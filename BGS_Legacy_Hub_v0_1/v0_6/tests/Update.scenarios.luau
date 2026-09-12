-- Synthetic replicated data exercises layout changes; these are not claimed live egg names/prices.
local S=createRuntime(L)
S:Start()
local checked=0
local function check(ok,label)assert(ok,label) checked+=1 end
local function tickFor(seconds)
    for _=1,math.ceil(seconds/0.1)do advance(0.1)S:Tick()end
end
local function findEntry(list,name)
    for _,entry in ipairs(list)do if entry.name==name then return entry end end
end
local eggData=itemMods.EggModule.export
local autumn=object('Model','AutumnArea',worlds.Overworld)
local ground=floor('Ground',autumn,Vector3.new(160,0,0))
local containers=object('Folder','Stands',autumn)
local nestedEggs=object('Folder','Eggs',containers)
for index=1,3 do
    local name='Fixture Fall '..index..' Egg'
    eggData[name]={Cost={'Leaves',index*100},World='Overworld',Limited=true}
    local model=object('Model',name,nestedEggs)
    local stand=object('Model','Stand',model)
    local button=floor('Hotkey',stand,Vector3.new(155+index*3,index*5,0),Vector3.new(2,2,2))button.CanCollide=false
    if index==2 then floor('Hotkey',model,button.Position,Vector3.new(2,2,2)).CanCollide=false end
end
local leaves=object('Folder','Leaves',pickups)
local leafModel=object('Model','Leaf1',leaves)
local leaf=floor('Hitbox',leafModel,Vector3.new(164,5,0),Vector3.new(2,2,2))leaf.CanCollide=false
object('TouchTransmitter','TouchInterest',leaf)
local decoration=object('Model','Decoration Egg',autumn)
floor('Decoration',decoration,Vector3.new(160,5,10),Vector3.new(2,2,2))
tickFor(1.2)
check(#S.eggs==4,'three nested event eggs plus basic egg, duplicate Hotkey excluded')
check(not findEntry(S.eggs,'Decoration Egg'),'decorative egg excluded')
local event=findEntry(S.islands,'AutumnArea')
check(event and event.event and event.world=='Overworld' and not event.def,'autumn area remains a local Overworld destination')
local e=findEntry(S.eggs,'Fixture Fall 2 Egg')
check(e and e.event and e.area=='AutumnArea' and e.currency=='Leaves' and e.price==200,'real replicated metadata supplies event/currency/cost')
check(S.eggs[3].name=='Fixture Fall 2 Egg','eggs sorted by world then height')
local leafEntry
for _,p in ipairs(S.pickups)do if p.part==leaf then leafEntry=p end end
check(leafEntry and leafEntry.currency=='Leaves','new currency learned before pickup compaction')
check(table.find(S.currencies,'Leaves')~=nil,'new currency appears in selector')
S:GoIsland(event)advance(2)
check(player:GetAttribute('World')=='Overworld' and math.abs(hrp.Position.X-160)<1,'local event teleport uses its loaded floor, no guessed world')
check(S.collectIslandLock and S.collectIslandLock.name=='AutumnArea','current-island farm locks event area')
local saved=hrp.CFrame
for key in pairs(S.chestEnabled)do S.chestEnabled[key]=key=='Overworld/The Floating Island'end
S:SetMode('autoBubble',true)S:SetMode('autoChestRoute',true)S:Tick()advance(4)
check(S.confirmedChests==1 and (hrp.Position-saved.Position).Magnitude<0.01 and S.autoBubble,'AFK chest route returns to exact event position and preserves mode')
S:HardStop()
S:SelectEgg(e)S:SetMode('autoHatch',true)
local old=e.object old:Destroy()
tickFor(1.2)
check(S.selectedEgg.available==false and S.selectedEgg.object==nil and S.autoHatch,'stream removal preserves selection/mode without retaining stale model')
local sent=requests('PurchaseEgg')
tickFor(2)
check(requests('PurchaseEgg')>sent,'known metadata still allows hatch-anywhere while model is streamed out')
eggData[e.name]=nil
S:Refresh()sent=requests('PurchaseEgg')tickFor(3)
check(requests('PurchaseEgg')==sent,'removed unknown egg cannot keep issuing hatch requests')
S:SetMode('autoHatch',false)
eggData[e.name]={Cost={'Leaves',250},World='Overworld',Limited=true}
local replacement=object('Model',e.name,nestedEggs)
floor('Hotkey',replacement,Vector3.new(164,10,0),Vector3.new(2,2,2)).CanCollide=false
tickFor(1.2)
check(S.selectedEgg.object==replacement and S.selectedEgg.available and S.selectedEgg.price==250,'selection rebinds to replaced model and updated price')
local plaza=object('Model','Fixture Plaza',workspace)
local relocated=object('Model','Unusual Display',plaza)relocated:SetAttribute('EggName','Fixture Relocated Egg')
eggData['Fixture Relocated Egg']={Cost={Currency='Gems',Amount=500},World='Heaven',Event=true}
floor('Hotkey',relocated,Vector3.new(5,10,5),Vector3.new(2,2,2)).CanCollide=false
S:Refresh()
local r=findEntry(S.eggs,'Fixture Relocated Egg')
check(r and r.world=='Heaven' and r.price==500 and r.kind=='gem' and r.event,'relocated Hotkey outside Eggs resolves exact name/world/cost from metadata')
local newWorld=object('Model','Fixture New World',worlds)newWorld:SetAttribute('Currency','Leaves')
worldPositions['Fixture New World']=10000
floor('Ground',newWorld,Vector3.new(10000,0,0))
S:Refresh()
check(#S.worlds==10 and #L.worlds==9,'loaded new world extends only this runtime catalog')
S:SetFarmWorld('Fixture New World')advance(2)
check(player:GetAttribute('World')=='Fixture New World' and hrp.Position.X==10000,'discovered world uses its replicated name for native world switch')
S:Refresh()check(#S.worlds==10,'refresh does not duplicate dynamic worlds')
local fresh=L.newWorldCatalog()check(#fresh==9,'another runtime does not inherit stale event worlds')
local currency,price=L.eggCost({Cost={Currency='Leaves',Amount=-2}})
check(currency=='Leaves' and price==nil,'invalid negative price excluded')
S:Stop('test')
print('Update layout and streaming scenarios passed:',checked)
