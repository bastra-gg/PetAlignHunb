# RockBug Boss 1.9 — startup repair

Only the Boss product changes. `RockBugBoss.lua` is now a compatibility launcher
for `RockBugBossAutoCollect.lua`, so both existing URLs run the same maintained
native Luau implementation. The six-variant delivery service and all other
products are unchanged.

The old Boss launcher still downloaded the legacy VM after AutoCollect had
already switched to the lightweight key gate. The old VM failed to resolve
`game:IsLoaded()` in an isolated executor-environment test; the native runtime
mounted its UI and key gate in the same boundary fixture. This test reproduces
environment loss, not every Roblox executor's behavior.

The launcher now validates downloaded source, supports executor HTTP fallback,
shows download failures, and reports a download that exceeds 25 seconds. Startup
reports missing game/LocalPlayer/PlayerGui instead of waiting silently forever.
Key checks use the existing server and credentials unchanged. HTTP key requests
have a 15-second client wait bound, so a stalled executor request no longer locks
the login UI indefinitely. A remembered key is checked on every new startup.

No authorization is granted by these timeouts or fallback paths. Unavailable,
invalid, expired, bound, or revoked keys still fail closed. Native client code is
not tamper-proof DRM; server validation remains the access gate requested for
the lightweight version.

Validation uses official Luau CLI 0.742:

```
luau-compile --null RockBugBoss.lua RockBugBossAutoCollect.lua
python3 tests/boss_startup/run.py --luau /path/to/luau
```

The suite runs the actual complete source with mocked Roblox/network boundaries:
UI startup, unauthorized start, valid/invalid response, saved-key revalidation,
hanging network timeout and retry, both public entry points, transport fallback,
error-page rejection, and runtime cleanup. It performs no real game actions or
license mutations. A live Roblox/executor/device run was not available.
