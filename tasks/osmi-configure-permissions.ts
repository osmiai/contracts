import { BigNumberish, BytesLike, id, getBytes } from "ethers"
import { task, subtask } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"

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

const tokenFunctionRoles = new Map<string, BigNumberish>()

function setTargetFunctionRole(signature: string, role: BigNumberish) {
    if (tokenFunctionRoles.has(signature)) {
        throw new Error("function signature already registered")
    }
    tokenFunctionRoles.set(signature, role)
}

// minter functions
setTargetFunctionRole("mint(address,uint256)", MINTER_ROLE)
// public functions
setTargetFunctionRole("approve(address,uint256)", PUBLIC_ROLE)
setTargetFunctionRole("burn(uint256)", PUBLIC_ROLE)
setTargetFunctionRole("burnFrom(address,uint256)", PUBLIC_ROLE)
setTargetFunctionRole("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)", PUBLIC_ROLE)
setTargetFunctionRole("transfer(address,uint256)", PUBLIC_ROLE)
setTargetFunctionRole("transferFrom(address,address,uint256)", PUBLIC_ROLE)

function selector(v: string): BytesLike {
    return getBytes(id(v).substring(0, 10))
}

task("osmi-configure-permissions", "Automated permission configuration.")
    .setAction(async (args, hre) => {
        await hre.run("sync-roles")
        await hre.run("grant-roles")
        await hre.run("sync-token-permissions")
    })

subtask("sync-roles")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:sync-roles")
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

subtask("sync-token-permissions")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:sync-token-permissions")
        const { OsmiAccessManager, OsmiToken } = await loadDeployedAddresses(hre)
        // create selector mapping
        const roleSelectors = new Map<BigNumberish, BytesLike[]>()
        for (const [signature, role] of tokenFunctionRoles) {
            const rs = roleSelectors.get(role)
            if (rs) {
                rs.push(selector(signature))
            } else {
                roleSelectors.set(role, [selector(signature)])
            }
        }
        // set token function roles
        for (const [role, selectors] of roleSelectors) {
            console.log(`setTargetFunctionRole: ${role} => ${selectors}`)
            await OsmiAccessManager.setTargetFunctionRole(OsmiToken, selectors, role)
        }
    })

subtask("grant-roles")
    .setAction(async (taskArgs, hre) => {
        console.log("osmi-configure-permissions:grant-roles")
        const [ admin ] = await hre.ethers.getSigners()
        const { OsmiAccessManager } = await loadDeployedAddresses(hre)
        // grant manager role to admin
        {
            const [ isMember ] = await OsmiAccessManager.hasRole(MANAGER_ROLE, admin)
            if(!isMember) {
                await OsmiAccessManager.grantRole(MANAGER_ROLE, admin, 0)
            }    
        }
        // grant minter role to admin
        {
            const [ isMember ] = await OsmiAccessManager.hasRole(MINTER_ROLE, admin)
            if(!isMember) {
                await OsmiAccessManager.grantRole(MINTER_ROLE, admin, 0)
            }    
        }
    })