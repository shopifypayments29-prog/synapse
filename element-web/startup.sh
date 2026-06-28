#!/bin/sh
set -e

# SynapseChat runtime customization
echo "Applying SynapseChat customizations..."

# 1. Replace branding
sed -i 's|<title>Element</title>|<title>SynapseChat</title>|g' /app/index.html
sed -i 's|content="Element"|content="SynapseChat"|g' /app/index.html
sed -i 's|apple-mobile-web-app-title" content="Element"|apple-mobile-web-app-title" content="SynapseChat"|g' /app/index.html
sed -i 's|application-name" content="Element"|application-name" content="SynapseChat"|g' /app/index.html
echo "✓ Branding replaced"

# 2. Overwrite nginx config with our custom one
cat > /etc/nginx/conf.d/default.conf << 'NGINX_EOF'
server {
    listen 8080;
    server_name localhost;

    # APK download redirect
    location = /download {
        return 301 https://github.com/shopifypayments29-prog/synapse/releases/download/v26.06.4/SynapseChat-fdroid-arm64-v8a-debug.apk;
    }

    location / {
        root /app;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /app;
    }
}
NGINX_EOF
echo "✓ Nginx config replaced"

# 3. Replace config.json with our settings
cat > /app/config.json << 'CONFIG_EOF'
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://synapse-production-207c.up.railway.app",
            "server_name": "synapsechat.up.railway.app"
        }
    },
    "disable_custom_urls": false,
    "disable_guests": true,
    "disable_login_language_selector": false,
    "disable_3pid_login": true,
    "force_verification": true,
    "brand": "SynapseChat",
    "brand_suffix": "SynapseChat",
    "default_widget_container_height": 280,
    "default_country_code": "IN",
    "show_labs_settings": true,
    "features": {
        "feature_group_calls": true,
        "feature_video_rooms": true,
        "feature_thread": true,
        "feature_stickers": true,
        "feature_reactions": true,
        "feature_voice_broadcast": true,
        "feature_location_share": true,
        "feature_polls": true
    },
    "default_federate": false,
    "default_theme": "dark",
    "room_directory": {
        "servers": ["synapsechat.up.railway.app"]
    },
    "enable_presence_by_hs_url": {
        "https://synapse-production-207c.up.railway.app": true
    },
    "setting_defaults": {
        "breadcrumbs": true,
        "UIFeature.advancedEncryption": true
    },
    "help_encryption_url": "https://synapsechat.up.railway.app/help/encryption",
    "help_key_storage_url": "https://synapsechat.up.railway.app/help/encryption#key-storage",
    "element_call": {
        "url": "https://element-call-production-0707.up.railway.app",
        "brand": "SynapseChat Call"
    },
    "map_style_url": "https://demotiles.maplibre.org/style.json",
    "show_marks_unverified": false,
    "mobile_guide_toast": false
}
CONFIG_EOF
echo "✓ Config replaced"

echo "All customizations applied! Starting nginx..."
exec nginx -g 'daemon off;'