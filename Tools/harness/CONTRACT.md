# AHK v2 grading harness — result contract

Every tier writes the same object, one per line, to stdout as NDJSON. Agents in
a workflow never talk to each other; they only agree on this shape. That
agreement is the whole coupling, so it lives in one place and `HarnessCore.ahk`
emits it for all tiers.

## The object

```json
{
  "schema":  "ahk-harness/result@2",
  "run":     "20260809071944-113184-482913",
  "label":   "static-3",
  "tier":    "static",
  "script":  "C:\\Scripts\\ci-report.ahk",
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
| `schema` | `ahk-harness/result@2`. The checker flags `@1` rows ("older contract version — re-run with the current gates") and anything else as a wrong schema |
| `run` | opaque run id. The default is `<A_Now>-<pid>-<tick>`, so two agents starting in the same second cannot share a run directory; an explicit `--run` is used verbatim |
| `tier` | `static` \| `pure` \| `dryrun` \| `live` — gate order. Anything else is a structural flag: an unrecognised tier would slip past every gap, branch and drift rule |
| `status` | `pass` \| `fail` \| `error` \| `timeout`. `error` means a *tool* broke, not the script |
| `parse` | `clean` \| `partial` \| `failed` \| `not-parsed` \| `error` |
| `confidence` | `full` \| `partial` — `partial` means the finding came from a tree the parser could not fully build |
| `sentinel` | proves the emitter finished writing; a truncated line loses it |

A diagnostic finding's `message` carries the interpreter headline plus its
continuation lines — `Specifically: <name>` and the indented stack lines, up to
the next headline or a blank line — so the offending variable name reaches the
result. A finding in a file the candidate includes names that file in brackets.

### Tier extras

**`pure`** rows add `tests` (test files run, ≥ 0) and `assertions`
(`{passed, failed}`, summed over those files). `tests: 0` with `status: "pass"`
means the script has no unit tests: that is coverage, not a verdict, and the
checker reports it separately instead of flagging it. Each test file gets a
`test:<file>` check row. Test files speak the `TestKit` protocol on stdout —
`AHKTEST|start|{...}` once at load, `AHKTEST|fail|{test,label,expected,actual,file,line,message}`
per failed assertion, `AHKTEST|case|{name,status,ms,failures}` per case, then
`AHKTEST|summary|{passed,failed,cases,errors}` and the fork-qa-compatible
`qa: P passed, F failed` line — and exit with the failure count (capped at 99).
The summary, not the exit code, is the source of truth, and the two must agree.
A file that announced TestKit but never reached its summary stopped part-way,
whatever its exit code. A plain script with no protocol at all is graded by its
exit code, and its check row says so.

**`dryrun`** rows add, on every row including early errors:

- `residency` — `exited` \| `idle` \| `wedged`; `unknown` only on
  `status: "error"` rows, where the child never ran or its exit was unobservable.
- `actions` — the number of intercepted calls.
- `intent` — counts by kind: `input`, `window`, `control`, `message`, `fs`,
  `registry`, `process`, `system`, `dialog`, `ui`, `timing`, `gui`, `hotkey`,
  `net`, `com`, `dll`, `clipboard`. `intent` need not sum to `actions`:
  `clipboard` counts writes the guard observed, which no shadow intercepted.
- `guard` — `{clipboard, dialogs, windows, focus}`: `clipboard` is
  `untouched` \| `restored` \| `restore-failed`, `dialogs` and `windows` count
  what the window watch caught, `focus` is `kept` \| `stolen`.

At this tier `parse` is `failed` when the child exited 12 — its own load
failure — and `not-parsed` otherwise: the dry-run tier performs no static parse
of its own, so `clean` and `partial` never appear there. A row that reached
launch carries informational `stdout` and `stderr` check rows (status `pass`,
exit 0) holding the child's captured streams, clipped to the check-row cap, and
a `watch` row summarising the guard.

**`live`** rows add `drift` — the snapshot of the UI the run observed (an
object), or `"unknown"` when nothing was observed — and `backend`
(`{name, verdict, evidence, interpreter}`). A live failure without a drift
snapshot cannot be attributed to the script.

## Rules the tiers obey

**Tiers gate in order per script: `static` → `pure` → `dryrun` → `live`. A
failed tier ends that branch.** Linting a file the interpreter cannot load
reports against a broken parse tree, so the later checks record `"skipped"`
rather than reporting zero problems.

**Every child runs contained.** `Harness.Launch` starts each child suspended,
assigns it to a job object, and only then resumes it, so nothing it spawns can
escape first. The job kills the whole tree when the gate closes it
(`KILL_ON_JOB_CLOSE`) and suppresses the crash-reporting dialog that would keep
a crashed child alive to the deadline. Candidate-running tiers add a memory cap
(`--memory`, default 1024 MB) and UI limits: no system-parameter, display or
desktop changes, and no log-off — a `Shutdown()` that slipped past every other
layer still cannot end the user's session. stdout and stderr go to files, never
to the gate's own stdout, so a candidate's `Print` cannot corrupt the NDJSON
stream.

**Only live-input nodes touch the desktop.** Foreground focus and synthetic
input are one shared resource, so every `live` node carries an implicit edge to
every other `live` node even with no data dependency between them. They run as
one serial pipeline, and `GateLive.ahk` enforces that with a session-wide lock
(`AHKHarness-Live`) rather than trusting the scheduler. Everything else fans out
freely, including `dryrun`:

- The candidate runs **in place** with `DryRunShim.ahk` injected ahead of it
  (`/include`), so `A_ScriptDir`, relative includes and error line numbers are
  its own and nothing is written next to it. `/force` keeps a candidate's
  `#SingleInstance Force` from replacing a copy of the same script the user
  already has running.
