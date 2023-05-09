let addresses = require(`/Users/zandent/Files/conflux_proj/swappi-v2/swappi-deploy/contractAddressPublicTestnet.json`);
async function main() {
    console.log(`Verifying contract on Etherscan...`);
    try {
        await hre.run(`verify:verify`, {
            address: addresses.SwappiRouterWeighted,
            constructorArguments: [addresses.SwappiFactoryWeighted, addresses.WCFX]
        });
        console.log(`Done for SwappiRouterWeighted`);
    } catch (error) {}
    console.log(`Done`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});