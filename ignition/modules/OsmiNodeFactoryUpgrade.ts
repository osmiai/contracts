import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

export const OsmiNodeFactoryUpgradeModule = buildModule("OsmiNodeFactoryUpgradeModule", (builder) => {
    // deploy the new implementation
    const osmiNode = builder.contract("OsmiNodeFactory")
    return { osmiNode }
})

export default OsmiNodeFactoryUpgradeModule;