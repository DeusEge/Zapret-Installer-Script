#!/bin/bash

# variables
error=""
process_manager="" # systemd or openrc


install_or_uninstall=""
uninstall_zapret=""


rm_zapret_opt=""
rm_zapret_zip=""
rm_zapret_file=""
rm_dns_configuration=""
rm_resolved_configuration=""
rm_stubby_configuration=""


supported_packet_manager=""


dns=""
dns_ipv4=""
dns_ipv4_alt=""
dns_ipv6=""
dns_ipv6_alt=""
tls_auth=""
tls_auth_mode=""


ip_protocol=""
ipv6_support=""

banned_site=""


install_zapret=""
setup_dot=""
resolved_or_stubby=""
reboot_recommended=""
reboot_choice=""
reboot_confirm=""


stubby_installed=""
stubby_required=""

sed_installed=""
sed_required=""

inetutils_installed=""
inetutils_required=""

nftables_installed=""
nftables_required=""

curl_installed=""
curl_required=""

unzip_installed=""
unzip_required=""

bind_installed=""
bind_required=""


dpi_parameter=""
# --


# learing what process manager user use
if command -v systemctl &> /dev/null; then
    process_manager="systemd"
elif command -v rc-status >/dev/null 2>&1; then
    process_manager="openrc"
else
    echo -e "\e[32mUndedected process manager\e[0m"
    echo -e "\e[32mThis script only supports Systemd and OpenRC\e[0m"
    exit 1
fi
echo -e "\e[32mprocess manager: $process_manager\e[0m"
# --


# functions for services
# starting service
service_start() {
    service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        sudo systemctl start "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        sudo rc-service "$service" start
    fi
}

# enabling service
service_enable() {
    service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        sudo systemctl enable "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        sudo rc-update add "$service" default
    fi
}

# restarting service
service_restart() {
    service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        sudo systemctl restart "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        sudo rc-service "$service" restart
    fi
}

# stopping service
service_stop() {
    service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        sudo systemctl stop "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        sudo rc-service "$service" stop
    fi
}

# disabling service
service_disable() {
    service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        sudo systemctl disable "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        sudo rc-update del "$service"
    fi
}

# checking if service is active
service_is_active() {
    local service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        sudo systemctl is-active --quiet "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        sudo rc-service "$service" status
    fi
}
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
        read -p "Do you want to reset DNS settings? (y/N): " rm_dns_settings
        rm_dns_settings=${rm_dns_settings:-"n"} # default value n
        rm_dns_settings=${rm_dns_settings,,} # lowercase
        if [[ "$rm_dns_settings" == "y" || "$rm_dns_settings" == "n" ]]; then
            echo "selected: $rm_dns_settings"
            break
        else
            echo "Invalid input. Try again."
            continue
        fi
    done
    # --

    echo

    # uninstalling selected options
    # uninstalling zapret
    if [[ "$uninstall_zapret" == "y" ]]; then
        echo "Uninstalling zapret..."
        /opt/zapret/uninstall_easy.sh <<EOF

EOF
        sudo rm -rf /opt/zapret
        echo -e "\e[32mDone!\e[0m"
        echo
    fi

    #reseting dns settings
    if [[ "$rm_dns_settings" == "y" ]]; then
        echo "reseting dns settings..."
        service_disable stubby
        service_stop stubby
        sudo chattr -i /etc/resolv.conf 2>/dev/null

        if [[ "$process_manager" == "systemd" ]]; then
            sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
EOF
            sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
            service_enable systemd-resolved
            service_restart systemd-resolved
            service_restart NetworkManager

        elif [[ "$process_manager" == "openrc" ]]; then
            if [ -L /etc/resolv.conf ]; then
                /etc/resolv.conf <<EOF