- The shim intercepts synthetic input and input capture (`KeyWait`,
  `InputHook`), window and control manipulation, window messages, `Gui`
  construction (a record-only stub class, so no candidate window ever exists),
  `Menu.Show`, dialogs and the `Edit`/`List*`/`KeyHistory` windows,
  `Run`/`RunWait`/`Reload`, process close/priority/waits, `Shutdown`, sound and
  volume, drive control, `Hotkey()`/`Hotstring()` registration, and the write
  half of file, directory, ini, registry and download I/O. Label hotkeys and
  hotstrings (`F1::`, `::btw::`) are suspended before the candidate's
  auto-execute section runs and stay suspended.
- Originals stay reachable through the built-in AHK module, so interception is
  selective: `FileOpen` passes reads through and redirects write, append and
  read-write opens into a sink file (append and read-write sinks are seeded
  with the real content); `DllCall` forwards everything except a deny-list of
  input, window, message, process, file, registry, hook, sound, display and
  shutdown APIs; `ComObject` forwards everything except automation objects with
  effects (shell, file system, Office and other `*.Application` servers, HTTP,
  speech, scheduler, firewall), which get a recording stand-in; `FileAppend`
  still reaches `*` and `**`.
- Reads (`FileRead`, `IniRead`, `RegRead`, `FileExist`, `ProcessExist`,
  `WinExist`) stay real.
- A candidate that defines a shadowed name itself (its own `MsgBox` wrapper)
  would not load beside the shadow. The interpreter names the collision; that
  one shadow is dropped from a per-run copy of the shim and the load retried.
  The candidate's own definition already hides the built-in, so nothing is lost.
- A candidate that uses the module system is **refused, not run**:
  `status: "error"` with a `shim-bypass` finding. The shadows are declarations
  in the main module. An import that names the AHK module, in any spelling
  (`#Import AHK {...}`, `#Import {...} from AHK`, the `Import` statement forms),
  reaches the original built-ins past every shadow; code under `#Module`, or in
  a module file an import loads, never sees the shadows at all. The scan follows
  `#Include`, so one of these in an included file counts too. It reads the text
  and asks no interpreter, so a spelling the installed build rejects (alpha.38
  accepts only `#Import AHK ...`) is refused the same way.
