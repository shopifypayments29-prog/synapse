#!/bin/sh
# SynapseChat Railway startup script
# This script: generates config → patches config → fixes DB → starts nginx → starts Synapse

# Redirect all output to stdout for Railway log collection
exec > /proc/1/fd/1 2>&1 || true

echo "=== SynapseChat Railway Startup ==="
echo "SERVER_NAME=${SERVER_NAME}"
echo "RAILWAY_STATIC_URL=${RAILWAY_STATIC_URL}"
echo "POSTGRES_HOST=${POSTGRES_HOST}"
echo "REDISHOST=${REDISHOST}"

CONFIG_PATH="/data/homeserver.yaml"

# Copy signing key and log config from build to persistent data volume
cp /synapsechat/synapsechat.up.railway.app.signing.key /data/ 2>/dev/null || true
cp /synapsechat/synapsechat.up.railway.app.log.config /data/ 2>/dev/null || true

# Step 1: Generate base config if it doesn't exist
if [ ! -f "$CONFIG_PATH" ]; then
    echo "Generating initial config via migrate_config..."
    python -m synapse.app.homeserver \
        --server-name "${SERVER_NAME:-synapsechat.up.railway.app}" \
        --generate-config \
        --config-path "$CONFIG_PATH" \
        --keys-directory /data \
        --report-stats no || true
    echo "Base config generated."
else
    echo "Config already exists, skipping generation."
fi

# Step 2: Fix media file paths
echo "Fixing media file paths to old format..."
python3 << 'FIXEOF'
import os, shutil
MEDIA_DIR = "/data/media/local_content"
if not os.path.isdir(MEDIA_DIR):
    print("No media directory found, skipping file fix.")
else:
    fixed = skipped = 0
    for dir1 in os.listdir(MEDIA_DIR):
        dir1_path = os.path.join(MEDIA_DIR, dir1)
        if not os.path.isdir(dir1_path) or len(dir1) != 2:
            continue
        for dir2 in os.listdir(dir1_path):
            dir2_path = os.path.join(dir1_path, dir2)
            if not os.path.isdir(dir2_path) or len(dir2) != 2:
                continue
            for filename in os.listdir(dir2_path):
                filepath = os.path.join(dir2_path, filename)
                if not os.path.isfile(filepath):
                    continue
                prefix = dir1 + dir2
                new_name = filename
                while new_name.startswith(prefix) and len(new_name) > 4:
                    new_name = new_name[len(prefix):]
                if new_name == filename:
                    skipped += 1
                    continue
                new_path = os.path.join(dir2_path, new_name)
                if os.path.exists(new_path) and new_path != filepath:
                    os.remove(filepath)
                    fixed += 1
                else:
                    shutil.move(filepath, new_path)
                    fixed += 1
    print(f"File fix: {fixed} files fixed, {skipped} files already in correct format.")
FIXEOF

# Step 3: Patch the config with Python
echo "Patching config with custom settings..."
python3 << 'PYEOF'
import yaml, os

config_path = "/data/homeserver.yaml"
with open(config_path, 'r') as f:
    config = yaml.safe_load(f)

# Database
if 'database' in config and isinstance(config['database'], dict):
    config['database']['allow_unsafe_locale'] = True
    if 'args' in config['database']:
        config['database']['args'].pop('allow_unsafe_locale', None)
        config['database']['args']['cp_min'] = 5
        config['database']['args']['cp_max'] = 20

# Redis
config['redis'] = {
    'enabled': True,
    'host': os.environ.get('REDISHOST', 'redis.railway.internal'),
    'port': int(os.environ.get('REDISPORT', '6379')),
    'password': os.environ.get('REDISPASSWORD', '')
}

# Registration
reg_enabled = os.environ.get('REGISTRATION_ENABLED', 'true').lower() == 'true'
config['enable_registration'] = reg_enabled
config['enable_registration_without_verification'] = reg_enabled

# E2E encryption by default
config['encryption_enabled_by_default_for_room_type'] = 'all'

# MSC3967 — skip UIAA for first cross-signing key upload
config.setdefault('experimental_features', {})
config['experimental_features']['msc3967_enabled'] = True

