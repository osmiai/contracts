import { task, vars } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"

task("osmi-distribution", "Do Osmi daily distribution.")
  .setAction(async (args, hre) => {
    const { OsmiDailyDistribution } = await loadDeployedAddresses(hre)
    const network = await hre.ethers.provider.getNetwork()
    console.log(`network: ${network.name} (${network.chainId})`)
    // const pools = await OsmiDailyDistribution.getPools()
    await OsmiDailyDistribution.doDailyDistribution()
  })