# v2.0.0 Upgrade Test Plan

Devnet topology: 1 RPC, 1 bootnode, 4 genesis validators (equal voting power), 2 test nodes (validator5/6)

## Execution Status

### Pre-#726 Tests (hardcoded V200)

| ID | Scenario | Priority | Status | Date | Notes |
|----|----------|----------|--------|------|-------|
| S1 | planUpgrade + cosmovisor auto-switch | P0 | **PASS** | 2026-03-23 | Re-verified with official #724 fix (9ec3785) |
| S2 | Fresh genesis chain with DKG | P0 | **PASS** | 2026-03-20 | V200=200 fork triggered |
| S3 | Node restart after upgrade | P0 | **PASS** | 2026-03-20 | No store mismatch |
| S4 | Fork hard-fork path | P1 | **PASS** | 2026-03-20 | Covered by S2 |
| S6 | DKG module functional | P0 | **PASS** | 2026-03-20 | Params initialized, events on every block |
| S7 | Vote extensions working | P0 | **PASS** | 2026-03-20 | ExtendVote + VerifyVoteExtension post-upgrade |
| S9 | State integrity | P1 | **PASS** | 2026-03-20 | 4 validators, equal voting power |

### Post-#726 Tests (binary-swap, disk fallback)

#726 changes v2.0.0 from fork-based to pure binary-swap upgrade. No hardcoded V200, disk fallback via `upgrade-info.json`.

| ID | Scenario | Priority | Status | Date | Notes |
|----|----------|----------|--------|------|-------|
| S1-726 | planUpgrade + cosmovisor (disk fallback) | P0 | **PASS** | 2026-03-23 | Height 275, no hardcoded V200 |
| S2-726 | Fresh genesis v2.0.0 chain | P0 | **PASS** | 2026-03-23 | DKG + VE from block 1 (requires genesis VE=1) |
| S3-726 | Node restart after upgrade | P0 | **PASS** | 2026-03-23 | Stale upgrade-info.json no interference |
| S6-726 | DKG functional (genesis chain) | P0 | **PASS** | 2026-03-23 | BeginBlocker from block 1 |
| S7-726 | VE timing via consensus params | P0 | **PASS** | 2026-03-23 | Uses VoteExtensionsEnableHeight |
| S5-726 | Rolling upgrade impossible | P1 | **PASS** | 2026-03-23 | Code analysis: ProcessProposal requires MsgAddDkgVote |
| D2-A | New node full sync (cosmovisor swap) | P0 | **PASS** | 2026-03-23 | val6: no app hash mismatch |
| D2-B | New node full sync (v2.0.0 only) | P0 | **FAIL** | 2026-03-23 | val5: app hash mismatch (expected, new KVStore) |
| S1-cosmovisor | Deploy via `cosmovisor add-upgrade` | P2 | **PASS** | 2026-03-23 | Standard deployment method |
| UT | Unit tests | P0 | **PASS** | 2026-03-23 | UpgradeStoreLoader 6/6 + DKG keeper |
| Smoke | EVM sanity (every step) | P0 | **PASS** | 2026-03-23 | transfer + contract call + blocks |

### Pending Tests

| ID | Scenario | Priority | Status | Notes |
|----|----------|----------|--------|-------|
| D2-ss | CL state sync with v2.0.0 only | **P0** | **PASS** | 2026-03-23 | val5: CometBFT state sync at height 3000, single v2.0.0 binary |
| D2-snap | EL snap sync post-upgrade | P1 | **PASS** | 2026-03-23 | val5: geth snap sync complete at block 3471, auto disabled |
| E1 | Validator delayed restart (1/4 down 2min) | P1 | **PASS** | 2026-03-23 | 3/4 continued, val4 caught up after restart |
| E2 | Crash during upgrade handler | P1 | **PASS** | 2026-03-23 | Cosmovisor recovered from crash-loop at upgrade height; handler too fast to kill mid-execution |
| E3 | Rollback past upgrade height | P1 | **PARTIAL** | 2026-03-24 | Post-upgrade rollback 5 blocks works; cross-upgrade-boundary rollback too slow on devnet (IAVL limitation) |
| E4 | Double planUpgrade (same name, pending) | P2 | **PASS** | 2026-03-23 | Second plan rejected: `pending_upgrade_exists` |
| E4b | planUpgrade after cancel | P2 | **PASS** | 2026-03-23 | cancel → re-plan succeeds |
| E4c | planUpgrade already completed name | P2 | **FINDING** | 2026-03-23 | evmengine allows re-plan of completed name (minor, SDK blocks execution) |
| E4d | cancelUpgrade leaves stale upgrade-info.json | P1 | **FINDING** | 2026-03-24 | `cancelUpgrade` clears on-chain state but NOT disk file; causes cosmovisor to look for wrong binary on restart/rollback |
| E5 | planUpgrade at past height | P2 | **PASS** | 2026-03-23 | Rejected on-chain |
| F1 | Pending unbonding across upgrade | P0 | - | delegate→undelegate before upgrade, verify mature after |
| F2 | In-flight tx at upgrade height | P0 | **PASS** | 2026-03-24 | 200 tx (forge script) across upgrade, all on-chain successful |
| F3 | Contract state survival | P1 | **PASS** | 2026-03-24 | ERC20 name/supply/balance intact post-upgrade |
| F4 | EL-CL consistency post-upgrade | P1 | **PASS** | 2026-03-24 | ERC20 deploy + transfer + approve + transferFrom all work |
| F5 | Block time regression | P1 | **PASS** | 2026-03-24 | 2.2s/block pre and post upgrade, no regression |
| F6 | Long-running stability (1h+) | P1 | - | Monitor RSS, disk, block time post-upgrade |
| F7 | Cross-version RPC (historical query) | P1 | **PASS** | 2026-03-24 | Historical balance at pre-upgrade block matches |
| F8 | Unequal voting power upgrade | P1 | - | 1 validator 10x stake, verify consensus |
| E6 | UBI distribution pre/post upgrade | P2 | - | DKG settlement + reward behavior change |
| E7 | Staking operations across upgrade | P2 | - | Subsumed by F1 for cross-upgrade case |
| E8 | Sequential upgrades (v2.0.0 → v3.0.0) | P2 | - | Multi-upgrade disk fallback |
| E9 | cancelUpgrade before execution | P2 | - | Nodes don't halt after cancel |
| F9 | Network partition during upgrade | P2 | - | 2/4 validators halt at different times |
| F10 | Downgrade v2.0.0 → v1.5.3 | P2 | - | Emergency rollback to old binary |
| F11 | New bin without planUpgrade | P1 | - | All validators swap to v2.0.0 without plan — can chain produce blocks? |
| F12 | Official binary on unknown chain ID | P1 | **INCONCLUSIVE** | 2026-03-24 | Binary started but app hash mismatch (DKG store mounted); no panic observed; needs clean upstream build to confirm |

