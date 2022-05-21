import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import buildList from '@uniswap/default-token-list/build/uniswap-default.tokenlist.json';

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { getNamedAccounts, deployments } = hre as any;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  //use env? if not using pathway or Badge then server address can go since only needed for verify
  const DEV_ADDRESS = "0xA072f8Bd3847E21C8EdaAf38D7425631a2A63631";
  const SERVER_ADDRESS = "0xA072f8Bd3847E21C8EdaAf38D7425631a2A63631";

  const NFTeeContract = await deploy('NFTee', {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [100],
    log: true,
  });
  console.log(`NFTee contract deployed to ${NFTeeContract.address}`);

  const NFTeeStakerContract = await deploy('NFTeeStaker', {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [NFTeeContract.address, 'Staked NFTee', 'stNFTEE'],
    log: true,
  });

  const project = await deploy("ProjectNFT", {
    from: deployer,
    args: [
      DEV_ADDRESS,
      [
        DEV_ADDRESS,
        "0xA072f8Bd3847E21C8EdaAf38D7425631a2A63631",
        "0x2c0B08C414A8EE088596832cf64eFcA283D46703",
        "0x16eBE01dCae1338f8d1802C63712C5279e768d29",
        "0x3E31155a1c17c9F85e74828447aec412090a4622",
        "0x4678854dB7421fF1B3C5ACAe6c5C11e73f4F5702",
        "0xDAFf97a69408Cdb4AeFE331eA029a55e189ef60b",
        "0xD39C3Cdb811f6544067ECFeDEf40855578cA0C52",
      ],
      10,
    ],
    log: true,
  });

  const vrf = await deploy("RandomNumberConsumer", {
    from: deployer,
    args: [
      [
        DEV_ADDRESS,
        "0xA072f8Bd3847E21C8EdaAf38D7425631a2A63631",
        "0x2c0B08C414A8EE088596832cf64eFcA283D46703",
        "0x16eBE01dCae1338f8d1802C63712C5279e768d29",
        "0x3E31155a1c17c9F85e74828447aec412090a4622",
        "0x4678854dB7421fF1B3C5ACAe6c5C11e73f4F5702",
        "0xDAFf97a69408Cdb4AeFE331eA029a55e189ef60b",
        "0xD39C3Cdb811f6544067ECFeDEf40855578cA0C52",
      ],
    ],
    log: true,
  });

  const verify = await deploy("Verify", {
    from: deployer,
    args: [
      SERVER_ADDRESS,
      [
        DEV_ADDRESS,
        "0xA072f8Bd3847E21C8EdaAf38D7425631a2A63631",
        "0x2c0B08C414A8EE088596832cf64eFcA283D46703",
        "0x16eBE01dCae1338f8d1802C63712C5279e768d29",
        "0x3E31155a1c17c9F85e74828447aec412090a4622",
        "0x4678854dB7421fF1B3C5ACAe6c5C11e73f4F5702",
        "0xDAFf97a69408Cdb4AeFE331eA029a55e189ef60b",
        "0xD39C3Cdb811f6544067ECFeDEf40855578cA0C52",
      ],
    ],
    log: true,
  });

  const pathway = await deploy("PathwayNFT", {
    from: deployer,
    args: [vrf.address, project.address, verify.address],
    log: true,
  });

  const badge = await deploy("BadgeNFT", {
    from: deployer,
    args: [vrf.address, project.address, pathway.address, verify.address],
    log: true,
  });
  
  const sponsorSFT = await deploy("SponsorPassSFT", {
    from: deployer,
    args: [
      [`0xde0b6b3a7640000`, `0x29a2241af62c0000`, `0x4563918244f40000`],
      project.address,
    ],
    log: true,
  });

  const dCompToken = await deploy("DCompToken", {
    from: deployer,
    args: [
      project.address
    ],
    log: true,
  });

  const apiConsumer = await deploy("APIConsumer", {
    from: deployer,
    args: [
      project.address,
      sponsorSFT.address
    ],
    log: true,
  })

  const appDiamond = await deploy("AppDiamond", {
    from: deployer,
    args: [
      project.address,
      pathway.address,
      verify.address,
      sponsorSFT.address,
      SERVER_ADDRESS,
    ],
    log: true,
  });

  // const adventurerNFTImpl = await deploy("AdventurerNFT", {
  //   from: deployer,
  //   args: [],
  //   log: true,
  // });

  // const adventurerNFTFactory = await deploy("AdventurerBadgeFactory", {
  //   from: deployer,
  //   args: [adventurerNFTImpl.address, project.address, pathway.address, badge.address, appDiamond.address],
  //   log: true,
  // });

  await deployments.execute(
    "ProjectNFT",
    { from: deployer },
    "setAppDiamond",
    appDiamond.address
  );
  await deployments.execute(
    "ProjectNFT",
    { from: deployer },
    "setSFTAddr",
    sponsorSFT.address
  );
  await deployments.execute(
    "PathwayNFT",
    { from: deployer },
    "setAppDiamond",
    appDiamond.address
  );
  await deployments.execute(
    "BadgeNFT",
    { from: deployer },
    "setAppDiamond",
    appDiamond.address
  );
  // await deployments.execute(
  //   "BadgeNFT",
  //   { from: DEPLOYER_PRIVATE_KEY },
  //   "setAdventureFactory",
  //   adventurerNFTFactory.address
  // );

  // const chainIds = "1, 3, 4, 42, 137, 80001";
  // const chainIdsArray : Number[] = chainIds
  //   .split(", ")
  //   .map((chainId) => parseInt(chainId, 10));

  // const chainAddrObj : any = {};
  // chainIdsArray.forEach((value : String) => {
  //   chainAddrObj[value] = [];
  // });

  // const tokens = buildList.tokens;
  // tokens.map((value, index) => {
  //   if (chainIdsArray.includes(value.chainId)) {
  //     chainAddrObj[value.chainId].push(value.address);
  //   }
  // });

  // for (let i = 0; i < chainIdsArray.length; i++) {
  //   await deployments.execute(
  //     "AppDiamond",
  //     { from: deployer },
  //     "addERC20PerChain",
  //     chainIdsArray[i],
  //     chainAddrObj[chainIdsArray[i]]
  //   );
  // }

  console.log(`NFTeeStaker contract deployed to ${NFTeeStakerContract.address}`);



  /*
    // Getting a previously deployed contract
    const YourContract = await ethers.getContract("YourContract", deployer);
    await YourContract.setPurpose("Hello");
    
    //const yourContract = await ethers.getContractAt('YourContract', "0xaAC799eC2d00C013f1F11c37E654e59B0429DF6A") //<-- if you want to instantiate a version of a contract at a specific address!
  */
};
export default func;

/*
Tenderly verification
let verification = await tenderly.verify({
  name: contractName,
  address: contractAddress,
  network: targetNetwork,
});
*/
