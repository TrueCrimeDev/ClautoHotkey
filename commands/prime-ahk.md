---
description: Prime AHK project context — orient on recent work, running scripts, modified files, and recent failures
---

# Prime AHK Project Context

Build situational awareness before starting work. Skills load knowledge; this command loads state.

## 1. Recent activity

Last 10 commits across the project:
!`git log --oneline -10 2>/dev/null`

Files modified since the last commit (top 20):
!`git status --short 2>/dev/null | head -20`

## 2. Running scripts

Currently-running AHK scripts:
!`powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='AutoHotkey64.exe'\" | ForEach-Object { if ($_.CommandLine -match '\"\"([A-Za-z]:[^\"\"]+\\.ahk)\"\"') { $Matches[1] } elseif ($_.CommandLine -match '\\s([A-Za-z]:[^\\s]+\\.ahk)') { $Matches[1] } } | ForEach-Object { Split-Path -Leaf $_ }" 2>/dev/null | tr -d '\r' | grep -v '^$'`

Debug server (port 9000) state:
!`powershell.exe -NoProfile -Command "if (Get-NetTCPConnection -LocalPort 9000 -State Listen -ErrorAction SilentlyContinue) { 'listening' } else { 'idle' }" 2>/dev/null | tr -d '\r'`

## 3. Recent failures

Last 5 entries in the error log (if any):
!`tail -5 .claude/error-log.jsonl 2>/dev/null | jq -c '{timestamp, file, line, type, message: (.message[:80])}' 2>/dev/null`

## 4. Read these

- `CLAUDE.md` — project doctrine: interpreter rule, demo location, banner rule, _Dark.ahk canonical, three-layer routing
- `.claude/hooks/ahk-session-primer.sh` — the skill/agent routing table (already injected at session start)

## After priming

Use the routing table to pick a skill or agent. Don't write code without first stating which layer (rule / skill / agent) you're operating in.
