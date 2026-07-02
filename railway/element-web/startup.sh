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
        return 301 https://github.com/shopifypayments29-prog/synapse/releases/download/v26.07.03/SynapseChat-v9.apk;
    }

    # Version JSON for in-app update checks
    location = /version.json {
        root /app;
        default_type application/json;
        add_header Access-Control-Allow-Origin '*' always;
        add_header Cache-Control 'no-cache, no-store, must-revalidate' always;
        try_files $uri =404;
    }

    # Custom mobile download page
    location /mobile_guide/ {
        root /app;
        index index.html;
        try_files $uri $uri/ /mobile_guide/index.html;
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
            "base_url": "https://synapsechat.up.railway.app",
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
        "feature_element_call_video_rooms": true,
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
        "https://synapsechat.up.railway.app": true
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
    "integrations_ui_url": "https://scalar.vector.im/",
    "integrations_rest_url": "https://scalar.vector.im/api",
    "widget_base_urls": ["https://neoboard.element.io"],
    "map_style_url": "https://demotiles.maplibre.org/style.json",
    "show_marks_unverified": true,
    "mobile_guide_toast": false,
    "push": {
        "gateway_url": "https://ntfy-push-production.up.railway.app/_matrix/push/v1/notify"
    }
}
CONFIG_EOF
echo "✓ Config replaced"

