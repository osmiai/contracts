import { HardhatUserConfig, vars } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "@openzeppelin/hardhat-upgrades"

const ALCHEMY_URL_SEPOLIA = vars.get("ALCHEMY_URL_SEPOLIA")
const SEPOLIA_PRIVATE_KEY = vars.get("SEPOLIA_PRIVATE_KEY")

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  
  networks: {
    sepolia: {
      url: ALCHEMY_URL_SEPOLIA,
      accounts: [SEPOLIA_PRIVATE_KEY],
    }
  }
}

export default config
