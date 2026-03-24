# Mock DKG Testing Guide (No TEE)

## Purpose

Devnet has no TEE. DKG settlement balance is always 0 and there's no active committee. Two mocks seed fake state in the v2.0.0 upgrade handler to test the non-zero paths in `ProcessUbiWithdrawal`.

## Branch

`test/mock-dkg-settlement` on `lucas2brh/story`

## Mock A: Settlement Balance (ClaimSettlementBalance)

**What it tests**: `ProcessUbiWithdrawal` line 24 — `ClaimSettlementBalance` reads non-zero balance → transfers from DKG to evmstaking → burn → withdrawal queue.

**Code** (in upgrade handler after `SetParams`):

```go
mockAmount := math.NewInt(10000)
mockCoins := sdk.NewCoins(sdk.NewCoin(sdk.DefaultBondDenom, mockAmount))
if err := keepers.BankKeeper.MintCoins(ctx, dkgtypes.ModuleName, mockCoins); err != nil {
    log.Warn(ctx, "Mock: failed to mint settlement coins", err)
} else if err := keepers.DKGKeeper.SettlementBalance.Set(ctx, mockAmount.String()); err != nil {
    log.Warn(ctx, "Mock: failed to set settlement balance", err)
} else {
    log.Info(ctx, "Mock: seeded DKG settlement balance", "amount", mockAmount.String())
}
```

**Why two steps**:
1. `MintCoins` — DKG module account needs tokens for `SendCoinsFromModuleToModule`
2. `SettlementBalance.Set` — writes string value for `ClaimSettlementBalance` to read

**Verification**:
```bash
journalctl -u cosmovisor | grep "Mock: seeded DKG settlement"
journalctl -u cosmovisor | grep "Claimed DKG settlement balance"
```

## Mock B: Active Committee (DistributeRewardsToActiveCommittee)

**What it tests**: `ProcessUbiWithdrawal` line 50 — `DistributeRewardsToActiveCommittee` finds active committee → calculates 10% of UBI → distributes per-member → remainder to settlement.

**Conditions needed**:
1. `getLatestActiveDKGNetwork` returns non-nil — needs DKG network in store
2. `getDKGRegistrationsByStatus` returns finalized members — needs fake registrations
3. Members have valid EVM addresses — for `SendCoinsFromModuleToAccount`

**Code** (in upgrade handler):

```go
// Mock B: fake active committee for DistributeRewardsToActiveCommittee
fakeRound := uint32(1)
fakeRoundKey := "1"

// Create DKG network
if err := keepers.DKGKeeper.DKGNetworks.Set(ctx, fakeRoundKey, dkgtypes.DKGNetwork{
    Round:            fakeRound,
    StartBlockHeight: plan.Height,
    Total:            3,
    Threshold:        2,
}); err != nil {
    log.Warn(ctx, "Mock B: failed to set DKG network", err)
}

// Set as active round
if err := keepers.DKGKeeper.LatestActiveRound.Set(ctx, fakeRoundKey); err != nil {
    log.Warn(ctx, "Mock B: failed to set active round", err)
}

// Create finalized registrations with real validator EVM addresses
// Use devnet validator addresses or any funded addresses
validators := []string{
    "0x1111111111111111111111111111111111111111",
    "0x2222222222222222222222222222222222222222",
    "0x3333333333333333333333333333333333333333",
}
for i, addr := range validators {
    regKey := fmt.Sprintf("%d_%s", fakeRound, strings.ToLower(addr))
    if err := keepers.DKGKeeper.DKGRegistrations.Set(ctx, regKey, dkgtypes.DKGRegistration{
        Round:         fakeRound,
        ValidatorAddr: strings.ToLower(addr),
        Index:         uint32(i),
        Status:        dkgtypes.DKGRegStatusFinalized,
    }); err != nil {
        log.Warn(ctx, "Mock B: failed to set registration", err, "addr", addr)
    }
}

log.Info(ctx, "Mock B: seeded fake DKG committee", "members", len(validators), "round", fakeRound)
```

**Expected flow** (first EndBlocker after upgrade, when UBI meets threshold):

```
DistributeRewardsToActiveCommittee(totalAmount)
  → getLatestActiveDKGNetwork → returns fakeNetwork (round 1)
  → getDKGRegistrationsByStatus(1, Finalized) → returns 3 members
  → dkgReward = totalAmount * 0.10
  → perMember = dkgReward / 3
  → SendCoinsFromModuleToAccount × 3
  → returns totalDistributed
```

**Verification**:
```bash
journalctl -u cosmovisor | grep "Distributed DKG committee rewards"
# Expected: "round=1 member_count=3 total_distributed=X per_member=Y"
```

**Note on registration key format**: Check `dkgRegistrationKey()` function for exact format. The key is `fmt.Sprintf("%d_%s", round, strings.ToLower(validatorAddr.Hex()))`.

## Imports Needed

```go
"cosmossdk.io/math"       // for math.NewInt
"fmt"                      // for fmt.Sprintf (Mock B)
"strings"                  // for strings.ToLower (Mock B)
```

## Test Steps

```bash
# 1. Checkout mock branch
git checkout test/mock-dkg-settlement

# 2. Add Mock B code to upgrade handler (if not already)

# 3. Cherry-pick InternalDevnetID
git cherry-pick <chainid-commit>

# 4. Compile + upload
GOOS=linux GOARCH=amd64 go build -o build/story-linux-amd64 ./client
aws s3 cp build/story-linux-amd64 "s3://story-devnet-binaries/binaries/story-mock-$(git rev-parse --short HEAD)" --profile story-devnet

# 5. Network reset (v1.5.3)
# 6. Deploy to 7 nodes via cosmovisor add-upgrade
# 7. planUpgrade(current+200)
# 8. Wait for upgrade
# 9. Verify logs (Mock A + Mock B)
# 10. Smoke test
```

## Pass Criteria

**Mock A**:
- [ ] "Mock: seeded DKG settlement balance" in logs
- [ ] "Claimed DKG settlement balance" in first EndBlocker
- [ ] Chain continues (no crash)

**Mock B**:
- [ ] "Mock B: seeded fake DKG committee" in logs
- [ ] "Distributed DKG committee rewards" in EndBlocker (when UBI threshold met)
- [ ] Chain continues (no crash)

## Notes

- Mock code on `test/mock-dkg-settlement` branch only — DO NOT merge to release
- Settlement is consumed in one block; committee rewards distribute on every UBI cycle
- Registration key format must match `dkgRegistrationKey()` exactly
- Validator addresses in Mock B receive actual token transfers — use funded or throwaway addresses
