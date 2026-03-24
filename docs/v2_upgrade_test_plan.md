# v2.0.0 Upgrade Test Plan

Devnet topology: 1 RPC, 1 bootnode, 4 genesis validators (equal voting power), 2 test nodes (validator5/6)

## Test Environment

- **Baseline**: piplabs/story `dkg/dev` @ 0382ec7
- **Test binary**: lucas2brh/story `dkg/dev` @ 97ca7a8 (baseline + InternalDevnetID + test docs)
- **Mock branch**: lucas2brh/story `test/mock-dkg-settlement` @ 98dee1c
- **Devnet genesis**: storyprotocol/story-devnet-aws `qa/f1-unbonding-test` (unbonding_time=600s)
- **Last updated**: 2026-03-24

## Execution Status

### P0

| ID | Scenario | Status | Date | Notes |
|----|----------|--------|------|-------|
| S1 | planUpgrade + cosmovisor (disk fallback) | **PASS** | 2026-03-23 | Height 275, no hardcoded V200 |
| S2 | Fresh genesis v2.0.0 chain (DKG from block 1) | **PASS** | 2026-03-23 | Requires genesis VE=1 |
| S3 | Node restart with stale upgrade-info.json | **PASS** | 2026-03-23 | No interference |
| UT | Unit tests (UpgradeStoreLoader + DKG keeper) | **PASS** | 2026-03-23 | 6/6 + keeper tests |
| S6 | DKG module functional (params, events) | **PASS** | 2026-03-23 | BeginBlocker from block 1 |
| S7 | Vote extensions (VoteExtensionsEnableHeight) | **PASS** | 2026-03-23 | ExtendVote + VerifyVoteExtension |
| Smoke | EVM sanity (transfer + contract + blocks) | **PASS** | 2026-03-23 | Every test step |
| D1 | upgrade-info.json happy path | **PASS** | 2026-03-23 | Covered by S1 |
| D2 | No upgrade-info.json (state sync) | **PASS** | 2026-03-23 | Covered by D2-ss |
| D3 | Stale upgrade-info.json (restart) | **PASS** | 2026-03-23 | Covered by S3 |
| D2-A | Full sync with cosmovisor binary swap | **PASS** | 2026-03-23 | val6: no app hash mismatch |
| D2-B | Full sync with v2.0.0 only | **FAIL** | 2026-03-23 | Expected: DKG store changes multistore hash |
| D2-ss | CL state sync with v2.0.0 only | **PASS** | 2026-03-23 | DKG store restored from snapshot |
| F1 | Pending unbonding across upgrade | **PASS** | 2026-03-24 | unbonding_time=600s, unstake@349 upgrade@486 completed@610 |
| F2 | In-flight tx at upgrade height | **PASS** | 2026-03-24 | 200 tx across upgrade, all successful |

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
| E6 | UBI distribution (mock A+B) | **PASS** | 2026-03-24 | Mock A: ClaimSettlementBalance 10000. Mock B: DistributeRewardsToActiveCommittee 3 members per_member=3885125/block. Requires UBI rate > 0 (setUBIPercentage via TimelockController). |
| F3 | Contract state survival (ERC20) | **PASS** | 2026-03-24 | name/supply/balance intact |
| F4 | EL-CL consistency (deploy + complex calls) | **PASS** | 2026-03-24 | deploy + transfer + approve + transferFrom |
| F5 | Block time regression | **PASS** | 2026-03-24 | 2.2s/block unchanged |
| F6 | Long-running stability (1h+) | - | | pending |
| F7 | Historical RPC query (pre-upgrade block) | **PASS** | 2026-03-24 | Balance matches |
| F8 | Unequal voting power upgrade | - | | pending |
| F11 | Hot-swap without planUpgrade | **FAIL** | 2026-03-24 | Expected: DKG store mismatch crash |
| F12 | Official binary on unknown chain ID | **CONFIRMED** | 2026-03-24 | panic: unknown chain ID |

### P2

