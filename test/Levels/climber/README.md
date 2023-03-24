## Climber solution

Yet another proxy has 10 million DVT tokens in its balance. Its implementation, `ClimberVault` contract, has a `withdraw` function with withdraw limit and waiting perioad, and a `sweepFunds` function which allows to transfer all the funds to the `sweeper` address, which was set up in construction and to whom we do not have access. It seems that the only way to steal funds would be to upgrade to new implementation. But for that we have to be the owner of the current one. We can see that upon construction a `TimeLock` contract was created and given the owner rights.

The `TimeLock` contract has two functions: `schedule` for scheduling and `execute` for executing what was scheduled. Scheduling is allowed only by the proposer role, which was given during the construction, and the function sets a delay at the end of which it is possible to execute. However, the `execute` function violates the CEI pattern and allows for reentrancy.

With that being said, our attack would look like this:
1. Upon calling the `execute` function we successively update the delay to zero, grant the proposer role to our contract, transfer ownership to the attacker address and finally call the `schedule` function with all that data, including the call to `schedule` function (it must be in a wrapper function to avoid recursion).
2. After that, we deploy a new implementation with call to (IERC20).transfer(). As this is UUPS pattern we are dealing with, it must adhere to it, i.e return the storage slot where the implementation address is assumed to be stored.
3. At last, we call `upgradeToAndCall` function on proxy. Since at this moment we are the owner of the implementation, we bypass the `_authorizeUpgrade`, upgrade to our new imlementation and call the transfer function.