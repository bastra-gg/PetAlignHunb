# Enchanted repetition pattern — test T29

The old public loader points to `iblameaabis/Enchanted/Enchanted Hub On Top`.
That repository returned 404 on 2026-09-12. The current official implementation
and the reported equality between 7–9 Rare Golems and pack pets are unverified.

Public source copies inspected at commit `0817933fb03ee95ae424e20359c3ea1d61292fda`:

- [RegularVersion.luau](https://github.com/jsjsjsuush148-cyber/AstronomicalUnitsAway/blob/0817933fb03ee95ae424e20359c3ea1d61292fda/scripts/leaks/Muscle%20Legends/Enchanted%20Hub/RegularVersion.luau): FarmV1 uses configurable concurrent workers sending `muscleEvent:FireServer("rep")` with a requested 0.01-second wait.
- [PaidVersion.luau](https://github.com/jsjsjsuush148-cyber/AstronomicalUnitsAway/blob/0817933fb03ee95ae424e20359c3ea1d61292fda/scripts/leaks/Muscle%20Legends/Enchanted%20Hub/PaidVersion.luau): Fast Rep uses batches of ten plain `rep` calls; Fast Tools sets `repTime` to zero for Weight, Pushups, Situps and Handstands. Other modes request far more workers/calls. No license/key logic from these copies is used.

The relevant routines do not replace 10% pet perks with 20% perks. They change
client activation/request timing; the server still decides which reps count.
A common effective server/timing limit could explain similar observed speeds,
but the server cooldown formula and the reported pet comparison were not found.

## Test-only implementation

`RockBugHub_v1_5.lua` T29 adds an opt-in FAST REPS switch under TRAIN.
It uses original code implementing plain rep batches (including machines), at most
ten calls per existing scheduler tick and 600 calls/second, reduced for high ping.
This replaces the legacy turbo sender while enabled. Existing tool activation
still runs. No extra worker threads, forced pet swaps, or pet stat edits are added.
The previous implementation already had a 200–1200 requests/second turbo sender;
the new profile is a protocol/timing alternative, not a proven speed multiplier.

Only the currently trained tool's numeric `repTime` is temporarily changed.
Its actual value is restored on disable, training stop, tool change, network hold,
death, respawn, or shutdown; later values supplied by the game are preserved.
The mode can be saved with the existing session controls. It requires an active
training mode or attached machine and pauses during boss combat.

Run `python3 tests/run_enchanted_rep.py --luau /path/to/luau`.
The scenarios cover production controller/adapter routing, exact restoration,
no stale/catch-up batches, stop mid-batch, respawn, machine arguments and ping.
Compilation and these local scenarios do not verify live Roblox server gains.
