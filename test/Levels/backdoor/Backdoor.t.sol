// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {Utilities} from "../../utils/Utilities.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {WalletRegistry} from "../../../src/Contracts/backdoor/WalletRegistry.sol";

import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {Exploit} from "./ExploitBackdoor.sol";

contract Backdoor is Test {
    uint256 constant AMOUNT_OF_TOKEN_DISTRIBUTED = 40e18;
    uint256 constant NUM_USERS = 4;

    Utilities utils;
    DamnValuableToken dvt;
    GnosisSafe masterCopy;
    GnosisSafeProxyFactory walletFactory;
    WalletRegistry registry;
    Exploit exploit;

    address[] users;
    address attacker;
    address alice;
    address bob;
    address charlie;
    address david;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(4);
        alice = users[0];
        bob = users[1];
        charlie = users[2];
        david = users[3];

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");

        attacker = address(
            uint160(uint256(keccak256(abi.encodePacked("attacker"))))
        );
        vm.label(attacker, "Attacker");

        // Deploy Gnosis Safe master copy and factory contracts
        masterCopy = new GnosisSafe();
        vm.label(address(masterCopy), "Gnosis Safe");

        walletFactory = new GnosisSafeProxyFactory();
        vm.label(address(walletFactory), "Wallet Factory");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        // Deploy the registry
        registry = new WalletRegistry(
            address(masterCopy),
            address(walletFactory),
            address(dvt),
            users
        );

        // Users are registered as beneficiaries
        for (uint256 i = 0; i < NUM_USERS; i++) {
            assertTrue(registry.beneficiaries(users[i]));
        }

        // Transfer tokens to be distributed to the registry
        dvt.transfer(address(registry), AMOUNT_OF_TOKEN_DISTRIBUTED);
    }

    function testExploit() public {
        vm.prank(attacker);
        exploit = new Exploit(address(registry), users);
        validation();
    }

    function validation() public {
        // Player must have used a single transaction
        // assertEq(vm.getNonce(attacker), 1);

        for (uint256 i = 0; i < NUM_USERS; i++) {
            address wallet = registry.wallets(users[i]);

            // User must have registered a wallet
            if (wallet == address(0)) {
                emit log("User did not register a wallet");
                fail();
            }

            // User is no longer registered as a beneficiary
            assertTrue(!registry.beneficiaries(users[i]));
        }

        // Attacker must have taken all tokens
        assertEq(dvt.balanceOf(attacker), AMOUNT_OF_TOKEN_DISTRIBUTED);
    }
}
