assert(not access.allowed(0))
for _,reply in ipairs({{}, {ok=1,user_id=17}, {ok=true,user_id=18}, {ok=true,user_id=0/0}})do
 assert(not access.accept(reply,17,10))
end
assert(not access.accept(nil,17,10))
assert(not access.accept({ok=true,user_id=17},17,math.huge))
assert(not access.accept({ok=true,user_id=17},17,0/0))
assert(access.accept({ok=true,user_id=17},17,10))
assert(access.allowed(189.99) and not access.allowed(190))
assert(access.accept({ok=true,user_id=17},17,100))
assert(access.allowed(279.99) and not access.allowed(280))
access.invalidate();assert(not access.active() and not access.allowed(100))
local reply={ok=true,user_id=17}
local begin=os.clock()
for _=1,10000 do assert(access.accept(reply,17,10))end
local validation=(os.clock()-begin)*1000/10000
begin=os.clock()
for _=1,1000000 do assert(access.allowed(10))end
local guard=(os.clock()-begin)*1000/1000000
print(string.format('PASS bounded license VM; mean validation %.6f ms, native guard %.6f ms (host only)',validation,guard))
