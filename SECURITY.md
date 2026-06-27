# Security Policy

## Supported Versions

| Version | Supported |
|--------|-----------|
| Latest release | ✅ |
| Previous major | ✅ (security fixes only) |
| Older versions | ❌ |

## Reporting a Vulnerability

**Do NOT report security vulnerabilities through public GitHub issues.**

Instead, report them through one of these channels:

### Option 1: Encrypted Email (Preferred)

Send an encrypted email to: security@synapse.chat

Our PGP key fingerprint: `[TO BE ADDED]`

### Option 2: GitHub Security Advisory

Create a private security advisory at:
https://github.com/synapsechat/synapse/security/advisories/new

### What to Include

1. **Description** of the vulnerability
2. **Steps to reproduce** (with curl commands if applicable)
3. **Impact assessment** (what an attacker could do)
4. **Suggested fix** (if you have one)
5. **Your contact information** for follow-up

## Response Timeline

| Stage | Target Time |
|-------|-------------|
| Acknowledgment | 24 hours |
| Initial assessment | 72 hours |
| Fix development | 7 days (critical), 30 days (high/medium) |
| Fix deployment | 48 hours after development |
| Public disclosure | 90 days or after fix is deployed |

## Bug Bounty

We are evaluating a bug bounty program. Follow this repository for announcements.

## Security Architecture

### E2E Encryption

- All messages use **Megolm/Double Ratchet** encryption (audited)
- The `matrix-sdk-crypto` and `vodozemac` Rust crates are used **as-is** — never modify them
- Key verification via emoji comparison is mandatory during onboarding
- Cross-signing is required for multi-device support
- Key backup uses AES-256-GCM with user-provided passphrase

### Server Security

- Federation is **disabled by default** (single-server mode like Telegram)
- Rate limiting on all authentication endpoints
- TLS 1.3 only in production
- Admin API restricted to localhost
- Media scanning with ClamAV
- Strict CSP headers (nonce-based, no `unsafe-inline`)

### Client Security

- Certificate pinning on mobile (Android KeyStore + iOS Secure Enclave)
- Biometric unlock after 15 minutes of inactivity
- Screenshot protection in E2EE rooms (`FLAG_SECURE` on Android)
- No plaintext keys or messages in logs

### Known Attack Vectors

| Vector | Mitigation |
|--------|-----------|
| MITM key substitution | Emoji verification, cross-signing |
| Server compromise | E2EE ensures server cannot read messages |
| Metadata leakage | Server sees who messages whom (inherent to server-mediated model) |
| Sybil attacks | Phone verification, rate limits |
| Key backup server access | Backups encrypted with user passphrase before upload |

## Security Update Process

1. Monitor upstream security advisories:
   - https://github.com/element-hq/synapse/security/advisories
   - https://github.com/element-hq/element-web/security/advisories
   - https://matrix.org/security-disclosure/
2. Merge upstream security patches within **48 hours**
3. Build and deploy updated images
4. Notify users via in-app notification and Matrix room