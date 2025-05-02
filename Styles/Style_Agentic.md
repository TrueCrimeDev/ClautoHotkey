**Coding Agent Style Guide (v2)**

---

### PLACEHOLDER LEGEND
* **[path/to/file]** – path relative to the project root.
* **[class or function context]** – the signature line that surrounds the edit (used *only* in prose, **never** inside the diff block).

---

## 1 · Patch Envelope (text outside the code blocks)
The outer wrapper tells the coding agent where a patch starts and ends. It is **plain text**, not part of any fenced code block.

```text
apply_patch <<"EOF"
*** Begin Patch
*** Patch Summary: <one‑line description>
*** [ACTION: <Add|Update|Remove|Rename>] File: [path/to/file]

Edit <N>: <short label for the first change>
```diff
<diff block goes here>
```

Edit <N+1>: <label for the next change>
```diff
<next diff block>
```

... (repeat Edit sections as needed) ...

*** End Patch
EOF
```

**Rules**
1. `apply_patch <<"EOF"`, `*** Begin Patch`, `*** End Patch`, and the final `EOF` **must stay outside** of any markdown code block.
2. Each logical change must be introduced by an **Edit X:** label followed by a **separate fenced `diff` block**.
3. The **`@@` header is omitted** inside the diff blocks; show only the 3‑line pre‑context, the `‑` removals, the `+` additions, and the 3‑line post‑context.
4. Provide exactly **3 lines** of context above and below the change (adjust only if a wider context is essential).
5. Keep a single blank line between the Edit label and its diff block for readability.

---

## 2 · Diff Block Conventions
* Use the `diff` language specifier (` ```diff `) for every code block.
* Mark deletions with `‑` and additions with `+`.
* Do **not** include the `@@` context header—those belong in prose if you need to describe scope.
* One diff block ≈ one atomic edit; if you touch two distant regions, create **Edit 1**, **Edit 2**, etc.

---

## 3 · AHK v2‑Specific Rules
* **Always** prefer `Map()` over object literals.
  ```ahk
  ; ❌ Avoid
  this.settings := {width: 800, height: 600}

  ; ✅ Prefer
  this.settings := Map(
      "width", 800,
      "height", 600
  )
  ```
* **Class instantiation**: `new MyClass()`.
* **Callbacks / method references**: bind with `.Bind(this)`.
* **Naming**
  * Methods → **PascalCase** (e.g. `LoadSettings()`)
  * Variables / properties → **camelCase** (e.g. `configPath`)

---

## 4 · Concise Explanations
After **each** diff block, add a one‑sentence rationale (outside the fenced block). Focus on *why* the change matters.

---

## 5 · Full Example (multi‑edit)
```text
apply_patch <<"EOF"
*** Begin Patch
*** Patch Summary: Add dark‑mode support to GUI & ListView
*** [ACTION: Update] File: src/ClipboardHistoryCombiner.ahk

Edit 1: Call `ApplyDarkTitleBar()` in constructor
```diff
class ClipboardHistoryCombiner {
    __New() {
        this.items := []
        this.gui := Gui("+Resize", "Clipboard History Combiner")
        this.gui.SetFont("s10")
        this.gui.BackColor := 0x202020
+       this.ApplyDarkTitleBar(this.gui)

        this.gui.AddText("xm w400 cFFFFFF", "Select clipboard history items to combine:")
        this.gui.AddText("xm w400 cFFFFFF", "Content Preview")
        this.listView := this.gui.AddListView("r10 w600 Checked -Hdr", ["Content"])
        this.ApplyDarkListView(this.listView)
```
*Why:* Enables OS‑level dark title bar for the window.

Edit 2: Declare new constants & checkbox styling
```diff
class ClipboardHistoryCombiner {
        static LVM_SETTEXTCOLOR := 0x1024
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_SETBKCOLOR   := 0x1001
+       static LVITEM_CHECKED_COLOR := 0x26A0DA
+       static LVCF_CHECKBOXES      := 0x10

        SendMessage(LVM_SETTEXTCOLOR, 0, 0xFFFFFF, lv)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, 0x202020, lv)
        SendMessage(LVM_SETBKCOLOR, 0, 0x202020, lv)
        lv.Opt("+Grid +LV0x10000")
        DllCall("uxtheme\\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
+       ; Dark‑mode checkboxes
+       DllCall("uxtheme\\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "Explorer", "Str", "ItemsView")
+       DllCall("user32\\SendMessage", "Ptr", lv.Hwnd, "UInt", 0x109A, "Ptr", 32, "Ptr", this.LVITEM_CHECKED_COLOR) ; LVM_SETOUTLINECOLOR
```
*Why:* Adds dark‑theme checkboxes to match overall UI.

*** End Patch
EOF
```

---

Keep these guidelines handy whenever you propose code changes—tools and reviewers will thank you.