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
    
    # Map architecture names (x86_64 -> amd64, aarch64 -> arm64v8)
    local download_arch
    case "${ARCHITECTURE}" in
        "x86_64")
            download_arch="amd64"
            ;;
        "aarch64")
            download_arch="arm64v8"
            ;;
        *)
            log_error "Unsupported architecture: ${ARCHITECTURE}"
            exit 1
            ;;
    esac
    
    # Download ZIP package
    log_info "Downloading RustDesk server package for ${download_arch}..."
    local zip_file="${temp_dir}/rustdesk-server-linux-${download_arch}.zip"
    
    if ! download_file "${base_url}/rustdesk-server-linux-${download_arch}.zip" "${zip_file}"; then
        log_error "Failed to download RustDesk server package"
        exit 1
    fi
    
    # Extract binaries
    extract_binaries "${temp_dir}" "${zip_file}"
    
    # Install binaries
    install_binaries "${temp_dir}"
    
    log_success "Server binaries downloaded and installed"
}

# Extract binaries from ZIP package
extract_binaries() {
    local temp_dir="$1"
    local zip_file="$2"
    
    log_info "Extracting server binaries..."
    
    # Check if unzip is available
    if ! command -v unzip >/dev/null 2>&1; then
        log_info "Installing unzip utility..."
        case "${PACKAGE_MANAGER}" in
            "dnf"|"yum")
                execute_cmd "${PACKAGE_MANAGER} install -y unzip"
                ;;
            "apt")
                execute_cmd "apt-get install -y unzip"
                ;;
            *)
                log_error "unzip utility required but package manager unknown"
                exit 1
                ;;
        esac
    fi
    
    # Extract ZIP file
    cd "${temp_dir}"
    if ! execute_cmd "unzip -o ${zip_file}"; then
        log_error "Failed to extract ZIP package"
        exit 1
    fi
    
    # Verify binaries exist
    if [[ ! -f "hbbs" || ! -f "hbbr" ]]; then
        log_error "Expected binaries (hbbs, hbbr) not found in extracted package"
        log_info "Contents of extracted package:"
        ls -la "${temp_dir}"
        exit 1
    fi
    
    log_success "Binaries extracted successfully"
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
        
        # Show binary info
        log_info "Binary information:"
        ls -la "${INSTALL_DIR}/hbbs" "${INSTALL_DIR}/hbbr"
        
        # Test binaries
        if "${INSTALL_DIR}/hbbs" --help >/dev/null 2>&1; then
            log_success "hbbs binary is functional"
        else
            log_warning "hbbs binary test failed"
        fi
        
        if "${INSTALL_DIR}/hbbr" --help >/dev/null 2>&1; then
            log_success "hbbr binary is functional"
        else
            log_warning "hbbr binary test failed"
        fi
    else
        log_error "Binary installation verification failed"
        exit 1
    fi
    
    # Clean up
    rm -rf "${temp_dir}"
}

# Alternative download method using specific version
download_specific_version() {
    local version="${1:-1.1.14}"
    local temp_dir="/tmp/rustdesk-server-installer"
    
    log_info "Downloading specific version: ${version}"
    
    mkdir -p "${temp_dir}"
    
    # Map architecture
    local download_arch
    case "${ARCHITECTURE}" in
        "x86_64") download_arch="amd64" ;;
        "aarch64") download_arch="arm64v8" ;;
        *) log_error "Unsupported architecture: ${ARCHITECTURE}"; exit 1 ;;
    esac
    
    local version_url="https://github.com/rustdesk/rustdesk-server/releases/download/${version}/rustdesk-server-linux-${download_arch}.zip"
    local zip_file="${temp_dir}/rustdesk-server-linux-${download_arch}.zip"
    
    if download_file "${version_url}" "${zip_file}"; then
        extract_binaries "${temp_dir}" "${zip_file}"
        install_binaries "${temp_dir}"
    else
        log_error "Failed to download version ${version}"
        exit 1
    fi
}
