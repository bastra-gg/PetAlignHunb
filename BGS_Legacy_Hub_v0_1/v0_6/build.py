#!/usr/bin/env python3
"""Bundle the reviewed sources into a single Roblox-executor entrypoint."""
from pathlib import Path

root = Path(__file__).resolve().parent
parts = ["-- BGS Legacy Hub 0.6.1; generated with v0_6/build.py.\n"]
for name, variable in [("Logic.lua", "logic"), ("Runtime.lua", "createRuntime"), ("UI.lua", "createUI")]:
    parts.append(f"local {variable}=(function()\n{(root/name).read_text()}\nend)()\n")
parts.append('''local S,api=createRuntime(logic)
local ok,result=xpcall(function() return createUI(S,api) end,function(err) return tostring(err) end)
if not ok then
    pcall(function() S:Stop("startup failure") end)
    error("BGS UI: "..result,0)
end
return result
''')
target = root.parent / "BGS_Legacy_Hub_v0_6_0.lua"
target.write_text("".join(parts), encoding="utf-8")
print(f"Built {target.name}: {target.stat().st_size} bytes")
