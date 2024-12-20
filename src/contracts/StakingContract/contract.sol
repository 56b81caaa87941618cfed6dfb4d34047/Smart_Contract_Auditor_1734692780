
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingContract is ReentrancyGuard, Pausable, Ownable {
    struct Stake {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Stake) public stakes;
    uint256 public totalStaked;

    uint256 public constant REWARD_RATE = 10; // 10% per year
    uint256 public immutable MAX_STAKE = 1000 ether;
    uint256 public immutable MIN_STAKE = 0.01 ether;
    uint256 private constant PRECISION_FACTOR = 1e18;

    event Deposited(address indexed user, uint256 amount);
    event WithdrawnAndRewarded(address indexed user, uint256 stakedAmount, uint256 reward);

    constructor() Ownable() {}

    function deposit() external payable nonReentrant whenNotPaused {
        receiveDeposit();
    }

    function withdraw() external nonReentrant whenNotPaused {
        Stake memory userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake to withdraw");

        uint256 reward = calculateRewards(msg.sender);
        uint256 totalAmount = userStake.amount + reward;

        require(address(this).balance >= totalAmount, "Insufficient contract balance");

        // Update state before external call (checks-effects-interactions pattern)
        totalStaked -= userStake.amount;
        delete stakes[msg.sender];

        // External call
        (bool success, ) = payable(msg.sender).call{value: totalAmount}("");
        require(success, "Transfer failed");

        emit WithdrawnAndRewarded(msg.sender, userStake.amount, reward);
    }

    function calculateRewards(address user) public view returns (uint256) {
        Stake memory userStake = stakes[user];
        if (userStake.amount == 0) {
            return 0;
        }
        uint256 stakingDuration = block.timestamp - userStake.timestamp;
        return (userStake.amount * REWARD_RATE * stakingDuration) / (365 days * 100);
    }

    function getStakedBalance(address user) external view returns (uint256) {
        require(user != address(0), "Invalid address");
        return stakes[user].amount;
    }

    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }

    receive() external payable {
        receiveDeposit();
    }

    function receiveDeposit() internal {
        require(msg.value >= MIN_STAKE, "Must deposit at least the minimum stake amount");
        require(msg.value + stakes[msg.sender].amount <= MAX_STAKE, "Exceeds maximum stake limit");

        uint256 newReward = calculateRewards(msg.sender);
        uint256 newStakeAmount = stakes[msg.sender].amount + msg.value + newReward;

        require(address(this).balance >= newStakeAmount, "Insufficient contract balance");

        stakes[msg.sender] = Stake({
            amount: newStakeAmount,
            timestamp: block.timestamp
        });

        totalStaked += msg.value;

        emit Deposited(msg.sender, msg.value);
        if (newReward > 0) {
            emit WithdrawnAndRewarded(msg.sender, 0, newReward);
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
