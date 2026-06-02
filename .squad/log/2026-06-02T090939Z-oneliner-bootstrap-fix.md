# Session Log: One-Liner Bootstrap Fix

**Timestamp:** 2026-06-02T090939Z  
**Title:** One-Liner Installer Bootstrap and Push Account Management

## Summary

Coordinated fix for one-liner installers (`iex` and `bash` piped invocations) to self-bootstrap when `$PSScriptRoot` and `BASH_SOURCE` are empty. Both switch and tank agents completed verification successfully. New decision (Decision 6) added to squad decisions log capturing bootstrap strategy and git account management.

## Changes

- ✅ `bootstrap/install.ps1` — Self-bootstrap block added
- ✅ `bootstrap/install.sh` — Self-bootstrap block added
- ✅ `README.md` — Git prerequisite notes added (EN+ES)
- ✅ `.squad/decisions.md` — Decision 6 added
- ✅ `.squad/orchestration-log/` — Agent logs created

## Issues Resolved

- Piped installers no longer fail on empty `$PSScriptRoot`/`BASH_SOURCE`
- 403 auth error workaround documented (use `gh auth switch --user jmanuelcorral`)

## Status

**COMPLETE**
