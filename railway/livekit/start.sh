#!/bin/bash
set -euo pipefail

echo "=== LiveKit Railway Startup ==="

# ──────────────────────────────────────────────────────────────────────
# Railway networking: UDP is blocked. WebRTC ICE media can only flow
# through TCP. The Railway TCP proxy (hayabusa.proxy.rlwy.net:25787)
# forwards external TCP traffic to container port 7881.
#
# Problem: LiveKit's tcp_port is used for BOTH listening AND advertising
# in ICE candidates. The TCP proxy has different internal (7881) and
# external (25787) ports.
#
# Solution: LiveKit listens on the PROXY port (25787) internally.
# We set up iptables REDIRECT (or haproxy fallback) to forward
# traffic arriving on 7881 → 25787 so the TCP proxy works.
#
# The external ICE candidate will show: hayabusa.proxy.rlwy.net:25787
# which is exactly where the TCP proxy forwards to container:7881,
# and our redirect sends 7881 → 25787 where LiveKit is listening.
# ──────────────────────────────────────────────────────────────────────

TCP_PROXY_DOMAIN="${RAILWAY_TCP_PROXY_DOMAIN:-}"
TCP_PROXY_PORT="${RAILWAY_TCP_PROXY_PORT:-}"
TCP_APP_PORT="${RAILWAY_TCP_APPLICATION_PORT:-}"
SIGNAL_PORT="${PORT:-7880}"

# API keys (required)
API_KEY="${LIVEKIT_API_KEY:-}"
API_SECRET="${LIVEKIT_SECRET:-}"

if [ -z "$API_KEY" ] || [ -z "$API_SECRET" ]; then
  echo "ERROR: LIVEKIT_API_KEY and LIVEKIT_SECRET must be set"
  exit 1
fi

# ── Node IP and ICE TCP Port Configuration ──
NODE_IP="0.0.0.0"
ICE_TCP_PORT="7881"
USE_EXTERNAL_IP="false"
NODE_IP_MODE="${LIVEKIT_NODE_IP_MODE:-auto}"

if [ -n "$TCP_PROXY_PORT" ] && [ -n "$TCP_PROXY_DOMAIN" ] && [ -n "$TCP_APP_PORT" ]; then
  echo "TCP proxy: ${TCP_PROXY_DOMAIN}:${TCP_PROXY_PORT} → container:${TCP_APP_PORT}"

  if [ "$NODE_IP_MODE" = "auto" ]; then
    # Let LiveKit discover its external IP via STUN
    USE_EXTERNAL_IP="true"
    NODE_IP=""
    echo "Node IP mode: auto (use_external_ip=true)"
  else
    # Resolve proxy domain to IP for node_ip
    RESOLVED_IP=$(getent ahostsv4 "$TCP_PROXY_DOMAIN" 2>/dev/null | awk 'NR==1 {print $1}' || true)
    if [ -z "$RESOLVED_IP" ]; then
      RESOLVED_IP=$(getent hosts "$TCP_PROXY_DOMAIN" 2>/dev/null | awk '{print $1}' | head -1 || true)
    fi

    if [ -n "$RESOLVED_IP" ]; then
      NODE_IP="$RESOLVED_IP"
      echo "Resolved ${TCP_PROXY_DOMAIN} → ${NODE_IP}"
    else
      echo "WARNING: Could not resolve ${TCP_PROXY_DOMAIN}, falling back to auto discovery"
      USE_EXTERNAL_IP="true"
      NODE_IP=""
    fi
  fi

  # LiveKit listens on the PROXY's external port (25787) internally.
  # ICE candidates will advertise this port, which matches the TCP proxy.
  ICE_TCP_PORT="$TCP_PROXY_PORT"

  # Set up redirect: traffic arriving on APP_PORT (7881) → ICE_TCP_PORT (25787)
  if [ "$TCP_APP_PORT" != "$ICE_TCP_PORT" ]; then
    echo "Setting up redirect: ${TCP_APP_PORT} → ${ICE_TCP_PORT}"
    if iptables -t nat -A PREROUTING -p tcp --dport "${TCP_APP_PORT}" -j REDIRECT --to-port "${ICE_TCP_PORT}" 2>/dev/null; then
      echo "✓ iptables redirect configured"
    else
      echo "iptables redirect failed (no NET_ADMIN?), falling back to haproxy"
      cat > /tmp/haproxy.cfg <<HACFG
