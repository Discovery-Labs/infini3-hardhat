// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestToken
 **/

contract TestToken is ERC20 {
    address public owner;
    mapping(address => bool) public approvedMinters; 

    constructor(
        string memory name,
        string memory symbol,
        address[] memory initialMinters
    ) ERC20(name, symbol) {
        owner = msg.sender;
        uint length = initialMinters.length;
        for(uint i = 0; i<length; i++){
            approvedMinters[initialMinters[i]] = true;
        }
    }

    function mint(address to, uint256 amount) external {
        require(approvedMinters[msg.sender], "NOT_ON_WHITELIST");
        _mint(to, amount);
    }

    function toggleMinter(address target) external {
        require(msg.sender == owner, "ONLY_OWNER");
        approvedMinters[target] = !approvedMinters[target];
    }
}