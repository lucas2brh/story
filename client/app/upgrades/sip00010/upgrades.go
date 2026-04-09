package sip00010

import (
	"context"

	upgradetypes "cosmossdk.io/x/upgrade/types"

	"github.com/cosmos/cosmos-sdk/types/module"

	"github.com/piplabs/story/client/app/keepers"
	"github.com/piplabs/story/lib/errors"
	"github.com/piplabs/story/lib/log"
)

func CreateUpgradeHandler(
	_ *module.Manager,
	_ module.Configurator,
	keepers *keepers.Keepers,
) upgradetypes.UpgradeHandler {
	return func(ctx context.Context, _ upgradetypes.Plan, vm module.VersionMap) (module.VersionMap, error) {
		if err := runSIP00010Upgrade(ctx, keepers); err != nil {
			return vm, err
		}

		return vm, nil
	}
}

func runSIP00010Upgrade(ctx context.Context, keepers *keepers.Keepers) error {
	log.Info(ctx, "Start SIP-00010 upgrade")

	// --------------------------------
	// Update evmstaking params: minPartialWithdrawalAmount 8 IP → 1 IP
	// --------------------------------
	log.Info(ctx, "Updating evmstaking minPartialWithdrawalAmount...")

	evmstakingParams, err := keepers.EvmStakingKeeper.GetParams(ctx)
	if err != nil {
		return errors.Wrap(err, "get evmstaking params")
	}

	evmstakingParams.MinPartialWithdrawalAmount = NewMinPartialWithdrawalAmount

	if err := keepers.EvmStakingKeeper.SetParams(ctx, evmstakingParams); err != nil {
		return errors.Wrap(err, "set evmstaking params")
	}

	// Verify
	updatedParams, err := keepers.EvmStakingKeeper.GetParams(ctx)
	if err != nil {
		return errors.Wrap(err, "reload evmstaking params")
	}

	if updatedParams.MinPartialWithdrawalAmount != NewMinPartialWithdrawalAmount {
		return errors.New("minPartialWithdrawalAmount not updated",
			"expected", NewMinPartialWithdrawalAmount,
			"actual", updatedParams.MinPartialWithdrawalAmount,
		)
	}

	log.Info(ctx, "Updated minPartialWithdrawalAmount", "new_value", NewMinPartialWithdrawalAmount)

	log.Info(ctx, "SIP-00010 upgrade complete",
		"minPartialWithdrawalAmount", NewMinPartialWithdrawalAmount,
	)

	return nil
}
