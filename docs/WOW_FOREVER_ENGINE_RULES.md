# World of Warcraft: Forever (`16001`) — Addon Engine Rules & Allowed Patterns

**Client Flavor:** `wowf` (`## Interface: 16001, 16000`)  
**Engine Architecture:** Built on Blizzard's **12.0+ (Midnight)** security model featuring **Secret Values** (`issecretvalue`) and **Restricted Regions** (`Action[FrameMeasurement]`).

Every future improvement or module added to **ForeverUI** MUST follow the rules below and pass `python tests/verify_addon.py`.

---

## Rule 1: Secret Values (`issecretvalue` / `ns.IsSecret`)

In `16001`, combat-sensitive APIs—including `UnitHealth(unit)`, `UnitHealthMax(unit)`, `UnitIsDead(unit)`, `UnitGUID(unit)`, and the `amount` parameter of `UNIT_COMBAT`—return opaque **Secret Values** (`secret number value`) rather than plain Lua numbers.

### Forbidden on Secret Values (Will Throw Lua Taint Errors)
- **Comparisons:** `curHp > 0`, `curHp < prevHp`, `amount <= 0`, `guid == otherGuid`
- **Arithmetic:** `curHp / maxHp`, `prevHp - curHp`, `math.floor(amount)`, `math.max(1, maxHp)`
- **String Conversion / Formatting:** `tostring(amount)`, `string.format("%d", amount)`, `"-" .. amount`
- **Table Indexing:** `byGUID[secretGuid] = enhancer`

### Allowed Patterns for Secret Values
Always check [`ns.IsSecret(val)`](../ForeverUI/Core/Config.lua) (which wraps `issecretvalue(val)`) before performing any Lua operation on unit/combat values, and pass secret values **directly into native C++ widgets**:

1. **Health Bars & Damage Trails (`StatusBar:SetMinMaxValues` & `StatusBar:SetValue`)**:
   Native `StatusBar` widgets accept secret `curHp` and `maxHp` directly in C++ and support hardware/C++ interpolation via `Enum.StatusBarInterpolation`:
   ```lua
   local interpImmediate = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
   local interpEase = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut or 1

   -- 1. Main bar snaps immediately to the new secret health:
   enhancer.mainBar:SetMinMaxValues(0, maxHp)
   enhancer.mainBar:SetValue(curHp, interpImmediate)

   -- 2. Trail bar holds its previous value for trailHoldTimer (0.24s–0.38s),
   --    then eases down in C++:
   enhancer.trailBar:SetMinMaxValues(0, maxHp)
   enhancer.trailBar:SetValue(curHp, interpEase)
   ```

2. **Cleavage Cut Line & Sparks at the HP Seam (`StatusBar:GetStatusBarTexture()`)**:
   Never calculate the health bar's cut position in Lua (`(curHp / maxHp) * barWidth`). Instead, anchor `cutLine` directly to the right edge of `mainBar:GetStatusBarTexture()` so C++ positions it automatically:
   ```lua
   local mainFillTexture = mainBar:GetStatusBarTexture()
   cutLine:SetPoint("TOP", mainFillTexture, "TOPRIGHT", 0, 3)
   cutLine:SetPoint("BOTTOM", mainFillTexture, "BOTTOMRIGHT", 0, -3)
   ```

3. **Scrolling Combat Text (`FontString:SetText`)**:
   Pass secret `amount` values from `UNIT_COMBAT` directly to `FontString:SetText(amount)` without `tostring()` or math:
   ```lua
   if ns.IsSecret(opts.text) then
       entry.fs:SetText(opts.text)
   else
       entry.fs:SetText(tostring(opts.text))
   end
   ```

4. **Table Keys (`UnitGUID`)**:
   Never index a table with `UnitGUID(unit)` unless `!ns.IsSecret(guid)` has been verified first:
   ```lua
   local guid = UnitGUID(unitToken)
   if guid and not ns.IsSecret(guid) then
       self.byGUID[guid] = enhancer
   end
   ```

---

## Rule 2: Restricted Regions (Zero `FrameMeasurement` Calls)

Nameplates (`C_NamePlate.GetNamePlateForUnit`) and **any frame anchored (`SetPoint`) to a nameplate** are marked by the engine as **Restricted Regions**. Even if a temporary probe frame is anchored to a nameplate once and later re-anchored to `UIParent`, that probe frame remains permanently tainted as a Restricted Region.

### Forbidden on Restricted Regions (Triggers Blizzard "Action Blocked" Modal Popup)
Calling any measurement getter on a nameplate or a frame anchored to a nameplate triggers:
`Action[FrameMeasurement] failed because[Can't measure restricted regions]`
- `:GetCenter()`
- `:GetLeft()`, `:GetRight()`, `:GetTop()`, `:GetBottom()`
- `:GetRect()`, `:GetScaledRect()`
- `:GetWidth()`, `:GetHeight()`, `:GetSize()`

