#!/usr/bin/env python3
"""Unit tests for hooks/_jqlite.py, the jq stand-in the hooks fall back to.

One test per distinct filter form the hooks and harness scripts use (taken from
hooks/*.sh, skills/*/hooks/*.sh, Tools/verify.sh, setup.sh and the repo-level
.claude/hooks), then the jq semantics those forms rely on, output formatting,
input handling, and the error contract: unsupported filters exit 3 loudly, bad
input exits 2, runtime errors exit 5, -e maps last output to 0/1/4.

Expected values are jq's documented behaviour, worked out by hand.

    python Tools/tests/test_jqlite.py        (or: python -m unittest discover Tools/tests)
"""

import io
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
HOOKS = os.path.normpath(os.path.join(HERE, "..", "..", "hooks"))
JQLITE = os.path.join(HOOKS, "_jqlite.py")

# Importing must not drop a __pycache__ into the plugin's hooks/ directory.
sys.dont_write_bytecode = True
sys.path.insert(0, HOOKS)
import _jqlite as jqlite  # noqa: E402


def run(args, stdin=b""):
    """Run jqlite in-process. Returns (exit status, stdout text, stderr text)."""
    if isinstance(stdin, str):
        stdin = stdin.encode("utf-8")
    out, err = io.BytesIO(), io.BytesIO()
    rc = jqlite.main(list(args), stdin=io.BytesIO(stdin), stdout=out, stderr=err)
    return rc, out.getvalue().decode("utf-8"), err.getvalue().decode("utf-8")


PRE_BASH = {
    "session_id": "abc-123",
    "hook_event_name": "PreToolUse",
    "tool_name": "Bash",
    "tool_input": {"command": "ls -la", "description": "List files"},
}
POST_WRITE = {
    "session_id": "abc-123",
    "tool_name": "Write",
    "tool_input": {"file_path": "C:\\Users\\me\\x.ahk", "content": "x := 1"},
    "tool_response": {"success": True},
}


