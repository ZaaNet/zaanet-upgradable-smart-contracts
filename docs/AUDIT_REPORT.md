# ZaaNet Smart Contract Security Audit Report

**Audit Date:** February 10, 2025  
**Scope:** ZaaNetStorage, ZaaNetPayment, ZaaNetNetwork, ZaaNetAdmin  
**Solidity Version:** ^0.8.28  
**OpenZeppelin:** Access (Ownable), Pausable, ReentrancyGuard, SafeERC20, IERC20

---

## Executive Summary

The ZaaNet system is a multi-contract suite for network registration, voucher-based payments, and platform fee management. The design uses a central **ZaaNetStorage** contract as the source of truth, with **ZaaNetNetwork** (registration), **ZaaNetPayment** (payments and voucher fees), and **ZaaNetAdmin** (configuration and emergency controls) as allowed callers.

**Overall assessment:** The contracts use solid patterns (Ownable, ReentrancyGuard, Pausable, SafeERC20) and clear separation of roles. Several **medium** and **low** severity issues were identified, plus a number of improvements for safety, consistency, and maintainability. No critical reentrancy or access-control bypasses were found.

---

## 1. ZaaNetStorage.sol

### 1.1 Architecture & Role

- Holds networks, host earnings, and platform statistics.
- Only **owner** or **allowedCallers** can mutate state (network writes, earnings updates).
- Uses `ReentrancyGuard` and `onlyAllowed` on all state-changing functions.

### 1.2 Security Findings

#### 1.2.1 [LOW] Pagination assumes contiguous network IDs

**Location:** `getNetworksPaginated` (lines 117–137)

**Issue:** The function iterates `networks[i + 1]` for `i` in `[offset, end)` and does not check `networkExists[i + 1]`. If an ID in that range were ever missing (e.g. a different allowed caller used non-contiguous IDs), the returned array could contain default-initialized `Network` structs.

**Current behavior:** In practice, only `ZaaNetNetwork.registerNetwork` creates networks, and it always calls `incrementNetworkId()` then `setNetwork(networkId, ...)`, so IDs are contiguous. The risk is future use or other allowed callers.

**Recommendation:** Either:
- Only include slots where `networkExists[i + 1]` is true and return a dynamic list, or
- Document that pagination is valid only when all IDs in `1..networkIdCounter` are set and enforce that in `setNetwork` / deployment.

#### 1.2.2 [INFORMATIONAL] No pause mechanism

**Issue:** Storage has no `Pausable` or emergency pause. If a bug is found in an allowed caller, Storage can still be used by other allowed callers until they are paused or removed.

**Recommendation:** Consider adding a simple pause controlled by owner and a modifier that blocks non-view functions when paused, or document that emergency response is done by pausing Payment/Network and adjusting allowed callers.

### 1.3 Positive Aspects

- Strict access control via `onlyAllowed` and owner.
- `nonReentrant` on all functions that update earnings/counters.
- Input validation (e.g. `id > 0`, `hostAddress != address(0)`, `pricePerSession > 0`, `mongoDataId` non-empty).
- `emergencyDeactivateNetwork` for owner to disable a network without deleting it.

---

## 2. ZaaNetPayment.sol

### 2.1 Architecture & Role

- Processes single and batch voucher payments (USDT), splits platform fee and host share, updates Storage.
- Only `adminContract.paymentAddress()` can call `processPayment` and `processBatchPayments`.
- Uses daily withdrawal cap, max single payment, and voucher idempotency.

### 2.2 Security Findings

#### 2.2.1 [MEDIUM] Daily limit consumed on failed single payment

**Location:** `processPayment` uses modifier `withinDailyLimit(_grossAmount)` (lines 130–145, 175).

**Issue:** The modifier updates state **before** the function body runs:

```solidity
dailyWithdrawals[today] = newDailyTotal;  // line 143
_;  // then body runs
```

If the body reverts (e.g. “Insufficient contract balance for payment” in `_executePayment`), the transaction reverts as a whole, so in practice the daily counter is **not** permanently increased. So the “consumed on failure” concern only applies **if** the modifier were ever refactored to not revert on later failure, or if there were a code path where the modifier ran in a separate call. As written, the modifier ordering is still error-prone: the daily limit is logically “reserved” before the payment execution. If you later split checks and state updates, or add a two-step flow, the same pattern could burn daily limit on a revert in a different way.

**Recommendation:** Move the daily limit update to **after** all validations and the balance check (e.g. update `dailyWithdrawals` at the end of `_executePayment` or after a successful `_executePayment` in `processPayment`). That way the limit is only consumed on success and the intent is clear.

#### 2.2.2 [LOW] `rescueERC20` can withdraw payment token

**Location:** `rescueERC20` (lines 378–384).

**Issue:** Owner can call `rescueERC20(usdt, to, amount)` and withdraw the contract’s USDT. That can drain funds that are intended for hosts and treasury.

**Recommendation:** Disallow rescuing the payment token (e.g. `require(_erc20 != address(usdt), "Cannot rescue payment token");`) so rescue is only for accidentally sent other tokens.

