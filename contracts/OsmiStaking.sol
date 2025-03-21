// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IOsmiConfig} from "./IOsmiConfig.sol";
import {IOsmiToken} from "./IOsmiToken.sol";
import {IOsmiDistributionManager} from "./IOsmiDistributionManager.sol";
import {IOsmiDailyDistribution} from "./IOsmiDailyDistribution.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @dev OsmiStaking manages staking of OSMI token.
 */
/// @custom:security-contact contact@osmi.ai
contract OsmiStaking is Initializable, AccessManagedUpgradeable, UUPSUpgradeable, EIP712Upgradeable, NoncesUpgradeable {
    bytes32 private constant BALANCE_TICKET_TYPEHASH = 
        keccak256("Ticket(address user,uint256 timestamp,uint256 balance,uint256 nonce)");

    /**
     * @dev Default APY numerator.
     */
    uint256 constant DEFAULT_APY_NUMERATOR = 160_000_000;

    /**
     * @dev Denominator of ratio calculations in this contract.
     */
    uint256 constant RATIO_DENOMINATOR = 1_000_000_000;

    /**
     * @dev Numerator of fast withdrawal tax (10%).
     */
    uint constant FAST_WITHDRAWAL_TAX_NUMERATOR = 100_000_000;

    /**
     * @dev Max APY numerator setting. (100%)
     */
    uint256 constant APY_NUMERATOR_MAX = RATIO_DENOMINATOR;

    /**
     * @dev Delay for normal withdrawals.
     */
    uint256 constant WITHDRAWAL_DELAY = 14 days;

    // errors
    error Uncancelable();
    error InsufficientBalance();
    error APYOutOfRange();
    error InvalidTicketSigner();
    error WrongTicketOwner();
    error WithdrawalAlreadyInProgress();
    error ZeroAddressNotAllowed();
    error ZeroAmountNotAllowed();

    // events
    event APYChanged(uint256 apy);
    event ConfigContractChanged(IOsmiConfig configContract);
    event TicketSignerChanged(address ticketSigner);
    event TokensDeposited(address from, address to, uint256 amount);
    event AutoStakeChanged(address user, bool value);
    event StreakStartTimeChanged(address user, uint256 value);
    event WithdrawalStarted(address user, uint256 timestamp, uint256 availableAt, uint256 amount);
    event WithdrawalCanceled(address user, uint256 availableAt, uint256 amount);

    /**
     * @dev Ticket is a signed message from the Osmi backend that permits the user to withdraw.
     */
    struct Ticket {
        address user;
        uint256 timestamp;
        uint256 balance;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // flags
    uint256 constant FLAG_AUTOSTAKE = 1 << 0;

    /**
     * @dev Staking state for an address.
     */
    struct Stake {
        // flags for this stake (see FLAG_XXX)
        uint256 flags;
        // timestamp of when this stake's streak started
        uint256 streakStartTime;
        // available timestamp of pending withdrawal
        uint256 withdrawalAvailableAt;
        // amount of pending withdrawal from node
        uint256 withdrawalAmount;
    }

    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiStakingStorage
    struct OsmiStakingStorage {
        IOsmiConfig configContract;
        address [2]ticketSigners;
        uint256 apyNumerator;
        mapping(address => Stake) stakes;
    }

    // keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiStaking")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OsmiStakingStorageLocation = 0xa3c4f2f291c8b2e507af98f0821c9deaec9b9fc659bd5466e3124818ea083600;

    function _getOsmiStakingStorage() private pure returns (OsmiStakingStorage storage $) {
        assembly {
            $.slot := OsmiStakingStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialAuthority,
        IOsmiConfig configContract,
        address ticketSigner
    ) initializer public {
        __AccessManaged_init(initialAuthority);
        __Nonces_init();
        __EIP712_init("OsmiStaking", "1");
        __UUPSUpgradeable_init();
        _setConfigContract(configContract);
        _setTicketSigner(ticketSigner);
        _setAPY(DEFAULT_APY_NUMERATOR);
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
     * @dev Return the currec config contract.
     */
    function getConfigContract() external view returns(IOsmiConfig) {
        return _getConfigContract();
    }

    function _getConfigContract() internal view returns(IOsmiConfig) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        return $.configContract;
    }

    /**
     * @dev Restricted function to set the config contract.
     */
    function setConfigContract(IOsmiConfig v) external restricted {
        _setConfigContract(v);
    }

    function _setConfigContract(IOsmiConfig v) internal {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        if($.configContract == v) {
            return;
        }
        $.configContract = v;
        emit ConfigContractChanged(v);
    }

    /**
     * @dev Return the current APY.
     */
    function getAPY() external view returns(uint256) {
        return _getAPY();
    }

    function _getAPY() internal view returns(uint256) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        return $.apyNumerator;
    }

    /**
     * @dev Restricted function to set the APY numerator.
     */
    function setAPY(uint256 v) external restricted {
        _setAPY(v);
    }

    function _setAPY(uint256 v) internal {
        if(v == 0 || v > APY_NUMERATOR_MAX) {
            revert APYOutOfRange();
        }
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        if($.apyNumerator == v) {
            return;
        }
        $.apyNumerator = v;
        emit APYChanged(v);
    }

    /**
     * @dev Return the currently recognized ticket signer addresses.
     */
    function getTicketSigners() external view returns(address,address) {
        return _getTicketSigners();
    }

    function _getTicketSigners() internal view returns(address,address) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        return ($.ticketSigners[0], $.ticketSigners[1]);
    }

    /**
     * @dev Restricted function to set the ticket signer. Signers are storedin a double-buffered manner. This function 
     * only updates the latest signer, pushing the previous signer into the second slot. This allows us to rotate out 
     * signing accounts without downtime.
     */
    function setTicketSigner(address signer) restricted external {
        _setTicketSigner(signer);
    }

    function _setTicketSigner(address signer) internal {
        require (signer != address(0), "signer address can't be zero");
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        if($.ticketSigners[0] == signer) {
            return;
        }
        $.ticketSigners[1] = $.ticketSigners[0];
        $.ticketSigners[0] = signer;
        emit TicketSignerChanged(signer);
    }

    /**
     * @dev Restricted external function to set auto staking for the caller.
     */
    function setAutoStake(bool v) external restricted {
        _setAutoStake(_msgSender(), v);
    }

    /**
     * @dev Restricted external function to set auto staking for a user.
     */
    function setAutoStakeFor(address user, bool v) external restricted {
        _setAutoStake(user, v);
    }

    function _setAutoStake(address user, bool v) internal {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        Stake storage s = $.stakes[user];
        bool cur = (s.flags & FLAG_AUTOSTAKE) == FLAG_AUTOSTAKE;
        if(v != cur) {
            emit AutoStakeChanged(user, v);
            if(v) {
                s.flags |= FLAG_AUTOSTAKE;
            } else {
                s.flags &= ~FLAG_AUTOSTAKE;
            }
        }
    }

    /**
     * @dev Returns the auto stake setting for the caller.
     */
    function getAutoStake() external view returns (bool) {
        return _getAutoStake(_msgSender());
    }

    /**
     * @dev Returns the auto stake setting for a user.
     */
    function getAutoStakeFor(address user) external view returns (bool) {
        return _getAutoStake(user);
    }

    function _getAutoStake(address user) internal view returns(bool) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        Stake storage s = $.stakes[user];
        bool cur = (s.flags & FLAG_AUTOSTAKE) == FLAG_AUTOSTAKE;
        return cur;
    }

    /**
     * @dev Restricted external function to stake from the caller's account into the user's account.
     */
    function stakeFor(address user, uint256 amount) external restricted {
        _stake(_msgSender(), user, amount);
    }

    function _stake(address from, address to, uint256 amount) internal {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        // get configured addresses
        IOsmiToken tokenContract = _getTokenContract();
        address stakingPool = _getStakingPool();
        // transfer tokens to the staking pool
        tokenContract.transferFrom(from, stakingPool, amount);
        // add to stake
        Stake storage s = $.stakes[to];
        emit TokensDeposited(from, to, amount);
        // update streak start time if this is the first stake
        if(s.streakStartTime == 0) {
            IOsmiDailyDistribution dailyDistro = _getDailyDistroContract();
            s.streakStartTime = dailyDistro.getLastDistributionTime();
            emit StreakStartTimeChanged(to, s.streakStartTime);
        }
    }

    /**
     * @dev Restricted function to initiate a withdrawal of staked tokens for the caller.
     */
    function withdraw(Ticket calldata ticket, uint256 amount, bool fast) external restricted {
        _withdraw(ticket, _msgSender(), amount, fast);
    }

    function _withdraw(Ticket calldata ticket, address user, uint256 amount, bool fast) internal {
        if(user == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        if(amount == 0) {
            revert ZeroAmountNotAllowed();
        }
        // verify ticket state
        if(ticket.user != user) {
            revert WrongTicketOwner();
        }
        if(amount > ticket.balance) {
            revert InsufficientBalance();
        }
        _verifyTicketSignature(ticket);
        // update state
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        Stake storage s = $.stakes[user];
        // disallow multiple pending withdrawals
        if(s.withdrawalAvailableAt > block.timestamp) {
            revert WithdrawalAlreadyInProgress();
        }
        // get configured addresses
        IOsmiToken tokenContract = _getTokenContract();
        IOsmiDailyDistribution dailyDistro = _getDailyDistroContract();
        address stakingPool = _getStakingPool();
        address nodeRewardPool = _getNodeRewardPool();
        // get last daily distro time
        uint256 lastDistroTime = dailyDistro.getLastDistributionTime();
        // update streak start time
        if(amount == ticket.balance) {
            s.streakStartTime = 0;
        } else {
            s.streakStartTime = lastDistroTime;
        }
        emit StreakStartTimeChanged(user, s.streakStartTime);
        if(fast) {
            // calculate and deduct tax
            uint256 tax = Math.mulDiv(amount, FAST_WITHDRAWAL_TAX_NUMERATOR, RATIO_DENOMINATOR);
            amount -= tax;
            if(tax > 0) {
                // burn tax
                tokenContract.burnFrom(stakingPool, tax);
            }
            // emit event; amount is available now
            emit WithdrawalStarted(user, block.timestamp, block.timestamp, amount);
        } else {
            // configure pending withdrawal
            s.withdrawalAmount = amount;
            s.withdrawalAvailableAt = lastDistroTime + WITHDRAWAL_DELAY;
            // emit event; amount is available later
            emit WithdrawalStarted(user, block.timestamp, s.withdrawalAvailableAt, amount);
        }
        // Transfer from the staking pool to the node rewards pool. We do this now to ensure tokens are available
        // to claim when the withdrawal delay is over. Otherwise we'd need another transaction. See _cancelWithdrawal
        // for the reclaim transfer when canceling.
        tokenContract.transferFrom(stakingPool, nodeRewardPool, amount);
        if(fast) {
            // fast withdrawal immediately credits to the distribution manager available allowance for the user
            _getDistroManagerContract().tokensUnstaked(user, amount);
        }
    }

    /**
     * @dev Restricted external function to cancel a withdrawal for the caller.
     */
    function cancelWithdrawal() external restricted {
        return _cancelWithdrawal(_msgSender());
    }

    /**
     * @dev Internal function to cancel a stake withdrawal.
     */
    function _cancelWithdrawal(address user) internal {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        Stake storage s = $.stakes[user];
        if(s.withdrawalAvailableAt == 0) {
            return;
        }
        if(s.withdrawalAmount == 0) {
            revert ZeroAmountNotAllowed();
        }
        if(block.timestamp >= s.withdrawalAvailableAt) {
            revert Uncancelable();
        }
        // get configured addresses
        IOsmiToken tokenContract = _getTokenContract();
        address stakingPool = _getStakingPool();
        address nodeRewardPool = _getNodeRewardPool();
        // emit event
        emit WithdrawalCanceled(user, s.withdrawalAvailableAt, s.withdrawalAmount);
        // transfer from the node reward pool back to the staking pool
        tokenContract.transferFrom(nodeRewardPool, stakingPool, s.withdrawalAmount);
        // zero out the request
        s.withdrawalAvailableAt = 0;
        s.withdrawalAmount = 0;
    }

    function _verifyTicketSignature(Ticket calldata ticket) internal returns (uint256 nonce) {
        nonce = _useNonce(ticket.user);
        bytes32 structHash = keccak256(abi.encode(
            BALANCE_TICKET_TYPEHASH, 
            ticket.user, 
            ticket.timestamp,
            ticket.balance, 
            nonce
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address recoveredSigner = ECDSA.recover(hash, ticket.v, ticket.r, ticket.s);
        _validateTicketSigner(recoveredSigner);
        return nonce;
    }

    function _validateTicketSigner(address v) internal view {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        if (v != $.ticketSigners[0] && v != $.ticketSigners[1]) {
            revert InvalidTicketSigner();
        }
    }

    function _getDailyDistroContract() internal view returns(IOsmiDailyDistribution) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        return (IOsmiDailyDistribution)($.configContract.getDailyDistributionContract());
    }

    function _getTokenContract() internal view returns(IOsmiToken) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        return (IOsmiToken)($.configContract.getTokenContract());
    }

    function _getDistroManagerContract() internal view returns(IOsmiDistributionManager) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        return (IOsmiDistributionManager)($.configContract.getDistributionManagerContract());
    }

    function _getStakingPool() internal view returns(address) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        return $.configContract.getStakingPool();
    }

    function _getNodeRewardPool() internal view returns(address) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        return $.configContract.getNodeRewardPool();
    }
}
