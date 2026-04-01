# v1.6.0 Upgrade Test Plan

Devnet topology: 1 RPC, 1 bootnode, 4 genesis validators (equal voting power), 2 test nodes (validator5/6)

## Test Environment

- **Baseline**: piplabs/story `v1.6.1` @ 4af80eb (release tag)
- **Previous baseline**: piplabs/story `release/1.6` @ 8307f9c
- **Test binary**: story-v161-devnet (v1.6.1 + InternalDevnetID)
- **Mock branch**: lucas2brh/story `test/mock-e6-release16` @ c2ae981
- **Regression GHA**: storyprotocol/story-devnet-aws `Regression Test` workflow (PR #17)
- **Last updated**: 2026-03-30

## Execution Status

### P0

| ID | Scenario | Status | Date | Baseline | Notes |
|----|----------|--------|------|----------|-------|
| S1 | planUpgrade + cosmovisor (disk fallback) | **PASS** | 2026-03-26 | 8307f9c | Regression GHA |
| S2 | Fresh genesis v1.6.0 chain (DKG from block 1) | **PASS** | 2026-03-26 | 8307f9c | v1.6.0 genesis + VE=1, DKG + VE from block 1, 4 validators, smoke |
| S3 | Node restart with stale upgrade-info.json | **PASS** | 2026-03-26 | 8307f9c | Regression GHA: SSM restart rpc1 |
| UT | Unit tests (UpgradeStoreLoader + DKG keeper) | **PASS** | 2026-03-23 | 0382ec7 | Not re-tested on 8307f9c |
| S6 | DKG module functional (params, events) | **PASS** | 2026-03-26 | 8307f9c | Regression GHA: VE log count (partial — no DKG params check) |
| S7 | Vote extensions (VoteExtensionsEnableHeight) | **PASS** | 2026-03-26 | 8307f9c | Regression GHA: num_votes=4 |
| Smoke | EVM sanity (transfer + contract + blocks) | **PASS** | 2026-03-26 | 8307f9c | Regression GHA |
| D1 | upgrade-info.json happy path | **PASS** | 2026-03-26 | 8307f9c | Covered by S1 |
| D2 | No upgrade-info.json (state sync) | **PASS** | 2026-03-26 | 8307f9c | Covered by D2-ss |
| D3 | Stale upgrade-info.json (restart) | **PASS** | 2026-03-26 | 8307f9c | Covered by S3 |
| D2-A | Full sync with cosmovisor binary swap | **PASS** | 2026-03-26 | 8307f9c | Regression GHA: validator6 wipe + cosmovisor full sync |
| D2-B | Full sync with v1.6.0 only | **SKIP** | 2026-03-26 | - | Devnet Horace=0, DKG store from genesis. Only valid on Aeneid/mainnet |
| D2-ss | CL state sync with v1.6.0 only | **PASS** | 2026-03-26 | 8307f9c | Manual GHA: DKG store in snapshot, no upgrade-info.json |
| F1 | Pending unbonding + redelegate across upgrade | **PASS** | 2026-03-30 | 4af80eb | P0 Reset GHA: unbonding_time=600s, stake+unstake → upgrade → balance verified |
| F2 | In-flight tx at upgrade height | **PASS** | 2026-03-26 | 8307f9c | Regression GHA: 5 wallets concurrent (self-transfer only) |

### P1

| ID | Scenario | Status | Date | Baseline | Notes |
|----|----------|--------|------|----------|-------|
| S5 | Rolling upgrade impossible | **PASS** | 2026-03-26 | 8307f9c | Manual GHA: grep MsgAddDkgVote in prouter.go |
| S9 | State integrity (validators, voting power) | **PASS** | 2026-03-26 | 8307f9c | Manual GHA: 4 validators equal power |
| D2-snap | EL snap sync post-upgrade | **PASS** | 2026-03-26 | 8307f9c | SSM geth SyncMode=snap, sync complete |
| E1 | Validator delayed restart (1/4 down 2min) | **PASS** | 2026-03-26 | 8307f9c | Manual GHA: chain continued + caught up + smoke |
| E2 | Crash during upgrade (cosmovisor recovery) | **PASS** | 2026-03-23 | 0382ec7 | Not re-tested on 8307f9c |
| E3 | Rollback past upgrade height | **PARTIAL** | 2026-03-24 | 0382ec7 | Cross-boundary too slow (IAVL) |
| E4d | cancelUpgrade leaves stale upgrade-info.json | **FINDING** | 2026-03-24 | 0382ec7 | Disk file not deleted on cancel |
| E6 | UBI distribution (mock A+B) | **PASS** | 2026-03-26 | 8307f9c | Mock A: settlement 10000. Mock B: 3 members per_member=1942541/block |
| F3 | Contract state survival (ERC20) | **PASS** | 2026-03-26 | 8307f9c | Manual GHA: forge deploy TestToken + verify name/supply/balance |
| F4 | EL-CL consistency (deploy + complex calls) | **PASS** | 2026-03-26 | 8307f9c | Manual GHA: transfer + approve + verify balanceOf + allowance |
| F5 | Block time regression | **PASS** | 2026-03-26 | 8307f9c | Regression GHA: 20s sample |
| F6 | Long-running stability (1h+) | - | | | pending |
| F7 | Historical RPC query (pre-upgrade block) | **PASS** | 2026-03-26 | 8307f9c | Regression GHA |
| F8 | Unequal voting power upgrade | - | | | pending |
| F11 | Hot-swap without planUpgrade | **FAIL** | 2026-03-26 | 8307f9c | Expected: version of store dkg mismatch, expected 210 got 0 |
| F13 | cosmovisor add-upgrade without planUpgrade | **PASS** | 2026-03-27 | 8307f9c | 131 blocks/5min, cosmovisor stayed on genesis, smoke OK |
| F14 | cosmovisor --upgrade-height crash + recovery | **PASS** | 2026-03-30 | v1.6.1 (4af80eb) | Crash at height 182: DKG store mismatch. Recovery: reset symlink + rm files → node resumed at 241 |
| F15 | Partial validator upgrade (2/4 → halt → recovery) | **PASS** | 2026-04-01 | 4af80eb | 2/4 halt@241, val3 → 3/4 recovered@259, val4 → 4/4 full recovery |
| F12 | Official binary on unknown chain ID | **CONFIRMED** | 2026-03-24 | 0382ec7 | panic: unknown chain ID |

### P2

| ID | Scenario | Status | Date | Notes |
|----|----------|--------|------|-------|
| E4 | Double planUpgrade (same name, pending) | **PASS** | 2026-03-26 | Re-verified on 8307f9c: invalid_request |
| E4b | planUpgrade after cancel | **PASS** | 2026-03-26 | Re-verified on 8307f9c: cancel → re-plan v1.6.0@77777 |
| E4c | planUpgrade already completed name | **FINDING** | 2026-03-26 | Re-verified on 8307f9c: evmengine accepts v1.6.0@99999 |
| E5 | planUpgrade at past height | **PASS** | 2026-03-26 | Re-verified on 8307f9c: silent reject |
| E8 | Sequential upgrades (v1.6.0 → v2.0.0) | - | | pending |
| E9 | cancelUpgrade before halt | **FINDING** | 2026-03-30 | 4af80eb | cancelUpgrade clears on-chain state but cosmovisor still switches at planned height via stale upgrade-info.json (#757) |
| F9 | Network partition during upgrade | - | | pending |
| F10 | Downgrade v1.6.0 → v1.5.3 | - | | pending |

## Score

**Latest regression (v1.6.1 @ 4af80eb)**: ALL PASS (GHA #23725827965, 9 nodes incl val5&6)
**Previous**: ff7d7d2 ALL PASS (#23635506361), b728ff2 ALL PASS (#23634152424)
**Tested on 8307f9c**: 19 PASS / 1 SKIP / 2 FINDING + F13 PASS
**Carried from 0382ec7**: 6 PASS / 2 FAIL (expected) / 1 FINDING / 1 PARTIAL
**Pending**: 5

## Known Limitations

| Issue | Impact |
|-------|--------|
| F3 only tests staking contract, not full ERC20 deploy | ERC20 state survival not verified on 8307f9c |
| F2 only does self-transfer | No contract interaction in load test |
| F5 sample is 20s (~9 blocks) | Statistically weak |
| S6 only checks VE log count | DKG params initialization not verified |
| D2-B invalid on devnet | Horace=0 means DKG store from genesis |

## Findings

| Finding | Impact | Fix |
|---------|--------|-----|
| UpgradeStoreLoader mountedStores bug | Blocks new stores at upgrade height | [#724](https://github.com/piplabs/story/pull/724) |
| Genesis v1.6.0 needs VE=1 | DKG non-functional without it | [devnet-aws#8](https://github.com/storyprotocol/story-devnet-aws/pull/8) |
| cancelUpgrade leaves stale upgrade-info.json | Cosmovisor looks for wrong binary on restart | Manual cleanup required |
| evmengine re-plan of completed name | Dirty pending state | Minor, SDK blocks execution |
| Unknown chain ID panics | Official binary unusable on custom chains | Propose: return empty map |
| v1.6.0 cannot single-binary full sync | New nodes need cosmovisor or state sync | Expected (new KVStore) |
| #727 compilation error (private field via interface) | dkg/dev branch broken | [#751](https://github.com/piplabs/story/pull/751) |
| dkg/dev CI has no go build check | Compilation errors not caught | [#750](https://github.com/piplabs/story/issues/750) |

## Test Execution Plan

### Step 1: Regression GHA (automated)

Covers: S1, S3, S6, S7, Smoke, D1, D3, F2, F5, F7, D2-A

```
gh workflow run "Regression Test" \
  -f environment=use1-devnet0 \
  -f upgrade_binary_s3_path=s3://story-devnet-binaries/binaries/story-release-1.6-8307f9c \
  -f upgrade_height_offset=50 \
  -f load_tx_count=50
```

### Step 2: Manual Tests GHA (after regression, same devnet)

Covers: D2-B (skip on devnet), S9, F3, S5, E1, D2-ss

```
gh workflow run "Manual Tests" \
  -f environment=use1-devnet0 \
  -f phase=all \
  -f upgrade_binary_s3_path=s3://story-devnet-binaries/binaries/story-release-1.6-8307f9c
```

### Step 3: Fresh genesis (separate reset)

Covers: S2

### Step 4: Long-running (background)

Covers: F6

### Step 5: Re-test with upgrade cycle (if needed)

Covers: E2, F11, F12, E4d, E6 — all PASS on previous baseline

### Step 6: P2 (if time permits)

E4, E4b, E4c, E5, E8, E9, F9, F10

## Upgrade Mechanism

v1.6.0 is a **binary-swap upgrade**:
```
planUpgrade("v1.6.0", H) on-chain
  → old binary halts at H, writes upgrade-info.json
  → cosmovisor reads it, switches to v1.6.0 binary
  → new binary reads upgrade-info.json → mounts DKG store
  → upgrade handler runs
```

**New node joining**: state sync (v1.6.0 only) or full sync (cosmovisor with v1.5.3 + v1.6.0).

## Deployment Notes

- Use `cosmovisor add-upgrade v1.6.0 <binary>` (no --upgrade-height)
- Deploy to all nodes: validators, rpc, bootnode, blockscout
- Fund executor account before planUpgrade
- Genesis v1.6.0 chains: set `vote_extensions_enable_height: "1"` in genesis.json
- After cancelUpgrade: manually delete `data/upgrade-info.json`

## TEE Limitation & Mock Plan

Devnet has no TEE (SGX). DKG functional tests (registration, dealing, finalization) cannot complete with real attestation.

**Mock branch**: `test/mock-dkg-settlement` on lucas2brh/story — seeds settlement balance + fake committee in upgrade handler.

**Blocked on**: Mock kernel server + modified DKG contract deployment.
