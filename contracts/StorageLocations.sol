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
}