class HookFilterForms(unittest.TestCase):
    """Each filter shape found in the hook inventory."""

    def test_field_alternative_empty(self):
        # tool_name=$(... | jq -r '.tool_name // empty')
        self.assertEqual(run(["-r", ".tool_name // empty"], json.dumps(PRE_BASH)), (0, "Bash\n", ""))
        self.assertEqual(run(["-r", ".tool_name // empty"], "{}"), (0, "", ""))

    def test_alternative_string_default(self):
        # session_id=$(... | jq -r '.session_id // "default"')
        self.assertEqual(run(["-r", '.session_id // "default"'], "{}")[1], "default\n")
        self.assertEqual(run(["-r", '.session_id // "default"'], '{"session_id":null}')[1], "default\n")
        self.assertEqual(run(["-r", '.session_id // "default"'], json.dumps(PRE_BASH))[1], "abc-123\n")

    def test_nested_path(self):
        # file_path=$(... | jq -r '.tool_input.file_path // empty')
        self.assertEqual(run(["-r", ".tool_input.file_path // empty"], json.dumps(POST_WRITE))[1],
                         "C:\\Users\\me\\x.ahk\n")
        self.assertEqual(run(["-r", ".tool_input.file_path // empty"], '{"tool_input":null}'), (0, "", ""))

    def test_alternative_swallows_index_errors(self):
        # A string where an object was expected is an error jq's // suppresses.
        self.assertEqual(run(["-r", ".tool_input.file_path // empty"], '{"tool_input":"text"}'), (0, "", ""))
        self.assertEqual(run(["-r", '.message // "x"'], "5"), (0, "x\n", ""))

    def test_chained_alternatives(self):
        # detect-v1-syntax: '.prompt // .user_prompt // empty'
        f = ".prompt // .user_prompt // empty"
        self.assertEqual(run(["-r", f], '{"user_prompt":"hi"}')[1], "hi\n")
        self.assertEqual(run(["-r", f], '{"prompt":"p","user_prompt":"u"}')[1], "p\n")
        self.assertEqual(run(["-r", f], '{"prompt":""}')[1], "\n")

    def test_raw_output_of_object_is_pretty_json(self):
        # error-logger: tool_input=$(... | jq -r '.tool_input // empty')
        rc, out, _ = run(["-r", ".tool_input // empty"], json.dumps(PRE_BASH))
        self.assertEqual(out, '{\n  "command": "ls -la",\n  "description": "List files"\n}\n')
        self.assertEqual(run(["-r", ".command // empty"], out)[1], "ls -la\n")

    def test_alternative_without_spaces(self):
        # error-logger: '.tool_output// empty'
        self.assertEqual(run(["-r", ".tool_output// empty"], '{"tool_output":"out"}')[1], "out\n")

    def test_exit_status_comparison(self):
        # post-capture-guidance: jq -e '.status == "timeout"' / '.success == true'
        self.assertEqual(run(["-e", '.status == "timeout"'], '{"status":"timeout"}'), (0, "true\n", ""))
        self.assertEqual(run(["-e", '.status == "timeout"'], '{"status":"done"}'), (1, "false\n", ""))
        self.assertEqual(run(["-e", ".success == true"], '{"success":true}')[0], 0)
        self.assertEqual(run(["-e", ".success == true"], "")[0], 4)

    def test_error_log_record(self):
        # post-edit / error-logger: line: ($line | tonumber? // 0)
        f = ("{timestamp: $ts, tool: $tool, file: $file, line: ($line | tonumber? // 0), "
             "type: $type, message: $msg}")

        def record(line):
            return run(["-nc", "--arg", "ts", "T", "--arg", "tool", "post-edit", "--arg", "file", "f.ahk",
                        "--arg", "line", line, "--arg", "type", "syntax", "--arg", "msg", "Missing operand.",
                        f])[1]
        self.assertEqual(record("12"),
                         '{"timestamp":"T","tool":"post-edit","file":"f.ahk","line":12,'
                         '"type":"syntax","message":"Missing operand."}\n')
        for bad_line in ("?", "", "2x"):
            self.assertIn('"line":0,', record(bad_line))

    def test_nested_object_pretty(self):
        # inject-rules: jq -n --arg ctx "$combined" '{hookSpecificOutput:{...}}'
        f = '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}'
        rc, out, _ = run(["-n", "--arg", "ctx", "rule\nbody \u2014 \u25b8", f])
        self.assertEqual(rc, 0)
        self.assertEqual(out, '{\n  "hookSpecificOutput": {\n    "hookEventName": "PreToolUse",\n'
                              '    "additionalContext": "rule\\nbody \u2014 \u25b8"\n  }\n}\n')

    def test_nested_field_alternative_empty(self):
        # error-logger: '.tool_output.exit_code // empty' - the OpenCode bridge's
        # payload has it, Claude Code's has no tool_output at all, and 0 is a value.
        f = ".tool_output.exit_code // empty"
        self.assertEqual(run(["-r", f], '{"tool_output":{"exit_code":2}}')[1], "2\n")
        self.assertEqual(run(["-r", f], '{"tool_output":{"exit_code":0}}')[1], "0\n")
        self.assertEqual(run(["-r", f], '{"tool_input":{}}'), (0, "", ""))

    def test_chained_field_alternatives(self):
        # session-event-logger: '.agent_type // .subagent_type // empty'
        f = ".agent_type // .subagent_type // empty"
        self.assertEqual(run(["-r", f], '{"agent_type":"a","subagent_type":"b"}')[1], "a\n")
        self.assertEqual(run(["-r", f], '{"subagent_type":"b"}')[1], "b\n")
        self.assertEqual(run(["-r", f], "{}"), (0, "", ""))

    def test_compact_alternative_of_any_shape(self):
        # post-capture-guidance: jq -c '.tool_response // .tool_output // empty'
        f = ".tool_response // .tool_output // empty"
        self.assertEqual(run(["-c", f], '{"tool_response":[{"type":"text","text":"{\\"status\\":\\"timeout\\"}"}]}')[1],
                         '[{"type":"text","text":"{\\"status\\":\\"timeout\\"}"}]\n')
        self.assertEqual(run(["-c", f], '{"tool_output":{"success":true}}')[1], '{"success":true}\n')
        self.assertEqual(run(["-c", f], "{}"), (0, "", ""))

    def test_string_concatenation_with_defaults(self):
        # inject-rules: what the edit writes - Write sends content, Edit new_string
        f = '(.tool_input.content // "") + "\\n" + (.tool_input.new_string // "")'
        self.assertEqual(run(["-r", f], json.dumps(POST_WRITE))[1], "x := 1\n\n")
        self.assertEqual(run(["-r", f], '{"tool_input":{"new_string":"win := Gui()"}}')[1], "\nwin := Gui()\n")
        self.assertEqual(run(["-r", f], '{"tool_input":{"file_path":"x.ahk"}}')[1], "\n\n")

    def test_post_tool_use_context_object(self):
        # post-capture-guidance: jq -nc --arg ctx "..." '{hookSpecificOutput: {...}}'
        f = '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
        self.assertEqual(run(["-nc", "--arg", "ctx", "next step", f])[1],
                         '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"next step"}}\n')

    def test_quoted_key(self):
        # post-compact-state: '{"additionalContext": $ctx}'
        self.assertEqual(run(["-nc", "--arg", "ctx", "x", '{"additionalContext": $ctx}'])[1],
                         '{"additionalContext":"x"}\n')

    def test_object_addition_with_conditionals(self):
        # session-event-logger
        f = ('{timestamp: $ts, event: $event}'
             ' + (if $session != "" then {session: $session} else {} end)'
             ' + (if $agent   != "" then {agent:   $agent}   else {} end)'
             ' + (if $matcher != "" then {matcher: $matcher} else {} end)'
             ' + (if $notif   != "" then {notification: $notif} else {} end)')
        base = ["-nc", "--arg", "ts", "T", "--arg", "event", "Stop"]
        self.assertEqual(run(base + ["--arg", "session", "s1", "--arg", "agent", "", "--arg", "matcher", "",
                                     "--arg", "notif", "", f])[1],
                         '{"timestamp":"T","event":"Stop","session":"s1"}\n')
        self.assertEqual(run(base + ["--arg", "session", "s", "--arg", "agent", "a", "--arg", "matcher", "m",
                                     "--arg", "notif", "n", f])[1],
                         '{"timestamp":"T","event":"Stop","session":"s","agent":"a",'
                         '"matcher":"m","notification":"n"}\n')

    def test_or_optional_tostring_length(self):
        # activity-logger's success test
        f = ('if (.tool_response.success? == false)'
             ' or ((.tool_response.error? // "") | tostring | length > 0)'
             ' then "false" else "true" end')
        self.assertEqual(run(["-r", f], '{"tool_response":{"success":false}}')[1], "false\n")
        self.assertEqual(run(["-r", f], '{"tool_response":{"error":"boom"}}')[1], "false\n")
        self.assertEqual(run(["-r", f], '{"tool_response":{"stdout":"x"}}')[1], "true\n")
        self.assertEqual(run(["-r", f], '{"tool_response":{"error":{"code":1}}}')[1], "false\n")
        # A string response: `.success?` yields nothing, so the condition and the if do too.
        self.assertEqual(run(["-r", f], '{"tool_response":"plain"}'), (0, "", ""))

    def test_argjson_and_string_slice(self):
        # activity-logger: --argjson ok, {command:($cmd[0:500])}
        f = ('{ok:$ok} + (if $file != "" then {file:$file} else {} end)'
             ' + (if $cmd != "" then {command:($cmd[0:5])} else {} end)')
        out = run(["-nc", "--arg", "file", "", "--arg", "cmd", "abcdefgh", "--argjson", "ok", "true", f])[1]
        self.assertEqual(out, '{"ok":true,"command":"abcde"}\n')

    def test_argjson_numbers_and_booleans(self):
        # policy-engine log_risk / snapshot record
        out = run(["-nc", "--arg", "c", "rm -rf x", "--argjson", "risk", "4", "--argjson", "blocked", "false",
                   "{command:$c, risk:$risk, blocked:$blocked}"])[1]
        self.assertEqual(out, '{"command":"rm -rf x","risk":4,"blocked":false}\n')

    def test_file_argument_and_iteration_count(self):
        # verify.sh: jq -e '.hooks' hooks.json; jq '[.hooks[][].hooks[]] | length' hooks.json
        doc = {"hooks": {"A": [{"hooks": [1, 2]}, {"hooks": [3]}], "B": [{"hooks": [4]}]}}
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "hooks.json")
            with open(p, "w") as fh:
                json.dump(doc, fh)
            self.assertEqual(run(["-e", ".hooks", p])[0], 0)
            self.assertEqual(run(["[.hooks[][].hooks[]] | length", p])[1], "4\n")
            self.assertEqual(run(["-e", ".nope", p])[0], 1)

    def test_settings_render(self):
        # setup.sh: object with a "$schema" key, literal arrays and hooks: .hooks
        f = '''{
              "$schema": "https://json.schemastore.org/claude-code-settings.json",
              permissions: { deny: [ "Read(**/node_modules/**)", "Read(.history/**)" ] },
              hooks: .hooks
            }'''
        rc, out, _ = run([f], '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"x"}]}]}}')
        self.assertEqual(rc, 0)
        self.assertTrue(out.startswith('{\n  "$schema": "https://json.schemastore.org/'))
        self.assertEqual(json.loads(out)["permissions"]["deny"][0], "Read(**/node_modules/**)")
        self.assertEqual(json.loads(out)["hooks"]["Stop"][0]["hooks"][0]["command"], "x")

    def test_interpolation_over_ndjson_file(self):
        # restore-snapshot.sh --list
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "manifest.jsonl")
            with open(p, "w") as fh:
                fh.write('{"seq":0,"op":"create","file":"a.ahk"}\n{"seq":1,"op":"modify","file":"b c.ahk"}\n')
            self.assertEqual(run(["-r", '"  #\\(.seq)  \\(.op)\\t\\(.file)"', p])[1],
                             "  #0  create\ta.ahk\n  #1  modify\tb c.ahk\n")

    def test_select_with_arg_compact(self):
        # restore-snapshot.sh: jq -c --arg f "$path" 'select(.file==$f)'
        ndjson = '{"file":"a","n":1}\n{"file":"b","n":2}\n{"file":"a","n":3}\n'
        self.assertEqual(run(["-c", "--arg", "f", "a", "select(.file==$f)"], ndjson)[1],
                         '{"file":"a","n":1}\n{"file":"a","n":3}\n')

    def test_empty_string_default(self):
        # restore-snapshot.sh: .snapshot // ""
        self.assertEqual(run(["-r", '.snapshot // ""'], '{"op":"create"}')[1], "\n")

    def test_session_report_record(self):
        # session-report.sh build_record: --slurpfile, as-bindings, map/select/sort/first/last,
        # unique, group_by, add, object shorthand, computed keys, if/elif/else.
        act = [
            {"timestamp": "2026-01-01T00:00:02Z", "session": "s", "tool": "Bash", "ok": True, "command": "ls"},
            {"timestamp": "2026-01-01T00:00:01Z", "session": "s", "tool": "Edit", "ok": False, "file": "b.ahk"},
            {"timestamp": "2026-01-01T00:00:03Z", "session": "s", "tool": "Write", "ok": True, "file": "a.ahk"},
            {"timestamp": "2026-01-01T00:00:04Z", "session": "other", "tool": "Bash", "ok": True},
        ]
        err = [
            {"timestamp": "t1", "session": "s", "tool": "post-edit", "file": "b.ahk", "line": 2,
             "type": "syntax", "message": "Missing operand."},
            {"timestamp": "t0", "tool": "x", "file": "z", "line": 0, "type": "u", "message": "m"},
        ]
        risk = [{"timestamp": "t", "session": "s", "command": "rm -rf build\nx", "risk": 4,
                 "blocked": False, "note": ""}]
        evt = [
            {"timestamp": "2026-01-01T00:00:00Z", "event": "Stop", "session": "s"},
            {"timestamp": "2026-01-01T00:00:05Z", "event": "Stop", "session": "s"},
            {"timestamp": "2026-01-01T00:00:06Z", "event": "Notification", "session": "s"},
        ]
        f = '''
            ($act  | map(select(.session == $s)))         as $a |
            ($risk | map(select(.session == $s)))         as $r |
            ($evt  | map(select(.session == $s)))         as $e |
            ($err  | map(select((.session // "") == $s))) as $x |
            {
                session: $s,
                started: ([ $a[].timestamp, $e[].timestamp ] | sort | first),
                ended:   ([ $a[].timestamp, $e[].timestamp ] | sort | last),
                tool_calls:   ($a | length),
                commands_run: ([ $a[] | select(.tool == "Bash") ] | length),
                tool_failures:([ $a[] | select(.ok == false) ] | length),
                files_edited: ([ $a[] | select(.tool == "Edit" or .tool == "Write") | .file ] | unique),
                errors:   ($x | map({timestamp, file, line, type, message})),
                risk_ops: ($r | map({command, risk, blocked, note})),
                events:   (($e | group_by(.event) | map({(.[0].event): length}) | add) // {}),
                status: (
                    if   (($r | map(select(.blocked))) | length) > 0 then "blocked-catastrophe"
                    elif ($x | length) > 0                           then "errors"
                    elif (([ $a[] | select(.ok == false) ]) | length) > 0 then "tool-failures"
                    else "clean" end)
            }'''
        with tempfile.TemporaryDirectory() as d:
            paths = {}
            for name, rows in (("act", act), ("err", err), ("risk", risk), ("evt", evt)):
                paths[name] = os.path.join(d, name + ".jsonl")
                with open(paths[name], "w") as fh:
                    fh.write("".join(json.dumps(r) + "\n" for r in rows))
            args = ["-n", "--arg", "s", "s"]
            for name in ("act", "err", "risk", "evt"):
                args += ["--slurpfile", name, paths[name]]
            rc, out, errtext = run(args + [f])
        self.assertEqual((rc, errtext), (0, ""))
        self.assertEqual(json.loads(out), {
            "session": "s",
            "started": "2026-01-01T00:00:00Z",
            "ended": "2026-01-01T00:00:06Z",
            "tool_calls": 3,
            "commands_run": 1,
            "tool_failures": 1,
            "files_edited": ["a.ahk", "b.ahk"],
            "errors": [{"timestamp": "t1", "file": "b.ahk", "line": 2, "type": "syntax",
                        "message": "Missing operand."}],
            "risk_ops": [{"command": "rm -rf build\nx", "risk": 4, "blocked": False, "note": ""}],
            "events": {"Notification": 1, "Stop": 2},
            "status": "errors",
        })

    def test_session_report_lines(self):
        rec = json.dumps({
            "files_edited": ["a.ahk", "b.ahk"],
            "errors": [{"file": "b.ahk", "line": 2, "type": "syntax", "message": "Missing operand."}],
            "risk_ops": [{"command": "rm -rf build\nx", "risk": 4, "blocked": True, "note": ""}],
            "events": {"Notification": 1, "Stop": 2},
        })
        self.assertEqual(run(["-r", '.files_edited[]? | "  " + .'], rec)[1], "  a.ahk\n  b.ahk\n")
        self.assertEqual(run(["-r", '.errors[] | "  " + (.file|tostring) + ":" + (.line|tostring)'
                                    ' + "  " + .type + "  " + (.message|.[0:80])'], rec)[1],
                         "  b.ahk:2  syntax  Missing operand.\n")
        self.assertEqual(run(["-r", '.risk_ops[] | "  [risk \\(.risk)]" + (if .blocked then " BLOCKED"'
                                    ' else "" end) + "  " + (.command|gsub("\\n";" ")|.[0:80])'], rec)[1],
                         "  [risk 4] BLOCKED  rm -rf build x\n")
        self.assertEqual(run(["-r", '.events | to_entries[]? | "  \\(.key): \\(.value)"'], rec)[1],
                         "  Notification: 1\n  Stop: 2\n")
        self.assertEqual(run([".files_edited | length"], rec)[1], "2\n")

    def test_last_session_from_ndjson(self):
        # session-report.sh: tail -1 log | jq -r '.session // empty'
        self.assertEqual(run(["-r", ".session // empty"], '{"session":"a"}\n{"x":1}\n{"session":"b"}\n')[1],
                         "a\nb\n")


