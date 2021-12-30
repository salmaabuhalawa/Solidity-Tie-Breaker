//SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract hashCalculator{
    function hashFinder(uint _hand, bytes32 _rand) public pure returns (bytes32 _hash){
        uint hand = _hand;
        bytes32 rand = _rand;
        return keccak256(abi.encodePacked(hand,rand));
    }

}