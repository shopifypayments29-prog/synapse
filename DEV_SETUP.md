# SynapseChat Development Setup

> Open-source Telegram-like messaging app built on Matrix/Element

## Prerequisites

- **Docker** 24+ and **Docker Compose** v2+
- **Git** 2.40+
- **Node.js** 20+ (for web client development)
- **Rust** 1.75+ (for matrix-rust-sdk and Tauri)
- **Android Studio** with SDK 34+ (for Android development)
- **Xcode** 15+ (for iOS development, macOS only)

## Quick Start

```bash
# 1. Clone the project
git clone https://github.com/synapsechat/synapsechat.git
cd synapsechat

# 2. Copy environment template
cp .env.example .env

# 3. Generate Synapse signing key and config
docker compose run --rm synapse generate

# 4. Start all services
docker compose up -d

# 5. Wait for Synapse to be healthy, then register test users
./scripts/register-test-users.sh
```

## Access Points

| Service | URL | Credentials |
|---------|-----|------------|
| Synapse API | http://localhost:8008 | - |
| Nginx Proxy | http://localhost:80 | - |
| MinIO Console | http://localhost:9001 | synapsechat / synapsechat_dev_password |
| Grafana | http://localhost:3000 | admin / synapsechat_dev |
| Prometheus | http://localhost:9090 | - |
| LiveKit | http://localhost:7880 | devkey / devsecret |

## Test Users

After running `./scripts/register-test-users.sh`:

| Username | Matrix ID | Password |
|----------|-----------|----------|
| synapsechat_admin | @synapsechat_admin:synapse.chat | admin_dev_password_123 |
| alice | @alice:synapse.chat | test_password_alice |
| bob | @bob:synapse.chat | test_password_bob |
| charlie | @charlie:synapse.chat | test_password_charlie |
| diana | @diana:synapse.chat | test_password_diana |
| eve | @eve:synapse.chat | test_password_eve |

## Repository Structure

```
synapsechat/
├── docker-compose.yml          # Development environment
├── .env.example                # Environment template
├── .gitignore
├── DEV_SETUP.md                # This file
├── CONTRIBUTING.md             # Contribution guidelines
├── SECURITY.md                 # Security policy
├── NOTICE                      # AGPL-3.0 compliance
├── docs/                       # Documentation
├── infra/
│   ├── synapse/                # Synapse homeserver config
│   │   ├── homeserver.yaml
│   │   └── log.config
│   ├── sygnal/                 # Push gateway config
│   │   └── sygnal.yaml
│   ├── livekit/                # Voice/video SFU config
│   │   └── livekit.yaml
│   ├── coturn/                 # TURN server config
│   │   └── turnserver.conf
│   ├── nginx/                  # Reverse proxy config
│   │   ├── nginx.conf
│   │   └── conf.d/
│   └── docker/
│       └── prometheus.yml
├── scripts/
│   └── register-test-users.sh
├── repos/                      # Forked repositories (git-managed)
│   ├── element-web/            # Web + Desktop client
│   ├── element-x-android/      # Android client
│   ├── element-x-ios/          # iOS client
│   ├── synapse/                # Homeserver
│   ├── sygnal/                 # Push gateway
│   ├── element-call/           # Voice/video calls
│   ├── matrix-rust-sdk/        # Shared crypto SDK
│   └── compound/               # Design system
└── .github/
    └── workflows/              # CI/CD
```

## Development Workflows

### Web Client Development

```bash
cd repos/element-web
yarn install
yarn start
# Opens at http://localhost:3000
# Point to your local Synapse at http://localhost:8008
```

### Android Development

```bash
cd repos/element-x-android
# Open in Android Studio
# Build variant: debug
# Point to local Synapse: change defaultHomeserverUrl in config
```

### iOS Development

```bash
cd repos/element-x-ios
# Open ElementX.xcodeproj in Xcode
# Change defaultHomeserverUrl in configuration
# Run on simulator
```

### Synapse Server Development

```bash
cd repos/synapse
# Create virtual environment
python -m venv .venv
source .venv/bin/activate
pip install -e ".[all]"
# Run with your config
python -m synapse.app.homeserver --config-path ../../infra/synapse/homeserver.yaml
```

## Syncing with Upstream

Each repository has an `upstream` remote pointing at the original Element/Matrix repo:

```bash
cd repos/element-web
git fetch upstream
git merge upstream/develop into synapsechat/develop
# Resolve conflicts, test, push
```

**Important:** Always merge upstream security patches promptly. Subscribe to:
- https://github.com/element-hq/synapse/security/advisories
- https://github.com/element-hq/element-web/security/advisories
- https://matrix.org/security-disclosure/

## Troubleshooting

### Synapse won't start
```bash
docker compose logs synapse
# Check: database connection, signing key, config syntax
```

### Database connection refused
```bash
docker compose logs postgres
# Ensure PostgreSQL is healthy: docker compose exec postgres pg_isready
```

### Port already in use
```bash
# Check what's using the port
lsof -i :8008
# Change ports in docker-compose.yml
```

### Reset everything
```bash
docker compose down -v  # WARNING: deletes all data
docker compose up -d    # Start fresh
./scripts/register-test-users.sh
```