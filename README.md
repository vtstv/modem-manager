# Modem Manager

Interactive bash tool for managing GSM/LTE/eSIM modems on Linux.

<img width="1450" height="1059" alt="modemmanager" src="https://github.com/user-attachments/assets/10093939-d869-4521-803c-b76dde8a7699" />

## Features

### Connection Management
- Connect/disconnect mobile modem
- Restart modem
- Signal strength monitoring
- Full diagnostics
- Create/modify/delete GSM connections

### SIM Management
- Unlock SIM with PIN/PUK
- Change PIN code
- Enable/disable PIN protection
- Store PIN in NetworkManager connection
- View SIM information
- Switch between SIM slots (dual SIM support)

### eSIM Support
- List installed eSIM profiles
- Install new eSIM profiles via activation code
- Delete eSIM profiles

### Automatic SIM Unlock
- Encrypted PIN storage using systemd credentials
- Automatic SIM unlock on boot via systemd service
- Secure credential management (no plain-text PIN)
- Easy install/uninstall/status management

### FCC Unlock (Qualcomm/Intel Modems)
- Automatic detection of FCC-locked modems (Quectel EM120, Foxconn SDX55, Fibocom L860)
- Check FCC lock status and modem state
- Enable/disable FCC unlock scripts for ModemManager
- Auto-detect device VID:PID and match unlock scripts
- Required for RF functionality on certain Lenovo ThinkPad WWAN modules

### Dependency Management
- Automatically detects missing dependencies on startup
- Identifies your Linux distribution and package manager
- Prompts user before installing anything — nothing runs silently
- Prompts user before enabling/starting system services
- Supports **Arch Linux**, **Debian/Ubuntu**, **Fedora/RHEL/CentOS/Rocky/AlmaLinux**, and **openSUSE/SUSE**
- Shows manual install instructions for unsupported distributions

## Supported Distributions

| Distribution Family | Examples | Package Manager |
|---|---|---|
| Arch-based | Arch Linux, Manjaro, EndeavourOS, Garuda, CachyOS | `pacman` |
| Debian-based | Debian, Ubuntu, Linux Mint, Pop!_OS, Kali | `apt` |
| Fedora/RHEL-based | Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux | `dnf` / `yum` |
| SUSE-based | openSUSE Leap, openSUSE Tumbleweed, SLES | `zypper` |


## Installation

```bash
chmod +x modem-manager.sh
./modem-manager.sh
```

On first run, if any dependencies are missing the script will:
1. Show exactly which tools are missing
2. Show which packages will be installed and via which package manager
3. **Ask for confirmation before installing anything**
4. After installation, ask before enabling/starting required services (ModemManager, NetworkManager)

## Usage

```bash
# From Auto Unlock Service menu:
1) Install   - Set up automatic unlock with encrypted PIN
2) Uninstall - Remove the service
3) Status    - Check service status and logs
```

**Security Features:**
- PIN encrypted using systemd-creds
- No plain-text PIN in files or logs
- Credentials loaded at runtime only
- Automatic unlock on every boot

## Version

**v1.3** - Added FCC unlock management for Qualcomm/Intel modems (EM120, SDX55, L860) with automatic detection and unlock script configuration

**v1.2** - Reorganized menu structure, added automatic SIM unlock with encrypted credentials, expanded distro support (Fedora/RHEL, openSUSE), user-confirmed dependency installation

## License

MIT License - see [LICENSE](LICENSE)

## Author

Murr - [GitHub](https://github.com/vtstv)