- Between wait slices a **window watch** looks at every visible top-level window
  the candidate's job owns. Any window is unexpected, so each is reported:
  an AutoHotkey error dialog (recognised by its fixed button ids, whatever the
  locale) ends the run — otherwise the dialog's live message loop let a crashed
  script sit to the deadline and score as an idle pass; other dialogs are
  dismissed with their default button, plain windows are closed. A candidate
  process taking the foreground is reported too.
- A **clipboard guard** covers the one gap no shadow can: `A_Clipboard`. It
  snapshots the user's clipboard, attributes each write by the owner window's
  process, and restores the user's data once the candidate is gone — never
  mid-run, so a candidate reading back its own write sees it. A copy the user
  makes mid-run becomes the new snapshot and is never clobbered. Candidates that
  touch the clipboard are serialised across agents through a lock
  (`AHKHarness-Clipboard`), so two of them cannot interleave.

A dry-run pass means "no intercepted effect fired", not "proven side-effect
free". A candidate can still reach the world through `DllCall` APIs outside the
deny-list (a `CreateFile` opened for writing, raw COM vtables) and through COM
objects outside the stub list.

At this tier a script path that cannot be found is a tool error
(`status: "error"`), not a script verdict — `static` is where "script not found"
is gradeable, and by tier 3 the file has already been seen once. Script paths
on every gate's command line resolve against the directory the command was run
from: AutoHotkey starts every script with its working directory set to
`A_ScriptDir`, so resolving them any other way lands in the harness folder.

**One run directory per run, one label per agent.** Scratch paths are
`<out>/<index>-<script>.<tool>.out`, and the label keeps parallel agents apart.
No bridge or broker is ever shared between agents; the only shared objects are
the two named locks above, and they exist to serialise.

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
its detail, never a silent skip.

**An error the candidate hides is still seen.** The shim records every error
the candidate raises, with its file and line, ahead of any handler the
candidate registers. An error its own `OnError` handler hides from stderr still
ends the thread it was raised in: in the auto-execute section the run fails
with a critical `runtime` finding (the fork still exits 10); in a later thread
of a script that stays resident it is reported as `error-suppressed`.

**Flagged results never reach synthesis.** `CheckResults.py` drops anything
unreadable, unsentinelled, empty, timed out, self-contradictory, missing a
contracted tier extra, or produced after its branch should already have ended.
Results are compared within one run only — grouped by (`run`, script), the path
case-folded and slash-normalised for grouping while the emitted string is
preserved — so the same script graded in two runs is never a contradiction.
Cross-result flags withhold only the offending rows: a stray row produced after
its branch ended is dropped, while the failing gate result that ended the
branch is legitimate evidence and still reaches synthesis. A present tier whose
earlier gate tier is absent, when that run demonstrably covered the gate tier,
is flagged — missing middle tiers included; tiers absent after a failure are
correct and never flagged. Pure-tier contradictions are flagged too: `pass`
with failed assertions, or assertions counted with `tests: 0`. Counts must be
non-negative integers. Values that describe what happened rather than how the
row was written — a `restore-failed` guard, a stolen focus, an empty backend
verdict on an error row — are data, never flags. A leading UTF-8 byte-order
mark is ignored. Exit codes: 0 = every result survived, 1 = at least one
flagged, 2 = usage or tool error (bad arguments, unreadable input, unwritable
`--out`) — data problems inside a readable file are flags, not tool errors.

## Severity

`critical` ends a branch. `high` is a defect. `medium` is worth fixing. `low` is
advisory and never drives a fix on its own.

