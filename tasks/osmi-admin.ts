import { task } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"
import { AddressLike } from "ethers"

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

task("osmi-mint-team-nodes", "Mint 250 nodes for the team.")
    .setAction(async (args, hre) => {
        const { OsmiNode } = await loadDeployedAddresses(hre)
        interface Mint {
            token: bigint
            address: AddressLike
        }
        const mints: Mint[] = []
        let token = 4n
        // grant snichols
        for (let i = 0; i < 75; i++) {
            mints.push({ token: token, address: "0x72e03eB06BFfb113dd0040E455F3423922275092" })
            token++
        }
        // grant eric
        for (let i = 0; i < 75; i++) {
            mints.push({ token: token, address: "0xb427419E84855957801F2ef1272Af02825FA6322" })
            token++
        }
        // grant chuter
        for (let i = 0; i < 75; i++) {
            mints.push({ token: token, address: "0xf11c6Ae858Dd1e9a28DB4cfcd41Ba7E1aF59CE50" })
            token++
        }
        // grant qasim
        for (let i = 0; i < 25; i++) {
            mints.push({ token: token, address: "0xC5c5Bb1aD74FF8825D10bba248f60608DCdC5c86" })
            token++
        }
        if (mints.length != 250) {
            throw new Error("mint count mismatch")
        }
        const overseer = await hre.ethers.getSigner("0x97932ed7cec8cEdf53e498F0efF5E55a54A0BB98")
        console.log("overseer:", overseer.address)
        const overseerOsmiNode = OsmiNode.connect(overseer)
        const totalSupply = await overseerOsmiNode.getTotalSupply()
        for (let node of mints) {
            if (totalSupply > node.token) {
                const owner = await overseerOsmiNode.ownerOf(node.token)
                console.log(`token: ${node.token} owner: ${owner}`)
            } else {
                console.log(`token: ${node.token} owner: null`)
                console.log(`   minting token: ${node.token} to address: ${node.address}`)
                await overseerOsmiNode.safeMint(node.address)
            }
        }
    })

task("unlock-node", "Remove the transfer lock for a node.")
    .setAction(async (args, hre) => {
        // const { OsmiNode } = await loadDeployedAddresses(hre)
        // const tokens = [76, 77, 78]
        // for(let i = 0; i < tokens.length; i++) {
        //     const token = tokens[i]
        //     await OsmiNode.setTransferLockedUntil(token, 1764075071n)
        //     // const lockedUntil = await OsmiNode.getTransferLockedUntil(token)
        //     // console.log("token:", token, "locked until:", lockedUntil)
        // }
    })

// task("osmi-burn", "Burn from the project fund.")
//     .setAction(async (args, hre) => {
//         const { OsmiToken } = await loadDeployedAddresses(hre)
//         const projectFund = await hre.ethers.getSigner("0xAdEE73C733cD77b9Ca906803bBE2cd5064D28487")
//         if (projectFund.address != "0xAdEE73C733cD77b9Ca906803bBE2cd5064D28487") {
//             throw new Error("project fund address not found")
//         }
//         const amount = 3_000_000_000000000000000000n
//         await OsmiToken.connect(projectFund).burn(amount)
//     })

// task("osmi-mint-project", "Mint to the project fund")
//     .setAction(async (args, hre) => {
//         const { OsmiToken } = await loadDeployedAddresses(hre)
//         const amount = 2_250_000_000000000000000000n
//         await OsmiToken.mint("0xAdEE73C733cD77b9Ca906803bBE2cd5064D28487", amount)
//     })

task("osmi-sign-message", "Manually sign a message.")
    .setAction(async (args, hre) => {
        const [admin] = await hre.ethers.getSigners()
        const response = await admin.signMessage("[Etherscan.io 23/11/2024 16:33:25] I, hereby verify that I am the owner/creator of the address [0xbf9a19e7e926d5d4c1a789f76db0af23ca9854ab]")
        console.log(response)
    })

task("osmi-upgrade-node", "Upgrade OsmiNode implementation.")
    .setAction(async (args, hre) => {
        // TODO: SNICHOLS: clean this up
        const { OsmiNode } = await loadDeployedAddresses(hre)
        // await OsmiNode.upgradeToAndCall("<address>", "0x")
    })

task("osmi-upgrade-node-factory", "Upgrade OsmiNodeFactory implementation.")
    .setAction(async (args, hre) => {
        // TODO: SNICHOLS: clean this up
        const { OsmiNodeFactory } = await loadDeployedAddresses(hre)
        // await OsmiNodeFactory.upgradeToAndCall("<address>", "0x")
    })

task("osmi-upgrade-daily-distribution", "Upgrade OsmiDailyDistribution implementation.")
    .setAction(async (args, hre) => {
        // TODO: SNICHOLS: clean this up
        const { OsmiDailyDistribution } = await loadDeployedAddresses(hre)
        // await OsmiDailyDistribution.upgradeToAndCall("<address>", "0x")
    })

task("osmi-upgrade-distribution-manager", "Upgrade OsmiDistributionManager implementation.")
    .setAction(async (args, hre) => {
        // TODO: SNICHOLS: clean this up
        const { OsmiDistributionManager } = await loadDeployedAddresses(hre)
        await OsmiDistributionManager.upgradeToAndCall("0x21C4fC244D02EC5EC0df4eF7861362171076E7Cc", "0x")
    })
