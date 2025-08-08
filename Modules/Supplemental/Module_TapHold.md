Don't use this library for reference unless "TapHold" is mentioned in the request.

### **TapHoldManager Library**

The **TapHoldManager** library is an **AutoHotkey v2** class-based system that allows developers to **manage complex key bindings** based on tap and hold events. It provides a structured way to handle **single key taps, multiple taps (chording), and key holds** in a highly configurable manner.

---

### **Key Features:**
| Feature | Description |
|---------|------------|
| **Tap Detection** | Detects when a key is quickly pressed and released. |
| **Hold Detection** | Detects when a key is held down beyond a configurable time threshold. |
| **Multi-Tap Support** | Allows sequences of taps to trigger specific actions (e.g., double-tap, triple-tap, etc.). |
| **Hotkey Pausing & Resuming** | Can temporarily disable or re-enable a hotkey. |
| **Window-Specific Bindings** | Can restrict key bindings to a specific window. |
| **Automatic Safety Checks** | Prevents keys from getting "stuck" in the down state. |

---

### **How the Library Works**
1. **Creating an Instance**
   ```ahk
   manager := TapHoldManager(150, 150)
   ```
   - **tapTime (ms)** → Time threshold to determine a tap (default: `150` ms).
   - **holdTime (ms)** → Time threshold to determine a hold (default: `150` ms).

2. **Adding a Key Binding**
   ```ahk
   manager.Add("a", CallbackFunction)
   ```
   - Binds the **"a" key** to a function callback that will be executed depending on whether it was tapped, held, or tapped multiple times.

3. **Callback Function Format**
   ```ahk
   CallbackFunction(isHold, sequence, state) {
       if (isHold) {
           MsgBox "Key held for " sequence " sequence(s)."
       } else {
           MsgBox "Key tapped " sequence " times."
       }
   }
   ```
   - `isHold`: `true` if the key was held, `false` if tapped.
   - `sequence`: Number of taps before release.
   - `state`: `1` for hold, `0` for tap.

4. **Removing a Binding**
   ```ahk
   manager.RemoveHotkey("a")
   ```

5. **Pausing & Resuming Hotkeys**
   ```ahk
   manager.PauseHotkey("a")  ; Temporarily disables "a"
   manager.ResumeHotkey("a")  ; Re-enables "a"
   ```

---

### **Internal Architecture Overview**
#### **TapHoldManager Class**
- **Stores all key bindings** in `Bindings := Map()`.
- Manages `activeKeys`, `lastKeyPress`, and ensures proper timing logic for taps and holds.

#### **KeyManager Subclass**
- Each **individual key** has a **KeyManager** instance, handling:
  - **State management** (tap, hold, multi-tap).
  - **Timers** for detecting tap vs. hold.
  - **Hotkey declaration & cleanup**.
  - **Safety checks** to prevent stuck keys.

#### **Timers Used**
- **HoldWatcher**: Triggers if the key is held beyond `holdTime`.
- **TapWatcher**: Detects consecutive taps within `tapTime`.
- **SafetyCheck**: Prevents stuck keys every 1 second.

---

### **Practical Use Cases**
| Scenario | Implementation |
|----------|---------------|
| **Custom Shortcut Handling** | Bind a key to perform different actions based on tap/hold. |
| **Gaming Keybinds** | Assign different in-game actions to a single key based on duration. |
| **Text Automation** | Short tap types a word, long hold types a phrase. |
| **Accessibility Features** | Alternative input methods for users with limited mobility. |

---

### **Why Use TapHoldManager?**
✅ **More control** over key behaviors.  
✅ **Reduces accidental inputs** by allowing multiple states.  
✅ **Supports advanced shortcuts** like sequences, combos, and press/hold actions.  
✅ **Prevents stuck keys** using built-in safety mechanisms.  

This library is particularly useful for **power users, gamers, and automation workflows** where **customized key handling** is essential. 🚀

This is my TapHoldManager Library script:

