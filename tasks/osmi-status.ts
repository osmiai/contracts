import { task, vars } from "hardhat/config"
import { loadDeployedAddresses } from "./utils"
import { BigNumberish, formatUnits } from "ethers"

function commify(value: string) {
  const match = value.match(/^(-?)([0-9]*)(\.?)([0-9]*)$/);
  if (!match || (!match[2] && !match[4])) {
    throw new Error(`bad formatted number: ${JSON.stringify(value)}`);
  }
  const neg = match[1];
  const whole = BigInt(match[2] || 0).toLocaleString("en-us");
  let frac = "0"
  if (match[4]) {
    const m4 = match[4].match(/^(.*?)0*$/)
    if (m4 && m4[1]) {
      frac = m4[1]
    }
  }
  return `${neg}${whole}.${frac}`;
}

task("osmi-status", "Reports osmi status on chain.")
  .setAction(async (args, hre) => {
    function format(v: BigNumberish) {
      return commify(formatUnits(v))
    }
    const { OsmiToken, OsmiAccessManager, OsmiNode, OsmiNodeFactory, OsmiDistributionManager, OsmiStaking } = await loadDeployedAddresses(hre)
    const network = await hre.ethers.provider.getNetwork()
    const [admin] = await hre.ethers.getSigners()
    console.log(`network: ${network.name} (${network.chainId})`)
    console.log(`account: ${admin.address}`)
    console.log("OsmiAccessManager:")
    console.log("  owner:", await OsmiAccessManager.owner())
    console.log("OsmiToken:")
    console.log("          name:", await OsmiToken.name())
    console.log("        symbol:", await OsmiToken.symbol())
    console.log("     authority:", await OsmiToken.authority())
    console.log("        closed:", await OsmiAccessManager.isTargetClosed(OsmiToken))
    console.log("           cap:", format(await OsmiToken.cap()))
    console.log("  total supply:", format(await OsmiToken.totalSupply()))
    console.log("OsmiNode:")
    console.log("          name:", await OsmiNode.name())
    console.log("        symbol:", await OsmiNode.symbol())
    console.log("     authority:", await OsmiNode.authority())
    console.log("        closed:", await OsmiAccessManager.isTargetClosed(OsmiNode))
    console.log("  total supply:", await OsmiNode.getTotalSupply())
    console.log("OsmiNodeFactory:")
    console.log("     authority:", await OsmiNodeFactory.authority())
    console.log("        closed:", await OsmiAccessManager.isTargetClosed(OsmiNodeFactory))
    {
      const [one, two] = await OsmiNodeFactory.getPurchaseTicketSigners()
      console.log("       signers:", one, two)
    }
    console.log("OsmiDistributionManager:")
    console.log("     authority:", await OsmiDistributionManager.authority())
    console.log("        closed:", await OsmiAccessManager.isTargetClosed(OsmiDistributionManager))
    console.log("       config:", await OsmiDistributionManager.getConfigContract())
    {
      const [one, two] = await OsmiDistributionManager.getTicketSigners()
      console.log("       signers:", one, two)
    }
    console.log("OsmiStaking:")
    console.log("     authority:", await OsmiStaking.authority())
    console.log("        closed:", await OsmiAccessManager.isTargetClosed(OsmiStaking))
    console.log("       config:", await OsmiStaking.getConfigContract())
    {
      const [one, two] = await OsmiStaking.getTicketSigners()
      console.log("       signers:", one, two)
    }
    console.log("osmi-nodes.eth:")
    console.log(`  $OSMI: ${format(await OsmiToken.balanceOf(vars.get("OSMI_NODE_REWARDS_ADDRESS")))}`)
    console.log("osmi-project.eth:")
    console.log(`  $OSMI: ${format(await OsmiToken.balanceOf(vars.get("OSMI_PROJECT_FUND_ADDRESS")))}`)
    console.log("osmi-referral.eth:")
    console.log(`  $OSMI: ${format(await OsmiToken.balanceOf(vars.get("OSMI_REFERRAL_PROGRAM_ADDRESS")))}`)
    console.log("osmi-community.eth:")
    console.log(`  $OSMI: ${format(await OsmiToken.balanceOf(vars.get("OSMI_STAKING_AND_COMMUNITY_INITIATIVES_ADDRESS")))}`)
    console.log("osmi-market.eth:")
    console.log(`  $OSMI: ${format(await OsmiToken.balanceOf(vars.get("OSMI_MARKET_MAKING_ADDRESS")))}`)
  })