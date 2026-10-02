#!/usr/bin/env python3
"""Phase 5 checker for the AHK v2 grading harness (result contract @2).

Reads harness NDJSON and decides which results are trustworthy enough to reach
synthesis. A result is dropped when it is unreadable, incomplete, timed out, or
contradicts another result about the same script in the same run. Cross-result
problems withhold only the offending rows, so a legitimate gate result still
reaches synthesis when a stray later-tier row is flagged.

The point is that a fix loop is only as good as the evidence feeding it. A
result that says "fail" without saying why, or a pass produced by a tool that
crashed, will generate a confident fix for a problem nobody can reproduce.

Contract @2 rows carry schema "ahk-harness/result@2". A row written under the
older @1 contract is flagged for a re-run with the current gates rather than
judged against fields its gates never emitted; any other schema is wrong. All
four tiers are built, gating in order static -> pure -> dryrun -> live, and
each non-static tier adds fields that are checked for presence and type. A
missing or ill-typed field is a flag that names it (nested keys as
"guard.focus", "assertions.failed"):

    dryrun  residency  exited | idle | wedged ("unknown" only when status is
                       error: the child never ran or its exit was unobservable)
            actions    int >= 0, intercepted call count
            intent     object, kind -> int >= 0
            guard      object: clipboard untouched | restored | restore-failed,
                       dialogs int >= 0, windows int >= 0, focus kept | stolen
    pure    tests      int >= 0, test files run
            assertions object: passed int >= 0, failed int >= 0
    live    drift      object, or the string "unknown"
            backend    object: name str, verdict str

A pure row that passes with failed assertions, or reports assertions from zero
test files, contradicts itself and is flagged. A pure row that passed after
running zero test files is honest: the script has no unit tests. That is a
coverage gap, not a flag, so it is reported beside the verdict in text mode
and as "uncovered" (script paths) in --json, and never changes the exit code.

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

SCHEMA = "ahk-harness/result@2"
# Rows from an earlier contract are not garbage: they came from gates that
# predate the current fields, so the remedy is a re-run, not a bug hunt.
OLDER_SCHEMAS = ("ahk-harness/result@1",)
SENTINEL = "AHKHARNESS-END"
REQUIRED = ("schema", "script", "tier", "status", "checks", "findings")
STATUSES = ("pass", "fail", "error", "timeout")

# Tiers in gate order. A branch that fails at one tier should not have results
# from a later one.
TIER_ORDER = ("static", "pure", "dryrun", "live")

RESIDENCY = ("exited", "idle", "wedged")
GUARD_CLIPBOARD = ("untouched", "restored", "restore-failed")
GUARD_FOCUS = ("kept", "stolen")


def load(paths):
    """Yield (source, lineno, raw, obj-or-None, error-or-None) for every
    non-blank line. lineno 0 marks a file-level failure."""
    for path in paths:
        try:
            # utf-8-sig: Windows tools (PowerShell 5, AutoHotkey's "UTF-8"
            # FileAppend) prepend a BOM when they save a captured stream. A BOM
            # says nothing about the results, so it must not flag line 1.
            stream = sys.stdin if path == "-" else open(path, encoding="utf-8-sig")
        except OSError as exc:
            yield (path, 0, "", None, f"cannot open: {exc}")
            continue
        with stream if path != "-" else _null_ctx(stream):
            try:
                for lineno, raw in enumerate(stream, 1):
                    raw = raw.strip()
                    if not raw:
                        continue
                    try:
                        yield (path, lineno, raw, json.loads(raw), None)
                    except json.JSONDecodeError as exc:
                        yield (path, lineno, raw, None, f"unparseable JSON: {exc}")
            except (OSError, UnicodeDecodeError) as exc:
                # Undecodable bytes leave the rest of the file unreadable, not
                # one row wrong: the checker's own input failed, which is a
                # tool error like a file that cannot be opened.
                yield (path, 0, "", None, f"cannot read: {exc}")


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


def _group_key(value):
    """A dict or list where an id belongs is unhashable; it must not crash the
    grouping, so it is keyed by its JSON text instead."""
    try:
        hash(value)
    except TypeError:
        return json.dumps(value, sort_keys=True)
    return value


def _count(value):
    """A JSON integer >= 0. bool is excluded: json gives True for `true`, and
    True would otherwise pass as the integer 1."""
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _is_object(value):
    return isinstance(value, dict)


def _is_str(value):
    return isinstance(value, str)


def _one_of(allowed):
    return lambda value: isinstance(value, str) and value in allowed


def _short(value):
    text = repr(value)
    return text if len(text) <= 80 else text[:77] + "..."


def _require(out, tier, holder, name, ok, want, prefix=""):
    """Flag a missing or ill-typed tier field, naming it. True when it is fine,
    so a caller only inspects the inside of a value that has the right shape."""
    label = prefix + name
    if name not in holder:
        out.append(f"missing required {tier} field {label!r}")
        return False
    if not ok(holder[name]):
        out.append(f"{tier} field {label!r} must be {want}, got {_short(holder[name])}")
        return False
    return True


def dryrun_flags(obj):
    """The dry-run extras. Every one is present on every dryrun row, early
    errors included, so a consumer never has to tell absent from empty."""
    out = []
    if "residency" not in obj:
        out.append("missing required dryrun field 'residency'")
    elif obj["residency"] == "unknown":
        # "unknown" means the child never ran or its exit was unobservable — a
        # tool failure. On a row with a real outcome it hides that outcome.
        if obj.get("status") != "error":
            out.append(f"dryrun field 'residency' is 'unknown' on a {obj.get('status')!r} "
                       "row — allowed only when status is 'error'")
    elif not _one_of(RESIDENCY)(obj["residency"]):
        out.append(f"dryrun field 'residency' must be one of {'/'.join(RESIDENCY)}, "
                   f"got {_short(obj['residency'])}")
    _require(out, "dryrun", obj, "actions", _count, "a non-negative integer")
    if _require(out, "dryrun", obj, "intent", _is_object, "an object of kind -> count"):
        for kind, total in obj["intent"].items():
            if not _count(total):
                out.append(f"dryrun field 'intent.{kind}' must be a non-negative "
                           f"integer, got {_short(total)}")
    if _require(out, "dryrun", obj, "guard", _is_object, "an object"):
        guard = obj["guard"]
        _require(out, "dryrun", guard, "clipboard", _one_of(GUARD_CLIPBOARD),
                 "one of " + "/".join(GUARD_CLIPBOARD), "guard.")
        _require(out, "dryrun", guard, "dialogs", _count, "a non-negative integer", "guard.")
        _require(out, "dryrun", guard, "windows", _count, "a non-negative integer", "guard.")
        _require(out, "dryrun", guard, "focus", _one_of(GUARD_FOCUS),
                 "one of " + "/".join(GUARD_FOCUS), "guard.")
    return out


def pure_flags(obj):
    """The pure-tier extras, then the two ways a pure row can contradict
    itself. Zero tests with a pass is deliberately absent: that is a script
    with no unit tests, reported as coverage, not a broken result."""
    out = []
    tests_ok = _require(out, "pure", obj, "tests", _count,
                        "a non-negative integer (test files run)")
    counts_ok = False
    if _require(out, "pure", obj, "assertions", _is_object,
                "an object with integer 'passed' and 'failed'"):
        assertions = obj["assertions"]
        passed_ok = _require(out, "pure", assertions, "passed", _count,
                             "a non-negative integer", "assertions.")
        failed_ok = _require(out, "pure", assertions, "failed", _count,
                             "a non-negative integer", "assertions.")
        counts_ok = passed_ok and failed_ok
    if not counts_ok:
        return out
    passed = obj["assertions"]["passed"]
    failed = obj["assertions"]["failed"]
    if obj.get("status") == "pass" and failed > 0:
        out.append(f"status 'pass' but {failed} assertion(s) failed")
    if tests_ok and obj["tests"] == 0 and passed + failed > 0:
        out.append(f"ran 0 test files but reported {passed + failed} assertion(s)")
    return out


def live_flags(obj):
    """The live extras. Without drift a live failure cannot be attributed to
    the script; without backend nobody can tell which input path judged it."""
    out = []
    _require(out, "live", obj, "drift",
             lambda value: isinstance(value, dict) or value == "unknown",
             "an object or 'unknown'")
    if _require(out, "live", obj, "backend", _is_object,
                "an object with string 'name' and 'verdict'"):
        backend = obj["backend"]
        _require(out, "live", backend, "name", _is_str, "a string", "backend.")
        _require(out, "live", backend, "verdict", _is_str, "a string", "backend.")
    return out


TIER_FIELDS = {"dryrun": dryrun_flags, "pure": pure_flags, "live": live_flags}


def structural_flags(obj):
    """Problems visible in one result on its own."""
    if not isinstance(obj, dict):
        return [f"result is not a JSON object (got {type(obj).__name__})"]
    out = []
    schema = obj.get("schema")
    if schema in OLDER_SCHEMAS:
        out.append("older contract version — re-run with the current gates "
                   f"(got {schema!r}, expected {SCHEMA!r})")
    elif schema != SCHEMA:
        out.append(f"wrong schema: {schema!r} (expected {SCHEMA!r})")
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

    # Shape before content: the rules below index into these, and a script
    # that is a list or a checks value that is a string would otherwise crash
    # the checker on data — which the contract says is a flag, never a tool
    # error.
    if not isinstance(obj.get("script"), str):
        out.append(f"field 'script' must be a string, got {_short(obj.get('script'))}")
    if not isinstance(checks, list) or not all(isinstance(c, dict) for c in checks):
        out.append("field 'checks' must be a list of objects")
        checks = [c for c in checks if isinstance(c, dict)] if isinstance(checks, list) else []
    if not isinstance(findings, list) or not all(isinstance(f, dict) for f in findings):
        out.append("field 'findings' must be a list of objects")
        findings = [f for f in findings if isinstance(f, dict)] if isinstance(findings, list) else []

    tier = obj.get("tier")
    if tier not in TIER_ORDER:
        # A misspelled or case-variant tier would match nothing downstream and
        # slip past every gap, branch and drift rule.
        out.append(f"unknown tier {tier!r} — expected one of {'/'.join(TIER_ORDER)}")
    if status not in STATUSES:
        # Same hazard as an unknown tier: "Pass" or "skipped" matches neither
        # passed() nor failed(), so the branch, drift and assertion rules
        # would all wave it through.
        out.append(f"unknown status {status!r} — expected one of {'/'.join(STATUSES)}")

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

    tier_rule = TIER_FIELDS.get(tier) if isinstance(tier, str) else None
    if tier_rule:
        out.extend(tier_rule(obj))
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


def uncovered_scripts(clean):
    """Scripts whose pure tier passed after running zero test files: no unit
    tests exist for them. Computed over surviving rows only, so a withheld row
    never speaks for coverage either way, and a script that ran tests in any
    surviving row is covered. Paths keep their first emitted spelling."""
    zero, covered, order = {}, set(), []
    for obj in clean:
        if obj.get("tier") != "pure":
            continue
        key = script_key(obj.get("script"))
        if obj.get("tests") == 0 and obj.get("status") == "pass":
            if key not in zero:
                zero[key] = obj.get("script")
                order.append(key)
        elif obj.get("tests", 0) > 0:
            covered.add(key)
    return [zero[key] for key in order if key not in covered]


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
            script = obj.get("script") if isinstance(obj, dict) else None
            flagged.append({"where": where, "script": script, "reasons": problems})
            continue
        run = _group_key(obj.get("run"))
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

    uncovered = uncovered_scripts(clean)
    if args.json:
        print(json.dumps({"clean": len(clean), "flagged": flagged,
                          "uncovered": uncovered}, indent=2))
    else:
        if flagged and not args.quiet:
            print(f"FLAGGED {len(flagged)} result(s) — withheld from synthesis\n")
            for item in flagged:
                name = str(item["script"] or "?").split("\\")[-1]
                print(f"  {item['where']}  {name}")
                for reason in item["reasons"]:
                    print(f"      - {reason}")
            print()
        if uncovered and not args.quiet:
            print(f"{len(uncovered)} script(s) have no unit tests (pure tier ran 0 tests)")
        print(f"{len(clean)} clean, {len(flagged)} flagged")

    if tool_error:
        return 2
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main())
