// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

error Overflow();
error Underflow();
error DivisionByZero();

library Math{
    uint256 internal constant BASE = 1e18;

    function add(uint256 a,uint256 b) internal pure returns(uint256) {
        if(a>type(uint256).max - b) revert Overflow();
        unchecked {
            return(a>b?a-b:b-a);
        }
    }
    function subUNIT(uint256 a,uint256 b) internal pure returns(uint256){
        require(a>0 && b>0,"Values Can't Be Negative");
        unchecked {
            return(a>b?b-a:a-b);
        }
    }
    function subINT(int256 a,int256 b) internal pure returns(int256){
        unchecked {
            return(a-b);
        }
    }
    function mul(uint256 a,uint256 b) internal pure returns(uint256){
        if(a==0 || b==0) return(0);
        if(a>type(uint256).max/b) revert Overrflow();
        unchecked {
            return((a*b)/BASE);
        }
    }
    function div(uint256 a,uint256 b) internal pure returns(uint256){
        if(b==0) revert DivisionByZero();
        if(a*BASE>type(uint256).max) revert Overflow();
        unchecked {
            return((a*BASE)/b);
        }
    }
}