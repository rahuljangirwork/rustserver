#!/bin/bash

# Configure firewall for RustDesk server
set -euo pipefail

# Configure server firewall
configure_server_firewall() {
    log_info "Configuring firewall for RustDesk server..."
    
    # Load port configuration
    source "${SCRIPT_DIR}/config/ports.conf"
    
    # Detect firewall type and configure
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        configure_firewalld
    elif command -v ufw >/dev/null 2>&1; then
        configure_ufw
    elif command -v iptables >/dev/null 2>&1; then
        configure_iptables
    else
        log_warning "No supported firewall found"
        show_manual_firewall_config
    fi
    
    log_success "Firewall configuration completed"
}

# Configure firewalld (RHEL/CentOS/Amazon Linux)
configure_firewalld() {
    log_info "Configuring firewalld..."
    
    # Add RustDesk server ports
    for port in "${RUSTDESK_SERVER_PORTS[@]}"; do
        if execute_cmd "firewall-cmd --permanent --add-port=${port}"; then
            log_info "Added firewall rule for port: ${port}"
        else
            log_warning "Failed to add firewall rule for port: ${port}"
        fi
    done
    
    # Reload firewall rules
    if execute_cmd "firewall-cmd --reload"; then
        log_success "Firewalld rules reloaded"
    else
        log_warning "Failed to reload firewalld rules"
    fi
    
    # Show current rules
    log_info "Current firewall rules:"
    firewall-cmd --list-ports 2>/dev/null | head -5
}

# Configure UFW (Ubuntu/Debian)
configure_ufw() {
    log_info "Configuring UFW..."
    
    # Check if UFW is active
    if ! ufw status | grep -q "Status: active"; then
        log_warning "UFW is not active"
        if ask_yes_no "Enable UFW firewall?"; then
            execute_cmd "ufw --force enable"
        else
            log_warning "UFW not enabled - manual configuration required"
            return
        fi
    fi
    
    # Add RustDesk server ports
    for port in "${RUSTDESK_SERVER_PORTS[@]}"; do
        # Remove protocol suffix for UFW
        local clean_port=${port%/*}
        local protocol=${port#*/}
        
        if execute_cmd "ufw allow ${clean_port}/${protocol}"; then
            log_info "Added UFW rule for port: ${port}"
        else
            log_warning "Failed to add UFW rule for port: ${port}"
        fi
    done
    
    log_success "UFW rules configured"
}

# Configure iptables (generic)
configure_iptables() {
    log_info "Configuring iptables..."
    
    # Add rules for each port
    for port in "${RUSTDESK_SERVER_PORTS[@]}"; do
        local clean_port=${port%/*}
        local protocol=${port#*/}
        
        if execute_cmd "iptables -A INPUT -p ${protocol} --dport ${clean_port} -j ACCEPT"; then
            log_info "Added iptables rule for port: ${port}"
        else
            log_warning "Failed to add iptables rule for port: ${port}"
        fi
    done
    
    # Try to save rules (method varies by distribution)
    if command -v iptables-save >/dev/null 2>&1; then
        execute_cmd "iptables-save > /etc/iptables/rules.v4" 2>/dev/null || \
        execute_cmd "iptables-save > /etc/sysconfig/iptables" 2>/dev/null || \
        log_warning "Could not save iptables rules permanently"
    fi
    
    log_success "Iptables rules configured"
}

# Show manual firewall configuration
show_manual_firewall_config() {
    log_warning "No automatic firewall configuration available"
    log_info "Please manually configure your firewall to allow these ports:"
    
    for port in "${RUSTDESK_SERVER_PORTS[@]}"; do
        echo "  - ${port}"
    done
    
    log_info "Or configure your cloud provider security groups accordingly"
}

# Helper function for yes/no questions
ask_yes_no() {
    local question="$1"
    local answer
    
    while true; do
        read -p "${question} (y/n): " answer
        case $answer in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Check if cloud firewall configuration is needed
check_cloud_firewall() {
    log_info "Cloud Provider Firewall Configuration:"
    
    # Check if running on AWS
    if curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
        log_warning "AWS EC2 detected - configure Security Groups:"
        echo "  - Go to EC2 Console > Security Groups"
        echo "  - Edit inbound rules to allow:"
        for port in "${RUSTDESK_SERVER_PORTS[@]}"; do
            echo "    - ${port} from 0.0.0.0/0 (or restricted source)"
        done
    fi
    
    # Check for other cloud providers could be added here
    log_info "Ensure cloud firewall/security groups allow the required ports"
}
