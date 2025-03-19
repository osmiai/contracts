import { task, vars } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"
import { MaxUint256 } from "ethers"
import { ProviderRpcError } from "hardhat/types"

task(
  "osmi-distribution",
  "Do Osmi daily distribution.",
).setAction(async (args, hre) => {
  const { OsmiDailyDistribution } = await loadDeployedAddresses(hre)
  const network = await hre.ethers.provider.getNetwork()
  console.log(`network: ${network.name} (${network.chainId})`)
  // const pools = await OsmiDailyDistribution.getPools()
  await OsmiDailyDistribution.doDailyDistribution()
})

task(
  "osmi-grant-distribution-allowances",
  "Grant allowances to distribution manager.",
).setAction(async (args, hre) => {
  const { OsmiToken, OsmiDistributionManager, OsmiStaking } = await loadDeployedAddresses(hre)
  const distributionManagerAddress = await OsmiDistributionManager.getAddress()
  const stakingContractAddress = await OsmiStaking.getAddress()
  const stakingPoolAddress = vars.get("OSMI_STAKING_AND_COMMUNITY_INITIATIVES_ADDRESS")
  const nodesPoolAddress = vars.get("OSMI_NODE_REWARDS_ADDRESS")
  // grant node pool allowances
  {
    const nodesPool = await hre.ethers.getSigner(nodesPoolAddress)
    const nodesPoolToken = OsmiToken.connect(nodesPool)  
    if(await nodesPoolToken.allowance(nodesPoolAddress, distributionManagerAddress) != MaxUint256) {
      console.log(`approving ${distributionManagerAddress} unlimited access to ${nodesPoolAddress} $OSMI transfers.`)
      await nodesPoolToken.approve(distributionManagerAddress, MaxUint256)
    }
    if(await nodesPoolToken.allowance(nodesPoolAddress, stakingContractAddress) != MaxUint256) {
      console.log(`approving ${stakingContractAddress} unlimited access to ${nodesPoolAddress} $OSMI transfers.`)
      await nodesPoolToken.approve(stakingContractAddress, MaxUint256)
    }
  }
  // grant staking pool allowances
  {
    const stakingPool = await hre.ethers.getSigner(stakingPoolAddress)
    const stakingPoolToken = OsmiToken.connect(stakingPool)
    if(await stakingPoolToken.allowance(stakingPoolAddress, stakingContractAddress) != MaxUint256) {
      console.log(`approving ${stakingContractAddress} unlimited access to ${stakingPoolAddress} $OSMI transfers.`)
      await stakingPoolToken.approve(stakingContractAddress, MaxUint256)
    }
  }
})

task(
  "osmi-set-distribution-signer",
  "Set distribution ticket signer.",
).setAction(async (args, hre) => {
  const { OsmiDistributionManager } = await loadDeployedAddresses(hre)
  await OsmiDistributionManager.setTicketSigner("0x97932ed7cec8cEdf53e498F0efF5E55a54A0BB98")
})

task(
  "osmi-configure-distribution-bridge",
  "Configure distribution manager bridge addresses",
).setAction(async (args, hre) => {
  const { OsmiDistributionManager } = await loadDeployedAddresses(hre)
  console.log(await OsmiDistributionManager.setBridgeContract(1, "0x9f452b7cC24e6e6FA690fe77CF5dD2ba3DbF1ED9"))
})

task(
  "osmi-distro-test-claim",
).setAction(async (args, hre) => {
  const { OsmiDistributionManager } = await loadDeployedAddresses(hre)
  const projectAccount = await hre.ethers.getSigner(vars.get("OSMI_PROJECT_ADDRESS"))
  const projectDistroManager = OsmiDistributionManager.connect(projectAccount)
  try {
    const response = await projectDistroManager.bridgeTokens(1, 1)
    console.log(response)
  } catch (err) {
    const fun = err as ProviderRpcError
    console.log(fun.name)
    console.log(fun.message)
    console.log(fun.code)
    console.log(fun.data)
    console.log(fun.stack)
  }
})
