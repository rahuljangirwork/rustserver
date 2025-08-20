#!/bin/bash

# Download RustDesk server binaries
set -euo pipefail

# Download RustDesk server binaries
download_server_binaries() {
    log_info "Downloading RustDesk server binaries..."
    
    # Load configuration
    source "${SCRIPT_DIR}/config/server.conf"
    
    local base_url="https://github.com/rustdesk/rustdesk-server/releases/latest/download"
    
    # Create temporary directory
    local temp_dir="/tmp/rustdesk-server-installer"
    mkdir -p "${temp_dir}"
    
    # Download hbbs (hub server)
    log_info "Downloading hbbs (hub server)..."
    if ! download_file "${base_url}/hbbs-linux-${ARCHITECTURE}" "${temp_dir}/hbbs"; then
        log_error "Failed to download hbbs"
        exit 1
    fi
    
    # Download hbbr (relay server)
    log_info "Downloading hbbr (relay server)..."
    if ! download_file "${base_url}/hbbr-linux-${ARCHITECTURE}" "${temp_dir}/hbbr"; then
        log_error "Failed to download hbbr"
        exit 1
    fi
    
    # Install binaries
    install_binaries "${temp_dir}"
    
    log_success "Server binaries downloaded and installed"
}

# Install downloaded binaries
install_binaries() {
    local temp_dir="$1"
    
    log_info "Installing server binaries..."
    
    # Copy binaries to install directory
    execute_cmd "cp ${temp_dir}/hbbs ${INSTALL_DIR}/"
    execute_cmd "cp ${temp_dir}/hbbr ${INSTALL_DIR}/"
    
    # Make executable
    execute_cmd "chmod +x ${INSTALL_DIR}/hbbs ${INSTALL_DIR}/hbbr"
    
    # Set ownership
    execute_cmd "chown ${SERVICE_USER}:${SERVICE_USER} ${INSTALL_DIR}/hbbs ${INSTALL_DIR}/hbbr"
    
    # Verify installation
    if [[ -x "${INSTALL_DIR}/hbbs" && -x "${INSTALL_DIR}/hbbr" ]]; then
        log_success "Binaries installed successfully"
    else
        log_error "Binary installation verification failed"
        exit 1
    fi
    
    # Clean up
    rm -rf "${temp_dir}"
}
