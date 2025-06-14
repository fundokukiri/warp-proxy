#!/bin/bash
# Force unbuffered output for better log visibility
exec > >(stdbuf -o0 cat)
exec 2> >(stdbuf -o0 cat >&2)

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print with timestamp and formatting
log_info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ${CYAN}INFO${NC}  $1"
}

log_success() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ${GREEN}OK${NC}    $1"
}

log_warning() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ${YELLOW}WARN${NC}  $1"
}

log_error() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ${RED}ERROR${NC} $1"
}

# Function to show loading animation
show_loading() {
    local pid=$1
    local delay=0.3
    local spinstr='|/-\'
    local temp
    
    while ps -p $pid > /dev/null 2>&1; do
        temp=${spinstr#?}
        printf " [%c] %s\r" "$spinstr" "$2"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "    \r"
}

# Function to handle signals
cleanup() {
    log_warning "Received shutdown signal, cleaning up..."
    pkill -f warp-svc
    pkill -f danted
    log_info "Cleanup completed"
    exit 0
}
trap cleanup SIGTERM SIGINT

# Function to check if warp daemon is ready
wait_for_warp_daemon() {
    log_info "Initializing WARP daemon connection..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if warp-cli --accept-tos status >/dev/null 2>&1; then
            printf "\n"
            log_success "WARP daemon ready (${attempt}s)"
            return 0
        fi
        printf "\r${BLUE}[$(date '+%H:%M:%S')]${NC} ${CYAN}INFO${NC}  Waiting for daemon... %d/%d" "$attempt" "$max_attempts"
        sleep 1
        ((attempt++))
    done
    
    printf "\n"
    log_error "WARP daemon initialization timeout (${max_attempts}s)"
    return 1
}

# Function to register WARP
register_warp() {
    log_info "Checking WARP registration status..."
    
    # Check if registration file exists
    if [ -f "/register-warp" ]; then
        log_success "WARP registration found"
        log_info "Registration details:"
        while IFS= read -r line; do
            echo -e "\t\t\t\t  ${CYAN}│${NC} $line"
        done < /register-warp
        return 0
    fi
    
    log_warning "No registration found, creating new account..."
    
    # Try registration multiple times
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Registration attempt ${attempt}/${max_attempts}..."
        
        if warp-cli --accept-tos registration new > /var/log/warp-registration.log 2>&1; then
            log_success "WARP registration completed"
            # Save registration info
            echo "Registration completed at: $(date)" > /register-warp
            echo "Registration details:" >> /register-warp
            warp-cli --accept-tos account >> /register-warp 2>/dev/null || echo "Account info unavailable" >> /register-warp
            return 0
        else
            log_error "Registration attempt ${attempt} failed"
            # Show specific error from log
            if [ -f /var/log/warp-registration.log ]; then
                log_warning "Error details:"
                tail -3 /var/log/warp-registration.log | while IFS= read -r line; do
                    echo -e "  ${RED}│${NC} $line"
                done
            fi
            
            if [ $attempt -eq $max_attempts ]; then
                log_error "All registration attempts failed"
                return 1
            fi
            log_info "Retrying in 5 seconds..."
            sleep 5
        fi
        ((attempt++))
    done
}

# Function to connect WARP
connect_warp() {
    log_info "Establishing WARP connection..."
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Connection attempt ${attempt}/${max_attempts}..."
        
        if warp-cli --accept-tos connect > /var/log/warp-connect.log 2>&1; then
            log_success "WARP connection established"
            log_info "Stabilizing connection..."
            sleep 5
            
            # Show connection status
            if warp-cli --accept-tos status 2>/dev/null | grep -q "Connected"; then
                log_success "Connection verified and stable"
                # Show status details
                warp-cli --accept-tos status 2>/dev/null | while IFS= read -r line; do
                    echo -e "\t\t\t\t  ${GREEN}│${NC} $line"
                done
            fi
            return 0
        else
            log_error "Connection attempt ${attempt} failed"
            if [ $attempt -eq $max_attempts ]; then
                log_error "All connection attempts failed"
                if [ -f /var/log/warp-connect.log ]; then
                    log_warning "Connection log:"
                    cat /var/log/warp-connect.log | while IFS= read -r line; do
                        echo -e "  ${RED}│${NC} $line"
                    done
                fi
                return 1
            fi
            log_info "Retrying in 5 seconds..."
            sleep 5
        fi
        ((attempt++))
    done
}

# Main execution starts here
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                    ${YELLOW}WARP Proxy Service${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                   Starting up components...                  ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Kill any existing warp processes
log_info "Terminating existing WARP processes..."
pkill -f warp-svc 2>/dev/null || true
sleep 2
log_success "Process cleanup completed"

log_info "Starting WARP service daemon..."
# Start warp-svc in background
nohup warp-svc > /var/log/warp-svc.log 2>&1 &
WARP_SVC_PID=$!

# Check if warp-svc started successfully
sleep 3
if ! kill -0 $WARP_SVC_PID 2>/dev/null; then
    log_error "WARP service daemon failed to start"
    log_warning "Service log:"
    cat /var/log/warp-svc.log | while IFS= read -r line; do
        echo -e "  ${RED}│${NC} $line"
    done
    exit 1
fi

log_success "WARP service daemon started (PID: $WARP_SVC_PID)"

# Wait for daemon to be ready
if ! wait_for_warp_daemon; then
    log_error "Daemon initialization failed"
    log_warning "Service log:"
    cat /var/log/warp-svc.log | while IFS= read -r line; do
        echo -e "  ${RED}│${NC} $line"
    done
    exit 1
fi

# Register WARP
if ! register_warp; then
    log_error "WARP registration failed"
    exit 1
fi

# Connect to WARP
if ! connect_warp; then
    log_error "WARP connection failed"
    exit 1
fi

# echo ""
log_success "\e[1;32mWARP service initialization completed\e[0m"
# echo ""

# Initialize other services
log_info "Initializing proxy services..."
for i in {1..5}; do
    printf "\r${BLUE}[$(date '+%H:%M:%S')]${NC} ${CYAN}INFO${NC}  Service initialization... %d/5" "$i"
    sleep 1
done
printf "\n"
log_success "Service initialization completed"

# Start danted proxy
log_info "Starting SOCKS5 proxy server..."
if [ -f /etc/danted.conf ]; then
    danted -f /etc/danted.conf &
    DANTED_PID=$!
    log_success "SOCKS5 proxy started (PID: $DANTED_PID)"
else
    log_warning "SOCKS5 configuration not found, skipping proxy"
    DANTED_PID=""
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}                    ${YELLOW}All Services Running${NC}                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                  Monitoring system health...                 ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Monitor processes
MONITOR_CYCLE=0
check_connection=1
while true; do
    MONITOR_CYCLE=$((MONITOR_CYCLE + 1))

    if [ $((MONITOR_CYCLE % 60)) -eq 0 ]; then
        # Check if warp-svc is still running
        if ! kill -0 $WARP_SVC_PID 2>/dev/null; then
            log_warning "WARP service daemon stopped unexpectedly"
            log_info "Restarting WARP service daemon..."
            nohup warp-svc > /var/log/warp-svc.log 2>&1 &
            WARP_SVC_PID=$!
            sleep 5
            log_success "WARP service daemon restarted (PID: $WARP_SVC_PID)"
        fi
        
        # Check if danted is still running (if it was started)
        if [ -n "$DANTED_PID" ] && ! kill -0 $DANTED_PID 2>/dev/null; then
            log_warning "SOCKS5 proxy stopped unexpectedly"
            log_info "Restarting SOCKS5 proxy..."
            danted -f /etc/danted.conf &
            DANTED_PID=$!
            log_success "SOCKS5 proxy restarted (PID: $DANTED_PID)"
        fi
    fi
    if [ $((MONITOR_CYCLE % 5)) -eq 0 ]; then
        status_output=$(warp-cli --accept-tos status 2>/dev/null)
        if echo "$status_output" | grep -q "Status update: Connecting"; then
            if [ $check_connection -eq 1 ] ;then
                log_warning "WARP connection lost"
                log_info "Attempting to reconnect..."
                check_connection=0
            fi
        elif echo "$status_output" | grep -q "Status update: Connected"; then
            if [ $check_connection -eq 0 ] ;then
                check_connection=1
                log_success "WARP connection restored"
            elif [ $((MONITOR_CYCLE % 150)) -eq 0 ]; then
                log_info "System health check: OK"
            fi
        else
            log_error "Failed to restore WARP connection"
        fi
    fi
    
    sleep 1
done