# PR #726 Test Report — Binary-Swap Upgrade

**PR**: [#726](https://github.com/piplabs/story/pull/726)
**Date**: 2026-03-23
**Network**: internal-devnet-1 (devnet0)
**Binary**: `story-726-faa1e37` (commit `faa1e37` + InternalDevnetID config)

## What Changed

PR #726 changes v2.0.0 from fork-based upgrade to pure binary-swap upgrade:

| Area | Before | After |
|------|--------|-------|
| V200 height | Hardcoded per network in `UpgradeHistories` | Read from `upgrade-info.json` via disk fallback |
| `isV200` guards | 6 places gating DKG/VE/UBI | Removed — all run unconditionally |
| `ProcessProposal` | `MsgAddDkgVote` optional before H+2 | Required from block 1 |
| `PrepareVotes` timing | `v200Height+1` guard | `VoteExtensionsEnableHeight` from consensus params |
| Fork path for V200 | `scheduleForkUpgrade` active | Eliminated |
| Binary | Network-specific (different V200 per chain) | Universal (one binary, all networks) |

## Test Results

### Completed

| ID | Test | Priority | Status | Notes |
|----|------|----------|--------|-------|
| UT | Unit tests (UpgradeStoreLoader 6/6 + DKG keeper) | P0 | **PASS** | `go test ./client/app/ -run TestUpgradeStoreLoader` + `go test ./client/x/dkg/keeper/...` |
| S1-726 | planUpgrade + cosmovisor (disk fallback) | P0 | **PASS** | Height 275, no hardcoded V200, upgrade-info.json drives store creation |
| S3-726 | Node restart after upgrade | P0 | **PASS** | Stale upgrade-info.json no interference, DefaultStoreLoader works |
| S2-726 | Fresh genesis v2.0.0 chain | P0 | **PASS** | DKG + VE from block 1 (requires genesis.json `vote_extensions_enable_height: "1"`) |
| S6-726 | DKG functional (genesis chain) | P0 | **PASS** | BeginBlocker unconditional, rounds initiating from block 1 |
| S7-726 | VE timing via consensus params | P0 | **PASS** | ExtendVote + VerifyVoteExtension from block 1 |
| S5-726 | Rolling upgrade impossible | P1 | **PASS** | Code analysis: ProcessProposal always requires MsgAddDkgVote |
| Smoke | EVM sanity (every step) | P0 | **PASS** | Token transfer + contract call + block production |

### Pending

| ID | Test | Priority | Prerequisite | Notes |
|----|------|----------|-------------|-------|
| D2/S8 | New node full sync through upgrade height | P0 | **PASS** | 2026-03-23 | validator5 wiped, full sync from genesis, cosmovisor auto-switch at 412, no app hash mismatch |
| D2-ss | New node state sync into post-upgrade network | P1 | - | | Needs snapshot enabled |
| S1-cosmovisor | S1 using `cosmovisor add-upgrade` | P2 | **PASS** | 2026-03-23 | Used in this round's S1 deployment |

### Execution Plan for Pending Tests

### D2/S8: New Node Full Sync Through Upgrade Height — PASS

**Date**: 2026-03-23
**Node**: validator5 (wiped data, full sync from genesis)
**Upgrade height**: 412

| Step | Result |
|------|--------|
| Network reset (v1.5.3 genesis) | [Workflow #23423256253](https://github.com/storyprotocol/story-devnet-aws/actions/runs/23423256253) — SUCCESS |
| Deploy #726 binary to 7 nodes via `cosmovisor add-upgrade` | 7/7 SUCCESS |
| planUpgrade(412) | schedule + execute SUCCESS |
| Upgrade on 4 validators | PASS, chain at 435+ |
| Smoke test | PASS |
| Stop validator5, wipe data, re-init, start cosmovisor | OK |
| v1.5.3 full sync from genesis to 411 | No app hash mismatch |
| Halt at 412, cosmovisor auto-switch to v2.0.0 | `upgrade-info.json` generated, current → upgrades/v2.0.0 |
| v2.0.0 upgrade handler at 412 | "applying upgrade v2.0.0", DKG activated |
| Continue sync to 563+ | No app hash mismatch |

**Note**: VE warning `Vote extensions enabled at unexpected height expected=413 actual=1` — because `genesis.json` has `vote_extensions_enable_height: "1"` (from devnet-aws#8), while upgrade handler tries to set it to 413. Handler detects it's already set and skips (harmless).

This validates that a new node can join a post-upgrade network by full-syncing from genesis with cosmovisor managing the binary switch. The `upgrade-info.json` is created automatically during replay when the old binary encounters the upgrade plan at height 412.

### Test B: v2.0.0 Direct Full Sync (No Cosmovisor Switch) — FAIL (Expected)

**Date**: 2026-03-23
**Node**: validator5 (v2.0.0 as genesis binary, no v1.5.3)

| Step | Result |
|------|--------|
| Replace genesis binary with v2.0.0 | OK |
| Remove upgrades directory | OK |
| Wipe data, start cosmovisor | OK |
| DKG BeginBlocker from block 1 | "Initiated new DKG round" at block 1 |
| App hash mismatch | **FAIL** at early blocks |

```
wrong Block.Header.AppHash.
Expected 379131F9669FD151D1D86624F737B9A31A80A3A4FECBB1BA1D35B89F5F64A185,
got 7ED8F0017B612FD883CB9EC9DE11A3FE5E24024208867002600197B4B4A3A955
```

**Root cause**: v2.0.0 binary mounts DKG KVStore from startup. When replaying
block 1 (originally committed by v1.5.3 which has no DKG store), the multistore
hash includes DKG → app hash diverges.

**This is NOT a #726 bug.** It's inherent to any upgrade that adds a new KVStore.
v2.0.0 is the first Story upgrade to add a new store (DKG). Previous upgrades
(Terence, Horace) only changed behavior within existing modules, so single-binary
full sync worked. With a new store, cosmovisor with binary swap is required.

**Operational implication for Aeneid/mainnet**: New nodes joining post-upgrade
MUST use cosmovisor with v1.5.3 (genesis) + v2.0.0 (upgrade) binaries. Cannot
use v2.0.0 alone for full sync.

## Detailed Results

### S1-726: planUpgrade + Cosmovisor (Disk Fallback)

**Upgrade height**: 275

| Step | Result |
|------|--------|
| Network reset (v1.5.3 genesis) | [Workflow #23420177061](https://github.com/storyprotocol/story-devnet-aws/actions/runs/23420177061) — SUCCESS |
| Deploy `story-726-faa1e37` to 7 nodes | 7/7 SUCCESS |
| Fund executor + planUpgrade(275) | schedule `0xbbd998...` execute `0x4b81f7...` |
| Pending upgrade confirmed | `{"plan":{"name":"v2.0.0","height":"275"}}` |
| Old binary halt at 275 | panic "UPGRADE v2.0.0 NEEDED" (expected) |
| Cosmovisor auto-switch | New PID running |
| `/upgrade/applied_plan/v2.0.0` | height 275 |
| 4 validators active | PASS |
| VerifyVoteExtension from 276+ | PASS |
| Processed DKG events every block | PASS |
| No store mismatch / panic | PASS |
| Smoke test | PASS |

Key validation: **No hardcoded V200 in binary.** `upgrade-info.json` written by old binary at halt, read by new binary via `ReadUpgradeInfoFromDisk()` to register DKG store at the correct height.

### S3-726: Node Restart After Upgrade

| Step | Result |
|------|--------|
| Restart rpc1 via SSM | OK |
| cosmovisor status after 30s | `active (running)` |
| Stale upgrade-info.json | No interference (past upgrade height < lastVersion, skipped) |
| Node caught up | Height 349 |
| Smoke test | PASS |

### S2-726: Fresh Genesis v2.0.0 Chain

**First attempt**: `vote_extensions_enable_height: "0"` in genesis.json → VE never enabled → DKG rounds initiate but never finalize. Issue [#729](https://github.com/piplabs/story/issues/729) filed.

**Root cause**: Not a code bug. `"0"` means disabled in CometBFT. Genesis chains need this set to `"1"` explicitly since no upgrade handler runs to call `enableVoteExtensions`.

**Fix**: [devnet-aws#8](https://github.com/storyprotocol/story-devnet-aws/pull/8) — changed to `"1"`.

**Re-test after fix**:

| Step | Result |
|------|--------|
| Network reset with #726 genesis + VE=1 | [Workflow #23422311070](https://github.com/storyprotocol/story-devnet-aws/actions/runs/23422311070) — SUCCESS |
| Chain producing blocks from height 1 | PASS (height 570+) |
| DKG BeginBlocker from block 1 | PASS (rounds initiating) |
| ExtendVote + VerifyVoteExtension | Present on every block |
| 4 validators active | PASS |
| No upgrade handler / fork trigger | PASS |
| Smoke test | PASS |

### S5-726: Rolling Upgrade Impossible (Code Analysis)

`ProcessProposal` (`client/app/prouter.go:76-79`) unconditionally requires exactly 1 `MsgAddDkgVote` in every proposal:

```go
expectedMsgCounts := map[string]int{
    sdk.MsgTypeURL(&evmenginetypes.MsgExecutionPayload{}): 1,
    sdk.MsgTypeURL(&dkgtypes.MsgAddDkgVote{}):             1, // always required
}
```

Old binary proposers don't include `MsgAddDkgVote` → new binary validators reject → consensus breaks. **All validators must switch at the same upgrade height.** This is by design (binary-swap).

### D2: No upgrade-info.json (Partial)

Validator5 running #726 binary on genesis chain:
- `upgrade-info.json`: not found
- Height 390, `catching_up: false`
- Binary starts normally via `lastVersion==0` early return

**Partial**: Only validates genesis scenario. Full D2 (new node joining post-upgrade network) requires S1-726 network — pending.

## Findings

### Genesis VE Configuration Required

**Issue**: [#729](https://github.com/piplabs/story/issues/729) (closed — config issue, not code bug)
**Fix**: [devnet-aws#8](https://github.com/storyprotocol/story-devnet-aws/pull/8)

Any chain starting with v2.0.0 as genesis binary must set `vote_extensions_enable_height: "1"` in genesis.json. The upgrade handler (which normally calls `enableVoteExtensions`) doesn't run on genesis chains.

### Deployment Notes

- Use `cosmovisor add-upgrade v2.0.0 <binary>` (no `--upgrade-height` flag)
- Deploy to **7 nodes**: validator1-4, rpc1, bootnode1, blockscout
- Do NOT deploy to validator5/6 (test nodes for join scenarios)
- Set planUpgrade height = current height + 200 (~7 min buffer at 2s/block)
- Fund executor account before planUpgrade (new chain has 0 balance)
- Binary is universal — same binary for all networks, no hardcoded V200

## Artifacts

| Item | Value |
|------|-------|
| PR #726 binary | `s3://story-devnet-binaries/binaries/story-726-faa1e37` |
| Genesis binary (S1) | `s3://story-devnet-binaries/binaries/story-v1.5.3-dev` |
| S1-726 planUpgrade schedule tx | `0xbbd998332b4ccbcd0fbb380a62e6ebf15da3fbce869e728ec2e78eba43b974a3` |
| S1-726 planUpgrade execute tx | `0x4b81f788958ed83145483d8480cca33d4b1cfef4eb8f82c2bff8f23e0475a400` |
| Genesis VE fix | [devnet-aws#8](https://github.com/storyprotocol/story-devnet-aws/pull/8) |
| VE issue (closed) | [story#729](https://github.com/piplabs/story/issues/729) |
