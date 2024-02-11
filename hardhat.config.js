require('@nomicfoundation/hardhat-toolbox');
require("dotenv").config({ path: ".env" });

module.exports = {
  solidity: "0.8.17",
  networks: {
    // for testnet
    'base-goerli': {
      url: 'https://goerli.base.org',
      accounts: [process.env.PRIVATE_KEY],
      gasPrice: 1000000000,
    },
  },
  etherscan: {
    apiKey: {
     "base-goerli": [process.env.BASE_API_KEY]
    },
    customChains: [
      {
        network: "base-goerli",
        chainId: 84531,
        urls: {
         apiURL: "https://api-goerli.basescan.org/api",
         browserURL: "https://goerli.basescan.org"
        }
      }
    ]
  },
  };