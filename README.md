# Minyaty

Minyaty is an X11 window manager that emphasizes low-effort switching between full-screen windows.

Rather than a stacking or tiling model, Minyaty uses a switching model: It sizes all windows to cover the entire screen and provides powerful tools to quickly raise the window you want.

When configured appropriately, a given window can be raised with a short, deterministic series of keystrokes. For example, in my configuration, `alt + F1` raises the terminal, `alt + F2` raises the primary browser, and `alt + F2, F2` raises the secondary browser. `alt + tab` alternates between the current and previous windows, and `alt + esc` cycles backwards through window history. See below for configuration and command documentation.

Minyaty was designed for use with a single monitor—I have come to prefer a single monitor with a powerful window switcher over multiple monitors. Multiple monitors may be supported in the future.

Minyaty can be thought of as a tagged alt-tabber, and in the future may support a non-window-manager mode wherein it offers only window switching.

## Installation

TODO: Write installation instructions here

## Usage

TODO: Write usage instructions here

## Example config.yml

```yml
---
categories:
  - name: "terminal"
    patterns: ["kitty", "xterm", "mpv"]
  - name: "browsers"
    patterns:
      - "vivaldi-stable"
          hints: {x: 0, y: -2, width: +2, height: +2}
      - "firefox"
      - "chromium"
      - "Opera"
  - name: "comms"
    patterns: ["thunderbird", "hexchat"]
  - name: "all"
  - name: "uncategorized"
taskbar:
  height: 15
```

## Example .xbindkeysrc

```
"/usr/local/lib/minyaty/bin/command.sh circulate-windows-down"
  Alt + Escape

"/usr/local/lib/minyaty/bin/command.sh circulate-windows-alt"
  Alt + Tab

"/usr/local/lib/minyaty/bin/command.sh cycle-category terminal"
  Alt + F1

"/usr/local/lib/minyaty/bin/command.sh cycle-category browsers"
  Alt + F2

"/usr/local/lib/minyaty/bin/command.sh cycle-category comms"
  Alt + F3

"/usr/local/lib/minyaty/bin/command.sh cycle-category uncategorized"
  Alt + F4

"/usr/local/lib/minyaty/bin/command.sh cycle-category all"
  Alt + F5
```

## Known limitations and planned features

See TODO file.
