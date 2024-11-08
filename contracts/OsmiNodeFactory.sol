// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IOsmiToken} from "./IOsmiToken.sol";
import {OsmiNode} from "./OsmiNode.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact contact@osmi.ai
contract OsmiNodeFactory is Initializable, AccessManagedUpgradeable, UUPSUpgradeable, EIP712Upgradeable, NoncesUpgradeable {
    /**
     * @dev Emitted when token contract is changed.
     */
    event TokenContractChanged(IOsmiToken tokenContract);

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
     * entitling the customer to burn tokens in order to receive an OsmiNodeNFT.
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
        OsmiNode nodeContract;
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

    function initialize(address initialAuthority, address tokenContract) initializer public {
        __AccessManaged_init(initialAuthority);
        __Nonces_init();
        __UUPSUpgradeable_init();
        __EIP712_init("OsmiNodeFactory", "1");
        _setTokenContract(tokenContract);
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
            // nothing to do
            return;
        }
        $.tokenContract = IOsmiToken(tokenContract);
        emit TokenContractChanged($.tokenContract);
    }

    /**
     * @dev Restricted function to buy an OsmiNode by burning $OSMI. Returns the id of the token if successful.
     */
    function buyOsmiNode(OsmiNodePurchaseTicket calldata ticket, ERC20PermitAllowance calldata allowance) restricted external returns (uint256) {
        return _buyOsmiNode(ticket, allowance);
    }

    function _buyOsmiNode(OsmiNodePurchaseTicket calldata ticket, ERC20PermitAllowance calldata allowance) internal returns (uint256) {
        require(allowance.spender == address(this), "this is not allowance spender");
        OsmiNodeFactoryStorage storage $ = _getOsmiNodeFactoryStorageLocation();
        // consume purchase ticticket
        _consumePurchaseTicket(ticket);
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

    function _consumePurchaseTicket(OsmiNodePurchaseTicket calldata ticket) internal {
        require(false, "not implemented");
    }
}
