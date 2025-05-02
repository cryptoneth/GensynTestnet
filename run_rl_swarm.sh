#!/bin/bash

ROOT=$PWD

RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;95m'
BLUE='\033[0;94m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS
export IDENTITY_PATH
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120
export TUNNEL_TYPE=""

DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ"
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

SMALL_SWARM_CONTRACT="0x69C6e1D608ec64885E7b185d39b04B491a71768C"
BIG_SWARM_CONTRACT="0x6947c6E196a48B77eFa9331EC1E3e45f3Ee5Fd58"

# Install prerequisites (build-essential, gcc, g++, jq)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if command -v apt &>/dev/null; then
    echo -e "${CYAN}${BOLD}[✓] Debian/Ubuntu detected. Installing build-essential, gcc, g++, jq...${NC}"
    sudo apt update > /dev/null 2>&1
    sudo apt install -y build-essential gcc g++ jq > /dev/null 2>&1
  elif command -v yum &>/dev/null; then
    echo -e "${CYAN}${BOLD}[✓] RHEL/CentOS detected. Installing Development Tools, jq...${NC}"
    sudo yum groupinstall -y "Development Tools" > /dev/null 2>&1
    sudo yum install -y gcc gcc-c++ jq > /dev/null 2>&1
  elif command -v pacman &>/dev/null; then
    echo -e "${CYAN}${BOLD}[✓] Arch Linux detected. Installing base-devel, jq...${NC}"
    sudo pacman -Sy --noconfirm base-devel gcc jq > /dev/null 2>&1
  else
    echo -e "${RED}${BOLD}[✗] Linux detected but unsupported package manager.${NC}"
    exit 1
  fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo -e "${CYAN}${BOLD}[✓] macOS detected. Installing Xcode Command Line Tools, jq...${NC}"
  xcode-select --install > /dev/null 2>&1 || true
  if ! command -v brew &>/dev/null; then
    echo -e "${CYAN}${BOLD}[✓] Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew install jq > /dev/null 2>&1
else
  echo -e "${RED}${BOLD}[✗] Unsupported OS: $OSTYPE${NC}"
  exit 1
fi

if command -v gcc &>/dev/null; then
  export CC=$(command -v gcc)
  echo -e "${CYAN}${BOLD}[✓] Exported CC=$CC${NC}"
else
  echo -e "${RED}${BOLD}[✗] gcc not found. Please install it manually.${NC}"
  exit 1
fi

