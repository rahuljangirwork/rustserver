#!/bin/bash

# Start RustDesk server services
set -euo pipefail

# Start RustDesk services
start_rustdesk_services() {
    log_info "Starting RustDesk server services..."
    
    # Enable and start services
    enable_services
    start_services
    verify_services
    
    log_success "RustDesk services started successfully"
}

# Enable services for auto-start
enable_services() {
    log_info "Enabling services for auto-start..."
    
    local services=("rustdesk-hbbs" "rustdesk-hbbr")
    
    for service in "${services[@]}"; do
        if execute_cmd "systemctl enable $service"; then
            log_success "Enabled service: $service"
        else
            log_error "Failed to enable service: $service"
            exit 1
        fi
    done
}

# Start services
start_services() {
    log_info "Starting services..."
    
    # Start hbbr first (relay server)
    if execute_cmd "systemctl start rustdesk-hbbr"; then
        log_success "Started rustdesk-hbbr service"
    else
        log_error "Failed to start rustdesk-hbbr service"
        show_service_logs "rustdesk-hbbr"
        exit 1
    fi
    
    # Wait a moment for hbbr to initialize
    sleep 2
    
    # Start hbbs (hub server)
    if execute_cmd "systemctl start rustdesk-hbbs"; then
        log_success "Started rustdesk-hbbs service"
    else
        log_error "Failed to start rustdesk-hbbs service"
        show_service_logs "rustdesk-hbbs"
        exit 1
    fi
    
    # Wait for services to initialize
    sleep 3
}

# Verify services are running
verify_services() {
    log_info "Verifying services are running..."
    
    local services=("rustdesk-hbbs" "rustdesk-hbbr")
    local all_running=true
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_success "Service is running: $service"
        else
            log_error "Service is not running: $service"
            all_running=false
            show_service_logs "$service"
        fi
    done
    
    if [[ "$all_running" != "true" ]]; then
        log_error "Some services failed to start"
        exit 1
    fi
    
    # Check if ports are listening
    verify_listening_ports
}

# Verify listening ports
verify_listening_ports() {
    log_info "Verifying listening ports..."
    
    # Load port configuration
    source "${SCRIPT_DIR}/config/ports.conf"
    
    # Wait a moment for ports to open
    sleep 2
    
    local expected_ports=("21115" "21116" "21117")
    
    for port in "${expected_ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_success "Port $port is listening"
        elif ss -tlnp 2>/dev/null | grep -q ":$port "; then
            log_success "Port $port is listening"
        else
            log_warning "Port $port may not be listening"
        fi
    done
}

# Show service logs for troubleshooting
show_service_logs() {
    local service_name="$1"
    local lines="${2:-20}"
    
    log_info "Last $lines lines of $service_name logs:"
    journalctl -u "$service_name" -n "$lines" --no-pager 2>/dev/null || \
    log_warning "Could not retrieve logs for $service_name"
}

# Stop services (for troubleshooting)
stop_services() {
    log_info "Stopping RustDesk services..."
    
    local services=("rustdesk-hbbs" "rustdesk-hbbr")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            execute_cmd "systemctl stop $service"
            log_info "Stopped service: $service"
        fi
    done
}

# Restart services
restart_services() {
    log_info "Restarting RustDesk services..."
    
    stop_services
    sleep 2
    start_services
    verify_services
    
    log_success "Services restarted successfully"
}

# Show service status
show_service_status() {
    log_info "RustDesk Service Status:"
    
    local services=("rustdesk-hbbs" "rustdesk-hbbr")
    
    for service in "${services[@]}"; do
        echo
        echo "=== $service ==="
        systemctl status "$service" --no-pager -l 2>/dev/null || \
        log_warning "Could not get status for $service"
    done
}