nameserver 192.168.122.1
EOF
            fi
            service_restart NetworkManager
            service_restart netifrc
        fi
        echo -e "\e[32mDone!\e[0m"
    fi
    # --

    echo

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
                sudo rm -rf /opt/zapret
                 echo -e "\e[32mDone!\e[0m"
            elif [[ "$rm_zapret_opt" == "n" ]]; then
                echo -e "\e[31mCannot continue.\e[0m"
                continue
            fi
        fi
        if [ -d "/var/tmp/zapret-v71.4" ]; then
            while true; do
                echo
                read -p "/var/tmp/zapret-v71.4 file is already exist. Wanna remove it? (Y/n) : " rm_zapret_file
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
                rm -rf /var/tmp/zapret-v71.4
                sudo rm -rf /var/tmp/zapret-v71.4
            elif [[ "$rm_zapret_file" == "n" ]]; then
                echo -e "\e[31mCannot continue.\e[0m"
                continue
            fi
        fi
        if [ -f "/var/tmp/zapret-v71.4.zip" ]; then
            while true; do
                echo
                read -p "/var/tmp/zapret-v71.4.zip file is already exist. Wanna remove it? (Y/n) : " rm_zapret_zip
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
                rm -rf /var/tmp/zapret-v71.4.zip
                sudo rm -rf /var/tmp/zapret-v71.4.zip
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


# setup DNS over TlS
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
        if [[ "$process_manager" == "openrc" ]]; then
            resolved_or_stubby="2"
        elif [[ "$process_manager" == "systemd" ]]; then
            while true; do
                echo
                echo "Choose DNS over TLS configuration type"
                echo "1 : systemd-resolved"
                echo "2 : stubby"
                read -p "your choice (default: 1) : " resolved_or_stubby
                resolved_or_stubby=${resolved_or_stubby:-1} # default value y
                if [[ "$resolved_or_stubby" == "1" || "$resolved_or_stubby" == "2" ]]; then
                    echo "selected: $resolved_or_stubby"
                    break
                else
                    echo "Invalid input. Try again."
                    continue
                fi
            done
        fi
        # checking is /etc/systemd/resolved.conf filled or stubby installed
        if grep -q . "/etc/systemd/resolved.conf" 2>/dev/null || service_is_active stubby; then
            while true; do
                echo
                echo "It seems like you have configured some DNS settings."
                read -p "Wanna reset DNS settings? (Y/n)" rm_dns_configuration
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

            echo

            if [[ "$rm_dns_configuration" == "y" ]]; then
                echo "reseting dns settings..."
                service_disable stubby
                service_stop stubby
                sudo chattr -i /etc/resolv.conf 2>/dev/null

                if [[ "$process_manager" == "systemd" ]]; then
                    sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
EOF
                    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
                    service_enable systemd-resolved
                    service_restart systemd-resolved
                    service_restart NetworkManager

                elif [[ "$process_manager" == "openrc" ]]; then
                    if [ -L /etc/resolv.conf ]; then
                        /etc/resolv.conf <<EOF
nameserver 192.168.122.1
EOF
                    fi
                    service_restart NetworkManager
                    service_restart netifrc
                fi
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


# dns choice
if [[ "$setup_dot" == "y" ]]; then
    while true; do
        echo
        echo "Which DNS do you want to use?"
        echo "1 : Cloudflare"
        echo "2 : Google"
        echo "3 : Yandex (not recommended)"
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
        tls_auth="cloudflare-dns.com"
    elif [[ "$dns" == "2" ]]; then # google
        dns_ipv4="8.8.8.8"
        dns_ipv4_alt="8.8.4.4"
        dns_ipv6="2001:4860:4860::8888"
        dns_ipv6_alt="2001:4860:4860::8844"
        tls_auth="dns.google"
    elif [[ "$dns" == "3" ]]; then # yandex
        dns_ipv4="77.88.8.8"
        dns_ipv4_alt="77.88.8.1"
        dns_ipv6="2a02:6b8::feed:0ff"
        dns_ipv6_alt="2a02:6b8:0:1::feed:0ff"
        tls_auth=""
    elif [[ "$dns" == "4" ]]; then # OpenDNS
        dns_ipv4="208.67.222.222"
        dns_ipv4_alt="208.67.220.220"
        dns_ipv6="2620:119:35::35"
        dns_ipv6_alt="2620:119:53::53"
        tls_auth="dns.opendns.com"
    elif [[ "$dns" == "5" ]]; then # Quad9
        dns_ipv4="9.9.9.9"
        dns_ipv4_alt="149.112.112.112"
        dns_ipv6="2620:fe::fe"
        dns_ipv6_alt="2620:fe::9"
        tls_auth="dns.quad9.net"
    elif [[ "$dns" == "6" ]]; then # custom
        read -p "Primary IPv4 DNS (1.1.1.1) : " dns_ipv4
        read -p "Secondary IPv4 DNS : (1.0.0.1) : " dns_ipv4_alt
        read -p "Primary IPv6 DNS (2606:4700:4700::1111) : " dns_ipv6
        read -p "Secondary IPv6 DNS (2606:4700:4700::1001) : " dns_ipv6_alt
        read -p "TLS authentication server (cloudflare-dns.com) (press enter if it is not available): " tls_auth
    fi
    if [[ -n "$tls_auth" ]]; then
        tls_auth_mode="GETDNS_AUTHENTICATION_REQUIRED"
    else
        tls_auth_mode="GETDNS_AUTHENTICATION_NONE"
    fi
    echo
    echo "ipv4 primary dns: $dns_ipv4"
    echo "ipv4 secondary dns: $dns_ipv4_alt"
    echo "ipv6 primary dns: $dns_ipv6"
    echo "ipv6 secondary dns: $dns_ipv6_alt"
    echo "TLS authentication server: $tls_auth"
    echo "TLS authentication mode: $tls_auth_mode"
