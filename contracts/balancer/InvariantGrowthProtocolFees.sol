pragma solidity ^0.8.4;

//import "./BaseWeightedPool.sol";
import "@balancer-labs/v2-pool-weighted/contracts/BaseWeightedPool.sol";

abstract contract InvariantGrowthProtocolFees is BaseWeightedPool {
    using FixedPoint for uint256;

    // This Pool pays protocol fees by measuring the growth of the invariant between joins and exits. Since weights are
    // immutable, the invariant only changes due to accumulated swap fees, which saves gas by freeing the Pool
    // from performing any computation or accounting associated with protocol fees during swaps.
    // This mechanism requires keeping track of the invariant after the last join or exit.
    uint256 private _lastPostJoinExitInvariant;

    /**
     * @dev Returns the value of the invariant after the last join or exit operation.
     */
    function getLastInvariant() public view returns (uint256) {
        return _lastPostJoinExitInvariant;
    }

    function _beforeJoinExit(
        uint256[] memory preBalances,
        uint256[] memory normalizedWeights,
        uint256 protocolSwapFeePercentage
    ) internal virtual override {
        // Before joins and exits, we measure the growth of the invariant compared to the invariant after the last join
        // or exit, which will have been caused by swap fees, and use it to mint BPT as protocol fees. This dilutes all
        // LPs, which means that new LPs will join the pool debt-free, and exiting LPs will pay any amounts due
        // before leaving.

        // We return immediately if the fee percentage is zero (to avoid unnecessary computation), or when the pool is
        // paused (to avoid complex computation during emergency withdrawals).
        if ((protocolSwapFeePercentage == 0) || !_isNotPaused()) {
            return;
        }

        uint256 preJoinExitInvariant = WeightedMath._calculateInvariant(normalizedWeights, preBalances);

        uint256 toMint = WeightedMath._calcDueProtocolSwapFeeBptAmount(
            totalSupply(),
            _lastPostJoinExitInvariant,
            preJoinExitInvariant,
            protocolSwapFeePercentage
        );

        _payProtocolFees(toMint);
    }

    function _afterJoinExit(
        bool isJoin,
        uint256[] memory preBalances,
        uint256[] memory balanceDeltas,
        uint256[] memory normalizedWeights
    ) internal virtual override {
        // After all joins and exits we store the post join/exit invariant in order to compute growth due to swap fees
        // in the next one.

        // Compute the post balances by adding or removing the deltas. Note that we're allowed to mutate preBalances.
        for (uint256 i = 0; i < preBalances.length; ++i) {
            // Cannot optimize calls with a function selector: there are 2- and 3-argument versions of SafeMath.sub
            preBalances[i] = isJoin
                ? SafeMath.add(preBalances[i], balanceDeltas[i])
                : SafeMath.sub(preBalances[i], balanceDeltas[i]);
        }

        uint256 postJoinExitInvariant = WeightedMath._calculateInvariant(normalizedWeights, preBalances);
        _lastPostJoinExitInvariant = postJoinExitInvariant;
    }
}