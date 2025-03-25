import { BigNumberish, BytesLike, AddressLike, id, getBytes, BaseContract } from "ethers"
import { task, subtask } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"
import { OsmiAccessManager } from "../typechain-types"

const ADMIN_ROLE = 0n
const PUBLIC_ROLE = 18446744073709551615n
const MANAGER_ROLE = 100n
const MINTER_ROLE = 200n
const STAKING_ROLE = 300n

interface RoleSettings {
    id: BigNumberish
    label: string
    admin: BigNumberish
    guardian: BigNumberish
}

const masterRoleSettings = new Map<BigNumberish, RoleSettings>()
masterRoleSettings.set(PUBLIC_ROLE, {
    id: PUBLIC_ROLE,
    label: "PUBLIC",
    admin: ADMIN_ROLE,
    guardian: ADMIN_ROLE,
})
masterRoleSettings.set(MANAGER_ROLE, {
    id: MANAGER_ROLE,
    label: "MANAGER",
    admin: ADMIN_ROLE,
    guardian: ADMIN_ROLE,
})
masterRoleSettings.set(MINTER_ROLE, {
    id: MINTER_ROLE,
    label: "MINTER",
    admin: MANAGER_ROLE,
    guardian: MANAGER_ROLE,
})
masterRoleSettings.set(STAKING_ROLE, {
    id: STAKING_ROLE,
    label: "STAKER",
    admin: MANAGER_ROLE,
    guardian: MANAGER_ROLE,
})

// token function roles
const tokenFunctionRoles = (() => {
    const functionRoles = new Map<string, BigNumberish>()
    function setFunctionRole(signature: string, role: BigNumberish) {
        if (functionRoles.has(signature)) {
            throw new Error("function signature already registered")
        }
        functionRoles.set(signature, role)
    }
    // minter functions
    setFunctionRole("mint(address,uint256)", MINTER_ROLE)
    // public functions
    setFunctionRole("approve(address,uint256)", PUBLIC_ROLE)
    setFunctionRole("burn(uint256)", PUBLIC_ROLE)
    setFunctionRole("burnFrom(address,uint256)", PUBLIC_ROLE)
    setFunctionRole("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)", PUBLIC_ROLE)
    setFunctionRole("transfer(address,uint256)", PUBLIC_ROLE)
    setFunctionRole("transferFrom(address,address,uint256)", PUBLIC_ROLE)
    // result
    return functionRoles
})()

// daily distribution function roles
const dailyDistributionFunctionRoles = (() => {
    const functionRoles = new Map<string, BigNumberish>()
    function setFunctionRole(signature: string, role: BigNumberish) {
        if (functionRoles.has(signature)) {
            throw new Error("function signature already registered")
        }
        functionRoles.set(signature, role)
    }
    // minter functions
    setFunctionRole("doDailyDistribution()", MINTER_ROLE)
    // result
    return functionRoles
})()

// node nft function roles
const nodeNftFunctionRoles = (() => {
    const functionRoles = new Map<string, BigNumberish>()
    function setFunctionRole(signature: string, role: BigNumberish) {
        if (functionRoles.has(signature)) {
            throw new Error("function signature already registered")
        }
        functionRoles.set(signature, role)
    }
    // minter roles
    setFunctionRole("safeMint(address)", MINTER_ROLE)
    // result
    return functionRoles
})()

// node factory function roles
const nodeFactoryFunctionRoles = (() => {
    const functionRoles = new Map<string, BigNumberish>()
    function setFunctionRole(signature: string, role: BigNumberish) {
        if (functionRoles.has(signature)) {
            throw new Error("function signature already registered")
        }
        functionRoles.set(signature, role)
    }
    // public functions
    setFunctionRole("buyOsmiNode((address,address,uint256,uint256,uint8,bytes32,bytes32),(address,address,uint256,uint256,uint8,bytes32,bytes32))", PUBLIC_ROLE)
    // result
    return functionRoles
})()

