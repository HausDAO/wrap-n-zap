const hre = require('hardhat');
const ethernal = require('hardhat-ethernal');

const networkName = {
	1: 'mainnet',
	42: 'kovan',
	4: 'rinkeby',
	100: 'xDai',
	137: 'polygon',
	10: 'optimism',
	69: 'optimistic kovan'
};

const networkCurrency = {
	1: 'ETH',
	42: 'ETH',
	4: 'ETH',
	100: 'xDai',
	137: 'MATIC',
	10: 'ETH',
	69: 'ETH',
};

async function main() {
	const [deployer] = await hre.ethers.getSigners();
	const address = await deployer.getAddress();
	const { chainId } = await deployer.provider.getNetwork();
	console.log('Deploying WrapNZapFactory on network:', networkName[chainId]);
	console.log('Account address:', address);
	console.log(
		'Account balance:',
		ethers.utils.formatEther(await deployer.provider.getBalance(address)),
		networkCurrency[chainId]
	);

	const factory = await ethers.getContractFactory('WrapNZapFactory');
	const wrapNZapFactory = await factory.deploy();

	await wrapNZapFactory.deployed();

	const txHash = wrapNZapFactory.deployTransaction.hash;
	const receipt = await deployer.provider.getTransactionReceipt(txHash);
	console.log('Transaction Hash:', txHash);
	console.log('Contract Address:', wrapNZapFactory.address);
	console.log('Block Number:', receipt.blockNumber);

	if (chainId == 1337) {
		await hre.ethernal.push({
			name: 'WrapNZapFactory',
			address: wrapNZapFactory.address,
		});
	}
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