# Well-known client content
config.setdefault('extra_well_known_client_content', {})
config['extra_well_known_client_content']['io.element.e2ee'] = {'default': True}
config['extra_well_known_client_content']['org.matrix.msc4143.rtc_foci'] = [
    {'type': 'livekit', 'livekit_service_url': f'https://{os.environ.get("RAILWAY_SERVICE_LK_JWT_SERVICE_URL", "lk-jwt-service-production.up.railway.app")}'}
]
config['extra_well_known_client_content']['io.element.call'] = {
    'url': f'https://{os.environ.get("RAILWAY_SERVICE_ELEMENT_CALL_URL", "element-call-production-0707.up.railway.app")}',
    'participant_limit': 999, 'e2ee': True,
    'posthog': {'project_api_key': '', 'api_host': ''}
}

# MSC3266, MSC4222, MSC4140 for Element Call
config['experimental_features']['msc3266_enabled'] = True
config['experimental_features']['msc4222_enabled'] = True
config['max_event_delay_duration'] = '24h'

# Upload, room version, presence, user directory
config['max_upload_size'] = '100M'
config['default_room_version'] = '10'
config['presence'] = {'enabled': True}
config['user_directory'] = {'enabled': True, 'search_all_users': True}

# Enable federation so lk-jwt-service can verify OpenID tokens
config['federation_enabled'] = True

# Serve /.well-known/matrix/server (needed by lk-jwt-service)
config['serve_server_wellknown'] = True

# Disable authenticated media
config['enable_authenticated_media'] = False

# Rate limiting
config['rc_login'] = {
    'account': {'per_second': 0.17, 'burst_count': 3},
    'address': {'per_second': 0.17, 'burst_count': 3},
    'failed_attempts': {'per_second': 0.17, 'burst_count': 3}
}
config['rc_registration'] = {'per_second': 0.17, 'burst_count': 3}
config['rc_delayed_event_mgmt'] = {'per_second': 1, 'burst_count': 20}

# Auto-delete stale devices after 90 days of inactivity.
# This prevents phantom devices (no keys uploaded) from accumulating
# and causing "encryption failed — unsigned devices" errors.
config['delete_stale_devices_after'] = '90d'

# Server name and public baseurl
server_name = os.environ.get('SERVER_NAME', 'synapsechat.up.railway.app')
config['server_name'] = server_name
railway_url = os.environ.get('RAILWAY_STATIC_URL', '')
if railway_url:
    config['public_baseurl'] = f'https://{railway_url}'
else:
    config['public_baseurl'] = f'https://{server_name}'

# Media paths
config['media_store_path'] = '/data/media'
config['uploads_path'] = '/data/uploads'

# Listeners — Synapse on 8009, nginx proxies 8008
config['listeners'] = [{
    'port': 8009, 'tls': False, 'type': 'http', 'x_forwarded': True,
    'resources': [{'names': ['client', 'federation', 'media'], 'compress': False}]
}]

# Remove TLS
config.pop('tls_certificate_path', None)
config.pop('tls_private_key_path', None)

# No auto-join, suppress key server warning
config['auto_join_rooms'] = []
config['suppress_key_server_warning'] = True

# Log config and signing key
config['log_config'] = '/data/synapsechat.up.railway.app.log.config'
config['signing_key_path'] = '/data/synapsechat.up.railway.app.signing.key'

# CORS
origins = []
element_url = os.environ.get('RAILWAY_SERVICE_ELEMENT_WEB_URL', '')
if element_url:
    origins.append(f'https://{element_url}')
call_url = os.environ.get('RAILWAY_SERVICE_ELEMENT_CALL_URL', 'element-call-production-0707.up.railway.app')
if call_url:
    origins.append(f'https://{call_url}')
origins.append('https://appassets.androidplatform.net')
origins.append('http://localhost')
origins.append('http://localhost:8080')
if origins:
    config['access_control_allow_origin'] = origins

config['url_preview_enabled'] = False
config['dynamic_thumbnails'] = True

