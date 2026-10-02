#!/usr/bin/env python3
"""CI report formats for the AHK v2 grading harness.

Turns harness NDJSON, normally CheckResults.py's clean output, into what CI
systems read: SARIF 2.1.0 for code scanning, JUnit XML for test dashboards,
GitHub workflow annotations, and a Markdown summary for a PR comment or a job
summary.

    Report.py <results.ndjson> [more.ndjson ...] --format sarif|junit|github|markdown
              [--out FILE] [--root DIR] [--baseline FILE] [--write-baseline FILE]
              [--fail-on critical|high|medium|low|none] [--quiet]

The checker decides whether a row is trustworthy; this tool only renders. A
blank input line is skipped, and a line that is not a JSON object is skipped
with a warning on stderr.

Script paths are reported relative to --root (default: the current directory)
with forward slashes, or absolute with forward slashes when the script lies
outside it.

Every finding carries a fingerprint that survives edits which only move it:
sha1 over the tier, the rule, the relative path, the text of the flagged
source line as it is on disk (whitespace-collapsed), and the message with its
numbers, quoted strings and paths masked, followed by an occurrence index
among identical keys in the same result. The path is part of the key, so a
baseline is written and applied with the same --root. --write-baseline records
every current fingerprint; --baseline drops matching findings from the output
and from the exit decision, and the summary says how many it dropped.

A row whose status is error or timeout always renders as a result of its own
(rule tool-error or timeout) and always fails the build unless --fail-on is
none, so CI never shows a broken run as clean. A baseline never suppresses it:
it describes the run, not the script.

Exit codes: 0 = no unsuppressed finding at or above --fail-on (default high)
and no error/timeout rows, or --fail-on none; 1 = otherwise; 2 = usage or tool
error (bad arguments, unreadable input or baseline, unwritable --out or
--write-baseline, --root not a directory).
"""

import argparse
import hashlib
import json
import ntpath
import os
import re
import sys
import xml.etree.ElementTree as ET
from urllib.parse import quote

BASELINE_SCHEMA = "ahk-harness/baseline@1"
FINGERPRINT_VERSION = "v1"
FINGERPRINT_KEY = "ahkHarness/v1"
TOOL_NAME = "ahk-harness"
INFORMATION_URI = "https://github.com/TrueCrimeDev/ClautoHotkey"
SARIF_SCHEMA = "https://json.schemastore.org/sarif-2.1.0.json"
SRCROOT = "%SRCROOT%"

TIER_ORDER = ("static", "pure", "dryrun", "live")
SEVERITIES = ("critical", "high", "medium", "low")
RANK = {"critical": 4, "high": 3, "medium": 2, "low": 1}
SARIF_LEVEL = {"critical": "error", "high": "error", "medium": "warning", "low": "note"}
GITHUB_LEVEL = {"critical": "error", "high": "error", "medium": "warning", "low": "notice"}
FORMATS = ("sarif", "junit", "github", "markdown")
FAIL_ON = ("critical", "high", "medium", "low", "none")

# Message masking for fingerprints. Quoted strings go first so a quoted path
# or a quoted name is one placeholder; AHK strings have no backslash escapes,
# so a quote simply runs to the next quote. A single quote only opens after a
# non-word character, which keeps the apostrophe in "doesn't" from pairing
# with a later quote.
_QUOTED = re.compile(
    r'"[^"\n]*"'
    r"|(?<!\w)'[^'\n]*'(?!\w)"
    r"|“[^”\n]*”"
    r"|‘[^’\n]*’"
)
# Drive and UNC paths, POSIX paths of two or more segments (so "/validate" or
# "and/or" stay words), and any other token holding a backslash, which in a
# harness message is a relative Windows path.
_PATH = re.compile(
    r"(?:\b[A-Za-z]:[\\/]|\\\\(?=[^\s\\/]))[^\s\"'<>|]*"
    r"|(?<![\w.~/])(?:/[^\s/\"'<>|]+){2,}/?"
    r"|[^\s\"'<>|]*\\[^\s\"'<>|]*"
)
_HEX = re.compile(r"\b0[xX][0-9a-fA-F]+\b")
_DIGITS = re.compile(r"\d+")
_WINDOWS_PATH = re.compile(r"^(?:[A-Za-z]:[\\/]|\\\\)")

