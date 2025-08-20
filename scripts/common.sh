#!/bin/bash

# Common functions and utilities for RustDesk server installer
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
INSTALL_DIR="/opt/rustdesk-server"
CONFIG_DIR="/etc/rustdesk-server"
LOG_DIR="/var/log/rustdesk-server"
SERVICE_USER="rustdesk"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOG_FILE:-/tmp/rustdesk-server-install.log}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${LOG_FILE:-/tmp/rustdesk-server-install.log}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE:-/tmp/rustdesk-server-install.log}" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOG_FILE:-/tmp/rustdesk-server-install.log}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check internet connectivity
check_internet() {
    log_info "Checking internet connectivity..."
    
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            log_error "No internet connection detected"
            return 1
        fi
    fi
    
    log_success "Internet connectivity confirmed"
    return 0
}

# Execute command with error handling
execute_cmd() {
    local cmd="$*"
    log_info "Executing: ${cmd}"
    
    if eval "${cmd}"; then
        log_success "Command executed successfully: ${cmd}"
        return 0
    else
        local exit_code=$?
        log_error "Command failed with exit code ${exit_code}: ${cmd}"
        return ${exit_code}
    fi
}

# Download file with retry
download_file() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry=0
    
    log_info "Downloading: ${url}"
    log_info "Output: ${output}"
    
    while [[ ${retry} -lt ${max_retries} ]]; do
        if wget -O "${output}" "${url}" >/dev/null 2>&1; then
            log_success "Download completed: ${output}"
            return 0
        else
            retry=$((retry + 1))
            log_warning "Download attempt ${retry}/${max_retries} failed, retrying..."
            sleep 2
        fi
    done
    
    log_error "Download failed after ${max_retries} attempts: ${url}"
    return 1
}

# Get server IP address
get_server_ip() {
    # Try AWS metadata first (for EC2 instances)
    local server_ip
    server_ip=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null) || \
    server_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}') || \
    server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    
    echo "${server_ip}"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Script failed with exit code: ${exit_code}"
        log_info "Check the log file for details: ${LOG_FILE:-/tmp/rustdesk-server-install.log}"
    fi
    
    # Clean up temporary files if any
    if [[ -d /tmp/rustdesk-server-installer ]]; then
        rm -rf /tmp/rustdesk-server-installer
    fi
}

# Show final connection information
show_connection_info() {
    local server_ip
    server_ip=$(get_server_ip)
    
    echo
    log_success "=== RustDesk Server Ready ==="
    echo
    log_info "Server Information:"
    echo "  Server IP: ${server_ip}"
    echo "  Hub Server Port: 21115"
    echo "  Relay Server Port: 21117"
    echo "  Web Console Port: 21119 (if enabled)"
    echo
    
    if [[ -f "${INSTALL_DIR}/id_ed25519.pub" ]]; then
        log_info "Public Key (share this with clients):"
        cat "${INSTALL_DIR}/id_ed25519.pub"
        echo
    fi
    
    log_info "Client Configuration:"
    echo "  ID Server: ${server_ip}:21115"
    echo "  Relay Server: ${server_ip}:21117"
    echo "  Key: $(cat ${INSTALL_DIR}/id_ed25519.pub 2>/dev/null || echo 'Key file not found')"
    echo
    
    log_info "Service Management:"
    echo "  Check Status: systemctl status rustdesk-hbbs rustdesk-hbbr"
    echo "  View Logs: journalctl -u rustdesk-hbbs -f"
    echo "  Restart: systemctl restart rustdesk-hbbs rustdesk-hbbr"
    echo "  Stop: systemctl stop rustdesk-hbbs rustdesk-hbbr"
}
