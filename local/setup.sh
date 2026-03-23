#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state"
RPC_URL="http://localhost:8545"
DEPLOYER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
DEPLOYER_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

mkdir -p "$STATE_DIR"

echo "Starting anvil..."
anvil --silent --dump-state "$STATE_DIR/anvil-state.json" &
ANVIL_PID=$!
trap 'kill $ANVIL_PID 2>/dev/null; wait $ANVIL_PID 2>/dev/null' EXIT
sleep 1

echo "Mining initial block..."
cast rpc anvil_mine --rpc-url "$RPC_URL" > /dev/null

echo "Deploying contracts..."
DEPLOY_OUTPUT=$(forge script script/DeployLocal.s.sol:DeployLocal \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --sender "$DEPLOYER_ADDRESS" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    2>&1)

RIPS_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "rips:" | awk '{print $3}')
VRF_SETUP_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "vrfSetup:" | awk '{print $3}')

echo "Fetching addresses..."
SUBSCRIPTION_ID=$(cast call "$VRF_SETUP_ADDRESS" "subscriptionId()(uint256)" --rpc-url "$RPC_URL" | awk '{print $1}')
COORDINATOR_ADDRESS=$(cast call "$VRF_SETUP_ADDRESS" "coordinator()(address)" --rpc-url "$RPC_URL")

cat > "$STATE_DIR/deployments.json" <<EOF
{
  "rips": "$RIPS_ADDRESS",
  "vrfCoordinator": "$COORDINATOR_ADDRESS",
  "vrfSetup": "$VRF_SETUP_ADDRESS",
  "subscriptionId": "$SUBSCRIPTION_ID"
}
EOF

echo "Done."
echo "  rips:           $RIPS_ADDRESS"
echo "  vrfCoordinator: $COORDINATOR_ADDRESS"
echo "  subscriptionId: $SUBSCRIPTION_ID"
echo "  state:          $STATE_DIR/"
