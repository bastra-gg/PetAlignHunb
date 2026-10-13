# Boss 1.10 license gate

Only RockBugBoss.lua and RockBugBossAutoCollect.lua are changed at runtime.
The license decision uses a finite four-instruction interpreter on server replies.
Combat, movement, UI and reward collection remain native Luau.

Authorization lives in a lexical closure with a 180-second lease, renewed by the
existing 60-second server check. Public authorized/lastKeyCheck fields are only
informational. Direct boss starts, ongoing attacks, training and rewards check the
private lease. Revocation and Destroy invalidate it. Transient request failures
cannot extend it. The server must return boolean ok=true and the current UserId.

This is a lightweight client gate, not source confidentiality or tamper-proof DRM.
A person controlling the executor can edit client code or intercept responses.
The existing public source and Git history remain readable. No anti-debug loops,
full-game interpreter, additional network endpoints or backend changes are added.

Validation: Luau compilation, actual-source startup fixtures, strict response and
account checks, public-flag bypass attempts, cached-key revalidation, lease expiry,
request timeout/retry and both loader paths. license.spec.luau benchmarks the
bounded validation and native guard on the host; it is not a Roblox FPS test.

Run: python3 tests/boss_startup/run.py --luau /path/to/luau
