#!/bin/bash

# System Information Script
# Displays comprehensive system information for Linux systems

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   SYSTEM INFORMATION SCRIPT                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to print section headers
print_section() {
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║ $1${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# System Overview
print_section "SYSTEM OVERVIEW"
echo -e "${GREEN}Hostname:${NC} $(hostname)"
echo -e "${GREEN}Uptime:${NC} $(uptime -p | sed 's/up //')"
echo -e "${GREEN}Date/Time:${NC} $(date)"
echo -e "${GREEN}Logged in users:${NC} $(who | wc -l)"

# OS Information
print_section "OPERATING SYSTEM"
if [ -f /etc/os-release ]; then
    source /etc/os-release
    echo -e "${GREEN}Distribution:${NC} $PRETTY_NAME"
    echo -e "${GREEN}Kernel:${NC} $(uname -r)"
    echo -e "${GREEN}Architecture:${NC} $(uname -m)"
else
    echo -e "${GREEN}Kernel:${NC} $(uname -r)"
    echo -e "${GREEN}Architecture:${NC} $(uname -m)"
fi

# CPU Information
print_section "CPU INFORMATION"
if command_exists lscpu; then
    echo -e "${GREEN}CPU Model:${NC} $(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^ *//')"
    echo -e "${GREEN}CPU Cores:${NC} $(nproc)"
    echo -e "${GREEN}CPU Threads:${NC} $(lscpu | grep -E "^Thread" | cut -d: -f2 | sed 's/^ *//')"
    echo -e "${GREEN}CPU MHz:${NC} $(lscpu | grep "MHz" | head -1 | cut -d: -f2 | sed 's/^ *//')"
else
    echo -e "${YELLOW}lscpu not available${NC}"
fi

# Memory Information
print_section "MEMORY INFORMATION"
if command_exists free; then
    total_mem=$(free -h | grep Mem | awk '{print $2}')
    used_mem=$(free -h | grep Mem | awk '{print $3}')
    free_mem=$(free -h | grep Mem | awk '{print $4}')
    echo -e "${GREEN}Total Memory:${NC} $total_mem"
    echo -e "${GREEN}Used Memory:${NC} $used_mem"
    echo -e "${GREEN}Free Memory:${NC} $free_mem"
    
    # Show memory usage as percentage
    total_mem_bytes=$(free | grep Mem | awk '{print $2}')
    used_mem_bytes=$(free | grep Mem | awk '{print $3}')
    mem_percent=$((used_mem_bytes * 100 / total_mem_bytes))
    echo -e "${GREEN}Memory Usage:${NC} $mem_percent%"
else
    echo -e "${YELLOW}free command not available${NC}"
fi

# Disk Information
print_section "DISK INFORMATION"
if command_exists df; then
    echo -e "${GREEN}Disk Usage:${NC}"
    df -h | grep -E "^/dev/" | while read line; do
        device=$(echo $line | awk '{print $1}')
        size=$(echo $line | awk '{print $2}')
        used=$(echo $line | awk '{print $3}')
        avail=$(echo $line | awk '{print $4}')
        use_percent=$(echo $line | awk '{print $5}')
        mount=$(echo $line | awk '{print $6}')
        echo -e "  $device: $used/$size used ($use_percent) on $mount"
    done
else
    echo -e "${YELLOW}df command not available${NC}"
fi

# Network Information
print_section "NETWORK INFORMATION"
if command_exists ip; then
    echo -e "${GREEN}Network Interfaces:${NC}"
    ip -o addr show | grep -v "lo" | while read line; do
        interface=$(echo $line | awk '{print $2}')
        ip_addr=$(echo $line | awk '{print $4}')
        state=$(cat "/sys/class/net/$interface/operstate" 2>/dev/null)
        echo -e "  $interface: $ip_addr ($state)"
    done
else
    echo -e "${YELLOW}ip command not available${NC}"
fi

# Load Average
print_section "SYSTEM LOAD"
load_avg=$(cat /proc/loadavg)
echo -e "${GREEN}Load Average (1, 5, 15 min):${NC} $load_avg"

# Running Processes
print_section "TOP PROCESSES BY MEMORY"
if command_exists ps; then
    ps aux --sort=-%mem | head -6 | awk '{print $2, $4, $11}' | while read pid mem command; do
        if [ "$pid" != "PID" ]; then
            echo -e "  PID: $pid, MEM: $mem%, Command: $command"
        fi
    done
else
    echo -e "${YELLOW}ps command not available${NC}"
fi

# Services Status
print_section "SERVICE STATUS"
if command_exists systemctl; then
    echo -e "${GREEN}Critical Services:${NC}"
    services=("ssh" "nginx" "apache2" "mysql" "postgresql" "docker")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            echo -e "  $service: ${GREEN}Active${NC}"
        else
            echo -e "  $service: ${RED}Inactive${NC}"
        fi
    done
else
    echo -e "${YELLOW}systemctl not available${NC}"
fi

# Hardware Information
print_section "HARDWARE INFORMATION"
# GPU Information
if command_exists lspci; then
    gpu_info=$(lspci | grep -i vga)
    if [ -n "$gpu_info" ]; then
        echo -e "${GREEN}GPU:${NC} $gpu_info"
    fi
fi

# Temperature (if available)
if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp_c=$((temp/1000))
    echo -e "${GREEN}CPU Temperature:${NC} ${temp_c}°C"
fi

# Security Information
print_section "SECURITY INFORMATION"
# Failed login attempts
if [ -f "/var/log/auth.log" ]; then
    failed_logins=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
    echo -e "${GREEN}Failed login attempts:${NC} $failed_logins"
fi

# SSH status
if command_exists systemctl; then
    ssh_status=$(systemctl is-active ssh)
    echo -e "${GREEN}SSH Service:${NC} $ssh_status"
fi

# Firewall status
if command_exists ufw; then
    ufw_status=$(ufw status | grep Status)
    echo -e "${GREEN}UFW Firewall:${NC} $ufw_status"
elif command_exists firewall-cmd; then
    firewall_status=$(firewall-cmd --state 2>/dev/null)
    echo -e "${GREEN}Firewalld:${NC} $firewall_status"
fi

# System Updates
print_section "UPDATE INFORMATION"
if command_exists apt; then
    updates=$(apt list --upgradable 2>/dev/null | wc -l)
    echo -e "${GREEN}Available updates:${NC} $((updates-1))"
elif command_exists yum; then
    updates=$(yum check-update --quiet 2>/dev/null | wc -l)
    echo -e "${GREEN}Available updates:${NC} $updates"
elif command_exists dnf; then
    updates=$(dnf check-update --quiet 2>/dev/null | wc -l)
    echo -e "${GREEN}Available updates:${NC} $updates"
else
    echo -e "${YELLOW}Package manager not detected${NC}"
fi

# Final summary
print_section "SYSTEM SUMMARY"
echo -e "${GREEN}System is running smoothly!${NC}" > /dev/null  # Placeholder

echo -e "\n${CYAN}System information collected on: $(date)${NC}"
echo -e "${CYAN}Script completed successfully!${NC}"
