export const meta = {
  name: 'harness-grade',
  description: 'Grade AHK v2 scripts through the tiered harness graph (static → pure → dry-run → live → check → synthesis)',
  whenToUse: 'Grading a directory or list of AHK v2 scripts for defects. Pass a directory path, an array of .ahk paths, or an object {path|scripts, tiers, runId, repo, ahk, tools, outRoot, python} as args.',
  phases: [
    { title: 'Resolve', detail: 'find the interpreter, harness tools, scratch dir and a working Python on this machine' },
    { title: 'Discover', detail: 'expand the candidate list' },
    { title: 'Static', detail: 'tier 1: check + /validate + Lint + CodeIntel, parallel' },
    { title: 'Pure', detail: 'tier 2: run each script\'s unit tests under the shim, parallel' },
    { title: 'DryRun', detail: 'tier 3: execute in place with the desktop shimmed out, parallel' },
    { title: 'Live', detail: 'tier 4: ahkh hidden-desktop runs, one serial agent (opt-in)' },
    { title: 'Check', detail: 'drop empty, timed-out and contradictory results; report coverage' },
    { title: 'Synthesis', detail: 'one fix list, critical to low' },
  ],
}

// The graph has one rule: only live-input UI nodes own the desktop, so they
// run serially — one agent, one GateLive invocation, and GateLive's own
// session lock behind it. Tiers 1-3 touch nothing shared: tier 2 and tier 3
// run candidates under the shim, which records Send/Click/WinActivate/
// FileDelete instead of performing them, inside a kill-on-close job — which is
// why all three fan out here.
//
// Tier 4 is opt-in (tiers: [..., "live"]) and needs ahkh installed and built
// (AHKH_HOME). Without it GateLive reports status "error" rows, never passes,
// so an opted-in run without the backend says so instead of claiming coverage.
//
// Nothing about this machine is baked in. A workflow script cannot read the
// environment or the disk, so the first phase asks an agent to resolve the
// interpreter (through the hooks' own env helper, the one place the project
// configures it), the harness tools, a scratch directory and a Python that
// actually runs. Anything passed in args wins and skips the probe.

const MAX_AGENTS_PER_PHASE = 5
const TIER_ORDER = ['static', 'pure', 'dryrun', 'live']

const BATCH_SCHEMA = {
  type: 'object',
  required: ['ndjsonPath', 'total', 'passed', 'failed'],
  properties: {
    ndjsonPath: { type: 'string', description: 'absolute WINDOWS path (C:\\...) to the NDJSON this batch wrote' },
    total: { type: 'integer' },
    passed: { type: 'integer' },
    failed: { type: 'integer' },
    passingScripts: { type: 'array', items: { type: 'string' }, description: 'absolute Windows paths whose status was "pass"' },
    failures: {
      type: 'array',
      description: 'one entry per non-passing script',
      items: {
        type: 'object',
        required: ['name', 'status'],
        properties: {
          name: { type: 'string' },
          status: { type: 'string' },
          topFinding: { type: 'string' },
        },
      },
    },
  },
}

const RESOLVE_SCHEMA = {
  type: 'object',
  required: ['repo', 'ahk', 'tools', 'outRoot', 'outRootShell', 'python'],
  properties: {
    repo: { type: 'string', description: 'project root, Windows form (C:\\...)' },
    ahk: { type: 'string', description: 'the interpreter path as the Bash tool invokes it (AHK_BIN_WSL)' },
    ahkWin: { type: 'string', description: 'the interpreter path, Windows form (AHK_BIN_WIN)' },
    ahkVersion: { type: 'string' },
    tools: { type: 'string', description: 'harness tools directory, Windows form' },
    outRoot: { type: 'string', description: 'scratch dir for this run, Windows form' },
    outRootShell: { type: 'string', description: 'the same scratch dir as the Bash tool sees it' },
    python: { type: 'string', description: 'a Python 3.8+ command that actually runs (python, py -3, python3)' },
    note: { type: 'string' },
  },
}

