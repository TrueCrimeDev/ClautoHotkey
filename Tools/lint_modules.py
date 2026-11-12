#!/usr/bin/env python3
"""Corpus lint for the ClautoHotkey knowledge modules.

These markdown files are loaded verbatim into an LLM's context, so a banned
pattern here becomes wrong code in every session that loads the module. The
checks below are the drift classes the 2026-08-26 audit found spread across a
dozen files.

    ./Tools/lint_modules.py                  lint Modules/ and Modules/Supplemental/
    ./Tools/lint_modules.py Modules/X.md     lint specific files
    ./Tools/lint_modules.py --summary        counts only, no per-line output

A module often has to *show* a banned pattern in order to forbid it. A hit is
suppressed when the line itself, or nearby context, marks it as a
counter-example -- or with an explicit `<!-- lint-ok: reason -->` marker.

Exit 0 = clean, 1 = errors, 2 = warnings only.
"""

import argparse
import pathlib
import re
import sys
from collections import Counter

REPO = pathlib.Path(__file__).resolve().parent.parent

# Portability is this module's whole subject, so it may name older floors.
VERSION_EXEMPT = {"Modules/Module_Versions.md"}

COUNTEREXAMPLE = re.compile(
    r"✗|✘|❌|🚫|\bWRONG\b|\bINVALID\b|\bBAD\b|\bBANNED\b|\banti-?pattern\b"
    r"|\bnever\b|\bdo not\b|\bdon't\b|\bavoid\b|\bforbidden\b|\billegal\b"
    r"|\bconstructor pairs?\b|\bpair form\b"
    r"|\bsyntax error\b|\bis removed\b|\bwas removed\b|\bno longer\b|\bremoved on\b"
    r"|\bfails? to (load|parse|run)\b|\bthrows\b|\brejected\b|\bv2\.0 (only|fallback)\b"
    r"|\breplaces\b|\binstead of\b|\bused to\b|\bpre-alpha\.30\b"
    r"|lint-ok",
    re.IGNORECASE,
)

FENCE = re.compile(r"^\s*```")


class Finding:
    def __init__(self, path, line, level, check, text):
        self.path, self.line, self.level, self.check, self.text = path, line, level, check, text


def fence_map(lines):
    """Map each line index to the index of its enclosing fence opener, or None."""
    owner, opener = [None] * len(lines), None
    for i, line in enumerate(lines):
        if FENCE.match(line):
            opener = None if opener is not None else i
            continue
        owner[i] = opener
    return owner


def suppressed(lines, owner, i):
    """True when line i is presented as a counter-example rather than as canon."""
    if COUNTEREXAMPLE.search(lines[i]):
        return True
    for j in range(max(0, i - 3), i):
        if COUNTEREXAMPLE.search(lines[j]):
            return True
    op = owner[i]
    if op is not None:
        for j in range(max(0, op - 3), op + 1):
            if COUNTEREXAMPLE.search(lines[j]):
                return True
    return False


CHECKS = [
    # (name, level, regex, suppressible)
    # A constructor call only: not preceded by a word char or dot (excludes ArrayMap(),
    # obj.Map(), StrMap()), and carrying at least one argument separator.
    ("map-pairs", "error",
     re.compile(r"""(?<![\w.])Map\(\s*(?!\s*\))[^)\n]*,"""), True),
    ("fence-tag", "error",
     re.compile(r"^\s*```(cpp|ahkv2|autohotkey_v2|AutoHotkey|ahk2)\s*$"), False),
    ("block-arrow", "error",
     re.compile(r"=>\s*\{\s*$"), True),
    ("v2.0-floor", "error",
     re.compile(r"#Requires\s+AutoHotkey\s+v2\.0"), True),
    ("optional-call", "error",
     re.compile(r"\?\.\(|\?\.\["), True),
    ("struct-from-ptr", "error",
     re.compile(r"\bStructFromPtr\b"), True),
    ("banner-comment", "error",
     re.compile(r"^\s*(?:[;#]|//|/\*)?\s*[-=*#_]{6,}\s*$"), False),
    ("type-string-prop", "warn",
     re.compile(r"^\s*[A-Za-z_]\w*\s*:\s*(i8|i16|i32|i64|u8|u16|u32|u64|f32|f64|uptr|iptr)\s*[,}]"), True),
]

MESSAGES = {
    "map-pairs": "Map() constructor pairs — canon is empty Map() then m[\"k\"] := v",
    "fence-tag": "wrong fence tag — the AHK tag is ```ahk",
    "block-arrow": "block-body fat arrow '=> {' is a syntax error on every build",
    "v2.0-floor": "targets v2.0 — the project floor is v2.1-alpha.30",
    "optional-call": "removed on alpha.30 — use (a?)() and (a?)[]",
    "struct-from-ptr": "StructFromPtr was removed on alpha.30",
    "banner-comment": "banner comment divider",
    "type-string-prop": "property type string removed on alpha.30 — use Int32/UInt32/IntPtr class refs",
}


