// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Borrow} from "../contracts/Borrow.sol";
import "forge-std/console.sol";


contract BorrowTest is Test{
    Borrow public borrow;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    function setUp() public {
        borrow = new Borrow();
    }

    function testFuzz_depositCollateral(uint _amount) public{
        uint amount = bound(_amount, 0.0001 ether, 10000 ether);
        vm.deal(user1,amount);
        vm.prank(user1);
        borrow.depositCollateral{value:amount}();
        (uint collateral,,,uint canBorrowMore) = borrow.borrower(user1);
        console.log(canBorrowMore);
        console.log(collateral);
        console.log(amount);
        vm.assertEq(collateral, amount);
        vm.assertEq(borrow.totalCollateralDeposited(), amount);
    }
    function testFuzz_BorrowAmount(uint _amount) public {
        uint amount  = bound(_amount,0.0001 ether,10000 ether);
        vm.deal(user1,amount);
        vm.prank(user1);
        borrow.depositCollateral{value:amount}();
        (uint collateral,uint borrowedAmount,uint userIndex,uint canBorrowMore) = borrow.borrower(user1);
        // For Borror
        vm.startPrank(user1);
        borrow.increaseLiquidity(canBorrowMore);
        borrow.borrow(canBorrowMore);
        vm.stopPrank();
        (collateral,borrowedAmount,userIndex,) = borrow.borrower(user1);
        vm.assertEq(borrow.totalNumberOfBorrowers(), 1);
        vm.assertEq(borrow.totalBorrowedAmount(), canBorrowMore);
        vm.assertEq(borrowedAmount, canBorrowMore);
        vm.assertEq(borrow.totalLiquidity(), 0);

        // Reverts
        vm.expectRevert("Exceeds borrow limit");
        vm.prank(user1);
        borrow.borrow(amount);

        //Revert If No Liquidity Or Insufficient Liquidity
        vm.deal(user2, amount);
        vm.prank(user2);
        borrow.depositCollateral{value:amount}();
        (,,,canBorrowMore) = borrow.borrower(user2);
        assertGt(canBorrowMore, 0,"Borrow Isn't greater");
        vm.expectRevert("Insufficient Liquidity");
        vm.prank(user2);
        borrow.borrow(canBorrowMore);

        //Revert For No Collateral Deposited
        vm.expectRevert("No Deposited Collateral");
        vm.prank(user3);
        borrow.borrow(amount);
    }
    // Test For Repay Loan
    function testFuzz_RepayLoan(uint _amount,uint _repayAmount) public{
        uint amount = bound(_amount, 0.01 ether, 10000 ether);
        vm.deal(user1,amount);
        vm.startPrank(user1);
        borrow.depositCollateral{value:amount}();
        (,,,uint canBorrowMore) = borrow.borrower(user1);
        borrow.increaseLiquidity(amount);
        borrow.borrow(canBorrowMore);
        vm.stopPrank();

        //Now uesr Can Repay After Borrowing
        uint repayAmount = bound(_repayAmount,0.001 ether,amount);
        uint debt = borrow.viewDEBT(user1);
        vm.prank(user1);
        console.log(borrow.globalBorrowIndex());
        console.log(debt);
        vm.warp(block.timestamp + 10 days);
        borrow.updateIndex();
        console.log(borrow.globalBorrowIndex());
        console.log(borrow.viewDEBT(user1));
    }
}
