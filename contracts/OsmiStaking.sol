// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IOsmiConfig} from "./IOsmiConfig.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @dev OsmiStaking manages staking of OSMI token.
 */
/// @custom:security-contact contact@osmi.ai
contract OsmiStaking is Initializable, AccessManagedUpgradeable, UUPSUpgradeable, EIP712Upgradeable, NoncesUpgradeable {
    /**
     * @dev How long to hold withdrawals before finalizing.
     */
    uint256 constant WITHDRAWAL_HOLDING_PERIOD = 14 days;

    /**
     * @dev Denominator of ratio calculations in this contract.
     */
    uint256 constant RATIO_DENOMINATOR = 1_000_000_000;

    /**
     * @dev Max APY numerator setting. (100%)
     */
    uint256 constant APY_NUMERATOR_MAX = RATIO_DENOMINATOR;

    // errors
    error ErrNotFound();
    error ErrUncancelable();
    error ErrNotEnoughStake();
    error ErrReusedStorage();
    error ErrItemRequired();
    error ErrPopulatedListRequired();
    error APYOutOfRange();
    error DurationOutOfRange();
    error InvalidTicketSigner(address signer, address one, address two);

    // events
    event HoldingPeriodChanged(uint256 duration);
    event APYChanged(uint256 apy);
    event ConfigContractChanged(IOsmiConfig configContract);
    event TicketSignerChanged(address ticketSigner);
    event TokensStaked(address user, uint64 timestamp, uint256 amount);
    event AutoStakeChanged(address user, bool value);
    event StreakStartTimeChanged(address user, uint64 value);
    event WithdrawalStarted(address user, uint64 id, uint64 timestamp, uint64 availableAt, uint256 amount);
    event WithdrawalCanceled(address user, uint256 amount);
    event WithdrawalCompleted(address user, uint256 amount);

    // flags
    uint256 constant FLAG_AUTOSTAKE = 1 << 0;

    /**
     * @dev Withdrawal request for an address.
     */
    struct Withdrawal {
        // block.timestamp when this withdrawal was created
        uint256 timestamp;
        // amount to withdraw
        uint256 amount;
    }

    /**
     * @dev Staking state for an address.
     */
    struct Stake {
        // flags for this stake (see FLAG_XXX)
        uint256 flags;
        // timestamp of when this stake's streak started
        uint256 streakStartTime;
        // balance of tokens staked
        uint256 balance;
    }

    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiStakingStorage
    struct OsmiStakingStorage {
        IOsmiConfig configContract;
        address [2]ticketSigners;
        uint256 apyNumerator;
        mapping(address => Stake) stakes;
        mapping(address => Withdrawal) withdrawals;
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
     * @dev Restricted external function to complete any pending withdrawals for an address. This is called by the 
     * distro manager to ensure any queued withdrawals are finalized before updating allowances. Returns the number
     * of tokens released.
     */
    function completeWithdrawal(address user) external restricted returns(uint256) {
        return _completeWithdrawal(user);
    }
    
    /**
     * @dev Internal function to complete stake withdrawals. Returns the number of tokens released.
     */
    function _completeWithdrawal(address user) internal returns(uint256 released) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        Withdrawal storage withdrawal = $.withdrawals[user];
        if(withdrawal.timestamp == 0) {
            // no pending withdrawal
            return 0;
        }
        Stake storage stake = $.stakes[user];
        if(block.timestamp < (withdrawal.timestamp + WITHDRAWAL_HOLDING_PERIOD)) {
            // withdrawal is still pending
            return 0;
        }
        if(stake.balance < withdrawal.amount) {
            revert ErrNotEnoughStake();
        }
        stake.balance -= withdrawal.amount;
        emit WithdrawalCompleted(user, withdrawal.amount);
        released = withdrawal.amount;
        delete $.withdrawals[user];
        return released;
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
        // OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        // Withdrawal storage withdrawal = _getWithdrawal(list, id);
        // uint64 minTimestamp = uint64(block.timestamp - WITHDRAWAL_HOLDING_PERIOD);
        // if(item.timestamp <= minTimestamp) {
        //     revert ErrUncancelable();
        // }
        // if(list.total < item.amount) {
        //     revert ErrNotEnoughStake();
        // }
        // list.total -= item.amount;
        // emit WithdrawalCanceled(user, item.id, item.amount);
        // _deleteWithdrawal(list, item);
    }

    /**
     * @dev Restricted external function to set auto staking setting for the caller.
     */
    function setAutoStake(bool v) external restricted {
        _setAutoStake(_msgSender(), v);
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
     * @dev Restricted external function to stake from the caller's account.
     */
    function stake(uint256 amount) external restricted {
        address caller = _msgSender();
        _stake(caller, caller, amount);
    }

    /**
     * @dev Restricted external function to stake from the caller's account on behalf of the user.
     */
    function stakeFor(address user, uint256 amount) external restricted {
        _stake(_msgSender(), user, amount);
    }

    function _stake(address from, address to, uint256 amount) internal {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
    }

    function _validateTicketSigner(address v) internal view {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        if (v != $.ticketSigners[0] && v != $.ticketSigners[1]) {
            revert InvalidTicketSigner(v, $.ticketSigners[0], $.ticketSigners[1]);
        }
    }
}
