#!/bin/bash

# Set root directory
ROOT=$PWD

# Define color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;95m'
BLUE='\033[0;94m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Export environment variables
export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS
export IDENTITY_PATH
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120
export TUNNEL_TYPE=""

# Default values for environment variables
DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ"
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

# Swarm contract addresses
SMALL_SWARM_CONTRACT="0x69C6e1D608ec64885E7b185d39b04B491a71768C"
BIG_SWARM_CONTRACT="0x6947c6E196a48B77eFa9331EC1E3e45f3Ee5Fd58"

# Check OS and install dependencies
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt &>/dev/null; then
        echo -e "${CYAN}${BOLD}🚀 Debian/Ubuntu found! Installing build tools...${NC}"
        sudo apt update > /dev/null 2>&1
        sudo apt install -y build-essential gcc g++ > /dev/null 2>&1
    elif command -v yum &>/dev/null; then
        echo -e "${CYAN}${BOLD}🚀 RHEL/CentOS found! Installing development tools...${NC}"
        sudo yum groupinstall -y "Development Tools" > /dev/null 2>&1
        sudo yum install -y gcc gcc-c++ > /dev/null 2>&1
    elif command -v pacman &>/dev/null; then
        echo -e "${CYAN}${BOLD}🚀 Arch Linux found! Installing base-devel...${NC}"
        sudo pacman -Sy --noconfirm base-devel gcc > /dev/null 2>&1
    else
        echo -e "${RED}${BOLD}❌ Unsupported Linux package manager detected.${NC}"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${CYAN}${BOLD}🚀 macOS detected! Setting up Xcode Command Line Tools...${NC}"
    xcode-select --install > /dev/null 2>&1
else
    echo -e "${RED}${BOLD}❌ Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

# Check for gcc and set CC
if command -v gcc &>/dev/null; then
    export CC=$(command -v gcc)
    echo -e "${CYAN}${BOLD}✅ gcc found and CC set to $CC${NC}"
else
    echo -e "${RED}${BOLD}❌ gcc not found. Please install it manually.${NC}"
    exit 1
fi

