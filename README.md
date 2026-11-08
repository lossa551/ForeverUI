# ForeverUI

**ForeverUI** is a high-impact combat feedback and state-aware UI addon for **World of Warcraft: Forever** (`Interface: 16001, 16000, 11505`).

It enhances unit health bars, overhead enemy nameplates, and floating combat numbers with visceral kinetic feedback while remaining 100% compliant with WoW Forever's **Secret Value (`issecretvalue`)** and **Restricted Nameplate Region** engine rules.

---

## Features

- **Violent Health Bar Trauma & Delayed Damage Trail (`UnitBars`)**
  - Smooth primary health interpolation paired with a high-contrast delayed white/amber damage trail bar (`trailHoldNormal` / `trailHoldCrit`).
  - Directional horizontal/vertical trauma recoil, scale punch, and impact flash on every hit.
  - Execute-range pulsing glow when targets drop below 20% health.
- **Bare Cracked Death Bars & Shatter Shards (`Nameplates` & `CombatFX`)**
  - On a killing blow, enemy overhead nameplates strip away clutter (hiding name/level text), tilt into a bare cracked gray corpse bar with fracture seams, and erupt with directional shatter shards.
- **High-Fountain Dynamic Combat Text (`CombatText`)**
  - Pure numeric floating combat text rendered on the `TOOLTIP` strata above enemy nameplates.
  - Multi-lane alternating fountain arcs prevent overlapping numbers during rapid hits.
  - **Flurry Escalation**: consecutive hits within the flurry window progressively scale up font size and color warmth.
  - **Crit Shockwave Echo**: critical strikes fire a sharp punch-in scale animation with an expanding ghost shockwave number.
  - Automatically suppresses duplicate vanilla 3D world floating combat numbers while keeping the target's nameplate unobstructed.
- **Shaman Dynamic Castbar & Pushback Recoil (`Castbars`)**
  - Classic weathered stone-bronze framing with school-adaptive Lead Spark (Nature cyan for *Lightning Bolt*, Frost aqua for *Healing Wave*, Fire amber for *Flame Shock*).
  - **Dynamic Latency Safe-Zone**: real-time ping sliver at the tail end of the bar derived from `GetNetStats()` to safely chain into instant shocks without clipping.
  - **Pushback Recoil Engine**: when taking damage while casting, the bar visibly recoils, flashes red, and undergoes physical trauma vibration.
- **Context-Aware State Engine (`StateEngine`)**
  - Tracks player state (`COMBAT`, `EXPLORING`, `TRAVELLING`, `RESTING`, `HARVESTING`) with configurable unit-frame alpha fading (`/fui statefade`).

---

## Installation

### Option 1: Install from Release `.zip`
1. Download `ForeverUI-v1.0.0.zip` from Releases (or build it locally with `.\Package-ForeverUI.ps1`).
2. Extract the archive into your World of Warcraft `Interface\AddOns` directory so the structure is:
   ```text
   <WoW Directory>\_forever_\Interface\AddOns\ForeverUI\ForeverUI.toc
   ```
3. Launch the game or type `/reload` in chat.

### Option 2: Deploy from Source (PowerShell)
Run the included deployment script from the repository root:
```powershell
.\Deploy-ForeverUI.ps1
# Or specify a custom AddOns path:
.\Deploy-ForeverUI.ps1 -WowAddonsPath "E:\Games\wow\World of Warcraft\_forever_\Interface\AddOns"
```

---

## Slash Commands

Use `/fui` or `/foreverui` in-game:

| Command | Description |
| :--- | :--- |
| `/fui` or `/fui test` | Run the 3-stage impact combo preview (Flurry Fountain -> Crit Shockwave -> Killing Blow Shatter) on an active enemy nameplate or simulated target bar |
| `/fui kill` | Preview the Killing Blow bare cracked/tilted gray death bar and shatter shards |
| `/fui cast [heal\|bolt]` | Preview Shaman Dynamic Castbar with school-adaptive Lead Spark, Latency Safe-Zone, and Pushback Recoil |
| `/fui status` | Show how many active enemy nameplates are currently hooked |
| `/fui state <STATE>` | Override the state engine (`COMBAT`, `EXPLORING`, `TRAVELLING`, `RESTING`, `HARVESTING`, or empty to clear) |
| `/fui statefade` | Toggle out-of-combat unit-frame alpha fading on/off |
| `/fui reset` | Reset `ForeverUIDB` saved variables to defaults |

---

## Packaging & Verification

To run the static verification test suite (`tests/verify_addon.py`) and build a clean release `.zip` in `dist/`:

```powershell
.\Package-ForeverUI.ps1
```

To run the verification check standalone:

```powershell
python tests/verify_addon.py
```
