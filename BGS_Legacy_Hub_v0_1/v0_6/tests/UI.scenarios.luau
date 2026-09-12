local eventArea=object('Model','AutumnArea',worlds.Overworld)
floor('Ground',eventArea,Vector3.new(160,0,0))
local eventEgg=object('Model','Fixture Event Egg',object('Folder','Eggs',eventArea))
floor('Hotkey',eventEgg,Vector3.new(160,10,0),Vector3.new(2,2,2)).CanCollide=false
itemMods.EggModule.export['Fixture Event Egg']={Cost={'Leaves',100},World='Overworld',Limited=true}
local S,api=createRuntime(L)
local result=createUI(S,api)
assert(result==S and S.startupReady and S.gui.Name=='BGSLegacyHub','full UI initialization')
advance(0.2)services.RunService.Heartbeat:Fire()
local function buttonText(text)
    for _,o in ipairs(S.gui:GetDescendants())do if o.ClassName=='TextButton' and o.Text==text then return o end end
    error('Button missing: '..text)
end
local function choose(text)
    for _,o in ipairs(S.gui:GetDescendants())do if o.ClassName=='TextLabel' and o.Text==text then o.Parent.Activated:Fire()return end end
    error('Choice missing: '..text)
end
choose('Только яйца события')assert(S.eventEggsOnly,'event toggle wired')
buttonText('ВЫБРАТЬ ЯЙЦО · 2  ›').Activated:Fire()
assert(not pcall(choose,'01. Basic Egg'),'normal egg excluded from event picker')
choose('02. Fixture Event Egg')assert(S.selectedEgg.name=='Fixture Event Egg','event picker selects actual entry')
buttonText('Количество яиц: 1 / 3').Activated:Fire()
choose('Открывать 3 яйца')assert(S.hatchCount==3,'triple picker wired')
buttonText('Мир фарма: Overworld  ›').Activated:Fire()
choose('Candy Land · мир конфет')advance(2)
assert(S.farmWorld=='Candy Land' and player:GetAttribute('World')=='Candy Land','world picker performs world switch')
services.RunService.Heartbeat:Fire()
buttonText('Сундуки · выбор 23 островов').Activated:Fire()
choose('✓ The Floating Island')assert(not S.chestEnabled['Overworld/The Floating Island'],'chest checklist wired')
buttonText('Выбор зелья').Activated:Fire()choose('Max Level')assert(S.potionRecipe==4,'potion picker wired')
buttonText('Выбор мини-игры').Activated:Fire()choose('Spin To Win')assert(S.minigame=='Spin To Win','minigame picker wired')
buttonText('СТОП').Activated:Fire()assert(not S.autoCollect and not S.autoChestRoute,'header stop wired')
S:Stop('test')assert(not S.alive and not S.gui.Parent,'UI cleanup')
print('UI construction and control scenarios passed: 11')
