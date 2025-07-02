#!/bin/bash

user=$(whoami)
timestamp=$(date +"%d%m%H%M%S")
script_start=$(date +%s)

START()
{
    if [[ "$user" != "root" ]]; then
        echo -e "\n\e[91m\e[107m[!] You must run this script as root\e[0m\n"
        exit
    else
        figlet "REMOTE CONTROL"
        echo -e "\nOleksandr Shevchuk S21, TMagen773637, Erel Regev\n"
        main_dir=$(pwd)/remote_control_results
        mkdir -p "$main_dir" > /dev/null 2>&1
        cd "$main_dir"
        working_dir="$timestamp"
        mkdir -p "$working_dir"
        cd "$working_dir"
        echo -e "\e[30m\e[107mCurrent working directory: $(pwd)\e[0m\n"
        CHECK_INTERNET_CONNECTION
    fi     
}

CHECK_INTERNET_CONNECTION()
{
    echo -e "\e[31m[*]\e[0m\e[34m Checking for the presence of utilities required for performing the analysis:\e[0m"
    sleep 2
    if ping -c 1  -W 3 8.8.8.8 > /dev/null 2>&1; then
        apt update > /dev/null 2>&1
        CHECK_NIPE
    else
        echo -e "\n\e[91m\e[107m[!] No internet connection. Check your network.\e[0m\n"
            sleep 2
            exit 1
    fi
}

CHECK_NIPE()
{
    echo -e "[*] Checking nipe..."
    nipe_path=$(find / -type f -name nipe.pl 2>/dev/null | grep "/nipe/nipe.pl" | head -n 1)
    if [[ -z "$nipe_path" ]]; then
        echo -e "\e[91m\e[107m[!] 'nipe.pl' not found on the system.\e[0m"
        echo -e "\e[31m[*]\e[0m\e[34m Installing nipe...\e[0m"
        if [[ ! -d /opt ]]; then
            mkdir -p /opt
        fi
        cd /opt
        git clone https://github.com/htrgouvea/nipe.git || { echo -e "\e[91m\e[107m[!] Failed to clone nipe.\e[0m"; exit 1; }
        cd nipe
        cpan install Try::Tiny Config::Simple JSON || { echo -e "\e[91m\e[107m[!] Failed to install.\e[0m"; exit 1; }
        perl nipe.pl install || { echo -e "\e[91m\e[107m[!] Failed to install.\e[0m"; exit 1; }
        echo -e "\e[31m[*]\e[0m\e[32m nipe installed successfully\e[0m"       
    else
        echo -e "\e[32m[✔] nipe\e[0m"
        sleep 0.6
    fi
    CHECK_APP
}


CHECK_APP()
{
    utilities_for_check="tor ssh nmap whois curl"
    for i in $utilities_for_check; do
        if ! command -v "$i" > /dev/null 2>&1; then
            echo -e "\e[91m\e[107m[!] '$i' is not installed.\e[0m"
            apt install "$i" -y || { echo -e "\e[91m\e[107m[!] Failed to install '$i'.\e[0m"; exit 1; }
        else
            echo -e "\e[32m[✔] $i\e[0m"
        fi
        sleep 0.6
    done
}


START