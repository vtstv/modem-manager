# Modem Manager

Interactive bash tool for managing GSM/LTE/eSIM modems on Linux.

<img width="1450" height="1059" alt="modemmanager" src="https://github.com/user-attachments/assets/a1362d27-7170-4529-aa18-c3372779dcda" />

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

### System Integration
- Auto-install dependencies (ModemManager, NetworkManager)
- Supports Arch/CachyOS Linux and Debian/Ubuntu
- Interactive menu-driven interface

## Requirements

- ModemManager
- NetworkManager
- systemd (for automatic unlock feature)
- Arch Linux, Debian, or Ubuntu

## Installation

```bash
chmod +x modem-manager.sh
./modem-manager.sh
```

Dependencies will be automatically installed on first run if missing.

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

**v1.2** - Reorganized menu structure, added automatic SIM unlock with encrypted credentials


## License

MIT License - see [LICENSE](LICENSE)

## Author

Murr - [GitHub](https://github.com/vtstv)
