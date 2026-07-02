#!/bin/sh
set -e

echo "=== LiveKit Railway Startup ==="

# Generate config from environment
CONFIG=/etc/livekit.yaml

# Railway TCP proxy endpoint (created via: railway tcp-proxy create --port 7881)
# This is the public-facing TCP endpoint for WebRTC ICE-TCP connections.
TCP_PROXY_HOST="hayabusa.proxy.rlwy.net"
TCP_PROXY_PORT="25787"

# Get Railway public domain for WebSocket connections
DOMAIN="${RAILWAY_STATIC_URL:-livekit-production-ef11.up.railway.app}"

# Resolve the domain to get our public IP for ICE candidates
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

# Generate LiveKit config
# IMPORTANT: On Railway, UDP port ranges (50000-60000) are NOT exposed.
# We use ICE-TCP only via the Railway TCP proxy (hayabusa.proxy.rlwy.net:25787)
# which forwards to our port 7881. This ensures WebRTC connections work.
cat > "$CONFIG" << YAML
port: 7880
rtc:
  use_external_ip: ${USE_EXTERNAL_IP}
YAML

if [ -n "$NODE_IP" ]; then
    echo "  node_ip: ${NODE_IP}" >> "$CONFIG"
fi

cat >> "$CONFIG" << YAML
  # Force TCP transport for ICE — UDP doesn't work on Railway
  # because Railway only exposes HTTP/HTTPS and TCP proxies, not UDP port ranges.
  # Clients will connect via ICE-TCP through the TCP proxy.
  tcp_port: 7881
  # Advertise the Railway TCP proxy as the ICE-TCP candidate
  # so clients connect through the proxy instead of trying direct UDP.
  ice_servers:
    - urls:
        - "turn:hayabusa.proxy.rlwy.net:25787?transport=tcp"
      username: "synapsechat"
      credential: "synapsechat"
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