# XML 1.0 cannot carry these even escaped, and captured stderr can hold them
# (an ANSI escape is enough), so they are replaced before serialising.
_XML_BAD = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f￾￿\ud800-\udfff]")
_MD_SPECIAL = re.compile(r"([\\`*_\[\]<>|~])")


class ToolError(Exception):
    """The report itself could not be produced: exit 2."""


class Finding(object):
    __slots__ = ("row", "severity", "rule", "line", "message", "source",
                 "confidence", "synthetic", "fingerprint", "suppressed")

    def __init__(self, row, severity, rule, line, message, source, confidence,
                 synthetic=False):
        self.row = row
        self.severity = severity
        self.rule = rule
        self.line = line
        self.message = message
        self.source = source
        self.confidence = confidence
        self.synthetic = synthetic
        self.fingerprint = ""
        self.suppressed = False


class Row(object):
    __slots__ = ("where", "obj", "tier", "status", "script", "path", "relative",
                 "ms", "run", "label", "findings")


def _warn(message):
    print(f"Report.py: warning: {message}", file=sys.stderr)


def _text(value):
    if value is None:
        return ""
    return value if isinstance(value, str) else str(value)


def _one_line(text):
    return " ".join(text.split())


def _line(value):
    """A finding's line as an int; anything unusable is 0, meaning no line."""
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float) and value.is_integer():
        return int(value)
    # isdecimal, not isdigit: "²" is a digit that int() rejects.
    if isinstance(value, str) and value.strip().isdecimal():
        return int(value.strip())
    return 0


