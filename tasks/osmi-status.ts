import { task, vars } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"

task("osmi-status", "Reports osmi status on chain.")
  .setAction(async (args, hre) => {
    const { OsmiToken, OsmiAccessManager } = await loadDeployedAddresses(hre)
    const network = await hre.ethers.provider.getNetwork()
    console.log(`network: ${network.name} (${network.chainId})`)
    console.log("OsmiAccessManager:")
    console.log("  PUBLIC_ROLE:", await OsmiAccessManager.PUBLIC_ROLE())
    console.log("  ADMIN_ROLE:", await OsmiAccessManager.ADMIN_ROLE())
    console.log("  owner:", await OsmiAccessManager.owner())
    console.log("OsmiToken:")
    console.log("  name:", await OsmiToken.name())
    console.log("  symbol:", await OsmiToken.symbol())
    console.log("  authority:", await OsmiToken.authority())
    console.log("  closed:", await OsmiAccessManager.isTargetClosed(OsmiToken))
    console.log("  total supply:", await OsmiToken.totalSupply())
    console.log("  cap:", await OsmiToken.cap())
  })