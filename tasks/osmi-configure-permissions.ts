import { BigNumberish, BytesLike, AddressLike, id, getBytes, BaseContract } from "ethers"
import { task, subtask } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"
import { OsmiAccessManager } from "../typechain-types"

const ADMIN_ROLE = 0n
const PUBLIC_ROLE = 18446744073709551615n
const MANAGER_ROLE = 100n
const MINTER_ROLE = 200n

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

function selector(v: string): BytesLike {
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
        const { OsmiAccessManager } = await loadDeployedAddresses(hre)
        // grant manager role to admin
        {
            const [isMember] = await OsmiAccessManager.hasRole(MANAGER_ROLE, admin)
            if (!isMember) {
                await OsmiAccessManager.grantRole(MANAGER_ROLE, admin, 0)
            }
        }
        // grant minter role to admin
        {
            const [isMember] = await OsmiAccessManager.hasRole(MINTER_ROLE, admin)
            if (!isMember) {
                await OsmiAccessManager.grantRole(MINTER_ROLE, admin, 0)
            }
        }
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
        await applyFunctionRoles(nodeNftFunctionRoles, OsmiAccessManager, OsmiDailyDistribution)
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
