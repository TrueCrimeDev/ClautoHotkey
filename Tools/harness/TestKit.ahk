#Requires AutoHotkey v2.1-alpha.30

#Include %A_LineFile%\..\HarnessCore.ahk

; TestKit.ahk — the assertion library the harness's pure tier (GatePure.ahk)
; runs. A test file includes it, makes assertions — loose, or grouped into
; cases with TestKit.Test — and ends with TestKit.Summary() as its LAST
; statement:
;
;   #Requires AutoHotkey v2.1-alpha.30
;   #Include %A_LineFile%\..\..\Tools\harness\TestKit.ahk
;   #Include %A_LineFile%\..\..\Calc.ahk
;
;   TestKit.Test("adds", () => TestKit.Eq(Calc.Add(2, 3), 5, "2 + 3"))
;   TestKit.Test("rejects zero", RejectsZero)
;   TestKit.Summary()
;
;   RejectsZero() {
;       TestKit.Throws(() => Calc.Div(1, 0), "1 / 0", ZeroDivisionError)
;       TestKit.Throws(() => Calc.Div(1, 0), "1 / 0 message", "by zero")
;   }
;
; Assertions. Method names are case-insensitive, so the fork's qa spelling
; (Assert.eq / truthy / falsy / throws / noThrow) works unchanged. Each
; returns true when it passed, false when it failed.
;
;   Eq(actual, expected, label := "")    strings: case-sensitive ==; both
;                                        numbers: numeric (1 = 1.0); objects:
;                                        the same object
;   Ne(actual, expected, label := "")    the opposite of Eq
;   Truthy(cond, label := "")            Falsy(cond, label := "")
;   Throws(fn, label := "", expect := "")
;                                        fn() must throw. expect is an error
;                                        class (passes when the thrown value
;                                        `is` it) or a message substring
;   NoThrow(fn, label := "")             fn() must not throw
;   Near(actual, expected, tolerance := 1e-9, label := "")
;   Match(text, regex, label := "")      RegExMatch must find the pattern
;   DeepEq(actual, expected, label := "")
;                                        Arrays, Maps, plain Objects' and
;                                        class instances' own properties;
;                                        anything else as Eq. A failure names
;                                        the first differing path: [2].name
;   Fail(message)                        an unconditional failure
;   Test(name, fn)                       one case. An exception escaping fn
;                                        fails the case with the error's own
;                                        message and line; the run goes on
;   Summary()                            prints the totals and exits
;
; Output: one stdout line per record through the fork's Print, a tag plus a
; JSON object written by HarnessJson, so a reader never has to guess:
;
;   AHKTEST|start|{"kit":"TestKit","protocol":1}
;   AHKTEST|fail|{"test":..,"label":..,"expected":..,"actual":..,"file":..,"line":..,"message":..}
;   AHKTEST|case|{"name":..,"status":"pass|fail|error","ms":..,"failures":n}
;   AHKTEST|summary|{"passed":P,"failed":F,"cases":C,"errors":E}
;   qa: P passed, F failed
;
; start is printed once, when this file loads. Passing assertions print
; nothing, so without it a file that stopped early with no failures (the
; code under test called ExitApp, say) would look like a script that never
; used TestKit at all; with it, GatePure knows a summary was owed.
;
; The last line is the fork's qa convention, so qa\run.ahk reads a TestKit
; file as one of its own. "failed" counts failed assertions plus cases that
; ended in an uncaught exception (those are also counted in "errors"), so a
; crashing case can never leave the exit code at 0. "test" is the enclosing
; case, empty outside one. expected/actual are display strings: strings
; quoted with AHK escapes, numbers bare, objects summarised by type and size.
;
; Exit code = failed, capped at 99 so it can never read as the 124/130/137
; outcomes. The summary line, not the exit code, is the source of truth: a
; file whose summary never printed did not finish, whatever it exited with,
; and GatePure checks that the two agree.
;
; Where a failure is reported was measured, not assumed: every public
; assertion builds Error("", -1) in its own body, which names the line that
; called it — the test file's line, not one in here. That holds through the
; Assert alias, inside a fat-arrow case (the arrow's line) and from inside a
; catch block, on alpha.30 and alpha.31 alike.
;
; Counters live on TestKit and every method names TestKit explicitly, never
; `this`, so a file that mixes TestKit.Eq and Assert.Eq counts each
; assertion once.
;
; TestKit needs HarnessCore.ahk beside it (the JSON writer) and the +Console
; fork's Print. To test a project outside this repo, include this file by
; path, or copy TestKit.ahk and HarnessCore.ahk together into its Lib\.
;
; Assert.ahk is the qa-style alias (class Assert extends TestKit). If the
; code under test already defines a class named Assert, include TestKit.ahk
; directly — not Assert.ahk — and call TestKit.* instead.

; The one statement this file runs: it sits in the including script's
; auto-execute section at the include's position, so the start record comes
; before anything the test does. Every record path calls Announce too, for a
; file that includes TestKit further down.
TestKit.Announce()

class TestKit {
    static Passed := 0
    static Failed := 0
    static Cases := 0
    static Errors := 0
    static CaseName := ""
    static CaseFailures := 0

    static Eq(actual, expected, label := "") {
        if TestKit.Same(actual, expected)
            return TestKit.Pass()
        return TestKit.Record(Error("", -1), label, TestKit.Show(expected), TestKit.Show(actual)
            , "Eq: values differ")
    }

    static Ne(actual, expected, label := "") {
        if !TestKit.Same(actual, expected)
            return TestKit.Pass()
        return TestKit.Record(Error("", -1), label, "anything but " TestKit.Show(expected)
            , TestKit.Show(actual), "Ne: values are equal")
    }

    static Truthy(cond, label := "") {
        if cond
            return TestKit.Pass()
        return TestKit.Record(Error("", -1), label, "truthy", TestKit.Show(cond)
            , "Truthy: value is falsy")
    }

    static Falsy(cond, label := "") {
        if !cond
            return TestKit.Pass()
        return TestKit.Record(Error("", -1), label, "falsy", TestKit.Show(cond)
            , "Falsy: value is truthy")
    }

    static Throws(fn, label := "", expect := "") {
        ; Throws(fn, ValueError) puts the class in the label slot. A class is
        ; never a useful label, so it is read as what it was meant to be.
        if (label is Class && TestKit.Blank(expect)) {
            expect := label
            label := ""
        }
        if (IsObject(expect) && !(expect is Class))
            return TestKit.Record(Error("", -1), label, "an error class or a message substring"
                , TestKit.Show(expect), "Throws: unusable expectation")
        ; Checked first: calling a non-callable throws too, and that would
        ; otherwise pass as the exception the test was waiting for.
        if !HasMethod(fn)
            return TestKit.Record(Error("", -1), label, "a callable", TestKit.Show(fn)
                , "Throws: fn is not callable")
        try {
            fn()
        } catch Any as thrown {
            if TestKit.Expected(thrown, expect)
                return TestKit.Pass()
            return TestKit.Record(Error("", -1), label, TestKit.ShowExpect(expect)
                , TestKit.ShowThrown(thrown), "Throws: threw something else" TestKit.Origin(thrown))
        }
        return TestKit.Record(Error("", -1), label, TestKit.ShowExpect(expect), "no exception"
            , "Throws: nothing was thrown")
    }

    static NoThrow(fn, label := "") {
        if !HasMethod(fn)
            return TestKit.Record(Error("", -1), label, "a callable", TestKit.Show(fn)
                , "NoThrow: fn is not callable")
        try {
            fn()
        } catch Any as thrown {
            return TestKit.Record(Error("", -1), label, "no exception", TestKit.ShowThrown(thrown)
                , "NoThrow: threw" TestKit.Origin(thrown))
        }
        return TestKit.Pass()
    }

    static Near(actual, expected, tolerance := 1e-9, label := "") {
        if (!TestKit.Numeric(actual) || !TestKit.Numeric(expected) || !TestKit.Numeric(tolerance))
            return TestKit.Record(Error("", -1), label, TestKit.Show(expected) " +/- " TestKit.Show(tolerance)
                , TestKit.Show(actual), "Near: needs numbers")
        gap := Abs(actual - expected)
        if (gap <= tolerance)
            return TestKit.Pass()
        ; The tolerance is shown short (0.1, not 0.10000000000000001); the
        ; values keep full precision, since that is where they differ.
        return TestKit.Record(Error("", -1), label, TestKit.Show(expected) " +/- " Format("{:g}", tolerance)
            , TestKit.Show(actual), "Near: off by " Format("{:g}", gap))
    }

    static Match(text, regex, label := "") {
        if (IsObject(text) || IsObject(regex))
            return TestKit.Record(Error("", -1), label, "text matching " TestKit.Show(regex)
                , TestKit.Show(text), "Match: needs a string and a pattern")
        try {
            found := RegExMatch(text, regex)
        } catch Any as err {
            return TestKit.Record(Error("", -1), label, "a valid pattern", TestKit.Show(regex)
                , "Match: bad pattern: " TestKit.MessageOf(err))
        }
        if found
            return TestKit.Pass()
        return TestKit.Record(Error("", -1), label, "text matching " TestKit.Show(regex)
            , TestKit.Show(text), "Match: no match")
    }

    static DeepEq(actual, expected, label := "") {
        out := Map()
        if !TestKit.Diff(actual, expected, "", out, Map(), 0)
            return TestKit.Pass()
        where := (out["path"] = "") ? "the top level" : out["path"]
        return TestKit.Record(Error("", -1), label, out["expected"], out["actual"]
            , "DeepEq: first difference at " where)
    }

    static Fail(message) {
        return TestKit.Record(Error("", -1), "", "", "", "Fail: " TestKit.Text(message))
    }

    ; One case. Failures inside it are counted against it; an exception that
    ; escapes it is one more failure, recorded where the error was raised —
    ; often inside the code under test — and the run moves on to the next
    ; case. Nested cases restore the outer case afterwards and add their
    ; failures to it.
    static Test(name, fn) {
        TestKit.Announce()
        priorName := TestKit.CaseName
        priorFailures := TestKit.CaseFailures
        TestKit.CaseName := TestKit.Text(name)
        TestKit.CaseFailures := 0
        TestKit.Cases += 1
        status := "pass"
        started := TestKit.Clock()
        try {
            if !HasMethod(fn)
                throw TypeError("TestKit.Test needs a callable, got " Type(fn), -1)
            fn()
        } catch Any as thrown {
            status := "error"
            TestKit.Errors += 1
            TestKit.RecordThrown(thrown, Error("", -1))
        }
        ms := Round(TestKit.Clock() - started)
        failures := TestKit.CaseFailures
        if (status = "pass" && failures > 0)
            status := "fail"
        record := JObj()
        record.Set("name", TestKit.CaseName)
        record.Set("status", status)
        record.Set("ms", ms)
        record.Set("failures", failures)
        Print("AHKTEST|case|" HarnessJson.Dump(record))
        TestKit.CaseName := priorName
        TestKit.CaseFailures := priorFailures + failures
        return status = "pass"
    }

    ; Must be the last statement of a test file: anything after ExitApp never
    ; runs, and a file that never reaches it has no summary — which the gate
    ; reads as a run that did not finish.
    static Summary() {
        TestKit.Announce()
        record := JObj()
        record.Set("passed", TestKit.Passed)
        record.Set("failed", TestKit.Failed)
        record.Set("cases", TestKit.Cases)
        record.Set("errors", TestKit.Errors)
        Print("AHKTEST|summary|" HarnessJson.Dump(record))
        Print("qa: {} passed, {} failed", TestKit.Passed, TestKit.Failed)
        ExitApp(Min(TestKit.Failed, 99))
    }

    static Announce() {
        static done := false
        if done
            return
        done := true
        record := JObj()
        record.Set("kit", "TestKit")
        record.Set("protocol", 1)
        Print("AHKTEST|start|" HarnessJson.Dump(record))
    }

    static Pass() {
        TestKit.Announce()
        TestKit.Passed += 1
        return true
    }

    ; `where` is the caller-frame Error a public assertion built in its own
    ; body; only its File and Line are used.
    static Record(where, label, expected, actual, message) {
        return TestKit.RecordAt(where.File, where.Line, label, expected, actual, message)
    }

    static RecordAt(file, line, label, expected, actual, message) {
        TestKit.Announce()
        TestKit.Failed += 1
        TestKit.CaseFailures += 1
        record := JObj()
        record.Set("test", TestKit.CaseName)
        record.Set("label", TestKit.Text(label))
        record.Set("expected", expected)
        record.Set("actual", actual)
        record.Set("file", file)
        record.Set("line", line)
        record.Set("message", message)
        Print("AHKTEST|fail|" HarnessJson.Dump(record))
        return false
    }

    ; An Error carries the place it was raised, which is the most useful
    ; place to point. Anything else thrown (a string, a number) has no
    ; position of its own, so the case's call site stands in.
    static RecordThrown(thrown, site) {
        if (thrown is Error) {
            spot := TestKit.Locate(thrown)
            ; The type is already in the label ("uncaught ValueError").
            message := TestKit.Text(thrown.Message)
            if (!IsObject(thrown.Extra) && thrown.Extra != "")
                message .= " | Specifically: " thrown.Extra
            TestKit.RecordAt(spot["file"], spot["line"], "uncaught " Type(thrown), "no exception"
                , TestKit.ShowThrown(thrown), message TestKit.ReachedFrom(thrown, spot))
            return
        }
        TestKit.Record(site, "uncaught " Type(thrown), "no exception"
            , TestKit.ShowThrown(thrown), "threw a " Type(thrown) " value: " TestKit.Show(thrown))
    }

    ; Where an error really came from. A thrower that used a negative What
    ; offset — throw ValueError(msg, -1) — names its caller, and when TestKit
    ; made that call the position lands in this file, which helps nobody
    ; (measured: "TestKit.ahk:140"). The stack's first frame outside this
    ; file is the throw site, so that is used instead.
    static Locate(thrown) {
        spot := Map()
        spot["file"] := thrown.File
        spot["line"] := thrown.Line
        if (thrown.File != A_LineFile)
            return spot
        try {
            for frame in StrSplit(thrown.Stack, "`n", "`r") {
                if (RegExMatch(frame, "^(.*) \((\d+)\) : \[", &m) && m[1] != A_LineFile) {
                    spot["file"] := m[1]
                    spot["line"] := Integer(m[2])
                    return spot
                }
            }
        } catch Error as err {
            OutputDebug("TestKit: cannot read a stack: " err.Message)
        }
        return spot
    }

    ; The test file's own frame on an error raised elsewhere (in the code
    ; under test, say), read from the stack: "file (line) : [what] code".
    static ReachedFrom(thrown, spot) {
        if (spot["file"] = A_ScriptFullPath)
            return ""
        try {
            for frame in StrSplit(thrown.Stack, "`n", "`r") {
                if (RegExMatch(frame, "^(.*) \((\d+)\) : \[", &m) && m[1] = A_ScriptFullPath)
                    return " (reached from " A_ScriptName ":" m[2] ")"
            }
        } catch Error as err {
            return " (stack unreadable: " err.Message ")"
        }
        return ""
    }

    ; Strings strictly (case-sensitive ==), pure numbers numerically, objects
    ; by identity. A number against a numeric string falls to ==, which
    ; compares those numerically too — the fork's qa Assert.eq behaves the
    ; same, so qa-style tests keep their meaning.
    static Same(a, b) {
        if (IsObject(a) || IsObject(b))
            return IsObject(a) && IsObject(b) && ObjPtr(a) = ObjPtr(b)
        if (a is Number && b is Number)
            return a = b
        return a == b
    }

    ; Walks both values together and stops at the first difference, filling
    ; out with its path and the two display strings found there. `seen`
    ; holds the pairs already being compared, so a cyclic structure ends
    ; instead of recursing forever; a pair met again is judged where it was
    ; first entered.
    static Diff(actual, expected, path, out, seen, depth) {
        if (!IsObject(actual) || !IsObject(expected)) {
            if TestKit.Same(actual, expected)
                return false
            return TestKit.Differ(out, path, TestKit.Show(expected), TestKit.Show(actual))
        }
        if (ObjPtr(actual) = ObjPtr(expected))
            return false
        pair := ObjPtr(actual) ":" ObjPtr(expected)
        if seen.Has(pair)
            return false
        seen[pair] := true
        if (depth >= 64)
            return TestKit.Differ(out, path, "(nesting deeper than 64 — not compared)", TestKit.Show(actual))
        if (expected is Array || actual is Array) {
            if !(expected is Array && actual is Array)
                return TestKit.Differ(out, path, TestKit.Show(expected), TestKit.Show(actual))
            loop Max(expected.Length, actual.Length) {
                here := path "[" A_Index "]"
                hasExpected := A_Index <= expected.Length && expected.Has(A_Index)
                hasActual := A_Index <= actual.Length && actual.Has(A_Index)
                if (!hasExpected || !hasActual) {
                    if (hasExpected = hasActual)
                        continue
                    return TestKit.Differ(out, here
                        , hasExpected ? TestKit.Show(expected[A_Index]) : TestKit.Absent(A_Index, expected)
                        , hasActual ? TestKit.Show(actual[A_Index]) : TestKit.Absent(A_Index, actual))
                }
                if TestKit.Diff(actual[A_Index], expected[A_Index], here, out, seen, depth + 1)
                    return true
            }
            return false
        }
        if (expected is Map || actual is Map) {
            if !(expected is Map && actual is Map)
                return TestKit.Differ(out, path, TestKit.Show(expected), TestKit.Show(actual))
            for key, value in expected {
                here := path "[" TestKit.Show(key) "]"
                if !actual.Has(key)
                    return TestKit.Differ(out, here, TestKit.Show(value), "<missing>")
                if TestKit.Diff(actual[key], value, here, out, seen, depth + 1)
                    return true
            }
            for key, value in actual {
                if !expected.Has(key)
                    return TestKit.Differ(out, path "[" TestKit.Show(key) "]", "<missing>", TestKit.Show(value))
            }
            return false
        }
        if (TestKit.IsRecord(expected) || TestKit.IsRecord(actual)) {
            if (Type(expected) != Type(actual))
                return TestKit.Differ(out, path, TestKit.Show(expected), TestKit.Show(actual))
            for name in expected.OwnProps() {
                here := path "." name
                if !actual.HasOwnProp(name)
                    return TestKit.Differ(out, here, TestKit.Show(TestKit.Prop(expected, name)), "<missing>")
                if TestKit.Diff(TestKit.Prop(actual, name), TestKit.Prop(expected, name), here, out, seen, depth + 1)
                    return true
            }
            for name in actual.OwnProps() {
                if !expected.HasOwnProp(name)
                    return TestKit.Differ(out, path "." name, "<missing>", TestKit.Show(TestKit.Prop(actual, name)))
            }
            return false
        }
        ; A Buffer, Func, COM object or the like has no structure to walk;
        ; two different ones are different.
        return TestKit.Differ(out, path, TestKit.Show(expected), TestKit.Show(actual))
    }

    static Differ(out, path, expected, actual) {
        out["path"] := path
        out["expected"] := expected
        out["actual"] := actual
        return true
    }

    static Absent(index, arr) => (index <= arr.Length) ? "<unset>" : "<missing>"

    ; A plain Object, or a class instance that carries fields of its own.
    ; Classes, functions, Buffers and COM wrappers are excluded: their own
    ; properties are not their value.
    static IsRecord(value) {
        if (!IsObject(value) || value is Class || value is Func || value is Buffer || value is ComValue)
            return false
        if (Type(value) = "Object")
            return true
        try {
            return ObjOwnPropCount(value) > 0
        } catch Error as err {
            OutputDebug("TestKit: cannot count the own properties of a " Type(value) ": " err.Message)
            return false
        }
    }

    ; A property that cannot be read still has to be compared and shown, so
    ; the failure becomes its value rather than an exception mid-walk.
    static Prop(obj, name) {
        try {
            return obj.%name%
        } catch Any as err {
            return "<unreadable: " TestKit.MessageOf(err) ">"
        }
    }

    static Expected(thrown, expect) {
        if TestKit.Blank(expect)
            return true
        if (expect is Class)
            return thrown is expect
        return InStr(TestKit.MessageOf(thrown), String(expect)) > 0
    }

    static ShowExpect(expect) {
        if TestKit.Blank(expect)
            return "an exception"
        if (expect is Class)
            return "a " expect.Prototype.__Class
        return "an exception whose message contains " TestKit.Show(expect)
    }

    static ShowThrown(thrown) {
        if (thrown is Error)
            return Type(thrown) ": " TestKit.Clip(TestKit.Text(thrown.Message), 300)
        return "a " Type(thrown) " value: " TestKit.Show(thrown)
    }

    static Origin(thrown) {
        if !(thrown is Error)
            return ""
        spot := TestKit.Locate(thrown)
        SplitPath(spot["file"], &name)
        return " at " name ":" spot["line"]
    }

    static MessageOf(thrown) {
        if (thrown is Error)
            return TestKit.Text(thrown.Message)
        return IsObject(thrown) ? TestKit.Describe(thrown) : String(thrown)
    }

    ; Strings quoted with the escapes AHK source would use, so a stray tab
    ; or line break is visible; numbers bare; objects as type and size.
    static Show(value) {
        if IsObject(value)
            return TestKit.Describe(value)
        if (value is Number)
            return String(value)
        text := String(value)
        clipped := StrLen(text) > 200
        if clipped
            text := SubStr(text, 1, 200)
        text := StrReplace(text, "``", "````")
        text := StrReplace(text, '"', '``"')
        text := StrReplace(text, "`r", "``r")
        text := StrReplace(text, "`n", "``n")
        text := StrReplace(text, "`t", "``t")
        return '"' text '"' (clipped ? "..." : "")
    }

    static Describe(obj) {
        try {
            if (obj is Array)
                return "Array(" obj.Length ")"
            if (obj is Map)
                return "Map(" obj.Count ")"
            if (obj is Buffer)
                return "Buffer(" obj.Size " bytes)"
            if (obj is Class)
                return "class " obj.Prototype.__Class
            if (obj is Func)
                return Type(obj) "(" (obj.Name = "" ? "anonymous" : obj.Name) ")"
            if (obj is Error)
                return Type(obj) "(" TestKit.Show(TestKit.Clip(TestKit.Text(obj.Message), 120)) ")"
            count := ObjOwnPropCount(obj)
            return Type(obj) "{" count " own prop" (count = 1 ? "" : "s") "}"
        } catch Any as err {
            ; Rendering is best effort: a value that cannot describe itself
            ; must not turn a failing assertion into a crash.
            return Type(obj)
        }
    }

    static Text(value) => IsObject(value) ? TestKit.Describe(value) : String(value)

    static Clip(text, max) => StrLen(text) <= max ? text : SubStr(text, 1, max) "..."

    static Blank(value) => !IsObject(value) && value == ""

    static Numeric(value) => !IsObject(value) && IsNumber(value)

    ; Milliseconds from the performance counter: A_TickCount moves in ~16 ms
    ; steps, which would report most cases as 0 or 16.
    static Clock() {
        static frequency := 0
        if !frequency
            DllCall("QueryPerformanceFrequency", "Int64*", &frequency)
        count := 0
        DllCall("QueryPerformanceCounter", "Int64*", &count)
        return count * 1000 / frequency
    }
}
