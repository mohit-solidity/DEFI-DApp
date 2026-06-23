// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Borrow Contract - Index-based Lending System
/// @author Mohit
/// @notice Implements borrowing, repayment, and collateral management with interest accrual
contract Borrow is ReentrancyGuard {

    uint constant RAY = 1e18;

    /// @dev Global index used to scale borrowed amounts over time
    uint public globalBorrowIndex = RAY;

    /// @dev Current borrow interest rate (per year, scaled by RAY)
    uint public borrowInterest;

    /// @dev Base borrow interest rate
    uint constant baseBorrowInterest = 3e16;

    /// @dev Last timestamp when borrow index was updated
    uint public lastUpdateBorrowIndex;

    /// @dev Total available liquidity in the protocol
    uint public totalLiquidity;

    /// @dev Total borrowed amount (real value, not scaled)
    uint public totalBorrowedAmount;

    /// @dev Total number of active borrowers
    uint public totalNumberOfBorrowers;

    /// @dev Total collateral deposited by all users
    uint public totalCollateralDeposited;

    /// @dev Struct representing a borrower
    struct Borrower {
        uint collateral;        // Collateral deposited
        uint borrowedAmount;   // Scaled borrowed amount
        uint userIndex;        // User's borrow index snapshot
        uint canBorrowMore;    // Remaining borrow capacity
    }

    /// @dev Mapping of user address to borrower data
    mapping(address => Borrower) public borrower;

    /// @dev Initializes contract with initial liquidity and base interest rate
    constructor() payable {
        lastUpdateBorrowIndex = block.timestamp;
        borrowInterest = baseBorrowInterest;
        totalLiquidity += msg.value;
    }

    /// @dev Updates the global borrow index based on elapsed time and interest rate
    function updateIndex() public {
        updateborrowInterest();

        uint timeElapsed = block.timestamp - lastUpdateBorrowIndex;

        if (timeElapsed > 0) {
            uint ratePerSecond = (borrowInterest * timeElapsed) / (365 days);

            globalBorrowIndex += (globalBorrowIndex * ratePerSecond) / RAY;

            lastUpdateBorrowIndex = block.timestamp;
        }
    }

    /// @dev Updates borrow interest rate based on utilization ratio using a kink model
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

    /// @notice Deposit ETH as collateral
    /// @dev Increases collateral and borrow capacity
    function depositCollateral() public payable {
        Borrower storage b = borrower[msg.sender];

        require(msg.value > 0, "Must Greater Than 0 ETH");

        uint amount = msg.value;

        b.collateral += amount;
        b.canBorrowMore += (amount * 5000) / 10000;

        totalCollateralDeposited += amount;

        updateIndex();
    }

    /// @notice Borrow ETH from the protocol
    /// @param _amount Amount of ETH to borrow
    /// @dev Updates user debt and transfers ETH
    function borrow(uint _amount) public nonReentrant {
        updateIndex();

        Borrower storage b = borrower[msg.sender];

        uint amount = b.collateral;

        require(amount > 0, "No Deposited Collateral");
        require(_amount <= b.canBorrowMore, "Exceeds borrow limit");

        if (b.borrowedAmount >= 0) {
            uint newAmount = viewDEBT(msg.sender);
            b.borrowedAmount = newAmount;
        } else {
            totalNumberOfBorrowers++;
        }

        b.userIndex = globalBorrowIndex;

        require(totalLiquidity >= _amount, "Insufficient Liquidity");

        totalBorrowedAmount += _amount;
        b.borrowedAmount += _amount;
        b.canBorrowMore -= _amount;

        totalLiquidity -= _amount;

        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transaction Failed");
    }

    /// @notice Withdraw collateral if no outstanding debt
    /// @param _amount Amount of collateral to withdraw
    /// @dev Requires full debt repayment before withdrawal
    function withdrawCollateral(uint _amount) public nonReentrant {
        updateIndex();

        Borrower storage b = borrower[msg.sender];

        uint amount = b.collateral;
        uint debt = viewDEBT(msg.sender);

        require(amount != 0, "No Collateral Deposited");
        require(debt == 0, "Repay debt first");
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

    /// @notice Repay borrowed ETH
    /// @dev Handles partial and full repayment with scaling logic
    function repay() public payable nonReentrant {
        updateIndex();

        Borrower storage b = borrower[msg.sender];

        uint debt = viewDEBT(msg.sender);

        require(debt != 0, "No Amount To Repay");
        require(msg.value > 0, "Must Send Greater Than 0 ETH");

        uint repayAmount = msg.value;
        uint freeAmount;

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

    /// @notice View current debt of a user including interest
    /// @param _user Address of the borrower
    /// @return debt Current debt including accrued interest
    function viewDEBT(address _user) public view returns (uint debt) {
        Borrower memory b = borrower[_user];

        if (b.borrowedAmount == 0 || b.userIndex == 0) return 0;

        debt = (b.borrowedAmount * globalBorrowIndex) / b.userIndex;
    }

    /// @dev Prevent direct ETH transfers
    receive() external payable {
        revert("Use Official Methods");
    }

    fallback() external payable {}
}
