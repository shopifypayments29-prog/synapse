# SynapseChat

> Open-source, cross-platform messaging app — a Telegram alternative built on Matrix/Element

[![CI](https://github.com/synapsechat/synapsechat/actions/workflows/ci.yml/badge.svg)](https://github.com/synapsechat/synapsechat/actions/workflows/ci.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL%203.0-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Matrix](https://img.shields.io/matrix/synapsechat:matrix.org)](https://matrix.to/#/#synapsechat:matrix.org)

## Features

- ✅ **E2E Encryption** — Audited Megolm/Double Ratchet protocol, on by default
- ✅ **1:1 & Group Chat** — Unlimited groups with threads, reactions, replies
- ✅ **Channels** — Public broadcast rooms with admin-only posting
- ✅ **Voice & Video Calls** — E2EE group calls via LiveKit/Element Call
- ✅ **File Sharing** — Up to 100MB, with drag-and-drop and progress bars
- ✅ **Bots** — Matrix Application Service framework for bot development
- ✅ **Stickers & Emoji** — Lottie animated stickers, custom emoji
- ✅ **Cross-Platform** — Web, Android, iOS, Desktop (Tauri)
- ✅ **Self-Hosted** — Run your own server with full data sovereignty
- ✅ **Open Source** — AGPL-3.0, all code publicly available

## Quick Start

```bash
# Clone the project
git clone https://github.com/synapsechat/synapsechat.git
cd synapsechat

# Copy environment template
cp .env.example .env

# Start all services
docker compose up -d

# Register test users
./scripts/register-test-users.sh
```

See [DEV_SETUP.md](./DEV_SETUP.md) for complete setup instructions.

## Architecture

```
Cloudflare (CDN/DDoS) → Traefik/Nginx (Reverse Proxy)
  → Synapse (Homeserver) → PostgreSQL
  → Sygnal (Push Gateway) → APNs/FCM
  → LiveKit (SFU) → coturn (TURN)
  → Redis (PubSub) → MinIO/S3 (Media)
  → Prometheus + Grafana (Monitoring)
```

## Repository Structure

| Directory | Purpose |
|-----------|---------|
| `infra/` | Docker configs for Synapse, Sygnal, LiveKit, coturn, Nginx |
| `repos/` | Forked Element/Matrix repositories |
| `scripts/` | Development and deployment scripts |
| `docs/` | Documentation |
| `.github/` | CI/CD workflows |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Server | Synapse (Python) |
| Database | PostgreSQL 16 |
| Cache | Redis 7 |
| Media Storage | S3-compatible (MinIO dev, Cloudflare R2 prod) |
| Push | Sygnal (APNs + FCM) |
| Voice/Video | LiveKit + Element Call |
| TURN | coturn |
| Proxy | Nginx / Traefik |
| Web Client | Element Web (React + TypeScript) |
| Android | Element X Android (Kotlin + Compose) |
| iOS | Element X iOS (Swift + SwiftUI) |
| Desktop | Tauri (Rust + Web) |
| Design | Compound design system |
| Monitoring | Prometheus + Grafana |

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines.

## Security

See [SECURITY.md](./SECURITY.md) for our security policy and vulnerability reporting process.

## License

SynapseChat is licensed under the [GNU Affero General Public License v3.0](./LICENSE).

This project incorporates code from Element/Matrix projects. See [NOTICE](./NOTICE) for third-party software attribution.

## Links

- 🌐 Website: [synapse.chat](https://synapse.chat) (coming soon)
- 💬 Matrix room: [#synapsechat:matrix.org](https://matrix.to/#/#synapsechat:matrix.org)
- 📖 Documentation: [docs.synapse.chat](https://docs.synapse.chat) (coming soon)
- 🐛 Bug reports: [GitHub Issues](https://github.com/synapsechat/synapsechat/issues)