print("=== SynapseChat Config ===")
print(f"server_name: {config.get('server_name')}")
print(f"public_baseurl: {config.get('public_baseurl')}")
print(f"federation_enabled: {config.get('federation_enabled')}")
print(f"serve_server_wellknown: {config.get('serve_server_wellknown')}")
print(f"listeners: {config.get('listeners')}")
print(f"=== End Config ===")

with open(config_path, 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)
print("Config patched successfully.")
PYEOF

echo "=== Config patch complete ==="

# Step 4: Fix database records
echo "Fixing media database records..."
python3 << 'DBEOF'
import os, psycopg2
db_args = {
    'host': os.environ.get('POSTGRES_HOST', os.environ.get('PGHOST', 'postgres.railway.internal')),
    'port': int(os.environ.get('POSTGRES_PORT', os.environ.get('PGPORT', '5432'))),
    'database': os.environ.get('POSTGRES_DB', os.environ.get('PGDATABASE', 'railway')),
    'user': os.environ.get('POSTGRES_USER', os.environ.get('PGUSER', 'postgres')),
    'password': os.environ.get('POSTGRES_PASSWORD', os.environ.get('PGPASSWORD', '')),
}
server_name = os.environ.get('SERVER_NAME', 'synapsechat.up.railway.app')
try:
    conn = psycopg2.connect(**db_args)
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute('ALTER TABLE local_media_repository ADD COLUMN IF NOT EXISTS filesystem_id text')
    cur.execute('ALTER TABLE local_media_repository ADD COLUMN IF NOT EXISTS media_origin text')
    cur.execute('ALTER TABLE local_media_repository ADD COLUMN IF NOT EXISTS media_source jsonb')
    cur.execute('UPDATE local_media_repository SET authenticated = false WHERE authenticated = true OR authenticated IS NULL')
    auth = cur.rowcount
    cur.execute('UPDATE local_media_repository SET media_origin = %s WHERE media_origin IS NULL', (server_name,))
    orig = cur.rowcount
    cur.execute("UPDATE local_media_repository SET media_source = '{\"media_type\": \"local\"}'::jsonb WHERE media_source IS NULL")
    src = cur.rowcount
    print(f'Database fix: authenticated={auth}, media_origin={orig}, media_source={src}')

    # ONE-TIME: Clean up server-created cross-signing keys that have no
    # client-side private keys. These were created by a previous bootstrap
    # script but are unusable because Element doesn't have the private keys.
    # After this one-time cleanup, cross-signing is set up naturally by
    # each user through Element (MSC3967 skips UIAA for first setup).
    # DO NOT delete cross-signing keys on every restart — that would break
    # user-created cross-signing setups.
    try:
        cur.execute("SELECT COUNT(*) FROM e2e_cross_signing_keys")
        cs_count = cur.fetchone()[0]
        if cs_count > 0:
            # Only clean up if there are existing keys (one-time migration)
            # Check if any user_signing keys exist — if not, all keys were
            # created by the server bootstrap (not by clients), so they're unusable.
            # The usage field is inside a JSON column. Try different column names
            # since the schema varies across Synapse versions.
            us_count = 0
            for col_name in ['key_json', 'key_data', 'stream_json', 'key_json_bytes']:
                try:
                    cur.execute(f"SELECT COUNT(*) FROM e2e_cross_signing_keys WHERE {col_name}::text LIKE '%%user_signing%%'")
                    us_count = cur.fetchone()[0]
                    print(f'Found user_signing keys via column {col_name}: {us_count}')
                    break
                except Exception:
                    continue

            if us_count == 0:
                # No user_signing keys = server-created keys = unusable, clean them up
                cur.execute('DELETE FROM e2e_cross_signing_signatures')
                sig_rows = cur.rowcount
                cur.execute('DELETE FROM e2e_cross_signing_keys')
                key_rows = cur.rowcount
                print(f'One-time cross-signing cleanup: {key_rows} unusable keys, {sig_rows} signatures deleted (server-created, no client private keys)')
            else:
                print(f'Cross-signing keys exist with user_signing keys ({us_count}), skipping cleanup (client-created keys are valid)')
        else:
            print('No cross-signing keys to clean up')
    except Exception as e:
        print(f'Cross-signing check warning (may not exist yet): {e}')

    # Clean up phantom devices (devices with no last_seen timestamp).
    # These are created when a user starts a session but never completes login/crypto setup.
    # They cause "encryption failed — unsigned devices" errors because they have no keys.
    try:
        cur.execute("""
            DELETE FROM devices
            WHERE last_seen IS NULL
              AND user_id IN (SELECT name FROM users WHERE admin = 0)
        """)
        phantom_rows = cur.rowcount
        print(f'Phantom device cleanup: {phantom_rows} phantom devices deleted (no last_seen, non-admin users)')
    except Exception as e:
        print(f'Phantom device cleanup warning (may not exist yet): {e}')

    # Promote admin users and reset admin password
    admin_user = os.environ.get('SYNAPSE_ADMIN_USER', '')
    admin_pass = os.environ.get('SYNAPSE_ADMIN_PASS', '')
    if admin_user:
        cur.execute('UPDATE users SET admin = 1 WHERE name = %s', (admin_user,))
        admin_rows = cur.rowcount
        print(f'Admin promotion: {admin_user} -> {admin_rows} rows updated')
        full_id = f'@{admin_user}:{server_name}'
        cur.execute('UPDATE users SET admin = 1 WHERE name = %s', (full_id,))
        admin_rows2 = cur.rowcount
        print(f'Admin promotion: {full_id} -> {admin_rows2} rows updated')

        # Reset admin password to the configured value
        # This ensures the admin can always log in, even if a previous bootstrap
        # script changed the password temporarily
        if admin_pass:
            try:
                import bcrypt
                hashed = bcrypt.hashpw(admin_pass.encode('utf-8'), bcrypt.gensalt(rounds=12)).decode('utf-8')
                cur.execute('UPDATE users SET password_hash = %s WHERE name = %s', (hashed, admin_user))
                pw_rows = cur.rowcount
                full_id = f'@{admin_user}:{server_name}'
                cur.execute('UPDATE users SET password_hash = %s WHERE name = %s', (hashed, full_id))
                pw_rows2 = cur.rowcount
                print(f'Admin password reset: {admin_user} -> {pw_rows + pw_rows2} rows updated')
            except ImportError:
                print('WARNING: bcrypt not available, cannot reset admin password in database')
            except Exception as e:
                print(f'Admin password reset warning (non-fatal): {e}')
    else:
        print('No SYNAPSE_ADMIN_USER set, skipping admin promotion')

    cur.close()
    conn.close()