### Allowed Patterns for Restricted Regions
1. **Use Relative `SetPoint` Anchoring Instead of Screen-Space `GetCenter()`**:
   - **Bar Overlays (`UnitBars.lua`)**: Anchor `TOPLEFT` and `BOTTOMRIGHT` directly to `statusBar` using stored Lua constants (`enhancer.baseHeight = 12`) instead of `bar:GetHeight()`:
     ```lua
     local h = enhancer.baseHeight or 12
     local yPad = (h * enhancer.barPunchY - h) * 0.5
     container:ClearAllPoints()
     container:SetPoint("TOPLEFT", bar, "TOPLEFT", dx, yPad + dy)
     container:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", dx, -yPad + dy)
     ```
   - **Sparks (`CombatFX.lua`)**: Anchor spark textures directly to `enhancer.cutLine` (for hit sparks) or `enhancer.container` (for death shatter shards):
     ```lua
     sp.tex:ClearAllPoints()
     sp.tex:SetPoint("CENTER", sp.anchorFrame, "CENTER", sp.x, sp.y)
     ```
   - **Death Shatter Bar (`CombatFX.lua`)**: Anchor `db.holder` (parented to `fxCanvas` on `UIParent`) directly to `db.anchorFrame` (`enhancer.container`) with rotated hinge offsets `(cx, cy)`:
     ```lua
     db.holder:ClearAllPoints()
     db.holder:SetPoint("CENTER", db.anchorFrame, "CENTER", cx, cy)
     ```
   - **Scrolling Combat Text (`CombatText.lua`)**: Anchor `ft.holder` directly above `ft.anchorFrame`:
     ```lua
     ft.holder:ClearAllPoints()
     ft.holder:SetPoint("CENTER", ft.anchorFrame, "TOP", ft.offsetX, ft.offsetY)
     ```
2. **Store Known Dimensions in Plain Lua Fields**:
   Store `frame.fuiWidth` and `frame.fuiHeight` as plain Lua numbers when creating frames so particle/crack math never calls `:GetWidth()` or `:GetHeight()`.

---

## Rule 3: Isolate `SetScale()` From Positioned Frames

In WoW's layout engine, calling `frame:SetScale(s)` on a frame anchored with `frame:SetPoint(point, relativeTo, relativePoint, x, y)` multiplies `x` and `y` by `s`.
- **Allowed Pattern**: Keep the outer positioned `holder` frame at `scale = 1.0`, and apply elastic pop-in scaling (`SetScale(scale)`) exclusively to an inner `zoomFrame` anchored at `("CENTER", holder, "CENTER", 0, 0)`.

---

## Rule 4: Native Portrait Frames, Protected Frames & `SetCVar`

- **Never Call `SetCVar` / `C_CVar.SetCVar`**: In `16001`, calling `SetCVar` (even wrapped in `pcall`) from an addon triggers C++ `ADDON_ACTION_FORBIDDEN` and pops up Blizzard's `"ForeverUI has been blocked from an action only available to the Blizzard UI"` dialog. Addons may only **read** CVars via `GetCVar()`. If a CVar needs changing (such as disabling vanilla 3D damage numbers), instruct the user to run `/console floatingCombatTextCombatDamage 0` in chat or toggle it in Blizzard's Options menu.
- **Top-Left `PlayerFrame` and `TargetFrame`**: Keep portrait health/mana bars 100% untouched native WoW unless explicitly requested, and never call `:SetPoint()`, `:SetScale()`, `:Show()`, `:Hide()`, or `:SetAlpha()` on protected frames during `InCombatLockdown()`.
- **Nameplate Child Alpha**: While an enemy is alive, keep `statusBar:SetAlpha(1.0)` so child frames (`enhancer.container`) remain at 100% effective opacity. Only set `statusBar:SetAlpha(0.0)` and `uf.name:SetAlpha(0.0)` on enemy death when displaying the `UIParent`-parented `DeathShatterBar`.

---

## Automated Verification & Diagnostics

- **Pre-Commit Verification Suite**: Run `C:\Python314\python.exe tests\verify_addon.py` after any code change. It statically checks all `.lua` files for balanced blocks, forbidden `PlayerFrame`/`TargetFrame` calls, and any forbidden `:GetCenter()` / `:GetWidth()` / `:GetHeight()` / `:GetRect()` calls.
- **Client Error Log**: Live Lua and taint errors are written by the game client to:
  `e:\Games\wow\World of Warcraft\_forever_\Logs\General.log`
  Check this log (`Select-String -Path "...\Logs\General.log" -Pattern "\[Lua\]"`) whenever debugging in-game behavior.
