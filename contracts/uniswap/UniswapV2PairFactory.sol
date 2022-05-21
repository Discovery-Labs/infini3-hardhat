//SPDX-License-Identifier: Unlicense
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
//import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
//import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2PairFactory.sol";

contract UniswapV2PairFactory is IUniswapV2PairFactory {
    address public uniswapV2PairImplementation;
    address public projectNFTAddress;
    address public sponsorSFTAddress;
    address public dCompTokenAddress;
    address public override feeTo;
    address public override feeToSetter;

    //projectId maps to address for pool
    mapping(string => address) public override getPoolByProject;
    address[] public override allPools;

    constructor(address _uniswapV2PairImplementation, address _feeToSetter, address _projectNFTAddress, address _sponsorSFTAddress, address _dCompTokenAddress) public {
        require(_uniswapV2PairImplementation != address(0) && _projectNFTAddress != address(0) && _sponsorSFTAddress!= address(0) && _dCompTokenAddress != address(0));
        uniswapV2PairImplementation = _uniswapV2PairImplementation;
        feeToSetter = _feeToSetter;
        projectNFTAddress = _projectNFTAddress;
        sponsorSFTAddress = _sponsorSFTAddress;
        dCompTokenAddress = _dCompTokenAddress;
    }

    function allPoolsLength() external view override returns (uint) {
        return allPools.length;
    }

    function createPair(address tokenB, string memory projectId) external override returns (address pair) {
        require(msg.sender == projectNFTAddress, "UniswapDComp: ONLY_PROJECT_NFT");
        require(tokenB != address(0), "UniswapDComp: ZERO_ADDRESS");
        address tokenA = dCompTokenAddress;
        require(tokenA != tokenB, "UniswapDComp: IDENTICAL_ADDRESSES");
        require(getPoolByProject[projectId] == address(0), "UniswapDComp: POOL_EXISTS");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, projectId));
        pair = Clones.cloneDeterministic(uniswapV2PairImplementation, salt);
        IUniswapV2Pair(pair).initialize(projectNFTAddress, token0, token1, projectId);
        getPoolByProject[projectId] = pair;
        allPools.push(pair);
        emit PairCreated(token0, token1, pair, allPools.length);
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