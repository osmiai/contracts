import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

export const OsmiStakingUpgradeModule = buildModule("OsmiStakingUpgradeModule", (builder) => {
    // deploy the new implementation
    const osmiStaking = builder.contract("OsmiStaking")
    return { osmiStaking }
})

export default OsmiStakingUpgradeModule;