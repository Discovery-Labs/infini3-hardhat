// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AdventurerSFT
 * @author dCompass
 */

contract AdventurerSFT is ERC1155, Ownable {
    uint256 public tokenIdCounter;
    address projectNFTAddr;
    address dCompTokenAddr;

    struct AdventurerTokenInfo {
        //project Id for this token
        string projectId;
        //allow for different versions (0 is assumed to be base version and free of charge)
        uint32 version;
        //price in Dcomp for this NFT
        uint112 priceInDComp;
        //cap for maxAllowed...0 is assumed to mean uncapped
        uint112 maximumCap;
    }

    mapping(string => mapping (uint => uint)) public optionTokenIdByProjectIdAndVersion;

    mapping(uint256 => AdventurerTokenInfo) public adventurerTokenInfoByTokenId;

    constructor(address _projectNFTAddr, address _dCompTokenAddr) ERC1155("https://<dCompassURIBase>/{id}.json") {
        projectNFTAddr = _projectNFTAddr;
        dCompTokenAddr = _dCompTokenAddr;
    }

    function upsertAdventurerNFT
    (
        string memory _projectId,
        uint256 _version,
        uint256 _price,
        uint256 _maxCap
    ) external{
        require(msg.sender == projectNFTAddr, "ADVENTURER_SFT: ONLY_PROJECT");
        uint tokenId = optionTokenIdByProjectIdAndVersion[_projectId][version];
        if(tokenId == 0){
            tokenIdCounter++;
            tokenId = tokenIdCounter;
            optionTokenIdByProjectIdAndVersion[_projectId][_version] = tokenId;
        }
        AdventurerTokenInfo storage adventureTokenInfo = adventurerTokenInfoByTokenId[tokenId];
        adventurerTokenInfo.projectId = _projectId;
        adventurerTokenInfo.version = _version;
        adventurerTokenInfo.priceInDComp = _price;
        adventurerTokenInfo.maximumCap = _maxCap;
    }
}