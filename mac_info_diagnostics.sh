#!/bin/bash
set -uo pipefail

# Read-only macOS diagnostics plus interactive manual checks.
# Does not record audio/video, change settings, or upload a report.

line() { printf '%*s\n' 72 '' | tr ' ' '-'; }
section() { printf '\n\033[1;34m%s\033[0m\n' "$1"; line; }
kv() { printf '%-30s: %s\n' "$1" "${2:-N/A}"; }
have() { command -v "$1" >/dev/null 2>&1; }
yesno() {
  local answer
  while true; do
    printf '%s [y/n]: ' "$1"
    read -r answer
    case "$answer" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}
open_app() {
  local app="$1"
  if [[ -d "/System/Applications/$app.app" ]]; then
    open "/System/Applications/$app.app"
  elif [[ -d "/Applications/$app.app" ]]; then
    open "/Applications/$app.app"
  else
    echo "Could not find $app.app automatically. Open it manually from Applications."
  fi
}

[[ "$(uname -s)" == "Darwin" ]] || { echo "This script is for macOS only."; exit 1; }

printf '%s\n' "======================================================================"
printf '%s\n' "                    MAC HEALTH CHECK"
printf '%s\n' "======================================================================"
printf '%s\n' "This combines automated checks with tests that need your eyes and ears."
printf '%s\n' "Let us see what you have got under that aluminium shell. Try to look impressive."
printf '%s\n' "Nothing is recorded or uploaded. Software cannot certify every component."
printf '\n'

section "1. SYSTEM"
echo "First, the basics. Every respectable machine has a little paperwork."
kv "Date" "$(date)"
kv "macOS version" "$(sw_vers -productVersion 2>/dev/null)"
kv "Build" "$(sw_vers -buildVersion 2>/dev/null)"
kv "Architecture" "$(uname -m)"
kv "Kernel" "$(uname -sr 2>/dev/null)"
kv "Computer name" "$(scutil --get ComputerName 2>/dev/null || hostname)"
kv "Uptime" "$(uptime 2>/dev/null | sed 's/.*up /up /' | sed 's/, [0-9]* user.*//')"

section "2. HARDWARE"
echo "Checking the brain, memory, and identity. Plenty to work with, I hope."
SP="$(system_profiler SPHardwareDataType 2>/dev/null || true)"
kv "Model" "$(printf '%s\n' "$SP" | awk -F': ' '/Model Name:/ {print $2; exit}')"
kv "Model identifier" "$(printf '%s\n' "$SP" | awk -F': ' '/Model Identifier:/ {print $2; exit}')"
kv "Chip" "$(printf '%s\n' "$SP" | awk -F': ' '/Chip:/ {print $2; exit}')"
kv "Processor" "$(printf '%s\n' "$SP" | awk -F': ' '/Processor Name:/ {print $2; exit}')"
kv "CPU cores" "$(printf '%s\n' "$SP" | awk -F': ' '/Total Number of Cores:/ {print $2; exit}')"
kv "Memory (system profiler)" "$(printf '%s\n' "$SP" | awk -F': ' '/Memory:/ {print $2; exit}')"
kv "Serial number" "$(printf '%s\n' "$SP" | awk -F': ' '/Serial Number \(system\):/ {print $2; exit}')"
MEM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
if [[ "$MEM_BYTES" =~ ^[0-9]+$ ]] && (( MEM_BYTES > 0 )); then kv "Physical memory" "$((MEM_BYTES/1024/1024/1024)) GiB"; fi
kv "CPU brand string" "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Apple Silicon / not exposed')"

section "3. GRAPHICS AND DISPLAYS"
echo "Checking the visuals. This is where you make an impression."
system_profiler SPDisplaysDataType 2>/dev/null | awk '/Chipset Model:|Type:|Bus:|Total Number of Cores:|Metal Support:|Resolution:|UI Looks like:|Refresh Rate:|Connection Type:/ {print}'

section "4. STORAGE"
echo "Checking the storage. Keeping things tidy is attractive, frankly."
df -h / | awk 'NR==1 {print "Root volume: " $0} NR==2 {print}'
diskutil list internal physical 2>/dev/null || true
diskutil info / 2>/dev/null | awk -F': *' '/Device Identifier:|Protocol:|SMART Status:|Solid State:|File System Personality:|Volume Free Space:|Volume Used Space:|Disk Size:/ {print $1 ": " $2}'
echo "SMART status may be unavailable for Apple internal storage; unavailable does not mean failed."

