import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const testUSDTModule = buildModule("testUSDTModule", (m) => {
  // Use m.contract() to deploy, not m.call()
  const testUSDT = m.contract("TestUSDT", []);

  return {
    testUSDT
  };
});

export default testUSDTModule;