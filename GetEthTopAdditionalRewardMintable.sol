// SPDX-License-Identifier: MIT
// The contract uses the MIT license.

pragma solidity ^0.8.0;
// Solidity version 0.8.0 or above is required for this contract.

// Interface for mintable ERC20 token standard.
interface IERC20Mintable {
    function mint(address to, uint256 amount) external returns (bool); // Function to mint new tokens.
}

// Interface for the GetEthTop game contract.
interface GetEthTop {
    function getPlayerInfo(address _playerAddress) external view returns (uint256 currentLevel, uint256 stepsCompleted, bool hasFinished); // Function to get player information from the game contract.
}

// Contract for managing additional mintable rewards in the GetEthTop game.
contract GetEthTopAdditionalReward {
    // Event for logging claimed rewards.
    event RewardsClaimed(address indexed player, uint256 totalReward);

    address public owner; // Address of the contract owner.
    GetEthTop public gameContract; // Instance of the GetEthTop game contract.
    IERC20Mintable public rewardToken; // Mintable ERC20 token used for rewards.

    // Array of rewards for each level.
    uint256[] public levelRewards;

    // Mapping to track the last claimed level for each player.
    mapping(address => uint256) public lastClaimedLevel;
    
    // Constructor to initialize the contract with required addresses and rewards.
    constructor(address _gameContractAddress, address _rewardTokenAddress, uint256[] memory _levelRewards) {
        owner = msg.sender; // Set the contract deployer as the owner.
        require(_gameContractAddress != address(0), "Invalid game contract address"); // Ensure a valid game contract address.
        require(_rewardTokenAddress != address(0), "Invalid reward token address"); // Ensure a valid reward token address.

        gameContract = GetEthTop(_gameContractAddress); // Initialize the game contract.
        rewardToken = IERC20Mintable(_rewardTokenAddress); // Initialize the reward token.
        levelRewards = _levelRewards; // Initialize level rewards.
    }
    
    // Modifier to restrict certain functions to the owner only.
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }
    
    // Function to update the game contract address.
    function updateGameContractAddress(address _newGameContractAddress) external onlyOwner {
        require(_newGameContractAddress != address(0), "Invalid address"); // Ensure a valid new address.
        gameContract = GetEthTop(_newGameContractAddress); // Update the game contract address.
    }

    // Function to update the reward token address.
    function updateRewardTokenAddress(address _newRewardTokenAddress) external onlyOwner {
        require(_newRewardTokenAddress != address(0), "Invalid address"); // Ensure a valid new address.
        rewardToken = IERC20Mintable(_newRewardTokenAddress); // Update the reward token address.
    }
    
     // Function for players to claim their rewards.
    function claimRewards() public {
    (uint256 currentLevel, , bool hasFinished) = gameContract.getPlayerInfo(msg.sender); // Get the current level and finished status of the player from the game contract.

    require(currentLevel > lastClaimedLevel[msg.sender] || (currentLevel == lastClaimedLevel[msg.sender] && hasFinished), "No new levels completed or final level not finished"); // Check if the player has completed new levels or finished the final level.

    uint256 totalReward = 0;
    for (uint256 i = lastClaimedLevel[msg.sender] + 1; i <= currentLevel; i++) {
        totalReward += levelRewards[i - 1]; // Calculate total reward for all completed levels.
    }

    if (hasFinished && currentLevel == lastClaimedLevel[msg.sender]) {
        totalReward += levelRewards[currentLevel - 1]; // Include reward for the final level if it's finished and was not previously claimed.
    }

    lastClaimedLevel[msg.sender] = currentLevel; // Update the last claimed level for the player.

    require(rewardToken.mint(msg.sender, totalReward), "Failed to mint rewards"); // Mint the reward for the player.

    emit RewardsClaimed(msg.sender, totalReward); // Emit the reward claimed event.
    }

}
