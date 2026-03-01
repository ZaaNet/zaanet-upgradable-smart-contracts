import { ethers, upgrades } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
    // Configuration - Update these addresses as needed per chain. Use .env for token/multisig.
    const mainnetUSDTAddress = process.env.USDT_ADDRESS || "0xFd086bC7CD5C481DCC9C85ebE478A1C0Bd69E843"; // Default to Arbitrum USDT
    const treasuryAddress = process.env.TREASURY_ADDRESS || "0xYourTreasuryAddress";
    const paymentAddress = process.env.PAYMENT_ADDRESS || "0xYourPaymentAddress";
    const platformFeePercent = 10; // 10% platform fee
    const hostingFee = 2n * 10n ** 6n; // 2 USDT (6 decimals)

    // Set in .env to transfer ownership to a multisig after deployment. If not set, deployer will remain owner.
    const multisigOwnerAddress = process.env.MULTISIG_OWNER_ADDRESS || "";

    console.log("🚀 Starting ZaaNet UPGRADABLE deployment...");
    console.log(`📋 Configuration:`);
    console.log(`   - Mainnet USDT: ${mainnetUSDTAddress}`);
    console.log(`   - Treasury: ${treasuryAddress}`);
    console.log(`   - Payment: ${paymentAddress}`);
    console.log(`   - Platform Fee: ${platformFeePercent}%`);
    console.log(`   - Hosting Fee: ${Number(hostingFee) / 10 ** 6} USDT`);
    if (multisigOwnerAddress) {
        console.log(`   - Multisig owner (post-deploy transfer): ${multisigOwnerAddress}`);
    } else {
        console.log(`   - Multisig owner: not set (deployer will remain owner)`);
    }

    // Get deployer account
    const [deployer] = await ethers.getSigners();
    console.log(`\n👤 Deploying with account: ${deployer.address}`);
    console.log(`   Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);

    // 1. Deploy ZaaNetStorageV1 with upgradeable proxy
    console.log(`\n📦 Step 1: Deploying ZaaNetStorageV1...`);
    const ZaaNetStorageV1 = await ethers.getContractFactory("ZaaNetStorageV1");
    const zaaNetStorageProxy = await upgrades.deployProxy(
        ZaaNetStorageV1,
        [], // No constructor arguments, uses initialize()
        {
            initializer: "initialize",
            kind: "uups",
        }
    );
    await zaaNetStorageProxy.waitForDeployment();
    const zaaNetStorage = await zaaNetStorageProxy.getAddress();
    console.log(`   ✅ ZaaNetStorageV1 proxy deployed at: ${zaaNetStorage}`);

    // Get implementation address
    const storageImplementation = await upgrades.erc1967.getImplementationAddress(zaaNetStorage);
    console.log(`   📍 Implementation: ${storageImplementation}`);

    // 2. Deploy ZaaNetAdminV1 with upgradeable proxy
    console.log(`\n📦 Step 2: Deploying ZaaNetAdminV1...`);
    const ZaaNetAdminV1 = await ethers.getContractFactory("ZaaNetAdminV1");
    const zaaNetAdminProxy = await upgrades.deployProxy(
        ZaaNetAdminV1,
        [
            zaaNetStorage,    // _storageContract
            treasuryAddress,  // _treasuryAddress
            paymentAddress,   // _paymentAddress
            platformFeePercent, // _platformFeePercent
            hostingFee,       // _hostingFee
        ],
        {
            initializer: "initialize",
            kind: "uups",
        }
    );
    await zaaNetAdminProxy.waitForDeployment();
    const zaaNetAdmin = await zaaNetAdminProxy.getAddress();
    console.log(`   ✅ ZaaNetAdminV1 proxy deployed at: ${zaaNetAdmin}`);

    const adminImplementation = await upgrades.erc1967.getImplementationAddress(zaaNetAdmin);
    console.log(`   📍 Implementation: ${adminImplementation}`);

    // 3. Deploy ZaaNetNetworkV1 with upgradeable proxy
    console.log(`\n📦 Step 3: Deploying ZaaNetNetworkV1...`);
    const ZaaNetNetworkV1 = await ethers.getContractFactory("ZaaNetNetworkV1");
    const zaaNetNetworkProxy = await upgrades.deployProxy(
        ZaaNetNetworkV1,
        [
            zaaNetStorage, // _storageContract
            zaaNetAdmin,   // _adminContract
            mainnetUSDTAddress, // _usdt
        ],
        {
            initializer: "initialize",
            kind: "uups",
        }
    );
    await zaaNetNetworkProxy.waitForDeployment();
    const zaaNetNetwork = await zaaNetNetworkProxy.getAddress();
    console.log(`   ✅ ZaaNetNetworkV1 proxy deployed at: ${zaaNetNetwork}`);

    const networkImplementation = await upgrades.erc1967.getImplementationAddress(zaaNetNetwork);
    console.log(`   📍 Implementation: ${networkImplementation}`);

    // 4. Deploy ZaaNetPaymentV1 with upgradeable proxy
    console.log(`\n📦 Step 4: Deploying ZaaNetPaymentV1...`);
    const ZaaNetPaymentV1 = await ethers.getContractFactory("ZaaNetPaymentV1");
    const zaaNetPaymentProxy = await upgrades.deployProxy(
        ZaaNetPaymentV1,
        [
            mainnetUSDTAddress, // _usdt
            zaaNetStorage,      // _storageContract
            zaaNetAdmin,        // _adminContract
        ],
        {
            initializer: "initialize",
            kind: "uups",
        }
    );
    await zaaNetPaymentProxy.waitForDeployment();
    const zaaNetPayment = await zaaNetPaymentProxy.getAddress();
    console.log(`   ✅ ZaaNetPaymentV1 proxy deployed at: ${zaaNetPayment}`);

    const paymentImplementation = await upgrades.erc1967.getImplementationAddress(zaaNetPayment);
    console.log(`   📍 Implementation: ${paymentImplementation}`);

    // 5. Access control - CRITICAL for functionality
    console.log(`\n🔐 Step 5: Setting up access control...`);

    const storageContract = await ethers.getContractAt("ZaaNetStorageV1", zaaNetStorage);

    const tx1 = await storageContract.setAllowedCaller(zaaNetNetwork, true);
    await tx1.wait();
    console.log(`   ✅ Authorized Network as storage caller`);

    const tx2 = await storageContract.setAllowedCaller(zaaNetPayment, true);
    await tx2.wait();
    console.log(`   ✅ Authorized Payment as storage caller`);

    const tx3 = await storageContract.setAllowedCaller(zaaNetAdmin, true);
    await tx3.wait();
    console.log(`   ✅ Authorized Admin as storage caller`);

    // Transfer ownership to multisig if configured
    if (multisigOwnerAddress && multisigOwnerAddress !== "0xYourTreasuryAddress") {
        console.log(`\n🔑 Step 6: Transferring ownership to multisig...`);

        const adminContract = await ethers.getContractAt("ZaaNetAdminV1", zaaNetAdmin);
        const networkContract = await ethers.getContractAt("ZaaNetNetworkV1", zaaNetNetwork);
        const paymentContract = await ethers.getContractAt("ZaaNetPaymentV1", zaaNetPayment);

        const tx4 = await storageContract.transferOwnership(multisigOwnerAddress);
        await tx4.wait();
        console.log(`   ✅ Transferred Storage ownership to multisig`);

        const tx5 = await adminContract.transferOwnership(multisigOwnerAddress);
        await tx5.wait();
        console.log(`   ✅ Transferred Admin ownership to multisig`);

        const tx6 = await networkContract.transferOwnership(multisigOwnerAddress);
        await tx6.wait();
        console.log(`   ✅ Transferred Network ownership to multisig`);

        const tx7 = await paymentContract.transferOwnership(multisigOwnerAddress);
        await tx7.wait();
        console.log(`   ✅ Transferred Payment ownership to multisig`);
    }

    // Summary
    console.log(`\n🎉 ZaaNet UPGRADABLE deployment completed!`);
    console.log(`\n📝 Deployment Summary:`);
    console.log(`   ZaaNetStorageV1: ${zaaNetStorage}`);
    console.log(`   ZaaNetAdminV1: ${zaaNetAdmin}`);
    console.log(`   ZaaNetNetworkV1: ${zaaNetNetwork}`);
    console.log(`   ZaaNetPaymentV1: ${zaaNetPayment}`);
    console.log(`\n💾 Save these addresses for future upgrades!`);

    // After all deployments and before summary:
const outputPath = path.join(__dirname, "../deployments/arbitrumOne-upgradable.json");
const deploymentData = {
  ZaaNetStorageV1: {
    proxy: zaaNetStorage,
    implementation: storageImplementation,
  },
  ZaaNetAdminV1: {
    proxy: zaaNetAdmin,
    implementation: adminImplementation,
  },
  ZaaNetNetworkV1: {
    proxy: zaaNetNetwork,
    implementation: networkImplementation,
  },
  ZaaNetPaymentV1: {
    proxy: zaaNetPayment,
    implementation: paymentImplementation,
  },
};
fs.writeFileSync(outputPath, JSON.stringify(deploymentData, null, 2));
console.log(`\n💾 Deployment info saved to ${outputPath}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
