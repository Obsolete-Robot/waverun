# WaveRun (Godot 4)

WaveRun is now a **3D open-ocean wave racing prototype** inspired by Wave Race 64 handling.

## What’s in this build

- Huge open water surface with animated shader waves
- Jetski-style rigid-body movement with buoyancy + drag + lateral grip
- Arcade-style handling tuned toward Wave Race feel (not 1:1 yet)
- Floating checkpoint circuit, lap timer, and best-lap tracking

## Controls

- **Throttle/Brake:** `W/S` or `↑/↓`
- **Steer:** `A/D` or `←/→`
- **Reset run:** `R`

## Export (Web)

```bash
/home/david/.local/bin/godot --headless --path . --export-release "Web" index.html
```

## Live

- https://games.obsoleterobot.com/waverun/
