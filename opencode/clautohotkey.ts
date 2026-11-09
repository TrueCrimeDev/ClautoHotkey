// ClautoHotkey for OpenCode (1.x plugin API).
//
// Loaded straight from the clone through a `plugin` entry in opencode.json
// (opencode/install.sh writes it), so the agents, commands, rules and hook
// scripts stay live: edit them here and the next OpenCode session sees them.
//
// What it does, mapped from the Claude Code plugin (hooks/hooks.json):
//   config                          agents/*.md -> config.agent, commands/*.md and
//                                   skills/*/SKILL.md -> config.command (/<name>)
//   experimental.chat.system.transform  hooks/ahk-session-primer.sh (session context,
//                                   harness status) plus a v1-syntax warning
//   tool.execute.before  bash       hooks/check-ahk-binary.sh, check-git-account.sh
//                                   (exit 2 blocks the command)
//   tool.execute.before  edit/write hooks/inject-rules.sh (path-scoped rules, once per
//                                   session, appended to that edit's result)
//   tool.execute.after   edit/write hooks/ahk-post-edit.sh (syntax + runtime check; a
//                                   failure is appended to the result so the model
//                                   fixes it), hooks/ahk-auto-reload.sh
//   tool.execute.after   bash       skills/ahk-mistakes/hooks/error-logger.sh,
//                                   hooks/ahk-auto-reload.sh
//   chat.message                    hooks/detect-v1-syntax.sh
//
// The hook scripts are the same files Claude Code runs. They read the Claude Code
// hook payload on stdin, so this file builds that payload and runs them with bash
// (Git Bash on Windows, or the system bash under WSL and Linux).

