# PR #726 Testing — Execution Steps

## Context

PR #726 changes v2.0.0 from fork-based to pure binary-swap upgrade. Need to verify:
- disk fallback (upgrade-info.json) works for live upgrade
- DKG runs unconditionally from block 1 on genesis chains
- node restart with stale upgrade-info.json is safe
- EVM layer works after every test

## Prerequisites

### 1. Checkout PR #726

```bash
gh pr checkout 726 --repo piplabs/story
```

### 2. Add InternalDevnetID config (not in #726, we maintain locally)

**`lib/netconf/chains.go`** — add constant:
```go
InternalDevnetID = "internal-devnet-1"
```

**`lib/netconf/upgrades.go`** — add to `UpgradeHistories` (no V200, that's the point of #726):
```go
InternalDevnetID: {
    V121:    0,
    Terence: 0,
    V142:    0,
    Horace:  100,
    // V200 intentionally absent — comes from upgrade-info.json via disk fallback
},
```

### 3. Verify compilation

```bash
go build ./client
```

## Step 1: Unit Tests

```bash
go test ./client/app/ -run TestUpgradeStoreLoader -v
go test ./client/x/dkg/keeper/... -v -count=1
```

Pass criteria: all tests pass, no panic.

## Step 2: S1 — planUpgrade + cosmovisor (disk fallback)

**Key difference from pre-#726**: no hardcoded V200 needed. One universal binary.

### 2a. Build & upload

```bash
GOOS=linux GOARCH=amd64 go build -o build/story-linux-amd64 ./client
BINARY_NAME="story-726-$(git rev-parse --short HEAD)"
aws s3 cp build/story-linux-amd64 "s3://story-devnet-binaries/binaries/${BINARY_NAME}" --profile story-devnet
```

### 2b. Network reset (main branch genesis)

```bash
# story-devnet-aws repo
gh workflow run "Network Reset" \
  -f environment=use1-devnet0 \
  -f binary_install_method=s3 \
  -f story_binary_s3_path="s3://story-devnet-binaries/binaries/story-v1.5.3-dev" \
  -f story_geth_binary_s3_path="s3://story-devnet-binaries/binaries/geth-v1.2.1-13f751"
```

Wait for workflow completion.

### 2c. Get instance IDs & confirm chain

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=*devnet0*" "Name=instance-state-name,Values=running" --query "..." --profile story-devnet --region us-east-1
# Check height via SSM on rpc1
```

### 2d. Deploy upgrade binary to 7 nodes

**All 7**: validator1-4, rpc1, bootnode1, **blockscout**

```bash
aws ssm send-command --instance-ids <all 7> --document-name "AWS-RunShellScript" \
  --parameters 'commands=["mkdir -p ...", "aws s3 cp ...", "cp ...", "chmod +x ...", "chown -R ubuntu:ubuntu ..."]'
```

### 2e. planUpgrade

Set height = current + 200 (~7 min buffer).

```bash
bash scripts/devnet-plan-upgrade.sh <HEIGHT>
```

### 2f. Wait & verify

- [x] Old binary halts at 275 ("UPGRADE v2.0.0 NEEDED") — **PASS**
- [x] Cosmovisor auto-switches to new binary (PID 18946) — **PASS**
- [x] `/upgrade/applied_plan/v2.0.0` returns 275 — **PASS**
- [x] 4 validators active — **PASS**
- [x] VerifyVoteExtension in logs from 276+ — **PASS**
- [x] No store mismatch / panic in logs — **PASS**
- [x] `bash scripts/devnet-smoke-test.sh` — **PASS**

**S1-726 Result: PASS** (2026-03-23)
Binary: `story-726-faa1e37`, upgrade height 275, disk fallback via upgrade-info.json

## Step 3: S3 — Node restart after upgrade — PASS

Restarted rpc1, waited 30s:
- [x] cosmovisor active (running) — **PASS**
- [x] No store mismatch / panic — **PASS**
- [x] Node at height 349, caught up — **PASS**
- [x] Stale upgrade-info.json doesn't interfere — **PASS**
- [x] `bash scripts/devnet-smoke-test.sh` — **PASS**

**S3-726 Result: PASS** (2026-03-23)

## Step 4: S2 — Fresh genesis v2.0.0 chain

**This destroys current devnet. Run after S1/S3.**

### 4a. Network reset with #726 binary as genesis

```bash
gh workflow run "Network Reset" \
  -f environment=use1-devnet0 \
  -f binary_install_method=s3 \
  -f story_binary_s3_path="s3://story-devnet-binaries/binaries/${BINARY_NAME}" \
  -f story_geth_binary_s3_path="s3://story-devnet-binaries/binaries/geth-v1.2.1-13f751"
```

### 4b. Verify

- [x] Chain producing blocks from height 1 — **PASS** (height 570+)
- [x] DKG BeginBlocker running from block 1 — **PASS** (round 86+ at height 341, `Processed DKG events` every block)
- [x] No fork trigger, no upgrade handler execution — **PASS** (no "upgrade" in logs)
- [x] 4 validators active — **PASS**
- [x] `bash scripts/devnet-smoke-test.sh` — **PASS**
- [ ] MsgAddDkgVote in proposals — empty vote (VE not enabled, see finding below)
- [ ] Vote extensions — **NOT ENABLED** (VoteExtensionsEnableHeight=0)

**S2-726 Result: PARTIAL PASS** (2026-03-23)

**Finding**: Genesis v2.0.0 chain has no upgrade handler to call `enableVoteExtensions`.
`VoteExtensionsEnableHeight` stays 0 in consensus params. DKG BeginBlocker runs but
VE never activates. `PrepareVotes` returns empty `MsgAddDkgVote` (veHeight==0 path).
Chain works but DKG rounds can never complete without VE data.
**Action needed**: Genesis chains need `VoteExtensionsEnableHeight` set in genesis.json or app init.

## Step 5: S6 + S7 — DKG & VE functional (on S2 chain)

- [ ] DKG params query returns initialized params
- [ ] ExtendVote / VerifyVoteExtension in every block
- [ ] PrepareVotes returns empty MsgAddDkgVote when VE not yet available, real vote after

## Step 6: Update docs

- Update `docs/v2_upgrade_test_plan.md` — add #726 results
- Update `docs/v2_upgrade_test_report.md` — add #726 test sections
- Update plan file with final status

## Execution Order

```
Unit tests → S1 (live upgrade) → S3 (restart) → S2 (genesis) → S6/S7 (functional) → docs
```

Each step ends with `devnet-smoke-test.sh`.

## Key Files

- `client/app/upgrades.go` — disk fallback, GetStoreUpgrades
- `client/app/upgrades_internal_test.go` — unit tests
- `client/app/prouter.go` — ProcessProposal always requires MsgAddDkgVote
- `client/x/dkg/keeper/vote.go` — PrepareVotes uses VoteExtensionsEnableHeight
- `scripts/devnet-smoke-test.sh` — post-test sanity check
- `scripts/devnet-plan-upgrade.sh` — planUpgrade via TimelockController