// distribution manager function roles
const distributionManagerFunctionRoles = (() => {
    const functionRoles = new Map<string, BigNumberish>()
    function setFunctionRole(signature: string, role: BigNumberish) {
        if (functionRoles.has(signature)) {
            throw new Error("function signature already registered")
        }
        functionRoles.set(signature, role)
    }
    // public functions
    setFunctionRole("redeem((address,address,uint256,bytes32,uint256,uint8,bytes32,bytes32))", PUBLIC_ROLE)
    setFunctionRole("bridgeTokens(uint256,uint8)", PUBLIC_ROLE)
    setFunctionRole("redeemAndBridge((address,address,uint256,bytes32,uint256,uint8,bytes32,bytes32),uint256,uint8)", PUBLIC_ROLE)
    setFunctionRole("bridgeTokensToGalaChainAlias(uint256,string)", PUBLIC_ROLE)
    setFunctionRole("redeemAndBridgeToGalaChainAlias((address,address,uint256,bytes32,uint256,uint8,bytes32,bytes32),uint256,string)", PUBLIC_ROLE)
    setFunctionRole("redeemAndStake((address,address,uint256,bytes32,uint256,uint8,bytes32,bytes32),uint256)", PUBLIC_ROLE)
    setFunctionRole("stakeTokens(uint256)", PUBLIC_ROLE)
    // manager functions
    setFunctionRole("claimTokens(uint256)", MANAGER_ROLE)
    setFunctionRole("redeemAndClaim((address,address,uint256,bytes32,uint256,uint8,bytes32,bytes32),uint256)", MANAGER_ROLE)
    // result
    return functionRoles
})()

// staking function roles
const stakingFunctionRoles = (() => {
    const functionRoles = new Map<string, BigNumberish>()
    function setFunctionRole(signature: string, role: BigNumberish) {
        if (functionRoles.has(signature)) {
            throw new Error("function signature already registered")
        }
        functionRoles.set(signature, role)
    }
    // public functions
    setFunctionRole("setAutoStake(bool)", PUBLIC_ROLE)
    setFunctionRole("redeem((address,uint256,bytes32,uint256,uint8,bytes32,bytes32))", PUBLIC_ROLE)
    setFunctionRole("redeemAndWithdraw((address,uint256,bytes32,uint256,uint8,bytes32,bytes32),uint256,bool)", PUBLIC_ROLE)
    setFunctionRole("withdraw(uint256,bool)", PUBLIC_ROLE)
    setFunctionRole("cancelWithdrawal()", PUBLIC_ROLE)
    // staking functions
    setFunctionRole("stakeFor(address,uint256)", STAKING_ROLE)
    // result
    return functionRoles
})()

function selector(v: string): BytesLike {
    // const x = id(v)
    // console.log(`selector("${v}") = ${x}`)
    return getBytes(id(v).substring(0, 10))
}

async function applyFunctionRoles(targetFunctionRoles: Map<string, BigNumberish>, accessManager: OsmiAccessManager, contract: BaseContract) {
    // create selector mapping
    const roleSelectors = new Map<BigNumberish, BytesLike[]>()
    for (const [signature, role] of targetFunctionRoles) {
        const rs = roleSelectors.get(role)
        if (rs) {
            rs.push(selector(signature))
        } else {
            roleSelectors.set(role, [selector(signature)])
        }
    }
    // set function roles
    for (const [role, selectors] of roleSelectors) {
        const finalSelectors: BytesLike[] = []
        for (const selector of selectors) {
            const currentRole = await accessManager.getTargetFunctionRole(contract, selector)
            if (currentRole == role) {
                continue
            }
            finalSelectors.push(selector)
        }
        if (finalSelectors.length > 0) {
            console.log(`setTargetFunctionRole: ${role} => ${selectors}`)
            await accessManager.setTargetFunctionRole(contract, selectors, role)
        }
    }
}

task("osmi-configure-permissions", "Automated permission configuration.")
    .setAction(async (args, hre) => {
        await hre.run("roles")
        await hre.run("accounts")
        await hre.run("token")
        await hre.run("node-nft")
        await hre.run("daily-distribution")
        await hre.run("node-factory")
        await hre.run("distribution-manager")
        await hre.run("staking")
    })

