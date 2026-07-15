# Vibe Hero — Documentation

Vibe Hero is a tiny native macOS app that turns the MacBook notch into a pixel-art RPG.
Your real Claude Code / Codex token usage becomes the hero's attacks: every token you
generate strikes the monster of the moment. Stop coding and the monster counterattacks.

> Vibe Hero lives entirely in the notch. It runs as an accessory app (no Dock icon),
> stays on top across Spaces and full-screen apps, and reads only local JSONL logs.

---

## Screenshots

### Collapsed notch

The resting state — a slim pill hugging the notch. Shows hero level, today's token total,
HP, and the XP progress bar. Hover the notch to expand.

<p align="center">
  <img src="images/collapsed.png" alt="Collapsed notch pill showing hero level, tokens, HP and XP" width="400">
</p>

### Expanded battle HUD

Hover the notch and the panel expands into the battle scene: hero vs. monster, floating
damage ticks, monster HP, token rate, skill energy bar, and combat status. It auto-collapses
shortly after the pointer leaves.

<p align="center">
  <img src="images/battle.png" alt="Expanded battle HUD with hero, monster, damage ticks and skill energy" width="720">
</p>

### Settings

Click the gear button in the expanded HUD to open settings: role, language, display
(screen pinning), the skill tree, and Token Hooks.

<p align="center">
  <img src="images/settings.png" alt="Vibe Hero settings window with role, language, display, skills and token hooks" width="560">
</p>

---

## How it works

```
local JSONL logs  ──►  TokenUsageScanner  ──►  token delta  ──►  hero attack on monster
        │                                                       (real usage = real damage)
        └─ no new tokens for a while ──► monster counterattacks the hero
```

1. **Scan.** Every few seconds `TokenUsageScanner` reads today's token counts from local
   Claude Code, Codex, and hook-fallback logs (timestamps + token counters only).
2. **Strike.** Each new batch of tokens triggers a hero attack whose damage scales with the
   token delta, the selected role's multiplier, learned skills, and any active Power Boost.
3. **Idle risk.** When no new token usage is detected for too long, the monster
   counterattacks and drains the hero's HP — coding literally keeps you alive.
4. **Reward.** Defeating a monster grants XP (level up → skill points) and rolls loot.
   If no real usage data exists for today, the HUD shows `NO DATA` instead of simulating.

---

## Hero roles

Pick a role in Settings to get a thematic perk. Roles tune active (token-driven) and idle
(monster-counterattack) damage.

| Role      | Perk                          |
|-----------|-------------------------------|
| PM        | Token strike damage +4%       |
| Designer  | (baseline)                    |
| Artist    | Idle damage −18%              |
| Engineer  | Token strike damage +15%      |
| QA        | Idle damage −25%              |
| Other     | (baseline)                    |

---

## Monsters

A rotating roster of token-waste creatures. Each has its own HP, XP reward, pixel form,
and death/respawn shards.

| Monster         | HP  | XP reward |
|-----------------|-----|-----------|
| Prompt Wraith   | 120 | 45        |
| Cache Golem     | 170 | 65        |
| Token Slime     | 95  | 35        |
| Null Sentinel   | 145 | 55        |

---

## Skills

A tiered skill tree unlocked by hero level. Spend skill points to rank up skills; some skills
can be set to auto-cast once learned. Skills consume skill energy (built from token usage) and
respect cast cooldowns.

| Skill           | Tier | Unlocks at LV | Max rank | Prereqs                          | Effect per rank                          |
|-----------------|------|---------------|----------|----------------------------------|------------------------------------------|
| Pulse Blade     | 1    | 1             | 3        | —                                | +5% strike damage                        |
| Token Volley    | 2    | 2             | 3        | Pulse Blade R1                   | +1 projectile                            |
| Arc Burst       | 3    | 3             | 3        | Token Volley R1                  | +1 chain arc                             |
| Wraith Mark     | 3    | 3             | 3        | Pulse Blade R2                   | +6% burst damage                         |
| Nova Storm      | 4    | 5             | 2        | Arc Burst R2, Wraith Mark R1     | Unlocks nova waves and orbit sparks      |
| Overclock Core  | 5    | 7             | 2        | Nova Storm R1, Token Volley R2   | Faster sustained attacks, larger impacts |

---

## Items & loot

Each defeated monster rolls a loot drop.

