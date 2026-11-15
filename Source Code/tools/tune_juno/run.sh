#!/bin/sh
# SI assistance metadata: This code used the help of SI.
G=$(ls -d /c/Users/ASUS/AppData/Local/Temp/claude/*/*/scratchpad/godot | head -1)
timeout 180 "$G/Godot_v4.3-stable_win64_console.exe" --headless --path . -s tools/tune_juno/sweep.gd 2>&1 | grep -v "^DataLoader\|^  [a-z_]* *[0-9]*$\|^Godot Engine\|^ERROR: BUG\|^   at:\|^WARNING: A Thread\|^Please call\|^     at:\|^ERROR: Pages"
