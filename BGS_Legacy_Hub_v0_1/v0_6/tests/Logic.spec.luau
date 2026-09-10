local L=require('../Logic')
local checked=0
local function check(ok,label) assert(ok,label) checked+=1 end
check(#L.worlds==9,'nine worlds')
check(#L.chests==23,'23 requested chest islands')
check(L.world('CandyLand')=='Candy Land','world aliases')
check(L.matches('See Shell Isle',L.chests[12]),'user island spelling')
check(L.matches('Claud Island',L.chests[22]),'cloud alias')
local single=L.hatchArgs('Common Egg',1)
local triple=L.hatchArgs('Common Egg',3)
check(single.n==2 and single[1]=='PurchaseEgg','one single request')
check(triple.n==3 and triple[3]=='Multi','native triple, not three single requests')
local owner=L.newLease()
local ticket=owner:begin('chest','character-1',{world='Candy Land'})
check(owner:begin('sell','character-1',{})==nil,'one movement owner')
check(owner:valid(ticket,'character-1',true),'valid owner')
check(not owner:valid(ticket,'character-2',true),'respawn invalidates return')
owner:cancel()
check(not owner:valid(ticket,'character-1',true),'hard stop invalidates delayed return')
local newer=owner:begin('manual','character-1',{})
owner:finish(ticket)
check(owner.current==newer,'old job cannot unlock new teleport')
local pets={}
for i=1,9 do pets[i]={id=i,name='Doggy',shiny=false,locked=false,equipped=false} end
check(#L.shinyGroups(pets)==0,'nine pets never consumed')
pets[10]={id=10,name='Doggy',shiny=false,locked=false,equipped=false}
check(#L.shinyGroups(pets)==1,'exactly ten is eligible')
pets[11]=pets[10]
check(L.shinyGroups(pets)[1].count==10,'duplicate IDs do not count twice')
pets[10].shiny=true
check(#L.shinyGroups(pets)==0,'shiny excluded')
pets[10].shiny=false pets[10].locked=true
check(#L.shinyGroups(pets)==0,'locked excluded')
pets[10].locked=false pets[10].equipped=true
check(#L.shinyGroups(pets)==0,'equipped excluded')
pets[10].equipped=nil
check(#L.shinyGroups(pets)==0,'unknown equipped state not treated as false')
pets[10].equipped=false
check(#L.shinyGroups(pets,'Kitty')==0,'pet type filter')
local memo={[1]='Doggy',[2]='Kitty',[3]='Doggy'}
check(L.matchNext(memo,{},nil,18)==1,'known pair first')
check(L.matchNext(memo,{},1,18)==3,'known counterpart second')
check(L.matchNext(memo,{[1]=true,[3]=true},nil,18)==4,'skip matched and seek unknown')
print('Logic scenarios passed:',checked)