fi
# --


# install zapret
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
# --


# checking which packets are required based on selected options
echo
if [[ "$resolved_or_stubby" == "2" ]]; then
    stubby_required="y"
    curl_required="y"
fi

if [[ "$install_zapret" == "y" ]]; then
    sed_required="y"
    unzip_required="y"
    nftables_required="y"
    inetutils_required="y"
    bind_required="y"
    curl_required="y"
fi
# --


# checking reboot will be recommended
if [[ "$resolved_or_stubby" == "2" ]]; then
    reboot_recommended="y"
fi

if [[ "$resolved_or_stubby" == "1" ]] && service_is_active stubby; then
    reboot_recommended="y"
fi

if [[ "$rm_dns_configuration" == "y" && "$process_manager" == "openrc" ]]; then
    reboot_recommended="y"
fi

# --


#checking if stubby installed
if [[ "$stubby_required" == "y" ]]; then
    if command -v stubby &> /dev/null; then
        stubby_installed="y"
        echo -e "\e[32mstubby is installed\e[0m"
    else
        stubby_installed="n"
        echo -e "\e[31mstubby is not installed\e[0m"
    fi
fi
# --


# checking if sed installed
if [[ "$sed_required" == "y" ]]; then
    if command -v sed &> /dev/null; then
        sed_installed="y"
        echo -e "\e[32msed is installed\e[0m"
    else
        sed_installed="n"
        echo -e "\e[31msed is not installed\e[0m"
    fi
fi
# --


#checking if inetutils installed
if [[ "$inetutils_required" == "y" ]]; then
    if command -v hostname &> /dev/null; then
        inetutils_installed="y"
        echo -e "\e[32minetutils is installed\e[0m"
    else
        inetutils_installed="n"
        echo -e "\e[31minetutils is not installed\e[0m"
    fi
fi
# --


#checking if nftables installed
if [[ "$nftables_required" == "y" ]]; then
    if command -v nft &> /dev/null; then
        nftables_installed="y"
        echo -e "\e[32mnftables is installed\e[0m"
    else
        nftables_installed="n"
        echo -e "\e[31mnftables is not installed\e[0m"
    fi
fi
# --


#checking if curl installed
if [[ "$curl_required" == "y" ]]; then
    if command -v curl &> /dev/null; then
        curl_installed="y"
        echo -e "\e[32mcurl is installed\e[0m"
    else
        curl_installed="n"
        echo -e "\e[31mcurl is not installed\e[0m"
    fi
fi
# --


#checking if unzip installed
if [[ "$unzip_required" == "y" ]]; then
    if command -v unzip &> /dev/null; then
        unzip_installed="y"
        echo -e "\e[32munzip is installed\e[0m"
    else
        unzip_installed="n"
        echo -e "\e[31munzip is not installed\e[0m"
    fi
fi
# --


#checking if bind installed
if [[ "$bind_required" == "y" ]]; then
    if command -v host &> /dev/null; then
        bind_installed="y"
        echo -e "\e[32mbind is installed\e[0m"
    else
        bind_installed="n"
        echo -e "\e[31mbind is not installed\e[0m"
    fi
fi
# --

echo

