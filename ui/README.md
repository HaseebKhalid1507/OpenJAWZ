# ui/

`hotkey/` — `openjawz summon` (the global key → terminal window of class `openjawz` → `synaps --attach`),
plus the Hyprland (`hyprland.conf`) and sway (`sway.conf`) snippets. `openjawz ui install` copies the snippet
to `~/.config/{hypr,sway}/openjawz.conf`, enables `foot-server.socket` when foot is present, and prints the
one `source =` / `include` line you add yourself.

`bar/` — `waybar-status` (one JSON line: sessions, lifecycle, owner, daemon memory) + the Waybar module block
and CSS states. `quickshell/` shows the same script wrapped for another bar.

`themes/swatch` — theme contrast previewer for the runtime's palettes (a dev tool, needs a runtime checkout).
