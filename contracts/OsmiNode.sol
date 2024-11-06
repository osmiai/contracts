// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact contact@osmi.ai
contract OsmiNode is Initializable, ERC721Upgradeable, AccessManagedUpgradeable, UUPSUpgradeable {
    /**
     * @dev Emitted when a token's transfer lock is updated.
     */
    event OsmiNodeTransferLockUpdated(uint256 tokenId, uint lockedUntil);

    /**
     * @dev Indicates a token is transfer locked.
     * @param tokenId Id of the token.
     * @param lockedUntil When are transfers unlocked for tokenId?
     */
    error OsmiNodeTransferLocked(uint256 tokenId, uint lockedUntil);

    /**
     * @dev Initial duration of transfer lock when minting tokens.
     */
    uint public constant InitialTransferLockDurationOnMint = 365 days;

    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiNode
    struct OsmiNodeStorage {
        uint256 nextTokenId;
        uint transferLockDurationOnMint;
        mapping(uint256 => uint) transferLockedUntil;
    }

    // keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiNode")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OsmiNodeStorageLocation = 0x9f791d4738865ba7c779eecd51509000f816d1d2e37f69177c0f7c39eff80000;

    function _getOsmiNodeStorageLocation() private pure returns (OsmiNodeStorage storage $) {
        assembly {
            $.slot := OsmiNodeStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority) initializer public {
        __ERC721_init("Osmi AI Node", "OsmiNode");
        __AccessManaged_init(initialAuthority);
        __UUPSUpgradeable_init();
        __transfer_locked_init();
    }

    /**
     * @dev Initialized the transfer locked system.
     */
    function __transfer_locked_init() internal onlyInitializing {
        OsmiNodeStorage storage $ = _getOsmiNodeStorageLocation();
        $.transferLockDurationOnMint = InitialTransferLockDurationOnMint;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://nodes.osmi.ai/api/metadata/";
    }

    /**
     * @dev Returns the total supply of nodes.
     */
    function getTotalSupply() external view returns (uint256) {
        OsmiNodeStorage storage $ = _getOsmiNodeStorageLocation();
        return $.nextTokenId;
    }

    /**
     * @dev Returns it a token is transfer locked and the time any lock expires.
     */
    function isTransferLocked(uint256 tokenId) external view returns (bool, uint) {
        return _isTransferLocked(tokenId);
    }

    function _isTransferLocked(uint256 tokenId) internal view returns (bool, uint) {
        uint lockedUntil = _getTransferLockedUntil(tokenId);
        bool locked = lockedUntil > block.timestamp;
        return (locked, lockedUntil);
    }

    /**
     * @dev Returns when a token's transfer lock is expired.
     */
    function getTransferLockedUntil(uint256 tokenId) external view returns (uint) {
        _requireOwned(tokenId);
        return _getTransferLockedUntil(tokenId);
    }

    function _getTransferLockedUntil(uint256 tokenId) internal view returns (uint) {
        OsmiNodeStorage storage $ = _getOsmiNodeStorageLocation();
        return $.transferLockedUntil[tokenId];
    }

    /**
     * @dev Restricted function for setting the transfer unlock time for a token.
     * @param tokenId Id of the token.
     * @param lockedUntil When are transfers unlocked for tokenId?
     */
    function setTransferLockedUntil(uint256 tokenId, uint lockedUntil) external restricted {
        _requireOwned(tokenId);
        _setTransferLockedUntil(tokenId, lockedUntil);
    }

    function _setTransferLockedUntil(uint256 tokenId, uint lockedUntil) internal {
        OsmiNodeStorage storage $ = _getOsmiNodeStorageLocation();
        $.transferLockedUntil[tokenId] = lockedUntil;
        emit OsmiNodeTransferLockUpdated(tokenId, lockedUntil);
    }

    /**
     * @dev Restricted function to set the transfer lock duration on mint of a new token.
     * @param duration How many seconds from mint time should the transfer lock last?
     */
    function setTransferLockDurationOnMint(uint duration) external restricted {
        _setTransferLockDurationOnMint(duration);
    }

    function _setTransferLockDurationOnMint(uint duration) internal {
        OsmiNodeStorage storage $ = _getOsmiNodeStorageLocation();
        $.transferLockDurationOnMint = duration;
    }

    /**
     * @dev Restricted function to mint a token to an address.
     * @param to Address to receive the token.
     */
    function safeMint(address to) public restricted {
        OsmiNodeStorage storage $ = _getOsmiNodeStorageLocation();
        uint256 tokenId = $.nextTokenId++;
        _setTransferLockedUntil(tokenId, block.timestamp + $.transferLockDurationOnMint);
        _safeMint(to, tokenId);
    }

    /**
     * @dev Transfers `tokenId` from its current owner to `to`, or alternatively mints (or burns) if the current owner
     * (or `to`) is the zero address. Returns the owner of the `tokenId` before the update.
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that
     * `auth` is either the owner of the token, or approved to operate on the token (by the owner).
     *
     * Emits a {Transfer} event.
     *
     * NOTE: If overriding this function in a way that tracks balances, see also {_increaseBalance}.
     */
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        uint lockedUntil = _getTransferLockedUntil(tokenId);
        if(lockedUntil > block.timestamp) {
            revert OsmiNodeTransferLocked(tokenId, lockedUntil);
        }
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Restricted function to authorize contract upgrades.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        restricted
        override
    {}
}