#!/usr/bin/env bash

# ================================================
#          OSINTDROID BY FRESH FORENSICS
# ================================================

# --- Colors ---
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"

# --- Animation Functions ---

# Typewriter: prints text in small chunks with a delay
# Handles ANSI escape sequences correctly (they pass through chunk boundaries seamlessly)
typewrite() {
    local text="$1"
    local delay="${2:-0.003}"
    local len=${#text}
    local i=0
    local chunk=2
    while [ $i -lt $len ]; do
        printf "%s" "${text:$i:$chunk}"
        i=$((i + chunk))
        sleep "$delay"
    done
}

# Brief fade-out transition when cycling back to menu
menu_fade() {
    local i
    printf "\n${DIM}"
    for ((i=0; i<3; i++)); do
        printf "·"
        sleep 0.12
    done
    printf "${RESET}\r"
    sleep 0.05
    printf "   \r"
}

# --- Banner ---
animate_banner() {
    local color_code=$GREEN
    local line
    echo -e "${color_code}"
    while IFS= read -r line; do
        echo -e "${line}"
        sleep 0.02
    done << "BANNER_EOF"

⣿⣿⣿⣿⣿⣿⣧⠻⣿⣿⠿⠿⠿⢿⣿⠟⣼⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⠟⠃⠁⠀⠀⠀⠀⠀⠀⠘⠻⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⡿⠃⠀⣴⡄⠀⠀⠀⠀⠀⣴⡆⠀⠘⢿⣿⣿⣿⣿
⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⣿
⣿⠿⢿⣿⠶⠶⠶⠶⠶⠶⠶⠶⠶⠶⠶⠶⠶⠶⠶⣿⡿⠿⣿
⡇⠀⠀⣿  OsintDroid  ⠀⣿⠀⠀⢸
⡇⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⢸
⡇⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⢸
⡇⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⢸
⣧⣤⣤⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣤⣤⣼
⣿⣿⣿⣿⣶⣤⡄⠀⠀⠀⣤⣤⣤⠀⠀⠀⢠⣤⣴⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⣿⣿⣿⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣤⣤⣴⣿⣿⣿⣦⣤⣤⣾⣿⣿⣿⣿⣿⣿

BANNER_EOF
    echo -e "${RESET}"  # Reset color
}

# --- Pre-flight Checks ---
check_adb() {
    if ! command -v adb &> /dev/null; then
        echo -e "${RED}${BOLD}ERROR: ADB not found!${RESET}"
        echo -e "${YELLOW}Please install Android Debug Bridge (ADB) and ensure it's in your PATH.${RESET}"
        echo -e "${YELLOW}Download: https://developer.android.com/studio/releases/platform-tools${RESET}"
        exit 1
    fi
    typewrite "${GREEN}[✓] ADB is installed${RESET}" 0.004
    echo
}

check_device() {
    local adb_output raw_output
    adb_output=$(adb devices 2>/dev/null)
    raw_output=$(echo "$adb_output" | awk 'NR>1 && NF {print $0}')

    if [ -z "$raw_output" ]; then
        echo -e "${RED}${BOLD}ERROR: No Android device detected!${RESET}"
        echo -e "${YELLOW}Make sure:${RESET}"
        echo -e "${YELLOW}  1) USB debugging is enabled on your device${RESET}"
        echo -e "${YELLOW}  2) Your device is connected via USB${RESET}"
        echo -e "${YELLOW}  3) You've authorized the connection${RESET}"
        exit 1
    fi

    # Check device statuses from the single adb output
    local unauthorized offline ready count
    unauthorized=$(echo "$adb_output" | awk 'NR>1 && $2=="unauthorized"')
    offline=$(echo "$adb_output" | awk 'NR>1 && $2=="offline"')
    ready=$(echo "$adb_output" | awk 'NR>1 && $2=="device" {print $1}')
    count=$(echo "$ready" | grep -c .)

    if [ -n "$unauthorized" ]; then
        echo -e "${RED}${BOLD}ERROR: Device is unauthorized!${RESET}"
        echo -e "${YELLOW}Please check your device and accept the USB debugging authorization prompt.${RESET}"
        exit 1
    fi

    if [ -n "$offline" ]; then
        echo -e "${RED}${BOLD}ERROR: Device is offline!${RESET}"
        echo -e "${YELLOW}Please reconnect your device and try again.${RESET}"
        exit 1
    fi

    if [ "$count" -eq 0 ]; then
        echo -e "${RED}${BOLD}ERROR: No device in 'device' state (found $(echo "$raw_output" | grep -c .) device(s) but none are ready).${RESET}"
        exit 1
    fi

    # Select device (handles single and multi-device)
    select_device
}
menu() {
    echo -e "${YELLOW}Choose an option:${RESET}"
    if [ -n "$ADB_SERIAL" ]; then
        echo -e "${CYAN}  Target device: ${BOLD}$ADB_SERIAL${RESET}"
    fi
    echo -e "${GREEN}  1)${RESET} Number of Reboots"
    echo -e "${GREEN}  2)${RESET} List Registered Emails"
    echo -e "${GREEN}  3)${RESET} List Account Applications"
    echo -e "${GREEN}  4)${RESET} List Phone Contacts"
    echo -e "${GREEN}  5)${RESET} Dump Call Logs"
    echo -e "${GREEN}  6)${RESET} Dump SMS"
    echo -e "${GREEN}  7)${RESET} List All APKs"
    echo -e "${GREEN}  8)${RESET} List 3rd Party"
    echo -e "${GREEN}  9)${RESET} Dump Secret Codes"
    echo -e "${GREEN} 10)${RESET} Dump WiFi Passwords"
    echo -e "${GREEN} 11)${RESET} Switch Device"
    echo -e "${GREEN} 12)${RESET} Device Properties"
    echo -e "${GREEN} 13)${RESET} App Permissions"
    echo -e "${GREEN} 14)${RESET} Location Forensics (GPS/BT/WiFi scan)"
    echo -e "${GREEN} 15)${RESET} Application Usage Timeline (UsageStats)"
    echo -e "${GREEN} 16)${RESET} Logcat Sensitive Data Leak Scanner"
    echo -e "${GREEN} 17)${RESET} SIM & Network Operator Forensics"
    echo -e "${GREEN} 18)${RESET} Battery & Charging Diagnostics"
    echo -e "${GREEN} 19)${RESET} Detailed Bluetooth Ecosystem"
    echo -e "${GREEN} 20)${RESET} Storage & Partition Analysis"
    echo -e "${GREEN} 21)${RESET} Installed Browser Profiles & Cache"
    echo -e "${GREEN} 22)${RESET} Device Security Status & Encryption"
    echo -e "${GREEN} 23)${RESET} Live Network Sockets (Netstat)"
    echo -e "${GREEN} 24)${RESET} Active Screen Focus (WindowManager)"
    echo -e "${GREEN} 25)${RESET} Active Camera & Audio Streams Audit"
    echo -e "${GREEN} 26)${RESET} Android Keystore Cryptographic Footprints"
    echo -e "${GREEN} 27)${RESET} Hardware Sensor Registry & Listeners"
    echo -e "${GREEN} 28)${RESET} Shared UID & App Signatures Audit"
    echo -e "${GREEN} 29)${RESET} Deep Activity Task Stack History"
    echo -e "${GREEN} 30)${RESET} Input Methods & Custom Keyboards"
    echo -e "${GREEN} 31)${RESET} Wi-Fi RTT Locational Capabilities"
    echo -e "${DIM}  (batch: use commas or ranges, e.g. ${BOLD}4,5,6${RESET}${DIM} or ${BOLD}1-31${RESET}${DIM})${RESET}"
    echo -e "${GREEN}  0)${RESET} Exit"
    echo
}

OUTPUT_DIR=""
ADB_SERIAL=""
SPINNER_PID=""

# --- Spinner / Progress Bar ---

# Indeterminate progress bar that bounces a ▶ cursor inside [━━━▶    ]
spinner_start() {
    local msg="${1:-Working}"
    local bar_width=20
    (
        local pos=0 dir=1
        while true; do
            printf "\r${YELLOW}[" >&2
            local j
            for ((j=0; j<bar_width; j++)); do
                if [ "$j" -eq "$pos" ]; then
                    printf "${GREEN}▶${RESET}" >&2
                elif [ "$j" -lt "$pos" ]; then
                    printf "${GREEN}━${RESET}" >&2
                else
                    printf " " >&2
                fi
            done
            printf "${YELLOW}]${RESET} %s..." "$msg" >&2
            pos=$((pos + dir))
            [ "$pos" -ge "$((bar_width - 1))" ] && { dir=-1; pos=$((bar_width - 2)); }
            [ "$pos" -le 0 ] && { dir=1; pos=1; }
            sleep 0.05
        done
    ) &
    SPINNER_PID=$!
}

# Stops the progress bar and shows an animated checkmark
spinner_stop() {
    if [ -n "$SPINNER_PID" ]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
        # Animated checkmark
        printf "\r${YELLOW}[   ]${RESET}                         " >&2
        sleep 0.04
        printf "\r${YELLOW}[ ${YELLOW}✓${RESET} ${YELLOW}]${RESET}                         " >&2
        sleep 0.04
        printf "\r${GREEN}[ ✓ ]${RESET} Done.                     \n" >&2
        SPINNER_PID=""
    fi
}

# Ensure spinner is cleaned up on exit
cleanup() {
    [ -n "$SPINNER_PID" ] && kill "$SPINNER_PID" 2>/dev/null
}
trap cleanup EXIT INT TERM

adb_target() {
    if [ -n "$ADB_SERIAL" ]; then
        echo "adb -s $ADB_SERIAL"
    else
        echo "adb"
    fi
}

select_device() {
    local adb_output ready_list count choice
    adb_output=$(adb devices 2>/dev/null)
    ready_list=$(echo "$adb_output" | awk 'NR>1 && $2=="device" {print $1}')
    count=$(echo "$ready_list" | grep -c .)

    if [ "$count" -eq 0 ]; then
        echo -e "${RED}${BOLD}ERROR: No ready device available!${RESET}"
        return 1
    fi

    if [ "$count" -eq 1 ]; then
        ADB_SERIAL="$ready_list"
        typewrite "${GREEN}  → Using device: $ADB_SERIAL${RESET}" 0.004
        echo
        return 0
    fi

    echo
    typewrite "${YELLOW}Multiple devices detected. Select one:${RESET}" 0.004
    echo
    echo "$ready_list" | awk '{print NR") "$0}'
    echo
    read -p "$(echo -e $MAGENTA'Select device (1-'$count'): '$RESET)" choice

    local selected
    selected=$(echo "$ready_list" | sed -n "${choice}p")
    if [ -z "$selected" ]; then
        typewrite "${RED}Invalid selection. Using default.${RESET}" 0.004
        echo
        ADB_SERIAL=""
    else
        ADB_SERIAL="$selected"
        typewrite "${GREEN}  → Using device: $ADB_SERIAL${RESET}" 0.004
        echo
    fi
}

setup_output_dir() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    OUTPUT_DIR="output/OsintDroid_$timestamp"
    mkdir -p "$OUTPUT_DIR"
    typewrite "${GREEN}[✓] Exports will be saved to: $OUTPUT_DIR${RESET}" 0.003
    echo
}