class Semantics(unittest.TestCase):
    """jq behaviour the hook filters lean on."""

    def out(self, args, stdin=b""):
        rc, out, err = run(args, stdin)
        self.assertEqual((rc, err), (0, ""), "jqlite %r failed" % (args,))
        return out

    def test_constants_and_literals(self):
        self.assertEqual(self.out(["-nc", "[true, false, null, 1, 1.5, \"s\", {}, []]"]),
                         '[true,false,null,1,1.5,"s",{},[]]\n')

    def test_cartesian_order_of_binary_operators(self):
        self.assertEqual(self.out(["-nc", "[(1,2) + (10,20)]"]), "[11,12,21,22]\n")

    def test_cartesian_order_of_object_construction(self):
        self.assertEqual(self.out(["-nc", "{a:(1,2), b:(3,4)}"]),
                         '{"a":1,"b":3}\n{"a":1,"b":4}\n{"a":2,"b":3}\n{"a":2,"b":4}\n')

    def test_interpolation_with_generators(self):
        self.assertEqual(self.out(["-nr", '"\\(1,2)-\\(3,4)"']), "1-3\n2-3\n1-4\n2-4\n")

    def test_arithmetic(self):
        self.assertEqual(self.out(["-nc", '[1/2, 7%3, -7%3, "ab"*2, ("a,b"/","), ([1,2,1]-[1]),'
                                          ' ({a:{b:1}}*{a:{c:2}}), (null+1), ("x"+null)]']),
                         '[0.5,1,-1,"abab",["a","b"],[2],{"a":{"b":1,"c":2}},1,"x"]\n')

    def test_comparisons_and_ordering(self):
        self.assertEqual(self.out(["-nc", '[1 == 1.0, true == 1, "a" < "b", [1] < [1,0], null < false]']),
                         "[true,false,true,true,true]\n")
        self.assertEqual(self.out(["-c", "sort"], '[{"a":1},"b",[0],2,true,false,null]'),
                         '[null,false,true,2,"b",[0],{"a":1}]\n')

    def test_and_or_not(self):
        self.assertEqual(self.out(["-nc", "[(true,false) and (true,false)]"]), "[true,false,false]\n")
        self.assertEqual(self.out(["-nc", "[false or true, (null | not), (0 | not)]"]), "[true,true,false]\n")

    def test_optional_and_try(self):
        self.assertEqual(self.out(["-c", "[.[] | .a?]"], '[1, {"a":2}, "x"]'), "[2]\n")
        self.assertEqual(self.out(["-c", "[.[]?]"], "5"), "[]\n")
        self.assertEqual(self.out(["-nr", 'try error("boom") catch .']), "boom\n")
        self.assertEqual(self.out(["-nc", '[.a?, (try error("x")), 1]']), "[null,1]\n")

    def test_tonumber(self):
        self.assertEqual(self.out(["-c", "map(tonumber? // \"bad\")"], '["12", "1.5", "x", 3, ""]'),
                         '[12,1.5,"bad",3,"bad"]\n')

    def test_slices_and_indices(self):
        self.assertEqual(self.out(["-c", "[.[1:3], .[-2:], .[:1], .[-1], .[10]]"], "[1,2,3,4]"),
                         "[[2,3],[3,4],[1],4,null]\n")
        self.assertEqual(self.out(["-r", ".[2:4]"], '"abcdef"'), "cd\n")
        self.assertEqual(self.out(["-c", '[.a.b.c, .["x y"], ."k"]'], '{"x y":1,"k":2}'), "[null,1,2]\n")

    def test_as_reduce_foreach(self):
        self.assertEqual(self.out(["-c", ". as $x | [$x[] * 2]"], "[1,2]"), "[2,4]\n")
        self.assertEqual(self.out(["-nc", "reduce range(5) as $i (0; . + $i)"]), "10\n")
        self.assertEqual(self.out(["-nc", "[foreach (1,2,3) as $x (0; . + $x)]"]), "[1,3,6]\n")
        self.assertEqual(self.out(["-nc", "[foreach (1,2,3) as $x (0; . + $x; [$x, .])]"]),
                         "[[1,1],[2,3],[3,6]]\n")

    def test_if_elif_without_else(self):
        self.assertEqual(self.out(["-c", '[.[] | if . == 1 then "one" elif . == 2 then "two" end]'], "[1,2,3]"),
                         '["one","two",3]\n')

    def test_collection_builtins(self):
        doc = '[{"k":"b","v":2},{"k":"a","v":1},{"k":"b","v":3}]'
        self.assertEqual(self.out(["-c", "group_by(.k) | map(length)"], doc), "[1,2]\n")
        self.assertEqual(self.out(["-c", "unique_by(.k) | map(.v)"], doc), "[1,2]\n")
        self.assertEqual(self.out(["-c", "sort_by(.v) | map(.v)"], doc), "[1,2,3]\n")
        self.assertEqual(self.out(["-c", "[min_by(.v).v, max_by(.v).v, (map(.v) | add)]"], doc), "[1,3,6]\n")
        self.assertEqual(self.out(["-c", "[limit(2; .[]) | .v] , first(.[]).k, (map(.k) | unique)"], doc),
                         '[2,1]\n"b"\n["a","b"]\n')
        self.assertEqual(self.out(["-c", "[.[] | select(.v > 1)] | length"], doc), "2\n")

    def test_object_builtins(self):
        self.assertEqual(self.out(["-c", "[keys, keys_unsorted, has(\"b\"), (to_entries | .[0])]"],
                                  '{"b":1,"a":2}'),
                         '[["a","b"],["b","a"],true,{"key":"b","value":1}]\n')
        self.assertEqual(self.out(["-c", "from_entries"], '[{"key":"a","value":1},{"k":"b","v":2},'
                                                          '{"name":"c","value":null}]'),
                         '{"a":1,"b":2,"c":null}\n')
        self.assertEqual(self.out(["-c", "with_entries({key: (.key | ascii_upcase), value})"], '{"a":1}'),
                         '{"A":1}\n')
        self.assertEqual(self.out(["-c", '[paths], getpath(["a",0])'], '{"a":[1]}'), '[["a"],["a",0]]\n1\n')

    def test_string_builtins(self):
        self.assertEqual(self.out(["-c", '[split(", "), (split(", ") | join("-")), ascii_downcase,'
                                         ' ltrimstr("A"), rtrimstr("c"), startswith("A"), length]'],
                                  '"A, b, c"'),
                         '[["A","b","c"],"A-b-c","a, b, c",", b, c","A, b, ",true,7]\n')
        self.assertEqual(self.out(["-c", '[test("^ab"; "i"), (sub("(?<x>b)"; "[\\(.x)]")),'
                                         ' gsub("b"; "_"), [match("b"; "g").offset], ([scan("[a-z]")] | length)]'],
                                  '"Abcb"'),
                         '[true,"A[b]cb","A_c_",[1,3],3]\n')
        self.assertEqual(self.out(["-c", 'capture("(?<n>[0-9]+)")'], '"id 42"'), '{"n":"42"}\n')

    def test_formats(self):
        self.assertEqual(self.out(["-r", "@csv, @tsv, @sh, @json, @base64, @uri"], '["a,b","c\\td", 1]'),
                         '"a,b","c\td",1\na,b\tc\\td\t1\n\'a,b\' \'c\td\' 1\n["a,b","c\\td",1]\n'
                         'WyJhLGIiLCJjXHRkIiwxXQ==\n%5B%22a%2Cb%22%2C%22c%5Ctd%22%2C1%5D\n')
        self.assertEqual(self.out(["-r", '@sh "rm \\(.)"'], '"it\'s"'), "rm 'it'\\''s'\n")
        self.assertEqual(self.out(["-r", "@base64d"], '"aGk="'), "hi\n")
        self.assertEqual(self.out(["-r", "@html"], '"<a href=\'x\'>&</a>"'),
                         "&lt;a href=&#39;x&#39;&gt;&amp;&lt;/a&gt;\n")

    def test_env_and_args(self):
        os.environ["JQLITE_TEST_VAR"] = "v1"
        try:
            self.assertEqual(self.out(["-nr", "$ENV.JQLITE_TEST_VAR, env.JQLITE_TEST_VAR"]), "v1\nv1\n")
        finally:
            del os.environ["JQLITE_TEST_VAR"]
        self.assertEqual(self.out(["-nc", "--arg", "a", "1", "$ARGS", "--args", "x", "y"]),
                         '{"positional":["x","y"],"named":{"a":"1"}}\n')
        self.assertEqual(self.out(["-nc", "$ARGS.positional", "--jsonargs", "1", '{"b":2}']),
                         '[1,{"b":2}]\n')


