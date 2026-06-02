# Switch Versioning Decision

**Date:** 2026-06-02
**Author:** Switch
**Status:** Proposed

## Decision

Use a root `VERSION` file containing one SemVer value as the single source of truth for the dotfiles version. Keep human-readable release notes in root `CHANGELOG.md` using Keep a Changelog-style headings.

## Rationale

This keeps version lookup shell-agnostic, works before any package tooling is installed, and avoids coupling the repo to tags, package managers, or a release tool.

## Update behavior

`dotfiles update` in both PowerShell and bash/zsh captures the current version, runs `git pull --ff-only`, reads the new version, prints `dotfiles: vOLD → vNEW` or `dotfiles: vNEW (already up to date)`, prints the new changelog section when available, and reruns the platform installer idempotently so new bootstrap changes are applied.
