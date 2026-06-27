#!/bin/bash
# SynapseChat - Register Test Users
# Run this after `docker compose up -d`
set -e

SYNAPSE_URL="http://localhost:8008"
ADMIN_USER="synapsechat_admin"
ADMIN_PASS="admin_dev_password_123"
REGISTER_URL="${SYNAPSE_URL}/_synapse/client/v1/register"

echo "🔐 SynapseChat Test User Registration"
echo "======================================="

# Wait for Synapse to be ready
echo "⏳ Waiting for Synapse to start..."
for i in $(seq 1 30); do
    if curl -sf "${SYNAPSE_URL}/health" > /dev/null 2>&1; then
        echo "✅ Synapse is ready!"
        break
    fi
    echo "  Attempt $i/30..."
    sleep 2
done

# Check if Synapse is actually up
if ! curl -sf "${SYNAPSE_URL}/health" > /dev/null 2>&1; then
    echo "❌ Synapse failed to start. Check logs: docker compose logs synapse"
    exit 1
fi

# Get admin registration token (shared secret)
SHARED_SECRET=$(grep -oP 'registration_shared_secret:\s*\K.*' /home/suraj/projects/synapsechat/infra/synapse/homeserver.yaml 2>/dev/null || echo "")

# Register admin user
echo ""
echo "👤 Registering admin user: ${ADMIN_USER}"
docker compose exec synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -u "${ADMIN_USER}" \
    -p "${ADMIN_PASS}" \
    -a 2>/dev/null || echo "  (Admin user may already exist)"

# Register test users
TEST_USERS=("alice" "bob" "charlie" "diana" "eve")
for user in "${TEST_USERS[@]}"; do
    echo "👤 Registering test user: ${user}"
    docker compose exec synapse register_new_matrix_user \
        -c /data/homeserver.yaml \
        -u "${user}" \
        -p "test_password_${user}" \
        2>/dev/null || echo "  (User ${user} may already exist)"
done

echo ""
echo "✅ Test users registered!"
echo ""
echo "📋 Registered users:"
echo "  Admin: @${ADMIN_USER}:synapse.chat / ${ADMIN_PASS}"
for user in "${TEST_USERS[@]}"; do
    echo "  User:  @${user}:synapse.chat / test_password_${user}"
done
echo ""
echo "🌐 Access the app at:"
echo "  Synapse API: http://localhost:8008"
echo "  Nginx proxy: http://localhost:80"
echo "  MinIO Console: http://localhost:9001 (synapsechat / synapsechat_dev_password)"
echo "  Grafana: http://localhost:3000 (admin / synapsechat_dev)"
echo "  Prometheus: http://localhost:9090"
echo ""
echo "🚀 Ready to connect clients! Point your Element/Web client to http://localhost:8008"