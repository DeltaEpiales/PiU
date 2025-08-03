#!/bin/bash

# Pi-hole Admin Toolkit
# A comprehensive, menu-driven script for managing a Pi-hole instance.

# --- Color Definitions ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---
press_enter_to_continue() {
    echo -e "\n${YELLOW}Press [Enter] to return to the menu...${NC}"
    read -r
}

# --- Core Functions ---

show_dashboard() {
    clear
    echo "========================================"
    echo "  Pi-hole Health Dashboard"
    echo "========================================"
    
    # Service Status
    if pihole status | grep -q "DNS service is running"; then
        echo -e "Service Status:  [  ${GREEN}OK${NC}  ] FTL is running"
    else
        echo -e "Service Status:  [ ${RED}FAIL${NC} ] FTL is not running"
    fi

    # Blocking Status
    if pihole status | grep -q "Blocking is enabled"; then
        echo -e "Blocking Status: [  ${GREEN}OK${NC}  ] Enabled"
    else
        echo -e "Blocking Status: [ ${YELLOW}WARN${NC} ] Disabled"
    fi
    
    # Gravity Info
    gravity_last_updated=$(pihole -g -q | grep "days old")
    echo -e "Gravity DB:      [ ${BLUE}INFO${NC} ] $gravity_last_updated"
    
    # System Vitals
    disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    echo -e "Disk Usage:      [ ${BLUE}INFO${NC} ] $disk_usage used"
    if command -v vcgencmd &> /dev/null; then
        temp=$(vcgencmd measure_temp | egrep -o '[0-9]*\.[0-9]*')
        echo -e "CPU Temp:        [ ${BLUE}INFO${NC} ] ${temp}°C"
    fi
    press_enter_to_continue
}

manage_gravity() {
    clear
    echo "Updating Gravity... this may take a moment."
    pihole -g
    echo -e "\n${GREEN}Gravity update complete.${NC}"
    press_enter_to_continue
}

manage_lists() {
    while true; do
        clear
        echo "========================================"
        echo "  List Management"
        echo "========================================"
        echo "1. Whitelist a domain"
        echo "2. Blacklist a domain"
        echo "3. Add a new Adlist URL"
        echo "4. Search for a domain in adlists"
        echo "5. Back to Main Menu"
        echo "----------------------------------------"
        read -p "Enter your choice [1-5]: " choice

        case $choice in
            1)
                read -p "Enter domain to whitelist: " domain
                pihole -w "$domain"
                press_enter_to_continue
                ;;
            2)
                read -p "Enter domain to blacklist: " domain
                pihole -b "$domain"
                press_enter_to_continue
                ;;
            3)
                read -p "Enter the full URL of the adlist: " adlist_url
                # Add the new URL to the adlists file
                echo "$adlist_url" | sudo tee -a /etc/pihole/adlists.list > /dev/null
                echo "Adlist added to /etc/pihole/adlists.list."
                echo "Remember to Update Gravity to apply changes."
                press_enter_to_continue
                ;;
            4)
                read -p "Enter domain to search for: " domain
                pihole --query-adlists "$domain"
                press_enter_to_continue
                ;;
            5)
                break
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

network_and_log_tools() {
    while true; do
        clear
        echo "========================================"
        echo "  Network & Log Tools"
        echo "========================================"
        echo "1. View Live Query Log (pihole -t)"
        echo "2. View Important Log & Config Files"
        echo "3. Show Top Clients & Blocked Domains"
        echo "4. Scan network for active clients (arp-scan)"
        echo "5. Back to Main Menu"
        echo "----------------------------------------"
        read -p "Enter your choice [1-5]: " choice

        case $choice in
            1)
                clear
                echo "Tailing Pi-hole log... Press Ctrl+C to stop."
                pihole -t
                press_enter_to_continue
                ;;
            2) view_files ;;
            3)
                clear
                echo "--- Top 10 Clients ---"
                echo "SELECT client, count(client) FROM queries GROUP BY client ORDER BY count(client) DESC LIMIT 10;" | sudo sqlite3 /etc/pihole/pihole-FTL.db
                echo -e "\n--- Top 10 Blocked Domains ---"
                pihole -c -t 10
                press_enter_to_continue
                ;;
            4)
                clear
                if command -v arp-scan &> /dev/null; then
                    sudo arp-scan --localnet
                else
                    echo -e "${YELLOW}arp-scan is not installed. Please install it with:${NC}"
                    echo "sudo apt update && sudo apt install arp-scan"
                fi
                press_enter_to_continue
                ;;
            5) break ;;
            *) echo -e "${RED}Invalid option. Please try again.${NC}"; sleep 1 ;;
        esac
    done
}

view_files() {
    while true; do
        clear
        echo "========================================"
        echo "  View Logs & Config Files"
        echo "========================================"
        echo "1. View pihole.log (live query log)"
        echo "2. View pihole-FTL.log (DNS resolver log)"
        echo "3. View setupVars.conf (Core install settings)"
        echo "4. View pihole-FTL.conf (Advanced FTL settings)"
        echo "5. View 01-pihole.conf (Main dnsmasq config)"
        echo "6. View 02-pihole-dhcp.conf (DHCP server config)"
        echo "7. Back to Previous Menu"
        echo "----------------------------------------"
        read -p "Enter your choice [1-7]: " choice
        
        # Use 'less' for easy viewing. Press 'q' to exit viewer.
        case $choice in
            1) less /var/log/pihole/pihole.log ;;
            2) less /var/log/pihole/pihole-FTL.log ;;
            3) less /etc/pihole/setupVars.conf ;;
            4) less /etc/pihole/pihole-FTL.conf ;;
            5) less /etc/dnsmasq.d/01-pihole.conf ;;
            6) less /etc/dnsmasq.d/02-pihole-dhcp.conf ;;
            7) break ;;
            *) echo -e "${RED}Invalid option. Please try again.${NC}"; sleep 1 ;;
        esac
    done
}