section "5. BATTERY AND POWER"
echo "Let us check your energy levels. No coffee required."
system_profiler SPPowerDataType 2>/dev/null | awk '/Condition:|Maximum Capacity:|Cycle Count:|State of Charge:|Charging:|Fully Charged:|Amperage \(mA\):|Voltage \(mV\):|Connected:|Wattage \(W\):|Power Source:/ {print}'
pmset -g batt 2>/dev/null || true

section "6. CAMERA, MICROPHONE, SPEAKERS"
echo "The senses department. Let us make sure everything is listening."
echo "Camera inventory:"
system_profiler SPCameraDataType 2>/dev/null || echo "Camera inventory unavailable."
echo
echo "Audio device inventory:"
system_profiler SPAudioDataType 2>/dev/null | awk '/Devices:|Input:|Output:|Default Input Device:|Default Output Device:|Manufacturer:|Current SampleRate:|Transport:|Input Channels:|Output Channels:/ {print}'
echo "Inventory is not a quality test; use the interactive checks below."

section "7. NETWORK"
echo "Checking the connection. Being hard to reach is not a personality trait."
ifconfig 2>/dev/null | awk '/^[a-zA-Z0-9]/ {iface=$1; sub(/:$/,"",iface)} /inet / && $2 != "127.0.0.1" {printf "%-18s %s\n", iface, $2}'
kv "Wi-Fi power/status" "$(networksetup -getairportpower en0 2>/dev/null || echo 'Not available on en0')"
if ping -c 1 -W 2000 1.1.1.1 >/dev/null 2>&1; then kv "Internet reachability (IP)" "PASS"; else kv "Internet reachability (IP)" "No response (may be offline/blocked)"; fi
if curl -fsSI --connect-timeout 5 https://www.apple.com >/dev/null 2>&1; then kv "HTTPS/DNS reachability" "PASS"; else kv "HTTPS/DNS reachability" "FAILED or network restricted"; fi
echo "VPNs, firewalls, captive portals, or network policy can affect these checks."

section "8. SECURITY AND DEVELOPER TOOLS"
echo "Checking your toolkit. A little preparation looks good on you."
kv "System Integrity Protection" "$(csrutil status 2>/dev/null || echo 'Unavailable in this boot context')"
kv "FileVault" "$(fdesetup status 2>/dev/null || echo N/A)"
kv "Gatekeeper" "$(spctl --status 2>/dev/null || echo N/A)"
kv "Command Line Tools" "$(xcode-select -p 2>/dev/null || echo 'Not installed')"
if have brew; then kv "Homebrew" "$(brew --version | head -1)"; else kv "Homebrew" "Not installed"; fi
if have python3; then kv "Python" "$(python3 --version 2>&1)"; kv "pip" "$(python3 -m pip --version 2>&1)"; else kv "Python" "Not installed"; fi
if have uv; then kv "uv" "$(uv --version 2>&1)"; else kv "uv" "Not installed"; fi
if have ollama; then kv "Ollama" "$(ollama --version 2>&1 | head -1)"; else kv "Ollama" "Not installed"; fi
if have claude; then kv "Claude Code" "$(claude --version 2>&1 | head -1)"; else kv "Claude Code" "Not installed"; fi
if [[ -d "/Applications/Visual Studio Code.app" ]]; then kv "VS Code" "$(defaults read "/Applications/Visual Studio Code.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo N/A)"; else kv "VS Code" "Not installed"; fi

section "9. OLLAMA"
echo "Checking the local AI setup. Let us see who is home."
if have ollama; then
  if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    ollama list
    curl -fsS --max-time 3 http://127.0.0.1:11434/api/version 2>/dev/null || true
    echo
  else
    echo "Ollama is installed but its local server is not responding."
  fi
else
  echo "Ollama is not installed."
fi

section "10. FILESYSTEM CHECK"
echo "A quick filesystem check. Fingers crossed; no need for dramatic music."
echo "Running macOS volume verification on / (this may take a moment)..."
if diskutil verifyVolume /; then
  echo "Filesystem verification command completed successfully."
else
  echo "Filesystem verification did not complete cleanly. Review output above."
fi
echo "This is not an SSD health certification or a backup check."

