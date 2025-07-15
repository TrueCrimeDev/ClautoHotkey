# Topic: Remove Default Auto-Focus and Text Highlighting in Edit Controls

## Category

Snippet

## Overview

When an Edit control is the default or only control in an AutoHotkey GUI, it automatically receives focus and its text gets highlighted. This snippet provides techniques to remove this default behavior, allowing for a cleaner user experience by preventing the automatic text selection when a GUI opens.

## Key Points

- Default behavior: Edit controls automatically receive focus and text highlighting when they are the first or only control
- Two solutions available: Message-based approach (no flicker) and post-show detection (simpler)
- The message-based method intercepts the EN_SETFOCUS message to prevent highlighting
- The caret position can be set to start (0) or end (-1) of the text

## Syntax and Parameters

```cpp
; Method 1: Message-based approach (no flicker)
OnMessage(EN_SETFOCUS:=0x0111, CB:=(wp,lp,*)=>(PostMessage(0xB1,0,0,lp),OnMessage(EN_SETFOCUS,CB,0)))

; Method 2: Post-show detection approach
(G.FocusedCtrl Is Gui.Edit) && Send("^{Home}")  ; Set caret to start
(G.FocusedCtrl Is Gui.Edit) && Send("^{End}")   ; Set caret to end
```

## Code Examples

```cpp
; Example 1: Message-based approach (prevents flicker)
#Requires AutoHotkey v2.0

Text := "
(
Apple
Banana
Cherry
)"

G := Gui()
G.AddEdit("w300 h200", Text)
; Set caret to the start & remove auto-focus
OnMessage(EN_SETFOCUS:=0x0111, CB:=(wp,lp,*)=>(PostMessage(0xB1,0,0,lp),OnMessage(EN_SETFOCUS,CB,0)))
G.Show()

; Example 2: Post-show detection approach
#Requires AutoHotkey v2.0

Text := "
(
Apple
Banana
Cherry
)"

G := Gui()
G.AddEdit("w300 h200", Text)
G.Show()
(G.FocusedCtrl Is Gui.Edit) && Send("^{Home}")  ; Set caret to start without selection
```

## Implementation Notes

- The message-based approach (Method 1):
  * Uses message hooking to intercept the EN_SETFOCUS notification
  * Sends EM_SETSEL message (0xB1) to position the caret without selection
  * Self-unhooks after executing once (one-time operation)
  * Prevents any visible flicker as it happens before the GUI is fully rendered
  * Change the second parameter of PostMessage from 0 to -1 to set caret to the end of text

- The post-show detection approach (Method 2):
  * Simpler but may show brief flicker on slower systems
  * Uses Gui.FocusedCtrl to detect if an Edit control has focus
  * Sends keyboard shortcuts (Ctrl+Home or Ctrl+End) to reposition the caret
  * Only works after the GUI is already displayed

- The message 0xB1 is EM_SETSEL, which selects a range of text:
  * First parameter: Start position (0 = beginning of text)
  * Second parameter: End position (0 = same as start = no selection)
  * Setting both parameters to the same value removes selection and positions the caret

- If you want to completely prevent the Edit control from getting focus initially, consider adding a dummy control with Tabstop style before the Edit control

## Related AHK Concepts

- OnMessage - For intercepting Windows messages
- PostMessage - For sending Windows messages directly to controls
- Gui.FocusedCtrl - For detecting which control has focus
- Send - For sending keyboard shortcuts to manipulate text selection
- Edit control notifications - Windows messages specific to Edit controls

## Tags

#AutoHotkey #GUI #EditControl #Focus #TextSelection #WindowsMessages #UserExperience