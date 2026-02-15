#!/bin/bash

# checking sudo
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31mThis script must be run with sudo or as root.\e[0m"
    echo
    exit 1
fi
# --


# variables
error=""
process_manager="" # systemd | openrc


operation_type="" # 1 | 2 | 3 | 4 | 5 | 12 | 45


rm_zapret_opt="" # y | n
rm_zapret_zip="" # y | n
rm_zapret_file="" # y | n
rm_dns_configuration="" # y | n
rm_resolved_configuration="" # y | n
rm_stubby_configuration="" # y | n


supported_packet_manager=""


dns="" # 1 | 2 | 3 | 4 | 5 | 6
dns_ipv4="" # 1.1.1.1
dns_ipv4_alt="" # 1.0.0.1
dns_ipv6="" # 2606:4700:4700::1111
dns_ipv6_alt="" # 2606:4700:4700::1001
tls_auth="" # cloudflare-dns.com
tls_auth_mode="" # GETDNS_AUTHENTICATION_REQUIRED


ip_protocol="" # 4=ipv4 | 6=ipv6 | 46=ipv4&ipv6
ipv6_support=""

banned_site=""  # discord.com


install_zapret="" # y |
install_dot="" # y |
uninstall_zapret="" # y |
uninstall_dot="" # y |
resolved_or_stubby="" # 1=systemd_resolved | 2=stubby


systemd_resolved_installed="" # y | n
systemd_resolved_required="" # y | n

stubby_installed="" # y | n
stubby_required="" # y | n

sed_installed="" # y | n
sed_required="" # y | n

inetutils_installed="" # y | n
inetutils_required="" # y | n

nftables_installed="" # y | n
nftables_required="" # y | n

curl_installed="" # y | n
curl_required="" # y | n

unzip_installed="" # y | n
unzip_required="" # y | n

bind_installed="" # y | n
bind_required="" # y | n


dpi_parameter=""

restore_file_index="" # X (backupX)

BASE_BACKUP_DIR="/var/lib/zapret_dot" # base directory for all backups
BACKUP_DIR="" # BASE_BACKUP_DIR/backupX
zapret_version="v71.4" # version cant be changed by just setting this value because scraping dpi parameter is spesific to version
# --


# learing what process manager user use
if command -v systemctl &> /dev/null; then
    process_manager="systemd"
elif command -v rc-status >/dev/null 2>&1; then
    process_manager="openrc"
else
    echo -e "\e[32mUndedected process manager\e[0m"
    echo -e "\e[32mThis script only supports Systemd and OpenRC\e[0m"
    echo
    exit 1
fi
echo "process manager: $process_manager"
echo
# --


# functions for services
# starting service
service_start() {
    local service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        systemctl start "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        rc-service "$service" start
    fi
}

# enabling service
service_enable() {
    local service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        systemctl enable "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        rc-update add "$service" default
    fi
}

# restarting service
service_restart() {
    local service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        systemctl restart "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        rc-service "$service" restart
    fi
}

# stopping service
service_stop() {
    local service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        systemctl stop "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        rc-service "$service" stop
    fi
}

# disabling service
service_disable() {
    local service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        systemctl disable "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        rc-update del "$service"
    fi
}

# checking if service is active
service_is_active() { # 0=active | 1=passive fuck bash
    local service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        systemctl is-active --quiet "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        rc-service "$service" status >/dev/null 2>&1
    fi
}

# checking if service is enabled
service_is_enabled() { # 0=enabled | 1=disabled fuck bash
    local service=$1
    if [[ "$process_manager" == "systemd" ]]; then
        systemctl is-enabled --quiet "$service"
    elif [[ "$process_manager" == "openrc" ]]; then
        rc-update show | grep -q "$service"
    fi
}

# checks if file backed up
is_file_backed_up() { # 0=backed up | 12=not backed up
    local SRC_FILE="$1"

    # validate source file
    if [[ ! -f "$SRC_FILE" ]]; then
        return 2
    fi

    if [[ -z "$BACKUP_DIR" ]]; then
        return 0
    fi

    local SRC_NAME="$(basename "$SRC_FILE")"
    if [[ -f "$BACKUP_DIR/$SRC_NAME" ]]; then
        return 1
    else
        return 0
    fi
}

# backup the file that given in parameter
backup_file() {
    local SRC_FILE="$1"

    # validate source file
    if [[ ! -f "$SRC_FILE" ]]; then
        echo "Error: source file does not exist: $SRC_FILE"
        return 1
    fi

    # checking if backup dir exists
    if [[ ! -d "$BASE_BACKUP_DIR" ]]; then
        mkdir -p "$BASE_BACKUP_DIR"
        chmod 700 "$BASE_BACKUP_DIR"
    fi

    # initialize backup directory (only once)
    if [[ -z "$BACKUP_DIR" ]]; then
        LAST_BACKUP_NUM=0

        for DIR in "$BASE_BACKUP_DIR"/backup*; do
            [[ -d "$DIR" ]] || continue

            DIR_NAME="$(basename "$DIR")"

            if [[ "$DIR_NAME" =~ ^backup([0-9]+)$ ]]; then
                NUM="${BASH_REMATCH[1]}"
                (( NUM > LAST_BACKUP_NUM )) && LAST_BACKUP_NUM="$NUM"
            fi
        done

        BACKUP_DIR="$BASE_BACKUP_DIR/backup$((LAST_BACKUP_NUM + 1))"

        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
    fi

    # backup file
    local SRC_NAME="$(basename "$SRC_FILE")"
    if [[ ! -f "$BACKUP_DIR/$SRC_NAME" ]]; then # if already didnt backed up
        cp -a "$SRC_FILE" "$BACKUP_DIR/$SRC_NAME" || return 1
    fi
}

write_manifest() {
    local line="$1"

    # checking if backup dir exists
    if [[ ! -d "$BASE_BACKUP_DIR" ]]; then
        mkdir -p "$BASE_BACKUP_DIR"
        chmod 700 "$BASE_BACKUP_DIR"
    fi

    # initialize backup directory (only once)
    if [[ -z "$BACKUP_DIR" ]]; then
        LAST_BACKUP_NUM=0

        for DIR in "$BASE_BACKUP_DIR"/backup*; do
            [[ -d "$DIR" ]] || continue

            NAME="$(basename "$DIR")"

            if [[ "$NAME" =~ ^backup([0-9]+)$ ]]; then
                NUM="${BASH_REMATCH[1]}"
                (( NUM > LAST_BACKUP_NUM )) && LAST_BACKUP_NUM="$NUM"
            fi
        done

        BACKUP_DIR="$BASE_BACKUP_DIR/backup$((LAST_BACKUP_NUM + 1))"

        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"

        echo "# Backup date: $(date '+%F %T')" > "$BACKUP_DIR/manifest"
        chmod 600 "$BACKUP_DIR/manifest"
    fi

    # write line to manfiest
    echo "$line" >> "$BACKUP_DIR/manifest"
}
# --


# operation type input
while true; do
    echo
    echo "What do you want to do?"
    echo "1 : install zapret"
    echo "2 : install DNS over TLS"
    echo "3 : uninstall zapret"
    echo "4 : reset DNS settings"
    echo "5 : restore system files from a backup created by a previous run of this script"
    echo
    echo "type 12 if you want to install both zapret and DoT"
    echo "type 34 if you want to uninstall both zapret and DoT"
    echo
    read -p "your choice (default: 12) : " operation_type
    operation_type=${operation_type:-"12"} # default value 12
    if [[ "$operation_type" == "1" || "$operation_type" == "2" || "$operation_type" == "3" || "$operation_type" == "4" || "$operation_type" == "5" || "$operation_type" == "12" || "$operation_type" == "34"  ]]; then
        echo -e "\e[36mselected: $operation_type\e[0m"
        echo
        break
    else
        echo -e "\e[93mInvalid input. Try again.\e[0m"
        echo
        continue
    fi
done

if [[ "$operation_type" == "1" || "$operation_type" == "12" ]]; then
    install_zapret="y"
fi
if [[ "$operation_type" == "2" || "$operation_type" == "12" ]]; then
    install_dot="y"
fi
if [[ "$operation_type" == "3" || "$operation_type" == "34" ]]; then
    uninstall_zapret="y"
fi
if [[ "$operation_type" == "4" || "$operation_type" == "34" ]]; then
    uninstall_dot="y"
fi
# --


# restore system files
if [[ "$operation_type" == "5" ]]; then
    dir="/var/lib/zapret_dot"

    backupX_max=0
    for f in "$dir"/backup[0-9]*; do
        [[ -e "$f" ]] || continue
        n=${f##*/}
        n=${n//[^0-9]/}
        (( n > backupX_max )) && backupX_max=$n
    done

    echo "$backupX_max"

    while true; do
        echo "Which backup you want to restore?"
        for f in "$BASE_BACKUP_DIR"/backup*; do
            [[ -d "$f" ]] || continue
            name="$(basename "$f")"
            num="${name#backup}"
            [[ "$num" =~ ^[0-9]+$ ]] && echo "$num: $name"
        done
        read -p "your choice (default: $backupX_max) : " restore_file_index
        restore_file_index=${restore_file_index:-"$backupX_max"} # default value backupX_max
        if [[ -d "$BASE_BACKUP_DIR/backup$restore_file_index" ]]; then
            echo
            break
        else
            echo -e "\e[93mInvalid input. Try again.\e[0m"
            echo
            continue
        fi
    done

    MANIFEST="$BASE_BACKUP_DIR/backup$restore_file_index/manifest"
    while IFS= read -r line; do
        [[ "$line" == UNDO:* ]] || continue
        cmd="${line#UNDO:}"
        echo "$cmd"
        eval "$cmd"
        echo
    done < <(tac "$MANIFEST")

    echo -e "\e[93mYour system may need a reboot for these changes to take effect.\e[0m"
    echo

    exit 0
fi
# --


# uninstalling selected options
# uninstalling zapret
if [[ "$uninstall_zapret" == "y" ]]; then
    echo "Uninstalling zapret..."
    if [ -d /opt/zapret ]; then
        /opt/zapret/uninstall_easy.sh <<EOF

EOF
        if [[ -d /opt/zapret ]]; then
            rm -rf /opt/zapret
        fi
        echo -e "\e[32m!!!!! ZAPRET UNINSTALLATION COMPLETE !!!!!\e[0m"
        echo
    else
        echo -e "\e[93mZapret Not Found.\e[0m"
        echo
    fi
fi


#reseting dns settings
if [[ "$uninstall_dot" == "y" ]]; then
    echo "Reseting DNS Settings..."

    service_is_enabled stubby
    if [[ "$?" == 0 ]]; then
        if [[ "$process_manager" == "systemd" ]]; then
            write_manifest "DONE:systemctl disable stubby"
            write_manifest "UNDO:systemctl enable stubby"
        elif [[ "$process_manager" == "openrc" ]]; then
            write_manifest "DONE:rc-update del stubby"
            write_manifest "UNDO:rc-update add stubby default"
        fi
        write_manifest ""
        service_disable stubby
    fi

    service_is_active stubby
    if [[ "$?" == 0 ]]; then
        if [[ "$process_manager" == "systemd" ]]; then
            write_manifest "DONE:systemctl stop stubby"
            write_manifest "UNDO:systemctl start stubby"
        elif [[ "$process_manager" == "openrc" ]]; then
            write_manifest "DONE:rc-service stubby stop"
            write_manifest "UNDO:rc-service stubby start"
        fi
        write_manifest ""
        service_stop stubby
    fi

    write_manifest "DONE:chattr -i /etc/resolv.conf"
    out=$(lsattr -d -- "/etc/resolv.conf" 2>/dev/null | awk '{print $1}')
    if echo "$out" | grep -qi "i"; then
        immutable_flag="+i"
    else
        immutable_flag="-i"
    fi
    write_manifest "UNDO:chattr $immutable_flag /etc/resolv.conf"
    write_manifest ""
    chattr -i /etc/resolv.conf 2>/dev/null

    if [[ "$process_manager" == "systemd" ]]; then
        is_file_backed_up /etc/systemd/resolved.conf
        if [[ "$?" == 0 ]]; then
            write_manifest "DONE:
tee /etc/systemd/resolved.conf <<EOF
[Resolve]
EOF"
            write_manifest "UNDO:cp -f $BACKUP_DIR/resolved.conf /etc/systemd/resolved.conf"
            write_manifest ""
            backup_file /etc/systemd/resolved.conf
        fi
        tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
EOF
        write_manifest "DONE: ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"
        link_target=$(readlink /etc/resolv.conf)
        if [[ -z "$link_target" ]]; then
            is_file_backed_up /etc/resolv.conf
            if [[ "$?" == 0 ]]; then
                write_manifest "UNDO:cp -f $BACKUP_DIR/resolv.conf /etc/resolv.conf"
                write_manifest "UNDO:rm -f /etc/resolv.conf"
                backup_file /etc/resolv.conf
            fi
        else
            write_manifest "UNDO:ln -sf $link_target /etc/resolv.conf"
        fi
        write_manifest ""
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

        for unit in \
            systemd-resolved.service \
            systemd-resolved-varlink.socket \
            systemd-resolved-monitor.socket
        do
            service_is_enabled "$unit"
            if [[ "$?" != 0 ]]; then
                if [[ "$process_manager" == "systemd" ]]; then
                    write_manifest "DONE:systemctl enable $unit"
                    write_manifest "UNDO:systemctl disable $unit"
                fi
                write_manifest ""
                service_enable "$unit"
            fi

            service_is_active "$unit"
            if [[ "$?" != 0 ]]; then
                if [[ "$process_manager" == "systemd" ]]; then
                    write_manifest "DONE:systemctl start $unit"
                    write_manifest "UNDO:systemctl stop $unit"
                fi
                write_manifest ""
                service_start "$unit"
            fi
        done

        service_restart NetworkManager 2>/dev/null || true

    elif [[ "$process_manager" == "openrc" ]]; then
        is_file_backed_up /etc/resolv.conf
        if [[ "$?" == 0 ]]; then
            write_manifest "DONE:
tee /etc/resolv.conf <<EOF
nameserver 192.168.122.1
EOF"
            write_manifest "UNDO:cp -f $BACKUP_DIR/resolv.conf /etc/resolv.conf"
            write_manifest "UNDO:rm -f /etc/resolv.conf"
            write_manifest ""
            backup_file /etc/resolv.conf
        fi
        tee /etc/resolv.conf > /dev/null <<EOF
nameserver 192.168.122.1
EOF
        service_restart NetworkManager 2>/dev/null || true
        service_restart netifrc
    fi
    echo -e "\e[32m!!!!! RESETTING DNS SETTINGS COMPLETE !!!!!\e[0m"
    echo
fi


if [[ "$uninstall_zapret" == "y" || "$uninstall_dot" == "y" ]]; then
    echo
    exit 0
fi
# --


# get zapret inputs
if [[ "$install_zapret" == "y" ]]; then
    if [ -d "/opt/zapret" ]; then
        while true; do
            echo
            echo -ne "\e[93m/opt/zapret file is already exist. Wanna remove it? (Y/n) : \e[0m"
            read rm_zapret_opt
            rm_zapret_opt=${rm_zapret_opt:-"y"} # default value y
            rm_zapret_opt=${rm_zapret_opt,,} # lowercase
            if [[ "$rm_zapret_opt" == "y" || "$rm_zapret_opt" == "n" ]]; then
                echo -e "\e[36mselected: $rm_zapret_opt\e[0m"
                echo
                break
            else
                echo -e "\e[93mInvalid input. Try again.\e[0m"
                echo
                continue
            fi
        done
        if [[ "$rm_zapret_opt" == "y" ]]; then
            /opt/zapret/uninstall_easy.sh <<EOF

EOF
            if [[ -d /opt/zapret ]]; then
                rm -rf /opt/zapret
            fi
            echo -e "\e[32mDone!\e[0m"
            echo
        elif [[ "$rm_zapret_opt" == "n" ]]; then
            echo -e "\e[31mCannot continue.\e[0m"
            echo
            exit 0
        fi
    fi
    if [ -d "/var/tmp/zapret-${zapret_version}" ]; then
        while true; do
            echo
            echo -ne "\e[93m/var/tmp/zapret-${zapret_version} file is already exist. Wanna remove it? (Y/n) : \e[0m"
            read rm_zapret_file
            rm_zapret_file=${rm_zapret_file:-"y"} # default value y
            rm_zapret_file=${rm_zapret_file,,} # lowercase
            if [[ "$rm_zapret_file" == "y" || "$rm_zapret_file" == "n" ]]; then
                echo "\e[36mselected: $rm_zapret_file\e[0m"
                echo
                break
            else
                echo -e "\e[93mInvalid input. Try again.\e[0m"
                echo
                continue
            fi
        done
        if [[ "$rm_zapret_file" == "y" ]]; then
            rm -rf /var/tmp/zapret-${zapret_version}
        elif [[ "$rm_zapret_file" == "n" ]]; then
            echo -e "\e[31mCannot continue.\e[0m"
            echo
            exit 0
        fi
    fi
    if [ -f "/var/tmp/zapret-${zapret_version}.zip" ]; then
        while true; do
            echo
            echo -ne "\e[93m/var/tmp/zapret-${zapret_version}.zip file is already exist. Wanna remove it? (Y/n) : \e[0m"
            read rm_zapret_zip
            rm_zapret_zip=${rm_zapret_zip:-"y"} # default value y
            rm_zapret_zip=${rm_zapret_zip,,} # lowercase
            if [[ "$rm_zapret_zip" == "y" || "$rm_zapret_zip" == "n" ]]; then
                echo -e "\e[36mselected: $rm_zapret_zip\e[0m"
                echo
                break
            else
                echo -e "\e[93mInvalid input. Try again.\e[0m"
                echo
                continue
            fi
        done
        if [[ "$rm_zapret_zip" == "y" ]]; then
            rm -f /var/tmp/zapret-${zapret_version}.zip
        elif [[ "$rm_zapret_zip" == "n" ]]; then
            echo -e "\e[31mCannot continue.\e[0m"
            echo
            exit 0
        fi
    fi

    echo
    read -p "Enter a website banned in your country (default: discord.com) : " banned_site
    banned_site=${banned_site:-discord.com}
    echo -e "\e[36mselected: $banned_site\e[0m"
    echo

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
            echo -e "\e[36mselected: $ip_protocol\e[0m"
            echo
            break;
        else
            echo -e "\e[93mInvalid input. Try again.\e[0m"
            echo
            continue;
        fi
    done
fi
# --


# get DoT inputs
if [[ "$install_dot" == "y" ]]; then
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
                echo -e "\e[36mselected: $resolved_or_stubby\e[0m"
                echo
                break
            else
                echo -e "\e[93mInvalid input. Try again.\e[0m"
                echo
                continue
            fi
        done
    fi
    # checking is /etc/systemd/resolved.conf filled or stubby installed
    if grep -qEv '^[[:space:]]*(#|$|\[)' /etc/systemd/resolved.conf 2>/dev/null || service_is_active stubby; then
        while true; do
            echo
            echo -ne "\e[93mIt seems like you have configured some DNS settings. Wanna reset DNS settings? (Y/n) : \e[0m"
            read rm_dns_configuration
            rm_dns_configuration=${rm_dns_configuration:-y} # default value y
            rm_dns_configuration=${rm_dns_configuration,,} # lowercase
            if [[ "$rm_dns_configuration" == "y" || "$rm_dns_configuration" == "n" ]]; then
                echo -e "\e[36mselected: $rm_dns_configuration\e[0m"
                echo
                break
            else
                echo -e "\e[93mInvalid input. Try again.\e[0m"
                echo
                continue
            fi
        done

        echo

        if [[ "$rm_dns_configuration" == "y" ]]; then
            echo "Reseting DNS settings..."

            service_is_enabled stubby
            if [[ "$?" == 0 ]]; then
                if [[ "$process_manager" == "systemd" ]]; then
                    write_manifest "DONE:systemctl disable stubby"
                    write_manifest "UNDO:systemctl enable stubby"
                elif [[ "$process_manager" == "openrc" ]]; then
                    write_manifest "DONE:rc-update del stubby"
                    write_manifest "UNDO:rc-update add stubby default"
                fi
                write_manifest ""
                service_disable stubby
            fi

            service_is_active stubby
            if [[ "$?" == 0 ]]; then
                if [[ "$process_manager" == "systemd" ]]; then
                    write_manifest "DONE:systemctl stop stubby"
                    write_manifest "UNDO:systemctl start stubby"
                elif [[ "$process_manager" == "openrc" ]]; then
                    write_manifest "DONE:rc-service stubby stop"
                    write_manifest "UNDO:rc-service stubby start"
                fi
                write_manifest ""
                service_stop stubby
            fi

            write_manifest "DONE:chattr -i /etc/resolv.conf"
            out=$(lsattr -d -- "/etc/resolv.conf" 2>/dev/null | awk '{print $1}')
            if echo "$out" | grep -qi "i"; then
                immutable_flag="+i"
            else
                immutable_flag="-i"
            fi
            write_manifest "UNDO:chattr $immutable_flag /etc/resolv.conf"
            write_manifest ""
            chattr -i /etc/resolv.conf 2>/dev/null

            if [[ "$process_manager" == "systemd" ]]; then
                is_file_backed_up /etc/systemd/resolved.conf
                if [[ "$?" == 0 ]]; then
                    write_manifest "DONE:
tee /etc/systemd/resolved.conf <<EOF
[Resolve]
EOF"
                    write_manifest "UNDO:cp -f $BACKUP_DIR/resolved.conf /etc/systemd/resolved.conf"
                    write_manifest "UNDO:rm -f /etc/resolv.conf"
                    write_manifest ""
                    backup_file /etc/systemd/resolved.conf
                fi
                tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
EOF

                write_manifest "DONE:ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"
                link_target=$(readlink /etc/resolv.conf)
                if [[ -z "$link_target" ]]; then
                    is_file_backed_up /etc/resolv.conf
                    if [[ "$?" == 0 ]]; then
                        write_manifest "UNDO:cp -f $BACKUP_DIR/resolv.conf /etc/resolv.conf"
                        write_manifest "UNDO:rm -f /etc/resolv.conf"
                        backup_file /etc/resolv.conf
                    fi
                else
                    write_manifest "UNDO:ln -sf $link_target /etc/resolv.conf"
                fi
                write_manifest ""
                ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

                for unit in \
                    systemd-resolved.service \
                    systemd-resolved-varlink.socket \
                    systemd-resolved-monitor.socket
                do
                    service_is_enabled "$unit"
                    if [[ "$?" != 0 ]]; then
                        if [[ "$process_manager" == "systemd" ]]; then
                            write_manifest "DONE:systemctl enable $unit"
                            write_manifest "UNDO:systemctl disable $unit"
                        fi
                        write_manifest ""
                        service_enable "$unit"
                    fi

                    service_is_active "$unit"
                    if [[ "$?" != 0 ]]; then
                        if [[ "$process_manager" == "systemd" ]]; then
                            write_manifest "DONE:systemctl start $unit"
                            write_manifest "UNDO:systemctl stop $unit"
                        fi
                        write_manifest ""
                        service_start "$unit"
                    fi
                done

                service_restart NetworkManager 2>/dev/null || true
            elif [[ "$process_manager" == "openrc" ]]; then
                is_file_backed_up /etc/resolv.conf
                if [[ "$?" == 0 ]]; then
                    write_manifest "DONE:
tee /etc/resolv.conf <<EOF
nameserver 192.168.122.1
EOF"
                    write_manifest "UNDO:cp -f $BACKUP_DIR/resolv.conf /etc/resolv.conf"
                    write_manifest "UNDO:rm -f /etc/resolv.conf"
                    write_manifest ""
                    backup_file /etc/resolv.conf
                fi
                tee /etc/resolv.conf > /dev/null <<EOF
nameserver 192.168.122.1
EOF
                service_restart NetworkManager 2>/dev/null || true
                service_restart netifrc
            fi
            echo -e "\e[32mDone!\e[0m"
            echo
        elif [[ "$rm_dns_configuration" == "n" ]]; then
            echo -e "\e[31mCannot continue.\e[0m"
            echo
            exit 0
        fi
    fi

    # dns choice
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
            echo -e "\e[36mselected: $dns\e[0m"
            echo
            break;
        else
            echo -e "\e[93mInvalid input. Try again.\e[0m"
            echo
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
    # echo
    # echo "ipv4 primary dns: $dns_ipv4"
    # echo "ipv4 secondary dns: $dns_ipv4_alt"
    # echo "ipv6 primary dns: $dns_ipv6"
    # echo "ipv6 secondary dns: $dns_ipv6_alt"
    # echo "TLS authentication server: $tls_auth"
    # echo "TLS authentication mode: $tls_auth_mode"
    # echo
fi
# --


# checking which packets are required based on selected options
if [[ "$resolved_or_stubby" == "1" ]]; then
    systemd_resolved_required="y"
elif [[ "$resolved_or_stubby" == "2" ]]; then
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


#checking if systemd_resolved installed
if [[ "$systemd_resolved_required" == "y" ]]; then
    if systemctl list-unit-files systemd-resolved.service >/dev/null 2>&1; then
        systemd_resolved_installed="y"
        echo -e "\e[36msystemd-resolved is installed\e[0m"
    else
        systemd_resolved_installed="n"
        echo -e "\e[93msystemd-resolved is not installed\e[0m"
    fi
fi
# --


#checking if stubby installed
if [[ "$stubby_required" == "y" ]]; then
    if command -v stubby &> /dev/null; then
        stubby_installed="y"
        echo -e "\e[36mstubby is installed\e[0m"
    else
        stubby_installed="n"
        echo -e "\e[93mstubby is not installed\e[0m"
    fi
fi
# --


# checking if sed installed
if [[ "$sed_required" == "y" ]]; then
    if command -v sed &> /dev/null; then
        sed_installed="y"
        echo -e "\e[36msed is installed\e[0m"
    else
        sed_installed="n"
        echo -e "\e[93msed is not installed\e[0m"
    fi
fi
# --


#checking if inetutils installed
if [[ "$inetutils_required" == "y" ]]; then
    if command -v hostname &> /dev/null; then
        inetutils_installed="y"
        echo -e "\e[36minetutils is installed\e[0m"
    else
        inetutils_installed="n"
        echo -e "\e[93minetutils is not installed\e[0m"
    fi
fi
# --


#checking if nftables installed
if [[ "$nftables_required" == "y" ]]; then
    if command -v nft &> /dev/null; then
        nftables_installed="y"
        echo -e "\e[36mnftables is installed\e[0m"
    else
        nftables_installed="n"
        echo -e "\e[93mnftables is not installed\e[0m"
    fi
fi
# --


#checking if curl installed
if [[ "$curl_required" == "y" ]]; then
    if command -v curl &> /dev/null; then
        curl_installed="y"
        echo -e "\e[36mcurl is installed\e[0m"
    else
        curl_installed="n"
        echo -e "\e[93mcurl is not installed\e[0m"
    fi
fi
# --


#checking if unzip installed
if [[ "$unzip_required" == "y" ]]; then
    if command -v unzip &> /dev/null; then
        unzip_installed="y"
        echo -e "\e[36munzip is installed\e[0m"
    else
        unzip_installed="n"
        echo -e "\e[93munzip is not installed\e[0m"
    fi
fi
# --


#checking if bind installed
if [[ "$bind_required" == "y" ]]; then
    if command -v host &> /dev/null; then
        bind_installed="y"
        echo -e "\e[36mbind is installed\e[0m"
    else
        bind_installed="n"
        echo -e "\e[93mbind is not installed\e[0m"
    fi
fi
# --

# finding packet manager and update the database
if [[ ( "$systemd_resolved_installed" == "n" && "$systemd_resolved_required" == "y" ) || \
      ( "$stubby_installed" == "n" && "$stubby_required" == "y" ) || \
      ( "$sed_installed" == "n" && "$sed_required" == "y" ) || \
      ( "$inetutils_installed" == "n" && "$inetutils_required" == "y" ) || \
      ( "$nftables_installed" == "n" && "$nftables_required" == "y" ) || \
      ( "$curl_installed" == "n" && "$curl_required" == "y" ) || \
      ( "$unzip_installed" == "n" && "$unzip_required" == "y" ) || \
      ( "$bind_installed" == "n" && "$bind_required" == "y" ) ]]; then
    if command -v apt-get &> /dev/null; then
        PKG_MGR="apt-get"
        apt-get update
        supported_packet_manager="y"
    elif command -v dnf &> /dev/null; then
        PKG_MGR="dnf"
        dnf makecache
        supported_packet_manager="y"
    elif command -v yum &> /dev/null; then
        PKG_MGR="yum"
        yum makecache
        supported_packet_manager="y"
    elif command -v pacman &> /dev/null; then
        PKG_MGR="pacman"
        pacman -Sy
        supported_packet_manager="y"
    elif command -v zypper &> /dev/null; then
        PKG_MGR="zypper"
        zypper refresh
        supported_packet_manager="y"
    else
        echo
        echo -e "\e[31mpacket manager is not supported\e[0m"
        echo -e "\e[31myou have to install theese packets manually:\e[0m"
        echo
        supported_packet_manager="n"
    fi

    INSTALL_CMD=""

    case "$PKG_MGR" in
        apt-get) INSTALL_CMD="apt-get install -y" ;;
        dnf)     INSTALL_CMD="dnf install -y" ;;
        yum)     INSTALL_CMD="yum install -y" ;;
        pacman)  INSTALL_CMD="pacman -S --noconfirm" ;;
        zypper)  INSTALL_CMD="zypper install -y" ;;
    esac
