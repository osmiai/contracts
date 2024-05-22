import { expect } from "chai"
import { ethers, upgrades } from "hardhat"
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { Osmi, OsmiAccessManager } from "../typechain-types"

describe("Osmi", () => {
    async function getSigners() {
        const [owner, contractA] = await ethers.getSigners()
        return {owner, contractA}
    }
    async function deployOsmi() {
        const {owner} = await loadFixture(getSigners)

        const AccessManager = await ethers.getContractFactory("OsmiAccessManager")
        const accessManager = (await upgrades.deployProxy(AccessManager, [owner.address])) as unknown as OsmiAccessManager

        const Osmi = await ethers.getContractFactory("Osmi")
        const osmi = (await upgrades.deployProxy(Osmi, [await accessManager.getAddress()])) as unknown as Osmi

        // grant public access to external functions
        const PUBLIC_ROLE = await accessManager.PUBLIC_ROLE()
        const signatures = [
            "transfer(address,uint256)",
            "approve(address,uint256)",
            "transferFrom(address,address,uint256)",
        ]
        const selectors = []
        for (const sig of signatures) {
            const selector = ethers.id(sig).substring(0, 10)
            selectors.push(selector)
            // console.log("public:", sig, selector)
        }
        await accessManager.setTargetFunctionRole(
            osmi,
            selectors,
            PUBLIC_ROLE,
        )

        return {osmi, accessManager}
    }
    describe("blacklist", () => {
        it("works", async () => {
            const {owner, contractA} = await loadFixture(getSigners)
            const {osmi, accessManager} = await loadFixture(deployOsmi)
            const BLACKLIST_ROLE = await accessManager.BLACKLIST_ROLE()
            const PUBLIC_ROLE = await accessManager.PUBLIC_ROLE()
            expect(await accessManager.grantRole(BLACKLIST_ROLE, contractA, 0))
            expect(await accessManager.hasRole(BLACKLIST_ROLE, contractA)).to.deep.equal([true, 0n])
            expect(await accessManager.hasRole(PUBLIC_ROLE, contractA)).to.deep.equal([false, 0n])
            expect(await osmi.balanceOf(contractA)).to.equal(0n)
        })    
    })
})