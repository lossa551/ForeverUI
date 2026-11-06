# ForeverUI Phase 1 Implementation Plan

> **For agentic workers:** implement this plan task-by-task, in order, checking off each step as it lands. Steps use checkbox (`- [ ]`) syntax for tracking. Dispatch a fresh subagent per task where the tasks are independent (see dispatching-parallel-agents), otherwise execute inline with a review checkpoint after each task.

**Goal:** Build the `ForeverUI` World of Warcraft: Forever (`## Interface: 16001, 16000`) addon with a modular state-aware core, high-impact violent health bar trauma on overhead enemy nameplates and default unit frames, bare cracked/tilted gray death bars, and pure text-only scrolling combat text.

**Architecture:** Zero-dependency native WoW Lua framework sharing the addon namespace (`local addonName, ns = ...`). A single event bus and sleeping 60 FPS `OnUpdate` ticker drive four decoupled modules (`UnitBars`, `Nameplates`, `CombatFX`, `CombatText`) plus `StateEngine`. All visual layers attach as non-protected child overlays or `UIParent` effect pools so animations never taint or fail during `InCombatLockdown()`.

**Tech Stack:** World of Warcraft Lua 5.1 API (`## Interface: 16001, 16000`), `C_NamePlate`, `COMBAT_LOG_EVENT_UNFILTERED`, `StatusBar` / `Texture` / `Line` / `FontString` object pools, PowerShell deployment helper.

---

### Task 1: Core Addon Manifest, Namespace Init, Config & Event/Animation Bus

**Files:**
- Create: `ForeverUI/ForeverUI.toc`
- Create: `ForeverUI/Core/Config.lua`
- Create: `ForeverUI/Core/Events.lua`
- Create: `ForeverUI/Core/Init.lua`

- [x] **Step 1: Create `ForeverUI/ForeverUI.toc`**
- [x] **Step 2: Create `ForeverUI/Core/Config.lua` with `SavedVariables` defaults and deep merge**
- [x] **Step 3: Create `ForeverUI/Core/Events.lua` with event multiplexing and auto-sleeping 60 FPS ticker**
- [x] **Step 4: Create `ForeverUI/Core/Init.lua` with module lifecycle and `/fui` slash commands**

---

### Task 2: Context State Engine (`Core/StateEngine.lua`)

**Files:**
- Create: `ForeverUI/Core/StateEngine.lua`

- [x] **Step 1: Implement `StateEngine.lua` tracking `COMBAT`, `HARVESTING`, `RESTING`, `TRAVELLING`, and `EXPLORING`**
- [x] **Step 2: Broadcast `FOREVERUI_STATE_CHANGED` and apply configurable state opacity transitions**

---

### Task 3: Combat FX Pool — Shatter Sparks, Bare Cracked/Tilted Death Bar & Low-HP Pulse (`Modules/CombatFX.lua`)

**Files:**
- Create: `ForeverUI/Modules/CombatFX.lua`

- [x] **Step 1: Implement pooled additive spark and stone-shard emitters (`SpawnBarSparks`)**
- [x] **Step 2: Implement pooled bare cracked/tilted stone-gray Death Shatter Ghost Bar (`SpawnDeathShatterBar`) using `CreateLine()` fracture fissures and left-hinge downward tilt physics**
- [x] **Step 3: Implement low-HP (`<= 30%`) screen-edge pulse and player combat glow**

---

### Task 4: Shared Violent Bar Trauma Enhancer & Default Unit Frames (`Modules/UnitBars.lua`)

**Files:**
- Create: `ForeverUI/Modules/UnitBars.lua`

- [x] **Step 1: Create reusable `CreateBarEnhancer(statusBar, opts)` factory (molten trail bar, smooth main bar, white-hot cleavage cut-line, hit-flash, damped `trauma^2` recoil shake, vertical bar scale punch, `<20%` execute border)**
- [x] **Step 2: Hook native `PlayerFrameHealthBar` and `TargetFrameHealthBar` in-place**

---

### Task 5: Overhead Enemy Nameplates Enhancer (`Modules/Nameplates.lua`)

**Files:**
- Create: `ForeverUI/Modules/Nameplates.lua`

- [x] **Step 1: Hook `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED`, and `UNIT_HEALTH` via `C_NamePlate.GetNamePlateForUnit`**
- [x] **Step 2: Attach violent bar trauma enhancer to overhead enemy health bars and map `unitGUID -> plateData`**
- [x] **Step 3: Trigger `CombatFX:SpawnDeathShatterBar` and hide native nameplate text/level immediately when an enemy reaches `0 HP`**

---

### Task 6: Pure Text-Only Dynamic Scrolling Combat Text (`Modules/CombatText.lua`)

**Files:**
- Create: `ForeverUI/Modules/CombatText.lua`

- [x] **Step 1: Implement pooled `FontString` combat numbers using `STANDARD_TEXT_FONT` (text-only, no icons)**
- [x] **Step 2: Parse `COMBAT_LOG_EVENT_UNFILTERED` (`SWING_DAMAGE`, `RANGE_DAMAGE`, `SPELL_DAMAGE`, `SPELL_PERIODIC_DAMAGE`, `SPELL_HEAL`, `SPELL_PERIODIC_HEAL`)**
- [x] **Step 3: Anchor outgoing numbers directly to the damaged enemy's overhead nameplate when visible, with parabolic arcs and elastic Crit Pop-In (`0.5x -> 1.8x -> 1.3x`)**

---

### Task 7: Verification Harness & Deployment Helper

**Files:**
- Create: `tests/verify_addon.py`
- Create: `Deploy-ForeverUI.ps1`

- [x] **Step 1: Verify all `.toc` file paths, Lua syntax, balanced blocks, and combat lockdown safety**
- [x] **Step 2: Create `Deploy-ForeverUI.ps1` to install/symlink `ForeverUI` into WoW's `Interface\AddOns` folder**