#### 2.2.3 [LOW] `withdrawToken` does not update Storage withdrawal stats

**Issue:** `updateZaanetWithdrawalsAmount` exists on Storage and is in the Payment interface, but `withdrawToken` never calls it. So “total amount processed through withdrawals” in Storage does not include owner withdrawals.

**Recommendation:** If that metric is intended to include owner withdrawals, call `storageContract.updateZaanetWithdrawalsAmount(_amount)` in `withdrawToken` (and ensure Storage is not paused or that Payment handles revert). Otherwise remove or document the unused Storage method.

#### 2.2.4 [LOW] Redundant payment-address check

**Location:** `processPayment` (lines 177–178 and 210–213).

**Issue:** The same condition `msg.sender == adminContract.paymentAddress()` is enforced twice (and `paymentWallet` is only used for that second check).

**Recommendation:** Keep a single check and remove the duplicate.

#### 2.2.5 [INFORMATIONAL] Constructor does not validate `_networkContract`

**Location:** Constructor (lines 146–163).

**Issue:** If `_networkContract` is `address(0)`, later `processPayment` will call `networkContract.MIN_PRICE_PER_SESSION()` and revert. Deployment would be broken but there is no explicit check.

**Recommendation:** Add `require(_networkContract != address(0), "network zero");` for consistency and clearer deploy-time errors.

### 2.3 Positive Aspects

- `processPayment` and `processBatchPayments` are `nonReentrant` and restricted to `paymentAddress`.
- Double-processing prevented by `processedVouchers[_voucherId]`.
- Caps: `MAX_INDIVIDUAL_PAYMENT`, `MAX_FEERATE_PERCENT`, daily limit.
- Balance check before transfers in `_executePayment`.
- Batch processing validates all items and total vs daily limit before updating `dailyWithdrawals` and executing; failures revert the whole batch (atomic).
- `SafeERC20` used for all transfers.
- `registerHostVouchersAndPayFee` pulls USDT from host and sends to treasury in one flow; no custody in the contract for that path.

---

## 3. ZaaNetNetwork.sol

### 3.1 Architecture & Role

- Hosts register and update networks; hosting fee is pulled in USDT and sent to treasury.
- Reads/writes networks via Storage (must be an allowed caller).
- Uses a local `hostNetworks` mapping in addition to Storage’s `hostNetworkIds` for host->network lists.

### 3.2 Security Findings

#### 3.2.1 [LOW] `deactivateNetwork` lacks `nonReentrant`

**Location:** `deactivateNetwork` (lines 234–243).

**Issue:** `updateNetwork` and `registerNetwork` use `nonReentrant`; `deactivateNetwork` does not. It calls `storageContract.getNetwork` and `_updateNetwork` → `storageContract.setNetwork`. Storage does not call back into Network, so reentrancy risk is low.

**Recommendation:** Add `nonReentrant` to `deactivateNetwork` for consistency and defense in depth.

#### 3.2.2 [INFORMATIONAL] Duplicate host-network lists

**Issue:** `hostNetworks[host]` (Network) and `hostNetworkIds[host]` (Storage) are both updated on registration. They stay in sync as long as the only way to add is `registerNetwork`. If in the future networks could be added or removed elsewhere (e.g. migration or admin), the two could diverge.

**Recommendation:** Document the invariant and, if you ever add other code paths that change host–network association, ensure both mappings are updated or consider keeping a single source of truth (e.g. only Storage) and deriving the list from Storage in Network.

### 3.3 Positive Aspects

- Registration cooldown (`REGISTRATION_COOLDOWN`) to dampen spam.
- Price and `mongoDataId` length bounds enforced.
- Hosting fee is pulled only when `hostingFee > 0` and treasury is set; Storage’s `updateZaanetHostingFeeEarnings` is updated.
- Only the host can update or deactivate their network (enforced in `_updateNetwork`).
- Uses `SafeERC20` for `transferFrom` to treasury.

---

## 4. ZaaNetAdmin.sol

### 4.1 Architecture & Role

- Holds platform fee, hosting fee, treasury, payment address, and host voucher fee tiers.
- Emergency operators can toggle emergency mode, deactivate networks, and set fees in emergency.
- Fee and treasury change history is recorded for transparency.

### 4.2 Security Findings

#### 4.2.1 [LOW] Interface mismatch: `getCurrentFees` return values

**Location:** `IZaaNetAdmin.getCurrentFees()` (interface) vs `ZaaNetAdmin.getCurrentFees()` (implementation).

**Issue:** The interface declares three return values: `(uint256 platformFeePercentage, uint256 hostingFeeAmount, address treasury)`. The implementation returns only two: `(platformFeePercent, hostingFee)`. Any caller expecting three values will decode incorrectly or revert.

**Recommendation:** Align implementation with the interface by adding the third return value, e.g. `return (platformFeePercent, hostingFee, treasuryAddress);`.

