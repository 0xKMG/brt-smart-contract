import "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  //standard config
  const {
    deployments: { deploy, get, save, execute },
    getNamedAccounts,
  } = hre;

  const { deployer } = await getNamedAccounts();

  //deploy mock token contract
  const mockToken = await deploy("ERC20Mock", {
    from: deployer,
    args: ["Be Right There", "BRT"],
    log: true,
  });

  const deployment = await deploy("EventContract", {
    from: deployer,
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: [mockToken.address],
        },
      },
      proxyContract: "OpenZeppelinTransparentProxy",
    },
    log: true,
  });

  await save("EventContract", { ...deployment, abi: deployment.abi });
};

export default func;
//
func.tags = ["test"];
