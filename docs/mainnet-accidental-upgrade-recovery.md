# Recovery: Accidental v1.6.0 Deployment on Mainnet

v1.6.0 is Aeneid testnet only. No `planUpgrade("v1.6.0")` exists on mainnet. All scenarios verified on devnet.

## Scenario A: `cosmovisor add-upgrade` without `--upgrade-height`

No impact. Node keeps running. Clean up:
```bash
rm -rf ~/.story/story/cosmovisor/upgrades/v1.6.0/
```

## Scenario B: with `--upgrade-height`, height not yet reached

Node still running, but `upgrade-info.json` was written. Clean up before that height:
```bash
rm -rf ~/.story/story/cosmovisor/upgrades/v1.6.0/
rm -f ~/.story/story/data/upgrade-info.json
```

## Scenario C: with `--upgrade-height`, node already crashed

Cosmovisor switched to v1.6.0, node crashed with:
```
ERRO !! Fatal error occurred, app died unexpectedly !!
  err="create app: load app: failed to load latest version:
  version of store dkg mismatch root store's version;
  expected <N> got 0; new stores should be added using StoreUpgrades"
```

Recovery:

1. Stop the node
```bash
sudo systemctl stop cosmovisor
```

2. Find the previous working binary and point cosmovisor back to it
```bash
# List all available binaries (ignore v1.6.0):
ls -d ~/.story/story/cosmovisor/upgrades/*/

# Point current to the most recent one that is NOT v1.6.0:
rm -f ~/.story/story/cosmovisor/current
ln -s ~/.story/story/cosmovisor/upgrades/<previous-upgrade-name> ~/.story/story/cosmovisor/current
```

3. Remove v1.6.0 artifacts
```bash
rm -rf ~/.story/story/cosmovisor/upgrades/v1.6.0/
rm -f ~/.story/story/data/upgrade-info.json
```

4. Restart
```bash
sudo systemctl start cosmovisor
```

No data lost — v1.6.0 crashes before committing any blocks, so the previous binary picks up cleanly.

---

## Scenario D: Planned upgrade but some validators didn't deploy binary

After `planUpgrade` is executed, the chain halts at the scheduled upgrade height. Validators that deployed the binary upgrade successfully, but those that didn't will crash loop.

### What you'll see

```
ERRO UPGRADE "v1.6.0" NEEDED at height: <upgrade_height>  module=x/upgrade
ERRO CONSENSUS FAILURE!!!  err="failed to apply block"
Error: binary not present, downloading disabled:
  stat .../cosmovisor/upgrades/v1.6.0/bin/story: no such file or directory
cosmovisor.service: Failed with result 'exit-code'
Scheduled restart job, restart counter is at 1
```

Cosmovisor crash-loops every ~3s trying to start the old binary, which panics at the upgrade height each time.

### Impact

If less than 2/3 of total voting power has upgraded, the network stalls — upgraded validators can't reach consensus alone.

### Recovery

```bash
# On each unprepared validator — just deploy the binary:
cosmovisor add-upgrade v1.6.0 /path/to/story-v1.6.0

# No manual restart needed — cosmovisor is already crash-looping
# and will pick up the binary on next restart cycle (~3s)
```

The network resumes as soon as 2/3+ voting power is running the new binary.

---

## Scenario E: Corrupted or missing upgrade-info.json

After `planUpgrade`, verify the file:
```bash
cat ~/.story/story/data/upgrade-info.json | jq .
```

If missing or invalid JSON, manually write it as the same user that runs cosmovisor:
```bash
# Run as the cosmovisor service user (not root), or fix ownership after:
echo '{"name":"v1.6.0","height":<upgrade_height>}' > ~/.story/story/data/upgrade-info.json

# If created as root, fix ownership to match the cosmovisor service user:
chown <service_user>:<service_group> ~/.story/story/data/upgrade-info.json
```

Without this file, cosmovisor won't switch the binary automatically. The SDK will attempt to rewrite it at halt height, but if that also fails, manual intervention is needed.

---

## Emergency Upgrade Cancellation

If `planUpgrade` has been submitted on-chain and needs to be cancelled before the halt height:

1. Submit `cancelUpgrade()` via TimelockController
2. **Manually delete `upgrade-info.json` on every node**:
```bash
rm -f ~/.story/story/data/upgrade-info.json
```

`cancelUpgrade` only clears the on-chain pending state. It does **not** delete `upgrade-info.json` from disk ([#757](https://github.com/piplabs/story/issues/757)). Without step 2, cosmovisor will still switch the binary at the originally planned height and the node will crash.
