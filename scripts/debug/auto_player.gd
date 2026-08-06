class_name AutoPlayer
extends Node
## Debug auto-player: a scripted "competent human" for the Sit.
##
## A bang-bang controller — hold while the needle sits below the midpoint of the
## Flow band, release above it — that also drops the push during any hazard which
## freezes The Push, so it passes Knocks. It drives the SAME intent path a person
## does (`Sit.set_auto_hold`), so what it plays is a genuine run: ticked by the
## sim, scored by Scoring, indistinguishable from a human to everything downstream.
##
## It exists to answer questions a no-input run cannot — is the sit completable,
## is the red line actually worth taking, do the meters end up earnable. It found
## all four of the tuning faults that produced the current numbers.
##
## What it CANNOT tell you is whether any of it feels good. Treat its runs as
## measurements, not playtests.
##
## Caveat on determinism: the sim stays deterministic for a given intent stream,
## but this controller reacts once per rendered frame, so the stream it generates
## is frame-rate dependent. Bot runs are therefore NOT bit-reproducible across
## machines — don't use one as a determinism fixture (the test suites drive
## intents per fixed step precisely to avoid this).
##
## Toggle at runtime with B, or tick `auto_play` on the Sit before pressing play.

## The Sit node being driven. Must expose sim_state() and set_auto_hold().
var sit: Node = null

## Nudges the aim off the band midpoint. The needle carries momentum, so a small
## negative bias can stop it drifting into the red on a wide band.
@export var aim_bias: float = 0.0


func _process(_delta: float) -> void:
	if sit == null:
		return
	var st: SimState = sit.sim_state()
	if st == null or st.flow_bands.is_empty():
		return

	# Swipe-answerable hazards: waft a Smell Cloud, re-centre after a Jolt. Both
	# are free to answer immediately, and one swipe serves either.
	if Hazards.find(st, SimEvent.Kind.SMELL) != null or Hazards.find(st, SimEvent.Kind.JOLT) != null:
		sit.set_auto_swipe(Vector2(60.0, 0.0))

	# Dismiss the phone before it rings out.
	if Hazards.find(st, SimEvent.Kind.BUZZ) != null:
		sit.set_auto_tap(true)

	# A freeze hazard (The Knock) demands no input at all — release and hold still.
	if Hazards.relief_stalled(st):
		sit.set_auto_hold(false)
		return

	# The nearest band, not the span's middle: on a split zone the latter is the dead
	# notch, and a bot aiming at it would measure a level nobody would play that way.
	var target: float = PushSim.nearest_band_centre(st) + aim_bias
	# In a quiet room (Church or Rave), pushing above the silence cap while the room
	# is exposed is audible — so hover just below the cap while exposed, and only push
	# into Flow when it's safe. Lets a bot run actually measure winnability either way.
	var level: LevelDef = sit.current_level() if sit.has_method("current_level") else null
	if level != null and level.is_quiet_room() and Hazards.room_exposed(st, level):
		target = maxf(0.0, level.silence_push_cap - 0.06)
	sit.set_auto_hold(st.needle < target)
