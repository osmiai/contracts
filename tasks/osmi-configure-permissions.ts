import { BigNumberish, id } from "ethers"
import { task, subtask } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"

const ADMIN_ROLE = 0n
const PUBLIC_ROLE = 0xffffffffffffffffn
const BLACKLIST_ROLE = 0xffffffffdeadbeefn
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
masterRoleSettings.set(BLACKLIST_ROLE, {
    id: BLACKLIST_ROLE,
    label: "BLACKLIST",
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
// manager functions
tokenFunctionRoles.set("pause()", MANAGER_ROLE)
tokenFunctionRoles.set("unpause()", MANAGER_ROLE)
// minter functions
tokenFunctionRoles.set("mint(address,uint256)", MINTER_ROLE)
// public functions
tokenFunctionRoles.set("transfer(address,uint256)", PUBLIC_ROLE)
tokenFunctionRoles.set("approve(address,uint256)", PUBLIC_ROLE)
tokenFunctionRoles.set("transferFrom(address,address,uint256)", PUBLIC_ROLE)
tokenFunctionRoles.set("burn(uint256)", PUBLIC_ROLE)
tokenFunctionRoles.set("burnFrom(address,uint256)", PUBLIC_ROLE)

function selector(v: string) {
    return id(v).substring(0, 10)
}

task("osmi-configure-permissions", "Automated permission configuration.")
    .setAction(async (args, hre) => {
        // const { OsmiAccessManager, OsmiToken } = await loadDeployedAddresses(hre)
        await hre.run("sync-roles")
        await hre.run("sync-token-permissions")

        // await OsmiAccessManager.labelRole(BLACKLIST_ROLE, "BLACKLIST")
        // const OsmiToken = await hre.ethers.getContractAt("OsmiToken", deployedAddresses["OsmiTokenProxyModule#ERC1967Proxy"])
        // const network = await hre.ethers.provider.getNetwork()
        // console.log(`network: ${network.name} (${network.chainId})`)
        // console.log("name:", await OsmiToken.name())
        // console.log("symbol:", await OsmiToken.symbol())
        // console.log("authority:", await OsmiToken.authority())
        // console.log("total supply:", await OsmiToken.totalSupply())
        // console.log("cap:", await OsmiToken.cap())
    })

subtask("sync-roles")
    .setAction(async (taskArgs, hre) => {
        const { OsmiAccessManager } = await loadDeployedAddresses(hre)
        // get current role labels from the contract event log 
        const RoleLabel = OsmiAccessManager.getEvent("RoleLabel")
        const roleLabelEvents = await OsmiAccessManager.queryFilter(RoleLabel)
        const roleLabels = new Map<BigNumberish, string>()
        roleLabelEvents.forEach((v) => {
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
        const { OsmiAccessManager, OsmiToken } = await loadDeployedAddresses(hre)
        // get current role labels from the contract event log 
        const RoleLabel = OsmiAccessManager.getEvent("RoleLabel")
        const roleLabelEvents = await OsmiAccessManager.queryFilter(RoleLabel)
        const roleLabels = new Map<BigNumberish, string>()
        roleLabelEvents.forEach((v) => {
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

// // grant public role access to restricted functions
// builder.call(
//     osmiAccessManagerProxy,
//     "setTargetFunctionRole",
//     [
//         osmiProxy,
//         [
//             selector("transfer(address,uint256)"),
//             selector("approve(address,uint256)"),
//             selector("transferFrom(address,address,uint256)"),
//         ],
//         PUBLIC_ROLE,
//     ],
//     {id: "setTargetFunctionRolePublic"},
// )

// // grant minter rols access to restricted functions
// builder.call(
//     osmiAccessManagerProxy,
//     "setTargetFunctionRole",
//     [
//         osmiProxy,
//         [
//             selector("mint(address,uint256)"),
//         ],
//         MINTER_ROLE,
//     ],
//     {id: "setTargetFunctionRoleMinter"},
// )

// // define roles
// const BLACKLIST_ROLE = builder.staticCall(osmiAccessManagerProxy, "BLACKLIST_ROLE", [])

// // label roles
// builder.call(osmiAccessManagerProxy, "labelRole", [BLACKLIST_ROLE, "BLACKLIST"], {id: "labelBlacklistRole"})
// builder.call(osmiAccessManagerProxy, "labelRole", [MANAGER_ROLE, "MANAGER"], {id: "labelManagerRole"})
// builder.call(osmiAccessManagerProxy, "labelRole", [MINTER_ROLE, "MINTER"], {id: "labelMinterRole"})

// // managers are effectively admin without being admin
// builder.call(osmiAccessManagerProxy, "setRoleAdmin", [MINTER_ROLE, MANAGER_ROLE], {id: "setMinterRoleAdmin"})
// builder.call(osmiAccessManagerProxy, "setRoleGuardian", [MINTER_ROLE, MANAGER_ROLE], {id: "setMinterRoleGuardian"})
