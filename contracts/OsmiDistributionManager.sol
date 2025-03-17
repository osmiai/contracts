// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IOsmiToken} from "./IOsmiToken.sol";
import {IOsmiStaking} from "./IOsmiStaking.sol";
import {IGalaBridge} from "./IGalaBridge.sol";
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
    bytes32 private constant TICKET_TYPEHASH = 
        keccak256("Ticket(address signer,address user,uint256 timestamp,bytes32 expectedHash,uint256 amount,uint256 nonce)");

    bytes32 private constant TICKET_CHAIN_TYPEHASH = 
        keccak256("TicketChain(bytes32 prev,address user,uint256 timestamp,uint256 amount,uint256 nonce)");

    /**
     * @dev Denominator of ratio calculations in this contract.
     */
    uint constant RATIO_DENOMINATOR = 1_000_000_000;

    /**
     * @dev Numerator of claim tax ratio.
     */
    uint constant TAX_NUMERATOR = 25_000_000;

    /**
     * @dev What's the minimum delta time between two distributions?
     */
    uint constant DISTRIBUTION_WINDOW = 1 days - 1 hours;

    /**
     * @dev Emitted when token contract is changed.
     */
    event TokenContractChanged(IOsmiToken tokenContract);

    /**
     * @dev Emitted when staking contract is changed.
     */
    event StakingContractChanged(IOsmiStaking stakingContract);

    /**
     * @dev Emitted when token pool is changed.
     */
    event TokenPoolChanged(address tokenPool);

    /**
     * @dev Emitted when ticket signer is changed.
     */
    event TicketSignerChanged(address ticketSigner);

    /**
     * @dev Emitted when a bridge contract is changed.
     */
    event BridgeContractChanged(Bridge bridge, address bridgeContract);

    /**
     * @dev Emitted when claim ticket is redeemed by a user.
     */
    event TicketRedeemed(address user, uint256 amount, uint256 timestamp);

    /**
     * @dev Emitted when tokens are claimed.
     */
    event TokensClaimed(address user, uint256 amount, Bridge bridge);

    /**
     * @dev Emitted when tokens are bridged to a custom target.
     */
    event TokensBridgedTo(address user, uint256 amount, Bridge bridge, string target);

    /**
     * @dev Invalid ticket signer.
     */
    error InvalidTicketSigner(address signer, address one, address two);

    /**
     * @dev Mismatched signature.
     */
    error InvalidSigner(address signer, address owner);

    /**
     * @dev Insufficient allowance to transfer tokens.
     */
    error InsufficientAllowance(address user, uint256 allowance, uint256 needed);

    /**
     * @dev Invalid ticket hash.
     */
    error InvalidTicketHash(bytes32 expected, bytes32 actual);

    /**
     * @dev Bridge identifies bridges we can use.
     */
    enum Bridge {
        None,
        GalaChain,
        Max
    }

    /**
     * @dev Ticket contains a signed ticket from the Osmi backend entitling a wallet to transfer tokens 
     * from the node pool.
     */
    struct Ticket {
        address signer;
        address user;
        uint256 timestamp;
        bytes32 expectedHash;
        uint256 amount;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev Wallet tracks state for a wallet address.
     */
    struct Wallet {
        uint256 allowance;
        uint256 lastTicketTimestamp;
        bytes32 lastTicketHash;
    }

    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiDistributionManager
    struct OsmiDistributionManagerStorage {
        IOsmiToken tokenContract;
        address tokenPool;
        address [2]ticketSigners;
        mapping(address => Wallet) wallets;
        mapping(Bridge => address) bridges;
        IOsmiStaking stakingContract;
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
        require(bridge == Bridge.GalaChain, "unsupported bridge");
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
     * @dev Public function to get the staking contract.
     */
    function getStakingContract() external view returns(IOsmiStaking stakingContract) {
        return _getStakingContract();
    }

    function _getStakingContract() internal view returns(IOsmiStaking stakingContract) {
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        return $.stakingContract;
    }

    /**
     * @dev Restricted function to set the staking contract.
     */
    function setStakingContract(address stakingContract) restricted external {
        return _setStakingContract(stakingContract);
    }

    function _setStakingContract(address stakingContract) internal {
        require(stakingContract != address(0), "address can't be zero");
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        if($.stakingContract == IOsmiStaking(stakingContract)) {
            return;
        }
        $.stakingContract = IOsmiStaking(stakingContract);
        emit StakingContractChanged($.stakingContract);
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
     * @dev Restricted external function to redeem a distribution ticket and then claim tokens from the allowance. The
     * new allowance is returned.
     */
    function redeemAndClaim(Ticket calldata ticket, uint256 amount) restricted external returns(uint256 allowance) {
        _redeemTicket(ticket);
        return _claimTokens(_msgSender(), amount);
    }

    /**
     * @dev Restricted external function to redeem a distribution ticket and then bridge tokens from the allowance. The
     * new allowance is returned.
     */
    function redeemAndBridge(Ticket calldata ticket, uint256 amount, Bridge bridge) restricted external returns(uint256 allowance) {
        _redeemTicket(ticket);
        return _bridgeTokens(_msgSender(), amount, bridge, "");
    }

    /**
     * @dev Restricted external function to redeem a distribution ticket and then stake tokens from the allowance. The
     * new allowance is returned.
     */
    function redeemAndStake(Ticket calldata ticket, uint256 amount) restricted external returns(uint256 allowance) {
        _redeemTicket(ticket);
        return _stakeTokens(_msgSender(), amount);
    }

    /**
     * @dev Restricted external function to redeem a distribution ticket and then bridge tokens from the allowance to
     * an address alias on GalaChain. The new allowance is returned.
     * 
     * HACK, REMOVE LATER
     */
    function redeemAndBridgeToGalaChainAlias(
        Ticket calldata ticket, uint256 amount, string calldata targetAlias
    ) restricted external returns(uint256 allowance) {
        _redeemTicket(ticket);
        return _bridgeTokens(_msgSender(), amount, Bridge.GalaChain, targetAlias);
    }

    /**
     * @dev Restricted external function to claim and bridge tokens from the token pool into the caller's wallet on the
     * target bridge. The updated allowance is returned.
     */
    function bridgeTokens(uint256 amount, Bridge bridge) restricted external returns(uint256 allowance) {
        return _bridgeTokens(_msgSender(), amount, bridge, "");
    }

    /**
     * @dev Restricted external function to claim and bridge tokens from the caller's token pool allowange into a 
     * target wallet on GalaChain. The updated allowance is returned.
     * 
     * HACK, REMOVE LATER
     */
    function bridgeTokensToGalaChainAlias(
        uint256 amount, string calldata targetAlias
    ) restricted external returns(uint256 allowance) {
        return _bridgeTokens(_msgSender(), amount, Bridge.GalaChain, targetAlias);
    }

    /**
     * @dev Internal function to claim and bridge tokens from the token pool into a wallet on the target bridge. The 
     * updated allowance is returned.
     */
    function _bridgeTokens(
        address user, uint256 amount, Bridge bridge, string memory target
    ) internal returns(uint256 allowance) {
        require(user != address(0), "user address can't be zero");
        require(amount != 0, "amount can't be zero");
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        // get the source wallet
        Wallet storage wallet = $.wallets[user];
        // check the allowance
        if(wallet.allowance < amount) {
            revert InsufficientAllowance(user, wallet.allowance, amount-wallet.allowance);
        }
        // update allowance
        wallet.allowance -= amount;
        // emit event
        emit TokensClaimed(user, amount, bridge);
        // calculate and deduct tax
        uint256 tax = Math.mulDiv(amount, TAX_NUMERATOR, RATIO_DENOMINATOR);
        amount -= tax;
        // burn tax and transfer amount to this contract
        $.tokenContract.burnFrom($.tokenPool, tax);
        $.tokenContract.transferFrom($.tokenPool, address(this), amount);
        // bridge from this contract to the recipient on the bridge
        address bridgeContract = _getBridgeContract(bridge);
        require(bridgeContract != address(0), "bridge unavailable");
        // approve transfer from this contract to the bridge
        $.tokenContract.approve(bridgeContract, amount);
        // SNICHOLS: generalize this?
        if(bytes(target).length == 0) {
            target = addressToGalaRecipient(user);
        } else {
            // emit bridged to event
            emit TokensBridgedTo(user, amount, bridge, target);
        }
        IGalaBridge(bridgeContract).bridgeOut(
            address(_getTokenContract()),
            amount,
            0,
            1,
            bytes(target)
        );
        return wallet.allowance;
    }

    /**
     * @dev Internal function to create a GalaChain recipent string from an address.
     */
    function addressToGalaRecipient(address addr) internal pure returns(string memory) {
        bytes4 prefix = "eth|";
        bytes16 hex_digits = "0123456789abcdef";
        bytes16 hex_digits_upper = "0123456789ABCDEF";
        // allocate buffer for the whole string
        string memory buffer = new string(44);
        /// @solidity memory-safe-assembly
        assembly {
            let lptr := add(buffer, 32)
            // store and skip prefix
            mstore(lptr, prefix)
            lptr := add(lptr, 4)
            // rptr at end of buffer
            let rptr := add(lptr, 40)
            // loop over each address nibble and convert to hex digit
            let addrValue := addr
            for {} gt(rptr, lptr) {} {
                rptr := sub(rptr, 1)
                mstore8(rptr, byte(and(addrValue, 0xf), hex_digits))
                addrValue := shr(4, addrValue)
            }
            // compute hash of the buffer without prefix
            let hashValue := shr(96, keccak256(lptr, 40))
            // loop over each hash hibble and convert address bytes to uppercase
            addrValue := addr
            rptr := add(lptr, 40)
            for {} gt(rptr, lptr) {} {
                rptr := sub(rptr, 1)
                if gt(and(hashValue, 0xf), 7) {
                    mstore8(rptr, byte(and(addrValue, 0xf), hex_digits_upper))
                }
                addrValue := shr(4, addrValue)
                hashValue := shr(4, hashValue)
            }
        }
        return buffer;
    }

    /**
     * @dev Restricted external function to transfer `amount` tokens from the token pool into the caller's wallet. The
     * updated allowance is returned.
     */
    function claimTokens(uint256 amount) restricted external returns(uint256 allowance) {
        return _claimTokens(_msgSender(), amount);
    }

    /**
     * @dev Attempt to transfer from the token pool into the user's wallet.
     */
    function _claimTokens(address user, uint256 amount) internal returns(uint256 allowance) {
        require(user != address(0), "user address can't be zero");
        require(amount != 0, "amount can't be zero");
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        // get the source wallet
        Wallet storage wallet = $.wallets[user];
        // check the allowance
        if(wallet.allowance < amount) {
            revert InsufficientAllowance(user, wallet.allowance, amount-wallet.allowance);
        }
        // update allowance
        wallet.allowance -= amount;
        // emit event
        emit TokensClaimed(user, amount, Bridge.None);
        // calculate and deduct tax
        uint256 tax = Math.mulDiv(amount, TAX_NUMERATOR, RATIO_DENOMINATOR);
        amount -= tax;
        // burn tax and transfer from node pool
        $.tokenContract.burnFrom($.tokenPool, tax);
        $.tokenContract.transferFrom($.tokenPool, user, amount);
        return wallet.allowance;
    }

    /**
     * @dev Restricted external function to stake `amount` tokens from the token pool into staking. The
     * updated allowance is returned.
     */
    function stakeTokens(uint256 amount) restricted external returns(uint256 allowance) {
        return _stakeTokens(_msgSender(), amount);
    }

    function _stakeTokens(address user, uint256 amount) internal returns(uint256 allowance) {
        require(user != address(0), "user address can't be zero");
        require(amount != 0, "amount can't be zero");
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        // get the source wallet
        Wallet storage wallet = $.wallets[user];
        // check the allowance
        if(wallet.allowance < amount) {
            revert InsufficientAllowance(user, wallet.allowance, amount-wallet.allowance);
        }
        // update allowance
        wallet.allowance -= amount;
        // emit event
        emit TokensClaimed(user, amount, Bridge.None);
        // transfer amount to this contract
        $.tokenContract.transferFrom($.tokenPool, address(this), amount);
        // approve transfer from this contract to the staking contract
        $.tokenContract.approve(address($.stakingContract), amount);
        // stake amount tokens on behalf of user
        $.stakingContract.stakeFor(user, amount);
        return wallet.allowance;
    }

    /**
     * @dev Restricted external function to redeem a distribution ticket. If the ticket is valid, it is consumed and 
     * the ticket's amount is credited to the user's allowance.
     */
    function redeem(Ticket calldata ticket) restricted external returns(uint256 allowance) {
        return _redeemTicket(ticket);
    }

    /**
     * @dev Internal function to redeem a distribution ticket. The ticket is verified then applied.
     */
    function _redeemTicket(Ticket calldata ticket) internal returns(uint256 allowance) {
        // verify signature
        uint256 nonce = _verifyTicketSignature(ticket);
        // get wallet
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        Wallet storage wallet = $.wallets[ticket.user];
        // verify ticket state
        require(ticket.amount > 0, "amount cannot be zero");
        require(ticket.user != address(0), "user address cannot be zero");
        // verify ticket timing
        uint256 tt = ticket.timestamp;
        uint256 ltt = wallet.lastTicketTimestamp;
        require((block.timestamp-tt) <= DISTRIBUTION_WINDOW, "ticket expired");
        require((tt-ltt) >= DISTRIBUTION_WINDOW, "ticket issued too soon");
        // check ticket chain
        if(ticket.expectedHash != wallet.lastTicketHash) {
            revert InvalidTicketHash(ticket.expectedHash, wallet.lastTicketHash);
        }
        // update wallet state
        wallet.allowance += ticket.amount;
        wallet.lastTicketTimestamp = ticket.timestamp;
        bytes32 structHash = keccak256(abi.encode(
            TICKET_CHAIN_TYPEHASH,
            wallet.lastTicketHash,
            ticket.user,
            ticket.timestamp,
            ticket.amount,
            nonce
        ));
        wallet.lastTicketHash = _hashTypedDataV4(structHash);
        // emit event
        emit TicketRedeemed(ticket.user, ticket.amount, tt);
        return wallet.allowance;
    }

    /**
     * @dev Internal function to verify a distribution ticket signature along with the nonce.
     */
    function _verifyTicketSignature(Ticket calldata ticket) internal returns (uint256 nonce) {
        _validateTicketSigner(ticket.signer);
        nonce = _useNonce(ticket.user);
        bytes32 structHash = keccak256(abi.encode(
            TICKET_TYPEHASH, 
            ticket.signer, 
            ticket.user, 
            ticket.timestamp,
            ticket.expectedHash,
            ticket.amount, 
            nonce
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address recoveredSigner = ECDSA.recover(hash, ticket.v, ticket.r, ticket.s);
        if (recoveredSigner != ticket.signer) {
            revert InvalidSigner(recoveredSigner, ticket.signer);
        }
        return nonce;
    }

    /**
     * @dev Internal function to check if the given address is on the ticket signer list.
     */
    function _validateTicketSigner(address v) internal view {
        OsmiDistributionManagerStorage storage $ = _getOsmiDistributionManagerStorage();
        if (v != $.ticketSigners[0] && v != $.ticketSigners[1]) {
            revert InvalidTicketSigner(v, $.ticketSigners[0], $.ticketSigners[1]);
        }
    }
}
