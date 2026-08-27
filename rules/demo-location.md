# Demo Location Rule

**ALWAYS** save demo scripts to the directory set as `DEMO_DIR` in `harness.env`
(by convention, a `Demo/` folder at the project root).

## When this rule applies

Whenever the user asks to:

- "show me features" / "show me a feature"
- "create a quick demo" / "make a demo" / "build a demo"
- "demo this" / "give me a demo of X"
- Any request phrased as a demonstration, showcase, or feature preview

Any `.ahk` file created to satisfy such a request belongs in the `Demo/` folder — not the repo root, not `Lib/`, not `Examples/`.

## How to apply

1. If `Demo/` does not exist, create it first.
2. Use a descriptive filename: `Demo\<Feature>_Demo.ahk` (e.g. `Demo\DarkMode_Demo.ahk`, `Demo\ListView_Sort_Demo.ahk`).
3. Make the demo self-contained and runnable — no external dependencies beyond what's already in `Lib/`.
4. Report the created path to the user as a clickable Windows path (e.g. `Demo\DarkMode_Demo.ahk`).

## Exceptions

- If the user explicitly specifies a different save location, use that instead.
- If the user asks to modify an *existing* demo that lives elsewhere, edit in place — do not relocate.
- Tests, library code, and production scripts do **not** belong in `Demo/`.
