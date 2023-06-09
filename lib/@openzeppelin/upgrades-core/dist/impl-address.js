"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getImplementationAddressFromProxy = exports.getImplementationAddressFromBeacon = exports.InvalidBeacon = void 0;
const ethereumjs_util_1 = require("ethereumjs-util");
const _1 = require(".");
const address_1 = require("./utils/address");
class InvalidBeacon extends _1.UpgradesError {
}
exports.InvalidBeacon = InvalidBeacon;
/**
 * Gets the implementation address from the beacon using its implementation() function.
 * @param provider
 * @param beaconAddress
 * @returns The implementation address.
 * @throws {InvalidBeacon} If the implementation() function could not be called or does not return an address.
 */
async function getImplementationAddressFromBeacon(provider, beaconAddress) {
    const implementationFunction = '0x' + (0, ethereumjs_util_1.keccak256)(Buffer.from('implementation()')).toString('hex').slice(0, 8);
    let result;
    try {
        const implAddress = await (0, _1.call)(provider, beaconAddress, implementationFunction);
        result = (0, address_1.parseAddress)(implAddress);
    }
    catch (e) {
        if (!(e.message.includes('function selector was not recognized') ||
            e.message.includes('invalid opcode') ||
            e.message.includes('revert') ||
            e.message.includes('execution error'))) {
            throw e;
        } // otherwise fall through with no result
    }
    if (result === undefined) {
        throw new InvalidBeacon(`Contract at ${beaconAddress} doesn't look like a beacon`);
    }
    return result;
}
exports.getImplementationAddressFromBeacon = getImplementationAddressFromBeacon;
/**
 * Gets the implementation address from a UUPS/Transparent/Beacon proxy.
 *
 * @returns a Promise with the implementation address, or undefined if a UUPS/Transparent/Beacon proxy is not located at the address.
 */
async function getImplementationAddressFromProxy(provider, proxyAddress) {
    try {
        return await (0, _1.getImplementationAddress)(provider, proxyAddress);
    }
    catch (e) {
        if (e instanceof _1.EIP1967ImplementationNotFound) {
            try {
                const beaconAddress = await (0, _1.getBeaconAddress)(provider, proxyAddress);
                return await getImplementationAddressFromBeacon(provider, beaconAddress);
            }
            catch (e) {
                if (e instanceof _1.EIP1967BeaconNotFound) {
                    return undefined;
                }
                else {
                    throw e;
                }
            }
        }
        else {
            throw e;
        }
    }
}
exports.getImplementationAddressFromProxy = getImplementationAddressFromProxy;
//# sourceMappingURL=impl-address.js.map