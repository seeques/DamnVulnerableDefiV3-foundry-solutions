// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {TheRewarderPool} from "../../../src/Contracts/the-rewarder/TheRewarderPool.sol";
import {RewardToken} from "../../../src/Contracts/the-rewarder/RewardToken.sol";
import {AccountingToken} from "../../../src/Contracts/the-rewarder/AccountingToken.sol";
import {FlashLoanerPool} from "../../../src/Contracts/the-rewarder/FlashLoanerPool.sol";
import {Exploit} from "./ExploitRewarder.sol";

contract TheRewarder is Test {
    uint256 constant TOKENS_IN_POOL = 1_000_000e18;
    uint256 constant USER_DEPOSIT = 100e18;

    Utilities utils;
    FlashLoanerPool flPool;
    TheRewarderPool rwPool;
    DamnValuableToken dvt;
    Exploit exploit;
    address payable attacker;
    address payable alice;
    address payable bob;
    address payable charlie;
    address payable david;
    address payable[] users;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        alice = users[0];
        bob = users[1];
        charlie = users[2];
        david = users[3];
        attacker = users[4];

        vm.label(attacker, "Attacker");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        flPool = new FlashLoanerPool(address(dvt));
        dvt.transfer(address(flPool), TOKENS_IN_POOL);
        vm.label(address(flPool), "FlPool");

        rwPool = new TheRewarderPool(address(dvt));
        vm.label(address(rwPool), "RwPool");

        for (uint256 i; i < 4; ++i) {
            dvt.transfer(users[i], USER_DEPOSIT);
            vm.startPrank(users[i]);
            dvt.approve(address(rwPool), USER_DEPOSIT);
            rwPool.deposit(USER_DEPOSIT);
            assertEq(
                rwPool.accountingToken().balanceOf(users[i]),
                USER_DEPOSIT
            );
            vm.stopPrank();
        }

        assertEq(rwPool.accountingToken().totalSupply(), USER_DEPOSIT * 4);
        assertEq(rwPool.rewardToken().totalSupply(), 0);

        // Advance time so that depositors may claim rewards
        vm.warp(block.timestamp + 5 days);

        for (uint256 i; i < 4; ++i) {
            vm.prank(users[i]);
            rwPool.distributeRewards();
            // each depositor gets 100*100/400 = 25 rewardTokens
            assertEq(rwPool.rewardToken().balanceOf(users[i]), 25e18);
        }

        assertEq(rwPool.rewardToken().totalSupply(), 100e18);
        assertEq(dvt.balanceOf(attacker), 0);
        assertEq(rwPool.roundNumber(), 2);
    }

    function testExploit() public {
        exploit = new Exploit(
            address(dvt),
            address(flPool),
            address(rwPool),
            attacker
        );
        vm.warp(block.timestamp + 5 days);
        exploit.attack();
        validation();
    }

    function validation() internal {
        assertEq(rwPool.roundNumber(), 3); // Only one round should have taken place
        for (uint8 i; i < 4; ++i) {
            // Users should get negligible rewards this round
            vm.prank(users[i]);
            rwPool.distributeRewards();
            uint256 rewardPerUser = rwPool.rewardToken().balanceOf(users[i]);
            uint256 delta = rewardPerUser - 25e18;
            assertLt(delta, 1e16);
        }
        // Rewards must have been issued to the attacker account
        assertGt(rwPool.rewardToken().totalSupply(), 100e18);
        uint256 rewardAttacker = rwPool.rewardToken().balanceOf(attacker);
        // The amount of rewards earned should be really close to 100 tokens
        uint256 deltaAttacker = 100e18 - rewardAttacker;
        assertLt(deltaAttacker, 1e17);

        // Attacker finishes with zero DVT tokens in balance
        assertEq(dvt.balanceOf(attacker), 0);
    }
}
