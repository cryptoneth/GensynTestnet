# GensynTestnet

- GensynTestnet - Join Swarm Now

<img width="885" alt="GnuWoJLXUAApSDN" src="https://github.com/user-attachments/assets/4487f132-7fc0-4986-90cf-468da306b773" />

## 💻 System Requirements
 
 | Requirement                        | Details                                                                                      |
 |-------------------------------------|---------------------------------------------------------------------------------------------|
 | **CUDA Devices (Recommended)**      | `RTX 3090`, `RTX 4090`, `A100`, `H100`                                                      |
 | **CPU Architecture**                | `arm64` or `amd64`                                                                          |
 | **Recommended RAM**                 | + 24 GB                                                                                     |

===========================================================================

## First Step 
- Rent GPU -

https://cloud.vast.ai

https://app.hyperbolic.xyz/

https://console.quickpod.io

**RTX 3090** 
**RTX 4090** 
**A100** 
**H100** 

Note: You can run the node without a GPU using CPU-only mode.

===========================================================================

## 2 Step 

- Connect To Your Server -

1 - open powershell on windows

2 - ```ssh-keygen -t rsa```

3 - press enter to save the file 

4 - copy your public key ( SSH )

```Get-Content C:\Users\crypton/.ssh/id_rsa.pub | Set-Clipboard```

5 - go back to the website and define ssh key for your servers

6 - get your private key on your windows powershell 

``` Get-Content C:\Users\crypton/.ssh/id_rsa | Set-Clipboard ```

7 - go to termius and set a keychain with your private and public key

8 - right now add a new host with ip and port ( your provider will give you )

Done 

===========================================================================


1. **Install `sudo`**
 ```bash
 apt update && apt install -y sudo
 ```
 2. **Install other dependencies**
 ```bash
 sudo apt update && sudo apt install -y python3 python3-venv python3-pip curl wget screen git && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - && echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list && sudo apt update && sudo apt install -y yarn
 ```

 **3. Install Python**
 ```bash
 sudo apt-get install python3 python3-pip python3-venv python3-dev -y
 ```
 
 **4. Install Node**
 ```
 sudo apt-get update
 ```
 ```
 curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
 ```
 ```
 sudo apt-get install -y nodejs
 ```
 ```
 node -v
 ```
 ```bash
 sudo npm install -g yarn
 ```
 ```bash
 yarn -v
 ```
 
 **5. Install Yarn**
 ```bash
 curl -o- -L https://yarnpkg.com/install.sh | bash
 ```
 ```bash
 export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
 ```
 ```bash
 source ~/.bashrc
 ```

 ## Get HuggingFace Access token
 **1- Create account in [HuggingFace](https://huggingface.co/)**
 
 **2- Create an Access Token with `Write` permissions [here](https://huggingface.co/settings/tokens) and save it**
 
 ---
 
 ## 3) Clone the Repository

 ```bash
 git clone https://github.com/gensyn-ai/rl-swarm/
 cd rl-swarm
 ```
 
 ---
 
 ## 4) Run the swarm
 Open a screen to run it in background
 ```bash
 screen -S swarm
 ```
 Install swarm

 ```
 pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
 ```

 ```bash
 python3 -m venv .venv
 source .venv/bin/activate
 ./run_rl_swarm.sh
 ```
 Press `Y`
 ---

## 5) Login

 Press `Crtl + A + D` to exit the screen
 ---

```
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz && tar -xvzf ngrok-v3-stable-linux-amd64.tgz && sudo mv ngrok /usr/local/bin/
```

Get the token from: https://dashboard.ngrok.com/get-started/your-authtoken.

Paste the token into the VPS and also paste this into the VPS:
``` ngrok http 3000 ```

Then Open Link And Connect To Gensyn Testnet with you Email

## 6) Backup
 **1- Node name**
 * Now your node started running, Find your name after word `Hello`, like mine is `whistling hulking armadillo` as in the image below (You can use `CTRL+SHIFT+F` to search Hello in terminal)
 
 ![image](https://github.com/user-attachments/assets/a1abdb1a-aa11-407f-8e5b-abe7d0a6b0f3)
 
 **2- Node `.pem` file**
 * Save `swarm.pem` file in this directory: `/root/rl-swarm/`
 
 ---
 
 ### Screen commands
 * Minimize: `CTRL` + `A` + `D`
 * Return: `screen -r swarm`
 * Stop and Kill: `screen -XS swarm quit`

Done, Welcome To Swarm
![1500x500 (1)](https://github.com/user-attachments/assets/ef2be4d2-f1a5-4592-8173-05aadd91cdab)


