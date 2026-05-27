# OsintDroid
OsintDroid is a script that helps you snoop on an Android phone — but only if you own the phone and have plugged it into your computer.
It uses ADB (Android Debug Bridge). Think of ADB as a secret backdoor that Android phones have for developers. If you turn on "USB Debugging" in your phone's settings and plug it in with a cable, your computer can talk directly to the phone's brain.

***What It Can Do (With One Click)***
Once connected, OsintDroid shows you a menu. Pick a number, and it pulls data off the phone.

***The Features***
 ### 👤 1. Digital Identity & Personal Data

  • Option 2: List Registered Emails – Extracts all email addresses logged into account authenticators on the device.
  • Option 3: List Account Applications – Lists apps (like social media, banking, etc.) associated with active device user accounts.
  • Option 4: List Phone Contacts – Extracts display names and phone numbers from the contacts provider. (Saves report)
  • Option 5: Dump Call Logs – Exports complete incoming, outgoing, and missed call history. (Saves report)
  • Option 6: Dump SMS – Exports all SMS messages stored on the device database. (Saves report)
  • Option 1: Number of Reboots – Retrieves the device global boot count.
  ──────
  ### 📦 2. Application & Privilege Auditing

  • Option 7: List All APKs – Displays packages of all installed system and third-party apps.
  • Option 8: List 3rd Party – Filters and lists only non-system, user-installed applications.
  • Option 13: App Permissions – Audits and flags applications holding dangerous permissions (Camera, Audio, Location, SMS, Contacts). (Saves report)
  • Option 21: Installed Browser Profiles & Cache – Scans for 8 popular browsers and flags active profile directories in public storage. (Saves report)
  • Option 28: Shared UID & App Signatures Audit – Scans packages sharing user IDs, exposing privilege-sharing apps or signed OEM suites. (Saves report)
  ──────
  ### 📡 3. Connectivity, Network & Locational Capabilities

  • Option 10: Dump WiFi Passwords – Extracts credentials from config files (requires root) or dumps current and saved network metadata (non-root). (Saves report)
  • Option 17: SIM & Network Operator Forensics – Queries active operators, SIM states, network types, and signal metrics. (Saves report)
  • Option 19: Detailed Bluetooth Ecosystem – Maps paired, bonded, and connected peripheral devices (smartwatches, audio systems). (Saves report)
  • Option 23: Live Network Sockets (Netstat) – Inspects active listening and established TCP/UDP network connections. (Saves report)
  • Option 31: Wi-Fi RTT Locational Capabilities – Diagnostics for IEEE 802.11mc fine-grained indoor ranging hardware capabilities. (Saves report)
  ──────
  ### 📊 4. Telemetry & Hardware Diagnostics

  • Option 12: Device Properties – Pulls key getprop details (Manufacturer, display ID, CPU architecture, operator). (Saves report)
  • Option 18: Battery & Charging Diagnostics – Dumps cycle counts, capacity metrics, voltage, chemistry, and active power source telemetry. (Saves report)
  • Option 20: Storage & Partition Analysis – Analyzes filesystem mount points, read/write flags, and disk usage geometry. (Saves report)
  • Option 22: Device Security Status & Encryption – Checks lockscreen PIN/password setup, FBE/FDE encryption states, and device policies. (Saves report)
  • Option 25: Active Camera & Audio Streams Audit – Details active camera connections and background microphone recording streams. (Saves report)
  • Option 27: Hardware Sensor Registry & Listeners – Profiles physical onboard sensors and detects background apps listening to telemetry data. (Saves report)
  ──────
  ### 📈 5. User Activity & Logging Telemetry

  • Option 14: Location Forensics – Sweeps last-known GPS provider records, BLE scans, and Wi-Fi networks in range. (Saves report)
  • Option 15: Application Usage Timeline (UsageStats) – Reconstructs user digital activity timelines showing active app foreground durations. (Saves report)
  • Option 16: Logcat Sensitive Data Leak Scanner – Scans system logcat lines using regex to catch credential leaks, tokens, and coordinates. (Saves report)
  • Option 24: Active Screen Focus (WindowManager) – Detects currently focused windows and activities actively running in the foreground. (Saves report)
  • Option 26: Android Keystore Cryptographic Footprints – Lists active hardware cryptographic key aliases and secure storage profiles. (Saves report)
  • Option 29: Deep Activity Task Stack History – Traces internal activity back-stacks, exposing navigation paths inside apps. (Saves report)
  • Option 30: Input Methods & Custom Keyboards – Identifies current software keyboards, custom user dictionaries, and keyboard locales. (Saves report)
  ──────
  ### ⚙️ 6. Toolkit Utilities

  • Option 11: Switch Device – Interactively cycles target ADB serial codes when multiple devices or emulators are connected.
  • Opt 3: Account Applications
  • Opt 4: Contacts Export  [Report]
  • Opt 5: Call Logs Dump  [Report]
  • Opt 6: SMS Messages Dump  [Report]
  • Opt 1: Device Boot Count

  ### 📦 2. Application & Privilege Auditing

  • Opt 7: All Installed Packages
  • Opt 8: User-Installed Packages (3rd Party)
  • Opt 13: Dangerous App Permissions  [Report]
  • Opt 21: Browser Profile Scanner  [Report]
  • Opt 28: Shared UID Package Audit  [Report]

  ### 📡 3. Connectivity & Networks

  • Opt 10: WiFi Passwords & Metadata  [Report]
  • Opt 17: SIM Operator & Signal Registry  [Report]
  • Opt 19: Bluetooth Paired Peripherals  [Report]
  • Opt 23: Live Network Sockets (Netstat)  [Report]
  • Opt 31: Wi-Fi RTT indoor Location Diagnostics  [Report]

  ### 📊 4. Telemetry & Hardware Diagnostics

  • Opt 12: Device Hardware Specs  [Report]
  • Opt 18: Battery Health & Diagnostics  [Report]
  • Opt 20: Partitions & Disk Geometry  [Report]
  • Opt 22: Encryption & Lockscreen Security  [Report]
  • Opt 25: Active Camera & Audio Channels Audit  [Report]
  • Opt 27: Hardware Sensors & Listener Registry  [Report]

  ### 📈 5. User Activity & System Logs

  • Opt 14: GPS, BT, & WiFi Location sweep  [Report]
  • Opt 15: App Foreground Timeline (UsageStats)  [Report]
  • Opt 16: Logcat Leak Scanner (Emails/Tokens)  [Report]
  • Opt 24: Foreground Focused App (WindowManager)  [Report]
  • Opt 26: Hardware Keystore Key Aliases  [Report]
  • Opt 29: Deep Activity Task Stack History  [Report]
  • Opt 30: Active Soft Keyboard & Dictionaries  [Report]

  ### ⚙️ 6. Utilities

  • Opt 11: Switch Target Device (Multi-ADB)
  • Opt 0: Exit & Export Session Summary
  
***Who Is This For?***
- Forensic investigators pulling data from a suspect's phone
- Phone repair techs diagnosing device issues
- Data recovery — grabbing contacts/SMS before a factory reset
- Curious tinkerers who want to see what's on their own phone

***What You Need***
1. A computer (Windows/Mac/Linux)
2. ADB installed (free from Google)
Windows: https://dl.google.com/android/repository/platform-tools-latest-windows.zip
macOS: Download SDK Platform-Tools for Mac https://dl.google.com/android/repository/platform-tools-latest-darwin.zip
Linux: Download SDK Platform-Tools for Linux https://dl.google.com/android/repository/platform-tools-latest-linux.zip
4. An Android phone with USB Debugging turned on (S ettings → Developer Options)
5. A USB cable

***What It Can't Do***
- Doesn't need root, but some features (WiFi passwords) work better with it
- Read-only — it never writes to the phone
- Won't work if USB Debugging is off
- Won't hack into someone else's phone remotely — you need physical access
────────────────────────────────────────────────────────────────────────────────


***Windows Users*** 
Users on windows may be forced to use WSL or Git Bash
