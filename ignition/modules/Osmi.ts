import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { AddressLike, BigNumberish } from "ethers"
import { vars } from "hardhat/config"

export const OsmiAccessManagerProxyModule = buildModule("OsmiAccessManagerProxyModule", (builder) => {
    // deploy the implementation contract
    const impl = builder.contract("OsmiAccessManager")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(impl, "initialize", [
        builder.getAccount(0),
    ])

    // deploy the ERC1967 proxy, pointing to the implementation
    const osmiAccessManagerProxy = builder.contract("ERC1967Proxy", [impl, initialize])

    // return the proxy
    return { osmiAccessManagerProxy }
})

export const OsmiTokenProxyModule = buildModule("OsmiTokenProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    
    // deploy the implementation contract
    const impl = builder.contract("OsmiToken")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(impl, "initialize", [
        osmiAccessManagerProxy,
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiProxy = builder.contract("ERC1967Proxy", [impl, initialize])

    // return the proxy
    return { osmiProxy }
})

export const OsmiNodeProxyModule = buildModule("OsmiNodeProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    
    // deploy the implementation contract
    const impl = builder.contract("OsmiNode")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(impl, "initialize", [
        osmiAccessManagerProxy,
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiNodeProxy = builder.contract("ERC1967Proxy", [impl, initialize])

    // return the proxy
    return { osmiNodeProxy }
})

export const OsmiDailyDistributionProxyModule = buildModule("OsmiDailyDistributionProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    const { osmiProxy } = builder.useModule(OsmiTokenProxyModule)
    
    // deploy the implementation contract
    const impl = builder.contract("OsmiDailyDistribution")

    interface Pool {
        [key: string]: any
        to: AddressLike
        numerator: BigNumberish
    }

    interface Pools {
        [key: string]: Pool
        nodeRewards: Pool
        projectDevelopmentFund: Pool
        stakingAndCommunityInitiatives: Pool
        referralProgram: Pool
    }

    const RatioDenominator = 1_000_000_000

    const pools: Pools = {
        nodeRewards: {
            to: vars.get("OSMI_NODE_REWARDS_ADDRESS"),
            numerator: Math.round(RatioDenominator * 0.5),
        },
        projectDevelopmentFund: {
            to: vars.get("OSMI_PROJECT_FUND_ADDRESS"),
            numerator: Math.round(RatioDenominator * 0.2),
        },
        stakingAndCommunityInitiatives: {
            to: vars.get("OSMI_STAKING_AND_COMMUNITY_INITIATIVES_ADDRESS"),
            numerator: Math.round(RatioDenominator * 0.2),
        },
        referralProgram: {
            to: vars.get("OSMI_REFERRAL_PROGRAM_ADDRESS"),
            numerator: Math.round(RatioDenominator * 0.1),
        },
    }

    console.log(pools)

    const dailyEmission = Math.round(RatioDenominator * (0.15/100))

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(impl, "initialize", [
        osmiAccessManagerProxy,
        osmiProxy,
        dailyEmission, 
        pools,
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiDailyDistributionProxy = builder.contract("ERC1967Proxy", [impl, initialize])

    // return the proxy
    return { osmiDailyDistributionProxy }
})

export const OsmiNodeFactoryProxyModule = buildModule("OsmiNodeFactoryProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    const { osmiProxy } = builder.useModule(OsmiTokenProxyModule)
    
    // deploy the implementation contract
    const impl = builder.contract("OsmiNodeFactory")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(impl, "initialize", [
        osmiAccessManagerProxy,
        osmiProxy,
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiNodeFactoryProxy = builder.contract("ERC1967Proxy", [impl, initialize])

    // return the proxy
    return { osmiNodeFactoryProxy }
})

export const OsmiModule = buildModule("OsmiModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    const { osmiProxy } = builder.useModule(OsmiTokenProxyModule)
    const { osmiNodeProxy } = builder.useModule(OsmiNodeProxyModule)    
    const { osmiDailyDistributionProxy } = builder.useModule(OsmiDailyDistributionProxyModule)
    const { osmiNodeFactoryProxy } = builder.useModule(OsmiNodeFactoryProxyModule)
    return { 
        osmiAccessManagerProxy,
        osmiProxy,
        osmiNodeProxy,
        osmiDailyDistributionProxy,
        osmiNodeFactoryProxy,
     }
})

export default OsmiModule;