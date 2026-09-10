#!/usr/bin/env python3
import argparse
import subprocess
import tempfile
from pathlib import Path
root=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--luau',default='luau')
args=parser.parse_args()
subprocess.run([args.luau,str(root/'Logic.spec.luau')],check=True)
parts=[(root/'MockRoblox.luau').read_text(), '\nlocal L=(function()\n', (root.parent/'Logic.lua').read_text(), '\nend)()\nlocal createRuntime=(function()\n', (root.parent/'Runtime.lua').read_text(), '\nend)()\n', (root/'Runtime.scenarios.luau').read_text()]
with tempfile.TemporaryDirectory(prefix='bgs-tests-') as directory:
    test=Path(directory)/'Runtime.spec.luau'
    test.write_text(''.join(parts))
    subprocess.run([args.luau,str(test)],check=True)

ui_parts=parts[:-1]+['\nlocal createUI=(function()\n', (root.parent/'UI.lua').read_text(), '\nend)()\n', (root/'UI.scenarios.luau').read_text()]
with tempfile.TemporaryDirectory(prefix='bgs-ui-tests-') as directory:
    test=Path(directory)/'UI.spec.luau'
    test.write_text(''.join(ui_parts))
    subprocess.run([args.luau,str(test)],check=True)