fi
# --


# installing needed packets
if [[ "$supported_packet_manager" == "n" ]]; then
    if [[ "$systemd_resolved_installed" == "n" && "$systemd_resolved_required" == "y" ]]; then
        error="y"
        echo -e "\e[31m*systemd-resolved\e[0m"
    fi
    if [[ "$stubby_installed" == "n" && "$stubby_required" == "y" ]]; then
        error="y"
        echo -e "\e[31m* stubby\e[0m"
    fi
    if [[ "$sed_installed" == "n" && "$sed_required" == "y" ]]; then
        error="y"
        echo -e "\e[31m* sed\e[0m"
    fi
    if [[ "$inetutils_installed" == "n" && "$inetutils_required" == "y" ]]; then
        error="y"
        echo -e "\e[31m* inetutils\e[0m"
    fi
    if [[ "$nftables_installed" == "n" && "$nftables_required" == "y" ]]; then
        error="y"
        echo -e "\e[31m* nftables\e[0m"
    fi
    if [[ "$curl_installed" == "n" && "$curl_required" == "y" ]]; then
        error="y"
        echo -e "\e[31m* curl\e[0m"
    fi
    if [[ "$unzip_installed" == "n" && "$unzip_required" == "y" ]]; then
        error="y"
        echo -e "\e[31m* unzip\e[0m"
    fi
    if [[ "$bind_installed" == "n" && "$bind_required" == "y" ]]; then
        error="y"
        echo -e "\e[31m* bind\e[0m"
    fi
    if [[ "$error" == "y" ]]; then
        exit 1
    fi

