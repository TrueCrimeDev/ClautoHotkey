#!/usr/bin/env python3
"""Phase 5 checker for the AHK v2 grading harness.

Reads harness NDJSON and decides which results are trustworthy enough to reach
synthesis. A result is dropped when it is unreadable, incomplete, timed out, or
contradicts another result about the same script in the same run. Cross-result
problems withhold only the offending rows, so a legitimate gate result still
reaches synthesis when a stray later-tier row is flagged.

The point is that a fix loop is only as good as the evidence feeding it. A
result that says "fail" without saying why, or a pass produced by a tool that
crashed, will generate a confident fix for a problem nobody can reproduce.

    CheckResults.py <results.ndjson> [more.ndjson ...] [--out clean.ndjson]
                    [--json] [--quiet]

Exit codes: 0 = every result survived, 1 = at least one result flagged,
2 = usage or tool error (bad arguments, unreadable input file, unwritable
--out). Data problems inside a readable file are flags (exit 1), not errors.
"""

import argparse
import json
import ntpath
import sys
from collections import defaultdict

SCHEMA = "ahk-harness/result@1"
SENTINEL = "AHKHARNESS-END"
REQUIRED = ("schema", "script", "tier", "status", "checks", "findings")

# Tiers in gate order. A branch that fails at one tier should not have results
# from a later one.
TIER_ORDER = ("static", "pure", "dryrun", "live")


def load(paths):
    """Yield (source, lineno, raw, obj-or-None) for every non-blank line."""
    for path in paths:
        try:
            stream = sys.stdin if path == "-" else open(path, encoding="utf-8")
        except OSError as exc:
            yield (path, 0, "", None, f"cannot open: {exc}")
            continue
        with stream if path != "-" else _null_ctx(stream):
            for lineno, raw in enumerate(stream, 1):
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    yield (path, lineno, raw, json.loads(raw), None)
                except json.JSONDecodeError as exc:
                    yield (path, lineno, raw, None, f"unparseable JSON: {exc}")


class _null_ctx:
    def __init__(self, obj):
        self.obj = obj

    def __enter__(self):
        return self.obj

    def __exit__(self, *a):
        return False


def script_key(path):
    """Grouping key for a script path. Windows paths are case-insensitive and
    slash-agnostic, so the key is normalised; output keeps the original string."""
    if not isinstance(path, str):
        return path
    return ntpath.normpath(path).casefold()


def structural_flags(obj):
    """Problems visible in one result on its own."""
    out = []
    if obj.get("schema") != SCHEMA:
        out.append(f"wrong schema: {obj.get('schema')!r} (expected {SCHEMA!r})")
    if obj.get("sentinel") != SENTINEL:
        # A truncated write loses the tail of the object, so the sentinel is
        # the cheapest proof the emitter finished what it started.
        out.append("missing end sentinel — result may be truncated")
    for field in REQUIRED:
        if field not in obj:
            out.append(f"missing required field {field!r}")
    if out:
        return out

    status = obj.get("status")
    checks = obj.get("checks") or []
    findings = obj.get("findings") or []

    tier = obj.get("tier")
    if tier not in TIER_ORDER:
        # A misspelled or case-variant tier would match nothing downstream and
        # slip past every gap, branch and drift rule.
        out.append(f"unknown tier {tier!r} — expected one of {'/'.join(TIER_ORDER)}")

    if status == "timeout":
        # Recorded, never silently dropped from the denominator.
        out.append("timed out — counts as a failed result, not a skip")
    if not checks:
        out.append("empty result: no checks ran")
    if status == "fail" and not findings:
        out.append("failed with no findings — nothing actionable to synthesise")
    if status == "error":
        broken = [c.get("name") for c in checks if c.get("status") == "error"]
        out.append("tool error in: " + (", ".join(map(str, broken)) or "unknown"))

    for check in checks:
        if check.get("status") != "pass":
            continue
        code = check.get("exit")
        if code in (0, None):
            continue
        if code == 124 and check.get("name") == "execute":
            # Contracted outcome, not a contradiction: an idle persistent
            # script killed at the deadline while its message loop still
            # answered counts as a pass.
            continue
        out.append(f"check {check.get('name')!r} says pass but exited {code}")
    return out


