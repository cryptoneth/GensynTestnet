#!/bin/bash

BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
NC="\e[0m"

SWARM_DIR="$HOME/rl-swarm"
HOME_DIR="$HOME"

cd $HOME

if [ -f "$SWARM_DIR/swarm.pem" ]; then
    echo -e "${BOLD}${YELLOW}You already have an existing ${GREEN}swarm.pem${YELLOW} file.${NC}\n"
    echo -e "${BOLD}${YELLOW}Do you want to:${NC}"
    echo -e "${BOLD}1) Use the existing swarm.pem${NC}"
    echo -e "${BOLD}${RED}2) Delete existing swarm.pem and start fresh${NC}"

    while true; do
        read -p $'\e[1mEnter your choice (1 or 2): \e[0m' choice
        if [ "$choice" == "1" ]; then
            echo -e "\n${BOLD}${YELLOW}[✓] Using existing swarm.pem...${NC}"
            mv "$SWARM_DIR/swarm.pem" "$HOME_DIR/"

            rm -rf "$SWARM_DIR"

            echo -e "${BOLD}${YELLOW}[✓] Cloning fresh repository...${NC}"
            cd $HOME && git clone https://github.com/zunxbt/rl-swarm.git > /dev/null 2>&1

            mv "$HOME_DIR/swarm.pem" rl-swarm/
            break
        elif [ "$choice" == "2" ]; then
            echo -e "${BOLD}${YELLOW}[✓] Removing existing folder and starting fresh...${NC}"
            rm -rf "$SWARM_DIR"
            sleep 2
            cd $HOME && git clone https://github.com/zunxbt/rl-swarm.git > /dev/null 2>&1
            break
        else
            echo -e "\n${BOLD}${RED}[✗] Invalid choice. Please enter 1 or 2.${NC}"
        fi
    done
else
    echo -e "${BOLD}${YELLOW}[✓] No existing swarm.pem found. Cloning repository...${NC}"
    cd $HOME && [ -d rl-swarm ] && rm -rf rl-swarm; git clone https://github.com/zunxbt/rl-swarm.git > /dev/null 2>&1
fi

cd rl-swarm || { echo -e "${BOLD}${RED}[✗] Failed to enter rl-swarm directory. Exiting.${NC}"; exit 1; }

echo -e "${BOLD}${YELLOW}[✓] Running rl-swarm...${NC}"
./run_rl_swarm.sh
