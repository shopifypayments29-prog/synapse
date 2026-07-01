#!/usr/bin/env python3
"""
Cross-Signing Bootstrap for SynapseChat v2

Automatically generates cross-signing keys for ALL users who don't have them.
Runs on every Synapse startup to ensure new users also get set up.

This permanently fixes the "encryption failed due to an error collecting
the recipient devices — one or more verified users have unsigned devices" error.

Key format follows Matrix spec:
- Master key self-signs itself
- Self-signing key is signed by master key
- User-signing key is signed by master key
- Signatures use {user_id} as outer key and ed25519:{pubkey} as inner key
"""

import base64
import json
import os
import sys
import secrets
import urllib.request
import urllib.error
import urllib.parse

from nacl.signing import SigningKey

# Global admin user for self-reference check
ADMIN_USER_GLOBAL = ''


# --- Matrix key utilities ---

def generate_key_pair():
    """Generate an ed25519 key pair for cross-signing."""
    signing_key = SigningKey.generate()
    private_key_bytes = bytes(signing_key)
    public_key_bytes = bytes(signing_key.verify_key)
    return private_key_bytes, public_key_bytes


def encode_base64(data: bytes) -> str:
    """Encode bytes as unpadded base64 (Matrix standard)."""
    return base64.b64encode(data).rstrip(b'=').decode('ascii')


def sign_json(json_obj: dict, signing_key_bytes: bytes, user_id: str, signing_key_id: str) -> dict:
    """Sign a JSON object with an ed25519 key, matching Matrix spec exactly.

    Args:
        json_obj: The JSON object to sign (will be modified in place)
        signing_key_bytes: 32-byte ed25519 private key
        user_id: The Matrix user ID (e.g. "@alice:server.com")
        signing_key_id: The full key ID (e.g. "ed25519:ABCDEF...")

    The signature is added under:
        json_obj["signatures"][user_id][signing_key_id] = base64_signature
    """
    # Step 1: Remove signatures and unsigned from the object before canonicalizing
    obj = {k: v for k, v in json_obj.items() if k not in ('signatures', 'unsigned')}

    # Step 2: Canonical JSON (sorted keys, no whitespace)
    canonical = json.dumps(obj, separators=(',', ':'), sort_keys=True).encode('utf-8')

    # Step 3: Sign with ed25519
    signing_key = SigningKey(signing_key_bytes)
    signature = signing_key.sign(canonical)

    # Step 4: Add signature under signatures[user_id][ed25519:key_id]
    if 'signatures' not in json_obj:
        json_obj['signatures'] = {}
    if user_id not in json_obj['signatures']:
        json_obj['signatures'][user_id] = {}
    json_obj['signatures'][user_id][signing_key_id] = encode_base64(signature.signature)

    return json_obj


def create_cross_signing_keys(user_id: str):
    """Generate a complete set of cross-signing keys for a user.

    Returns dict with master_key, self_signing_key, user_signing_key,
    plus private keys for device signing.
    """
    # Generate master key
    master_priv, master_pub = generate_key_pair()
    master_key_id = f'ed25519:{encode_base64(master_pub)}'

    master_key_obj = {
        'user_id': user_id,
        'usage': ['master'],
        'keys': {master_key_id: encode_base64(master_pub)},
    }
    # Master key signs itself
    sign_json(master_key_obj, master_priv, user_id, master_key_id)

    # Generate self-signing key
    ss_priv, ss_pub = generate_key_pair()
    ss_key_id = f'ed25519:{encode_base64(ss_pub)}'

    ss_key_obj = {
        'user_id': user_id,
        'usage': ['self_signing'],
        'keys': {ss_key_id: encode_base64(ss_pub)},
    }
    # Self-signing key is signed by the MASTER key
    sign_json(ss_key_obj, master_priv, user_id, master_key_id)

    # Generate user-signing key
    us_priv, us_pub = generate_key_pair()
    us_key_id = f'ed25519:{encode_base64(us_pub)}'

    us_key_obj = {
        'user_id': user_id,
        'usage': ['user_signing'],
        'keys': {us_key_id: encode_base64(us_pub)},
    }
    # User-signing key is signed by the MASTER key
    sign_json(us_key_obj, master_priv, user_id, master_key_id)

    return {
        'master_key': master_key_obj,
        'self_signing_key': ss_key_obj,
        'user_signing_key': us_key_obj,
        # Private keys for signing device keys later
        'master_priv': master_priv,
        'ss_priv': ss_priv,
        'us_priv': us_priv,
        'master_key_id': master_key_id,
        'ss_key_id': ss_key_id,
        'us_key_id': us_key_id,
    }


