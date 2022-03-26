require('dotenv').config();
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-etherscan');
require('hardhat-ethernal');

const { ETHERSCAN_API_KEY, INFURA_PROJECT_ID, SEED } = process.env;

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
	const accounts = await ethers.getSigners();

	for (const account of accounts) {
		console.log(account.address);
	}
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
	solidity: {
		version: '0.8.1',
		settings: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
		},
	},
	networks: {
		localhost: {
			url: 'http://127.0.0.1:8545',
		},
		hardhat: {
			accounts: {
				mnemonic: SEED,
			},
			chainId: 1337,
		},
		xdai: {
			url: 'https://xdai.1hive.org/',
			accounts: {
				mnemonic: SEED,
				count: 1,
				gasPrice: 1000000000,
			},
			gasPrice: 1000000000,
		},
		rinkeby: {
			url: `https://rinkeby.infura.io/v3/${INFURA_PROJECT_ID}`,
			accounts: {
				mnemonic: SEED,
				count: 1,
			},
		},
		kovan: {
			url: `https://kovan.infura.io/v3/${INFURA_PROJECT_ID}`,
			accounts: {
				mnemonic: SEED,
				count: 1,
			},
		},
		polygon: {
			url: 'https://rpc-mainnet.matic.network',
			chainId: 137,
			accounts: {
				mnemonic: SEED,
				count: 1,
			},
			gasPrice: 1000000000,
		},

		mainnet: {
			url: `https://mainnet.infura.io/v3/${INFURA_PROJECT_ID}`,
			accounts: {
				mnemonic: SEED,
				count: 1,
			},
			gasPrice: 15000000000
		},
    'optimism': {
      url: "https://mainnet.optimism.io",
      accounts: {
				mnemonic: SEED,
				count: 1,
			},
    },
    'optimism-kovan': {
      url: "https://kovan.optimism.io",
      accounts: {
				mnemonic: SEED,
				count: 1,
			},
    },
	},
	etherscan: {
		apiKey: ETHERSCAN_API_KEY,
	},
};

