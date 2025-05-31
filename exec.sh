#!/bin/bash

# Force unbuffered output for better log visibility
exec > >(stdbuf -o0 cat)
exec 2> >(stdbuf -o0 cat >&2)

# Function to handle signals
cleanup() {
    echo "Shutting down services..."
    pkill -f warp-svc
    pkill -f danted
    exit 0
}
trap cleanup SIGTERM SIGINT

echo "Starting warp-svc..."
nohup warp-svc > /var/log/warp-svc.log 2>&1 &
sleep 3
echo "Checking WARP registration..."
if [ ! -f "/warp-registered" ]; then
    echo "WARP not registered yet. Registering new account..."
    
    # Try registration and capture output
    if warp-cli --accept-tos registration new > /var/log/warp-registration.log 2>&1; then
        echo "WARP registration successful"
        # Save registration info with timestamp
        echo "Registration completed at: $(date)" > /warp-registered
        echo "Registration details:" >> /warp-registered
        warp-cli account >> /warp-registered 2>/dev/null || echo "Could not get account info" >> /warp-registered
    else
        echo "ERROR: WARP registration failed"
        echo "Check registration log:"
        cat /var/log/warp-registration.log
        exit 1
    fi
else
    echo "WARP already registered"
    echo "Registration info:"
    cat /warp-registered
fi

sleep 3

echo "Connecting warp-cli..."
warp-cli --accept-tos connect

echo "Initializing services..."
for i in {1..5}; do
    printf "Service initialization step: %d/5\n" "$i"
    sleep 1
done
echo "Services initialization completed successfully!"

echo "Starting danted proxy..."
danted -f /etc/danted.conf &
DANTED_PID=$!

echo "All services started. Monitoring processes..."

# Monitor processes instead of tail
while kill -0 $DANTED_PID 2>/dev/null; do
    sleep 30
done

echo "Main process died, exiting..."