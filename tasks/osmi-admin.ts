import { task, vars } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"

task("osmi-close", "Close OsmiToken.")
    .setAction(async (args, hre) => {
        const { OsmiAccessManager, OsmiToken } = await loadDeployedAddresses(hre)
        await OsmiAccessManager.setTargetClosed(OsmiToken, true)
    })

task("osmi-open", "Open OsmiToken.")
    .setAction(async (args, hre) => {
        const { OsmiAccessManager, OsmiToken } = await loadDeployedAddresses(hre)
        await OsmiAccessManager.setTargetClosed(OsmiToken, false)
    })

task("osmi-new-wallet", "Create a new random wallet.")
    .setAction(async (args, hre) => {
        const wallet = hre.ethers.Wallet.createRandom()
        console.log("address:", wallet.address)
        console.log("private key:", wallet.signingKey.privateKey)
    })

task("osmi-mint-alpha-nodes", "Mint those alpha nodes")
    .setAction(async (args, hre) => {
        const { OsmiNode } = await loadDeployedAddresses(hre)
        const alphaNodes = [
            { token: 0, address: "0x72e03eB06BFfb113dd0040E455F3423922275092" },
            { token: 1, address: "0xb427419E84855957801F2ef1272Af02825FA6322" },
            { token: 2, address: "0xf11c6Ae858Dd1e9a28DB4cfcd41Ba7E1aF59CE50" },
            { token: 3, address: "0xC5c5Bb1aD74FF8825D10bba248f60608DCdC5c86" },
        ]
        const totalSupply = await OsmiNode.getTotalSupply()
        for (let node of alphaNodes) {
            if (totalSupply > node.token) {
                const owner = await OsmiNode.ownerOf(node.token)
                console.log(`token: ${node.token} owner: ${owner}`)
            } else {
                console.log(`token: ${node.token} owner: null`)
                console.log(`   minting token: ${node.token} to address: ${node.address}`)
                await OsmiNode.safeMint(node.address)
            }
        }
    })

task("osmi-sign-message", "Manually sign a message.")
    .setAction(async (args, hre) => {
        const [ admin ] = await hre.ethers.getSigners()
        const response = await admin.signMessage("[Etherscan.io 23/11/2024 16:33:25] I, hereby verify that I am the owner/creator of the address [0xbf9a19e7e926d5d4c1a789f76db0af23ca9854ab]")
        console.log(response)
    })


task("osmi-upgrade-node", "Upgrade OsmiNode implementation.")
    .setAction(async (args, hre) => {
        // TODO: SNICHOLS: clean this up
        const { OsmiNode } = await loadDeployedAddresses(hre)
        // await OsmiNode.upgradeToAndCall("0x14EA14A50fE434B5f7d9d337a5f096d7054e3d8e", "0x")
    })
