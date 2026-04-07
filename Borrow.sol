// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract Borrow {
    uint constant RAY = 1e18;
    uint public globalBorrowIndex = RAY;
    uint public interest;
    uint constant baseInterest = 3e16;
    uint public lastUpdatedTime;
    uint public totalLiquidity;
    uint public totalBorrowedAmount;
    uint public totalNumberOfBorrowers;
    uint public totalCollateralDeposited;
    bool locked;
    struct Borrower {
        uint borrowedAmount;
        uint collateral;
        uint userIndex;
        uint canBorrowMore;
    }
    mapping(address => Borrower) public borrower;

    modifier nonReenterant() {
        require(!locked, "No Reenterant");
        locked = true;
        _;
        locked = false;
    }
    constructor() payable {
        lastUpdatedTime = block.timestamp;
        interest = baseInterest;
        totalLiquidity += msg.value;
    }
    function updateIndex() public {
        uint timeElapsed = block.timestamp - lastUpdatedTime;
        if (timeElapsed > 0) {
            uint ratePerSecond = (interest * timeElapsed) / (365 days);
            globalBorrowIndex += (globalBorrowIndex * ratePerSecond) / RAY;
            lastUpdatedTime = block.timestamp;
        }
        updateInterest();
    }
    function updateInterest() public {
        if (totalLiquidity == 0) {
            interest = baseInterest;
            return;
        }
        uint utilization = (totalBorrowedAmount * RAY) / totalLiquidity;
        uint slope1 = 1e17;
        uint slope2 = 3e17;
        uint utilizationMax = 8e17;
        if (utilization < utilizationMax) {
            interest = baseInterest + (utilization * slope1) / RAY;
        } else {
            interest =
                baseInterest +
                (utilizationMax * slope1) / RAY +
                ((utilization - utilizationMax) * slope2) / RAY;
        }
    }
    function updateStakeAPY() public {}
    function depositCollateral() public payable {
        Borrower storage b = borrower[msg.sender];
        require(msg.value > 0, "Must Greater Than 0 ETH");
        uint amount = msg.value;
        b.collateral += amount;
        b.canBorrowMore += (amount * 5000) / 10000;
        totalCollateralDeposited += amount;
        updateIndex();
    }
    function withdrawCollateral(uint _amount) public nonReenterant {
        updateIndex();
        Borrower storage b = borrower[msg.sender];
        uint amount = b.collateral;
        uint debt = viewDEBT(msg.sender);
        require(amount != 0, "No Collateral Deposited");
        require(debt == 0, "Please Pay Full  Debt First Before Withdrawing");
        require(_amount <= amount, "Insufficient Balance");
        b.collateral -= _amount;
        if (totalCollateralDeposited < _amount) totalCollateralDeposited = 0;
        else totalCollateralDeposited -= _amount;
        if (b.collateral == 0) {
            delete borrower[msg.sender];
        }
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transaction Failed");
    }
    function repay() public payable nonReenterant {
        updateIndex();
        uint freeAmount;
        Borrower storage b = borrower[msg.sender];
        uint debt = viewDEBT(msg.sender);
        uint amount = debt;
        require(amount != 0, "No Amount To Repay");
        require(
            msg.value >= amount,
            "Must Send Greater Than Amount Of Total DEBT"
        );
        if (msg.value > amount) {
            freeAmount = msg.value - amount;
        }
        if (totalBorrowedAmount <= amount) {
            totalBorrowedAmount = 0;
        } else {
            totalBorrowedAmount -= amount;
        }
        totalLiquidity += amount;
        b.borrowedAmount = 0;
        b.userIndex = 0;
        b.canBorrowMore = 0;
        totalNumberOfBorrowers--;
        (bool success, ) = payable(msg.sender).call{value: freeAmount}("");
        require(success, "Transaction Failed");
    }
    function borrow(uint _amount) public nonReenterant {
        updateIndex();
        Borrower storage b = borrower[msg.sender];
        uint amount = b.collateral;
        require(amount > 0, "No Deposited Collateral");
        uint maxAllowed = (amount * 5000) / 10000;
        require(
            _amount <= maxAllowed,
            "Max 50% Allowed To Borrow Of User Balance"
        );
        require(
            _amount <= b.canBorrowMore,
            "Can't Reach More Than 50% Of Your Max Balance"
        );
        if (b.borrowedAmount == 0) {
            b.userIndex = globalBorrowIndex;
            totalNumberOfBorrowers++;
        }
        if (totalLiquidity < _amount) revert("Insufficient Liquidity");
        totalBorrowedAmount += _amount;
        b.borrowedAmount += _amount;
        b.canBorrowMore -= _amount;
        totalLiquidity -= _amount;
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transaction Failed");
    }
    function viewDEBT(address _user) public view returns (uint) {
        Borrower memory b = borrower[_user];
        if (b.borrowedAmount == 0) return 0;
        if (b.userIndex == 0) return b.borrowedAmount;
        uint debt = ((b.borrowedAmount * globalBorrowIndex) / b.userIndex);
        return (debt);
    }
    function withdrawAll() public {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Tranasction Failed");
    }
}
