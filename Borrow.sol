// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Borrow is ReentrancyGuard {
    uint constant RAY = 1e18;
    uint public globalBorrowIndex = RAY;
    uint public borrowInterest;
    uint constant baseBorrowInterest = 3e16;
    uint public lastUpdateBorrowIndex;
    uint public totalLiquidity;
    uint public totalBorrowedAmount;
    uint public totalNumberOfBorrowers;
    uint public totalCollateralDeposited;
    struct Borrower {
        uint collateral;
        uint borrowedAmount;
        uint userIndex;
        uint canBorrowMore;
    }
    mapping(address => Borrower) public borrower;

    constructor() payable {
        lastUpdateBorrowIndex = block.timestamp;
        borrowInterest = baseBorrowInterest;
        totalLiquidity += msg.value;
    }
    function updateIndex() public {
        updateborrowInterest();
        uint timeElapsed = block.timestamp - lastUpdateBorrowIndex;
        if (timeElapsed > 0) {
            uint ratePerSecond = (borrowInterest * timeElapsed) / (365 days);
            globalBorrowIndex += (globalBorrowIndex * ratePerSecond) / RAY;
            lastUpdateBorrowIndex = block.timestamp;
        }
    }
    function updateborrowInterest() public {
        if (totalLiquidity == 0) {
            borrowInterest = baseBorrowInterest;
            return;
        }
        uint utilization = (totalBorrowedAmount * RAY) / totalLiquidity;
        uint slope1 = 1e17;
        uint slope2 = 3e17;
        uint utilizationMax = 8e17;
        if (utilization < utilizationMax) {
            borrowInterest = baseBorrowInterest + (utilization * slope1) / RAY;
        } else {
            borrowInterest =
                baseBorrowInterest +
                (utilizationMax * slope1) / RAY +
                ((utilization - utilizationMax) * slope2) / RAY;
        }
    }
    function depositCollateral() public payable {
        Borrower storage b = borrower[msg.sender];
        require(msg.value > 0, "Must Greater Than 0 ETH");
        uint amount = msg.value;
        b.collateral += amount;
        b.canBorrowMore += (amount * 5000) / 10000;
        totalCollateralDeposited += amount;
        updateIndex();
    }
    function borrow(uint _amount) public nonReentrant {
        updateIndex();
        Borrower storage b = borrower[msg.sender];
        uint amount = b.collateral;
        require(amount > 0, "No Deposited Collateral");
        require(
            _amount <= b.canBorrowMore,
            "Can't Reach More Than 50% Of Your Max Balance"
        );
        if(b.borrowedAmount>=0){
            uint newAmount = viewDEBT(msg.sender);
            b.borrowedAmount = newAmount;
        }else{
            totalNumberOfBorrowers ++;
        }
        b.userIndex = globalBorrowIndex;
        if (totalLiquidity < _amount) revert("Insufficient Liquidity");
        totalBorrowedAmount += _amount;
        b.borrowedAmount += _amount;
        b.canBorrowMore -= _amount;
        totalLiquidity -= _amount;
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transaction Failed");
    }
    function withdrawCollateral(uint _amount) public nonReentrant {
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
        (bool success, ) = payable(msg.sender).call{value: _amount}("hello()");
        require(success, "Transaction Failed");
    }
    function repay() public payable nonReentrant {
        updateIndex();
        uint freeAmount;
        Borrower storage b = borrower[msg.sender];
        uint debt = viewDEBT(msg.sender);
        uint repayAmount = msg.value;
        require(debt != 0, "No Amount To Repay");
        require(repayAmount > 0, "Must Send Greater Than 0 ETH");
        if (repayAmount > debt) {
            freeAmount = repayAmount - debt;
            repayAmount = debt;
        }
        uint newDebt = debt - repayAmount;
        if (newDebt == 0) {
            b.userIndex = 0;
            b.borrowedAmount = 0;
            b.canBorrowMore = 0;
            if (totalNumberOfBorrowers > 0) {
                totalNumberOfBorrowers--;
            }
        } else {
            require(b.borrowedAmount != 0, "No Borrowed Amount");
            b.borrowedAmount = (newDebt * globalBorrowIndex) / b.userIndex;
            b.userIndex = globalBorrowIndex;
            b.canBorrowMore = (b.borrowedAmount * 5000) / 10000;
        }
        totalLiquidity += repayAmount;
        require(totalBorrowedAmount >= repayAmount, "Accounting Error");
        totalBorrowedAmount -= repayAmount;
        if (freeAmount != 0) {
            (bool success, ) = payable(msg.sender).call{value: freeAmount}("");
            require(success, "Transaction Failed");
        }
    }
    function viewDEBT(address _user) public view returns (uint) {
        Borrower memory b = borrower[_user];
        if (b.borrowedAmount == 0) return (0);
        if (b.userIndex == 0) return (0);
        uint debt = ((b.borrowedAmount * globalBorrowIndex) / b.userIndex);
        return (debt);
    }
    receive() external payable {
        revert("Use Official Website For Deposits And Borrowing");
    }
    fallback() external payable {}

}
