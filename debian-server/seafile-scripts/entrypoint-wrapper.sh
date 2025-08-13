#!/bin/bash

# Entrypoint wrapper that starts seafile and then launches seaf-fuse

# Start the seaf-fuse startup script in the background
/usr/local/bin/start-seaf-fuse.sh &

# Execute the original entrypoint
exec /sbin/my_init -- /scripts/enterpoint.sh
