"""Run the full native HUD with a Roblox boundary double, plus layout tests."""
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
    hud=(root/'src/HologramHUD.lua').read_text()
    assert 'BindActionAtPriority' not in hud and 'GetGuiObjectsAtPosition' not in hud, 'Use native GUI dispatch'
    bridge=launcher.split('-- HOLOGRAM_CONTENT_BEGIN',1)[1].split('-- HOLOGRAM_CONTENT_END',1)[0]
    script.write_text((root/'tests/hologram.fixture.luau').read_text()+'\n'+bridge+'\noptions.content=q.hologramContent\nlocal HUD=(function()\n'+(root/'src/HologramHUD.lua').read_text()+'\nend)()\n'+(root/'tests/hologram_lifecycle.spec.luau').read_text())
    subprocess.run([args.luau,str(script)],check=True)

    controls=launcher.split('local function oC(',1)[1].split('local p0=',1)[0]
    setup="""
Enum.TextXAlignment.Right="Right";Enum.Font.GothamBlack="GothamBlack"
input.InputEnded=signal();local f=input
local lw={Surface=Color3.fromRGB(27,46,59),SurfaceAlt=Color3.fromRGB(38,56,68),Text=Color3.fromRGB(238,249,255),Muted=Color3.fromRGB(154,178,189),Success=Color3.fromRGB(96,199,147),Accent=Color3.fromRGB(65,224,255),Accent2=Color3.fromRGB(65,224,255)}
q.layoutUI.themeAccentFills={};q.layoutUI.themeIconFills={}
local function mg(parent,radius)local c=Instance.new("UICorner");c.Parent=parent;c.CornerRadius=UDim.new(0,radius);return c end
local function mq(parent)local c=Instance.new("UIStroke");c.Parent=parent;return c end
local function mt(parent,text,size,font,color)local label=Instance.new("TextLabel");label.Parent=parent;label.Text=text;label.TextSize=size;label.Font=font;label.TextColor3=color;label.BackgroundTransparency=1;return label end
local function aJ(connection)return connection end
local function aP()end
task.defer=function(callback)callback()end
"""
    script.write_text((root/'tests/hologram.fixture.luau').read_text()+setup+'local function oC('+controls+(root/'tests/drawer_controls.spec.luau').read_text())
    subprocess.run([args.luau,str(script)],check=True)
