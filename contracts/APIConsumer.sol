// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

contract APIConsumer is ChainlinkClient {
    using Chainlink for Chainlink.Request;
    
    address projectNFTAddr;
    address sponsorSFTAddr;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    mapping (bytes32 => string) projectPerRequestId;
    mapping (string => uint256) pricePerProject;
    
    /**
     * Network: Kovan
     * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel   
     * Node)
     * Job ID: d5270d1c311941d0b08bead21fea7747
     * Fee: 0.1 LINK
     */
    constructor(address _projectNFTAddr, address _sponsorSFTAddr) {
        setPublicChainlinkToken();
        oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "d5270d1c311941d0b08bead21fea7747";
        fee = 0.1 * 10 ** 18; // (Varies by network and job)
        projectNFTAddr = _projectNFTAddr;
    }
    
    /**
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function requestPriceData(address tokenAddr, string memory projectId) external returns (bytes32 requestId) 
    {
        require(msg.sender == projectNFTAddr, "API_CONSUMER: INVALID_CALLER");
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get", string(abi.encodePacked("https://adc2ftpvi8.execute-api.us-east-2.amazonaws.com/production/dCompHack/", tokenAddr)));
        
        request.add("path", "price"); // Chainlink nodes 1.0.0 and later support this format
        
        // Multiply the result by 1000000000000000000 to remove decimals
        // int timesAmount = 10**2;
        // request.addInt("times", timesAmount);

        // Sends the request
        requestId = sendChainlinkRequestTo(oracle, request, fee);
        
        projectPerRequestId[requestId] = projectId;        
        // Sends the request
        return requestId;
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId)
    {
        string memory projectId = projectPerRequestId[_requestId];
        pricePerProject[projectId] = _price;
        (bool success, ) = projectNFTAddr.call(abi.encodeWithSelector(bytes4(keccak256("addInitLiquidity(string,uint256)")), projectId, _price));
        require(success);
        //callback add initial liquidity instead of create pool?
    }

    // function withdrawLink() external onlyOwner{

    // }
}
