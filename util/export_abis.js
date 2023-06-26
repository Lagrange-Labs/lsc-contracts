const fs = require('fs')
const path = require('path');

async function main() {
    // Contract ABI
    const lc_out = await fs.readFileSync(path.join(__dirname,"../out/LagrangeCommittee.sol/LagrangeCommittee.json"));
    const lc_json = await JSON.parse(lc_out);
    const jsonABI = lc_json.abi;
    const jsonStr = JSON.stringify(jsonABI,null,2);

    // Contract Binary
    const bin = lc_json.deployedBytecode.object;

    // Write to lagrange-node
    await fs.writeFileSync(path.join(__dirname,"../../lagrange-node/scinterface/bin/LagrangeCommittee.abi"),jsonStr);
    await fs.writeFileSync(path.join(__dirname,"../../lagrange-node/scinterface/bin/LagrangeCommittee.bin"),bin);
}

main();
