#!/usr/bin/env bash
# Exercises the PowerShell inside hooks/ahk-auto-reload.sh without touching a real
# process: the script text is lifted out of the hook as written, the four things
# it does to the machine (list processes, read a file's timestamp, stop, start)
# are replaced by recording stand-ins, and each case states which processes must
# be restarted and with what command line.
#
#   bash Tools/tests/reload_logic.sh
#
# Runs under PowerShell 7 (pwsh) on any platform, or Windows PowerShell 5.1.
# Exit 0 when every case passes, 1 when one fails, 2 when no PowerShell is found.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../../hooks/ahk-auto-reload.sh"

ps_exe=""
for c in pwsh powershell.exe powershell; do
    if type -P "$c" >/dev/null 2>&1; then ps_exe="$c"; break; fi
done
if [[ -z "$ps_exe" ]]; then
    echo "no PowerShell found (pwsh, powershell.exe): nothing was tested" >&2
    exit 2
fi

# The hook's PowerShell: everything between the <<'PS' line and the closing PS.
body="$(awk '/<<.PS.$/ {on=1; next} on && /^PS$/ {exit} on {print}' "$HOOK")"
if [[ -z "$body" ]]; then
    echo "could not find the PowerShell block in $HOOK" >&2
    exit 2
fi
if [[ "$body" == *'"'* ]]; then
    echo "FAIL  the hook's PowerShell contains a double quote; it must use [char]34" >&2
    exit 1
fi

IFS= read -r -d '' cases <<'PS'
$q = [char]34
$global:failed = 0
$old = [datetime]'2026-01-01T08:00:00'
$new = [datetime]'2026-01-01T09:00:00'

function Get-CimInstance { param($Class, $Filter) $global:lastFilter = $Filter; return $global:mockProcs }
function Get-Item { param($LiteralPath, $ErrorAction) return $global:mockFiles[$LiteralPath] }
function Stop-Process { param($Id, [switch]$Force, $ErrorAction) $global:stopped += @($Id) }
function Start-Sleep { param($Milliseconds) }
function Start-Process {
    param($FilePath, $ArgumentList, $WorkingDirectory)
    $global:started += @($FilePath + ' ' + $ArgumentList + ' @' + $WorkingDirectory)
}

function Proc($id, $cmd, $created) {
    return New-Object psobject -Property @{ ProcessId = $id; CommandLine = $cmd; CreationDate = $created }
}
function File($written) { return New-Object psobject -Property @{ LastWriteTime = $written } }

function Case($name, $editedFiles, $procs, $files, $wantOut, $wantStarted) {
    $global:mockProcs = $procs
    $global:mockFiles = $files
    $global:stopped = @()
    $global:started = @()
    $ahk = 'C:\AHK Fork\AutoHotkey64.exe'
    $edited = $editedFiles
    $out = @(& ([scriptblock]::Create($body)))
    $gotOut = ($out -join ';')
    $gotStarted = ($global:started -join ';')
    if ($gotOut -eq $wantOut -and $gotStarted -eq $wantStarted) {
        Write-Output ('  PASS  ' + $name)
    } else {
        Write-Output ('  FAIL  ' + $name)
        Write-Output ('        output  want [' + $wantOut + '] got [' + $gotOut + ']')
        Write-Output ('        started want [' + $wantStarted + '] got [' + $gotStarted + ']')
        $global:failed += 1
    }
}

$exe = $q + 'C:\AHK Fork\AutoHotkey64.exe' + $q
$x = 'C:\Scripts\x.ahk'
$spaced = 'C:\My Scripts\tool.ahk'
$lib = 'C:\Scripts\Lib\util.ahk'

Case 'an edited script that is running is restarted' @($x) `
    @((Proc 10 ($exe + ' ' + $q + $x + $q) $old)) @{ $x = (File $new) } `
    ('restarted|' + $x + '|self') `
    ('C:\AHK Fork\AutoHotkey64.exe ' + $q + $x + $q + ' @C:\Scripts')

Case 'a path with a space is started as one quoted argument' @($spaced) `
    @((Proc 11 ($exe + ' ' + $q + $spaced + $q) $old)) @{ $spaced = (File $new) } `
    ('restarted|' + $spaced + '|self') `
    ('C:\AHK Fork\AutoHotkey64.exe ' + $q + $spaced + $q + ' @C:\My Scripts')

