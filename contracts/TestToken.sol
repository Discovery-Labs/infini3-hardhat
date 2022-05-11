// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestToken
 **/

contract TestToken is ERC20 {
    uint8 public decimals;
    address public owner;
    mapping(address => bool) public approvedMinters; 

    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimals,
        address[] memory initialMinters
    ) ERC20(name, symbol) {
        decimals = _decimals;
        owner = msg.sender;
        uint length = initialMinters.length;
        for(uint i = 0; i<length; i++){
            approvedMinters[initialMinters[i]] = true;
        }
    }

    function decimals() public view virtual override returns (uint8) {
        return decimals;
    }

    function mint(address to, uint256 amount) external {
        require(approvedMinters[msg.sender], "NOT_ON_WHITELIST");
        _mint(to, amount);
    }

    function toggleMinter(address target){
        require(msg.sender == owner, "ONLY_OWNER");
        approvedMinters[target] = !approvedMinters[target];
    }
}