global
  log stdout format raw local0 info

defaults
  mode tcp
  timeout connect 5s
  timeout client 300s
  timeout server 300s
  log global
  option tcplog

listen ice_forwarder
  bind 0.0.0.0:${TCP_APP_PORT}
  server livekit 127.0.0.1:${ICE_TCP_PORT}
HACFG
      haproxy -f /tmp/haproxy.cfg -D
      echo "✓ haproxy started (forwarding ${TCP_APP_PORT} → ${ICE_TCP_PORT})"
    fi
  else
    echo "TCP application port matches proxy port; no forwarder needed"
  fi
else
  echo "No TCP proxy configured, using default tcp_port=7881"
fi

# ── Redis Configuration ──
REDIS_SECTION=""
if [ -n "${REDIS_URL:-}" ]; then
  REDIS_PASSWORD=$(echo "$REDIS_URL" | sed -n 's|redis://[^:]*:\([^@]*\)@.*|\1|p')
  REDIS_HOST_PORT=$(echo "$REDIS_URL" | sed -n 's|redis://[^@]*@\(.*\)|\1|p')
  if [ -n "$REDIS_HOST_PORT" ]; then
    echo "Redis: ${REDIS_HOST_PORT}"
    REDIS_SECTION="redis:
  address: ${REDIS_HOST_PORT}
  password: ${REDIS_PASSWORD}"
  fi
else
  echo "No REDIS_URL set, running in single-node mode"
fi

# ── Generate livekit.yaml ──
CONFIG=/etc/livekit.yaml

cat > "$CONFIG" <<YAML
port: ${SIGNAL_PORT}
bind_addresses:
  - "0.0.0.0"

rtc:
  tcp_port: ${ICE_TCP_PORT}
  port_range_start: 0
  port_range_end: 0
  use_external_ip: ${USE_EXTERNAL_IP}
  # Railway blocks ALL UDP traffic. force_tcp ensures only TCP candidates
  # are generated, so clients connect via the Railway TCP proxy.
  force_tcp: true
  # TURN servers for browsers that don't support ICE-TCP (e.g. Firefox).
  # Firefox requires TURNS (TLS) for TCP relay — ICE-TCP alone is not enough.
  # freeTURN.net provides free TURN/TURNS service (2Mbit/s limit).
  # Chrome uses ICE-TCP via the Railway proxy; Firefox uses TURNS via freeTURN.
  turn_servers:
    - host: freeturn.net
      port: 5349
      protocol: tls
      username: free
      credential: free
    - host: freeturn.net
      port: 3478
      protocol: tcp
      username: free
      credential: free
    - host: freeturn.net
      port: 3478
      protocol: udp
      username: free
      credential: free

room:
  auto_create: false
  enable_remote_unmute: true

logging:
  level: info

keys:
  ${API_KEY}: ${API_SECRET}
${REDIS_SECTION:+$REDIS_SECTION}
YAML

echo ""
echo "=== LiveKit Config ==="
cat "$CONFIG"
echo ""
echo "=== Starting LiveKit ==="
echo "  Signaling:    ${SIGNAL_PORT}"
echo "  ICE TCP:      ${ICE_TCP_PORT}"
echo "  Node IP mode: ${NODE_IP_MODE}"
echo "  Node IP:      ${NODE_IP:-auto}"
echo "  TCP proxy:    ${TCP_PROXY_DOMAIN:-none}:${TCP_PROXY_PORT:-none} → container:${TCP_APP_PORT:-none}"
echo ""

if [ -n "$NODE_IP" ]; then
  exec livekit-server --config "$CONFIG" --node-ip "$NODE_IP"
else
  exec livekit-server --config "$CONFIG"
fi