# Mainnet Deployment Runbook — Arbitrum One

This checklist ensures all security fixes and post-deploy steps are in place before and after deploying ZaaNet contracts to **Arbitrum One**.

---

## Network: Arbitrum One

| Item | Value |
|------|--------|
| **Chain ID** | 42161 |
| **RPC** | Configure in Hardhat (e.g. `https://arb1.arbitrum.io/rpc` or your provider) |
| **Explorer** | https://arbiscan.io |
| **USDT** | Use Arbitrum One USDT contract address (e.g. canonical bridged USDT). Set via `USDT_ADDRESS` in `.env`. |

Ensure `hardhat.config` has a network entry for Arbitrum One (e.g. `arbitrumOne` or `arbitrum-one`) with the correct chainId and url.

---

## Pre-deploy checklist

- [ ] **Tests pass:** Run `forge test` — all 64 tests must pass.
- [ ] **Critical fix applied:** `ZaaNetStorage.setNetwork()` has the `nonReentrant` modifier (see README_SECURITY_TESTS.md).
- [ ] **Environment:** Set Arbitrum One RPC and deployer key in `.env`. Do not commit secrets.
- [ ] **Config for Arbitrum One:** In deployment module or `.env`:
  - `USDT_ADDRESS` — USDT token address on Arbitrum One.
  - `TREASURY_ADDRESS` — treasury wallet that receives fees.
  - `PAYMENT_ADDRESS` — wallet allowed to call `processPayment` / `processBatchPayments`.
  - `MULTISIG_OWNER_ADDRESS` (optional) — if set, ownership of all contracts is transferred here after deployment.
- [ ] **Fees:** Confirm `platformFeePercent` and `hostingFee` in the deployment module match the product design (e.g. 1–20% platform fee, hosting fee in token units with correct decimals).

---

## Deployment

Deploy using Hardhat Ignition (see `ignition/modules/ZaaNetDeploymentModule.ts`):

```bash
# From repo root; use the network name that points to Arbitrum One in hardhat.config
npx hardhat ignition deploy ignition/modules/ZaaNetDeploymentModule.ts --network arbitrumOne
```

This project’s `hardhat.config.ts` already defines `arbitrumOne` (chainId 42161) with Alchemy RPC and Etherscan/Arbiscan verification; ensure `ALCHEMY_API_KEY` and `PRIVATE_KEY` are set in `.env`.

Deployment order is: **ZaaNetStorage → ZaaNetAdmin → ZaaNetNetwork → ZaaNetPayment**. The module then runs the required `setAllowedCaller` steps (see below).

---

## Post-deploy (included in deployment module)

The Ignition module already performs these **required** steps; verify they succeeded:

1. **Storage allowed callers (must be set or contracts will not work):**
   - `storageContract.setAllowedCaller(zaaNetNetwork, true)`
   - `storageContract.setAllowedCaller(zaaNetPayment, true)`
   - `storageContract.setAllowedCaller(zaaNetAdmin, true)` — required for emergency deactivation and any admin-triggered storage calls.

2. **Optional:** If `MULTISIG_OWNER_ADDRESS` is set, ownership of Storage, Admin, Network, and Payment is transferred to that address after the above.

---

## Post-deploy verification (manual)

- [ ] **Allowed callers:** On Storage, confirm `allowedCallers(networkAddress)`, `allowedCallers(paymentAddress)`, and `allowedCallers(adminAddress)` are `true`.
- [ ] **Admin config:** Confirm `admin.treasuryAddress()`, `admin.paymentAddress()`, `admin.platformFeePercent()`, and `admin.hostingFee()` match deployment config.
- [ ] **Explorer:** Verify contract source on [Arbiscan](https://arbiscan.io) if desired.
- [ ] **Backend / frontend:** Update server and client config with the new contract addresses for **Arbitrum One** (chain ID 42161).

---

## Security status (as of runbook date)

- **Critical:** `nonReentrant` on `setNetwork` — **fixed.**
- **Zero-address:** `setAllowedCaller` rejects `address(0)` — **fixed.**
- **Post-deploy:** Admin must be an allowed caller on Storage — **handled in deployment module.**

See `test/README_SECURITY_TESTS.md` for full audit findings and accepted limitations.
