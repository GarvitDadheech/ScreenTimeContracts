// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ScreenTimeStaking {
    address public owner;

    struct Stake {
        uint256 amount;      // Amount of ETH staked
        uint256 startTime;   // Timestamp when staking started
        uint256 endTime;     // Timestamp when staking ends
        uint256 allowedTime; // Allowed screen time (in seconds)
        bool withdrawn;      // Whether the funds have been withdrawn
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount, uint256 endTime);
    event Withdrawn(address indexed user, uint256 reward, uint256 penalty);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Allows users to stake ETH directly into the contract (callable only by owner).
     * @param user Address of the staker.
     * @param duration Duration (in seconds) for staking.
     * @param allowedTime Allowed screen time (in seconds) during the staking period.
     */
    function stakeETH(address user, uint256 duration, uint256 allowedTime) external payable onlyOwner {
        require(msg.value > 0, "Stake amount must be greater than 0");
        require(stakes[user].amount == 0, "Already staked");

        // Record user's stake details
        stakes[user] = Stake({
            amount: msg.value,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            allowedTime: allowedTime,
            withdrawn: false
        });

        emit Staked(user, msg.value, block.timestamp + duration);
    }

    /**
     * @dev Allows users to withdraw their ETH based on screen time (callable only by owner).
     * @param user Address of the staker.
     * @param screenTime Total screen time used (in seconds).
     */
    function withdraw(address user, uint256 screenTime) external onlyOwner {
        Stake storage userStake = stakes[user];
        require(userStake.amount > 0, "No stake found");
        require(block.timestamp >= userStake.endTime, "Staking period not ended");
        require(!userStake.withdrawn, "Already withdrawn");

        uint256 reward = calculateReward(user, screenTime);
        uint256 penalty = userStake.amount > reward ? userStake.amount - reward : 0;
        userStake.withdrawn = true;

        // Transfer ETH reward to the user
        payable(user).transfer(reward);

        emit Withdrawn(user, reward, penalty);
    }

    /**
     * @dev Calculates the reward or penalty based on screen time.
     * @param user Address of the staker.
     * @param screenTime Total screen time used (in seconds).
     * @return reward Final ETH reward after penalty calculation.
     */
    function calculateReward(address user, uint256 screenTime) public view returns (uint256 reward) {
        Stake memory userStake = stakes[user];
        require(userStake.amount > 0, "No stake found");
        require(block.timestamp >= userStake.endTime, "Staking period not ended");

        uint256 penalty = 0;

        if (screenTime > userStake.allowedTime) {
            uint256 exceededHours = (screenTime - userStake.allowedTime) / 3600; // Convert exceeded time to hours
            penalty = exceededHours * 0.00015 ether;
        }

        // Ensure penalty does not exceed the staked amount
        if (penalty >= userStake.amount) {
            return 0;
        }

        return userStake.amount - penalty;
    }

    /**
     * @dev Fallback function to receive ETH.
     */
    receive() external payable {}

    /**
     * @dev Allows the owner to withdraw contract balance (e.g., for maintenance).
     */
    function withdrawContractBalance() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    /**
     * @dev Transfers ownership to a new address.
     * @param newOwner Address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}