# finding packet manager and update the database
if [[ ( "$stubby_installed" == "n" && "$stubby_required" == "y" ) || \
      ( "$sed_installed" == "n" && "$sed_required" == "y" ) || \
      ( "$inetutils_installed" == "n" && "$inetutils_required" == "y" ) || \
      ( "$nftables_installed" == "n" && "$nftables_required" == "y" ) || \
      ( "$curl_installed" == "n" && "$curl_required" == "y" ) || \
      ( "$unzip_installed" == "n" && "$unzip_required" == "y" ) || \
      ( "$bind_installed" == "n" && "$bind_required" == "y" ) ]]; then
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
        echo -e "\e[31myou have to install theese packets manually\e[0m"
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
    if [[ "$stubby_installed" == "n" && "$stubby_required" == "y" ]]; then
        error="y"
        echo -e "\e[31mstubby\e[0m"
    fi
    if [[ "$sed_installed" == "n" && "$sed_required" == "y" ]]; then
        error="y"
        echo -e "\e[31msed\e[0m"
    fi
    if [[ "$inetutils_installed" == "n" && "$inetutils_required" == "y" ]]; then
        error="y"
        echo -e "\e[31minetutils\e[0m"
    fi
    if [[ "$nftables_installed" == "n" && "$nftables_required" == "y" ]]; then
        error="y"
        echo -e "\e[31mnftables\e[0m"
    fi
    if [[ "$curl_installed" == "n" && "$curl_required" == "y" ]]; then
        error="y"
        echo -e "\e[31mcurl\e[0m"
    fi
    if [[ "$unzip_installed" == "n" && "$unzip_required" == "y" ]]; then
        error="y"
        echo -e "\e[31munzip\e[0m"
    fi
    if [[ "$bind_installed" == "n" && "$bind_required" == "y" ]]; then
        error="y"
        echo -e "\e[31mbind\e[0m"
    fi
    if [[ "$error" == "y" ]]; then
        exit 1
    fi

elif [[ "$supported_packet_manager" == "y" ]]; then
    if [[ "$stubby_installed" == "n" && "$stubby_required" == "y" ]]; then
        echo "installing stubby..."
        $INSTALL_CMD stubby
    fi

    if [[ "$sed_installed" == "n" && "$sed_required" == "y" ]]; then
        echo "installing sed..."
        $INSTALL_CMD sed
    fi

    if [[ "$inetutils_installed" == "n" && "$inetutils_required" == "y" ]]; then
        echo "installing inetutils..."
        $INSTALL_CMD inetutils
    fi

    if [[ "$nftables_installed" == "n" && "$nftables_required" == "y" ]]; then
        echo "installing nftables..."
        $INSTALL_CMD nftables
    fi

    if [[ "$curl_installed" == "n" && "$curl_required" == "y" ]]; then
        echo "installing curl..."
        $INSTALL_CMD curl
    fi

    if [[ "$unzip_installed" == "n" && "$unzip_required" == "y" ]]; then
        echo "installing unzip..."
        $INSTALL_CMD unzip
    fi

    if [[ "$bind_installed" == "n" && "$bind_required" == "y" ]]; then
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
    #systemd-resolved
    if [[ "$resolved_or_stubby" == "1" ]]; then
        service_enable systemd-resolved
        service_start systemd-resolved

        if [[ -n "$tls_auth" ]]; then
            sudo tee /etc/systemd/resolved.conf > /dev/null << EOF
  [Resolve]
  DNS=$dns_ipv4#$tls_auth $dns_ipv4_alt#$tls_auth $dns_ipv6#$tls_auth $dns_ipv6_alt#$tls_auth
  DNSOverTLS=yes
EOF
        else
            sudo tee /etc/systemd/resolved.conf > /dev/null << EOF
  [Resolve]
  DNS=$dns_ipv4 $dns_ipv4_alt $dns_ipv6 $dns_ipv6_alt
  DNSOverTLS=yes
EOF
        fi
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        service_restart systemd-resolved

    #stubby
    elif [[ "$resolved_or_stubby" == "2" ]]; then
        sudo tee /etc/stubby/stubby.yml > /dev/null <<EOF
resolution_type: GETDNS_RESOLUTION_STUB
round_robin_upstreams: 1
dns_transport_list:
  - GETDNS_TRANSPORT_TLS
tls_authentication: $tls_auth_mode
idle_timeout: 10000
listen_addresses:
  - 127.0.0.1@53
  - 0::1@53
