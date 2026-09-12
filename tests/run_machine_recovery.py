"""Exercise the actual embedded recovery, metadata reader, send gate and input adapter."""
import argparse
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parent.parent
p=argparse.ArgumentParser();p.add_argument('--luau',default='luau');args=p.parse_args()
s=(root/'RockBugHub_v1_5.lua').read_text()
def section(name):return s.split('-- MACHINE_'+name+'_BEGIN',1)[1].split('-- MACHINE_'+name+'_END',1)[0]
sender=s.split('local function ih(eh)',1)[1].split('local function ii()',1)[0]
sender='local function ih(eh)'+sender
with tempfile.TemporaryDirectory(prefix='machine-recovery-')as directory:
    path=Path(directory)/'recovery.luau'
    path.write_text('local q={}\nlocal B=pcall\n'+section('REQUIREMENTS')+section('RECOVERY')+sender+(root/'tests/machine_recovery.spec.luau').read_text())
    subprocess.run([args.luau,str(path)],check=True)

    path=Path(directory)/'attach.luau'
    path.write_text((root/'tests/machine_attach.fixture.luau').read_text()+section('ATTACH')+(root/'tests/machine_attach.spec.luau').read_text())
    subprocess.run([args.luau,str(path)],check=True)
