# Local AI Setup & Mac Diagnostics

A pair of standalone Bash scripts for macOS: one to inspect your Mac's hardware and software, and another to install the tools needed for a local AI development environment.

## Scripts

| Script | Purpose |
|---|---|
| `mac_info_diagnostics.sh` | Reports system and hardware information, checks selected macOS settings and installed tools, and guides you through interactive hardware tests. |
| `setup_local_ai.sh` | Installs or updates the software configured for your local AI development environment. |

## Requirements

- A Mac running macOS
- Terminal
- An internet connection for downloading software and AI models
- Permission to install the required software

Review both scripts before running them. The setup script installs software and may make changes to your system.

## Recommended Order

Run the scripts in this order:

1. **Diagnostics:** Check your Mac before installing anything.
2. **Setup:** Install the local AI and development tools.
3. **Diagnostics again:** Verify the resulting setup.

If the initial diagnostics reveals a serious hardware, storage, or system issue, investigate it before proceeding with the software installation.

## Getting Started

### 1. Open the repository in Terminal

If you cloned the repository into your `Projects` directory, run:

```bash
cd ~/Projects/<repository-name>
```

Replace `<repository-name>` with the actual directory name.

### 2. Make the scripts executable

Run this once:

```bash
chmod +x mac_info_diagnostics.sh setup_local_ai.sh
```

### 3. Run the diagnostics

```bash
./mac_info_diagnostics.sh
```

Review the output and follow the prompts. The script collects system information and guides you through optional interactive tests.

### 4. Install the local AI tools

```bash
./setup_local_ai.sh
```

Follow any prompts or instructions displayed by the installer. Depending on your setup, downloading software and AI models may take some time.

### 5. Verify the installation

After the setup script finishes, run the diagnostics again:

```bash
./mac_info_diagnostics.sh
```

Check that the expected tools are detected and that Ollama's local service responds.

## What the Diagnostics Script Checks

`mac_info_diagnostics.sh` checks or reports:

- macOS version, build, architecture, and uptime
- Mac model, chip, CPU, memory, and serial number
- Graphics and display information
- Storage devices, available space, and filesystem verification
- Battery and power information
- Camera and audio device inventory
- Network interfaces and connectivity
- System Integrity Protection, FileVault, and Gatekeeper status
- Development tools and their versions
- Ollama installation, local server response, and available models

It also offers interactive camera, microphone, and speaker tests, followed by a manual hardware checklist.

### Interactive tests

Some checks require your input:

- **Camera:** Opens Photo Booth so you can inspect the image.
- **Microphone:** Opens QuickTime Player and explains how to record and play back a short test.
- **Speakers:** Plays a short built-in sound.
- **Manual checklist:** Prompts you to inspect components such as the display, keyboard, trackpad, ports, battery, and hinge.

Press Enter when you have finished a test or checklist. Answer the prompts honestly: a skipped or unconfirmed test is not a successful test.

The diagnostics script does not record audio or video itself, change system settings, or upload a report.

## What the Setup Script Installs

`setup_local_ai.sh` is configured to install or update tools such as:

- Homebrew
- Python and pip
- `uv`
- Ollama
- A Qwen model
- Visual Studio Code
- Claude Code

Check the script for the exact model, package versions, and installation behavior.

Installing Claude Code does not automatically mean you are signed in or have completed authentication.

## Important Notes

- These scripts are intended for macOS, not Windows or Linux.
- The setup script may download large files. AI models can require substantial disk space.
- Some diagnostics require administrator permissions or may be unavailable on certain Mac models or macOS versions.
- Network checks can be affected by VPNs, firewalls, DNS issues, or network restrictions.
- A successful automated check does not guarantee that every hardware component is working correctly.
- SMART information may not be available for internal Apple storage.
- For persistent hardware issues, run Apple Diagnostics and contact Apple or an authorized service provider.
- Keep important data backed up before repairs, upgrades, or erasing your Mac.

## Troubleshooting

### Permission denied

Make the scripts executable again:

```bash
chmod +x mac_info_diagnostics.sh setup_local_ai.sh
```

### Command not found

Ensure you are in the repository directory and use `./` before the script name:

```bash
./mac_info_diagnostics.sh
```

### Ollama is installed but not responding

Check the Ollama application and local service. The diagnostics script reports whether the local server responds; it does not install or repair Ollama.

### A network check fails

Check your internet connection, VPN, firewall, or network restrictions. A failed ping alone does not necessarily mean HTTPS access is unavailable.

---

Have fun, keep your models local, and may your terminal output be more green than red.
