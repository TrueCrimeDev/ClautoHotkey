# AHK v2 grading harness — result contract

Every tier writes the same object, one per line, to stdout as NDJSON. Agents in
a workflow never talk to each other; they only agree on this shape. That
agreement is the whole coupling, so it lives in one place and `HarnessCore.ahk`
emits it for all tiers.

## The object

```json
{
  "schema":  "ahk-harness/result@1",
  "run":     "20260809071944-113184-482913",
  "label":   "static-3",
  "tier":    "static",
  "script":  "C:\\Scripts\\tools\\ci-report.ahk",
  "name":    "ci-report.ahk",
  "parse":   "clean",
  "status":  "pass",
  "ms":      312,
  "checks":  [ { "name": "check", "status": "pass", "exit": 0, "ms": 94, "detail": "CHECK PASS" } ],
  "findings":[ { "severity": "high", "rule": "empty-catch", "line": 88,
                 "source": "lint", "confidence": "full", "message": "…" } ],
  "counts":  { "critical": 0, "high": 1, "medium": 0, "low": 4 },
  "sentinel":"AHKHARNESS-END"
}
```

Every field is always present. A consumer never has to tell "absent" from
"empty", which is what makes the checker's rules mechanical.

| field | meaning |
|---|---|
| `run` | opaque run id. The default is `<A_Now>-<pid>-<tick>`, so two agents starting in the same second cannot share a run directory; an explicit `--run` is used verbatim |
| `tier` | `static` \| `pure` \| `dryrun` \| `live` — gate order. Anything else is a structural flag: an unrecognised tier would slip past every gap, branch and drift rule |
| `status` | `pass` \| `fail` \| `error` \| `timeout`. `error` means a *tool* broke, not the script |
| `parse` | `clean` \| `partial` \| `failed` \| `not-parsed` \| `error` |
| `confidence` | `full` \| `partial` — `partial` means the finding came from a tree the parser could not fully build |
| `sentinel` | proves the emitter finished writing; a truncated line loses it |

A diagnostic finding's `message` carries the interpreter headline plus its
continuation lines — `Specifically: <name>` and the indented stack lines, up to
the next headline or a blank line — so the offending variable name reaches the
result.

`dryrun` results add `residency` (`exited` \| `idle` \| `wedged`), `actions`
(intercepted call count) and `intent` (counts by kind: `input`, `window`,
`control`, `fs`, `registry`, `process`, `dialog`, `ui`, `timing`, `gui`,
`hotkey`, `net`). All three extras are present on every `dryrun` row, early
errors included. `residency` may additionally read `unknown`, but only on
`status: "error"` rows, where the child never ran or its exit was unobservable;
every row on which the child produced a real outcome uses the three-value set.
At this tier `parse` is `failed` when the child exited 12 — its own load
failure — and `not-parsed` otherwise: the dry-run tier performs no static parse
of its own, so `clean` and `partial` never appear there. A `dryrun` result that
reached launch also carries an informational `stderr` check row (status `pass`,
exit 0) holding the child's raw captured stderr, clipped to the check-row cap,
so the full diagnostic detail survives beyond what the folded finding messages
keep. `live` results add `drift`, the selector-drift snapshot, without which a
live failure cannot be attributed to the script.

## Rules the tiers obey

**Tiers gate in order per script: `static` → `pure` → `dryrun` → `live`. A
failed tier ends that branch.** Linting a file the interpreter cannot load
reports against a broken parse tree, so the later checks record `"skipped"`
rather than reporting zero problems.

**Only live-input nodes touch the desktop.** Foreground focus and synthetic
input are one shared resource, so every `live` node carries an implicit edge to
every other `live` node even with no data dependency between them. They run as
one serial pipeline. Everything else fans out freely — including `dryrun`,
where the shim intercepts synthetic input, window and control manipulation,
`Gui` construction (a record-only stub class, so no candidate window ever
exists), dialogs, `Run`/`RunWait`/`Reload`, `Hotkey()`/`Hotstring()`
registration, process close/priority/waits, and the write half of file,
directory, ini, registry and download I/O. Reads (`FileRead`, `IniRead`,
`RegRead`, `FileExist`, `ProcessExist`, `WinExist`) stay real.

A dry-run pass means "no intercepted effect fired", not "proven side-effect
free". A candidate can still reach the world through `A_Clipboard` (a built-in
variable no declaration can shadow), `FileOpen` write handles (left real so
legitimate config reads keep working), `DllCall`/`ComCall`, `ComObject`, and
hotkey or hotstring *label* syntax (`F1::`, `::x::`) — only the function forms
are intercepted. The gate snapshots and restores the clipboard around each
child, but parallel agents' candidates can still interleave clipboard writes —
an accepted residual race. And because `Gui` is a stub and `Hotkey()` a
recording shadow, a GUI-only or hotkey-function-only candidate exits cleanly
(`residency: "exited"`, exit 0) instead of sitting resident to the deadline;
`idle` now comes from real persistence — label-syntax hotkeys, timers and the
like.

The dry-run wrapper is written next to the candidate under a dot-prefixed
per-agent name, so `A_ScriptDir` and relative paths resolve to the candidate's
directory, and is removed as soon as the child is gone; a read-only candidate
directory falls back to the scratch dir, with the wrapper still setting the
working directory to the candidate's home. At this tier a script path that
cannot be found is a tool error (`status: "error"`), not a script verdict —
`static` is where "script not found" is gradeable, and by tier 3 the file has
already been seen once.

**One run directory per run, one label per agent.** Scratch paths are
`<out>/<index>-<script>.<tool>.out`, and the label keeps parallel agents apart.
No bridge or broker is ever shared between agents.

