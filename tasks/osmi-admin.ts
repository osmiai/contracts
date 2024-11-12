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