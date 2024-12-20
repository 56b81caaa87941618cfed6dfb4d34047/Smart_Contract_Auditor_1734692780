
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract VestingContract is Ownable {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 duration;
        uint256 releasedAmount;
        bool revoked;
    }

    IERC20 public immutable token;
    mapping(address => VestingSchedule) public vestingSchedules;

    event VestingScheduleCreated(address indexed beneficiary, uint256 totalAmount, uint256 startTime, uint256 duration);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 refundedAmount);

    constructor() Ownable() {
        token = IERC20(address(0x1234567890123456789012345678901234567890)); // Placeholder address, should be changed
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration
    ) external onlyOwner {
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(totalAmount > 0, "Total amount must be greater than zero");
        require(duration > 0, "Duration must be greater than zero");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting schedule already exists");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            startTime: startTime,
            duration: duration,
            releasedAmount: 0,
            revoked: false
        });

        token.safeTransferFrom(msg.sender, address(this), totalAmount);

        emit VestingScheduleCreated(beneficiary, totalAmount, startTime, duration);
    }

    function releaseVestedTokens(address beneficiary) external {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        require(!schedule.revoked, "Vesting has been revoked");

        uint256 vestedAmount = getVestedAmount(beneficiary);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;
        require(releasableAmount > 0, "No tokens available for release");

        schedule.releasedAmount += releasableAmount;
        token.safeTransfer(beneficiary, releasableAmount);

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        require(!schedule.revoked, "Vesting already revoked");

        uint256 vestedAmount = getVestedAmount(beneficiary);
        uint256 refundAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        schedule.totalAmount = vestedAmount;

        if (refundAmount > 0) {
            token.safeTransfer(owner(), refundAmount);
        }

        emit VestingRevoked(beneficiary, refundAmount);
    }

    function getVestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
        }

        if (block.timestamp < schedule.startTime) {
            return 0;
        } else if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount;
        } else {
            return (schedule.totalAmount * (block.timestamp - schedule.startTime)) / schedule.duration;
        }
    }
}
