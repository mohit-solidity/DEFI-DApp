// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Borrow} from "../contracts/Borrow.sol";

contract BorrowTest is Test{
    Borrow public borrow;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    function setUp() public {
        borrow = new Borrow();
    }

    function testFuzz_depositCollateral(uint _amount) public{
        uint amount = bound(_amount, 1, 10000 ether);
        vm.deal(user1,amount);
        vm.prank(user1);
        borrow.depositCollateral{value:amount}();
        (uint collateral,uint borrowedAmount,uint userIndex,uint canBorrowMore) = borrow.borrower(user1);
    }
}
