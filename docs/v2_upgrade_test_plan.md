# v2.0.0 Upgrade Test Plan

Devnet topology: 1 RPC, 1 bootnode, 4 genesis validators (same voting power), 2 test nodes (can join as new validators)

## Execution Status

| ID | Scenario | Priority | Status | Date | Notes |
|----|----------|----------|--------|------|-------|
| S1 | planUpgrade + cosmovisor auto-switch | P0 | **PASS** | 2026-03-23 | Re-verified with official #724 fix (9ec3785), height 1000 |
| S2 | Fresh genesis chain with DKG | P0 | **PASS** | 2026-03-20 | network-reset with dkg/dev binary, V200=200 fork triggered |
| S3 | Node restart after upgrade | P0 | **PASS** | 2026-03-20 | rpc1 restarted, no store mismatch (`height <= lastVersion` path) |
| S4 | Fork hard-fork path (BeginBlock auto-trigger) | P1 | **PASS** | 2026-03-20 | Covered by S2: V200=200 triggered via scheduleForkUpgrade |
| S5 | Rolling upgrade (partial validator switch) | P1 | - | | |
| S6 | DKG module functional (params, events) | P0 | **PASS** | 2026-03-20 | Params initialized, `Processed DKG events` on every block |
| S7 | Vote extensions enabled and working | P0 | **PASS** | 2026-03-20 | ExtendVote + VerifyVoteExtension on every block post-200 |
| S8 | EVM continuity (contract calls, transfers) | P1 | - | | |
| S9 | State integrity (balances, validators, staking) | P1 | **PASS** | 2026-03-20 | 4 validators, equal voting power, 8 peers |
| S10 | New node state sync post-upgrade | P1 | - | | |
| S11 | Late node upgrade (deploy binary after upgrade height) | P1 | - | | |
| S12 | Rollback to old binary | P2 | - | | |

### PR #726 Tests

PR #726 changes v2.0.0 from fork-based to pure binary-swap upgrade. Removes all `isV200` guards, adds disk fallback via `upgrade-info.json`. Tests below validate the new mechanism.

