#!/bin/bash

# variables
install_or_uninstall=""
uninstall_zapret=""
reset_dns_settings=""

rm_zapret_opt=""
rm_zapret_zip=""
rm_zapret_file=""
rm_dns_configuration=""

supported_packet_manager=""

dns=""
dns_ipv4=""
dns_ipv4_alt=""
dns_ipv6=""
dns_ipv6_alt=""

ip_protocol=""
ipv6_support=""

banned_site=""

install_zapret=""
setup_dot=""

sed_installed=""
inetutils_installed=""
nftables_installed=""
curl_installed=""
unzip_installed=""
bind_installed=""

dpi_parameter=""
# --


# install or uninstall
while true; do
echo
read -p "Do you want to install or uninstall? (I/u): " install_or_uninstall
install_or_uninstall=${install_or_uninstall:-"i"} # default value i
install_or_uninstall=${install_or_uninstall,,} # lowercase
    if [[ "$install_or_uninstall" = "i" || "$install_or_uninstall" = "u" ]]; then
        echo "selected: $install_or_uninstall"
        break
    else
        echo "Invalid input. Try again."
        continue
    fi
done
# --

# uninstall
if [[ "$install_or_uninstall" == "u" ]]; then
    # uninstall zapret
    while true; do
        echo
        read -p "Do you want to uninstall zapret? (y/N): " uninstall_zapret
        uninstall_zapret=${uninstall_zapret:-"n"} # default value n
        uninstall_zapret=${uninstall_zapret,,} # lowercase
        if [[ "$uninstall_zapret" == "y" || "$uninstall_zapret" == "n" ]]; then
            echo "selected: $uninstall_zapret"
            break
        else
            echo "Invalid input. Try again."
            continue
        fi
    done
    # --


    # reset dns settings
    while true; do
        echo
        read -p "Do you want to reset DNS settings? (y/N): " reset_dns_settings
        reset_dns_settings=${reset_dns_settings:-"n"} # default value n
        reset_dns_settings=${reset_dns_settings,,} # lowercase
        if [[ "$reset_dns_settings" == "y" || "$reset_dns_settings" == "n" ]]; then
            echo "selected: $reset_dns_settings"
            break
        else
            echo "Invalid input. Try again."
            continue
        fi
    done
    # --

    # uninstalling selected options
    # uninstalling zapret
    if [[ "$uninstall_zapret" == "y" ]]; then
        echo "Uninstalling zapret..."
        /opt/zapret/uninstall_easy.sh <<EOF

EOF
        rm -rf ~/zapret-v71.4
        sudo rm -rf /opt/zapret
        echo -e "\e[32mDone!\e[0m"
        echo
    fi

    #reseting dns settings
    if [[ "$reset_dns_settings" == "y" ]]; then
        echo "reseting dns settings..."
        sudo systemctl enable systemd-resolved
        sudo systemctl start systemd-resolved
        sudo tee /etc/systemd/resolved.conf > /dev/null <<< ""
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        sudo systemctl restart systemd-resolved
        echo -e "\e[32mDone!\e[0m"
    fi
    # --

    exit 0
fi
# --


#install
# install_zapret
while true; do
    echo
    read -p "Do you want to install zapret? (Y/n): " install_zapret
    install_zapret=${install_zapret:-"y"} # default value y
    install_zapret=${install_zapret,,} # lowercase
    if [[ "$install_zapret" == "y" || "$install_zapret" == "n" ]]; then
        echo "selected: $install_zapret"
    else
        echo "Invalid input. Try again."
        continue
    fi

    if [[ "$install_zapret" == "y" ]]; then
        if [ -d "/opt/zapret" ]; then
            while true; do
                echo
                read -p "/opt/zapret file is already exist. Wanna remove it? (Y/n) : " rm_zapret_opt
                rm_zapret_opt=${rm_zapret_opt:-"y"} # default value y
                rm_zapret_opt=${rm_zapret_opt,,} # lowercase
                if [[ "$rm_zapret_opt" == "y" || "$rm_zapret_opt" == "n" ]]; then
                    echo "selected: $rm_zapret_opt"
                    break
                else
                    echo "Invalid input. Try again."
                    continue
                fi
            done
            if [[ "$rm_zapret_opt" == "y" ]]; then
                /opt/zapret/uninstall_easy.sh <<EOF

