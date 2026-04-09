package sip00010

import (
	storetypes "cosmossdk.io/store/types"

	sdk "github.com/cosmos/cosmos-sdk/types"

	"github.com/piplabs/story/client/app/keepers"
	"github.com/piplabs/story/client/app/upgrades"
	"github.com/piplabs/story/lib/log"
	"github.com/piplabs/story/lib/netconf"
)

const (
	// NewMinPartialWithdrawalAmount is 1 IP in gwei (10^9).
	NewMinPartialWithdrawalAmount uint64 = 1_000_000_000
)

var Upgrade = upgrades.Upgrade{
	UpgradeName:          netconf.SIP00010,
	CreateUpgradeHandler: CreateUpgradeHandler,
	StoreUpgrades:        storetypes.StoreUpgrades{},
}

var Fork = upgrades.Fork{
	UpgradeName:    netconf.SIP00010,
	UpgradeInfo:    "SIP-00010: reduce staking thresholds and fees",
	BeginForkLogic: func(_ sdk.Context, _ *keepers.Keepers) {},
}

func GetUpgradeHeight(ctx sdk.Context) (int64, bool) {
	height, err := netconf.GetUpgradeHeight(ctx.ChainID(), netconf.SIP00010)
	if err != nil {
		log.Error(ctx, "Failed to get upgrade height", err, "chain_id", ctx.ChainID(), "upgrade_name", netconf.SIP00010)
		return 0, false
	}

	return height, true
}
