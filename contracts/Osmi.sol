// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Osmi is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable, AccessManagedUpgradeable, ERC20PermitUpgradeable, ERC20CappedUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority) initializer public {
        __ERC20_init("Osmi", "OSMI");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __ERC20Capped_init(1000000000 * 10 ** decimals());
        __AccessManaged_init(initialAuthority);
        __ERC20Permit_init("Osmi");
        __UUPSUpgradeable_init();
    }

    function pause() public restricted {
        _pause();
    }

    function unpause() public restricted {
        _unpause();
    }

    function mint(address to, uint256 amount) public restricted {
        _mint(to, amount);
    }

    /**
     * @dev Overridden version of transfer to add restricted modifier for potential blacklisting.
     * 
     * See {IERC20-transfer}.
     */
    function transfer(address to, uint256 value) public restricted override returns (bool) {
        return super.transfer(to, value);
    }

    /**
     * @dev Overridden version of approve to add restricted modifier for potential blacklisting.
     * 
     * See {IERC20-approve}.
     */
    function approve(address spender, uint256 value) public restricted override returns (bool) {
        return super.approve(spender, value);
    }

    /**
     * @dev Overridden version of transferFrom to add restricted modifier for potential blacklisting.
     * 
     * See {IERC20-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 value) public restricted override returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        restricted
        override
    {}

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20CappedUpgradeable)
    {
        super._update(from, to, value);
    }
}
