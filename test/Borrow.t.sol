// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Borrow} from "../contracts/Borrow.sol";
import "forge-std/console.sol";


contract BorrowTest is Test{
    Borrow public borrow;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
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
        (uint collateral,,,uint canBorrowMore) = borrow.borrower(user1);
        vm.startPrank(user1);
        borrow.increaseLiquidity(canBorrowMore);
        borrow.borrow(canBorrowMore);
    }
}
