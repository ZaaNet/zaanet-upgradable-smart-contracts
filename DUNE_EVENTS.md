# ZaaNet Events Catalog for Dune Analytics

> Comprehensive event documentation for building Dune dashboards and queries.
> Last Updated: February 2026

---

## Event Signatures Reference

### ZaaNetPayment Events

#### PaymentProcessed
```solidity
event PaymentProcessed(
    bytes32 indexed voucherId,
    uint256 indexed contractId,
    address indexed host,
    address payer,
    uint256 grossAmount,
    uint256 platformFee,
    uint256 hostAmount,
    uint256 timestamp
);
```
**Signature:** `PaymentProcessed(bytes32,uint256,address,address,uint256,uint256,uint256,uint256)`
**Use Case:** Track individual voucher redemptions, calculate host payouts, payment volume
**Indexed:** voucherId, contractId, host

#### BatchPaymentProcessed
```solidity
event BatchPaymentProcessed(
    uint256 batchSize,
    uint256 totalAmount,
    uint256 totalPlatformFee
);
```
**Signature:** `BatchPaymentProcessed(uint256,uint256,uint256)`
**Use Case:** Track batch processing efficiency, total volume from batches

#### HostVouchersRegistered
```solidity
event HostVouchersRegistered(
    address indexed host,
    uint8 indexed tier,
    uint256 voucherCount,
    uint256 totalFee,
    uint256 timestamp
);
```
**Signature:** `HostVouchersRegistered(address,uint8,uint256,uint256,uint256)`
**Use Case:** Track voucher registration fees, host voucher inventory growth

#### DailyLimitExceeded
```solidity
event DailyLimitExceeded(
    address indexed treasury,
    uint256 attemptedAmount,
    uint256 dailyLimit,
    uint256 alreadyWithdrawn
);
```
**Signature:** `DailyLimitExceeded(address,uint256,uint256,uint256)`
**Use Case:** Monitor daily limit usage, detect unusual patterns

---

### ZaaNetNetwork Events

#### NetworkRegistered
```solidity
event NetworkRegistered(
    uint256 indexed networkId,
    address indexed hostAddress,
    string mongoDataId,
    uint256 pricePerSession,
    bool isActive,
    uint256 hostingFeePaid,
    uint256 timestamp
);
```
**Signature:** `NetworkRegistered(uint256,address,string,uint256,bool,uint256,uint256)`
**Use Case:** Track new network registrations, network growth over time

#### HostingFeePaid
```solidity
event HostingFeePaid(
    address indexed host,
    uint256 amount,
    uint256 timestamp
);
```
**Signature:** `HostingFeePaid(address,uint256,uint256)`
**Use Case:** Track hosting fee revenue, network registration costs

#### NetworkUpdated
```solidity
event NetworkUpdated(
    uint256 indexed networkId,
    address indexed hostAddress,
    uint256 pricePerSession,
    string mongoDataId,
    bool isActive
);
```
**Signature:** `NetworkUpdated(uint256,address,uint256,string,bool)`
**Use Case:** Track network modifications, price changes

#### NetworkPriceUpdated
```solidity
event NetworkPriceUpdated(
    uint256 indexed networkId,
    uint256 oldPrice,
    uint256 newPrice
);
```
**Signature:** `NetworkPriceUpdated(uint256,uint256,uint256)`
**Use Case:** Track pricing dynamics, host strategy changes

#### NetworkStatusChanged
```solidity
event NetworkStatusChanged(
    uint256 indexed networkId,
    bool oldStatus,
    bool newStatus
);
```
**Signature:** `NetworkStatusChanged(uint256,bool,bool)`
**Use Case:** Track active/inactive networks, network health

#### HostAdded
```solidity
event HostAdded(address indexed host);
```
**Signature:** `HostAdded(address)`
**Use Case:** Track new host onboarding

---

### ZaaNetStorage Events

#### NetworkStored
```solidity
event NetworkStored(
    uint256 indexed id,
    address indexed hostAddress,
    uint256 pricePerSession
);
```
**Signature:** `NetworkStored(uint256,address,uint256)`
**Use Case:** Mirror of NetworkRegistered for storage layer

#### HostEarningsUpdated
```solidity
event HostEarningsUpdated(address indexed hostAddress, uint256 totalEarned);
```
**Signature:** `HostEarningsUpdated(address,uint256)`
**Use Case:** Track cumulative host earnings, calculate payouts

#### ClientVoucherFeeEarningsUpdated
```solidity
event ClientVoucherFeeEarningsUpdated(uint256 totalEarned);
```
**Signature:** `ClientVoucherFeeEarningsUpdated(uint256)`
**Use Case:** Track platform fees from voucher redemptions

#### HostVoucherFeeEarningsUpdated
```solidity
event HostVoucherFeeEarningsUpdated(uint256 totalEarned);
```
**Signature:** `HostVoucherFeeEarningsUpdated(uint256)`
**Use Case:** Track platform fees from host voucher registration

