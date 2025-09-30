# Zapret Installer Script

This is a simple Bash script to **download, install, and configure Zapret** on Linux systems. It also supports setting up **DNS over TLS**.

## Features

- Download the latest Zapret release automatically  
- Install required dependencies if missing  
- Configure DNS over TLS  
- Easy uninstall options  

## Requirements

- Linux system with Bash  
- `systemd` (for DNS over TLS)  

## Usage
```bash
wget -P ~/Downloads https://github.com/DeusEge/Zapret-Installer-Script/releases/download/v1.0.0/zapret_dot.sh
chmod +x zapret_dot.sh
sudo ~/Downloads/zapret_dot.sh
rm ~/Downloads/zapret_dot.sh
