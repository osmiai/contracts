// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./IGalaBridge.sol";
import "./IOsmiDailyDistribution.sol";
import "./IOsmiDistributionManager.sol";
import "./IOsmiNode.sol";
import "./IOsmiNodeFactory.sol";
import "./IOsmiStaking.sol";
import "./IOsmiToken.sol";

/// @custom:security-contact contact@osmi.ai
contract OsmiConfig is Initializable, AccessManagedUpgradeable, UUPSUpgradeable {
    /// @custom:storage-location erc7201:ai.osmi.storage.OsmiConfig
    struct OsmiConfigStorage {
        IOsmiToken tokenContract;
        IOsmiNode nodeContract;
        IOsmiDailyDistribution dailyDistributionContract;
        IOsmiDistributionManager distributionManagerContract;
        IOsmiNodeFactory nodeFactoryContract;
        IOsmiStaking stakingContract;
        address nodeRewardPool;
        address stakingPool;
    }

    // keccak256(abi.encode(uint256(keccak256("ai.osmi.storage.OsmiConfig")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OsmiConfigStorageLocation = 0x1e00a1c1aedac593f06609f85365527388796fedfa78627bb4369402d4d99c00;

    function _getOsmiConfigStorage() private pure returns (OsmiConfigStorage storage $) {
        assembly {
            $.slot := OsmiConfigStorageLocation
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

    error NoTokenContract();
    event TokenContractChanged(IOsmiToken v);

    function getTokenContract() external view returns (IOsmiToken) {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if(address($.tokenContract) == address(0)) {
            revert NoTokenContract();
        }
        return $.tokenContract;
    }

    function setTokenContract(IOsmiToken v) external restricted {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if($.tokenContract == v) {
            return;
        }
        emit TokenContractChanged(v);
        $.tokenContract = v;
    }

    error NoNodeContract();
    event NodeContractChanged(IOsmiNode v);

    function getNodeContract() external view returns (IOsmiNode) {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if(address($.nodeContract) == address(0)) {
            revert NoNodeContract();
        }
        return $.nodeContract;
    }

    function setNodeContract(IOsmiNode v) external restricted {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if($.nodeContract == v) {
            return;
        }
        emit NodeContractChanged(v);
        $.nodeContract = v;
    }

    error NoDailyDistributionContract();
    event DailyDistributionContractChanged(IOsmiDailyDistribution v);

    function getDailyDistributionContract() external view returns (IOsmiDailyDistribution) {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if(address($.dailyDistributionContract) == address(0)) {
            revert NoDailyDistributionContract();
        }
        return $.dailyDistributionContract;
    }

    function setDailyDistributionContract(IOsmiDailyDistribution v) external restricted {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if($.dailyDistributionContract == v) {
            return;
        }
        emit DailyDistributionContractChanged(v);
        $.dailyDistributionContract = v;
    }

    error NoDistributionManagerContract();
    event DistributionManagerContractChanged(IOsmiDistributionManager v);

    function getDistributionManagerContract() external view returns (IOsmiDistributionManager) {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if(address($.distributionManagerContract) == address(0)) {
            revert NoDistributionManagerContract();
        }
        return $.distributionManagerContract;
    }

    function setDistributionManagerContract(IOsmiDistributionManager v) external restricted {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if($.distributionManagerContract == v) {
            return;
        }
        emit DistributionManagerContractChanged(v);
        $.distributionManagerContract = v;
    }

    error NoNodeFactoryContract();
    event NodeFactoryContractChanged(IOsmiNodeFactory v);

    function getNodeFactoryContract() external view returns (IOsmiNodeFactory) {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if(address($.nodeFactoryContract) == address(0)) {
            revert NoNodeFactoryContract();
        }
        return $.nodeFactoryContract;
    }

    function setNodeFactoryContract(IOsmiNodeFactory v) external restricted {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if($.nodeFactoryContract == v) {
            return;
        }
        emit NodeFactoryContractChanged(v);
        $.nodeFactoryContract = v;
    }

    error NoStakingContract();
    event StakingContractChanged(IOsmiStaking v);

    function getStakingContract() external view returns (IOsmiStaking) {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if(address($.stakingContract) == address(0)) {
            revert NoStakingContract();
        }
        return $.stakingContract;
    }

    function setStakingContract(IOsmiStaking v) external restricted {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if($.stakingContract == v) {
            return;
        }
        emit StakingContractChanged(v);
        $.stakingContract = v;
    }

    error NoNodeRewardPool();
    event NodeRewardPoolChanged(address v);

    function getNodeRewardPool() external view returns (address) {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if($.nodeRewardPool == address(0)) {
            revert NoNodeRewardPool();
        }
        return $.nodeRewardPool;
    }

    function setNodeRewardPool(address v) external restricted {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if($.nodeRewardPool == v) {
            return;
        }
        emit NodeRewardPoolChanged(v);
        $.nodeRewardPool = v;
    }

    error NoStakingPool();
    event StakingPoolChanged(address v);

    function getStakingPool() external view returns (address) {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if($.stakingPool == address(0)) {
            revert NoStakingPool();
        }
        return $.stakingPool;
    }

    function setStakingPool(address v) external restricted {
        OsmiConfigStorage storage $ = _getOsmiConfigStorage();
        if($.stakingPool == v) {
            return;
        }
        emit StakingPoolChanged(v);
        $.stakingPool = v;
    }
}
