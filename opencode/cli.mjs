#!/usr/bin/env node
// opencode-clautohotkey: the npm install's companion to opencode/install.sh.
//
//   npx opencode-clautohotkey skills [--project DIR]     copy the skills where OpenCode's
//                                                        skill tool reads them
//   npx opencode-clautohotkey skills --remove [--project DIR]
//   npx opencode-clautohotkey where                      print the package folder
//
// An npm install already registers the agents and the /ahk-* commands through the
// plugin entry in opencode.json; only the skill copies need a file step, because
// OpenCode does not look inside node_modules for skills.
import { execFileSync } from "node:child_process"
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)))
const ROOT_FWD = ROOT.replace(/\\/g, "/")
const MARKER = ".clautohotkey"

const args = process.argv.slice(2)
const command = args[0] ?? "help"
const remove = args.includes("--remove")
const projectIdx = args.indexOf("--project")
const project = projectIdx >= 0 ? resolve(args[projectIdx + 1] ?? ".") : undefined

function configDir() {
  if (project) return join(project, ".opencode")
  try {
    const out = execFileSync("opencode", ["debug", "paths"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] })
    const line = out.split(/\r?\n/).find((l) => /^config\s/.test(l))
    if (line) return line.replace(/^config\s+/, "").trim()
  } catch {
    // opencode not on PATH: fall back to the default location
  }
  return join(process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), "opencode")
}

function skills() {
  const target = join(configDir(), "skill")
  mkdirSync(target, { recursive: true })
  let n = 0
  if (remove) {
    for (const name of readdirSync(target)) {
      if (existsSync(join(target, name, MARKER))) {
        rmSync(join(target, name), { recursive: true, force: true })
        n++
      }
    }
    console.log(`removed ${n} skill copies from ${target}`)
    return
  }
  for (const name of readdirSync(join(ROOT, "skills"))) {
    const src = join(ROOT, "skills", name)
    if (name.startsWith("_") || !existsSync(join(src, "SKILL.md"))) continue
    const dest = join(target, name)
    if (existsSync(dest) && !existsSync(join(dest, MARKER))) {
      console.warn(`skipping skill '${name}': ${dest} exists and is not ours`)
      continue
    }
    rmSync(dest, { recursive: true, force: true })
    cpSync(src, dest, { recursive: true })
    const skill = join(dest, "SKILL.md")
    writeFileSync(skill, readFileSync(skill, "utf8").replace(/\$\{CLAUDE_PLUGIN_ROOT\}|\$CLAUDE_PLUGIN_ROOT\b/g, ROOT_FWD))
    writeFileSync(join(dest, MARKER), `installed from ${ROOT_FWD} by opencode-clautohotkey; re-run to refresh, do not edit here\n`)
    n++
  }
  console.log(`copied ${n} skills to ${target}`)
  console.log("check: opencode debug skill | grep -c '\"ahk-'")
}

switch (command) {
  case "skills":
    skills()
    break
  case "where":
    console.log(ROOT)
    break
  default:
    console.log(readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n").slice(1, 12).map((l) => l.replace(/^\/\/ ?/, "")).join("\n"))
}