elif [[ "$supported_packet_manager" == "y" ]]; then
    if [[ "$systemd_resolved_installed" == "n" && "$systemd_resolved_required" == "y" ]]; then
        echo "installing systemd-resolved..."
        $INSTALL_CMD systemd-resolved
        if ! systemctl list-unit-files systemd-resolved.service >/dev/null 2>&1; then
            echo -e "\e[31msystemd-resolved download failed.\e[0m"
            echo -e "\e[31mCheck your internet connection or install it manually.\e[0m"
            echo
            exit 1
        fi
    fi
    if [[ "$stubby_installed" == "n" && "$stubby_required" == "y" ]]; then
        echo "installing stubby..."
        $INSTALL_CMD stubby
        if ! command -v stubby &> /dev/null; then
            echo -e "\e[31mstubby download failed.\e[0m"
            echo -e "\e[31mCheck your internet connection or install it manually.\e[0m"
            echo
            exit 1
        fi
    fi

    if [[ "$sed_installed" == "n" && "$sed_required" == "y" ]]; then
        echo "installing sed..."
        $INSTALL_CMD sed
        if ! command -v sed &> /dev/null; then
            echo -e "\e[31msed download failed.\e[0m"
            echo -e "\e[31mCheck your internet connection or install it manually.\e[0m"
            echo
            exit 1
        fi
    fi

    if [[ "$inetutils_installed" == "n" && "$inetutils_required" == "y" ]]; then
        echo "installing inetutils..."
        $INSTALL_CMD inetutils
        if ! command -v hostname &> /dev/null; then
            echo -e "\e[31minetutils download failed.\e[0m"
            echo -e "\e[31mCheck your internet connection or install it manually.\e[0m"
            echo
            exit 1
        fi
    fi

    if [[ "$nftables_installed" == "n" && "$nftables_required" == "y" ]]; then
        echo "installing nftables..."
        $INSTALL_CMD nftables
        if ! command -v nft &> /dev/null; then
            echo -e "\e[31mnftables download failed.\e[0m"
            echo -e "\e[31mCheck your internet connection or install it manually.\e[0m"
            echo
            exit 1
        fi
    fi

    if [[ "$curl_installed" == "n" && "$curl_required" == "y" ]]; then
        echo "installing curl..."
        $INSTALL_CMD curl
        if ! command -v curl &> /dev/null; then
            echo -e "\e[31mcurl download failed.\e[0m"
            echo -e "\e[31mCheck your internet connection or install it manually.\e[0m"
            echo
            exit 1
        fi
    fi

    if [[ "$unzip_installed" == "n" && "$unzip_required" == "y" ]]; then
        echo "installing unzip..."
        $INSTALL_CMD unzip
        if ! command -v unzip &> /dev/null; then
            echo -e "\e[31munzip download failed.\e[0m"
            echo -e "\e[31mCheck your internet connection or install it manually.\e[0m"
            echo
            exit 1
        fi
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
        if ! command -v host &> /dev/null; then
            echo -e "\e[31mbind download failed.\e[0m"
            echo -e "\e[31mCheck your internet connection or install it manually.\e[0m"
            echo
            exit 1
        fi
    fi
