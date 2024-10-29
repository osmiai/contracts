// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract OsmiAccessManager is AccessManagerUpgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiAccessManager
    struct OsmiAccessManagerStorage {
        uint256 __reserved;
    }

    // keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiAccessManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OsmiAccessManagerStorageLocation = 0x8b016679fc5ed39c90f49853290cb8934e811a906232253a532de3ae6b936c00;

    function _getOsmiAccessManagerStorage() private pure returns (AccessManagerStorage storage $) {
        assembly {
            $.slot := OsmiAccessManagerStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAdmin) initializer public {
        require(initialAdmin != address(0), "Initial admin address cannot be the zero address");
        __AccessManager_init(initialAdmin);
        __Ownable2Step_init();
        __Ownable_init(initialAdmin);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}
}
