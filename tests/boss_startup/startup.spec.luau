local function boot(src)
 local value
 task.spawn(function()value=compile(src or source)()end)
 for _=1,300 do if value then break end advance()end
 assert(type(value)=='table','startup did not return a runtime')
 assert(value.alive==true,'runtime not alive')
 assert(type(value.bossCycle)=='table','boss cycle absent')
 assert(playerGui:FindFirstChild('RockBugBossStandalone'),'UI missing')
 return value
end
local function button(text)
 local ui=assert(playerGui:FindFirstChild('RockBugBossStandalone'))
 for _,item in ipairs(ui:GetDescendants())do if item.Text==text then return item end end
 error('button absent: '..text)
end
local function login(key)
 local ui=assert(playerGui:FindFirstChild('RockBugBossStandalone'))
 for _,item in ipairs(ui:GetDescendants())do if item.ClassName=='TextBox' then item.Text=key end end
 button('Активировать').Activated:Fire()
end
local value=boot()
assert(value.authorized==false,'key check bypassed')
assert(value:StartBoss()==false,'unauthorized start allowed')
value.authorized=true;value.lastKeyCheck=math.huge
assert(value:StartBoss()==false,'public flag bypassed private lease')
assert(value.boss:Start()==false,'direct boss start bypassed private lease')
value.authorized=false
print('PASS initial startup, visible UI, key required')
local checks=0
env.request=function()checks+=1;return {StatusCode=403,Body='invalid'}end
login('BAD');assert(not value.authorized,'invalid key accepted');assert(checks==1)
env.request=function()checks+=1;return {StatusCode=200,Body='valid'}end
login('GOOD');assert(value.authorized,'valid key did not unlock');assert(checks==2)
print('PASS valid and invalid server responses')
env.request=function()return {StatusCode=503,Body='unavailable'}end
advance(181)
assert(value:StartBoss()==false,'expired lease allowed start')
assert(value.boss:Start()==false,'expired lease allowed direct start')
assert(not value.authorized,'expired lease did not close gate')
for _,body in ipairs({'wrong-user','truthy'})do
 env.request=function()return {StatusCode=200,Body=body}end
 login('BAD');assert(not value.authorized,'malformed response accepted: '..body)
end
print('PASS private lease, expiry and strict account-bound response validation')
value:Destroy();assert(not value.alive and not value.authorized)
assert(not playerGui:FindFirstChild('RockBugBossStandalone'),'UI remained after destroy')
env.request=function()return {StatusCode=403,Body='invalid'}end
value=boot();assert(not value.authorized,'cached key bypassed fresh server validation')
print('PASS cached key revalidated after restart')
value:Destroy();env.RockBugBossKeys=nil
-- A hanging executor request must return control and allow another attempt.
env.request=function()while true do task.wait(100)end end
value=boot();login('GOOD');assert(button('Проверяю…'))
advance(16)
assert(not value.authorized,'network timeout authorized user')
assert(button('Активировать'),'retry stayed locked after timeout')
env.request=nil;env.http={request=function()return {Body='valid',StatusCode=200}end}
login('GOOD');assert(value.authorized,'http.request fallback failed')
print('PASS hanging network expires and http.request retry unlocks')
value:Destroy();env.RockBugBossKeys=nil;env.http=nil;env.request=nil
-- Both public entry points must mount the same runtime, never the old VM.
local downloads=0
function game:HttpGet(url)
 assert(url:find('/RockBugBossAutoCollect.lua',1,true),'wrong product URL')
 assert(not url:find('rb-bootstrap',1,true),'old VM route used')
 downloads+=1;return source
end
value=boot(launcher);assert(not value.authorized);assert(downloads==1)
value:Destroy()
function game:HttpGet()error('unsupported transport')end
env.request=function(p)
 if p.Method=='GET' then return {StatusCode=200,Body=source}end
 return {StatusCode=403,Body='invalid'}
end
value=boot(launcher);assert(not value.authorized);value:Destroy()
print('PASS legacy launcher and HTTP fallback reach identical protected runtime')
env.request=function()return {StatusCode=503,Body='<html>unavailable</html>'}end
local ok,err=pcall(compile(launcher))
assert(not ok and tostring(err):find('Не удалось скачать',1,true),'error page executed or silently ignored')
assert(#notices>0,'download failure not shown')
print('PASS download error is visible; error page never executed')
