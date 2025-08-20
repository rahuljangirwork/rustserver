#!/bin/bash

# RustDesk Server Auto Installer
# Main entry point script
set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
LOGS_DIR="${SCRIPT_DIR}/logs"

# Create logs directory
mkdir -p "${LOGS_DIR}"

# Log file
LOG_FILE="${LOGS_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

# Source common functions
source "${SCRIPTS_DIR}/common.sh"

# Main installation function
main() {
    log_info "=== RustDesk Server Installation Started ==="
    log_info "Timestamp: $(date)"
    log_info "User: $(whoami)"
    log_info "Script directory: ${SCRIPT_DIR}"
    
    # Check if running as root
    check_root
    
    # Detect system
    log_info "Detecting system..."
    source "${SCRIPTS_DIR}/detect_system.sh"
    if ! detect_system; then
        log_error "Failed to detect system"
        exit 1
    fi
    
    # Setup environment
    log_info "Setting up environment..."
    source "${SCRIPTS_DIR}/setup_environment.sh"
    setup_environment
    
    # Download server binaries
    log_info "Downloading server binaries..."
    source "${SCRIPTS_DIR}/download_server.sh"
    download_server_binaries
    
    # Generate keys
    log_info "Generating server keys..."
    source "${SCRIPTS_DIR}/generate_keys.sh"
    generate_server_keys
    
    # Configure firewall
    log_info "Configuring firewall..."
    source "${SCRIPTS_DIR}/configure_firewall.sh"
    configure_server_firewall
    
    # Create services
    log_info "Creating systemd services..."
    source "${SCRIPTS_DIR}/create_services.sh"
    create_systemd_services
    
    # Start services
    log_info "Starting services..."
    source "${SCRIPTS_DIR}/start_services.sh"
    start_rustdesk_services
    
    log_success "=== RustDesk Server Installation Completed Successfully ==="
    show_connection_info
}

# Trap for cleanup on exit
trap cleanup EXIT ERR

# Run main function
main "$@"
