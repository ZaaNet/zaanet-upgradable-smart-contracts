# Testing Multisig Ownership on Testnet

Use this flow to practice the full multisig workflow on testnet before mainnet. **Base Sepolia** is supported by Safe; Arbitrum Sepolia may not appear in the Safe UI. After deployment, **all owner actions are done in the Safe UI**, not in the terminal.

---

## 1. One-time setup (terminal + Safe)

### 1.1 Create a Safe on testnet

1. Go to [app.safe.global](https://app.safe.global).
2. Connect your wallet and switch to **Base Sepolia** (or another Safe-supported testnet).
3. Create a new Safe: add 2–3 signer addresses, set threshold (e.g. 2 of 3), confirm.
4. Note the **Safe address** (e.g. `0xF207aD025667Ba9671b70F66b7419eda6E69fbC4` on Base Sepolia). You’ll use it as `MULTISIG_OWNER_ADDRESS`.

### 1.2 Fund the deployer (for gas)

- The EOA that holds `PRIVATE_KEY` in `.env` needs testnet ETH on the target chain for deployment and gas.
- **Base Sepolia:** get ETH from [Base Sepolia faucet](https://www.coinbase.com/faucets/base-sepolia-faucet) or another Base Sepolia faucet.

### 1.3 Deploy and transfer ownership to the Safe

In `.env` set (example for Base Sepolia):

```bash
MULTISIG_OWNER_ADDRESS=0xF207aD025667Ba9671b70F66b7419eda6E69fbC4
```

For **Base Sepolia** you must use a 6-decimal token on that chain. The default address in the module is for Arbitrum Sepolia and will cause `ZaaNetPayment` to revert on Base Sepolia. Do this:

**Step A – Deploy TestUSDT on Base Sepolia (one time):**
```bash
npm run deployTestUSDTBaseSepolia
```
Note the deployed **TestUSDT** address from the output (or from `ignition/deployments/chain-84532/deployed_addresses.json`).

**Step B – Set it in `.env`:**
```bash
USDT_ADDRESS=0xYourTestUSDTAddressFromStepA
```

**Step C – Full ZaaNet deploy (fresh):**  
Remove the existing Base Sepolia deployment state so all contracts use the new token, then deploy:
```bash
rm -rf ignition/deployments/chain-84532
npm run deployBaseSepolia
```
(If you already ran deployBaseSepolia and it failed at ZaaNetPayment, removing `chain-84532` forces a clean deploy so Storage, Admin, Network, and Payment all use `USDT_ADDRESS`.)

After this runs, the **Safe** is the owner of Storage, Admin, Network, and Payment. Save the deployed contract addresses from the output (or from `ignition/deployments/chain-84532/deployed_addresses.json` for Base Sepolia).

---

## 2. All further owner actions in the Safe UI

From here on, you don’t use the terminal for owner actions. You use the Safe.

### 2.1 Open your Safe and network

1. Go to [app.safe.global](https://app.safe.global).
2. Connect a signer wallet and switch to **Base Sepolia** (or the network you deployed to).
3. Open your Safe (paste Safe address if needed, e.g. `0xF207aD025667Ba9671b70F66b7419eda6E69fbC4`).

### 2.2 Create a new transaction (Contract interaction)

1. Click **New transaction** → **Contract interaction** (or **Transaction builder**).
2. **Contract address:** paste one of your deployed contract addresses, e.g.:
   - **ZaaNetPayment** – for `pause()`, `unpause()`, `withdrawToken(...)`, `setDailyWithdrawalLimit(...)`.
   - **ZaaNetAdmin** – for `setTreasuryAddress(...)`, `setPaymentAddress(...)`, `toggleEmergencyMode()`, `setEmergencyOperator(...)`.
   - **ZaaNetStorage** – for `setAllowedCaller(...)`, `pause()`, `unpause()`, `emergencyDeactivateNetwork(...)`.
3. **ABI:** paste the ABI for that contract (from `artifacts/contracts/<ContractName>.sol/<ContractName>.json` → copy the `"abi"` array, or from the block explorer after verification).
4. **Value / OETH:** leave as **0** for these owner calls.
5. Choose the **function** (e.g. `pause`, `withdrawToken`, `setTreasuryAddress`) and fill parameters.
6. Submit the transaction. It will appear as **pending** and need more signatures (until the threshold is met).

### 2.3 Sign and execute

- Other signers: open the same Safe, see the pending transaction, and **Sign** it.
- When the signature count reaches the Safe’s threshold (e.g. 2 of 3), the transaction becomes **executable**.
- Any signer (or the executor, if configured) clicks **Execute** and pays gas. The call runs on-chain (e.g. `ZaaNetPayment.pause()`).

---

## 3. Suggested test sequence on testnet

Run these from the Safe UI to confirm everything works:

| # | Contract       | Function              | Purpose |
|---|----------------|------------------------|---------|
| 1 | ZaaNetPayment  | `pause()`              | Pause payments (no params). |
| 2 | ZaaNetPayment  | `unpause()`            | Unpause again. |
| 3 | ZaaNetAdmin    | `toggleEmergencyMode()`| Turn emergency mode on (payments/registration blocked). |
| 4 | ZaaNetAdmin    | `toggleEmergencyMode()`| Turn it off again. |
| 5 | ZaaNetStorage  | `setAllowedCaller(address,true)` | If you ever need to add a new allowed caller (use a test address). |

Optional, if the Payment contract holds testnet USDT:

| # | Contract      | Function                | Purpose |
|---|---------------|-------------------------|---------|
| 6 | ZaaNetPayment | `withdrawToken(to, amount)` | Withdraw to your EOA (stay within daily limit). |

After each execution, check the block explorer: the transaction should be from the **Safe address** and the contract state (e.g. paused, emergency mode) should match what you called.

---

## 4. Where to get ABIs and addresses

- **Addresses:**  
  After deploy: `ignition/deployments/chain-84532/deployed_addresses.json` (Base Sepolia) or from the deploy log.

- **ABIs:**  
  - From repo: `artifacts/contracts/ZaaNetPayment.sol/ZaaNetPayment.json` (and similarly for ZaaNetAdmin, ZaaNetStorage, ZaaNetNetwork). Open the file and copy the `"abi"` array.  
  - From block explorer: after verifying the contract, open the contract page and copy the ABI from there.

---

## 5. Mainnet checklist (when ready)

- [ ] Create mainnet Safe (e.g. Arbitrum One) with chosen signers and threshold.
- [ ] Set `MULTISIG_OWNER_ADDRESS` to mainnet Safe address.
- [ ] Deploy with `--network arbitrumOne` (or your mainnet).
- [ ] Verify contracts on the block explorer.
- [ ] Add Safe as emergency operator on ZaaNetAdmin if desired (`setEmergencyOperator(safeAddress, true)` from the Safe).
- [ ] Run one test transaction from the Safe (e.g. pause then unpause) to confirm the flow.