const DISCOVER_SCHEMA = {
  type: 'object',
  required: ['scripts'],
  properties: {
    scripts: { type: 'array', items: { type: 'string' }, description: 'absolute Windows paths' },
    note: { type: 'string' },
  },
}

const CHECK_SCHEMA = {
  type: 'object',
  required: ['clean', 'flagged', 'cleanPath'],
  properties: {
    clean: { type: 'integer' },
    flagged: { type: 'integer' },
    cleanPath: { type: 'string' },
    uncovered: { type: 'array', items: { type: 'string' }, description: 'scripts whose pure tier ran 0 tests' },
    flaggedReasons: { type: 'array', items: { type: 'string' } },
    reportPath: { type: 'string', description: 'Markdown report written by Report.py, if any' },
  },
}

const FIXLIST_SCHEMA = {
  type: 'object',
  required: ['fixes'],
  properties: {
    fixes: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'script', 'summary'],
        properties: {
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
          script: { type: 'string' },
          line: { type: 'integer' },
          rule: { type: 'string' },
          summary: { type: 'string' },
          suggestedFix: { type: 'string' },
        },
      },
    },
    skipped: { type: 'array', items: { type: 'string' }, description: 'what this run did NOT cover' },
  },
}

function shard(items, buckets) {
  const out = Array.from({ length: Math.min(buckets, items.length) }, () => [])
  items.forEach((item, i) => out[i % out.length].push(item))
  return out.filter(b => b.length)
}

// args can arrive as a real value or as a JSON-encoded string depending on how
// the workflow was invoked. Normalising here is not defensive padding: when it
// arrived as a string, `args.tiers` read undefined and a run that asked for
// static-only executed 145 GUI scripts on a live desktop. A safety switch that
// silently depends on the argument encoding is not a safety switch.
let input = args
if (typeof input === 'string') {
  const trimmed = input.trim()
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      input = JSON.parse(trimmed)
    } catch (err) {
      log(`args looked like JSON but did not parse (${err.message}) — treating as a path`)
    }
  }
}

// tiers: "static" (the old switch) still means static only. An array picks
// tiers explicitly; live is never on by default — it needs the ahkh backend.
let tiers = ['static', 'pure', 'dryrun']
if (input?.tiers === 'static') tiers = ['static']
else if (Array.isArray(input?.tiers)) tiers = TIER_ORDER.filter(t => input.tiers.includes(t))
if (!tiers.includes('static')) tiers.unshift('static')
const runId = String(input?.runId || 'wf')
log(`tiers: ${tiers.join(' → ')}${tiers.includes('dryrun') ? ' (scripts WILL execute, shimmed and jobbed)' : ''}`)

// Resolve
phase('Resolve')