EOF
                rm -rf ~/zapret-v71.4
                sudo rm -rf /opt/zapret
                 echo -e "\e[32mDone!\e[0m"
            elif [[ "$rm_zapret_opt" == "n" ]]; then
                echo -e "\e[31mCannot continue.\e[0m"
                continue
            fi
        fi
        if [ -d "$HOME/Downloads/zapret-v71.4" ]; then
            while true; do
                echo
                read -p "$HOME/Downloads/zapret-v71.4 file is already exist. Wanna remove it? (Y/n) : " rm_zapret_file
                rm_zapret_file=${rm_zapret_file:-"y"} # default value y
                rm_zapret_file=${rm_zapret_file,,} # lowercase
                if [[ "$rm_zapret_file" == "y" || "$rm_zapret_file" == "n" ]]; then
                    echo "selected: $rm_zapret_file"
                    break
                else
                    echo "Invalid input. Try again."
                    continue
                fi
            done
            if [[ "$rm_zapret_file" == "y" ]]; then
                rm -rf ~/Downloads/zapret-v71.4
                sudo rm -rf ~/Downloads/zapret-v71.4
            elif [[ "$rm_zapret_file" == "n" ]]; then
                echo -e "\e[31mCannot continue.\e[0m"
                continue
            fi
        fi
        if [ -f "$HOME/Downloads/zapret-v71.4.zip" ]; then
            while true; do
                echo
                read -p "$HOME/Downloads/zapret-v71.4.zip file is already exist. Wanna remove it? (Y/n) : " rm_zapret_zip
                rm_zapret_zip=${rm_zapret_zip:-"y"} # default value y
                rm_zapret_zip=${rm_zapret_zip,,} # lowercase
                if [[ "$rm_zapret_zip" == "y" || "$rm_zapret_zip" == "n" ]]; then
                    echo "selected: $rm_zapret_zip"
                    break
                else
                    echo "Invalid input. Try again."
                    continue
                fi
            done
            if [[ "$rm_zapret_zip" == "y" ]]; then
                rm -rf $HOME/Downloads/zapret-v71.4.zip
                sudo rm -rf $HOME/Downloads/zapret-v71.4.zip
            elif [[ "$rm_zapret_zip" == "n" ]]; then
                echo -e "\e[31mCannot continue.\e[0m"
                continue
            fi
        fi
        break
    elif [[ "$install_zapret" == "n" ]]; then
        break
    fi
done
# --


# setup_dot
while true; do
    echo
    read -p "Do you want to setup DNS over TLS? (Y/n): " setup_dot
    setup_dot=${setup_dot:-y} # default value y
    setup_dot=${setup_dot,,} # lowercase
    if [[ "$setup_dot" == "y" || "$setup_dot" == "n" ]]; then
        echo "selected: $setup_dot"
    else
        echo "Invalid input. Try again."
        continue
    fi

    if [[ "$setup_dot" == "y" ]]; then
        # checking is systemd available
        if ! command -v systemctl &> /dev/null; then
            echo
            echo -e "\e[31msystemd is not available\e[0m"
            echo -e "\e[31myou have to install systemd or DoT manually\e[0m"
            exit 1
        fi
        # checking is /etc/systemd/resolved.conf filled
        if grep -q . "/etc/systemd/resolved.conf"; then
            while true; do
                echo
                echo "/etc/systemd/resolved.conf contains configuration"
                read -p "Wanna reset /etc/systemd/resolved.conf settings? (Y/n)" rm_dns_configuration
                rm_dns_configuration=${rm_dns_configuration:-y} # default value y
                rm_dns_configuration=${rm_dns_configuration,,} # lowercase
                if [[ "$rm_dns_configuration" == "y" || "$rm_dns_configuration" == "n" ]]; then
                    echo "selected: $rm_dns_configuration"
                    break
                else
                    echo "Invalid input. Try again."
                    continue
                fi
            done
            if [[ "$rm_dns_configuration" == "y" ]]; then
                echo "reseting dns settings..."
                sudo systemctl enable systemd-resolved
                sudo systemctl start systemd-resolved
                sudo tee /etc/systemd/resolved.conf > /dev/null <<< ""
                sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
                sudo systemctl restart systemd-resolved
                echo -e "\e[32mDone!\e[0m"
            elif [[ "$rm_dns_configuration" == "n" ]]; then
                echo -e "\e[31mCannot continue.\e[0m"
                continue
            fi
        fi
        break
    elif [[ "$setup_dot" == "n" ]]; then
        break
    fi
