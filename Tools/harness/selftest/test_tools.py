#!/usr/bin/env python3
"""Self-tests for the harness's Python side: CheckResults.py and Report.py.

Run from ClautoHotkey/:

    python Tools/harness/selftest/test_tools.py

Every fixture is built by the test that needs it, inside a temporary
directory, so the suite reads and writes nothing outside those directories.
Bytecode writing is switched off so importing the tools leaves no __pycache__
next to them.
"""

import contextlib
import hashlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
HARNESS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HARNESS not in sys.path:
    sys.path.insert(0, HARNESS)

import CheckResults  # noqa: E402
import Report  # noqa: E402

SCRIPT_A = "C:\\Scripts\\a.ahk"
SCRIPT_B = "C:\\Scripts\\b.ahk"

# Marks a field make_row should leave out entirely.
DROP = object()


def finding(severity="high", rule="empty-catch", line=3,
            message="Empty catch block swallows the error", source="lint",
            confidence="full"):
    return {"severity": severity, "rule": rule, "line": line, "source": source,
            "confidence": confidence, "message": message}


def valid_guard(**overrides):
    guard = {"clipboard": "untouched", "dialogs": 0, "windows": 0, "focus": "kept"}
    guard.update(overrides)
    return guard


def make_row(tier="static", status="pass", script=SCRIPT_A, run="run-1", **fields):
    """A row that satisfies contract @2 for its tier and status. Keyword
    arguments replace or add fields; a field given as DROP is removed."""
    row = {
        "schema": CheckResults.SCHEMA,
        "run": run,
        "label": f"{tier}-1",
        "tier": tier,
        "script": script,
        "name": script.replace("/", "\\").split("\\")[-1] if isinstance(script, str) else "",
        "parse": "clean" if tier == "static" else "not-parsed",
        "status": status,
        "ms": 250,
        "checks": [{"name": "check", "status": "pass", "exit": 0, "ms": 5,
                    "detail": "CHECK PASS"}],
        "findings": [finding()] if status == "fail" else [],
        "counts": {"critical": 0, "high": 0, "medium": 0, "low": 0},
        "sentinel": CheckResults.SENTINEL,
    }
    if tier == "dryrun":
        row.update({"residency": "exited", "actions": 2, "intent": {"input": 1, "fs": 1},
                    "guard": valid_guard()})
    elif tier == "pure":
        row.update({"tests": 1, "assertions": {"passed": 4, "failed": 0}})
        if status == "fail":
            row["assertions"] = {"passed": 3, "failed": 1}
    elif tier == "live":
        row.update({"drift": {"selectors": 3, "moved": 0},
                    "backend": {"name": "uia", "verdict": "ok"}})
    if status == "error":
        row["checks"] = [{"name": "launch", "status": "error", "exit": -1, "ms": 0,
                          "detail": "launch failed: file not found"}]
        if tier == "dryrun":
            row["residency"] = "unknown"
    if status == "timeout":
        row["checks"] = [{"name": "execute", "status": "fail", "exit": 137, "ms": 30000,
                          "detail": "residency=wedged actions=0"}]
        row["findings"] = [finding("critical", "hung", 0,
                                   "no response for 30 s — hard killed; message loop blocked",
                                   "dryrun")]
        if tier == "dryrun":
            row["residency"] = "wedged"
    row.update(fields)
    for key in [k for k, v in row.items() if v is DROP]:
        del row[key]
    return row


def flags(row):
    return CheckResults.structural_flags(row)


def call(func, argv):
    """Run a tool's main() in-process, capturing stdout and stderr."""
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = func(argv)
    return code, out.getvalue(), err.getvalue()


class FlagAssertions(object):
    def assertFlag(self, reasons, needle):
        self.assertTrue(any(needle in reason for reason in reasons),
                        f"{needle!r} not among {reasons}")

    def assertNoFlag(self, reasons, needle):
        self.assertFalse(any(needle in reason for reason in reasons),
                         f"{needle!r} unexpectedly among {reasons}")


class TempDirCase(unittest.TestCase, FlagAssertions):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = self._tmp.name

    def path(self, *parts):
        return os.path.join(self.tmp, *parts)

    def write_ndjson(self, name, rows):
        """Rows are dicts (written as JSON) or strings (written verbatim)."""
        path = self.path(name)
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            for row in rows:
                fh.write((row if isinstance(row, str) else json.dumps(row)) + "\n")
        return path


class CheckerStructuralTests(unittest.TestCase, FlagAssertions):
    def test_valid_rows_of_every_tier_pass(self):
        for tier in CheckResults.TIER_ORDER:
            for status in ("pass", "fail"):
                with self.subTest(tier=tier, status=status):
                    self.assertEqual(flags(make_row(tier, status)), [])

    def test_contract_version_is_two(self):
        self.assertEqual(CheckResults.SCHEMA, "ahk-harness/result@2")

    def test_wrong_schema(self):
        reasons = flags(make_row(schema="ahk-harness/result@9"))
        self.assertFlag(reasons, "wrong schema: 'ahk-harness/result@9'")

    def test_older_contract_version_asks_for_a_rerun(self):
        reasons = flags(make_row(schema="ahk-harness/result@1"))
        self.assertFlag(reasons, "older contract version — re-run with the current gates")
        self.assertNoFlag(reasons, "wrong schema")

    def test_older_rows_are_not_judged_on_fields_their_gates_never_had(self):
        row = make_row("dryrun", schema="ahk-harness/result@1", guard=DROP)
        self.assertEqual(len(flags(row)), 1, flags(row))

    def test_missing_or_wrong_sentinel(self):
        for sentinel in (DROP, "AHKHARNESS-EN"):
            with self.subTest(sentinel=sentinel):
                self.assertFlag(flags(make_row(sentinel=sentinel)), "missing end sentinel")

    def test_each_required_field_is_named(self):
        for field in CheckResults.REQUIRED:
            with self.subTest(field=field):
                reasons = flags(make_row(**{field: DROP}))
                self.assertFlag(reasons, f"missing required field {field!r}")

    def test_unknown_tier(self):
        self.assertFlag(flags(make_row(tier="Static")), "unknown tier 'Static'")

    def test_unknown_status(self):
        self.assertFlag(flags(make_row(status="skipped")), "unknown status 'skipped'")

    def test_non_object_row_is_a_flag(self):
        self.assertFlag(flags([1, 2]), "result is not a JSON object")

    def test_malformed_shapes_are_flags_not_crashes(self):
        cases = [
            ({"script": ["a.ahk"]}, "field 'script' must be a string"),
            ({"checks": "check"}, "field 'checks' must be a list of objects"),
            ({"checks": [1]}, "field 'checks' must be a list of objects"),
            ({"findings": {"rule": "x"}}, "field 'findings' must be a list of objects"),
        ]
        for override, needle in cases:
            with self.subTest(override=override):
                self.assertFlag(flags(make_row(**override)), needle)

    def test_timeout_is_a_failed_result(self):
        reasons = flags(make_row("dryrun", "timeout"))
        self.assertFlag(reasons, "timed out — counts as a failed result, not a skip")

    def test_empty_checks(self):
        self.assertFlag(flags(make_row(checks=[])), "empty result: no checks ran")

    def test_fail_without_findings(self):
        reasons = flags(make_row(status="fail", findings=[]))
        self.assertFlag(reasons, "failed with no findings — nothing actionable to synthesise")

    def test_tool_error_names_the_broken_check(self):
        self.assertFlag(flags(make_row(status="error")), "tool error in: launch")

    def test_tool_error_without_a_broken_check(self):
        row = make_row(status="error", checks=[{"name": "check", "status": "pass", "exit": 0}])
        self.assertFlag(flags(row), "tool error in: unknown")

    def test_passing_check_with_nonzero_exit(self):
        row = make_row(checks=[{"name": "check", "status": "pass", "exit": 2}])
        self.assertFlag(flags(row), "check 'check' says pass but exited 2")

    def test_execute_exit_124_is_the_idle_pass(self):
        row = make_row("dryrun", residency="idle",
                       checks=[{"name": "execute", "status": "pass", "exit": 124}])
        self.assertEqual(flags(row), [])

    def test_exit_124_outside_execute_is_a_contradiction(self):
        row = make_row(checks=[{"name": "lint", "status": "pass", "exit": 124}])
        self.assertFlag(flags(row), "check 'lint' says pass but exited 124")

    def test_execute_exit_137_marked_pass_is_a_contradiction(self):
        row = make_row("dryrun", checks=[{"name": "execute", "status": "pass", "exit": 137}])
        self.assertFlag(flags(row), "check 'execute' says pass but exited 137")


