import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

export const OsmiDistributionManagerUpgradeModule = buildModule("OsmiDistributionManagerUpgradeModule", (builder) => {
    // deploy the new implementation
    const osmiDistributionManager = builder.contract("OsmiDistributionManager")
    return { osmiDistributionManager }
})

export default OsmiDistributionManagerUpgradeModule;