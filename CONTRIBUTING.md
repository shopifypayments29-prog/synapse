# Contributing to SynapseChat

Thank you for your interest in contributing to SynapseChat! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Report security vulnerabilities through our responsible disclosure process (see SECURITY.md)

## Development Setup

See [DEV_SETUP.md](./DEV_SETUP.md) for complete development environment setup instructions.

## Branching Strategy

- `main` — Production-ready code
- `develop` — Integration branch for features
- `synapsechat/develop` — Our customizations on top of upstream
- `feature/<name>` — Individual feature branches
- `fix/<name>` — Bug fix branches
- `security/<name>` — Security fix branches (private)

### Syncing with Upstream

Each forked repository has an `upstream` remote. Regularly merge upstream changes:

```bash
git fetch upstream
git checkout synapsechat/develop
git merge upstream/develop
# Resolve conflicts, test, push
```

**CRITICAL:** Merge upstream security patches within 48 hours of publication.

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <description>

<optional body>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`, `security`

Examples:
- `feat: add phone number registration`
- `fix: resolve message bubble alignment on RTL layouts`
- `security: update matrix-sdk-crypto to v0.7.3`

## Pull Request Process

1. Create a feature branch from `synapsechat/develop`
2. Make your changes with clear, focused commits
3. Add tests for new functionality (80%+ coverage target)
4. Run the test suite: `yarn test` (web), `./gradlew test` (Android), `swift test` (iOS)
5. Submit a PR against `synapsechat/develop`
6. Request review from a maintainer
7. Address review feedback
8. Ensure CI passes before merging

## Code Review Checklist

- [ ] Code is readable and well-named
- [ ] Functions are focused (<50 lines)
- [ ] No hardcoded secrets or credentials
- [ ] Error handling is explicit
- [ ] Tests exist for new functionality
- [ ] No mutation where immutable patterns apply
- [ ] Security-sensitive code is flagged for security review

## Security

See [SECURITY.md](./SECURITY.md) for our security policy and vulnerability reporting process.

## License

SynapseChat is licensed under AGPL-3.0-or-later. All contributions are licensed under the same terms. By submitting a PR, you agree that your code will be licensed under AGPL-3.0-or-later.

Original code from Element/Matrix projects retains their respective copyright notices (see NOTICE file).