"""Run extracted production timing code with the Luau CLI (no Roblox/executor needed)."""
import os, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[2]
source = (ROOT / 'TDMacroPrototype.lua').read_text()
core = source[source.index('local Core = {}'):source.index('local defaultConfig =')]
waits = source[source.index('local function waitForWaveSyncMoment'):source.index('local function waitForRecordedMoment')]
maximum = source[source.index('local function setMaximumGameSpeed'):source.index('\narmMatchControls =')]
preamble = '''local VERSION = 2
local game = {PlaceId = 42}
local HttpService = {GenerateGUID = function() return "test-id" end}
'''
tests = (ROOT / 'tests/td_macro/speed.spec.luau').read_text()
# Test code supplies the runtime upvalues, then receives the production functions.
wave_clock = source[source.index('function Core.gameTime()'):source.index('-- Keep wave transitions hot')]
tests = tests.replace('-- @PRODUCTION_WAVE_CLOCK', wave_clock).replace('-- @PRODUCTION_WAITS', waits).replace('-- @PRODUCTION_MAXIMUM', maximum)
with tempfile.NamedTemporaryFile('w', suffix='.luau', delete=False) as f:
    f.write(preamble + core + tests)
    path = f.name
try:
    subprocess.run([os.environ.get('LUAU_BIN', 'luau'), path], check=True)
finally:
    pathlib.Path(path).unlink()
