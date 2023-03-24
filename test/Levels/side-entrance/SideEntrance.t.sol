// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {SideEntranceLenderPool, IFlashLoanEtherReceiver} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";
import {Exploit} from "./ExploitSideEntrance.sol";

contract SideEntrance is Test {
    uint256 constant ETH_POOL_BALANCE = 1_000e18;
    uint256 constant ETH_ATTACKER_BALANCE = 1e18;

    SideEntranceLenderPool pool;
    Exploit exploit;
    address payable attacker =
        payable(
            address(
                uint160(
                    uint256(keccak256(abi.encodePacked("attacker address")))
                )
            )
        );

    function setUp() public {
        vm.label(address(attacker), "Attacker");
        vm.deal(address(attacker), ETH_ATTACKER_BALANCE);

        pool = new SideEntranceLenderPool();
        vm.label(address(pool), "Pool");
        vm.deal(address(pool), ETH_POOL_BALANCE);

        assertEq(address(pool).balance, ETH_POOL_BALANCE);
        assertEq(address(attacker).balance, ETH_ATTACKER_BALANCE);
    }

    function testExploit() public {
        console.log("Pool balance before attack:", address(pool).balance);
        console.log(
            "Attacker balance before attack:",
            address(attacker).balance
        );

        exploit = new Exploit(address(pool), address(attacker));
        exploit.attack();
        validation();
    }

    function validation() public {
        console.log("Pool balance after attack:", address(pool).balance);
        console.log(
            "Attacker balance after attack:",
            address(attacker).balance
        );

        assertEq(address(pool).balance, 0);
        assertEq(
            address(attacker).balance,
            ETH_POOL_BALANCE + ETH_ATTACKER_BALANCE
        );
    }
}
