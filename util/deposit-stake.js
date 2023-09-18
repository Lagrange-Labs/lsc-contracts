const { exec } = require('child_process');
const fs = require('fs');
require('dotenv').config();

const accountsPath = './config/accounts.json';

const rpcURL = process.env.RPC_URL;

fs.readFile(accountsPath, 'utf8', (err, data) => {
    if (err) {
        console.error('Error reading file:', err);
        return;
    }

    try {
        const accounts = JSON.parse(data);
        Object.keys(accounts).splice(0, 10).forEach((address) => {
            console.log("Starting to register operator for address: ", address);
            const command = `forge script script/localnet/Deposit_Stake.s.sol:DepositStake --rpc-url ${rpcURL} --private-key ${accounts[address]} --broadcast -vvvvv`
            exec(command, (error, stdout, stderr) => {
                console.log(`Command output: ${stdout}`);
                if (error) {
                    console.error(`Error executing command: ${error.message}`);
                    return;
                }

                if (stderr) {
                    console.error(`Command stderr: ${stderr}`);
                    return;
                }
            });
        });
    } catch (err) {
        console.error('Error parsing JSON string:', err);
    }
});