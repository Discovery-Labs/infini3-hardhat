// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AdventurerSFT
 * @author dCompass
 */

contract AdventurerSFT is ERC1155, Ownable {
    using SafeERC20 for IERC20;

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

    mapping(uint => uint) public totalSupplyPerTokenId;

    mapping(uint256 => AdventurerTokenInfo) public adventurerTokenInfoByTokenId;

    constructor(address _dCompTokenAddr) ERC1155("https://<dCompassURIBase>/{id}.json") {
        dCompTokenAddr = _dCompTokenAddr;
    }

    function upsertAdventurerNFT
    (
        string memory _projectId,
        uint256 _version,
        uint256 _price,
        uint256 _maxCap
    ) external{
        //require(msg.sender == projectNFTAddr, "ADVENTURER_SFT: ONLY_PROJECT");
        uint tokenId = optionTokenIdByProjectIdAndVersion[_projectId][_version];
        if(tokenId == 0){
            tokenIdCounter++;
            tokenId = tokenIdCounter;
            optionTokenIdByProjectIdAndVersion[_projectId][_version] = tokenId;
        }
        AdventurerTokenInfo storage adventurerTokenInfo = adventurerTokenInfoByTokenId[tokenId];
        adventurerTokenInfo.projectId = _projectId;
        adventurerTokenInfo.version = uint32(_version);
        adventurerTokenInfo.priceInDComp = uint112(_price);
        adventurerTokenInfo.maximumCap = uint112(_maxCap);
    }

    function mint(
        address _to,
        string memory _projectId,
        uint256 _version
    ) external{
        //require(msg.sender == projectNFTAddr, "ADVENTURER_SFT: ONLY_PROJECT");
        uint tokenId = optionTokenIdByProjectIdAndVersion[_projectId][_version];
        require(tokenId > 0, "ADVENTURER_SFT: INVALID_TOKEN_ID");
        require(balanceOf(_to, tokenId) == 0, "ADVENTURER_SFT: DUPLICATE_MINT");
        uint currentSupply = totalSupplyPerTokenId[tokenId];
        AdventurerTokenInfo memory adventureTokenInfo = adventurerTokenInfoByTokenId[tokenId]; 
        require(adventureTokenInfo.maximumCap == 0 || currentSupply < adventureTokenInfo.maximumCap, "ADVENTURER_SFT: CAP_REACHED");
        totalSupplyPerTokenId[tokenId]++;
        //possibly have specialized transfer function from this contract for dComp token to avoid approval?
        if(adventureTokenInfo.priceInDComp > 0){
            IERC20(dCompTokenAddr).safeTransferFrom(_to, address(this), adventureTokenInfo.priceInDComp);
        }
        _mint(_to, tokenId, 1, "");
    }

    function completionCheck(address _user, string memory _projectId, uint256 version) external view returns(bool) {
        uint tokenId = optionTokenIdByProjectIdAndVersion[_projectId][version];
        if(tokenId == 0){
            return false;
        }
        if(balanceOf(_user, tokenId) == 0){
            return false;
        }
        return true;

    }
}