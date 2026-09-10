local S=createRuntime(L)
S:Start()
local checked=0
local function check(ok,label)assert(ok,label) checked+=1 end
local function tickFor(seconds)
    for _=1,math.ceil(seconds/0.1)do advance(0.1)S:Tick()end
end
local function reset()
    S:HardStop() rejectChest=false rejectEgg=false hangData=false
    S.farmWorld='Overworld' S:GoFarmWorld()advance(1)
    hrp.CFrame=CFrame.new(0,6,0)S.collectCurrentIslandOnly=true
end
check(S.startupReady,'runtime starts')
check(#S.worlds==9 and #S.chestDefs==23,'full menu data')
check(#S.pickups==1 and S.pickups[1].part==coin,'nested model pickup discovered')
check(S.islands[2].name~=nil,'FloatingIslands discovery')
S:SetMode('autoCollect',true)S:Tick()
check(S.target and S.target.part==coin,'nested coin chosen')
local firstDest=human.destination
hrp.CFrame=CFrame.new(14,6,0)advance(0.3)S:Tick()
check(human.destination.X==firstDest.X and firstDest.X>coin.Position.X,'crossing direction does not reverse near target')
local coin2=floor('Part',nested,Vector3.new(18,5,0),Vector3.new(2,2,2))coin2.CanCollide=false
object('TouchTransmitter','TouchInterest',coin2)
tickFor(1.1)
check(#S.pickups==2,'streamed pickup added')
coin2:Destroy()tickFor(1.1)
check(#S.pickups==1,'removed pickup pruned')
S:SetMode('autoCollect',false)coin.Transparency=1
S:SetMode('autoCollect',true)tickFor(0.3)
check(S.target and S.target.part==coin,'transparent real hitbox remains collectible')
coin.Transparency=0
reset()
S:SelectEgg(S.eggs[1])S.hatchCount=3
S:HatchOnce()tickFor(0.2)
check(requests('PurchaseEgg')==1,'triple sends exactly one request')
local purchase=requestLog[#requestLog]
check(purchase.action=='PurchaseEgg' and purchase.args[2]=='Multi','correct native triple argument')
check(data.EGGS_OPENED==3,'mock server hatches three')
reset()
S:SetMode('autoCollect',true) S:SelectEgg(S.eggs[1])S:SetMode('autoHatch',true)
S:Tick()
check(S.target~=nil and S.autoHatch and S.autoCollect,'hatch and collect concurrent')
reset()
local saved=hrp.CFrame
S:SetMode('autoCollect',true)S:SetMode('autoBubble',true)
S:SetMode('autoChestRoute',true)S:Tick()advance(3)
check(S.confirmedChests==1,'chest success uses regeneration feedback')
check((hrp.Position-saved.Position).Magnitude<0.01,'returns exactly to afk position')
check(S.autoCollect and S.autoBubble,'prior modes still enabled after chest')
S:Tick()check(S.target~=nil,'farm resumes after chest')
reset()
regen.Enabled=false rejectChest=true
local beforeConfirmed=S.confirmedChests
S:SetMode('autoChestRoute',true)
-- Only the first chest enabled so the target is deterministic across cycles.
for key in pairs(S.chestEnabled)do S.chestEnabled[key]=key=='Overworld/The Floating Island'end
S:Tick()advance(6)
check(S.confirmedChests==beforeConfirmed,'remote pcall is not reward confirmation')
check(S.chestResults['Overworld/The Floating Island']=='Нет подтверждения','unconfirmed reward shown honestly')
check((hrp.Position-Vector3.new(0,6,0)).Magnitude<0.01,'returns on failed chest')
reset()
regen.Enabled=false S:SetMode('autoChestRoute',true)S:Tick()advance(0.1)
S:HardStop()hrp.CFrame=CFrame.new(35,6,0)
local sentBefore=#requestLog
advance(8)
check((hrp.Position-Vector3.new(35,6,0)).Magnitude<0.01,'hard stop cancels delayed chest teleport/return')
check(#requestLog==sentBefore,'hard stop cancels future requests')
reset()
regen.Enabled=false S:SetMode('autoChestRoute',true)S:Tick()advance(0.1)
S:SetFarmWorld('Candy Land')advance(3)
check(player:GetAttribute('World')=='Candy Land','manual world change replaces chest job')
check(hrp.Position.X==1000,'cancelled chest cannot return over manual teleport')
check(S.farmWorld=='Candy Land' and not S.collectCurrentIslandOnly,'world choice selects world farm scope')
reset()
regen.Enabled=false S:SetMode('autoChestRoute',true)S:Tick()advance(0.1)
local oldCharacter=character
character=object('Model','RespawnCharacter',workspace)
hrp=floor('HumanoidRootPart',character,Vector3.new(30,6,0),Vector3.new(2,2,1))
human=object('Humanoid','Humanoid',character)
player.Character=character player.CharacterAdded:Fire(character)
advance(4)
check((hrp.Position-Vector3.new(30,6,0)).Magnitude<0.01,'respawn never inherits stale chest return')
check(S.autoChestRoute,'respawn preserves enabled modes')
oldCharacter:Destroy()
reset()
for i=1,10 do data.PETS[i]={i,'Doggy',0,1,0,false,false,false}end
S:SetMode('autoShiny',true)tickFor(5)
check(requests('MakePetShiny')==1,'one shiny request for unchanged inventory')
tickFor(6)check(requests('MakePetShiny')==1,'unchanged/rejected inventory never repeatedly consumed')
reset()
data.PETS[10][7]=true S:SetMode('autoShiny',true)tickFor(4)
check(requests('MakePetShiny')==1,'locked tenth pet prevents shiny request')
reset()
S:SetMode('autoPotions',true)tickFor(9)
check(requests('BrewPotion')==3,'fills available brewing slots once')
local slot=brewing.Brew1 slot.Brewing.Skip.Visible=false
tickFor(3)
check(requests('ClaimPotion')==1,'claims only completed slot')
check(requests('BrewPotion')>=3,'craft continues after claim')
reset()
S.minigame='Match The Pet' S:SetMode('autoMinigames',true)tickFor(70)
local matchedCount=0 for _ in pairs(serverMatched)do matchedCount+=1 end
check(matchedCount==18,'matching solver completes all nine pairs')
check(requests('MatchThePet')<=54,'matching solver has bounded requests')
reset()
hangData=true S:SetMode('autoShiny',true)
local reads=requests('GetPlayerData')tickFor(20)
check(requests('GetPlayerData')==reads+1,'hung invoke does not accumulate remote tasks')
S:HardStop()advance(1)hangData=false
check(not S.autoShiny,'stop cancels hung inventory reader')
S:Stop('tests')
local finalRequests=#requestLog advance(30)
check(#requestLog==finalRequests and not S.alive,'closed runtime stays stopped')
print('Runtime integration scenarios passed:',checked)
