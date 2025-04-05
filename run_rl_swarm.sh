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

print_step() {
    echo -e "\n${CYAN}${BOLD}Step $1: $2${NC}"
}

check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success!${NC}"
    else
        echo -e "${RED}✗ Failed! Please check errors above and try again.${NC}"
        exit 1
    fi
}

# Export environment variables
export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS
export IDENTITY_PATH
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120

# Set default values for environment variables if not already defined
DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ"
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

if [ -f "modal-login/temp-data/userData.json" ]; then
    cd modal-login
    source ~/.bashrc

    # Install npm if not present
    if ! command -v npm >/dev/null 2>&1; then
        echo -e "${YELLOW}npm is not installed. Installing Node.js and npm...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
        source ~/.bashrc
    fi

    echo -e "\n${CYAN}Installing dependencies with npm. This may take a few minutes, depending on your internet speed...${NC}"
    npm install --legacy-peer-deps

    # Start the development server in the background
    echo -e "\n${CYAN}Starting the development server...${NC}"
    npm run dev > server.log 2>&1 &
    SERVER_PID=$!
    MAX_WAIT=60
    counter=0
    while [ $counter -lt $MAX_WAIT ]; do
        if grep -q "Local:        http://localhost:" server.log; then
            PORT=$(grep "Local:        http://localhost:" server.log | sed -n 's/.*http:\/\/localhost:\([0-9]*\).*/\1/p')
            if [ -n "$PORT" ]; then
                echo -e "${GREEN}Server is running successfully on port $PORT\n${NC}"
                break
            fi
        fi
        sleep 1
        counter=$((counter + 1))
    done

    if [ $counter -eq $MAX_WAIT ]; then
        echo -e "${RED}Timeout waiting for server to start.${NC}"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    cd ..

    # Extract ORG_ID from userData.json
    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo -e "${CYAN}ORG_ID has been set to: ${BOLD}$ORG_ID\n${NC}"

    # Cleanup function for graceful shutdown
    cleanup() {
        echo -e "${YELLOW}Shutting down server and ngrok...${NC}"
        kill $SERVER_PID 2>/dev/null || true
        exit 0
    }

    trap cleanup INT
    
