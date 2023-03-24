## Naive recevier solution

Our ojective here is to drain funds of the `FlashLoanReceiver` contract in a single transaction. The fee on flashloan is a constant of 1 ETH and the receiver has 10 ETH in total. The `NaiveReceiverLenderPool.flashLoan()` can be executed by anyone and since `onFlashLoan` function of the receiver contract only checks that `msg.sender == pool`, which is always the case, we can repeatedly call the `flashLoan` function with this receiver, succesfully draining him.

```
    function attack() public {
        for (uint256 i; i < 10; ++i) {
            pool.flashLoan(receiver, ETH, 0, "");
        }
    }
```