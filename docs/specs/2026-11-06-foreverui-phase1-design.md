# ForeverUI — Phase 1 Design Specification

**Date:** 2026-11-06  
**Target Client:** *World of Warcraft: Forever* (`## Interface: 16001, 16000`)  
**Architecture:** Option A — Native Zero-Dependency Modular Framework (`ForeverUI`)

---

## 1. Goals & Visual Direction

1. **100% Native WoW Look & Feel**:
   - Keep Blizzard's authentic **Overhead Enemy Nameplates (`C_NamePlate`)** as well as the top-left `PlayerFrame` and `TargetFrame` intact.
   - Use Blizzard's native `Interface\TargetingFrame\UI-StatusBar` bar texture and `FRIZQT__.TTF` (`STANDARD_TEXT_FONT`) typography so everything feels like a supercharged version of native WoW.
2. **Violent, High-Punch Overhead Nameplate & Unit Health Bars (`Nameplates` + `UnitBars` + `CombatFX`)**:
   - **Overhead Enemy Nameplates (`C_NamePlate`)**: Attach non-protected overlay layers directly onto the health bars floating above enemies' heads in the 3D world (`NAME_PLATE_UNIT_ADDED`), as well as onto `PlayerFrame` and `TargetFrame`.
   - **Immediate Bar Cut + Molten Damage Trail**: When damage lands, the health bar cuts rapidly while an exposed white-to-crimson trail chunk holds (`240ms` normal, `380ms` crit) before draining down smoothly.
   - **White-Hot Cleavage Slash & Shatter Sparks**: A bright vertical cleavage spark flashes at the exact HP cut seam on the overhead nameplate (and unit frame), and crits / heavy blows (`>= 15% max HP`) burst pooled spark particles off the cut point.
   - **Proportional Trauma Recoil & Vertical Bar Punch**: Big hits and crits trigger a damped spring recoil jolt (`trauma^2`) and a brief vertical bar scale swell (`1.2x` normal, `1.5x` crit) on the enemy's overhead health bar and unit frame bar overlay.
   - **Execute & Combat Cues**: Pulsing crimson execute border on the overhead enemy nameplate (and `TargetFrame`) when an enemy drops to `<= 20%` HP, plus combat glow and low-HP pulse on `PlayerFrame`.
   - **Killing Blow / Death Shatter Bar (Bare Bar Tilt, Gray-Out & Crack)**: When an enemy hits `0 HP` (`UNIT_DIED` / `UnitIsDead`), before Blizzard hides the overhead nameplate, `Nameplates.lua` snapshots the bar's screen position and spawns a pooled **Death Shatter Ghost Bar** on `UIParent` that:
     1. Strips away the unit name, level badge, and HP text so **only the bare bar itself** remains.
     2. Turns stone-gray (`#47474f`) with a brief white impact flash.
     3. Renders jagged fracture cracks across the bar using `CreateLine()` fissure segments.
     4. Hinges and tilts downward (`~11.5°` right-side drop with spring bounce and gravity slide) while bursting stone/metal debris shards before fading out.
3. **Pure Text-Only Dynamic Scrolling Combat Text (`CombatText`)**:
   - **No spell icons** — clean, bold, outlined numbers using WoW's native `FRIZQT__.TTF` (`STANDARD_TEXT_FONT`).
   - **Anchored to Overhead Enemy Nameplates**: When an enemy's overhead nameplate is visible on screen, outgoing damage and crits erupt directly from above that enemy's overhead health bar! (Falls back cleanly to a center-right arc if the nameplate is off-screen).
   - Authentic WoW colors: White (`#FFFFFF`) for melee/auto-attacks, Classic Gold (`#FFD100`) and spell-school hues for abilities/spells, Red (`#FF2020`) for incoming damage, and Green (`#20FF20`) for healing.
   - Elastic **Crit Pop-In** (`0.5x -> 1.8x -> 1.3x` settle) for critical hits.
