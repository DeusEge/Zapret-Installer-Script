# Zapret Installer Script

This is a simple Bash script to **download, install, and configure Zapret** on Linux systems. It also supports setting up **DNS over TLS**.

## Features

- Installing Zapret v71.4 and set up automatically
- Configure DNS over TLS  
- Easy uninstall options
- Rollback option 

## Requirements

- Linux system with Bash  
- `Systemd` or `OpenRC`

## Usage

```bash
sudo mkdir -p /var/lib/zapret_dot
sudo wget -P /var/lib/zapret_dot https://github.com/DeusEge/Zapret-Installer-Script/releases/download/v1.3.0/zapret_dot.sh
sudo chmod +x /var/lib/zapret_dot/zapret_dot.sh
sudo /var/lib/zapret_dot/zapret_dot.sh
```

## Rollback

If DNS over TLS installation breaks your system, you can easily restore the previous configuration.

Simply run the script again and select the rollback option.
All changes will be reverted and your original system state will be restored.

```bash
sudo /var/lib/zapret_dot/zapret_dot.sh
```
## Delete Script

Following command will delete script and its logs without changing the changes script made before.
```bash
sudo rm -rf /var/lib/zapret_dot
```
