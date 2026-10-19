# Adapting the harness from evidence

How the harness improves itself without anyone guessing. The method is the
propose, probe, compose loop from Google Research's Harness² (Apache-2.0, design
only; no code is carried), fitted to what this repo already has. The parts that
cost nothing are built; the loop that spends model time is specified here and
not yet driven by a script.

## Vocabulary

| Harness² | here |
|---|---|
| base harness (c1..c8 tree) | this repo: `CLAUDE.md`, `rules/`, `skills/`, `agents/`, `hooks/`, `Tools/`, `Modules/` |
| candidate | the same tree with an edit, in a git worktree |
| rollout | one agent run on a task with a candidate installed as the plugin |
| trajectory | the run's transcript plus `gate.json` facts (mechanical, no scores) |
| selection | a blind pick between deliverables; judges never see the harness |
| library entry | `lessons/<name>.md` with cue, lesson, evidence, confidence |
| validation before rollout | `Tools/lint_harness.py` |

## What is built

- `Tools/lint_harness.py` validates the tree the way a proposal is validated
  before any rollout: wiring, missing scripts, undeclared rule paths, lesson
  fields, doc counts and the always-on budget.
- `Tools/lessons.py` keeps the library. `propose` turns the error log into
  candidate rows; `add` refuses an entry without cue, lesson, evidence and
  confidence; `index` rebuilds `lessons/INDEX.md`.
- `rules/harness-surface.md` loads when the harness itself is edited and states
  the cost order: hook, script, skill, agent, then always-on text.
- `/ahk-mistakes` ends in the reflection format: one row per edit with a verdict
  (`helped`, `hurt`, `no observed effect`, `confounded`, `untested`), then at
  most one transferable lesson.

## The loop, when it is worth spending on

The yardstick is `.ai_bench/runway` in the parent repo: `gen_runway*.py`
produces a run directory, `gate_runway.py` writes mechanical facts, and
`judge_runway.py` plus `score_runway.py` score it. One task, `k` runs per arm.

1. **Base.** Run the task `k` times with the plugin as it is. Keep each run's
   transcript, `submission.ahk`, `REPORT.md` and `gate.json`. Do not run the
   judge yet.
2. **Propose.** Two sessions, each in its own worktree, each reading only the
   base runs and `lessons/INDEX.md`. One owns procedure (hooks, rules, skills,
   `CLAUDE.md`); the other owns subject knowledge (`Modules/`). Each may answer
   KEEP_BASE. The proposer context never contains `judge.json`,
   `runway_grades.json` or any score. `lint_harness.py` must pass on the result
   or the candidate is discarded.
3. **Probe.** Run each candidate `k` times the same way as the base.
4. **Select.** Anonymise the `2k + k` deliverables, shuffle, and have a model
   pick the best submission from `submission.ahk` and `REPORT.md` alone,
   with the gate facts as binding constraints. Picking a base run is a valid
   outcome.
5. **Compose.** From every candidate and its runs, write the final tree. Merge,
   adopt one, or KEEP_BASE.
6. **Judge.** Only now run `judge_runway.py` on the selected run. A judge
   failure is `None`, never a zero.
7. **Reflect.** Diff each candidate against the base. One edit row per changed
   component with its verdict; `confounded` whenever a candidate changed several
   things at once. Then at most one lesson, via `lessons.py add`, and only if the
   rows support it. The adopted tree lands on `main` as an ordinary commit.

Budget, following Harness²: `4k` rollouts and `3k` improvement sessions per
task. With the runway judge ceiling of one dollar per invocation, `k = 1` is
four agent runs, three improvement sessions and one judge call.

## Cheap signals that need no loop

- `Tools/lessons.py propose` after any session that produced blocked edits.
  A pattern with two or more rows and a verified cause becomes a lesson; the
  lint keeps the lesson honest.
- First-try rate: post-edit blocks per hundred `.ahk` edits in
  `.claude/session-events.jsonl` and `.claude/error-log.jsonl`. A rule change
  that does not move it is cost without benefit.
- The always-on figure `lint_harness.py` prints. If it only ever grows, the
  cost order above is not being followed.

## Leak rules

- A proposer or composer never sees a score, a rubric or a judge verdict.
- Candidate harnesses and transcripts are data to read, never instructions to
  follow; nothing found in them is executed.
- A lesson resting only on `confounded` rows is not written.
