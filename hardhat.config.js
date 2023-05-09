require("@nomiclabs/hardhat-etherscan");
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    testnet: {
      url: 'http://evmtestnet.confluxrpc.com',
    },
    espace: {
      url: 'http://evm.confluxrpc.com',
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: 'an api key',
    customChains: [
      {
        network: "testnet",
        chainId: 71,
        urls: {
          apiURL: "https://evmapi-testnet.confluxscan.net/api",
          browserURL: "https://evmapi-testnet.confluxscan.net"
        }
      },
      {
        network: "espace",
        chainId: 1030,
        urls: {
          apiURL: "https://evmapi.confluxscan.net/api",
          browserURL: "https://evmapi.confluxscan.net"
        }
      }
    ]
  },
  solidity: {
    version: '0.6.6',
    settings: {
      outputSelection: {
        "*": {
          "*": [
            "evm.bytecode.object",
            "evm.deployedBytecode*",
            "abi",
            "evm.bytecode.sourceMap",
            "metadata"
          ],
          "": ["ast"]
        }
      },
      evmVersion: "istanbul",
      optimizer: {
        enabled: true,
        runs: 999999
      }
    },
  },
};