Case 'a file older than the process is a mention, not an edit' @($x) `
    @((Proc 12 ($exe + ' ' + $q + $x + $q) $new)) @{ $x = (File $old) } '' ''

Case 'another script with the same ending is left alone' @($x) `
    @((Proc 13 ($exe + ' ' + $q + 'C:\Scripts\max.ahk' + $q) $old)) @{ $x = (File $new) } '' ''

Case 'the same name in another folder is left alone' @($x) `
    @((Proc 14 ($exe + ' ' + $q + 'D:\Other\x.ahk' + $q) $old)) @{ $x = (File $new) } '' ''

Case 'drive letter and slash spelling do not matter' @('c:/scripts/X.AHK') `
    @((Proc 15 ($exe + ' ' + $q + $x + $q) $old)) @{ 'c:/scripts/X.AHK' = (File $new) } `
    ('restarted|' + $x + '|self') `
    ('C:\AHK Fork\AutoHotkey64.exe ' + $q + $x + $q + ' @C:\Scripts')

Case 'an unquoted command line still yields the script' @($x) `
    @((Proc 16 ('C:\AHK\AutoHotkey64.exe /ErrorStdOut ' + $x) $old)) @{ $x = (File $new) } `
    ('restarted|' + $x + '|self') `
    ('C:\AHK Fork\AutoHotkey64.exe ' + $q + $x + $q + ' @C:\Scripts')

Case 'a script started by a relative path is matched by name' @($x) `
    @((Proc 17 ($exe + ' x.ahk') $old)) @{ $x = (File $new) } `
    ('restarted|' + $x + '|self') `
    ('C:\AHK Fork\AutoHotkey64.exe ' + $q + $x + $q + ' @C:\Scripts')

Case 'a Lib edit restarts the scripts beside that Lib folder, once each' @($lib) `
    @((Proc 18 ($exe + ' ' + $q + 'C:\Scripts\app.ahk' + $q) $old),
      (Proc 19 ($exe + ' ' + $q + 'C:\Scripts\sub\deep.ahk' + $q) $old),
      (Proc 20 ($exe + ' ' + $q + 'C:\Elsewhere\other.ahk' + $q) $old)) `
    @{ $lib = (File $new) } `
    ('restarted|C:\Scripts\app.ahk|lib:util.ahk;restarted|C:\Scripts\sub\deep.ahk|lib:util.ahk') `
    ('C:\AHK Fork\AutoHotkey64.exe ' + $q + 'C:\Scripts\app.ahk' + $q + ' @C:\Scripts;' +
     'C:\AHK Fork\AutoHotkey64.exe ' + $q + 'C:\Scripts\sub\deep.ahk' + $q + ' @C:\Scripts\sub')

Case 'a harness child run with /include is not mistaken for the script' @($x) `
    @((Proc 21 ($exe + ' /force /include ' + $q + 'C:\H\DryRunShim.ahk' + $q + ' ' + $q + $x + $q) $old)) `
    @{ $x = (File $new) } '' ''

Case 'a process with no readable command line is skipped' @($x) `
    @((Proc 22 $null $old)) @{ $x = (File $new) } '' ''

Case 'a file that vanished is skipped' @($x) `
    @((Proc 23 ($exe + ' ' + $q + $x + $q) $old)) @{} '' ''

if ($global:lastFilter -eq 'Name=''AutoHotkey64.exe''') { Write-Output '  PASS  the process filter names the configured executable' }
else { Write-Output ('  FAIL  process filter was [' + $global:lastFilter + ']'); $global:failed += 1 }

Write-Output ''
if ($global:failed) { Write-Output ([string]$global:failed + ' case(s) failed'); exit 1 }
Write-Output 'all reload cases passed'
exit 0
PS

echo "PowerShell: $ps_exe"
"$ps_exe" -NoProfile -NonInteractive -Command "\$body = @'
$body
'@
$cases"