| ID | Scenario | Priority | Status | Date | Notes |
|----|----------|----------|--------|------|-------|
| S1-726 | planUpgrade + cosmovisor (disk fallback) | P0 | **PASS** | 2026-03-23 | height 275, disk fallback worked, no hardcoded V200 |
| S2-726 | Fresh genesis v2.0.0 chain | P0 | **PARTIAL** | 2026-03-23 | DKG runs from block 1, but VE never enabled ([#729](https://github.com/piplabs/story/issues/729)) |
| S3-726 | Node restart after upgrade | P0 | **PASS** | 2026-03-23 | stale upgrade-info.json no interference |
| S6-726 | DKG functional (genesis chain) | P0 | **PARTIAL** | 2026-03-23 | BeginBlocker runs, rounds initiate but never finalize (VE disabled) |
| S7-726 | VE timing via consensus params | P0 | **FAIL** | 2026-03-23 | VoteExtensionsEnableHeight=0 on genesis chain |
| D2 | State sync (no upgrade-info.json) | P1 | - | | |
| S5-726 | Rolling upgrade impossible | P1 | - | | |

### UpgradeStoreLoader Fix Validation

| ID | Code Path | Covered By | Status |
|----|-----------|------------|--------|
| S13 | `lastVersion==0` (genesis) | S2 | **PASS** |
| S14 | `height <= lastVersion` (restart) | S3 | **PASS** |
| S15 | `height > nextVersion` (future pre-add) | S4 | - |

### Disk Fallback Validation (PR #726)

| ID | Scenario | Covered By | Status |
|----|----------|------------|--------|
| D1 | upgrade-info.json exists, correct name | S1-726 | **PASS** |
| D2 | upgrade-info.json missing (state sync) | - | - |
| D3 | Stale upgrade-info.json (restart) | S3-726 | **PASS** |

### Standard Post-Test Sanity Check

Every test must end with `scripts/devnet-smoke-test.sh`:
1. Token transfer (0.01 IP) — EVM tx execution
2. Contract call (IPTokenStaking.minStakeAmount) — contract interaction
3. Block production — height increases over 3s

### Bugs Found

| Issue | Status | Fix |
|-------|--------|-----|
| UpgradeStoreLoader mountedStores filter blocks new stores | [#722](https://github.com/piplabs/story/issues/722) | Remove mountedStores check at exact upgrade height |
| install.sh missing chown (cosmovisor runs as ubuntu, files owned by root) | [PR #7](https://github.com/storyprotocol/story-devnet-aws/pull/7) | Add chown -R ubuntu:ubuntu |
| Genesis v2.0.0: VoteExtensions never enabled, DKG cannot finalize | [#729](https://github.com/piplabs/story/issues/729) | Set VoteExtensionsEnableHeight in InitGenesis |

### TEE limitation

Devnet validators do not have TEE (SGX). DKG requires two TEE-dependent components:
- **story-kernel**: gRPC sidecar running inside SGX enclave, handles DKG key generation/dealing/signing
- **DKG contract attestation**: `register()` and `finalize()` call `authenticateEnclaveReport()` via SGXValidationHook, which verifies real enclave reports

Without TEE, upgrade mechanism tests work normally. DKG functional tests will fail at registration.

## Detailed Test Cases

| ID | Phase | Scenario | Priority |
|----|-------|----------|----------|
| S1 | Happy Path | planUpgrade + cosmovisor auto-switch | P0 |
| S2 | Happy Path | planUpgrade + manual binary swap | P0 |
| S3 | Consensus Fault Tolerance | 1/4 validator delayed restart | P1 |
| S4 | Consensus Fault Tolerance | 2/4 validators delayed restart | P1 |
| S5 | Consensus Fault Tolerance | 1 validator never upgrades | P1 |
| S6 | Store & AppHash | New binary started before upgrade height | P0 |
| S7 | Store & AppHash | Full sync from genesis after upgrade | P2 |
| S8 | Vote Extensions | H / H+1 / H+2 timing verification | P0 |
| S9 | Vote Extensions | MsgAddDkgVote in proposals | P2 |
| S10 | DKG | First DKG round after activation `[TEE]` | P0 |
| S11 | DKG | Height gating before v2.0.0 | P2 |
| S12 | Node Join | New validator joins after upgrade and participates in DKG `[TEE]` | P1 |
| S13 | Node Join | Existing validator upgrades with planUpgrade halt and participates in DKG `[TEE]` | P1 |
| S14 | Node Join | State sync after upgrade | P2 |
| S15 | Recovery | Rollback to pre-upgrade height | P1 |
| S16 | Recovery | Crash during upgrade handler | P1 |
| S17 | UBI & Staking | UBI distribution before/after upgrade | P2 |

---

## Prerequisite

在升级高度 H 之前，发送 `UpgradeEntrypoint.planUpgrade("v2.0.0", H, info)`，高度必须与 `lib/netconf/upgrades.go` 中硬编码的 V200 高度一致。

## Appendix: Upgrade Trigger Mechanism

### Two Upgrade Paths

**Path A: planUpgrade Contract (on-chain)**

```
owner calls UpgradeEntrypoint.planUpgrade(name, height, info)
  → contract emit SoftwareUpgrade event
  → evmengine ProcessUpgradeEvents
  → evmengine ScheduleUpgrade → SetPendingUpgrade
  → PreBlocker checks ShouldUpgrade
  → at height: UpgradeKeeper.ScheduleUpgrade → ApplyUpgrade
```

**Path B: scheduleForkUpgrade (hardcoded fork)**

```
upgrade height hardcoded in lib/netconf/upgrades.go
  → PreBlocker calls scheduleForkUpgrade
  → blockHeight == upgradeHeight: UpgradeKeeper.ScheduleUpgrade
  → ApplyUpgrade executes handler
```

### PR #726 Change

#726 eliminates Path B for v2.0.0 and adds disk fallback: old binary writes `upgrade-info.json` at halt, new binary reads it via `ReadUpgradeInfoFromDisk()` to register store upgrades. One universal binary for all networks.

### Verification APIs

| API | Source | Purpose |
|-----|--------|---------|
| `/upgrade/current_plan` | Cosmos upgrade module | Pending but not-yet-executed plan |
| `/upgrade/applied_plan/{name}` | Cosmos upgrade module | Upgrade completed + execution height |
| `/upgrade/module_versions` | Cosmos upgrade module | All module consensus versions |
| `/evmengine/pending_upgrade` | evmengine KV store | planUpgrade contract pending plan |