```cpp
#Requires AutoHotkey v2.1-alpha.16

class TapHoldManager {
	Bindings := Map()

	__New(tapTime?, holdTime?, maxTaps := "", prefixes := "$", window := "") {
		this.tapTime := tapTime ?? 150
		this.holdTime := holdTime ?? 150
		this.maxTaps := maxTaps
		this.prefixes := prefixes
		this.window := window

		this.activeKeys := Map()
		this.lastKeyPress := 0
	}

	; Add a key
	Add(keyName, callback, tapTime?, holdTime?, maxTaps?, prefixes?, window?) {
		if this.Bindings.Has(keyName)
			this.RemoveHotkey(keyName)
		this.Bindings[keyName] := TapHoldManager.KeyManager(this, keyName, callback, tapTime ?? this.tapTime, holdTime ?? this.holdTime, maxTaps ?? this.maxTaps, prefixes?, window?)
	}

	; Remove a key
	RemoveHotkey(keyName) {
		this.Bindings.Delete(keyName).SetState(0)
	}

	; Pause a key
	PauseHotkey(keyName) {
		this.Bindings[keyName].SetState(0)
	}

	; Unpause a key
	ResumeHotkey(keyName) {
		this.Bindings[keyName].SetState(1)
	}

	class KeyManager {
		; AutoHotInterception mod does not use prefixes or window, so these parameters must be optional
		__New(manager, keyName, callback, tapTime, holdTime, maxTaps, prefixes?, window?) {
			; Existing properties
			this.state := 0
			this.sequence := 0
			this.holdWatcherState := 0
			this.tapWatcherState := 0
			this.holdActive := 0

			; Add safety properties
			this.lastPriorKey := ""       ; Track last prior key for validation
			this.forceReleased := false   ; Track if key was force-released

			; Core properties
			this.manager := manager
			this.keyName := keyName
			this.callback := callback
			this.tapTime := tapTime
			this.holdTime := holdTime
			this.maxTaps := maxTaps
			this.prefixes := prefixes ?? manager.prefixes
			this.window := window ?? manager.window
			this.lastStateChange := A_TickCount

			; Bind functions
			this.HoldWatcherFn := this.HoldWatcher.Bind(this)
			this.TapWatcherFn := this.TapWatcher.Bind(this)
			this.JoyReleaseFn := this.JoyButtonRelease.Bind(this)
			this.SafetyCheckFn := this.SafetyCheck.Bind(this)

			this.DeclareHotkeys()

			; Add periodic safety check
			SetTimer(this.SafetyCheckFn, 1000)
		}

		SafetyCheck() {
			; Check if key has been stuck down for over 1 seconds
			if (this.state == 1 && A_TickCount - this.lastStateChange > 1000) {
				this.ForceKeyRelease()
			}
		}

		ForceKeyRelease() {
			; Reset all key states
			this.state := 0
			this.forceReleased := true
			this.ResetSequence()

			; Force key up command
			Send("{" this.keyName " up}")

			; Clear any running timers
			SetTimer(this.HoldWatcherFn, 0)
			SetTimer(this.TapWatcherFn, 0)
		}

		DeclareHotkeys() {
			if (this.window)
				HotIfWinactive this.window

			Hotkey this.prefixes this.keyName, this.KeyEvent.Bind(this, 1), "On"
			if (this.keyName ~= "i)^\d*Joy") {
				Hotkey this.keyName " up", (*) => SetTimer(this.JoyReleaseFn, 10), "On"
			} else {
				Hotkey this.prefixes this.keyName " up", this.KeyEvent.Bind(this, 0), "On"
			}

			if (this.window)
				HotIfWinactive ; restores hotkey window context to default
		}

		; Turns On/Off hotkeys (should be previously declared) // state is either "1: On" or "0: Off"
		SetState(state) {
			; "state" under this method context refers to whether the hotkey will be turned on or off, while in other methods context "state" refers to the current activity on the hotkey (whether it's pressed or released (after a tap or hold))
			if (this.window)
				HotIfWinactive this.window

			state := (state ? "On" : "Off")
			Hotkey this.prefixes this.keyName, state
			if (this.keyName ~= "i)^\d*Joy") {
				Hotkey this.keyName " up", state
			} else {
				Hotkey this.prefixes this.keyName " up", state
			}
			if (state == "Off") {
				SendInput("{Blind}" this.keyName " Up")
			}

			if (this.window)
				HotIfWinactive
		}

		; For correcting a bug in AHK
		; A joystick button hotkey such as "1Joy1 up::" will fire on button down, and not on release up
		; So when the button is pressed, we start a timer which checks the actual state of the button using GetKeyState...
		; ... and when it is actually released, we fire the up event
		JoyButtonRelease() {
			if (GetKeyState(this.keyName))
				return
			SetTimer this.JoyReleaseFn, 0
			this.KeyEvent(0)
		}

		; Called when key events (down / up) occur
		KeyEvent(state, *) {
			if (state == this.state)
				return	; Suppress Repeats
			this.state := state
			if (state) {
				; Key went down
				this.sequence++
				this.SetHoldWatcherState(1)
			} else {
				; Key went up
				this.SetHoldWatcherState(0)
				if (this.holdActive) {
					this.holdActive := 0
					SetTimer this.FireCallback.Bind(this, this.sequence, 0), -1
					this.ResetSequence()
					return
				} else {
					if (this.maxTaps && this.Sequence == this.maxTaps) {
						SetTimer this.FireCallback.Bind(this, this.sequence, -1), -1
						this.ResetSequence()
					} else {
						this.SetTapWatcherState(1)
					}
				}
			}
		}

		; Enhanced sequence reset with modifier cleanup
		ResetSequence() {
			this.SetHoldWatcherState(0)
			this.SetTapWatcherState(0)
			this.sequence := 0
			this.holdActive := 0

			; Clean up any stuck modifiers
			static modifiers := ["Shift", "Ctrl", "Alt"]
			for mod in modifiers {
				if GetKeyState(mod) {
					Send("{" mod " up}")
				}
			}
		}

		; When a key is pressed, if it is not released within tapTime, then it is considered a hold
		SetHoldWatcherState(state) {
			this.holdWatcherState := state
			SetTimer this.HoldWatcherFn, (state ? "-" this.holdTime : 0)
		}

		; When a key is released, if it is re-pressed within tapTime, the sequence increments
		SetTapWatcherState(state) {
			this.tapWatcherState := state
			; SetTimer this.TapWatcherFn, (state ? "-" this.tapTime : 0)
			SetTimer this.TapWatcherFn, (state ? "-" this.tapTime : 0)
		}

		; If this function fires, a key was held for longer than the tap timeout, so engage hold mode
		HoldWatcher() {
			if (this.sequence > 0 && this.state == 1) {
				; Got to end of tapTime after first press, and still held.
				; HOLD PRESS
				SetTimer this.FireCallback.Bind(this, this.sequence, 1), -1
				this.holdActive := 1
			}
		}

		; If this function fires, a key was released and we got to the end of the tap timeout, but no press was seen
		TapWatcher() {
			if (this.sequence > 0 && this.state == 0) {
				; TAP
				SetTimer this.FireCallback.Bind(this, this.sequence), -1
				this.ResetSequence()
			}
		}

		; Fires the user-defined callback
		FireCallback(seq, state := -1) {
			this.Callback.Call(state != -1, seq, state)
		}
	}
}
```

Here's my curre