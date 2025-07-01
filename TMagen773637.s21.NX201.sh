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
        CHECK_APP
    fi     
}

CHECK_APP()
{
    echo -e "\e[31m[*]\e[0m\e[34m Checking for the presence of utilities required for performing the analysis:\e[0m"
    sleep 2
    if ping -c 1  -W 3 8.8.8.8 > /dev/null 2>&1; then
        apt update > /dev/null 2>&1
    else
        echo -e "\n\e[91m\e[107m[!] No internet connection. Check your network.\e[0m\n"
            sleep 2
            exit 1
    fi

    utilites_for_check="nipe tor ssh nmap whois curl"
    for i in $utilites_for_check; do
        if ! command -v "$i" > /dev/null 2>&1; then
            echo -e "\e[91m\e[107m[!] '$i' is not installed.\e[0m"
            if [[ "$i" == "nipe" ]]; then
                INSTALL_NIPE
            else
                apt install "$i" -y > /dev/null 2>install_error.log
                if [[ $? -eq 0 ]]; then
                    echo -e "\e[32m[✔] $i installed successfully\e[0m"
                    # TODO: continue the script
                else
                    echo -e "\e[91m\e[107m[!] Failed to install '$i' .\e[0m"
                    tail -n 5 install_error.log
                    exit 1
                fi
            fi
        else
            echo -e "\e[32m[✔] $i\e[0m"
        fi
        sleep 0.6
    done
}

INSTALL_NIPE()
{
    echo -e "[*] Installing nipe..."
    # TODO: (git clone... etc.)
}

START