4. **Future-Ready Context State Engine (`StateEngine`)**:
   - Tracks `COMBAT`, `RESTING` (town/inn), `TRAVELLING` (mounted/flying), `HARVESTING` (gathering cast), and `EXPLORING` (open world) and broadcasts `STATE_CHANGED` events so Phase 2's immersive UI fading and state transitions plug straight into the same core.

---

## 2. File & Module Structure

```text
ForeverUI/
├── ForeverUI.toc          # Interface: 16001, 16000 | SavedVariables: ForeverUIDB
├── Core/
│   ├── Init.lua           # Addon namespace (ns), module lifecycle, /fui slash commands
│   ├── Config.lua         # Default config table, SavedVariables merge, getters/setters
│   ├── Events.lua         # Event dispatcher + shared 60 FPS OnUpdate animation ticker
│   └── StateEngine.lua    # Detects COMBAT, RESTING, TRAVELLING, HARVESTING, EXPLORING
└── Modules/
    ├── Nameplates.lua     # Overhead enemy health bar enhancers (trail, recoil, cleavage, execute)
    ├── UnitBars.lua       # In-place native Player/Target bar enhancers, trail, cleavage, recoil
    ├── CombatFX.lua       # Pooled bar-shatter sparks, combat glow, low-HP pulse
    └── CombatText.lua     # Pooled text-only scrolling combat text anchored to overhead nameplates
```

---

## 3. Component Specifications & Data Flow

### 3.1 `Core/Init.lua` & `Core/Config.lua`
- Exposes `local addonName, ns = ...` and global `ForeverUI = ns`.
- `ns:RegisterModule(name, moduleTable)` registers modules and invokes `OnInitialize()` at `ADDON_LOADED` and `OnEnable()` at `PLAYER_LOGIN`.
- Slash commands (`/fui` or `/foreverui`):
  - `/fui test` — Spawns an in-game preview/test sequence firing normal hits, crits, mega shatter (`35% HP`), incoming hit, and heal on your active nameplate/unit frames.
  - `/fui state <combat|explore|town>` — Preview state transitions.
  - `/fui reset` — Resets `ForeverUIDB` to defaults.

### 3.2 `Core/Events.lua`
- Single hidden event frame multiplexing WoW client events to registered module callbacks (`ns.Events:Register(event, callback)`).
- Shared animation loop (`ns.Events:RegisterTicker(id, fn)`): Runs `OnUpdate` **only** while at least one animation (bar trail, trauma shake, spark, or floating text) is active, automatically sleeping at `0%` CPU when idle.

