// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IOsmiToken} from "./IOsmiToken.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @dev OsmiDistribution implements the daily minting of $OSMI into organizational pools.
 */
/// @custom:security-contact contact@osmi.ai
contract OsmiDailyDistribution is Initializable, AccessManagedUpgradeable, UUPSUpgradeable {
    /**
     * @dev Indicates distribution can't happen yet.
     * @param until When can the next distribution happen?
     */
    error DistributionOnCooldown(uint until);

    /**
     * @dev Indicates an discrepancy in the mint calculation.
     * @param expected What mint total do we expect to see?
     * @param actual What mint total did we actually see?
     */
    error MintDiscrepancy(uint256 expected, uint256 actual);

    /**
     * @dev Inidicates that the emission numerator is out of range.
     */
    error InvalidEmissionNumerator();

    /**
     * @dev Emitted when a daily distribution occurs.
     */
    event DailyDistribution(uint timestamp, uint256 minted, uint256 totalSupply, uint256 cap);

    /**
     * @dev Emitted when token contract is changed.
     */
    event TokenContractChanged(IOsmiToken tokenContract);

    /**
     * @dev Emitted when daily emission numerator is changed.
     */
    event DailyEmissionNumeratorChanged(uint256 value);

    /**
     * @dev Emitted when node rewards pool is changed.
     */
    event NodeRewardsChanged(address to, uint256 numerator);

    /**
     * @dev Emitted when project development fund pool is changed.
     */
    event ProjectDevelopmentFundChanged(address to, uint256 numerator);

    /**
     * @dev Emitted when staking and community initiatives pool is changed.
     */
    event StakingAndCommunityInitiativesChanged(address to, uint256 numerator);

    /**
     * @dev Emitted when referral program pool is changed.
     */
    event ReferralProgramChanged(address to, uint256 numerator);

    /**
     * @dev Pool holds configuration for a single distribution pool.
     */
    struct Pool {
        address to;
        uint256 numerator;
    }

    /**
     * @dev Pools holds configration all distribution pools.
     */
    struct Pools {
        Pool nodeRewards;
        Pool projectDevelopmentFund;
        Pool stakingAndCommunityInitiatives;
        Pool referralProgram;
    }

    /**
     * @dev Denominator of ratio calculations in this contract.
     */
    uint constant RatioDenominator = 1_000_000_000;

    /**
     * @dev Max daily emission numerator.
     */
    uint constant MaxDailyEmission = RatioDenominator/10;

    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiDailyDistribution
    struct OsmiDailyDistributionStorage {
        /**
         * @dev Token contract address.
         */
        IOsmiToken tokenContract;

        /**
         * @dev When was the last daily distribution?
         */
        uint lastDistributionTime;

        /**
         * @dev What percentage of (cap-totalSupply) is emitted each day?
         */
        uint256 dailyEmissionNumerator;

        /**
         * @dev Distribution pools.
         */
        Pools pools;
    }

    // keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiDailyDistribution")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OsmiDailyDistributionStorageLocation = 0x11e36f22dc3e60b61fc7ee072e0af835828cfda265c4a879bb366f002f523f00;

    function _getOsmiDailyDistributionStorage() private pure returns (OsmiDailyDistributionStorage storage $) {
        assembly {
            $.slot := OsmiDailyDistributionStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority, address tokenContract, uint256 dailyEmissionNumerator, Pools calldata pools) initializer public {
        __AccessManaged_init(initialAuthority);
        __UUPSUpgradeable_init();
        _setTokenContract(tokenContract);
        _configureDistribution(dailyEmissionNumerator, pools);
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
     * @dev Restricted function to set the token contract for minting.
     */
    function setTokenContract(address tokenContract) restricted external {
        return _setTokenContract(tokenContract);
    }

    function _setTokenContract(address tokenContract) internal {
        require(tokenContract != address(0), "token contract can't be zero");
        OsmiDailyDistributionStorage storage $ = _getOsmiDailyDistributionStorage();
        if($.tokenContract == IOsmiToken(tokenContract)) {
            // nothing to do
            return;
        }
        $.tokenContract = IOsmiToken(tokenContract);
        emit TokenContractChanged($.tokenContract);
    }

    /**
     * @dev Restricted function to configure the distribution pools.
     */
    function configureDistribution(uint256 dailyEmissionNumerator, Pools calldata pools) restricted external {
        _configureDistribution(dailyEmissionNumerator, pools);
    }

    function _configurePool(Pool storage pool, Pool calldata config) internal returns (bool) {
        bool changed = false;
        if(pool.to != config.to) {
            require(config.to != address(0), "target pool can't be zero address");
            pool.to = config.to;
            changed = true;
        }
        if(pool.numerator != config.numerator) {
            pool.numerator = config.numerator;
            changed = true;
        }
        return changed;
    }

    function _configureDistribution(uint256 dailyEmissionNumerator, Pools calldata pools) internal {
        OsmiDailyDistributionStorage storage $ = _getOsmiDailyDistributionStorage();
        // configure daily emission numerator
        if($.dailyEmissionNumerator != dailyEmissionNumerator) {
            if(dailyEmissionNumerator == 0 || dailyEmissionNumerator>MaxDailyEmission) {
                revert InvalidEmissionNumerator();
            }
            $.dailyEmissionNumerator = dailyEmissionNumerator;
            emit DailyEmissionNumeratorChanged(dailyEmissionNumerator);
        }
        // configure node rewards
        if(_configurePool($.pools.nodeRewards, pools.nodeRewards)) {
            emit NodeRewardsChanged(pools.nodeRewards.to, pools.nodeRewards.numerator);
        }
        // configure project development fund
        if(_configurePool($.pools.projectDevelopmentFund, pools.projectDevelopmentFund)) {
            emit ProjectDevelopmentFundChanged(pools.projectDevelopmentFund.to, pools.projectDevelopmentFund.numerator);
        }
        // configure staking and community initiatives
        if(_configurePool($.pools.stakingAndCommunityInitiatives, pools.stakingAndCommunityInitiatives)) {
            emit StakingAndCommunityInitiativesChanged(pools.stakingAndCommunityInitiatives.to, pools.stakingAndCommunityInitiatives.numerator);
        }
        // configure referral program
        if(_configurePool($.pools.referralProgram, pools.referralProgram)) {
            emit ReferralProgramChanged(pools.referralProgram.to, pools.referralProgram.numerator);
        }
        // validate numerators
        uint256 totalNumerator = 0;
        totalNumerator += pools.nodeRewards.numerator;
        totalNumerator += pools.projectDevelopmentFund.numerator;
        totalNumerator += pools.stakingAndCommunityInitiatives.numerator;
        totalNumerator += pools.referralProgram.numerator;
        require(totalNumerator == RatioDenominator, "sum of pool numerators must equal denominator");
    }

    /**
     * @dev Return the current pool config.
     */
    function getPools() view external returns(Pools memory) {
        OsmiDailyDistributionStorage storage $ = _getOsmiDailyDistributionStorage();
        return $.pools;
    }

    /**
     * @dev Restricted function to do daily distribution.
     */
    function doDailyDistribution() restricted external {
        OsmiDailyDistributionStorage storage $ = _getOsmiDailyDistributionStorage();

        // check if we're on cooldown
        uint nextDistributionTime = $.lastDistributionTime + 1 days;
        if (nextDistributionTime > block.timestamp) {
            revert DistributionOnCooldown(nextDistributionTime);
        }
        $.lastDistributionTime = block.timestamp;

        // calculate distribution: (cap-totalSupply)*dailyEmission/RatioDenominator
        uint256 cap = $.tokenContract.cap();
        uint256 totalSupply = $.tokenContract.totalSupply();
        uint256 dailyEmission = $.dailyEmissionNumerator;
        uint256 distribution = Math.mulDiv(cap-totalSupply, dailyEmission, RatioDenominator);

        // track total mint for sanity check
        uint256 totalMinted = 0;
        uint256 minted = 0;
        
        // mint node rewards
        minted = Math.mulDiv(distribution, $.pools.nodeRewards.numerator, RatioDenominator);
        $.tokenContract.mint($.pools.nodeRewards.to, minted);
        totalMinted += minted;

        // mint project development fund
        minted = Math.mulDiv(distribution, $.pools.projectDevelopmentFund.numerator, RatioDenominator);
        $.tokenContract.mint($.pools.projectDevelopmentFund.to, minted);
        totalMinted += minted;

        // mint staking and community initiatives
        minted = Math.mulDiv(distribution, $.pools.stakingAndCommunityInitiatives.numerator, RatioDenominator);
        $.tokenContract.mint($.pools.stakingAndCommunityInitiatives.to, minted);
        totalMinted += minted;

        // mint referral program
        minted = Math.mulDiv(distribution, $.pools.referralProgram.numerator, RatioDenominator);
        $.tokenContract.mint($.pools.referralProgram.to, minted);
        totalMinted += minted;

        // sanity check
        if(totalMinted > distribution) {
            revert MintDiscrepancy(distribution, totalMinted);
        }

        emit DailyDistribution(block.timestamp, totalMinted, totalSupply, cap);
    }
}