control_services() {
    while true; do
        clear
        echo "========================================"
        echo "  Service Control"
        echo "========================================"
        echo "1. Enable Pi-hole blocking"
        echo "2. Disable Pi-hole blocking (for 30 seconds)"
        echo "3. Disable Pi-hole blocking (for 5 minutes)"
        echo "4. Restart DNS resolver (pihole restartdns)"
        echo "5. Back to Main Menu"
        echo "----------------------------------------"
        read -p "Enter your choice [1-5]: " choice

        case $choice in
            1)
                pihole enable
                echo -e "${GREEN}Pi-hole enabled.${NC}"
                press_enter_to_continue
                ;;
            2)
                pihole disable 30s
                echo -e "${YELLOW}Pi-hole disabled for 30 seconds.${NC}"
                press_enter_to_continue
                ;;
            3)
                pihole disable 5m
                echo -e "${YELLOW}Pi-hole disabled for 5 minutes.${NC}"
                press_enter_to_continue
                ;;
            4)
                pihole restartdns
                echo -e "${GREEN}DNS resolver restarted.${NC}"
                press_enter_to_continue
                ;;
            5)
                break
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

change_hostname() {
    clear
    current_hostname=$(hostname)
    echo "Current system hostname is: $current_hostname"
    read -p "Enter the new hostname: " new_hostname

    if [[ -z "$new_hostname" ]]; then
        echo -e "${RED}Hostname cannot be empty.${NC}"
        press_enter_to_continue
        return
    fi
    
    echo -e "\n${RED}WARNING:${NC} This will change the system hostname from '$current_hostname' to '$new_hostname'."
    echo "This requires a system reboot to take full effect."
    read -p "Are you sure you want to continue? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Changing hostname..."
        sudo hostnamectl set-hostname "$new_hostname"
        sudo sed -i "s/127.0.1.1.*$current_hostname/127.0.1.1\t$new_hostname/g" /etc/hosts
        echo -e "${GREEN}Hostname changed. Please reboot your system for changes to apply fully.${NC}"
        echo "You may also need to run 'pihole -r' and choose 'Reconfigure' after rebooting."
    else
        echo "Hostname change cancelled."
    fi
    press_enter_to_continue
}

manage_teleporter() {
    while true; do
        clear
        echo "========================================"
        echo "  Backup & Restore (Teleporter)"
        echo "========================================"
        echo "1. Create a new backup"
        echo "2. Restore from a backup file"
        echo "3. Back to Previous Menu"
        echo "----------------------------------------"
        read -p "Enter your choice [1-3]: " choice

        case $choice in
            1)
                backup_file="teleporter_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
                pihole -a -t "$backup_file"
                echo -e "\n${GREEN}Backup created at: $(pwd)/$backup_file${NC}"
                press_enter_to_continue
                ;;
            2)
                read -p "Enter the full path to the teleporter backup file (.tar.gz): " restore_file
                if [[ -f "$restore_file" ]]; then
                    echo -e "${RED}WARNING:${NC} This will overwrite your current Pi-hole settings."
                    read -p "Are you sure you want to restore from '$restore_file'? (y/N): " confirm_restore
                    if [[ "$confirm_restore" =~ ^[Yy]$ ]]; then
                        pihole -a -t "$restore_file"
                    else
                        echo "Restore cancelled."
                    fi
                else
                    echo -e "${RED}Error: Backup file not found at '$restore_file'${NC}"
                fi
                press_enter_to_continue
                ;;
            3) break ;;
            *) echo -e "${RED}Invalid option. Please try again.${NC}"; sleep 1 ;;
        esac
    done
}


system_and_maintenance() {
     while true; do
        clear
        echo "========================================"
        echo "  System & Maintenance"
        echo "========================================"
        echo "1. Update Pi-hole software (pihole -up)"
        echo "2. Change Pi-hole Hostname"
        echo "3. Backup / Restore Pi-hole (Teleporter)"
        echo "4. Run a debug session (pihole -d)"
        echo "5. Back to Main Menu"
        echo "----------------------------------------"
        read -p "Enter your choice [1-5]: " choice

        case $choice in
            1)
                pihole -up
                press_enter_to_continue
                ;;
            2)
                change_hostname
                ;;
            3)
                manage_teleporter
                ;;
            4)
                pihole -d
                press_enter_to_continue
                ;;
            5)
                break
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- Main Menu ---
while true; do
    clear
    echo "========================================"
    echo "       Pi-hole Admin Toolkit"
    echo "========================================"
    echo -e "What would you like to do?"
    echo -e " ${YELLOW}1)${NC} View Health Dashboard"
    echo -e " ${YELLOW}2)${NC} Update Gravity (Adlists)"
    echo -e " ${YELLOW}3)${NC} Manage Whitelist / Blacklist / Adlists"
    echo -e " ${YELLOW}4)${NC} Network & Log Tools"
    echo -e " ${YELLOW}5)${NC} Service Control (Enable/Disable/Restart)"
    echo -e " ${YELLOW}6)${NC} System & Maintenance"
    echo "----------------------------------------"
    echo -e " ${RED}7)${NC} Exit"
    echo "========================================"
    read -p "Enter your choice [1-7]: " main_choice

    case $main_choice in
        1) show_dashboard ;;
        2) manage_gravity ;;
        3) manage_lists ;;
        4) network_and_log_tools ;;
        5) control_services ;;
        6) system_and_maintenance ;;
        7)
            clear
            echo "Exiting Pi-hole Admin Toolkit. Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            sleep 1
            ;;
    esac
done