### 3.3 `Core/StateEngine.lua`
- Listens to `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `PLAYER_UPDATE_RESTING`, `PLAYER_MOUNT_DISPLAY_CHANGED`, `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_STOP`, and `ZONE_CHANGED_NEW_AREA`.
- Priority order: `COMBAT` > `HARVESTING` > `RESTING` > `TRAVELLING` > `EXPLORING`.
- Fires internal callback `ns.Events:FireCustom("FOREVERUI_STATE_CHANGED", newState, oldState)`.

### 3.4 `Modules/Nameplates.lua` & `Modules/UnitBars.lua`
- **`Nameplates.lua` (Overhead Bars above Enemies' Heads)**:
  - Listens to `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED`, and `UNIT_HEALTH`.
  - Uses `C_NamePlate.GetNamePlateForUnit(unitToken)` and resolves `namePlate.UnitFrame.healthBar` (with fallbacks for Classic/Forever `16001` nameplate child structures).
  - Maps `UnitGUID(unitToken)` -> active nameplate health bar so `CombatText` and `CombatFX` can anchor numbers and sparks directly to the specific enemy's overhead health bar!
- **`UnitBars.lua` (Top-Left Player & Target Frames)**:
  - Hooks `PlayerFrameHealthBar` and `TargetFrameHealthBar` using the shared bar-enhancer factory.
- **Shared Bar-Enhancer Overlay Factory**:
  - Attaches a non-protected overlay hierarchy using `Interface\TargetingFrame\UI-StatusBar`:
    - `trailBar` (`StatusBar` in `ARTWORK` sublevel 1): Warm white/orange/crimson catch-up chunk, holds `0.24s` (`0.38s` on crits) and lerps toward current HP.
    - `smoothBar` (`StatusBar` in `ARTWORK` sublevel 2): Lerps rapidly to current HP.
    - `hitFlash` (`Texture` in `OVERLAY`, additive blend): White flash on damage taken.
    - `cutLine` (`Texture` in `OVERLAY`, additive blend): Bright cleavage spark at the right edge of `smoothBar`.
  - **Trauma Shake & Vertical Bar Punch**:
    - Computes `trauma = min(1.0, (pctLost / 0.26) * (isCrit and 1.75 or 0.90))`.
    - Applies damped spring offset `(dx, dy)` and vertical scale punch to the non-protected bar overlay container.

### 3.5 `Modules/CombatFX.lua`
- **Bar Shatter Sparks & Debris Shards**: Pooled `4x4` additive spark and stone-shard textures spawned at the `cutLine` seam on overhead nameplates and unit frames on crits, hits `>= 10% HP`, or enemy death, flying outward with gravity.
- **Death Shatter Ghost Bar (`SpawnDeathShatterBar`)**:
  - Pooled `UIParent` frame positioned at the dying enemy's overhead nameplate screen coordinates so it persists for `1.3s` even after Blizzard removes the native nameplate on death.
  - Renders **only the bare bar itself** (no name, no level badge, and no HP/status text)—just a stone-gray status bar (`Interface\TargetingFrame\UI-StatusBar`), dark iron border, and jagged fracture cracks across the bar using `frame:CreateLine()` segments (dark fissure lines paired with light zinc bevel lines).
  - Animates a left-hinged downward tilt (`-11.5°` rotation / split-segment vertical shear + damped spring bounce) and downward gravity drift after `0.22s`, fading out between `0.85s` and `1.30s`.
- **Execute Glow (`<= 20% HP`)**: Pulsing red additive border overlay around any enemy overhead nameplate (and `TargetFrame`) when `hp / maxHp <= 0.20`.
- **Low-HP Player Pulse (`<= 30% HP`)**: Subtle red screen-edge pulse (`UIParent` overlay, mouse-disabled) when in combat below `30%` HP.

### 3.6 `Modules/CombatText.lua`
- Registers `COMBAT_LOG_EVENT_UNFILTERED` (`CombatLogGetCurrentEventInfo()`).
- When `sourceGUID == UnitGUID("player")`, looks up `destGUID` in `Nameplates:GetBarForGUID(destGUID)`:
  - If the enemy's overhead nameplate is on screen, spawns the damage number **directly above that enemy's overhead health bar**!
  - Otherwise, spawns on the fallback target arc.
- Uses an object pool of `FontString` wrappers using `STANDARD_TEXT_FONT` — **text only, no icons**.
- **Trajectory & Crit Elastic Pop**:
  - Normal hits: `16pt`, parabolic arc (`vx`, `vy`, `gravity`), `1.15s` duration.
  - Crits: `24pt`, elastic scale curve (`0.5x -> 1.8x` in `0.08s`, settling to `1.3x` by `0.22s`).

---

## 4. Error Handling, Engine Rules & Verification Plan

- **WoW: Forever (`16001`) Secret Values & Restricted Regions**: See [`docs/WOW_FOREVER_ENGINE_RULES.md`](../WOW_FOREVER_ENGINE_RULES.md) for mandatory rules on handling secret values (`ns.IsSecret` + native `StatusBar:SetValue` / `FontString:SetText` pass-through) and avoiding `FrameMeasurement` getters (`:GetCenter()`, `:GetHeight()`, `:GetWidth()`) on nameplate Restricted Regions.
- **Combat Lockdown Verification**: Neither `Nameplates.lua` nor `UnitBars.lua` calls protected functions (`SetPoint`, `SetScale`, `Show`, `Hide`) on secure frames. Top-left `PlayerFrame` and `TargetFrame` portrait bars remain 100% untouched native WoW.
- **In-Game Self-Test (`/fui test` & `/fui kill`)**: Simulates hits, crits, mega shatter blows, and the bare cracked/tilted gray death bar on an active enemy nameplate (or a simulated preview bar offset to the right of screen center).
