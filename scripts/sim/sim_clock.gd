class_name SimClock
extends RefCounted
## Sole owner of simulation time. `step` (a monotonic integer) is the canonical
## clock — everything deterministic keys off it, so the same seed and the same
## per-step intents always reproduce the same run. `elapsed` is derived, for
## display and scoring only.
##
## All gameplay randomness pulls from `rng`, seeded once per match. Never use the
## global randf()/randi() or wall-clock time in simulation logic — that would
## break reproducible ghost replay and fair mirrored 1v1 boards (spec §17).

## One simulation step, in seconds. A fixed constant on purpose: it must not
## depend on frame rate or project settings, or replays would desync.
const FIXED_DT: float = 1.0 / 60.0

var step: int = 0
var rng := RandomNumberGenerator.new()

## Derived wall-time equivalent — read-only for the view; never drives the sim.
var elapsed: float:
	get:
		return float(step) * FIXED_DT


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value


func advance() -> void:
	step += 1


func reset(seed_value: int) -> void:
	step = 0
	rng.seed = seed_value
