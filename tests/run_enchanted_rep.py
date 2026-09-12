"""Exercise the actual embedded controller, adapter and turbo routing with Luau."""
import argparse
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
source = (root / "RockBugHub_v1_5.lua").read_text()
production = source.split("q.turboRepEnabled=true;", 1)[1].split("function q.runFastPunch", 1)[0]
fixture = r'''
local calls={}
local legacySends=0
local failures=0
local afterSend=nil
local sendFailure=false
local character={}
local humanoid={Health=100}
local q={alive=true,trainOrder={},leverRefs={},directRemoteEnabled=true,remoteSentWindow=0,
    remoteWindowStart=0,turboRepEnabled=true,pingAvailable=false,networkPaused=false}
local function aM()return character end
local function aN()return humanoid end
local function cU(tool)return tool.Name=="Punch"end
local remote={}
function remote:FireServer(...)
    if sendFailure then error("simulated remote failure")end
    calls[#calls+1]=table.pack(...)
    if afterSend then afterSend()end
end
local function eg()return remote end
local function ej()end
local function ei()legacySends+=1 end
local function dN()failures+=1 end
local function aJ(connection)return connection end
local characterRemoving
local j={CharacterRemoving={Connect=function(_,callback)characterRemoving=callback return {}end}}
function j:FindFirstChild()return nil end
'''
with tempfile.TemporaryDirectory(prefix="enchanted-rep-tests-") as directory:
    script = Path(directory) / "scenarios.luau"
    script.write_text(fixture + production + (root / "tests/enchanted_rep.spec.luau").read_text())
    subprocess.run([args.luau, str(script)], check=True)
