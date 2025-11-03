#!/bin/bash

# Seafile FUSE Auto-Start Script
# This script waits for seafile to be healthy and then launches seaf-fuse

MOUNT_POINT="/seafile-fuse"
LOG_FILE="/opt/seafile/logs/seaf-fuse-startup.log"
MAX_WAIT=120  # Maximum wait time in seconds
WAIT_INTERVAL=2  # Check interval in seconds
HEALTH_ENDPOINT="http://localhost/api2/server-info/"

function log() {
    local time=$(date +"%F %T")
    echo "[$time] $1" | tee -a "$LOG_FILE"
}

log "Starting seaf-fuse auto-start script..."

# Wait for seafile HTTP endpoint to be healthy
elapsed=0
while [ $elapsed -lt $MAX_WAIT ]; do
    if curl -f -s "$HEALTH_ENDPOINT" > /dev/null 2>&1; then
        log "Seafile is healthy and responding on $HEALTH_ENDPOINT"
        break
    fi
    log "Waiting for seafile to be healthy... (${elapsed}s/${MAX_WAIT}s)"
    sleep $WAIT_INTERVAL
    elapsed=$((elapsed + WAIT_INTERVAL))
done

if [ $elapsed -ge $MAX_WAIT ]; then
    log "ERROR: Seafile did not become healthy within ${MAX_WAIT} seconds"
    exit 1
fi

# Give seafile a moment to fully initialize after health check passes
log "Waiting 3 seconds for seafile to fully stabilize..."
sleep 3

# Check if seaf-fuse is already running (check for the actual binary, not scripts)
if pgrep -x "seaf-fuse" > /dev/null 2>&1; then
    log "seaf-fuse is already running"
    exit 0
fi

# Clean up any stale PID files
if [ -f /opt/seafile/pids/seaf-fuse.pid ]; then
    log "Removing stale seaf-fuse.pid file"
    rm -f /opt/seafile/pids/seaf-fuse.pid
fi

# Start seaf-fuse
log "Starting seaf-fuse with mount point: $MOUNT_POINT"
cd /opt/seafile/seafile-server-latest

# Execute seaf-fuse.sh start command with allow_other option
./seaf-fuse.sh start -o allow_other "$MOUNT_POINT" >> "$LOG_FILE" 2>&1
start_result=$?

# Check if seaf-fuse started successfully
sleep 2
if pgrep -x "seaf-fuse" > /dev/null 2>&1; then
    log "seaf-fuse started successfully"
    log "Mount point $MOUNT_POINT is now accessible"
else
    log "ERROR: Failed to start seaf-fuse (exit code: $start_result)"
    log "Check /opt/seafile/logs/seaf-fuse.log for details"
    exit 1
fi

log "seaf-fuse auto-start completed successfully"
exit 0
