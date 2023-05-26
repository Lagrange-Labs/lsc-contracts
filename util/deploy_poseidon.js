const fs = require('fs')
const path = require('path');
const exec = require('child_process');
const poseidonUnit = require("circomlib/src/poseidon_gencontract.js");
const ethers = require("ethers");

async function deployPoseidon() {

    console.log('Generating and deploying Hermez/Poseidon contracts...');

    // Poseidon Contracts
    const currentProvider = new ethers.providers.JsonRpcProvider('http://0.0.0.0:8545');
    const signerNode = await currentProvider.getSigner();
    poseidonAddrs = {};
    for (i = 2; i<= 4; i++) {
	cf = new ethers.ContractFactory(
	    poseidonUnit.generateABI(i),
	    poseidonUnit.createCode(i),
	    signerNode
	);
	cd = await cf.deploy();
	if(i == 2) {
	    res = await cd["poseidon(uint256[2])"]([1,2]);
	    resString = await res.toString();
	    target = String("7853200120776062878684798364095072458815029376092732009249414926327459813530");
	    console.log("Result:",resString);
	    console.log("Expected:",target);
	    console.log("Hash check:",resString==target);
	}
	cd = await cd.deployed();
	console.log("poseidon "+i+" elements at: ", cd.address);
	poseidonAddrs[i] = cd.address;
    }
    console.log("deployed poseidon libs");
    console.log(poseidonAddrs);
    
    jsonAddrs = JSON.stringify(poseidonAddrs,null,2);
    
    fs.writeFile(path.join(__dirname, 'addresses.json'), jsonAddrs, err => {
        if (err) {
            console.log('Error writing addresses to file:', err)
        } else {
            console.log('Addresses written to addresses.json')
        }
    });
    console.log(jsonAddrs);
}

deployPoseidon();
