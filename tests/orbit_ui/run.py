"""Native orbit UI tests; pinned fixtures come from the current T64 core/modules."""
import argparse
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parent.parent.parent
here=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--luau',default='luau')
args=parser.parse_args()
module=(root/'RockBugHub_TEST_OrbitUI.lua').read_text()
hud=module.split('-- ORBIT_UI_BEGIN',1)[1].split('-- ORBIT_UI_END',1)[0]
assert 'BindActionAtPriority' not in hud and 'GetGuiObjectsAtPosition' not in hud
fixture=(here/'hologram.fixture.luau').read_text()+'\n'+(here/'content.fixture.luau').read_text()+'\noptions.content=q.hologramContent\n'
with tempfile.TemporaryDirectory(prefix='orbit-ui-') as temp:
    script=Path(temp)/'test.luau'
    for name in ['hologram_lifecycle.spec.luau','orbit.spec.luau','integration.spec.luau']:
        spec=here/name
        if not spec.exists():continue
        body=spec.read_text()
        if name=='integration.spec.luau':
            body=body.replace('-- __STABLE_CARDS__',(here/'stable_cards.fixture.luau').read_text())
            body=body.replace('-- __BOSS_COMPACT__',(here/'boss_compact.fixture.luau').read_text())
            body=body.replace('-- __INSTALL__',module.split('-- ORBIT_INSTALL_BEGIN',1)[1].split('-- ORBIT_INSTALL_END',1)[0])
        script.write_text(fixture+hud+'\n'+body)
        subprocess.run([args.luau,str(script)],check=True)
