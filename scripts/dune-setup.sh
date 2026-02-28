#!/bin/bash
# =============================================================================
# ZaaNet Dune Analytics Setup Script
# Generates ABI and event signature files for Dune import
# =============================================================================

set -e

echo "=========================================="
echo "ZaaNet Dune Analytics Setup"
echo "=========================================="

# Configuration
CONTRACTS_DIR="./contracts"
OUTPUT_DIR="./dune-setup"
NETWORK=${1:-"arbitrum"} # Default to arbitrum, can pass mainnet/sepolia

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo ""
echo "Step 1: Compiling contracts..."
forge build

echo ""
echo "Step 2: Extracting ABIs..."

# Function to extract ABI for a contract
extract_abi() {
	local contract=$1
	local address=$2

	# Find the artifact
	local artifact=$(find ./out -name "${contract}.sol" -name "*.json" 2>/dev/null | head -1)

	if [ -z "$artifact" ]; then
		echo "⚠️  Warning: Could not find artifact for $contract"
		return
	fi

	# Extract ABI and create JSON
	local abi=$(forge inspect "$contract" abi 2>/dev/null)

	if [ -n "$abi" ]; then
		cat >"$OUTPUT_DIR/${contract}.json" <<EOF
{
  "name": "$contract",
  "address": "$address",
  "abi": $abi
}
EOF
		echo "✅ Created $contract.json"
	fi
}

# Extract ABIs for main contracts (update addresses after deployment)
extract_abi "ZaaNetStorage" "0x0000000000000000000000000000000000000001"
extract_abi "ZaaNetAdmin" "0x0000000000000000000000000000000000000001"
extract_abi "ZaaNetNetwork" "0x0000000000000000000000000000000000000001"
extract_abi "ZaaNetPayment" "0x0000000000000000000000000000000000000001"

echo ""
echo "Step 3: Generating event signatures..."

# Generate event signatures
cat >"$OUTPUT_DIR/event-signatures.txt" <<'EOF'
# ZaaNet Event Signatures
# Add these to Dune for automatic event decoding

# ZaaNetPayment
PaymentProcessed(bytes32,uint256,address,address,uint256,uint256,uint256,uint256)
BatchPaymentProcessed(uint256,uint256,uint256)
HostVouchersRegistered(address,uint8,uint256,uint256,uint256)
DailyLimitExceeded(address,uint256,uint256,uint256)

# ZaaNetNetwork
NetworkRegistered(uint256,address,string,uint256,bool,uint256,uint256)
HostingFeePaid(address,uint256,uint256)
NetworkUpdated(uint256,address,uint256,string,bool)
NetworkPriceUpdated(uint256,uint256,uint256)
NetworkStatusChanged(uint256,bool,bool)
HostAdded(address)

# ZaaNetStorage
AllowedCallerUpdated(address,bool)
NetworkStored(uint256,address,uint256)
NetworkUpdated(uint256,address)
HostEarningsUpdated(address,uint256)
ClientVoucherFeeEarningsUpdated(uint256)
HostVoucherFeeEarningsUpdated(uint256)

# ZaaNetAdmin
PlatformFeeUpdated(uint256,uint256,address)
TreasuryUpdated(address,address,address)
HostingFeeUpdated(uint256,uint256,address)
HostVoucherFeeTierUpdated(uint8,uint256,address)
PaymentAddressUpdated(address,address,address)
AdminPaused(address)
AdminUnpaused(address)
EmergencyModeToggled(bool,address)
EmergencyOperatorUpdated(address,bool,address)
ContractsInitialized(address,uint256)
EOF

echo "✅ Created event-signatures.txt"

echo ""
echo "Step 4: Creating Dune import configuration..."

cat >"$OUTPUT_DIR/dune-config.json" <<'EOF'
{
  "name": "ZaaNet Protocol",
  "description": "Decentralized WiFi voucher system on Arbitrum",
  "network": "arbitrum_one",
  "contracts": [
    {
      "name": "ZaaNetStorage",
      "address": "UPDATE_AFTER_DEPLOYMENT",
      "abi_file": "ZaaNetStorage.json"
    },
    {
      "name": "ZaaNetAdmin", 
      "address": "UPDATE_AFTER_DEPLOYMENT",
      "abi_file": "ZaaNetAdmin.json"
    },
    {
      "name": "ZaaNetNetwork",
      "address": "UPDATE_AFTER_DEPLOYMENT",
      "abi_file": "ZaaNetNetwork.json"
    },
    {
      "name": "ZaaNetPayment",
      "address": "UPDATE_AFTER_DEPLOYMENT",
      "abi_file": "ZaaNetPayment.json"
    }
  ],
  "usdt_token": {
    "address": "0xFd086b7CD5C755DDc49674BD709DaB5C2dEC0D3",
    "decimals": 6
  }
}
EOF

echo "✅ Created dune-config.json"

echo ""
echo "Step 5: Copying query files..."

# Copy SQL queries to output
cp -r dune-queries/* "$OUTPUT_DIR/" 2>/dev/null || true

echo "✅ Copied SQL queries"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Output files in: $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "1. Update contract addresses in *.json files"
echo "2. Import ABIs to Dune"
echo "3. Run SQL queries to verify"
echo "4. Build dashboards"
echo ""
echo "For help, see:"
echo "  - DUNE_EVENTS.md (Event catalog)"
echo "  - DUNE_DASHBOARDS.md (Dashboard templates)"
echo ""
