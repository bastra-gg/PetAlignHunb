-- RockBugHub loader + Boss Reward Auto Collect
-- Original v1.5 core is pinned to the last full source commit so this loader never recurses.
local CORE = "https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/9203a6627ae0b686683e9493ecb7f440260ae945/RockBugHub_v1_5.lua"
local ADDON = "https://raw.githubusercontent.com/bastra-gg/PetAlignHunb/main/RockBugHub_BossRewardAddon.lua"

local function run(url, label)
    local ok, source = pcall(function()
        return game:HttpGet(url .. (url:find("?", 1, true) and "&" or "?") .. "cb=" .. tostring(os.time()))
    end)
    if not ok or type(source) ~= "string" or #source < 10 then
        warn("[RockBugHub] failed to download " .. label .. ": " .. tostring(source))
        return nil
    end
    local fn, err = loadstring(source)
    if not fn then
        warn("[RockBugHub] failed to compile " .. label .. ": " .. tostring(err))
        return nil
    end
    local ran, result = pcall(fn)
    if not ran then
        warn("[RockBugHub] " .. label .. " runtime error: " .. tostring(result))
        return nil
    end
    return result
end

run(CORE, "core")
task.defer(function()
    task.wait(0.8)
    run(ADDON, "boss reward addon")
end)
