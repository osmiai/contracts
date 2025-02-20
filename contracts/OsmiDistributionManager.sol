// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IOsmiToken} from "./IOsmiToken.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @dev OsmiDistributionManager manages unlocked daily distribution.
 */
/// @custom:security-contact contact@osmi.ai
contract OsmiDistributionManager is Initializable, AccessManagedUpgradeable, UUPSUpgradeable, EIP712Upgradeable, NoncesUpgradeable {
    bytes32 private constant CLAIM_TICKET_TYPEHASH = 
        keccak256("ClaimTicket(address signer,address customer,uint256 price,uint256 nonce,uint256 deadline)");

    /**
     * @dev Emitted when token contract is changed.
     */
    event TokenContractChanged(IOsmiToken tokenContract);

    /**
     * @dev Emitted when claim ticket signer is changed.
     */
    event ClaimTicketSignerChanged(address claimTicketSigner);

    /**
     * @dev Emitted when claim ticket is redeemed by a user.
     */
    event ClaimTicketRedeemed(address user, uint256 amount, bytes32 state);

    /**
     * @dev Invalid claim ticket signer.
     */
    error InvalidClaimTicketSigner(address signer, address one, address two);

    /**
     * @dev Unexpected claimState for a user.
     */
    error UnexpectedClaimState(address user, bytes32 expected, bytes32 actual);

    /**
     * @dev Signature deadline expired.
     */
    error ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error InvalidSigner(address signer, address owner);

    /**
     * @dev DistributionClaimTicket contains a signed ticket from the Osmi backend 
     * entitling a wallet to tranfser tokens from the node pool.
     */
    struct DistributionClaimTicket {
        address signer;
        address wallet;
        address fromPool;
        bytes32 expectedClaimState;
        bytes32 newClaimState;
        uint256 amount;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct Wallet {
        bytes32 claimState;
        uint256 balance;
    }

    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiDistributionManager
    struct OsmiDistributionManagerStorage {
        IOsmiToken tokenContract;
        address [2]claimTicketSigners;
        mapping(address => Wallet) wallets;
    }

    // keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiDistributionManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OsmiDistributionManagerStorageLocation = 0x;

    function _getOsmDistributionManagerStorage() private pure returns (OsmiDistributionManagerStorage storage $) {
        assembly {
            $.slot := OsmiDistributionManagerStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority, address tokenContract, address claimTicketSigner) initializer public {
        __AccessManaged_init(initialAuthority);
        __Nonces_init();
        __UUPSUpgradeable_init();
        __EIP712_init("OsmiDistributionManager", "1");
        __UUPSUpgradeable_init();
        _setTokenContract(tokenContract);
        _setClaimTicketSigner(claimTicketSigner);
    }

    /**
     * @dev Restricted function to authorize contract upgrades.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        restricted
        override
    {}

    /**
     * @dev Restricted function to set the token contract for purchasing.
     */
    function setTokenContract(address tokenContract) restricted external {
        return _setTokenContract(tokenContract);
    }

    function _setTokenContract(address tokenContract) internal {
        require(tokenContract != address(0), "token contract can't be zero");
        OsmiDistributionManagerStorage storage $ = _getOsmDistributionManagerStorage();
        if($.tokenContract == IOsmiToken(tokenContract)) {
            return;
        }
        $.tokenContract = IOsmiToken(tokenContract);
        emit TokenContractChanged($.tokenContract);
    }

    /**
     * @dev Return the currently recognized claim ticket signer addresses.
     */
    function getClaimTicketSigners() external view returns(address,address) {
        OsmiDistributionManagerStorage storage $ = _getOsmDistributionManagerStorage();
        return ($.claimTicketSigners[0], $.claimTicketSigners[1]);
    }

    /**
     * @dev Restricted function to set the claim ticket signer. Signers are stored
     * in a double-buffered manner. This function only updates the latest signer, pushing
     * the previous signer into the second slot. This allows us to rotate out signing
     * accounts without downtime.
     */
    function setClaimTicketSigner(address signer) restricted external {
        return _setClaimTicketSigner(signer);
    }

    function _setClaimTicketSigner(address signer) internal {
        require (signer != address(0), "signer address can't be zero");
        OsmiDistributionManagerStorage storage $ = _getOsmDistributionManagerStorage();
        if($.claimTicketSigners[0] == signer) {
            return;
        }
        $.claimTicketSigners[1] = $.claimTicketSigners[0];
        $.claimTicketSigners[0] = signer;
        emit ClaimTicketSignerChanged(signer);
    }

    function _consumeClaimTicket(DistributionClaimTicket ticket) internal {
        _verifyClaimTicket(ticket);
        _applyClaimTicket(ticket);
    }

    function _verifyClaimTicket(DistributionClaimTicket ticket) internal {
        if (block.timestamp > ticket.deadline) {
            revert ExpiredSignature(ticket.deadline);
        }
        _validateClaimTicketSigner(ticket.signer);
        bytes32 structHash = keccak256(abi.encode(
            CLAIM_TICKET_TYPEHASH, 
            ticket.signer, 
            ticket.wallet, 
            ticket.fromPool,
            ticket.expectedClaimState,
            ticket.newClaimState,
            ticket.amount, 
            _useNonce(ticket.wallet), 
            deadline
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address recoveredSigner = ECDSA.recover(hash, v, r, s);
        if (recoveredSigner != signer) {
            revert InvalidSigner(recoveredSigner, signer);
        }
    }

    function _applyClaimTicket(DistributionClaimTicket ticket) internal {
        OsmiDistributionManagerStorage storage $ = _getOsmDistributionManagerStorage();
        if(expected != $.claimState[ticket.wallet]) {
            revert UnexpectedClaimState(wicket.wallet, expectedClaimState, $.claimState[ticket.wallet]);
        }
        $.claimState[ticket.wallet] = newClaimState;
        $.balance[ticket.wallet] += ticket.amount;
    }

    function _validateClaimTicketSigner(address v) internal view {
        OsmiDistributionManagerStorage storage $ = _getOsmDistributionManagerStorage();
        if (v != $.claimTicketSigners[0] && v != $.claimTicketSigners[1]) {
            revert InvalidClaimTicketSigner(v, $.claimTicketSigners[0], $.claimTicketSigners[1]);
        }
    }
}