class CheckerDryrunTests(unittest.TestCase, FlagAssertions):
    def test_each_missing_field_is_named(self):
        for field in ("residency", "actions", "intent", "guard"):
            with self.subTest(field=field):
                reasons = flags(make_row("dryrun", **{field: DROP}))
                self.assertFlag(reasons, f"missing required dryrun field {field!r}")

    def test_each_missing_guard_key_is_named(self):
        for key in ("clipboard", "dialogs", "windows", "focus"):
            with self.subTest(key=key):
                guard = valid_guard()
                del guard[key]
                reasons = flags(make_row("dryrun", guard=guard))
                self.assertFlag(reasons, f"missing required dryrun field 'guard.{key}'")

    def test_ill_typed_fields_are_named(self):
        cases = [
            ({"actions": "3"}, "'actions'"),
            ({"actions": True}, "'actions'"),
            ({"actions": -1}, "'actions'"),
            ({"actions": 2.0}, "'actions'"),
            ({"intent": []}, "'intent'"),
            ({"intent": {"input": "2"}}, "'intent.input'"),
            ({"guard": "kept"}, "'guard'"),
            ({"guard": valid_guard(clipboard="wiped")}, "'guard.clipboard'"),
            ({"guard": valid_guard(dialogs=1.5)}, "'guard.dialogs'"),
            ({"guard": valid_guard(windows=None)}, "'guard.windows'"),
            ({"guard": valid_guard(focus="lost")}, "'guard.focus'"),
            ({"residency": "running"}, "'residency'"),
        ]
        for override, field in cases:
            with self.subTest(override=override):
                reasons = flags(make_row("dryrun", **override))
                self.assertFlag(reasons, f"dryrun field {field} must be")

    def test_every_documented_value_is_accepted(self):
        for residency in CheckResults.RESIDENCY:
            with self.subTest(residency=residency):
                self.assertEqual(flags(make_row("dryrun", residency=residency)), [])
        for clipboard in CheckResults.GUARD_CLIPBOARD:
            for focus in CheckResults.GUARD_FOCUS:
                with self.subTest(clipboard=clipboard, focus=focus):
                    row = make_row("dryrun", guard=valid_guard(clipboard=clipboard, focus=focus,
                                                               dialogs=2, windows=1))
                    self.assertEqual(flags(row), [])
        self.assertEqual(flags(make_row("dryrun", actions=0, intent={})), [])

    def test_unknown_residency_is_only_allowed_on_error_rows(self):
        reasons = flags(make_row("dryrun", residency="unknown"))
        self.assertFlag(reasons, "is 'unknown' on a 'pass' row")
        reasons = flags(make_row("dryrun", "error"))
        self.assertNoFlag(reasons, "residency")
        self.assertFlag(reasons, "tool error in: launch")


class CheckerPureTests(unittest.TestCase, FlagAssertions):
    def test_missing_fields_are_named(self):
        self.assertFlag(flags(make_row("pure", tests=DROP)), "missing required pure field 'tests'")
        self.assertFlag(flags(make_row("pure", assertions=DROP)),
                        "missing required pure field 'assertions'")
        self.assertFlag(flags(make_row("pure", assertions={"failed": 0})),
                        "missing required pure field 'assertions.passed'")
        self.assertFlag(flags(make_row("pure", assertions={"passed": 1})),
                        "missing required pure field 'assertions.failed'")

    def test_ill_typed_fields_are_named(self):
        cases = [
            ({"tests": "1"}, "'tests'"),
            ({"tests": -1}, "'tests'"),
            ({"tests": True}, "'tests'"),
            ({"assertions": []}, "'assertions'"),
            ({"assertions": {"passed": "2", "failed": 0}}, "'assertions.passed'"),
            ({"assertions": {"passed": 2, "failed": -1}}, "'assertions.failed'"),
        ]
        for override, field in cases:
            with self.subTest(override=override):
                self.assertFlag(flags(make_row("pure", **override)), f"pure field {field} must be")

    def test_pass_with_failed_assertions_is_a_contradiction(self):
        reasons = flags(make_row("pure", assertions={"passed": 3, "failed": 2}))
        self.assertFlag(reasons, "status 'pass' but 2 assertion(s) failed")

    def test_fail_with_failed_assertions_is_consistent(self):
        self.assertEqual(flags(make_row("pure", "fail")), [])

    def test_assertions_from_zero_test_files_is_a_contradiction(self):
        reasons = flags(make_row("pure", tests=0, assertions={"passed": 1, "failed": 0}))
        self.assertFlag(reasons, "ran 0 test files but reported 1 assertion(s)")

    def test_zero_tests_with_a_pass_is_not_a_flag(self):
        row = make_row("pure", tests=0, assertions={"passed": 0, "failed": 0})
        self.assertEqual(flags(row), [])


