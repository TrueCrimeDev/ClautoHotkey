#!/bin/bash
# Restart running AHK scripts whose source just changed.
#
#   standalone .ahk   the running copy of that script
#   a file under Lib/ every running script that lives beside that Lib/ folder
#
# Two callers:
#   - ahk-post-edit.sh, after an Edit/Write passed validation. Claude Code starts
#     every hook matched to one event at the same time, so a separate reload hook
#     could not wait for the validator's verdict; the validator calls this instead
#     and a failed edit never reaches it. AHK_RELOAD_PLAIN=1 asks for one plain
#     "restarted <name>" line per script on stdout instead of the stderr box.
#   - PostToolUse on Bash, for edits made through the shell (sed -i, git checkout).
#
# A Bash command that merely names a script must not bounce a copy the user has
# running: `cat x.ahk`, `git diff x.ahk` or grading x.ahk through a gate touch
# nothing. So a file named by a Bash command counts only if it was modified while
# that command ran, and no script is restarted unless the changed file is newer
# than the process running it.

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

input=$(cat)
harness_need_jq || exit 1
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)

# How far back a Bash command can have modified a file: its own duration plus
# slack. Claude Code reports duration_ms; a host that does not gets a minute.
recent_window=0
if [[ "$tool_name" == Bash ]]; then
    duration_ms=$(echo "$input" | jq -r '.duration_ms // empty' 2>/dev/null)
    if [[ "$duration_ms" =~ ^[0-9]+$ ]]; then
        recent_window=$(( duration_ms / 1000 + 5 ))
    else
        recent_window=60
    fi
fi
now_s=$(date +%s)

# Collect candidate .ahk file paths from either Edit/Write (single path)
# or Bash (parse command for any .ahk references)
file_paths=()
case "$tool_name" in
    Edit|Write|NotebookEdit)
        # Only the validator may ask for an edit's reload. A settings.json rendered
        # before this script stopped being a Write|Edit hook of its own would still
        # start it beside the validator, and the two would restart the script twice.
        [[ "${AHK_RELOAD_PLAIN:-0}" == 1 ]] || exit 0
        fp=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        [[ -n "$fp" && "$fp" == *.ahk ]] && file_paths+=("$fp")
        ;;
    Bash)
        cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
        # Extract any token ending in .ahk (handles quoted/unquoted, /mnt/c, C:\)
        while IFS= read -r p; do
            [[ -n "$p" ]] && file_paths+=("$p")
        done < <(echo "$cmd" | grep -oE "[/A-Za-z0-9._\\:-]+\.ahk" | sort -u)
        ;;
    *)
        exit 0 ;;
esac

