#Requires AutoHotkey v2.1-alpha.30

; nocoverage.ahk — a pure function with no tests anywhere GatePure looks, so
; its pure row passes with tests: 0 — a coverage gap, not a verdict. Nothing
; runs at load time, so launching it directly does nothing and exits 0.

Greeting(name) => "Hello, " name
