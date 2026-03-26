# Test Progress (live state)

## Current
- **Date**: 2026-03-26
- **Baseline**: release/1.6 @ 8307f9c
- **Devnet**: post-upgrade, running with mock binary, height ~600

## Today's completed
- E6: UBI distribution (mock A+B) — PASS. Upgrade at height 229. Mock A: settlement 10000 claimed. Mock B: 3 members per_member=1942541/block.
- E5: planUpgrade at past height — PASS. Silent reject on release/1.6.
- E4c: planUpgrade already completed name — FINDING confirmed. evmengine accepts v1.6.0@99999.
- E4: Double planUpgrade — PASS. Rejected: invalid_request.
- E4b: planUpgrade after cancel — PASS. cancel → re-plan v1.6.0@77777 succeeded.

## Next
- F11 (hot-swap without planUpgrade) — needs reset + non-mock binary
- E4d (cancelUpgrade stale file) — re-verify on release/1.6
- F6, F8 — pending P1 tests
- E8, E9, F9, F10 — pending P2 tests
