---
name: ahk-screen
description: >
  Screen, pixels, images, monitors and DPI for AHK v2 — CoordMode, PixelGetColor and PixelSearch,
  ImageSearch, MonitorGet and per-monitor DPI, screen capture to a DIB and PNG through GDI+, and
  click-through overlays.
  TRIGGER when: user says "pixel color", "PixelSearch", "ImageSearch", "screenshot", "screen
  capture", "monitor", "multi-monitor", "DPI", "scaling", "CoordMode", "overlay", "find an image on
  screen", "wait for a color".
  Examples: "wait until this pixel turns green", "capture a region to a PNG", "find a button image",
  "draw an overlay on monitor 2", "my coordinates are off on a 150% display"
---

# AHK v2 Screen, Pixels and Images

Load `${CLAUDE_PLUGIN_ROOT}/Modules/Module_GraphicsAndScreen.md`. For GUI controls and dark mode use `/ahk-gui`. For window coordinates use `/ahk-input`.

## Critical rules

- `CoordMode` is per thread and a new thread starts fresh. Set it at startup or at the top of each hotkey and timer callback that uses coordinates.
- AHK v2 is DPI aware, so screen coordinates are already physical pixels. Do not scale them by `A_ScreenDPI`.
- Create overlays with `-DPIScale` or their position is wrong at any scaling above 100%.
- Monitor layouts change at runtime. Refresh cached `MonitorGet` data on `WM_DISPLAYCHANGE`.
- A bad image file or option makes `ImageSearch` raise `ValueError`. It is not a silent failure.
- Compare pixel colors as integers, for example `PixelGetColor(x, y) = 0xFF0000`.
