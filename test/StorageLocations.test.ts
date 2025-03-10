import { expect } from "chai";
import { vars, task } from "hardhat/config"
import hre from "hardhat";

describe("StorageLocations", () => {
    it("should return storage locations", async function () {
        const locations = await hre.ethers.deployContract("StorageLocations");
        console.log("OsmiAccessManagerStorageLocation:", await locations.getOsmiAccessManagerStorageLocation())
        console.log("OsmiTokenStorageLocation:", await locations.getOsmiTokenStorageLocation())
        console.log("OsmiNodeStorageLocation:", await locations.getOsmiNodeStorageLocation())
        console.log("OsmiDailyDistributionStorageLocation:", await locations.getOsmiDailyDistributionStorageLocation())
        console.log("OsmiNodeFactoryStorageLocation:", await locations.getOsmiNodeFactoryStorageLocation())
        console.log("OsmiDistributionManagerStorageLocation:", await locations.getOsmiDistributionManagerStorageLocation())
        console.log("OsmiStakingStorageLocation:", await locations.getOsmiStakingStorageLocation())
    });
})