upstream_recursive_servers:
  - address_data: $dns_ipv4
    tls_port: 853
    tls_auth_name: "$tls_auth"
  - address_data: $dns_ipv4_alt
    tls_port: 853
    tls_auth_name: "$tls_auth"
  - address_data: $dns_ipv6
    tls_port: 853
    tls_auth_name: "$tls_auth"
  - address_data: $dns_ipv6_alt
    tls_port: 853
    tls_auth_name: "$tls_auth"
EOF

        service_disable systemd-resolved
        service_stop systemd-resolved

        service_enable stubby
        service_restart stubby

        service_restart NetworkManager

        sudo tee /etc/resolv.conf > /dev/null <<EOF
# edited by Zapret Installer Script https://github.com/DeusEge/Zapret-Installer-Script
# this file is unwritable right now. do sudo chattr -i /etc/resolv.conf to make it writable
nameserver 127.0.0.1
EOF
        sudo chattr +i /etc/resolv.conf
        service_restart stubby
    fi
fi
# --


# zapret
if [[ "$install_zapret" == "y" ]]; then
    wget -P /var/tmp https://github.com/bol-van/zapret/releases/download/v71.4/zapret-v71.4.zip
    unzip /var/tmp/zapret-v71.4.zip -d /var/tmp
    rm -rf /var/tmp/zapret-v71.4.zip

    /var/tmp/zapret-v71.4/install_prereq.sh <<EOF
2
EOF


    /var/tmp/zapret-v71.4/install_bin.sh


    if curl -V 2>/dev/null | grep -q "HTTP3"; then
        dpi_parameter=$(
            /var/tmp/zapret-v71.4/blockcheck.sh <<EOF | tee /dev/tty | grep -m1 'curl_test_https_tls12 : nfqws '
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
    else
        dpi_parameter=$(
            /var/tmp/zapret-v71.4/blockcheck.sh <<EOF | tee /dev/tty | grep -m1 'curl_test_https_tls12 : nfqws '
$banned_site
$ip_protocol
y
y
n
1
2
EOF
        )
    fi

    dpi_parameter=$(printf '%s' "$dpi_parameter" | sed 's/.*curl_test_https_tls12 : nfqws //') # line
    dpi_parameter="$(printf '%s' "$dpi_parameter" | xargs)" # trim

    echo -e "\e[32mDPI PARAMETER: $dpi_parameter\e[0m"

    sed -i "98s/.*/$dpi_parameter/; 99s/.*/\"/; 100,101d" /var/tmp/zapret-v71.4/config.default # write dpi parameter to file
    sed -i "98s/.*/$dpi_parameter/; 99s/.*/\"/; 100,101d" /var/tmp/zapret-v71.4/config # write dpi parameter to file


    /var/tmp/zapret-v71.4/install_easy.sh <<EOF
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

    rm -rf /var/tmp/zapret-v71.4

    echo -e "\e[32m!!!!! INSTALLATION COMPLETE !!!!!\e[0m"
    echo

    if [[ "$reboot_recommended" == "y" ]]; then
        while true; do
            echo
            echo "System reboot required. Reboot now?"
            echo "1 : now"
            echo "2 : later"
            read -p "your choice : " reboot_choice
            if [[ "$reboot_choice" == "1" || "$reboot_choice" == "2" ]]; then
                echo "selected: $reboot_choice"
                if [[ "$reboot_choice" == "1" ]]; then
                    while true; do
                        echo
                        read -p "Are you sure? (y/n): " reboot_confirm
                        reboot_confirm=${reboot_confirm,,} # lowercase
                        if [[ "$reboot_confirm" == "y" || "$reboot_confirm" == "n" ]]; then
                            echo "selected: $reboot_confirm"
                            break
                        else
                            echo "Invalid input. Try again."
                            continue
                        fi
                    done
                    if [[ "$reboot_confirm" == "y" ]]; then
                        break
                    elif [[ "$reboot_confirm" == "n" ]]; then
                        continue
                    fi
                elif [[ "$reboot_choice" == "2" ]]; then
                    break
                fi
            else
                echo "Invalid input. Try again."
            fi
        done
        echo

        if [[ "$reboot_choice" == "1" ]]; then
            sudo reboot
        fi
    fi
fi
