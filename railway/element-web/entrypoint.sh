#!/bin/sh
set -e

# SynapseChat customizations applied at runtime
# This avoids Railway Docker build cache issues

echo "=== SynapseChat: Applying customizations ==="

# 1. Replace config.json
cp /app/custom-config.json /app/config.json
echo "✓ Config replaced"

# 2. Replace nginx config
cp /app/custom-nginx.conf /etc/nginx/conf.d/default.conf
echo "✓ Nginx config replaced"

# 3. Replace branding in index.html
sed -i 's|<title>Element</title>|<title>SynapseChat</title>|g' /app/index.html
sed -i 's|content="Element"|content="SynapseChat"|g' /app/index.html
sed -i 's|apple-mobile-web-app-title" content="Element"|apple-mobile-web-app-title" content="SynapseChat"|g' /app/index.html
sed -i 's|application-name" content="Element"|application-name" content="SynapseChat"|g' /app/index.html
echo "✓ Branding replaced"

# 4. Replace mobile guide page
cp /app/custom-mobile-guide.html /app/mobile_guide/index.html
echo "✓ Mobile guide replaced"

echo "=== SynapseChat: Customizations complete ==="

# Start nginx (original entrypoint)
exec nginx -g 'daemon off;'