done
# --

if [[ "$install_zapret" == "y" ]]; then
    echo
    read -p "Enter a website banned in your country (default: discord.com) : " banned_site
    banned_site=${banned_site:-discord.com}
    echo "selected: $banned_site"

    if [[ "$banned_site" == "roblox.com" ]]; then
cat <<'EOF'

             _ ,+z@@@@@@@@@@@wwwwp_    _,wwwww@@@@@@@@@@@p*w_
             *{#M*?`___   `[?T"%*f      _"**%"""[`__   _-*%Np_
             _` _  __,[[[[''``` w_       _w ``,[[[[[[L__    `
                __zMF"--@@@M1@` ]N_      Jb_]MT--@@@F"*W_
                _ `%MMMMMMMWWMW `         `_ /MmWMMMMMMMM" _


                                                           _
                                                         _m
                                                        ,&
                                                  __   ,M
                                             ___,wM   .M
                        ,.           __,,[wwwWMFL    _$
                        `\0"**TTTTTTPT*/*            /F
                                                     !

EOF
    fi

    while true; do
        echo
        echo "Choose ip protocol version"
        echo "4 : ipv4"
        echo "6 : ipv6"
        echo "46 : ipv4 and ipv6"
        read -p "your choice (default: 4) : " ip_protocol
        ip_protocol=${ip_protocol:-4}
        if [[ "$ip_protocol" == "4" || "$ip_protocol" == "6" || "$ip_protocol" == "46" ]]; then
            if [[ "$ip_protocol" == "4" ]]; then
                ipv6_support="n"
            elif [[ "$ip_protocol" == "6" || "$ip_protocol" == "46" ]]; then
                ipv6_support="y"
            fi
            echo "selected: $ip_protocol"
            break;
        else
            echo "Invalid input. Try again."
            continue;
        fi
    done
fi

if [[ "$setup_dot" == "y" ]]; then
    while true; do
        echo
        echo "Which DNS do you want to use?"
        echo "1 : Cloudflare"
        echo "2 : Google"
        echo "3 : Yandex"
        echo "4 : OpenDNS"
        echo "5 : Quad9"
        echo "6 : Custom DNS"
        read -p "your choice (default: 1) : " dns
        dns=${dns:-1}
        if [[ "$dns" == "1" || "$dns" == "2" || "$dns" == "3" || "$dns" == "4" || "$dns" == "5" || "$dns" == "6" ]]; then
            echo "selected: $dns"
            break;
        else
            echo "Invalid input. Try again."
            continue;
        fi
    done
    if [[ "$dns" == "1" ]]; then # cloudflare
        dns_ipv4="1.1.1.1"
        dns_ipv4_alt="1.0.0.1"
        dns_ipv6="2606:4700:4700::1111"
        dns_ipv6_alt="2606:4700:4700::1001"
    elif [[ "$dns" == "2" ]]; then # google
        dns_ipv4="8.8.8.8"
        dns_ipv4_alt="8.8.4.4"
        dns_ipv6="2001:4860:4860::8888"
        dns_ipv6_alt="2001:4860:4860::8844"
    elif [[ "$dns" == "3" ]]; then # yandex
        dns_ipv4="77.88.8.8"
        dns_ipv4_alt="77.88.8.1"
        dns_ipv6="2a02:6b8::feed:0ff"
        dns_ipv6_alt="2a02:6b8:0:1::feed:0ff"
    elif [[ "$dns" == "4" ]]; then # OpenDNS
        dns_ipv4="208.67.222.222"
        dns_ipv4_alt="208.67.220.220"
        dns_ipv6="2620:119:35::35"
        dns_ipv6_alt="2620:119:53::53"
    elif [[ "$dns" == "5" ]]; then # Quad9
        dns_ipv4="9.9.9.9"
        dns_ipv4_alt="149.112.112.112"
        dns_ipv6="2620:fe::fe"
        dns_ipv6_alt="2620:fe::9"
    elif [[ "$dns" == "6" ]]; then # custom
        read -p "Primary IPv4 DNS (1.1.1.1) : " dns_ipv4
        read -p "Secondary IPv4 DNS : (1.0.0.1) : " dns_ipv4_alt
        read -p "Primary IPv6 DNS (2606:4700:4700::1111) : " dns_ipv6
        read -p "Secondary IPv6 DNS (2606:4700:4700::1001) : " dns_ipv6_alt
    fi
    echo
    echo "ipv4 primary dns: $dns_ipv4"
    echo "ipv4 secondary dns: $dns_ipv4_alt"
    echo "ipv6 primary dns: $dns_ipv6"
    echo "ipv6 secondary dns: $dns_ipv6_alt"
fi
# --


# --
echo
# --


# checking if sed installed
if command -v sed &> /dev/null; then
    sed_installed="y"
    echo -e "\e[32msed is installed\e[0m"
else
    sed_installed="n"
    echo -e "\e[31msed is not installed\e[0m"
fi
# --


#checking if inetutils installed
if command -v hostname &> /dev/null; then
    inetutils_installed="y"
    echo -e "\e[32minetutils is installed\e[0m"
else
    inetutils_installed="n"
    echo -e "\e[31minetutils is not installed\e[0m"
fi
# --


#checking if nftables installed
if command -v nft &> /dev/null; then
    nftables_installed="y"
    echo -e "\e[32mnftables is installed\e[0m"
else
    nftables_installed="n"
    echo -e "\e[31mnftables is not installed\e[0m"
fi
# --


#checking if curl installed
if command -v curl &> /dev/null; then
    curl_installed="y"
    echo -e "\e[32mcurl is installed\e[0m"
else
    curl_installed="n"
    echo -e "\e[31mcurl is not installed\e[0m"
fi
# --


#checking if unzip installed
if command -v unzip &> /dev/null; then
    unzip_installed="y"
    echo -e "\e[32munzip is installed\e[0m"
else
    unzip_installed="n"
    echo -e "\e[31munzip is not installed\e[0m"
fi
# --


#checking if bind-tools installed
if command -v host &> /dev/null; then
    bind_installed="y"
    echo -e "\e[32mbind is installed\e[0m"
else
    bind_installed="n"
    echo -e "\e[31mbind is not installed\e[0m"
fi
# --

echo

# finding packet manager and update the database
if [[ "$sed_installed" == "n" || "$inetutils_installed" == "n" || "$nftables_installed" == "n" || "$curl_installed" == "n" || "$unzip_installed" == "n" || "$bind_installed" == "n" ]]; then
    if command -v apt-get &> /dev/null; then
        PKG_MGR="apt-get"
        sudo apt-get update
        supported_packet_manager="y"
    elif command -v dnf &> /dev/null; then
        PKG_MGR="dnf"
        sudo dnf makecache
        supported_packet_manager="y"
    elif command -v yum &> /dev/null; then
        PKG_MGR="yum"
        sudo yum makecache
        supported_packet_manager="y"
    elif command -v pacman &> /dev/null; then
        PKG_MGR="pacman"
        sudo pacman -Sy
        supported_packet_manager="y"
    elif command -v zypper &> /dev/null; then
        PKG_MGR="zypper"
        sudo zypper refresh
        supported_packet_manager="y"
    else
        echo -e "\e[31mpacket manager is not supported\e[0m"
        echo -e "\e[31myou have to install packets manually if needed\e[0m"
        supported_packet_manager="n"
    fi

    INSTALL_CMD=""

    case "$PKG_MGR" in
        apt-get) INSTALL_CMD="sudo apt-get install -y" ;;
        dnf)     INSTALL_CMD="sudo dnf install -y" ;;
        yum)     INSTALL_CMD="sudo yum install -y" ;;
        pacman)  INSTALL_CMD="sudo pacman -S --noconfirm" ;;
        zypper)  INSTALL_CMD="sudo zypper install -y" ;;
    esac
