import { HardhatRuntimeEnvironment } from "hardhat/types"
import fs from "fs"

export async function loadDeployedAddresses(hre: HardhatRuntimeEnvironment) {
    const network = await hre.ethers.provider.getNetwork()
    const addresses = JSON.parse(fs.readFileSync(`./ignition/deployments/chain-${network.chainId}/deployed_addresses.json`, 'utf-8'))
    return {
        addresses,
        OsmiAccessManager: await hre.ethers.getContractAt("OsmiAccessManager", addresses["OsmiAccessManagerProxyModule#ERC1967Proxy"]),
        OsmiToken: await hre.ethers.getContractAt("OsmiToken", addresses["OsmiTokenProxyModule#ERC1967Proxy"]),
        OsmiNode: await hre.ethers.getContractAt("OsmiNode", addresses["OsmiNodeProxyModule#ERC1967Proxy"]),
        OsmiDailyDistribution: await hre.ethers.getContractAt("OsmiDailyDistribution", addresses["OsmiDailyDistributionProxyModule#ERC1967Proxy"]),
    }
}