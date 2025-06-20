# 🔐 WPS PIN Cracker Tool (`wps-pin-cracker-expexc.sh`)

A Bash script to brute-force WPS (Wi-Fi Protected Setup) PINs on vulnerable routers using randomized attempts.  
Created for educational and authorized security testing purposes only.

---

## 📝 Table of Contents

- [✨ Features](#-features)
- [⚙️ Requirements](#-requirements)
- [📥 Installation](#-installation)
- [🚀 Usage](#-usage)
- [⚡ Configuration](#-configuration)
- [📂 Logs](#-logs)
- [⚠️ Legal Notice](#️-legal-notice)
- [🔧 Troubleshooting](#-troubleshooting)
- [📜 License](#-license)

---

## ✨ Features

- ✅ **Automated WPS PIN Brute-Force** – Continuously tests randomized PINs.
- ✅ **Monitor Mode Setup** – Automatically configures wireless interface.
- ✅ **WPS Network Scanning** – Detects WPS-enabled access points.
- ✅ **Randomized PIN Attempts** – Minimizes detection chances.
- ✅ **Session Logging** – Tracks progress with timestamped logs.
- ✅ **Safe Exit Handling** – Restores original settings on exit.

---

## ⚙️ Requirements

- **Linux OS** (Kali, Ubuntu recommended)
- **Wireless Adapter** with monitor mode & packet injection support
- **Root Privileges** (required for wireless control)
- **Dependencies:**
  ```bash
  airmon-ng iw wash reaver crunch shuf

📦 Install dependencies:

sudo apt install aircrack-ng reaver crunch coreutils

📥 Installation

    Download the script:

wget https://example.com/wps-pin-cracker-expexc.sh
chmod +x wps-pin-cracker-expexc.sh

Run the script:

    sudo ./wps-pin-cracker-expexc.sh

🚀 Usage

Basic execution:

sudo ./wps-pin-cracker-expexc.sh

What it does:

    Scans for nearby WPS-enabled networks

    Lets you select a target

    Starts brute-forcing using randomized PINs

To stop the script:

    Press Ctrl+C — it will automatically clean up monitor mode settings

⚡ Configuration

Edit the following variables directly in the script as needed:

REAL_IFACE="wlan0"           # Wireless interface name
PIN_LIST="wps_pins.txt"      # List of WPS PINs to try
MAX_ATTEMPTS=10000           # Maximum PIN attempts
REAVER_TIMEOUT=0.5           # Delay between attempts (in seconds)

📂 Logs

Logs are saved with timestamps:

wps_crack_YYYYMMDD_HHMMSS.log

Example log entry:

[*] Attempt 1/10000: Trying PIN: 12345670
[+] SUCCESS: WPS PIN 12345670 worked!

⚠️ Legal Notice

    🛑 For educational and authorized use only.
    🛑 Unauthorized access is illegal.
    🛑 Many routers now block WPS brute-force attacks.

🔧 Troubleshooting
Issue	Solution
Monitor mode fails	Run sudo airmon-ng check kill firs
No WPS networks found	Ensure WPS is enabled on target router
Reaver fails repeatedly	Try alternatives like bully or wpspin
📜 License

This tool is provided strictly for educational and authorized testing.
Use responsibly and legally.
