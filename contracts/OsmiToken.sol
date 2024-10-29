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

contract OsmiToken is Initializable, AccessManagedUpgradeable, UUPSUpgradeable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable, ERC20CappedUpgradeable {
    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiToken
    struct OsmiTokenStorage {
        uint256 __reserved;
    }

    // keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OsmiTokenStorageLocation = 0xcc1a81470f2dcd857da9ee1c5c5a23da5e98a3549166fa5bb480af7aab542500;

    function _getOsmiTokenStorage() private pure returns (OsmiTokenStorage storage $) {
        assembly {
            $.slot := OsmiTokenStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority) initializer public {
        __ERC20_init("Osmi AI", "OSMI");
        __ERC20Burnable_init();
        __ERC20Capped_init(1000000000 * 10 ** decimals());
        __AccessManaged_init(initialAuthority);
        __ERC20Permit_init("Osmi AI");
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Restricted version of approve.
     * 
     * See {IERC20-approve}.
     */
    function approve(address spender, uint256 value) public restricted override returns (bool) {
        return super.approve(spender, value);
    }

    /**
     * @dev Restricted version of burn.
     *
     * See {ERC20-burn}.
     */
    function burn(uint256 value) public restricted override {
        super.burn(value);
    }

    /**
     * @dev Restricted version of burnFrom
     *
     * See {ERC20-burnFrom}.
     */
    function burnFrom(address account, uint256 value) public restricted override {
        super.burnFrom(account, value);
    }

    /**
     * @dev Restricted implementation of mint.
     */
    function mint(address to, uint256 amount) external restricted {
        _mint(to, amount);
    }

    /**
     * @dev Restricted version of permit.
     *
     * See {IERC20Permit}.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public restricted override {
        super.permit(owner, spender, value, deadline, v, r, s);
    }
    
    /**
     * @dev Restricted version of transfer.
     * 
     * See {IERC20-transfer}.
     */
    function transfer(address to, uint256 value) public restricted override returns (bool) {
        return super.transfer(to, value);
    }

    /**
     * @dev Restricted version of transferFrom.
     * 
     * See {IERC20-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 value) public restricted override returns (bool) {
        return super.transferFrom(from, to, value);
    }

    /**
     * @dev Restricted version of _authorizedUpgrade.
     */
    function _authorizeUpgrade(address newImplementation) internal restricted override {}

    /**
     * @dev Required override.
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20CappedUpgradeable)
    {
        super._update(from, to, value);
    }
}
