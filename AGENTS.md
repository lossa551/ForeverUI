# ForeverUI — Agent & Developer Guidelines

Before modifying any Lua file in `ForeverUI/`, read [`docs/WOW_FOREVER_ENGINE_RULES.md`](docs/WOW_FOREVER_ENGINE_RULES.md).

## Critical Engine Constraints (`Interface: 16001` / WoW: Forever)

1. **Secret Number Values (`ns.IsSecret` / `issecretvalue`)**:
   - `UnitHealth()`, `UnitHealthMax()`, `UnitIsDead()`, `UnitGUID()`, and `UNIT_COMBAT` `amount` return opaque **secret values** in combat.
   - **NEVER** perform Lua comparisons (`<`, `>`, `<=`, `>=`, `==`), arithmetic (`+`, `-`, `*`, `/`), `tostring()`, or table indexing on a value without first checking `not ns.IsSecret(val)`.
   - **DO** pass secret health values directly into `StatusBar:SetMinMaxValues(0, maxHp)` and `StatusBar:SetValue(curHp, Enum.StatusBarInterpolation.Immediate / ExponentialEaseOut)`, and pass secret damage amounts directly into `FontString:SetText(amount)`.

2. **Restricted Regions (Zero `FrameMeasurement` Getters)**:
   - Nameplates and any frame anchored (`SetPoint`) to a nameplate are **Restricted Regions**.
   - **NEVER** call `:GetCenter()`, `:GetLeft()`, `:GetRight()`, `:GetTop()`, `:GetBottom()`, `:GetRect()`, `:GetScaledRect()`, `:GetWidth()`, `:GetHeight()`, or `:GetSize()`. Doing so triggers `Action[FrameMeasurement] failed` and pops up Blizzard's `"ForeverUI has been blocked from an action only available to the Blizzard UI"` dialog.
   - **DO** anchor all overlays, sparks, floating combat numbers, and death shatter bars directly to target frames via relative `SetPoint` offsets, and use plain Lua numbers (`frame.fuiWidth`, `frame.fuiHeight`, `enhancer.baseHeight`) for geometry math.

3. **Live Workspace Link & Verification**:
   - `e:\Games\wow\World of Warcraft\_forever_\Interface\AddOns\ForeverUI` is a Windows Directory Junction pointing to `e:\Games\wow\addons\ForeverUI`. Edits here are live immediately on `/reload`.
   - Always run `C:\Python314\python.exe tests\verify_addon.py` before finishing any change.
   - Check `e:\Games\wow\World of Warcraft\_forever_\Logs\General.log` for `[E][Lua]` entries when diagnosing in-game issues.