def _ms(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return 0
    if value != value or value < 0 or value == float("inf"):
        return 0
    return value


def _severity(value):
    """Contract severities only. Anything else ranks high rather than low: an
    unrecognised severity must not quietly pass CI."""
    severity = _text(value).strip().lower()
    return severity if severity in RANK else "high"


def message_signature(message):
    """The message with numbers, quoted strings and paths masked, lowercased
    and whitespace-collapsed, so "line 42" and "line 45", or two different
    temp directories, sign the same."""
    text = _QUOTED.sub("<str>", _text(message))
    text = _PATH.sub("<path>", text)
    text = _HEX.sub("<n>", text)
    text = _DIGITS.sub("<n>", text)
    return " ".join(text.lower().split())


def fingerprint_key(tier, rule, rel_path, source_line, message):
    """sha1 over the fields that identify a finding independent of where it
    sits in the file. The occurrence index is appended by the caller."""
    material = "|".join((FINGERPRINT_VERSION, tier, rule, rel_path.casefold(),
                         source_line, message_signature(message)))
    return hashlib.sha1(material.encode("utf-8", "surrogatepass")).hexdigest()


class SourceLines(object):
    """Script lines, read once per file. A missing or unreadable file has no
    lines, so its findings fingerprint with an empty source line — still
    stable, only less specific."""

    def __init__(self):
        self._files = {}

    def line(self, path, number):
        if not path or number <= 0:
            return ""
        lines = self._files.get(path)
        if lines is None:
            lines = self._read(path)
            self._files[path] = lines
        if number > len(lines):
            return ""
        return " ".join(lines[number - 1].split())

    @staticmethod
    def _read(path):
        try:
            with open(path, encoding="utf-8-sig", errors="replace", newline="") as fh:
                text = fh.read()
        except (OSError, ValueError):
            return []
        # Split on LF only: str.splitlines() also breaks on form feeds and
        # Unicode separators, which would shift every later line number away
        # from the interpreter's count.
        return text.split("\n")


def display_path(script, root):
    """(path, is_relative): relative to root with forward slashes when the
    script lies under it, otherwise absolute with forward slashes."""
    if not isinstance(script, str) or not script:
        return ("?" if script in (None, "") else _text(script)), False
    if os.name != "nt" and (_WINDOWS_PATH.match(script) or "\\" in script):
        # A Windows path read on a POSIX host cannot lie under a POSIX root.
        return ntpath.normpath(script).replace("\\", "/"), False
    absolute = os.path.abspath(script)
    try:
        rel = os.path.relpath(absolute, root)
    except ValueError:
        # Another drive: never under the root.
        return absolute.replace("\\", "/"), False
    if rel == os.pardir or rel.startswith(os.pardir + os.sep) or os.path.isabs(rel):
        return absolute.replace("\\", "/"), False
    return rel.replace("\\", "/"), True


def _script_file(script):
    if not isinstance(script, str) or not script:
        return None
    if os.name != "nt" and (_WINDOWS_PATH.match(script) or "\\" in script):
        return None
    return os.path.abspath(script)


def _check_detail(checks):
    for check in checks:
        detail = _one_line(_text(check.get("detail")))
        if detail:
            if len(detail) > 300:
                detail = detail[:297] + "..."
            return f"{_text(check.get('name')) or 'check'}: {detail}"
    return ""


def _status_finding(row):
    """The result a broken row contributes on its own, so a tool error or a
    timeout can never render as a clean script."""
    if row.status in ("pass", "fail"):
        return None
    checks = row.obj.get("checks")
    checks = [c for c in checks if isinstance(c, dict)] if isinstance(checks, list) else []
    if row.status == "timeout":
        rule = "timeout"
        message = "timed out"
        if row.ms:
            message += f" after {int(row.ms)} ms"
        message += " — counts as a failed result, not a skip"
        detail = _check_detail([c for c in checks if c.get("status") != "pass"])
    elif row.status == "error":
        rule = "tool-error"
        broken = [c for c in checks if c.get("status") == "error"]
        names = ", ".join(_text(c.get("name")) for c in broken) or "unknown"
        message = f"tool error in: {names}"
        detail = _check_detail(broken)
    else:
        rule = "tool-error"
        what = f"unrecognised status {row.status!r}" if row.status else "no status"
        message = f"{what} — treated as a tool error"
        detail = ""
    if detail:
        message += f" — {detail}"
    return Finding(row, "critical", rule, 0, message, "harness", "full", synthetic=True)


def build_rows(entries, root, sources=None):
    """Rows with their findings, a status finding for broken rows, and every
    finding fingerprinted. entries are (where, obj) pairs."""
    sources = sources if sources is not None else SourceLines()
    rows = []
    for where, obj in entries:
        row = Row()
        row.where = where
        row.obj = obj
        row.tier = _text(obj.get("tier")) or "unknown"
        row.status = _text(obj.get("status"))
        row.script = obj.get("script")
        row.path, row.relative = display_path(row.script, root)
        row.ms = _ms(obj.get("ms"))
        row.run = _text(obj.get("run"))
        row.label = _text(obj.get("label"))
        row.findings = []
        items = obj.get("findings")
        for item in items if isinstance(items, list) else ():
            if not isinstance(item, dict):
                continue
            row.findings.append(Finding(
                row, _severity(item.get("severity")), _text(item.get("rule")) or "unnamed",
                _line(item.get("line")), _text(item.get("message")),
                _text(item.get("source")), _text(item.get("confidence"))))
        broken = _status_finding(row)
        if broken is not None:
            row.findings.append(broken)
        _fingerprint(row, sources)
        rows.append(row)
    return rows


def _fingerprint(row, sources):
    # The occurrence index counts identical keys within one result: two
    # identical lines raising the identical message are still two findings.
    # Counting per result rather than across results keeps a script graded
    # twice from minting ":1" fingerprints no single-run baseline holds.
    seen = {}
    script_file = _script_file(row.script)
    for finding in row.findings:
        # Some findings point into another file: a pure-tier assertion's line
        # is in the test file, and a diagnostic raised in an include is marked
        # "[in other.ahk]". Reading the row's own script at that line would
        # sign the finding with unrelated text, so those sign by message only.
        elsewhere = row.tier == "pure" or "[in " in finding.message
        source = "" if elsewhere else sources.line(script_file, finding.line)
        key = fingerprint_key(row.tier, finding.rule, row.path, source, finding.message)
        index = seen.get(key, 0)
        seen[key] = index + 1
        finding.fingerprint = f"{key}:{index}"


def read_ndjson(paths):
    entries = []
    for path in paths:
        try:
            if path == "-":
                entries.extend(_parse_lines("<stdin>", sys.stdin))
            else:
                with open(path, encoding="utf-8-sig", errors="replace") as fh:
                    entries.extend(_parse_lines(path, fh))
        except OSError as exc:
            raise ToolError(f"cannot read {path}: {exc}")
    return entries


def _parse_lines(name, stream):
    for lineno, raw in enumerate(stream, 1):
        raw = raw.strip()
        if not raw:
            continue
        where = f"{name}:{lineno}"
        try:
            obj = json.loads(raw)
        except ValueError as exc:
            _warn(f"{where}: skipped, unparseable JSON ({exc})")
            continue
        if not isinstance(obj, dict):
            _warn(f"{where}: skipped, not a JSON object")
            continue
        yield where, obj


def load_baseline(path):
    try:
        with open(path, encoding="utf-8-sig") as fh:
            data = json.load(fh)
    except (OSError, ValueError) as exc:
        raise ToolError(f"cannot read baseline {path}: {exc}")
    if (not isinstance(data, dict) or data.get("schema") != BASELINE_SCHEMA
            or not isinstance(data.get("fingerprints"), list)):
        raise ToolError(f"{path} is not an {BASELINE_SCHEMA} file")
    return {fp for fp in data["fingerprints"] if isinstance(fp, str)}


def apply_baseline(rows, accepted):
    """Mark accepted findings suppressed; returns how many. Status findings
    are never suppressed: they describe a broken run, not the script."""
    suppressed = 0
    for row in rows:
        for finding in row.findings:
            if not finding.synthetic and finding.fingerprint in accepted:
                finding.suppressed = True
                suppressed += 1
    return suppressed


def baseline_fingerprints(rows):
    return sorted({f.fingerprint for row in rows for f in row.findings if not f.synthetic})


def exit_code(rows, fail_on):
    if fail_on == "none":
        return 0
    threshold = RANK[fail_on]
    for row in rows:
        for finding in row.findings:
            if finding.synthetic:
                return 1
            if not finding.suppressed and RANK[finding.severity] >= threshold:
                return 1
    return 0


def visible(rows):
    return [f for row in rows for f in row.findings if not f.suppressed]


def _no_unit_tests(row):
    tests = row.obj.get("tests")
    return (row.tier == "pure" and row.status == "pass"
            and isinstance(tests, int) and not isinstance(tests, bool) and tests == 0)


def uncovered(rows):
    """Scripts whose pure tier passed after running zero test files, minus any
    script some other pure row ran tests for."""
    zero, covered = [], set()
    for row in rows:
        if row.tier != "pure":
            continue
        tests = row.obj.get("tests")
        if _no_unit_tests(row):
            zero.append(row.path)
        elif isinstance(tests, int) and not isinstance(tests, bool) and tests > 0:
            covered.add(row.path.casefold())
    out, seen = [], set()
    for path in zero:
        key = path.casefold()
        if key not in seen and key not in covered:
            seen.add(key)
            out.append(path)
    return out


def _tiers(rows):
    present = []
    for row in rows:
        if row.tier not in present:
            present.append(row.tier)
    return [t for t in TIER_ORDER if t in present] + [t for t in present if t not in TIER_ORDER]


def _quote_uri(path):
    return quote(path, safe="/:", errors="replace")


def file_uri(path):
    """file:// URI for an absolute path that already uses forward slashes."""
    if path.startswith("//"):
        return "file:" + _quote_uri(path)
    if not path.startswith("/"):
        path = "/" + path
    return "file://" + _quote_uri(path)


def render_sarif(rows, root, suppressed):
    shown = visible(rows)
    # A rule's default level is the most severe level it was seen at; each
    # result still carries its own level, which is what viewers display.
    worst = {}
    for finding in shown:
        current = worst.get(finding.rule)
        if current is None or RANK[finding.severity] > RANK[current]:
            worst[finding.rule] = finding.severity
    rule_ids = sorted(worst)
    index = {rule: i for i, rule in enumerate(rule_ids)}
    rules = [{
        "id": rule,
        "shortDescription": {"text": rule},
        "defaultConfiguration": {"level": SARIF_LEVEL[worst[rule]]},
    } for rule in rule_ids]

    results = []
    for finding in shown:
        row = finding.row
        if row.relative:
            artifact = {"uri": _quote_uri(row.path), "uriBaseId": SRCROOT}
        else:
            artifact = {"uri": file_uri(row.path)}
        results.append({
            "ruleId": finding.rule,
            "ruleIndex": index[finding.rule],
            "level": SARIF_LEVEL[finding.severity],
            "message": {"text": finding.message or finding.rule},
            "locations": [{"physicalLocation": {
                "artifactLocation": artifact,
                "region": {"startLine": max(1, finding.line)},
            }}],
            "partialFingerprints": {FINGERPRINT_KEY: finding.fingerprint},
            "properties": {
                "tier": row.tier,
                "severity": finding.severity,
                "confidence": finding.confidence,
                "source": finding.source,
                "run": row.run,
                "label": row.label,
            },
        })

    root_uri = file_uri(root.replace("\\", "/").rstrip("/") + "/")
    healthy = not any(row.status not in ("pass", "fail", "timeout") for row in rows)
    document = {
        "$schema": SARIF_SCHEMA,
        "version": "2.1.0",
        "runs": [{
            "tool": {"driver": {
                "name": TOOL_NAME,
                "informationUri": INFORMATION_URI,
                "rules": rules,
            }},
            "invocations": [{"executionSuccessful": healthy}],
            "originalUriBaseIds": {SRCROOT: {"uri": root_uri}},
            "results": results,
        }],
    }
    return json.dumps(document, indent=2, ensure_ascii=False) + "\n"


def _xml(value):
    return _XML_BAD.sub("\ufffd", _text(value))


def _finding_text(finding):
    where = f" line {finding.line}" if finding.line > 0 else ""
    return f"[{finding.severity}] {finding.rule}{where}: {_one_line(finding.message)}"


def _junit_case(case, row):
    """Fill one testcase; returns which counter it lands in."""
    shown = [f for f in row.findings if not f.synthetic and not f.suppressed]
    hidden = sum(1 for f in row.findings if f.suppressed)
    broken = next((f for f in row.findings if f.synthetic), None)

    if row.status == "fail":
        if shown or not hidden:
            if shown:
                top = max(shown, key=lambda f: RANK[f.severity])
                headline = _finding_text(top)
            else:
                headline = "failed with no findings"
            element = ET.SubElement(case, "failure", {"message": _xml(headline), "type": "fail"})
            element.text = _xml("\n".join(_finding_text(f) for f in shown))
            return "failures"
        # Every finding behind the failure is accepted in the baseline.
        out = ET.SubElement(case, "system-out")
        out.text = _xml(f"{hidden} finding(s) suppressed by baseline")
        return "passed"
    if row.status == "timeout":
        element = ET.SubElement(case, "failure", {"message": _xml(broken.message),
                                                  "type": "timeout"})
        element.text = _xml("\n".join(_finding_text(f) for f in shown))
        return "failures"
    if broken is not None:
        element = ET.SubElement(case, "error", {"message": _xml(broken.message),
                                                "type": broken.rule})
        checks = row.obj.get("checks")
        lines = []
        for check in checks if isinstance(checks, list) else ():
            if isinstance(check, dict) and check.get("status") == "error":
                lines.append(f"{_text(check.get('name'))} (exit {_text(check.get('exit'))}): "
                             f"{_one_line(_text(check.get('detail')))}")
        lines.extend(_finding_text(f) for f in shown)
        element.text = _xml("\n".join(lines))
        return "errors"
    if _no_unit_tests(row):
        ET.SubElement(case, "skipped", {"message": "no unit tests"})
        return "skipped"
    if shown:
        out = ET.SubElement(case, "system-out")
        out.text = _xml("\n".join(_finding_text(f) for f in shown))
    return "passed"


def _indent(element, level=0):
    # ElementTree.indent arrived in 3.9; this keeps the output readable on 3.8.
    pad = "\n" + "  " * level
    children = list(element)
    if children:
        if not element.text or not element.text.strip():
            element.text = pad + "  "
        for child in children:
            _indent(child, level + 1)
        if not children[-1].tail or not children[-1].tail.strip():
            children[-1].tail = pad
    if level and (not element.tail or not element.tail.strip()):
        element.tail = pad


def render_junit(rows, root, suppressed):
    suites = ET.Element("testsuites", {"name": TOOL_NAME})
    totals = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
    total_time = 0.0
    for tier in _tiers(rows):
        tier_rows = [row for row in rows if row.tier == tier]
        suite = ET.SubElement(suites, "testsuite", {"name": _xml(tier)})
        counts = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0, "passed": 0}
        suite_time = 0.0
        for row in tier_rows:
            seconds = row.ms / 1000.0
            suite_time += seconds
            case = ET.SubElement(suite, "testcase", {
                "classname": _xml(f"{TOOL_NAME}.{tier}"),
                "name": _xml(row.path),
                "time": f"{seconds:.3f}",
            })
            counts[_junit_case(case, row)] += 1
            counts["tests"] += 1
        for key in ("tests", "failures", "errors", "skipped"):
            suite.set(key, str(counts[key]))
            totals[key] += counts[key]
        suite.set("time", f"{suite_time:.3f}")
        total_time += suite_time
    for key in ("tests", "failures", "errors", "skipped"):
        suites.set(key, str(totals[key]))
    suites.set("time", f"{total_time:.3f}")
    _indent(suites)
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            + ET.tostring(suites, encoding="unicode") + "\n")


