local count = 0
local function eq(a,b) assert(a==b, tostring(a).." ~= "..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<0.06, tostring(a).." ~= "..tostring(b)) end
local function check(name, fn) fn(); count += 1; print("PASS "..name) end
check("speed labels: Latin, Cyrillic, multiplication sign and decimal comma", function()
    for _, v in ipairs({"3x","x3","×3","3×","х3","Х3"," X3 "}) do eq(Core.parseSpeed(v),3) end
    eq(Core.parseSpeed("1,5x"),1.5); eq(Core.parseSpeed(2),2)
    eq(Core.parseSpeed("x30"),nil); eq(Core.parseSpeed("unknown"),nil)
    assert(Core.bindingScore("x2", "3x", "") >= 100)
    assert(Core.bindingScore("x2", "×3", "") >= 100)
end)
check("speed integration does not rescale past time", function()
    local c={};eq(Core.advanceSpeedClock(c,0,1),0)
    eq(Core.advanceSpeedClock(c,4,3),4)
    eq(Core.advanceSpeedClock(c,6,2),10)
    eq(Core.advanceSpeedClock(c,9,1),16)
end)
check("pause keeps input/camera time aligned", function()
    local c={};Core.advanceSpeedClock(c,0,2)
    eq(Core.advanceSpeedClock(c,3,2,true),6)
    eq(Core.advanceSpeedClock(c,10,3,false),6)
    eq(Core.advanceSpeedClock(c,12,3),12)
end)
check("new time metadata and legacy macros survive normalization", function()
    local m=Core.normalizeMacro({id="a",settings={x2=false},clock={recordedSpeed=3},timingMode="game_time_v2",events={{kind="remote",t=5,gameT=12,matchGameTime=21,waveGameOffset=9,gameSpeed=3}},cameraTrack={{t=5,gameT=12,cframe={1,2,3,4,5,6,7,8,9,10,11,12}}}})
    eq(m.events[1].waveGameOffset,9);eq(m.cameraTrack[1].gameT,12);eq(Core.recordedSpeed(m),3)
    local old=Core.normalizeMacro({id="old",settings={x2=true},events={{kind="remote",t=5,waveSyncOffset=10}}})
    eq(old.events[1].waveSyncOffset,10);eq(Core.gameTarget(old.events[1],"waveGameOffset","waveSyncOffset",old),20)
    eq(Core.gameTarget(m.events[1],"waveGameOffset","waveSyncOffset",m),9)
end)
check("real wave clock resets on new waves and match restart", function()
    local state = {speedClock = {}}
    local now, rate, startedAt, wave, intermission = 0, 2, 100, 1, 3
    local os = {clock = function() return now end}
    local ReplicatedStorage = {FindFirstChild = function() return {GetAttribute = function(_, k)
        return ({StartedAt=startedAt,CurrentWave=wave,IntermissionRemaining=intermission})[k]
    end} end}
    local function matchElapsed() return now, startedAt end
    local function serverNow() return now + 100 end
    Core.readLiveSpeed = function() state.liveGameSpeed=rate;return rate end
    -- @PRODUCTION_WAVE_CLOCK
    eq(waveSyncSnapshot().pending,true)
    now=3;intermission=0;eq(waveSyncSnapshot().gameOffset,0)
    now=5;near(waveSyncSnapshot().gameOffset,4)
    rate=3;Core.gameTime();now=7;near(waveSyncSnapshot().gameOffset,10)
    wave=2;intermission=2;eq(waveSyncSnapshot().anchorKnown,false)
    now=9;intermission=0;eq(waveSyncSnapshot().gameOffset,0)
    startedAt=200;wave=1;intermission=4;eq(waveSyncSnapshot().anchorKnown,false)
    now=13;intermission=0;eq(waveSyncSnapshot().gameOffset,0)
end)
-- A deterministic server + game-time clock used by actual wait functions.
local state, task, elapsed, timeline, phase, schedule, stopAt
local function reset(rate)
    state={playToken=1,playing=true,controlRunId=1,config={settings={x2=true,auto=true}}}
    elapsed=0;timeline={};phase={wave=1,anchorKnown=true,pending=false}
    schedule={{0,rate}};stopAt=nil
    Core.advanceSpeedClock(timeline,0,rate)
