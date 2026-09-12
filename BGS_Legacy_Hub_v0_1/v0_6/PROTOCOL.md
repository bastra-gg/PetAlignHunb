# Protocol evidence and compatibility

The runtime is original implementation. These public, older BGS code examples were read for command names, arguments, instance paths, and array fields; no external script is downloaded or executed at runtime.

- [PinguHub BGS GUI](https://github.com/GamingBoyZ379/PinguHub/blob/2386c00edd1d2f7aa9008e9e3b415581fe52c9ff/BGS%20GUI.lua): `PurchaseEgg(name, "Multi")`; `MakePetShiny(id)`; `GetPlayerData`; `Assets.Modules.Library.index.PETS`; pet slots 1=id, 2=name, 6=equipped, 7=locked, 8=shiny; `WorldService:SetWorld(name)`; `TeleportToCheckpoint(islandName)`; `CollectChestReward(islandName)`; chest `Regen.Enabled`; `MatchThePet(index)` results `first`, `match`, `complete`; `SpinToWin` and `DoggyJumpWin(stage)`.
- [DoComplement AutoLab](https://github.com/DoComplement/Roblox/blob/main/Games/BubbleGumSimulator/AutoLab/UI_Upd/Three.lua): `ScreenGui.BrewingFrame.Brewing.Brew1..3`; `Empty.Visible`, `Brewing.Visible`, `Brewing.Skip.Visible`; `BrewPotion(recipeNumber)` and `ClaimPotion(slotNumber)`. Recipes 1–9 are displayed from this interface's order.
- [diglt BubbleGum example](https://github.com/diglt/Luau-Scripts/blob/405b44d2527740c39fa71c403027a755b2693ffc/Old%20Projects/BubbleGum%20Simulator.luau): islands under `workspace.FloatingIslands.Overworld`; chest interaction anchor `Chest.FastSpawn.Ignore`.

These examples concern the original BGS, not proof of current Legacy server compatibility. Runtime checks require replicated instances/data for the corresponding adapter. In particular, no assertion is made that `DoggyJumpWin` is accepted by the current Legacy server, or that distant/multi hatching bypasses server restrictions. Unsupported schemas are reported, not searched via remote-command guessing.

Regression fixtures model these observed contracts. They validate cancellation, request arguments, bounded retries, exact return to the farm, grouping, and UI construction; they do not validate Roblox physics or the live server.

## Fall compatibility update (0.6.1)

On 2026-09-12, the [official original Bubble Gum Simulator page](https://www.roblox.com/games/2512643572/Bubble-Gum-Simulator) displayed the FALL update: an Autumn area, three eggs, a redesigned lobby, Bubble Pass season 26, Autumn Challenges/shop, and new pets. This identifies the game/update; it does not establish its instance hierarchy or introduce verified new remote contracts.

The update extends map discovery using replicated `Worlds`/`FloatingIslands` children, nested `Eggs`, `Hotkey` ownership, `EggName`, and the existing `EggModule`. Event areas are recognized by replicated event attributes/containers and Autumn/Fall area names; areas inside a world are local destinations. Names, currencies, and prices come from loaded objects/data. No new event quest/shop remote was guessed. The fixture's three Fall egg names and prices are deliberately synthetic.

Streaming replacement preserves the selected egg by world/name. Hatch-anywhere can still use a known `EggModule` entry when its model is unloaded; an egg absent from both sources waits for discovery. Tests cover the new layout, dynamic currency, event filtering, model replacement, a newly loaded world, and exact AFK return to an event location. Live game/executor compatibility remains unverified.
