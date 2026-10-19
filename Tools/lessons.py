#!/usr/bin/env python3
"""The lesson library: what earlier mistakes taught about this harness.

A lesson is one file under lessons/ with a cue (the shape of situation it
applies to), the operation to perform on a named harness component, the
evidence it rests on and a confidence. An entry without all four is refused,
because a lesson without evidence is a guess that every later session would
read as fact.

    ./Tools/lessons.py propose [--min 2] [--log PATH] [--json]
        Recurring error-log patterns that no lesson covers yet. Candidates,
        not lessons: each needs a verified cause before it becomes one.
    ./Tools/lessons.py add --name SLUG --cue ... --lesson ... --evidence ...
                           --component PATH --confidence high|medium|low
                           [--signature REGEX] [--status proposed|adopted]
        Write one entry and rebuild INDEX.md.
    ./Tools/lessons.py check          validate every entry (exit 1 on a problem)
    ./Tools/lessons.py index          rebuild INDEX.md from what is on disk

The error log is `.claude/error-log.jsonl` in the project the hooks ran in
(CLAUDE_PROJECT_DIR), one JSON object per line as `error-logger.sh` writes it.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LESSONS = ROOT / "lessons"

CONFIDENCE = ("high", "medium", "low")
STATUS = ("proposed", "adopted", "rejected", "retired")
VERDICTS = ("helped", "hurt", "no observed effect", "confounded", "untested")
REQUIRED = ("name", "cue", "component", "confidence", "status")
SECTIONS = ("Lesson", "Evidence")
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]*$")
HEADLINE = re.compile(r"==> ([^\n]+)")


def parse(path: pathlib.Path) -> dict:
    """Frontmatter fields plus the `## Section` bodies, with no YAML library."""
    text = path.read_text(encoding="utf-8", errors="replace")
    fields: dict[str, str] = {}
    body = text
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            for line in text[3:end].splitlines():
                if ":" in line and not line.startswith((" ", "\t")):
                    key, value = line.split(":", 1)
                    fields[key.strip()] = value.strip()
            body = text[end + 4 :]
    sections: dict[str, str] = {}
    current = None
    for line in body.splitlines():
        if line.startswith("## "):
            current = line[3:].strip()
            sections[current] = ""
        elif current is not None:
            sections[current] += line + "\n"
    return {"path": path, "fields": fields, "sections": sections}


def validate(entry: dict) -> list[str]:
    """Every reason this entry is not a lesson. Empty means it is one."""
    fields, sections, path = entry["fields"], entry["sections"], entry["path"]
    problems = []
    for key in REQUIRED:
        if not fields.get(key, "").strip():
            problems.append(f"missing frontmatter field `{key}`")
    name = fields.get("name", "")
    if name and name != path.stem:
        problems.append(f"name `{name}` does not match the file name `{path.stem}`")
    if name and not SLUG.match(name):
        problems.append(f"name `{name}` is not a lower-case slug")
    if fields.get("confidence") and fields["confidence"] not in CONFIDENCE:
        problems.append(f"confidence must be one of {', '.join(CONFIDENCE)}")
    if fields.get("status") and fields["status"] not in STATUS:
        problems.append(f"status must be one of {', '.join(STATUS)}")
    for section in SECTIONS:
        if not sections.get(section, "").strip():
            problems.append(f"empty or missing `## {section}` section")
    component = fields.get("component", "")
    if component and fields.get("status") == "adopted":
        if not (ROOT / component).exists():
            problems.append(f"adopted, but component `{component}` does not exist")
    edits = sections.get("Edits", "")
    for row in edits.splitlines():
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(cells) == 4 and cells[0] not in ("component", "---") and not set(cells[0]) <= {"-"}:
            if cells[3] not in VERDICTS:
                problems.append(f"edit row verdict `{cells[3]}` is not one of {', '.join(VERDICTS)}")
    signature = fields.get("signature", "")
    if signature:
        try:
            re.compile(signature)
        except re.error as exc:
            problems.append(f"signature is not a valid regex: {exc}")
    return problems


def entries() -> list[dict]:
    if not LESSONS.is_dir():
        return []
    return [parse(p) for p in sorted(LESSONS.glob("*.md")) if p.name != "INDEX.md"]


def render_index(items: list[dict]) -> str:
    lines = [
        "# Lessons",
        "",
        "Each entry is something a recorded mistake taught about this harness: the shape of",
        "situation it applies to, the change it argues for on a named component, and the",
        "evidence behind it. Read the cue column first; open an entry only when its cue",
        "matches what is in front of you. `proposed` entries are changes nobody has made yet.",
        "",
        "Rebuilt by `Tools/lessons.py index`; do not edit by hand.",
        "",
    ]
    by_status: dict[str, list[dict]] = collections.defaultdict(list)
    for item in items:
        by_status[item["fields"].get("status", "proposed")].append(item)
    for status in STATUS:
        group = by_status.get(status)
        if not group:
            continue
        lines += [f"## {status}", "", "| lesson | cue | component | confidence |", "|---|---|---|---|"]
        for item in group:
            f = item["fields"]
            lines.append(
                f"| [{f['name']}]({item['path'].name}) | {f.get('cue', '')} | "
                f"`{f.get('component', '')}` | {f.get('confidence', '')} |"
            )
        lines.append("")
    if not items:
        lines += ["_(empty)_", ""]
    return "\n".join(lines)


def write_index() -> pathlib.Path:
    LESSONS.mkdir(parents=True, exist_ok=True)
    index = LESSONS / "INDEX.md"
    index.write_text(render_index(entries()), encoding="utf-8", newline="\n")
    return index


def index_is_current() -> bool:
    index = LESSONS / "INDEX.md"
    if not index.is_file():
        return not entries()
    return index.read_text(encoding="utf-8").replace("\r\n", "\n") == render_index(entries())


def default_log() -> pathlib.Path:
    """The project's log: CLAUDE_PROJECT_DIR, else the working directory, else this repo."""
    project = os.environ.get("CLAUDE_PROJECT_DIR") or os.environ.get("PROJECT_DIR")
    candidates = [pathlib.Path(project)] if project else []
    candidates += [pathlib.Path.cwd(), ROOT]
    for base in candidates:
        log = base / ".claude" / "error-log.jsonl"
        if log.is_file():
            return log
    return candidates[0] / ".claude" / "error-log.jsonl"


