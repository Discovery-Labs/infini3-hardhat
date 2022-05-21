// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title dCompassProjectNFT
 * @dev NFTs for creating project
 */

import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {IUniswapV2PairFactory} from './uniswap/interfaces/IUniswapV2PairFactory.sol';

contract ProjectNFT is ERC721URIStorage, Ownable, ReentrancyGuard {
  using Counters for Counters.Counter;
  using SafeERC20 for IERC20;

  Counters.Counter private _tokenIds;
  Counters.Counter private _multiSigRequest;

  //uint public stakeAmount = 0.001 ether;
  mapping(address => bool) public reviewers;
  uint128 public multiSigThreshold; //gives minimum multisig percentage (30 = 30% )
  uint128 public numReviewers; //number of Reviewers. Needed for threshold calculation
  address payable public appWallet; //sign in a script and also withdraw slashed stakes
  address payable appDiamond; //address of the app level diamond
  address payable sponsorSFTAddr; //address of ERC1155 that controls sponsor staking
  address public adventurerSFTAddr; //address of ERC1155 that controls adventurer SFT
  address apiConsumerAddr; //address of chaninlink address
  address factoryAddr; //address of the UniswapV2 Factory
  address dCompTokenAddr; //address of DCompToken
  enum ProjectStatus {
    NONEXISTENT,
    PENDING,
    DENIED,
    APPROVED
  }

  mapping(string => address[]) internal contributors;
  //mapping (string => address[]) internal approvedERC20Addrs;
  mapping(string => address) public projectWallets;
  mapping(string => uint256) public stakePerProject;
  mapping(string => uint256) public refundPerProject;
  mapping(string => uint256) public sponsorLevel;
  mapping(string => uint256) sponsorLevels;
  mapping(uint256 => string) public statusStrings;
  mapping(string => ProjectStatus) public status;
  mapping(string => uint256) public votes; //tally of approved votes;
  mapping(string => uint256) public votesReject; //tally of rejection votes;
  mapping(string => mapping(address => bool)) public reviewerVotes; //vote record of reviewers for ProjectId
  mapping(string => bool) public projectMinted; // tracks if mint has been done
  mapping(string => uint256) public projectThresholds; // threshold for the project contributors to approve pathways
  mapping(string => address) public erc20PoolTokenPerProjectId; //erc20 address used to make pool for projectID

  event NFTProjectMinted(address indexed _to, string indexed _tokenURI, string indexed _questId);
  event ReceiveCalled(address _caller, uint256 _value);
  event ProjectApproved(string indexed _projectId);

  constructor(
    address payable _walletAddress,
    address[] memory _reviewers,
    uint128 _initialThreshold
  ) ERC721('dCompassProject', 'DCOMPROJ') {
    require(_reviewers.length > 0, 'Must have at least 1 reviewer');
    require(_initialThreshold > 0 && _initialThreshold <= 100, 'invalid threshold');
    multiSigThreshold = _initialThreshold;
    appWallet = _walletAddress;
    for (uint256 i = 0; i < _reviewers.length; i++) {
      if (_reviewers[i] != address(0) && !reviewers[_reviewers[i]]) {
        reviewers[_reviewers[i]] = true;
        numReviewers++;
      }
    }
    statusStrings[0] = 'NONEXISTENT';
    statusStrings[1] = 'PENDING';
    statusStrings[2] = 'DENIED';
    statusStrings[3] = 'APPROVED';
    sponsorLevels['SILVER'] = 1;
    sponsorLevels['GOLD'] = 2;
    sponsorLevels['DIAMOND'] = 3;
  }

  modifier onlyReviewer() {
    require(reviewers[_msgSender()], 'not a reviewer');
    _;
  }

  receive() external payable {
    emit ReceiveCalled(msg.sender, msg.value);
  }

  function voteForApproval(
    address[] memory _contributors,
    uint256 _threshold,
    string memory _projectId
  ) public onlyReviewer {
    require(status[_projectId] == ProjectStatus.PENDING, 'status not pending');
    require(!reviewerVotes[_projectId][_msgSender()], 'already voted for this project');
    require(projectWallets[_projectId] != address(0), 'no project wallet');
    votes[_projectId]++;
    reviewerVotes[_projectId][_msgSender()] = true;
    if (votes[_projectId] == 1) {
      require(_contributors.length > 0, 'empty array');
      require(_threshold > 0 && _threshold <= 100, 'invalid threshold');
      //rarities[_projectId] = _rarities;
      contributors[_projectId] = _contributors;
      projectThresholds[_projectId] = _threshold;
      //approvedERC20Addrs[_projectId] = approvedAddrs;
      if ((multiSigThreshold * numReviewers) / 100 == 0) {
        status[_projectId] = ProjectStatus.APPROVED;
        (bool success, ) = appWallet.call{value: stakePerProject[_projectId]}('');
        require(success, 'transfer failed');
        emit ProjectApproved(_projectId);
        //approveMint(_projectId);
      }
    } else {
      uint256 minVotes = (multiSigThreshold * numReviewers) / 100;
      if (minVotes * 100 < multiSigThreshold * numReviewers) {
        minVotes++;
      }
      if (votes[_projectId] >= minVotes) {
        status[_projectId] = ProjectStatus.APPROVED;
        (bool success, ) = appWallet.call{value: stakePerProject[_projectId]}('');
        require(success, 'transfer failed');
        emit ProjectApproved(_projectId);
        //approveMint(_projectId);
      }
    }
  }

  function voteForRejection(string memory _projectId) public onlyReviewer {
    require(status[_projectId] == ProjectStatus.PENDING, 'project not pending');
    require(!reviewerVotes[_projectId][_msgSender()], 'already voted for this project');
    votesReject[_projectId]++;
    reviewerVotes[_projectId][_msgSender()] = true;
    uint256 minVotes = (multiSigThreshold * numReviewers) / 100;
    if (minVotes * 100 < multiSigThreshold * numReviewers) {
      minVotes++;
    }
    if (votesReject[_projectId] >= minVotes) {
      status[_projectId] = ProjectStatus.DENIED;
      (bool success, ) = payable(projectWallets[_projectId]).call{value: stakePerProject[_projectId]}('');
      require(success, 'transfer failed');
    }
  }

  function createToken(
    uint32[] memory firstURIParts,
    uint256[] memory secondURIParts,
    string memory _projectId,
    uint256[] memory versions,
    uint256[] memory prices,
    uint256[] memory maxCaps,
    address _ERC20AddressPool
  ) public onlyReviewer returns (uint256[] memory) {
    require(status[_projectId] == ProjectStatus.APPROVED, 'job not approved yet');
    require(!projectMinted[_projectId], 'already minted');
    require(firstURIParts.length == secondURIParts.length && firstURIParts.length == contributors[_projectId].length, 'incorrect arrs');
    require(versions.length > 0 && versions.length == prices.length && versions.length == maxCaps.length, 'incorrect arrs');
    require(_ERC20AddressPool != address(0));
    //batch minting
    uint256[] memory newItems = new uint256[](contributors[_projectId].length);
    uint256 newItemId;
    string memory _tokenURI;
    bytes memory data;

    for (uint256 i = 0; i < contributors[_projectId].length; i++) {
      _tokenIds.increment();
      newItemId = _tokenIds.current();
      _tokenURI = string(abi.encodePacked('ipfs://f', uint32tohexstr(firstURIParts[i]), uint256tohexstr(secondURIParts[i])));

      _mint(contributors[_projectId][i], newItemId);
      _setTokenURI(newItemId, _tokenURI);

      emit NFTProjectMinted(contributors[_projectId][i], _tokenURI, _projectId);
    }
    projectMinted[_projectId] = true;

    erc20PoolTokenPerProjectId[_projectId] = _ERC20AddressPool;

    //set the approval within app Diamond contract
    (bool success, ) = appDiamond.call(abi.encodeWithSelector(bytes4(keccak256('setApproved(string)')), _projectId));
    require(success, 'diamond approval failed');

    //mint SFT here
    (success, ) = sponsorSFTAddr.call(
      abi.encodeWithSelector(bytes4(keccak256('mint(uint256,address,string)')), sponsorLevel[_projectId], projectWallets[_projectId], _projectId)
    );
    require(success, 'sponsor mint failed');

    //mint all adventurer SFT versions here
    for (uint256 i = 0; i < versions.length; i++) {
      (success, ) = adventurerSFTAddr.call(
        abi.encodeWithSelector(bytes4(keccak256('upsertAdventurerNFT(string,uint256,uint256,uint256)')), _projectId, versions[i], prices[i], maxCaps[i])
      );
      require(success, 'adventurer mint failed');
    }

    (success, data) = appDiamond.call(
      abi.encodeWithSelector(bytes4(keccak256('checkApprovedERC20PerProjectByChain(string,uint256,address)')), _projectId, block.chainid, _ERC20AddressPool)
    );
    require(success);
    success = abi.decode(data, (bool));
    require(success, 'ERC20 not approved');

    //create pool here
    IUniswapV2PairFactory(factoryAddr).createPair(_ERC20AddressPool, _projectId);

    (success, ) = apiConsumerAddr.call(abi.encodeWithSelector(bytes4(keccak256('requestPriceData(address,string)')), _ERC20AddressPool, _projectId));
    require(success);

    return newItems;
  }

  function addProjectWallet(
    string memory _projectId,
    address _projectWallet,
    string memory level
  ) external payable {
    require(projectWallets[_projectId] == address(0), 'already project wallet');
    //require(status[_projectId] == ProjectStatus.NONEXISTENT);
    uint256 pendingSponsorLevel = sponsorLevels[level];
    require(pendingSponsorLevel > 0, 'invalid sponsor stake');
    (bool success, bytes memory data) = sponsorSFTAddr.call(abi.encodeWithSelector(bytes4(keccak256('stakeAmounts(uint256)')), pendingSponsorLevel));
    require(success);
    uint256 stakeAmount = abi.decode(data, (uint256));
    require(msg.value == stakeAmount, 'not enough staked');
    /*(success, data) = sponsorSFTAddr.call(abi.encodeWithSelector(bytes4(keccak256("isAddrOwner(address)")), _projectWallet));
        require(success);
        bool isActive = abi.decode(data, (bool));
        require(!isActive, "address already linked with active project");*/
    // require(_ERC20Address != address(0));
    //     (success, data) = appDiamond.call(abi.encodeWithSelector(bytes4(keccak256("checkApprovedERC20PerProjectByChain(string,uint256,address)")), projectIdforPathway[_pathwayId],block.chainid, _ERC20Address));
    //     require(success);
    //     success = abi.decode(data, (bool));
    //     require(success, "ERC20 not approved");
    //     IERC20(_ERC20Address).transferFrom(_msgSender(), appWallet, appPortion);
    //     IERC20(_ERC20Address).transferFrom(_msgSender(), address(this), amount + creatorPortion);
    //     IERC20(_ERC20Address).transfer(creator[_pathwayId], creatorPortion);
    //     erc20Amounts[_pathwayId][_ERC20Address] += amount;
    projectWallets[_projectId] = _projectWallet;
    stakePerProject[_projectId] = stakeAmount;
    sponsorLevel[_projectId] = pendingSponsorLevel;
    status[_projectId] = ProjectStatus.PENDING;
  }

  function addProjectERC20PoolFund(
    string memory _projectId,
    address _ERC20Address,
    uint256 amount
  ) external onlyReviewer {
    (bool success, bytes memory data) = appDiamond.call(
      abi.encodeWithSelector(bytes4(keccak256('checkApprovedERC20PerProjectByChain(string,uint256,address)')), _projectId, block.chainid, _ERC20Address)
    );
    require(success);
    success = abi.decode(data, (bool));
    require(success, 'not approved ERC20Addr');
    IERC20(_ERC20Address).transferFrom(_msgSender(), sponsorSFTAddr, amount);
  }

  function changeProjectWallet(string memory _projectId, address newAddr) external {
    require(_msgSender() == sponsorSFTAddr, 'ProjectNFT: wrong caller');
    require(projectWallets[_projectId] != address(0), 'no project wallet');
    projectWallets[_projectId] = newAddr;
  }

  function projectRefund(string memory _projectId) external payable {
    require(status[_projectId] == ProjectStatus.PENDING || status[_projectId] == ProjectStatus.APPROVED, 'incorrect status');
    require(_msgSender() == appWallet, 'wrong sender'); //multiSig Wallet of app
    refundPerProject[_projectId] += msg.value;
  }

  function updateSponsorLevel(string memory _projectId, string memory newLevel) external payable nonReentrant {
    require(status[_projectId] == ProjectStatus.PENDING || status[_projectId] == ProjectStatus.APPROVED, 'incorrect status');
    require(_msgSender() == projectWallets[_projectId], 'wrong sender');
    uint256 newSponsorLevel = sponsorLevels[newLevel];
    require(newSponsorLevel > 0, 'invalid level');
    (bool success, bytes memory data) = sponsorSFTAddr.call(abi.encodeWithSelector(bytes4(keccak256('stakeAmounts(uint256)')), newSponsorLevel));
    require(success);
    uint256 stakeAmount = abi.decode(data, (uint256));
    uint256 pastAmount = stakePerProject[_projectId];
    uint256 currLevel = sponsorLevel[_projectId];
    if (currLevel == newSponsorLevel) {
      if (status[_projectId] == ProjectStatus.PENDING) {
        if (stakeAmount < pastAmount) {
          stakePerProject[_projectId] = stakeAmount;
          (success, ) = payable(_msgSender()).call{value: pastAmount - stakeAmount}('');
          require(success, 'failed refund');
        }
      } else {
        stakePerProject[_projectId] = stakeAmount;
        uint256 refund = refundPerProject[_projectId];
        delete refundPerProject[_projectId];
        (success, ) = payable(_msgSender()).call{value: refund}('');
        require(success, 'failed refund');
      }
      return;
    }
    stakePerProject[_projectId] = stakeAmount;
    sponsorLevel[_projectId] = newSponsorLevel;
    if (stakeAmount <= pastAmount) {
      if (status[_projectId] == ProjectStatus.PENDING) {
        (success, ) = payable(_msgSender()).call{value: pastAmount - stakeAmount}('');
        require(success, 'failed refund');
      } else {
        uint256 refund = refundPerProject[_projectId];
        delete refundPerProject[_projectId];
        (success, ) = payable(_msgSender()).call{value: refund}('');
        require(success, 'failed refund');
      }
    } else {
      require(msg.value >= stakeAmount - pastAmount, 'insufficent funds for new level');
      if (msg.value > stakeAmount - pastAmount) {
        (success, ) = payable(_msgSender()).call{value: msg.value + pastAmount - stakeAmount}('');
        require(success, 'failed refund');
      }
    }
    if (projectMinted[_projectId]) {
      (success, data) = sponsorSFTAddr.call(
        abi.encodeWithSelector(
          bytes4(keccak256('updateLevel(uint256,address,string,uint256)')),
          currLevel,
          projectWallets[_projectId],
          _projectId,
          newSponsorLevel
        )
      );
      require(success);
    }
    // stakePerProject[_projectId] = stakeAmount;
    // sponsorLevel[_projectId] = newSponsorLevel;
  }

  function addInitLiquidity(string memory _projectId, uint256 prices) external {
    require(msg.sender == apiConsumerAddr, 'only api consumer');
    address erc20PoolToken = erc20PoolTokenPerProjectId[_projectId];
    uint256 ethPriceOfPoolToken = (prices % 100000000);
    uint256 halfAmountForPool = stakePerProject[_projectId] / (2 * ethPriceOfPoolToken);
    uint256 amountOfDCompToken = halfAmountForPool * (prices / 1000000000);

    bytes memory data;
    (bool success, ) = dCompTokenAddr.call(
      abi.encodeWithSelector(bytes4(keccak256('mint(address,uint256,string)')), address(this), amountOfDCompToken, _projectId)
    );
    require(success);

    IERC20(erc20PoolToken).transferFrom(projectWallets[_projectId], address(this), halfAmountForPool);

    //get pool address
    (success, data) = factoryAddr.call(abi.encodeWithSelector(bytes4(keccak256("getPoolByProject(string)")), _projectId));
    require(success);
    address poolAddr = abi.decode(data, (address));

    //add init liquidity to pool...
    (success, data) = poolAddr.call(abi.encodeWithSelector(bytes4(keccak256("mint(string)")), _projectId));
    require(success);

    //sending half pledge back to user to pay for his share of ERC20 tokens
    (success, ) = payable(projectWallets[_projectId]).call{value: stakePerProject[_projectId] / 2}('');
    require(success);
  }

  function addReviewer(address _reviewer) public onlyReviewer {
    require(!reviewers[_reviewer], 'already reviewer');
    reviewers[_reviewer] = true;
    numReviewers++;
  }

  function setStatusString(uint256 index, string memory newName) external onlyReviewer {
    statusStrings[index] = newName;
  }

  function addProjectContributor(string memory _projectId, address newContributor) external {
    require(status[_projectId] != ProjectStatus.NONEXISTENT, "project doesn't exist");
    require(!projectMinted[_projectId], 'project already minted');
    bool isAllowed = reviewers[_msgSender()];
    bool notContributor = true;
    address[] memory currContributors = contributors[_projectId];
    for (uint256 i = 0; i < currContributors.length; i++) {
      if (!isAllowed && _msgSender() == currContributors[i]) {
        isAllowed = true;
      }
      if (newContributor == currContributors[i]) {
        notContributor = false;
      }
    }
    require(isAllowed, 'must be a project contributor or reviewer');
    require(notContributor, 'already a contributor on project');
    contributors[_projectId].push(newContributor);
  }

  function setThreshold(uint128 _newThreshold) public onlyReviewer {
    require(_newThreshold > 0 && _newThreshold <= 100, 'invalid threshold');
    multiSigThreshold = _newThreshold;
  }

  //helpers for building URIs
  function uint8tohexchar(uint8 i) internal pure returns (uint8) {
    return
      (i > 9)
        ? (i + 87) // ascii a-f
        : (i + 48); // ascii 0-9
  }

  function uint32tohexstr(uint32 i) internal pure returns (string memory) {
    bytes memory o = new bytes(8);
    uint32 mask = 0x0000000f;
    uint256 count = 8;
    while (count > 0) {
      o[count - 1] = bytes1(uint8tohexchar(uint8(i & mask)));
      if (count > 1) {
        i = i >> 4;
      }
      count--;
    }
    return string(o);
  }

  function uint256tohexstr(uint256 i) internal pure returns (string memory) {
    bytes memory o = new bytes(64);
    uint256 mask = 0x0000000000000000000000000000000f;

    uint256 count = 64;
    while (count > 0) {
      o[count - 1] = bytes1(uint8tohexchar(uint8(i & mask)));
      if (count > 1) {
        i = i >> 4;
      }
      count--;
    }
    return string(o);
  }

  function getContributors(string memory _projectId) external view returns (address[] memory) {
    return contributors[_projectId];
  }

  function setAppDiamond(address payable _appDiamond) external onlyReviewer {
    require(_appDiamond != address(0));
    appDiamond = _appDiamond;
  }

  function getAppDiamond() external view returns (address) {
    return appDiamond;
  }

  function setSFTAddr(address payable _SFTAddr) external onlyReviewer {
    require(_SFTAddr != address(0));
    sponsorSFTAddr = _SFTAddr;
  }

  function getSFTAddr() external view returns (address) {
    return sponsorSFTAddr;
  }

  function setAPIConsumerAddr(address _apiConsumerAddr) external onlyReviewer {
    require(_apiConsumerAddr != address(0));
    apiConsumerAddr = _apiConsumerAddr;
    (bool success, ) = sponsorSFTAddr.call(abi.encodeWithSelector(bytes4(keccak256('setAPIConsumerAddr(address)')), _apiConsumerAddr));
    require(success);
  }

  function getAPIConsumerAddr() external view returns (address) {
    return apiConsumerAddr;
  }

  function setdCompTokenAddr(address _dCompTokenAddr) external onlyReviewer {
    require(_dCompTokenAddr != address(0));
    dCompTokenAddr = _dCompTokenAddr;
  }

  function getdCompTokenAddr() external view returns (address) {
    return dCompTokenAddr;
  }

  function setFactoryAddr(address _factoryAddr) external onlyReviewer {
    require(_factoryAddr != address(0));
    factoryAddr = _factoryAddr;
  }

  function getFactoryAddr() external view returns (address) {
    return factoryAddr;
  }

  function setAdventureSFTAddr(address _adventurerSFTAddr) external onlyReviewer {
    require(_adventurerSFTAddr != address(0));
    adventurerSFTAddr = _adventurerSFTAddr;
  }
}