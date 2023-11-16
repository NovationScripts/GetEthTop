// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract GetEthTop {
   // Constants for fund distribution
   uint256 public constant CONTRACT_COMMISSION = 9; // Contract commission percentage
   uint256 public constant PAYOUT_MULTIPLIER = 150; // Payout multiplier
   uint256 public constant REFERRAL_COMMISSION = 1; // Referral commission percentage



   // Contract state variables
   uint256 public contractEarnings; // Total earnings of the contract
   address public owner; // Owner of the contract
   address public externalContractAddress; // External Contract Address
   uint256 public totalReferralEarnings = 0; // Total referral earnings
   uint256 public totalReferralWithdrawals = 0; // Total referral withdrawals



	constructor() {
    owner = msg.sender; // Assign the contract creator as the owner of the contract
     externalContractAddress = address(0); // Initial value - zero address
    // Register the contract owner as the first player in the system
    players[owner].referrer = address(0);
    }



    uint256[] LEVEL_STEPS = [30, 15, 4, 4, 4, 3, 3, 4, 3, 2, 5]; // Steps required for each level, I am working on it



    // Step cost on each level in ether, I am working on it
    uint256[] public STEP_COSTS = [
    0.01 ether,  // Cost of a step on level 1
    0.1 ether,   // Cost of a step on level 2
    0.5 ether,   // Cost of a step on level 3
    1 ether,     // Cost of a step on level 4
    2 ether,     // Cost of a step on level 5
    5 ether,     // Cost of a step on level 6
    10 ether,    // Cost of a step on level 7
    20 ether,    // Cost of a step on level 8
    50 ether,    // Cost of a step on level 9
    100 ether,   // Cost of a step on level 10
    150 ether   // Cost of a step on level 11
    ];
	
	

    // Data structure for a player
    struct Player {
    address referrer; // Address of the player who referred this player
    uint256 referralEarnings; // Amount earned by the player from referrals
    uint256 currentLevel; // Current level of the player in the game
    uint256 deposit; // Amount of ether deposited by the player
    bool isWaiting; // Indicates whether the player is waiting for a payout
    uint256 stepsCompleted;  // Number of steps completed by the player
    bool hasFinished; // Flag to track whether the player has finished the game
    uint256 referralWithdrawals; // Variable added to track the total amount of withdrawals made by referrals
    uint256 lastStepTime; // Timestamp of the player's last step
    uint256 referralsCompletedFirstLevel; // Number of referrals who have completed the first level
    }
	


	// Structure for a queue, I am working on it
    struct Queue {
    address[] queue; // Array of addresses in the queue

    uint256 front;   // Index of the front element in the queue
    uint256 back;    // Index of the back element in the queue
    }



    // Data structure for a level in the game
    struct Level {
    uint256 currentStep; // Current step within the level
    uint256 budget;      // Budget allocated for the level
    Queue playersQueue;  // Queue of players in the level
    }



    // Mapping of player addresses to their data
    mapping(address => Player) public players; 



    // Array representing data for each level in the game
    Level[11] public levels; 



    // Mapping to track total payouts for each player
    mapping(address => uint256) public totalPayouts; 



    // Events for logging actions in the contract
    event Registered(address indexed player, uint256 deposit, uint256 level); // Triggered when a player registers
    event LevelUp(address indexed player, uint256 newLevel); // Triggered when a player moves up a level
    event ReceivedPayment(address indexed player, uint256 amount); // Triggered when a player receives a payment
    event DonationMade(address indexed donor, uint256 amount); // Triggered when a donation is made
    event OwnerWithdrawal(address indexed owner, uint256 withdrawalAmount, uint256 redistributedAmount); // Triggered when the owner withdraws funds
    event ReferralWithdrawal(address indexed referrer, uint256 withdrawalAmount, uint256 redistributedAmount); // Triggered when a referrer withdraws funds
    event ReferralWithdrawalMade(address indexed referrer, uint256 amount); // Triggered when a referrer successfully withdraws referral earnings



    // Function for registering a player
    function register(address _referrer) external {
    // Check to ensure the player is not already registered
    require(players[msg.sender].referrer == address(0), "Player already registered");

    // Check for the presence of a valid referrer in the system who is not the current player
    require(_referrer != address(0) && _referrer != msg.sender, "Invalid referrer");

    // Register the player with the specified referrer
    players[msg.sender].referrer = _referrer;
    }



     // This function allows a player to play by making a step in the game.
    function play() external payable onlyPlayer {
    Player storage player = players[msg.sender];
    // If the player's level is 0, set it to the first level on the first step.
    if (player.currentLevel == 0) {
        player.currentLevel = 1;
    }
    // Add the sent value to the budget of the player's current level.
    levels[player.currentLevel].budget += msg.value;
    // Ensure the sent value matches the step cost for the current level.
    require(msg.value == STEP_COSTS[player.currentLevel], "Incorrect step cost sent");

    // Increment the number of steps completed by the player.
    player.stepsCompleted++;
    
    
    }
    



     // Function for making a deposit
    function makeDeposit(uint256 /* amount */) public payable onlyPlayer {
    Player storage player = players[msg.sender];
    // Ensure the player is not in waiting mode
    require(!player.isWaiting, "Player is in waiting mode");
    // Check if the deposit amount matches the step cost for the player's current level
    require(msg.value == STEP_COSTS[player.currentLevel], "Incorrect deposit for the current level");
    
    // Set a fixed waiting time of 10 hours
    uint256 waitingTime = 10 hours;
    // Ensure the current time is greater than the player's last step time plus waiting time
    require(block.timestamp >= player.lastStepTime + waitingTime, "You must wait to make the next step");
    
    // Update the time of the player's last step
    player.lastStepTime = block.timestamp;

    // If the player is not on the first level, redistribute 1% to the first level's budget
    if(players[msg.sender].currentLevel > 1) {
        uint256 redistributionAmount = msg.value / 100;
        levels[1].budget += redistributionAmount;
    }

    // Calculate the referral fee as 1% of the deposit amount
    uint256 referralFee = msg.value / 100;
    // Calculate the contract commission
    uint256 contractCommission = (msg.value * CONTRACT_COMMISSION) / 100;
    // Accumulate the contract earnings
    contractEarnings += contractCommission;  

    // Increase the player's deposit amount
    player.deposit += msg.value;
    
	// Add the player to the queue of his current level
    uint256 playerLevel = player.currentLevel;
    levels[playerLevel].playersQueue.queue.push(msg.sender);
    levels[playerLevel].playersQueue.back += 1;
    
    // Update the budget of the player's current level
    levels[player.currentLevel].budget += (msg.value - referralFee - contractCommission);
    
    // Retrieve the player's referrer
    address referrer = player.referrer;
    // Ensure there is a referrer assigned to the player
    require(referrer != address(0), "No referrer assigned to player");
    
    // Accumulate the referral fee if the referrer has completed at least 10 steps on the first level
    if (players[referrer].currentLevel == 1 && players[referrer].stepsCompleted >= 10) {
        // The referrer meets the condition, accrue referral rewards
        players[referrer].referralEarnings += referralFee;
    }
    }
	

   
       // Function to check if a player can make the next step
    function canMakeNextStep(address playerAddress) public view returns (bool) {
    Player storage player = players[playerAddress];
    // Set a fixed waiting time of 10 hours
    uint256 requiredWait = 10 hours;
    // Check if the current time is greater than the player's last step time plus the required wait time
    return block.timestamp >= (player.lastStepTime + requiredWait);
    }



    // Function to check if a payout is available for a given player.
    function isPayoutAvailableFor(address playerAddress) public view returns (bool) {
    Player storage player = players[playerAddress];
    // Access the current level data of the player.
    Level storage currentLevel = levels[player.currentLevel];
    
    // Check if the player is in a waiting state and if the level's budget is sufficient 
    // for a payout based on the player's deposit and the payout multiplier.
    if (player.isWaiting && currentLevel.budget >= player.deposit * PAYOUT_MULTIPLIER / 100) {
        return true; // Payout is available.
    }
    return false; // Payout is not available.
    }

    // Function for players to request their payout.
    function requestPayout() external canRequestPayout {
    // Process the payments for the player's current level.
    processPayments(players[msg.sender].currentLevel);
    }

	


    function processPayments(uint256 level) internal onlyPlayer {
    // Loop as long as the budget for the level is enough for the reward, and there are players in the queue.
    while (levels[level].budget > 0 && levels[level].playersQueue.queue.length > 0) {
        // Skip already processed players
        while (levels[level].playersQueue.front < levels[level].playersQueue.queue.length && 
               levels[level].playersQueue.processed[levels[level].playersQueue.front]) {
            levels[level].playersQueue.front += 1;
        }

        // Break if all players in the queue have been processed
        if (levels[level].playersQueue.front >= levels[level].playersQueue.queue.length) {
            break;
        }

        address payable playerAddress = payable(levels[level].playersQueue.queue[levels[level].playersQueue.front]);
        Player storage currentPlayer = players[playerAddress];

        // Calculate the payout based on the player's deposit and the payout multiplier
        uint256 payout = currentPlayer.deposit * PAYOUT_MULTIPLIER / 100;

        // Check if the contract balance can cover the payout
        if (address(this).balance >= payout) {
            // Transfer the payout to the player
            playerAddress.transfer(payout);
            // Record the total payout for the player
            totalPayouts[playerAddress] += payout;
            // Emit an event for the received payment
            emit ReceivedPayment(playerAddress, payout);

            // Adjust the level's budget by subtracting the net payout (minus the original deposit)
            levels[level].budget -= (payout - currentPlayer.deposit);
            // Set the player's waiting status to false
            currentPlayer.isWaiting = false;

            // Move the player to the next level if they have reached the maximum number of steps for their level
            if (currentPlayer.stepsCompleted >= LEVEL_STEPS[currentPlayer.currentLevel]) {
                moveToNextLevel(playerAddress);
            }

            // Mark the player as processed
            levels[level].playersQueue.processed[levels[level].playersQueue.front] = true;
        } else {
            // Exit the loop if the contract balance isn't sufficient for the payout
            break;
        }
    }
    }


    // Function to move a player to the next level.
    function moveToNextLevel(address playerAddress) internal {
    // Retrieve player information from the storage.
    Player storage player = players[playerAddress];
    
    // Check if the player has reached the final level (11th).
    if (player.currentLevel == 11) {
        // Mark the player as having finished the game.
        player.hasFinished = true;
        // Exit the function as the player has completed the game.
        return;
    }
    
    // Increment the player's current level to move to the next level.
    player.currentLevel += 1;
    // Reset the number of steps completed.
    player.stepsCompleted = 0;  

   
    // Emit an event indicating the player has levelled up.
    emit LevelUp(playerAddress, player.currentLevel);

    }



    // Function to withdraw referral earnings
    function withdrawReferralEarnings() external onlyPlayer {
    Player storage player = players[msg.sender];
    uint256 amount = player.referralEarnings;
    // Ensure there are referral earnings to withdraw
    require(amount > 0, "No referral earnings to withdraw");

    // Calculate the amount for redistribution and withdrawal
    uint256 redistributionAmount = amount / 10;
    uint256 withdrawalAmount = amount - redistributionAmount;

    // Allocate 10% to the budget of the first level
    levels[1].budget += redistributionAmount;

    // Record the withdrawal by the referee
    player.referralWithdrawals += withdrawalAmount;
    totalReferralWithdrawals += withdrawalAmount;

    // Decrease the total referral earnings by the withdrawal amount
    totalReferralEarnings -= amount;

    // Reset the player's referral earnings before sending funds
    player.referralEarnings = 0;

    // Log the referral withdrawal event
    emit ReferralWithdrawalMade(msg.sender, withdrawalAmount);

    // Send the remaining 90% to the referrer
    payable(msg.sender).transfer(withdrawalAmount);

    }




    // Function to get data of the current level of a player.
    function getCurrentLevelData() external view returns(Level memory) {
    // Retrieve player data from storage.
    Player storage player = players[msg.sender];
    // Check that the player's current level is valid (between 1 and 11).
    require(player.currentLevel > 0 && player.currentLevel <= 11, "Invalid level");
    // Return level data for the player's current level.
    return levels[player.currentLevel];
    }

    // Function to get the count of players on a specified level.
    function getPlayersCountOnLevel(uint256 _level) external view returns(uint256) {
    // Ensure the specified level is valid (between 1 and 11).
    require(_level > 0 && _level <= 11, "Invalid level");
    // Return the length of the player queue for the specified level.
    return levels[_level].playersQueue.queue.length;
    }

    // Function to get the list of players on a specified level.
    function getPlayersOnLevel(uint256 _level) external view returns(address[] memory) {
    // Ensure the specified level is valid (between 1 and 11).
    require(_level > 0 && _level <= 11, "Invalid level");
    // Return the addresses of players in the queue for the specified level.
    return levels[_level].playersQueue.queue;
    }

    // Function to retrieve specific information about a player.
    function getPlayerInfo(address _playerAddress) external view returns(uint256 level, uint256 stepsCompleted, bool hasFinished) {
    // Retrieve player data from storage.
    Player storage player = players[_playerAddress];
    // Return the player's current level, steps completed, and finish status.
    return (player.currentLevel, player.stepsCompleted, player.hasFinished);
    }


    // Function to get the budgets of all levels.
    function getBudgetsByLevel() public view returns (uint256[] memory) {
    // Initialize an array to store the budgets of each level.
    uint256[] memory budgets = new uint256[](levels.length);
    // Iterate over each level and store its budget in the array.
    for (uint256 i = 0; i < levels.length; i++) {
        budgets[i] = levels[i].budget; // No need for offset, as levels are now 0-indexed.
    }
    // Return the array of budgets.
    return budgets;
    }

    // Function to get the contract commission percentage.
    function getContractEarningsPercentage() public pure returns (uint256) {
    // Return the constant value of the contract commission.
    return CONTRACT_COMMISSION;
    }

    // Function to get the total earnings of the contract.
    function getTotalContractEarnings() public view returns (uint256) {
    // Return the total earnings accumulated by the contract.
    return contractEarnings;
    }

    // Function to get the referral earnings percentage.
    function getReferralEarningsPercentage() public pure returns (uint256) {
    // Return the constant value of the referral commission.
    return REFERRAL_COMMISSION;
    }

     // Function to retrieve a player's referral earnings.
    function getReferralEarnings() public view returns (uint256) {
    // Returns the amount of referral earnings for the message sender.
    return players[msg.sender].referralEarnings;
    }
    
    // Function to get the total referral earnings.
    function getTotalReferralEarnings() public view returns (uint256) {
    // Return the total amount of referral earnings.
    return totalReferralEarnings;
    }

    // Function to get referral earnings by wallet address
    function getReferralEarningsByWallet(address referrer) public view returns (uint256) {
    // Return the referral earnings of the specified referrer address.
    return players[referrer].referralEarnings;
    }

    // Function to get referral withdrawals by wallet address
    function getReferralWithdrawalsByWallet(address referrer) public view returns (uint256) {
    // Return the total amount of referral withdrawals of the specified referrer address.
    return players[referrer].referralWithdrawals;
    }

    // Function to calculate the player's profit
    function getPlayerProfit(address playerAddress) external view returns (int256) {
    // Retrieve the player's data from the mapping
    Player storage player = players[playerAddress];
    
    // Calculate the difference between the total payouts to the player and their deposit
    int256 profit = int256(totalPayouts[playerAddress]) - int256(player.deposit);

    // Return the calculated profit
    return profit;
    }
    
    // Function for donations to the first level
    function donateToFirstLevel() public payable {
    // Ensure the donated amount is greater than zero
    require(msg.value > 0, "Donation must be greater than 0");
    // Only allow players above level 1 to make a donation
    require(players[msg.sender].currentLevel > 1, "Only players above level 1 can donate");

    // Add the donation amount to the budget of the first level
    // Index 1 is used because level numbering starts from 1
    levels[1].budget += msg.value;
    
    // Log the donation event
    emit DonationMade(msg.sender, msg.value);
    }


    // Function for the owner to withdraw earnings
    function withdrawOwnerEarnings() external onlyOwner {
    // Calculate 10% of the contract earnings for redistribution
    uint256 redistributionAmount = contractEarnings / 10;
    // Calculate the amount to be withdrawn by the owner
    uint256 withdrawalAmount = contractEarnings - redistributionAmount;
    
    // Distribute 10% to the budget of the first level
    levels[1].budget += redistributionAmount;
    
    // Reset contract earnings and transfer the withdrawal amount to external contract addres
    contractEarnings = 0;
     (bool sent, ) = externalContractAddress.call{value: withdrawalAmount}("");
        require(sent, "Failed to send Ether");
    
    // Log the event of owner's withdrawal and redistribution
    emit OwnerWithdrawal(owner, withdrawalAmount, redistributionAmount);
    }
    
    // Function for changing the address of an external contract (only for the owner)
    function updateExternalContractAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Invalid address");
        externalContractAddress = _newAddress;
    }

     // Internal function to complete the first level for a referrer
    function completeFirstLevel(address referrer) internal {
    // Increment the count of referrals who have completed the first level for the referrer
    players[referrer].referralsCompletedFirstLevel += 1;
    }

    // Modifier to ensure that only the contract owner can call certain functions
    modifier onlyOwner() {
    // Check that the message sender is the owner of the contract
    require(msg.sender == owner, "Caller is not the owner");
    _; // Continue execution of the function
    }

    // Modifier to ensure that only registered players can call certain functions
    modifier onlyPlayer() {
    // Check that the message sender is a registered player and has not finished the game
    require(players[msg.sender].referrer != address(0), "Not a registered player");
    require(!players[msg.sender].hasFinished, "Player has finished the game");
    _; // Continue execution of the function
    }

   

    // Modifier to check if a payout is available for the calling player
    modifier canRequestPayout() {
    // Check if the player is eligible for a payout
    require(isPayoutAvailableFor(msg.sender), "Payout is not available");
    _; // Continue execution of the function
    }
    }
