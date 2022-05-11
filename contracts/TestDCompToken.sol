// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestToken
 **/

contract TestToken is ERC20, Ownable {
    address public owner;
    address public projectNFTAddress;
    mapping (address => bool) public approvedMinters;
    mapping (string => uint) public projectBalance;

    constructor(
        address _projectNFTAddress
    ) ERC20("DCompToken", "DCOMPXP") {
        projectNFTAddress = _projectNFTAddress;
    }

    function mint(address to, uint256 amount, string memory _projectId) external {
        require(msg.sender == projectNFTAddress, "DCOMPTOKEN: ONLY_PROJECTNFT");
        projectBalance[_projectId] += amount;
        _mint(to, amount);
    }
}