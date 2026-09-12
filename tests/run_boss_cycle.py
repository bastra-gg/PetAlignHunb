"""Run the embedded test-hub code with a fake clock and delayed game acknowledgements."""
import argparse
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
args = parser.parse_args()
source = (root / 'RockBugHub_v1_5.lua').read_text()
def section(name):
    return source.split('-- BOSS_' + name + '_BEGIN', 1)[1].split('-- BOSS_' + name + '_END', 1)[0]
paid = (root / 'RockBugBoss.lua').read_text()
for name in ['REWARD_TEXT', 'CHEST_COLLECTOR', 'CHEST_BUTTON', 'CHEST_INTERACT']:
    paid_section = paid.split('-- BOSS_' + name + '_BEGIN', 1)[1].split('-- BOSS_' + name + '_END', 1)[0]
    assert paid_section == section(name), 'Paid reward implementation diverged: ' + name
print('Paid reward routines match the tested hub', flush=True)
parts = '\n'.join(section(name) for name in ['SEAT_WAIT', 'MACHINE_PRESENCE', 'REWARD_TEXT', 'CHEST_COLLECTOR', 'CHEST_BUTTON', 'CHEST_INTERACT', 'CYCLE'])
restore = source.split('    local function cancelRestore()', 1)[1].split('-- BOSS_RESTORE_END', 1)[0]
restore = 'local function cancelRestore()' + restore
with tempfile.TemporaryDirectory(prefix='boss-cycle-tests-') as directory:
    script = Path(directory) / 'scenarios.luau'
    script.write_text('local workspace={}\n' + parts + (root / 'tests/boss_cycle.spec.luau').read_text())
    subprocess.run([args.luau, str(script)], check=True)
    script.write_text((root / 'tests/boss_restore.fixture.luau').read_text() + section('SEAT_WAIT') + section('MACHINE_PRESENCE') + restore + (root / 'tests/boss_restore.spec.luau').read_text())
    subprocess.run([args.luau, str(script)], check=True)
