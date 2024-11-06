import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

export const OsmiAccessManagerProxyModule = buildModule("OsmiAccessManagerProxyModule", (builder) => {
    // deploy the implementation contract
    const impl = builder.contract("OsmiAccessManager")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(impl, "initialize", [
        builder.getAccount(0),
    ])

    // deploy the ERC1967 proxy, pointing to the implementation
    const osmiAccessManagerProxy = builder.contract("ERC1967Proxy", [impl, initialize])

    // return the proxy
    return { osmiAccessManagerProxy }
})

export const OsmiTokenProxyModule = buildModule("OsmiTokenProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    
    // deploy the implementation contract
    const impl = builder.contract("OsmiToken")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(impl, "initialize", [
        osmiAccessManagerProxy,
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiProxy = builder.contract("ERC1967Proxy", [impl, initialize])

    // return the proxy
    return { osmiProxy }
})

export const OsmiNodeProxyModule = buildModule("OsmiNodeProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    
    // deploy the implementation contract
    const impl = builder.contract("OsmiNode")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(impl, "initialize", [
        osmiAccessManagerProxy,
    ])

    // deploy the ERC1967 proxy, pointing to the initial implementation
    const osmiNodeProxy = builder.contract("ERC1967Proxy", [impl, initialize])

    // return the proxy
    return { osmiNodeProxy }
})

export const OsmiModule = buildModule("OsmiModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)
    const { osmiProxy } = builder.useModule(OsmiTokenProxyModule)
    const { osmiNodeProxy } = builder.useModule(OsmiNodeProxyModule)    
    return { 
        osmiAccessManagerProxy,
        osmiProxy,
        osmiNodeProxy,
     }
})

export default OsmiModule;