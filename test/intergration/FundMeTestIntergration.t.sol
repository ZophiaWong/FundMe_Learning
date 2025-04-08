// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {WithdrawFundMe} from "../../script/Interactions.s.sol";
import {Test, console} from "forge-std/Test.sol";

contract FundMeTestIntergration is Test {
    FundMe public fundMe;
    DeployFundMe deployFundMe;

    uint256 private constant STARTING_USER_BALANCE = 10e18; // 10 ETH
    uint256 private constant SEND_VALUE = 0.1e18; // 0.1 ETH

    address private ALICE = makeAddr("alice");

    function setUp() external {
        deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(ALICE, STARTING_USER_BALANCE);
    }

    function testUserCanFundAndOwnerWithdraw() public {
        // === arrange ===
        uint256 preUserBalance = address(ALICE).balance;
        uint256 preOwnerBalance = address(fundMe.getOwner()).balance;
        // === act ===
        // Using vm.prank to simulate funding from the USER address
        vm.prank(ALICE);
        fundMe.fund{value: SEND_VALUE}();

        WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
        withdrawFundMe.withdrawFundMe(address(fundMe));

        uint256 afterUserBalance = address(ALICE).balance;
        uint256 afterOwnerBalance = address(fundMe.getOwner()).balance;

        // === assert ===
        assert(address(fundMe).balance == 0);
        assert(afterUserBalance + SEND_VALUE == preUserBalance);
        assert(preOwnerBalance + SEND_VALUE == afterOwnerBalance);
    }
}
