#!/bin/bash

# Pi-hole Admin Toolkit v4.0 (Definitive Edition)
# A comprehensive, menu-driven script for managing and troubleshooting a Pi-hole instance.
# Enhanced with a guided setup, static IP configuration, error checking, and advanced utilities.

# --- Color Definitions ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# --- Helper Functions ---
press_enter_to_continue() {
    echo -e "\n${YELLOW}Press [Enter] to return to the menu...${NC}"
    read -r
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${YELLOW}Warning: Command '$1' not found. Some features may not work.${NC}"
        read -p "Do you want to try and install it now? (y/N): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            sudo apt-get update && sudo apt-get install -y "$1"
        fi
    fi
}

# --- IP Configuration ---
manage_ip_configuration() {
    clear
    echo "========================================"
    echo "  Set Static IP Address"
    echo "========================================"
    echo "This tool will configure a static IP in /etc/dhcpcd.conf."
    echo -e "${RED}A static IP is CRUCIAL for Pi-hole to work reliably.${NC}"
    
    read -p "Which interface do you want to configure? (eth0 for wired, wlan0 for wireless): " interface
    if [[ "$interface" != "eth0" && "$interface" != "wlan0" ]]; then
        echo -e "${RED}Invalid interface. Please choose 'eth0' or 'wlan0'.${NC}"
        press_enter_to_continue
        return
    fi

    echo -e "\nPlease provide the network details:"
    read -p "Static IP address (e.g., 192.168.1.10): " ip_address
    read -p "Subnet mask in CIDR format (e.g., 24): " cidr
    read -p "Gateway/Router IP address (e.g., 192.168.1.1): " gateway

    # Validate input
    if [[ -z "$ip_address" || -z "$cidr" || -z "$gateway" ]]; then
        echo -e "${RED}All fields are required. Aborting.${NC}"
        press_enter_to_continue
        return
    fi
    
    echo -e "\n${YELLOW}Configuration to be applied for interface '$interface':${NC}"
    echo "IP Address:   $ip_address/$cidr"
    echo "Gateway:      $gateway"
    
    read -p "Are you sure you want to apply these settings? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Backing up /etc/dhcpcd.conf to /etc/dhcpcd.conf.bak..."
        sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.bak
        
        # Remove any existing static configurations for the interface to avoid conflicts
        sudo sed -i "/^interface $interface/,/^\s*$/d" /etc/dhcpcd.conf

        echo "Applying new configuration..."
        {
            echo ""
            echo "interface $interface"
            echo "    static ip_address=$ip_address/$cidr"
            echo "    static routers=$gateway"
            echo "    static domain_name_servers=127.0.0.1"
        } | sudo tee -a /etc/dhcpcd.conf > /dev/null

        echo -e "\n${GREEN}Configuration applied successfully!${NC}"
        echo -e "${RED}A system reboot is required for these changes to take effect.${NC}"
        read -p "Do you want to reboot now? (y/N): " reboot_choice
        if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
            sudo reboot
        fi
    else
        echo "Operation cancelled."
    fi
    press_enter_to_continue
}


# --- Guided Configuration ---
run_guided_configuration() {
    clear
    echo "========================================"
    echo "  Pi-hole Guided Configuration"
    echo "========================================"
    echo "This wizard will help you check and fix common setup issues."

    # 1. Check Static IP
    echo -e "\n${BLUE}Step 1: Checking Network Configuration...${NC}"
    if ! grep -q "static ip_address" /etc/dhcpcd.conf; then
        echo -e "${YELLOW}Warning: Your Pi-hole does not appear to have a static IP set in /etc/dhcpcd.conf.${NC}"
        echo "This is the most common cause of Pi-hole failure after a reboot."
        read -p "Would you like to configure a static IP now? (y/N): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            manage_ip_configuration
        fi
    else
        echo -e "${GREEN}Static IP configuration found in /etc/dhcpcd.conf.${NC}"
    fi

    # 2. Check Upstream DNS
    echo -e "\n${BLUE}Step 2: Checking Upstream DNS Servers...${NC}"
    upstream_dns=$(grep 'PIHOLE_DNS_' /etc/pihole/setupVars.conf | cut -d'=' -f2)
    if [[ -z "$upstream_dns" ]]; then
        echo -e "${RED}Error: No upstream DNS servers are configured!${NC}"
        read -p "Run Pi-hole reconfigure to set them now? (y/N): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then pihole -r; fi
    else
        echo -e "${GREEN}Upstream DNS servers found:${NC}\n$upstream_dns"
    fi
    
    echo -e "\n${GREEN}Guided configuration check complete!${NC}"
    press_enter_to_continue
}


# --- Core Functions ---

