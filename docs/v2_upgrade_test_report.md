# v2.0.0 Upgrade Test Report — Devnet0

**Date**: 2026-03-20 ~ 2026-03-23
**Network**: internal-devnet-1 (devnet0)
**Binary (pre-#726)**: `story-dkg-dev-official-9ec3785-v1000`
**Binary (post-#726)**: `story-726-faa1e37`

## Test Results Summary

### Pre-#726 (hardcoded V200, fork-based)

| ID | Test | Status |
|----|------|--------|
| S1 | planUpgrade + cosmovisor | **PASS** |
| S2 | Fresh genesis chain with DKG | **PASS** |
| S3 | Node restart after upgrade | **PASS** |
| S4 | Fork hard-fork path | **PASS** |
| S6 | DKG module functional | **PASS** |
| S7 | Vote extensions working | **PASS** |
| S9 | State integrity | **PASS** |

### Post-#726 (binary-swap, disk fallback)

| ID | Test | Status |
|----|------|--------|
| UT | Unit tests (UpgradeStoreLoader 6/6 + DKG keeper) | **PASS** |
| S1-726 | planUpgrade + cosmovisor (disk fallback) | **PASS** |
| S2-726 | Fresh genesis v2.0.0 chain | **PASS** |
| S3-726 | Node restart after upgrade | **PASS** |
| S6-726 | DKG functional (genesis chain) | **PASS** |
| S7-726 | VE timing via consensus params | **PASS** |
| S5-726 | Rolling upgrade impossible | **PASS** |
| D2-A | New node full sync (cosmovisor swap) | **PASS** |
| D2-B | New node full sync (v2.0.0 only) | **FAIL (expected)** |
| S1-cosmovisor | Deploy via `cosmovisor add-upgrade` | **PASS** |
| Smoke | EVM sanity (every step) | **PASS** |
| D2-ss | State sync post-upgrade | pending |

---

## Pre-#726 Details

### S1: planUpgrade + Cosmovisor — PASS

**Date**: 2026-03-20 (original), 2026-03-23 (re-verified with #724 fix)
**Upgrade height**: 1000

Initial attempt failed due to UpgradeStoreLoader bug ([#722](https://github.com/piplabs/story/issues/722)) — `mountedStores` filter prevented DKG store from being added. Fixed by [#724](https://github.com/piplabs/story/pull/724).

Re-verified on 2026-03-23 with official #724 fix (`9ec3785`). Chain producing blocks, applied_plan at 1000, 4 validators, VE active.

### S2: Fresh Genesis — PASS

V200=200, fork triggered via `scheduleForkUpgrade`. DKG in module_versions before V200, VE from 201+.

### S3: Node Restart — PASS

Restarted rpc1 at height ~4500. No store mismatch, synced in ~30s.

### S6/S7/S9 — PASS

DKG params initialized, ExtendVote + VerifyVoteExtension from 201+, 4 validators equal power.

---

## Post-#726 Details

### What #726 Changed

| Area | Before | After |
|------|--------|-------|
| V200 height | Hardcoded per network | Read from `upgrade-info.json` |
| `isV200` guards | 6 places gating DKG/VE/UBI | Removed — all unconditional |
| `ProcessProposal` | `MsgAddDkgVote` optional before H+2 | Required from block 1 |
| Fork path for V200 | Active | Eliminated |
| Binary | Network-specific | Universal |

### S1-726: planUpgrade + Cosmovisor (Disk Fallback) — PASS

**Upgrade height**: 275

| Step | Result |
|------|--------|
| Network reset (v1.5.3 genesis) | [Workflow #23420177061](https://github.com/storyprotocol/story-devnet-aws/actions/runs/23420177061) — SUCCESS |
| Deploy to 7 nodes via `cosmovisor add-upgrade` | 7/7 SUCCESS |
| planUpgrade(275) | schedule `0xbbd998...` execute `0x4b81f7...` |
| Old binary halt at 275 | panic "UPGRADE v2.0.0 NEEDED" (expected) |
| Cosmovisor auto-switch | PASS |
| `/upgrade/applied_plan/v2.0.0` | height 275 |
| VE + DKG active | PASS |
| Smoke test | PASS |

Key: **No hardcoded V200.** `upgrade-info.json` drives store creation via `ReadUpgradeInfoFromDisk()`.

### S3-726: Node Restart — PASS

Restarted rpc1. Stale `upgrade-info.json` no interference (past height skipped). Height 349, caught up.

### S2-726: Fresh Genesis v2.0.0 — PASS

**First attempt**: VE=0 in genesis.json → DKG rounds never finalize ([#729](https://github.com/piplabs/story/issues/729), closed).
**Fix**: [devnet-aws#8](https://github.com/storyprotocol/story-devnet-aws/pull/8) — set VE=1.
**Re-test**: DKG + VE from block 1, 4 validators, smoke test PASS.

### S5-726: Rolling Upgrade Impossible — PASS (Code Analysis)

`ProcessProposal` (`prouter.go:76-79`) always requires `MsgAddDkgVote`. Old binary proposers don't include it → new validators reject → consensus breaks. Binary-swap only.

### D2-A: New Node Full Sync (Cosmovisor Swap) — PASS

**Node**: validator6 (wiped data, cosmovisor with v1.5.3 + v2.0.0)
**Upgrade height**: 412

v1.5.3 replayed blocks 1-411 → halt at 412 → `upgrade-info.json` auto-generated → cosmovisor switched to v2.0.0 → "applying upgrade v2.0.0" → synced to 858+. **No app hash mismatch.**

### D2-B: New Node Full Sync (v2.0.0 Only) — FAIL (Expected)

**Node**: validator5 (v2.0.0 as genesis binary, no v1.5.3)

App hash mismatch at early blocks:
```
Expected 379131F9..., got 7ED8F001...
```

**Root cause**: v2.0.0 mounts DKG KVStore from startup. Block 1 was committed by pre-v2.0.0 binary without DKG store → multistore hash differs. This is inherent to any upgrade adding a new KVStore — not a #726 bug. Previous upgrades (Terence, Horace) didn't add stores so single-binary sync worked.

**Operational implication**: New nodes MUST use cosmovisor with pre-upgrade + v2.0.0 binaries for full sync.

---

## Findings

| Finding | Impact | Fix |
|---------|--------|-----|
| UpgradeStoreLoader bug | Blocks new stores at upgrade height | [#724](https://github.com/piplabs/story/pull/724) |
| Genesis VE config required | DKG non-functional on genesis v2.0.0 chains | [devnet-aws#8](https://github.com/storyprotocol/story-devnet-aws/pull/8) |
| Single-binary full sync impossible | New nodes need cosmovisor + multi-binary | Expected (new KVStore) |
| install.sh chown missing | cosmovisor permission denied | [devnet-aws#7](https://github.com/storyprotocol/story-devnet-aws/pull/7) |
| evmengine re-plan of completed name | Minor — `SetPendingUpgrade` skips done check, SDK blocks at apply | No fix needed |

## planUpgrade Edge Case Tests (2026-03-23)

| ID | Test | Result |
|----|------|--------|
| E4 | Double plan (same name, pending) | **PASS** — rejected `pending_upgrade_exists` |
| E4b | Cancel → re-plan | **PASS** — cancel clears pending, re-plan succeeds |
| E4c | Plan already completed name | **FINDING** — evmengine accepts, creates pending; SDK would block at execution |
| E5 | Plan at past height | **PASS** — rejected on-chain |
| E2 | Crash during upgrade | **PASS** — cosmovisor recovered from crash-loop, handler too fast to kill mid-exec |
| E3 | Rollback + recovery | **PASS** — `story rollback` to 4640, restarted, caught up to 4684, no mismatch |

## E1: Validator Delayed Restart — PASS

**Date**: 2026-03-23
**Node**: validator4 (stopped for 2 min)

| Step | Result |
|------|--------|
| Pre-stop height | 3599 |
| Stop validator4 | OK |
| Chain continues (3/4 = 75%) | 3610→3613, producing |
| Validator4 down 2 min | Chain at 3649 |
| Restart validator4 | active, catching_up=false at 4216 |
| Smoke test | PASS |

## D2-ss: State Sync with v2.0.0 Only — PASS

**Date**: 2026-03-23
**Node**: validator5 (v2.0.0 as genesis binary, state sync from rpc1)
**Trust height**: 3000

| Check | Result |
|-------|--------|
| State sync completed | PASS (height 3165+) |
| upgrade-info.json | Not found (expected) |
| Single v2.0.0 binary | faa1e37 (#726) |
| No cosmovisor switch | current → genesis |
| catching_up | false |
| No app hash mismatch | PASS |

**State sync evidence** (logs from validator5 startup):

```
07:57:26  ABCI call: OfferSnapshot              — CometBFT found snapshot from peers
07:57:27  ABCI call: ApplySnapshotChunk         — applying snapshot data
07:57:27  restoring snapshot  store=acc
07:57:27  restoring snapshot  store=bank
07:57:27  restoring snapshot  store=consensus
07:57:27  restoring snapshot  store=distribution
07:57:27  restoring snapshot  store=dkg          ← DKG store restored from snapshot
07:57:27  restoring snapshot  store=evidence
07:57:27  restoring snapshot  store=evmengine
07:57:27  restoring snapshot  store=evmstaking
07:57:27  restoring snapshot  store=gov
07:57:27  restoring snapshot  store=mint
07:57:27  restoring snapshot  store=slashing
07:57:27  restoring snapshot  store=staking
07:57:27  restoring snapshot  store=upgrade
```

DKG store is included in the snapshot and restored directly — no upgrade handler, no
upgrade-info.json, no cosmovisor binary switch needed.

Confirms: **post-upgrade nodes can join via CL state sync using only v2.0.0 binary.**

Note: This tests CometBFT state sync (CL layer).

## D2-snap: EL Snap Sync Post-Upgrade — PASS

**Date**: 2026-03-23
**Node**: validator5 (geth SyncMode changed from "full" to "snap")

| Check | Result |
|-------|--------|
| Geth snap sync enabled | `Enabled snap sync  head=0 hash=8f1c33..edb7a2` |
| Snap sync completed | `Snap sync complete, auto disabling` synced=100.00% |
| eth_syncing | false |
| eth_blockNumber | 0xd8f (3471) |
| Imported chain segments | Continuous, no errors |

EL snap sync works independently of CL upgrade. Geth downloads EVM state trie
from peers without replaying historical blocks. DKG module (CL only) does not
affect geth state.

## Artifacts

| Item | Value |
|------|-------|
| Genesis binary | `s3://story-devnet-binaries/binaries/story-v1.5.3-dev` |
| Pre-#726 upgrade binary | `s3://story-devnet-binaries/binaries/story-dkg-dev-official-9ec3785-v1000` |
| Post-#726 binary | `s3://story-devnet-binaries/binaries/story-726-faa1e37` |
| S1-726 planUpgrade schedule | `0xbbd998332b4ccbcd0fbb380a62e6ebf15da3fbce869e728ec2e78eba43b974a3` |
| S1-726 planUpgrade execute | `0x4b81f788958ed83145483d8480cca33d4b1cfef4eb8f82c2bff8f23e0475a400` |
