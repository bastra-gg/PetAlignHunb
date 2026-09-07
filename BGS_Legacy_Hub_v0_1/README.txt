BGS Legacy Hub v0.1

Первый прототип:
- Auto Bubble
- Auto Hatch + выбор яйца из workspace.Eggs
- обычная ходьба к яйцу
- Auto Collect через workspace.Pickups
- Hard Stop
- без телепортов и обходов античита

OG BGS структура:
ReplicatedStorage.NetworkRemoteEvent
FireServer("BlowBubble")
FireServer("PurchaseEgg", eggName)
workspace.Eggs[eggName].Hotkey
workspace.Pickups

Сначала проверь: UI, Auto Bubble, скан яиц, Auto Hatch рядом с яйцом, Auto Collect.
