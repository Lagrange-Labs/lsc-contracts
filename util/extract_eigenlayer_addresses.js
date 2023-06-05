const fs = require('fs')
const path = require('path');

async function main() {
    const ELOut = await fs.readFileSync(path.join(__dirname,"../lib/eigenlayer-contracts/script/output/M1_deployment_data.json"),"utf-8");
    const json = await JSON.parse(ELOut);
    const strats = json.addresses.strategies;
    const WETHAddr = strats["Wrapped Ether"];
    const res = {};
    res.WETH = WETHAddr;
    res.strategyManager = "0x3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c";
    await fs.writeFileSync(path.join(__dirname,"output/eigenlayer.json"),JSON.stringify(res, null, 2));
}

main();
