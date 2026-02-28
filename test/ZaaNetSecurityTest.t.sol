// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../contracts/ZaaNetAdminV1.sol";
import "../contracts/ZaaNetStorageV1.sol";
import "../contracts/TestUSDT.sol";
import "../contracts/ZaaNetPaymentV1.sol";
import "../contracts/ZaaNetNetworkV1.sol";
import "../contracts/interface/IZaaNetAdmin.sol";
import "../contracts/interface/IZaaNetStorage.sol";
import "../contracts/interface/IZaaNetPayment.sol";
import "../contracts/interface/IZaaNetNetwork.sol";

// Minimal interfaces to avoid importing conflicting contracts
interface IPayment {
    function processPayment(
        uint256 _contractId,
        uint256 _grossAmount,
        bytes32 _voucherId
    ) external;

    function processBatchPayments(BatchPayment[] calldata payments) external;

    function withdrawToken(address _to, uint256 _amount) external;

    function rescueERC20(address _erc20, address _to, uint256 _amount) external;

    function addTokenToWhitelist(address _token) external;

    function removeTokenFromWhitelist(address _token) external;

    function isTokenWhitelisted(address _token) external view returns (bool);

    function getWhitelistedTokens() external view returns (address[] memory);

    struct BatchPayment {
        uint256 contractId;
        uint256 grossAmount;
        bytes32 voucherId;
    }
}

interface INetwork {
    function registerNetwork(
        uint256 _pricePerSession,
        string memory _mongoDataId,
        bool _isActive
    ) external;

    function updateNetwork(
        uint256 _networkId,
        uint256 _pricePerSession,
        bool _isActive
    ) external;

    function deactivateNetwork(uint256 _networkId) external;
}

/**
 * @title ZaaNetSecurityTest
 * @notice Comprehensive security test suite
 */
contract ZaaNetSecurityTest is Test {
    ZaaNetAdminV1 public admin;
    ZaaNetStorageV1 public storageContract;
    ZaaNetPaymentV1 public payment;
    ZaaNetNetworkV1 public network;
    TestUSDT public usdt;

    address public owner = address(1);
    address public treasury = address(2);
    address public paymentWallet = address(3);
    address public attacker = address(4);
    address public host = address(5);

    uint256 constant INITIAL_BALANCE = 1000000 * 10 ** 6;
    uint256 constant HOSTING_FEE = 5 * 10 ** 6;
    uint256 constant PLATFORM_FEE = 5;

    function setUp() public {
        vm.startPrank(owner);
        usdt = new TestUSDT();
        storageContract = new ZaaNetStorageV1();
        storageContract.initialize();
        admin = new ZaaNetAdminV1();
        admin.initialize(
            address(storageContract),
            treasury,
            paymentWallet,
            5, // platform fee percent
            5000000 // hosting fee
        );
        payment = new ZaaNetPaymentV1();
        payment.initialize(
            address(usdt),
            address(storageContract),
            address(admin)
        );
        network = new ZaaNetNetworkV1();
        network.initialize(
            address(storageContract),
            address(admin),
            address(usdt)
        );
        storageContract.setAllowedCaller(address(admin), true);
        storageContract.setAllowedCaller(address(payment), true);
        storageContract.setAllowedCaller(address(network), true);

        // Deploy network and payment using create2 or directly
        // For now, we'll use minimal testing approach
        vm.stopPrank();
    }

    function test_AttemptUnauthorizedFeeChange() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        admin.setPlatformFee(10);
        vm.expectRevert();
        admin.emergencySetPlatformFee(10);
        vm.stopPrank();
        console.log("[PASS] Fee change access control working");
    }

    function test_AttemptZeroAddressTreasury() public {
        vm.startPrank(owner);
        vm.expectRevert();
        admin.setTreasuryAddress(address(0));
        vm.stopPrank();
        console.log("[PASS] Zero address validation working");
    }

    function test_PlatformFeeWithinBounds() public {
        uint256 fee = admin.platformFeePercent();
        assertLe(fee, 20);
        assertGe(fee, 1);
        console.log("[PASS] Platform fee within bounds");
    }

    function test_FeeCalculationCorrect() public {
        uint256 amount = 100 * 10 ** 6;
        uint256 fee = admin.calculatePlatformFee(amount);
        uint256 expectedFee = (amount * PLATFORM_FEE) / 100;
        assertEq(fee, expectedFee);
        console.log("[PASS] Fee calculation correct");
    }
}
