import { task, vars } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"

task("osmi-close", "Close OsmiToken.")
    .setAction(async (args, hre) => {
        const { OsmiAccessManager, OsmiToken } = await loadDeployedAddresses(hre)
        await OsmiAccessManager.setTargetClosed(OsmiToken, true)
    })

task("osmi-open", "Open OsmiToken.")
    .setAction(async (args, hre) => {
        const { OsmiAccessManager, OsmiToken } = await loadDeployedAddresses(hre)
        await OsmiAccessManager.setTargetClosed(OsmiToken, false)
    })

task("osmi-new-wallet", "Create a new random wallet.")
    .setAction(async (args, hre) => {
        const wallet = hre.ethers.Wallet.createRandom()
        console.log("address:", wallet.address)
        console.log("private key:", wallet.signingKey.privateKey)
    })


task("osmi-upgrade-node", "Upgrade OsmiNode implementation.")
    .setAction(async (args, hre) => {
        // TODO: SNICHOLS: clean this up
        const { OsmiNode } = await loadDeployedAddresses(hre)
        // await OsmiNode.upgradeToAndCall("0xbC66EdCd35a91A682125753243984E9a54e700BB", "0x")
    })    