[[ ${#file_paths[@]} -eq 0 ]] && exit 0

# A value for a single-quoted PowerShell string, where only ' is special. Doubling
# backslashes (what this used to do) breaks [regex]::Escape, which then looks for
# C:\\Users and never matches a real command line.
ps_quote() { printf '%s' "${1//\'/\'\'}"; }

# The changed files that exist and are not opted out, as a PowerShell array literal.
IFS=',' read -ra _noreload <<< "${NO_AUTO_RELOAD:-}"
edited=""
for file_path in "${file_paths[@]}"; do
    # One spelling for this shell, whatever the tool or command used.
    file_path=$(harness_to_unix "$file_path")
    [[ -n "$file_path" && "$file_path" == *.ahk && -f "$file_path" ]] || continue
    filename="${file_path##*/}"
    skip_reload=false
    for n in "${_noreload[@]}"; do [[ -n "$n" && "$filename" == "$(echo "$n" | xargs)" ]] && skip_reload=true; done
    [[ "$skip_reload" == true ]] && continue
    if (( recent_window > 0 )); then
        mtime_s=$(stat -c %Y "$file_path" 2>/dev/null) || continue
        (( now_s - mtime_s <= recent_window )) || continue
    fi
    edited+="${edited:+, }'$(ps_quote "$(harness_to_win "$file_path")")'"
done
[[ -z "$edited" ]] && exit 0

# Restarting means stopping a script and starting it again with the interpreter;
# without one, stop before stopping anything.
harness_need_ahk || exit 1

AHK_EXE="${AHK_EXE:-$AHK_BIN_SH}"
AHK_WIN=$(ps_quote "$(harness_to_win "$AHK_EXE")")

# The PowerShell below contains no double quote ([char]34 stands in for it), so
# no layer between this shell and powershell.exe has a quote to mangle. Paths are
# taken apart with string operations rather than Split-Path so the same text can
# be exercised by Tools/tests/reload_logic.ps1 on any platform.
IFS= read -r -d '' ps_body <<'PS'
$q = [char]34
$quoted = [regex]('(?i)' + $q + '([^' + $q + ']+\.ahk)' + $q)
$bare = [regex]('(?i)(?:^|\s)([^\s' + $q + ']+\.ahk)(?=\s|$)')
function Leaf($p) { return ($p -replace '^.*[\\/]', '') }
function Parent($p) { return ($p -replace '[\\/][^\\/]*$', '') }
function Norm($p) { return ($p -replace '/', '\').TrimEnd('\').ToLowerInvariant() }
function Rooted($p) { return ($p -match '^[A-Za-z]:[\\/]' -or $p -match '^[\\/]{2}') }

$exeName = Leaf $ahk
$procs = @(Get-CimInstance Win32_Process -Filter ('Name=''' + $exeName + ''''))
foreach ($p in $procs) {
    $cmd = [string]$p.CommandLine
    if (-not $cmd) { continue }
    # The first script on the command line. The executable itself is skipped: its
    # own path can end in .ahk only by accident, but it is always the first token.
    $rest = $cmd
    $exeAt = $cmd.ToLowerInvariant().IndexOf($exeName.ToLowerInvariant())
    if ($exeAt -ge 0) { $rest = $cmd.Substring($exeAt + $exeName.Length) }
    $script = $null
    $m = $quoted.Match($rest)
    if ($m.Success) { $script = $m.Groups[1].Value }
    else {
        $m = $bare.Match($rest)
        if ($m.Success) { $script = $m.Groups[1].Value }
    }
    if (-not $script) { continue }

    $why = $null
    $launch = $script
    foreach ($e in $edited) {
        $isLib = $false
        $libRoot = ''
        $at = (Norm $e).LastIndexOf('\lib\')
        if ($at -ge 0) { $isLib = $true; $libRoot = (Norm $e).Substring(0, $at) }

        $hit = $false
        if ($isLib) {
            # A library change reaches every script beside (or below) that Lib folder.
            if ((Rooted $script) -and (Norm $script).StartsWith($libRoot + '\')) { $hit = $true }
        } elseif (Rooted $script) {
            if ((Norm $script) -eq (Norm $e)) { $hit = $true }
        } elseif ((Leaf $script).ToLowerInvariant() -eq (Leaf $e).ToLowerInvariant()) {
            # Started with a relative path: the name is all there is to go on, and
            # the edited file is the best guess at what to start again.
            $hit = $true
            $launch = $e
        }
        if (-not $hit) { continue }

        # Newer than the process that is running it, or it was only mentioned.
        $item = Get-Item -LiteralPath $e -ErrorAction SilentlyContinue
        if (-not $item) { continue }
        if ($p.CreationDate -and $item.LastWriteTime -le $p.CreationDate) { continue }
        if ($isLib) { $why = 'lib:' + (Leaf $e) } else { $why = 'self' }
        break
    }
    if (-not $why) { continue }

    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    # The path is quoted by hand: Start-Process joins its arguments with spaces
    # and adds no quotes, so C:\My Scripts\x.ahk would arrive as two arguments.
    $argument = $q + $launch + $q
    if (Rooted $launch) {
        Start-Process -FilePath $ahk -ArgumentList $argument -WorkingDirectory (Parent $launch)
    } else {
        Start-Process -FilePath $ahk -ArgumentList $argument
    }
    Write-Output ('restarted|' + $launch + '|' + $why)
}
PS

result=$(powershell.exe -NoProfile -NonInteractive -Command "\$ahk = '$AHK_WIN'
\$edited = @($edited)
$ps_body" 2>/dev/null | tr -d '\r')

[[ -z "$result" ]] && exit 0

D="\x1b[90m"
C="\x1b[36m"
G="\x1b[32m"
Z="\x1b[0m"

while IFS='|' read -r verdict script why; do
    [[ "$verdict" == restarted && -n "$script" ]] || continue
    restarted="${script##*[\\/]}"
    if [[ "${AHK_RELOAD_PLAIN:-0}" == 1 ]]; then
        printf 'restarted %s\n' "$restarted"
        continue
    fi
    detail="restarted"
    [[ "$why" == lib:* ]] && detail="(lib edit: ${why#lib:})"
    echo -e "${D}─── ${G}reload${D} ──────────────────────────────────${Z}" >&2
    echo -e "    ${G}↺${Z} ${C}${restarted}${Z}  ${D}${detail}${Z}" >&2
    echo -e "${D}──────────────────────────────────────────${Z}" >&2
done <<< "$result"

exit 0