def cross_flags(group, tiers_present_in_run=frozenset()):
    """Problems only visible by comparing results about the same script within
    one run. Returns (obj, reason) pairs: only the offending rows are withheld,
    so a legitimate earlier-tier result still reaches synthesis when a stray
    later-tier row is flagged."""
    out = []
    by_tier = defaultdict(list)
    for obj in group:
        by_tier[obj.get("tier")].append(obj)

    for tier, objs in by_tier.items():
        statuses = {o.get("status") for o in objs}
        if len(statuses) > 1:
            reason = f"tier {tier!r} reported more than one status: {sorted(statuses)}"
            out.extend((o, reason) for o in objs)

    def passed(tier):
        return any(o.get("status") == "pass" for o in by_tier.get(tier, []))

    def failed(tier):
        return any(o.get("status") in ("fail", "timeout") for o in by_tier.get(tier, []))

    # The contradiction worth catching: the script behaved in dry run and broke
    # under live input. That is either a real input-timing defect or the target
    # UI moved under it. Without a drift note there is no way to tell, and
    # attributing it to the script is a guess.
    if passed("dryrun") and failed("live"):
        live = by_tier.get("live", [])
        if not any(o.get("drift") not in (None, "", "unknown") for o in live):
            reason = (
                "dry-run passed but live failed with no selector-drift snapshot — "
                "cannot attribute to the script"
            )
            out.extend((o, reason) for o in live)

    first_fail = next((i for i, t in enumerate(TIER_ORDER) if failed(t)), None)

    # A later-tier result for a script with no earlier-tier evidence is
    # unverifiable: the branch either skipped its gate or its gate result was
    # lost. Every present tier is examined, so a missing middle tier is caught
    # too. Only tiers the run demonstrably covered are demanded, so a
    # deliberate single-tier run is not flagged wholesale. Tiers past the
    # first failure are strays — the branch-end rule below flags those rows,
    # and tiers that never ran after the failure are correctly absent.
    for i, tier in enumerate(TIER_ORDER):
        objs = by_tier.get(tier)
        if not objs:
            continue
        if first_fail is not None and i > first_fail:
            continue
        missing = [
            earlier for earlier in TIER_ORDER[:i]
            if earlier in tiers_present_in_run and not by_tier.get(earlier)
        ]
        if missing:
            reason = (
                f"tier {tier!r} reported but {missing} missing for this script — "
                "ran without its gate, or the gate result was lost"
            )
            out.extend((o, reason) for o in objs)

    # A branch is supposed to end at its first failing tier; anything after it
    # is a stray. Only the stray rows are withheld — the failing result itself
    # is legitimate evidence.
    if first_fail is not None:
        gate = TIER_ORDER[first_fail]
        for tier in TIER_ORDER[first_fail + 1:]:
            for obj in by_tier.get(tier, []):
                out.append((obj, f"tier {gate!r} failed but tier {tier!r} still "
                                 "reported — branch should have ended"))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description="Check harness NDJSON results.")
    ap.add_argument("paths", nargs="+", help="NDJSON files, or - for stdin")
    ap.add_argument("--out", help="write surviving results here as NDJSON")
    ap.add_argument("--json", action="store_true", help="emit the report as JSON")
    ap.add_argument("--quiet", action="store_true", help="only print the verdict")
    args = ap.parse_args(argv)

    flagged, clean, groups = [], [], defaultdict(list)
    run_tiers = defaultdict(set)
    tool_error = False

    for path, lineno, raw, obj, err in load(args.paths):
        where = f"{path}:{lineno}"
        if err:
            if lineno == 0:
                # File-level failure: the checker could not read its own input.
                print(f"{path}: {err}", file=sys.stderr)
                tool_error = True
            else:
                flagged.append({"where": where, "script": None, "reasons": [err],
                                "raw": raw[:300]})
            continue
        problems = structural_flags(obj)
        if problems:
            flagged.append({"where": where, "script": obj.get("script"),
                            "reasons": problems})
            continue
        run = obj.get("run")
        groups[(run, script_key(obj.get("script")))].append((where, obj))
        run_tiers[run].add(obj.get("tier"))

    for (run, _key), entries in groups.items():
        bad = {}
        for obj, reason in cross_flags([o for _, o in entries], run_tiers[run]):
            bad.setdefault(id(obj), []).append(reason)
        for where, obj in entries:
            reasons = bad.get(id(obj))
            if reasons:
                flagged.append({"where": where, "script": obj.get("script"),
                                "reasons": reasons})
            else:
                clean.append(obj)

    if args.out:
        try:
            with open(args.out, "w", encoding="utf-8") as fh:
                for obj in clean:
                    fh.write(json.dumps(obj, ensure_ascii=False) + "\n")
        except OSError as exc:
            print(f"cannot write {args.out}: {exc}", file=sys.stderr)
            return 2

    if args.json:
        print(json.dumps({"clean": len(clean), "flagged": flagged}, indent=2))
    else:
        if flagged and not args.quiet:
            print(f"FLAGGED {len(flagged)} result(s) — withheld from synthesis\n")
            for item in flagged:
                name = (item["script"] or "?").split("\\")[-1]
                print(f"  {item['where']}  {name}")
                for reason in item["reasons"]:
                    print(f"      - {reason}")
            print()
        print(f"{len(clean)} clean, {len(flagged)} flagged")

    if tool_error:
        return 2
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main())
