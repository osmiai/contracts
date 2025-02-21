import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { AddressLike, BigNumberish } from "ethers"
import { vars } from "hardhat/config"

export const OsmiAccessManagerProxyModule = buildModule("OsmiAccessManagerProxyModule", (builder) => {
    // deploy the implementation contract
    const osmiAccessManager = builder.contract("OsmiAccessManager")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(osmiAccessManager, "initialize", [
        builder.getAccount(0),
    ])

    // deploy the ERC1967 proxy, pointing to the implementation
    const osmiAccessManagerProxy = builder.contract("ERC1967Proxy", [osmiAccessManager, initialize])

    // return the proxy
    return { osmiAccessManagerProxy, osmiAccessManager }
})

export const OsmiTokenProxyModule = buildModule("OsmiTokenProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    
    // deploy the implementation contract
    const osmiToken = builder.contract("OsmiToken")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(osmiToken, "initialize", [
        osmiAccessManagerProxy,
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiProxy = builder.contract("ERC1967Proxy", [osmiToken, initialize])

    // return the proxy
    return { osmiProxy, osmiToken }
})

export const OsmiNodeProxyModule = buildModule("OsmiNodeProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    
    // deploy the implementation contract
    const osmiNode = builder.contract("OsmiNode")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(osmiNode, "initialize", [
        osmiAccessManagerProxy,
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiNodeProxy = builder.contract("ERC1967Proxy", [osmiNode, initialize])

    // return the proxy
    return { osmiNodeProxy, osmiNode }
})

export const OsmiDailyDistributionProxyModule = buildModule("OsmiDailyDistributionProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    const { osmiProxy } = builder.useModule(OsmiTokenProxyModule)
    
    // deploy the implementation contract
    const osmiDailyDistribution = builder.contract("OsmiDailyDistribution")

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

    // this must match the value in OsmiDailyDistribution.sol
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
    const initialize = builder.encodeFunctionCall(osmiDailyDistribution, "initialize", [
        osmiAccessManagerProxy,
        osmiProxy,
        dailyEmission, 
        pools,
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiDailyDistributionProxy = builder.contract("ERC1967Proxy", [osmiDailyDistribution, initialize])

    // return the proxy
    return { osmiDailyDistributionProxy, osmiDailyDistribution }
})

export const OsmiNodeFactoryProxyModule = buildModule("OsmiNodeFactoryProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    const { osmiProxy } = builder.useModule(OsmiTokenProxyModule)
    const { osmiNodeProxy } = builder.useModule(OsmiNodeProxyModule)
    
    // deploy the implementation contract
    const osmiNodeFactory = builder.contract("OsmiNodeFactory")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(osmiNodeFactory, "initialize", [
        osmiAccessManagerProxy,
        osmiProxy,
        osmiNodeProxy,
        vars.get("OSMI_PURCHASE_TICKET_SIGNER"),
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiNodeFactoryProxy = builder.contract("ERC1967Proxy", [osmiNodeFactory, initialize])

    // return the proxy
    return { osmiNodeFactoryProxy, osmiNodeFactory }
})

export const OsmiDistributionManagerProxyModule = buildModule("OsmiDistributionManagerProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    const { osmiProxy } = builder.useModule(OsmiTokenProxyModule)
    
    // deploy the implementation contract
    const osmiDistributionManager = builder.contract("OsmiDistributionManager")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(osmiDistributionManager, "initialize", [
        osmiAccessManagerProxy,
        osmiProxy,
        vars.get("OSMI_NODE_REWARDS_ADDRESS"),
        vars.get("OSMI_DISTRIBUTION_TICKET_SIGNER"),
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiDistributionManagerProxy = builder.contract("ERC1967Proxy", [osmiDistributionManager, initialize])

    // return the proxy
    return { osmiDistributionManagerProxy }
})

export const OsmiModule = buildModule("OsmiModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    const { osmiProxy } = builder.useModule(OsmiTokenProxyModule)
    const { osmiNodeProxy } = builder.useModule(OsmiNodeProxyModule)    
    const { osmiDailyDistributionProxy } = builder.useModule(OsmiDailyDistributionProxyModule)
    const { osmiNodeFactoryProxy } = builder.useModule(OsmiNodeFactoryProxyModule)
    const { osmiDistributionManagerProxy } = builder.useModule(OsmiDistributionManagerProxyModule)
    return { 
        osmiAccessManagerProxy,
        osmiProxy,
        osmiNodeProxy,
        osmiDailyDistributionProxy,
        osmiNodeFactoryProxy,
        osmiDistributionManagerProxy,
     }
})

export default OsmiModule;