# 4. Replace mobile guide page with our custom download page
mkdir -p /app/mobile_guide
cat > /app/mobile_guide/index.html << 'HTML_EOF'
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Download SynapseChat</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #0dbd8b 0%, #0a9e73 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #ffffff;
        }
        .container {
            max-width: 480px;
            width: 100%;
            padding: 40px 24px;
            text-align: center;
        }
        .logo {
            font-size: 42px;
            font-weight: 700;
            margin-bottom: 8px;
            letter-spacing: -0.5px;
        }
        .subtitle {
            font-size: 17px;
            opacity: 0.9;
            margin-bottom: 36px;
            line-height: 1.5;
        }
        .step {
            background: rgba(255,255,255,0.15);
            border-radius: 16px;
            padding: 24px;
            margin-bottom: 20px;
            text-align: left;
        }
        .step-number {
            display: inline-block;
            background: #ffffff;
            color: #0dbd8b;
            width: 32px;
            height: 32px;
            border-radius: 50%;
            text-align: center;
            line-height: 32px;
            font-weight: 700;
            font-size: 16px;
            margin-bottom: 10px;
        }
        .step h3 {
            font-size: 17px;
            margin-bottom: 6px;
        }
        .step p {
            font-size: 14px;
            opacity: 0.85;
            line-height: 1.5;
        }
        .download-btn {
            display: inline-block;
            background: #ffffff;
            color: #0dbd8b;
            text-decoration: none;
            padding: 18px 36px;
            border-radius: 14px;
            font-size: 19px;
            font-weight: 700;
            transition: transform 0.2s, box-shadow 0.2s;
            box-shadow: 0 4px 16px rgba(0,0,0,0.2);
            margin: 28px 0;
        }
        .download-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 24px rgba(0,0,0,0.25);
        }
        .download-btn:active {
            transform: translateY(0);
        }
        .size-info {
            font-size: 13px;
            opacity: 0.7;
            margin-bottom: 28px;
        }
        .features {
            text-align: left;
            background: rgba(255,255,255,0.1);
            border-radius: 14px;
            padding: 20px 24px;
            margin-top: 8px;
        }
        .features h3 {
            margin-bottom: 12px;
            font-size: 16px;
        }
        .features ul {
            list-style: none;
            padding: 0;
        }
        .features li {
            padding: 5px 0;
            font-size: 14px;
            opacity: 0.9;
        }
        .features li::before {
            content: "✓ ";
            font-weight: bold;
        }
        .info {
            margin-top: 24px;
            font-size: 13px;
            opacity: 0.7;
            line-height: 1.6;
        }
        .desktop-link {
            margin-top: 20px;
            display: inline-block;
            color: #ffffff;
            opacity: 0.7;
            text-decoration: underline;
            font-size: 14px;
        }
        .desktop-link:hover {
            opacity: 1;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">💬 SynapseChat</div>
        <p class="subtitle">Your fully self-hosted, private messaging app.</p>

        <div class="step">
            <div class="step-number">1</div>
            <h3>Download SynapseChat</h3>
            <p>Tap the button below to download the APK for Android.</p>
        </div>

        <a href="https://github.com/shopifypayments29-prog/synapse/releases/download/v26.07.03/SynapseChat-v9.apk" class="download-btn">
            ⬇️ Download SynapseChat APK (v26.07.03)
        </a>

        <p class="size-info">APK size: ~155 MB · arm64-v8a · Android 7.0+</p>

        <p class="info" style="margin-top:8px;color:#ffe066;font-weight:600;">
            ⚠️ If you installed a previous version, uninstall it first before installing this one.
        </p>

        <div class="step">
            <div class="step-number">2</div>
            <h3>Install ntfy for Push Notifications</h3>
            <p>Install the <strong>ntfy</strong> app from <a href="https://play.google.com/store/apps/details?id=io.heckel.ntfy" style="color:#fff;text-decoration:underline;">Google Play</a> or <a href="https://f-droid.org/en/packages/io.heckel.ntfy/" style="color:#fff;text-decoration:underline;">F-Droid</a>. Open it, tap <strong>+</strong>, subscribe to <code style="background:rgba(255,255,255,0.2);padding:2px 6px;border-radius:4px;">synapsechat-<em>your-username</em></code>, then in SynapseChat go to Settings → Notifications → Push and enable push notifications.</p>
        </div>

        <div class="step">
            <div class="step-number">3</div>
            <h3>Sign in to SynapseChat</h3>
            <p>Open SynapseChat and sign in with your account, or create a new one.</p>
        </div>

        <div class="features">
            <h3>Why SynapseChat?</h3>
            <ul>
                <li>End-to-end encrypted messaging</li>
                <li>Fully self-hosted — your data, your rules</li>
                <li>Group video &amp; voice calls</li>
                <li>No tracking, no ads, no analytics</li>
                <li>Open source (AGPL-3.0)</li>
            </ul>
        </div>

        <p class="info">
            After downloading, you may need to enable "Install from unknown sources"<br>
            in your Android settings.
        </p>

        <a href="/" class="desktop-link">← Use the desktop web version instead</a>
    </div>
</body>
</html>
HTML_EOF
echo "✓ Mobile guide replaced"

# 5. Inject TDZ error recovery patch into index.html
# Element Web v1.12.22 has a bug where the Markdown renderer triggers
# "ReferenceError: can't access lexical declaration 'X' before initialization"
# during initial load (GitHub issue #30025). This patch catches that specific
# error and recovers by reloading the page once, preventing the persistent
# "Something went wrong" dialog.
echo "Patching index.html with TDZ error recovery..."
sed -i '/<\/head>/i\
<script>\
(function(){\
  var reloaded = sessionStorage.getItem("synapsechat_tdz_recovery");\
  window.addEventListener("error", function(e){\
    if(e.error && e.error instanceof ReferenceError && e.error.message.indexOf("lexical declaration")!==-1){\
      if(reloaded){\
        console.warn("SynapseChat: TDZ error persists after reload, suppressing");\
        e.preventDefault();\
        return true;\
      }\
      console.warn("SynapseChat: TDZ error detected, reloading page for recovery");\
      sessionStorage.setItem("synapsechat_tdz_recovery","1");\
      location.reload();\
      return true;\
    }\
  });\
  if(reloaded){\
    sessionStorage.removeItem("synapsechat_tdz_recovery");\
  }\
})();\
</script>' /app/index.html
echo "✓ TDZ recovery patch injected"

echo "All customizations applied! Starting nginx..."
exec nginx -g 'daemon off;'