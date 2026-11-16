import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON_DIR = os.path.join(ROOT, "ForeverUI")
TOC_PATH = os.path.join(ADDON_DIR, "ForeverUI.toc")


def strip_lua_comments_and_strings(code: str) -> str:
    # Remove block comments --[[ ... ]]
    code = re.sub(r"--\[\[.*?\]\]", "", code, flags=re.DOTALL)
    # Remove single line comments
    code = re.sub(r"--[^\n]*", "", code)
    # Remove double-quoted and single-quoted strings
    code = re.sub(r'"(?:\\.|[^"\\])*"', '""', code)
    code = re.sub(r"'(?:\\.|[^'\\])*'", "''", code)
    return code


def verify_toc():
    assert os.path.isfile(TOC_PATH), f"Missing TOC file: {TOC_PATH}"
    with open(TOC_PATH, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f.readlines()]

    interface_lines = [l for l in lines if l.startswith("## Interface:")]
    assert interface_lines, "Missing ## Interface: in ForeverUI.toc"
    assert "16001" in interface_lines[0], f"Expected 16001 in {interface_lines[0]}"

    sv_lines = [l for l in lines if l.startswith("## SavedVariables:")]
    assert sv_lines and "ForeverUIDB" in sv_lines[0], "Missing ## SavedVariables: ForeverUIDB"

    lua_files = [l.replace("\\", os.sep) for l in lines if l and not l.startswith("#")]
    assert len(lua_files) == 10, f"Expected 10 Lua files in TOC, found {len(lua_files)}"

    for rel_path in lua_files:
        full_path = os.path.join(ADDON_DIR, rel_path)
        assert os.path.isfile(full_path), f"TOC references missing file: {rel_path}"

    print(f"[PASS] ForeverUI.toc verified ({len(lua_files)} Lua modules in load order, Interface 16001).")
    return [os.path.join(ADDON_DIR, p) for p in lua_files]


def verify_lua_blocks_and_safety(lua_paths):
    open_tokens = {"function", "if", "do", "repeat"}
    for path in lua_paths:
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read()
        cleaned = strip_lua_comments_and_strings(raw)

        # Count block openers vs closers
        words = re.findall(r"\b(?:function|if|do|repeat|end|until)\b", cleaned)
        depth = 0
        for w in words:
            if w in open_tokens:
                depth += 1
            elif w in {"end", "until"}:
                depth -= 1
                assert depth >= 0, f"Unbalanced '{w}' in {os.path.basename(path)}"
        assert depth == 0, f"Unclosed Lua block (depth={depth}) in {os.path.basename(path)}"

        # Check braces and parens
        assert cleaned.count("{") == cleaned.count("}"), f"Unbalanced {{}} in {os.path.basename(path)}"
        assert cleaned.count("(") == cleaned.count(")"), f"Unbalanced () in {os.path.basename(path)}"

        # Combat Lockdown & Protected CVar Safety Check: never call SetCVar or mutate PlayerFrame/TargetFrame
        forbidden = re.findall(r"\b(?:SetCVar|(?:PlayerFrame|TargetFrame)\s*:\s*(?:SetPoint|SetScale|Show|Hide))\b", cleaned)
        assert not forbidden, f"Forbidden Blizzard-only call in {os.path.basename(path)}: {forbidden}"

        # Restricted Region Safety Check (WoW 12.0+ / 16001): never call FrameMeasurement getters
        measurement = re.findall(r":\s*Get(?:Center|Left|Right|Top|Bottom|Rect|ScaledRect|Width|Height|Size)\s*\(", cleaned)
        assert not measurement, f"Restricted-region FrameMeasurement call in {os.path.basename(path)}: {measurement}"

        print(f"[PASS] {os.path.relpath(path, ROOT)}: balanced Lua blocks, combat-lockdown & restricted-region safe.")