| rule | rank | tier | meaning |
|---|---|---|---|
| `parse`, `runtime`, `hung`, `missing-file` | critical | all | the script did not load, died, or wedged (in the pure tier a test that is still running at the deadline is `hung` either way: a test is meant to end) |
| `error-dialog` | critical | dryrun, pure | an AutoHotkey error dialog appeared; the run was ended |
| `test-crash` | critical | pure | a test file died before its summary, or its summary disagreed with its exit |
| `harness-leak`, `focus-stolen` | critical | live | the live sandbox did not hold |
| `assert` | high | pure | a unit-test assertion failed; the message names the test file, case and label, and `line` is in the test file |
| `dialog`, `focus-stolen` | high | dryrun, pure | a dialog got past the shim; the candidate took the foreground |
| `shim-bypass` | high | dryrun, pure | the script (or test) uses `#Import`, `#Module` or an `Import` statement and was not run |
| `clipboard-restore-failed` | high | dryrun, pure | the user's clipboard could not be put back |
| `nonzero-exit` | high | dryrun | the candidate exited nonzero and said nothing |
| `window-leak`, `warn-dialog`, `error-suppressed`, `warn` | medium | dryrun, pure | see the rules above |
| `test-not-run`, `protocol` | medium | pure | a test file could not be launched; a malformed `AHKTEST` record |

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

## Reporting

`Report.py` turns harness NDJSON (normally the checker's clean output) into CI
formats: SARIF 2.1.0, JUnit XML, GitHub workflow annotations and Markdown.

- **Fingerprints survive line shifts.** Each finding's fingerprint hashes its
  tier, rule, root-relative path, the *text* of the source line it points at
  (whitespace-collapsed) and a normalised message (digits, quoted strings and
  paths replaced), plus an occurrence index within that row. Inserting lines
  above a finding does not change it, so a `--baseline` written today still
  suppresses the same findings tomorrow. Write and apply a baseline with the
  same `--root`. A finding that points into another file — every pure-tier
  finding (an assertion's line is in the test file) and any diagnostic marked
  `[in other.ahk]` — is signed by its message alone, since the row's own
  script holds unrelated text at that line.
- `error` and `timeout` rows always surface (ranked critical) and are never
  suppressed by a baseline, so CI cannot read a broken tool as clean.
- JUnit follows row status; the exit code follows findings against `--fail-on`
  (default `high`). A static row with only high findings is a pass row, so use
  `--fail-on critical` when the exit code should match the JUnit view.

## Tools

| tier | tool | state |
|---|---|---|
| `static` | `GateStatic.ahk` | fork `check` + `/validate` + Lint + CodeIntel + v1 scan; also feeds the post-edit hook via `.claude/hooks/lint-runner.ahk` |
| `pure` | `GatePure.ahk` + `TestKit.ahk` (`Assert.ahk` alias) | runs a script's unit tests (`<stem>.test.ahk`, `Test_<stem>.ahk`, `<stem>_Test.ahk`, beside it or in `Tests\`/`tests\`/`!Tests\`) under the shim; deterministic, no paid grading involved |
| `dryrun` | `GateDryRun.ahk` + `ShimRun.ahk` + `DryRunShim.ahk` | runs the candidate in place under the shim, jobbed and watched |
| `live` | `GateLive.ahk` | an adapter over [ahkh](https://github.com/owhs/AHKTestHarness) (hidden desktop, dialog catching, message-based input), pinned to the gate's own interpreter through `AHKH_AHK` and serialised by lock; reports `status: "error"` until ahkh is installed and built (`AHKH_HOME`) |
| checker | `CheckResults.py` | drops untrustworthy rows; reports coverage |
| reporting | `Report.py` | SARIF / JUnit / GitHub / Markdown, with line-shift-tolerant baselines |
| triage | `Reduce.ahk` | delta-debugs a failing script down to the fewest lines that still fail the same way |
| proof | `SelfTest.ahk --run` | runs every gate against canaries with known verdicts and checks them, including that the canaries' attempted side effects never landed |

Generating new unit tests with a model is a separate, opt-in step (the
`ahk-test-generator` agent) and is the only part of grading that spends money;
running the tests that exist does not.

## Running the gates from a shell

The fork's `AutoHotkey64.exe` is a GUI-subsystem program, so PowerShell does not
wait for it when its output is redirected to a file — the gate keeps running
detached and the redirect captures nothing. Pipe it instead:

```powershell
& $ahk GateDryRun.ahk one.ahk two.ahk 2>err.txt | Set-Content -Encoding utf8 results.ndjson
```

Bash (Git Bash or WSL) waits normally. Python on Windows is usually `python` or
`py -3`; `python3` is often the Microsoft Store stub that runs nothing.
