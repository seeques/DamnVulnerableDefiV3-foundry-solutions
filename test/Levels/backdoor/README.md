## Backdoor solution

There is a `WalletRegistry` contract that utilizes the GnosisSafe wallet functionality by implementing `proxyCreated` callback. There is also a list of beneficiaries who are eligible for 10 DVT tokens each on GnosisSafeProxy creation, the funds in the registry are currently at 40 DVT tokens. Our goal is to take them in a single transaction.

This can be done as anybody can create wallets on behalf of the beneficiaries. The `GnosisSafe` (or master copy), an implementation contract, has a `setUp` function which proxy must call upon its creation. It sets up onwers of the proxy, an additional module (that is, an arbitrary contract which a user wants to call on proxy creation) and a fallback handler (a contract which manages fallbacks to implementation). Since the `proxyCreated` fallback expects a zero address on a fallback handler position slot, we should turn our gaze to module set up. And as it turns out, it delegatecalls our delegatecall to a module contract. So, if we wanted to exploit this, we would implement a token approval function on our module contract. And since, as already been mentioned, module setup delegatecalls a delegatecall, upon calling approval function the msg.sender would be the proxy contract itself.