fi
# --


# DNS over tls
if [[ "$install_dot" == "y" ]]; then
    echo "Configuring DNS over TLS..."
    # systemd-resolved
    if [[ "$resolved_or_stubby" == "1" ]]; then

        for unit in \
            systemd-resolved.service \
            systemd-resolved-varlink.socket \
            systemd-resolved-monitor.socket
        do
            service_is_enabled "$unit"
            if [[ "$?" != 0 ]]; then
                if [[ "$process_manager" == "systemd" ]]; then
                    write_manifest "DONE:systemctl enable $unit"
                    write_manifest "UNDO:systemctl disable $unit"
                fi
                write_manifest ""
                service_enable "$unit"
            fi

            service_is_active "$unit"
            if [[ "$?" != 0 ]]; then
                if [[ "$process_manager" == "systemd" ]]; then
                    write_manifest "DONE:systemctl start $unit"
                    write_manifest "UNDO:systemctl stop $unit"
                fi
                write_manifest ""
                service_start "$unit"
            fi
        done

        if [[ -n "$tls_auth" ]]; then
            is_file_backed_up /etc/systemd/resolved.conf
            if [[ "$?" == 0 ]]; then
                write_manifest "DONE:
tee /etc/systemd/resolved.conf << EOF
  [Resolve]
  DNS=$dns_ipv4#$tls_auth $dns_ipv4_alt#$tls_auth $dns_ipv6#$tls_auth $dns_ipv6_alt#$tls_auth
  DNSOverTLS=yes
