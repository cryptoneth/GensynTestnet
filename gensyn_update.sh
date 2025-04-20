#!/bin/bash

# Stop the Gensyn screen session
echo "Stopping Gensyn screen session..."
screen -S gensyn -X quit

# Change to the home directory
cd $HOME

# Create a backup directory with a timestamp
BACKUP_DIR="$HOME/gensyn_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup specified files
echo "Creating backup of configuration files..."
cp rl-swarm/modal-login/temp-data/userData.json "$BACKUP_DIR/userData.json" 2>/dev/null || echo "Warning: userData.json not found"
cp rl-swarm/modal-login/temp-data/userApiKey.json "$BACKUP_DIR/userApiKey.json" 2>/dev/null || echo "Warning: userApiKey.json not found"
cp rl-swarm/swarm.pem "$BACKUP_DIR/swarm.pem" 2>/dev/null || echo "Warning: swarm.pem not found"

# Remove the existing rl-swarm directory
echo "Removing existing rl-swarm directory..."
rm -rf rl-swarm

# Clone new repositories
echo "Cloning repositories..."
git clone https://github.com/gensyn-ai/rl-swarm/
git clone https://github.com/cryptoneth/GensynTestnet

# Move run_rl_swarm.sh to rl-swarm
echo "Moving run_rl_swarm.sh to rl-swarm..."
mv GensynTestnet/run_rl_swarm.sh rl-swarm/run_rl_swarm.sh

# Change to the rl-swarm directory
cd rl-swarm

# Restore backup files
echo "Restoring backup files..."
mkdir -p modal-login/temp-data
cp "$BACKUP_DIR/userData.json" modal-login/temp-data/userData.json 2>/dev/null || echo "Warning: Could not restore userData.json"
cp "$BACKUP_DIR/userApiKey.json" modal-login/temp-data/userApiKey.json 2>/dev/null || echo "Warning: Could not restore userApiKey.json"
cp "$BACKUP_DIR/swarm.pem" . 2>/dev/null || echo "Warning: Could not restore swarm.pem"

# Apply configuration changes
echo "Applying configuration changes..."
sed -i 's/dht = hivemind\.DHT(start=True, .*)/dht = hivemind.DHT(start=True, ensure_bootstrap_success=False, **self._dht_kwargs(grpo_args))/' $HOME/rl-swarm/hivemind_exp/runner/gensyn/testnet_grpo_runner.py
sed -i 's/max_steps: [0-9]\+/max_steps: 3/' $HOME/rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml

# Install dependencies and start the node
echo "Installing dependencies and starting node..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Create and activate a virtual environment, then run the script
python3 -m venv .venv
source .venv/bin/activate
chmod +x ./run_rl_swarm.sh

# Start a new screen session for Gensyn
echo "Starting new screen session for Gensyn..."
screen -dmS gensyn bash -c "source .venv/bin/activate && ./run_rl_swarm.sh ; exec bash"

echo "Gensyn node setup and execution completed!"
