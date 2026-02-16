# Modem Manager

Interactive bash tool for managing GSM/LTE/eSIM modems on Linux.

<img width="1471" height="1056" alt="modemmanager" src="https://github.com/user-attachments/assets/fa8ddcd4-f7d7-493d-be73-951b87ed98ff" />

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

### Main Menu Options

1. **Connect (Up)** - Enable modem and connect to network
2. **Disconnect (Down)** - Disconnect and disable modem
3. **Restart Modem** - Full modem restart
4. **Show Signal** - Display signal strength and network info
5. **Full Diagnostics** - Complete system diagnostics
6. **SIM Information** - View detailed SIM card info
7. **Unlock PIN** - Manually unlock SIM with PIN
8. **Unlock PUK** - Unlock SIM with PUK code
9. **Change PIN** - Change SIM PIN code
10. **Disable PIN** - Disable PIN requirement
11. **Enable PIN** - Enable PIN protection
12. **Store PIN in Connection** - Save PIN in NetworkManager
13. **Connection Management** - Create/modify/delete connections
14. **Switch SIM Slot** - Switch between physical SIM and eSIM
15. **eSIM Management** - Manage eSIM profiles
16. **SIM Unlock Service** - Configure automatic encrypted unlock


```bash
# From menu option 16:
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

**v1.2** - Added automatic SIM unlock service with encrypted credentials
**v1.1** - Added Create/modify/delete connections


## License

MIT License - see [LICENSE](LICENSE)

## Author

Murr - [GitHub](https://github.com/vtstv)
