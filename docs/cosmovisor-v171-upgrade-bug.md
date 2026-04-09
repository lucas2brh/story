# Cosmovisor v1.7.x Upgrade Switch Failure

## Problem

Cosmovisor v1.7.0/v1.7.1 fails to switch binaries when the app panics at upgrade height. The `current` symlink stays on `genesis/` instead of switching to `upgrades/v1.6.0/`.

Reported by multiple Aeneid validators running cosmovisor v1.7.1 at upgrade height 16332000.

## Root Cause

v1.7.0 (#22528) changed the height check in `CheckUpdate` (scanner.go):

**v1.6.0** (works):
```go
currentHeight, _ := fw.checkHeight()
if currentHeight != 0 && currentHeight < info.Height {
    return false
}
```
When app is dead, `checkHeight()` returns `(0, err)`. `0 != 0` = false → doesn't skip → proceeds to trigger upgrade.

**v1.7.x** (broken):
```go
currentHeight, err := fw.checkHeight()
if (err != nil || currentHeight < info.Height) && !errors.Is(err, errUntestAble) {
    return false  // ← always hits this when app is dead
}
```
When app is dead, `checkHeight()` returns error. `err != nil` = true → returns false → no upgrade triggered.

## How It Manifests

1. App reaches upgrade height → `UPGRADE "v1.6.0" NEEDED` → panic
2. Cosmovisor detects process exit (`cmdDone` in `WaitForUpgradeOrExit`)
3. Calls `CheckUpdate()` → `checkHeight()` fails (process dead) → returns false
4. Cosmovisor treats it as "no upgrade needed" → restarts with genesis binary
5. Genesis binary panics again at upgrade height → infinite crash loop with `current -> genesis/`

## Two Upgrade Paths in Cosmovisor

```
select {
case <-l.fw.MonitorUpdate(currentUpgrade):   // Path A: poll detects upgrade
case err := <-cmdDone:                       // Path B: app exits, recheck
    if !l.fw.CheckUpdate(currentUpgrade) {   // ← broken in v1.7.x
        return false, err
    }
}
```

- **Path A** (poll): May work if poll happens to catch `height >= upgrade_height` before app panics. Race condition with 300ms poll interval.
- **Path B** (app exit): Always fails in v1.7.x because `checkHeight()` can't reach dead process.

## Affected Versions

| Version | Behavior |
|---------|----------|
| v1.6.0 | Works — height=0 bypasses check |
| v1.7.0 | Broken — err != nil blocks upgrade |
| v1.7.1 | Broken — same as v1.7.0 |
| unreleased (#23720) | Should fix — reads height from db instead of CLI |

## Recovery (for stuck validators)

```bash
# Manual symlink switch:
sudo systemctl stop cosmovisor
rm -f ~/.story/story/cosmovisor/current
ln -s ~/.story/story/cosmovisor/upgrades/v1.6.0 ~/.story/story/cosmovisor/current
sudo systemctl start cosmovisor
```

## Recommendations

1. Validators should use cosmovisor **v1.6.0** for this upgrade
2. Or wait for a release that includes #23720
3. If already stuck: manual symlink switch (see recovery above)

## Devnet Verification

Tested on internal-devnet-1 with val5 (cosmovisor v1.6.0) and val6 (cosmovisor v1.7.1), both doing full sync from genesis through upgrade height 241:

| Node | Cosmovisor | Result | current symlink |
|------|-----------|--------|-----------------|
| val5 | v1.6.0 | Switched to v1.6.0, syncing at height 3726 | upgrades/v1.6.0 |
| val6 | v1.7.1 | Crash loop at height 241, never switched | genesis |

val6 log:
```
UPGRADE "v1.6.0" NEEDED at height: 241
Fatal error occurred, app died unexpectedly
cosmovisor.service: Failed with result 'exit-code'
(repeats every ~3s, never switches binary)
```

## References

- v1.7.0 fix that introduced the regression: https://github.com/cosmos/cosmos-sdk/pull/22528
- Fix for the regression (unreleased): https://github.com/cosmos/cosmos-sdk/pull/23720
- Relative symlink change in v1.7.0: https://github.com/cosmos/cosmos-sdk/pull/21891
