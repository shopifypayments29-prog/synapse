#!/bin/sh
set -e

echo "=== LiveKit Egress Railway Startup ==="

# Generate egress config from environment variables
CONFIG=/etc/egress.yaml

LIVEKIT_HOST="${LIVEKIT_HOST:-http://livekit.railway.internal:7880}"
LIVEKIT_API_KEY="${LIVEKIT_API_KEY:-API3C8Q3C8Q3C8Q}"
LIVEKIT_API_SECRET="${LIVEKIT_API_SECRET:-381a4334b088529a74895de1ec9d4588bd4c7f}"
REDIS_HOST="${REDISHOST:-redis.railway.internal}"
REDIS_PORT="${REDISPORT:-6379}"
REDIS_PASSWORD="${REDISPASSWORD:-}"

cat > "$CONFIG" << YAML
# LiveKit Egress Configuration
api_key: ${LIVEKIT_API_KEY}
api_secret: ${LIVEKIT_API_SECRET}

# LiveKit server connection
rpc:
  server_address: ${LIVEKIT_HOST}
  rtc:
    tcp_port: 7881

# Redis for job coordination
redis:
  address: ${REDIS_HOST}:${REDIS_PORT}
YAML

if [ -n "$REDIS_PASSWORD" ]; then
    echo "  password: ${REDIS_PASSWORD}" >> "$CONFIG"
fi

# Add S3-compatible storage if configured
if [ -n "$EGRESS_S3_BUCKET" ]; then
    cat >> "$CONFIG" << YAML

# S3-compatible storage for recordings
s3:
  bucket: ${EGRESS_S3_BUCKET}
  region: ${EGRESS_S3_REGION:-auto}
YAML
    if [ -n "$EGRESS_S3_ENDPOINT" ]; then
        echo "  endpoint: ${EGRESS_S3_ENDPOINT}" >> "$CONFIG"
    fi
    if [ -n "$EGRESS_S3_ACCESS_KEY" ]; then
        echo "  access_key: ${EGRESS_S3_ACCESS_KEY}" >> "$CONFIG"
    fi
    if [ -n "$EGRESS_S3_SECRET_KEY" ]; then
        echo "  secret_key: ${EGRESS_S3_SECRET_KEY}" >> "$CONFIG"
    fi
fi

echo "=== Egress Config ==="
cat "$CONFIG"
echo "=== Starting LiveKit Egress ==="
exec /egress --config "$CONFIG"