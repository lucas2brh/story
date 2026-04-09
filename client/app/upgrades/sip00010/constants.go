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
	// NewMinStakeAmount is 32 IP in wei (32 * 10^18).
	NewMinStakeAmount = "32000000000000000000"
	// NewMinUnstakeAmount is 32 IP in wei.
	NewMinUnstakeAmount = "32000000000000000000"
	// NewFee is 0.1 IP in wei (10^17).
	NewFee = "100000000000000000"
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