def _gh_data(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def _gh_property(text):
    # Property values additionally escape the characters that delimit them.
    return _gh_data(text).replace(":", "%3A").replace(",", "%2C")


def render_github(rows, root, suppressed):
    lines = []
    for finding in visible(rows):
        properties = ["file=" + _gh_property(finding.row.path)]
        if finding.line > 0:
            properties.append(f"line={finding.line}")
        properties.append("title=" + _gh_property(f"{finding.row.tier}/{finding.rule}"))
        lines.append(f"::{GITHUB_LEVEL[finding.severity]} {','.join(properties)}::"
                     f"{_gh_data(finding.message or finding.rule)}")
    return "".join(line + "\n" for line in lines)


def _md(text):
    return _MD_SPECIAL.sub(r"\\\1", _one_line(_text(text)))


def render_markdown(rows, root, suppressed):
    out = ["# AHK harness report", ""]
    tiers = _tiers(rows)
    if tiers:
        out.append("| tier | pass | fail | error | timeout |")
        out.append("|---|---:|---:|---:|---:|")
        for tier in tiers:
            counts = {"pass": 0, "fail": 0, "error": 0, "timeout": 0}
            for row in rows:
                if row.tier == tier:
                    counts[row.status if row.status in counts else "error"] += 1
            out.append(f"| {_md(tier)} | {counts['pass']} | {counts['fail']} | "
                       f"{counts['error']} | {counts['timeout']} |")
    else:
        out.append("No results in the input.")

    out += ["", "## Findings", ""]
    shown = visible(rows)
    if not shown:
        out += ["No findings.", ""]
    for severity in SEVERITIES:
        group = [f for f in shown if f.severity == severity]
        if not group:
            continue
        out += [f"### {severity} ({len(group)})", ""]
        for finding in group:
            where = finding.row.path + (f":{finding.line}" if finding.line > 0 else "")
            rule = finding.rule.replace("`", "'")
            out.append(f"- **{severity}** `{rule}` — {_md(where)} — "
                       f"{_md(finding.message or finding.rule)}")
        out.append("")

    out += ["## No unit tests", ""]
    missing = uncovered(rows)
    out += [f"- {_md(path)}" for path in missing] if missing else ["None."]
    out += ["", f"Suppressed by baseline: {suppressed} finding(s).", ""]
    return "\n".join(out)


RENDERERS = {
    "sarif": render_sarif,
    "junit": render_junit,
    "github": render_github,
    "markdown": render_markdown,
}


def write_text(text, out):
    if out:
        try:
            with open(out, "w", encoding="utf-8", errors="replace", newline="\n") as fh:
                fh.write(text)
        except OSError as exc:
            raise ToolError(f"cannot write {out}: {exc}")
        return
    # Straight to the byte stream as UTF-8: SARIF and JUnit declare UTF-8, and
    # a redirected Windows console would otherwise encode with the ANSI code
    # page and die on the first character outside it.
    buffer = getattr(sys.stdout, "buffer", None)
    if buffer is None:
        sys.stdout.write(text)
        return
    sys.stdout.flush()
    buffer.write(text.encode("utf-8", "replace"))
    buffer.flush()


def write_baseline(rows, path):
    fingerprints = baseline_fingerprints(rows)
    document = {"schema": BASELINE_SCHEMA, "fingerprints": fingerprints}
    try:
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(document, fh, indent=2)
            fh.write("\n")
    except OSError as exc:
        raise ToolError(f"cannot write baseline {path}: {exc}")
    return len(fingerprints)


def _parser():
    ap = argparse.ArgumentParser(
        description="Render harness NDJSON as SARIF, JUnit XML, GitHub annotations or Markdown.")
    ap.add_argument("paths", nargs="+", help="NDJSON files, or - for stdin")
    ap.add_argument("--format", required=True, choices=FORMATS, help="output format")
    ap.add_argument("--out", help="write the report here instead of stdout")
    ap.add_argument("--root", help="report script paths relative to this directory "
                                   "(default: the current directory)")
    ap.add_argument("--baseline", help="suppress findings whose fingerprints this file lists")
    ap.add_argument("--write-baseline", help="write every current fingerprint to this file")
    ap.add_argument("--fail-on", choices=FAIL_ON, default="high",
                    help="lowest severity that fails the run (default: high)")
    ap.add_argument("--quiet", action="store_true", help="no summary on stderr")
    return ap


def run(args):
    root = os.path.abspath(args.root if args.root else os.getcwd())
    if not os.path.isdir(root):
        raise ToolError(f"--root {args.root!r} is not a directory")
    accepted = load_baseline(args.baseline) if args.baseline else None
    rows = build_rows(read_ndjson(args.paths), root)
    if not rows:
        _warn("no results in the input")
    suppressed = apply_baseline(rows, accepted) if accepted is not None else 0
    write_text(RENDERERS[args.format](rows, root, suppressed), args.out)
    written = write_baseline(rows, args.write_baseline) if args.write_baseline else None
    code = exit_code(rows, args.fail_on)

    if not args.quiet:
        parts = [f"{len(rows)} result(s)", f"{len(visible(rows))} finding(s) reported"]
        if accepted is not None:
            parts.append(f"{suppressed} suppressed by baseline")
        broken = sum(1 for row in rows if row.status not in ("pass", "fail"))
        if broken:
            parts.append(f"{broken} error/timeout row(s)")
        missing = len(uncovered(rows))
        if missing:
            parts.append(f"{missing} script(s) with no unit tests")
        print(f"Report.py: {', '.join(parts)}; fail-on {args.fail_on} -> exit {code}",
              file=sys.stderr)
        if written is not None:
            print(f"Report.py: wrote {written} fingerprint(s) to {args.write_baseline}",
                  file=sys.stderr)
    return code


def main(argv=None):
    args = _parser().parse_args(argv)
    try:
        return run(args)
    except ToolError as exc:
        print(f"Report.py: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
