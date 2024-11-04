import { task, subtask, vars } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"
import { parseUnits, formatUnits, AddressLike, BigNumberish } from "ethers"

task("osmi-tge", "Token generation event")
    .setAction(async (args, hre) => {
        await hre.run("tge-mint")
    })

subtask("tge-mint")
    .setAction(async (args, hre) => {
        const TGETotalMint = 100_000_000n
        interface TGEMint {
            target: AddressLike
            amount: bigint
        }
        const mints:TGEMint[] = [
            {target: vars.get("OSMI_NODE_REWARDS_ADDRESS"), amount: 50_000_000n},
            {target: vars.get("OSMI_MARKET_MAKING_ADDRESS"), amount: 20_000_000n},
            {target: vars.get("OSMI_PROJECT_FUND_ADDRESS"), amount: 20_000_000n},
            {target: vars.get("OSMI_REFERRAL_PROGRAM_ADDRESS"), amount: 10_000_000n},
        ]
        let total = 0n
        for(const mint of mints) {
            total += mint.amount            
        }
        if(total > TGETotalMint) {
            throw new Error("mints exceed allotted total")
        }
        const { OsmiToken } = await loadDeployedAddresses(hre)
        const decimals = await OsmiToken.decimals()
        const [ admin ] = await hre.ethers.getSigners()
        console.log(`OsmiToken: ${await OsmiToken.getAddress()}`)
        console.log(`Account: ${admin.address}`)
        for(const mint of mints) {
            const amount = parseUnits(mint.amount.toString(), decimals)
            const balance = await OsmiToken.balanceOf(mint.target)
            if(balance < amount) {
                const tokensToMint = amount - balance
                console.log(`mint: ${tokensToMint} to ${mint.target} (balance ${balance})`)
                await OsmiToken.mint(mint.target, tokensToMint)
            }
        }
        // const totalSupply = await OsmiToken.totalSupply()
        // const decimals = await OsmiToken.decimals()
        // const initialSupply = parseUnits(tgeInitialMint.toString(), decimals)
        // if (totalSupply >= initialSupply) {
        //     console.log("mint not required")
        //     return
        // }
        // console.log(`initialSupply: ${initialSupply}`)
        // console.log(`  totalSupply: ${totalSupply}`)
        // const tokensToMint = initialSupply - totalSupply
        // console.log(`      minting: ${tokensToMint}`)
        // await OsmiToken.mint()
    })