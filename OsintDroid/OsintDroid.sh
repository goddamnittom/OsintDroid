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
    echo -e "${DIM}  (batch: use commas or ranges, e.g. ${BOLD}4,5,6${RESET}${DIM} or ${BOLD}1-6${RESET}${DIM})${RESET}"
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
