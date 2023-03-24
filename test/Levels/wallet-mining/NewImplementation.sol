// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract NewImplementation {
    function proxiableUUID() external view returns (bytes32) {
        return
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    }

    fallback() external {
        selfdestruct(payable(address(0)));
    }
}
