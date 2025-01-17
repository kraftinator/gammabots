const ethers = require('ethers'); // Ensure ethers is required correctly

async function getBalance(address, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl);
    const balance = await provider.getBalance(address); // Balance in wei
    console.log('Raw balance:', balance.toString()); // Debug log for raw balance in wei
    return ethers.formatEther(balance); // Convert to ETH
}

// Accept command-line arguments
const [address, providerUrl] = process.argv.slice(2);
getBalance(address, providerUrl)
    .then(balance => {
        console.log(balance); // Print balance to stdout
    })
    .catch(error => {
        console.error(`Error: ${error.message}`); // Print errors to stderr
        process.exit(1);
    });
