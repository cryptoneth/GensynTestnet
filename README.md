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

2 -  

```bash
ssh-keygen -t rsa 
```

3 - press enter to save the file 

4 - copy your public key ( SSH )

Replace Your Address
```bash
Get-Content C:\Users\.../.ssh/id_rsa.pub | Set-Clipboard
```

5 - go back to the website and define ssh key for your servers

6 - get your private key on your windows powershell 

Replace Your Address
```bash
Get-Content C:\Users\.../.ssh/id_rsa | Set-Clipboard 
```

7 - go to termius and set a keychain with your private and public key

8 - right now add a new host with ip and port ( your provider will give you )

Done 

===========================================================================


1. **Install `sudo` and other dependencies**
 ```bash
 apt update && apt install -y sudo 
sudo apt update && sudo apt install -y python3 python3-venv python3-pip curl wget screen git && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - && echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list && sudo apt update && sudo apt install -y yarn
 ```

 **3. Install Python**
 ```bash
 sudo apt-get install python3 python3-pip python3-venv python3-dev -y
 ```
 
 **4. Install Node**

 ```bash
 sudo apt-get update
 curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
 sudo apt-get install -y nodejs
 node -v
 yarn -v
 ```


 ## Get HuggingFace Access token
 **1- Create account in [HuggingFace](https://huggingface.co/)**
 
 **2- Create an Access Token with `Write` permissions [here](https://huggingface.co/settings/tokens) and save it**
 
 ---
 
 ## 3) Clone the Repository

 ```bash
 git clone https://github.com/gensyn-ai/rl-swarm/
 git clone https://github.com/cryptoneth/GensynTestnet
 mv GensynTestnet/run_rl_swarm.sh rl-swarm/run_rl_swarm.sh
 cd rl-swarm
 ```

 ## 4) Run the swarm
 Open a screen to run it in background
 ```bash
 screen -S gensyn
 ```
 Install swarm

 ```
 pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
 ```

 ```bash
python3 -m venv .venv && . .venv/bin/activate &&  chmod +x ./run_rl_swarm.sh && ./run_rl_swarm.sh
 ```
 Press `Y`
 ---

## 5) Login

go to ngrok
Get the token from: https://dashboard.ngrok.com/get-started/your-authtoken

paste your AuthToken

Then Open Link And Connect To Gensyn Testnet with your Email

Then Paste Your Hugging Face Token

Every Things Fine Right Now 

Just Copy Your Node Name And Wait For Correct Log

Press Crtl + A + D

## 6) Backup
 **1- Node name**
 * Now your node started running, Find your name after word `Hello`, like mine is `whistling hulking armadillo` as in the image below (You can use `CTRL+SHIFT+F` to search Hello in terminal)
 
 **2-  Save `swarm.pem` file in this directory: `/root/rl-swarm/`

and make sure to back up these 


```bash
cd
nano rl-swarm/modal-login/temp-data/userData.json
```
```bash
cd
nano rl-swarm/modal-login/temp-data/userApiKey.json
```
 
 ---
 
 ### Screen commands
 * Minimize: `CTRL` + `A` + `D`
 * Return: `screen -r swarm`
 * Stop and Kill: `screen -XS swarm quit`

---

Track Your Node With this Bot on Tg

@gensyntrackbot

Example : /check QmZPwBPynMxz56tTaj25QFXdo2YFHA....

Done, Welcome To Swarm
![1500x500 (1)](https://github.com/user-attachments/assets/ef2be4d2-f1a5-4592-8173-05aadd91cdab)