except Exception as e:
    print(f'Database fix warning (non-fatal): {e}')
DBEOF

echo "=== Database fix complete ==="

# Step 5: Start nginx (serving /.well-known/matrix/server and proxying to Synapse)
echo "=== Starting nginx (serving /.well-known/matrix/server) ==="
nginx
echo "=== nginx started ==="

# Step 7: Start Synapse in background so we can run bootstrap after it's ready
echo "=== Starting Synapse on port 8009 (nginx proxies 8008->8009) ==="
echo "=== Config path: $CONFIG_PATH ==="
ls -la "$CONFIG_PATH" 2>/dev/null || echo "WARNING: Config file not found at $CONFIG_PATH"
python -m synapse.app.homeserver --config-path "$CONFIG_PATH" &
SYNAPSE_PID=$!
echo "=== Synapse started (PID: $SYNAPSE_PID) ==="

# Step 8: Cross-signing is handled client-side through Element.
# MSC3967 is enabled (skip UIAA for first cross-signing key upload), so
# users can set up cross-signing without re-entering their password.
# Server-created cross-signing keys don't work because the client
# doesn't have the private keys — Element must create them.
# To set up cross-signing: Element → Settings → Security → Set up secure backup
echo "=== Cross-signing: handled client-side via Element (MSC3967 enabled) ==="
echo "=== Users should set up cross-signing in Element: Settings → Security ==="

# Step 9: Wait for Synapse (keep container running)
echo "=== SynapseChat is ready ==="
wait $SYNAPSE_PID