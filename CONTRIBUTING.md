# Contributing to CC Pocket

Thanks for your interest in contributing! Here's how to get started.

## Getting started

### Prerequisites

- [Node.js](https://nodejs.org/) >= 18
- [Flutter](https://flutter.dev/) (Dart SDK ^3.11.0)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) or [Codex CLI](https://github.com/openai/codex) (for testing sessions)

### Setup

```bash
git clone https://github.com/K9i-0/ccpocket.git
cd ccpocket
npm install
cd apps/mobile && flutter pub get && cd ../..
```

### Common commands

| Command | Description |
|---------|-------------|
| `npm run bridge` | Run Bridge Server in dev mode |
| `npm run bridge:build` | Build Bridge Server |
| `npm run test:bridge` | Run Bridge Server tests |
| `npm run test:bridge:coverage` | Run tests with coverage |
| `cd apps/mobile && flutter test` | Run Flutter tests |
| `cd apps/mobile && dart analyze` | Run Dart static analysis |

## Making changes

1. Fork the repository and create a branch from `main`
2. Make your changes
3. Add tests for new functionality
4. Ensure all tests pass
5. Open a pull request

## Code style

- **Bridge Server (TypeScript)**: Follows the existing project conventions. Run tests with `npm run test:bridge` before submitting.
- **Mobile App (Flutter/Dart)**: Run `dart analyze` to check for issues.

## Reporting bugs

Please use the [bug report template](https://github.com/K9i-0/ccpocket/issues/new?template=bug_report.yml) when filing bugs.

## Suggesting features

Please use the [feature request template](https://github.com/K9i-0/ccpocket/issues/new?template=feature_request.yml) for feature ideas.
