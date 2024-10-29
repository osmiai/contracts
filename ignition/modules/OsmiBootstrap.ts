import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

const OsmiAccessManagerProxyModule = buildModule("OsmiAccessManagerProxyModule", (builder) => {
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

const OsmiTokenProxyModule = buildModule("OsmiTokenProxyModule", (builder) => {
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

export default OsmiTokenProxyModule