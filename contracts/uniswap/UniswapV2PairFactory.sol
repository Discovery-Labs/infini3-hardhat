//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
//import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract UniswapV2PairFactory is IUniswapV2Factory {
    address public uniswapV2PairImplementation;
    address public sponsorSFTAddress;
    address public dCompTokenAddress;
    address public override feeTo;
    address public override feeToSetter;

    //projectId maps to address for pool
    mapping(string => address) public override getPoolByProject;
    address[] public override allPools;

    constructor(address _uniswapV2PairImplementation, address _feeToSetter, address _sponsorSFTAddress, address _dCompTokenAddress) public {
        require(_uniswapV2PairImplementation != address(0) && _sponsorSFTAddress!= address(0) && _dCompTokenAddress != address(0));
        uniswapV2PairImplementation = _uniswapV2PairImplementation;
        feeToSetter = _feeToSetter;
        sponsorSFTAddress = _sponsorSFTAddress;
        dCompTokenAddress = _dCompTokenAddress;
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenB, string memory projectId) external override returns (address pair) {
        require(msg.sender == sponsorSFTAddress, "UniswapDComp: ONLY_SPONSOR_SFT");
        require(tokenB != address(0), "UniswapDComp: ZERO_ADDRESS");
        address tokenA = dCompTokenAddress;
        require(tokenA != tokenB, "UniswapDComp: IDENTICAL_ADDRESSES");
        require(getPoolByProject[projectId] == address(0), "UniswapDComp: POOL_EXISTS");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, projectId));
        pair = Clones.cloneDeterministic(uniswapV2PairImplementation, salt);
        IUniswapV2Pair(pair).initialize(sponsorSFTAddress, token0, token1, projectId);
        getPoolByProject[projectId] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "UniswapDComp: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "UniswapDComp: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}