"""Bundle the native HUD into the existing, self-contained test launcher."""
from pathlib import Path
import argparse

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
path = root / 'RockBugHub_v1_5.lua'
source = path.read_text()
module = (root / 'src/HologramHUD.lua').read_text()
begin, end = '-- HOLOGRAM_HUD_BEGIN', '-- HOLOGRAM_HUD_END'
bundle = begin + '\ndo (function()\nlocal Hologram = (function()\n' + module + '''
end)()
local ok, reason = pcall(Hologram.mount, q, {
    player=j, env=n, classicGui=q.uiRoot, report=aP,
    openClassic=function(tab)q.openClassicPanel(tab)end,
})
if not ok then
    if q.hologram then pcall(function()q.hologram:Destroy()end)end
    q.uiRoot.Enabled=true
    warn("[RockBugHub] Hologram startup failed: "..tostring(reason))
    aP("HUD: "..tostring(reason))
else
    local previousUltra=q.setUltraBlack
    q.setUltraBlack=function(...)
        local result=table.pack(previousUltra(...))
        if q.hologram then q.hologram:SetSuspended(q.ultraBlack==true)end
        return table.unpack(result,1,result.n)
    end
end
end)()end
''' + end
if begin in source:
    before, rest = source.split(begin, 1)
    _, after = rest.split(end, 1)
    updated = before + bundle + after
else:
    # Insert after the existing UI startup guard, without touching session code.
    anchor = 'q.sessionApiUrl='
    assert source.count(anchor) == 1
    updated = source.replace(anchor, bundle + '\n' + anchor, 1)
if args.check:
    assert updated == source, 'HUD bundle is stale; run scripts/build_hologram.py'
    print('HUD source and launcher bundle match')
else:
    path.write_text(updated)