class CheckerLiveTests(unittest.TestCase, FlagAssertions):
    def test_missing_fields_are_named(self):
        self.assertFlag(flags(make_row("live", drift=DROP)), "missing required live field 'drift'")
        self.assertFlag(flags(make_row("live", backend=DROP)),
                        "missing required live field 'backend'")
        self.assertFlag(flags(make_row("live", backend={"verdict": "ok"})),
                        "missing required live field 'backend.name'")
        self.assertFlag(flags(make_row("live", backend={"name": "uia"})),
                        "missing required live field 'backend.verdict'")

    def test_drift_is_an_object_or_unknown(self):
        for drift in (5, "moved", None, []):
            with self.subTest(drift=drift):
                self.assertFlag(flags(make_row("live", drift=drift)),
                                "live field 'drift' must be an object or 'unknown'")
        for drift in ("unknown", {}):
            with self.subTest(drift=drift):
                self.assertEqual(flags(make_row("live", drift=drift)), [])

    def test_backend_fields_are_strings(self):
        self.assertFlag(flags(make_row("live", backend="uia")), "live field 'backend' must be")
        self.assertFlag(flags(make_row("live", backend={"name": 5, "verdict": "ok"})),
                        "live field 'backend.name' must be a string")
        self.assertFlag(flags(make_row("live", backend={"name": "uia", "verdict": None})),
                        "live field 'backend.verdict' must be a string")


