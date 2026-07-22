class_name Scoring
extends RefCounted
## Deterministic score + star evaluation from end-of-run state (spec: base 1000 =
## clear 100 + Discretion 300 + Cleanliness 300 + Flow 150 + Speed 150). Returns
## numbers only — no display strings; the view maps stars → rank title, so this
## stays unit-testable and localization-agnostic (guardrail 3).

## Cleanliness at/above this at the end counts as "no major mess" for the ★★★ gate.
const NO_MAJOR_MESS_MIN: float = 50.0


static func evaluate(state: SimState, _level: LevelDef) -> Dictionary:
	var cleared := state.phase == SimState.Phase.WON

	var clear_pts := 100 if cleared else 0
	var discretion_pts := int(round(clampf(state.discretion, 0.0, 100.0) / 100.0 * 300.0))
	var cleanliness_pts := int(round(clampf(state.cleanliness, 0.0, 100.0) / 100.0 * 300.0))
	var flow_pts := int(round(state.flow_ratio() * 150.0))
	# Speed rewards Composure left at the moment you cleared; a loss scores none.
	var speed_pts := int(round(clampf(state.composure, 0.0, 100.0) / 100.0 * 150.0)) if cleared else 0

	var base := clear_pts + discretion_pts + cleanliness_pts + flow_pts + speed_pts

	var never_detected := state.detection_count == 0
	var no_major_mess := state.cleanliness >= NO_MAJOR_MESS_MIN

	var stars := 0
	if cleared:
		stars = 1
		if base >= 600:
			stars = 2
		if base >= 850 and never_detected and no_major_mess:
			stars = 3

	return {
		"cleared": cleared,
		"base": base,
		"stars": stars,
		"never_detected": never_detected,
		"breakdown": {
			"clear": clear_pts,
			"discretion": discretion_pts,
			"cleanliness": cleanliness_pts,
			"flow": flow_pts,
			"speed": speed_pts,
		},
	}