**A timeout is a failed result, never a skip.** Exit `124` means the script's
own message loop was still answering when the deadline passed — a persistent
hotkey or GUI script sitting idle, which is a pass unless it also reported a
diagnostic. Exit `137` means it had to be terminated because it stopped
answering, which is a failure. The difference is measured with a `WM_NULL`
probe, not assumed. `CheckResults.py` honours the distinction: a passing
`execute` check that recorded exit `124` is the contracted idle-persistent
outcome, never flagged as a pass/exit contradiction — any other nonzero exit on
a passing check is. The tier tools themselves run under a deadline too, an
explicit per-call timeout or a 120 s ceiling when none is given; a timed-out
tool surfaces as a failed check with exit `137` and `timeout after <N>ms` in
its detail, never a silent skip, and the interpreter under the cmd wrapper is
killed as a tree so nothing is orphaned. When a process handle cannot be
opened, the deadline is still enforced by polling and a timeout keeps its
normal shape — killed, responsiveness probed, exit `124` or `137`; only an exit
that could not be observed at all is reported as a tool error.

**Flagged results never reach synthesis.** `CheckResults.py` drops anything
unreadable, unsentinelled, empty, timed out, self-contradictory, or produced
after its branch should already have ended. Results are compared within one run
only — grouped by (`run`, script), the path case-folded and slash-normalised
for grouping while the emitted string is preserved — so the same script graded
in two runs is never a contradiction. Cross-result flags withhold only the
offending rows: a stray row produced after its branch ended is dropped, while
the failing gate result that ended the branch is legitimate evidence and still
reaches synthesis. A present tier whose earlier gate tier is absent, when that
run demonstrably covered the gate tier, is flagged — missing middle tiers
included; tiers absent after a failure are correct and never flagged. Exit
codes: 0 = every result survived, 1 = at least one flagged, 2 = usage or tool
error (bad arguments, unreadable input, unwritable `--out`) — data problems
inside a readable file are flags, not tool errors.

## Severity

`critical` ends a branch. `high` is a defect. `medium` is worth fixing. `low` is
advisory and never drives a fix on its own.

Three rankings are deliberate rather than inherited from the underlying tools.
Each was measured, not assumed:

- `undefined-call` is ranked **low**. CodeIntel sees one file, so it cannot know
  about a name defined in an `#Include`, and its built-in table is incomplete —
  it flags `ValueError`, `OutputDebug`, `FileGetSize`, `WinGetPID` and
  `WinGetProcessName` on a parse it handled perfectly. It is a lead, not a defect.
- `unreachable-code` is capped at **medium**. It catches real dead code, but it
  also fires on the search-a-collection idiom — `for … { if (x) return y }`
  followed by `return default` — because a loop whose body ends in a return is
  treated as terminal for the block around it. Reproduced on a *clean* parse, so
  it is a rule bug rather than the partial-parse effect below. The message does
  not distinguish the two cases.
- Any finding from a **partial** parse is demoted one rank and marked
  `"confidence":"partial"`. If the parse-state detector itself errors —
  CodeIntel throws — the tree's parse state was never assessed: the result
  carries `parse: "error"`, the `codeintel` check row records status `"error"`,
  and every finding gathered afterward is demoted and marked the same way. An
  unassessed tree is contained like a known-partial one.
- `v1-clipboard`, `v1-new` and `v1-command` are ranked **high**. These are v1
  APIs that load cleanly under v2 and then do nothing — the script runs and
  simply fails at its job, so nothing else reports them. `Clipboard := x`
  assigns an ordinary variable (the real one is `A_Clipboard`); it hit 46 of
  161 scripts in the `.ai` corpus, every one previously filed as a low
  `unused-local`. The scan is plain text, so it still works on a file the
  parser cannot load — which matters, because those files never reach Lint or
  CodeIntel at all. It strips string literals and trailing comments before
  matching, and a brace counter exempts a field named `Clipboard` declared
  directly inside a class body — the same line one level deeper, in a method
  body, still counts. It stays plain text with no parser dependency.

Findings are capped at **10 per rule per file**, with the remainder folded into
one row stating how many were omitted. One wholly-v1 script produced 589
`v1-command` findings and buried every other result in the aggregate. The cap
lives in `Harness.Finish`, the single tail every tier and every early return
passes through — capping at a call site missed the parse-failure path, which is
exactly where an all-v1 file lands.

## The partial-parse trap

The bundled `tree-sitter-ahk.dll` grammar fails on **a brace-less clause body
that follows a closing brace**:

```ahk
try { … } catch Error as err      ; breaks the parse
    DoThing()

try { … } finally                 ; also breaks the parse
    DoThing()

try                               ; parses fine — no preceding }
    DoThing()
finally
    DoOther()
```

The interpreter accepts every one of these (`check` exits 0), so this is purely
a grammar gap. But when it triggers, `HasParseError` goes true and *every* Lint
and CodeIntel finding in that file is reasoning over a damaged tree — which is
what the demotion above exists to contain. Bracing the clause body clears it.
The grammar is a compiled DLL from `holy-tao/tree-sitter-autohotkey`, so it
cannot be patched from this repo; `Lib/TreeSitter.ahk` is only the binding.

## Tier status

| tier | tool | state |
|---|---|---|
| `static` | `GateStatic.ahk` | built, runnable now; also feeds the post-edit hook via `.claude/hooks/lint-runner.ahk` |
| `pure` | — | **not built.** Needs an approved spend ceiling before any paid grading runs |
| `dryrun` | `GateDryRun.ahk` + `DryRunShim.ahk` | built, runnable now |
| `live` | — | **not built.** Needs a machine whose keyboard and mouse can be surrendered |
| checker | `CheckResults.py` | built, runnable now |
