import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ZaaNetDeploymentModule = buildModule("ZaaNetDeploymentModule", (m) => {
  // Configuration - Update these addresses as needed per chain. Use .env for token/multisig.
  const mainnetUSDTAddress = process.env.USDT_ADDRESS!;
  const treasuryAddress = process.env.TREASURY_ADDRESS!;
  const paymentAddress = process.env.PAYMENT_ADDRESS!;
  const platformFeePercent = 10; // 10% platform fee
  const hostingFee = 2 * (10 ** 6); // 2 USDT (6 decimals)

  // Set in .env to transfer ownership to a multisig after deployment. If not set, deployer will remain owner.
  // Deployer (PRIVATE_KEY) pays gas and is initial owner; then ownership is transferred here.
  const multisigOwnerAddress = process.env.MULTISIG_OWNER_ADDRESS || "";

  console.log("🚀 Starting ZaaNet deployment with Hardhat Ignition...");
  console.log(`📋 Configuration:`);
  console.log(`   - Mainnet USDT: ${mainnetUSDTAddress}`);
  console.log(`   - Treasury: ${treasuryAddress}`);
  console.log(`   - Payment: ${paymentAddress}`);
  console.log(`   - Platform Fee: ${platformFeePercent}%`);
  console.log(`   - Hosting Fee: ${hostingFee / (10 ** 6)} USDT`);
  if (multisigOwnerAddress) {
    console.log(`   - Multisig owner (post-deploy transfer): ${multisigOwnerAddress}`);
  } else {
    console.log(`   - Multisig owner: not set (deployer will remain owner)`);
  }

  // 1. Deploy ZaaNetStorage first (no dependencies)
  const zaaNetStorage = m.contract("ZaaNetStorage", [], {
    id: "ZaaNetStorage",
  });

  // 2. Deploy ZaaNetAdmin (depends on storage)
  const zaaNetAdmin = m.contract("ZaaNetAdmin", [
    zaaNetStorage,
    treasuryAddress,
    paymentAddress,
    platformFeePercent,
    hostingFee
  ], {
    id: "ZaaNetAdmin",
  });

  // 3. Deploy ZaaNetNetwork (depends on storage and admin)
  const zaaNetNetwork = m.contract("ZaaNetNetwork", [
    zaaNetStorage,
    zaaNetAdmin,
    mainnetUSDTAddress
  ], {
    id: "ZaaNetNetwork",
  });

  // 4. Deploy ZaaNetPayment (depends on all above contracts)
  const zaaNetPayment = m.contract("ZaaNetPayment", [
    mainnetUSDTAddress,
    zaaNetStorage,
    zaaNetAdmin,
    zaaNetNetwork 
  ], {
    id: "ZaaNetPayment",
  });

  // 5. Access control - CRITICAL for functionality (must complete before any ownership transfer)
  const authorizeNetworkCaller = m.call(zaaNetStorage, "setAllowedCaller", [zaaNetNetwork, true], {
    id: "authorizeNetworkCaller",
    after: [zaaNetNetwork],
  });

  const authorizePaymentCaller = m.call(zaaNetStorage, "setAllowedCaller", [zaaNetPayment, true], {
    id: "authorizePaymentCaller",
    after: [zaaNetPayment],
  });

  const authorizeAdminCaller = m.call(zaaNetStorage, "setAllowedCaller", [zaaNetAdmin, true], {
    id: "authorizeAdminCaller",
    after: [zaaNetAdmin],
  });

  // Transfer ownership to multisig only after ALL setAllowedCaller calls succeed (deployer must still own Storage for those)
  if (multisigOwnerAddress) {
    const afterAllAuth = [authorizeNetworkCaller, authorizePaymentCaller, authorizeAdminCaller];
    m.call(zaaNetStorage, "transferOwnership", [multisigOwnerAddress], {
      id: "transferStorageOwnership",
      after: afterAllAuth,
    });
    m.call(zaaNetAdmin, "transferOwnership", [multisigOwnerAddress], {
      id: "transferAdminOwnership",
      after: afterAllAuth,
    });
    m.call(zaaNetNetwork, "transferOwnership", [multisigOwnerAddress], {
      id: "transferNetworkOwnership",
      after: afterAllAuth,
    });
    m.call(zaaNetPayment, "transferOwnership", [multisigOwnerAddress], {
      id: "transferPaymentOwnership",
      after: afterAllAuth,
    });
  }

  // Return all deployed contracts for external reference
  return {
    zaaNetStorage,
    zaaNetAdmin, 
    zaaNetNetwork,
    zaaNetPayment,
  };
});

export default ZaaNetDeploymentModule;