
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract StakingContract is ReentrancyGuard, Pausable, Ownable {
    using Address for address payable;

    struct Stake {
        uint128 amount;
        uint128 timestamp;
    }

    mapping(address => Stake) public stakes;
    uint256 public totalStaked;

    uint256 public constant REWARD_RATE = 10; // 10% per year
    uint256 public immutable MAX_STAKE = 1000 ether;
    uint256 public immutable MIN_STAKE = 0.01 ether;
    uint256 private constant PRECISION_FACTOR = 1e27;
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    event Deposited(address indexed user, uint256 amount);
    event WithdrawnAndRewarded(address indexed user, uint256 stakedAmount, uint256 reward);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);

    constructor() Ownable() {}

    function deposit() external payable nonReentrant whenNotPaused {
        receiveDeposit();
    }

    function withdraw() external nonReentrant whenNotPaused {
        Stake memory userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake to withdraw");

        uint256 reward = calculateRewards(msg.sender);
        uint256 totalAmount = uint256(userStake.amount) + reward;

        require(address(this).balance >= totalAmount, "Insufficient contract balance");

        // Update state before external call (checks-effects-interactions pattern)
        totalStaked -= userStake.amount;
        delete stakes[msg.sender];

        // External call using Address.sendValue for safe transfer
        payable(msg.sender).sendValue(totalAmount);

        emit WithdrawnAndRewarded(msg.sender, userStake.amount, reward);
    }

    function calculateRewards(address user) public view returns (uint256) {
        Stake memory userStake = stakes[user];
        if (userStake.amount == 0) {
            return 0;
        }
        uint256 stakingDuration;
        unchecked {
            stakingDuration = block.timestamp - userStake.timestamp;
        }
        return (uint256(userStake.amount) * REWARD_RATE * stakingDuration * PRECISION_FACTOR) / (SECONDS_PER_YEAR * 100 * PRECISION_FACTOR);
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
        require(address(this).balance >= msg.value, "Insufficient contract balance");

        uint256 newReward = calculateRewards(msg.sender);
        uint256 newStakeAmount = uint256(stakes[msg.sender].amount) + msg.value + newReward;

        require(newStakeAmount <= type(uint128).max, "Stake amount overflow");

        if (newStakeAmount != stakes[msg.sender].amount) {
            stakes[msg.sender] = Stake({
                amount: uint128(newStakeAmount),
                timestamp: uint128(block.timestamp)
            });
        }

        totalStaked += msg.value;

        emit Deposited(msg.sender, msg.value);
        if (newReward > 0) {
            emit WithdrawnAndRewarded(msg.sender, 0, newReward);
        }
    }

    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }
}
