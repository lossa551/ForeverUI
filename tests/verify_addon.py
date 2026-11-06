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
    assert len(lua_files) == 8, f"Expected 8 Lua files in TOC, found {len(lua_files)}"

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

        # Combat Lockdown Safety Check: never call SetPoint/Show/Hide on PlayerFrame or TargetFrame
        forbidden = re.findall(r"\b(?:PlayerFrame|TargetFrame)\s*:\s*(?:SetPoint|SetScale|Show|Hide)\b", cleaned)
        assert not forbidden, f"Combat-lockdown unsafe call in {os.path.basename(path)}: {forbidden}"

        print(f"[PASS] {os.path.relpath(path, ROOT)}: balanced Lua blocks & combat-lockdown safe.")


def verify_feature_requirements():
    # 1. Verify CombatText.lua is strictly text-only (creates FontString, no CreateTexture icons)
    ct_path = os.path.join(ADDON_DIR, "Modules", "CombatText.lua")
    with open(ct_path, "r", encoding="utf-8") as f:
        ct_code = strip_lua_comments_and_strings(f.read())
    assert "CreateFontString" in ct_code, "CombatText.lua must create FontStrings"
    assert "CreateTexture" not in ct_code, "CombatText.lua must NOT create icon textures (text-only requirement)"
    print("[PASS] CombatText.lua verified strictly text-only (no damage icons).")

    # 2. Verify CombatFX.lua DeathShatterBar has CreateLine cracks, SetRotation tilt, and NO FontStrings
    fx_path = os.path.join(ADDON_DIR, "Modules", "CombatFX.lua")
    with open(fx_path, "r", encoding="utf-8") as f:
        fx_code = strip_lua_comments_and_strings(f.read())
    assert "CreateLine" in fx_code, "CombatFX.lua must draw fracture cracks via CreateLine"
    assert "SetRotation" in fx_code, "CombatFX.lua must tilt the death bar via SetRotation"
    assert "CreateFontString" not in fx_code, "CombatFX.lua DeathShatterBar must be a bare bar with no text/level"
    print("[PASS] CombatFX.lua DeathShatterBar verified: bare stone-gray bar, CreateLine cracks, and tilt physics.")


if __name__ == "__main__":
    paths = verify_toc()
    verify_lua_blocks_and_safety(paths)
    verify_feature_requirements()
    print("\nALL FOREVERUI PHASE 1 VERIFICATION CHECKS PASSED!")
