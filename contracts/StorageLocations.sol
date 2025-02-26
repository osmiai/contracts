// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

contract StorageLocations {
    function getOsmiAccessManagerStorageLocation() external pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiAccessManager")) - 1)) & ~bytes32(uint256(0xff));
    } 

    function getOsmiTokenStorageLocation() external pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiToken")) - 1)) & ~bytes32(uint256(0xff));
    } 

    function getOsmiNodeStorageLocation() external pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiNode")) - 1)) & ~bytes32(uint256(0xff));
    } 

    function getOsmiDailyDistributionStorageLocation() external pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiDailyDistribution")) - 1)) & ~bytes32(uint256(0xff));
    } 

    function getOsmiNodeFactoryStorageLocation() external pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiNodeFactory")) - 1)) & ~bytes32(uint256(0xff));
    } 

    function getOsmiDistributionManagerStorageLocation() external pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiDistributionManager")) - 1)) & ~bytes32(uint256(0xff));
    }

    function addressToGalaRecipient(address addr) external pure returns(string memory) {
        bytes4 prefix = "eth|";
        bytes16 hex_digits = "0123456789abcdef";
        bytes16 hex_digits_upper = "0123456789ABCDEF";
        // allocate buffer for the whole string
        string memory buffer = new string(44);
        /// @solidity memory-safe-assembly
        assembly {
            let lptr := add(buffer, 32)
            // store and skip prefix
            mstore(lptr, prefix)
            lptr := add(lptr, 4)
            // rptr at end of buffer
            let rptr := add(lptr, 40)
            // loop over each address nibble and convert to hex digit
            let addrValue := addr
            for {} gt(rptr, lptr) {} {
                rptr := sub(rptr, 1)
                mstore8(rptr, byte(and(addrValue, 0xf), hex_digits))
                addrValue := shr(4, addrValue)
            }
            // compute hash of the buffer without prefix
            let hashValue := shr(96, keccak256(lptr, 40))
            // loop over each hash hibble and convert address bytes to uppercase
            addrValue := addr
            rptr := add(lptr, 40)
            for {} gt(rptr, lptr) {} {
                rptr := sub(rptr, 1)
                if gt(and(hashValue, 0xf), 7) {
                    mstore8(rptr, byte(and(addrValue, 0xf), hex_digits_upper))
                }
                addrValue := shr(4, addrValue)
                hashValue := shr(4, hashValue)
            }
        }
        return buffer;
    }
}