def headline(message: str) -> str:
    """The interpreter's own one-line verdict, stripped of paths and line numbers."""
    m = HEADLINE.search(message)
    text = m.group(1) if m else message.strip().splitlines()[0] if message.strip() else ""
    text = re.sub(r"[A-Za-z]:\\[^\s(]+\(\d+\)\s*:\s*", "", text)
    text = re.sub(r"\s+", " ", text).strip().rstrip(".")
    return text[:120]


def load_log(path: pathlib.Path) -> list[dict]:
    rows = []
    if not path.is_file():
        return rows
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def propose(args: argparse.Namespace) -> int:
    log = pathlib.Path(args.log) if args.log else default_log()
    rows = load_log(log)
    if not rows:
        print(f"no error log at {log}")
        return 0
    cutoff = None
    if args.since:
        cutoff = (dt.datetime.now() - dt.timedelta(days=args.since)).strftime("%Y-%m-%dT%H:%M:%S")
    covered = [(e["fields"]["name"], re.compile(e["fields"]["signature"], re.I))
               for e in entries() if e["fields"].get("signature")]
    groups: dict[str, dict] = {}
    covered_counts: collections.Counter = collections.Counter()
    for row in rows:
        ts = str(row.get("timestamp", ""))
        if cutoff and ts < cutoff:
            continue
        message = str(row.get("message", ""))
        key = headline(message)
        if not key or key.startswith("PASS") or key.startswith("FAIL"):
            continue
        owner = next((name for name, rx in covered if rx.search(key) or rx.search(message)), None)
        if owner:
            covered_counts[owner] += 1
            continue
        g = groups.setdefault(key, {"count": 0, "last": "", "files": collections.Counter(), "sample": ""})
        g["count"] += 1
        g["last"] = max(g["last"], ts)
        g["files"][str(row.get("file", ""))] += 1
        if not g["sample"]:
            g["sample"] = message[:400]
    ranked = sorted(groups.items(), key=lambda kv: (-kv[1]["count"], kv[0]))
    ranked = [(k, g) for k, g in ranked if g["count"] >= args.min]
    if args.json:
        out = [{"headline": k, "count": g["count"], "last": g["last"],
                "files": g["files"].most_common(5), "sample": g["sample"]} for k, g in ranked]
        print(json.dumps({"log": str(log), "rows": len(rows), "uncovered": out,
                          "covered": dict(covered_counts)}, indent=2))
        return 0
    print(f"Error log: {log} ({len(rows)} rows)")
    print()
    print("Recurring patterns with no lesson yet. A row here is a candidate: it becomes a")
    print("lesson only once the cause is verified and the fix names a component.")
    print()
    print("| count | last seen | headline | files |")
    print("|---|---|---|---|")
    for key, g in ranked:
        files = ", ".join(f"{f} ({n})" for f, n in g["files"].most_common(3))
        print(f"| {g['count']} | {g['last'][:10]} | {key} | {files} |")
    if covered_counts:
        print()
        print("Already covered by a lesson:")
        for name, n in covered_counts.most_common():
            print(f"- `{name}`: {n} rows")
    return 0


