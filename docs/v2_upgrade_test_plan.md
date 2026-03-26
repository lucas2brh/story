# v1.6.0 Upgrade Test Plan

Devnet topology: 1 RPC, 1 bootnode, 4 genesis validators (equal voting power), 2 test nodes (validator5/6)

## Test Environment

- **Baseline**: piplabs/story `release/1.6` @ 8307f9c
- **Test binary**: lucas2brh/story `release/1.6-test` @ 8307f9c (baseline + InternalDevnetID)
- **Mock branch**: lucas2brh/story `test/mock-dkg-settlement` @ 98dee1c
- **Regression GHA**: storyprotocol/story-devnet-aws `Regression Test` workflow (PR #13)
- **Manual tests**: storyprotocol/story-devnet-aws `scripts/devnet-manual-tests.sh`
- **Last updated**: 2026-03-26

## Execution Status

### P0

| ID | Scenario | Status | Date | Notes |
|----|----------|--------|------|-------|
| S1 | planUpgrade + cosmovisor (disk fallback) | **PASS** | 2026-03-25 | GHA regression (795dc17) |
| S2 | Fresh genesis v1.6.0 chain (DKG from block 1) | **PASS** | 2026-03-23 | Requires genesis VE=1 |
| S3 | Node restart with stale upgrade-info.json | **PASS** | 2026-03-23 | No interference |
| UT | Unit tests (UpgradeStoreLoader + DKG keeper) | **PASS** | 2026-03-23 | 6/6 + keeper tests |
| S6 | DKG module functional (params, events) | **PASS** | 2026-03-23 | BeginBlocker from block 1 |
| S7 | Vote extensions (VoteExtensionsEnableHeight) | **PASS** | 2026-03-23 | ExtendVote + VerifyVoteExtension |
| Smoke | EVM sanity (transfer + contract + blocks) | **PASS** | 2026-03-25 | GHA regression (795dc17) |
| D1 | upgrade-info.json happy path | **PASS** | 2026-03-23 | Covered by S1 |
| D2 | No upgrade-info.json (state sync) | **PASS** | 2026-03-23 | Covered by D2-ss |
| D3 | Stale upgrade-info.json (restart) | **PASS** | 2026-03-23 | Covered by S3 |
| D2-A | Full sync with cosmovisor binary swap | **PASS** | 2026-03-23 | val6: no app hash mismatch |
| D2-B | Full sync with v1.6.0 only | **FAIL** | 2026-03-23 | Expected: DKG store changes multistore hash |
| D2-ss | CL state sync with v1.6.0 only | **PASS** | 2026-03-23 | DKG store restored from snapshot |
| F1 | Pending unbonding across upgrade | **PASS** | 2026-03-24 | unbonding_time=600s, unstake@349 upgrade@486 completed@610 |
| F2 | In-flight tx at upgrade height | **PASS** | 2026-03-25 | GHA regression: 5 wallets concurrent across upgrade boundary |

### P1

| ID | Scenario | Status | Date | Notes |
|----|----------|--------|------|-------|
| S5 | Rolling upgrade impossible | **PASS** | 2026-03-23 | ProcessProposal rejects old proposals |
| S9 | State integrity (validators, voting power) | **PASS** | 2026-03-20 | 4 validators, equal power |
| D2-snap | EL snap sync post-upgrade | **PASS** | 2026-03-23 | geth snap sync complete |
| E1 | Validator delayed restart (1/4 down 2min) | **PASS** | 2026-03-23 | 3/4 continued, val4 caught up |
| E2 | Crash during upgrade (cosmovisor recovery) | **PASS** | 2026-03-23 | Handler too fast to kill mid-exec |
| E3 | Rollback past upgrade height | **PARTIAL** | 2026-03-24 | Post-upgrade 5-block rollback works; cross-boundary too slow (IAVL) |
| E4d | cancelUpgrade leaves stale upgrade-info.json | **FINDING** | 2026-03-24 | Disk file not deleted on cancel |
| E6 | UBI distribution (mock A+B) | **PASS** | 2026-03-26 | Re-verified on release/1.6 baseline. Mock A: settlement 10000. Mock B: 3 members per_member=1942541/block. |
| F3 | Contract state survival (ERC20) | **PASS** | 2026-03-24 | name/supply/balance intact |
| F4 | EL-CL consistency (deploy + complex calls) | **PASS** | 2026-03-24 | deploy + transfer + approve + transferFrom |
| F5 | Block time regression | **PASS** | 2026-03-25 | GHA regression (795dc17) |
| F6 | Long-running stability (1h+) | - | | pending |
| F7 | Historical RPC query (pre-upgrade block) | **PASS** | 2026-03-25 | GHA regression (795dc17) |
| F8 | Unequal voting power upgrade | - | | pending |
| F11 | Hot-swap without planUpgrade | **FAIL** | 2026-03-24 | Expected: DKG store mismatch crash |
| F12 | Official binary on unknown chain ID | **CONFIRMED** | 2026-03-24 | panic: unknown chain ID |

### P2

| ID | Scenario | Status | Date | Notes |
|----|----------|--------|------|-------|
| E4 | Double planUpgrade (same name, pending) | **PASS** | 2026-03-26 | Re-verified on release/1.6: invalid_request |
| E4b | planUpgrade after cancel | **PASS** | 2026-03-26 | Re-verified on release/1.6: cancel → re-plan v1.6.0@77777 |
| E4c | planUpgrade already completed name | **FINDING** | 2026-03-26 | Re-verified on release/1.6: evmengine accepts v1.6.0@99999 |
| E5 | planUpgrade at past height | **PASS** | 2026-03-26 | Re-verified on release/1.6: silent reject (no log) |
| E8 | Sequential upgrades (v1.6.0 → v2.0.0) | - | | Multi-upgrade disk fallback |
| E9 | cancelUpgrade before halt | - | | Nodes don't halt after cancel |
| F9 | Network partition during upgrade | - | | 2/4 halt at different times |
| F10 | Downgrade v1.6.0 → v1.5.3 | - | | Emergency rollback |

## Score

**25 PASS / 2 FAIL (expected) / 3 FINDING / 1 PARTIAL / 5 pending**

## Findings

| Finding | Impact | Fix |
|---------|--------|-----|
| UpgradeStoreLoader mountedStores bug | Blocks new stores at upgrade height | [#724](https://github.com/piplabs/story/pull/724) |
| Genesis v1.6.0 needs VE=1 | DKG non-functional without it | [devnet-aws#8](https://github.com/storyprotocol/story-devnet-aws/pull/8) |
| cancelUpgrade leaves stale upgrade-info.json | Cosmovisor looks for wrong binary on restart | [#757](https://github.com/piplabs/story/issues/757) |
| evmengine re-plan of completed name | Dirty pending state | Minor, SDK blocks execution |
| Unknown chain ID panics | Official binary unusable on custom chains | Propose: return empty map |
| v1.6.0 cannot single-binary full sync | New nodes need cosmovisor or state sync | Expected (new KVStore) |
| #727 compilation error (private field via interface) | dkg/dev branch broken | [#751](https://github.com/piplabs/story/pull/751) |
| dkg/dev CI has no go build check | Compilation errors not caught | Reported in [#750](https://github.com/piplabs/story/issues/750) |

## Test Execution Plan

### Step 1: Regression GHA (automated)

Covers: S1, S3, S6, S7, Smoke, D1, D3, F2 (5 wallets), F5, F7, D2-A, D2-ss

```
gh workflow run "Regression Test" --ref qa/regression-loadtest \
  -f environment=use1-devnet0 \
  -f upgrade_binary_s3_path=s3://story-devnet-binaries/binaries/story-release-1.6-8307f9c \
  -f upgrade_height_offset=50 \
  -f load_tx_count=50
```

### Step 2: Manual script (after regression passes, same devnet)

Covers: UT, D2-B, S9, F3, F4, S5, E1

```
DEVNET_PROPOSER_KEY=0x... ./scripts/devnet-manual-tests.sh all
```

### Step 3: Fresh genesis (separate reset)

Covers: S2

Network reset with v1.6.0 as genesis binary, verify DKG + VE from block 1.

### Step 4: Long-running (background)

Covers: F6

Let devnet run 1h+, check block production periodically.

### Step 5: Re-test with upgrade cycle (if needed)

Covers: E2, F11, F12, E4d, E6

These were all PASS on previous baseline. Re-test only if code changes affect upgrade logic.

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
- Deploy to 7 nodes: validator1-4, rpc1, bootnode1, blockscout
- Fund executor account before planUpgrade
- Genesis v1.6.0 chains: set `vote_extensions_enable_height: "1"` in genesis.json
- After cancelUpgrade: manually delete `data/upgrade-info.json`

## TEE Limitation & Mock Plan

Devnet has no TEE (SGX). DKG functional tests (registration, dealing, finalization) cannot complete with real attestation.

**Mock approach**: Deploy modified DKG.sol with `authenticateEnclaveReport()` returning true unconditionally.

**Mock branch**: `test/mock-dkg-settlement` on lucas2brh/story — seeds settlement balance + fake committee in upgrade handler.

**Blocked on**: Mock kernel server + modified DKG contract deployment. Track with dev team.
