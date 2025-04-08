// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    uint256 private constant STARTING_BALANCE = 10e18; // 10 ETH
    uint256 private constant SEND_VALUE = 1e18;

    address private ALICE = makeAddr("alice");

    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        // Set up the test environment
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(ALICE, STARTING_BALANCE); // Give ALICE 10 ETH
    }

    function testGetVersion() external view {
        // Test the getVersion function
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundWithoutETH() public {
        vm.expectRevert();
        fundMe.fund(); // this line is expected to revert
    }

    function testFundUpdatesFundDataStructure() public {
        vm.prank(ALICE); // The next TX would be sent by ALICE
        fundMe.fund{value: SEND_VALUE}();
        // 合约间交互： 在合约 A 调用合约 B 的函数时，在合约 B 中，msg.sender 的值会是合约 A 的地址，而 address(this) 仍然是合约 B 自身的地址。
        // console.log(msg.sender);
        // console.log(address(this));
        uint256 amount = fundMe.getAddressToAmountFunded(ALICE);
        assertEq(amount, SEND_VALUE);
    }

    modifier funded() {
        vm.prank(ALICE);
        fundMe.fund{value: SEND_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(ALICE);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(funder, ALICE);
    }

    function testOnlyOwnerCanWithDraw() public funded {
        vm.expectRevert();
        fundMe.withdraw(); // this line is expected to revert
    }

    function testWithdrawFromASingleFunder() public funded {
        // Arrange: Set up the test by initializing variables, and objects and prepping preconditions
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.txGasPrice(GAS_PRICE);
        uint256 gasStart = gasleft(); // find out how much gas we had before and after we called the transaction

        // Act: Perform the action to be tested like a function invocation
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; // calculate the gas used
        console.log("Withdraw consumed : %d gas", gasUsed);

        // Assert: Compare the received output with the expected output
        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            endingOwnerBalance,
            startingOwnerBalance + startingFundMeBalance
        );
    }

    function testWithdrawMutipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // hoax = prank + deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
        assert(
            (numberOfFunders + 1) * SEND_VALUE ==
                fundMe.getOwner().balance - startingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
        assert(
            (numberOfFunders + 1) * SEND_VALUE ==
                fundMe.getOwner().balance - startingOwnerBalance
        );
    }

    function testPrintStorageData() public view {
        for (uint256 i = 0; i < 3; i++) {
            bytes32 value = vm.load(address(fundMe), bytes32(i));
            console.log("Storage slot %s: ", i);
            console.logBytes32(value);
        }
        console.log("PriceFeed address: ", address(fundMe.getPriceFeed()));
    }
}
