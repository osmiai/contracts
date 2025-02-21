// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IOsmiToken} from "./IOsmiToken.sol";
import {IGalaBridge} from "./IGalaBridge.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @dev OsmiDistributionManager manages unlocked daily distribution.
 */
/// @custom:security-contact contact@osmi.ai
contract OsmiDistributionManager is Initializable, AccessManagedUpgradeable, UUPSUpgradeable, EIP712Upgradeable, NoncesUpgradeable {
    bytes32 private constant TICKET_TYPEHASH = 
        keccak256("Ticket(address signer,address wallet,address pool,bytes32 expectedClaimState,bytes32 newClaimState,uint256 amount,uint256 nonce,uint256 deadline)");

    /**
     * @dev Emitted when token contract is changed.
     */
    event TokenContractChanged(IOsmiToken tokenContract);

    /**
     * @dev Emitted when token pool is changed.
     */
    event TokenPoolChanged(address tokenPool);

    /**
     * @dev Emitted when ticket signer is changed.
     */
    event TicketSignerChanged(address claimTicketSigner);

    /**
     * @dev Emitted when a bridge contract is changed.
     */
    event BridgeContractChanged(Bridge bridge, address bridgeContract);

    /**
     * @dev Emitted when claim ticket is redeemed by a user.
     */
    event TicketRedeemed(address user, uint256 amount, bytes32 state);

    /**
     * @dev Emitted when tokens are claimed.
     */
    event TokensClaimed(address from, address to, uint256 amount);

    /**
     * @dev Emitted when tokens are bridged.
     */
    event TokensBridged(address user, uint256 amount, Bridge bridge);

    /**
     * @dev Invalid ticket signer.
     */
    error InvalidTicketSigner(address signer, address one, address two);

    /**
     * @dev Invalid token pool.
     */
    error InvalidTokenPool(address pool, address expected);

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
     * @dev Insufficient balance to complete a claim.
     */
    error InsufficientBalance(address spender, uint256 balance, uint256 needed);

    /**
     * @dev Bridge identifies bridges we can use.
     */
    enum Bridge {
        None,
        GalaChain,
        Max
    }

    /**
     * @dev Ticket contains a signed ticket from the Osmi backend entitling a wallet to tranfser tokens 
     * from the node pool.
     */
    struct Ticket {
        address signer;
        address wallet;
        address pool;
        bytes32 expectedClaimState;
        bytes32 newClaimState;
        uint256 amount;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev Wallet tracks state for a wallet address.
     */
    struct Wallet {
        bytes32 claimState;
        uint256 balance;
    }

    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiDistributionManager
    struct OsmiDistributionManagerStorage {
        IOsmiToken tokenContract;
        address tokenPool;
        address [2]ticketSigners;
        mapping(address => Wallet) wallets;
        mapping(Bridge => address) bridges;
    }

    // keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiDistributionManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OsmiDistributionManagerStorageLocation = 0x55830a805815e4d506db4501e6719bc7b974e594ecdefb09d1856bf6a5d79500;

    function _getOsmiDistributionManagerStorage() private pure returns (OsmiDistributionManagerStorage storage $) {
        assembly {
            $.slot := OsmiDistributionManagerStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialAuthority, 
        address tokenContract, 
        address tokenPool, 
        address ticketSigner
    ) initializer public {
        __AccessManaged_init(initialAuthority);
        __Nonces_init();
        __UUPSUpgradeable_init();
        __EIP712_init("OsmiDistributionManager", "1");
        __UUPSUpgradeable_init();
        _setTokenContract(tokenContract);
        _setTokenPool(tokenPool);
        _setTicketSigner(ticketSigner);
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
     * @dev Public function to get a bridge contract address.
     */
    function getBridgeContract(Bridge bridge) external view returns(address) {
        return _getBridgeContract(bridge);
    }

    function _getBridgeContract(Bridge bridge) internal view returns(address) {
        require(bridge != Bridge.GalaChain, "unsupported bridge");
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        return $.bridges[bridge];
    }

    /**
     * @dev Restricted function to get a bridge contract address.
     */
    function setBridgeContract(Bridge bridge, address bridgeContract) restricted external {
        require(bridge > Bridge.None && bridge < Bridge.Max, "unsupported bridge");
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        if($.bridges[bridge] == bridgeContract) {
            return;
        }
        $.bridges[bridge] = bridgeContract;
        emit BridgeContractChanged(bridge, bridgeContract);
    }

    /**
     * @dev Public function to get the token contract.
     */
    function getTokenContract() external view returns(IOsmiToken tokenContract) {
        return _getTokenContract();
    }

    function _getTokenContract() internal view returns(IOsmiToken tokenContract) {
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        return $.tokenContract;
    }

    /**
     * @dev Restricted function to set the token contract for purchasing.
     */
    function setTokenContract(address tokenContract) restricted external {
        return _setTokenContract(tokenContract);
    }

    function _setTokenContract(address tokenContract) internal {
        require(tokenContract != address(0), "token contract can't be zero");
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        if($.tokenContract == IOsmiToken(tokenContract)) {
            return;
        }
        $.tokenContract = IOsmiToken(tokenContract);
        emit TokenContractChanged($.tokenContract);
    }

    /**
     * @dev Public function to get the token pool.
     */
    function getTokenPool() external view returns(address tokenPool) {
        return _getTokenPool();
    }

    function _getTokenPool() internal view returns(address tokenPool) {
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        return $.tokenPool;
    }

    /**
     * @dev Restricted function to set the address of the token pool.
     */
    function setTokenPool(address tokenPool) restricted external {
        return _setTokenPool(tokenPool);
    }

    function _setTokenPool(address tokenPool) internal {
        require(tokenPool != address(0), "token pool can't be zero");
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        if($.tokenPool == tokenPool) {
            return;
        }
        $.tokenPool = tokenPool;
        emit TokenPoolChanged($.tokenPool);
    }

    /**
     * @dev Return the currently recognized claim ticket signer addresses.
     */
    function getTicketSigners() external view returns(address,address) {
        return _getTicketSigners();
    }

    function _getTicketSigners() internal view returns(address,address) {
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        return ($.ticketSigners[0], $.ticketSigners[1]);
    }

    /**
     * @dev Restricted function to set the ticket signer. Signers are stored
     * in a double-buffered manner. This function only updates the latest signer, pushing
     * the previous signer into the second slot. This allows us to rotate out signing
     * accounts without downtime.
     */
    function setTicketSigner(address signer) restricted external {
        _setTicketSigner(signer);
    }

    function _setTicketSigner(address signer) internal {
        require (signer != address(0), "signer address can't be zero");
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        if($.ticketSigners[0] == signer) {
            return;
        }
        $.ticketSigners[1] = $.ticketSigners[0];
        $.ticketSigners[0] = signer;
        emit TicketSignerChanged(signer);
    }

    /**
     * @dev Restricted external function to redeem a distribution ticket and then claim tokens from the balance. The
     * new balance is returned.
     */
    function redeemAndClaim(Ticket calldata ticket, uint256 amount) restricted external returns(uint256 balance) {
        _redeemTicket(ticket);
        address caller = _msgSender();
        return _claimTokens(caller, caller, amount);
    }

    /**
     * @dev Restricted external function to redeem a distribution ticket and then bridge tokens from the balance. The
     * new balance is returned.
     */
    function redeemAndBridge(Ticket calldata ticket, uint256 amount, Bridge bridge) restricted external returns(uint256 balance) {
        _redeemTicket(ticket);
        address caller = _msgSender();
        return _bridgeTokens(caller, caller, amount, bridge);
    }

    /**
     * @dev Restricted external function to bridge tokens from the token pool into the caller's wallet on the target
     * bridge. The updated balance is returned. This function reverts on any issues.
     */
    function bridgeTokens(uint256 amount, Bridge bridge) restricted external returns(uint256 balance) {
        address caller = _msgSender();
        return _bridgeTokens(caller, caller, amount, bridge);
    }

    /**
     * @dev Internal function to bridge tokens from the token pool into a wallet on the target bridge. The updated
     * balance is returned. This function reverts on any issues.
     */
    function _bridgeTokens(address from, address to, uint256 amount, Bridge bridge) internal returns(uint256 balance) {
        // first claim tokens to the destination
        balance = _claimTokens(from, to, amount);
        // next bridge to the target
        address bridgeContract = _getBridgeContract(bridge);
        require(bridgeContract != address(0), "bridge unavailable");
        IGalaBridge(bridgeContract).bridgeOut(
            address(_getTokenContract()),
            amount,
            0,
            1,
            bytes(addressToGalaRecipient(to))
        );
        emit TokensBridged(to, amount, bridge);
        return balance;
    }

    /**
     * @dev Internal function to create a GalaChain recipent string from an address.
     */
    function addressToGalaRecipient(address addr) internal pure returns(string memory) {
        unchecked {
            bytes4 prefix = "eth|";
            bytes16 hex_digits = "0123456789abcdef";
            string memory buffer = new string(44);
            uint256 lptr;
            uint256 rptr;
            /// @solidity memory-safe-assembly
            assembly {
                lptr := add(buffer, 32)
                mstore(lptr, prefix)
                lptr := add(lptr, 4)
                rptr := add(lptr, 40)
            }
            uint256 value = uint256(uint160(addr));
            while(rptr > lptr) {
                rptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(rptr, byte(and(value, 0xf), hex_digits))
                }
                value >>= 4;
            }
            return buffer;
        }
    }

    /**
     * @dev Restricted external function to transfer `amount` tokens from the token pool into the caller's wallet. The
     * updated balance is returned. This function reverts on any issues.
     */
    function claimTokens(uint256 amount) restricted external returns(uint256 balance) {
        address caller = _msgSender();
        return _claimTokens(caller, caller, amount);
    }

    /**
     * @dev Internal function to transfer `amount` tokens from the token pool between from and to. The from wallet must
     * have sufficient balance in order to complete the transfer. This function reverts on any issues.
     */
    function _claimTokens(address from, address to, uint256 amount) internal returns(uint256 balance) {
        require(from != address(0), "from address can't be zero");
        require(to != address(0), "to address can't be zero");
        require(amount != 0, "amount can't be zero");
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        // get the source wallet
        Wallet storage wallet = $.wallets[from];
        // check the balance
        if(wallet.balance < amount) {
            revert InsufficientBalance(from, wallet.balance, amount-wallet.balance);
        }
        // transfer from node pool to destination
        $.tokenContract.transferFrom($.tokenPool, to, amount);
        // update balance
        wallet.balance -= amount;
        emit TokensClaimed(from, to, amount);
        return wallet.balance;
    }

    /**
     * @dev Restricted external function to redeem a distribution ticket. If the ticket is valid, it is consumed and 
     * the ticket's balance is credited to the ticket's wallet. This credit is applied to the internal balance
     * of the wallet. Use claimTokens to transfer internal balance to an ethereum wallet. The updated wallet balance is 
     * returned. This function will revert on any issues.
     */
    function redeem(Ticket calldata ticket) restricted external returns(uint256 balance) {
        return _redeemTicket(ticket);
    }

    /**
     * @dev Internal function to redeem a distribution ticket. The ticket is verified then applied. This function will
     * revert on any issues.
     */
    function _redeemTicket(Ticket calldata ticket) internal returns(uint256 balance) {
        _verifyTicket(ticket);
        return _applyTicket(ticket);
    }

    /**
     * @dev Internal function to verify a distribution ticket. The signature is verified along with the nonce. This 
     * function will revert on any issues.
     */
    function _verifyTicket(Ticket calldata ticket) internal {
        if (block.timestamp > ticket.deadline) {
            revert ExpiredSignature(ticket.deadline);
        }
        _validateTokenPool(ticket.pool);
        _validateTicketSigner(ticket.signer);
        bytes32 structHash = keccak256(abi.encode(
            TICKET_TYPEHASH, 
            ticket.signer, 
            ticket.wallet, 
            ticket.pool,
            ticket.expectedClaimState,
            ticket.newClaimState,
            ticket.amount, 
            _useNonce(ticket.wallet), 
            ticket.deadline
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address recoveredSigner = ECDSA.recover(hash, ticket.v, ticket.r, ticket.s);
        if (recoveredSigner != ticket.signer) {
            revert InvalidSigner(recoveredSigner, ticket.signer);
        }
    }

    /**
     * @dev Internal function to apply a distribution ticket. The ticket is assumed to be valid. This function reverts
     * on any issues.
     */
    function _applyTicket(Ticket calldata ticket) internal returns (uint256 balance) {
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        Wallet storage wallet = $.wallets[ticket.wallet];
        if(ticket.expectedClaimState != wallet.claimState) {
            revert UnexpectedClaimState(ticket.wallet, ticket.expectedClaimState, wallet.claimState);
        }
        wallet.claimState = ticket.newClaimState;
        wallet.balance += ticket.amount;
        emit TicketRedeemed(ticket.wallet, ticket.amount, wallet.claimState);
        return wallet.balance;
    }

    /**
     * @dev Internal function to check if the given address is on the ticket signer list. This function reverts
     * on any issues.
     */
    function _validateTicketSigner(address v) internal view {
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        if (v != $.ticketSigners[0] && v != $.ticketSigners[1]) {
            revert InvalidTicketSigner(v, $.ticketSigners[0], $.ticketSigners[1]);
        }
    }

    function _validateTokenPool(address v) internal view {
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        if (v != $.tokenPool) {
            revert InvalidTokenPool(v, $.tokenPool);
        }
    }    
}
