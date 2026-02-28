# ZaaNet Dune Analytics Implementation Guide

> Step-by-step guide to setting up Dune Analytics for ZaaNet protocol.

---

## Prerequisites

- [ ] Deployed ZaaNet contracts on Arbitrum One mainnet
- [ ] Dune account (free tier works for public data)
- [ ] Contract addresses recorded
- [ ] ABIs exported from deployment

---

## Step 1: Gather Contract Information

### Deployed Contract Addresses

> ⚠️ UPDATE THESE WITH YOUR ACTUAL DEPLOYED ADDRESSES

| Contract | Address | Transaction Hash |
|----------|---------|-----------------|
| ZaaNetStorage | `0x...` | `0x...` |
| ZaaNetAdmin | `0x...` | `0x...` |
| ZaaNetNetwork | `0x...` | `0x...` |
| ZaaNetPayment | `0x...` | `0x...` |

### USDT Token (Arbitrum)
- **Address:** `0xFd086b7CD5C755DDc49674BD709DaB5C2dEC0D3`
- **Decimals:** 6

---

## Step 2: Create Dune Team

1. Go to [dune.com](https://dune.com)
2. Click **"Sign Up"**
3. Choose **"Team"** for organization
4. Enter team name: `ZaaNet`
5. Complete registration

---

## Step 3: Add Contracts to Dune

### Direct Link (Use this!)
Go to: **https://dune.com/contracts/new**

This is where you submit new contracts for decoding.

### Step-by-Step Guide

1. **Open the link above**: https://dune.com/contracts/new

4. **Fill Contract Details**

   For each contract, fill in:
   
   | Field | Value |
   |-------|--------|
   | **Network** | `Arbitrum One` (from dropdown) |
   | **Contract Address** | Your deployed contract address (e.g., `0xABC...`) |
   | **Contract Name** | `ZaaNetStorage` (or ZaaNetAdmin, ZaaNetNetwork, ZaaNetPayment) |
   | **ABI** | Paste the contract ABI JSON |

5. **Where to get ABI?**

   After deploying, your ABI is in:
   ```
   smart-contracts/out/ZaaNetStorage.sol/ZaaNetStorage.json
   ```
   
   Look for the `"abi"` field and copy that array.
   
   Or use Forge to extract:
   ```bash
   cd smart-contracts
   forge inspect ZaaNetStorage abi
   ```

6. **Repeat for all 4 contracts**:
   - ZaaNetStorage
   - ZaaNetAdmin
   - ZaaNetNetwork
   - ZaaNetPayment

### Finding Your Contract Addresses

If you deployed via a script, check:
- The deployment transaction logs
- Your deployment script output
- Arbiscan/Blockscout (search by deployer address)

### How to Get the ABI

#### Option 1: From Forge (Recommended)
```bash
cd smart-contracts
forge inspect ZaaNetStorage abi
```
Copy the output - that's your ABI.

#### Option 2: From JSON File
```bash
# The ABI is in this file:
cat out/ZaaNetStorage.sol/ZaaNetStorage.json
```
Look for the `"abi"` key - copy just that array.

#### Option 3: From ABI File
```bash
# Export all ABIs
forge flatten contracts/ZaaNetStorage.sol > ZaaNetStorage_flat.sol
```

### Common Issues

| Problem | Solution |
|---------|----------|
| ABI not valid | Make sure to copy the array `[{...}]`, not the whole file |
| Wrong network | Must select "Arbitrum One" not "Ethereum" |
| Address not found | Wait 1-2 minutes for Dune to index, or verify address is correct |

### Method B: Using Setup Script

```bash
# Run the setup script
cd smart-contracts
chmod +x scripts/dune-setup.sh
./scripts/dune-setup.sh

# This generates JSON files in dune-setup/
# Manually update addresses and import to Dune
```

---

## Step 4: Verify Event Decoding

After adding contracts, test that events are decoded:

1. Go to **"Query"** → **"New Query"**
2. Try a simple query:

```sql
SELECT * FROM ZaaNetPayment_evt_PaymentProcessed LIMIT 10
```

3. If results appear, decoding is working ✅
4. If not, check contract address and ABI

---

## Step 5: Create Queries

### Option A: Use Provided Templates

1. Navigate to `dune-queries/` folder
2. Copy SQL from any file
3. Create new query in Dune
4. Paste and run
5. Save with descriptive B: Build Custom Queries

1. Go name

### Option to **"Query"** → **"New Query"**
2. Write SQL using event tables:
   - `ContractName_evt_EventName`
3. Add visualizations
4. Save and name appropriately

---

## Step 6: Build Dashboards

### Create Your First Dashboard

1. Click **"Dashboards"** → **"New Dashboard"**
2. Name: `ZaaNet Protocol Overview`
3. Add widgets:

#### Widget 1: Total Volume (Big Number)
```sql
SELECT SUM(grossAmount) / 1e6 AS total FROM ZaaNetPayment_evt_PaymentProcessed
```
- Visualization: **Big Number**

#### Widget 2: Daily Volume (Area Chart)
```sql
SELECT 
    date_trunc('day', evt_block_time) AS day,
    SUM(grossAmount) / 1e6 AS volume
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 1 DESC
LIMIT 30
```
- Visualization: **Area Chart**

#### Widget 3: Top Hosts (Table)
```sql
SELECT 
    host,
    SUM(hostAmount) / 1e6 AS earnings
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10
```
- Visualization: **Table**

---

## Step 7: Configure Auto-Refresh

1. On each dashboard, click **Settings**
2. Set refresh interval:
   - Overview: **15 minutes**
   - Financial: **1 hour**
   - Security: **5 minutes**
3. Enable **"Auto-refresh"**

---

## Step 8: Share for Grant Review

### Make Public

1. Dashboard → Settings → **"Make Public"**
2. Copy public URL
3. Share with grant reviewers

### Embed in Documentation

1. Dashboard → **"Share"** → **"Embed"**
2. Copy iframe code
3. Add to `README.md` or website

---

## Troubleshooting

### Events Not Decoding

| Issue | Solution |
|-------|----------|
| Wrong network | Ensure "Arbitrum One" selected |
| Wrong address | Verify contract address |
| ABI mismatch | Re-export ABI from deployment |

### Query Errors

| Error | Fix |
|-------|-----|
| Table not found | Wait 5-10 min for indexing |
| No data | Check if events have been emitted |
| Syntax error | Verify SQL syntax |

### Dashboard Not Loading

- Check dashboard is **Public** (for external access)
- Verify widget queries are saved
- Clear browser cache

---

## Metrics for Grant Application

### Key Metrics to Showcase

| Metric | Dashboard | Query |
|--------|-----------|-------|
| Total Payment Volume | Overview | `01_protocol_overview.sql` |
| Active Networks | Overview | `04_network_growth.sql` |
| Host Earnings | Financial | `03_host_analytics.sql` |
| Platform Revenue | Financial | `05_financial_analytics.sql` |
| Security Events | Security | `07_security_audit.sql` |

### Demo Dashboard URL Format
```
https://dune.com/your-team-name/zaanet-protocol-overview
```

---

## Grant Submission Checklist

- [ ] All 4 contracts added to Dune
- [ ] Queries running successfully
- [ ] Dashboards created (min 3)
- [ ] Dashboards set to Public
- [ ] Demo URLs recorded
- [ ] Event documentation reviewed
- [ ] Metrics verified accurate

---

## Support Resources

- **Dune Docs:** [docs.dune.com](https://docs.dune.com)
- **Dune Discord:** [discord.gg/dune-analytics](https://discord.gg/dune-analytics)
- **ZaaNet Events:** See `DUNE_EVENTS.md`

---

*Last Updated: February 2026*