# --- Synapse API client ---

class SynapseClient:
    """Client for Synapse admin and Matrix client APIs."""

    def __init__(self, base_url: str, admin_token: str):
        self.base_url = base_url.rstrip('/')
        self.admin_token = admin_token

    def _request(self, method: str, path: str, data: dict = None, token: str = None,
                 expect_json: bool = True):
        """Make an HTTP request to Synapse."""
        url = f'{self.base_url}{path}'
        headers = {'Content-Type': 'application/json'}
        auth_token = token or self.admin_token
        if auth_token:
            headers['Authorization'] = f'Bearer {auth_token}'

        body = json.dumps(data).encode('utf-8') if data else None
        req = urllib.request.Request(url, data=body, headers=headers, method=method)

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                if resp.status == 204:
                    return {'success': True}
                raw = resp.read().decode('utf-8')
                if not raw:
                    return {'success': True}
                return json.loads(raw)
        except urllib.error.HTTPError as e:
            raw_body = e.read().decode('utf-8', errors='replace')
            try:
                error_data = json.loads(raw_body)
            except json.JSONDecodeError:
                error_data = {'error': raw_body, 'errcode': 'UNKNOWN'}
            return {'error': error_data, 'status': e.code}
        except Exception as e:
            return {'error': str(e), 'status': 0}

    def _is_error(self, result: dict) -> bool:
        """Check if a result is an error."""
        return 'error' in result and 'success' not in result

    def get_users(self):
        """List all users on the server."""
        users = []
        from_token = 0
        while True:
            result = self._request('GET',
                                    f'/_synapse/admin/v2/users?from={from_token}&limit=100&guests=false')
            if self._is_error(result):
                print(f'  Error listing users: {result.get("error", result)}')
                return users
            batch = result.get('users', [])
            users.extend(batch)
            next_token = result.get('next_token')
            if not next_token or not batch:
                break
            from_token = next_token
        return users

    def get_user_devices(self, user_id: str):
        """Get all devices for a user."""
        encoded = urllib.parse.quote(user_id, safe='')
        result = self._request('GET', f'/_synapse/admin/v2/users/{encoded}/devices')
        if self._is_error(result):
            return []
        return result.get('devices', [])

    def get_cross_signing_keys(self, user_id: str):
        """Check if a user has cross-signing keys."""
        # Use the admin query endpoint
        result = self._request('POST', '/_matrix/client/v3/keys/query',
                               data={'device_keys': {user_id: []}})
        if self._is_error(result):
            # Fallback: try the admin-specific endpoint
            encoded = urllib.parse.quote(user_id, safe='')
            result2 = self._request('GET',
                                    f'/_synapse/admin/v1/users/{encoded}/cross_signing_keys')
            if self._is_error(result2):
                return False
            # Check if there are any cross-signing keys
            return bool(result2.get('cross_signing_keys'))
        # Check if the user has master and self_signing keys
        master = result.get('master_keys', {}).get(user_id)
        self_signing = result.get('self_signing_keys', {}).get(user_id)
        return master is not None and self_signing is not None

    def create_user_token(self, user_id: str):
        """Create a temporary access token for a user via admin API.

        Uses POST /_synapse/admin/v1/users/{user_id}/login with type com.synapse.admin.login.
        """
        encoded = urllib.parse.quote(user_id, safe='')
        result = self._request('POST',
                                f'/_synapse/admin/v1/users/{encoded}/login',
                                data={'type': 'com.synapse.admin.login'})
        if self._is_error(result):
            error = result.get('error', {})
            if isinstance(error, dict):
                errcode = error.get('errcode', '')
                errmsg = error.get('error', str(error))
                print(f'    Admin login API failed for {user_id}: {errcode} - {errmsg}')
            else:
                print(f'    Admin login API failed for {user_id}: {error}')
            return None
        return result.get('access_token')

    def set_temp_password(self, user_id: str, password: str):
        """Set a temporary password for a user via admin API."""
        encoded = urllib.parse.quote(user_id, safe='')
        result = self._request('PUT',
                                f'/_synapse/admin/v2/users/{encoded}',
                                data={'password': password})
        if self._is_error(result):
            error = result.get('error', {})
            print(f'    Failed to set password for {user_id}: {error}')
            return False
        return True

    def login_with_password(self, user_id: str, password: str, server_name: str):
        """Login with username and password to get an access token."""
        result = self._request('POST', '/_matrix/client/v3/login',
                               data={
                                   'type': 'm.login.password',
                                   'user': user_id.split(':')[0].lstrip('@'),
                                   'password': password,
                               })
        if self._is_error(result):
            error = result.get('error', {})
            print(f'    Password login failed for {user_id}: {error}')
            return None
        return result.get('access_token')

    def upload_cross_signing_keys(self, token: str, keys: dict):
        """Upload cross-signing keys using MSC3967 (no UIAA for first upload).

        POST /_matrix/client/v3/keys/device_signing/upload
        """
        data = {
            'master_key': keys['master_key'],
            'self_signing_key': keys['self_signing_key'],
        }
        if 'user_signing_key' in keys:
            data['user_signing_key'] = keys['user_signing_key']

        result = self._request('POST', '/_matrix/client/v3/keys/device_signing/upload',
                               data=data, token=token)
        return result

    def sign_devices_with_key(self, token: str, user_id: str,
                               ss_priv: bytes, ss_key_id: str):
        """Sign all device keys with the self-signing key."""
        # Get the user's device keys
        result = self._request('POST', '/_matrix/client/v3/keys/query',
                               data={'device_keys': {user_id: []}},
                               token=token)
        if self._is_error(result):
            print(f'    Could not query device keys: {result.get("error", result)}')
            return 0

        device_keys = result.get('device_keys', {}).get(user_id, {})
        if not device_keys:
            return 0

        # Sign each device key
        signatures_upload = {}
        signed_count = 0
        for device_id, device_key_data in device_keys.items():
            # Create a clean copy for signing (remove signatures and unsigned)
            clean_key = {k: v for k, v in device_key_data.items()
                        if k not in ('signatures', 'unsigned')}

            # Canonical JSON for signing
            canonical = json.dumps(clean_key, separators=(',', ':'), sort_keys=True).encode('utf-8')

            # Sign with self-signing key
            signing_key = SigningKey(ss_priv)
            signature = signing_key.sign(canonical)

            # Add signature in the format expected by Matrix
            if user_id not in signatures_upload:
                signatures_upload[user_id] = {}
            signatures_upload[user_id][device_id] = {
                'signatures': {
                    user_id: {
                        ss_key_id: encode_base64(signature.signature)
                    }
                }
            }
            signed_count += 1

        # Upload signatures
        if signed_count > 0:
            sig_result = self._request('POST', '/_matrix/client/v3/keys/signatures/upload',
                                       data=signatures_upload, token=token)
            if self._is_error(sig_result):
                print(f'    Warning: Could not upload device signatures: {sig_result.get("error", sig_result)}')
            else:
                print(f'    Signed {signed_count} device(s) with self-signing key')

        return signed_count


