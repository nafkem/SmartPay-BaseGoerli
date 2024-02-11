const hre = require("hardhat");

async function main() {
  const SmartPay = await hre.ethers.getContractFactory("SmartPay");
  const smartPay = await SmartPay.deploy();

  await smartPay.waitForDeployment();

 //await smartPay.deployed(); // Wait for the contract to be deployed

  console.log(
    `SmartPay deployed to ${smartPay.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
