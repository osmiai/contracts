import { vars, task } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "@nomicfoundation/hardhat-ledger"
import "@openzeppelin/hardhat-upgrades"
import "./tasks/osmi-configure-permissions"
import "./tasks/osmi-tge"
import "./tasks/osmi-status"
import "./tasks/osmi-admin"

const ALCHEMY_URL_SEPOLIA = vars.get("ALCHEMY_URL_SEPOLIA")
const ALCHEMY_URL_MAINNET = vars.get("ALCHEMY_URL_MAINNET")
const OSMI_ADMIN_ADDRESS = vars.get("OSMI_ADMIN_ADDRESS")

export default {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    mainnet: {
      url: ALCHEMY_URL_MAINNET,
      ledgerAccounts: [
        OSMI_ADMIN_ADDRESS,
      ],
    },
    sepolia: {
      url: ALCHEMY_URL_SEPOLIA,
      ledgerAccounts: [
        OSMI_ADMIN_ADDRESS,
      ],
    }
  }
}
