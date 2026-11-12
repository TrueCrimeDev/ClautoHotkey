#!/usr/bin/env node
// Drives opencode/clautohotkey.ts the way OpenCode does, without a model: calls its
// config hook, the system-prompt transform, the v1 detector, the interpreter guard
// and the post-edit validator against a scratch project, and prints PASS/FAIL per
// check. Needs Node 22.6+ (TypeScript type stripping) and the same bash + AutoHotkey
// the hooks need. Run from anywhere:
//
//   node opencode/selftest.mjs
//
// Exit code 1 if any check failed.
import { spawn } from "node:child_process"
import { mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { Readable } from "node:stream"
import { fileURLToPath, pathToFileURL } from "node:url"

const HERE = dirname(fileURLToPath(import.meta.url))

// The plugin runs under Bun inside OpenCode; give it the two Bun.spawn pieces it uses.
globalThis.Bun ??= {}
globalThis.Bun.spawn ??= (cmd, opts = {}) => {
  const child = spawn(cmd[0], cmd.slice(1), { cwd: opts.cwd, env: opts.env, stdio: ["pipe", "pipe", "pipe"] })
  const exited = new Promise((resolve) => child.on("close", (code) => resolve(code ?? 0)))
  // A hook that never reads its stdin (the session primer) exits with the pipe
  // still open; the write then fails with EPIPE, which says nothing about the hook.
  child.stdin.on("error", () => {})
  if (opts.stdin && typeof opts.stdin.text === "function") {
    opts.stdin.text().then((text) => child.stdin.end(text))
  } else {
    child.stdin.end()
  }
  return {
    stdout: Readable.toWeb(child.stdout),
    stderr: Readable.toWeb(child.stderr),
    exited,
    kill: () => child.kill(),
  }
}

const results = []
function check(name, ok, detail = "") {
  results.push({ name, ok, detail })
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? `  (${detail})` : ""}`)
}

const project = mkdtempSync(join(tmpdir(), "clautohotkey-oc-"))
try {
  const mod = await import(pathToFileURL(join(HERE, "clautohotkey.ts")).href)
  const plugin = mod.default
  const hooks = await plugin({ directory: project, worktree: project, project: {}, client: {}, serverUrl: new URL("http://127.0.0.1:0"), $: undefined })
  // Unique per run: inject-rules.sh remembers what it injected per session id.
  const sessionID = `selftest-${Date.now()}`

  // config: agents, commands, skills as commands
  const cfg = {}
  await hooks.config(cfg)
  const agents = Object.keys(cfg.agent ?? {})
  const commands = Object.keys(cfg.command ?? {})
  check("config registers agents", agents.includes("ahk-analysis") && agents.includes("layout"), `${agents.length} agents`)
  check("config registers skills as commands", commands.includes("ahk-fix") && commands.includes("ahk-gui"), `${commands.length} commands`)
  check("config registers commands", commands.includes("prime-ahk"))
  check("skill bodies name the clone, not ${CLAUDE_PLUGIN_ROOT}", !/\$\{CLAUDE_PLUGIN_ROOT\}/.test(cfg.command["ahk-fix"].template))
  check("layout agent tools are restricted", cfg.agent.layout.tools?.bash === false && cfg.agent.layout.tools?.edit === true)

  // system prompt: primer present
  const sys = { system: [] }
  await hooks["experimental.chat.system.transform"]({}, sys)
  const sysText = sys.system.join("\n")
  check("system prompt carries the primer", /ClautoHotkey \(OpenCode\)/.test(sysText) && /Skill & Agent Routing|Session Context/.test(sysText), `${sysText.length} chars`)

  // v1 detection -> note on the next system prompt
  await hooks["chat.message"]({ sessionID }, { message: {}, parts: [{ type: "text", text: "MsgBox, hello\nStringLeft, out, var, 3\nIfEqual, a, b" }] })
  const sys2 = { system: [] }
  await hooks["experimental.chat.system.transform"]({}, sys2)
  check("v1 syntax in a prompt adds a warning", sys2.system.some((s) => /v1 syntax/.test(s)))

  // interpreter guard blocks a foreign AutoHotkey binary
  let blocked = ""
  try {
    await hooks["tool.execute.before"]({ tool: "bash", sessionID, callID: "c1" }, { args: { command: '"C:/Program Files/AutoHotkey/v2/AutoHotkey32.exe" x.ahk' } })
  } catch (e) {
    blocked = String(e.message)
  }
  check("bash guard blocks a non-configured AutoHotkey exe", /blocked/i.test(blocked), blocked.split("\n")[0])
  let passed = true
  try {
    await hooks["tool.execute.before"]({ tool: "bash", sessionID, callID: "c2" }, { args: { command: "git status" } })
  } catch {
    passed = false
  }
  check("bash guard lets ordinary commands through", passed)

  // broken edit -> validation failure appended to the tool result
  const bad = join(project, "bad.ahk")
  writeFileSync(bad, "#Requires AutoHotkey v2.0\nx := (\n")
  await hooks["tool.execute.before"]({ tool: "write", sessionID, callID: "w1" }, { args: { filePath: bad, content: "" } })
  const out1 = { title: "bad.ahk", output: "Wrote file", metadata: {} }
  await hooks["tool.execute.after"]({ tool: "write", sessionID, callID: "w1" }, out1)
  check("broken .ahk edit reports VALIDATION FAILED", /VALIDATION FAILED/.test(out1.output), out1.output.split("\n").find((l) => /Line|error/i.test(l)) ?? "")
  check("path-scoped rules are appended on the first .ahk edit", /Rule: ahk-v2-syntax/.test(out1.output))

  // good edit -> validated
  const good = join(project, "good.ahk")
  writeFileSync(good, "#Requires AutoHotkey v2.0\nx := 1\n")
  await hooks["tool.execute.before"]({ tool: "write", sessionID, callID: "w2" }, { args: { filePath: good, content: "" } })
  const out2 = { title: "good.ahk", output: "Wrote file", metadata: {} }
  await hooks["tool.execute.after"]({ tool: "write", sessionID, callID: "w2" }, out2)
  check("valid .ahk edit reports validated", /validated good\.ahk/.test(out2.output) && !/FAILED/.test(out2.output), out2.output.split("\n").pop())
  check("rules are injected once per session", !/Rule: ahk-v2-syntax/.test(out2.output))

  // non-.ahk edits are left alone
  const out3 = { title: "notes.md", output: "Wrote file", metadata: {} }
  await hooks["tool.execute.before"]({ tool: "write", sessionID, callID: "w3" }, { args: { filePath: join(project, "notes.md") } })
  await hooks["tool.execute.after"]({ tool: "write", sessionID, callID: "w3" }, out3)
  check("non-.ahk edits are untouched", out3.output === "Wrote file")
} catch (e) {
  check("plugin loads and runs", false, String(e?.stack ?? e))
} finally {
  rmSync(project, { recursive: true, force: true })
}

const failed = results.filter((r) => !r.ok).length
console.log(`\n${results.length - failed}/${results.length} checks passed`)
process.exit(failed ? 1 : 0)
