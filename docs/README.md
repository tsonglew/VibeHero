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

1. **Scan.** On launch `TokenUsageScanner` reads today's token counts from local
   Claude Code, Codex, and hook-fallback logs (timestamps + token counters only), then
   keeps tailing only newly appended lines every few seconds.
2. **Strike.** Each new batch of tokens triggers a hero attack whose damage scales with the
   token delta, the selected role's multiplier, learned skills, the active combo, equipped
   gear, and any active Power Boost. Monster toughness and stage depth divide that damage.
3. **Idle risk.** When no new token usage is detected for too long, the monster
   counterattacks and drains the hero's HP — coding literally keeps you alive.
4. **Reward.** Defeating a monster grants XP (level up → skill points) and rolls loot,
   including rarity-tiered equipment. If no real usage data exists for today, the HUD shows
   `NO DATA` instead of simulating.

---

## Stages & bosses

Progress is measured in stages, persisted across launches:

- Every **8 monster defeats** advance the stage counter by 1.
- Monster toughness scales with stage depth: incoming damage is divided by
  `1 + 0.10 × (stage − 1)`, and each monster's own HP stat acts as a toughness multiplier
  (`maxHP ÷ 120`), so a Cache Golem really is beefier than a Token Slime.
- XP rewards scale up with depth: `× (1 + 0.08 × (stage − 1))`.
- **Every 5th stage is a Boss stage.** Bosses take an additional `×2.2` toughness, spawn
  larger with a crown, grant double XP, always drop **Rare or better equipment**, and burst
  an extra 20–40 gold.

The current stage is shown in the expanded HUD title (`STAGE n` / `STAGE n · BOSS`).

---

## Combo & critical hits

- **Combo.** Token-usage ticks landing within 12 seconds of each other build a combo
  (max ×10). Each combo point adds **+5% damage** to token strikes and skill casts. Taking
  a monster counterattack — or letting the 12-second window lapse — breaks the combo.
- **Critical hits.** Token strikes and skill casts have a **12% chance to crit** for double
  damage, shown with a larger `CRIT` damage tick.

---

## Combat feel

- The hero walks in place while the world scrolls by with parallax layers. Monsters stand
  at fixed spots in the world and scroll into view from the right; the world pauses when
  one reaches the hero's melee range, and resumes when it falls.

- Token bursts split into **staggered strikes** (1/2/3/5 hits by burst size), each popping
  its own token-scaled damage number — the number you see is the tokens you spent.
- **Attack intensity tiers** (driven by your token rate) scale projectile size and count,
  slash arcs, hit flashes, shake weight, and sustained-fire density.
- Pooled floating combat text: damage on the monster, heals/damage taken on the hero,
  banners for level-ups, stage-ups, boss arrivals, combos, and gear drops.
- HP bars keep a **ghost trail** that drains behind the real bar when damage lands, and
  **pulse when the hero drops below 30% HP**.
- Monsters flash white, shake, and spray sparks on hit; critical hits hit harder visually
  and shake the whole scene.
- The collapsed pill jabs and pulses on each hero strike, so attacks read without expanding.
- Level-ups fire a golden burst; monsters have spawn/death animations; bosses arrive with
  a heavier flash and shake.

---

## Battle backdrops

The battle scene is drawn over a pixel backdrop picked in **Settings → Scene**. The world
scrolls endlessly to the left with three parallax layers (far silhouettes, near
silhouettes, ground marks), so the hero is always walking forward through it:

- **Midnight Forest** — starfield, moon, and pine silhouettes.
- **Crystal Cave** — stalactites with glowing teal/violet crystals.
- **Sunset Dunes** — a violet-to-orange sky band, blocky sun, and layered dunes.
- **Neon City** — a dark skyline with lit windows.

Monsters stand at fixed spots in the world: the scrolling ground carries each one into
view from the right edge, and when it reaches the hero the world pauses while they fight
at melee range. Defeating it resumes the journey toward the next monster.

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

A rotating roster of token-waste creatures. Each has its own HP (a real toughness
multiplier), XP reward, pixel form, and death/respawn shards.

| Monster         | HP  | Toughness | XP reward |
|-----------------|-----|-----------|-----------|
| Prompt Wraith   | 120 | ×1.00     | 45        |
| Cache Golem     | 170 | ×1.42     | 65        |
| Token Slime     | 95  | ×0.79     | 35        |
| Null Sentinel   | 145 | ×1.21     | 55        |

On Boss stages the current monster spawns as a crowned, larger boss variant (see
[Stages & bosses](#stages--bosses)).

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

Each defeated monster rolls a loot drop (bosses always drop equipment):

| Drop          | Chance | Effect                                                       |
|---------------|--------|--------------------------------------------------------------|
| Health Potion | 24%    | Restore 18–32 HP                                             |
| Power Boost   | 16%    | +25% damage for 60 seconds                                   |
| Gold          | 28%    | +6–18 gold (persisted across launches)                       |
| Equipment     | 16%    | Weapon / Armor / Charm in a rolled rarity (see below)        |
| (nothing)     | 16%    | —                                                            |

### Equipment & rarity

Equipment drops roll one of three slots and a rarity tier:

| Rarity        | Chance | Weapon (ATK) | Armor (idle DEF) | Charm (skill charge) |
|---------------|--------|--------------|------------------|----------------------|
| Common        | 52%    | +4%          | −4%              | +6%                  |
| Uncommon      | 26%    | +7%          | −7%              | +10%                 |
| Rare          | 13%    | +10%         | −10%             | +15%                 |
| Epic          | 7%     | +14%         | −14%             | +20%                 |
| Legendary     | 2%     | +20%         | −20%             | +28%                 |

- Stronger drops **auto-equip**; weaker or duplicate-tier drops are salvaged into gold
  (`5 × rarity tier`).
- Equipped gear is persisted in `UserDefaults` and shown in **Settings → Equipment**.
- Boss stages guarantee a Rare-or-better equipment drop plus 20–40 bonus gold.

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
- **Scene** — pick the battle backdrop: Midnight Forest, Crystal Cave, Sunset Dunes, or
  Neon City.
- **Skill tree** — spend points, rank up skills, toggle auto-cast.
- **Equipment** — view the equipped Weapon / Armor / Charm, their rarity, and bonuses.
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
| `NotchContentView.swift`  | Collapsed + expanded HUD, combat loop, stages, combo, crits, XP/level, roles, pinning. |
| `GameViews.swift`         | Pixel actors (incl. boss variants), battle scene and selectable backdrops, floating combat text, ghost HP bars, effects. |
| `SkillSystem.swift`       | Skill definitions, tree tiers, prerequisites, energy/cooldowns.     |
| `ItemSystem.swift`        | Loot table, equipment slots and rarities, gold, Power Boost buff.   |
| `TokenUsage.swift`        | Incrementally tails local JSONL logs into a token snapshot.          |
| `TokenHookInstaller.swift`| Installs/removes token event hooks for Claude/Codex/OpenCode.        |
| `NotchSettingsWindow.swift`| Role, language, display, skill tree, equipment, Token Hooks UI.     |
| `Localization.swift`      | i18n layer (English / 简体中文 / 日本語).                            |

### Project conventions

- All user-facing text goes through the i18n layer in `Localization.swift`.
- English is the fallback. Add translations for all three languages when adding or changing
  any label, menu item, HUD status text, combat text, or empty/error state.
