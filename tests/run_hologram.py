"""Run the full native HUD with a Roblox boundary double, plus geometry tests."""
import argparse
from pathlib import Path
import subprocess
import tempfile

root=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--luau',default='luau')
args=parser.parse_args()
subprocess.run([args.luau,str(root/'tests/hologram.spec.luau')],check=True)
with tempfile.TemporaryDirectory(prefix='hologram-tests-') as directory:
    script=Path(directory)/'lifecycle.luau'
    launcher=(root/'RockBugHub_v1_5.lua').read_text()
    assert 'openClassicPanel' not in launcher, 'Legacy shell entry point must stay removed'
    bridge=launcher.split('-- HOLOGRAM_CONTENT_BEGIN',1)[1].split('-- HOLOGRAM_CONTENT_END',1)[0]
    script.write_text((root/'tests/hologram.fixture.luau').read_text()+'\n'+bridge+'\noptions.content=q.hologramContent\nlocal HUD=(function()\n'+(root/'src/HologramHUD.lua').read_text()+'\nend)()\n'+(root/'tests/hologram_lifecycle.spec.luau').read_text())
    subprocess.run([args.luau,str(script)],check=True)
