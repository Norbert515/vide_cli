# VHS tape for Vide multi-agent enterprise workflow demo
# Run: cd /path/to/vide_cli_2 && vhs docs/demo.tape
# Requires: vhs (brew install vhs)
#
# SETUP:
# 1. Reset the demo project: git -C docs/demo-project reset --hard HEAD
# 2. Do a practice run manually to calibrate timing
# 3. Adjust Sleep durations below to match your run
# 4. Run: vhs docs/demo.tape
#
# The demo project at docs/demo-project/ is a minimal Flutter app
# with stubs for authentication - perfect for agents to implement.

Output docs/vide-demo.mp4

Set Shell "bash"
Set FontSize 13
Set Width 1400
Set Height 900
Set Theme "Dracula"
Set Padding 0
Set Framerate 30

# Enable true color support for the TUI
Env COLORTERM "truecolor"
Env TERM "xterm-256color"

# Navigate to the demo project
Hide
Type "cd docs/demo-project"
Enter
Sleep 300ms
Type "clear"
Enter
Sleep 200ms
Show

# Show the vide command being typed
Type@50ms "vide"
Sleep 300ms
Enter

# Wait for vide TUI to load
Sleep 2s

# Type a task that reads and writes multiple files
# The @50ms makes typing visible and dramatic
Type@50ms "Add a User model with name and email fields, and a UserService with CRUD methods"
Sleep 500ms
Enter

# ============================================
# ADJUST THESE TIMES BASED ON YOUR ACTUAL RUN
# Do a practice run first to calibrate!
# ============================================

# Wait for the agent to explore and implement
Sleep 45s

# Show the completed state for a moment
Sleep 3s

# Exit cleanly
Hide
Ctrl+C
Sleep 500ms
