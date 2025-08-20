#!/bin/bash

# Environment setup for RustDesk server
set -euo pipefail

# Setup environment for RustDesk server
setup_environment() {
    log_info "Setting up RustDesk server environment..."
    
    # Load configuration
    source "${SCRIPT_DIR}/config/server.conf"
    
    # Check internet connectivity
    check_internet || {
        log_error "Internet connectivity required for installation"
        exit 1
    }
    
    # Install basic dependencies
    install_dependencies
    
    # Create service user
    create_service_user
    
    # Create directories
    create_directories
    
    log_success "Environment setup completed"
}

# Install basic dependencies
install_dependencies() {
    log_info "Installing basic dependencies..."
    
    case "${PACKAGE_MANAGER}" in
        "dnf"|"yum")
            execute_cmd "${PACKAGE_MANAGER} install -y wget curl systemd"
            ;;
        "apt")
            execute_cmd "apt-get update"
            execute_cmd "apt-get install -y wget curl systemd"
            ;;
        *)
            log_warning "Unknown package manager, skipping dependency installation"
            ;;
    esac
}

# Create service user
create_service_user() {
    log_info "Creating service user: ${SERVICE_USER}"
    
    if ! id "${SERVICE_USER}" &>/dev/null; then
        execute_cmd "useradd -r -s /bin/false -d /nonexistent ${SERVICE_USER}"
        log_success "Created user: ${SERVICE_USER}"
    else
        log_info "User ${SERVICE_USER} already exists"
    fi
}

# Create necessary directories
create_directories() {
    log_info "Creating directories..."
    
    # Create directories
    execute_cmd "mkdir -p ${INSTALL_DIR} ${CONFIG_DIR} ${LOG_DIR}"
    
    # Set ownership
    execute_cmd "chown ${SERVICE_USER}:${SERVICE_USER} ${INSTALL_DIR} ${CONFIG_DIR} ${LOG_DIR}"
    
    # Set permissions
    execute_cmd "chmod 755 ${INSTALL_DIR} ${CONFIG_DIR}"
    execute_cmd "chmod 750 ${LOG_DIR}"
    
    log_success "Directories created and configured"
}