| ID | Scenario | Status | Date | Notes |
|----|----------|--------|------|-------|
| E4 | Double planUpgrade (same name, pending) | **PASS** | 2026-03-23 | Rejected: pending_upgrade_exists |
| E4b | planUpgrade after cancel | **PASS** | 2026-03-23 | cancel → re-plan succeeds |
| E4c | planUpgrade already completed name | **FINDING** | 2026-03-23 | evmengine allows, SDK blocks at execution |
| E5 | planUpgrade at past height | **PASS** | 2026-03-23 | Rejected on-chain |
| E8 | Sequential upgrades (v2.0.0 → v3.0.0) | - | | Multi-upgrade disk fallback |
| E9 | cancelUpgrade before halt | - | | Nodes don't halt after cancel |
| F9 | Network partition during upgrade | - | | 2/4 halt at different times |
| F10 | Downgrade v2.0.0 → v1.5.3 | - | | Emergency rollback |

## Score

**25 PASS / 2 FAIL (expected) / 3 FINDING / 1 PARTIAL / 5 pending**

## Findings

| Finding | Impact | Fix |
|---------|--------|-----|
| UpgradeStoreLoader mountedStores bug | Blocks new stores at upgrade height | [#724](https://github.com/piplabs/story/pull/724) |
| Genesis v2.0.0 needs VE=1 | DKG non-functional without it | [devnet-aws#8](https://github.com/storyprotocol/story-devnet-aws/pull/8) |
| cancelUpgrade leaves stale upgrade-info.json | Cosmovisor looks for wrong binary on restart | Manual cleanup required |
| evmengine re-plan of completed name | Dirty pending state | Minor, SDK blocks execution |
| Unknown chain ID panics | Official binary unusable on custom chains | Propose: return empty map |
| v2.0.0 cannot single-binary full sync | New nodes need cosmovisor or state sync | Expected (new KVStore) |

## Standard Post-Test Sanity Check

Every test must end with `scripts/devnet-smoke-test.sh`:
1. Token transfer (0.01 IP)
2. Contract call (IPTokenStaking.minStakeAmount)
3. Block production (height increases over 3s)

## TX Load Testing

Run `scripts/devnet-tx-load.sh` during upgrade tests to simulate real traffic.
Forge script: 5 independent wallets, 200 tx (ETH + ERC20 transfers).

## Upgrade Mechanism

v2.0.0 is a **binary-swap upgrade**:
```
planUpgrade("v2.0.0", H) on-chain
  → old binary halts at H, writes upgrade-info.json
  → cosmovisor reads it, switches to v2.0.0 binary
  → new binary reads upgrade-info.json → mounts DKG store
  → upgrade handler runs
```

**New node joining**: state sync (v2.0.0 only) or full sync (cosmovisor with pre-upgrade + v2.0.0).

## Deployment Notes

- Use `cosmovisor add-upgrade v2.0.0 <binary>` (no --upgrade-height)
- Deploy to 7 nodes: validator1-4, rpc1, bootnode1, blockscout
- Set planUpgrade height = current + 50 (no pre-upgrade setup) or + 200 (with setup)
- Fund executor account before planUpgrade
- Genesis v2.0.0 chains: set `vote_extensions_enable_height: "1"` in genesis.json
- After cancelUpgrade: manually delete `data/upgrade-info.json`

## TEE Limitation & Mock Plan

Devnet has no TEE (SGX). DKG functional tests (registration, dealing, finalization) cannot complete with real attestation.

**Mock approach**: Deploy modified DKG.sol with `authenticateEnclaveReport()` returning true unconditionally. This allows:
- Mock kernel server to register validators without real SGX enclave
- DKG rounds to complete (dealing, response, finalization)
- Non-zero settlement balance → validates `ProcessUbiWithdrawal` full path
- Active committee → validates `DistributeRewardsToActiveCommittee` with real distribution

**Steps**:
1. Modify `contracts/src/protocol/DKG.sol` — bypass attestation check
2. Deploy modified contract to devnet (via upgrade or redeploy)
3. Run mock kernel gRPC server on each validator
4. Verify DKG round completes → settlement balance > 0
5. Verify UBI distribution includes DKG rewards (F1/E6)
6. Coordinate with Hans for mock kernel implementation

**Blocked on**: Mock kernel server + modified DKG contract deployment. Track with dev team.
