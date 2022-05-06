pragma solidity ^0.8.4;

import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";

import "@balancer-labs/v2-pool-utils/contracts/factories/BasePoolSplitCodeFactory.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/FactoryWidePauseWindow.sol";

import "./OracleWeightedPool.sol";

contract OracleWeightedPoolFactory is BasePoolSplitCodeFactory, FactoryWidePauseWindow {
    constructor(IVault vault) BasePoolSplitCodeFactory(vault, type(OracleWeightedPool).creationCode) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Deploys a new `OracleWeightedPool`.
     */
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory weights,
        uint256 swapFeePercentage,
        bool oracleEnabled,
        address owner
    ) external returns (address) {
        // TODO: Do not use arrays in the interface for tokens and weights
        (uint256 pauseWindowDuration, uint256 bufferPeriodDuration) = getPauseConfiguration();

        OracleWeightedPool.NewPoolParams memory params = OracleWeightedPool.NewPoolParams({
            vault: getVault(),
            name: name,
            symbol: symbol,
            tokens: tokens,
            normalizedWeight0: weights[0],
            normalizedWeight1: weights[1],
            swapFeePercentage: swapFeePercentage,
            pauseWindowDuration: pauseWindowDuration,
            bufferPeriodDuration: bufferPeriodDuration,
            oracleEnabled: oracleEnabled,
            owner: owner
        });

        return _create(abi.encode(params));
    }
}