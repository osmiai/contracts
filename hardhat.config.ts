import { vars, task } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "@nomicfoundation/hardhat-ledger"
import "@openzeppelin/hardhat-upgrades"
import "hardhat-contract-sizer"
import "./tasks/osmi-configure-permissions"
import "./tasks/osmi-tge"
import "./tasks/osmi-status"
import "./tasks/osmi-admin"
import "./tasks/osmi-distribution"

const ALCHEMY_URL_SEPOLIA = vars.get("ALCHEMY_URL_SEPOLIA")
const ALCHEMY_URL_MAINNET = vars.get("ALCHEMY_URL_MAINNET")
const OSMI_ADMIN_ADDRESS = vars.get("OSMI_ADMIN_ADDRESS")
const OSMI_PROJECT_ADDRESS = vars.get("OSMI_PROJECT_ADDRESS")
const OSMI_NODE_REWARDS_ADDRESS = vars.get("OSMI_NODE_REWARDS_ADDRESS")

export default {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      // evmVersion: 'cancun',
    },
  },
  networks: {
    mainnet: {
      url: ALCHEMY_URL_MAINNET,
      // accounts: [OSMI_OVERSEER_PRIVATE_KEY],
      ledgerAccounts: [
        OSMI_ADMIN_ADDRESS,
        OSMI_PROJECT_ADDRESS,
        OSMI_NODE_REWARDS_ADDRESS,
      ],
    },
    sepolia: {
      url: ALCHEMY_URL_SEPOLIA,
      ledgerAccounts: [
        OSMI_ADMIN_ADDRESS,
        OSMI_PROJECT_ADDRESS,
        OSMI_NODE_REWARDS_ADDRESS,
      ],
      // accounts: [OSMI_OVERSEER_PRIVATE_KEY],
    }
  }
}
