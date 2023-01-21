require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
/** @type import('hardhat/config').HardhatUserConfig */

const AURORA_PRIVATE_KEY = "3ed376fe27223f063fd74515ae37bb7d0f87a58e5762194316d7a325d9acc87a";

module.exports = {
	  solidity: "0.8.17",
	  networks: {
		      testnet_aurora: {
			            url: 'https://testnet.aurora.dev',
			            accounts: [`0x${AURORA_PRIVATE_KEY}`],
			            chainId: 1313161555,
			            gasPrice: 120 * 1000000000
			          },
		      local_aurora: {
			            url: 'http://localhost:8545',
			            accounts: [`0x${AURORA_PRIVATE_KEY}`],
			            chainId: 1313161555,
			            gasPrice: 120 * 1000000000
			          },
		      ropsten: {
			            url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
			            accounts: [`0x${AURORA_PRIVATE_KEY}`],
			            chainId: 3,
			            live: true,
			            gasPrice: 50000000000,
			            gasMultiplier: 2,
			          },
		      goerli : {
			                  url: `https://eth-goerli.alchemyapi.io/v2/2Fy33mEevVi6JEtiqTk_vYDrlAlbtKjh`,
			                  accounts: [`0x${AURORA_PRIVATE_KEY}`]
			          },
		    },
	  etherscan: {
		      // Your API key for Etherscan
		  //     // Obtain one at https://etherscan.io/
		          apiKey: "K8IEHI3UW38W7A93A7GQS2JJMCDIIWJUAF" //AuroraKey
		                  //  apiKey: "V6FQPUW8Y52DVEMCUTH7ZRQPWT8JD4HEMJ"
		                    }
		                    };