def verify_feature_requirements():
    # 1. Verify CombatText.lua is strictly text-only (creates FontString, no CreateTexture icons, no FATAL banner)
    ct_path = os.path.join(ADDON_DIR, "Modules", "CombatText.lua")
    with open(ct_path, "r", encoding="utf-8") as f:
        ct_raw = f.read()
        ct_code = strip_lua_comments_and_strings(ct_raw)
    assert "CreateFontString" in ct_code, "CombatText.lua must create FontStrings"
    assert "CreateTexture" not in ct_code, "CombatText.lua must NOT create icon textures (text-only requirement)"
    assert '"FATAL"' not in ct_raw, "CombatText.lua must not display FATAL sub-banner text"
    print("[PASS] CombatText.lua verified strictly text-only (no damage icons, no FATAL banner).")

    # 2. Verify CombatFX.lua DeathShatterBar uses a clean Vanilla+ single cracked & tilted bar
    fx_path = os.path.join(ADDON_DIR, "Modules", "CombatFX.lua")
    with open(fx_path, "r", encoding="utf-8") as f:
        fx_raw = f.read()
        fx_code = strip_lua_comments_and_strings(fx_raw)
    assert "CreateLine" in fx_code, "CombatFX.lua must draw fracture cracks via CreateLine"
    assert "SetRotation" in fx_code, "CombatFX.lua must tilt the death bar via SetRotation"
    assert "SpawnDeathShatterBar" in fx_code and "deathTiltDegrees" in fx_code, (
        "CombatFX.lua DeathShatterBar must honor deathTiltDegrees on a single cracked death bar"
    )
    assert "NUM_DEATH_CHUNKS" not in fx_code and "TriggerDeathBarBreak" not in fx_code, (
        "CombatFX.lua must not contain the overkill 5-chunk Pop & Break system"
    )
    assert "UI-StatusBar" in fx_raw, "CombatFX.lua must use Blizzard UI-StatusBar texture for Vanilla+ consistency"
    assert "CreateFontString" not in fx_code, "CombatFX.lua DeathShatterBar must be a bare bar with no text/level"
    print("[PASS] CombatFX.lua DeathShatterBar verified: Vanilla+ cracked & tilted bar, CreateLine cracks, and UI-StatusBar.")

    # 3. Verify Secret Value guards (ns.IsSecret / issecretvalue) are present in combat & quest modules
    for rel in ["Core/Config.lua", "Core/StateEngine.lua", "Modules/UnitBars.lua", "Modules/Nameplates.lua", "Modules/CombatFX.lua", "Modules/CombatText.lua", "Modules/Castbars.lua"]:
        mod_path = os.path.join(ADDON_DIR, rel.replace("/", os.sep))
        with open(mod_path, "r", encoding="utf-8") as f:
            mod_code = strip_lua_comments_and_strings(f.read())
        assert "IsSecret" in mod_code, f"{rel} must guard secret values with ns.IsSecret"
    print("[PASS] Secret-value guards (ns.IsSecret) verified across all combat modules.")

    # 4. Verify DeathShatterBar never triggers on living units (no `or recentHit` in OnNamePlateRemoved,
    #    no fake TriggerDamageImpact in secret SyncUnitState, and pooled nameplate anchors clear old FX)
    np_path = os.path.join(ADDON_DIR, "Modules", "Nameplates.lua")
    with open(np_path, "r", encoding="utf-8") as f:
        np_code = strip_lua_comments_and_strings(f.read())
    assert "or recentHit" not in np_code, "Nameplates.lua must never trigger death on 'or recentHit' when unit is still alive"
    assert "CanTriggerDeath" in np_code, "Nameplates.lua must guard death triggers via CanTriggerDeath"
    assert "ClearAnchorFX" in np_code, "Nameplates.lua must clear pooled anchor FX when a nameplate is added"
    assert "ScheduleInterruptForEnhancer" in np_code, "Nameplates.lua must defer and verify unit survival before showing INTERRUPTED"
    assert "ClearInterruptsForAnchor" in np_code and "ClearInterruptsForAnchor" in ct_code, (
        "TriggerDeathForEnhancer must clear any active INTERRUPTED callouts when an enemy dies"
    )
    assert "HasRecentPlayerInterrupt" in np_code, (
        "UNIT_SPELLCAST_INTERRUPTED must require a genuine player interrupt so dying/cancelling mobs never trigger INTERRUPTED"
    )

    ub_path = os.path.join(ADDON_DIR, "Modules", "UnitBars.lua")
    with open(ub_path, "r", encoding="utf-8") as f:
        ub_raw = f.read()
        ub_code = strip_lua_comments_and_strings(ub_raw)
    assert "self:TriggerDamageImpact(enhancer, 0.08" not in ub_code, (
        "UnitBars.lua SyncUnitState must not fire fake TriggerDamageImpact on secret UNIT_HEALTH events"
    )
    assert "UI-StatusBar" in ub_raw, "UnitBars.lua must use Blizzard UI-StatusBar texture for Vanilla+ look"
    assert "ClearAnchorFX" in fx_code, "CombatFX.lua must implement ClearAnchorFX for pooled nameplate frames"
    print("[PASS] DeathShatterBar guards & Vanilla+ healthbar texture verified.")

    # 5. Verify Options.lua and Art Presets system
    opt_path = os.path.join(ADDON_DIR, "Core", "Options.lua")
    with open(opt_path, "r", encoding="utf-8") as f:
        opt_raw = f.read()
        opt_code = strip_lua_comments_and_strings(opt_raw)
    assert "CreateMinimapButton" in opt_code, "Options.lua must create the Minimap button"
    assert "ForeverUI_OptionsFrame" in opt_raw, "Options.lua must define ForeverUI_OptionsFrame"
    assert "BuildPresetsTab" in opt_code, "Options.lua must provide the Art Presets tab"
    print("[PASS] Options.lua verified: OptionsFrame, MinimapButton, and Art Presets tab implemented.")

    # 6. Verify v1.3.0 9-Element Art Overhaul, Cracked Death Bar Options & Redundant Code Removal
    cfg_path = os.path.join(ADDON_DIR, "Core", "Config.lua")
    with open(cfg_path, "r", encoding="utf-8") as f:
        cfg_raw = f.read()
        cfg_code = strip_lua_comments_and_strings(cfg_raw)
    assert "WOW_PROFILES" not in cfg_code, "Redundant WOW_PROFILES table must be removed from Config.lua"
    for elem in ["LIGHTNING", "FIRE", "EARTH", "FROST", "SHADOW", "NATURE", "ARCANE", "HOLY", "PHYSICAL"]:
        assert elem in cfg_raw, f"Config.lua must define element profile {elem}"
    for field in ["trailHot", "trailHold", "trailFade", "deathCrackHot", "sparkPalette"]:
        assert field in cfg_code, f"Config.lua element profiles must define {field}"
    for death_opt in ["deathElementalCracks", "deathRandomTilt", "deathPunchScale", "deathBounce", "deathDropSpeed", "deathDebrisScale"]:
        assert death_opt in cfg_code, f"Config.lua must define death bar option {death_opt}"
        assert death_opt in opt_raw, f"Options.lua must expose control for {death_opt}"
        assert death_opt in fx_code, f"CombatFX.lua must apply death bar option {death_opt}"
    assert "cutGlow" in ub_code and "cutSubFlare" in ub_code and "glowTex" in ub_code, (
        "UnitBars.lua must implement multi-layer wound seam (cutGlow/cutSubFlare) and dual-layer trailFragments (glowTex)"
    )
    assert "OnCombatLogImpact" not in np_code and "OnCombatLogEvent" not in ct_code and "SCHOOL_COLORS" not in ct_code, (
        "Dead combat log and SCHOOL_COLORS stubs must be removed from Nameplates.lua and CombatText.lua"
    )
    print("[PASS] v1.3.0 9-element art overhaul, Cracked Death Bar options, and dead-code cleanup verified.")


if __name__ == "__main__":
    paths = verify_toc()
    verify_lua_blocks_and_safety(paths)
    verify_feature_requirements()
    print("\nALL FOREVERUI PHASE 1 & v1.3.0 VERIFICATION CHECKS PASSED!")