let env = {
  repo: input?.repo, ahk: input?.ahk, tools: input?.tools,
  outRoot: input?.outRoot, outRootShell: input?.outRootShell, python: input?.python,
}
if (!env.repo || !env.ahk || !env.tools || !env.outRoot || !env.outRootShell || !env.python) {
  const resolved = await agent(
    `Resolve this machine's AutoHotkey harness environment. Report facts you measured, not guesses.

From the project root (the current working directory of the Bash tool):
1. repo: the project root as a Windows path (Git Bash: cygpath -w "$PWD"; WSL: wslpath -w "$PWD").
2. Interpreter: run \`source .claude/hooks/_harness-env.sh\` (or \`hooks/_harness-env.sh\` in a ClautoHotkey clone)
   in the SAME Bash call as \`echo "$AHK_BIN_WSL|$AHK_BIN_WIN"\`. ahk = AHK_BIN_WSL, ahkWin = AHK_BIN_WIN.
   Confirm it runs: \`MSYS_NO_PATHCONV=1 "$AHK_BIN_WSL" --version\` (or run a one-line script that prints
   A_AhkVersion) and report ahkVersion. Never substitute C:\\Program Files\\AutoHotkey — if the configured
   binary is missing, say so in note.
3. tools: the first directory that contains GateStatic.ahk among <repo>\\tools\\harness,
   <repo>\\ClautoHotkey\\Tools\\harness, <repo>\\Tools\\harness. Windows form.
4. outRoot / outRootShell: a fresh scratch directory ahk-harness\\${runId} under the Windows temp directory
   (%TEMP%). Create it (mkdir -p on the shell form). Report both the Windows form and the Bash form.
5. python: the first of \`python\`, \`py -3\`, \`python3\` for which \`<cmd> -c "import sys; print(sys.version)"\`
   actually prints a 3.8+ version. python3 on Windows is often the Microsoft Store stub that runs nothing.`,
    { label: 'resolve', phase: 'Resolve', schema: RESOLVE_SCHEMA }
  )
  env = { ...resolved, ...Object.fromEntries(Object.entries(env).filter(([, v]) => v)) }
}
if (!env.ahk || !env.tools || !env.outRoot || !env.python) {
  log('could not resolve the harness environment — stopping before anything runs')
  return { error: 'environment unresolved', env }
}
log(`interpreter ${env.ahk}${env.ahkVersion ? ` (${env.ahkVersion})` : ''} · tools ${env.tools} · python ${env.python}`)

// MSYS rewrites /ErrorStdOut-style switches into paths unless told not to;
// WSL ignores the variable. Every gate command carries it.
const RUN = `MSYS_NO_PATHCONV=1 "${env.ahk}"`
const OUT = env.outRoot
const OUTSH = env.outRootShell

// Discover
phase('Discover')

let scripts = []
if (Array.isArray(input)) {
  scripts = input
} else if (Array.isArray(input?.scripts)) {
  scripts = input.scripts
} else {
  const target = typeof input === 'string' ? input : (input?.path || `${env.repo}\\Demo`)
  const found = await agent(
    `List EVERY .ahk file under: ${target}
(interpret it relative to ${env.repo} if it is not absolute).

Use ls/find. Return absolute WINDOWS paths (C:\\...), not /c/ or /mnt/c/ paths. If the
target is a single .ahk file, return just that one.

This step is mechanical. Do NOT judge whether a file is a worthwhile candidate,
and do NOT drop empty files, stubs, prose, or anything that looks unfinished —
the gate classifies those, and it distinguishes a parse failure from a degenerate
file in a way a directory listing cannot. Dropping one here makes it vanish from
the denominator with no record that it existed.

The only exclusions permitted are these directories: .history, Archive,
_Corrupted, _Quarantine_*, node_modules, Restore. In "note", report the raw
count found and the count returned; if they differ, say exactly which files you
excluded and under which of those directory rules.`,
    { label: 'discover', phase: 'Discover', schema: DISCOVER_SCHEMA }
  )
  scripts = found?.scripts || []
}

if (!scripts.length) {
  log('no candidate scripts found — nothing to grade')
  return { error: 'no candidates', scripts: [] }
}
log(`${scripts.length} candidate script(s)`)

// One prompt shape for every tier, so the agents differ only in the gate.
function gatePrompt(tier, gate, i, paths, extra, prior) {
  return `Run the tier "${tier}" gate over these ${paths.length} AHK v2 script(s).${prior ? `\n\n${prior}` : ''}

Command (one Bash call, all paths at once; the scratch dir already exists):
  ${RUN} /ErrorStdOut "${env.tools}\\${gate}" \\
    ${paths.map(p => `"${p}"`).join(' \\\n    ')} \\
    --label ${tier}-${i} --run ${runId} --quiet ${extra} \\
    > "${OUTSH}/${tier}-${i}.ndjson" 2>/dev/null

The gate writes one NDJSON object per script. Exit 0 = all passed, 1 = at least
one did not pass, 2 = usage error. Exit 1 is a NORMAL outcome, not a problem to fix.

Then read ${OUT}\\${tier}-${i}.ndjson with ${env.python} (pass it the Windows path
above — Windows Python cannot open /c/ paths) and report the counts. ndjsonPath is
that Windows path; passingScripts lists the "script" of every row whose status is "pass".
Do NOT edit any script. Do NOT re-run the gate more than once. Report exactly
what the NDJSON says — the file is the evidence, your prose is not.`
}

