// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract OsmiAccessManager is AccessManagerUpgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
    uint64 public constant BLACKLIST_ROLE = 0xffffffffdeadbeef;

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

    /**
     * @dev We override hasRole to enforce blacklisting. If an account has the blacklist role
     * then that will be the only role it has, regardless of other configuration. This 
     * ensures that no restricted functions can be called by that account.
     * 
     * AccessManaged contracts must add the restricted modifier to each function that should
     * be affected by blacklisting (i.e. ERC20 transfer). Additionally, PUBLIC_ROLE must be
     * granted access for each restricted function that should be accessible by the public.
     * 
     * See {IAccessManager-hasRole}.
     */
    function hasRole(uint64 roleId, address account) public view override(AccessManagerUpgradeable) returns (bool, uint32) {
        (bool isBlacklisted, uint32 executionDelay) = super.hasRole(BLACKLIST_ROLE, account);
        if(isBlacklisted) {
            return (roleId == BLACKLIST_ROLE, executionDelay);
        }
        return super.hasRole(roleId, account);
    }
}
