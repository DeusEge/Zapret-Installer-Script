# Zapret Installer Script

This is a simple Bash script to **download, install, and configure Zapret** on Linux systems. It also supports setting up **DNS over TLS**.

## Features

- Installing Zapret v71.4 and set up automatically
- Configure DNS over TLS  
- Easy uninstall options  

## Requirements

- Linux system with Bash  
- `Systemd` or `OpenRC`

## Usage
```bash
wget -P /var/tmp https://github.com/DeusEge/Zapret-Installer-Script/releases/download/v1.2.0/zapret_dot.sh
chmod +x /var/tmp/zapret_dot.sh
sudo /var/tmp/zapret_dot.sh
rm /var/tmp/zapret_dot.sh
