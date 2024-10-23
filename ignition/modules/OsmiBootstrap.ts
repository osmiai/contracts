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

const OsmiAccessManagerModule = buildModule("OsmiAccessManagerModule", (builder) => {
    // get the proxy from the previous module
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerProxyModule)

    // instantiate the contract using the deployed proxy
    const osmiAccessManagerImpl = builder.contractAt("OsmiAccessManager", osmiAccessManagerProxy)
    
    // return the instance and proxy
    return { osmiAccessManagerImpl, osmiAccessManagerProxy }
})

const OsmiTokenProxyModule = buildModule("OsmiTokenProxyModule", (builder) => {
    const { osmiAccessManagerProxy } = builder.useModule(OsmiAccessManagerModule)
    
    // deploy the implementation contract
    const impl = builder.contract("OsmiToken")

    // encode the initalize function call for the contract
    const initialize = builder.encodeFunctionCall(impl, "initialize", [
        osmiAccessManagerProxy,
    ])

    // deploy the ERC1967 proxy, pointing to the implementation
    const osmiProxy = builder.contract("ERC1967Proxy", [impl, initialize])

    // return the proxy
    return { osmiProxy }
})

const OsmiTokenModule = buildModule("OsmiModule", (builder) => {
    // get the proxy from the previous module
    const { osmiProxy } = builder.useModule(OsmiTokenProxyModule)

    // instantiate the contract using the deployed proxy
    const osmiTokenImpl = builder.contractAt("OsmiToken", osmiProxy)
    
    // return the instance and proxy
    return { osmiTokenImpl, osmiProxy }
})

export default OsmiTokenModule