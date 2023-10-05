const deployedMock = require('../script/output/deployed_mock.json');
const deployedWETH = require('../script/output/deployed_weth9.json');
const fs = require('fs');

const filePath = './config/LagrangeService.json';

// Read the JSON file and parse its contents
fs.readFile(filePath, 'utf8', (err, data) => {
  if (err) {
    console.error('Error reading JSON file:', err);
    return;
  }

  try {
    // Parse the JSON data into a JavaScript object
    const jsonObject = JSON.parse(data);

    // Update the desired field in the JavaScript object

    if (jsonObject.isNative) {
      const token = jsonObject.tokens[0];
      token.token_address = deployedWETH.WETH9;
      jsonObject.tokens = [token];
    } else {
      const strategy = jsonObject.strategies[0];
      strategy.strategy_address = deployedMock.addresses.strategy;
      jsonObject.strategies = [strategy];
    }

    // Convert the JavaScript object back to a JSON string
    const updatedJsonString = JSON.stringify(jsonObject, null, 4);

    // Write the updated JSON string back to the file
    fs.writeFile(filePath, updatedJsonString, 'utf8', (err) => {
      if (err) {
        console.error('Error writing JSON file:', err);
        return;
      }

      console.log('JSON file updated successfully.');
    });
  } catch (err) {
    console.error('Error parsing JSON:', err);
  }
});