EOF"
                write_manifest "UNDO:cp -f $BACKUP_DIR/resolved.conf /etc/systemd/resolved.conf"
                write_manifest ""
                backup_file /etc/systemd/resolved.conf
            fi
            tee /etc/systemd/resolved.conf > /dev/null << EOF
  [Resolve]
  DNS=$dns_ipv4#$tls_auth $dns_ipv4_alt#$tls_auth $dns_ipv6#$tls_auth $dns_ipv6_alt#$tls_auth
  DNSOverTLS=yes
EOF
        else
            is_file_backed_up /etc/systemd/resolved.conf
            if [[ "$?" == 0 ]]; then
                write_manifest "DONE:
tee /etc/systemd/resolved.conf << EOF
  [Resolve]
  DNS=$dns_ipv4 $dns_ipv4_alt $dns_ipv6 $dns_ipv6_alt
  DNSOverTLS=yes
EOF"
                write_manifest "UNDO:cp -f $BACKUP_DIR/resolved.conf /etc/systemd/resolved.conf"
                write_manifest ""
                backup_file /etc/systemd/resolved.conf
            fi
            tee /etc/systemd/resolved.conf > /dev/null << EOF
  [Resolve]
  DNS=$dns_ipv4 $dns_ipv4_alt $dns_ipv6 $dns_ipv6_alt
  DNSOverTLS=yes
