# upgrade-info.json Lifecycle

Cosmovisor version: **v1.6.0**

## Files

Three copies of `upgrade-info.json` exist after a successful upgrade:

| Path | Written by | Purpose |
|------|-----------|---------|
| `data/upgrade-info.json` | Story binary (`DumpUpgradeInfoToDisk`) | Source of truth. Read by both Story binary and cosmovisor |
| `cosmovisor/upgrades/<name>/upgrade-info.json` | Cosmovisor (`SetCurrentUpgrade`) | Written when cosmovisor switches the current symlink |
| `cosmovisor/backup/data-backup-<date>/upgrade-info.json` | Cosmovisor (pre-upgrade backup) | Copy of data dir before upgrade |

## Write

`data/upgrade-info.json` is written **twice**:

1. When `planUpgrade` tx is processed on-chain (Story layer, `evmengine/keeper/upgrades.go:105`). Failure is a **Warn** only — planUpgrade still succeeds on-chain but cosmovisor won't know about it.
2. At halt height in `PreBlocker` (SDK layer, `x/upgrade/abci.go:90`). Failure is a **hard error** — block cannot finalize.

```
evmengine/keeper/upgrades.go → DumpUpgradeInfoToDisk(height, plan)
  → cosmos-sdk x/upgrade/keeper/keeper.go:512
  → path: {homePath}/data/upgrade-info.json
```

Content: `{"name":"v1.6.0","time":"...","height":159}`

The second write is a safety net. In normal operation both writes succeed with identical content.

## Read

### By Story binary (on startup)

```
client/app/upgrades.go:82
  → ReadUpgradeInfoFromDisk()
  → path: {homePath}/data/upgrade-info.json
  → uses name + height to register StoreUpgrades (mount new KVStores)
```

### By Cosmovisor (file watcher)

```
cosmovisor/scanner.go:40
  → cfg.UpgradeInfoFilePath()
  → path: {Home}/data/upgrade-info.json
  → polls every 300ms (default DAEMON_POLL_INTERVAL)
  → checks file mtime + compares height with current chain height
  → triggers switch when currentHeight >= info.Height
```

Both read the **same file** at the same path.

In practice, the app panics at upgrade height before cosmovisor's poll detects it. Cosmovisor then catches the process exit and rechecks the file (`process.go WaitForUpgradeOrExit`).

### Verification

After `planUpgrade` is submitted, operators should verify the file exists:

```
cat ~/.story/story/data/upgrade-info.json
```

Expected: `{"name":"v1.6.0","height":<upgrade_height>}`. If missing, the first write failed — the SDK will still write it at halt height, but cosmovisor won't detect the upgrade until then.

## Switch

When cosmovisor detects the upgrade:

```
cosmovisor/upgrade.go → UpgradeBinary()
  → cfg.SetCurrentUpgrade(plan)
    → symlink current → upgrades/<name>
    → os.Create(upgrades/<name>/upgrade-info.json)
```

This creates the second copy at `cosmovisor/upgrades/<name>/upgrade-info.json`.

Source: [cosmos-sdk/tools/cosmovisor/args.go SetCurrentUpgrade](https://github.com/cosmos/cosmos-sdk/blob/cosmovisor/v1.6.0/tools/cosmovisor/args.go)

## Delete

**Nobody deletes `data/upgrade-info.json`.**

- `cancelUpgrade` clears on-chain state only ([#757](https://github.com/piplabs/story/issues/757))
- Cosmovisor does not delete it after switching
- Story binary does not delete it after applying the upgrade

This is why `cancelUpgrade` is ineffective against cosmovisor — the file remains on disk and cosmovisor still switches at the planned height.
