# ForeverUI: Dynamic Castbars & Shaman Spell-Weaving Implementation Plan

> **For agentic workers:** implement this plan task-by-task, in order, checking off each step as it lands. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a high-impact, Vanilla+ dynamic castbar module (`Castbars.lua`) for ForeverUI, tailored for Shaman spellcasting (Lightning Bolt, Chain Lightning, Healing Wave pushback recoil) and tactical enemy interrupts (Earth Shock kickable vs uninterruptible shield ribs, enemy channel ticks, and First Aid bandage ticks).

**Architecture:** Pure WoW Lua 5.1 module adhering to WoW Forever `16001` engine rules (zero `FrameMeasurement` calls, safe secret value handling, no combat lockdown taint). Subscribes to `UNIT_SPELLCAST_*` events via `ForeverUI/Core/Events.lua`, driving native `StatusBar` widgets with lead sparks, latency safe-zone slivers, and channel tick pips.

**Tech Stack:** World of Warcraft Lua 5.1 (`## Interface: 16001, 16000, 11505`), `StatusBar`, `Texture`, `FontString`, `GetNetStats()`, `UnitCastingInfo` / `UnitChannelInfo`.

---

### File Structure & Responsibilities

1. **`ForeverUI/Modules/Castbars.lua`**:
   - Manages Player Castbar and Target Castbar.
   - Renders classic stone/bronze border framing with class/school elemental color tints.
   - Computes dynamic latency safe-zone clip window (`GetNetStats()`).
   - Renders pushback recoil animation on `UNIT_SPELLCAST_DELAYED`.
   - Renders channeled tick pips for First Aid bandages (8 ticks) and core channeled spells.
   - Renders Earth Shock interrupt cue vs uninterruptible iron shield ribs on target casts.
2. **`ForeverUI/Core/Config.lua`**:
   - Registers default configuration in `ForeverUIDB.castbars` (enable, showLatency, showTicks, targetShield).
3. **`ForeverUI/ForeverUI.toc`**:
   - Adds `Modules\Castbars.lua` into the addon load order.
4. **`ForeverUI/Core/Init.lua`**:
   - Registers `/fui castbar` preview command for instant in-game testing.
5. **`tests/verify_addon.py`**:
   - Updates verification script to validate `Castbars.lua` safety rules.

---

### Task 1: Configuration & TOC Registration

**Files:**
- Modify: `ForeverUI/Core/Config.lua`
- Modify: `ForeverUI/ForeverUI.toc`

- [ ] **Step 1: Add castbar configuration defaults in `Config.lua`**
  Add `db.castbars = { enabled = true, showLatency = true, showTicks = true, targetShield = true, pushbackRecoil = true }`.
- [ ] **Step 2: Add `Modules\Castbars.lua` to `ForeverUI.toc`**
  Register `Modules\Castbars.lua` before `Core\Init.lua`.
- [ ] **Step 3: Update `tests/verify_addon.py` file count**
  Adjust the module count from 8 to 9 Lua files and run `python tests/verify_addon.py` to confirm failure until `Castbars.lua` exists.

---

### Task 2: Core Castbar Frame & Vanilla+ Styling Factory

**Files:**
- Create: `ForeverUI/Modules/Castbars.lua`

- [ ] **Step 1: Implement `CreateCastbar(unit, opts)` factory**
  - Create native `StatusBar` with smooth fill texture (`Interface\\TargetingFrame\\UI-StatusBar`).
  - Add dark slate background and classic Blizzard border frame (`Interface\\Tooltips\\UI-Tooltip-Border` or sculpted brass trim).
  - Add spell name and time remaining `FontString` widgets in Friz Quadrata.
  - Add spell icon with a sharp square bevel.
- [ ] **Step 2: Implement Lead Ember / Lightning Spark**
  - Anchor a bright spark texture to the right edge of `bar:GetStatusBarTexture()`.
  - Color-tint the spark dynamically based on spell school:
    - **Nature / Lightning** (Lightning Bolt, Chain Lightning): Vibrant electric cyan/gold (`#66CCFF`).
    - **Fire** (Flame Shock, Fire Nova): Fiery amber/orange (`#FF9900`).
    - **Frost / Water** (Frost Shock, Healing Wave, Chain Heal): Cool turquoise/blue (`#33AAFF`).
