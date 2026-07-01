#!/bin/sh
set -e

echo "=== LiveKit Railway Startup ==="

# Generate config from environment
CONFIG=/etc/livekit.yaml

# Get Railway public domain
DOMAIN="${RAILWAY_STATIC_URL:-livekit-production-ef11.up.railway.app}"

# Try to resolve the domain to an IP address
NODE_IP=""
for attempt in 1 2 3 4 5; do
    NODE_IP=$(getent hosts "${DOMAIN}" 2>/dev/null | head -1 | awk '{print $1}' || true)
    if [ -n "$NODE_IP" ]; then
        echo "Resolved ${DOMAIN} -> ${NODE_IP}"
        break
    fi
    echo "Attempt $attempt: Could not resolve ${DOMAIN}, retrying in 2s..."
    sleep 2
done

if [ -z "$NODE_IP" ]; then
    echo "WARNING: Could not resolve ${DOMAIN}, using use_external_ip=true with STUN"
    USE_EXTERNAL_IP="true"
else
    echo "Using node_ip: ${NODE_IP}"
    USE_EXTERNAL_IP="false"
fi

# Generate config
cat > "$CONFIG" << YAML
port: 7880
rtc:
  use_external_ip: ${USE_EXTERNAL_IP}
YAML

if [ -n "$NODE_IP" ]; then
    echo "  node_ip: ${NODE_IP}" >> "$CONFIG"
fi

cat >> "$CONFIG" << YAML
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  turn_servers:
    - host: freeturn.net
      port: 3478
      protocol: udp
      username: free
      credential: free
    - host: freeturn.net
      port: 3478
      protocol: tcp
      username: free
      credential: free
    - host: freeturn.net
      port: 5349
      protocol: tls
      username: free
      credential: free
room:
  auto_create: false
  enable_remote_unmute: true
logging:
  level: info
YAML

echo "=== LiveKit Config ==="
cat "$CONFIG"
echo "=== Starting LiveKit ==="
exec /livekit-server --config "$CONFIG"