human_size() {
    local bytes=$1
    if [ "$bytes" -ge 1048576 ]; then
        echo "$((bytes / 1048576)).$(((bytes % 1048576) * 10 / 1048576)) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$((bytes / 1024)).$(((bytes % 1024) * 10 / 1024)) KB"
    else
        echo "$bytes B"
    fi
}

show_help() {
    echo -e "${CYAN}════════════════════════════════════════${RESET}"
    typewrite "${BOLD}  OsintDroid${RESET} — Android forensic data extraction tool" 0.004
    echo -e "${CYAN}════════════════════════════════════════${RESET}"
    echo -e "  ${YELLOW}Requirements:${RESET} Android device with USB Debugging enabled"
    typewrite "  ${YELLOW}Commands:${RESET}    Enter a number (1-14) or batch like ${BOLD}4,5,6${RESET} or ${BOLD}1-6${RESET}" 0.004
    typewrite "  ${YELLOW}Exports:${RESET}      Some options save results to the ${BOLD}output/${RESET} folder" 0.004
    typewrite "  ${YELLOW}Device:${RESET}       Use option ${BOLD}11${RESET} to switch to a different device" 0.004
    typewrite "  ${YELLOW}Exit:${RESET}         Press ${BOLD}0${RESET} to quit and see an export summary" 0.005
    echo -e "${CYAN}════════════════════════════════════════${RESET}"
    echo
}

