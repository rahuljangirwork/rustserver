#!/bin/bash

# Create systemd services for RustDesk server
set -euo pipefail

# Create systemd services
create_systemd_services() {
    log_info "Creating systemd services for RustDesk server..."
    
    # Get server IP for relay configuration
    local server_ip
    server_ip=$(get_server_ip)
    
    if [[ -z "$server_ip" ]]; then
        log_error "Could not determine server IP address"
        exit 1
    fi
    
    log_info "Using server IP: $server_ip"
    
    # Create hbbs service
    create_hbbs_service "$server_ip"
    
    # Create hbbr service
    create_hbbr_service
    
    # Reload systemd
    execute_cmd "systemctl daemon-reload"
    
    log_success "Systemd services created successfully"
}

# Create hbbs (hub server) service
create_hbbs_service() {
    local server_ip="$1"
    
    log_info "Creating hbbs (hub server) service..."
    
    # Use template and substitute variables
    local service_file="/etc/systemd/system/rustdesk-hbbs.service"
    
    # Create service file from template
    cat > "$service_file" << EOF
[Unit]
Description=RustDesk Hub Server (hbbs)
Documentation=https://github.com/rustdesk/rustdesk-server
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/hbbs -r ${server_ip}:21117
Restart=always
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${INSTALL_DIR} ${LOG_DIR}

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rustdesk-hbbs

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "Created hbbs service file"
}

# Create hbbr (relay server) service
create_hbbr_service() {
    log_info "Creating hbbr (relay server) service..."
    
    local service_file="/etc/systemd/system/rustdesk-hbbr.service"
    
    # Create service file
    cat > "$service_file" << EOF
[Unit]
Description=RustDesk Relay Server (hbbr)
Documentation=https://github.com/rustdesk/rustdesk-server
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/hbbr
Restart=always
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${INSTALL_DIR} ${LOG_DIR}

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rustdesk-hbbr

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "Created hbbr service file"
}

# Create optional web console service
create_web_console_service() {
    local server_ip="$1"
    local web_password="$2"
    
    log_info "Creating web console service..."
    
    local service_file="/etc/systemd/system/rustdesk-hbbs-web.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=RustDesk Hub Server with Web Console
Documentation=https://github.com/rustdesk/rustdesk-server
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/hbbs -r ${server_ip}:21117 -w ${web_password}
Restart=always
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${INSTALL_DIR} ${LOG_DIR}

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rustdesk-hbbs-web

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "Created web console service file"
}

# Validate service files
validate_service_files() {
    log_info "Validating service files..."
    
    local services=("rustdesk-hbbs" "rustdesk-hbbr")
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1 || systemctl list-unit-files | grep -q "$service"; then
            log_success "Service file validated: $service"
        else
            log_error "Service file validation failed: $service"
            exit 1
        fi
    done
}