### Disk Fallback Validation

| ID | Scenario | Covered By | Status |
|----|----------|------------|--------|
| D1 | upgrade-info.json happy path | S1-726 | **PASS** |
| D2 | No upgrade-info.json (state sync) | D2-ss | **PASS** |
| D3 | Stale upgrade-info.json (restart) | S3-726 | **PASS** |

### Standard Post-Test Sanity Check

Every test must end with `scripts/devnet-smoke-test.sh`:
1. Token transfer (0.01 IP) — EVM tx execution
2. Contract call (IPTokenStaking.minStakeAmount) — contract interaction
3. Block production — height increases over 3s

### TX Load Testing

Run `scripts/devnet-tx-load.sh` in background during upgrade tests to simulate real traffic:
- Sends transfer + contract call every 3s
- Logs height, tx count, fail count per iteration
- Validates no tx loss across upgrade boundary
- Usage: `DEVNET_PROPOSER_KEY="0x..." ./scripts/devnet-tx-load.sh 3 &`

### Bugs & Findings

| Issue | Status | Fix |
|-------|--------|-----|
| UpgradeStoreLoader mountedStores filter blocks new stores | [#722](https://github.com/piplabs/story/issues/722) | [#724](https://github.com/piplabs/story/pull/724) |
| install.sh missing chown | [devnet-aws#7](https://github.com/storyprotocol/story-devnet-aws/pull/7) | chown -R ubuntu:ubuntu |
| Genesis v2.0.0 needs VE=1 in genesis.json | [#729](https://github.com/piplabs/story/issues/729) (closed) | [devnet-aws#8](https://github.com/storyprotocol/story-devnet-aws/pull/8) |
| v2.0.0 cannot single-binary full sync | Expected behavior | New DKG KVStore changes multistore hash; must use cosmovisor |
| evmengine allows re-plan of completed upgrade name | Minor | `SetPendingUpgrade` doesn't check `GetDoneHeight`; SDK blocks execution at apply time |
| cancelUpgrade leaves stale upgrade-info.json | **P1** | `DumpUpgradeInfoToDisk` writes at plan time, `cancelUpgrade` doesn't delete it; causes cosmovisor to look for wrong binary on restart/rollback |

### TEE Limitation

Devnet validators do not have TEE (SGX). DKG functional tests (registration, dealing, finalization) cannot complete without kernel sidecar. Upgrade mechanism tests work normally.

## Upgrade Mechanism (post-#726)

v2.0.0 is a **binary-swap upgrade**. Old binary halts at planUpgrade height, writes `upgrade-info.json`. New binary reads it via `ReadUpgradeInfoFromDisk()` to register DKG store.

```
planUpgrade("v2.0.0", H) on-chain
  → old binary halts at H, writes upgrade-info.json
  → cosmovisor reads it, switches to v2.0.0 binary
  → new binary reads upgrade-info.json → mounts DKG store
  → upgrade handler runs (InitGenesis + SetParams + enableVoteExtensions)
```

No hardcoded V200 needed. One universal binary for all networks.

**New node joining post-upgrade**: Must use cosmovisor with pre-upgrade + v2.0.0 binaries for full sync. Cannot use v2.0.0 alone (DKG store changes multistore hash from block 1).

### Verification APIs

| API | Purpose |
|-----|---------|
| `/upgrade/applied_plan/{name}` | Verify upgrade completed + height |
| `/upgrade/module_versions` | DKG should appear (version=1) |
| `/evmengine/pending_upgrade` | Check pending planUpgrade |

### Deployment Notes

- Use `cosmovisor add-upgrade v2.0.0 <binary>` (no `--upgrade-height`)
- Deploy to 7 nodes: validator1-4, rpc1, bootnode1, blockscout
- Set planUpgrade height = current + 200 (~7 min buffer)
- Fund executor account before planUpgrade
- Genesis v2.0.0 chains: set `vote_extensions_enable_height: "1"` in genesis.json