EOF
        fi
        write_manifest "DONE:ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"
        link_target=$(readlink /etc/resolv.conf)
        if [[ -z "$link_target" ]]; then
            is_file_backed_up /etc/resolv.conf
            if [[ "$?" == 0 ]]; then
                write_manifest "UNDO:cp -f $BACKUP_DIR/resolv.conf /etc/resolv.conf"
                write_manifest "UNDO:rm -f /etc/resolv.conf"
                backup_file /etc/resolv.conf
            fi
        else
            write_manifest "UNDO:ln -sf $link_target /etc/resolv.conf"
        fi
        write_manifest ""
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

        if [ -f "/etc/selinux/config" ]; then
            is_file_backed_up /etc/selinux/config
            if [[ "$?" == 0 ]]; then
                write_manifest "DONE:sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config"
                write_manifest "UNDO:cp -f $BACKUP_DIR/config /etc/selinux/config"
                write_manifest ""
                backup_file "/etc/selinux/config"
            fi
            sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null
        fi

        service_restart systemd-resolved

    #stubby
    elif [[ "$resolved_or_stubby" == "2" ]]; then
        is_file_backed_up /etc/stubby/stubby.yml
        if [[ "$?" == 0 ]]; then
            write_manifest "DONE:
tee /etc/stubby/stubby.yml <<EOF
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
EOF"
            write_manifest "UNDO:cp -f $BACKUP_DIR/stubby.yml /etc/stubby/stubby.yml"
            write_manifest ""
            backup_file /etc/stubby/stubby.yml
        fi
        tee /etc/stubby/stubby.yml > /dev/null <<EOF
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

        if [[ "$process_manager" == "systemd" ]]; then
            for unit in \
                systemd-resolved.service \
                systemd-resolved-varlink.socket \
                systemd-resolved-monitor.socket
            do
                service_is_enabled "$unit"
                if [[ "$?" == 0 ]]; then
                    if [[ "$process_manager" == "systemd" ]]; then
                        write_manifest "DONE:systemctl disable $unit"
                        write_manifest "UNDO:systemctl enable $unit"
                    fi
                    write_manifest ""
                    service_disable "$unit"
                fi

                service_is_active "$unit"
                if [[ "$?" == 0 ]]; then
                    if [[ "$process_manager" == "systemd" ]]; then
                        write_manifest "DONE:systemctl stop $unit"
                        write_manifest "UNDO:systemctl start $unit"
                    fi
                    write_manifest ""
                    service_stop "$unit"
                fi
            done
        fi

        service_is_enabled stubby
        if [[ "$?" != 0 ]]; then
            if [[ "$process_manager" == "systemd" ]]; then
                write_manifest "DONE:systemctl enable stubby"
                write_manifest "UNDO:systemctl disable stubby"
            elif [[ "$process_manager" == "openrc" ]]; then
                write_manifest "DONE:rc-update add stubby default"
                write_manifest "UNDO:rc-update del stubby"
            fi
            write_manifest ""
            service_enable stubby
        fi

        service_is_active stubby
        if [[ "$?" != 0 ]]; then
            if [[ "$process_manager" == "systemd" ]]; then
                write_manifest "DONE:systemctl start stubby"
                write_manifest "UNDO:systemctl stop stubby"
            elif [[ "$process_manager" == "openrc" ]]; then
                write_manifest "DONE:rc-service stubby start"
                write_manifest "UNDO:rc-service stubby stop"
            fi
            write_manifest ""
            service_start stubby
        fi

        service_restart stubby

        service_restart NetworkManager 2>/dev/null || true


        is_file_backed_up /etc/resolv.conf
        if [[ "$?" == 0 ]]; then
            write_manifest "DONE:
