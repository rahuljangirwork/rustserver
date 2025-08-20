#!/bin/bash

# Generate RustDesk server keys
set -euo pipefail

# Generate server keys
generate_server_keys() {
    log_info "Generating RustDesk server keys..."
    
    cd "${INSTALL_DIR}"
    
    # Check if keys already exist
    if [[ -f "id_ed25519" && -f "id_ed25519.pub" ]]; then
        log_warning "Keys already exist, skipping generation"
        log_info "Existing public key:"
        cat id_ed25519.pub
        return 0
    fi
    
    # Generate keys by running hbbs briefly
    log_info "Starting hbbs to generate keys..."
    
    # Run hbbs in background to generate keys
    sudo -u "${SERVICE_USER}" ./hbbs -k _ > /dev/null 2>&1 &
    local hbbs_pid=$!
    
    # Wait for key generation
    sleep 3
    
    # Stop hbbs
    kill $hbbs_pid 2>/dev/null || true
    wait $hbbs_pid 2>/dev/null || true
    
    # Verify keys were generated
    if [[ -f "id_ed25519" && -f "id_ed25519.pub" ]]; then
        # Set proper permissions
        execute_cmd "chown ${SERVICE_USER}:${SERVICE_USER} id_ed25519 id_ed25519.pub"
        execute_cmd "chmod 600 id_ed25519"
        execute_cmd "chmod 644 id_ed25519.pub"
        
        log_success "Server keys generated successfully"
        log_info "Public key content:"
        cat id_ed25519.pub
    else
        log_error "Failed to generate server keys"
        exit 1
    fi
}
