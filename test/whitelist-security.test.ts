import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

describe("ZaaNet Whitelist Security Tests", function () {
    let admin: any;
    let storage: any;
    let payment: any;
    let network: any;
    let usdt: any;
    let owner: any;
    let user1: any;

    const USDT_DECIMALS = 6;
    const INITIAL_MINT = ethers.parseUnits("1000000", USDT_DECIMALS);

    beforeEach(async function () {
        [owner, user1] = await ethers.getSigners();

        // Deploy mock USDT
        const TestUSDT = await ethers.getContractFactory("TestUSDT");
        usdt = await TestUSDT.deploy();
        const usdtAddress = await usdt.getAddress();
        await usdt.mint(owner.address, INITIAL_MINT);
        await usdt.mint(user1.address, INITIAL_MINT);

        // Deploy Storage first (no args)
        const Storage = await ethers.getContractFactory("ZaaNetStorageV1");
        storage = await upgrades.deployProxy(Storage, [], { initializer: "initialize" });
        const storageAddress = await storage.getAddress();

        // Deploy Admin (5 args) - hostingFee = 0 to avoid setting it later
        const Admin = await ethers.getContractFactory("ZaaNetAdminV1");
        admin = await upgrades.deployProxy(Admin, [
            ethers.ZeroAddress, // storageContract
            owner.address,      // treasuryAddress
            owner.address,      // paymentAddress
            10,                 // platformFeePercent (10%)
            0                   // hostingFee (already 0)
        ], { initializer: "initialize" });
        const adminAddress = await admin.getAddress();

        // Deploy Payment (3 args) - USDC for testing additional whitelist
        const Payment = await ethers.getContractFactory("ZaaNetPaymentV1");
        payment = await upgrades.deployProxy(Payment, [
            usdtAddress,
            storageAddress,
            adminAddress
        ], { initializer: "initialize" });

        // Deploy Network (3 args)
        const Network = await ethers.getContractFactory("ZaaNetNetworkV1");
        network = await upgrades.deployProxy(Network, [
            storageAddress,
            adminAddress,
            usdtAddress
        ], { initializer: "initialize" });

        // Set up allowed callers in storage
        const paymentAddress = await payment.getAddress();
        const networkAddress = await network.getAddress();
        await storage.setAllowedCaller(paymentAddress, true);
        await storage.setAllowedCaller(networkAddress, true);
        await storage.setAllowedCaller(adminAddress, true);

        // Approve tokens
        await usdt.approve(paymentAddress, ethers.MaxUint256);
        await usdt.approve(networkAddress, ethers.MaxUint256);
        await usdt.connect(user1).approve(networkAddress, ethers.MaxUint256);
    });

    describe("Token Whitelist Security", function () {
        it("should have token whitelisted by default", async function () {
            const usdtAddress = await usdt.getAddress();
            // USDT is already whitelisted in initialize
            expect(await payment.isTokenWhitelisted(usdtAddress)).to.be.true;
        });

        it("should prevent adding invalid token address", async function () {
            await expect(
                payment.addTokenToWhitelist(ethers.ZeroAddress)
            ).to.be.revertedWith("Invalid token address");
        });

        it("should prevent removing primary payment token", async function () {
            const usdtAddress = await usdt.getAddress();
            await expect(
                payment.removeTokenFromWhitelist(usdtAddress)
            ).to.be.revertedWith("Cannot remove primary payment token");
        });

        it("should get whitelisted tokens", async function () {
            const usdtAddress = await usdt.getAddress();
            const tokens = await payment.getWhitelistedTokens();
            expect(tokens).to.include(usdtAddress);
        });
    });

    describe("Daily Withdrawal Limit", function () {
        it("should set daily withdrawal limit with upper bound", async function () {
            await payment.setDailyWithdrawalLimit(ethers.parseUnits("500000", USDT_DECIMALS));
            expect(await payment.dailyWithdrawalLimit()).to.equal(ethers.parseUnits("500000", USDT_DECIMALS));
        });

        it("should reject limit exceeding maximum", async function () {
            await expect(
                payment.setDailyWithdrawalLimit(ethers.parseUnits("2000000", USDT_DECIMALS))
            ).to.be.revertedWith("Limit exceeds maximum");
        });

        it("should reject zero limit", async function () {
            await expect(
                payment.setDailyWithdrawalLimit(0)
            ).to.be.revertedWith("Invalid limit");
        });
    });

    describe("Network Limit per Host", function () {
        it("should check host network limit", async function () {
            const limit = await storage.hasReachedNetworkLimit(owner.address);
            expect(limit).to.be.false;
        });

        it("should track host network count", async function () {
            const count = await storage.getHostNetworkCount(owner.address);
            expect(count).to.equal(0);
        });

        it("should have MAX_NETWORKS_PER_HOST constant", async function () {
            const maxNetworks = await storage.MAX_NETWORKS_PER_HOST();
            expect(maxNetworks).to.be.gt(0);
        });
    });

    describe("Gas Limit Protection", function () {
        it("should have MAX_BATCH_SIZE constant", async function () {
            const maxBatch = await network.MAX_BATCH_SIZE();
            expect(maxBatch).to.be.lt(100);
        });

        it("should have MAX_NETWORKS_PER_HOST in network", async function () {
            const maxNetworks = await network.MAX_NETWORKS_PER_HOST();
            expect(maxNetworks).to.be.gt(0);
        });
    });
});