def add(args: argparse.Namespace) -> int:
    missing = [k for k in ("name", "cue", "lesson", "evidence", "component") if not getattr(args, k, "").strip()]
    if missing:
        print(f"refused: a lesson needs {', '.join(missing)}", file=sys.stderr)
        return 1
    if not SLUG.match(args.name):
        print("refused: --name must be a lower-case slug", file=sys.stderr)
        return 1
    path = LESSONS / f"{args.name}.md"
    if path.exists() and not args.force:
        print(f"refused: {path} exists (pass --force to overwrite)", file=sys.stderr)
        return 1
    today = dt.date.today().isoformat()
    front = [
        "---",
        f"name: {args.name}",
        f"cue: {args.cue.strip()}",
        f"component: {args.component.strip()}",
        f"confidence: {args.confidence}",
        f"status: {args.status}",
    ]
    if args.signature:
        front.append(f"signature: {args.signature}")
    front += [f"recorded: {today}", "---", ""]
    body = [
        "## Lesson",
        "",
        args.lesson.strip(),
        "",
        "## Evidence",
        "",
        args.evidence.strip(),
        "",
    ]
    text = "\n".join(front + body)
    LESSONS.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")
    problems = validate(parse(path))
    if problems:
        path.unlink()
        for p in problems:
            print(f"refused: {p}", file=sys.stderr)
        return 1
    write_index()
    print(f"wrote {path.relative_to(ROOT)} and rebuilt lessons/INDEX.md")
    return 0


def check(args: argparse.Namespace) -> int:
    bad = 0
    items = entries()
    for item in items:
        for p in validate(item):
            print(f"{item['path'].relative_to(ROOT)}: {p}")
            bad += 1
    if not index_is_current():
        print("lessons/INDEX.md is stale; run `Tools/lessons.py index`")
        bad += 1
    if not bad:
        print(f"{len(items)} lesson(s) valid, index current")
    return 1 if bad else 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("propose", help="recurring error-log patterns no lesson covers")
    p.add_argument("--log", help="error-log.jsonl path (default: the project's .claude/error-log.jsonl)")
    p.add_argument("--min", type=int, default=2, help="minimum occurrences (default 2)")
    p.add_argument("--since", type=int, default=0, help="only rows from the last N days")
    p.add_argument("--json", action="store_true")
    p.set_defaults(fn=propose)
    a = sub.add_parser("add", help="write one lesson")
    a.add_argument("--name", required=True)
    a.add_argument("--cue", required=True, help="the shape of situation this applies to")
    a.add_argument("--lesson", required=True, help="the operation on the harness, naming the component")
    a.add_argument("--evidence", required=True, help="what the record shows: rows, files, dates, probes")
    a.add_argument("--component", required=True, help="repo-relative path of the component concerned")
    a.add_argument("--confidence", choices=CONFIDENCE, required=True)
    a.add_argument("--status", choices=STATUS, default="proposed")
    a.add_argument("--signature", default="", help="regex that matches the error headline this lesson covers")
    a.add_argument("--force", action="store_true")
    a.set_defaults(fn=add)
    sub.add_parser("check", help="validate every entry").set_defaults(fn=check)
    sub.add_parser("index", help="rebuild INDEX.md").set_defaults(fn=lambda _a: (print(f"wrote {write_index().relative_to(ROOT)}"), 0)[1])
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
