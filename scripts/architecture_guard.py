#!/usr/bin/env python3
"""Ratcheting architecture fitness checks for known repository debt.

The checked-in allowlist records existing violations by rule, path, and count.
New paths or count increases fail. Count decreases also fail until the matching
allowlist budget is reduced, which makes architectural cleanup explicit.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ALLOWLIST = ROOT / "scripts" / "architecture_allowlist.json"


@dataclass(frozen=True)
class RuleSpec:
    key: str
    title: str
    pattern: str
    owner: str
    reason: str
    disposition: str = "migration-debt"
    expressions: tuple[str, ...] = ()
    exempt_paths: tuple[str, ...] = ()


@dataclass(frozen=True)
class Finding:
    count: int
    lines: tuple[int, ...]


RULES = (
    RuleSpec(
        key="remote-construction",
        title="remote construction outside the future generated registry",
        pattern='Instance.new("RemoteEvent|RemoteFunction") or transport:RemoteEvent|RemoteFunction',
        owner="networking",
        reason="Existing code-declared and service-owned remotes must migrate to the network manifest.",
        expressions=(
            r"Instance\s*\.\s*new\s*\(\s*[\"']Remote(?:Event|Function)[\"']\s*\)",
            r"\b[A-Za-z_][A-Za-z0-9_]*\s*:\s*Remote(?:Event|Function)\s*\(",
        ),
        exempt_paths=("src/Shared/Network/SignalRegistry.lua",),
    ),
    RuleSpec(
        key="game-event-publication",
        title="direct gameplay-event network publication",
        pattern="Signals.GameEvent:FireClient|FireAllClients",
        owner="gameplay events",
        reason="Existing direct sends must migrate behind the authoritative gameplay-event publisher.",
        expressions=(r"\bSignals\s*\.\s*GameEvent\s*:\s*(?:FireClient|FireAllClients)\s*\(",),
    ),
    RuleSpec(
        key="pet-record-mutation",
        title="pet ownership mutation outside the mint/transfer boundary",
        pattern='AddItem(..., "pets", ...) or direct Inventory.pets.items assignment',
        owner="pet inventory",
        reason="Existing pet creation bypasses must migrate to pet mint or transfer transactions.",
        expressions=(
            r"\bAddItem\s*\([\s\S]{0,500}?[\"']pets[\"']",
            r"\bInventory\s*(?:\.\s*pets|\[\s*[\"']pets[\"']\s*\])\s*"
            r"(?:\.\s*items|\[\s*[\"']items[\"']\s*\])\s*(?:\[[^\]]+\])?\s*=",
        ),
    ),
    RuleSpec(
        key="currency-persistence-call",
        title="direct low-level currency mutation",
        pattern="_dataService|dataService|dataSvc:AddCurrency|RemoveCurrency|SetCurrency",
        owner="economy and persistence",
        reason="Existing direct persistence calls must migrate to the economy transaction boundary.",
        expressions=(
            r"\b(?:_dataService|dataService|dataSvc)\s*:\s*"
            r"(?:AddCurrency|RemoveCurrency|SetCurrency)\s*\(",
        ),
    ),
    RuleSpec(
        key="service-global-locator",
        title="runtime global service locator usage",
        pattern="_G.RBXTemplateServices",
        owner="service lifecycle",
        reason="Existing global lookups must migrate to declared dependencies or event subscriptions.",
        expressions=(r"_G\s*\.\s*RBXTemplateServices\b",),
    ),
    RuleSpec(
        key="runtime-wait",
        title="runtime task.wait/task.delay usage",
        pattern="task.wait(...) or task.delay(...) under src/",
        owner="path owners in CODEOWNERS",
        reason="Existing timers require classification and synchronization waits must migrate to completion contracts.",
        expressions=(r"\btask\s*\.\s*(?:wait|delay)\s*\(",),
    ),
    RuleSpec(
        key="config-without-schema",
        title="config without explicit ConfigLoader validation",
        pattern="configs/*.lua absent from ConfigLoader:ValidateConfig dispatch",
        owner="configuration",
        reason="Existing permissive configs must gain explicit schemas and version policy.",
    ),
)

RULE_BY_KEY = {rule.key: rule for rule in RULES}
SHORTCUTS = {
    "network": ("remote-construction", "game-event-publication"),
    "mutations": ("pet-record-mutation", "currency-persistence-call"),
    "timing": ("runtime-wait",),
    "configs": ("config-without-schema",),
    "services": ("service-global-locator",),
}


def strip_lua_comments(text: str) -> str:
    """Remove ordinary Luau comments while preserving strings and line numbers."""
    out: list[str] = []
    index = 0
    quote: str | None = None
    while index < len(text):
        char = text[index]
        if quote is not None:
            out.append(char)
            if char == "\\" and index + 1 < len(text):
                index += 1
                out.append(text[index])
            elif char == quote:
                quote = None
            index += 1
            continue

        if char in ("'", '"'):
            quote = char
            out.append(char)
            index += 1
            continue

        if text.startswith("--[[", index):
            end = text.find("]]", index + 4)
            end = len(text) if end == -1 else end + 2
            comment = text[index:end]
            out.extend("\n" if item == "\n" else " " for item in comment)
            index = end
            continue

        if text.startswith("--", index):
            end = text.find("\n", index + 2)
            end = len(text) if end == -1 else end
            out.extend(" " for _ in text[index:end])
            index = end
            continue

        out.append(char)
        index += 1
    return "".join(out)


def runtime_files(root: Path) -> list[Path]:
    src = root / "src"
    return sorted((*src.rglob("*.lua"), *src.rglob("*.luau")))


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def collect_regex_rule(root: Path, rule: RuleSpec) -> dict[str, Finding]:
    expressions = tuple(re.compile(pattern) for pattern in rule.expressions)
    findings: dict[str, Finding] = {}
    for path in runtime_files(root):
        relative = path.relative_to(root).as_posix()
        if relative in rule.exempt_paths:
            continue
        text = strip_lua_comments(path.read_text(encoding="utf-8", errors="ignore"))
        lines: list[int] = []
        for expression in expressions:
            for match in expression.finditer(text):
                prefix = text[max(0, match.start() - 20) : match.start()]
                if rule.key == "currency-persistence-call" and re.search(r"function\s+$", prefix):
                    continue
                lines.append(line_number(text, match.start()))
        if lines:
            findings[relative] = Finding(count=len(lines), lines=tuple(sorted(lines)))
    return findings


def collect_unregistered_configs(root: Path) -> dict[str, Finding]:
    loader_path = root / "src" / "Shared" / "ConfigLoader.lua"
    loader = strip_lua_comments(loader_path.read_text(encoding="utf-8", errors="ignore"))
    registered = set(re.findall(r"\bconfigName\s*==\s*[\"']([^\"']+)[\"']", loader))
    findings: dict[str, Finding] = {}
    for path in sorted((root / "configs").glob("*.lua")):
        if path.stem not in registered:
            findings[path.relative_to(root).as_posix()] = Finding(count=1, lines=(1,))
    return findings


def collect_findings(root: Path, selected: Iterable[str] | None = None) -> dict[str, dict[str, Finding]]:
    selected_keys = set(selected or RULE_BY_KEY)
    result: dict[str, dict[str, Finding]] = {}
    for rule in RULES:
        if rule.key not in selected_keys:
            continue
        if rule.key == "config-without-schema":
            result[rule.key] = collect_unregistered_configs(root)
        else:
            result[rule.key] = collect_regex_rule(root, rule)
    return result


def baseline_document(findings: dict[str, dict[str, Finding]], tracking: str) -> dict[str, object]:
    rules: dict[str, object] = {}
    for rule in RULES:
        if rule.key not in findings:
            continue
        rules[rule.key] = {
            "pattern": rule.pattern,
            "owner": rule.owner,
            "reason": rule.reason,
            "disposition": rule.disposition,
            "files": {path: item.count for path, item in sorted(findings[rule.key].items())},
        }
    return {"version": 1, "tracking": tracking, "rules": rules}


def load_allowlist(path: Path) -> dict[str, object]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise ValueError(f"allowlist is missing: {path}") from error
    except json.JSONDecodeError as error:
        raise ValueError(f"allowlist is invalid JSON: {error}") from error
    if document.get("version") != 1:
        raise ValueError("allowlist version must be 1")
    if not document.get("tracking"):
        raise ValueError("allowlist requires a tracking issue or PR")
    if not isinstance(document.get("rules"), dict):
        raise ValueError("allowlist rules must be an object")
    return document


def compare_findings(
    findings: dict[str, dict[str, Finding]], allowlist: dict[str, object]
) -> list[str]:
    errors: list[str] = []
    allowed_rules = allowlist["rules"]
    assert isinstance(allowed_rules, dict)
    for rule_key, current_files in findings.items():
        rule = RULE_BY_KEY[rule_key]
        allowed = allowed_rules.get(rule_key)
        if not isinstance(allowed, dict):
            errors.append(f"NEW RULE DEBT [{rule_key}] no allowlist section")
            allowed_files: dict[str, object] = {}
        else:
            expected_metadata = {
                "pattern": rule.pattern,
                "owner": rule.owner,
                "reason": rule.reason,
                "disposition": rule.disposition,
            }
            for field, expected in expected_metadata.items():
                if allowed.get(field) != expected:
                    errors.append(
                        f"INVALID ALLOWLIST [{rule_key}] {field} must match the rule definition"
                    )
            if not isinstance(allowed.get("files"), dict):
                errors.append(f"INVALID ALLOWLIST [{rule_key}] files must be an object")
            raw_files = allowed.get("files", {})
            allowed_files = raw_files if isinstance(raw_files, dict) else {}

        for path, finding in sorted(current_files.items()):
            expected = allowed_files.get(path)
            location = f"{path}:{','.join(str(line) for line in finding.lines[:8])}"
            if expected is None:
                errors.append(
                    f"NEW DEBT [{rule_key}] {location} has {finding.count} occurrence(s): {rule.pattern}"
                )
            elif not isinstance(expected, int) or expected < 1:
                errors.append(f"INVALID ALLOWLIST [{rule_key}] {path} count must be a positive integer")
            elif finding.count > expected:
                errors.append(
                    f"INCREASED DEBT [{rule_key}] {location}: {expected} -> {finding.count} occurrence(s)"
                )
            elif finding.count < expected:
                errors.append(
                    f"STALE ALLOWLIST [{rule_key}] {path}: {expected} -> {finding.count}; reduce the budget"
                )

        for path, expected in sorted(allowed_files.items()):
            if path not in current_files:
                errors.append(
                    f"STALE ALLOWLIST [{rule_key}] {path}: {expected} -> 0; remove the entry"
                )
    return errors


def selected_rules(args: argparse.Namespace) -> tuple[str, ...]:
    selected: set[str] = set(args.rule or ())
    for shortcut, rule_keys in SHORTCUTS.items():
        if getattr(args, shortcut):
            selected.update(rule_keys)
    return tuple(sorted(selected or RULE_BY_KEY))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allowlist", type=Path, default=DEFAULT_ALLOWLIST)
    parser.add_argument("--rule", action="append", choices=sorted(RULE_BY_KEY))
    parser.add_argument("--print-baseline", action="store_true")
    parser.add_argument("--tracking", default="https://github.com/sploithunter/HaloAndHorns/issues/3")
    for shortcut in SHORTCUTS:
        parser.add_argument(f"--{shortcut}", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    chosen = selected_rules(args)
    findings = collect_findings(ROOT, chosen)
    if args.print_baseline:
        print(json.dumps(baseline_document(findings, args.tracking), indent=2, sort_keys=True))
        return 0

    try:
        allowlist = load_allowlist(args.allowlist)
    except ValueError as error:
        print(f"architecture: {error}")
        return 1

    errors = compare_findings(findings, allowlist)
    total = sum(item.count for files in findings.values() for item in files.values())
    print(f"architecture: checked {len(findings)} rule(s), {total} allowlisted occurrence(s)")
    for rule_key in chosen:
        files = findings.get(rule_key, {})
        count = sum(item.count for item in files.values())
        print(f"  {rule_key}: {count} occurrence(s) across {len(files)} file(s)")
    if errors:
        for error in errors:
            print(f"architecture: {error}")
        print("architecture: failed; migrate the new debt or deliberately update the reviewed baseline")
        return 1
    print("architecture: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