else
    cd modal-login
    source ~/.bashrc
    if ! command -v npm >/dev/null 2>&1; then
        echo -e "${YELLOW}npm is not installed. Installing Node.js and npm...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
        source ~/.bashrc
    fi
    echo -e "\n${CYAN}Installing dependencies with npm. This may take a few minutes, depending on your internet speed...${NC}"
    npm install --legacy-peer-deps

    # Start the development server in the background
    echo -e "\n${CYAN}Starting the development server...${NC}"
    npm run dev > server.log 2>&1 &
    SERVER_PID=$!
    MAX_WAIT=60
    counter=0
    while [ $counter -lt $MAX_WAIT ]; do
        if grep -q "Local:        http://localhost:" server.log; then
            PORT=$(grep "Local:        http://localhost:" server.log | sed -n 's/.*http:\/\/localhost:\([0-9]*\).*/\1/p')
            if [ -n "$PORT" ]; then
                echo -e "${GREEN}Server is running successfully on port $PORT.${NC}"
                break
            fi
        fi
        sleep 1
        counter=$((counter + 1))
    done

    if [ $counter -eq $MAX_WAIT ]; then
        echo -e "${RED}Timeout waiting for server to start.${NC}"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi

    print_step 1 "Detecting system architecture"
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    if [ "$ARCH" = "x86_64" ]; then
        NGROK_ARCH="amd64"
        echo -e "${GREEN}Detected x86_64 architecture.${NC}"
    elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
        NGROK_ARCH="arm64"
        echo -e "${GREEN}Detected ARM64 architecture.${NC}"
    elif [[ "$ARCH" == arm* ]]; then
        NGROK_ARCH="arm"
        echo -e "${GREEN}Detected ARM architecture.${NC}"
    else
        echo -e "${RED}Unsupported architecture: $ARCH. Please use a supported system.${NC}"
        exit 1
    fi

    print_step 2 "Downloading and installing ngrok"
    echo -e "${YELLOW}Downloading ngrok for $OS-$NGROK_ARCH...${NC}"
    wget -q --show-progress "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
    check_success

    echo -e "${YELLOW}Extracting ngrok...${NC}"
    tar -xzf "ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
    check_success

    echo -e "${YELLOW}Moving ngrok to /usr/local/bin/ (requires sudo)...${NC}"
    sudo mv ngrok /usr/local/bin/
    check_success

    echo -e "${YELLOW}Cleaning up temporary files...${NC}"
    rm "ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
    check_success

    print_step 3 "Authenticating ngrok"
    while true; do
        echo -e "\n${YELLOW}To get your authtoken:${NC}"
        echo "1. Sign up or log in at https://dashboard.ngrok.com"
        echo "2. Go to 'Your Authtoken' section: https://dashboard.ngrok.com/get-started/your-authtoken"
        echo "3. Click on the eye icon to reveal your ngrok auth token"
        echo "4. Copy that auth token and paste it in the prompt below"
        echo -e "\n${BOLD}Please enter your ngrok authtoken:${NC}"
        read -p "> " NGROK_TOKEN

        if [ -z "$NGROK_TOKEN" ]; then
            echo -e "${RED}No token provided. Please enter a valid token.${NC}"
            continue
        fi

        # Ensure any previous ngrok processes are killed before authentication
        pkill -f ngrok || true
        sleep 2

        ngrok authtoken "$NGROK_TOKEN"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Successfully authenticated ngrok!${NC}"
            break
        else
            echo -e "${RED}✗ Authentication failed. Please check your token and try again.${NC}"
        fi
    done

    print_step 4 "Preparing for ngrok tunnel"
    # Kill any existing ngrok processes
    pkill -f ngrok || true
    sleep 3

    # Find available ports for ngrok web interface
    NGROK_WEB_PORT=4040
    while lsof -i :$NGROK_WEB_PORT >/dev/null 2>&1; do
        echo -e "${YELLOW}Port $NGROK_WEB_PORT is in use. Trying next port...${NC}"
        NGROK_WEB_PORT=$((NGROK_WEB_PORT + 1))
    done
    echo -e "${GREEN}Will use port $NGROK_WEB_PORT for ngrok web interface.${NC}"

    print_step 5 "Starting ngrok tunnel on port $PORT"

    get_url_from_method1() {
        # Method 1: JSON log parsing
        local url=$(grep -o '"url":"https://[^"]*' ngrok_output.log 2>/dev/null | head -n1 | cut -d'"' -f4)
        echo "$url"
    }

    get_url_from_method2() {
        # Method 2: API approach with web interface port
        local url=""
        for try_port in $(seq $NGROK_WEB_PORT $((NGROK_WEB_PORT + 5))); do
            if curl -s "http://localhost:$try_port/api/tunnels" >/dev/null 2>&1; then
                url=$(curl -s "http://localhost:$try_port/api/tunnels" | grep -o '"public_url":"https://[^"]*' | head -n1 | cut -d'"' -f4)
                if [ -n "$url" ]; then
                    break
                fi
            fi
        done
        echo "$url"
    }

    get_url_from_method3() {
        # Method 3: Old-style output parsing
        local url=$(grep -m 1 "Forwarding" ngrok_output.log 2>/dev/null | grep -o "https://[^ ]*")
        echo "$url"
    }

    get_url_from_method4() {
        # Method 4: Alternative approach with explicit region  
        # Kill existing ngrok process and restart with explicit settings
        kill $NGROK_PID 2>/dev/null || true
        sleep 3
        
        ngrok http --region us --log=stdout "$PORT" > ngrok_output_alt.log 2>&1 &
        NGROK_PID=$!
        
        sleep 10
        
        # Try to extract URL from alternative log
        local url=$(grep -o '"url":"https://[^"]*' ngrok_output_alt.log 2>/dev/null | head -n1 | cut -d'"' -f4)
        
        # If that fails, try API on multiple ports
        if [ -z "$url" ]; then
            for check_port in $(seq 4040 4050); do
                if curl -s "http://localhost:$check_port/api/tunnels" >/dev/null 2>&1; then
                    url=$(curl -s "http://localhost:$check_port/api/tunnels" | grep -o '"public_url":"https://[^"]*' | head -n1 | cut -d'"' -f4)
                    if [ -n "$url" ]; then
                        break
                    fi
                fi
            done
        fi
        
        echo "$url"
    }

    # Start ngrok with default configuration first
    ngrok http "$PORT" --log=stdout --log-format=json --log-level=info > ngrok_output.log 2>&1 &
    NGROK_PID=$!
    sleep 5

    # Try all methods in sequence  
    echo -e "\n${PURPLE}Trying method 1...${NC}"
    FORWARDING_URL=$(get_url_from_method1)
    
    if [ -z "$FORWARDING_URL" ]; then
        echo -e "\n${PURPLE}Method 1 failed. Trying method 2...${NC}"
        FORWARDING_URL=$(get_url_from_method2)
    fi
    
    if [ -z "$FORWARDING_URL" ]; then
        echo -e "\n${PURPLE}Method 2 failed. Trying method 3...${NC}"
        FORWARDING_URL=$(get_url_from_method3)
    fi
    
    if [ -z "$FORWARDING_URL" ]; then
        echo -e "\n${PURPLE}Method 3 failed. Trying method 4...${NC}"
        FORWARDING_URL=$(get_url_from_method4)
    fi

    if [ -n "$FORWARDING_URL" ]; then
        echo -e "${GREEN}${BOLD}✓ Success! Please visit this website and log in using your email:${NC} ${CYAN}${BOLD}${FORWARDING_URL}${NC}"
    else
        echo -e "\n${BLUE}Don't worry, you can use this manual method. Please follow these instructions:${NC}"
        echo "1. Open Command Prompt on your PC."
        echo -e "2. Paste this command into Command Prompt: ssh -L 3000:localhost:$PORT $(whoami)@$(curl -s ifconfig.me)"
        echo "3. After connecting, visit this website and log in using your email: http://localhost:3000/"
        echo "4. Please note that the website may take up to 1 minute to be fully ready."
        kill $NGROK_PID 2>/dev/null || true
    fi

    cd ..
    echo -e "\n${CYAN}Waiting for you to complete the login process...${NC}"
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        sleep 3
    done
    echo -e "${GREEN}${BOLD}✓ Success! The userData.json file has been created. Proceeding with remaining setups...${NC}"

    # Extract ORG_ID from userData.json
    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo -e "\n${CYAN}ORG_ID has been set to: ${BOLD}$ORG_ID\n${NC}"

    # Cleanup function for graceful shutdown
    cleanup() {
        echo -e "${YELLOW}Shutting down server and ngrok processes...${NC}"
        kill $SERVER_PID 2>/dev/null || true
        kill $NGROK_PID 2>/dev/null || true
        exit 0
    }

    trap cleanup INT