show_summary() {
    if [ -z "$OUTPUT_DIR" ] || [ ! -d "$OUTPUT_DIR" ]; then
        return
    fi

    local files found count
    files=("$OUTPUT_DIR"/*.txt)
    found=0
    for f in "${files[@]}"; do
        [ -f "$f" ] && found=1 && break
    done

    if [ "$found" -eq 0 ]; then
        return
    fi

    echo -e "\n${CYAN}${BOLD}══════════════════════════════════${RESET}"
    echo -e "${CYAN}${BOLD}   SESSION EXPORT SUMMARY${RESET}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════${RESET}"
    echo -e "${YELLOW}  Directory:${RESET} $OUTPUT_DIR"
    echo

    local total_size=0
    local count=0
    local file raw_size name desc display

    for file in "${files[@]}"; do
        [ -f "$file" ] || continue

        raw_size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
        name=$(basename "$file")

        case "$name" in
            contacts.txt)      desc="Phone contacts with numbers" ;;
            call_logs.txt)     desc="Call history logs" ;;
            sms.txt)           desc="SMS messages" ;;
            wifi_passwords.txt) desc="WiFi credentials" ;;
            device_info.txt)   desc="Device hardware and software properties" ;;
            permissions.txt)       desc="App permission grants" ;;
            location_forensics.txt) desc="GPS, Bluetooth, and WiFi scan history" ;;
            usagestats.txt)    desc="Application usage telemetry" ;;
            logcat_leak_scan.txt) desc="Scanned system logs for sensitive data leaks" ;;
            telephony_info.txt) desc="SIM operator & cellular status" ;;
            battery_diagnostics.txt) desc="Battery health & telemetry stats" ;;
            bluetooth_ecosystem.txt) desc="Bluetooth paired & bonded device map" ;;
            storage_partitions.txt) desc="Filesystem partitions & disk usage" ;;
            browser_detection.txt) desc="Installed web browsers & profile scan" ;;
            device_security.txt) desc="Lockscreen active status & device encryption" ;;
            network_sockets.txt) desc="Active live network sockets" ;;
            active_screen.txt) desc="Active foreground application and activity" ;;
            camera_audio.txt)  desc="Active camera & audio hardware logs" ;;
            keystore_footprints.txt) desc="Exposed Android Keystore alias & algorithm footprints" ;;
            sensor_registry.txt) desc="Hardware sensors and active listener background list" ;;
            shared_uids.txt)   desc="Identified system and custom shared UIDs" ;;
            activity_stack.txt) desc="Navigated tasks & Activity stack history" ;;
            input_methods.txt)  desc="Active keyboard, input engines, and dictionaries" ;;
            wifi_rtt.txt)       desc="Wi-Fi RTT indoor ranging capability diagnostics" ;;
            *)                      desc="Exported data" ;;
        esac

        display=$(human_size "$raw_size")
        echo -e "  ${GREEN}•${RESET} ${BOLD}$name${RESET}  ($display)  — $desc"

        total_size=$((total_size + raw_size))
        count=$((count + 1))
    done

    echo
    echo -e "${CYAN}  Total: ${BOLD}$count file(s)${RESET}${CYAN} — ${BOLD}$(human_size $total_size)${RESET}"
    echo -e "${CYAN}══════════════════════════════════${RESET}\n"
}

# --- Option Functions ---
option_1() {
    typewrite "${GREEN}Running: $(adb_target) shell settings list global${RESET}" 0.003
    echo
    $(adb_target) shell settings list global|grep "boot_count="|cut -d= -f2|head -n 1|xargs echo "Booted:"|sed 's/$/ times/g'
}

option_2() {
    typewrite "${GREEN}Querying device accounts...${RESET}" 0.004
    echo
    spinner_start "Querying accounts"
    local result
    result=$($(adb_target) shell dumpsys account 2>/dev/null)
    spinner_stop
    typewrite "${GREEN}Listing all emails used on device:${RESET}" 0.004
    echo
    echo "$result" | grep -aE -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"
}

option_3() {
    typewrite "${GREEN}Querying device accounts...${RESET}" 0.004
    echo
    spinner_start "Querying accounts"
    local result
    result=$($(adb_target) shell dumpsys account 2>/dev/null)
    spinner_stop
    typewrite "${GREEN}Listing all applications the user has an account on...${RESET}" 0.004
    echo
    echo "$result" | grep -i com.*$ -o | cut -d' ' -f1 | cut -d} -f1 | grep -v com$
}

option_4() {
    local file="$OUTPUT_DIR/contacts.txt"
    typewrite "${GREEN}Listing all contacts and associated phone numbers...${RESET}" 0.004
    echo
    echo "=== Contacts (exported $(date)) ===" > "$file"
    spinner_start "Exporting contacts"
    $(adb_target) shell content query --uri content://contacts/phones/ --projection display_name:number 2>/dev/null | tee -a "$file"
    spinner_stop
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_5() {
    local file="$OUTPUT_DIR/call_logs.txt"
    typewrite "${GREEN}Dumping all call logs...${RESET}" 0.004
    echo
    echo "=== Call Logs (exported $(date)) ===" > "$file"
    spinner_start "Exporting call logs"
    $(adb_target) shell content query --uri content://call_log/calls 2>/dev/null | tee -a "$file"
    spinner_stop
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_6() {
    local file="$OUTPUT_DIR/sms.txt"
    typewrite "${GREEN}Dumping all sms messages...${RESET}" 0.004
    echo
    echo "=== SMS Messages (exported $(date)) ===" > "$file"
    spinner_start "Exporting SMS messages"
    $(adb_target) shell content query --uri content://sms/ 2>/dev/null | tee -a "$file"
    spinner_stop
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_7() {
    typewrite "${GREEN}Listing all install packages...${RESET}" 0.004
    echo
    $(adb_target) shell pm list packages
}

option_8() {
    typewrite "${GREEN}Listing all 3rd party packages...${RESET}" 0.004
    echo
    $(adb_target) shell pm list packages -3
}

option_wifi() {
    local file="$OUTPUT_DIR/wifi_passwords.txt"
    typewrite "${GREEN}Dumping saved WiFi credentials...${RESET}" 0.004
    echo
    echo "=== WiFi Passwords (exported $(date)) ===" > "$file"
    echo "" >> "$file"

    # Check if root is available
    typewrite "${YELLOW}Checking root access...${RESET}" 0.004
    spinner_start "Testing root access"
    local has_root
    $(adb_target) shell 'su -c "id"' 2>/dev/null | grep -q "uid=0" && has_root=1 || has_root=0
    spinner_stop
    if [ "$has_root" -eq 1 ]; then
        typewrite "${GREEN}[✓] Root available${RESET}" 0.004
        echo
        typewrite "${GREEN}Reading /data/misc/wifi/wpa_supplicant.conf...${RESET}" 0.003
        echo
        echo -e "\n--- wpa_supplicant.conf ---" >> "$file"
        spinner_start "Reading wpa_supplicant.conf"
        $(adb_target) shell su -c 'cat /data/misc/wifi/wpa_supplicant.conf' >> "$file" 2>/dev/null \
            && { spinner_stop; typewrite "${GREEN}  [✓] wpa_supplicant.conf found${RESET}" 0.003; echo; } \
            || { spinner_stop; typewrite "${YELLOW}  [i] wpa_supplicant.conf not found (Android 10+ uses WifiConfigStore)${RESET}" 0.003; echo; }

        # Try WifiConfigStore.xml (Android 10+)
        typewrite "${GREEN}Reading /data/misc/wifi/WifiConfigStore.xml...${RESET}" 0.003
        echo
        echo -e "\n--- WifiConfigStore.xml ---" >> "$file"
        spinner_start "Reading WifiConfigStore.xml"
        $(adb_target) shell su -c 'cat /data/misc/wifi/WifiConfigStore.xml' >> "$file" 2>/dev/null \
            && { spinner_stop; typewrite "${GREEN}  [✓] WifiConfigStore.xml found${RESET}" 0.003; echo; } \
            || { spinner_stop; typewrite "${YELLOW}  [i] WifiConfigStore.xml not found${RESET}" 0.003; echo; }

        # Also try the old wpa_supplicant path for older devices
        typewrite "${GREEN}Reading /data/misc/wifi/wpa_supplicant/wpa_supplicant.conf...${RESET}" 0.003
        echo
        echo -e "\n--- wpa_supplicant/wpa_supplicant.conf ---" >> "$file"
        spinner_start "Reading alternate path"
        $(adb_target) shell su -c 'cat /data/misc/wifi/wpa_supplicant/wpa_supplicant.conf' >> "$file" 2>/dev/null \
            && { spinner_stop; typewrite "${GREEN}  [✓] Alternate path found${RESET}" 0.003; echo; } \
            || { spinner_stop; typewrite "${YELLOW}  [i] Alternate path not found${RESET}" 0.003; echo; }
    else
        typewrite "${YELLOW}[✗] No root access${RESET}" 0.004
        echo
        typewrite "${YELLOW}Root access is required to read WiFi config files directly.${RESET}" 0.004
        echo
        typewrite "${YELLOW}Trying alternative non-root methods...${RESET}" 0.004
        echo

        # Non-root: show connected network info from dumpsys
        echo -e "\n=== Connected Network (dumpsys wifi) ===" >> "$file"
        typewrite "${GREEN}Current WiFi network info...${RESET}" 0.004
        echo
        spinner_start "Querying WiFi info"
        local wifi_dump
        wifi_dump=$($(adb_target) shell dumpsys wifi 2>/dev/null)
        spinner_stop
        echo "$wifi_dump" | grep -iE "ssid|psk|password|key|network.id|network_id|wificonfiguration" | head -30 | tee -a "$file"

        # Try cmd wifi (works on some devices without root)
        echo -e "\n=== Saved Networks (cmd wifi) ===" >> "$file"
        typewrite "${GREEN}Saved networks via cmd wifi...${RESET}" 0.004
        echo
        spinner_start "Querying saved networks"
        local wifi_networks
        wifi_networks=$($(adb_target) shell cmd wifi list-networks 2>/dev/null)
        spinner_stop
        echo "$wifi_networks" | tee -a "$file"

        # Show the current connection details
        echo -e "\n=== Current Connection (wifi status) ===" >> "$file"
        typewrite "${GREEN}Current connection status...${RESET}" 0.004
        echo
        spinner_start "Querying connection status"
        local wifi_status
        wifi_status=$($(adb_target) shell dumpsys wifi 2>/dev/null)
        spinner_stop
        echo "$wifi_status" | grep -iE "mNetworkInfo|mWifiInfo|SSID:-|linkSpeed|frequency|rssi" | head -20 | tee -a "$file"

        echo -e "\n${YELLOW}Note: Without root, only the current connected SSID is visible —
passwords are protected by Android Keystore on modern devices.${RESET}"
    fi

    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_9() {
    typewrite "${GREEN}Dumping Android secret codes from system packages...${RESET}" 0.004
    echo

    # Get system package names
    spinner_start "Fetching system packages"
    local pkg_list
    pkg_list=$($(adb_target) shell pm list packages -s -f 2>/dev/null \
        | awk -F 'package:' '{print $2}' \
        | awk -F '=' '{print $2}')
    spinner_stop

    for pkg in ${pkg_list}; do
        spinner_start "Dumping $pkg"
        local pkg_dump
        pkg_dump=$($(adb_target) shell pm dump "${pkg}" 2>/dev/null)
        spinner_stop

        typewrite "${GREEN}Package:${RESET} ${pkg}" 0.003
        echo
        echo "$pkg_dump" \
            | grep -E 'Scheme: "android_secret_code"|Authority: "[0-9].*"|Authority: "[A-Z].*"' \
            | while IFS= read -r line; do
                echo -e "  ${GREEN}${line}${RESET}"
            done

        echo
    done

    typewrite "${GREEN}Secret code dump complete.${RESET}" 0.004
    echo
}

option_device_info() {
    local file="$OUTPUT_DIR/device_info.txt"
    typewrite "${GREEN}Gathering device properties...${RESET}" 0.004
    echo

    echo "=== Device Properties (exported $(date)) ===" > "$file"

    spinner_start "Fetching device info"
    local props
    props=$($(adb_target) shell getprop 2>/dev/null)
    spinner_stop

    # Key properties to highlight
    local key_pattern="^\[(ro\.product\.model|ro\.product\.manufacturer|ro\.build\.version\.release|ro\.build\.version\.sdk|ro\.build\.version\.security_patch|ro\.build\.date|ro\.serialno|ro\.boot\.serialno|ro\.build\.display\.id|persist\.sys\.timezone|gsm\.sim\.operator\.alpha|ro\.build\.fingerprint|ro\.product\.cpu\.abi|ro\.hardware|ro\.build\.type|ro\.product\.name|persist\.sys\.locale|ro\.product\.board|ro\.build\.description)\]"

    echo -e "\n${CYAN}${BOLD}Key Device Properties:${RESET}" | tee -a "$file"
    echo
    echo "$props" | grep -E "$key_pattern" | while IFS= read -r line; do
        local key val
        key=$(echo "$line" | sed -n 's/^\[\(.*\)\]:.*$/\1/p')
        val=$(echo "$line" | sed -n 's/^\[.*\]:\s*\[\(.*\)\]$/\1/p')
        [ -n "$val" ] && printf "  ${CYAN}%-40s${RESET} %s\n" "$key" "$val"
        echo "$line" >> "$file"
    done

    echo -e "\n${DIM}Full property list saved to: $file${RESET}"

    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_permissions() {
    local file="$OUTPUT_DIR/permissions.txt"
    typewrite "${GREEN}Scanning app permissions...${RESET}" 0.004
    echo

    echo "=== App Permissions (exported $(date)) ===" > "$file"

    spinner_start "Fetching permission data"
    local dump
    dump=$($(adb_target) shell dumpsys package packages 2>/dev/null)
    spinner_stop

    # Regex matching the dangerous permission names (full paths to avoid false matches)
    local danger_re="android\\.permission\\.(CAMERA|RECORD_AUDIO|ACCESS_FINE_LOCATION|ACCESS_COARSE_LOCATION|READ_CONTACTS|READ_CALL_LOG|READ_SMS|READ_EXTERNAL_STORAGE|SEND_SMS|RECEIVE_SMS|READ_PHONE_STATE|CALL_PHONE|READ_CALENDAR|BODY_SENSORS|ACTIVITY_RECOGNITION)"

    echo -e "\n${CYAN}${BOLD}Packages with dangerous permissions:${RESET}" | tee -a "$file"
    echo >> "$file"

    # Parse dumpsys output: extract packages that have dangerous install/runtime permissions
    echo "$dump" | grep -E "^  Package \[|install-permissions:|runtime-permissions:|android\.permission\." | awk -v danger="$danger_re" '
        /^  Package \[/ {
            if (pkg != "" && has_danger) print_block()
            match($0, /\[([^]]+)\]/)
            pkg = substr($0, RSTART+1, RLENGTH-2)
            perms = ""
            has_danger = 0
            next
        }
        {
            line = $0
            if (line ~ /android\.permission\./) {
                perms = perms line "\n"
                if (line ~ danger) has_danger = 1
            }
        }
        function print_block() {
            print "--- " pkg " ---"
            printf "%s", perms
        }
        END { if (pkg != "" && has_danger) print_block() }
    ' | tee -a "$file"

    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_location() {
    local file="$OUTPUT_DIR/location_forensics.txt"
    typewrite "${GREEN}Running location forensics dump...${RESET}" 0.004
    echo

    echo "=== Location Forensics (exported $(date)) ===" > "$file"

    # --- GPS / Location ---
    echo -e "\n${CYAN}${BOLD}═══ GPS / Location Providers ═══${RESET}"
    echo -e "\n=== GPS / Location Providers ===" >> "$file"

    spinner_start "Querying location providers"
    local loc_dump
    loc_dump=$($(adb_target) shell dumpsys location 2>/dev/null)
    spinner_stop

    # Show enabled providers
    local providers
    providers=$($(adb_target) shell settings get secure location_providers_allowed 2>/dev/null)
    typewrite "${GREEN}Location providers enabled:${RESET} ${providers:-none}" 0.004
    echo
    echo "Location providers enabled: $providers" >> "$file"

    # Show last known locations
    echo "$loc_dump" | grep -iE "last location|lastknown|last Know" | head -10 | tee -a "$file"

    # Show providers and listeners
    echo "$loc_dump" | grep -iE "gps|network|fused|passive|provider|listener|request" | grep -v "\[\]" | head -30 | tee -a "$file"

    echo -e "\n${DIM}Location data saved to: $file${RESET}"

    # --- Bluetooth ---
    echo -e "\n${CYAN}${BOLD}═══ Bluetooth ═══${RESET}"
    echo -e "\n=== Bluetooth ===" >> "$file"

    spinner_start "Querying Bluetooth"
    local bt_dump
    bt_dump=$($(adb_target) shell dumpsys bluetooth_manager 2>/dev/null)
    spinner_stop

    # Check if BT scanning is enabled
    local ble_scan
    ble_scan=$($(adb_target) shell settings get global ble_scan_always_enabled 2>/dev/null)
    typewrite "${GREEN}BLE scanning always enabled:${RESET} ${ble_scan:-unknown}" 0.004
    echo

    # Paired / bonded devices
    echo "$bt_dump" | grep -iE "bonded|paired|connected|device|name:|address:" | head -20 | tee -a "$file"

    # Bluetooth state
    echo "$bt_dump" | grep -iE "state:|adapter|enabled|discover|scan_mode" | head -10 | tee -a "$file"

    echo -e "\n${DIM}Bluetooth data saved to: $file${RESET}"

    # --- WiFi Scan History ---
    echo -e "\n${CYAN}${BOLD}═══ WiFi Scan History ═══${RESET}"
    echo -e "\n=== WiFi Scan History ===" >> "$file"

    spinner_start "Querying WiFi scan history"
    local wifi_dump
    wifi_dump=$($(adb_target) shell dumpsys wifi 2>/dev/null)
    spinner_stop

    # Scan results (visible networks)
    echo -e "${YELLOW}Recent scan results (visible networks):${RESET}"
    echo -e "\n--- Recent Scan Results ---" >> "$file"
    echo "$wifi_dump" | grep -iE "SSID:|BSSID:|frequency|rssi|capabilities|level:" | head -50 | tee -a "$file"

    # Connection history
    echo -e "\n${YELLOW}Connection state and history:${RESET}"
    echo -e "\n--- Connection State ---" >> "$file"
    echo "$wifi_dump" | grep -iE "mNetworkInfo|mWifiInfo|linkSpeed|supplicant|state:" | head -20 | tee -a "$file"

    # WiFi interface state
    echo -e "\n${YELLOW}WiFi interface:${RESET}"
    echo -e "\n--- Interface ---" >> "$file"
    echo "$wifi_dump" | grep -iE "interface|isHidden|is24ghz|is5ghz|is6ghz|wifi_on|scanning" | head -20 | tee -a "$file"

    # Passpoint / saved networks from dumpsys
    echo -e "\n${YELLOW}Saved networks info:${RESET}"
    echo -e "\n--- Saved Networks ---" >> "$file"
    echo "$wifi_dump" | grep -iE "networkid|network_id|configured|priority|scan_ssid|key_mgmt" | head -20 | tee -a "$file"

    echo -e "\n${DIM}WiFi scan data saved to: $file${RESET}"

    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_15() {
    local file="$OUTPUT_DIR/usagestats.txt"
    typewrite "${GREEN}Dumping application usage stats...${RESET}" 0.004
    echo
    echo "=== Application Usage Stats (exported $(date)) ===" > "$file"
    spinner_start "Exporting usagestats"
    $(adb_target) shell dumpsys usagestats 2>/dev/null | tee -a "$file"
    spinner_stop
    # Print a nice summary of the most recently used packages
    echo -e "\n${CYAN}${BOLD}Top recently active packages:${RESET}"
    echo "$($(adb_target) shell dumpsys usagestats 2>/dev/null | grep -iE 'package=|time=' | head -30)"
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_16() {
    local file="$OUTPUT_DIR/logcat_leak_scan.txt"
    typewrite "${GREEN}Scanning recent logcat for sensitive leaks...${RESET}" 0.004
    echo
    echo "=== Logcat Sensitive Leak Scan (exported $(date)) ===" > "$file"
    spinner_start "Scanning logcat logs"
    
    # Grab recent logs and scan for typical OSINT leakage patterns
    local logs
    logs=$($(adb_target) shell logcat -d -t 5000 2>/dev/null)
    
    local danger_patterns="[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|latitude|longitude|gps|token=|session=|key=|password="
    local matched
    matched=$(echo "$logs" | grep -E -i "$danger_patterns")
    
    echo "$matched" >> "$file"
    spinner_stop
    
    if [ -z "$matched" ]; then
        typewrite "${GREEN}[✓] No immediately obvious sensitive info found in the last 5000 logcat lines.${RESET}" 0.004
        echo
    else
        typewrite "${RED}[!] Potential leaks identified in logcat:${RESET}" 0.004
        echo
        echo "$matched" | head -40 | while IFS= read -r line; do
            echo -e "  ${YELLOW}${line}${RESET}"
        done
        [ "$(echo "$matched" | wc -l)" -gt 40 ] && echo -e "  ${DIM}... and more lines saved to file.${RESET}"
    fi
    
    typewrite "${GREEN}[✓] Full scan log exported to: $file${RESET}" 0.003
    echo
}

option_17() {
    local file="$OUTPUT_DIR/telephony_info.txt"
    typewrite "${GREEN}Gathering SIM and Telephony Registry information...${RESET}" 0.004
    echo
    echo "=== SIM & Telephony Registry Info (exported $(date)) ===" > "$file"
    
    spinner_start "Querying SIM & Network status"
    local props registry
    props=$($(adb_target) shell getprop 2>/dev/null | grep -iE 'gsm|sim')
    registry=$($(adb_target) shell dumpsys telephony.registry 2>/dev/null)
    spinner_stop
    
    echo "--- GetProp SIM/GSM Properties ---" >> "$file"
    echo "$props" >> "$file"
    echo -e "\n--- Telephony Registry Status ---" >> "$file"
    echo "$registry" >> "$file"
    
    # Highlight key information
    echo -e "${CYAN}${BOLD}Cellular & SIM Highlights:${RESET}"
    echo "$props" | grep -E '\[gsm\.sim\.state\]|\[gsm\.operator\.alpha\]|\[gsm\.sim\.operator\.alpha\]|\[gsm\.network\.type\]' | while IFS= read -r line; do
        echo -e "  ${GREEN}${line}${RESET}"
    done
    echo "$registry" | grep -E 'mCallState|mServiceState|mSignalStrength|mMessageWaiting' | head -15 | while IFS= read -r line; do
        echo -e "  ${GREEN}${line}${RESET}"
    done
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_18() {
    local file="$OUTPUT_DIR/battery_diagnostics.txt"
    typewrite "${GREEN}Dumping battery telemetry & diagnostics...${RESET}" 0.004
    echo
    echo "=== Battery Diagnostics (exported $(date)) ===" > "$file"
    
    spinner_start "Querying battery stats"
    local battery batterystats
    battery=$($(adb_target) shell dumpsys battery 2>/dev/null)
    batterystats=$($(adb_target) shell dumpsys batterystats 2>/dev/null)
    spinner_stop
    
    echo "--- Dumpsys Battery ---" >> "$file"
    echo "$battery" >> "$file"
    echo -e "\n--- Dumpsys Batterystats (summary) ---" >> "$file"
    echo "$batterystats" | head -200 >> "$file"
    
    # Show active battery stats on screen
    echo -e "${CYAN}${BOLD}Battery Status & Telemetry:${RESET}"
    echo "$battery" | while IFS= read -r line; do
        echo -e "  ${GREEN}${line}${RESET}"
    done
    
    # Pull cycle count and capacity info if available
    local charge_cycles
    charge_cycles=$(echo "$batterystats" | grep -i "Charge cycles:" | head -n 1)
    [ -n "$charge_cycles" ] && echo -e "  ${CYAN}${charge_cycles}${RESET}"
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_19() {
    local file="$OUTPUT_DIR/bluetooth_ecosystem.txt"
    typewrite "${GREEN}Querying Bluetooth Ecosystem...${RESET}" 0.004
    echo
    echo "=== Bluetooth Ecosystem (exported $(date)) ===" > "$file"
    
    spinner_start "Gathering Bluetooth info"
    local bt_dump
    bt_dump=$($(adb_target) shell dumpsys bluetooth_manager 2>/dev/null)
    spinner_stop
    
    echo "$bt_dump" >> "$file"
    
    echo -e "${CYAN}${BOLD}Bluetooth Controller & Config:${RESET}"
    echo "$bt_dump" | grep -iE "state:|adapter|enabled|discover|scan_mode" | head -10 | while IFS= read -r line; do
        echo -e "  ${GREEN}${line}${RESET}"
    done
    
    echo -e "\n${CYAN}${BOLD}Paired & Bonded Devices:${RESET}"
    local paired
    paired=$(echo "$bt_dump" | grep -iE "bonded|paired|connected|device|name:|address:" | head -30)
    if [ -n "$paired" ]; then
        echo "$paired" | while IFS= read -r line; do
            echo -e "  ${YELLOW}${line}${RESET}"
        done
    else
        echo -e "  ${DIM}No paired devices found or Bluetooth is off.${RESET}"
    fi
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_20() {
    local file="$OUTPUT_DIR/storage_partitions.txt"
    typewrite "${GREEN}Analyzing storage partitions & mount geometry...${RESET}" 0.004
    echo
    echo "=== Storage & Partition Analysis (exported $(date)) ===" > "$file"
    
    spinner_start "Querying partition geometry"
    local df_out mount_out
    df_out=$($(adb_target) shell df -h 2>/dev/null)
    mount_out=$($(adb_target) shell mount 2>/dev/null)
    spinner_stop
    
    echo "--- Partition Usage (df -h) ---" >> "$file"
    echo "$df_out" >> "$file"
    echo -e "\n--- Mount Configurations ---" >> "$file"
    echo "$mount_out" >> "$file"
    
    echo -e "${CYAN}${BOLD}Primary Partitions Usage:${RESET}"
    echo "$df_out" | grep -E 'Filesystem|/data|/system|/storage|/sdcard' | while IFS= read -r line; do
        echo -e "  ${GREEN}${line}${RESET}"
    done
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_21() {
    local file="$OUTPUT_DIR/browser_detection.txt"
    typewrite "${GREEN}Detecting installed web browsers...${RESET}" 0.004
    echo
    echo "=== Installed Web Browsers & Profiles (exported $(date)) ===" > "$file"
    
    # Popular browser package list
    local browsers=(
        "com.android.chrome|Google Chrome"
        "org.mozilla.firefox|Mozilla Firefox"
        "com.brave.browser|Brave Browser"
        "com.duckduckgo.mobile.android|DuckDuckGo Browser"
        "com.opera.browser|Opera Browser"
        "org.torproject.torbrowser|Tor Browser"
        "com.microsoft.emmx|Microsoft Edge"
        "com.sec.android.app.sbrowser|Samsung Internet"
    )
    
    spinner_start "Checking installed packages"
    local pkgs
    pkgs=$($(adb_target) shell pm list packages 2>/dev/null)
    spinner_stop
    
    echo -e "${CYAN}${BOLD}Detected Web Browsers:${RESET}"
    for entry in "${browsers[@]}"; do
        local pkg name
        pkg=$(echo "$entry" | cut -d'|' -f1)
        name=$(echo "$entry" | cut -d'|' -f2)
        
        if echo "$pkgs" | grep -q "$pkg"; then
            echo -e "  ${GREEN}[✓] ${name}${RESET} (${pkg}) is installed."
            echo "[✓] ${name} (${pkg}) is installed." >> "$file"
            
            # Check if public profile folder exists
            local path_check
            path_check=$($(adb_target) shell ls -d "/sdcard/Android/data/${pkg}" 2>/dev/null)
            if [ -n "$path_check" ]; then
                echo -e "      ${YELLOW}→ Found active user profile folder in public storage.${RESET}"
                echo "      → Found active user profile folder: ${path_check}" >> "$file"
            fi
        else
            echo "[ ] ${name} (${pkg}) is NOT installed." >> "$file"
        fi
    done
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_22() {
    local file="$OUTPUT_DIR/device_security.txt"
    typewrite "${GREEN}Scanning Device Security & Encryption status...${RESET}" 0.004
    echo
    echo "=== Device Security & Encryption Status (exported $(date)) ===" > "$file"
    
    spinner_start "Querying security settings"
    local props policy lock_settings
    props=$($(adb_target) shell getprop 2>/dev/null)
    policy=$($(adb_target) shell dumpsys device_policy 2>/dev/null)
    lock_settings=$($(adb_target) shell dumpsys lock_settings 2>/dev/null)
    spinner_stop
    
    echo "--- Security System Properties ---" >> "$file"
    echo "$props" | grep -iE 'crypt|secure|lockscreen|frp|trust' >> "$file"
    echo -e "\n--- Device Policy Manager status ---" >> "$file"
    echo "$policy" | head -150 >> "$file"
    echo -e "\n--- Lock Settings status ---" >> "$file"
    echo "$lock_settings" >> "$file"
    
    echo -e "${CYAN}${BOLD}Device Security Summary:${RESET}"
    
    # Check encryption state
    local enc_state
    enc_state=$(echo "$props" | grep -iE 'ro\.crypto\.state|ro\.crypto\.type')
    if [ -n "$enc_state" ]; then
        echo "$enc_state" | while IFS= read -r line; do
            echo -e "  ${GREEN}${line}${RESET}"
        done
    fi
    
    # Check lock screen active status
    local pwd_active
    pwd_active=$(echo "$lock_settings" | grep -i "lockscreen.password_type" | head -n 1)
    [ -n "$pwd_active" ] && echo -e "  ${GREEN}Lockscreen Password Type: $(echo "$pwd_active" | cut -d= -f2)${RESET}"
    
    # FRP status
    local frp
    frp=$(echo "$props" | grep -i "ro.frp.pst")
    [ -n "$frp" ] && echo -e "  ${GREEN}Factory Reset Protection partition: yes${RESET}"
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_23() {
    local file="$OUTPUT_DIR/network_sockets.txt"
    typewrite "${GREEN}Gathering active network sockets (Netstat)...${RESET}" 0.004
    echo
    echo "=== Active Network Sockets (exported $(date)) ===" > "$file"
    
    spinner_start "Querying active sockets"
    local netstat_out
    netstat_out=$($(adb_target) shell netstat -an 2>/dev/null || $(adb_target) shell cat /proc/net/tcp 2>/dev/null)
    spinner_stop
    
    echo "$netstat_out" >> "$file"
    
    if [ -n "$netstat_out" ]; then
        echo -e "${CYAN}${BOLD}Recent active TCP/UDP connections:${RESET}"
        echo "$netstat_out" | grep -v '0.0.0.0' | grep -v '::' | grep -iE 'ESTABLISHED|LISTEN|tcp|udp' | head -30 | while IFS= read -r line; do
            echo -e "  ${GREEN}${line}${RESET}"
        done
    else
        echo -e "  ${YELLOW}[i] netstat command not supported or returned empty on this device.${RESET}"
    fi
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_24() {
    local file="$OUTPUT_DIR/active_screen.txt"
    typewrite "${GREEN}Querying Active Screen Focus (WindowManager)...${RESET}" 0.004
    echo
    echo "=== Active Screen Focus (exported $(date)) ===" > "$file"
    
    spinner_start "Querying WindowManager focus"
    local focus
    focus=$($(adb_target) shell dumpsys window 2>/dev/null | grep -iE 'mCurrentFocus|mFocusedApp')
    spinner_stop
    
    echo "$focus" >> "$file"
    
    echo -e "${CYAN}${BOLD}Currently focused screen/application:${RESET}"
    if [ -n "$focus" ]; then
        echo "$focus" | while IFS= read -r line; do
            echo -e "  ${GREEN}${line}${RESET}"
        done
    else
        echo -e "  ${YELLOW}[i] Could not retrieve focused window. Screen might be locked/off.${RESET}"
    fi
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_25() {
    local file="$OUTPUT_DIR/camera_audio.txt"
    typewrite "${GREEN}Querying active Camera & Audio streams...${RESET}" 0.004
    echo
    echo "=== Active Camera & Audio Streams (exported $(date)) ===" > "$file"
    
    spinner_start "Querying media services"
    local camera audio
    camera=$($(adb_target) shell dumpsys media.camera 2>/dev/null)
    audio=$($(adb_target) shell dumpsys audio 2>/dev/null)
    spinner_stop
    
    echo "--- Dumpsys Media Camera ---" >> "$file"
    echo "$camera" >> "$file"
    echo -e "\n--- Dumpsys Audio ---" >> "$file"
    echo "$audio" >> "$file"
    
    echo -e "${CYAN}${BOLD}Active Camera Clients & Recording Status:${RESET}"
    local camera_clients
    camera_clients=$(echo "$camera" | grep -iE "camera client|active|opened|client package")
    if [ -n "$camera_clients" ]; then
        echo "$camera_clients" | while IFS= read -r line; do
            echo -e "  ${GREEN}${line}${RESET}"
        done
    else
        echo -e "  ${DIM}No active camera hardware sessions found.${RESET}"
    fi
    
    echo -e "\n${CYAN}${BOLD}Active Audio Players & Streams:${RESET}"
    local audio_streams
    audio_streams=$(echo "$audio" | grep -iE "stream type|player|record|active" | head -15)
    if [ -n "$audio_streams" ]; then
        echo "$audio_streams" | while IFS= read -r line; do
            echo -e "  ${GREEN}${line}${RESET}"
        done
    else
        echo -e "  ${DIM}No active audio playback/record processes found.${RESET}"
    fi
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_26() {
    local file="$OUTPUT_DIR/keystore_footprints.txt"
    typewrite "${GREEN}Querying Android Keystore cryptographic footprints...${RESET}" 0.004
    echo
    echo "=== Keystore Cryptographic Footprints (exported $(date)) ===" > "$file"
    
    spinner_start "Querying Keystore service"
    local keystore
    keystore=$($(adb_target) shell dumpsys keystore 2>/dev/null)
    spinner_stop
    
    echo "$keystore" >> "$file"
    
    echo -e "${CYAN}${BOLD}Cryptographic Key Aliases & Algorithms:${RESET}"
    local key_aliases
    key_aliases=$(echo "$keystore" | grep -iE "alias|algorithm|key|owner" | head -25)
    if [ -n "$key_aliases" ]; then
        echo "$key_aliases" | while IFS= read -r line; do
            echo -e "  ${GREEN}${line}${RESET}"
        done
    else
        echo -e "  ${DIM}No active cryptographic key aliases exposed in this keystore dump.${RESET}"
    fi
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_27() {
    local file="$OUTPUT_DIR/sensor_registry.txt"
    typewrite "${GREEN}Scanning hardware sensors & active listeners...${RESET}" 0.004
    echo
    echo "=== Hardware Sensor Registry (exported $(date)) ===" > "$file"
    
    spinner_start "Querying sensor service"
    local sensors
    sensors=$($(adb_target) shell dumpsys sensorservice 2>/dev/null)
    spinner_stop
    
    echo "$sensors" >> "$file"
    
    echo -e "${CYAN}${BOLD}Registered Hardware Sensors:${RESET}"
    echo "$sensors" | grep -iE "sensor|active list|connection|type=" | head -15 | while IFS= read -r line; do
        echo -e "  ${GREEN}${line}${RESET}"
    done
    
    echo -e "\n${CYAN}${BOLD}Active Background Listeners:${RESET}"
    local active_listeners
    active_listeners=$(echo "$sensors" | grep -A 5 -i "active connections")
    if [ -n "$active_listeners" ]; then
        echo "$active_listeners" | head -25 | while IFS= read -r line; do
            echo -e "  ${YELLOW}${line}${RESET}"
        done
    else
        echo -e "  ${DIM}No active sensor listener connections found.${RESET}"
    fi
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_28() {
    local file="$OUTPUT_DIR/shared_uids.txt"
    typewrite "${GREEN}Auditing packages sharing User IDs (UIDs)...${RESET}" 0.004
    echo
    echo "=== Shared UID Audit (exported $(date)) ===" > "$file"
    
    spinner_start "Querying system packages"
    local pkgs
    pkgs=$($(adb_target) shell pm list packages -U 2>/dev/null)
    spinner_stop
    
    echo "$pkgs" >> "$file"
    
    echo -e "${CYAN}${BOLD}Identified Shared/System UIDs:${RESET}"
    # Sort and group by UID, finding packages that share UIDs
    local shared
    shared=$(echo "$pkgs" | sort -t: -k3 | uniq -f1 -d | head -30)
    if [ -n "$shared" ]; then
        echo "$shared" | while IFS= read -r line; do
            echo -e "  ${GREEN}${line}${RESET}"
        done
    else
        echo -e "  ${DIM}All packages appear to be running under isolated UIDs.${RESET}"
    fi
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_29() {
    local file="$OUTPUT_DIR/activity_stack.txt"
    typewrite "${GREEN}Extracting detailed Activity Task Stack...${RESET}" 0.004
    echo
    echo "=== Activity Task Stack (exported $(date)) ===" > "$file"
    
    spinner_start "Querying Activity Manager activities"
    local activities
    activities=$($(adb_target) shell dumpsys activity activities 2>/dev/null)
    spinner_stop
    
    echo "$activities" >> "$file"
    
    echo -e "${CYAN}${BOLD}Recent Task & Activity Stack History:${RESET}"
    echo "$activities" | grep -E '\* Task|ResumedActivity|mFocusedApp|Running activities|TaskRecord' | head -25 | while IFS= read -r line; do
        echo -e "  ${GREEN}${line}${RESET}"
    done
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_30() {
    local file="$OUTPUT_DIR/input_methods.txt"
    typewrite "${GREEN}Querying keyboards & input methods...${RESET}" 0.004
    echo
    echo "=== Keyboard & Input Methods (exported $(date)) ===" > "$file"
    
    spinner_start "Querying input method service"
    local input_method
    input_method=$($(adb_target) shell dumpsys input_method 2>/dev/null)
    spinner_stop
    
    echo "$input_method" >> "$file"
    
    echo -e "${CYAN}${BOLD}Active Keyboard & Input System:${RESET}"
    echo "$input_method" | grep -E 'mCurMethodId|mSelectedInputMethod|mEnabledInputMethods|mCurrentKeyboard' | while IFS= read -r line; do
        echo -e "  ${GREEN}${line}${RESET}"
    done
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

option_31() {
    local file="$OUTPUT_DIR/wifi_rtt.txt"
    typewrite "${GREEN}Querying Wi-Fi RTT ranging capabilities...${RESET}" 0.004
    echo
    echo "=== Wi-Fi RTT Diagnostics (exported $(date)) ===" > "$file"
    
    spinner_start "Querying Wi-Fi RTT services"
    local wifi_rtt
    wifi_rtt=$($(adb_target) shell dumpsys wifi_rtt 2>/dev/null)
    spinner_stop
    
    echo "$wifi_rtt" >> "$file"
    
    echo -e "${CYAN}${BOLD}Wi-Fi RTT Service & Status:${RESET}"
    if [ -n "$wifi_rtt" ]; then
        echo "$wifi_rtt" | grep -iE "rtt|enable|status|ranging|supported" | head -15 | while IFS= read -r line; do
            echo -e "  ${GREEN}${line}${RESET}"
        done
    else
        echo -e "  ${YELLOW}[i] Wi-Fi RTT ranging service not supported on this device/ROM.${RESET}"
    fi
    
    typewrite "${GREEN}[✓] Exported to: $file${RESET}" 0.003
    echo
}

# --- Batch Mode ---

# Parse batch input like "1,3,5-8" into a list of numbers
parse_batch_input() {
    local input="$1"
    local result=""
    local old_ifs="$IFS"
    IFS=','
    for token in $input; do
        IFS="$old_ifs"
        token=$(echo "$token" | xargs)
        if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start=${BASH_REMATCH[1]}
            local end=${BASH_REMATCH[2]}
            for ((i=start; i<=end; i++)); do
                result="$result $i"
            done
        elif [[ "$token" =~ ^[0-9]+$ ]]; then
            result="$result $token"
        fi
        IFS=','
    done
    IFS="$old_ifs"
    echo "$result"
}

# Run a single option by number (shared by single and batch mode)
run_option() {
    local opt=$1
    case "$opt" in
        1) option_1; return 0 ;;
        2) option_2; return 0 ;;
        3) option_3; return 0 ;;
        4) option_4; return 0 ;;
        5) option_5; return 0 ;;
        6) option_6; return 0 ;;
        7) option_7; return 0 ;;
        8) option_8; return 0 ;;
        9) option_9; return 0 ;;
        10) option_wifi; return 0 ;;
        11) select_device; return 0 ;;
        12) option_device_info; return 0 ;;
        13) option_permissions; return 0 ;;
        14) option_location; return 0 ;;
        15) option_15; return 0 ;;
        16) option_16; return 0 ;;
        17) option_17; return 0 ;;
        18) option_18; return 0 ;;
        19) option_19; return 0 ;;
        20) option_20; return 0 ;;
        21) option_21; return 0 ;;
        22) option_22; return 0 ;;
        23) option_23; return 0 ;;
        24) option_24; return 0 ;;
        25) option_25; return 0 ;;
        26) option_26; return 0 ;;
        27) option_27; return 0 ;;
        28) option_28; return 0 ;;
        29) option_29; return 0 ;;
        30) option_30; return 0 ;;
        31) option_31; return 0 ;;
        *) return 1 ;;
    esac
}

# --- Main Loop ---
# --- Run Pre-flight Checks ---
check_adb
check_device

# --- Setup Output Directory ---
setup_output_dir

# --- Startup Help ---
show_help

# --- Main Loop ---
while true; do
    animate_banner
    menu
    typewrite "${MAGENTA}${BOLD}Enter choice: ${RESET}" 0.004
    read choice

    # Batch mode: detect commas or ranges
    if [[ "$choice" == *,* || "$choice" == *-* ]]; then
        items=$(parse_batch_input "$choice")
        ran_any=false
        for item in $items; do
            if run_option "$item"; then
                ran_any=true
            else
                typewrite "${RED}Invalid option: $item${RESET}" 0.003
                echo
            fi
        done
        if [ "$ran_any" = true ]; then
            echo
            read -p "Press Enter to continue..."
        fi
    elif [[ "$choice" =~ ^[0-9]+$ ]]; then
        case "$choice" in
            0) typewrite "${GREEN}Exiting.${RESET}" 0.004; echo; show_summary; exit 0 ;;
            *) if run_option "$choice"; then
                   read -p "Press Enter to continue..."
               else
                   typewrite "${RED}Invalid option.${RESET}" 0.005; echo; sleep 1
               fi ;;
        esac
    else
        typewrite "${RED}Invalid option.${RESET}" 0.005; echo; sleep 1
    fi
    menu_fade
done
