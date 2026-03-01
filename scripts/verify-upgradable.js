// scripts/verify-upgradable.js
// This script verifies all upgradable contract implementations on Arbitrum One
// Usage: node scripts/verify-upgradable.js

const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

// List your upgradable contract names here
const contracts = [
  "ZaaNetAdminV1",
  "ZaaNetNetworkV1",
  "ZaaNetPaymentV1",
  "ZaaNetStorageV1",
];

// Path to deployment info (update if you save addresses elsewhere)
const deploymentsPath = path.join(
  __dirname,
  "./deployments/arbitrumOne-upgradable.json",
);

async function main() {
  let deployments;
  try {
    deployments = JSON.parse(fs.readFileSync(deploymentsPath));
  } catch (e) {
    console.error("Could not read deployment info at", deploymentsPath);
    process.exit(1);
  }

  for (const contract of contracts) {
    const implAddress = deployments[contract]?.implementation;
    if (!implAddress) {
      console.warn(`No implementation address found for ${contract}`);
      continue;
    }
    try {
      console.log(`Verifying ${contract} at ${implAddress}...`);
      await hre.run("verify:verify", {
        address: implAddress,
        constructorArguments: [], // update if your implementation has constructor args
      });
      console.log(`Verified: ${contract}`);
    } catch (err) {
      console.error(`Error verifying ${contract}:`, err.message);
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
