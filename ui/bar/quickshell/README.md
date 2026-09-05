# Quickshell / eww

Same script, same JSON. `waybar-status` prints one line `{"text","alt","class":[…],"tooltip"}`;
wrap it in a `Process` (Quickshell) or `deflisten`/`defpoll` (eww) and read `alt` for the state.
Example only — v0.1 ships the Waybar module; nothing here is tested.

```qml
// shell.qml — minimal Quickshell reader
import Quickshell
import Quickshell.Io
ShellRoot {
  Process { id: oj; command: ["/usr/lib/openjawz/ui/waybar-status"]; running: true
    stdout: SplitParser { onRead: data => { const j = JSON.parse(data); status.text = j.text; status.state = j.alt } } }
  Timer { interval: 10000; running: true; repeat: true; onTriggered: oj.running = true }
  // …render `status` as you like; class "pending" means `openjawz migrate` has work
}
```