class OutputFormat(unittest.TestCase):

    def test_pretty_compact_raw_join(self):
        doc = '{"a":[1,{"b":null}],"e":{},"l":[]}'
        self.assertEqual(run(["."], doc)[1],
                         '{\n  "a": [\n    1,\n    {\n      "b": null\n    }\n  ],\n  "e": {},\n  "l": []\n}\n')
        self.assertEqual(run(["-c", "."], doc)[1], '{"a":[1,{"b":null}],"e":{},"l":[]}\n')
        self.assertEqual(run(["-r", ".[]"], '["x", 1]')[1], "x\n1\n")
        self.assertEqual(run(["-j", ".[]"], '["x", 1]')[1], "x1")

    def test_indent_tab_sort_ascii(self):
        self.assertEqual(run(["--indent", "1", "."], '{"a":1}')[1], '{\n "a": 1\n}\n')
        self.assertEqual(run(["--tab", "."], '{"a":1}')[1], '{\n\t"a": 1\n}\n')
        self.assertEqual(run(["-S", "-c", "."], '{"b":1,"a":{"d":1,"c":2}}')[1], '{"a":{"c":2,"d":1},"b":1}\n')
        self.assertEqual(run(["-c", "."], '"\u00e9\u2014"')[1], '"\u00e9\u2014"\n')
        self.assertEqual(run(["-a", "-c", "."], '"\u00e9"')[1], '"\\u00e9"\n')

    def test_numbers_print_like_jq(self):
        self.assertEqual(run(["-c", "."], "[1.0, 1.5, 1e3, 0.1, 100]")[1], "[1,1.5,1000,0.1,100]\n")
        self.assertEqual(run(["-nc", "[1e1000, -1e1000, nan]"])[1],
                         "[1.7976931348623157e+308,-1.7976931348623157e+308,null]\n")


