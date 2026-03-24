# v2.0.0 Upgrade Test Plan

Devnet topology: 1 RPC, 1 bootnode, 4 genesis validators (equal voting power), 2 test nodes (validator5/6)

## Execution Status

### Upgrade Mechanism

| ID | Scenario | Priority | Status | Date | Notes |
|----|----------|----------|--------|------|-------|
| S1 | planUpgrade + cosmovisor (disk fallback) | P0 | **PASS** | 2026-03-23 | Height 275, no hardcoded V200 |
| S2 | Fresh genesis v2.0.0 chain (DKG from block 1) | P0 | **PASS** | 2026-03-23 | Requires genesis VE=1 |
| S3 | Node restart with stale upgrade-info.json | P0 | **PASS** | 2026-03-23 | No interference |
| S5 | Rolling upgrade impossible | P1 | **PASS** | 2026-03-23 | ProcessProposal rejects old proposals |
| UT | Unit tests (UpgradeStoreLoader + DKG keeper) | P0 | **PASS** | 2026-03-23 | 6/6 + keeper tests |

### Functional

| ID | Scenario | Priority | Status | Date | Notes |
|----|----------|----------|--------|------|-------|
| S6 | DKG module functional (params, events) | P0 | **PASS** | 2026-03-23 | BeginBlocker from block 1 |
| S7 | Vote extensions (VoteExtensionsEnableHeight) | P0 | **PASS** | 2026-03-23 | ExtendVote + VerifyVoteExtension |
| S9 | State integrity (validators, voting power) | P1 | **PASS** | 2026-03-20 | 4 validators, equal power |
| Smoke | EVM sanity (transfer + contract + blocks) | P0 | **PASS** | 2026-03-23 | Every test step |

### Node Join

| ID | Scenario | Priority | Status | Date | Notes |
|----|----------|----------|--------|------|-------|
| D2-A | Full sync with cosmovisor binary swap | P0 | **PASS** | 2026-03-23 | val6: no app hash mismatch |
| D2-B | Full sync with v2.0.0 only | P0 | **FAIL** | 2026-03-23 | Expected: DKG store changes multistore hash |
| D2-ss | CL state sync with v2.0.0 only | P0 | **PASS** | 2026-03-23 | DKG store restored from snapshot |
| D2-snap | EL snap sync post-upgrade | P1 | **PASS** | 2026-03-23 | geth snap sync complete |

### Disk Fallback

| ID | Scenario | Priority | Status | Notes |
|----|----------|----------|--------|-------|
| D1 | upgrade-info.json happy path | P0 | **PASS** | Covered by S1 |
| D2 | No upgrade-info.json (state sync) | P0 | **PASS** | Covered by D2-ss |
| D3 | Stale upgrade-info.json (restart) | P0 | **PASS** | Covered by S3 |

### Operational

| ID | Scenario | Priority | Status | Date | Notes |
|----|----------|----------|--------|------|-------|
| E1 | Validator delayed restart (1/4 down 2min) | P1 | **PASS** | 2026-03-23 | 3/4 continued, val4 caught up |
| E2 | Crash during upgrade (cosmovisor recovery) | P1 | **PASS** | 2026-03-23 | Handler too fast to kill mid-exec |
| E3 | Rollback past upgrade height | P1 | **PARTIAL** | 2026-03-24 | Post-upgrade 5-block rollback works; cross-boundary too slow (IAVL) |
| F11 | Hot-swap without planUpgrade | P1 | **FAIL** | 2026-03-24 | Expected: DKG store mismatch crash |
| F12 | Official binary on unknown chain ID | P1 | **CONFIRMED** | 2026-03-24 | panic: unknown chain ID |
| E4d | cancelUpgrade leaves stale upgrade-info.json | P1 | **FINDING** | 2026-03-24 | Disk file not deleted on cancel |

### planUpgrade Edge Cases

| ID | Scenario | Priority | Status | Date | Notes |
|----|----------|----------|--------|------|-------|
| E4 | Double planUpgrade (same name, pending) | P2 | **PASS** | 2026-03-23 | Rejected: pending_upgrade_exists |
| E4b | planUpgrade after cancel | P2 | **PASS** | 2026-03-23 | cancel → re-plan succeeds |
| E4c | planUpgrade already completed name | P2 | **FINDING** | 2026-03-23 | evmengine allows, SDK blocks at execution |
| E5 | planUpgrade at past height | P2 | **PASS** | 2026-03-23 | Rejected on-chain |

### Real-Chain Simulation

| ID | Scenario | Priority | Status | Date | Notes |
|----|----------|----------|--------|------|-------|
| F1 | Pending unbonding across upgrade | P0 | - | | Unbonding period too long for devnet |
| F2 | In-flight tx at upgrade height | P0 | **PASS** | 2026-03-24 | 200 tx across upgrade, all successful |
| F3 | Contract state survival (ERC20) | P1 | **PASS** | 2026-03-24 | name/supply/balance intact |
| F4 | EL-CL consistency (deploy + complex calls) | P1 | **PASS** | 2026-03-24 | deploy + transfer + approve + transferFrom |
| F5 | Block time regression | P1 | **PASS** | 2026-03-24 | 2.2s/block unchanged |
| F6 | Long-running stability (1h+) | P1 | - | | pending |
| F7 | Historical RPC query (pre-upgrade block) | P1 | **PASS** | 2026-03-24 | Balance matches |
| F8 | Unequal voting power upgrade | P1 | - | | pending |

### Pending (P2)

| ID | Scenario | Priority | Status | Notes |
|----|----------|----------|--------|-------|
| E6 | UBI distribution pre/post (needs TEE) | P2 | - | DKG settlement + reward |
| E8 | Sequential upgrades (v2.0.0 → v3.0.0) | P2 | - | Multi-upgrade disk fallback |
| E9 | cancelUpgrade before halt | P2 | - | Nodes don't halt after cancel |
| F9 | Network partition during upgrade | P2 | - | 2/4 halt at different times |
| F10 | Downgrade v2.0.0 → v1.5.3 | P2 | - | Emergency rollback |

## Score

**24 PASS / 2 FAIL (expected) / 3 FINDING / 1 PARTIAL / 8 pending**

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
- Set planUpgrade height = current + 200 (~7 min buffer)
- Fund executor account before planUpgrade
- Genesis v2.0.0 chains: set `vote_extensions_enable_height: "1"` in genesis.json
- After cancelUpgrade: manually delete `data/upgrade-info.json`

## TEE Limitation

Devnet has no TEE (SGX). DKG functional tests (registration, dealing, finalization) cannot complete. Upgrade mechanism tests work normally.