tee /etc/resolv.conf <<EOF
# edited by Zapret Installer Script https://github.com/DeusEge/Zapret-Installer-Script
# this file is unwritable right now. do sudo chattr -i /etc/resolv.conf to make it writable
nameserver 127.0.0.1
EOF"
            write_manifest "UNDO:cp -f $BACKUP_DIR/resolv.conf /etc/resolv.conf"
            write_manifest "UNDO:rm -f /etc/resolv.conf"
            write_manifest ""
            backup_file /etc/resolv.conf
        fi
        tee /etc/resolv.conf > /dev/null <<EOF
# edited by Zapret Installer Script https://github.com/DeusEge/Zapret-Installer-Script
# this file is unwritable right now. do sudo chattr -i /etc/resolv.conf to make it writable
nameserver 127.0.0.1
EOF
        write_manifest "DONE:chattr +i /etc/resolv.conf"
        out=$(lsattr -d -- "/etc/resolv.conf" 2>/dev/null | awk '{print $1}')
        if echo "$out" | grep -qi "i"; then
            immutable_flag="+i"
        else
            immutable_flag="-i"
        fi
        write_manifest "UNDO:chattr $immutable_flag /etc/resolv.conf"
        write_manifest ""
        chattr +i /etc/resolv.conf
        service_restart stubby
    fi
    echo
    echo -e "\e[32m!!!!! DNS OVER TLS INSTALLATION COMPLETE !!!!!\e[0m"
    echo
