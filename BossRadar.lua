-- BossRadar protected launcher
local URL="https://szfjrpkdbccsveklkwyy.supabase.co/functions/v1/boss-radar-bootstrap"
local ok,src=pcall(function()return game:HttpGet(URL.."?v="..tostring(os.time()),true)end)
if not ok or type(src)~="string"then error("BossRadar: load failed",0)end
local compiler=loadstring or load
if type(compiler)~="function"then error("BossRadar: loadstring unavailable",0)end
local fn,err=compiler(src)
if type(fn)~="function"then error("BossRadar: "..tostring(err),0)end
local runtime=fn()

task.spawn(function()
    if type(runtime)~="table" then return end
    local Players=game:GetService("Players")
    local HttpService=game:GetService("HttpService")
    local UIS=game:GetService("UserInputService")
    local player=Players.LocalPlayer
    if not player then return end

    local endpoint="https://szfjrpkdbccsveklkwyy.supabase.co/functions/v1/rockbug-online"
    local clientKey="b071080d347e5e9aac86deaa4f0567b3ca04f0048aa945761d1c2f31121ed5ae"
    local sessionId=HttpService:GenerateGUID(false)
    local commandVersion=0
    local paused=false
    local snapshot=nil

    local function post(payload)
        local good,body=pcall(function()return HttpService:JSONEncode(payload)end)
        if not good then return nil end
        local requestFn=nil
        pcall(function()
            requestFn=request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
        end)
        local raw=nil
        if type(requestFn)=="function" then
            local sent,res=pcall(requestFn,{
                Url=endpoint,Method="POST",
                Headers={["Content-Type"]="application/json",["x-rockbug-key"]=clientKey},
                Body=body,Timeout=10
            })
            if sent then raw=type(res)=="table"and(res.Body or res.body)or res end
        else
            local sent,res=pcall(function()
                return game:HttpPost(endpoint.."?key="..clientKey,body,"application/json")
            end)
            if sent then raw=res end
        end
        if type(raw)~="string"or#raw>65536 then return nil end
        local decodedOk,decoded=pcall(function()return HttpService:JSONDecode(raw)end)
        return decodedOk and type(decoded)=="table"and decoded or nil
    end

    local function setRef(ref,value,silent)
        if ref and type(ref.Set)=="function" then pcall(ref.Set,value,silent==true) end
    end

    local function pause()
        local core=runtime.runtime
        local cfg=runtime.settings or {}
        snapshot={
            boss=cfg.bossFarm==true,
            rebirth=cfg.autoRebirth==true,
            machine=cfg.machineFarm==true,
            kill=tostring(cfg.killMode or "off"),
        }
        if core then
            if core.bossCycle and type(core.bossCycle.SetEnabled)=="function" then
                pcall(core.bossCycle.SetEnabled,core.bossCycle,false)
            end
            local refs=core.leverRefs
            setRef(refs and refs.autoRebirth,false)
            setRef(refs and refs.machineFarm,false)
            if refs and type(refs.kill)=="table" then
                for _,mode in ipairs({"all","whitelist","blacklist"})do setRef(refs.kill[mode],false,true)end
            end
            core.killMode="off"
        end
        paused=true
    end

    local function resume()
        local core=runtime.runtime
        if core and snapshot then
            if snapshot.boss and core.bossCycle and type(core.bossCycle.SetEnabled)=="function" then
                pcall(core.bossCycle.SetEnabled,core.bossCycle,true)
            end
            local refs=core.leverRefs
            if snapshot.rebirth then setRef(refs and refs.autoRebirth,true)end
            if snapshot.machine then setRef(refs and refs.machineFarm,true)end
            if snapshot.kill~="off" and refs and type(refs.kill)=="table" then
                setRef(refs.kill[snapshot.kill],true)
            end
        end
        snapshot=nil
        paused=false
    end

    local function ack(version,state,message)
        post({action="ack",session_id=sessionId,command_version=version,state=state,error=tostring(message or ""):sub(1,300)})
    end

    while runtime.alive~=false do
        local executor=""
        pcall(function()
            if type(identifyexecutor)=="function"then executor=tostring(identifyexecutor())
            elseif type(getexecutorname)=="function"then executor=tostring(getexecutorname())end
        end)
        local result=post({
            action="heartbeat",session_id=sessionId,
            player_user_id=player.UserId,player_name=player.Name,display_name=player.DisplayName,
            version="Boss Radar",executor_name=executor:sub(1,80),
            place_id=game.PlaceId,job_id=game.JobId,
            state=paused and "paused"or"running",
            details={device=UIS.TouchEnabled and "mobile"or"desktop",locale=""}
        })
        if type(result)=="table" and type(result.command)=="string" then
            local version=math.max(0,math.floor(tonumber(result.command_version)or 0))
            if version>commandVersion then
                commandVersion=version
                if result.command=="pause" then
                    local done,problem=pcall(pause)
                    ack(version,done and "paused"or"error",done and ""or problem)
                elseif result.command=="resume" then
                    local done,problem=pcall(resume)
                    ack(version,done and "running"or"error",done and ""or problem)
                elseif result.command=="stop" then
                    ack(version,"stopped","")
                    pcall(function()runtime:Destroy()end)
                    task.wait(.15)
                    post({action="leave",session_id=sessionId,state="stopped"})
                    return
                end
            end
        end
        for _=1,12 do
            if runtime.alive==false then break end
            task.wait(1)
        end
    end
    post({action="leave",session_id=sessionId,state="stopped"})
end)

return runtime