fi
# --


# installing needed packets
if [[ "$supported_packet_manager" == "n" ]]; then
    if [[ "$sed_installed" == "n" ]]; then
        echo -e "\e[31myou have to install sed manually\e[0m"
    fi
    if [[ "$inetutils_installed" == "n" ]]; then
        echo -e "\e[31myou have to install inetutils manually\e[0m"
    fi
    if [[ "$nftables_installed" == "n" ]]; then
        echo -e "\e[31myou have to install nftables manually\e[0m"
    fi
    if [[ "$curl_installed" == "n" ]]; then
        echo -e "\e[31myou have to install curl manually\e[0m"
    fi
    if [[ "$unzip_installed" == "n" ]]; then
        echo -e "\e[31myou have to install unzip manually\e[0m"
    fi
    if [[ "$bind_installed" == "n" ]]; then
        echo -e "\e[31myou have to install bind manually\e[0m"
    fi
    if [[ "$sed_installed" == "n" || "$inetutils_installed" == "n" || "$nftables_installed" == "n" || "$curl_installed" == "n" || "$unzip_installed" == "n" || "$bind_installed" == "n" ]]; then
        exit 1
    fi

elif [[ "$supported_packet_manager" == "y" ]]; then
    if [[ "$sed_installed" == "n" ]]; then
        echo "installing sed..."
        $INSTALL_CMD sed
    fi

    if [[ "$inetutils_installed" == "n" ]]; then
        echo "installing inetutils..."
        $INSTALL_CMD inetutils
    fi

    if [[ "$nftables_installed" == "n" ]]; then
        echo "installing nftables..."
        $INSTALL_CMD nftables
    fi

    if [[ "$curl_installed" == "n" ]]; then
        echo "installing curl..."
        $INSTALL_CMD curl
    fi

    if [[ "$unzip_installed" == "n" ]]; then
        echo "installing unzip..."
        $INSTALL_CMD unzip
    fi

    if [[ "$bind_installed" == "n" ]]; then
        echo "installing bind..."
        case "$PKG_MGR" in
            apt-get)
                $INSTALL_CMD dnsutils # Debian/Ubuntu
                ;;
            dnf|yum)
                $INSTALL_CMD bind-utils # Fedora/RHEL/CentOS
                ;;
            pacman)
                $INSTALL_CMD bind-tools # Arch
                ;;
            zypper)
                $INSTALL_CMD bind-utils # openSUSE
                ;;
        esac
    fi