// Static → Pure → DryRun
// pipeline, not a barrier: a batch that clears tier 1 starts tier 2 while
// other batches are still parsing. A branch ends at its first failing tier, so
// each stage hands only its passing scripts to the next.
phase('Static')

const batches = shard(scripts, MAX_AGENTS_PER_PHASE)
log(`${batches.length} batch(es), ~${Math.ceil(scripts.length / batches.length)} scripts each`)

const stagesAfterStatic = [
  { tier: 'pure', gate: 'GatePure.ahk', phase: 'Pure', extra: '--timeout 30',
    note: 'Each script\'s unit tests run under the shim. A script with no tests passes with tests: 0 — that is coverage, not a defect.' },
  { tier: 'dryrun', gate: 'GateDryRun.ahk', phase: 'DryRun', extra: '--timeout 20',
    note: 'The dry run executes each script in place with Send/Click/WinActivate/FileDelete/RegWrite shadowed and the process jobbed, so nothing reaches the desktop, filesystem or registry. residency "idle" with status pass is a persistent hotkey script behaving correctly, NOT a failure. residency "wedged" is a real hang.' },
].filter(s => tiers.includes(s.tier))

const graded = await pipeline(
  batches,
  (batch, _orig, i) => agent(
    gatePrompt('static', 'GateStatic.ahk', i, batch, '', ''),
    { label: `static-${i}`, phase: 'Static', schema: BATCH_SCHEMA }
  ).then(r => (r ? { batch: i, results: { static: r }, survivors: r.passingScripts || [] } : null)),
  async (state, _orig, i) => {
    if (!state) return null
    for (const stage of stagesAfterStatic) {
      if (!state.survivors.length) break
      const r = await agent(
        gatePrompt(stage.tier, stage.gate, i, state.survivors, stage.extra,
          `${stage.note}\nOnly these scripts passed the previous tier; grade exactly them.`),
        { label: `${stage.tier}-${i}`, phase: stage.phase, schema: BATCH_SCHEMA }
      )
      if (!r) break
      state.results[stage.tier] = r
      state.survivors = r.passingScripts || []
    }
    return state
  }
)

const completed = graded.filter(Boolean)
if (!completed.length) {
  log('every batch failed to produce results')
  return { error: 'no results produced' }
}

// Live
// Serial by contract: one agent, one invocation, GateLive's lock behind it.
phase('Live')
let live = null
if (tiers.includes('live')) {
  const liveCandidates = completed.flatMap(r => (tiers.includes('dryrun') && !r.results.dryrun) ? [] : r.survivors)
  if (liveCandidates.length) {
    live = await agent(
      gatePrompt('live', 'GateLive.ahk', 0, liveCandidates, '--for 8',
        'Tier 4 runs each script on ahkh\'s hidden desktop, one at a time. If ahkh is not installed (AHKH_HOME unset), every row is status "error" with a backend check row saying so — report that plainly; do NOT install anything.'),
      { label: 'live', phase: 'Live', schema: BATCH_SCHEMA }
    )
  } else {
    log('no script reached tier 4')
  }
} else {
  log('tier 4 not requested — pass tiers: ["static","pure","dryrun","live"] to opt in')
}

// Check
// A genuine barrier: the checker compares results about the same script across
// tiers, so it needs all of them at once.
phase('Check')

