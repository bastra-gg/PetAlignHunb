"""Run the real Boss source with a deterministic Roblox boundary (no live network/game)."""
from pathlib import Path
import argparse, subprocess, tempfile
p=argparse.ArgumentParser();p.add_argument('--luau',default='luau');p.add_argument('--source',default='RockBugBossAutoCollect.lua');a=p.parse_args()
root=Path(__file__).resolve().parents[2]
base=(root/'tests/orbit_ui/hologram.fixture.luau').read_text().split('local run={bindings={}}')[0]
base=base.replace('Position=UDim2.fromOffset(0,0)},node)','Position=UDim2.fromOffset(0,0),AbsoluteSize=Vector3.new(348,302),AbsolutePosition=Vector3.new(30,80),Visible=true,Enabled=true,TextTransparency=0,DescendantAdded=signal()},node)')
setup=(Path(__file__).parent/'setup.luau').read_text()
source=Path(a.source).resolve().read_text()
text=base+'\n'+setup+'\nlocal source=[====[\n'+source+'\n]====]\n'
text+='local launcher=[====[\n'+(root/'RockBugBoss.lua').read_text()+'\n]====]\n'
text+=(Path(__file__).parent/'startup.spec.luau').read_text()
with tempfile.TemporaryDirectory() as d:
 f=Path(d)/'test.luau';f.write_text(text)
 subprocess.run([a.luau,str(f)],check=True,timeout=40)

vm=source.split('-- BEGIN LICENSE VM',1)[1].split('-- END LICENSE VM',1)[0]
with tempfile.TemporaryDirectory() as d:
 f=Path(d)/'license.luau'
 f.write_text(vm+'\n'+(Path(__file__).parent/'license.spec.luau').read_text())
 subprocess.run([a.luau,str(f)],check=True,timeout=10)
