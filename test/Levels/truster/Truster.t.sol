// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import {TrusterLenderPool} from "../../../src/Contracts/truster/TrusterLenderPool.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {Exploit} from "./ExploitTruster.sol";

contract Truster is Test {
    uint256 constant TOKENS_IN_POOL = 1_000_000e18;

    Utilities utils;
    TrusterLenderPool pool;
    DamnValuableToken dvt;
    Exploit exploit;
    address payable attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");
        pool = new TrusterLenderPool(dvt);
        vm.label(address(pool), "Pool");

        dvt.transfer(address(pool), TOKENS_IN_POOL);

        assertEq(dvt.balanceOf(address(pool)), TOKENS_IN_POOL);
    }

    function testExploit() public {
        console.log(
            "Pool balance before attack:",
            dvt.balanceOf(address(pool))
        );
        console.log("Attacker balance before attack:", dvt.balanceOf(attacker));

        exploit = new Exploit(address(pool), attacker, address(dvt));
        validation();
    }

    function validation() public {
        // Pool balance must be zero and attacker must have it all
        assertEq(dvt.balanceOf(address(pool)), 0);
        assertEq(dvt.balanceOf(address(attacker)), TOKENS_IN_POOL);

        console.log("Pool balance after attack:", dvt.balanceOf(address(pool)));
        console.log("Attacker balance after attack:", dvt.balanceOf(attacker));
    }
}
