// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestToken
 **/

contract DCompToken is ERC20{
    address public owner;
    address public adventurerSFTAddr;
    mapping (address => bool) public approvedMinters;
    mapping (string => uint) public projectBalance;

    constructor(
    ) ERC20("DCompToken", "DCOMPXP") {
        //projectNFTAddress = _projectNFTAddress;
        //adventurerSFTAddr = _adventurerSFTAddr;
    }

    function mintProject(address to, uint256 amount, string memory _projectId) external {
        //require(msg.sender == projectNFTAddress, "DCOMPTOKEN: ONLY_PROJECTNFT");
        projectBalance[_projectId] += amount;
        _mint(to, amount);
    }

    function mintIndividuals(address to, uint256 amount) external {
        //require(msg.sender == projectNFTAddress, "DCOMPTOKEN: ONLY_PROJECTNFT");
        _mint(to, amount);
    }

    function adventurerTransfer(address to, address from, uint256 amount) external{
        require(msg.sender == adventurerSFTAddr, "only adventurer SFT");
        _transfer(from, to, amount);
    }

    function setAdventurerSFT(address _adventurerSFTAddr) external {
        adventurerSFTAddr = _adventurerSFTAddr;
    }

}