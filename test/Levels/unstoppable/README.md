## Unstoppable solution

Our objective is to stop the vault from offering flash loans. We start with 10 DVT tokens in balance, while the vault has 1 million of the underlying tokens deposited.

The function we are interested in is `flashLoan`. It has an invariant check, which we can brake:
```
uint256 balanceBefore = totalAssets();
        if (convertToShares(totalSupply) != balanceBefore)
            revert InvalidBalance();
```
`totalAssets` here is the amount of underlying tokens in vault. `convertToShares()` function takes a certain amount of tokens as an argument and calculates the amount of shares for that tokens in return. And `totalSupply` is the total amount of shares. So `convertToShares(totalSupply)` == (amout of tokens to convert * total amount of shares / totalAssets).
As shares are minted only when someone deposits DVT tokens, we can simply `transfer` our initial DVT balance to the vault, so that the `totalAssets` would increase by 10 DVT but `totalSupply` would stay the same, which would result in error.