subtask("roles")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:roles")
        const { OsmiAccessManager } = await loadDeployedAddresses(hre)
        // get current role labels from the contract event log 
        const RoleLabel = OsmiAccessManager.getEvent("RoleLabel")
        const roleLabelEvents = await OsmiAccessManager.queryFilter(RoleLabel)
        const roleLabels = new Map<BigNumberish, string>()
        roleLabelEvents.forEach((v) => {
            // console.log(`role: ${v.args[0]} label: ${v.args[1]}`)
            roleLabels.set(v.args[0], v.args[1])
        })
        // sync role properties
        for (const role of masterRoleSettings.values()) {
            // sync labels that aren't built in to the contract
            if (role.id != PUBLIC_ROLE && role.id != ADMIN_ROLE) {
                if (roleLabels.get(role.id) != role.label) {
                    console.log(`labelRole: ${role.id} => ${role.label}`)
                    await OsmiAccessManager.labelRole(role.id, role.label)
                }
                // sync role admin
                {
                    const admin = await OsmiAccessManager.getRoleAdmin(role.id)
                    if (admin != role.admin) {
                        console.log(`setRoleAdmin: ${role.label} => ${role.admin}`)
                        await OsmiAccessManager.setRoleAdmin(role.id, role.admin)
                    }
                }
                // sync role guardian
                {
                    const guardian = await OsmiAccessManager.getRoleGuardian(role.id)
                    if (guardian != role.guardian) {
                        console.log(`setRoleGuardian: ${role.label} => ${role.guardian}`)
                        await OsmiAccessManager.setRoleGuardian(role.id, role.guardian)
                    }
                }
            }
        }
    })

subtask("accounts")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:accounts")
        const [admin] = await hre.ethers.getSigners()
        const { OsmiAccessManager, OsmiStaking, OsmiDistributionManager } = await loadDeployedAddresses(hre)
        async function grantRole(account: AddressLike, role: BigNumberish) {
            const [isMember] = await OsmiAccessManager.hasRole(role, account)
            if (!isMember) {
                console.log(`grant role ${role} to ${account}`)
                await OsmiAccessManager.grantRole(role, account, 0)
            }
        }
        async function grantManager(account: AddressLike) {
            await grantRole(account, MANAGER_ROLE)
            await grantRole(account, MINTER_ROLE)
            await grantRole(account, STAKING_ROLE)
        }
        async function grantStaking(account: AddressLike) {
            await grantRole(account, STAKING_ROLE)
        }
        // grant manager role to admin and osmi-overseer
        await grantManager(admin);
        await grantManager("0x97932ed7cec8cEdf53e498F0efF5E55a54A0BB98")
        // grant staking role to OsmiStaking and OsmiDistributionManager
        await grantStaking(await OsmiStaking.getAddress())
        await grantStaking(await OsmiDistributionManager.getAddress())
    })

subtask("token")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:token")
        const { OsmiAccessManager, OsmiToken } = await loadDeployedAddresses(hre)
        await applyFunctionRoles(tokenFunctionRoles, OsmiAccessManager, OsmiToken)
    })

subtask("node-nft")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:node-nft")
        const { OsmiAccessManager, OsmiNode } = await loadDeployedAddresses(hre)
        await applyFunctionRoles(nodeNftFunctionRoles, OsmiAccessManager, OsmiNode)
    })

subtask("daily-distribution")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:daily-distribution")
        const { OsmiAccessManager, OsmiDailyDistribution } = await loadDeployedAddresses(hre)
        await applyFunctionRoles(dailyDistributionFunctionRoles, OsmiAccessManager, OsmiDailyDistribution)
        // grant minting role to daily distribution
        const [isMember] = await OsmiAccessManager.hasRole(MINTER_ROLE, OsmiDailyDistribution)
        if (!isMember) {
            await OsmiAccessManager.grantRole(MINTER_ROLE, OsmiDailyDistribution, 0)
        }
    })

subtask("node-factory")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:node-factory")
        const { OsmiAccessManager, OsmiNodeFactory } = await loadDeployedAddresses(hre)
        await applyFunctionRoles(nodeFactoryFunctionRoles, OsmiAccessManager, OsmiNodeFactory)
        // grant minting role to node factory
        const [isMember] = await OsmiAccessManager.hasRole(MINTER_ROLE, OsmiNodeFactory)
        if (!isMember) {
            await OsmiAccessManager.grantRole(MINTER_ROLE, OsmiNodeFactory, 0)
        }
    })

subtask("distribution-manager")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:distribution-manager")
        const { OsmiAccessManager, OsmiDistributionManager } = await loadDeployedAddresses(hre)
        await applyFunctionRoles(distributionManagerFunctionRoles, OsmiAccessManager, OsmiDistributionManager)
    })

subtask("staking")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:staking")
        const { OsmiAccessManager, OsmiStaking } = await loadDeployedAddresses(hre)
        await applyFunctionRoles(stakingFunctionRoles, OsmiAccessManager, OsmiStaking)
    })