fi

# Install Python requirements
echo -e "${CYAN}Installing required Python packages...${NC}"
pip install -r "$ROOT"/requirements-hivemind.txt > /dev/null
pip install -r "$ROOT"/requirements.txt > /dev/null

# Determine config path based on hardware
if ! which nvidia-smi; then
    CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
elif [ -n "$CPU_ONLY" ]; then
    CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
else
    pip install -r "$ROOT"/requirements_gpu.txt > /dev/null
    CONFIG_PATH="$ROOT/hivemind_exp/configs/gpu/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
fi

echo -e "${GREEN}>>> Awesome, All packages installed successfully!\n${NC}"

# Handle Hugging Face token
if [ -n "${HF_TOKEN}" ]; then
    HUGGINGFACE_ACCESS_TOKEN=${HF_TOKEN}
else
    read -p "Would you like to push models you train in the RL swarm to the Hugging Face Hub? [y/N] " yn
    yn=${yn:-N}
    case $yn in
        [Yy]* ) read -p "Enter your Hugging Face access token: " HUGGINGFACE_ACCESS_TOKEN;;
        [Nn]* ) HUGGINGFACE_ACCESS_TOKEN="None";;
        * ) echo -e "${YELLOW}>>> No answer was given, so NO models will be pushed to the Hugging Face Hub.${NC}" && HUGGINGFACE_ACCESS_TOKEN="None";;
    esac
fi

echo -e "\n${GREEN}${BOLD}Good luck in the swarm! Your training session is about to begin.\n${NC}"

# Run the Python training script with appropriate parameters
if [ -n "$ORG_ID" ]; then
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --modal_org_id "$ORG_ID" \
        --config "$CONFIG_PATH"
else
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --public_maddr "$PUB_MULTI_ADDRS" \
        --initial_peers "$PEER_MULTI_ADDRS" \
        --host_maddr "$HOST_MULTI_ADDRS" \
        --config "$CONFIG_PATH"
fi

wait