end
local function rateAt(t)
    local r=schedule[1][2];for _, entry in ipairs(schedule) do if t>=entry[1] then r=entry[2] end end;return r
end
local function tick(dt)
    elapsed+=dt;Core.advanceSpeedClock(timeline,elapsed,rateAt(elapsed))
    assert(elapsed<120,"wait hung")
    if stopAt and elapsed>=stopAt then state.playing=false;state.playToken+=1 end
end
task={wait=tick}
local function waveSyncSnapshot() phase.gameOffset=timeline.total or 0;return phase end
local function matchElapsed() return elapsed,1000 end
Core.matchGameElapsed=function() return timeline.total or 0 end
-- @PRODUCTION_WAITS
check("all 1/1.5/2/3x recording-playback combinations", function()
    for _, recordRate in ipairs({1,1.5,2,3}) do
        for _, playRate in ipairs({1,1.5,2,3}) do
            reset(playRate)
            assert(waitForWaveSyncMoment({waveSyncWave=1,waveSyncOffset=6,gameSpeed=recordRate},1,{}))
            near(elapsed,6*recordRate/playRate)
        end
    end
end)
check("changes to speed during a wave keep event position", function()
    reset(1);schedule={{0,1},{2,3},{4,2}}
    assert(waitForWaveSyncMoment({waveSyncWave=1,waveGameOffset=12},1,{}));near(elapsed,6)
end)
check("match fallback adapts older x2 recordings to x3", function()
    reset(3);assert(waitForMatchMoment({matchTime=9},1,{settings={x2=true}}));near(elapsed,6)
end)
check("new match-time target not multiplied twice", function()
    reset(3);assert(waitForMatchMoment({matchGameTime=12,matchTime=9,gameSpeed=2},1,{}));near(elapsed,4)
end)
check("wave boundary blocks actions even when enough total time passed", function()
    reset(3);phase.wave=1
    task.wait=function(dt) tick(dt);if elapsed>=2 then phase.wave=2;timeline.total=0;task.wait=tick end end
    assert(waitForWaveSyncMoment({waveSyncWave=2,waveGameOffset=3},1,{}));near(elapsed,3)
end)
check("late attach falls back, later wave catches up, stop aborts", function()
    reset(3);phase.anchorKnown=false;eq(waitForWaveSyncMoment({waveSyncWave=1,waveGameOffset=9},1,{}),nil)
    phase.wave=2;eq(waitForWaveSyncMoment({waveSyncWave=1,waveGameOffset=99},1,{}),true)
    reset(3);stopAt=1;eq(waitForMatchMoment({matchGameTime=30},1,{}),false)
end)
-- Exercise actual maximum-speed loop against mock HUD acknowledgements.
local os = {clock = function() return elapsed end}
local values, index, presses, messages
local function log(text) messages[#messages+1]=text end
local function pressSpeedKey() presses+=1;index=index%#values+1;return true end
Core.readLiveSpeed=function() return values[index] end
Core.gameTime=function() return 0 end
-- @PRODUCTION_MAXIMUM
local function maximum(v, start)
    reset(1);values=v;index=start or 1;presses=0;messages={};task.wait=tick
    setMaximumGameSpeed(1);return values[index],presses
end
check("maximum selects x3 and leaves existing x3 unchanged", function()
    local rate,n=maximum({1,1.5,2,3});eq(rate,3);eq(n,3)
    rate,n=maximum({1,1.5,2,3},4);eq(rate,3);eq(n,0)
end)
check("x2-only and x1.5-only cycles recover highest available speed", function()
    local rate,n=maximum({1,1.5,2});eq(rate,2);eq(n,5)
    rate,n=maximum({1,1.5});eq(rate,1.5);eq(n,3)
end)
check("unchanging or unreadable speed does not spam input", function()
    local rate,n=maximum({2});eq(rate,2);eq(n,1)
    rate,n=maximum({false});eq(n,0)
end)
print("Passed "..count.." speed/timing tests")
