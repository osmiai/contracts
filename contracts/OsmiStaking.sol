// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IOsmiToken} from "./IOsmiToken.sol";
// import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
// import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @dev OsmiStaking manages staking of OSMI token.
 */
/// @custom:security-contact contact@osmi.ai
contract OsmiStaking is Initializable, AccessManagedUpgradeable, UUPSUpgradeable { //, EIP712Upgradeable, NoncesUpgradeable {
    /**
     * @dev How long to hold withdrawals before finalizing.
     */
    uint256 constant WITHDRAWAL_HOLDING_PERIOD = 14 days;

    /**
     * @dev Maximum number of pending withdrawals per address.
     */
    uint256 constant MAX_PENDING_WITHDRAWALS = 5;

    /**
     * @dev Denominator of ratio calculations in this contract.
     */
    uint256 constant RATIO_DENOMINATOR = 1_000_000_000;

    /**
     * @dev Annual percentage yield (APY) numerator.
     */
    uint256 constant DEFAULT_APY_NUMERATOR = 75_000_000; // 7.5%

    /**
     * @dev Daily percentage yield numerator.
     */
    uint256 constant DEFAULT_DPY_NUMERATOR = DEFAULT_APY_NUMERATOR / 365;

    // errors
    error ErrNotFound();
    error ErrUncancelable();
    error ErrNotEnoughStake();
    error ErrReusedStorage();
    error ErrItemRequired();
    error ErrPopulatedListRequired();

    // events
    event CoinsStaked(address user, uint64 timestamp, uint256 amount);
    event AutoStakeChanged(address user, bool value);
    event StreakStartTimeChanged(address user, uint64 value);
    event WithdrawalStarted(address user, uint64 id, uint64 timestamp, uint64 availableAt, uint256 amount);
    event WithdrawalCanceled(address user, uint64 id, uint256 amount);
    event WithdrawalCompleted(address user, uint64 id, uint256 amount);

    // flags
    uint256 constant FLAG_AUTOSTAKE = 1 << 0;

    /**
     * @dev Withdrawal request for an address.
     */
    struct Withdrawal {
        // withdrawals mapping key
        uint64 id;
        // block.timestamp when this withdrawal was created
        uint64 timestamp;
        // id of the previous withdrawal
        uint64 prev;
        // id of the next withdrawal
        uint64 next;
        // amount to withdraw
        uint256 amount;
    }

    /**
     * @dev Pending withdrawals for an address.
     */
    struct Withdrawals {
        // number of entries in our mapping
        uint64 length;
        // id used by the last withdrawal
        uint64 last;
        // id of the head withdrawal
        uint64 head;
        // id of the tail withdrawal
        uint64 tail;
        // total number of tokens pending withdrawal
        uint256 total;
        // mapping of ids to withdrawals
        mapping(uint64 => Withdrawal) items;
    }

    /**
     * @dev Staking state for an address.
     */
    struct Stake {
        // flags for this stake (see FLAG_XXX)
        uint256 flags;
        // numerator of this stake's apy
        uint256 apyNumerator;
        // timestamp of when this stake's streak started
        uint256 streakStartTime;
        // total number of tokens staked
        uint256 total;
        // pending withdrawals
        Withdrawals ws;
    }

    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiStakingStorage
    struct OsmiStakingStorage {
        IOsmiToken tokenContract;
        // IOsmiDistributionManager distroManagerContract;
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
        address initialAuthority
    ) initializer public {
        __AccessManaged_init(initialAuthority);
        // __Nonces_init();
        __UUPSUpgradeable_init();
        // __EIP712_init("OsmiStaking", "1");
        __UUPSUpgradeable_init();
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
     * @dev Restricted external function to complete any pending withdrawals for an address. This is called by the 
     * distro manager to ensure any queued withdrawals are finalized before updating allowances. Returns the number
     * of tokens released.
     */
    function completeWithdrawals(address user) external restricted returns(uint256) {
        return _completeWithdrawals(user);
    }
    
    /**
     * @dev Internal function to complete stake withdrawals. Returns the number of tokens released.
     */
    function _completeWithdrawals(address user) internal returns(uint256 total) {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        Stake storage stake = $.stakes[user];
        Withdrawals storage list = stake.ws;
        if(list.length == 0) {
            return 0;
        }
        uint256 released;
        uint64 minTimestamp = uint64(block.timestamp - WITHDRAWAL_HOLDING_PERIOD);
        uint64 id = list.head;
        while(id != 0) {
            Withdrawal storage item = _getWithdrawal(list, id);
            if(item.timestamp > minTimestamp) {
                // We assume items are stored in timestamp order. Once we hit one that isn't old enough, we can stop.
                break;
            }
            emit WithdrawalCompleted(user, item.id, item.amount);
            released += item.amount;
            id = item.next;
            _deleteWithdrawal(list, item);
        }
        if(released > 0) {
            if(list.total < released || stake.total < released) {
                revert ErrNotEnoughStake();
            }
            list.total -= released;
            stake.total -= released;
        }
        return released;
    }

    /**
     * @dev Restricted external function to cancel a withdrawal for the caller.
     */
    function cancelWithdrawal(uint64 id) external restricted {
        return _cancelWithdrawal(_msgSender(), id);
    }

    /**
     * @dev Internal function to cancel a stake withdrawal.
     */
    function _cancelWithdrawal(address user, uint64 id) internal {
        OsmiStakingStorage storage $ = _getOsmiStakingStorage();
        Stake storage stake = $.stakes[user];
        Withdrawals storage list = stake.ws;
        Withdrawal storage item = _getWithdrawal(list, id);
        uint64 minTimestamp = uint64(block.timestamp - WITHDRAWAL_HOLDING_PERIOD);
        if(item.timestamp <= minTimestamp) {
            revert ErrUncancelable();
        }
        if(list.total < item.amount) {
            revert ErrNotEnoughStake();
        }
        list.total -= item.amount;
        emit WithdrawalCanceled(user, item.id, item.amount);
        _deleteWithdrawal(list, item);
    }

    function _hasWithdrawal(Withdrawals storage list, uint64 id) internal view returns(bool) {
        return id != 0 && list.items[id].id == id;
    }

    function _getWithdrawal(Withdrawals storage list, uint64 id) internal view returns(Withdrawal storage) {
        Withdrawal storage result = list.items[id];
        if(id == 0 || result.id != id) {
            revert ErrNotFound();
        }
        return result;
    }

    function _addWithdrawal(Withdrawals storage list) internal returns (Withdrawal storage) {
        Withdrawal storage item = list.items[++list.last];
        if(item.id != 0) {
            revert ErrReusedStorage();
        }
        item.id = list.last;
        if(list.length == 0) {
            list.head = item.id;
            list.tail = item.id;
        } else {
            Withdrawal storage tail = _getWithdrawal(list, list.tail);
            tail.next = item.id;
            item.prev = list.tail;
            list.tail - item.id;
        }
        list.length++;
        return item;
    }

    function _deleteWithdrawal(Withdrawals storage list, Withdrawal storage item) internal {
        if(item.id == 0) {
            revert ErrItemRequired();
        }
        if(list.length == 0) {
            revert ErrPopulatedListRequired();
        }
        if(item.next != 0) {
            _getWithdrawal(list, item.next).prev = item.prev;
        }
        if(item.prev != 0) {
            _getWithdrawal(list, item.prev).next = item.next;
        }
        if(item.id == list.head) {
            list.head = item.next;
        }
        if(item.id == list.tail) {
            list.tail = item.prev;
        }
        list.length--;
        delete list.items[item.id];
    }
}
