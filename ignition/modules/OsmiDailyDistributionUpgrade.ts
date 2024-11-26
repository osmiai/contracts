import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

export const OsmiDailyDistributionUpgradeModule = buildModule("OsmiDailyDistributionUpgradeModule", (builder) => {
    // deploy the new implementation
    const osmiNode = builder.contract("OsmiDailyDistribution")
    return { osmiNode }
})

export default OsmiDailyDistributionUpgradeModule;