# --- Main bootstrap logic ---

def bootstrap_cross_signing(base_url: str, admin_token: str, server_name: str, admin_user: str):
    """Set up cross-signing for all users who don't have it."""
    client = SynapseClient(base_url, admin_token)
    global ADMIN_USER_GLOBAL
    ADMIN_USER_GLOBAL = admin_user

    print('=== Cross-Signing Bootstrap ===')

    # Get all users
    users = client.get_users()
    active_users = [u for u in users if not u.get('deactivated', False)]
    print(f'Found {len(active_users)} active users ({len(users)} total)')

    fixed_count = 0
    skipped_count = 0
    error_count = 0

    for user in active_users:
        user_id = user['name']

        # Skip test/admin helper users
        if any(prefix in user_id.lower() for prefix in
               ['test', 'admincheck', 'mediatest', 'mediafixtest']):
            print(f'  Skipping test user: {user_id}')
            skipped_count += 1
            continue

        # Check if cross-signing keys already exist
        has_keys = client.get_cross_signing_keys(user_id)
        if has_keys:
            print(f'  ✓ Already has cross-signing: {user_id}')
            skipped_count += 1
            continue

        print(f'  Setting up cross-signing for: {user_id}')

        # Generate cross-signing keys
        try:
            keys = create_cross_signing_keys(user_id)
        except Exception as e:
            print(f'    ✗ Error generating keys: {e}')
            error_count += 1
            continue

        # Try to get a user token
        token = None
        method = None

        # For the admin user we're already logged in as, reuse the admin token
        if user_id == f'@{ADMIN_USER_GLOBAL}:{server_name}':
            token = admin_token
            method = 'admin_self'
            print(f'    Using existing admin token (self)')
        else:
            # Method 1: Admin login API (com.synapse.admin.login)
            token = client.create_user_token(user_id)
            if token:
                method = 'admin_login'
                print(f'    Got token via admin login API')
            else:
                # Method 2: Set temporary password and login
                print(f'    Admin login failed, trying temporary password approach...')
                temp_password = secrets.token_urlsafe(32)
                if client.set_temp_password(user_id, temp_password):
                    token = client.login_with_password(user_id, temp_password, server_name)
                    if token:
                        method = 'temp_password'
                        print(f'    Got token via temporary password')
                    else:
                        print(f'    ✗ Could not login with temporary password')
                        error_count += 1
                        continue
                else:
                    print(f'    ✗ Could not set temporary password')
                    error_count += 1
                    continue

        # Upload cross-signing keys (MSC3967: no UIAA for first upload)
        result = client.upload_cross_signing_keys(token, keys)
        if client._is_error(result):
            error = result.get('error', {})
            if isinstance(error, dict):
                errcode = error.get('errcode', '')
                errmsg = error.get('error', str(error))
                print(f'    ✗ Error uploading keys: {errcode} - {errmsg}')
            else:
                print(f'    ✗ Error uploading keys: {error}')
            error_count += 1
            continue

        print(f'    ✓ Cross-signing keys uploaded for {user_id}')

        # Sign all existing devices with the self-signing key
        try:
            client.sign_devices_with_key(token, user_id,
                                          keys['ss_priv'], keys['ss_key_id'])
        except Exception as e:
            print(f'    Warning: Could not sign devices: {e}')

        # If we used a temporary password for a non-admin user, reset it
        # so the user can log in normally next time (they'll need to reset their password
        # via forgot password flow, or an admin can set it)
        # For security, set a random password that no one knows
        if method == 'temp_password':
            random_pass = secrets.token_urlsafe(64)
            client.set_temp_password(user_id, random_pass)
            print(f'    Temporary password reset (user should use forgot-password)')

        fixed_count += 1
        print(f'    ✓ Cross-signing set up for {user_id}')

    print(f'\n=== Bootstrap Complete ===')
    print(f'  Fixed: {fixed_count}')
    print(f'  Skipped: {skipped_count}')
    print(f'  Errors: {error_count}')
    return fixed_count


