import { task } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"

task("osmi-status", "Reports osmi status on chain.")
  .setAction(async (args, hre) => {
    const { OsmiToken } = await loadDeployedAddresses(hre)
    const network = await hre.ethers.provider.getNetwork()
    console.log(`network: ${network.name} (${network.chainId})`)
    console.log("name:", await OsmiToken.name())
    console.log("symbol:", await OsmiToken.symbol())
    console.log("authority:", await OsmiToken.authority())
    console.log("total supply:", await OsmiToken.totalSupply())
    console.log("cap:", await OsmiToken.cap())
  })
