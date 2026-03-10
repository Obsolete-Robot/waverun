# WaveRun Physics Handoff

## Goal

Replace the original Godot rigid-body jet ski with a custom Wave Race 64-style watercraft controller and a custom wave solver, plus add enough logging to debug the behavior from actual runs.


## Current State

The project is no longer using `RigidBody3D` for the jet ski.

Current controller:
- File: [scripts/jetski.gd](/mnt/e/Projects/waverun/scripts/jetski.gd)
- Base node: `Node3D`
- Motion model: fully manual integration
- State tracked manually:
  - planar velocity
  - vertical velocity
  - heading
  - yaw rate
  - grounded / traction
  - sampled water height / normal
  - pitch / roll attitude

Current water solver:
- File: [scripts/main.gd](/mnt/e/Projects/waverun/scripts/main.gd)
- Shared by:
  - physics sampling via `wave_height_at()` / `wave_normal_at()`
  - shader rendering via [materials/ocean.gdshader](/mnt/e/Projects/waverun/materials/ocean.gdshader)

Wave debug logging:
- File path written at runtime: [debug/jetski_debug.log](/mnt/e/Projects/waverun/debug/jetski_debug.log)
- Logger lives in [scripts/jetski.gd](/mnt/e/Projects/waverun/scripts/jetski.gd)


## Major Changes Made

### 1. Removed rigid-body physics

Previous approach:
- `RigidBody3D`
- force/torque stacking
- buoyancy samples applied through Godot physics

Problems:
- unstable
- hard to tune
- produced flying / flipping / drift behavior

Replacement:
- custom controller in `Node3D`
- explicit integration in `_physics_process()`


### 2. Rebuilt wave solver

Wave state now comes from layered directional sine waves in [scripts/main.gd](/mnt/e/Projects/waverun/scripts/main.gd).

Important implementation detail:
- wave normals are derived analytically from the same phase model used for height

Important correction already made:
- an earlier version multiplied the wave phase and gradient by `60.0`
- that made the surface absurdly steep
- logs showed `normal_y` collapsing as low as about `0.2`
- this was fixed by removing that scaling and reducing amplitudes/frequencies


### 3. Added visible local water detail

The original ocean plane was too coarse over a huge area, so wave displacement was hard to see.

Current setup in [scripts/main.gd](/mnt/e/Projects/waverun/scripts/main.gd):
- `OceanFar`: large lower-detail mesh
- `OceanDetail`: smaller high-density mesh centered on the player

This was added so the water shape is actually readable near the craft.


### 4. Added persistent debug logging

Logger output:
- path: [debug/jetski_debug.log](/mnt/e/Projects/waverun/debug/jetski_debug.log)

Logged fields currently include:
- throttle
- steer
- grounded
- traction
- forward speed
- slip speed
- position
- velocity
- heading
- yaw speed
- surface height
- pitch / roll
- surface normal
- front/back/left/right sampled wave heights

Purpose:
- identify whether failures come from
  - input handling
  - water solver
  - surface contact logic
  - lateral slip / yaw behavior


## What The Logs Proved

### First major issue: water solver was broken

Observed in old logs:
- `normal_y` values far below sane range
- huge wave height differences across a ~1 meter craft footprint
- large pitch/roll at idle

Conclusion:
- the controller was reacting to pathological water normals
- water had to be fixed before controller tuning meant anything

Status:
- largely fixed


### Second major issue: controller behaved like a hovercraft

Observed after wave fix:
- craft kept high lateral slip
- heading kept accumulating without solid carving behavior
- speed plateaued oddly
- turning looked like sliding rather than biting into water

Changes made:
- increased water grip
- reduced air grip
- made yaw depend more on forward motion
- logged `forward_speed` and `slip_speed`

Status:
- improved, but not solved


### Third major issue: craft could fall through the water state

Observed in latest logs:
- once `grounded` flipped false, `traction` went to `0`
- then `vel_y` kept accelerating downward
- craft never recovered to the ride target
- it effectively fell through the water model

