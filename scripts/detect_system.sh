#!/bin/bash

# System detection for RustDesk server
set -euo pipefail

# Global variables for detected system info
DISTRO=""
DISTRO_VERSION=""
ARCHITECTURE=""
PACKAGE_MANAGER=""

# Detect system information
detect_system() {
    log_info "Starting system detection..."
    
    # Detect architecture
    ARCHITECTURE=$(uname -m)
    log_info "Architecture: ${ARCHITECTURE}"
    
    # Check for supported architectures
    case "${ARCHITECTURE}" in
        x86_64|amd64)
            ARCHITECTURE="x86_64"
            ;;
        aarch64|arm64)
            ARCHITECTURE="aarch64"
            ;;
        *)
            log_error "Unsupported architecture: ${ARCHITECTURE}"
            return 1
            ;;
    esac
    
    # Detect distribution
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO="${ID}"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
        
        log_info "Detected OS: ${NAME} ${VERSION_ID:-}"
        log_info "Distribution ID: ${DISTRO}"
    else
        log_error "Cannot detect Linux distribution - /etc/os-release not found"
        return 1
    fi
    
    # Detect package manager
    detect_package_manager
    
    log_info "System detection completed successfully"
    log_info "Distro: ${DISTRO}"
    log_info "Version: ${DISTRO_VERSION}"
    log_info "Package Manager: ${PACKAGE_MANAGER}"
    log_info "Architecture: ${ARCHITECTURE}"
    
    return 0
}

# Detect available package manager
detect_package_manager() {
    log_info "Detecting package manager..."
    
    if command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
        log_info "Found DNF package manager"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
        log_info "Found YUM package manager"
    elif command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
        log_info "Found APT package manager"
    else
        log_warning "No recognized package manager found"
        PACKAGE_MANAGER="unknown"
    fi
}