fi
# --


# DNS over tls
if [[ "$setup_dot" == "y" ]]; then
    sudo systemctl enable systemd-resolved
    sudo systemctl start systemd-resolved

    sudo tee /etc/systemd/resolved.conf > /dev/null << EOF
  [Resolve]
  DNS=$dns_ipv4 $dns_ipv4_alt $dns_ipv6 $dns_ipv6_alt
  DNSOverTLS=yes
EOF

    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    sudo systemctl restart systemd-resolved
fi
# --


# zapret
if [[ "$install_zapret" == "y" ]]; then
    wget -P ~/Downloads https://github.com/bol-van/zapret/releases/download/v71.4/zapret-v71.4.zip
    unzip ~/Downloads/zapret-v71.4.zip -d ~/Downloads
    rm -rf ~/Downloads/zapret-v71.4.zip

    ~/Downloads/zapret-v71.4/install_prereq.sh <<EOF
2
EOF

    ~/Downloads/zapret-v71.4/install_bin.sh

    dpi_parameter=$(
        ~/Downloads/zapret-v71.4/blockcheck.sh <<EOF | tee /dev/tty | grep -m1 'curl_test_https_tls12 : nfqws '
$banned_site
$ip_protocol
y
y
n
y
1
2
EOF
    )
    dpi_parameter=$(printf '%s' "$dpi_parameter" | sed 's/.*curl_test_https_tls12 : nfqws //') # line
    dpi_parameter="$(printf '%s' "$dpi_parameter" | xargs)" # trim

    echo -e "\e[32mDPI PARAMETER: $dpi_parameter\e[0m"

    sed -i "98s/.*/$dpi_parameter/; 99s/.*/\"/; 100,101d" ~/Downloads/zapret-v71.4/config.default # write dpi parameter to file
    sed -i "98s/.*/$dpi_parameter/; 99s/.*/\"/; 100,101d" ~/Downloads/zapret-v71.4/config # write dpi parameter to file

    ~/Downloads/zapret-v71.4/install_easy.sh <<EOF
y
2
$ipv6_support
1
1
n
n
y
n
1
1
EOF

    rm -rf ~/Downloads/zapret-v71.4

    echo -e "\e[32m!!!!! INSTALLATION COMPLETE !!!!!\e[0m"
    echo
fi
