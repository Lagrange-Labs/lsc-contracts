const operators = require("./operators.json");

const x = {};
operators.forEach((op) => {
    x[op.chain_name] = [];
    op.operators.forEach((addr, index) => {
        x[op.chain_name].push({
            operator: addr,
            bls_pub_key: op.bls_pub_keys[index],
            chain_id: op.chain_id
    });
});
});

console.log(JSON.stringify(x, null, 4));