Changes made:
- stricter but recoverable water contact logic
- submerged reentry lift
- submerge-depth clamp

Status:
- code changed, but not yet verified in a follow-up log after the last patch


## Files Touched

- [scripts/jetski.gd](/mnt/e/Projects/waverun/scripts/jetski.gd)
- [scripts/main.gd](/mnt/e/Projects/waverun/scripts/main.gd)
- [materials/ocean.gdshader](/mnt/e/Projects/waverun/materials/ocean.gdshader)
- [scenes/main.tscn](/mnt/e/Projects/waverun/scenes/main.tscn)
- [debug/jetski_debug.log](/mnt/e/Projects/waverun/debug/jetski_debug.log)


## Current Technical Design

### Jet ski controller

Main phases in [scripts/jetski.gd](/mnt/e/Projects/waverun/scripts/jetski.gd):
1. `_read_input(delta)`
2. `_sample_wave(t)`
3. `_step_vertical(delta, wave)`
4. `_step_planar(delta)`
5. apply `global_position += velocity * delta`
6. `_update_attitude(delta, wave)`
7. `_log_debug_sample(delta, wave)`

Water contact is not collision-based.
It is based on ride target relative to sampled water height.


### Water rendering

Main world/ocean setup is in [scripts/main.gd](/mnt/e/Projects/waverun/scripts/main.gd).

Visual ocean:
- far plane for horizon coverage
- detail plane around player for readable displacement

Shader:
- [materials/ocean.gdshader](/mnt/e/Projects/waverun/materials/ocean.gdshader)
- uses same directional wave family as gameplay script


### UI

Wave size slider exists in [scenes/main.tscn](/mnt/e/Projects/waverun/scenes/main.tscn) and is driven from [scripts/main.gd](/mnt/e/Projects/waverun/scripts/main.gd).

It updates:
- shader wave scale
- physics wave sampling scale


## Known Problems Still Open

1. The controller still does not feel like Wave Race 64.
2. Surface reacquisition after losing contact was just patched and needs verification from a new log.
3. Turning still likely needs a stronger carve model rather than current yaw-rate steering.
4. There is no true planing model yet, only a ride-height spring with planar steering/grip logic.
5. There is no stunt/jump/landing behavior model.
6. There is no rider lean system separated from hull attitude.


## Recommended Next Steps

### Immediate

1. Run the game again and inspect [debug/jetski_debug.log](/mnt/e/Projects/waverun/debug/jetski_debug.log).
2. Verify that when the craft dips below the ride target:
   - `grounded` returns to `true`
   - `traction` returns to `1.00`
   - `vel_y` does not run away downward
3. Confirm the new `OceanDetail` mesh makes wave displacement visible near the player.


### Controller redesign likely needed

If continuing toward Wave Race feel, the next controller should probably be restructured around:
- scalar forward speed
- scalar lateral slip
- heading / yaw state
- ride height from water
- explicit carve behavior
- explicit airborne state

That is likely cleaner than continuing to push the current vector-velocity controller.


## Environment Notes

I could not run Godot locally in this environment because there is no `godot` or `godot4` binary available in the sandbox.

That means:
- code edits were made by reading and patching scripts directly
- validation was done from the generated runtime log file, not from local execution here


## Important Artifacts

- Handoff doc: [HANDOFF_PHYSICS.md](/mnt/e/Projects/waverun/HANDOFF_PHYSICS.md)
- Controller: [scripts/jetski.gd](/mnt/e/Projects/waverun/scripts/jetski.gd)
- Water/gameplay: [scripts/main.gd](/mnt/e/Projects/waverun/scripts/main.gd)
- Water shader: [materials/ocean.gdshader](/mnt/e/Projects/waverun/materials/ocean.gdshader)
- Latest debug log: [debug/jetski_debug.log](/mnt/e/Projects/waverun/debug/jetski_debug.log)
