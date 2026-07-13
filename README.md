# Notch Hero

A tiny native macOS notch app prototype. It creates a transparent, always-on-top AppKit panel anchored to the top center of the active display, plus a small menu bar item for showing or quitting the app.

## Run

```sh
make run
```

The app runs as an accessory app, so it does not appear in the Dock. Use the sparkle icon in the menu bar to show the notch again or quit.

The Makefile points Swift at full Xcode by default. To use a different developer directory:

```sh
make run DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer
```

## Build

```sh
make build
```

For a release build:

```sh
make release
```

The release executable will be at:

```sh
.build/release/NotchHero
```

## What exists now

- Native AppKit app entry point
- Transparent, borderless top-center notch panel with proportions matched to the current screen's top bar
- Collapsed view with hero level, current token total, HP, and XP progress
- Expanded battle view with hero, monster, damage ticks, monster HP, token rate, and combat status
- Hover to expand into battle, then auto-collapse shortly after the pointer leaves
- Reads real local token usage from Claude Code and Codex JSONL logs when available
- Always-on-top behavior across Spaces and full-screen apps
- Menu bar controls for show and quit
- Animated pixel-style game HUD driven by local token usage events

## Token Usage

Notch Hero scans local JSONL logs every few seconds and only extracts timestamps plus token counters.

Current sources:

- Claude Code: `~/.claude/projects/**/*.jsonl`
- Codex: `~/.codex/sessions/YYYY/MM/DD/*.jsonl`

If no token events are found for the current day, the UI shows `NO DATA` instead of simulated usage.
