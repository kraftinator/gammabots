const ethersFunctions = require('./ethers_utils');

async function main() {
    const [functionName, ...args] = process.argv.slice(2);

    try {
        if (ethersFunctions[functionName]) {
            const result = await ethersFunctions[functionName](...args);
            console.log(JSON.stringify({ success: true, result }));
        } else {
            throw new Error(`Invalid function name: ${functionName}`);
        }
    } catch (error) {
        console.error(JSON.stringify({ success: false, error: error.message }));
        process.exit(1);
    }
}

main();
