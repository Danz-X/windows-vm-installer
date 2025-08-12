# Windows VM Auto Installer for VPS

🚀 Automated script to install Windows VM on Ubuntu VPS using Docker and dockurr/windows image.

## Features

- ✅ **One-click installation** - Full automated setup
- ✅ **Multiple Windows versions** - Windows 10/11, LTSC, Server 2019/2022
- ✅ **System requirements check** - RAM, disk space, KVM support
- ✅ **Auto Docker installation** - Docker CE + Docker Compose
- ✅ **Firewall configuration** - Auto open required ports
- ✅ **Interactive setup** - Choose specs and credentials
- ✅ **Root support** - Works with root and non-root users

## Supported Windows Versions

| Version | Description |
|---------|-------------|
| `win10` | Windows 10 Pro |
| `win11` | Windows 11 Pro |
| `ltsc10` | Windows 10 LTSC |
| `2022` | Windows Server 2022 |
| `2019` | Windows Server 2019 |

## System Requirements

### Minimum Requirements
- **OS**: Ubuntu 18.04+ (other Linux distros may work)
- **RAM**: 8GB+ (6GB for Windows + 2GB for host)
- **Storage**: 200GB+ free space
- **CPU**: 4 cores with virtualization support
- **Virtualization**: KVM support required

### Recommended Requirements
- **RAM**: 16GB+
- **Storage**: 500GB+ SSD
- **CPU**: 8 cores
- **Network**: Unlimited bandwidth

## Quick Start

### Method 1: Direct Download & Run
```bash
wget -O install-windows-vm.sh https://raw.githubusercontent.com/Danz-X/windows-vm-installer/main/install-windows-vm.sh
chmod +x install-windows-vm.sh
bash install-windows-vm.sh
```

### Method 2: Clone Repository
```bash
git clone https://github.com/Danz-X/windows-vm-installer.git
cd windows-vm-installer
chmod +x install-windows-vm.sh
bash install-windows-vm.sh
```

### Method 3: One-liner Installation
```bash
curl -sSL https://raw.githubusercontent.com/Danz-X/windows-vm-installer/main/install-windows-vm.sh | bash
```

## Installation Process

The script will:

1. **Check system requirements** (RAM, disk, KVM)
2. **Install Docker & Docker Compose** if not present
3. **Configure firewall** (open ports 8006, 3389)
4. **Setup directories** with proper permissions
5. **Interactive configuration** for Windows specs
6. **Generate docker-compose.yml** with your settings
7. **Start Windows VM** container
8. **Display access information**

## Configuration Options

During installation, you'll be prompted to configure:

- **Windows Version**: Choose from available versions
- **RAM Size**: Default 6GB (adjust based on your VPS)
- **CPU Cores**: Default 4 cores
- **Disk Size**: Default 150GB
- **Username**: Windows admin username (default: admin)
- **Password**: Windows admin password (minimum 8 characters)

## Access Your Windows VM

After installation, you can access Windows via:

### Web Console (Recommended for first setup)
```
http://YOUR_VPS_IP:8006
```

### RDP Connection
```
Server: YOUR_VPS_IP:3389
Username: [your_chosen_username]
Password: [your_chosen_password]
```

## Useful Commands

### Check VM Status
```bash
docker ps
docker logs windows
docker logs -f windows  # Follow logs
```

### Control VM
```bash
cd ~/windows-vm  # or /root/windows-vm if root
docker-compose up -d      # Start VM
docker-compose down       # Stop VM
docker-compose restart    # Restart VM
docker-compose pull       # Update image
```

### Monitor Resources
```bash
docker stats windows     # Real-time stats
htop                     # System resources
```

## Troubleshooting

### VM Won't Start
```bash
# Check logs
docker logs windows

# Check KVM support
ls -la /dev/kvm
lsmod | grep kvm

# Check system resources
free -h
df -h
```

### Can't Connect via RDP
1. **Wait for Windows installation** - Initial setup takes 30-60 minutes
2. **Check via web console first** - `http://YOUR_VPS_IP:8006`
3. **Verify firewall** - Ports 3389 and 8006 should be open
4. **Check container status** - `docker ps` should show "windows" running

### Performance Issues
```bash
# Increase RAM allocation
nano docker-compose.yml
# Change RAM_SIZE: "8G" (or higher)
docker-compose up -d

# Check host resources
htop
iotop
```

### Storage Issues
```bash
# Check disk usage
df -h
du -sh /var/win10

# Clean Docker
docker system prune -af
docker volume prune -f
```

## Security Considerations

- Change default password immediately after first login
- Use strong passwords (12+ characters)
- Enable Windows Firewall inside the VM
- Keep Windows updated
- Consider VPN for RDP access
- Regularly backup important data

## Backup & Restore

### Backup VM Data
```bash
# Stop VM
docker-compose down

# Backup storage
tar -czf windows-backup-$(date +%Y%m%d).tar.gz /var/win10

# Backup compose file
cp docker-compose.yml docker-compose.yml.backup
```

### Restore VM
```bash
# Restore storage
tar -xzf windows-backup-YYYYMMDD.tar.gz -C /

# Start VM
docker-compose up -d
```

## Advanced Configuration

### Custom Docker Compose
You can modify `docker-compose.yml` for advanced settings:

```yaml
version: "3"
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "win10"
      RAM_SIZE: "8G"
      CPU_CORES: "6" 
      DISK_SIZE: "200G"
      USERNAME: "admin"
      PASSWORD: "YourStrongPassword123"
      # Additional options:
      # LANGUAGE: "English"
      # KEYBOARD: "us"
      # DEBUG: "Y"
    devices:
      - /dev/kvm
    cap_add:
      - NET_ADMIN
    ports:
      - "8006:8006"
      - "3389:3389/tcp"
      - "3389:3389/udp"
    stop_grace_period: 2m
    restart: unless-stopped
    volumes:
      - /var/win10:/storage
    # Resource limits
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 6G
```

### Network Configuration
For advanced networking, you can create custom networks:

```bash
docker network create windows-net
# Update compose file to use custom network
```

## FAQ

**Q: How long does the first setup take?**
A: 30-60 minutes depending on internet speed and VPS performance.

**Q: Can I run multiple Windows VMs?**
A: Yes, but you'll need to change ports and container names in compose file.

**Q: Does this work on other Linux distributions?**
A: Primarily tested on Ubuntu. May work on Debian, CentOS with modifications.

**Q: Can I use this for production?**
A: This is suitable for development/testing. For production, consider proper licensing and security hardening.

**Q: How do I update Windows?**
A: Use Windows Update inside the VM normally.

## Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/Danz-X/windows-vm-installer/blob/main/LICENSE) file for details.

## Disclaimer

- This script is provided as-is without warranty
- Ensure you have proper Windows licensing
- Use at your own risk
- Not affiliated with Microsoft or Docker

## Support

- 🐛 [Report Issues](https://github.com/Danz-X/windows-vm-installer/issues)
- 💬 [Discussions](https://github.com/Danz-X/windows-vm-installer/discussions)
- ⭐ Star this repo if it helped you!

## Acknowledgments

- [dockurr/windows](https://github.com/dockurr/windows) - The Docker image that makes this possible
- [Docker](https://docker.com) - Containerization platform
- Ubuntu community for the excellent documentation

---

**Made with ❤️ for the selfhosted community**
