// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./Borrow.sol";

contract Staking is Borrow {
    uint public totalStakedAmount;
    uint public stakedInterest;
    uint public globalSupplyIndex = RAY;
    uint lastUpdatedStakingIndex;
    struct StakedUser {
        uint stakedAmount;
        uint userIndex;
    }
    mapping(address => StakedUser) public stakedUser;

    constructor() {
        lastUpdatedStakingIndex = block.timestamp;
    }
    function updateStakeIndex() public {
        uint timeElapsed = block.timestamp - lastUpdatedStakingIndex;
        if (timeElapsed > 0) {
            updateStakeInterest();
            uint rateAccumulated = (timeElapsed * stakedInterest) / (365 days);
            globalSupplyIndex += (globalSupplyIndex * rateAccumulated) / RAY;
        }
        lastUpdatedStakingIndex = block.timestamp;
    }
    function updateStakeInterest() public {
        if (totalStakedAmount == 0 || totalLiquidity == 0) {
            stakedInterest = 2e16;
            return;
        }
        uint utilization = (totalBorrowedAmount * RAY) / totalLiquidity;
        stakedInterest = (utilization * borrowInterest) / (RAY);
    }
    function stake() public payable {
        require(msg.value > 0, "Must Greater Than 0 ETH");
        updateStakeIndex();
        _updateUser(msg.sender);
        StakedUser storage s = stakedUser[msg.sender];
        uint amount = msg.value;
        s.stakedAmount += amount;
        totalStakedAmount += amount;
        totalLiquidity += amount;
    }
    function _updateUser(address user) internal {
        StakedUser storage s = stakedUser[user];
        if (s.userIndex == 0) {
            s.userIndex = globalSupplyIndex;
            return;
        }
        if (s.stakedAmount > 0) {
            uint totalAmount = (s.stakedAmount * globalSupplyIndex) /
                s.userIndex;
            s.stakedAmount = totalAmount;
        }
        s.userIndex = globalSupplyIndex;
    }
    function withdrawStaking() public nonReentrant {
        StakedUser storage s = stakedUser[msg.sender];
        updateStakeIndex();
        require(s.stakedAmount > 0, "No Amount To Withdraw");
        _updateUser(msg.sender);
        uint amount = s.stakedAmount;
        s.stakedAmount = 0;
        s.userIndex = 0;
        require(totalLiquidity >= amount, "Insufficient Liquidity");
        totalLiquidity -= amount;
        if (totalStakedAmount < amount) {
            totalStakedAmount = 0;
        } else {
            totalStakedAmount -= amount;
        }
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transaction Failed");
    }
    function seeStakingDetails(
        address user
    ) public view returns (StakedUser memory) {
        StakedUser memory s = stakedUser[user];
        return (s);
    }
}