# Function to check CUDA and GPU setup
check_cuda_installation() {
    echo -e "\n${CYAN}${BOLD}🔍 Verifying GPU and CUDA setup...${NC}"
    
    GPU_AVAILABLE=false
    CUDA_AVAILABLE=false
    NVCC_AVAILABLE=false
    
    detect_gpu() {
        if command -v lspci &> /dev/null; then
            if lspci | grep -i nvidia &> /dev/null; then
                echo -e "${GREEN}${BOLD}✅ NVIDIA GPU detected (lspci)${NC}"
                return 0
            elif lspci | grep -i "vga\|3d\|display" | grep -i "amd\|radeon\|ati" &> /dev/null; then
                echo -e "${YELLOW}${BOLD}⚠️ AMD GPU detected (lspci). Only NVIDIA GPUs are supported for CUDA.${NC}"
                return 2 
            fi
            return 1 
        fi
        
        if command -v nvidia-smi &> /dev/null; then
            if nvidia-smi &> /dev/null; then
                echo -e "${GREEN}${BOLD}✅ NVIDIA GPU detected (nvidia-smi)${NC}"
                return 0
            fi
        fi
        
        if [ -d "/proc/driver/nvidia" ] || [ -d "/dev/nvidia0" ]; then
            echo -e "${GREEN}${BOLD}✅ NVIDIA GPU detected (system directories)${NC}"
            return 0
        fi
        
        if [ -x "/usr/local/cuda/samples/bin/x86_64/linux/release/deviceQuery" ]; then
            if /usr/local/cuda/samples/bin/x86_64/linux/release/deviceQuery | grep "Result = PASS" &> /dev/null; then
                echo -e "${GREEN}${BOLD}✅ NVIDIA GPU detected (deviceQuery)${NC}"
                return 0
            fi
        fi

        if [ -d "/sys/class/gpu" ] || ls /sys/bus/pci/devices/*/vendor 2>/dev/null | xargs cat 2>/dev/null | grep -q "0x10de"; then
            echo -e "${GREEN}${BOLD}✅ NVIDIA GPU detected (sysfs)${NC}"
            return 0
        fi

        echo -e "${YELLOW}${BOLD}⚠️ No NVIDIA GPU detected.${NC}"
        return 1
    }
    
    detect_gpu
    gpu_result=$?
    
    if [ $gpu_result -eq 0 ]; then
        GPU_AVAILABLE=true
    elif [ $gpu_result -eq 2 ]; then
        echo -e "${YELLOW}${BOLD}⚠️ Switching to CPU-only mode.${NC}"
        CPU_ONLY="true"
        return 0
    else
        echo -e "${YELLOW}${BOLD}⚠️ No NVIDIA GPU found. Using CPU-only mode.${NC}"
        CPU_ONLY="true"
        return 0
    fi

    if command -v nvidia-smi &> /dev/null; then
        echo -e "${GREEN}${BOLD}✅ CUDA drivers detected (nvidia-smi).${NC}"
        CUDA_AVAILABLE=true
        echo -e "${CYAN}${BOLD}ℹ️ GPU details:${NC}"
        nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu --format=csv,noheader
    elif [ -d "/proc/driver/nvidia" ]; then
        echo -e "${GREEN}${BOLD}✅ CUDA drivers detected (NVIDIA driver directory).${NC}"
        CUDA_AVAILABLE=true
    else
        echo -e "${YELLOW}${BOLD}⚠️ CUDA drivers not detected.${NC}"
    fi
    
    if command -v nvcc &> /dev/null; then
        NVCC_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
        echo -e "${GREEN}${BOLD}✅ NVCC compiler detected (version $NVCC_VERSION).${NC}"
        NVCC_AVAILABLE=true
    else
        echo -e "${YELLOW}${BOLD}⚠️ NVCC compiler not detected.${NC}"
    fi
    
    if [ "$GPU_AVAILABLE" = true ] && ([ "$CUDA_AVAILABLE" = false ] || [ "$NVCC_AVAILABLE" = false ]); then
        echo -e "${YELLOW}${BOLD}⚠️ NVIDIA GPU detected but CUDA setup is incomplete.${NC}"
        read -p "🌟 Would you like to install CUDA and NVCC? [Y/n] " install_choice
        install_choice=${install_choice:-Y}
        
        if [[ $install_choice =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}${BOLD}🚀 Fetching CUDA installation script...${NC}"
            bash <(curl -sSL https://raw.githubusercontent.com/zunxbt/gensyn-testnet/main/cuda.sh)
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}${BOLD}✅ CUDA installation completed successfully!${NC}"
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
                    echo -e "${GREEN}${BOLD}✅ NVCC installed (version $NVCC_VERSION).${NC}"
                    NVCC_AVAILABLE=true
                else
                    echo -e "${YELLOW}${BOLD}⚠️ NVCC installation may require a reboot.${NC}"
                fi
                
                if command -v nvidia-smi &> /dev/null; then
                    echo -e "${CYAN}${BOLD}ℹ️ NVIDIA driver details:${NC}"
                    nvidia-smi --query-gpu=driver_version,name,temperature.gpu,utilization.gpu,utilization.memory --format=csv,noheader
                fi
            else
                echo -e "${RED}${BOLD}❌ CUDA installation failed.${NC}"
                echo -e "${YELLOW}${BOLD}⚠️ Please install CUDA manually using NVIDIA's guide. Switching to CPU-only mode.${NC}"
                CPU_ONLY="true"
            fi
        else
            echo -e "${YELLOW}${BOLD}⚠️ Skipping CUDA installation. Using CPU-only mode.${NC}"
            CPU_ONLY="true"
        fi
    elif [ "$GPU_AVAILABLE" = true ] && [ "$CUDA_AVAILABLE" = true ] && [ "$NVCC_AVAILABLE" = true ]; then
        echo -e "${GREEN}${BOLD}✅ GPU and CUDA environment fully configured!${NC}"
        CPU_ONLY="false"
    else
        echo -e "${YELLOW}${BOLD}⚠️ Using CPU-only mode.${NC}"
        CPU_ONLY="true"
    fi
    
    return 0
}

check_cuda_installation
export CPU_ONLY

if [ "$CPU_ONLY" = "true" ]; then
    echo -e "\n${YELLOW}${BOLD}⚙️ Running in CPU-only mode${NC}"
else
    echo -e "\n${GREEN}${BOLD}⚙️ Running with GPU acceleration${NC}"
fi

# Prompt user to select swarm
while true; do
    echo -e "\n${PURPLE}${BOLD}🌌 Which swarm would you like to join?${NC}"
    echo -e "${PURPLE}${BOLD}[A] Basic Math Swarm${NC}"
    echo -e "${PURPLE}${BOLD}[B] Advanced Math Swarm${NC}"
    read -p "➡️ Enter your choice: " ab
    ab=${ab:-A}
    case $ab in
        [Aa]*)  USE_BIG_SWARM=false; break ;;
        [Bb]*)  USE_BIG_SWARM=true; break ;;
        *)      echo -e "${RED}${BOLD}❌ Please select either A or B.${NC}" ;;
    esac
done

if [ "$USE_BIG_SWARM" = true ]; then
    SWARM_CONTRACT="$BIG_SWARM_CONTRACT"
else
    SWARM_CONTRACT="$SMALL_SWARM_CONTRACT"
fi
echo -e "${CYAN}${BOLD}✅ Selected contract address: $SWARM_CONTRACT${NC}"

# Prompt user for parameter size
while true; do
    echo -e "\n${PURPLE}${BOLD}📏 Select model size (in billions of parameters):${NC}"
    echo -e "${PURPLE}${BOLD}[0.5, 1.5, 7, 32, 72]${NC}"
    read -p "➡️ Enter size: " pc
    pc=${pc:-0.5}
    case $pc in
        0.5 | 1.5 | 7 | 32 | 72) PARAM_B=$pc; break ;;
        *) echo -e "${RED}${BOLD}❌ Please choose from [0.5, 1.5, 7, 32, 72].${NC}" ;;
    esac
done

# Cleanup function (no JSON file deletion)
cleanup() {
    echo -e "${YELLOW}${BOLD}🛑 Terminating processes...${NC}"
    kill $SERVER_PID 2>/dev/null || true
    kill $TUNNEL_PID 2>/dev/null || true
    exit 0
}

trap cleanup INT

sleep 2

# Always start the development server
cd modal-login
echo -e "\n${CYAN}${BOLD}📦 Installing npm dependencies...${NC}"
npm install --legacy-peer-deps

echo -e "\n${CYAN}${BOLD}🚀 Launching development server...${NC}"
if ! command -v ss &>/dev/null; then
    echo -e "${YELLOW}${BOLD}⚠️ 'ss' command missing. Installing iproute2...${NC}"
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y iproute2
    elif command -v yum &>/dev/null; then
        sudo yum install -y iproute
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy iproute2
    else
        echo -e "${RED}${BOLD}❌ Unable to install 'ss'. Package manager not found.${NC}"
        exit 1
    fi
fi

PORT_LINE=$(ss -ltnp | grep ":3000 ")
if [ -n "$PORT_LINE" ]; then
    PID=$(echo "$PORT_LINE" | grep -oP 'pid=\K[0-9]+')
    if [ -n "$PID" ]; then
        echo -e "${YELLOW}${BOLD}⚠️ Port 3000 in use. Terminating process: $PID${NC}"
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
            echo -e "${GREEN}${BOLD}✅ Server running on port $PORT!${NC}"
            break
        fi
    fi
    sleep 1
done

if [ $i -eq $MAX_WAIT ]; then
    echo -e "${RED}${BOLD}❌ Server failed to start within time limit.${NC}"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Check for userData.json and skip tunnel setup if it exists
if [ -f "temp-data/userData.json" ]; then
    echo -e "${CYAN}${BOLD}✅ Found userData.json. Skipping tunnel setup...${NC}"
    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' temp-data/userData.json)
    echo -e "${CYAN}${BOLD}✅ Organization ID set to: $ORG_ID${NC}"
    echo -e "${CYAN}${BOLD}✅ Using contract: $SWARM_CONTRACT${NC}"
    echo -e "${YELLOW}${BOLD}⚠️ Note: Ensure ORG_ID ($ORG_ID) matches the selected contract ($SWARM_CONTRACT). If not, re-login may be required.${NC}"
else
    echo -e "\n${PURPLE}${BOLD}🔗 Want to set up a tunnel (localtunnel, cloudflared, or ngrok)?${NC}"
    read -p "➡️ [Y/n]: " tunnel_choice
    tunnel_choice=${tunnel_choice:-N}

    if [[ $tunnel_choice =~ ^[Yy]$ ]]; then
        # Tunnel setup functions
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
                echo -e "${GREEN}${BOLD}✅ Localtunnel already installed.${NC}"
                return 0
            fi
            echo -e "\n${CYAN}${BOLD}📦 Installing localtunnel...${NC}"
            npm install -g localtunnel > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}${BOLD}✅ Localtunnel installed successfully.${NC}"
                return 0
            else
                echo -e "${RED}${BOLD}❌ Failed to install localtunnel.${NC}"
                return 1
            fi
        }

        install_cloudflared() {
            if command -v cloudflared >/dev/null 2>&1; then
                echo -e "${GREEN}${BOLD}✅ Cloudflared already installed.${NC}"
                return 0
            fi
            echo -e "\n${CYAN}${BOLD}📦 Installing cloudflared...${NC}"
            CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH"
            wget -q --show-progress "$CF_URL" -O cloudflared
            if [ $? -ne 0 ]; then
                echo -e "${RED}${BOLD}❌ Failed to download cloudflared.${NC}"
                return 1
            fi
            chmod +x cloudflared
            sudo mv cloudflared /usr/local/bin/
            if [ $? -ne 0 ]; then
                echo -e "${RED}${BOLD}❌ Failed to move cloudflared to /usr/local/bin/.${NC}"
                return 1
            fi
            echo -e "${GREEN}${BOLD}✅ Cloudflared installed successfully.${NC}"
            return 0
        }

        install_ngrok() {
            if command -v ngrok >/dev/null 2>&1; then
                echo -e "${GREEN}${BOLD}✅ ngrok already installed.${NC}"
                return 0
            fi
            echo -e "\n${CYAN}${BOLD}📦 Installing ngrok...${NC}"
            NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
            wget -q --show-progress "$NFROK_URL" -O ngrok.tgz
            if [ $? -ne 0 ]; then
                echo -e "${RED}${BOLD}❌ Failed to download ngrok.${NC}"
                return 1
            fi
            tar -xzf ngrok.tgz
            if [ $? -ne 0 ]; then
                echo -e "${RED}${BOLD}❌ Failed to extract ngrok.${NC}"
                rm ngrok.tgz
                return 1
            fi
            sudo mv ngrok /usr/local/bin/
            if [ $? -ne 0 ]; then
                echo -e "${RED}${BOLD}❌ Failed to move ngrok to /usr/local/bin/.${NC}"
                rm ngrok.tgz
                return 1
            fi
            rm ngrok.tgz
            echo -e "${GREEN}${BOLD}✅ ngrok installed successfully.${NC}"
            return 0
        }

        try_localtunnel() {
            echo -e "\n${CYAN}${BOLD}🔗 Attempting localtunnel...${NC}"
            if install_localtunnel; then
                echo -e "\n${CYAN}${BOLD}🚀 Starting localtunnel on port $PORT...${NC}"
                TUNNEL_TYPE="localtunnel"
                lt --port $PORT > localtunnel_output.log 2>&1 &
                TUNNEL_PID=$!
                sleep 5
                URL=$(grep -o "https://[^ ]*" localtunnel_output.log | head -n1)
                if [ -n "$URL" ]; then
                    PASS=$(curl -s https://loca.lt/mytunnelpassword)
                    FORWARDING_URL="$URL"
                    echo -e "${GREEN}${BOLD}✅ Success! Visit this URL: ${YELLOW}${BOLD}${URL}${GREEN}${BOLD} and enter password: ${YELLOW}${BOLD}${PASS}${GREEN}${BOLD} to log in with your email.${NC}"
                    return 0
                else
                    echo -e "${RED}${BOLD}❌ Failed to retrieve localtunnel URL.${NC}"
                    kill $TUNNEL_PID 2>/dev/null || true
                fi
            fi
            return 1
        }

        try_cloudflared() {
            echo -e "\n${CYAN}${BOLD}🔗 Attempting cloudflared...${NC}"
            if install_cloudflared; then
                echo -e "\n${CYAN}${BOLD}🚀 Starting cloudflared tunnel...${NC}"
                TUNNEL_TYPE="cloudflared"
                cloudflared tunnel --url http://localhost:$PORT > cloudflared_output.log 2>&1 &
                TUNNEL_PID=$!
                counter=0
                MAX_WAIT=10
                while [ $counter -lt $MAX_WAIT ]; do
                    CLOUDFLARED_URL=$(grep -o 'https://[^ ]*\.trycloudflare.com' cloudflared_output.log | head -n1)
                    if [ -n "$CLOUDFLARED_URL" ]; then
                        echo -e "${GREEN}${BOLD}✅ Cloudflared tunnel started!${NC}"
                        echo -e "\n${CYAN}${BOLD}🔍 Verifying cloudflared URL...${NC}"
                        if check_url "$CLOUDFLARED_URL"; then
                            FORWARDING_URL="$CLOUDFLARED_URL"
                            return 0
                        else
                            echo -e "${RED}${BOLD}❌ Cloudflared URL not accessible.${NC}"
                            kill $TUNNEL_PID 2>/dev/null || true
                            break
                        fi
                    fi
                    sleep 1
                    counter=$((counter + 1))
                done
                kill $TUNNEL_PID 2>/dev/null || true
            fi
            return 1
        }

        get_ngrok_url_method1() {
            local url=$(grep -o '"url":"https://[^"]*' ngrok_output.log 2>/dev/null | head -n1 | cut -d'"' -f4)
            echo "$url"
        }

        get_ngrok_url_method2() {
            local try_port
            local url=""
            for try_port in $(seq 4040 4045); do
                local response=$(curl -s "http://localhost:$try_port/api/tunnels" 2>/dev/null)
                if [ -n "$response" ]; then
                    url=$(echo "$response" | grep -o '"public_url":"https://[^"]*' | head -n1 | cut -d'"' -f4)
                    if [ -n "$url" ]; then
                        break
                    fi
                fi
            done
            echo "$url"
        }

        get_ngrok_url_method3() {
            local url=$(grep -o "Forwarding.*https://[^ ]*" ngrok_output.log 2>/dev/null | grep -o "https://[^ ]*" | head -n1)
            echo "$url"
        }

        try_ngrok() {
            echo -e "\n${CYAN}${BOLD}🔗 Attempting ngrok...${NC}"
            if install_ngrok; then
                TUNNEL_TYPE="ngrok"
                while true; do
                    echo -e "\n${YELLOW}${BOLD}🔑 To get your ngrok authtoken:${NC}"
                    echo "1. Sign up or log in at https://dashboard.ngrok.com"
                    echo "2. Navigate to 'Your Authtoken': https://dashboard.ngrok.com/get-started/your-authtoken"
                    echo "3. Reveal and copy your ngrok auth token"
                    echo -e "\n${BOLD}Enter your ngrok authtoken:${NC}"
                    read -p "➡️ " NGROK_TOKEN
                    if [ -z "$NGROK_TOKEN" ]; then
                        echo -e "${RED}${BOLD}❌ Please provide a valid token.${NC}"
                        continue
                    fi
                    pkill ngrok || true
                    sleep 2
                    ngrok authtoken "$NGROK_TOKEN" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}${BOLD}✅ ngrok authenticated successfully!${NC}"
                        break
                    else
                        echo -e "${RED}${BOLD}❌ Authentication failed. Verify your token and try again.${NC}"
                    fi
                done

                echo -e "\n${CYAN}${BOLD}🚀 Starting ngrok (method 1)...${NC}"
                ngrok http "$PORT" --log=stdout --log-format=json > ngrok_output.log 2>&1 &
                TUNNEL_PID=$!
                sleep 5
                NGROK_URL=$(get_ngrok_url_method1)
                if [ -n "$NGROK_URL" ]; then
                    FORWARDING_URL="$NGROK_URL"
                    return 0
                else
                    echo -e "${RED}${BOLD}❌ Failed to get ngrok URL (method 1).${NC}"
                    kill $TUNNEL_PID 2>/dev/null || true
                fi

                echo -e "\n${CYAN}${BOLD}🚀 Starting ngrok (method 2)...${NC}"
                ngrok http "$PORT" > ngrok_output.log 2>&1 &
                TUNNEL_PID=$!
                sleep 5
                NGROK_URL=$(get_ngrok_url_method2)
                if [ -n "$NGROK_URL" ]; then
                    FORWARDING_URL="$NGROK_URL"
                    return 0
                else
                    echo -e "${RED}${BOLD}❌ Failed to get ngrok URL (method 2).${NC}"
                    kill $TUNNEL_PID 2>/dev/null || true
                fi

                echo -e "\n${CYAN}${BOLD}🚀 Starting ngrok (method 3)...${NC}"
                ngrok http "$PORT" --log=stdout > ngrok_output.log 2>&1 &
                TUNNEL_PID=$!
                sleep 5
                NGROK_URL=$(get_ngrok_url_method3)
                if [ -n "$NGROK_URL" ]; then
                    FORWARDING_URL="$NGROK_URL"
                    return 0
                else
                    echo -e "${RED}${BOLD}❌ Failed to get ngrok URL (method 3).${NC}"
                    kill $TUNNEL_PID 2>/dev/null || true
                fi
            fi
            return 1
        }

        start_tunnel() {
            if try_localtunnel; then
                return 0
            fi
            if try_cloudflared; then
                return 0
            fi
            if try_ngrok; then
                return 0
            fi
            return 1
        }

        start_tunnel
        if [ $? -eq 0 ]; then
            if [ "$TUNNEL_TYPE" != "localtunnel" ]; then
                echo -e "${GREEN}${BOLD}✅ Success! Visit ${CYAN}${BOLD}${FORWARDING_URL}${GREEN}${BOLD} and log in with your email.${NC}"
            fi
        else
            echo -e "\n${BLUE}${BOLD}ℹ️ Manual tunnel setup instructions:${NC}"
            echo "1. Open a new terminal tab in this WSL/VPS or GPU server"
            echo "2. Run: ngrok http $PORT"
            echo "3. You'll get a URL like: https://xxxx.ngrok-free.app"
            echo "4. Visit the URL and log in with your email (may take ~30s to load)"
            echo "5. Return to this tab to continue"
        fi

        echo -e "\n${CYAN}${BOLD}⏳ Awaiting login completion...${NC}"
        MAX_WAIT_LOGIN=60
        counter=0
        while [ ! -f "temp-data/userData.json" ]; do
            sleep 3
            counter=$((counter + 3))
            if [ $counter -ge $MAX_WAIT_LOGIN ]; then
                echo -e "${RED}${BOLD}❌ Timeout waiting for login. Please complete login manually and retry.${NC}"
                exit 1
            fi
        done

        echo -e "\n${CYAN}${BOLD}⏳ Waiting for API key activation...${NC}"
        if ! nc -z localhost 3000 >/dev/null 2>&1; then
            echo -e "${RED}${BOLD}❌ Server not running on port 3000. Check server.log for errors.${NC}"
            cat server.log 2>/dev/null || true
            exit 1
        fi
        MAX_WAIT_API=120
        counter=0
        while true; do
            STATUS=$(curl -s "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID")
            if [[ "$STATUS" == "activated" ]]; then
                echo -e "${GREEN}${BOLD}✅ API key activated! Proceeding...${NC}"
                break
            else
                echo -e "${CYAN}${BOLD}⏳ Still waiting for API key activation...${NC}"
                sleep 5
                counter=$((counter + 5))
                if [ $counter -ge $MAX_WAIT_API ]; then
                    echo -e "${RED}${BOLD}❌ Timeout waiting for API key activation. Check server and retry.${NC}"
                    exit 1
                fi
            fi
        done

        ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' temp-data/userData.json)
        echo -e "${CYAN}${BOLD}✅ Organization ID set to: $ORG_ID${NC}"
        echo -e "${CYAN}${BOLD}✅ Using contract: $SWARM_CONTRACT${NC}"
        echo -e "${YELLOW}${BOLD}⚠️ Note: Ensure ORG_ID ($ORG_ID) matches the selected contract ($SWARM_CONTRACT). If not, re-login may be required.${NC}"
    else
        echo -e "${YELLOW}${BOLD}⚠️ Tunnel setup skipped. Ensure userData.json exists from a manual login.${NC}"
        if [ ! -f "temp-data/userData.json" ]; then
            echo -e "${RED}${BOLD}❌ userData.json missing. Please log in manually to create it and retry.${NC}"
            exit 1
        fi
        ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' temp-data/userData.json)
        echo -e "${CYAN}${BOLD}✅ Organization ID set to: $ORG_ID${NC}"
        echo -e "${CYAN}${BOLD}✅ Using contract: $SWARM_CONTRACT${NC}"
        echo -e "${YELLOW}${BOLD}⚠️ Note: Ensure ORG_ID ($ORG_ID) matches the selected contract ($SWARM_CONTRACT). If not, re-login may be required.${NC}"
    fi
fi

cd ..

echo -e "${GREEN}${BOLD}✅ userData.json ready! Moving to next steps...${NC}"
rm -f modal-login/server.log modal-login/localtunnel_output.log modal-login/cloudflared_output.log modal-login/ngrok_output.log

# Set up .env file (mimicking script 1)
ENV_FILE="$ROOT/modal-login/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${CYAN}${BOLD}📝 Creating .env file at $ENV_FILE${NC}"
    touch "$ENV_FILE"
    echo -e "# .env file for modal-login\nSMART_CONTRACT_ADDRESS=\n" > "$ENV_FILE"
fi
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
else
    sed -i "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
fi
echo -e "${CYAN}${BOLD}📄 .env file contents:${NC}"
cat "$ENV_FILE"

# Set up Python virtual environment
echo -e "\n${CYAN}${BOLD}🐍 Preparing Python virtual environment...${NC}"
python3 -m venv .venv && . .venv/bin/activate && \
echo -e "${GREEN}${BOLD}✅ Virtual environment created successfully!${NC}" || \
echo -e "${RED}${BOLD}❌ Failed to create virtual environment.${NC}"

# Configure based on GPU/CPU and parameters
if [ -z "$CONFIG_PATH" ]; then
    if command -v nvidia-smi &> /dev/null || [ -d "/proc/driver/nvidia" ]; then
        echo -e "${GREEN}${BOLD}✅ GPU detected!${NC}"
        case "$PARAM_B" in
            32 | 72) 
                CONFIG_PATH="$ROOT/hivemind_exp/configs/gpu/grpo-qwen-2.5-${PARAM_B}b-bnb-4bit-deepseek-r1.yaml"
                ;;
            0.5 | 1.5 | 7) 
                CONFIG_PATH="$ROOT/hivemind_exp/configs/gpu/grpo-qwen-2.5-${PARAM_B}b-deepseek-r1.yaml"
                ;;
            *)  
                echo -e "${YELLOW}${BOLD}⚠️ Unrecognized parameter size. Defaulting to 0.5b.${NC}"
                CONFIG_PATH="$ROOT/hivemind_exp/configs/gpu/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
                ;;
        esac
        if [ "$USE_BIG_SWARM" = true ]; then
            GAME="dapo"
        else
            GAME="gsm8k"
        fi
        echo -e "${CYAN}${BOLD}📜 Config file: $CONFIG_PATH${NC}"
        echo -e "${CYAN}${BOLD}📦 Installing GPU requirements...${NC}"
        pip install -r "$ROOT"/requirements-gpu.txt
        pip install flash-attn --no-build-isolation
    else
        echo -e "${YELLOW}${BOLD}⚠️ No GPU detected. Using CPU configuration.${NC}"
        pip install -r "$ROOT"/requirements-cpu.txt
        case "$PARAM_B" in
            0.5 | 1.5) 
                CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-${PARAM_B}b-deepseek-r1.yaml"
                ;;
            *)  
                echo -e "${YELLOW}${BOLD}⚠️ Unrecognized parameter size for CPU. Defaulting to 0.5b.${NC}"
                CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
                ;;
        esac
        GAME="gsm8k"
        echo -e "${CYAN}${BOLD}📜 Config file: $CONFIG_PATH${NC}"
    fi
fi

# Prompt for Hugging Face token
if [ -n "${HF_TOKEN}" ]; then
    HUGGINGFACE_ACCESS_TOKEN=${HF_TOKEN}
else
    echo -e "\n${PURPLE}${BOLD}🤗 Want to push trained models to Hugging Face Hub?${NC}"
    read -p "➡️ [y/N]: " yn
    yn=${yn:-N}
    case $yn in
        [Yy]* ) 
            echo -e "${PURPLE}${BOLD}🔑 Enter your Hugging Face access token:${NC}"
            read -p "➡️ " HUGGINGFACE_ACCESS_TOKEN ;;
        [Nn]* ) HUGGINGFACE_ACCESS_TOKEN="None" ;;
        * ) 
            echo -e "${YELLOW}${BOLD}⚠️ No input provided. Models will not be pushed to Hugging Face Hub.${NC}"
            HUGGINGFACE_ACCESS_TOKEN="None" ;;
    esac
fi

# Final setup and execution
echo -e "\n${GREEN}${BOLD}🎉 Best of luck in the swarm! Training is starting...${NC}"
[ "$(uname)" = "Darwin" ] && sed -i '' -E -e 's/(startup_timeout: *float *= *)[0-9.]+/\1120/' -e '/startup_timeout: float = 120,/a\'$'\n''    bootstrap_timeout: float = 120,' -e '/anonymous_p2p = await cls\.create\(/a\'$'\n''        bootstrap_timeout=120,' $(python3 -c "import hivemind.p2p.p2p_daemon as m; print(m.__file__)") || sed -i -E -e 's/(startup_timeout: *float *= *)[0-9.]+/\1120/' -e '/startup_timeout: float = 120,/a\    bootstrap_timeout: float = 120,' -e '/anonymous_p2p = await cls\.create\(/a\        bootstrap_timeout=120,' $(python3 -c "import hivemind.p2p.p2p_daemon as m; print(m.__file__)")

[ "$(uname)" = "Darwin" ] && sed -i '' -e 's/bootstrap_timeout: Optional\[float\] = None/bootstrap_timeout: float = 120/' -e 's/p2p = await P2P.create(\*\*kwargs)/p2p = await P2P.create(bootstrap_timeout=120, **kwargs)/' $(python3 -c 'import hivemind.dht.node as m; print(m.__file__)') || sed -i -e 's/bootstrap_timeout: Optional\[float\] = None/bootstrap_timeout: float = 120/' -e 's/p2p = await P2P.create(\*\*kwargs)/p2p = await P2P.create(bootstrap_timeout=120, **kwargs)/' $(python3 -c 'import hivemind.dht.node as m; print(m.__file__)')

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