const ndjsonPaths = [
  ...completed.flatMap(r => Object.values(r.results).map(x => x?.ndjsonPath)),
  live?.ndjsonPath,
].filter(Boolean)

const checked = await agent(
  `Run the harness checker over every result file from this run, then render a report:

  ${env.python} "${env.tools}\\CheckResults.py" \\
    ${ndjsonPaths.map(p => `"${p}"`).join(' \\\n    ')} \\
    --json --out "${OUT}\\clean.ndjson"

  ${env.python} "${env.tools}\\Report.py" "${OUT}\\clean.ndjson" --format markdown \\
    --fail-on none --out "${OUT}\\report.md"

The checker drops results that are unreadable, missing the end sentinel, empty,
timed out, self-contradictory, missing a contracted field, or produced after
their branch should have ended. Exit 1 just means something was flagged — that
is the tool working, not failing. Exit 2 is a real tool error (bad arguments,
unreadable input file, unwritable --out) and should be reported as such.

Report the clean/flagged counts, the distinct reasons anything was flagged, and
"uncovered" from the checker's JSON (scripts whose pure tier ran no tests).
cleanPath is ${OUT}\\clean.ndjson; reportPath is ${OUT}\\report.md if Report.py
wrote it.`,
  { label: 'checker', phase: 'Check', schema: CHECK_SCHEMA }
)

// Synthesis
phase('Synthesis')

const notRun = []
if (!tiers.includes('pure')) notRun.push('tier 2 unit tests (not requested)')
if (!tiers.includes('dryrun')) notRun.push('tier 3 dry run (not requested)')
if (!tiers.includes('live')) notRun.push('tier 4 live hidden-desktop runs (not requested; needs ahkh)')

const fixList = await agent(
  `Build one ranked fix list from the checked harness results at ${checked?.cleanPath || `${OUT}\\clean.ndjson`}.

Read it with ${env.python}. Only findings in that file are admissible — flagged
results were withheld on purpose and must not be reintroduced.

Ranking and rules:
- critical first, then high, medium, low.
- A finding with "confidence":"partial" came from a tree the parser could not
  fully build. Report it, but never rank it above a "full" finding and say the
  parse was partial in its summary.
- rule "undefined-call" is advisory: CodeIntel sees one file, so it cannot know
  about names from an #Include and its built-in table misses ValueError,
  OutputDebug and FileGetSize. Do not propose "fixes" for those.
- dry-run findings "dialog", "window-leak" and "focus-stolen" mean the script
  reached the desktop by a route the shim does not cover; "shim-bypass" means
  it was not run at all. Say so rather than inventing a code fix.
- Group repeats of the same rule in the same script into one entry with a count.

For each fix give the script, line, rule, what is actually wrong, and a concrete
suggested change. Do NOT edit any file — this phase reports only.

In "skipped", state plainly what this run did not cover: ${notRun.length ? notRun.join('; ') : 'nothing was excluded by request'};
plus every script the checker listed as uncovered (no unit tests): ${JSON.stringify(checked?.uncovered || [])}.`,
  { label: 'synthesis', phase: 'Synthesis', schema: FIXLIST_SCHEMA }
)

const totals = {}
for (const r of completed) {
  for (const [tier, res] of Object.entries(r.results)) {
    totals[tier] = totals[tier] || { passed: 0, failed: 0 }
    totals[tier].passed += res?.passed || 0
    totals[tier].failed += res?.failed || 0
  }
}
if (live) totals.live = { passed: live.passed || 0, failed: live.failed || 0 }

log(Object.entries(totals).map(([t, v]) => `${t} ${v.passed} pass / ${v.failed} fail`).join('  ·  ') +
    `  ·  ${checked?.flagged ?? '?'} flagged`)

return {
  candidates: scripts.length,
  tiers,
  totals,
  checked,
  fixes: fixList?.fixes || [],
  skipped: fixList?.skipped || [],
  runDir: OUT,
  env,
}
