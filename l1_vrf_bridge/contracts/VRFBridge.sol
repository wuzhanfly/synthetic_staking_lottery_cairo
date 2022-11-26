// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;


import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";


interface IStarknetCore {
    /**
      Sends a message to an L2 contract.
      Returns the hash of the message.
    */
    function sendMessageToL2(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload
    ) external returns (bytes32);

    /**
      Consumes a message that was sent from an L2 contract.
      Returns the hash of the message.
    */
    function consumeMessageFromL2(uint256 fromAddress, uint256[] calldata payload)
        external
        returns (bytes32);
}

contract Random is VRFConsumerBaseV2 {
   
   IStarknetCore starknetCore = IStarknetCore(0xde29d060D45901Fb19ED6C6e959EB22d8626708e);

  //calculate with get_selector_from_name when you deploy
   uint256 constant DISTRIBUTE_WITH_RANDOM_SELECTOR = 11111111;

   uint256 l2ContractAddress; 

   VRFCoordinatorV2Interface COORDINATOR;

  // Your subscription ID.
  uint64 s_subscriptionId;

  // Goerli coordinator. For other networks,
  // see https://docs.chain.link/docs/vrf-contracts/#configurations
  address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;

  // The gas lane to use, which specifies the maximum gas price to bump to.
  // For a list of available gas lanes on each network,
  // see https://docs.chain.link/docs/vrf-contracts/#configurations
  bytes32 keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

  // Depends on the number of requested values that you want sent to the
  // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
  // so 100,000 is a safe default for this example contract. Test and adjust
  // this limit based on the network that you select, the size of the request,
  // and the processing of the callback request in the fulfillRandomWords()
  // function.
  uint32 callbackGasLimit = 100000;

  // The default is 3, but you can set this higher.
  uint16 requestConfirmations = 3;

  // For this example, retrieve 2 random values in one request.
  // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
  uint32 numWords =  2;

  uint256[] public s_randomWords;
  uint256 public s_requestId;
  address s_owner;

  constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    s_owner = msg.sender;
    s_subscriptionId = subscriptionId;
  }

    function requestRandomWords() external onlyOwner {
    // Will revert if subscription is not set and funded.
    s_requestId = COORDINATOR.requestRandomWords(
      keyHash,
      s_subscriptionId,
      requestConfirmations,
      callbackGasLimit,
      numWords
    );
  }
    // Assigned at request from L2
    uint256 rangeLimit;
    uint256 q_or_n;

    function fulfillRandomWords(
    uint256, /* requestId */
    uint256[] memory randomWords
    ) internal override {
        // Assuming only one random word was requested. interval -> 1 - range limit
        random_number = (randomWords[0] % rangeLimit) + 1;
        
        // Construct the deposit message's payload.
        uint256[] memory payload = new uint256[](2);
        payload[0] = random_number;
        payload[1] = q_or_n;

        // Send the message to the StarkNet core contract.
        starknetCore.sendMessageToL2{value: msg.value}(l2ContractAddress, DISTRIBUTE_WITH_RANDOM_SELECTOR, payload);
    }       

    modifier onlyOwner() {
        require(msg.sender == s_owner);
    _;
    }

    function requestRandomFromL2(uint _rangeLimit, uint _q_or_n ) external onlyOwner {
        uint256[] memory payload = new uint256[](3);
        payload[0] = REQUEST_RANDOM;
        payload[1] = _rangeLimit;
        payload[2] = q_or_n;

        starknetCore.consumeMessageFromL2(l2ContractAddress, payload);
        rangeLimit = _rangeLimit;
        q_or_n = _q_or_n;
        requestRandomWords();

    }

    function changeL2ContractAddress(uint256 _l2ContractAddress) external onlyOwner {
      l2ContractAddress = _l2ContractAddress;
    }
}