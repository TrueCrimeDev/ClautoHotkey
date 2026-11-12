#!/usr/bin/env python3
"""Validate the harness tree the way a proposal would be validated before it runs.

The skills, agents, rules, hooks, lessons and the always-on text are one surface
that every session reads. A component that is wired wrong is not merely dead: a
skill nobody is told about, a hook whose script is missing or a rule with no
paths fails silently in every session that needed it. This lint makes those
failures visible before they ship.

    ./Tools/lint_harness.py                 lint the whole surface
    ./Tools/lint_harness.py --summary       counts only
    ./Tools/lint_harness.py --fix           rebuild lessons/INDEX.md when stale
    ./Tools/lint_harness.py --always-on-max 20000

Checks:
  skills    name matches the directory, description present, the name is
            advertised in CLAUDE.md, README.md or index.md and routed by the
            session primer
  agents    name matches the file, description present, routed by the primer
  rules     frontmatter declares a path glob or a contains string; a rule with
            neither is named, with its file, by the session primer (the one text
            a plugin install always loads; CLAUDE.md is not loaded there)
  hooks     hooks.json parses, every ${CLAUDE_PLUGIN_ROOT} script exists, events known
  paths     every Tools/, hooks/, skills/, agents/, rules/, commands/, Lib/,
            Modules/ or lessons/ file named in the docs, skills, agents, rules,
            commands or lessons exists
  lessons   every entry carries cue, lesson, evidence, confidence, a known status,
            and INDEX.md matches the entries on disk
  always-on chars that reach every session (CLAUDE.md) plus every .ahk edit
            (rules whose globs match any .ahk) against a cap
  counts    the skill, agent and rule counts the docs quote match the tree

Exit 0 = clean, 1 = errors, 2 = warnings only. Notes never affect the exit code.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "Tools"))
import lessons  # noqa: E402

DOCS = ("CLAUDE.md", "README.md", "index.md")
PRIMER = "hooks/ahk-session-primer.sh"
HOOK_EVENTS = {
    "SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse",
    "PostToolUseFailure", "Notification", "Stop", "SubagentStart", "SubagentStop",
    "PreCompact", "PostCompact", "PermissionRequest", "Setup",
}
REF_DIRS = r"Tools|hooks|skills|agents|rules|commands|Lib|Modules|lessons"
REF = re.compile(
    r"(?:\$\{CLAUDE_PLUGIN_ROOT\}/)?((?:" + REF_DIRS + r")/[A-Za-z0-9_./-]+\.(?:py|sh|ahk|md|json|dll))\b"
)
SKIP_DIRS = {".git", ".history", "node_modules", "__pycache__", "logs"}


class Report:
    def __init__(self) -> None:
        self.rows: list[tuple[str, str, str]] = []

    def error(self, where: str, msg: str) -> None:
        self.rows.append(("ERROR", where, msg))

    def warn(self, where: str, msg: str) -> None:
        self.rows.append(("WARN", where, msg))

    def note(self, where: str, msg: str) -> None:
        self.rows.append(("NOTE", where, msg))

    def count(self, level: str) -> int:
        return sum(1 for r in self.rows if r[0] == level)


def frontmatter(path: pathlib.Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    fields: dict[str, str] = {}
    key = None
    for line in text[3:end].splitlines():
        if line and not line[0].isspace() and ":" in line:
            key, value = line.split(":", 1)
            key = key.strip()
            fields[key] = value.strip()
        elif key and line.strip():
            fields[key] += " " + line.strip()
    return fields


def rule_list(path: pathlib.Path, key: str = "paths") -> list[str]:
    """The items of a frontmatter list, read the way inject-rules.sh reads them."""
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text.startswith("---"):
        return []
    end = text.find("\n---", 3)
    block = text[3:end] if end != -1 else ""
    out, inside = [], False
    for line in block.splitlines():
        if re.match(rf"^{re.escape(key)}:\s*$", line):
            inside = True
            continue
        if inside and re.match(r"^\s*-\s*", line):
            out.append(re.sub(r"^\s*-\s*", "", line).strip().strip("\"'"))
        elif inside and line and not line[0].isspace():
            inside = False
    return out


def rule_paths(path: pathlib.Path) -> list[str]:
    return rule_list(path, "paths")


def glob_to_re(glob: str) -> re.Pattern:
    """The same translation inject-rules.sh performs, so the lint agrees with the
    hook. Case is ignored there too: Windows paths have none."""
    g = re.sub(r"[][(){}.^$+|]", lambda m: "\\" + m.group(0), glob)
    g = g.replace("**/", "\x01").replace("**", "\x02").replace("*", "[^/]*").replace("?", "[^/]")
    g = g.replace("\x01", "(.*/)?").replace("\x02", ".*")
    return re.compile("^" + g + "$", re.IGNORECASE)


def fires_on_any_ahk(globs: list[str]) -> bool:
    probes = ("x.ahk", "Lib/x.ahk", "a/b/c.ahk")
    return any(all(glob_to_re(g).match(p) for p in probes) for g in globs)


def doc_text() -> str:
    return "\n".join((ROOT / d).read_text(encoding="utf-8", errors="replace") for d in DOCS if (ROOT / d).is_file())


def primer_text() -> str:
    primer = ROOT / PRIMER
    return primer.read_text(encoding="utf-8", errors="replace") if primer.is_file() else ""


def check_skills(rep: Report, docs: str, primer: str) -> int:
    skills = sorted(p for p in (ROOT / "skills").iterdir() if p.is_dir()) if (ROOT / "skills").is_dir() else []
    for d in skills:
        skill = d / "SKILL.md"
        where = f"skills/{d.name}"
        if not skill.is_file():
            rep.error(where, "no SKILL.md")
            continue
        fm = frontmatter(skill)
        if fm.get("name", "") != d.name:
            rep.error(where, f"frontmatter name `{fm.get('name', '')}` does not match the directory")
        if not fm.get("description", "").strip():
            rep.error(where, "no description: the skill is never surfaced")
        if f"/{d.name}" not in docs and f"`{d.name}`" not in docs:
            rep.warn(where, "not named in CLAUDE.md, README.md or index.md; nothing tells a session it exists")
        if primer and f"`/{d.name}`" not in primer:
            rep.warn(where, f"not in the routing table of {PRIMER}; a plugin session is never pointed at it")
    return len(skills)


def check_agents(rep: Report, primer: str) -> int:
    agents = sorted((ROOT / "agents").glob("*.md")) if (ROOT / "agents").is_dir() else []
    agents = [a for a in agents if a.name.lower() != "readme.md"]
    for a in agents:
        fm = frontmatter(a)
        where = f"agents/{a.name}"
        if fm.get("name", "") != a.stem:
            rep.error(where, f"frontmatter name `{fm.get('name', '')}` does not match the file name")
        if not fm.get("description", "").strip():
            rep.error(where, "no description")
        if primer and f"`{a.stem}` agent" not in primer:
            rep.warn(where, f"not in the routing table of {PRIMER}; a plugin session is never pointed at it")
    return len(agents)


def check_rules(rep: Report, primer: str) -> tuple[int, int]:
    rules = sorted((ROOT / "rules").glob("*.md")) if (ROOT / "rules").is_dir() else []
    always = 0
    for r in rules:
        globs = rule_paths(r)
        where = f"rules/{r.name}"
        build = frontmatter(r).get("build", "").strip().strip("\"'")
        if build and build.lower() != "fork":
            rep.warn(where, f"`build: {build}` is not a build inject-rules.sh knows; only `fork` narrows a rule")
        if not globs and not rule_list(r, "contains"):
            # Nothing fires it. The docs do not count as a way in: a plugin install
            # never loads this repo's CLAUDE.md, so the primer has to carry the
            # rule's gist and say where the file is.
            if r.name in primer:
                rep.note(where, f"no `paths:`; a reference rule, pointed to by {PRIMER}")
            else:
                rep.warn(where, f"no `paths:` or `contains:` and {PRIMER} does not name {r.name}; "
                                "nothing loads it in a plugin install")
            continue
        if fires_on_any_ahk(globs):
            always += len(r.read_text(encoding="utf-8", errors="replace"))
    return len(rules), always


def check_hooks(rep: Report) -> int:
    hooks_json = ROOT / "hooks" / "hooks.json"
    if not hooks_json.is_file():
        rep.error("hooks/hooks.json", "missing")
        return 0
    try:
        data = json.loads(hooks_json.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        rep.error("hooks/hooks.json", f"not valid JSON: {exc}")
        return 0
    scripts: set[str] = set()
    for event, entries in data.get("hooks", {}).items():
        if event not in HOOK_EVENTS:
            rep.warn("hooks/hooks.json", f"unknown event `{event}`")
        for entry in entries:
            for hook in entry.get("hooks", []):
                cmd = hook.get("command", "")
                for m in re.finditer(r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\"'\s]+)", cmd):
                    rel = m.group(1)
                    scripts.add(rel)
                    if not (ROOT / rel).is_file():
                        rep.error("hooks/hooks.json", f"`{event}` names `{rel}`, which does not exist")
    return len(scripts)


def prose_only(text: str) -> str:
    """Drop the frontmatter and fenced code blocks: a rule's path globs and an
    example listing are not claims that a file exists."""
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            text = text[end + 4 :]
    out, fenced = [], False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if not fenced:
            out.append(line)
    return "\n".join(out)


def check_refs(rep: Report) -> None:
    files = [ROOT / d for d in DOCS]
    for sub in ("skills", "agents", "rules", "commands", "lessons"):
        if (ROOT / sub).is_dir():
            files += sorted((ROOT / sub).rglob("*.md"))
    seen: set[tuple[str, str]] = set()
    for f in files:
        if not f.is_file():
            continue
        text = prose_only(f.read_text(encoding="utf-8", errors="replace"))
        for m in REF.finditer(text):
            rel = m.group(1)
            if "*" in rel or "<" in rel:
                continue
            key = (str(f.relative_to(ROOT)), rel)
            if key in seen:
                continue
            seen.add(key)
            if not (ROOT / rel).exists():
                rep.error(key[0], f"names `{rel}`, which does not exist")


def check_lessons(rep: Report, fix: bool) -> int:
    items = lessons.entries()
    for item in items:
        for p in lessons.validate(item):
            rep.error(str(item["path"].relative_to(ROOT)), p)
    if items and not lessons.index_is_current():
        if fix:
            lessons.write_index()
            rep.note("lessons/INDEX.md", "rebuilt")
        else:
            rep.warn("lessons/INDEX.md", "stale; run `Tools/lessons.py index` or `--fix`")
    return len(items)


def check_counts(rep: Report, docs: str, skills: int, agents: int, rules: int) -> None:
    claims = {
        "skills": re.findall(r"(\d+)\s+skills\b", docs),
        "agents": re.findall(r"(\d+)\s+(?:agents|fresh-context investigators)\b", docs),
        "rules": re.findall(r"(\d+)\s+(?:path-triggered )?rules\b", docs),
    }
    actual = {"skills": skills, "agents": agents, "rules": rules}
    plugin = ROOT / ".claude-plugin" / "plugin.json"
    if plugin.is_file():
        desc = json.loads(plugin.read_text(encoding="utf-8")).get("description", "")
        claims["skills"] += re.findall(r"(\d+)\s+skills\b", desc)
        claims["agents"] += re.findall(r"(\d+)\s+agents\b", desc)
    for kind, found in claims.items():
        wrong = sorted({n for n in found if int(n) != actual[kind]})
        if wrong:
            rep.warn("docs", f"quote {', '.join(wrong)} {kind} but the tree has {actual[kind]}")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--summary", action="store_true")
    ap.add_argument("--fix", action="store_true", help="rebuild lessons/INDEX.md when stale")
    ap.add_argument("--always-on-max", type=int, default=26000,
                    help="warn when CLAUDE.md plus the rules that fire on every .ahk exceed this many chars "
                         "(default 26000: just above the 2026-10-18 baseline, so growth is flagged, not the status quo)")
    args = ap.parse_args(argv)

    rep = Report()
    docs = doc_text()
    primer = primer_text()
    n_skills = check_skills(rep, docs, primer)
    n_agents = check_agents(rep, primer)
    n_rules, rules_always = check_rules(rep, primer)
    n_hooks = check_hooks(rep)
    check_refs(rep)
    n_lessons = check_lessons(rep, args.fix)
    check_counts(rep, docs, n_skills, n_agents, n_rules)

    claude_md = ROOT / "CLAUDE.md"
    always_on = (len(claude_md.read_text(encoding="utf-8", errors="replace")) if claude_md.is_file() else 0) + rules_always
    if always_on > args.always_on_max:
        rep.warn("always-on", f"{always_on:,} chars reach every .ahk edit (cap {args.always_on_max:,}); "
                              "move something to a skill, a narrower rule or a hook")

    if not args.summary:
        for level, where, msg in rep.rows:
            print(f"{level:5} {where}: {msg}")
        if rep.rows:
            print()
    print(f"{n_skills} skills, {n_agents} agents, {n_rules} rules, {n_hooks} hook scripts, "
          f"{n_lessons} lessons; {always_on:,} always-on chars per .ahk edit")
    print(f"{rep.count('ERROR')} error(s), {rep.count('WARN')} warning(s), {rep.count('NOTE')} note(s)")
    if rep.count("ERROR"):
        return 1
    return 2 if rep.count("WARN") else 0


if __name__ == "__main__":
    sys.exit(main())