def lint_file(path):
    rel = path.relative_to(REPO).as_posix()
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    owner = fence_map(lines)
    out = []

    for name, level, pattern, can_suppress in CHECKS:
        if name == "v2.0-floor" and rel in VERSION_EXEMPT:
            continue
        for i, line in enumerate(lines):
            if not pattern.search(line):
                continue
            if name == "banner-comment" and line.strip() in ("---", "***", "___"):
                continue  # markdown thematic break / YAML fence
            if can_suppress and suppressed(lines, owner, i):
                continue
            out.append(Finding(rel, i + 1, level, name, line.strip()[:100]))

    out.extend(lint_frontmatter(rel, lines))
    out.extend(lint_crossrefs(rel, lines))
    return out


def lint_frontmatter(rel, lines):
    """Top-level modules must carry name + a subject-leading description."""
    parts = pathlib.PurePosixPath(rel).parts
    if len(parts) != 2 or parts[0] != "Modules":
        return []
    stem = pathlib.PurePosixPath(rel).stem
    if not lines or lines[0].strip() != "---":
        return [Finding(rel, 1, "error", "frontmatter", "missing YAML frontmatter (needs name + description)")]

    try:
        end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    except StopIteration:
        return [Finding(rel, 1, "error", "frontmatter", "frontmatter block is never closed")]

    block = lines[1:end]
    found = []

    name_line = next((l for l in block if l.startswith("name:")), None)
    if name_line is None:
        found.append(Finding(rel, 2, "error", "frontmatter", "no name: key"))
    elif name_line.split(":", 1)[1].strip() != stem:
        found.append(Finding(rel, 2, "error", "frontmatter",
                             f"name '{name_line.split(':', 1)[1].strip()}' != filename stem '{stem}'"))

    desc_idx = next((i for i, l in enumerate(block) if l.startswith("description:")), None)
    if desc_idx is None:
        found.append(Finding(rel, 2, "error", "frontmatter", "no description: key (skills trigger-match on it)"))
        return found

    desc = " ".join(l.strip() for l in block[desc_idx:]).strip()
    desc = re.sub(r"^description:\s*[>|]?-?\s*", "", desc).strip("'\" ")

    if "TRIGGER" not in desc.upper():
        found.append(Finding(rel, 2, "warn", "frontmatter", "description carries no TRIGGER keyword list"))

    opener = desc[:180]
    if re.search(r"(are|is) not covered|belongs? in Module_|not covered here", opener, re.IGNORECASE):
        found.append(Finding(rel, 2, "warn", "frontmatter",
                             "description opens with negative scoping — lead with the subject, boundaries last"))
    return found


def lint_crossrefs(rel, lines):
    """Every Module_*.md named in a body must exist."""
    found, seen = [], set()
    for i, line in enumerate(lines):
        for ref in re.findall(r"Module_[A-Za-z][A-Za-z_]*\.md", line):
            if ref in seen:
                continue
            seen.add(ref)
            if not (REPO / "Modules" / ref).exists() and not (REPO / "Modules" / "Supplemental" / ref).exists():
                found.append(Finding(rel, i + 1, "error", "crossref", f"dangling cross-reference to {ref}"))
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--summary", action="store_true", help="counts only")
    args = ap.parse_args()

    if args.files:
        paths = [pathlib.Path(f).resolve() for f in args.files]
    else:
        paths = sorted((REPO / "Modules").rglob("*.md"))

    findings = []
    for p in paths:
        if p.is_file():
            findings.extend(lint_file(p))

    errors = [f for f in findings if f.level == "error"]
    warns = [f for f in findings if f.level == "warn"]

    if not args.summary:
        for rel in sorted({f.path for f in findings}):
            group = [f for f in findings if f.path == rel]
            print(f"\n{rel}")
            for f in sorted(group, key=lambda x: x.line):
                tag = "ERROR" if f.level == "error" else "warn "
                msg = MESSAGES.get(f.check) or f.text
                print(f"  {tag} {f.line:>5}  [{f.check}] {msg}")
                if f.check not in ("frontmatter", "crossref"):
                    print(f"              {f.text}")

    print()
    by_check = Counter(f.check for f in findings)
    for check, n in by_check.most_common():
        print(f"  {n:>4}  {check}")
    print(f"\nlinted {len(paths)} file(s): {len(errors)} error(s), {len(warns)} warning(s)")

    return 1 if errors else (2 if warns else 0)


if __name__ == "__main__":
    sys.exit(main())
