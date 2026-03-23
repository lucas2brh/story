# v2.0.0 Upgrade Test Report — Devnet0

**Date**: 2026-03-20 ~ 2026-03-23
**Network**: internal-devnet-1 (devnet0)
**Result**: PASS (upgrade mechanism), issues found in PR #726 genesis path

## Summary

v2.0.0 upgrade (DKG module activation) was tested on devnet0 across multiple
scenarios: planUpgrade + cosmovisor, fresh genesis, node restart, and PR #726
binary-swap upgrade path.

## S1: planUpgrade + Cosmovisor Auto-Switch — PASS

**Date**: 2026-03-20 (original), 2026-03-23 (re-verified with #724 fix)
**Upgrade height**: 1000

### Timeline

| Time (UTC+8) | Event |
|---------------|-------|
| 16:00 | Confirmed devnet producing blocks (height ~226, 4 validators) |
| 16:05 | Set V200=1000, cross-compiled, uploaded to S3 |
| 16:10 | Deployed upgrade binary to 6 nodes (validator1-4, rpc1, bootnode1) |
| 16:15 | planUpgrade tx submitted (schedule + execute via TimelockController) |
| 16:30 | Chain reached height 1000, old binary panicked as expected |
| 16:30 | **FAILURE**: New binary crash-looped with DKG store mismatch error |
| 16:50 | Root cause identified, hotfix applied |
| 16:55 | Chain resumed at height 1001, upgrade applied |

### Bug: UpgradeStoreLoader Incorrectly Filters New Module Stores

**Error**: `failed to load latest version: version of store dkg mismatch root store's version; expected 999 got 0`

**Root Cause**: `mountedStores` filter in `UpgradeStoreLoader` confuses "store key registered in app" with "store has committed data on disk". New binary registers DKG at startup, filter sees it as "already mounted" and skips it from `StoreUpgrades.Added`.

**Fix**: [#724](https://github.com/piplabs/story/pull/724) — Remove `mountedStores` filter entirely.

### Verification Results

| Check | Result |
|-------|--------|
| Chain producing blocks after upgrade | height 1197, continuous |
| `/upgrade/applied_plan/v2.0.0` | height: 1000 |
| Active validators | 4 |
| Cosmovisor logs — no panic | `Processed DKG events` on every block |
| Vote extensions active | `VerifyVoteExtension` calls in logs |

### Artifacts

| Item | Value |
|------|-------|
| Genesis binary (old) | git_commit=c6c6be1, v1.5.3-stable (main branch) |
| Upgrade binary (new) | git_commit=dd43702, dkg/dev branch |
| S3 path | `s3://story-devnet-binaries/binaries/story-dkg-dev-dd43702-v1000-fix1` |
| planUpgrade schedule tx | `0xb2381e9f8d7033637774932f6ff508f7718eae972297410dd014e166b8ed8585` |
| planUpgrade execute tx | `0xc3311ff416c504a81626c584998360806ea607c6591f4350526996ef2d1d11c1` |

### S1 Re-verification: Official #724 Fix — PASS

**Date**: 2026-03-23
**Binary**: `story-dkg-dev-official-9ec3785-v1000` (dkg/dev HEAD, official #724 fix)

| Step | Result |
|------|--------|
| Network reset with main branch genesis | SUCCESS |
| SSM deploy to 6 nodes | All 6 SUCCESS |
| Fund executor + planUpgrade(1000) | schedule + execute SUCCESS |
| Old binary halt at height 1000 | panic "UPGRADE v2.0.0 NEEDED" (expected) |
| Cosmovisor auto-switch | New PID running |
| `/upgrade/applied_plan/v2.0.0` | height 1000 |
| Active validators | 4 |
| VerifyVoteExtension | Present from 1001+ |
| Smoke test | PASS |

---

## S3: Node Restart After Upgrade — PASS

**Date**: 2026-03-20
**Test node**: rpc1 (non-validator)

| Step | Result |
|------|--------|
| Record pre-restart height | 4517 |
| `systemctl restart cosmovisor` on rpc1 | OK |
| cosmovisor status after 30s | `active (running)` |
| Log grep for `store mismatch` / `panic` / `fatal` / `error` | None found |
| Node caught up to latest height | 5367 (synced in ~30s) |

---

## S2: Fresh Genesis Chain with DKG — PASS

**Date**: 2026-03-20
**Binary**: `story-dkg-genesis-dd43702` (dkg/dev branch, V200=200)

| Step | Result |
|------|--------|
| Chain producing blocks (genesis phase) | height 133, 4 validators |
| DKG in module_versions before V200 | Present (`dkg: 1` at height 197) |
| V200 fork triggered at height 200 | `/upgrade/applied_plan/v2.0.0` returns 200 |
| Vote extensions enabled after 200 | VerifyVoteExtension in logs from height 201+ |
| Chain stable after upgrade | height 239+, no errors |

---

## S4: Fork Hard-Fork Path — PASS

**Date**: 2026-03-20. Covered by S2.

---

## S6: DKG Module Functional — PASS

**Date**: 2026-03-20

| Check | Result |
|-------|--------|
| DKG params query | Returned initialized params (code=0) |
| `Processed DKG events` in validator logs | Present on every block (count=0, no TEE) |

---

## S7: Vote Extensions Enabled and Working — PASS

**Date**: 2026-03-20

| Check | Result |
|-------|--------|
| `ExtendVote` calls in validator logs | Present on every block from height 201+ |
| `VerifyVoteExtension` calls in logs | 3-4 per block |

---

## S9: State Integrity — PASS

**Date**: 2026-03-20

| Check | Result |
|-------|--------|
| Active validators | 4 |
| Voting power distribution | Equal (10000000000 each) |
| Connected peers | 8 |

---

## PR #726: Binary-Swap Upgrade Tests

**PR**: [#726](https://github.com/piplabs/story/pull/726)
**Binary**: `story-726-faa1e37` (commit `faa1e37` + InternalDevnetID config)

### Unit Tests — PASS

6/6 `TestUpgradeStoreLoader` tests passed.

### S1-726: planUpgrade + Cosmovisor (Disk Fallback) — PASS

**Date**: 2026-03-23
**Upgrade height**: 275 (no hardcoded V200)

| Step | Result |
|------|--------|
| Network reset (main genesis) | [Workflow #23420177061](https://github.com/storyprotocol/story-devnet-aws/actions/runs/23420177061) SUCCESS |
| Deploy to 7 nodes (incl blockscout) | 7/7 SUCCESS |
| Fund executor + planUpgrade(275) | schedule `0xbbd998...` execute `0x4b81f7...` |
| Old binary halt at 275 | panic "UPGRADE v2.0.0 NEEDED" (expected) |
| Cosmovisor auto-switch | New PID running |
| `/upgrade/applied_plan/v2.0.0` | height 275 |
| 4 validators active | PASS |
| VerifyVoteExtension from 276+ | PASS |
| No store mismatch / panic | PASS |
| Smoke test | PASS |

Key validation: **No hardcoded V200 in binary.** `upgrade-info.json` written by old binary at halt, read by new binary via `ReadUpgradeInfoFromDisk()` to register DKG store.

### S3-726: Node Restart After Upgrade — PASS

**Date**: 2026-03-23

| Step | Result |
|------|--------|
| Restart rpc1 | cosmovisor active |
| Stale upgrade-info.json | No interference |
| Node height | 349, caught up |
| Smoke test | PASS |

### S2-726: Fresh Genesis v2.0.0 Chain — PARTIAL PASS

**Date**: 2026-03-23
**Method**: Network reset with `story-726-faa1e37` as genesis binary

| Step | Result |
|------|--------|
| Chain producing blocks from height 1 | PASS (height 570+) |
| DKG BeginBlocker from block 1 | PASS (round 86+ at height 341) |
| 4 validators active | PASS |
| Smoke test | PASS |
| VoteExtensionsEnableHeight | **FAIL** — value is 0, VE never enabled |
| DKG round finalization | **FAIL** — rounds initiate but never finalize |

### Finding & Fix: Genesis v2.0.0 VoteExtensions Not Enabled

**Issue**: [#729](https://github.com/piplabs/story/issues/729)
**Fix**: [devnet-aws#8](https://github.com/storyprotocol/story-devnet-aws/pull/8)

Initial S2-726 test showed `VoteExtensionsEnableHeight=0` — VE never enabled on
genesis chain because upgrade handler (which calls `enableVoteExtensions`) doesn't
run on genesis chains.

**Root cause**: Not a code bug. Genesis config issue — `vote_extensions_enable_height`
was `"0"` (disabled) in `genesis-node.json`. Changed to `"1"` to enable from block 1.

**Re-test result (2026-03-23)**: After merging devnet-aws#8 and network-reset:
- ExtendVote + VerifyVoteExtension present from block 1
- DKG rounds initiating with VE data available
- Smoke test PASS

**Takeaway**: Any new chain with v2.0.0 genesis binary must set
`vote_extensions_enable_height: "1"` in genesis.json.

### D2: No upgrade-info.json (Validator5) — PARTIAL PASS

**Date**: 2026-03-23

Validator5 running #726 binary on genesis chain, no upgrade-info.json exists.
Node at height 390, `catching_up: false`, fully synced. Binary starts normally
without disk fallback (genesis path: `lastVersion==0` early return).

Partial because this only covers genesis scenario. Full D2 (state sync into
post-upgrade network) needs S1-726 devnet which was overwritten by S2-726.

### S5-726: Rolling Upgrade Impossible — PASS (Code Analysis)

**Date**: 2026-03-23

`ProcessProposal` (`client/app/prouter.go:76-79`) unconditionally requires
exactly 1 `MsgAddDkgVote` in every proposal. Old binary proposers don't include
this message → new binary validators reject → consensus cannot be reached with
mixed binaries. Confirms binary-swap is the only upgrade path.

### DKG Keeper Unit Tests — PASS

**Date**: 2026-03-23

All tests passed: `go test ./client/x/dkg/keeper/... -v -count=1`

---

## Code Changes (story repo, uncommitted)

1. `lib/netconf/chains.go` — Added `InternalDevnetID`
2. `lib/netconf/upgrades.go` — Added `InternalDevnetID` to `UpgradeHistories` (V200=1000 on dkg/dev, no V200 on #726 branch)
3. `client/app/upgrades.go` — Using upstream #724 version
4. `scripts/devnet-plan-upgrade.sh` — planUpgrade via TimelockController
5. `scripts/devnet-smoke-test.sh` — Post-test sanity check (transfer + contract call + block production)
