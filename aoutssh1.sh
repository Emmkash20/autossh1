#!/bin/bash

# VPS Auto Script to install and configure SSH, V2Ray, Xray (VMess, Trojan, VLess)
# Supports Ubuntu and Debian
# Author: Emmksh20
# GitHub:https://github.com/Emmkash20
# Script by Emmkash Technologies

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
RESET='\033[0m'

# Function to detect distribution
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
  else
    echo "Unsupported OS."
    exit 1
  fi

  if [ "$OS" != "ubuntu" ] && [ "$OS" != "debian" ]; then
    echo "This script supports only Ubuntu and Debian."
    exit 1
  fi
}

# Function to update system packages
update_system() {
  echo "Updating system..."
  sudo apt-get update -y
  sudo apt-get upgrade -y
}

# Function to install and configure SSH
install_ssh() {
  if ! dpkg -l | grep -q openssh-server; then
    echo "Installing OpenSSH Server..."
    sudo apt-get install -y openssh-server
  else
    echo "OpenSSH Server is already installed."
  fi

  echo "Starting and enabling SSH service..."
  sudo systemctl start ssh
  sudo systemctl enable ssh

  echo "SSH installation completed. You can now connect using SSH."
}

# Function to create an SSH user with expiry in days and connection limit
create_ssh_user() {
  echo "Enter username for SSH account: "
  read username
  echo "Enter password for SSH account: "
  read -s password
  echo "Enter number of days until account expires: "
  read expiry_days
  echo "Enter number of simultaneous connections allowed: "
  read connection_limit

  sudo useradd -m $username
  echo "$username:$password" | sudo chpasswd

  # Calculate expiry date
  expiry_date=$(date -d "+$expiry_days days" +%Y-%m-%d)
  sudo chage -E $expiry_date $username

  # Set max connections in SSH config
  sudo sed -i "/^MaxSessions/c\MaxSessions $connection_limit" /etc/ssh/sshd_config

  echo "SSH user $username created with expiry in $expiry_days days and connection limit of $connection_limit."
}

# Function to check online users (SSH connected users)
check_online_users() {
  echo "Checking online users..."
  who | awk '{print $1}'
}

# Function to delete SSH user
delete_user() {
  echo "Enter the username to delete: "
  read del_user

  sudo deluser --remove-home $del_user
  echo "User $del_user deleted successfully."
}

# Function to check open ports
check_ports() {
  echo "Checking open ports..."
  sudo netstat -tuln | grep LISTEN
}

# Function to reboot the server
reboot_server() {
  echo "Rebooting server..."
  sudo reboot
}

# Function to change SSH banner
change_banner() {
  echo "Enter a new banner message: "
  read new_banner

  echo "$new_banner" | sudo tee /etc/issue.net
  sudo sed -i 's/#Banner none/Banner \/etc\/issue.net/' /etc/ssh/sshd_config
  sudo systemctl restart ssh

  echo "Banner changed successfully."
}

# Function to install and configure V2Ray
install_v2ray() {
  if ! command -v v2ray &> /dev/null; then
    echo "Installing V2Ray..."

    bash <(curl -L https://install.direct/go.sh)
  else
    echo "V2Ray is already installed."
  fi

  cat <<EOF >/etc/v2ray/config.json
{
  "inbounds": [
    {
      "port": 1080,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true,
        "ip": "127.0.0.1"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 8080,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$(uuidgen)",
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ray"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

  sudo systemctl start v2ray
  sudo systemctl enable v2ray

  echo "V2Ray installed and configured."
}

# Function to create V2Ray user account (VMess, VLess, Trojan, Xray support)
create_v2ray_account() {
  echo "Enter user ID for V2Ray account: "
  user_id=$(uuidgen)
  echo "New V2Ray account UUID: $user_id"

  cat <<EOF >>/etc/v2ray/config.json
  {
    "id": "$user_id",
    "alterId": 64
  }
EOF

  sudo systemctl restart v2ray
  echo "V2Ray account created with UUID $user_id."
}

# Install Xray for additional protocols (VMess, Trojan, VLess)
install_xray() {
  if ! command -v xray &> /dev/null; then
    echo "Installing Xray..."
    
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
  else
    echo "Xray is already installed."
  fi

  # Basic configuration for Xray
  cat <<EOF >/usr/local/etc/xray/config.json
{
  "inbounds": [
    {
      "port": 10086,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$(uuidgen)",
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
        "network": "tcp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

  sudo systemctl start xray
  sudo systemctl enable xray

  echo "Xray installed with VMess, VLess, and Trojan support."
}

# Function to monitor and disable users with multiple logins
monitor_multiple_logins() {
  echo "Monitoring multiple logins..."

  # List of users with multiple sessions
  users=$(who | awk '{print $1}' | sort | uniq -d)
  if [ -n "$users" ]; then
    for user in $users; do
      echo "Disabling user $user due to multiple logins..."
      sudo usermod -L $user
      echo "$user has been locked due to multiple logins."
    done
  else
    echo "No users with multiple logins found."
  fi
}

# Menu function
menu() {
  clear
  echo -e "${BLUE}==============================="
  echo -e " VPS Setup Script"
  echo -e " Script by ${PURPLE}Emmkash Technologies${RESET}"
  echo -e "${BLUE}===============================${RESET}"
  echo -e "${GREEN}1.${RESET} ${CYAN}Update System${RESET}           | ${GREEN}2.${RESET} ${CYAN}Install SSH${RESET}            | ${GREEN}3.${RESET} ${CYAN}Create SSH Account${RESET}"
  echo -e "${GREEN}4.${RESET} ${CYAN}Check Online Users${RESET}    | ${GREEN}5.${RESET} ${CYAN}Delete User${RESET}            | ${GREEN}6.${RESET} ${CYAN}Check Open Ports${RESET}"
  echo -e "${GREEN}7.${RESET} ${CYAN}Reboot Server${RESET}         | ${GREEN}8.${RESET} ${CYAN}Change SSH Banner${RESET}      | ${GREEN}9.${RESET} ${CYAN}Install V2Ray${RESET}"
  echo -e "${GREEN}10.${RESET} ${CYAN}Create V2Ray Account${RESET} | ${GREEN}11.${RESET} ${CYAN}Install Xray (VMess, VLess, Trojan)${RESET} | ${GREEN}12.${RESET} ${CYAN}Monitor Multiple Logins${RESET} | ${GREEN}13.${RESET} ${CYAN}Exit${RESET}"
  echo -e "${BLUE}===============================${RESET}"
  echo -n "Choose an option [1-13]: "
  read option

  case $option in
    1)
      update_system
      ;;
    2)
      install_ssh
      ;;
    3)
      create