section "11. CAMERA TEST"
if yesno "Open Photo Booth for a live camera preview?"; then
  open_app "Photo Booth"
  echo "Camera check. Go on, make a good impression."
  echo "Check image stability, focus, color, exposure, spots, and flicker."
  read -r -p "Press Enter when you have finished checking the camera... " _
  if yesno "Did the camera image look normal?"; then echo "Camera: USER MARKED PASS"; else echo "Camera: USER MARKED NEEDS ATTENTION"; fi
else
  echo "Camera: NOT TESTED. The paparazzi will have to wait."
fi

section "12. MICROPHONE TEST"
if yesno "Open QuickTime Player for a microphone test?"; then
  open_app "QuickTime Player"
  echo "Say something charming. Or just check that the microphone works."
  echo "In QuickTime: File > New Audio Recording. Select the microphone, speak,"
  echo "watch the level meter, record a few seconds, then play it back."
  echo "This script does not start or save a recording. Go ahead and test it now."
  read -r -p "Press Enter when you have finished the microphone test... " _
  if yesno "Did the meter respond and playback sound clear?"; then echo "Microphone: USER MARKED PASS"; else echo "Microphone: USER MARKED NEEDS ATTENTION"; fi
else
  echo "Microphone: NOT TESTED. Your secrets remain safely unamplified."
fi

section "13. SPEAKER TEST"
if yesno "Play a short built-in sound through the current audio output?"; then
  if [[ -f /System/Library/Sounds/Glass.aiff ]]; then
    afplay /System/Library/Sounds/Glass.aiff
    echo "Let us hear what you have got. No need to show off."
    echo "Listen for crackling, distortion, imbalance, or sound from only one side."
    read -r -p "Press Enter when you have finished listening... " _
    if yesno "Did the sound play clearly?"; then echo "Speakers: USER MARKED PASS"; else echo "Speakers: USER MARKED NEEDS ATTENTION"; fi
  else
    echo "Built-in test sound unavailable. Test speakers manually."
  fi
else
  echo "Speakers: NOT TESTED. A quiet confidence, then."
fi

section "14. MANUAL HARDWARE CHECKLIST"
echo "The human senses are up next. I will wait; no rushing the expert."
cat <<'CHECKLIST'
Check these yourself; software cannot reliably certify them:

[ ] Display: show solid white, black, red, green, and blue screens. Look for dead/stuck
    pixels, bright spots, uneven lighting, flicker, image retention, and pressure marks.
[ ] Keyboard: test every key, modifiers, arrows, backlight, and Touch ID.
[ ] Trackpad: test clicking, all areas, gestures, dragging, and haptic feedback.
[ ] Chassis/hinge: inspect for dents, gaps, bending, swelling, loose parts, and smooth hinge.
[ ] Ports: test each USB-C/Thunderbolt, MagSafe, headphone, and other port with known-good
    accessories. Test charging and external display output.
[ ] Wi-Fi/Bluetooth: connect to a known network and pair a known-good device.
[ ] Battery: compare capacity/cycle count with age; test real runtime and charging stability.
[ ] Sleep/wake: close the lid, wait, reopen; check wake, reconnection, and unusual battery drain.
[ ] Thermals: under normal workload, watch for abnormal heat, noise, throttling, or shutdowns.
[ ] Apple Diagnostics: run Apple's model-specific hardware diagnostic. On Apple silicon,
    shut down, hold power until startup options appear, then press Command-D.
[ ] Activation Lock: ensure the previous owner removed Find My/Activation Lock and the Mac
    can be erased/activated by its intended owner. Never bypass another person's lock.
[ ] Coverage: check the serial number directly with Apple's coverage service.
[ ] Backup: verify that important data is backed up before any repair or erase.
CHECKLIST
read -r -p "Press Enter when you have finished the manual checklist... " _

section "15. INTERPRETING RESULTS"
echo "The fine print. Even a charming diagnostic has to be honest."
cat <<'LIMITS'
- PASS means only that the specific check completed; it is not a full hardware guarantee.
- A failed network test may indicate the network, VPN, or firewall rather than the Mac.
- Camera/mic inventory does not prove quality; test in the apps above.
- SMART data may be unavailable for internal Apple storage.
- Battery readings are estimates; a real runtime test is useful.
- If something fails, repeat with known-good accessories and note the exact symptom.
- For persistent issues, run Apple Diagnostics and contact Apple or an authorized provider.
LIMITS

printf '\n%s\n' "======================================================================"
printf '%s\n' "Report complete. Well, look at you. Almost suspiciously well-behaved."
printf '%s\n' "Nothing was uploaded by this script."
printf '%s\n' "======================================================================"
