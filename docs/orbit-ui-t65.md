# T65 orbit UI

This update starts from T64 (`904f79a471b31712909ac75418e61285112d198a`),
including its rewritten bootstrap. All seven pinned core/automation/UI module URLs
and the T64 strength-before-boss / machine-before-rebirth coordinator are retained.
The paid loaders are unchanged.

The existing launch now mounts `RockBugHub_TEST_OrbitUI.lua` after the core and
before the current adaptive and boss UI patches. It moves existing content into
the new HUD before destroying the old visual shell. It retains the original
controls and callbacks. A failed construction restores the previous HUD.

The visual changes are rounded layered panels, a console that grows from the
selected card, a visible connection on wide screens, and a compact centered
console on narrow screens. Opening, closing, tab changes and pointer feedback
have short finite animations. Touch targets stop moving while a finger is held.
Loot reports have their own rounded, scrollable details popup. The full console
is capped at 364 by 424 pixels and shrinks for the available safe screen area.

The current StableFarmCards module remains the farm-caption writer. Its locks
are updated when changing groups so farm labels cannot overwrite other groups.
BossCompact's loot callback remains on the farm boss card; other groups' fourth
cards still open their own sections.

The HUD uses 43 beams and 39 shared attachments (84 total world descendants),
compared with 129 beams and 258 attachments (396 world descendants) in the pinned
T38 HUD. Panel layout uses one shared projection, capped at 30 updates/second;
there are no invisible per-panel world parts or continuously rotating effects.
Low FPS sustained for two seconds reduces decoration and layout frequency;
recovery requires five seconds of stable higher FPS. Hiding, ultra mode and chest
input stop HUD rendering. Finite animation can also be disabled with
`getgenv().RockBugHologramMotion=false` before launch.

Validation: 53 Luau scenarios pass: 38 lifecycle/native-input cases, 10 layout,
animation and performance-budget cases, and 5 integration/handoff cases using the
actual pinned T64 StableFarmCards and BossCompact sources. Both Lua files compile
with Luau 0.690. T64 bootstrap source outside the UI hook, version label and badge
placement guard is byte-identical. The fixtures' content bridge comes from the
same pinned core at `09719f8e7536f55acda625e8e18ae0ff44ce9cdb`.

Run: `python tests/orbit_ui/run.py --luau /path/to/luau`.

These are code and boundary-double checks, not a Roblox renderer or a device FPS
benchmark. Actual frame rate and appearance still need verification in Roblox.
The design follows the event-driven and reduced per-frame work guidance in
[Roblox's performance documentation](https://create.roblox.com/docs/performance-optimization/design).
