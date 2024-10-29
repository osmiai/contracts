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