#### AllowedCallerUpdated
```solidity
event AllowedCallerUpdated(address indexed caller, bool status);
```
**Signature:** `AllowedCallerUpdated(address,bool)`
**Use Case:** Track authorized callers changes (security)

---

### ZaaNetAdmin Events

#### PlatformFeeUpdated
```solidity
event PlatformFeeUpdated(
    uint256 indexed oldFee,
    uint256 indexed newFee,
    address indexed changedBy
);
```
**Signature:** `PlatformFeeUpdated(uint256,uint256,address)`
**Use Case:** Track fee changes, governance decisions

#### TreasuryUpdated
```solidity
event TreasuryUpdated(
    address indexed oldTreasury,
    address indexed newTreasury,
    address indexed changedBy
);
```
**Signature:** `TreasuryUpdated(address,address,address)`
**Use Case:** Track treasury address changes (security)

#### HostingFeeUpdated
```solidity
event HostingFeeUpdated(
    uint256 indexed oldFee,
    uint256 indexed newFee,
    address indexed changedBy
);
```
**Signature:** `HostingFeeUpdated(uint256,uint256,address)`
**Use Case:** Track hosting fee changes

#### HostVoucherFeeTierUpdated
```solidity
event HostVoucherFeeTierUpdated(
    uint8 indexed tier,
    uint256 indexed newFee,
    address indexed changedBy
);
```
**Signature:** `HostVoucherFeeTierUpdated(uint8,uint256,address)`
**Use Case:** Track voucher fee tier changes

#### PaymentAddressUpdated
```solidity
event PaymentAddressUpdated(
    address indexed oldAddress,
    address indexed newAddress,
    address indexed changedBy
);
```
**Signature:** `PaymentAddressUpdated(address,address,address)`
**Use Case:** Track payment processor changes

#### AdminPaused
```solidity
event AdminPaused(address indexed triggeredBy);
```
**Signature:** `AdminPaused(address)`
**Use Case:** Track pause events (security)

#### AdminUnpaused
```solidity
event AdminUnpaused(address indexed triggeredBy);
```
**Signature:** `AdminUnpaused(address)`
**Use Case:** Track unpause events

#### EmergencyModeToggled
```solidity
event EmergencyModeToggled(bool enabled, address indexed triggeredBy);
```
**Signature:** `EmergencyModeToggled(bool,address)`
**Use Case:** Track emergency mode usage (critical for audits)

#### EmergencyOperatorUpdated
```solidity
event EmergencyOperatorUpdated(
    address indexed operator,
    bool status,
    address indexed updatedBy
);
```
**Signature:** `EmergencyOperatorUpdated(address,bool,address)`
**Use Case:** Track emergency operator changes

#### ContractsInitialized
```solidity
event ContractsInitialized(address indexed storageContract, uint256 timestamp);
```
**Signature:** `ContractsInitialized(address,uint256)`
**Use Case:** Track contract deployment/init

---

## Indexed Fields Reference

| Event | Indexed Fields | Query Use |
|-------|---------------|-----------|
| PaymentProcessed | voucherId, contractId, host | Filter by voucher, network, host |
| NetworkRegistered | networkId, hostAddress | Filter by network, host |
| HostEarningsUpdated | hostAddress | Filter by host |
| EmergencyModeToggled | triggeredBy | Filter by operator |
| TreasuryUpdated | oldTreasury, newTreasury, changedBy | Audit trail |

---

## Common Query Patterns

### Payment Volume by Day
```sql
SELECT 
    date_trunc('day', evt_block_time) as day,
    SUM(grossAmount) / 1e6 as total_volume_usdt,
    COUNT(*) as transaction_count
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 1 DESC
```

### Active Networks
```sql
SELECT 
    COUNT(DISTINCT contractId) as active_networks
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time > NOW() - INTERVAL '30 days'
```

### Top Hosts by Earnings
```solidity
SELECT 
    host,
    SUM(hostAmount) / 1e6 as total_earnings_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10
```

---

## Contract Addresses (Mainnet)

> ⚠️ UPDATE WITH ACTUAL DEPLOYED ADDRESSES

| Contract | Address | Notes |
|----------|---------|-------|
| ZaaNetStorage | `0x...` | Update on deployment |
| ZaaNetAdmin | `0x...` | Update on deployment |
| ZaaNetNetwork | `0x...` | Update on deployment |
| ZaaNetPayment | `0x...` | Update on deployment |
| USDT | `0xFd086b7CD5C755DDc49674BD709DaB5C2dEC0D3` | Arbitrum USDT |

---

## Dune Import Format

### ABI JSON Structure
```json
{
  "name": "ZaaNetPayment",
  "address": "0x...",
  "abi": [...]
}
```

### Event Decoding
Dune automatically decodes events when you add the contract. Use event names as shown in the Event Signatures section above.

---

*For questions or updates, contact the ZaaNet team.*
