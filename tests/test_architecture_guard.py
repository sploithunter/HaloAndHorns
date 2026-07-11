from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "architecture_guard", ROOT / "scripts" / "architecture_guard.py"
)
assert SPEC and SPEC.loader
architecture_guard = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = architecture_guard
SPEC.loader.exec_module(architecture_guard)


class ArchitectureGuardTest(unittest.TestCase):
    def test_comment_stripping_preserves_strings_and_line_numbers(self) -> None:
        source = '''-- Signals.GameEvent:FireClient(player)\nlocal value = "--not a comment"\n--[[\nNet:RemoteEvent("Hidden")\n]]\nNet:RemoteEvent("Visible")\n'''
        stripped = architecture_guard.strip_lua_comments(source)
        self.assertEqual(source.count("\n"), stripped.count("\n"))
        self.assertIn('"--not a comment"', stripped)
        self.assertNotIn("Hidden", stripped)
        self.assertIn("Visible", stripped)

    def test_collection_ignores_comments_and_finds_unregistered_configs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "src" / "Shared").mkdir(parents=True)
            (root / "configs").mkdir()
            (root / "src" / "Shared" / "Network.lua").write_text(
                '-- Transport:RemoteEvent("Ignored")\nTransport:RemoteEvent("Found")\n',
                encoding="utf-8",
            )
            (root / "src" / "Shared" / "Network").mkdir()
            (root / "src" / "Shared" / "Network" / "SignalRegistry.lua").write_text(
                'Transport:RemoteEvent("Canonical")\n', encoding="utf-8"
            )
            (root / "src" / "Shared" / "ConfigLoader.lua").write_text(
                'if configName == "registered" then return true end\n', encoding="utf-8"
            )
            (root / "src" / "Server" / "Services").mkdir(parents=True)
            (root / "src" / "Server" / "Services" / "EconomyService.lua").write_text(
                'self._dataService:AddCurrency(player, "coins", 1)\n', encoding="utf-8"
            )
            (root / "src" / "Server" / "Services" / "FeatureService.lua").write_text(
                'self._dataService:AddCurrency(player, "coins", 1)\n', encoding="utf-8"
            )
            (root / "configs" / "registered.lua").write_text("return {}\n", encoding="utf-8")
            (root / "configs" / "missing.lua").write_text("return {}\n", encoding="utf-8")

            findings = architecture_guard.collect_findings(
                root,
                ("remote-construction", "config-without-schema", "currency-persistence-call"),
            )
            remote = findings["remote-construction"]["src/Shared/Network.lua"]
            self.assertEqual(1, remote.count)
            self.assertEqual((2,), remote.lines)
            self.assertNotIn(
                "src/Shared/Network/SignalRegistry.lua", findings["remote-construction"]
            )
            self.assertNotIn(
                "src/Shared/Network/RuntimeTransport.lua", findings["remote-construction"]
            )
            self.assertNotIn(
                "src/Shared/Libraries/Matter/debugger/debugger.luau",
                findings["remote-construction"],
            )
            self.assertEqual(
                {"configs/missing.lua"}, set(findings["config-without-schema"])
            )
            self.assertEqual(
                {"src/Server/Services/FeatureService.lua"},
                set(findings["currency-persistence-call"]),
            )

    def test_exact_baseline_passes_and_ratchet_changes_fail(self) -> None:
        finding = architecture_guard.Finding(count=2, lines=(3, 7))
        findings = {"runtime-wait": {"src/A.lua": finding}}
        rule = architecture_guard.RULE_BY_KEY["runtime-wait"]
        allowlist = {
            "version": 1,
            "tracking": "https://example.test/issue/1",
            "rules": {
                "runtime-wait": {
                    "pattern": rule.pattern,
                    "owner": rule.owner,
                    "reason": rule.reason,
                    "disposition": rule.disposition,
                    "files": {"src/A.lua": 2},
                }
            },
        }
        self.assertEqual([], architecture_guard.compare_findings(findings, allowlist))

        increased = {"runtime-wait": {"src/A.lua": architecture_guard.Finding(3, (3, 7, 9))}}
        self.assertIn("INCREASED DEBT", architecture_guard.compare_findings(increased, allowlist)[0])

        reduced = {"runtime-wait": {"src/A.lua": architecture_guard.Finding(1, (3,))}}
        self.assertIn("STALE ALLOWLIST", architecture_guard.compare_findings(reduced, allowlist)[0])

        moved = {"runtime-wait": {"src/B.lua": architecture_guard.Finding(1, (1,))}}
        errors = architecture_guard.compare_findings(moved, allowlist)
        self.assertTrue(any("NEW DEBT" in error for error in errors))
        self.assertTrue(any("STALE ALLOWLIST" in error for error in errors))

        allowlist["rules"]["runtime-wait"]["pattern"] = "stale pattern"
        errors = architecture_guard.compare_findings(findings, allowlist)
        self.assertTrue(any("pattern must match" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