#### 4.2.2 [INFORMATIONAL] Emergency mode does not affect Payment/Network

**Issue:** When `emergencyMode` is true, only Admin’s own setters (e.g. `setPlatformFee`, `setTreasuryAddress`) are blocked by `notInEmergencyMode`. ZaaNetPayment and ZaaNetNetwork do not read `emergencyMode`. So payments and network registration can continue while Admin is in emergency mode.

**Recommendation:** If the intended behavior is to halt payments and/or registration in emergency, have Payment and Network check `adminContract.emergencyMode()` in their main entry points and revert when true. Otherwise document that emergency mode only freezes Admin parameter changes.

#### 4.2.3 [INFORMATIONAL] Emergency fee setters allow zero

**Location:** `emergencySetPlatformFee`, `emergencySetHostingFee` (lines 255–287).

**Issue:** They only enforce `_newFeePercent <= MAX_PLATFORM_FEE` and `_newFee <= MAX_HOSTING_FEE`. They do not enforce a minimum (e.g. 0 is allowed). That may be intentional for emergency “turn off fees” but can be surprising.

**Recommendation:** Document that emergency setters may set fees to zero, or add an explicit minimum when desired.

### 4.3 Positive Aspects

- Clear separation: owner vs emergency operators; `notInEmergencyMode` on normal setters.
- Fee and treasury change history (and hosting fee history) improve transparency and debugging.
- Constructor validates treasury, payment address, and fee bounds; records initial state in history.
- Owner is set as emergency operator in the constructor.
- `getHostVoucherFeeTier` cleanly maps tier to the three fee state variables.

---

## 5. Cross-Contract & Integration

### 5.1 Dependency and Trust

- **Storage** must have Payment and Network (and any other callers) set as `allowedCallers`. If a malicious address is added, it could corrupt networks or earnings.
- **Payment** trusts `adminContract` for fee percent, treasury, payment address, and host voucher fees; and `networkContract` for `MIN_PRICE_PER_SESSION`. Use verified Admin and Network addresses.
- **Network** trusts Admin for hosting fee and treasury. Ensure Admin is the intended contract.

### 5.2 Consistency

- **IZaaNetStorage** (in `contracts/interface/`) still references `increaseZaaNetEarnings`, `getZaaNetEarnings`, `incrementSessionId`, which are not present in the current Storage implementation. Consider updating or removing these from the interface so it matches the implementation and avoids confusion.

### 5.3 Reentrancy and External Calls

- Payment: transfers go to `network.hostAddress` and `treasuryWallet`. Both could be contracts; `nonReentrant` prevents reentry into Payment.
- Network: `safeTransferFrom(msg.sender, treasuryAddress, hostingFee)` — if `msg.sender` is a contract, it could try to reenter; `nonReentrant` on `registerNetwork` prevents that.
- Storage: only allowed callers invoke it; no user-supplied addresses in the call path; `nonReentrant` on earnings/update functions is still good practice.

---

## 6. Recommendations Summary

### High priority

1. **Payment – daily limit:** Move the daily withdrawal update to after successful payment execution (e.g. in `_executePayment` or after it in `processPayment`) so the limit is only consumed on success and the code is robust to future changes.
2. **Payment – rescue:** Prevent rescuing the payment token (USDT) in `rescueERC20` to avoid accidental or intentional draining of payment funds.

### Medium / low priority

3. **Payment – withdrawToken:** Either call `storageContract.updateZaanetWithdrawalsAmount(_amount)` from `withdrawToken` or document/remove the unused Storage method.
4. **Payment – processPayment:** Remove the duplicate payment-address check and validate `_networkContract != address(0)` in the constructor.
5. **Storage – getNetworksPaginated:** Tighten or document the assumption that network IDs are contiguous; optionally filter by `networkExists`.
6. **Network – deactivateNetwork:** Add `nonReentrant` for consistency.
7. **Admin – getCurrentFees:** Return three values to match the interface (add `treasuryAddress`).

### Informational / documentation

8. Document that Admin’s emergency mode does not pause Payment/Network unless you add those checks.
9. Align `contracts/interface/IZaaNetStorage.sol` with the actual Storage API (remove or implement legacy functions).
10. Consider adding a pause or emergency freeze to Storage if you want a single place to halt all Storage writes.

---

## 7. Conclusion

The ZaaNet contracts are structured clearly, use standard OpenZeppelin patterns, and enforce access control and reentrancy guards where it matters. The main actionable issues are: (1) daily limit update ordering in single payment flow, (2) restricting `rescueERC20` from the payment token, and (3) aligning Admin’s `getCurrentFees` with its interface. Addressing these and the lower-priority items will improve robustness and consistency. No critical vulnerabilities that would allow theft of funds or bypass of access control were identified under the current design and trusted roles (owner, payment address, allowed callers).

---

*This report reflects a static review of the four contracts and their interfaces. Integration with frontends, oracles, and off-chain systems was not audited. Recommend running the test suite and deployment scripts in a fork or testnet before mainnet deployment.*
