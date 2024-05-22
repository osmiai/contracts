// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "hardhat/console.sol";

contract OsmiAccessManager is AccessManagerUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAdmin) initializer public {
        require(initialAdmin != address(0), "Initial admin address cannot be the zero address");
        __AccessManager_init(initialAdmin);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address /* newImplementation */) internal override view {
        require(address(this) == msg.sender, "Only the current contract can call this function.");
    }

    uint64 public constant BLACKLIST_ROLE = 0xdeadbeef;

    function hasRole(uint64 roleId, address account) public view override(AccessManagerUpgradeable) returns (bool, uint32) {
        (bool isBlacklisted, ) = super.hasRole(BLACKLIST_ROLE, account);
        if(isBlacklisted) {
            return (roleId == BLACKLIST_ROLE, 0);
        }
        return super.hasRole(roleId, account);
    }
}