import type { Plugin } from "@opencode-ai/plugin"
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs"
import { basename, dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

type Dict = Record<string, any>

const HERE = dirname(fileURLToPath(import.meta.url))
const ROOT = dirname(HERE)
const ROOT_FWD = ROOT.replace(/\\/g, "/")
const IS_WIN = process.platform === "win32"
const TAG = "[ClautoHotkey]"

const ANSI = /\x1b\[[0-9;]*m/g
const BOX = /[━─┌┐└┘│├┤┬┴┼▸]/g

function clean(text: string): string {
  return text
    .replace(ANSI, "")
    .split(/\r?\n/)
    .map((line) => line.replace(BOX, "").replace(/\s+$/, ""))
    .filter((line, i, arr) => line.trim() !== "" || (i > 0 && arr[i - 1].trim() !== ""))
    .join("\n")
    .trim()
}

// YAML subset used by this repo's frontmatter: `key: value`, `key: >` or `key: |`
// folded blocks, and `key:` list blocks (returned as arrays).
function frontmatter(text: string): { meta: Dict; body: string } {
  const meta: Dict = {}
  if (!text.startsWith("---")) return { meta, body: text }
  const end = text.indexOf("\n---", 3)
  if (end < 0) return { meta, body: text }
  const head = text.slice(text.indexOf("\n") + 1, end).split(/\r?\n/)
  const body = text.slice(end + 4).replace(/^\r?\n/, "")
  let i = 0
  while (i < head.length) {
    const m = head[i].match(/^([A-Za-z_][\w-]*):\s*(.*)$/)
    if (!m) {
      i++
      continue
    }
    const key = m[1]
    let value = m[2].trim()
    i++
    if (value === ">" || value === "|" || value === "") {
      const lines: string[] = []
      while (i < head.length && (/^\s/.test(head[i]) || head[i] === "")) {
        lines.push(head[i].trim())
        i++
      }
      if (lines.length && lines.every((l) => l === "" || l.startsWith("- "))) {
        meta[key] = lines.filter(Boolean).map((l) => l.slice(2).replace(/^["']|["']$/g, ""))
        continue
      }
      value = value === "|" ? lines.join("\n") : lines.join(" ")
    }
    meta[key] = value.replace(/^["']|["']$/g, "")
  }
  return { meta, body }
}

function read(path: string): string {
  return readFileSync(path, "utf8").replace(/\r\n/g, "\n")
}

// Skill and agent bodies name files under ${CLAUDE_PLUGIN_ROOT}; this install has
// no such variable, so the clone path is written in.
function localize(text: string): string {
  return text.replace(/\$\{CLAUDE_PLUGIN_ROOT\}|\$CLAUDE_PLUGIN_ROOT\b/g, ROOT_FWD)
}

// Claude Code tool names -> OpenCode tool ids. An agent that lists tools gets the
// rest of the editing tools switched off, which is what the list meant.
const TOOL_MAP: Dict = {
  read: "read", write: "write", edit: "edit", multiedit: "edit", grep: "grep", glob: "glob",
  bash: "bash", powershell: "bash", webfetch: "webfetch", websearch: "webfetch",
  agent: "task", task: "task", todowrite: "todowrite", todoread: "todoread",
}
const RESTRICTABLE = ["write", "edit", "bash", "patch", "webfetch", "task"]

function toolsFor(spec: unknown): Dict | undefined {
  if (typeof spec !== "string" || spec.trim() === "" || /all tools/i.test(spec)) return undefined
  const wanted = new Set<string>()
  for (const name of spec.split(",")) {
    const id = TOOL_MAP[name.trim().toLowerCase()]
    if (id) wanted.add(id)
  }
  if (!wanted.size) return undefined
  const tools: Dict = {}
  for (const id of RESTRICTABLE) tools[id] = wanted.has(id)
  for (const id of wanted) tools[id] = true
  return tools
}

function listMarkdown(dir: string): string[] {
  if (!existsSync(dir)) return []
  return readdirSync(dir)
    .filter((f) => f.endsWith(".md") && f.toLowerCase() !== "readme.md")
    .sort()
    .map((f) => join(dir, f))
}

function listSkills(dir: string): string[] {
  if (!existsSync(dir)) return []
  return readdirSync(dir)
    .map((d) => join(dir, d, "SKILL.md"))
    .filter((p) => !basename(dirname(p)).startsWith("_") && existsSync(p))
    .sort()
}

// bash for the hook scripts. Git Bash is preferred on Windows: System32\bash.exe is
// the WSL launcher, which would need the scripts' paths spelled as /mnt/c/...
function findBash(): string | undefined {
  const pinned = process.env.CLAUTOHOTKEY_BASH
  if (pinned && existsSync(pinned)) return pinned
  if (!IS_WIN) return "bash"
  const pf = process.env.ProgramFiles ?? "C:\\Program Files"
  const local = process.env.LOCALAPPDATA ?? ""
  const candidates = [
    join(pf, "Git", "bin", "bash.exe"),
    join(pf, "Git", "usr", "bin", "bash.exe"),
    join("C:\\Program Files (x86)", "Git", "bin", "bash.exe"),
    local && join(local, "Programs", "Git", "bin", "bash.exe"),
  ].filter(Boolean) as string[]
  for (const c of candidates) if (existsSync(c)) return c
  const path = (process.env.PATH ?? "").split(";")
  for (const dir of path) {
    if (!dir || /system32/i.test(dir)) continue
    const c = join(dir, "bash.exe")
    if (existsSync(c)) return c
  }
  return undefined
}

type HookResult = { code: number; stdout: string; stderr: string }

const Clautohotkey: Plugin = async ({ directory }) => {
  const bash = findBash()
  const project = directory
  const pendingRules = new Map<string, string[]>()
  const v1Note = new Map<string, string>()
  // tool.execute.after is not handed the call's arguments, so they are kept from
  // tool.execute.before under the call id.
  const argsByCall = new Map<string, Dict>()
  let primer: string | undefined

  async function runHook(script: string, payload: Dict, timeoutMs = 20000): Promise<HookResult> {
    const scriptPath = join(ROOT, script)
    if (!bash || !existsSync(scriptPath)) {
      return { code: 0, stdout: "", stderr: bash ? "" : `${TAG} bash not found; hooks inactive. Install Git for Windows or set CLAUTOHOTKEY_BASH.` }
    }
    const env: Dict = {
      ...process.env,
      CLAUDE_PROJECT_DIR: project,
      CLAUDE_PLUGIN_ROOT: ROOT,
      CLAUTOHOTKEY_HOST: "opencode",
    }
    const proc = Bun.spawn([bash, IS_WIN ? scriptPath.replace(/\\/g, "/") : scriptPath], {
      cwd: project,
      env,
      stdin: new Blob([JSON.stringify(payload)]),
      stdout: "pipe",
      stderr: "pipe",
    })
    const timer = setTimeout(() => proc.kill(), timeoutMs)
    try {
      const [stdout, stderr, code] = await Promise.all([
        new Response(proc.stdout).text(),
        new Response(proc.stderr).text(),
        proc.exited,
      ])
      return { code, stdout, stderr }
    } finally {
      clearTimeout(timer)
    }
  }

  function isAhk(path: unknown): path is string {
    return typeof path === "string" && /\.ahk$/i.test(path) && !/\.d\.ahk$/i.test(path)
  }

  function claudeToolName(tool: string): string {
    return { edit: "Edit", write: "Write", bash: "Bash" }[tool] ?? tool
  }

  function editPayload(tool: string, args: Dict, sessionID: string): Dict {
    return { tool_name: claudeToolName(tool), tool_input: { file_path: args.filePath }, session_id: sessionID }
  }

  async function sessionPrimer(): Promise<string> {
    if (primer !== undefined) return primer
    const r = await runHook("hooks/ahk-session-primer.sh", { hook_event_name: "SessionStart", source: "startup" })
    const about = [
      `## ClautoHotkey (OpenCode)`,
      ``,
      `AutoHotkey v2 companion loaded from \`${ROOT_FWD}\`. Knowledge modules: \`${ROOT_FWD}/Modules/\`.`,
      `Skills are commands here: type \`/ahk-gui\`, \`/ahk-fix\`, \`/ahk-oop\` and so on. Agents (\`ahk-analysis\`,`,
      `\`ahk-test-generator\`, ...) run through the task tool. Every \`.ahk\` edit is validated after it lands;`,
      `a result that says \`${TAG} VALIDATION FAILED\` means the file is broken and must be fixed next.`,
      `Snippets that mention \`$CLAUDE_PROJECT_DIR\` mean the project folder (\`${project.replace(/\\/g, "/")}\`);`,
      `\`\${CLAUDE_PLUGIN_ROOT}\` means \`${ROOT_FWD}\`. Interpreter and project settings come from \`harness.env\``,
      `in the project (else the clone), see \`${ROOT_FWD}/harness.env.example\`.`,
      ``,
    ].join("\n")
    primer = about + (r.stdout.trim() ? r.stdout.trim() + "\n" : "")
    if (!bash) primer += `\n${TAG} bash was not found, so the validation hooks are inactive. Install Git for Windows or set CLAUTOHOTKEY_BASH.\n`
    return primer
  }

  return {
    config: async (cfg) => {
      cfg.agent ??= {}
      for (const file of listMarkdown(join(ROOT, "agents"))) {
        const { meta, body } = frontmatter(read(file))
        const name = String(meta.name || basename(file, ".md"))
        if (cfg.agent[name]) continue
        const agent: Dict = {
          description: String(meta.description ?? `ClautoHotkey agent ${name}`),
          mode: "subagent",
          prompt: localize(body),
        }
        const tools = toolsFor(meta.tools)
        if (tools) agent.tools = tools
        cfg.agent[name] = agent
      }

      cfg.command ??= {}
      for (const file of listMarkdown(join(ROOT, "commands"))) {
        const { meta, body } = frontmatter(read(file))
        const name = basename(file, ".md")
        if (cfg.command[name]) continue
        cfg.command[name] = { template: localize(body), description: String(meta.description ?? name) }
      }
      for (const file of listSkills(join(ROOT, "skills"))) {
        const { meta, body } = frontmatter(read(file))
        const name = String(meta.name || basename(dirname(file)))
        if (cfg.command[name]) continue
        const description = String(meta.description ?? name).replace(/\s+/g, " ").trim()
        const lede = `Skill ${name} (${ROOT_FWD}/skills/${basename(dirname(file))}/SKILL.md). Follow it for the request below.`
        cfg.command[name] = {
          template: `${lede}\n\n${localize(body)}\n\nRequest: $ARGUMENTS`,
          description: description.length > 160 ? description.slice(0, 157) + "..." : description,
        }
      }
    },

    "experimental.chat.system.transform": async (_input, output) => {
      output.system.push(await sessionPrimer())
      for (const [sessionID, note] of v1Note) {
        output.system.push(note)
        v1Note.delete(sessionID)
      }
    },

    "chat.message": async (input, output) => {
      const text = output.parts
        .filter((p: any) => p.type === "text" && typeof p.text === "string")
        .map((p: any) => p.text)
        .join("\n")
      if (!text) return
      const r = await runHook("hooks/detect-v1-syntax.sh", { prompt: text, session_id: input.sessionID }, 5000)
      const found = clean(r.stderr).match(/v1 patterns found:\s*(.+)/i)
      if (found) {
        v1Note.set(input.sessionID, `${TAG} The latest user message contains AutoHotkey v1 syntax (${found[1].trim()}). This project is AHK v2 only: write v2 and offer /ahk-convert for the old code.`)
      }
    },

    "tool.execute.before": async (input, output) => {
      const args: Dict = output.args ?? {}
      if (input.tool === "bash" || input.tool === "edit" || input.tool === "write") {
        argsByCall.set(input.callID, { ...args })
        if (argsByCall.size > 200) argsByCall.delete(argsByCall.keys().next().value as string)
      }
      if (input.tool === "bash" && typeof args.command === "string") {
        const payload = { tool_name: "Bash", tool_input: { command: args.command }, session_id: input.sessionID }
        for (const script of ["hooks/check-ahk-binary.sh", "hooks/check-git-account.sh"]) {
          const r = await runHook(script, payload, 10000)
          if (r.code === 2) throw new Error(`${TAG} blocked this command.\n${clean(r.stderr)}`)
        }
        return
      }
      if ((input.tool === "edit" || input.tool === "write") && isAhk(args.filePath)) {
        const r = await runHook("hooks/inject-rules.sh", editPayload(input.tool, args, input.sessionID), 10000)
        if (r.code === 0 && r.stdout.trim()) {
          try {
            const ctx = JSON.parse(r.stdout)?.hookSpecificOutput?.additionalContext
            if (typeof ctx === "string" && ctx.trim()) {
              const list = pendingRules.get(input.sessionID) ?? []
              list.push(ctx.trim())
              pendingRules.set(input.sessionID, list)
            }
          } catch {
            // Not JSON: the script reported a problem on stderr; the edit still proceeds.
          }
        }
      }
    },

    "tool.execute.after": async (input, output) => {
      const args: Dict = argsByCall.get(input.callID) ?? {}
      argsByCall.delete(input.callID)
      if (input.tool === "edit" || input.tool === "write") {
        let filePath = args.filePath ?? output.metadata?.filepath ?? output.metadata?.filePath ?? titlePath(output.title)
        if (typeof filePath === "string" && !/^([A-Za-z]:[\\/]|\/|\\\\)/.test(filePath)) filePath = join(project, filePath)
        const notes: string[] = []
        const rules = pendingRules.get(input.sessionID)
        if (rules?.length) {
          notes.push(rules.join("\n\n"))
          pendingRules.delete(input.sessionID)
        }
        if (isAhk(filePath)) {
          const payload = editPayload(input.tool, { filePath }, input.sessionID)
          const r = await runHook("hooks/ahk-post-edit.sh", payload)
          const report = clean(r.stderr)
          if (r.code === 2) {
            notes.push(`${TAG} VALIDATION FAILED. The file was written but AutoHotkey rejects it; fix this before anything else.\n${report}`)
          } else if (r.code === 0) {
            // The script's last line is "✓ name.ahk  syntax  runtime  123ms"; keep the steps.
            const last = (report.split("\n").filter(Boolean).pop() ?? "").replace(/^[✓✗\s]+/, "").replace(basename(filePath), "").trim()
            notes.push(`${TAG} validated ${basename(filePath)}${last ? `: ${last}` : ""}`)
          } else if (report) {
            notes.push(`${TAG} ${report}`)
          }
          const reload = await runHook("hooks/ahk-auto-reload.sh", payload, 15000)
          const reloadText = clean(reload.stderr)
          if (reloadText) notes.push(`${TAG} ${reloadText}`)
        }
        if (notes.length) output.output = `${output.output}\n\n${notes.join("\n\n")}`
        return
      }
      if (input.tool === "bash") {
        const command = args.command ?? output.metadata?.command ?? ""
        const exit = output.metadata?.exit ?? output.metadata?.exitCode ?? output.metadata?.exit_code ?? 0
        const payload = {
          tool_name: "Bash",
          tool_input: { command },
          tool_output: { stdout: output.output, exit_code: exit },
          session_id: input.sessionID,
        }
        await runHook("skills/ahk-mistakes/hooks/error-logger.sh", payload, 10000)
        if (/\.ahk\b/i.test(String(command))) {
          const reload = await runHook("hooks/ahk-auto-reload.sh", payload, 15000)
          const reloadText = clean(reload.stderr)
          if (reloadText) output.output = `${output.output}\n\n${TAG} ${reloadText}`
        }
      }
    },
  }
}

// The edit and write tools title their result with the file's path.
function titlePath(title: unknown): string | undefined {
  if (typeof title !== "string") return undefined
  const m = title.match(/([A-Za-z]:[\\/][^\s"']+\.ahk|\/[^\s"']+\.ahk)/i)
  return m ? m[1] : undefined
}

export default Clautohotkey
