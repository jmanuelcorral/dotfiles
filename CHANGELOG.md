# Changelog

All notable changes to this dotfiles repository are documented here.

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html). The root `VERSION` file is the single source of truth for the current version.

## [1.0.0] - 2026-06-02

### Added
- Cross-platform bootstrap installers for Windows PowerShell and Unix/WSL/macOS shells.
- Idempotent package orchestration for modern CLI tools, shell aliases, prompt setup, fonts, and profile stubs.
- `dotfiles` CLI helper with help, tool listing, registration, update, edit, offline explain, and local agent setup paths.
- Shared registries for aliases and tools under `shared/`.
- Self-bootstrap support for one-line installs via `irm ... | iex` and `curl ... | bash`.

### Changed
- Established `VERSION` as the repository version source of truth.
