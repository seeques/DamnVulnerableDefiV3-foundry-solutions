// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {FlashLoanReceiver} from "../../../src/Contracts/naive-receiver/FlashLoanReceiver.sol";
import {NaiveReceiverLenderPool} from "../../../src/Contracts/naive-receiver/NaiveReceiverLenderPool.sol";
import {Exploit} from "./ExploitReceiver.sol";

contract NaiveReceiver is Test {
    uint256 constant ETH_IN_POOL = 1_000e18;
    uint256 constant ETH_IN_RECEIVER = 10e18;

    NaiveReceiverLenderPool pool;
    FlashLoanReceiver receiver;
    Exploit exploit;

    function setUp() public {
        pool = new NaiveReceiverLenderPool();
        vm.label(address(pool), "Pool Address");
        vm.deal(address(pool), ETH_IN_POOL);

        receiver = new FlashLoanReceiver(payable(pool));
        vm.label(address(receiver), "Receiver Address");
        vm.deal(address(receiver), ETH_IN_RECEIVER);

        assertEq(address(pool).balance, ETH_IN_POOL);
        assertEq(address(receiver).balance, ETH_IN_RECEIVER);
    }

    function testExploit() public {
        console.log("Pool balance before attack:", address(pool).balance);
        console.log(
            "Receiver balance before attack:",
            address(receiver).balance
        );
        exploit = new Exploit(address(receiver), address(pool));
        validation();
    }

    function validation() public {
        // No ETH in receiver
        assertEq(address(receiver).balance, 0);
        assertEq(address(pool).balance, ETH_IN_RECEIVER + ETH_IN_POOL);

        console.log("Pool balance after attack:", address(pool).balance);
        console.log(
            "Receiver balance after attack:",
            address(receiver).balance
        );
    }
}
