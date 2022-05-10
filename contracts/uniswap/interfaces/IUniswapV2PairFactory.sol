pragma solidity >=0.5.0;

interface IUniswapV2PairFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPoolByProject(string memory projectId) external view returns (address pair);
    function allPools(uint) external view returns (address pair);
    function allPoolsLength() external view returns (uint);

    function createPair(address tokenB, string memory projectId) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}