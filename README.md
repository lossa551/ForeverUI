# ForeverUI

**ForeverUI** is a high-impact combat feedback and state-aware UI addon for **World of Warcraft: Forever** (`Interface: 16001, 16000, 11505`).

It enhances unit health bars, overhead enemy nameplates, and floating combat numbers with visceral kinetic feedback while remaining 100% compliant with WoW Forever's **Secret Value (`issecretvalue`)** and **Restricted Nameplate Region** engine rules.

---

## Features

- **Vanilla+ Health Bar Art, 9-Element VFX & Multi-Stage Damage Trail (`UnitBars`)**
  - Classic Blizzard `UI-StatusBar` texture with vertical specular bevel gradients, 1px top highlight rim, recessed `UI-StatusBar` empty trough with inner shadow, and weathered stone-bronze & iron borders.
  - **3-Stage Thermal Trail Ramp**: lost health transitions through a hot impact flash (`trailHot`), mid-drain elemental hold (`trailHold`), and cool embers/ash (`trailFade`) with dual-layer glow + core dissolving fragments inside the draining strip.
  - **Multi-Layer Wound Cut Seam**: 4-layer bloom at the live health edge (`cutGlow`, `cutLine`, `cutFlare`, `cutSubFlare`) plus bespoke elemental burst physics across all **9 WoW elements** (`PHYSICAL`, `HOLY`, `FIRE`, `NATURE`, `FROST`, `SHADOW`, `ARCANE`, `LIGHTNING`, `EARTH`).
  - **Metallic-Backed Target Lock-On Brackets** with a crisp target-acquire snap animation and a **Double-Beat (`lub-dub`) Cardiac Execute Pulse** below 20% health.
- **Customizable Cracked & Tilted Death Bars (`Nameplates` & `CombatFX`)**
  - On a killing blow, enemy overhead nameplates strip away clutter (hiding name/level text), draw two-phase glowing elemental `CreateLine` fracture fissures (`deathCrackHot` → `deathCrack`) across a single `UI-StatusBar` corpse bar, deliver a configurable killing-blow scale punch, hinge-tilt with a tactile metallic bounce/clank, settle with elemental sparks/debris, and fade out cleanly.
  - **6 New Death Bar Feel Controls** in `/fui` → **Nameplates & Death**:
    - *Elemental Glowing Cracks* (`deathElementalCracks`)
    - *Randomize Tilt Side (Left / Right)* (`deathRandomTilt`)
    - *Kill Impact Punch Scale* (`deathPunchScale`)
    - *Hinge Bounce & Clank* (`deathBounce`)
    - *Corpse Bar Drop Speed* (`deathDropSpeed`)
    - *Kill Spark & Debris Scale* (`deathDebrisScale`)
    - Instant **Preview Cracked Death Bar** button in the settings UI.
- **High-Fountain Dynamic Combat Text (`CombatText`)**
  - Pure numeric floating combat text rendered on the `TOOLTIP` strata above enemy nameplates with per-element trajectories (including Arcane orbital wave, Nature organic spiral, Holy ascending pillar, Frost lateral snap, Fire buoyant rise, and Earth heavy gravity).
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
- **Interactive Control Panel & Minimap Icon (`Options`)**
  - Sleek dark HUD settings window with tab navigation, real-time sliders, and live elemental & death bar preview buttons.
  - Circular draggable minimap button with tooltips for quick settings access and showcase triggers.
  - Curated **Art Presets**:
    - **Vanilla+ (Signature)**: Classic `UI-StatusBar` & stone-bronze framing, dynamic 9-element spell particles & colors, controlled trauma recoil (0.70x), subtle scale punch (1.08x–1.32x), 3-stage elemental trails, and a crisp -8.5° cracked death bar.
    - **Brutal (Heavy Metal)**: Exaggerated combat violence, massive punch scale (up to 1.90x), heavy trauma recoil (1.6x), slow bleeding trails (3.8), -16.0° alternating death tilt with heavy bounce & debris, and giant lingering numbers.
    - **Minimal (Clean Esports)**: Ultra-fast bar snap (28) & rapid trails (11.0), zero death tilt (0°), minimal recoil (0.20x), no screen clutter or cast shake, and compact fast-clearing numbers.
    - **Arcade (Bouncy Pop)**: Fast bar snap (26) & rapid trails (9.5), vertical bounce pops (1.18x–1.58x) with light sideways shake (0.45x), bouncy alternating death bars, wide 2.2s flurry combos, and brisk poppy numbers.
    - **Cinematic (Vanilla Bars)**: Immersive RPG & authentic Vanilla bars with rigid non-stretching bars, soft cut-seam glints, weighty slow trails (3.2), WoW spell-school colors, gentle -4.5° death bar, subtle numbers, and deep out-of-combat HUD fade.
  - Built to cleanly integrate future art presets, textures, and community styles.

---

## Installation

### Option 1: Install from Release `.zip`
1. Download `ForeverUI-v1.3.5.zip` from Releases (or build it locally with `.\Package-ForeverUI.ps1`).
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
| `/fui` or `/fui config` | Open the Settings & Art Presets configuration panel |
| `/fui test` or `/fui showcase` | Run the full 9-element combat combo preview (Lightning -> Fire -> Earth -> Frost -> Shadow -> Nature -> Arcane -> Holy -> Physical -> Kill) |
| `/fui <element>` | Preview a single element (`lightning`, `fire`, `earth`, `frost`, `shadow`, `nature`, `arcane`, `holy`, `physical`) |
| `/fui dot [element]` | Preview continuous 6s DoT burning/crackling on remaining health |
| `/fui kill [element]` | Preview the Killing Blow cracked & tilted death bar (cycles elements if omitted) |
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