check_cuda_installation() {
    echo -e "\n${CYAN}${BOLD}[✓] Checking GPU and CUDA installation...${NC}"
    
    GPU_AVAILABLE=false
    CUDA_AVAILABLE=false
    NVCC_AVAILABLE=false
    
    detect_gpu() {
        if command -v lspci &> /dev/null; then
            if lspci | grep -i nvidia &> /dev/null; then
                echo -e "${GREEN}${BOLD}[✓] NVIDIA GPU detected (via lspci)${NC}"
                return 0
            elif lspci | grep -i "vga\|3d\|display" | grep -i "amd\|radeon\|ati" &> /dev/null; then
                echo -e "${YELLOW}${BOLD}[!] AMD GPU detected (via lspci)${NC}"
                echo -e "${YELLOW}${BOLD}[!] This script only supports NVIDIA GPUs for CUDA installation${NC}"
                return 2 
            fi
            return 1 
        fi
        
        if command -v nvidia-smi &> /dev/null; then
            if nvidia-smi &> /dev/null; then
                echo -e "${GREEN}${BOLD}[✓] NVIDIA GPU detected (via nvidia-smi)${NC}"
                return 0
            fi
        fi
        
        if [ -d "/proc/driver/nvidia" ] || [ -d "/dev/nvidia0" ]; then
            echo -e "${GREEN}${BOLD}[✓] NVIDIA GPU detected (via system directories)${NC}"
            return 0
        fi
        
        if [ -x "/usr/local/cuda/samples/bin/x86_64/linux/release/deviceQuery" ]; then
            if /usr/local/cuda/samples/bin/x86_64/linux/release/deviceQuery | grep "Result = PASS" &> /dev/null; then
                echo -e "${GREEN}${BOLD}[✓] NVIDIA GPU detected (via deviceQuery)${NC}"
                return 0
            fi
        fi
        
        if [ -d "/sys/class/gpu" ] || ls /sys/bus/pci/devices/*/vendor 2>/dev/null | xargs cat 2>/dev/null | grep -q "0x10de"; then
            echo -e "${GREEN}${BOLD}[✓] NVIDIA GPU detected (via sysfs)${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}${BOLD}[!] No NVIDIA GPU detected with any detection method${NC}"
        return 1
    }
    
    detect_gpu
    gpu_result=$?
    
    if [ $gpu_result -eq 0 ]; then
        GPU_AVAILABLE=true
    elif [ $gpu_result -eq 2 ]; then
        echo -e "${YELLOW}${BOLD}[!] Proceeding with CPU-only mode${NC}"
        CPU_ONLY="true"
        return 0
    else
        echo -e "${YELLOW}${BOLD}[!] No NVIDIA GPU detected - using CPU-only mode${NC}"
        echo -e "${YELLOW}${BOLD}[!] CUDA installation will be skipped${NC}"
        CPU_ONLY="true"
        return 0
    fi

    if command -v nvidia-smi &> /dev/null; then
        echo -e "${GREEN}${BOLD}[✓] CUDA drivers detected (nvidia-smi found)${NC}"
        CUDA_AVAILABLE=true
        echo -e "${CYAN}${BOLD}[✓] GPU information:${NC}"
        nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu --format=csv,noheader
    elif [ -d "/proc/driver/nvidia" ]; then
        echo -e "${GREEN}${BOLD}[✓] CUDA drivers detected (NVIDIA driver directory found)${NC}"
        CUDA_AVAILABLE=true
    else
        echo -e "${YELLOW}${BOLD}[!] CUDA drivers not detected${NC}"
    fi
    
    if command -v nvcc &> /dev/null; then
        NVCC_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
        echo -e "${GREEN}${BOLD}[✓] NVCC compiler detected (version $NVCC_VERSION)${NC}"
        NVCC_AVAILABLE=true
    else
        echo -e "${YELLOW}${BOLD}[!] NVCC compiler not detected${NC}"
    fi
    
    if [ "$GPU_AVAILABLE" = true ] && ([ "$CUDA_AVAILABLE" = false ] || [ "$NVCC_AVAILABLE" = false ]); then
        echo -e "${YELLOW}${BOLD}[!] NVIDIA GPU is available but CUDA environment is not completely set up${NC}"
        read -p "Would you like to install CUDA and NVCC? [Y/n] " install_choice
        install_choice=${install_choice:-Y}
        
        if [[ $install_choice =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}${BOLD}[✓] Downloading and running CUDA installation script from GitHub...${NC}"
            bash <(curl -sSL https://raw.githubusercontent.com/zunxbt/gensyn-testnet/main/cuda.sh)
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}${BOLD}[✓] CUDA installation script completed successfully${NC}"
                source ~/.profile 2>/dev/null || true
                source ~/.bashrc 2>/dev/null || true
                
                if [ -f "/etc/profile.d/cuda.sh" ]; then
                    source /etc/profile.d/cuda.sh
                fi
                
                if [ -d "/usr/local/cuda/bin" ] && [[ ":$PATH:" != *":/usr/local/cuda/bin:"* ]]; then
                    export PATH="/usr/local/cuda/bin:$PATH"
                fi
                
                if [ -d "/usr/local/cuda/lib64" ] && [[ ":$LD_LIBRARY_PATH:" != *":/usr/local/cuda/lib64:"* ]]; then
                    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
                fi
                
                if command -v nvcc &> /dev/null; then
                    NVCC_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
                    echo -e "${GREEN}${BOLD}[✓] NVCC successfully installed (version $NVCC_VERSION)${NC}"
                    NVCC_AVAILABLE=true
                else
                    echo -e "${YELLOW}${BOLD}[!] NVCC installation may require a system restart${NC}"
                    echo -e "${YELLOW}${BOLD}[!] If you continue to have issues after this script completes, please restart your system${NC}"
                fi
                
                if command -v nvidia-smi &> /dev/null; then
                    echo -e "${CYAN}${BOLD}[✓] Current NVIDIA driver information:${NC}"
                    nvidia-smi --query-gpu=driver_version,name,temperature.gpu,utilization.gpu,utilization.memory --format=csv,noheader
                fi
            else
                echo -e "${RED}${BOLD}[✗] CUDA installation failed${NC}"
                echo -e "${YELLOW}${BOLD}[!] Please try installing CUDA manually by following NVIDIA's installation guide${NC}"
                echo -e "${YELLOW}${BOLD}[!] Proceeding with CPU-only mode${NC}"
                CPU_ONLY="true"
            fi
        else
            echo -e "${YELLOW}${BOLD}[!] Proceeding without CUDA installation${NC}"
            echo -e "${YELLOW}${BOLD}[!] CPU-only mode will be used${NC}"
            CPU_ONLY="true"
        fi
    elif [ "$GPU_AVAILABLE" = true ] && [ "$CUDA_AVAILABLE" = true ] && [ "$NVCC_AVAILABLE" = true ]; then
        echo -e "${GREEN}${BOLD}[✓] GPU with CUDA environment properly configured${NC}"
        CPU_ONLY="false"
    else
        echo -e "${YELLOW}${BOLD}[!] Using CPU-only mode${NC}"
        CPU_ONLY="true"
    fi
    
    return 0
}

check_cuda_installation

export CPU_ONLY

if [ "$CPU_ONLY" = "true" ]; then
    echo -e "\n${YELLOW}${BOLD}[✓] Running in CPU-only mode${NC}"
else
    echo -e "\n${GREEN}${BOLD}[✓] Running with GPU acceleration${NC}"
fi

while true; do
    echo -e "\n${CYAN}${BOLD}Please select a swarm to join:\n[A] Math\n[B] Math Hard${NC}"
    read -p "> " ab
    ab=${ab:-A}
    case $ab in
        [Aa]*)  USE_BIG_SWARM=false; break ;;
        [Bb]*)  USE_BIG_SWARM=true; break ;;
        *)      echo ">>> Please answer A or B." ;;
    esac
done

if [ "$USE_BIG_SWARM" = true ]; then
    SWARM_CONTRACT="$BIG_SWARM_CONTRACT"
else
    SWARM_CONTRACT="$SMALL_SWARM_CONTRACT"
fi

while true; do
    echo -e "\n${CYAN}${BOLD}How many parameters (in billions)? [0.5, 1.5, 7, 32, 72]${NC}"
    read -p "> " pc
    pc=${pc:-0.5}
    case $pc in
        0.5 | 1.5 | 7 | 32 | 72) PARAM_B=$pc; break ;;
        *) echo ">>> Please answer in [0.5, 1.5, 7, 32, 72]." ;;
    esac
done

cleanup() {
    echo -e "${YELLOW}${BOLD}[✓] Shutting down processes...${NC}"
    kill $SERVER_PID 2>/dev/null || true
    kill $TUNNEL_PID 2>/dev/null || true
    exit 0
}

trap cleanup INT

sleep 2

cd modal-login

echo -e "\n${CYAN}${BOLD}[✓] Installing dependencies with npm. This may take a few minutes, depending on your internet speed...${NC}"
npm install --legacy-peer-deps

# Run sed command before npm run dev
echo -e "${CYAN}${BOLD}[✓] Updating max_steps in config file...${NC}"
cd
sed -i 's/max_steps: [0-9]\+/max_steps: 3/' rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml
cd $ROOT/modal-login

echo -e "\n${CYAN}${BOLD}[✓] Starting the development server...${NC}"
if ! command -v ss &>/dev/null; then
  echo -e "${YELLOW}[!] 'ss' not found. Attempting to install 'iproute2'...${NC}"
  if command -v apt &>/dev/null; then
    sudo apt update && sudo apt install -y iproute2
  elif command -v yum &>/dev/null; then
    sudo yum install -y iproute
  elif command -v pacman &>/dev/null; then
    sudo pacman -Sy iproute2
  else
    echo -e "${RED}[✗] Could not install 'ss'. Package manager not found.${NC}"
    exit 1
  fi
fi

PORT_LINE=$(ss -ltnp | grep ":3000 ")
if [ -n "$PORT_LINE" ]; then
  PID=$(echo "$PORT_LINE" | grep -oP 'pid=\K[0-9]+')
  if [ -n "$PID" ]; then
    echo -e "${YELLOW}[!] Port 3000 is in use. Killing process: $PID${NC}"
    kill -9 $PID
    sleep 2
  fi
fi

npm run dev > server.log 2>&1 &
SERVER_PID=$!
MAX_WAIT=30  

for ((i = 0; i < MAX_WAIT; i++)); do
    if grep -q "Local:        http://localhost:" server.log; then
        PORT=$(grep "Local:        http://localhost:" server.log | sed -n 's/.*http:\/\/localhost:\([0-9]*\).*/\1/p')
        if [ -n "$PORT" ]; then
            echo -e "${GREEN}${BOLD}[✓] Server is running successfully on port $PORT.${NC}"
            break
        fi
    fi
    sleep 1
done

if [ $i -eq $MAX_WAIT ]; then
    echo -e "${RED}${BOLD}[✗] Timeout waiting for server to start.${NC}"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Check if JSON files exist to skip tunnel process
SKIP_TUNNEL=false
if [ -f "temp-data/userData.json" ] && [ -f "temp-data/userApiKey.json" ]; then
    echo -e "${GREEN}${BOLD}[✓] userData.json and userApiKey.json found. Skipping tunnel process...${NC}"
    SKIP_TUNNEL=true
fi

if [ "$SKIP_TUNNEL" = false ]; then
    echo -e "\n${CYAN}${BOLD}[✓] Detecting system architecture...${NC}"
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    if [ "$ARCH" = "x86_64" ]; then
        NGROK_ARCH="amd64"
        CF_ARCH="amd64"
        echo -e "${GREEN}${BOLD}[✓] Detected x86_64 architecture.${NC}"
    elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
        NGROK_ARCH="arm64"
        CF_ARCH="arm64"
        echo -e "${GREEN}${BOLD}[✓] Detected ARM64 architecture.${NC}"
    elif [[ "$ARCH" == arm* ]]; then
        NGROK_ARCH="arm"
        CF_ARCH="arm"
        echo -e "${GREEN}${BOLD}[✓] Detected ARM architecture.${NC}"
    else
        echo -e "${RED}[✗] Unsupported architecture: $ARCH. Please use a supported system.${NC}"
        exit 1
    fi

    check_url() {
        local url=$1
        local max_retries=3
        local retry=0
        
        while [ $retry -lt $max_retries ]; do
            http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
            if [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
                return 0
            fi
            retry=$((retry + 1))
            sleep 2
        done
        return 1
    }

    install_localtunnel() {
        if command -v lt >/dev/null 2>&1; then
            echo -e "${GREEN}${BOLD}[✓] Localtunnel is already installed.${NC}"
            return 0
        fi
        echo -e "\n${CYAN}${BOLD}[✓] Installing localtunnel...${NC}"
        npm install -g localtunnel > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${BOLD}[✓] Localtunnel installed successfully.${NC}"
            return 0
        else
            echo -e "${RED}${BOLD}[✗] Failed to install localtunnel.${NC}"
            return 1
        fi
    }

    install_cloudflared() {
        if command -v cloudflared >/dev/null 2>&1; then
            echo -e "${GREEN}${BOLD}[✓] Cloudflared is already installed.${NC}"
            return 0
        fi
        echo -e "\n${YELLOW}${BOLD}[✓] Installing cloudflared...${NC}"
        CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH"
        wget -q --show-progress "$CF_URL" -O cloudflared
        if [ $? -ne 0 ]; then
            echo -e "${RED}${BOLD}[✗] Failed to download cloudflared.${NC}"
            return 1
        fi
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin/
        if [ $? -ne 0 ]; then
            echo -e "${RED}${BOLD}[✗] FailedTINGS = 120/' \
                -e '/anonymous_p2p = await cls\.create\(/a\        bootstrap_timeout=120,' \
                "$P2P_DAEMON_FILE"
        fi
        echo -e "${CYAN}${BOLD}[✓] Applied p2p_daemon timeout changes${NC}"
    else
        echo -e "${GREEN}${BOLD}[✓] p2p_daemon timeout changes already applied, skipping${NC}"
    fi
else
    echo -e "${YELLOW}${BOLD}[!] Could not locate hivemind.p2p.p2p_daemon. Skipping timeout changes.${NC}"
fi

if [ -n "$DHT_NODE_FILE" ] && [ -f "$DHT_NODE_FILE" ]; then
    if ! grep -q "bootstrap_timeout: float = 120" "$DHT_NODE_FILE"; then
        if [ "$(uname)" = "Darwin" ]; then
            sed -i '' -e 's/bootstrap_timeout: Optional\[float\] = None/bootstrap_timeout: float = 120/' \
                -e 's/p2p = await P2P.create(\*\*kwargs)/p2p = await P2P.create(bootstrap_timeout=120, **kwargs)/' \
                "$DHT_NODE_FILE"
        else
            sed -i -e 's/bootstrap_timeout: Optional\[float\] = None/bootstrap_timeout: float = 120/' \
                -e 's/p2p = await P2P.create(\*\*kwargs)/p2p = await P2P.create(bootstrap_timeout=120, **kwargs)/' \
                "$DHT_NODE_FILE"
        fi
        echo -e "${CYAN}${BOLD}[✓] Applied dht_node timeout changes${NC}"
    else
        echo -e "${GREEN}${BOLD}[✓] dht_node timeout changes already applied, skipping${NC}"
    fi
else
    echo -e "${YELLOW}${BOLD}[!] Could not locate hivemind.dht.node. Skipping timeout changes.${NC}"
fi

# Update max_steps in config file at the end
echo -e "${CYAN}${BOLD}[✓] Updating max_steps in config file...${NC}"
cd
sed -i 's/max_steps: [0-9]\+/max_steps: 3/' rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml

if [ -n "$ORG_ID" ]; then
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --modal_org_id "$ORG_ID" \
        --contract_address "$SWARM_CONTRACT" \
        --config "$CONFIG_PATH" \
        --game "$GAME"
else
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --public_maddr "$PUB_MULTI_ADDRS" \
        --initial_peers "$PEER_MULTI_ADDRS" \
        --host_maddr "$HOST_MULTI_ADDRS" \
        --config "$CONFIG_PATH" \
        --game "$GAME"
fi

wait
