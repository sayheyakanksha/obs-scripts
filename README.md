# OBS Lua Scripts

A collection of simple, no-nonsense Lua scripts for OBS Studio. Built because the options out there were either too complicated or didn't do what we needed.

## Scripts

### OBS Advanced Timer (`obs-timer.lua`)
A flexible count-up and countdown timer.

- **Count Up & Countdown** modes
- Set a custom start time for both modes
- Display format: `HH:MM:SS:ms` with toggles for hours and milliseconds
- Start/Pause toggle, Reset controls
- Text prefix and suffix (e.g., "Time: 01:23:45:67 elapsed")
- Countdown end text and auto-reset option
- Adjustable update speed (10ms to 1000ms)
- Hotkey support for hands-free control

### OBS Counter (`obs-counter.lua`)
A simple counter that goes up or down by 1.

- Increment and decrement by 1
- Text prefix and suffix (e.g., "Score: 5 pts")
- Configurable starting value
- Reset to starting value
- Hotkey support for hands-free control

## How to Install

1. Download the `.lua` file(s) you want
2. In OBS, go to **Tools > Scripts**
3. Click the **+** button and select the script
4. Choose a **Text (GDI+/FreeType)** source from the dropdown
5. Configure settings and you're good to go

**Tip:** Need the same script for multiple text sources? Just duplicate the `.lua` file (e.g., `obs-timer-2.lua`) and add it as a separate script.

## Hotkeys

All scripts register hotkeys that you can assign in **OBS Settings > Hotkeys**. Search for "Timer" or "Counter" to find them.

## More Scripts Coming

We're planning to add more scripts over time. If you have suggestions or ideas for scripts you'd like to see, feel free to open an issue or reach out!

## Author

[@sayheyakanksha](https://github.com/sayheyakanksha)