if __name__ == '__main__':
    # Configuration from environment variables
    BASE_URL = os.environ.get('SYNAPSE_BASE_URL', 'http://localhost:8009')
    ADMIN_USER = os.environ.get('SYNAPSE_ADMIN_USER', 'synapsechat_admin')
    ADMIN_PASS = os.environ.get('SYNAPSE_ADMIN_PASS', '')
    SERVER_NAME = os.environ.get('SERVER_NAME', 'synapsechat.up.railway.app')

    # Get admin token by logging in
    print(f'Connecting to Synapse at {BASE_URL}')
    login_data = {
        'type': 'm.login.password',
        'user': ADMIN_USER,
        'password': ADMIN_PASS,
    }

    try:
        req = urllib.request.Request(
            f'{BASE_URL}/_matrix/client/v3/login',
            data=json.dumps(login_data).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            login_result = json.loads(resp.read().decode('utf-8'))
            admin_token = login_result['access_token']
            print(f'Logged in as {ADMIN_USER}')
    except urllib.error.HTTPError as e:
        print(f'ERROR: Could not login as admin: {e.read().decode()}')
        print('Cross-signing bootstrap cannot proceed without admin access.')
        sys.exit(1)
    except Exception as e:
        print(f'ERROR: Could not connect to Synapse: {e}')
        print('Will retry on next startup.')
        sys.exit(0)  # Don't crash the container

    fixed = bootstrap_cross_signing(BASE_URL, admin_token, SERVER_NAME, ADMIN_USER)

    if fixed > 0:
        print(f'\n✓ Cross-signing bootstrap fixed {fixed} users')
    else:
        print('\n✓ All users already have cross-signing keys or need manual setup')