- [ ] **Step 3: Implement Latency Safe-Zone Slivers**
  - Query `select(4, GetNetStats())` to get network ping in ms.
  - Position a shaded amber/red texture at the tail end of the castbar corresponding to `ping / totalCastTime`.
  - Allows Shaman to safely chain Lightning Bolt into an Earth Shock / Chain Lightning without wasted milliseconds.

---

### Task 3: Shaman Pushback Recoil Engine

**Files:**
- Modify: `ForeverUI/Modules/Castbars.lua`

- [ ] **Step 1: Hook `UNIT_SPELLCAST_DELAYED` for the player**
  - When taking damage during Healing Wave or Lightning Bolt, capture the delayed time delta.
  - Trigger a visual "Pushback Recoil":
    - Extend the castbar duration smoothly.
    - Spawn a brief red/amber recoil flash across the bar.
    - Apply a subtle horizontal trauma shake (using `UnitBars` trauma math) to convey taking a heavy blow while casting.

---

### Task 4: Channel Ticks Engine (First Aid & Target Channels)

**Files:**
- Modify: `ForeverUI/Modules/Castbars.lua`

- [ ] **Step 1: Define Spell Channel Tick Database**
  - Map tick counts and intervals:
    - `First Aid` (Bandages): 8 ticks (every 1.0s)
    - `Far Sight`: Continuous utility channel
    - Enemy target channels: `Mind Flay` (3 ticks), `Drain Life` / `Drain Soul` (5 ticks), `Arcane Missiles` (5 ticks), `Blizzard` / `Rain of Fire` (8 ticks).
- [ ] **Step 2: Generate Tick Pip Overlay Elements**
  - Pool small vertical metallic notch textures anchored at exact percentage intervals along the castbar width.
  - Show/hide notches based on whether the current spell is a recognized channel.
- [ ] **Step 3: Animate Tick Impact Flare**
  - As the channel bar drains past each notch, flash the notch with a bright amber spark to give instant visual feedback that a tick landed.

---

### Task 5: Target Castbar & Earth Shock Interrupt Alert

**Files:**
- Modify: `ForeverUI/Modules/Castbars.lua`

- [ ] **Step 1: Hook `UNIT_SPELLCAST_START` and `UNIT_SPELLCAST_CHANNEL_START` for `target`**
  - Detect when the current target begins casting or channeling.
  - Read `notInterruptible` flag from `UnitCastingInfo("target")` / `UnitChannelInfo("target")`.
- [ ] **Step 2: Uninterruptible Shield Ribs**
  - If `notInterruptible == true`, display classic silver/gold spiked shield ribs across the castbar frame.
  - Visual cue: *"Do NOT waste Earth Shock / Wind Shear!"*
- [ ] **Step 3: Interruptible Earth Shock Alert**
  - If interruptible, display a high-contrast glowing brass border and kick indicator.
- [ ] **Step 4: Successful Interrupt Shatter**
  - On `UNIT_SPELLCAST_INTERRUPTED`, snap the target castbar in half with a lightning spark and stamp a bold `"INTERRUPTED"` crimson banner.

---

### Task 6: Slash Command Test Preview & Verification

**Files:**
- Modify: `ForeverUI/Core/Init.lua`
- Modify: `tests/verify_addon.py`

- [ ] **Step 1: Implement `/fui castbar` in `Init.lua`**
  - Simulates a 2.5s Lightning Bolt cast (with latency pip and pushback recoil).
  - Simulates a Target enemy cast with Earth Shock kickable alert and interrupt shatter.
  - Simulates an 8-second First Aid bandage with 8 channel tick pips.
- [ ] **Step 2: Run verification script**
  - Run `python tests/verify_addon.py` to ensure zero syntax errors, zero `FrameMeasurement` violations, balanced Lua blocks, and proper secret value handling.
