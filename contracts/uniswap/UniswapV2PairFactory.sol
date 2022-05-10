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

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

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

        address tokenA = dCompTokenAddress;
        require(tokenA != tokenB, "UniswapDComp: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapDComp: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "UniswapDComp: PAIR_EXISTS"); // single check is sufficient
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pair = Clones.cloneDeterministic(uniswapV2PairImplementation, salt);
        IUniswapV2Pair(pair).initialize(sponsorSFTAddress, token0, token1, projectId);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
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