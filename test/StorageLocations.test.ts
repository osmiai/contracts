import { expect } from "chai";
import hre from "hardhat";

describe("StorageLocations", () => {
    it("should return storage locations", async function () {
        const locations = await hre.ethers.deployContract("StorageLocations");
        console.log("OsmiAccessManagerStorageLocation:", await locations.getOsmiAccessManagerStorageLocation())
        console.log("OsmiTokenStorageLocation:", await locations.getOsmiTokenStorageLocation())
    });
})