show_dashboard() {
    clear
    echo "========================================"
    echo "  Pi-hole Health Dashboard"
    echo "========================================"
    
    pihole status
    
    echo -e "\n--- System Vitals ---"
    disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    echo -e "Disk Usage:      [ ${BLUE}INFO${NC} ] $disk_usage used"
    if command -v vcgencmd &> /dev/null; then
        temp=$(vcgencmd measure_temp | egrep -o '[0-9]*\.[0-9]*')
        echo -e "CPU Temp:        [ ${BLUE}INFO${NC} ] ${temp}°C"
    fi
    press_enter_to_continue
}

show_chronometer() {
    clear
    echo "Showing live stats... Press Ctrl+C to exit."
    pihole chronometer
    press_enter_to_continue
}

manage_gravity() {
    clear
    echo "Updating Gravity... this may take a moment."
    pihole -g
    echo -e "\n${GREEN}Gravity update complete.${NC}"
    press_enter_to_continue
}

audit_adlists() {
    clear
    echo "--- Auditing Adlists ---"
    ADLIST_FILE="/etc/pihole/adlists.list"

    # Check for duplicates
    duplicates=$(sort "$ADLIST_FILE" | uniq -d)
    if [[ -n "$duplicates" ]]; then
        echo -e "${YELLOW}Duplicate adlists found:${NC}"
        echo "$duplicates"
        read -p "Do you want to remove these duplicates? (y/N): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            echo "Backing up adlists to ${ADLIST_FILE}.bak"
            sudo cp "$ADLIST_FILE" "${ADLIST_FILE}.bak"
            sort -u "$ADLIST_FILE" -o "$ADLIST_FILE"
            echo "Duplicates removed."
        fi
    else
        echo -e "${GREEN}No duplicate adlists found.${NC}"
    fi

    # Check for unreachable lists
    echo -e "\n--- Checking adlist availability (this may take a while) ---"
    unreachable_count=0
    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            status_code=$(curl -o /dev/null --silent --head --write-out '%{http_code}' --max-time 10 "$line")
            if [[ "$status_code" -ne 200 ]]; then
                echo -e "${RED}Unreachable:${NC} $line (Status: $status_code)"
                unreachable_count=$((unreachable_count + 1))
            fi
        fi
    done < "$ADLIST_FILE"

    if [[ "$unreachable_count" -eq 0 ]]; then
        echo -e "\n${GREEN}All adlists are reachable.${NC}"
    else
        echo -e "\n${YELLOW}Found $unreachable_count unreachable adlist(s). Consider removing them.${NC}"
    fi
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
        echo -e "${PURPLE}5. Audit Adlists (Check for duplicates & dead links)${NC}"
        echo "6. Back to Main Menu"
        echo "----------------------------------------"
        read -p "Enter your choice [1-6]: " choice

        case $choice in
            1)
                read -p "Enter domain to whitelist: " domain
                if [[ -n "$domain" ]]; then pihole -w "$domain"; fi
                press_enter_to_continue
                ;;
            2)
                read -p "Enter domain to blacklist: " domain
                if [[ -n "$domain" ]]; then pihole -b "$domain"; fi
                press_enter_to_continue
                ;;
            3)
                read -p "Enter the full URL of the adlist: " adlist_url
                if [[ -n "$adlist_url" ]]; then
                    echo "$adlist_url" | sudo tee -a /etc/pihole/adlists.list > /dev/null
                    echo "Adlist added. Remember to Update Gravity."
                fi
                press_enter_to_continue
                ;;
            4)
                read -p "Enter domain to search for: " domain
                if [[ -n "$domain" ]]; then pihole --query-adlists "$domain"; fi
                press_enter_to_continue
                ;;
            5)
                audit_adlists
                ;;
            6)
                break
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"; sleep 1 ;;
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
        echo "3. Show Top Clients & Blocked Domains (Last 24h)"
        echo "4. Query a specific client's recent activity"
        echo "5. Scan network for active clients"
        echo "6. Back to Main Menu"
        echo "----------------------------------------"
        read -p "Enter your choice [1-6]: " choice

        case $choice in
            1)
                clear; echo "Tailing Pi-hole log... Press Ctrl+C to stop."; pihole -t; press_enter_to_continue ;;
            2) view_files ;;
            3)
                clear
                echo "--- Top 10 Clients (Last 24h) ---"
                echo "SELECT client, count(client) FROM queries WHERE timestamp >= strftime('%s','now','-24 hours') GROUP BY client ORDER BY count(client) DESC LIMIT 10;" | sudo sqlite3 /etc/pihole/pihole-FTL.db
                echo -e "\n--- Top 10 Blocked Domains (Last 24h) ---"
                echo "SELECT domain, count(domain) FROM queries WHERE status IN (1,4,5,6,7,8,9,10,11) AND timestamp >= strftime('%s','now','-24 hours') GROUP BY domain ORDER BY count(domain) DESC LIMIT 10;" | sudo sqlite3 /etc/pihole/pihole-FTL.db
                press_enter_to_continue
                ;;
            4)
                read -p "Enter client IP address to query: " client_ip
                if [[ -n "$client_ip" ]]; then
                    clear
                    echo "--- Recent queries for $client_ip (last 100) ---"
                    echo "SELECT strftime('%Y-%m-%d %H:%M:%S', timestamp), domain, type, status FROM queries WHERE client='$client_ip' ORDER BY timestamp DESC LIMIT 100;" | sqlite3 /etc/pihole/pihole-FTL.db | while IFS="|" read -r ts dom typ stat; do printf "%-20s %-50s %-5s %s\n" "$ts" "$dom" "$typ" "$stat"; done
                fi
                press_enter_to_continue
                ;;
            5)
                clear
                if command -v arp-scan &> /dev/null; then
                    sudo arp-scan --localnet
                else
                    echo -e "${YELLOW}arp-scan not found. Using pihole's network table as a fallback.${NC}"
                    pihole -c -j | jq -r '.network | .[] | "IP: \(.ip) | MAC: \(.mac) | Name: \(.name[0])"'
                fi
                press_enter_to_continue
                ;;
            6) break ;;
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

