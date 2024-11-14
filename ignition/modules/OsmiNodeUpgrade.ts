import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

export const OsmiNodeUpgradeModule = buildModule("OsmiNodeUpgradeModule", (builder) => {
    // deploy the new implementation
    const osmiNode = builder.contract("OsmiNode")
    return { osmiNode }
})

export default OsmiNodeUpgradeModule;