class CheckerRunTests(TempDirCase):
    """Cross-result rules, coverage and the command line, through main()."""

    def check(self, rows, *args):
        path = self.write_ndjson("results.ndjson", rows)
        code, out, err = call(CheckResults.main, [path, "--json"] + list(args))
        return code, json.loads(out), err

    @staticmethod
    def by_line(report):
        return {int(item["where"].rsplit(":", 1)[1]): item["reasons"]
                for item in report["flagged"]}

    def test_two_statuses_for_one_tier_in_one_run(self):
        rows = [make_row(status="pass"), make_row(status="fail", label="static-2")]
        code, report, _ = self.check(rows)
        flagged = self.by_line(report)
        self.assertEqual((code, sorted(flagged)), (1, [1, 2]))
        self.assertFlag(flagged[1], "tier 'static' reported more than one status")

    def test_a_leading_byte_order_mark_is_not_a_flag(self):
        # Windows tools that save a captured stream (PowerShell 5,
        # AutoHotkey's "UTF-8" FileAppend) prepend a BOM; it says nothing
        # about the results and must not flag line 1.
        path = self.path("bom.ndjson")
        with open(path, "w", encoding="utf-8-sig", newline="\n") as fh:
            fh.write(json.dumps(make_row()) + "\n")
        code, out, _ = call(CheckResults.main, [path, "--json"])
        report = json.loads(out)
        self.assertEqual((code, report["clean"], report["flagged"]), (0, 1, []))

    def test_same_script_in_two_runs_is_not_a_contradiction(self):
        rows = [make_row(status="pass", run="run-1"), make_row(status="fail", run="run-2")]
        code, report, _ = self.check(rows)
        self.assertEqual((code, report["clean"], report["flagged"]), (0, 2, []))

    def test_script_keys_are_case_and_slash_normalised(self):
        rows = [make_row(script="C:\\Scripts\\A.ahk", status="pass"),
                make_row(script="c:/scripts/a.ahk", status="fail")]
        code, report, _ = self.check(rows)
        self.assertEqual(code, 1)
        self.assertEqual(sorted(self.by_line(report)), [1, 2])
        # Grouping is normalised, the emitted strings are not.
        self.assertEqual({item["script"] for item in report["flagged"]},
                         {"C:\\Scripts\\A.ahk", "c:/scripts/a.ahk"})

    def test_drift_rule_withholds_unattributable_live_failures(self):
        rows = [make_row("static"), make_row("pure"), make_row("dryrun"),
                make_row("live", "fail", drift="unknown")]
        code, report, _ = self.check(rows)
        flagged = self.by_line(report)
        self.assertEqual((code, report["clean"], sorted(flagged)), (1, 3, [4]))
        self.assertFlag(flagged[4], "no selector-drift snapshot")

    def test_drift_snapshot_lets_a_live_failure_through(self):
        rows = [make_row("static"), make_row("pure"), make_row("dryrun"),
                make_row("live", "fail", drift={"selectors": 4, "moved": 1})]
        code, report, _ = self.check(rows)
        self.assertEqual((code, report["clean"]), (0, 4))

    def test_gap_rule_flags_a_tier_reported_without_its_gate(self):
        rows = [make_row("static", script=SCRIPT_A), make_row("dryrun", script=SCRIPT_A),
                make_row("dryrun", script=SCRIPT_B)]
        code, report, _ = self.check(rows)
        flagged = self.by_line(report)
        self.assertEqual((code, sorted(flagged)), (1, [3]))
        self.assertFlag(flagged[3], "tier 'dryrun' reported but ['static'] missing")

    def test_gap_rule_catches_a_missing_middle_tier(self):
        rows = [make_row("static", script=SCRIPT_A), make_row("pure", script=SCRIPT_A),
                make_row("dryrun", script=SCRIPT_A),
                make_row("static", script=SCRIPT_B), make_row("dryrun", script=SCRIPT_B)]
        code, report, _ = self.check(rows)
        flagged = self.by_line(report)
        self.assertEqual((code, sorted(flagged)), (1, [5]))
        self.assertFlag(flagged[5], "['pure'] missing")

    def test_single_tier_run_is_not_a_gap(self):
        rows = [make_row("dryrun", script=SCRIPT_A), make_row("dryrun", script=SCRIPT_B)]
        code, report, _ = self.check(rows)
        self.assertEqual((code, report["clean"]), (0, 2))

    def test_branch_end_strays_are_withheld_and_the_gate_failure_survives(self):
        rows = [make_row("static", "fail"), make_row("dryrun", "pass")]
        code, report, _ = self.check(rows)
        flagged = self.by_line(report)
        self.assertEqual((code, report["clean"], sorted(flagged)), (1, 1, [2]))
        self.assertFlag(flagged[2], "tier 'static' failed but tier 'dryrun' still reported "
                                    "— branch should have ended")

    def test_a_stray_row_gets_only_the_branch_end_reason(self):
        # Script B shows the run covered pure; script A failed static, so its
        # missing pure tier is correct and its dryrun row is a stray, not a gap.
        rows = [make_row("static", script=SCRIPT_B), make_row("pure", script=SCRIPT_B),
                make_row("dryrun", script=SCRIPT_B),
                make_row("static", "fail", script=SCRIPT_A), make_row("dryrun", script=SCRIPT_A)]
        code, report, _ = self.check(rows)
        flagged = self.by_line(report)
        self.assertEqual((code, sorted(flagged)), (1, [5]))
        self.assertEqual(len(flagged[5]), 1, flagged[5])
        self.assertFlag(flagged[5], "branch should have ended")

    def test_a_failed_pure_tier_ends_the_branch(self):
        rows = [make_row("static"), make_row("pure", "fail"), make_row("dryrun"),
                make_row("live")]
        code, report, _ = self.check(rows)
        flagged = self.by_line(report)
        self.assertEqual((code, report["clean"], sorted(flagged)), (1, 2, [3, 4]))
        self.assertFlag(flagged[4], "tier 'pure' failed but tier 'live' still reported")

    def test_tiers_absent_after_a_failure_are_not_flagged(self):
        rows = [make_row("static", "fail", script=SCRIPT_A),
                make_row("static", script=SCRIPT_B), make_row("dryrun", script=SCRIPT_B)]
        code, report, _ = self.check(rows)
        self.assertEqual((code, report["clean"]), (0, 3))

    def test_unparseable_line_is_a_flag_and_blank_lines_are_skipped(self):
        rows = ["", make_row(), "   ", "{not json"]
        code, report, _ = self.check(rows)
        flagged = self.by_line(report)
        self.assertEqual((code, report["clean"], sorted(flagged)), (1, 1, [4]))
        self.assertFlag(flagged[4], "unparseable JSON")

    def test_non_object_line_is_a_flag(self):
        code, report, _ = self.check([make_row(), "[1, 2]"])
        self.assertEqual(code, 1)
        self.assertFlag(self.by_line(report)[2], "result is not a JSON object")

    def test_json_report_shape(self):
        code, report, _ = self.check([make_row()])
        self.assertEqual(code, 0)
        self.assertEqual(sorted(report), ["clean", "flagged", "uncovered"])
        self.assertEqual((report["clean"], report["flagged"], report["uncovered"]), (1, [], []))

    def test_coverage_is_reported_and_never_flagged(self):
        rows = [make_row("static", script=SCRIPT_A),
                make_row("pure", script=SCRIPT_A, tests=0, assertions={"passed": 0, "failed": 0}),
                make_row("static", script=SCRIPT_B),
                make_row("pure", script=SCRIPT_B, tests=2)]
        code, report, _ = self.check(rows)
        self.assertEqual((code, report["clean"], report["uncovered"]), (0, 4, [SCRIPT_A]))

    def test_coverage_text_line(self):
        rows = [make_row("pure", tests=0, assertions={"passed": 0, "failed": 0})]
        path = self.write_ndjson("results.ndjson", rows)
        code, out, _ = call(CheckResults.main, [path])
        self.assertEqual(code, 0)
        lines = out.strip().splitlines()
        self.assertIn("1 script(s) have no unit tests (pure tier ran 0 tests)", lines)
        self.assertEqual(lines[-1], "1 clean, 0 flagged")

    def test_coverage_lists_each_script_once_and_skips_covered_ones(self):
        zero = {"tests": 0, "assertions": {"passed": 0, "failed": 0}}
        rows = [make_row("pure", script="C:\\Scripts\\A.ahk", run="run-1", **zero),
                make_row("pure", script="c:/scripts/a.ahk", run="run-2", **zero),
                make_row("pure", script=SCRIPT_B, run="run-1", **zero),
                make_row("pure", script=SCRIPT_B, run="run-2", tests=3)]
        code, report, _ = self.check(rows)
        self.assertEqual((code, report["uncovered"]), (0, ["C:\\Scripts\\A.ahk"]))

    def test_expected_tiers_name_a_branch_that_stopped_without_failing(self):
        rows = [make_row("static", script=SCRIPT_A), make_row("pure", script=SCRIPT_A),
                make_row("dryrun", script=SCRIPT_A),
                make_row("static", script=SCRIPT_B)]
        code, report, _ = self.check(rows, "--expect-tiers", "static,pure,dryrun")
        self.assertEqual(code, 1)
        self.assertEqual(report["flagged"], [])
        self.assertEqual(report["clean"], 4)
        self.assertEqual(report["unfinished"],
                         [{"script": SCRIPT_B, "run": "run-1", "reached": ["static"],
                           "missing": ["pure", "dryrun"]}])

    def test_a_branch_that_ended_at_a_failure_is_finished(self):
        rows = [make_row("static", script=SCRIPT_A),
                make_row("pure", "fail", script=SCRIPT_A),
                make_row("static", "fail", script=SCRIPT_B)]
        code, report, _ = self.check(rows, "--expect-tiers", "static,pure,dryrun")
        self.assertEqual((code, report["unfinished"]), (0, []))

    def test_a_withheld_row_still_ends_its_branch(self):
        # The dry-run row timed out, so it is flagged and kept from synthesis,
        # but it is the reason there is no live row: nothing is missing.
        rows = [make_row("static"), make_row("pure"), make_row("dryrun", "timeout")]
        code, report, _ = self.check(rows, "--expect-tiers", "static,pure,dryrun,live")
        self.assertEqual((code, len(report["flagged"]), report["unfinished"]), (1, 1, []))

    def test_expected_tiers_are_judged_per_run(self):
        rows = [make_row("static", run="run-1"), make_row("pure", run="run-1"),
                make_row("static", run="run-2")]
        code, report, _ = self.check(rows, "--expect-tiers", "pure,static")
        self.assertEqual(code, 1)
        self.assertEqual([(u["run"], u["missing"]) for u in report["unfinished"]],
                         [("run-2", ["pure"])])

    def test_without_expectations_the_report_and_exit_are_unchanged(self):
        code, report, _ = self.check([make_row("static")])
        self.assertEqual((code, sorted(report)), (0, ["clean", "flagged", "uncovered"]))

    def test_expected_count_reports_scripts_that_never_got_a_row(self):
        rows = [make_row("static", script=SCRIPT_A), make_row("static", script=SCRIPT_B),
                make_row("pure", script="c:/scripts/A.AHK")]
        code, report, _ = self.check(rows, "--expect-count", "3")
        self.assertEqual((code, report["expected"], report["covered"]), (1, 3, 2))
        code, report, _ = self.check(rows, "--expect-count", "2")
        self.assertEqual((code, report["expected"], report["covered"]), (0, 2, 2))

    def test_expectations_in_text_mode(self):
        path = self.write_ndjson("results.ndjson", [make_row("static")])
        code, out, _ = call(CheckResults.main,
                            [path, "--expect-tiers", "static,pure", "--expect-count", "2"])
        self.assertEqual(code, 1)
        self.assertIn("UNFINISHED 1 script(s) passed what they reached but never got to static/pure", out)
        self.assertIn("  a.ahk: reached static; no row for pure", out)
        self.assertIn("COVERAGE the run was handed 2 script(s); results exist for 1", out)
        self.assertEqual(out.strip().splitlines()[-1], "1 clean, 0 flagged")

    def test_an_unknown_expected_tier_is_a_usage_error(self):
        path = self.write_ndjson("results.ndjson", [make_row("static")])
        code, out, err = call(CheckResults.main, [path, "--expect-tiers", "static,dry-run"])
        self.assertEqual(code, 2)
        self.assertIn("unknown tier(s) dry-run", err)

    def test_withheld_rows_never_count_toward_coverage(self):
        rows = [make_row("pure", tests=0, assertions={"passed": 0, "failed": 0}, sentinel=DROP)]
        code, report, _ = self.check(rows)
        self.assertEqual((code, report["uncovered"]), (1, []))

    def test_quiet_prints_only_the_verdict(self):
        rows = [make_row("pure", tests=0, assertions={"passed": 0, "failed": 0}),
                make_row(schema="ahk-harness/result@1")]
        path = self.write_ndjson("results.ndjson", rows)
        code, out, _ = call(CheckResults.main, [path, "--quiet"])
        self.assertEqual((code, out.strip().splitlines()), (1, ["1 clean, 1 flagged"]))

    def test_out_keeps_only_clean_rows(self):
        rows = [make_row(script=SCRIPT_A), make_row(script=SCRIPT_B, schema="ahk-harness/result@1")]
        path = self.write_ndjson("results.ndjson", rows)
        clean_path = self.path("clean.ndjson")
        code, _, _ = call(CheckResults.main, [path, "--out", clean_path, "--quiet"])
        with open(clean_path, encoding="utf-8") as fh:
            kept = [json.loads(line) for line in fh if line.strip()]
        self.assertEqual((code, [row["script"] for row in kept]), (1, [SCRIPT_A]))

    def test_exit_codes(self):
        good = self.write_ndjson("good.ndjson", [make_row()])
        bad = self.write_ndjson("bad.ndjson", [make_row(sentinel=DROP)])
        self.assertEqual(call(CheckResults.main, [good, "--quiet"])[0], 0)
        self.assertEqual(call(CheckResults.main, [bad, "--quiet"])[0], 1)
        code, _, err = call(CheckResults.main, [self.path("missing.ndjson"), "--quiet"])
        self.assertEqual(code, 2)
        self.assertIn("cannot open", err)
        # An existing directory cannot be opened for writing.
        self.assertEqual(call(CheckResults.main, [good, "--out", self.tmp, "--quiet"])[0], 2)

    def test_undecodable_input_is_a_tool_error(self):
        path = self.path("binary.ndjson")
        with open(path, "wb") as fh:
            fh.write(json.dumps(make_row()).encode("utf-8") + b"\n\xff\xfe\x81 broken\n")
        code, _, err = call(CheckResults.main, [path, "--quiet"])
        self.assertEqual(code, 2)
        self.assertIn("cannot read", err)

    def test_bad_arguments_exit_2(self):
        with self.assertRaises(SystemExit) as raised:
            call(CheckResults.main, [])
        self.assertEqual(raised.exception.code, 2)

    def test_command_line_entry_point(self):
        path = self.write_ndjson("results.ndjson", [make_row(), make_row(status="sideways")])
        proc = subprocess.run([sys.executable, os.path.join(HARNESS, "CheckResults.py"),
                               path, "--json"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(proc.returncode, 1, proc.stderr)
        report = json.loads(proc.stdout.decode("utf-8"))
        self.assertEqual((report["clean"], len(report["flagged"])), (1, 1))


SCRIPT_LINES = [
    "#Requires AutoHotkey v2.0",
    "x := 1",
    "Clipboard := x",
    "try {",
    "} catch {",
    "}",
    "Clipboard := x",
    "MsgBox(x)",
]


class ReportCase(TempDirCase):
    def setUp(self):
        super().setUp()
        self.root = self.path("repo")
        os.makedirs(os.path.join(self.root, "src"))
        self.script = os.path.join(self.root, "src", "tool.ahk")
        self.other = os.path.join(self.root, "src", "other.ahk")
        self.write_script(SCRIPT_LINES)
        self.write_script(["MsgBox(1)"], self.other)

    def write_script(self, lines, path=None):
        with open(path or self.script, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(lines) + "\n")

    def fingerprints(self, row):
        rows = Report.build_rows([("test:1", row)], self.root)
        return [f.fingerprint for f in rows[0].findings]

    def report(self, rows, *args, fmt="sarif"):
        path = self.write_ndjson("clean.ndjson", rows)
        return call(Report.main, [path, "--format", fmt, "--root", self.root] + list(args))

    def mixed_rows(self):
        third = os.path.join(self.root, "src", "third.ahk")
        return [
            make_row("static", "fail", script=self.script, findings=[
                finding("critical", "parse", 2, "Missing close-paren", "gate"),
                finding("high", "empty-catch", 5, "Empty catch block", "lint"),
                finding("medium", "unreachable-code", 7, "Unreachable code", "codeintel",
                        "partial"),
                finding("low", "undefined-call", 0, "Call to undefined 'Foo'", "codeintel"),
            ]),
            make_row("static", "pass", script=self.other),
            make_row("dryrun", "error", script=self.other),
            make_row("dryrun", "timeout", script=third),
            make_row("pure", "pass", script=self.other, tests=0,
                     assertions={"passed": 0, "failed": 0}),
        ]


class FingerprintTests(ReportCase):
    def test_message_signature_masks_numbers_paths_and_quotes(self):
        sig = Report.message_signature
        self.assertEqual(sig("Missing value at line 42 in C:\\Temp\\run-1\\x.ahk"),
                         sig("missing   value at LINE 45 in C:\\Temp\\run-22\\other.ahk"))
        self.assertEqual(sig('Variable "count" is never used'),
                         sig("Variable 'total' is never used"))
        self.assertEqual(sig("cannot open /tmp/a/x.ahk"), sig("cannot open /var/tmp/b.ahk"))
        self.assertEqual(sig("HRESULT 0x8007023E"), sig("HRESULT 0x80004005"))
        self.assertEqual(sig("Error in Lib\\Foo.ahk"), sig("Error in Lib\\Bar.ahk"))
        self.assertNotEqual(sig("Empty catch block"), sig("Unreachable code"))

    def test_fingerprint_follows_the_documented_formula(self):
        row = make_row("static", "fail", script=self.script,
                       findings=[finding(line=5, message="Empty catch block at line 5")])
        material = "v1|static|empty-catch|src/tool.ahk|} catch {|empty catch block at line <n>"
        expected = hashlib.sha1(material.encode("utf-8")).hexdigest() + ":0"
        self.assertEqual(self.fingerprints(row), [expected])

    def test_fingerprint_survives_lines_inserted_above(self):
        before = make_row("static", "fail", script=self.script,
                          findings=[finding(line=5, message="Empty catch block at line 5")])
        original = self.fingerprints(before)
        self.write_script(["; header one", "; header two", "; header three"] + SCRIPT_LINES)
        after = make_row("static", "fail", script=self.script,
                         findings=[finding(line=8, message="Empty catch block at line 8")])
        self.assertEqual(self.fingerprints(after), original)
        # Control: editing the flagged line itself is a different finding.
        edited = list(SCRIPT_LINES)
        edited[4] = "} catch Error as err {"
        self.write_script(edited)
        self.assertNotEqual(self.fingerprints(before), original)

    def test_occurrence_index_separates_identical_findings(self):
        message = "Clipboard := assigns a plain variable in v2; use A_Clipboard"
        row = make_row("static", "fail", script=self.script, findings=[
            finding("high", "v1-clipboard", 3, message, "gate"),
            finding("high", "v1-clipboard", 7, message, "gate"),
            finding("high", "empty-catch", 5, "Empty catch block", "lint"),
        ])
        first, second, other = self.fingerprints(row)
        self.assertEqual(first.split(":")[0], second.split(":")[0])
        self.assertEqual((first[-2:], second[-2:], other[-2:]), (":0", ":1", ":0"))

    def test_findings_without_a_readable_line_use_an_empty_source(self):
        at_zero = make_row("static", "fail", script=self.script,
                           findings=[finding(line=0, message="Folded rows")])
        past_end = make_row("static", "fail", script=self.script,
                            findings=[finding(line=999, message="Folded rows")])
        missing = make_row("static", "fail", script=os.path.join(self.root, "gone.ahk"),
                           findings=[finding(line=5, message="Folded rows")])
        self.assertEqual(self.fingerprints(at_zero), self.fingerprints(past_end))
        self.assertEqual(len(self.fingerprints(missing)), 1)

    @unittest.skipUnless(os.name == "nt", "Windows paths are case-insensitive")
    def test_fingerprint_ignores_path_case(self):
        upper = make_row("static", "fail", script=self.script.upper(),
                         findings=[finding(line=5, message="Empty catch block")])
        lower = make_row("static", "fail", script=self.script,
                         findings=[finding(line=5, message="Empty catch block")])
        self.assertEqual(self.fingerprints(upper), self.fingerprints(lower))


class ReportPathTests(ReportCase):
    def test_script_under_root_is_relative_with_forward_slashes(self):
        self.assertEqual(Report.display_path(self.script, self.root), ("src/tool.ahk", True))

    def test_script_outside_root_is_absolute_with_forward_slashes(self):
        outside = self.path("elsewhere", "x.ahk")
        expected = os.path.abspath(outside).replace("\\", "/")
        self.assertEqual(Report.display_path(outside, self.root), (expected, False))

    @unittest.skipUnless(os.name == "nt", "Windows path semantics")
    def test_case_and_slash_variants_still_resolve_under_root(self):
        variant = self.script.upper().replace("\\", "/")
        path, relative = Report.display_path(variant, self.root)
        self.assertEqual((path.casefold(), relative), ("src/tool.ahk", True))


class ReportFormatTests(ReportCase):
    def test_sarif_has_the_required_shape(self):
        code, out, _ = self.report(self.mixed_rows(), fmt="sarif")
        self.assertEqual(code, 1)
        doc = json.loads(out)
        self.assertEqual((doc["version"], len(doc["runs"])), ("2.1.0", 1))
        run = doc["runs"][0]
        driver = run["tool"]["driver"]
        self.assertEqual(driver["name"], "ahk-harness")
        self.assertEqual(driver["informationUri"], "https://github.com/TrueCrimeDev/ClautoHotkey")
        levels = {rule["id"]: rule["defaultConfiguration"]["level"] for rule in driver["rules"]}
        self.assertEqual(levels, {"parse": "error", "empty-catch": "error",
                                  "unreachable-code": "warning", "undefined-call": "note",
                                  "hung": "error", "tool-error": "error", "timeout": "error"})
        self.assertIs(run["invocations"][0]["executionSuccessful"], False)
        for result in run["results"]:
            with self.subTest(rule=result["ruleId"]):
                self.assertEqual(driver["rules"][result["ruleIndex"]]["id"], result["ruleId"])
                self.assertIn(result["level"], ("error", "warning", "note"))
                self.assertTrue(result["message"]["text"])
                location = result["locations"][0]["physicalLocation"]
                self.assertTrue(location["artifactLocation"]["uri"])
                self.assertGreaterEqual(location["region"]["startLine"], 1)
                self.assertRegex(result["partialFingerprints"]["ahkHarness/v1"],
                                 r"^[0-9a-f]{40}:\d+$")
                self.assertEqual(sorted(result["properties"]),
                                 ["confidence", "label", "run", "severity", "source", "tier"])
        by_rule = {result["ruleId"]: result for result in run["results"]}
        self.assertEqual([by_rule[r]["level"] for r in
                          ("parse", "empty-catch", "unreachable-code", "undefined-call")],
                         ["error", "error", "warning", "note"])
        catch = by_rule["empty-catch"]["locations"][0]["physicalLocation"]
        self.assertEqual(catch["artifactLocation"], {"uri": "src/tool.ahk", "uriBaseId": "%SRCROOT%"})
        self.assertEqual(catch["region"]["startLine"], 5)
        line_zero = by_rule["undefined-call"]["locations"][0]["physicalLocation"]["region"]
        self.assertEqual(line_zero["startLine"], 1)
        self.assertEqual(by_rule["unreachable-code"]["properties"]["confidence"], "partial")
        self.assertEqual((by_rule["tool-error"]["level"], by_rule["timeout"]["level"]),
                         ("error", "error"))
        self.assertTrue(run["originalUriBaseIds"]["%SRCROOT%"]["uri"].startswith("file://"))

    def test_sarif_without_error_rows_reports_a_successful_execution(self):
        code, out, _ = self.report([make_row("static", "fail", script=self.script)])
        self.assertIs(json.loads(out)["runs"][0]["invocations"][0]["executionSuccessful"], True)

    def test_sarif_script_outside_root_uses_a_file_uri(self):
        outside = self.path("elsewhere", "x y.ahk")
        _, out, _ = self.report([make_row("static", "fail", script=outside)])
        artifact = json.loads(out)["runs"][0]["results"][0]["locations"][0][
            "physicalLocation"]["artifactLocation"]
        self.assertNotIn("uriBaseId", artifact)
        self.assertTrue(artifact["uri"].startswith("file://"))
        self.assertTrue(artifact["uri"].endswith("/elsewhere/x%20y.ahk"))

    def test_junit_parses_and_counts(self):
        code, out, _ = self.report(self.mixed_rows(), fmt="junit")
        self.assertEqual(code, 1)
        root = ET.fromstring(out.encode("utf-8"))
        self.assertEqual(root.tag, "testsuites")
        self.assertEqual([s.get("name") for s in root.findall("testsuite")],
                         ["static", "pure", "dryrun"])
        attrs = ("tests", "failures", "errors", "skipped")
        self.assertEqual([root.get(a) for a in attrs], ["5", "2", "1", "1"])
        suites = {s.get("name"): s for s in root.findall("testsuite")}
        self.assertEqual([suites["static"].get(a) for a in attrs], ["2", "1", "0", "0"])
        self.assertEqual([suites["dryrun"].get(a) for a in attrs], ["2", "1", "1", "0"])
        self.assertEqual([suites["pure"].get(a) for a in attrs], ["1", "0", "0", "1"])

        failed = suites["static"].find("testcase[@name='src/tool.ahk']")
        self.assertEqual((failed.get("classname"), failed.get("time")),
                         ("ahk-harness.static", "0.250"))
        failure = failed.find("failure")
        self.assertTrue(failure.get("message").startswith("[critical] parse line 2"))
        self.assertEqual(len(failure.text.strip().splitlines()), 4)
        timeout = suites["dryrun"].find("testcase[@name='src/third.ahk']/failure")
        self.assertEqual(timeout.get("type"), "timeout")
        self.assertIsNotNone(suites["dryrun"].find("testcase[@name='src/other.ahk']/error"))
        skipped = suites["pure"].find("testcase/skipped")
        self.assertEqual(skipped.get("message"), "no unit tests")

    def test_junit_escapes_markup_and_control_characters(self):
        message = '<b>"x" & y</b> \x1b[31mred\x00'
        code, out, _ = self.report([make_row("static", "fail", script=self.script,
                                             findings=[finding(message=message)])], fmt="junit")
        failure = ET.fromstring(out.encode("utf-8")).find("testsuite/testcase/failure")
        self.assertIn('<b>"x" & y</b>', failure.text)
        self.assertIn('<b>"x" & y</b>', failure.get("message"))

    def test_github_annotations_escape_and_map_levels(self):
        odd = os.path.join(self.root, "src", "odd, name.ahk")
        self.write_script(["a", "b", "c", "d"], odd)
        rows = [make_row("static", "fail", script=odd, findings=[
            finding("high", "empty-catch", 4, "50% done\r\nnext line"),
            finding("medium", "warn", 0, "advisory"),
            finding("low", "undefined-call", 2, "lead only"),
        ]), make_row("dryrun", "error", script=self.other)]
        code, out, _ = self.report(rows, fmt="github")
        lines = out.splitlines()
        self.assertEqual(lines[0], "::error file=src/odd%2C name.ahk,line=4,"
                                   "title=static/empty-catch::50%25 done%0D%0Anext line")
        self.assertEqual(lines[1], "::warning file=src/odd%2C name.ahk,title=static/warn::advisory")
        self.assertEqual(lines[2], "::notice file=src/odd%2C name.ahk,line=2,"
                                   "title=static/undefined-call::lead only")
        self.assertTrue(lines[3].startswith("::error file=src/other.ahk,title=dryrun/tool-error::"))
        self.assertEqual(len(lines), 4)

    def test_github_property_escaping(self):
        self.assertEqual(Report._gh_property("C:/a,b%\r\n"), "C%3A/a%2Cb%25%0D%0A")
        self.assertEqual(Report._gh_data("a: b, 100%"), "a: b, 100%25")

    def test_markdown_summary(self):
        code, out, _ = self.report(self.mixed_rows(), fmt="markdown")
        self.assertTrue(out.strip())
        self.assertIn("| tier | pass | fail | error | timeout |", out)
        self.assertIn("| static | 1 | 1 | 0 | 0 |", out)
        self.assertIn("| dryrun | 0 | 0 | 1 | 1 |", out)
        positions = [out.index(f"### {s}") for s in ("critical", "high", "medium", "low")]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("- **high** `empty-catch` — src/tool.ahk:5 — Empty catch block", out)
        self.assertLess(out.index("## No unit tests"), out.index("- src/other.ahk"))
        self.assertIn("Suppressed by baseline: 0 finding(s).", out)


class ReportExitTests(ReportCase):
    def test_fail_on_threshold(self):
        medium = [make_row("static", "pass", script=self.script,
                           findings=[finding("medium", "warn", 2, "advisory")])]
        self.assertEqual(self.report(medium, "--quiet")[0], 0)
        self.assertEqual(self.report(medium, "--fail-on", "medium", "--quiet")[0], 1)
        self.assertEqual(self.report(medium, "--fail-on", "low", "--quiet")[0], 1)
        high = [make_row("static", "fail", script=self.script)]
        self.assertEqual(self.report(high, "--quiet")[0], 1)
        self.assertEqual(self.report(high, "--fail-on", "critical", "--quiet")[0], 0)
        self.assertEqual(self.report(high, "--fail-on", "none", "--quiet")[0], 0)

    def test_unrecognised_severity_ranks_high(self):
        rows = [make_row("static", "fail", script=self.script,
                         findings=[finding("bogus", "odd-rule", 2, "who knows")])]
        code, out, _ = self.report(rows, "--quiet")
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["runs"][0]["results"][0]["level"], "error")

    def test_odd_lines_and_a_missing_status_never_crash_the_report(self):
        rows = [make_row("static", "fail", script=self.script, findings=[
                    finding(line="²"), finding(line="7"), finding(line=None),
                    finding(line=4.0)]),
                make_row("static", script=self.other, status=DROP)]
        code, out, _ = self.report(rows, "--quiet")
        lines = [r["locations"][0]["physicalLocation"]["region"]["startLine"]
                 for r in json.loads(out)["runs"][0]["results"] if r["ruleId"] == "empty-catch"]
        self.assertEqual((code, lines), (1, [1, 7, 1, 4]))
        code, out, _ = self.report(rows, "--quiet", fmt="junit")
        error = ET.fromstring(out.encode("utf-8")).find(
            "testsuite/testcase[@name='src/other.ahk']/error")
        self.assertEqual(error.get("message"), "no status — treated as a tool error")

    def test_error_and_timeout_rows_fail_unless_fail_on_none(self):
        for status in ("error", "timeout"):
            rows = [make_row("dryrun", status, script=self.script)]
            with self.subTest(status=status):
                self.assertEqual(self.report(rows, "--quiet")[0], 1)
                self.assertEqual(self.report(rows, "--fail-on", "critical", "--quiet")[0], 1)
                self.assertEqual(self.report(rows, "--fail-on", "none", "--quiet")[0], 0)

    def test_baseline_suppression_changes_the_exit_code(self):
        baseline = self.path("baseline.json")
        rows = [make_row("static", "fail", script=self.script,
                         findings=[finding(line=5, message="Empty catch block at line 5")])]
        code, _, _ = self.report(rows, "--write-baseline", baseline, "--quiet")
        self.assertEqual(code, 1)

        code, out, err = self.report(rows, "--baseline", baseline)
        self.assertEqual(code, 0)
        self.assertIn("1 suppressed by baseline", err)
        self.assertEqual(json.loads(out)["runs"][0]["results"], [])

        # The accepted finding moves down three lines and stays accepted.
        self.write_script(["; one", "; two", "; three"] + SCRIPT_LINES)
        moved = [make_row("static", "fail", script=self.script,
                          findings=[finding(line=8, message="Empty catch block at line 8")])]
        self.assertEqual(self.report(moved, "--baseline", baseline, "--quiet")[0], 0)

        # A new finding is not in the baseline and fails the run again.
        moved[0]["findings"].append(finding("high", "v1-clipboard", 6, "Clipboard := x"))
        code, out, _ = self.report(moved, "--baseline", baseline, "--quiet")
        self.assertEqual(code, 1)
        self.assertEqual([r["ruleId"] for r in json.loads(out)["runs"][0]["results"]],
                         ["v1-clipboard"])

    def test_fully_baselined_failure_is_a_passing_testcase(self):
        baseline = self.path("baseline.json")
        rows = [make_row("static", "fail", script=self.script)]
        self.report(rows, "--write-baseline", baseline, "--quiet")
        code, out, _ = self.report(rows, "--baseline", baseline, "--quiet", fmt="junit")
        root = ET.fromstring(out.encode("utf-8"))
        self.assertEqual((code, root.get("failures")), (0, "0"))
        self.assertIn("suppressed by baseline", root.find("testsuite/testcase/system-out").text)

    def test_write_baseline_records_every_fingerprint_sorted(self):
        baseline = self.path("baseline.json")
        rows = self.mixed_rows()
        self.report(rows, "--write-baseline", baseline, "--quiet")
        with open(baseline, encoding="utf-8") as fh:
            data = json.load(fh)
        self.assertEqual(data["schema"], "ahk-harness/baseline@1")
        fps = data["fingerprints"]
        self.assertEqual(fps, sorted(set(fps)))
        # Four static findings plus the timeout row's "hung"; the synthetic
        # tool-error and timeout results describe the run and are not recorded.
        self.assertEqual(len(fps), 5)

        # Applying it suppresses every finding, yet the broken rows still fail,
        # and writing again while applying it still records everything.
        again = self.path("again.json")
        code, _, err = self.report(rows, "--baseline", baseline, "--write-baseline", again)
        self.assertEqual(code, 1)
        self.assertIn("5 suppressed by baseline", err)
        with open(again, encoding="utf-8") as fh:
            self.assertEqual(json.load(fh)["fingerprints"], fps)

    def test_markdown_reports_the_suppressed_count(self):
        baseline = self.path("baseline.json")
        rows = [make_row("static", "fail", script=self.script)]
        self.report(rows, "--write-baseline", baseline, "--quiet")
        code, out, _ = self.report(rows, "--baseline", baseline, "--quiet", fmt="markdown")
        self.assertEqual(code, 0)
        self.assertIn("Suppressed by baseline: 1 finding(s).", out)
        self.assertIn("No findings.", out)

    def test_tool_errors_exit_2(self):
        good = self.write_ndjson("good.ndjson", [make_row("static", script=self.script)])
        base = ["--format", "sarif", "--root", self.root, "--quiet"]
        self.assertEqual(call(Report.main, [self.path("missing.ndjson")] + base)[0], 2)
        self.assertEqual(call(Report.main, [good, "--out", self.tmp] + base)[0], 2)
        self.assertEqual(call(Report.main, [good, "--write-baseline", self.tmp] + base)[0], 2)
        self.assertEqual(call(Report.main, [good, "--baseline", self.path("nope.json")] + base)[0], 2)
        wrong = self.path("wrong.json")
        with open(wrong, "w", encoding="utf-8") as fh:
            json.dump({"schema": "something-else", "fingerprints": []}, fh)
        self.assertEqual(call(Report.main, [good, "--baseline", wrong] + base)[0], 2)
        code, _, err = call(Report.main, [good, "--format", "sarif",
                                          "--root", self.path("no-such-dir")])
        self.assertEqual(code, 2)
        self.assertIn("is not a directory", err)

    def test_bad_arguments_exit_2(self):
        good = self.write_ndjson("good.ndjson", [make_row()])
        for argv in ([good], [good, "--format", "pdf"], [good, "--format", "sarif",
                                                          "--fail-on", "severe"]):
            with self.subTest(argv=argv[1:]):
                with self.assertRaises(SystemExit) as raised:
                    call(Report.main, argv)
                self.assertEqual(raised.exception.code, 2)

    def test_unparseable_lines_warn_and_are_skipped(self):
        rows = ["", "{oops", "[1, 2]", make_row("static", script=self.script)]
        code, out, err = self.report(rows, fmt="junit")
        self.assertEqual(code, 0)
        self.assertIn("clean.ndjson:2: skipped, unparseable JSON", err)
        self.assertIn("clean.ndjson:3: skipped, not a JSON object", err)
        self.assertEqual(ET.fromstring(out.encode("utf-8")).get("tests"), "1")

    def test_quiet_suppresses_the_summary(self):
        rows = [make_row("static", script=self.script)]
        self.assertIn("result(s)", self.report(rows)[2])
        self.assertEqual(self.report(rows, "--quiet")[2], "")

    def test_out_writes_the_report_to_a_file(self):
        target = self.path("report.sarif")
        code, out, _ = self.report([make_row("static", "fail", script=self.script)],
                                   "--out", target, "--quiet")
        self.assertEqual((code, out), (1, ""))
        with open(target, encoding="utf-8") as fh:
            self.assertEqual(json.load(fh)["version"], "2.1.0")

    def test_command_line_writes_utf8_to_stdout(self):
        message = "Expected \u2713 near caf\u00e9 \u2014 \u65e5\u672c"
        path = self.write_ndjson("clean.ndjson", [make_row(
            "static", "fail", script=self.script, findings=[finding(message=message)])])
        proc = subprocess.run([sys.executable, os.path.join(HARNESS, "Report.py"), path,
                               "--format", "sarif", "--root", self.root, "--quiet"],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(proc.returncode, 1, proc.stderr)
        doc = json.loads(proc.stdout.decode("utf-8"))
        self.assertEqual(doc["runs"][0]["results"][0]["message"]["text"], message)


if __name__ == "__main__":
    unittest.main()
