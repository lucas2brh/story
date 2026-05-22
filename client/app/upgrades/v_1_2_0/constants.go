//nolint:staticcheck,revive,nolintlint // versioning
package v_1_2_0

import (
	storetypes "cosmossdk.io/store/types"

	sdk "github.com/cosmos/cosmos-sdk/types"

	"github.com/piplabs/story/client/app/keepers"
	"github.com/piplabs/story/client/app/upgrades"
	"github.com/piplabs/story/lib/netconf"
)

const (
	UpgradeName = "v1.2.0"

	// AeneidUpgradeHeight defines the block height at which v1.2.0 upgrade is triggered on Aeneid.
	AeneidUpgradeHeight = 4362990
	// StoryUpgradeHeight defines the block height at which v1.2.0 upgrade is triggered on Mainnet.
	StoryUpgradeHeight = 4477880

	// new max bytes for consensus params.
	newMaxBytes = 104857600 // 100MB (raised from 20MB for trace-bench-100mb test, 2026-05-22)

	// LocalnetUpgradeHeight: low non-zero height so the v1.2.0 cap raise actually
	// applies on story-localnet (default GetUpgradeHeight returns false for it).
	LocalnetUpgradeHeight = 5
)

var Upgrade = upgrades.Upgrade{
	UpgradeName:          UpgradeName,
	CreateUpgradeHandler: CreateUpgradeHandler,
	StoreUpgrades:        storetypes.StoreUpgrades{},
}

var Fork = upgrades.Fork{
	UpgradeName: UpgradeName,
	UpgradeInfo: "upgrade to change the max bytes of block in consensus parameters",
	// UpgradeHeight is set in `scheduleForkUpgrade`
	BeginForkLogic: func(_ sdk.Context, _ *keepers.Keepers) {},
}

func GetUpgradeHeight(chainID string) (int64, bool) {
	switch chainID {
	case netconf.AeneidChainID:
		return AeneidUpgradeHeight, true
	case netconf.StoryChainID:
		return StoryUpgradeHeight, true
	case netconf.StoryLocalnetID:
		// trace-bench-100mb test: apply the cap raise on story-localnet too.
		return LocalnetUpgradeHeight, true
	default:
		return 0, false
	}
}