class Input(unittest.TestCase):

    def test_ndjson_and_concatenated_values(self):
        self.assertEqual(run(["-c", ".a"], '{"a":1}\n{"a":2} {"a":3}{"a":4}')[1], "1\n2\n3\n4\n")

    def test_bom_and_crlf(self):
        self.assertEqual(run(["-r", ".a"], b'\xef\xbb\xbf{"a":"x"}\r\n'), (0, "x\n", ""))

    def test_slurp_raw_null_input(self):
        self.assertEqual(run(["-c", "-s", "."], "1 2 3")[1], "[1,2,3]\n")
        self.assertEqual(run(["-c", "-R", "."], "a\nb\n")[1], '"a"\n"b"\n')
        self.assertEqual(run(["-c", "-Rs", "."], "a\nb\n")[1], '"a\\nb\\n"\n')
        self.assertEqual(run(["-nc", "[inputs]"], "1 2")[1], "[1,2]\n")
        self.assertEqual(run(["-c", "[., input]"], "1 2 3 4")[1], "[1,2]\n[3,4]\n")

    def test_empty_input(self):
        self.assertEqual(run([".a"], ""), (0, "", ""))
        self.assertEqual(run([".a"], "\n  \n"), (0, "", ""))


class Errors(unittest.TestCase):

    def test_input_that_is_not_json(self):
        # Interpreter text fed to '.message // empty': nothing on stdout, exit 2.
        rc, out, err = run(["-r", ".message // empty"], "C:\\x.ahk (2) : ==> Missing operand.\n")
        self.assertEqual((rc, out), (2, ""))
        self.assertIn("jqlite: parse error", err)

    def test_values_before_bad_input_are_processed(self):
        rc, out, err = run(["-c", "."], '{"a":1}\n{bad')
        self.assertEqual((rc, out), (2, '{"a":1}\n'))
        self.assertIn("line 2", err)

    def test_unsupported_filters_fail_loudly(self):
        for f in ("def f: 1; f", ".a = 1", ".a |= 1", ".a += 1", "del(.a)", "path(.a)",
                  ". as [$a] | $a", "$__loc__", "label $out | 1", "tostream", "input_line_number",
                  "getpath([\"a\"]) |= 1", "import \"m\" as m; 1", "strptime(\"%Y\")"):
            rc, out, err = run(["-n", f])
            self.assertEqual((rc, out), (3, ""), f)
            self.assertIn("jqlite: unsupported filter", err, f)

    def test_syntax_errors(self):
        for f in ("{a:", ".[", "1 +", '"unterminated', "if . then 1", ". | | .", "1 == 2 == 3"):
            rc, out, err = run(["-n", f])
            self.assertEqual((rc, out), (3, ""), f)
            self.assertIn("compile error", err, f)

    def test_undefined_variable(self):
        rc, _, err = run(["-n", "$nope"])
        self.assertEqual(rc, 3)
        self.assertIn("$nope is not defined", err)

    def test_runtime_errors(self):
        rc, out, err = run([".a"], "5")
        self.assertEqual((rc, out), (5, ""))
        self.assertIn('Cannot index number with "a"', err)
        rc, out, err = run(["-c", ".[] | .a"], '[{"a":1}, 2, {"a":3}]')
        self.assertEqual((rc, out), (5, "1\n"))
        self.assertEqual(run(['"a" + 1'], "null")[0], 5)
        self.assertEqual(run([".[]"], "null")[0], 5)

    def test_runtime_error_does_not_stop_later_inputs(self):
        rc, out, _ = run([".a"], '5 {"a":2}')
        self.assertEqual((rc, out), (5, "2\n"))

    def test_exit_status_flag(self):
        self.assertEqual(run(["-e", ".a"], '{"a":1}')[0], 0)
        self.assertEqual(run(["-e", ".a"], '{"a":false}')[0], 1)
        self.assertEqual(run(["-e", ".a"], '{"a":null}')[0], 1)
        self.assertEqual(run(["-e", ".a // empty"], "{}")[0], 4)
        self.assertEqual(run(["-e", ".[]"], "[1, null]")[0], 1)
        self.assertEqual(run(["-e", ".[]"], "[null, 1]")[0], 0)

    def test_usage_errors(self):
        self.assertEqual(run(["--seq", "."], "1")[0], 2)
        self.assertEqual(run(["-C", "."], "1")[0], 2)
        self.assertEqual(run(["--arg", "x"], "1")[0], 2)
        self.assertEqual(run(["--argjson", "x", "{bad", "."], "1")[0], 2)
        rc, _, err = run([".", os.path.join(tempfile.gettempdir(), "no-such-jqlite-input.json")])
        self.assertEqual(rc, 2)
        self.assertIn("Could not open", err)


