// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IOsmiToken} from "./IOsmiToken.sol";
import {IOsmiNode} from "./IOsmiNode.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact contact@osmi.ai
contract OsmiNodeFactory is Initializable, AccessManagedUpgradeable, UUPSUpgradeable, EIP712Upgradeable, NoncesUpgradeable {
    bytes32 private constant PURCHASE_TICKET_TYPEHASH = 
        keccak256("PurchaseTicket(address signer,address customer,uint256 price,uint256 nonce,uint256 deadline)");

    /**
     * @dev Emitted when token contract is changed.
     */
    event TokenContractChanged(IOsmiToken tokenContract);

    /**
     * @dev Emitted when node contract is changed.
     */
    event NodeContractChanged(IOsmiNode nodeContract);

    /**
     * @dev Emitted when purchase ticket signer is changed.
     */
    event PurchaseTicketSignerChanged(address purchaseTicketSigner);

    /**
     * @dev Signature deadline expired.
     */
    error OsmiExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error OsmiInvalidSigner(address signer, address owner);

    /**
     * @dev Invalid purchase ticket signer.
     */
    error OsmiInvalidPurchaseTicketSigner(address signer, address one, address two);

    /**
     * @dev ERC20PermitAllowance contains a signed ERC20Permit allowance request. This
     * is used to set the factory's allowance when purchasing.
     */
    struct ERC20PermitAllowance {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev OsmiNodePurchaseTicket contains a signed ticket from the Osmi backend 
     * entitling the customer to burn tokens in order to receive an OsmiNode NFT.
     */
    struct OsmiNodePurchaseTicket {
        address signer;
        address customer;
        uint256 price;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiNodeFactory
    struct OsmiNodeFactoryStorage {
        IOsmiToken tokenContract;
        IOsmiNode nodeContract;
        address [2]purchaseTicketSigners;
    }

    // keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiNodeFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OsmiNodeFactoryStorageLocation = 0x0fcd9c378940f300c1be3c1a4577c232db834454ea38358b32a770dd9ba76900;

    function _getOsmiNodeFactoryStorageLocation() private pure returns (OsmiNodeFactoryStorage storage $) {
        assembly {
            $.slot := OsmiNodeFactoryStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority, address tokenContract, address nodeContract, address purchaseTicketSigner) initializer public {
        __AccessManaged_init(initialAuthority);
        __Nonces_init();
        __UUPSUpgradeable_init();
        __EIP712_init("OsmiNodeFactory", "1");
        _setTokenContract(tokenContract);
        _setNodeContract(nodeContract);
        _setPurchaseTicketSigner(purchaseTicketSigner);
    }

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
        OsmiNodeFactoryStorage storage $ = _getOsmiNodeFactoryStorageLocation();
        if($.tokenContract == IOsmiToken(tokenContract)) {
            return;
        }
        $.tokenContract = IOsmiToken(tokenContract);
        emit TokenContractChanged($.tokenContract);
    }

    /**
     * @dev Restricted function to set the node contract for purchasing.
     */
    function setNodeContract(address nodeContract) restricted external {
        return _setNodeContract(nodeContract);
    }

    function _setNodeContract(address nodeContract) internal {
        require(nodeContract != address(0), "node contract can't be zero");
        OsmiNodeFactoryStorage storage $ = _getOsmiNodeFactoryStorageLocation();
        if($.nodeContract == IOsmiNode(nodeContract)) {
            return;
        }
        $.nodeContract = IOsmiNode(nodeContract);
        emit NodeContractChanged($.nodeContract);
    }

    /**
     * @dev Return the currently recognized purchase ticket signer addresses.
     */
    function getPurchaseTicketSigners() external view returns(address,address) {
        OsmiNodeFactoryStorage storage $ = _getOsmiNodeFactoryStorageLocation();
        return ($.purchaseTicketSigners[0], $.purchaseTicketSigners[1]);
    }

    /**
     * @dev Restricted function to set the purchase ticket signer. Signers are stored
     * in a double-buffered manner. This function only updates the latest signer, pushing
     * the previous signer into the second slot. This allows us to rotate out signing
     * accounts without downtime.
     */
    function setPurchaseTicketSigner(address purchaseTicketSigner) restricted external {
        return _setPurchaseTicketSigner(purchaseTicketSigner);
    }

    function _setPurchaseTicketSigner(address purchaseTicketSigner) internal {
        require (purchaseTicketSigner != address(0), "signer address can't be zero");
        OsmiNodeFactoryStorage storage $ = _getOsmiNodeFactoryStorageLocation();
        if($.purchaseTicketSigners[0] == purchaseTicketSigner) {
            return;
        }
        $.purchaseTicketSigners[1] = $.purchaseTicketSigners[0];
        $.purchaseTicketSigners[0] = purchaseTicketSigner;
        emit PurchaseTicketSignerChanged(purchaseTicketSigner);
    }

    /**
     * @dev Restricted function to buy an OsmiNode by burning $OSMI. Returns the id of the token if successful.
     */
    function buyOsmiNode(OsmiNodePurchaseTicket calldata ticket, ERC20PermitAllowance calldata allowance) restricted external returns (uint256) {
        return _buyOsmiNode(ticket, allowance);
    }

    function _buyOsmiNode(OsmiNodePurchaseTicket calldata ticket, ERC20PermitAllowance calldata allowance) internal returns (uint256) {
        require(allowance.spender == address(this), "this is not the allowance spender");
        OsmiNodeFactoryStorage storage $ = _getOsmiNodeFactoryStorageLocation();
        // consume purchase ticket
        _consumePurchaseTicket(
            ticket.signer,
            ticket.customer,
            ticket.price,
            ticket.deadline,
            ticket.v,
            ticket.r,
            ticket.s
        );
        // set token allowance
        $.tokenContract.permit(
            allowance.owner,
            allowance.spender,
            allowance.value,
            allowance.deadline,
            allowance.v,
            allowance.r,
            allowance.s
        );
        // burn the token allowance
        $.tokenContract.burnFrom(allowance.owner, allowance.value);
        // mint NFT to customer
        $.nodeContract.safeMint(ticket.customer);
        // return token id
        return $.nodeContract.getTotalSupply() - 1;
    }

    function _consumePurchaseTicket(
        address signer, 
        address customer, 
        uint256 price, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) internal {
        if (block.timestamp > deadline) {
            revert OsmiExpiredSignature(deadline);
        }

        _validatePurchaseTicketSigner(signer);

        bytes32 structHash = keccak256(abi.encode(
            PURCHASE_TICKET_TYPEHASH, 
            signer, 
            customer, 
            price, 
            _useNonce(customer), 
            deadline
        ));

        bytes32 hash = _hashTypedDataV4(structHash);

        address recoveredSigner = ECDSA.recover(hash, v, r, s);
        if (recoveredSigner != signer) {
            revert OsmiInvalidSigner(recoveredSigner, signer);
        }
    }

    function _validatePurchaseTicketSigner(address v) internal view {
        OsmiNodeFactoryStorage storage $ = _getOsmiNodeFactoryStorageLocation();
        if (v != $.purchaseTicketSigners[0] && v != $.purchaseTicketSigners[1]) {
            revert OsmiInvalidPurchaseTicketSigner(v, $.purchaseTicketSigners[0], $.purchaseTicketSigners[1]);
        }
    }
}
