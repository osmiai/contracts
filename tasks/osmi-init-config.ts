import { task, vars } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"
import { AddressLike, MaxUint256 } from "ethers"
import { ProviderRpcError } from "hardhat/types"

task(
    "osmi-init-config",
    "Initialize config contract.",
).setAction(async (args, hre) => {
    const {
        OsmiConfig, OsmiToken, OsmiNode, OsmiNodeFactory,
        OsmiDailyDistribution, OsmiDistributionManager, OsmiStaking,
    } = await loadDeployedAddresses(hre)
    const network = await hre.ethers.provider.getNetwork()
    console.log(`network: ${network.name} (${network.chainId})`)
    {
        const newAddr: AddressLike = await OsmiToken.getAddress()
        let oldAddr: AddressLike = ""
        try {
            oldAddr = await OsmiConfig.getTokenContract()
        } catch(err) {
        }
        if(newAddr != oldAddr) {
            console.log("setTokenContract:", newAddr)
            await OsmiConfig.setTokenContract(newAddr)
        }
    }
    {
        const newAddr: AddressLike = await OsmiNode.getAddress()
        let oldAddr: AddressLike = ""
        try {
            oldAddr = await OsmiConfig.getNodeContract()
        } catch(err) {
        }
        if(newAddr != oldAddr) {
            console.log("setNodeContract:", newAddr)
            await OsmiConfig.setNodeContract(newAddr)
        }
    }
    {
        const newAddr: AddressLike = await OsmiNodeFactory.getAddress()
        let oldAddr: AddressLike = ""
        try {
            oldAddr = await OsmiConfig.getNodeFactoryContract()
        } catch(err) {
        }
        if(newAddr != oldAddr) {
            console.log("setNodeFactoryContract:", newAddr)
            await OsmiConfig.setNodeFactoryContract(newAddr)
        }
    }
    {
        const newAddr: AddressLike = await OsmiDailyDistribution.getAddress()
        let oldAddr: AddressLike = ""
        try {
            oldAddr = await OsmiConfig.getDailyDistributionContract()
        } catch(err) {
        }
        if(newAddr != oldAddr) {
            console.log("setDailyDistributionContract:", newAddr)
            await OsmiConfig.setDailyDistributionContract(newAddr)
        }
    }
    {
        const newAddr: AddressLike = await OsmiDistributionManager.getAddress()
        let oldAddr: AddressLike = ""
        try {
            oldAddr = await OsmiConfig.getDistributionManagerContract()
        } catch(err) {
        }
        if(newAddr != oldAddr) {
            console.log("setDistributionManagerContract:", newAddr)
            await OsmiConfig.setDistributionManagerContract(newAddr)
        }
    }
    {
        const newAddr: AddressLike = await OsmiStaking.getAddress()
        let oldAddr: AddressLike = ""
        try {
            oldAddr = await OsmiConfig.getStakingContract()
        } catch(err) {
        }
        if(newAddr != oldAddr) {
            console.log("setStakingContract:", newAddr)
            await OsmiConfig.setStakingContract(newAddr)
        }
    }
    {
        const newAddr: AddressLike = vars.get("OSMI_NODE_REWARDS_ADDRESS")
        let oldAddr: AddressLike = ""
        try {
            oldAddr = await OsmiConfig.getNodeRewardPool()
        } catch(err) {
        }
        if(newAddr != oldAddr) {
            console.log("setNodeRewardPool:", newAddr)
            await OsmiConfig.setNodeRewardPool(newAddr)
        }
    }
    {
        const newAddr: AddressLike = vars.get("OSMI_STAKING_AND_COMMUNITY_INITIATIVES_ADDRESS")
        let oldAddr: AddressLike = ""
        try {
            oldAddr = await OsmiConfig.getStakingPool()
        } catch(err) {
        }
        if(newAddr != oldAddr) {
            console.log("setStakingPool:", newAddr)
            await OsmiConfig.setStakingPool(newAddr)
        }
    }
})