system_and_maintenance() {
     while true; do
        clear
        echo "========================================"
        echo "  System & Maintenance"
        echo "========================================"
        echo -e "${PURPLE}1. Set Static IP Address${NC}"
        echo "2. Update Pi-hole software (pihole -up)"
        echo "3. Change Pi-hole Hostname"
        echo "4. Backup / Restore Pi-hole (Teleporter)"
        echo "5. Flush Pi-hole Logs & Network Table"
        echo "6. Run a debug session (pihole -d)"
        echo -e "${RED}7. Reboot System${NC}"
        echo -e "${RED}8. Shutdown System${NC}"
        echo "9. Back to Main Menu"
        echo "----------------------------------------"
        read -p "Enter your choice [1-9]: " choice

        case $choice in
            1)
                manage_ip_configuration ;;
            2)
                pihole -up; press_enter_to_continue ;;
            3)
                change_hostname ;;
            4)
                manage_teleporter ;;
            5)
                clear
                echo -e "${RED}WARNING:${NC} This will permanently delete your query logs and clear the network table."
                read -p "Are you sure you want to continue? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    pihole -f
                    echo "Network table cleared."
                else
                    echo "Operation cancelled."
                fi
                press_enter_to_continue
                ;;
            6)
                pihole -d; press_enter_to_continue ;;
            7)
                read -p "Are you sure you want to REBOOT the system? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then sudo reboot; fi
                ;;
            8)
                read -p "Are you sure you want to SHUT DOWN the system? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then sudo shutdown now; fi
                ;;
            9)
                break ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"; sleep 1 ;;
        esac
    done
}

# --- Main Execution ---

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script uses commands that require root privileges.${NC}" 
   echo "Please run it with sudo: sudo ./pihole_toolkit.sh"
   exit 1
fi

# Check for --configure flag
if [[ "$1" == "--configure" ]]; then
    run_guided_configuration
    exit 0
fi

# Check for required dependencies
check_dependency "arp-scan"
check_dependency "sqlite3"
check_dependency "jq"

while true; do
    clear
    echo "======================================================"
    echo "    Pi-hole Admin Toolkit v4.0 (Definitive Edition)"
    echo "======================================================"
    echo -e " ${YELLOW}1)${NC} Health Dashboard"
    echo -e " ${YELLOW}2)${NC} Live Stats (Chronometer)"
    echo -e " ${YELLOW}3)${NC} Update Gravity (Adlists)"
    echo -e " ${YELLOW}4)${NC} Manage Whitelist / Blacklist / Adlists"
    echo -e " ${YELLOW}5)${NC} Network & Log Tools"
    echo -e " ${YELLOW}6)${NC} System & Maintenance"
    echo "------------------------------------------------------"
    echo -e " ${BLUE}Tip: Run with '--configure' for a guided setup check.${NC}"
    echo -e " ${RED}7)${NC} Exit"
    echo "======================================================"
    read -p "Enter your choice [1-7]: " main_choice

    case $main_choice in
        1) show_dashboard ;;
        2) show_chronometer ;;
        3) manage_gravity ;;
        4) manage_lists ;;
        5) network_and_log_tools ;;
        6) system_and_maintenance ;;
        7)
            clear; echo "Exiting Pi-hole Admin Toolkit. Goodbye!"; exit 0 ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"; sleep 1 ;;
    esac
done