class CommandLine(unittest.TestCase):
    """The script as the hooks run it: a separate process reading stdin."""

    def proc(self, args, stdin=b""):
        p = subprocess.run([sys.executable, "-E", "-S", JQLITE] + args, input=stdin,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
        return p.returncode, p.stdout, p.stderr

    def test_output_has_no_carriage_returns(self):
        # Command substitution in bash keeps a trailing \r; output must be plain \n.
        rc, out, _ = self.proc(["-r", ".a, .b"], b'{"a":"x","b":{"c":1}}')
        self.assertEqual((rc, out), (0, b'x\n{\n  "c": 1\n}\n'))

    def test_exit_codes_from_the_process(self):
        self.assertEqual(self.proc(["-r", ".a // empty"], b"not json")[0], 2)
        rc, _, err = self.proc(["-n", "def f: 1; f"])
        self.assertEqual(rc, 3)
        self.assertIn(b"jqlite: unsupported filter", err)
        self.assertEqual(self.proc([".a"], b"5")[0], 5)
        self.assertEqual(self.proc(["-e", ".a"], b'{"a":false}')[0], 1)

    def test_utf8_arguments_and_output(self):
        rc, out, _ = self.proc(["-nr", "--arg", "s", "\u2014 \u25b8 \u00e9", "$s"])
        self.assertEqual((rc, out), (0, "\u2014 \u25b8 \u00e9\n".encode("utf-8")))


@unittest.skipUnless(os.name == "nt", "path mapping only applies to native Windows Python")
class WindowsPaths(unittest.TestCase):

    def test_posix_spellings_map_to_drive_paths(self):
        self.assertEqual(jqlite.native_path("/c/Windows"), "C:/Windows")
        self.assertEqual(jqlite.native_path("/mnt/d/data/x.json"), "D:/data/x.json")
        self.assertEqual(jqlite.native_path("/cygdrive/e/y"), "E:/y")
        self.assertEqual(jqlite.native_path("/dev/null"), os.devnull)
        self.assertEqual(jqlite.native_path("relative/p.json"), "relative/p.json")

    def test_slurpfile_dev_null_is_empty(self):
        self.assertEqual(run(["-nc", "--slurpfile", "a", "/dev/null", "$a"])[1], "[]\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
