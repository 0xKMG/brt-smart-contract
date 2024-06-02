import "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import hre, { deployments, ethers, getNamedAccounts } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  //standard config
  const {
    deployments: { deploy, get, save, execute },
    getNamedAccounts,
  } = hre;

  const { deployer } = await getNamedAccounts();
  //
  //     deploy mock token contract
  //   const mockToken = await deploy("ERC20Mock", {
  //     from: deployer,
  //     args: ["Be Right There", "BRT"],
  //     log: true,
  //   });

  const deployment = await deploy("EventContract", {
    from: deployer,
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: ["0xbd1270f3f8175927Fe427a220b9253b360Be52Bd"],
        },
      },
      proxyContract: "OpenZeppelinTransparentProxy",
    },
    log: true,
  });

  await save("EventContract", { ...deployment, abi: deployment.abi });
  //   await save("ERC20Mock", { ...mockToken, abi: mockToken.abi });

  //   await execute("ERC20Mock", { from: deployer, log: true }, "approve", deployment.address, ethers.parseEther("10000"));
  //
//   await execute(
//     "EventContract",
//     { from: deployer, log: true },
//     "createEvent",
//     "Hello",
//     "1717307907619",
//     "1719820800000",
//     ethers.parseEther("1000"),
//     ethers.parseEther("900"),
//     "0x0000000000000000000000000153737f00000000000000000000000006ce0d46",
//     [
//       "0xadd81d4f68ab0420eda840cfbc07ff2d6fd708f1",
//       "0x8fa77bbece6f2654d65c268b7dd636998ccb9576",
//       "0x764580ab307e0c6ee032b467d212dae7690b1424",
//       "0x33e3f1a34bf0bac3620f2bd4334b23fde1423831",
//     ],
//   );
};

export default func;
//
func.tags = ["test"];
