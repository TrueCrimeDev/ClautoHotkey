#Requires AutoHotkey v2.0
; Basic test script that should always pass

; Variables to test
testVar1 := "Hello"
testVar2 := "World"
testResult := testVar1 " " testVar2

; Simple function to test
Add(a, b) {
    return a + b
}

; Run a simple test
if (Add(2, 3) = 5)
    success1 := true
else
    success1 := false
    
; String concatenation test
if (testResult = "Hello World")
    success2 := true
else
    success2 := false

; Exit with success status
if (success1 && success2)
    ExitApp 0  ; Success exit code
else
    ExitApp 1  ; Error exit code
