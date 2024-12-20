
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingContract is ReentrancyGuard {
    using SafeMath for uint256;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Stake) public stakes;
    uint256 public totalStaked;
    uint256 public constant REWARD_RATE = 10; // 10% per year

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);

    function deposit() external payable nonReentrant {
        receiveDeposit();
    }

    function withdraw() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake to withdraw");

        uint256 reward = calculateRewards(msg.sender);
        uint256 totalAmount = userStake.amount.add(reward);

        require(address(this).balance >= totalAmount, "Insufficient contract balance");

        totalStaked = totalStaked.sub(userStake.amount);
        delete stakes[msg.sender];

        (bool success, ) = payable(msg.sender).call{value: totalAmount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, userStake.amount, reward);
    }

    function calculateRewards(address user) public view returns (uint256) {
        Stake memory userStake = stakes[user];
        if (userStake.amount == 0) {
            return 0;
        }
        uint256 stakingDuration = block.timestamp.sub(userStake.timestamp);
        return userStake.amount.mul(REWARD_RATE).mul(stakingDuration).div(365 days).div(100);
    }

    function getStakedBalance(address user) external view returns (uint256) {
        return stakes[user].amount;
    }

    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }

    receive() external payable {
        receiveDeposit();
    }

    function receiveDeposit() internal {
        require(msg.value > 0, "Must deposit some ETH");

        Stake storage userStake = stakes[msg.sender];
        if (userStake.amount > 0) {
            uint256 reward = calculateRewards(msg.sender);
            userStake.amount = userStake.amount.add(reward);
        }

        userStake.amount = userStake.amount.add(msg.value);
        userStake.timestamp = block.timestamp;
        totalStaked = totalStaked.add(msg.value);

        emit Deposited(msg.sender, msg.value);
    }
}
