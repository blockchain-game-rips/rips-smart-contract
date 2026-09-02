#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$SCRIPT_DIR/state"
RPC_URL="http://localhost:8545"
CHAIN_ID=8453
DEPLOYER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
DEPLOYER_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

mkdir -p "$STATE_DIR"

echo "Starting anvil..."
anvil --silent --chain-id $CHAIN_ID --dump-state "$STATE_DIR/anvil-state.json" &
ANVIL_PID=$!
trap 'kill $ANVIL_PID 2>/dev/null; wait $ANVIL_PID 2>/dev/null' EXIT
sleep 1

echo "Mining initial block..."
cast rpc anvil_mine --rpc-url "$RPC_URL" >/dev/null

echo "Deploying VRF..."
forge script script/DeployVrf.s.sol:DeployVrf \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --sender "$DEPLOYER_ADDRESS" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    2>&1 | tail -5

VRF_BROADCAST="$REPO_DIR/broadcast/DeployVrf.s.sol/$CHAIN_ID/run-latest.json"
COORDINATOR_ADDRESS=$(jq -r '.transactions[] | select(.transactionType == "CREATE") | .contractAddress' "$VRF_BROADCAST" | head -1)
SUBSCRIPTION_ID=$(jq -r '.receipts[].logs[] | select(.topics[0] == "0x1d3015d7ba850fa198dc7b1a3f5d42779313a681035f77c8c03764c61005518d") | .topics[1]' "$VRF_BROADCAST" | head -1 | xargs -I{} node -e "console.log(BigInt('{}').toString())")

echo "Deploying Rips..."
VRF_COORDINATOR="$COORDINATOR_ADDRESS" VRF_SUBSCRIPTION_ID="$SUBSCRIPTION_ID" \
    forge script script/DeployRipsHarness.s.sol:DeployRips \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --sender "$DEPLOYER_ADDRESS" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    2>&1 | tail -5

RIPS_BROADCAST="$REPO_DIR/broadcast/DeployRipsHarness.s.sol/$CHAIN_ID/run-latest.json"
RIPS_ADDRESS=$(jq -r '.transactions[] | select(.transactionType == "CREATE") | .contractAddress' "$RIPS_BROADCAST" | head -1)

echo "Deploying conduit..."
RIPS="$RIPS_ADDRESS" \
    forge script script/DeployConduit.s.sol:DeployConduit \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --sender "$DEPLOYER_ADDRESS" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    2>&1 | tail -5

CONDUIT_BROADCAST="$REPO_DIR/broadcast/DeployConduit.s.sol/$CHAIN_ID/run-latest.json"
CONDUIT_ADDRESS=$(jq -r '.transactions[] | select(.transactionType == "CREATE") | .contractAddress' "$CONDUIT_BROADCAST" | head -1)

cat >"$STATE_DIR/deployments.json" <<EOF
{
  "rips": "$RIPS_ADDRESS",
  "conduit": "$CONDUIT_ADDRESS",
  "vrfCoordinator": "$COORDINATOR_ADDRESS",
  "subscriptionId": "$SUBSCRIPTION_ID"
}
EOF

echo "Done."
echo "  rips:           $RIPS_ADDRESS"
echo "  conduit:        $CONDUIT_ADDRESS"
echo "  vrfCoordinator: $COORDINATOR_ADDRESS"
echo "  subscriptionId: $SUBSCRIPTION_ID"
echo "  state:          $STATE_DIR/"