| Drop          | Chance | Effect                                                       |
|---------------|--------|--------------------------------------------------------------|
| Health Potion | 28%    | Restore 18–32 HP                                             |
| Power Boost   | 20%    | +25% damage for 60 seconds                                   |
| Gold          | 34%    | +6–18 gold (persisted across launches)                       |
| (nothing)     | 18%    | —                                                            |

Gold is persisted in `UserDefaults` and accumulates across sessions.

---

## Leveling & XP

Hero level is derived from total XP. The early level curve:

`120 · 260 · 450 · 700 · 1000 · 1360 · 1780 · 2260 · 2800 · 3400 · 4060 · 4780`

…then `+820` per level beyond the table. Each level-up grants a skill point to spend in the
skill tree. XP and level are persisted, so progress survives restarts.

---

## Settings

Open from the gear button in the expanded HUD.

- **Role** — choose your hero role and perk.
- **Language** — English, 简体中文, 日本語 (English is the fallback).
- **Display** — pin the notch to a specific screen (useful for multi-display setups); defaults
  to the main screen.
- **Skill tree** — spend points, rank up skills, toggle auto-cast.
- **Token Hooks** — install faster event hooks (see below).

All settings persist via `UserDefaults`.

---

## Token data sources & privacy

Vibe Hero scans local JSONL logs every few seconds and extracts **only timestamps and token
counters**. No prompt content, no completions, nothing leaves your machine.

Current sources:

| Source       | Path                                                |
|--------------|-----------------------------------------------------|
| Claude Code  | `~/.claude/projects/**/*.jsonl`                     |
| Codex        | `~/.codex/sessions/YYYY/MM/DD/*.jsonl`              |
| Codex (arch) | `~/.codex/archived_sessions/**/*.jsonl`             |
| Hook fallback| `~/.vibe-hero/token-events.jsonl`                   |

If no token events are found for the current day, the UI shows `NO DATA` instead of
simulated usage.

### Token Hooks

Local logs can lag a few seconds behind real usage. Open **Settings → Token Hooks** to install
faster event hooks that write to the fallback log and fill in when local logs are delayed:

- **Claude Code** — appends hooks to `~/.claude/settings.json`
- **Codex** — appends hooks to `~/.codex/hooks.json` and enables `codex_hooks`
- **OpenCode** — installs a plugin under `~/.config/opencode/plugins`

---

## Build & run

```sh
make run      # run the app
make dev      # run with auto-restart on source changes
make build    # debug build
make release  # release build → .build/release/NotchHero
make app      # build Vibe Hero.app → .build/app/Vibe Hero.app
make install  # install to /Applications
```

The app runs as an accessory app, so it does not appear in the Dock. Use the sparkle icon in
the menu bar to show the notch again or quit.

The Makefile points Swift at full Xcode by default. To use a different developer directory:

```sh
make run DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer
```

Requires macOS 14.0+.

---

## Architecture

Pure Swift + AppKit, no third-party dependencies, built with the Swift Package Manager.

| File                      | Responsibility                                                       |
|---------------------------|----------------------------------------------------------------------|
| `main.swift`              | AppKit entry point.                                                  |
| `AppDelegate.swift`       | Accessory-app lifecycle, menu bar item, screen/language observers.  |
| `NotchWindow.swift`       | Transparent, borderless, always-on-top panel anchored to the notch. |
| `NotchContentView.swift`  | Collapsed + expanded HUD, combat loop, XP/level, roles, pinning.     |
| `GameViews.swift`         | Pixel actors, battle scene, monster roster, bars, damage ticks.      |
| `SkillSystem.swift`       | Skill definitions, tree tiers, prerequisites, energy/cooldowns.     |
| `ItemSystem.swift`        | Loot table, gold, Power Boost buff.                                  |
| `TokenUsage.swift`        | Scans local JSONL logs into a token snapshot.                        |
| `TokenHookInstaller.swift`| Installs/removes token event hooks for Claude/Codex/OpenCode.        |
| `NotchSettingsWindow.swift`| Role, language, display, skill tree, Token Hooks UI.                |
| `Localization.swift`      | i18n layer (English / 简体中文 / 日本語).                            |

### Project conventions

- All user-facing text goes through the i18n layer in `Localization.swift`.
- English is the fallback. Add translations for all three languages when adding or changing
  any label, menu item, HUD status text, combat text, or empty/error state.
