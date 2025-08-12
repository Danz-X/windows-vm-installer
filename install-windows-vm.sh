#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root - Docker will be configured for root user"
        RUNNING_AS_ROOT=true
    else
        RUNNING_AS_ROOT=false
    fi
}

check_system() {
    print_status "Checking system requirements..."
    
    if ! grep -q "Ubuntu" /etc/os-release; then
        print_warning "This script is optimized for Ubuntu. Proceed with caution on other distributions."
    fi
    
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $RAM_GB -lt 8 ]]; then
        print_warning "Recommended RAM: 8GB+. Current: ${RAM_GB}GB"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    DISK_GB=$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')
    if [[ $DISK_GB -lt 200 ]]; then
        print_warning "Recommended disk space: 200GB+. Available: ${DISK_GB}GB"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    if [[ -e /dev/kvm ]]; then
        print_success "KVM virtualization is available"
    else
        print_error "KVM virtualization not available. This VPS may not support nested virtualization."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_docker() {
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed"
        return
    fi
    
    print_status "Installing Docker..."
    
    apt-get update -qq
    
    apt-get install -y -qq ca-certificates curl gnupg lsb-release
    
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    systemctl start docker
    systemctl enable docker
    
    if [[ "$RUNNING_AS_ROOT" == false ]]; then
        usermod -aG docker $USER
    fi
    
    print_success "Docker installed successfully"
}

install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose is already installed"
        return
    fi
    
    print_status "Installing Docker Compose..."
    apt-get install -y -qq docker-compose
    print_success "Docker Compose installed successfully"
}

configure_firewall() {
    print_status "Configuring firewall..."
    
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        print_status "UFW is active, opening required ports..."
        ufw allow 8006 comment 'Windows VM Web Console'
        ufw allow 3389 comment 'Windows VM RDP'
        print_success "Firewall configured"
    else
        print_status "UFW is not active or not installed, skipping firewall configuration"
    fi
}

setup_directories() {
    print_status "Setting up directories..."
    
    if [[ "$RUNNING_AS_ROOT" == true ]]; then
        mkdir -p /root/windows-vm
        WORK_DIR="/root/windows-vm"
    else
        mkdir -p ~/windows-vm
        WORK_DIR="~/windows-vm"
    fi
    
    mkdir -p /var/win10
    chmod 755 /var/win10
    
    print_success "Directories created"
}

get_user_preferences() {
    echo
    print_status "Windows VM Configuration"
    echo "========================="
    
    echo "Available Windows versions:"
    echo "1) Windows 10 (win10)"
    echo "2) Windows 11 (win11)"
    echo "3) Windows 10 LTSC (ltsc10)"
    echo "4) Windows Server 2022 (2022)"
    echo "5) Windows Server 2019 (2019)"
    
    while true; do
        read -p "Choose Windows version (1-5) [1]: " version_choice
        version_choice=${version_choice:-1}
        
        case $version_choice in
            1) WIN_VERSION="win10"; break;;
            2) WIN_VERSION="win11"; break;;
            3) WIN_VERSION="ltsc10"; break;;
            4) WIN_VERSION="2022"; break;;
            5) WIN_VERSION="2019"; break;;
            *) print_error "Invalid choice. Please select 1-5.";;
        esac
    done
    
    read -p "RAM size in GB [6]: " ram_size
    RAM_SIZE="${ram_size:-6}G"
    
    read -p "CPU cores [4]: " cpu_cores
    CPU_CORES=${cpu_cores:-4}
    
    read -p "Disk size in GB [150]: " disk_size
    DISK_SIZE="${disk_size:-150}G"
    
    read -p "Windows username [admin]: " username
    USERNAME=${username:-admin}
    
    while true; do
        read -s -p "Windows password [Nezuko123]: " password
        echo
        if [[ -z "$password" ]]; then
            PASSWORD="Nezuko123"
            break
        elif [[ ${#password} -ge 8 ]]; then
            PASSWORD="$password"
            break
        else
            print_error "Password must be at least 8 characters long."
        fi
    done
    
    echo
    print_status "Configuration summary:"
    echo "- Windows Version: $WIN_VERSION"
    echo "- RAM: $RAM_SIZE"
    echo "- CPU Cores: $CPU_CORES"
    echo "- Disk Size: $DISK_SIZE"
    echo "- Username: $USERNAME"
    echo "- Password: [HIDDEN]"
    echo
}

create_compose_file() {
    print_status "Creating docker-compose.yml..."
    
    if [[ "$RUNNING_AS_ROOT" == true ]]; then
        cd /root/windows-vm
    else
        cd ~/windows-vm
    fi
    
    cat > docker-compose.yml << EOF
version: "3"
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "$WIN_VERSION"
      RAM_SIZE: "$RAM_SIZE"
      CPU_CORES: "$CPU_CORES"
      DISK_SIZE: "$DISK_SIZE"
      USERNAME: "$USERNAME"
      PASSWORD: "$PASSWORD"
    devices:
      - /dev/kvm
    cap_add:
      - NET_ADMIN
    ports:
      - 8006:8006
      - 3389:3389/tcp
      - 3389:3389/udp
    stop_grace_period: 2m
    restart: on-failure
    volumes:
      - /var/win10:/storage
EOF
    
    print_success "docker-compose.yml created"
}

start_windows_vm() {
    print_status "Starting Windows VM..."
    
    if [[ "$RUNNING_AS_ROOT" == true ]]; then
        cd /root/windows-vm
    else
        cd ~/windows-vm
    fi
    
    docker-compose up -d
    
    print_success "Windows VM started successfully!"
}

show_access_info() {
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo
    print_success "Windows VM Installation Complete!"
    echo "=================================="
    echo
    echo "Access Information:"
    echo "- Web Console: http://$SERVER_IP:8006"
    echo "- RDP Access: $SERVER_IP:3389"
    echo "- Username: $USERNAME"
    echo "- Password: $PASSWORD"
    echo
    echo "Important Notes:"
    echo "- Initial setup may take 30-60 minutes (downloading and installing Windows)"
    echo "- Monitor progress via: docker logs -f windows"
    echo "- Use web console first to check if Windows is ready"
    echo "- RDP will be available after Windows completes installation"
    echo
    echo "Useful Commands:"
    echo "- Check status: docker ps"
    echo "- View logs: docker logs windows"
    echo "- Stop VM: docker-compose down"
    echo "- Start VM: docker-compose up -d"
    echo "- Restart VM: docker-compose restart"
    echo
}

main() {
    clear
    echo "================================================================"
    echo "           Windows VM Auto Installer for VPS"
    echo "================================================================"
    echo
    
    check_root
    check_system
    install_docker
    install_docker_compose
    configure_firewall
    setup_directories
    get_user_preferences
    create_compose_file
    start_windows_vm
    show_access_info
    
    print_success "Installation completed! Enjoy your Windows VM!"
}

main "$@"