fi
# --


# zapret
if [[ "$install_zapret" == "y" ]]; then
    if ! wget -O /var/tmp/zapret-${zapret_version}.zip https://github.com/bol-van/zapret/releases/download/${zapret_version}/zapret-${zapret_version}.zip; then
        echo -e "\e[31mZapret download failed.\e[0m"
        echo -e "\e[31mCheck your internet connection.\e[0m"
        echo
        rm -f /var/tmp/zapret-${zapret_version}.zip
        exit 1
    fi

    if [ ! -s /var/tmp/zapret-${zapret_version}.zip ]; then
        echo -e "\e[31mDownloaded zapret file is empty.\e[0m"
        echo -e "\e[31mCheck your internet connection.\e[0m"
        echo
        rm -f /var/tmp/zapret-${zapret_version}.zip
        exit 1
    fi

    if ! unzip /var/tmp/zapret-${zapret_version}.zip -d /var/tmp; then
        echo -e "\e[31mUnziping zapret failed.\e[0m"
        echo
        rm -f /var/tmp/zapret-${zapret_version}.zip
        exit 1
    fi

    if [[ ! -d "/var/tmp/zapret-${zapret_version}" ]]; then
        echo -e "\e[31mZapret directory not found after unzip.\e[0m"
        echo
        rm -f /var/tmp/zapret-${zapret_version}.zip
        exit 1
    fi

    rm -f /var/tmp/zapret-${zapret_version}.zip

    /var/tmp/zapret-${zapret_version}/install_prereq.sh <<EOF
2
EOF


    /var/tmp/zapret-${zapret_version}/install_bin.sh


    if curl -V 2>/dev/null | grep -q "HTTP3"; then
        dpi_parameter=$(
            /var/tmp/zapret-${zapret_version}/blockcheck.sh <<EOF | tee /dev/tty | grep -m1 'curl_test_https_tls12 : nfqws '
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
            /var/tmp/zapret-${zapret_version}/blockcheck.sh <<EOF | tee /dev/tty | grep -m1 'curl_test_https_tls12 : nfqws '
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

    echo -e "\e[36mDPI PARAMETER: $dpi_parameter\e[0m"
    echo

    if [ -z "$dpi_parameter" ]; then
        echo -e "\e[31mDPI Parameter Couldn't Be Found.\e[0m"
        echo -e "\e[31mRemoving Temp Files.\e[0m"
        echo
        rm -rf /var/tmp/zapret-${zapret_version}
        exit 1
    fi

    sed -i "98s/.*/$dpi_parameter/; 99s/.*/\"/; 100,101d" /var/tmp/zapret-${zapret_version}/config.default # write dpi parameter to file
    sed -i "98s/.*/$dpi_parameter/; 99s/.*/\"/; 100,101d" /var/tmp/zapret-${zapret_version}/config # write dpi parameter to file


    if [[ "$process_manager" == "systemd" || "$process_manager" == "openrc" ]]; then
        /var/tmp/zapret-${zapret_version}/install_easy.sh <<EOF
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
    fi

    if [[ -n "$zapret_version" && -d "/var/tmp/zapret-${zapret_version}" ]]; then
        rm -rf "/var/tmp/zapret-${zapret_version}"
    fi
    service_restart NetworkManager 2>/dev/null || true

    echo
    echo -e "\e[32m!!!!! ZAPRET INSTALLATION COMPLETE !!!!!\e[0m"
    echo
fi
# --


# important note
if [[ "$install_zapret" == "y" || "$install_dot" == "y" ]]; then
    echo
    echo -e "\e[93m!!!!!!!!!!!!!!!!!!!!! IMPORTANT NOTE !!!!!!!!!!!!!!!!!!!!!\e[0m"
    echo
    echo -e "\e[93mYOUR SYSTEM MAY NEED A REBOOT FOR THESE CHANGES TO TAKE EFFECT.\e[0m"
    echo -e "\e[93mAFTER REBOOT, YOU MAY NOT BE ABLE TO CONNECT TO THE INTERNET.\e[0m"
    echo -e "\e[93mIF THIS HAPPENS, RUN THE SCRIPT AGAIN AND SELECT\e[0m"
    echo -e "\e[93mRESTORE SYSTEM FILES FROM THE PREVIOUS SCRIPT BACKUP.\e[0m"
    echo -e "\e[93mThis is very unlikely, but it's worth keeping in mind.\e[0m"
    echo
    echo -e "\e[93m!!!!!!!!!!!!!!!!!!!!! IMPORTANT NOTE !!!!!!!!!!!!!!!!!!!!!\e[0m"
    echo
fi
# --
